-- Remote-SSH, VS Code style. Sessions are opened with the `nv` command (bin/nv), which
-- sets vim.g.nv when it attaches: { host?, dir, hosts = ssh hosts, recent = sessions }.
local M = {}

--- The SSH host this session runs on, if any.
M.host = vim.env.NV_HOST ~= "" and vim.env.NV_HOST or nil

--- Status bar label: the host name you connected with.
function M.label()
  local nv = vim.g.nv
  return type(nv) == "table" and nv.host or M.host
end

--- Ask nv to switch this window to another session. The current one keeps running.
local function switch(target)
  vim.g.nv_next = target
  vim.cmd("detach")
end

local function ask_folder(host, default)
  vim.ui.input({ prompt = "Folder on " .. host .. ": ", default = default or "~" }, function(dir)
    if dir and dir ~= "" then
      switch({ host = host, dir = dir })
    end
  end)
end

--- :Remote: connect to an SSH host, go back to this machine, or reopen a session.
function M.pick()
  local nv = vim.g.nv
  if type(nv) ~= "table" then
    vim.notify("Start Neovim with the `nv` command to use SSH hosts.", vim.log.levels.WARN)
    return
  end

  local items, last_dir, last_local = {}, {}, nil
  for _, r in ipairs(nv.recent or {}) do
    if not (r.host == nv.host and r.dir == nv.dir) then
      items[#items + 1] = { text = "Open " .. (r.host and (r.host .. ":") or "") .. r.dir, target = r }
    end
    if r.host then
      last_dir[r.host] = last_dir[r.host] or r.dir
    else
      last_local = last_local or r.dir
    end
  end
  for _, host in ipairs(nv.hosts or {}) do
    items[#items + 1] = { text = "Connect to " .. host, host = host }
  end
  items[#items + 1] = { text = "Connect to another host (user@host)...", host = false }
  if M.host then
    items[#items + 1] = { text = "Open a folder on this machine...", ["local"] = true }
  end

  vim.ui.select(items, { prompt = "Remote", format_item = function(i) return i.text end }, function(item)
    if not item then
      return
    elseif item.target then
      switch(item.target)
    elseif item.host then
      ask_folder(item.host, last_dir[item.host])
    elseif item.host == false then
      vim.ui.input({ prompt = "SSH host: " }, function(host)
        if host and host ~= "" then
          ask_folder(host, last_dir[host])
        end
      end)
    else
      -- nv resolves the path on this machine (this code runs on the host).
      vim.ui.input({ prompt = "Folder on this machine: ", default = last_local or "~" }, function(dir)
        if dir and dir ~= "" then
          switch({ dir = dir })
        end
      end)
    end
  end)
end

function M.setup()
  if M.host then
    -- Copy to your local clipboard through the connection (OSC 52). Pasting from the
    -- clipboard works with your terminal's paste; "+p pastes Neovim's last yank.
    local osc52 = require("vim.ui.clipboard.osc52")
    local function paste()
      return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
    end
    vim.g.clipboard = {
      name = "OSC 52",
      copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
      paste = { ["+"] = paste, ["*"] = paste },
    }
  end
  vim.api.nvim_create_user_command("Remote", M.pick, { desc = "Connect to an SSH host or switch sessions" })
end

return M
