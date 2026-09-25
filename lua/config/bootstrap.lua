-- Run by install.sh in headless Neovim: installs plugins, tree-sitter parsers and
-- plugin binaries up front, so the first real start is instant. Exits when done.
local M = {}

local function say(msg)
  io.stdout:write(msg .. "\n")
  io.stdout:flush()
end

function M.run()
  local problems = {}

  -- Missing plugins were already installed while Neovim started up.
  local lazy = require("lazy")
  lazy.install({ wait = true, show = false })
  lazy.restore({ wait = true, show = false }) -- pin to lazy-lock.json
  local not_installed = vim.tbl_filter(function(p) return not p._.installed end, require("lazy.core.config").plugins)
  for _, p in pairs(not_installed) do
    problems[#problems + 1] = "plugin " .. p.name .. " failed to install"
  end
  lazy.load({ plugins = { "nvim-treesitter", "blink.cmp", "codediff.nvim" } })

  -- Loading blink.cmp starts its binary download in the background. Note when it
  -- settles: "rust" on success, "lua" when it falls back after a failed download.
  local fuzzy = require("blink.cmp.fuzzy")
  local fuzzy_impl = fuzzy.implementation_type == "rust" and "rust" or nil
  local set_implementation = fuzzy.set_implementation
  fuzzy.set_implementation = function(impl)
    fuzzy_impl = impl
    return set_implementation(impl)
  end

  local ts = require("config.treesitter")
  if #ts.missing() > 0 then
    say("  Building tree-sitter parsers (about a minute)...")
    local task = ts.install()
    if task then
      task:wait(20 * 60 * 1000)
    end
  end
  local missing = ts.missing()
  if #missing > 0 then
    problems[#problems + 1] = "tree-sitter parsers failed: " .. table.concat(missing, ", ")
  end

  vim.wait(5 * 60 * 1000, function() return fuzzy_impl ~= nil end, 200)
  if fuzzy_impl ~= "rust" then
    problems[#problems + 1] = "completion engine download failed (completion still works, just slower)"
  end

  local ok, installed = pcall(require("codediff.core.installer.libvscode_diff").install, { silent = true })
  if not (ok and installed) then
    problems[#problems + 1] = "diff viewer library download failed (it retries when you first open it)"
  end

  if #problems > 0 then
    for _, p in ipairs(problems) do
      say("  ! " .. p)
    end
    vim.cmd("cquit 1")
  end
  vim.cmd("qall!")
end

return M
