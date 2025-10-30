-- Main plugin entry point
-- This file is automatically sourced by Neovim

-- Prevent loading the plugin twice
if vim.g.loaded_worktree then
  return
end
vim.g.loaded_worktree = 1

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
