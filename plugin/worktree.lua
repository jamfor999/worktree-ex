-- Main plugin entry point
-- This file is automatically sourced by Neovim

-- Prevent loading the plugin twice
if vim.g.loaded_worktree then
  return
end
vim.g.loaded_worktree = 1

-- Auto-restore buffers or check for bare repository on startup
vim.api.nvim_create_autocmd('VimEnter', {
  pattern = '*',
  callback = function()
    -- Use schedule to ensure this runs after other startup tasks
    vim.schedule(function()
      local worktree = require('worktree')
      
      -- First check if we're in a bare repo
      worktree.check_bare_repo()
      
      -- Then check if we should auto-restore buffers
      worktree.check_auto_restore_buffers()
    end)
  end,
  desc = 'Auto-restore worktree buffers or check for bare repository',
})

-- Create user commands
vim.api.nvim_create_user_command('WorktreeSwitch', function()
  require('worktree').switch_worktree()
end, { desc = 'Switch to a different worktree' })

vim.api.nvim_create_user_command('WorktreeCreate', function()
  require('worktree').create_worktree()
end, { desc = 'Create a new worktree' })

vim.api.nvim_create_user_command('WorktreeList', function()
  local worktrees = require('worktree').list_worktrees()
  local current = require('worktree').get_current_worktree()

  if #worktrees == 0 then
    print('No worktrees found')
    return
  end

  print('Worktrees:')
  for _, wt in ipairs(worktrees) do
    local marker = (current and wt.path == current.path) and '* ' or '  '
    local branch = wt.branch or 'detached'
    print(string.format('%s%s: %s', marker, branch, wt.path))
  end
end, { desc = 'List all worktrees' })

vim.api.nvim_create_user_command('WorktreeBufferClear', function()
  require('worktree').clear_buffer_list()
end, { desc = 'Clear persisted buffer list for current worktree and quit' })
