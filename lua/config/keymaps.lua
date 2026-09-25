-- VS Code style keybindings. Every <C-x> shortcut also gets a <D-x> (Cmd) twin.
-- Shortcuts with Shift, Tab or digits need a terminal that supports the
-- kitty keyboard protocol (kitty, WezTerm, Ghostty, foot, Alacritty, iTerm2).
local util = require("config.util")
local cmap = util.cmap
local map = vim.keymap.set

-- Leave insert mode first, so shortcuts also work while typing.
local function anywhere(fn)
  return function()
    if vim.fn.mode() == "i" then
      vim.cmd.stopinsert()
      vim.schedule(fn)
    else
      fn()
    end
  end
end

-- Quick open / go to symbol / command palette / search
cmap({ "n", "i" }, "p", anywhere(function() Snacks.picker.files({ hidden = true }) end), "Go to file")
cmap({ "n", "i" }, "S-o", anywhere(function() Snacks.picker.lsp_symbols() end), "Go to symbol in editor")
cmap({ "n", "i" }, "t", anywhere(function() Snacks.picker.lsp_workspace_symbols() end), "Go to symbol in workspace")
cmap({ "n", "i" }, "S-p", anywhere(function() Snacks.picker.commands() end), "Command palette")
cmap({ "n", "i" }, "S-f", anywhere(function() Snacks.picker.grep({ hidden = true }) end), "Search in files")

-- Explorer and panel (terminal)
cmap({ "n", "i" }, "e", anywhere(function() Snacks.explorer() end), "Toggle explorer")
cmap({ "n", "i", "t" }, "j", anywhere(function() Snacks.terminal() end), "Toggle panel (terminal)")
cmap({ "n", "i", "t" }, "`", anywhere(function() Snacks.terminal() end), "Toggle terminal")

-- Problems
cmap({ "n", "i" }, "S-m", anywhere(function() Snacks.picker.diagnostics() end), "Problems")
map("n", "<F8>", function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "Next problem" })
map("n", "<S-F8>", function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = "Previous problem" })

-- Save
cmap({ "n", "i", "x" }, "s", "<Cmd>write<CR>", "Save")

-- Undo / redo (u and <C-r> still work too)
cmap("n", "z", "u", "Undo")
cmap("i", "z", "<C-o>u", "Undo")
cmap("x", "z", "<Esc>u", "Undo")
cmap("n", "S-z", "<C-r>", "Redo")
cmap("i", "S-z", "<C-o><C-r>", "Redo")
map("n", "<C-y>", "<C-r>", { desc = "Redo" })
map("i", "<C-y>", "<C-o><C-r>", { desc = "Redo" })

-- Editor tabs
local function tabs(lhs, cmd, desc)
  for _, key in ipairs(lhs) do
    map({ "n", "i" }, key, "<Cmd>" .. cmd .. "<CR>", { desc = desc })
  end
end
tabs({ "<C-Tab>", "<C-PageDown>", "<D-}>", "<D-A-Right>" }, "BufferLineCycleNext", "Next tab")
tabs({ "<C-S-Tab>", "<C-PageUp>", "<D-{>", "<D-A-Left>" }, "BufferLineCyclePrev", "Previous tab")
tabs({ "<C-S-PageDown>" }, "BufferLineMoveNext", "Move tab right")
tabs({ "<C-S-PageUp>" }, "BufferLineMovePrev", "Move tab left")
for i = 1, 9 do
  tabs({ "<A-" .. i .. ">" }, "BufferLineGoToBuffer " .. i, "Go to tab " .. i)
end
tabs({ "<A-0>" }, "BufferLineGoToBuffer -1", "Go to last tab")
cmap("n", "w", util.close_editor, "Close tab / split")

-- Split view (editor groups)
cmap("n", "\\", "<Cmd>vsplit<CR>", "Split editor right")
for i = 1, 9 do
  cmap({ "n", "i" }, tostring(i), anywhere(function() util.focus_group(i) end), "Focus editor group " .. i)
end
for _, mod in ipairs({ "C", "D" }) do
  local k = "<" .. mod .. "-k>"
  map("n", k .. "<" .. mod .. "-\\>", "<Cmd>split<CR>", { desc = "Split editor down" })
  map("n", k .. "<" .. mod .. "-Left>", "<Cmd>wincmd h<CR>", { desc = "Focus left group" })
  map("n", k .. "<" .. mod .. "-Right>", "<Cmd>wincmd l<CR>", { desc = "Focus right group" })
  map("n", k .. "<" .. mod .. "-Up>", "<Cmd>wincmd k<CR>", { desc = "Focus group above" })
  map("n", k .. "<" .. mod .. "-Down>", "<Cmd>wincmd j<CR>", { desc = "Focus group below" })
end
