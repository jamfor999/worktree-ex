-- Example configuration for lazy.nvim
-- Place this in your ~/.config/nvim/lua/plugins/ directory

return {
  {
    'yourusername/worktree.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim', -- Optional, for better async support
    },
    config = function()
      require('worktree').setup({
        -- Customize keymaps if desired
        keymaps = {
          switch = '<leader>gws', -- Switch worktree
          create = '<leader>gwc', -- Create worktree
        },
        -- Auto-remap buffers when switching (recommended)
        auto_remap_buffers = true,
        -- Show notifications
        notify = true,
        -- Enable statusline component
        enable_statusline = true,
      })
    end,
    keys = {
      { '<leader>gws', desc = 'Switch worktree' },
      { '<leader>gwc', desc = 'Create worktree' },
    },
  },

  -- Optional: Integrate with lualine
  {
    'nvim-lualine/lualine.nvim',
    opts = function(_, opts)
      -- Add worktree component to lualine
      local worktree_component = require('worktree').statusline.lualine_component()

      -- Add to the right section
      table.insert(opts.sections.lualine_x, 1, worktree_component)
    end,
  },

  -- Optional: Better UI for vim.ui.select
  {
    'stevearc/dressing.nvim',
    opts = {},
  },

  -- OR use telescope-ui-select
  {
    'nvim-telescope/telescope-ui-select.nvim',
    config = function()
      require('telescope').setup({
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown({}),
          },
        },
      })
      require('telescope').load_extension('ui-select')
    end,
  },
}
