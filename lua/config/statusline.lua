-- Status bar pieces:
-- | branch | sync (incoming/outgoing) | blame | errors/warnings | todos | Ln/Col/selection | language |
local M = {}

local function refresh()
  if package.loaded["lualine"] then
    require("lualine").refresh()
  end
end

-- Background git commands must never prompt (a password prompt would draw over the editor).
local quiet_git_env = { GIT_TERMINAL_PROMPT = "0", SSH_ASKPASS = "false", SSH_ASKPASS_REQUIRE = "force" }

local function git(args, cb)
  local ok = pcall(vim.system, vim.list_extend({ "git" }, args), { text = true, env = quiet_git_env }, function(res)
    vim.schedule(function() cb(res) end)
  end)
  if not ok then
    cb({ code = 1, stdout = "", stderr = "" })
  end
end

---------------------------------------------------------------------------
-- Sync: commits to pull (incoming) and push (outgoing)
---------------------------------------------------------------------------
local sync = { repo = false, upstream = false, ahead = 0, behind = 0 }

function M.refresh_sync()
  git({ "rev-list", "--left-right", "--count", "HEAD...@{upstream}" }, function(res)
    if res.code == 0 then
      local ahead, behind = res.stdout:match("(%d+)%s+(%d+)")
      sync.repo, sync.upstream = true, true
      sync.ahead, sync.behind = tonumber(ahead) or 0, tonumber(behind) or 0
      refresh()
    else
      git({ "rev-parse", "--git-dir" }, function(r)
        sync.repo, sync.upstream, sync.ahead, sync.behind = r.code == 0, false, 0, 0
        refresh()
      end)
    end
  end)
end

-- Fetch in the background so incoming commits show up (like VS Code's git.autofetch).
function M.fetch()
  if sync.upstream then
    git({ "fetch", "--quiet" }, M.refresh_sync)
  end
end

function M.sync_status()
  if not sync.repo then
    return ""
  elseif not sync.upstream then
    return "󰅧 Publish"
  end
  return ("󰓦 %d↓ %d↑"):format(sync.behind, sync.ahead)
end

-- Click: publish the branch, or pull then push. Runs in a terminal so
-- credential prompts work; it closes by itself on success.
function M.sync_click()
  local cmd = sync.upstream and "git pull && git push" or "git push -u origin HEAD"
  Snacks.terminal(cmd, { win = { position = "float", height = 0.4, width = 0.6 } })
end

---------------------------------------------------------------------------
-- TODO comments in the workspace (respects .gitignore)
---------------------------------------------------------------------------
M.todo_pattern = [[\b(TODO|FIXME|HACK|XXX|BUG)\b]]
local todos = { count = nil, running = false }

function M.refresh_todos()
  if todos.running or vim.fn.executable("rg") == 0 then
    return
  end
  todos.running = true
  vim.system({ "rg", "--count-matches", "--with-filename", "--no-messages", "-e", M.todo_pattern }, { text = true }, function(res)
    local n = 0
    for c in (res.stdout or ""):gmatch(":(%d+)\n") do
      n = n + tonumber(c)
    end
    vim.schedule(function()
      todos.count, todos.running = n, false
      refresh()
    end)
  end)
end

function M.todos()
  return todos.count and ("󰄬 %d"):format(todos.count) or ""
end

function M.todos_click()
  Snacks.picker.grep({ search = M.todo_pattern, regex = true, live = false })
end

---------------------------------------------------------------------------
-- Blame of the current line (from gitsigns)
---------------------------------------------------------------------------
function M.blame()
  local text = vim.trim(vim.b.gitsigns_blame_line or "")
  if vim.fn.strchars(text) > 60 then
    text = vim.fn.strcharpart(text, 0, 59) .. "…"
  end
  return text
end

---------------------------------------------------------------------------
-- Errors / warnings across the workspace
---------------------------------------------------------------------------
function M.problems()
  local sev = vim.diagnostic.severity
  return {
    error = #vim.diagnostic.get(nil, { severity = sev.ERROR }),
    warn = #vim.diagnostic.get(nil, { severity = sev.WARN }),
  }
end

---------------------------------------------------------------------------
-- Ln / Col / selection
---------------------------------------------------------------------------
function M.position()
  local text = ("Ln %d, Col %d"):format(vim.fn.line("."), vim.fn.virtcol("."))
  local mc = package.loaded["multicursor-nvim"]
  if mc and mc.numCursors() > 1 then
    return text .. (" (%d selections)"):format(mc.numCursors())
  end
  if vim.fn.mode():find("^[vVsS\22\19]") then
    text = text .. (" (%d selected)"):format(vim.fn.wordcount().visual_chars)
  end
  return text
end

---------------------------------------------------------------------------
-- Language name
---------------------------------------------------------------------------
local lang_names = {
  text = "Plain Text", json = "JSON", jsonc = "JSON with Comments", toml = "TOML", yaml = "YAML", sh = "Shell Script",
  bash = "Shell Script", javascript = "JavaScript", typescript = "TypeScript", html = "HTML", css = "CSS",
}

function M.language(ft)
  if ft == "" then
    return "Plain Text"
  end
  return lang_names[ft] or (ft:sub(1, 1):upper() .. ft:sub(2))
end

---------------------------------------------------------------------------
function M.setup()
  local group = vim.api.nvim_create_augroup("statusline_git", { clear = true })
  vim.api.nvim_create_autocmd({ "FocusGained", "DirChanged", "BufWritePost", "TermClose" }, {
    group = group,
    callback = function()
      M.refresh_sync()
      M.refresh_todos()
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = { "NeogitPushComplete", "NeogitPullComplete", "NeogitFetchComplete", "NeogitCommitComplete" },
    callback = M.refresh_sync,
  })
  M.refresh_sync()
  M.refresh_todos()
  vim.defer_fn(M.fetch, 3000)
  vim.fn.timer_start(3 * 60 * 1000, function() M.fetch() end, { ["repeat"] = -1 })
end

return M
