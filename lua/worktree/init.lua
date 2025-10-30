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

-- Get the buffer list storage directory
local function get_bufferlist_dir()
  local config_home = os.getenv('XDG_CONFIG_HOME') or (os.getenv('HOME') .. '/.config')
  return config_home .. '/worktree-ex/bufferlist'
end

-- Get a safe filename for a worktree path
local function get_bufferlist_filename(worktree_path)
  -- Create a safe filename from the worktree path
  local filename = worktree_path:gsub('/', '_'):gsub('^_', '')
  return get_bufferlist_dir() .. '/' .. filename .. '.json'
end

-- Save current buffer list for a worktree
function M._save_buffer_list(worktree_path)
  local buffers = {}
  
  -- Collect all valid file buffers from this worktree
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
      local buf_name = vim.api.nvim_buf_get_name(bufnr)
      
      -- Only save buffers that are actual files within the worktree
      if buf_name ~= '' and buf_name:sub(1, #worktree_path) == worktree_path then
        local rel_path = buf_name:sub(#worktree_path + 1)
        if rel_path:sub(1, 1) == '/' then
          rel_path = rel_path:sub(2)
        end
        
        table.insert(buffers, {
          path = rel_path,
          cursor = vim.api.nvim_buf_get_mark(bufnr, '"'),
        })
      end
    end
  end
  
  -- Create directory if it doesn't exist
  local dir = get_bufferlist_dir()
  vim.fn.mkdir(dir, 'p')
  
  -- Write buffer list to file
  local filename = get_bufferlist_filename(worktree_path)
  local file = io.open(filename, 'w')
  if file then
    file:write(vim.json.encode(buffers))
    file:close()
  end
end

-- Restore buffer list for a worktree
function M._restore_buffer_list(worktree_path)
  local filename = get_bufferlist_filename(worktree_path)
  
  -- Check if buffer list file exists
  if vim.fn.filereadable(filename) ~= 1 then
    return
  end
  
  -- Read and parse buffer list
  local file = io.open(filename, 'r')
  if not file then
    return
  end
  
  local content = file:read('*a')
  file:close()
  
  local ok, buffers = pcall(vim.json.decode, content)
  if not ok or not buffers then
    return
  end
  
  -- Close all existing buffers except special ones
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local buf_name = vim.api.nvim_buf_get_name(bufnr)
      local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')
      
      -- Only close file buffers
      if buftype == '' and buf_name ~= '' then
        local buf_modified = vim.api.nvim_buf_get_option(bufnr, 'modified')
        if not buf_modified then
          pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
        end
      end
    end
  end
  
  -- Restore buffers
  for _, buf_info in ipairs(buffers) do
    local full_path = worktree_path .. '/' .. buf_info.path
    
    if vim.fn.filereadable(full_path) == 1 then
      -- Open the buffer
      vim.cmd('badd ' .. vim.fn.fnameescape(full_path))
    end
  end
  
  -- Open the first buffer in the current window if any were restored
  if #buffers > 0 then
    local first_path = worktree_path .. '/' .. buffers[1].path
    if vim.fn.filereadable(first_path) == 1 then
      vim.cmd('edit ' .. vim.fn.fnameescape(first_path))
    end
  end
end

-- Internal function to perform the switch
function M._do_switch(new_worktree_path)
  local current = git.get_current_worktree()
  if not current then
    vim.notify('Not in a git worktree', vim.log.levels.ERROR)
    return
  end

  -- Resolve the path to absolute path (handles .. and .)
  new_worktree_path = vim.fn.fnamemodify(new_worktree_path, ':p'):gsub('/$', '')

  if current.path == new_worktree_path then
    vim.notify('Already in this worktree', vim.log.levels.INFO)
    return
  end

  -- Save current buffer list before switching
  if M.config.auto_persist_buffers then
    M._save_buffer_list(current.path)
  end

  -- Change directory
  vim.cmd('cd ' .. vim.fn.fnameescape(new_worktree_path))

  -- Restore buffer list for new worktree
  if M.config.auto_persist_buffers then
    M._restore_buffer_list(new_worktree_path)
  end

  -- Refresh file explorer if neo-tree is loaded
  local ok, neotree = pcall(require, 'neo-tree.command')
  if ok then
    vim.cmd('Neotree close')
    vim.schedule(function()
      vim.cmd('Neotree show')
    end)
  end

  if M.config.notify then
    local worktrees = git.list_worktrees()
    local target_wt = vim.tbl_filter(function(wt)
      return wt.path == new_worktree_path
    end, worktrees)[1]

    local branch = target_wt and target_wt.branch or 'unknown'
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
  -- Only run if we're in a git worktree (not bare repo)
  if not M.config.auto_persist_buffers then
    return
  end
  
  local current = git.get_current_worktree()
  if not current or current.is_bare then
    return
  end
  
  -- Check if nvim was opened with a directory argument (nvim .)
  local argv = vim.fn.argv()
  local opened_with_dir = false
  
  if #argv == 1 then
    local arg = argv[1]
    local stat = vim.loop.fs_stat(arg)
    if stat and stat.type == 'directory' then
      opened_with_dir = true
    end
  elseif #argv == 0 then
    -- Also handle when opened with no arguments in a directory
    opened_with_dir = true
  end
  
  if not opened_with_dir then
    return
  end
  
  -- Check if persisted buffer list exists
  local filename = get_bufferlist_filename(current.path)
  if vim.fn.filereadable(filename) ~= 1 then
    -- No persisted buffers, let default behavior happen
    return
  end
  
  -- We have persisted buffers - restore them instead of showing directory listing
  vim.schedule(function()
    M._restore_buffer_list(current.path)
  end)
end

-- Clear the persisted buffer list for the current worktree
function M.clear_buffer_list()
  local current = git.get_current_worktree()
  if not current then
    vim.notify('Not in a git worktree', vim.log.levels.ERROR)
    return
  end
  
  local filename = get_bufferlist_filename(current.path)
  
  -- Delete the buffer list file if it exists
  if vim.fn.filereadable(filename) == 1 then
    os.remove(filename)
    vim.notify('Cleared buffer list for worktree: ' .. (current.branch or current.path), vim.log.levels.INFO)
  else
    vim.notify('No buffer list found for current worktree', vim.log.levels.INFO)
  end
  
  -- Quit Neovim
  vim.schedule(function()
    vim.cmd('qall')
  end)
end

return M
