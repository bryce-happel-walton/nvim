return {
  -- Syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("config.treesitter").setup()
    end,
  },

  -- Completion (IntelliSense)
  {
    "saghen/blink.cmp",
    version = "1.*",
    opts = {
      keymap = {
        preset = "enter", -- Enter accepts, Ctrl+Space opens
        ["<Tab>"] = { "accept", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "snippet_backward", "fallback" },
      },
      completion = { documentation = { auto_show = true } },
      signature = { enabled = true },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
  },

  -- rust-analyzer
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "saghen/blink.cmp" }, -- sets completion capabilities for all servers
    config = function()
      vim.diagnostic.config({
        virtual_text = { current_line = true },
        severity_sort = true,
        float = { border = "rounded" },
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp_keymaps", { clear = true }),
        callback = function(ev)
          local function map(modes, lhs, rhs, desc)
            vim.keymap.set(modes, lhs, rhs, { buffer = ev.buf, desc = desc })
          end
          map("n", "<F12>", function() Snacks.picker.lsp_definitions() end, "Go to definition")
          map("n", "<C-LeftMouse>", "<LeftMouse><Cmd>lua Snacks.picker.lsp_definitions()<CR>", "Go to definition")
          map("n", "<D-LeftMouse>", "<LeftMouse><Cmd>lua Snacks.picker.lsp_definitions()<CR>", "Go to definition")
          map("n", "<C-F12>", function() Snacks.picker.lsp_implementations() end, "Go to implementation")
          map("n", "<S-F12>", function() Snacks.picker.lsp_references() end, "Go to references")
          map("n", "<F2>", vim.lsp.buf.rename, "Rename symbol")
          map({ "n", "i" }, "<C-.>", vim.lsp.buf.hover, "Show hover")
          map({ "n", "i" }, "<D-.>", vim.lsp.buf.hover, "Show hover")
          map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "Quick fix / code action")
        end,
      })

      vim.lsp.enable("rust_analyzer")
    end,
  },

  -- Formatting (format on save + Shift+Alt+F)
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    keys = {
      { "<A-F>", function() require("conform").format() end, mode = { "n", "x", "i" }, desc = "Format document" },
      { "<S-A-f>", function() require("conform").format() end, mode = { "n", "x", "i" }, desc = "Format document" },
    },
    opts = {
      formatters_by_ft = {
        rust = { "rustfmt" },
      },
      default_format_opts = { lsp_format = "fallback" },
      format_on_save = { timeout_ms = 1000 },
    },
  },
}
