-- Simple AstroNvim configuration for worktree.nvim
-- Place this file in: ~/.config/nvim/lua/plugins/worktree.lua

return {
  {
    "yourusername/worktree.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-telescope/telescope-ui-select.nvim",
    },
    config = function()
      require("worktree").setup({
        keymaps = {
          switch = "<leader>gws",
          create = "<leader>gwc",
        },
        auto_remap_buffers = true,
        notify = true,
        enable_statusline = true,
        -- Try to override AstroNvim's git branch click to use worktree switcher
        override_astronvim_click = true,
      })
    end,
    keys = {
      {
        "<leader>gws",
        function() require("worktree").switch_worktree() end,
        desc = "Switch worktree",
      },
      {
        "<leader>gwc",
        function() require("worktree").create_worktree() end,
        desc = "Create worktree",
      },
    },
  },

  -- Setup telescope ui-select for better worktree picker
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-telescope/telescope-ui-select.nvim",
    },
    opts = function(_, opts)
      local telescope_config = opts or {}
      telescope_config.extensions = telescope_config.extensions or {}
      telescope_config.extensions["ui-select"] = {
        require("telescope.themes").get_dropdown({
          previewer = false,
          initial_mode = "normal",
        }),
      }
      return telescope_config
    end,
    config = function(_, opts)
      local telescope = require("telescope")
      telescope.setup(opts)
      telescope.load_extension("ui-select")
    end,
  },

  -- Add which-key descriptions
  {
    "folke/which-key.nvim",
    optional = true,
    opts = function(_, opts)
      if not opts.spec then opts.spec = {} end
      table.insert(opts.spec, {
        { "<leader>gw", group = "Worktree", icon = "" },
      })
      return opts
    end,
  },
}
