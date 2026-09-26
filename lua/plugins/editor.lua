return {
  -- VS Code style multi-cursor
  {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    event = "VeryLazy",
    config = function()
      local mc = require("multicursor-nvim")
      mc.setup()

      local map = vim.keymap.set
      local cmap = require("config.util").cmap

      -- Multicursor actions leave Visual mode, where typing runs Vim commands.
      -- Switch every cursor to Select mode so typing replaces the selections.
      local function in_select(action)
        return function()
          action()
          if vim.fn.mode() == "v" then
            vim.api.nvim_input("<C-g>") -- as if typed, so every cursor switches
          end
        end
      end

      -- Select the word under the cursor in Select mode, so typing replaces it.
      local function select_word()
        vim.api.nvim_feedkeys(vim.keycode("viw<C-g>"), "nx!", false)
      end

      local add_next = in_select(function() mc.matchAddCursor(1) end)
      local skip_next = in_select(function() mc.matchSkipCursor(1) end)

      -- Ctrl+D: first press selects the word, next presses add the next occurrence.
      cmap({ "n", "v" }, "d", function()
        if vim.fn.mode() == "n" and not mc.hasCursors() then
          select_word()
        else
          add_next()
        end
      end, "Add selection to next find match")

      -- Ctrl+K Ctrl+D: skip this occurrence and move to the next one.
      map("v", "<C-k><C-d>", skip_next, { desc = "Skip to next find match" })
      map("v", "<D-k><D-d>", skip_next, { desc = "Skip to next find match" })

      -- Ctrl+Shift+L: select every occurrence.
      cmap({ "n", "v" }, "S-l", function()
        if vim.fn.mode() == "n" and not mc.hasCursors() then
          select_word()
          vim.api.nvim_input("<C-S-l>") -- add the cursors once the selection has settled
          return
        end
        local text = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = "v" })
        local escaped = vim.tbl_map(function(l) return vim.fn.escape(l, "\\") end, text)
        local pattern = "\\C\\V" .. table.concat(escaped, "\\n")
        local total = vim.fn.searchcount({ pattern = pattern, maxcount = 0 }).total or 0
        in_select(function()
          for _ = mc.numCursors() + 1, total do
            mc.matchAddCursor(1)
          end
        end)()
      end, "Select all occurrences")

      -- Add cursor above/below (Ctrl+Alt, Shift+Alt and Cmd+Alt + Up/Down).
      for _, mod in ipairs({ "C-A", "S-A", "D-A" }) do
        map({ "n", "v" }, "<" .. mod .. "-Up>", function() mc.lineAddCursor(-1) end, { desc = "Add cursor above" })
        map({ "n", "v" }, "<" .. mod .. "-Down>", function() mc.lineAddCursor(1) end, { desc = "Add cursor below" })
      end

      -- Alt+Click adds/removes a cursor.
      map("n", "<A-LeftMouse>", mc.handleMouse)
      map("n", "<A-LeftDrag>", mc.handleMouseDrag)
      map("n", "<A-LeftRelease>", mc.handleMouseRelease)

      -- Only active while there are multiple cursors.
      mc.addKeymapLayer(function(layer)
        layer("n", "<Esc>", function()
          if not mc.cursorsEnabled() then
            mc.enableCursors()
          else
            mc.clearCursors()
          end
        end)
      end)
    end,
  },
}
