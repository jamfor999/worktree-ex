local M = {}

local git = require('worktree.git')
local ui = require('worktree.ui')
local statusline = require('worktree.statusline')

-- Logging system - writes to persistent file
local log_file_path = nil
local function get_log_file_path()
  if not log_file_path then
    local config_home = os.getenv('XDG_CONFIG_HOME') or (os.getenv('HOME') .. '/.config')
    local log_dir = config_home .. '/worktree-ex'
    vim.fn.mkdir(log_dir, 'p')
    log_file_path = log_dir .. '/debug.log'
  end
  return log_file_path
end

local function log(message)
  -- Write to persistent log file only (no print to avoid "Press ENTER" prompts)
  pcall(function()
    local file = io.open(get_log_file_path(), 'a')
    if file then
      local timestamp = os.date('%Y-%m-%d %H:%M:%S')
      file:write(string.format('[%s] %s\n', timestamp, message))
      file:close()
    end
  end)
end

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

-- Get the debug log file path
function M.get_log_path()
  return get_log_file_path()
end

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
  return get_session_dir() .. '/' .. filename .. '.json'
end

-- Save current session for a worktree
function M._save_buffer_list(worktree_path)
  log('[worktree] DEBUG: _save_buffer_list called for path: ' .. worktree_path)

  -- Create directory if it doesn't exist
  local dir = get_session_dir()
  vim.fn.mkdir(dir, 'p')
  log('[worktree] DEBUG: Session directory: ' .. dir)

  -- Get session filename
  local filename = get_session_filename(worktree_path)
  log('[worktree] DEBUG: Saving buffer list to: ' .. filename)

  -- Collect all file buffers (not special buffers like neo-tree)
  -- ONLY save buffers that belong to this worktree to prevent cross-contamination
  local file_buffers = {}
  local normalized_worktree = vim.fn.fnamemodify(worktree_path, ':p')

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local buf_name = vim.api.nvim_buf_get_name(bufnr)
      local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')

      -- Only save regular file buffers (not special buffers)
      if buftype == '' and buf_name ~= '' then
        -- Validate that this buffer belongs to the current worktree
        local normalized_buf_path = vim.fn.fnamemodify(buf_name, ':p')

        if normalized_buf_path:sub(1, #normalized_worktree) == normalized_worktree then
          table.insert(file_buffers, buf_name)
          log('[worktree] DEBUG: Saving buffer: ' .. buf_name)
        else
          log('[worktree] DEBUG: Skipping buffer from different worktree: ' .. buf_name)
        end
      end
    end
  end

  log('[worktree] DEBUG: Found ' .. #file_buffers .. ' file buffers to save')

  -- If no buffers to save, delete the session file instead of saving an empty list
  if #file_buffers == 0 then
    log('[worktree] DEBUG: No buffers to save, deleting session file if it exists')
    if vim.fn.filereadable(filename) == 1 then
      os.remove(filename)
      log('[worktree] DEBUG: Deleted empty session file')
    else
      log('[worktree] DEBUG: No session file to delete')
    end
    return
  end

  -- Save to JSON file (only if we have buffers)
  local ok, err = pcall(function()
    local file = io.open(filename, 'w')
    if file then
      file:write(vim.fn.json_encode(file_buffers))
      file:close()
      log('[worktree] DEBUG: Successfully saved buffer list')
    else
      error('Failed to open file for writing')
    end
  end)

  if not ok then
    log('[worktree] ERROR: Failed to save buffer list: ' .. tostring(err))
  end
end

-- Helper function to get list of modified file buffers
local function get_modified_file_buffers()
  local modified_buffers = {}

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local buf_name = vim.api.nvim_buf_get_name(bufnr)
      local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')
      local buf_modified = vim.api.nvim_buf_get_option(bufnr, 'modified')

      -- Only check regular file buffers (not special buffers like neo-tree)
      if buftype == '' and buf_name ~= '' and buf_modified then
        table.insert(modified_buffers, {
          bufnr = bufnr,
          name = buf_name,
          short_name = vim.fn.fnamemodify(buf_name, ':t')
        })
      end
    end
  end

  return modified_buffers
end

-- Helper function to close all file buffers with optional force
local function close_all_file_buffers(force)
  log('[worktree] DEBUG: Closing all file buffers (force=' .. tostring(force) .. ')')
  local closed_count = 0

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local buf_name = vim.api.nvim_buf_get_name(bufnr)
      local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')

      -- Only close regular file buffers (not special buffers like neo-tree)
      if buftype == '' and buf_name ~= '' then
        log('[worktree] DEBUG: Closing buffer ' .. bufnr .. ': ' .. buf_name)
        pcall(vim.api.nvim_buf_delete, bufnr, { force = force or false })
        closed_count = closed_count + 1
      end
    end
  end

  log('[worktree] DEBUG: Closed ' .. closed_count .. ' file buffers')
  return closed_count
end

-- Restore session for a worktree (only restores, does not close buffers)
function M._restore_buffer_list(worktree_path)
  log('[worktree] DEBUG: _restore_buffer_list called for path: ' .. worktree_path)
  local filename = get_session_filename(worktree_path)
  log('[worktree] DEBUG: Looking for buffer list file: ' .. filename)

  -- Check if buffer list file exists
  if vim.fn.filereadable(filename) ~= 1 then
    log('[worktree] DEBUG: No buffer list file found')
    return false
  end

  log('[worktree] DEBUG: Buffer list file exists, restoring file buffers...')

  -- Read and restore file buffers
  local restored_count = 0
  local ok, err = pcall(function()
    local file = io.open(filename, 'r')
    if file then
      local content = file:read('*a')
      file:close()

      local file_buffers = vim.fn.json_decode(content)
      log('[worktree] DEBUG: Found ' .. #file_buffers .. ' file buffers to restore')

      -- Defensive: treat empty buffer list as if no session file exists
      if #file_buffers == 0 then
        log('[worktree] DEBUG: Buffer list is empty, treating as no session file')
        return
      end

      -- Open each file buffer using 'edit' to actually open them in windows
      for i, buf_path in ipairs(file_buffers) do
        -- Validate that the path belongs to the current worktree
        local normalized_buf_path = vim.fn.fnamemodify(buf_path, ':p')
        local normalized_worktree = vim.fn.fnamemodify(worktree_path, ':p')

        -- Check if file path starts with the worktree path
        if normalized_buf_path:sub(1, #normalized_worktree) ~= normalized_worktree then
          log('[worktree] WARNING: Skipping file from different worktree: ' .. buf_path)
        elseif vim.fn.filereadable(buf_path) == 1 then
          -- Check if file still exists
          log('[worktree] DEBUG: Restoring buffer ' .. i .. ': ' .. buf_path)

          local edit_ok, edit_err = pcall(function()
            if i == 1 then
              -- First file: edit in current window
              vim.cmd('edit ' .. vim.fn.fnameescape(buf_path))
            else
              -- Subsequent files: add to buffer list
              vim.cmd('badd ' .. vim.fn.fnameescape(buf_path))
            end
          end)

          if edit_ok then
            restored_count = restored_count + 1
          else
            log('[worktree] ERROR: Failed to restore buffer: ' .. buf_path .. ' - ' .. tostring(edit_err))
          end
        else
          log('[worktree] DEBUG: Skipping non-existent file: ' .. buf_path)
        end
      end

      log('[worktree] DEBUG: Successfully restored ' .. restored_count .. ' file buffers')
    else
      error('Failed to open file for reading')
    end
  end)

  if ok and restored_count > 0 then
    return true
  else
    if not ok then
      log('[worktree] ERROR: Failed to restore buffer list: ' .. tostring(err))
    end
    return false
  end
end

-- Internal function to perform the switch
function M._do_switch(new_worktree_path)
  log('[worktree] DEBUG: _do_switch called with path: ' .. new_worktree_path)

  local current = git.get_current_worktree()
  if not current then
    log('[worktree] ERROR: Not in a git worktree')
    vim.notify('Not in a git worktree', vim.log.levels.ERROR)
    return
  end

  log('[worktree] DEBUG: Current worktree: ' .. current.path)
  log('[worktree] DEBUG: Current branch: ' .. (current.branch or 'unknown'))

  -- Resolve the path to absolute path (handles .. and .)
  new_worktree_path = vim.fn.fnamemodify(new_worktree_path, ':p'):gsub('/$', '')
  log('[worktree] DEBUG: Resolved target path: ' .. new_worktree_path)

  if current.path == new_worktree_path then
    log('[worktree] DEBUG: Already in target worktree')
    vim.notify('Already in this worktree', vim.log.levels.INFO)
    return
  end

  -- Step 1: Check for unsaved changes and prompt user
  local modified_buffers = get_modified_file_buffers()
  local force_close = false

  if #modified_buffers > 0 then
    log('[worktree] DEBUG: Found ' .. #modified_buffers .. ' modified buffers')

    -- Build a list of modified file names for display
    local file_list = {}
    for _, buf in ipairs(modified_buffers) do
      table.insert(file_list, buf.short_name)
    end
    local file_names = table.concat(file_list, ', ')

    -- Prompt user for action
    local choice = vim.fn.confirm(
      'You have unsaved changes in: ' .. file_names .. '\n\nWhat would you like to do?',
      "&Save all\n&Discard all\n&Cancel",
      3  -- Default to Cancel
    )

    if choice == 1 then
      -- Save all modified buffers
      log('[worktree] DEBUG: User chose to save all changes')
      for _, buf in ipairs(modified_buffers) do
        local save_ok = pcall(function()
          vim.api.nvim_buf_call(buf.bufnr, function()
            vim.cmd('write')
          end)
        end)
        if save_ok then
          log('[worktree] DEBUG: Saved buffer: ' .. buf.name)
        else
          log('[worktree] ERROR: Failed to save buffer: ' .. buf.name)
        end
      end
      force_close = false
    elseif choice == 2 then
      -- Discard all changes
      log('[worktree] DEBUG: User chose to discard all changes')
      force_close = true
    else
      -- Cancel the switch
      log('[worktree] DEBUG: User cancelled worktree switch')
      vim.notify('Worktree switch cancelled', vim.log.levels.INFO)
      return
    end
  end

  -- Step 2: Save current buffer list before switching
  log('[worktree] DEBUG: auto_persist_buffers = ' .. tostring(M.config.auto_persist_buffers))
  if M.config.auto_persist_buffers then
    log('[worktree] DEBUG: Saving buffer list for current worktree')
    M._save_buffer_list(current.path)
  end

  -- Step 3: Create a scratch buffer FIRST to prevent main window from closing
  -- CRITICAL: Do this BEFORE closing file buffers!
  -- When we close a file buffer, if it's the only buffer in a window, the window closes too
  -- By creating scratch buffer first, the window switches to scratch instead of closing
  log('[worktree] DEBUG: Creating scratch buffer to prevent window/nvim exit')
  vim.cmd('enew')
  local scratch_bufnr = vim.api.nvim_get_current_buf()
  vim.bo.buftype = 'nofile'
  vim.bo.bufhidden = 'hide'
  vim.bo.swapfile = false

  -- Step 4: Now safe to close all file buffers (window won't close, it shows scratch)
  -- Uses force_close to discard changes if user chose to discard
  log('[worktree] DEBUG: Closing all file buffers before switch')
  close_all_file_buffers(force_close)

  -- Step 5: Change directory to new worktree
  log('[worktree] DEBUG: Changing directory to: ' .. new_worktree_path)
  vim.cmd('cd ' .. vim.fn.fnameescape(new_worktree_path))
  log('[worktree] DEBUG: Current directory after cd: ' .. vim.fn.getcwd())

  -- Step 6: Try to restore buffer list for new worktree
  local restored = false
  if M.config.auto_persist_buffers then
    log('[worktree] DEBUG: Attempting to restore buffer list for new worktree')
    restored = M._restore_buffer_list(new_worktree_path)
  end

  -- Step 7: Leave scratch buffer alone - it's harmless and deletion causes crashes
  -- The scratch buffer served its purpose (keeping nvim alive during transition)
  -- If buffers were restored, they're now active and scratch buffer sits idle in background
  -- If no buffers restored, scratch buffer is the clean slate for the user
  -- Either way: DO NOT DELETE IT
  if restored then
    log('[worktree] DEBUG: Buffers restored successfully, leaving scratch buffer in background')
  else
    log('[worktree] DEBUG: No buffers restored, scratch buffer remains active for user')
  end

  -- Step 8: Verify window/buffer state after restore (diagnostic logging)
  vim.schedule(function()
    local windows = vim.api.nvim_list_wins()
    local buffers = vim.api.nvim_list_bufs()
    local current_win = vim.api.nvim_get_current_win()
    local current_buf = vim.api.nvim_get_current_buf()

    log('[worktree] DEBUG: POST-RESTORE STATE CHECK:')
    log('[worktree] DEBUG:   Total windows: ' .. #windows)
    log('[worktree] DEBUG:   Total buffers: ' .. #buffers)
    log('[worktree] DEBUG:   Current window: ' .. current_win)
    log('[worktree] DEBUG:   Current buffer: ' .. current_buf)

    -- Check each window
    for _, win in ipairs(windows) do
      local win_buf = vim.api.nvim_win_get_buf(win)
      local buf_name = vim.api.nvim_buf_get_name(win_buf)
      log('[worktree] DEBUG:   Window ' .. win .. ' -> Buffer ' .. win_buf .. ' (' .. (buf_name ~= '' and buf_name or '[no name]') .. ')')
    end

    -- Verify current window has valid buffer
    if vim.api.nvim_win_is_valid(current_win) then
      local win_buf = vim.api.nvim_win_get_buf(current_win)
      if vim.api.nvim_buf_is_valid(win_buf) then
        log('[worktree] DEBUG:   Current window has valid buffer - OK')
      else
        log('[worktree] ERROR:   Current window has INVALID buffer!')
      end
    else
      log('[worktree] ERROR:   Current window is INVALID!')
    end
  end)

  -- Notify user of successful switch
  if M.config.notify then
    local worktrees = git.list_worktrees()
    local target_wt = vim.tbl_filter(function(wt)
      return wt.path == new_worktree_path
    end, worktrees)[1]

    local branch = target_wt and target_wt.branch or 'unknown'
    log('[worktree] DEBUG: Switch complete to branch: ' .. branch)
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
  log('[worktree] DEBUG: check_auto_restore_buffers called')
  
  -- Only run if we're in a git worktree (not bare repo)
  if not M.config.auto_persist_buffers then
    log('[worktree] DEBUG: auto_persist_buffers disabled, skipping')
    return
  end
  
  local current = git.get_current_worktree()
  if not current or current.is_bare then
    log('[worktree] DEBUG: Not in a worktree or in bare repo, skipping')
    return
  end
  
  log('[worktree] DEBUG: Current worktree: ' .. current.path)
  
  -- Check if nvim was opened with a directory argument (nvim .)
  local argv = vim.fn.argv()
  local opened_with_dir = false
  
  log('[worktree] DEBUG: argv count: ' .. #argv)
  
  if #argv == 1 then
    local arg = argv[1]
    local stat = vim.loop.fs_stat(arg)
    if stat and stat.type == 'directory' then
      opened_with_dir = true
      log('[worktree] DEBUG: Opened with directory: ' .. arg)
    end
  elseif #argv == 0 then
    -- Also handle when opened with no arguments in a directory
    opened_with_dir = true
    log('[worktree] DEBUG: Opened with no arguments')
  end
  
  if not opened_with_dir then
    log('[worktree] DEBUG: Not opened with directory, skipping')
    return
  end
  
  -- Check if persisted session exists
  local filename = get_session_filename(current.path)
  log('[worktree] DEBUG: Checking for session file: ' .. filename)
  if vim.fn.filereadable(filename) ~= 1 then
    -- No persisted session, let default behavior happen
    log('[worktree] DEBUG: No persisted session found')
    return
  end
  
  log('[worktree] DEBUG: Found persisted session, scheduling restore')
  -- We have persisted session - restore it instead of showing directory listing
  vim.schedule(function()
    -- Create a scratch buffer first to prevent nvim from closing if restore fails
    vim.cmd('enew')
    local scratch_bufnr = vim.api.nvim_get_current_buf()
    vim.bo.buftype = 'nofile'
    vim.bo.bufhidden = 'hide'
    vim.bo.swapfile = false

    -- Close any default file buffers that were created on startup
    close_all_file_buffers()

    -- Restore the persisted buffer list
    local restored = M._restore_buffer_list(current.path)

    -- Leave scratch buffer alone - it's harmless
    if restored then
      log('[worktree] DEBUG: Auto-restore complete, leaving scratch buffer in background')
    else
      log('[worktree] DEBUG: Auto-restore found no buffers, scratch buffer remains active')
    end
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
