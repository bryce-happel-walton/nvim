local opt = vim.opt

opt.number = true
opt.relativenumber = false
opt.signcolumn = "yes"
opt.cursorline = true
opt.termguicolors = true
opt.mouse = "a"
opt.mousemodel = "extend" -- right-click extends selection instead of popup menu
opt.showmode = true -- the status bar has no mode section, so show it below
opt.laststatus = 3 -- one global statusline, like VS Code's status bar
opt.showtabline = 2 -- always show the tab bar
opt.scrolloff = 4
opt.sidescrolloff = 8
opt.wrap = false

opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.smartindent = true

opt.ignorecase = true
opt.smartcase = true

opt.splitright = true
opt.splitbelow = true

opt.undofile = true -- persistent undo across sessions
opt.swapfile = false
opt.updatetime = 250
opt.timeoutlen = 500
opt.confirm = true -- ask to save instead of failing on :q with changes

opt.fillchars = { eob = " ", diff = "╱" }
