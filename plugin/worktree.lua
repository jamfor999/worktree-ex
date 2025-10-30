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

vim.api.nvim_create_user_command('WorktreeLogClear', function()
  local config_home = os.getenv('XDG_CONFIG_HOME') or (os.getenv('HOME') .. '/.config')
  local log_file = config_home .. '/worktree-ex/debug.log'

  -- Delete the log file
  if vim.fn.filereadable(log_file) == 1 then
    os.remove(log_file)
    vim.notify('Debug log cleared: ' .. log_file, vim.log.levels.INFO)
  else
    vim.notify('No debug log found', vim.log.levels.INFO)
  end
end, { desc = 'Clear the debug log file' })

vim.api.nvim_create_user_command('WorktreeLogShow', function()
  local config_home = os.getenv('XDG_CONFIG_HOME') or (os.getenv('HOME') .. '/.config')
  local log_file = config_home .. '/worktree-ex/debug.log'

  if vim.fn.filereadable(log_file) == 1 then
    -- Open log file in a split
    vim.cmd('split ' .. vim.fn.fnameescape(log_file))
    -- Go to end of file
    vim.cmd('normal! G')
  else
    vim.notify('No debug log found at: ' .. log_file, vim.log.levels.WARN)
  end
end, { desc = 'Show the debug log file' })
