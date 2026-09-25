-- Open a CodeDiff view of one commit (against its parent) or a range.
local function diff_commit(commit)
  local parent = commit.parents[1] or "4b825dc642cb6eb9a060e54bf8d69288fbee4904" -- empty tree for root commits
  vim.cmd(("CodeDiff %s %s"):format(parent, commit.hash))
end

return {
  -- Gutter change markers, line blame, hunk actions
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      current_line_blame = true, -- shown in the status bar, not inline
      current_line_blame_opts = { delay = 300, virt_text = false },
      on_attach = function(buf)
        local gs = require("gitsigns")
        local function map(modes, lhs, rhs, desc)
          vim.keymap.set(modes, lhs, rhs, { buffer = buf, desc = desc })
        end
        local function next_change() gs.nav_hunk("next") end
        local function prev_change() gs.nav_hunk("prev") end
        map("n", "]c", next_change, "Next change")
        map("n", "[c", prev_change, "Previous change")
        map({ "n", "i" }, "<A-F5>", next_change, "Next change")
        map({ "n", "i" }, "<S-A-F5>", prev_change, "Previous change")
        map("n", "<leader>gp", gs.preview_hunk_inline, "Peek change")
        map({ "n", "x" }, "<leader>gs", gs.stage_hunk, "Stage change")
        map({ "n", "x" }, "<leader>gr", gs.reset_hunk, "Revert change")
        map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Blame line")
        map("n", "<leader>gB", gs.blame, "Blame file")
      end,
    },
  },

  -- VS Code style Source Control view and side-by-side diffs
  {
    "esmuellert/codediff.nvim",
    cmd = "CodeDiff",
    keys = {
      { "<C-S-g>", "<Cmd>CodeDiff<CR>", desc = "Source control" },
      { "<D-S-g>", "<Cmd>CodeDiff<CR>", desc = "Source control" },
      { "<leader>gd", "<Cmd>CodeDiff<CR>", desc = "Source control (changes)" },
      { "<leader>gh", "<Cmd>CodeDiff history %<CR>", desc = "File history" },
      { "<leader>gH", "<Cmd>CodeDiff history<CR>", desc = "Repository history" },
    },
    opts = {},
  },

  -- Git graph (like the VS Code "Git Graph" extension)
  {
    "isakbm/gitgraph.nvim",
    dependencies = { "esmuellert/codediff.nvim" },
    keys = {
      {
        "<leader>gl",
        function()
          vim.cmd("tab split") -- open in its own tab page; `q` closes it
          require("gitgraph").draw({}, { all = true, max_count = 5000 })
          vim.keymap.set("n", "q", "<Cmd>tabclose<CR>", { buffer = true, desc = "Close git graph" })
        end,
        desc = "Git graph",
      },
    },
    opts = {
      symbols = {
        commit = "●",
        commit_end = "●",
        merge_commit = "◉",
        merge_commit_end = "◉",
      },
      format = {
        timestamp = "%Y-%m-%d %H:%M",
        fields = { "hash", "timestamp", "author", "branch_name", "tag" },
      },
      hooks = {
        -- <CR> on a commit shows its diff; <CR> on a visual range diffs the range.
        on_select_commit = diff_commit,
        on_select_range_commit = function(from, to)
          local base = from.parents[1] or "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
          vim.cmd(("CodeDiff %s %s"):format(base, to.hash))
        end,
      },
    },
  },

  -- Commit, push, pull, branches, stash
  {
    "NeogitOrg/neogit",
    cmd = "Neogit",
    dependencies = { "nvim-lua/plenary.nvim", "esmuellert/codediff.nvim", "folke/snacks.nvim" },
    keys = {
      { "<leader>gg", "<Cmd>Neogit<CR>", desc = "Git (commit, push, pull, branches)" },
      { "<leader>gc", "<Cmd>Neogit commit<CR>", desc = "Commit" },
    },
    opts = {
      diff_viewer = "codediff",
      integrations = { codediff = true, snacks = true },
    },
  },
}
