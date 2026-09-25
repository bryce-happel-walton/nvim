local M = {}

--- Map a VS Code style shortcut for both Ctrl (Linux/Windows) and Cmd (macOS).
--- `key` is the part after the modifier, e.g. "p" -> <C-p> and <D-p>,
--- "S-o" -> <C-S-o> and <D-S-o>.
---@param modes string|string[]
---@param key string
---@param rhs string|function
---@param desc string
---@param opts? vim.keymap.set.Opts
function M.cmap(modes, key, rhs, desc, opts)
  opts = vim.tbl_extend("force", opts or {}, { desc = desc })
  for _, mod in ipairs({ "C", "D" }) do
    vim.keymap.set(modes, "<" .. mod .. "-" .. key .. ">", rhs, opts)
  end
end

--- Windows that hold a real file buffer (skips explorer, terminal, floats...).
--- Ordered left-to-right / top-to-bottom, like VS Code editor groups.
---@return integer[]
function M.editor_wins()
  local wins = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_win_get_config(win).relative == "" and vim.bo[buf].buftype == "" then
      wins[#wins + 1] = win
    end
  end
  table.sort(wins, function(a, b)
    local pa, pb = vim.api.nvim_win_get_position(a), vim.api.nvim_win_get_position(b)
    if pa[2] ~= pb[2] then
      return pa[2] < pb[2]
    end
    return pa[1] < pb[1]
  end)
  return wins
end

--- Focus editor group `n`; like VS Code, a missing group is created to the right.
---@param n integer
function M.focus_group(n)
  local wins = M.editor_wins()
  if wins[n] then
    vim.api.nvim_set_current_win(wins[n])
  elseif #wins > 0 then
    vim.api.nvim_set_current_win(wins[#wins])
    vim.cmd("vsplit")
  end
end

--- Ctrl+W: close the split if there is more than one, otherwise close the tab (buffer).
function M.close_editor()
  local cur = vim.api.nvim_get_current_win()
  local wins = M.editor_wins()
  if not vim.tbl_contains(wins, cur) then
    return -- ignore in explorer/terminal/special windows
  end
  if #wins > 1 then
    vim.cmd("close")
  else
    Snacks.bufdelete()
  end
end

--- Document symbols from LSP when available, otherwise from treesitter.
function M.document_symbols()
  local has_lsp = #vim.lsp.get_clients({ bufnr = 0, method = "textDocument/documentSymbol" }) > 0
  if has_lsp then
    Snacks.picker.lsp_symbols()
  else
    Snacks.picker.treesitter()
  end
end

return M
