return {
  -- VS Code Dark+ theme
  {
    "Mofiqul/vscode.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("vscode").setup({})
      vim.cmd.colorscheme("vscode")
    end,
  },

  { "nvim-tree/nvim-web-devicons", lazy = true },

  -- Editor tabs
  {
    "akinsho/bufferline.nvim",
    version = "*",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        close_command = function(buf) Snacks.bufdelete(buf) end,
        right_mouse_command = function(buf) Snacks.bufdelete(buf) end,
        diagnostics = "nvim_lsp",
        always_show_bufferline = true,
        show_buffer_close_icons = true,
        separator_style = "thin",
        -- Keep tabs aligned to the right of the explorer sidebar.
        offsets = {
          { filetype = "snacks_layout_box", text = "EXPLORER", text_align = "left", separator = true },
        },
      },
    },
  },

  -- Status bar: | SSH host | branch | sync | blame | problems | todos | position | language |
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local sl = require("config.statusline")
      sl.setup()
      require("lualine").setup({
        options = {
          theme = "vscode",
          globalstatus = true,
          component_separators = { left = "│", right = "│" },
          section_separators = "",
        },
        sections = {
          lualine_a = {
            {
              function() return "󰣀 SSH: " .. require("config.remote").label() end,
              cond = function() return require("config.remote").host ~= nil end,
              on_click = function() vim.cmd("Remote") end,
            },
            "branch",
          },
          lualine_b = { { sl.sync_status, on_click = sl.sync_click } },
          lualine_c = { sl.blame },
          lualine_x = {
            {
              "diagnostics",
              sources = { sl.problems },
              sections = { "error", "warn" },
              always_visible = true,
              on_click = function() Snacks.picker.diagnostics() end,
            },
            { sl.todos, on_click = sl.todos_click },
          },
          lualine_y = { sl.position },
          lualine_z = { { "filetype", fmt = sl.language, cond = function() return vim.bo.buftype == "" end } },
        },
      })
    end,
  },
}
