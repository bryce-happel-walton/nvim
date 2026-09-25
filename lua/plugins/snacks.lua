-- Quick open pickers, file explorer, terminal panel.
return {
  "folke/snacks.nvim",
  lazy = false,
  priority = 900,
  opts = {
    bufdelete = { enabled = true },
    explorer = { enabled = true, replace_netrw = true },
    notifier = { enabled = true },
    input = { enabled = true },
    picker = {
      enabled = true,
      ui_select = true,
      sources = {
        explorer = {
          hidden = true,
          win = {
            list = {
              -- Let the global VS Code shortcuts work while the explorer is focused.
              keys = {
                ["<c-p>"] = false,
                ["<c-t>"] = false,
                ["<c-j>"] = false,
                ["<c-e>"] = false,
              },
            },
          },
        },
      },
    },
    terminal = {
      win = { position = "bottom", height = 0.3 },
    },
  },
}
