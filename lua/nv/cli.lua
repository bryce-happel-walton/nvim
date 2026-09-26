-- nv: Neovim sessions that keep running in the background, on this machine or on
-- an SSH host (like VS Code Remote-SSH). Run with `nvim -l`; see bin/nv.
--
--   nv [folder]          a session on this machine (default: the current folder)
--   nv HOST[:folder]     a session on an SSH host (default: your home folder there)
--   nv --list            sessions you've opened
--
-- Closing the terminal or losing the connection leaves the session running, with its
-- open files and terminals. Running the same command gets you back to it; after a dropped
-- connection nv reconnects by itself. Quit Neovim (:qa) to end a session.
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(arg[0], ":p"))))
package.path = root .. "/lua/?.lua;" .. package.path
local server = require("nv.server")

local state_dir = vim.fs.joinpath(vim.fn.stdpath("state"), "nv")
vim.fn.mkdir(state_dir, "p")

local function say(msg)
  io.stdout:write(msg .. "\n")
  io.stdout:flush()
end

local function fail(msg)
  io.stderr:write("nv: " .. msg .. "\n")
  os.exit(1)
end

--- Quote for /bin/sh.
local function q(s)
  return "'" .. tostring(s):gsub("'", [['\'']]) .. "'"
end

--- Run a shell command attached to this terminal. Returns ok, interrupted (Ctrl+C), exit code.
local function run(cmd)
  local r = os.execute(cmd)
  local status = type(r) == "number" and r or (r == true and 0 or 256)
  return status == 0, status % 256 == 2, math.floor(status / 256)
end

local function sleep(seconds)
  local _, interrupted = run("sleep " .. seconds)
  if interrupted then
    os.exit(130)
  end
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then
    return ""
  end
  local data = f:read("*a")
  f:close()
  return data
end

--- Run Lua in a session. Returns the result, or nil if the session can't be reached.
local function rpc(sock, code, ...)
  local ok, chan = pcall(vim.fn.sockconnect, "pipe", sock, { rpc = true })
  if not ok or chan == 0 then
    return nil
  end
  local ok2, result = pcall(vim.rpcrequest, chan, "nvim_exec_lua", code, { ... })
  pcall(vim.fn.chanclose, chan)
  return ok2 and result or nil
end

local function label(t)
  return t.host and (t.host .. ":" .. t.dir) or t.dir
end

---------------------------------------------------------------------------
-- Recent sessions and SSH hosts (shown by :Remote)
---------------------------------------------------------------------------
local recent_file = vim.fs.joinpath(state_dir, "recent.json")

local function read_recent()
  local ok, list = pcall(vim.json.decode, read_file(recent_file))
  return ok and type(list) == "table" and list or {}
end

local function remember(t)
  local list = { { host = t.host, dir = t.dir } }
  for _, r in ipairs(read_recent()) do
    if #list < 20 and not (r.host == t.host and r.dir == t.dir) then
      list[#list + 1] = r
    end
  end
  local f = io.open(recent_file, "w")
  if f then
    f:write(vim.json.encode(list))
    f:close()
  end
end

--- Host aliases from ~/.ssh/config (and files it includes), skipping patterns.
local function ssh_hosts()
  local hosts, seen = {}, {}
  local function read(pattern, depth)
    for _, file in ipairs(depth < 5 and vim.fn.glob(pattern, false, true) or {}) do
      for line in read_file(file):gmatch("[^\n]+") do
        local key, rest = line:match("^%s*(%a+)%s*[=%s]%s*(.-)%s*$")
        key = key and key:lower()
        for word in (rest or ""):gmatch("%S+") do
          if key == "host" and not word:find("[*?!]") and not seen[word] then
            seen[word] = true
            hosts[#hosts + 1] = word
          elseif key == "include" then
            read(vim.fs.normalize(word:match("^[/~]") and word or ("~/.ssh/" .. word)), depth + 1)
          end
        end
      end
    end
  end
  read(vim.fs.normalize("~/.ssh/config"), 0)
  return hosts
end

---------------------------------------------------------------------------
-- Targets
---------------------------------------------------------------------------
local function parse(a)
  if not a or a == "" then
    return { dir = vim.uv.cwd() }
  end
  local host, dir = a:match("^([^/:]+):(.*)$")
  if host then
    return { host = host, dir = dir ~= "" and dir or "~" }
  end
  local path = vim.uv.fs_realpath(vim.fn.fnamemodify(vim.fs.normalize(a), ":p"))
  if path and vim.fn.isdirectory(path) == 1 then
    return { dir = path }
  elseif path then
    return { dir = vim.fs.dirname(path), file = path }
  elseif a:find("@") or vim.list_contains(ssh_hosts(), a) then
    return { host = a, dir = "~" }
  end
  fail(("%s isn't a folder or an SSH host. For a folder on a host, use HOST:folder"):format(a))
end

---------------------------------------------------------------------------
-- Local sessions
---------------------------------------------------------------------------
local function connect_local(t)
  t.sock = server.ensure(t.dir)
  return t
end

---------------------------------------------------------------------------
-- SSH sessions. Each nv process keeps its own ssh connection, as a child process
-- (so it ends with the terminal), which carries the session's socket. If it's gone
-- when the UI closes, the connection was lost, rather than Neovim closed.
---------------------------------------------------------------------------
local pid = vim.fn.getpid()

-- Clean up after nv processes that are gone.
for name in vim.fs.dir(state_dir) do
  local owner = tonumber(name:match("^(%d+)%.sock$") or name:match("^(%d+)%.ssh$"))
  if owner and owner ~= pid and not vim.uv.kill(owner, 0) then
    local path = vim.fs.joinpath(state_dir, name)
    if name:match("%.ssh$") then
      os.execute("ssh -S " .. "'" .. path .. "' -O exit nv >/dev/null 2>&1")
    end
    os.remove(path)
  end
end
local v = vim.version()
local nvim_tag = v.prerelease and "nightly" or ("v%d.%d.%d"):format(v.major, v.minor, v.patch)

-- Ignore RemoteCommand / RequestTTY from ~/.ssh/config (like auto-starting tmux).
local SSH_OPTS = { "-o", "RemoteCommand=none", "-o", "RequestTTY=no" }

local function mux(t)
  return "ssh -S " .. q(t.control) .. " -o ControlMaster=no " .. table.concat(SSH_OPTS, " ") .. " "
end

local function connected(t)
  return run(mux(t) .. "-O check " .. q(t.host) .. " 2>/dev/null")
end

--- Run a command on the host and capture its output.
local function remote(t, cmd, stdin)
  local args = vim.list_extend({ "ssh", "-S", t.control, "-o", "ControlMaster=no" }, SSH_OPTS)
  return vim.system(vim.list_extend(args, { t.host, cmd }), { stdin = stdin, text = true }):wait()
end

local master ---@type vim.SystemObj?

local function open_connection(t)
  os.remove(t.control)
  local errors, exited = {}, false
  -- The connection runs `cat` on the host, reading a pipe from this process: when nv
  -- goes away for any reason (like a closed terminal), the pipe closes and so does ssh.
  -- Password and host key prompts still work: ssh asks on the terminal directly.
  master = vim.system(vim.list_extend(vim.list_extend({
    "ssh", "-M", "-S", t.control,
    "-o", "ServerAliveInterval=5", "-o", "ServerAliveCountMax=3", "-o", "ConnectTimeout=15",
    "-o", "StreamLocalBindUnlink=yes", "-o", "ExitOnForwardFailure=no",
  }, SSH_OPTS), { t.host, "cat >/dev/null" }), {
    stdin = true,
    stderr = function(_, data)
      errors[#errors + 1] = data
    end,
  }, function()
    exited = true
  end)
  vim.wait(10 * 60 * 1000, function()
    return exited or vim.uv.fs_stat(t.control) ~= nil
  end, 100)
  if exited or not connected(t) then
    local msg = vim.trim(table.concat(errors))
    error(msg ~= "" and msg:match("[^\n]*$") or ("couldn't connect to " .. t.host))
  end
end

--- Make sure the host has the same Neovim version as this machine. Returns its path.
local function remote_nvim(t)
  local script, out = root .. "/lua/nv/ensure-nvim.sh", vim.fn.tempname()
  -- Progress and errors go straight to the terminal; the path comes back on stdout.
  local function ensure(args)
    local _, interrupted, code = run(("%s%s %s < %s > %s"):format(mux(t), q(t.host), q("sh -s -- " .. args), q(script), q(out)))
    if interrupted then
      os.exit(130)
    end
    return code, vim.trim(read_file(out)):match("[^\n]+$")
  end
  local code, path = ensure(q(nvim_tag))
  if code == 3 then
    -- The host can't download it: download here and copy it over.
    local u = remote(t, "uname -s; uname -m").stdout or ""
    local os_name = u:match("Darwin") and "macos" or "linux"
    local arch = (u:match("aarch64") or u:match("arm64")) and "arm64" or "x86_64"
    local url = ("https://github.com/neovim/neovim/releases/download/%s/nvim-%s-%s.tar.gz"):format(nvim_tag, os_name, arch)
    local tmp = vim.fn.tempname() .. ".tar.gz"
    say("  " .. t.host .. " can't download Neovim, so copying it from here...")
    local ok = run("curl -fsSL -o " .. q(tmp) .. " " .. q(url))
      and run(mux(t) .. q(t.host) .. [[ 'cat > "$HOME/.nv-nvim.tar.gz"' < ]] .. q(tmp))
    os.remove(tmp)
    if not ok then
      error("couldn't install Neovim on " .. t.host)
    end
    code, path = ensure(q(nvim_tag) .. [[ "$HOME/.nv-nvim.tar.gz"]])
  end
  os.remove(out)
  if code ~= 0 or not path then
    error("couldn't install Neovim on " .. t.host)
  end
  return path
end

--- Copy this config to the host (as ~/.config/nv, so it doesn't touch an existing Neovim
--- config there) and run its installer when something changed.
local function setup_remote(t, nvim)
  local tar = vim.uv.os_uname().sysname == "Darwin" and "COPYFILE_DISABLE=1 tar --no-xattrs" or "tar"
  local unpack = [[d="${XDG_CONFIG_HOME:-$HOME/.config}/nv"; rm -rf "$d.new" && mkdir -p "$d.new" ]]
    .. [[&& tar -xf - -C "$d.new" && rm -rf "$d" && mv "$d.new" "$d"]]
  if not run(("%s --exclude=.git -cf - -C %s . | %s%s %s"):format(tar, q(root), mux(t), q(t.host), q("sh -c " .. q(unpack)))) then
    error("couldn't copy the config to " .. t.host)
  end

  local stamp = vim.fn.sha256(nvim_tag .. read_file(root .. "/install.sh") .. read_file(root .. "/lazy-lock.json")
    .. read_file(root .. "/lua/config/treesitter.lua") .. read_file(root .. "/lua/config/bootstrap.lua"))
  local install = [[f="${XDG_DATA_HOME:-$HOME/.local/share}/nv/install-stamp"
[ "$(cat "$f" 2>/dev/null)" = ]] .. stamp .. [[ ] && exit 0
echo "Setting up ]] .. t.host .. [[ (the first time, and after updates)..."
PATH=]] .. q(vim.fs.dirname(nvim)) .. [[:"$PATH" NVIM_APPNAME=nv sh "${XDG_CONFIG_HOME:-$HOME/.config}/nv/install.sh" --server \
  && echo ]] .. stamp .. [[ > "$f"]]
  if not run(mux(t) .. q(t.host) .. " " .. q("sh -c " .. q(install))) then
    say("  Setup on " .. t.host .. " had problems (see above); it retries next time. Continuing...")
  end
end

local function connect_remote(t, fresh)
  t.control = vim.fs.joinpath(state_dir, pid .. ".ssh")
  if not connected(t) then
    say("Connecting to " .. t.host .. "...")
    open_connection(t)
  end
  local nvim = remote_nvim(t)
  if fresh then
    setup_remote(t, nvim)
  end

  local res = remote(t, "sh -c " .. q("NVIM_APPNAME=nv " .. q(nvim)
    .. [[ -l "${XDG_CONFIG_HOME:-$HOME/.config}/nv/lua/nv/server.lua" ]] .. q(t.dir) .. " " .. q(t.host)))
  local dir, rsock = (res.stdout or ""):match("([^\t\n]+)\t([^\t\n]+)")
  if res.code ~= 0 or not rsock then
    error(vim.trim(res.stderr or "") ~= "" and vim.trim(res.stderr) or ("couldn't start Neovim on " .. t.host))
  end
  t.dir, t.rsock = dir, rsock
  t.sock = vim.fs.joinpath(state_dir, pid .. ".sock")

  if not server.alive(t.sock) then
    os.remove(t.sock)
    run(mux(t) .. "-O forward -L " .. q(t.sock .. ":" .. rsock) .. " " .. q(t.host) .. " 2>/dev/null")
  end
  if not vim.wait(5000, function() return server.alive(t.sock) end, 100) then
    error("couldn't reach Neovim on " .. t.host)
  end
  return t
end

local function disconnect(t)
  if t.control then
    run(mux(t) .. "-O exit " .. q(t.host) .. " 2>/dev/null")
    os.remove(t.control)
    os.remove(t.sock)
  end
end

---------------------------------------------------------------------------
-- Main loop
---------------------------------------------------------------------------
if arg[1] == "-h" or arg[1] == "--help" then
  say([[Usage: nv [folder]         open a session on this machine (default: current folder)
       nv HOST[:folder]    open a session on an SSH host (default: home folder)
       nv --list           list sessions you've opened
Sessions keep running when you close the terminal or lose the connection; run the
same command to get back. In Neovim, :Remote switches hosts; :qa ends the session.]])
  return
end

if arg[1] == "--list" then
  for _, r in ipairs(read_recent()) do
    local status = r.host and "" or (server.alive(server.socket(r.dir)) and "  (running)" or "")
    say(label(r) .. status)
  end
  return
end

local target = parse(arg[1])
local fresh, attempts = true, 0
while true do
  local ok, err = pcall(target.host and connect_remote or connect_local, target, fresh)
  if not ok then
    err = tostring(err):gsub("^.-:%d+: ", "")
    if fresh then
      fail(err)
    end
    -- Reconnecting after a dropped connection: keep trying.
    attempts = attempts + 1
    local wait = math.min(30, 2 ^ attempts)
    say(("Still can't reach %s (%s). Trying again in %ds; Ctrl+C to stop."):format(target.host, err, wait))
    sleep(wait)
  else
    fresh, attempts = false, 0
    remember(target)
    rpc(target.sock, "vim.g.nv = ...; vim.g.nv_next = nil", {
      host = target.host,
      dir = target.dir,
      hosts = ssh_hosts(),
      recent = read_recent(),
    })
    if target.file then
      rpc(target.sock, "vim.cmd.edit(vim.fn.fnameescape(...))", target.file)
      target.file = nil
    end
    run(q(vim.v.progpath) .. " --remote-ui --server " .. q(target.sock))

    -- The UI closed. Find out why.
    if target.host and not connected(target) then
      say("Lost the connection to " .. target.host .. ". Reconnecting... (Ctrl+C to stop)")
    else
      local info = rpc(target.sock, "local n = vim.g.nv_next; vim.g.nv_next = nil; return { next = n }")
      disconnect(target)
      if info and info.next then
        -- :Remote asked to switch to another session.
        target, fresh = info.next, true
        if not target.host then
          target = parse(target.dir)
        end
      else
        if info then
          say(("Session %s is still running. Get back to it with: nv %s"):format(label(target), label(target)))
        end
        return
      end
    end
  end
end
