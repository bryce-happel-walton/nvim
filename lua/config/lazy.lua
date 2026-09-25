-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
    }, true, {})
    if #vim.api.nvim_list_uis() > 0 then -- never wait for a key in headless runs (install.sh)
      vim.api.nvim_echo({ { "\nPress any key to exit..." } }, true, {})
      vim.fn.getchar()
    end
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = { { import = "plugins" } },
  install = { colorscheme = { "vscode" } },
  checker = { enabled = false },
  change_detection = { notify = false },
  headless = { process = false, log = false, task = false }, -- keep install.sh quiet; it reports failures itself
})
