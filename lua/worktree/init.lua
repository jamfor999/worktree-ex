local M = {}

local git = require('worktree.git')
local ui = require('worktree.ui')
local statusline = require('worktree.statusline')

M.config = {
  -- Default configuration
  keymaps = {
    switch = '<leader>gws',
    create = '<leader>gwc',
  },
  -- Auto-persist/restore buffers when switching worktrees
  auto_persist_buffers = true,
  -- Show notifications
  notify = true,
  -- Enable statusline component auto-refresh
  enable_statusline = false,
  -- Try to override AstroNvim's git branch click handler (experimental)
  override_astronvim_click = false,
}

-- Setup function to be called by user
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})

  -- Set up keymaps
  vim.keymap.set('n', M.config.keymaps.switch, function()
    M.switch_worktree()
  end, { desc = 'Switch worktree' })

  vim.keymap.set('n', M.config.keymaps.create, function()
    M.create_worktree()
  end, { desc = 'Create new worktree' })

  -- Set up statusline auto-refresh if enabled
  if M.config.enable_statusline then
    statusline.setup_auto_refresh()
  end

  -- Optionally try to override AstroNvim's git branch click handler
  if M.config.override_astronvim_click then
    statusline.try_override_astronvim_click()
  end
end

-- Expose statusline module for manual integration
M.statusline = statusline

-- Get current worktree info
function M.get_current_worktree()
  return git.get_current_worktree()
end

-- List all worktrees
function M.list_worktrees()
  return git.list_worktrees()
end

-- Switch to a different worktree
function M.switch_worktree(worktree_path)
  if not worktree_path then
    -- Show UI selector
    ui.show_worktree_selector(function(selected)
      if selected then
        M._do_switch(selected)
      end
    end)
  else
    M._do_switch(worktree_path)
  end
end

-- Get the session storage directory
local function get_session_dir()
  local config_home = os.getenv('XDG_CONFIG_HOME') or (os.getenv('HOME') .. '/.config')
  return config_home .. '/worktree-ex/sessions'
end

-- Get a safe filename for a worktree path
local function get_session_filename(worktree_path)
  -- Create a safe filename from the worktree path
  local filename = worktree_path:gsub('/', '_'):gsub('^_', '')
  return get_session_dir() .. '/' .. filename .. '.vim'
end

-- Save current session for a worktree
function M._save_buffer_list(worktree_path)
  print('[worktree] DEBUG: _save_buffer_list called for path: ' .. worktree_path)
  
  -- Create directory if it doesn't exist
  local dir = get_session_dir()
  vim.fn.mkdir(dir, 'p')
  print('[worktree] DEBUG: Session directory: ' .. dir)
  
  -- Get session filename
  local filename = get_session_filename(worktree_path)
  print('[worktree] DEBUG: Saving session to: ' .. filename)
  
  -- Save session options
  local saved_sessionoptions = vim.o.sessionoptions
  -- We want to save: buffers, curdir, folds, help, tabpages, winsize, winpos
  -- We DON'T want: blank, globals, localoptions, options, resize, terminal
  vim.o.sessionoptions = 'buffers,curdir,folds,tabpages,winsize,winpos'
  
  -- Save the session
  local ok, err = pcall(function()
    vim.cmd('mksession! ' .. vim.fn.fnameescape(filename))
  end)
  
  -- Restore session options
  vim.o.sessionoptions = saved_sessionoptions
  
  if ok then
    print('[worktree] DEBUG: Successfully saved session')
  else
    print('[worktree] ERROR: Failed to save session: ' .. tostring(err))
  end
end

-- Restore session for a worktree
function M._restore_buffer_list(worktree_path)
  print('[worktree] DEBUG: _restore_buffer_list called for path: ' .. worktree_path)
  local filename = get_session_filename(worktree_path)
  print('[worktree] DEBUG: Looking for session file: ' .. filename)
  
  -- Check if session file exists
  if vim.fn.filereadable(filename) ~= 1 then
    print('[worktree] DEBUG: No session file found, skipping restore')
    return false
  end
  
  print('[worktree] DEBUG: Session file exists, restoring...')
  
  -- Source the session file
  local ok, err = pcall(function()
    vim.cmd('source ' .. vim.fn.fnameescape(filename))
  end)
  
  if ok then
    print('[worktree] DEBUG: Successfully restored session')
    return true
  else
    print('[worktree] ERROR: Failed to restore session: ' .. tostring(err))
    return false
  end
end

-- Internal function to perform the switch
function M._do_switch(new_worktree_path)
  print('[worktree] DEBUG: _do_switch called with path: ' .. new_worktree_path)
  
  local current = git.get_current_worktree()
  if not current then
    print('[worktree] ERROR: Not in a git worktree')
    vim.notify('Not in a git worktree', vim.log.levels.ERROR)
    return
  end
  
  print('[worktree] DEBUG: Current worktree: ' .. current.path)
  print('[worktree] DEBUG: Current branch: ' .. (current.branch or 'unknown'))

  -- Resolve the path to absolute path (handles .. and .)
  new_worktree_path = vim.fn.fnamemodify(new_worktree_path, ':p'):gsub('/$', '')
  print('[worktree] DEBUG: Resolved target path: ' .. new_worktree_path)

  if current.path == new_worktree_path then
    print('[worktree] DEBUG: Already in target worktree')
    vim.notify('Already in this worktree', vim.log.levels.INFO)
    return
  end

  -- Save current buffer list before switching
  print('[worktree] DEBUG: auto_persist_buffers = ' .. tostring(M.config.auto_persist_buffers))
  if M.config.auto_persist_buffers then
    print('[worktree] DEBUG: Saving buffer list for current worktree')
    M._save_buffer_list(current.path)
  end

  -- Change directory
  print('[worktree] DEBUG: Changing directory to: ' .. new_worktree_path)
  vim.cmd('cd ' .. vim.fn.fnameescape(new_worktree_path))
  print('[worktree] DEBUG: Current directory after cd: ' .. vim.fn.getcwd())

  -- Restore buffer list for new worktree
  local restored = false
  if M.config.auto_persist_buffers then
    print('[worktree] DEBUG: Restoring session for new worktree')
    restored = M._restore_buffer_list(new_worktree_path)
  end

  -- If no session was restored, clean up old buffers and start fresh
  if not restored then
    print('[worktree] DEBUG: No session restored, cleaning up old buffers')
    
    -- Close all file buffers from the old worktree
    local closed_count = 0
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        local buf_name = vim.api.nvim_buf_get_name(bufnr)
        local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')
        
        -- Only close regular file buffers (not special buffers like neo-tree)
        if buftype == '' and buf_name ~= '' then
          local buf_modified = vim.api.nvim_buf_get_option(bufnr, 'modified')
          if not buf_modified then
            print('[worktree] DEBUG: Closing old buffer ' .. bufnr .. ': ' .. buf_name)
            pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
            closed_count = closed_count + 1
          else
            print('[worktree] DEBUG: Skipping modified buffer ' .. bufnr .. ': ' .. buf_name)
          end
        end
      end
    end
    print('[worktree] DEBUG: Closed ' .. closed_count .. ' old buffers')
    
    -- Refresh neo-tree for the new worktree
    print('[worktree] DEBUG: Manually refreshing neo-tree for new worktree')
    local ok, neotree = pcall(require, 'neo-tree.command')
    if ok then
      vim.cmd('Neotree close')
      vim.schedule(function()
        vim.cmd('Neotree show')
      end)
    end
  else
    print('[worktree] DEBUG: Session restored, neo-tree state should be preserved')
  end

  if M.config.notify then
    local worktrees = git.list_worktrees()
    local target_wt = vim.tbl_filter(function(wt)
      return wt.path == new_worktree_path
    end, worktrees)[1]

    local branch = target_wt and target_wt.branch or 'unknown'
    print('[worktree] DEBUG: Switch complete to branch: ' .. branch)
    vim.notify('Switched to worktree: ' .. branch, vim.log.levels.INFO)
  end
end

-- Create a new worktree
function M.create_worktree()
  ui.show_create_worktree_ui(function(path, branch)
    if path and branch then
      local success, result = git.create_worktree(path, branch)
      if success then
        vim.notify('Created worktree: ' .. path .. ' on branch ' .. branch, vim.log.levels.INFO)
        -- Optionally switch to the new worktree
        vim.ui.select({'Yes', 'No'}, {
          prompt = 'Switch to new worktree?',
        }, function(choice)
          if choice == 'Yes' then
            M._do_switch(result.path)
          end
        end)
      else
        vim.notify('Failed to create worktree: ' .. (result or 'unknown error'), vim.log.levels.ERROR)
      end
    end
  end)
end

-- Check if opened in a bare repository and prompt for first worktree
function M.check_bare_repo()
  -- Only run if we're in a bare repository
  if not git.is_bare_repo() then
    return
  end

  -- Check if any non-bare worktrees exist
  local worktrees = git.list_worktrees()
  local has_worktrees = false
  for _, wt in ipairs(worktrees) do
    if not wt.is_bare then
      has_worktrees = true
      break
    end
  end

  -- If worktrees already exist, don't prompt
  if has_worktrees then
    return
  end

  -- Prompt to create first worktree
  vim.schedule(function()
    ui.show_bare_repo_worktree_prompt(function(path, branch)
      if path and branch then
        -- Switch to the newly created worktree
        vim.cmd('cd ' .. vim.fn.fnameescape(path))
        
        -- Refresh file explorer if neo-tree is loaded
        local ok, neotree = pcall(require, 'neo-tree.command')
        if ok then
          vim.schedule(function()
            vim.cmd('Neotree show')
          end)
        end
        
        vim.notify('Switched to new worktree: ' .. branch, vim.log.levels.INFO)
      end
    end)
  end)
end

-- Check if we should auto-restore buffers on startup
function M.check_auto_restore_buffers()
  print('[worktree] DEBUG: check_auto_restore_buffers called')
  
  -- Only run if we're in a git worktree (not bare repo)
  if not M.config.auto_persist_buffers then
    print('[worktree] DEBUG: auto_persist_buffers disabled, skipping')
    return
  end
  
  local current = git.get_current_worktree()
  if not current or current.is_bare then
    print('[worktree] DEBUG: Not in a worktree or in bare repo, skipping')
    return
  end
  
  print('[worktree] DEBUG: Current worktree: ' .. current.path)
  
  -- Check if nvim was opened with a directory argument (nvim .)
  local argv = vim.fn.argv()
  local opened_with_dir = false
  
  print('[worktree] DEBUG: argv count: ' .. #argv)
  
  if #argv == 1 then
    local arg = argv[1]
    local stat = vim.loop.fs_stat(arg)
    if stat and stat.type == 'directory' then
      opened_with_dir = true
      print('[worktree] DEBUG: Opened with directory: ' .. arg)
    end
  elseif #argv == 0 then
    -- Also handle when opened with no arguments in a directory
    opened_with_dir = true
    print('[worktree] DEBUG: Opened with no arguments')
  end
  
  if not opened_with_dir then
    print('[worktree] DEBUG: Not opened with directory, skipping')
    return
  end
  
  -- Check if persisted session exists
  local filename = get_session_filename(current.path)
  print('[worktree] DEBUG: Checking for session file: ' .. filename)
  if vim.fn.filereadable(filename) ~= 1 then
    -- No persisted session, let default behavior happen
    print('[worktree] DEBUG: No persisted session found')
    return
  end
  
  print('[worktree] DEBUG: Found persisted session, scheduling restore')
  -- We have persisted session - restore it instead of showing directory listing
  vim.schedule(function()
    M._restore_buffer_list(current.path)
  end)
end

-- Clear the persisted session for the current worktree
function M.clear_buffer_list()
  local current = git.get_current_worktree()
  if not current then
    vim.notify('Not in a git worktree', vim.log.levels.ERROR)
    return
  end
  
  local filename = get_session_filename(current.path)
  
  -- Delete the session file if it exists
  if vim.fn.filereadable(filename) == 1 then
    os.remove(filename)
    vim.notify('Cleared session for worktree: ' .. (current.branch or current.path), vim.log.levels.INFO)
  else
    vim.notify('No session found for current worktree', vim.log.levels.INFO)
  end
  
  -- Quit Neovim
  vim.schedule(function()
    vim.cmd('qall')
  end)
end

return M
