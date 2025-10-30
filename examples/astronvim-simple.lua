-- Simplified AstroNvim configuration for worktree.nvim
-- Place this file in: ~/.config/nvim/lua/plugins/worktree.lua
--
-- This is a minimal version that includes all essential features

return {
  {
    "yourusername/worktree.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "nvim-telescope/telescope-ui-select.nvim",
    },
    config = function()
      -- Setup worktree plugin
      require("worktree").setup({
        keymaps = {
          switch = "<leader>gws",
          create = "<leader>gwc",
        },
        auto_remap_buffers = true,
        notify = true,
        enable_statusline = true,
      })

      -- Setup telescope ui-select for better UI
      require("telescope").load_extension("ui-select")
    end,
    keys = {
      { "<leader>gws", function() require("worktree").switch_worktree() end, desc = "Switch worktree" },
      { "<leader>gwc", function() require("worktree").create_worktree() end, desc = "Create worktree" },
      { "<leader>gwl", "<cmd>WorktreeList<cr>", desc = "List worktrees" },
    },
  },
}
