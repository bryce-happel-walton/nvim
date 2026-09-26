-- Background Neovim servers, one per folder. They keep running when the UI
-- disconnects, so open files and terminals survive closed terminals and
-- dropped SSH connections.
--
-- Used by the nv launcher, and on SSH hosts as:
--   nvim -l server.lua <dir> [host]
-- which starts (or finds) the server for <dir> and prints "<dir>\t<socket>".
local M = {}

--- Is a server listening on this socket?
---@param sock string
function M.alive(sock)
  if not vim.uv.fs_stat(sock) then
    return false
  end
  local ok, chan = pcall(vim.fn.sockconnect, "pipe", sock, { rpc = true })
  if not ok or chan == 0 then
    return false
  end
  vim.fn.chanclose(chan)
  return true
end

---@param dir string absolute folder path
function M.socket(dir)
  return vim.fs.joinpath(vim.fn.stdpath("state"), "servers", vim.fn.sha256(dir):sub(1, 16) .. ".sock")
end

--- Start the server for `dir` unless it's already running. Returns its socket.
---@param dir string absolute folder path
---@param env? table<string, string> extra environment for the server
function M.ensure(dir, env)
  local sock = M.socket(dir)
  if M.alive(sock) then
    return sock
  end
  vim.fn.mkdir(vim.fs.dirname(sock), "p")
  os.remove(sock) -- left over after a reboot or crash

  local server_env = vim.fn.environ()
  server_env.NVIM, server_env.NVIM_LISTEN_ADDRESS = nil, nil -- don't inherit the launcher's address
  for k, v in pairs(env or {}) do
    server_env[k] = v
  end
  vim.system({ vim.v.progpath, "--headless", "--listen", sock }, {
    cwd = dir,
    env = server_env,
    clear_env = true,
    detach = true, -- own session: survives the launcher, closed terminals and SSH logouts
    stdout = false,
    stderr = false,
  })
  if not vim.wait(10000, function() return M.alive(sock) end, 50) then
    error("Neovim didn't start in " .. dir)
  end
  return sock
end

-- Run as a script on an SSH host.
if arg and arg[0] and vim.fs.basename(arg[0]) == "server.lua" then
  local dir = vim.uv.fs_realpath(vim.fs.normalize(arg[1] and arg[1] ~= "" and arg[1] or "~"))
  if not dir or vim.fn.isdirectory(dir) == 0 then
    io.stderr:write("No such folder: " .. tostring(arg[1]) .. "\n")
    os.exit(2)
  end
  -- Put this Neovim first on PATH, so `nvim` in the session's terminals is the same version.
  local path = vim.fs.dirname(vim.v.progpath) .. ":" .. (vim.env.PATH or "")
  local ok, sock = pcall(M.ensure, dir, { NV_HOST = arg[2], PATH = path })
  if not ok then
    io.stderr:write(tostring(sock) .. "\n")
    os.exit(1)
  end
  io.stdout:write(dir .. "\t" .. sock .. "\n")
  return
end

return M
