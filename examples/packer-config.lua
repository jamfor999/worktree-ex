-- Example configuration for packer.nvim
-- Place this in your ~/.config/nvim/lua/plugins.lua or init.lua

return require('packer').startup(function(use)
  -- Worktree plugin
  use {
    'yourusername/worktree.nvim',
    config = function()
      require('worktree').setup({
        keymaps = {
          switch = '<leader>gws',
          create = '<leader>gwc',
        },
        auto_remap_buffers = true,
        notify = true,
        enable_statusline = true,
      })
    end,
  }

  -- Optional: Integrate with lualine
  use {
    'nvim-lualine/lualine.nvim',
    requires = { 'nvim-tree/nvim-web-devicons', opt = true },
    config = function()
      require('lualine').setup({
        sections = {
          lualine_a = { 'mode' },
          lualine_b = {
            'branch',
            'diff',
            'diagnostics',
          },
          lualine_c = { 'filename' },
          lualine_x = {
            -- Add worktree component
            require('worktree').statusline.lualine_component(),
            'encoding',
            'fileformat',
            'filetype',
          },
          lualine_y = { 'progress' },
          lualine_z = { 'location' },
        },
      })
    end,
  }

  -- Optional: Better UI selector
  use {
    'stevearc/dressing.nvim',
    config = function()
      require('dressing').setup()
    end,
  }
end)
