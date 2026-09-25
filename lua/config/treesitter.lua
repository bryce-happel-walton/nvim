-- Tree-sitter syntax highlighting. Parsers are compiled with the tree-sitter CLI;
-- install.sh installs the CLI and these parsers.
local M = {}

M.languages = {
  "rust", "toml", "lua", "json", "yaml", "markdown", "markdown_inline",
  "bash", "vim", "vimdoc", "query", "regex", "diff",
  "gitcommit", "git_rebase", "gitignore", "git_config",
}

---@return string[]
function M.missing()
  local installed = require("nvim-treesitter").get_installed()
  return vim.tbl_filter(function(lang)
    return not vim.list_contains(installed, lang)
  end, M.languages)
end

--- Install missing parsers in the background.
--- Returns the install task (call `:wait()` to block), or nil if there is nothing to do.
function M.install()
  local langs = M.missing()
  if #langs == 0 then
    return nil
  end
  if vim.fn.executable("tree-sitter") == 0 then
    vim.notify("tree-sitter CLI not found. Run install.sh from your Neovim config folder.", vim.log.levels.WARN)
    return nil
  end
  return require("nvim-treesitter").install(langs, { summary = true })
end

function M.setup()
  -- Only auto-install in interactive sessions; install.sh installs them itself.
  vim.api.nvim_create_autocmd("UIEnter", { once = true, callback = function() M.install() end })

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("treesitter_highlight", { clear = true }),
    callback = function(ev)
      pcall(vim.treesitter.start, ev.buf)
    end,
  })
end

return M
