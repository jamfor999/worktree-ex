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
  -- Auto-update buffers when switching worktrees
  auto_remap_buffers = true,
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

  -- Remap all buffers
  if M.config.auto_remap_buffers then
    M._remap_buffers(current.path, new_worktree_path)
  end

  -- Change directory
  vim.cmd('cd ' .. vim.fn.fnameescape(new_worktree_path))

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

-- Remap buffer paths from old worktree to new worktree
function M._remap_buffers(old_path, new_path)
  print("=== REMAP BUFFERS DEBUG ===")
  print("Old path: " .. old_path)
  print("New path: " .. new_path)
  
  -- First, capture which buffers are visible in which windows
  local window_buffers = {}
  for _, winnr in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(winnr) then
      local bufnr = vim.api.nvim_win_get_buf(winnr)
      local buf_name = vim.api.nvim_buf_get_name(bufnr)
      
      print(string.format("Window %d -> Buffer %d: %s", winnr, bufnr, buf_name))
      
      -- Only track windows showing buffers from the old worktree
      if buf_name:sub(1, #old_path) == old_path then
        window_buffers[winnr] = {
          bufnr = bufnr,
          old_path = buf_name,
          rel_path = buf_name:sub(#old_path + 1)
        }
        print(string.format("  -> TRACKED: rel_path = %s", buf_name:sub(#old_path + 1)))
      else
        print("  -> NOT in old worktree, skipping")
      end
    end
  end

  local buffers = vim.api.nvim_list_bufs()
  local buffer_mapping = {} -- Map old buffer to new buffer

  print("\n=== REMAPPING BUFFERS ===")
  for _, bufnr in ipairs(buffers) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
      local buf_name = vim.api.nvim_buf_get_name(bufnr)

      -- Check if buffer path is within the old worktree
      if buf_name:sub(1, #old_path) == old_path then
        -- Calculate relative path
        local rel_path = buf_name:sub(#old_path + 1)

        -- Create new path in the new worktree
        local new_buf_path = new_path .. rel_path

        print(string.format("Buffer %d: %s", bufnr, buf_name))
        print(string.format("  -> New path: %s", new_buf_path))
        
        -- Check if the file exists in the new worktree
        if vim.fn.filereadable(new_buf_path) == 1 then
          print("  -> File exists, remapping buffer")
          -- Update buffer to point to new path
          vim.api.nvim_buf_set_name(bufnr, new_buf_path)

          -- Reload the buffer
          vim.api.nvim_buf_call(bufnr, function()
            vim.cmd('edit!')
          end)
          
          -- Track the mapping for window restoration
          buffer_mapping[buf_name] = bufnr
          print(string.format("  -> Mapped %s -> bufnr %d", buf_name, bufnr))
        else
          print("  -> File doesn't exist, deleting buffer")
          -- File doesn't exist in new worktree, close the buffer
          local buf_modified = vim.api.nvim_buf_get_option(bufnr, 'modified')
          if not buf_modified then
            vim.api.nvim_buf_delete(bufnr, { force = false })
            print("  -> Buffer deleted")
          else
            print("  -> Buffer modified, keeping it")
          end
        end
      end
    end
  end

  print("\n=== RESTORING WINDOWS ===")
  -- Restore buffers in windows
  for winnr, info in pairs(window_buffers) do
    print(string.format("Window %d (was showing %s)", winnr, info.old_path))
    if vim.api.nvim_win_is_valid(winnr) then
      local mapped_bufnr = buffer_mapping[info.old_path]
      print(string.format("  -> Mapped bufnr: %s", mapped_bufnr or "nil"))
      
      if mapped_bufnr and vim.api.nvim_buf_is_valid(mapped_bufnr) then
        -- Set the window to show the remapped buffer
        print(string.format("  -> Setting window to buffer %d", mapped_bufnr))
        vim.api.nvim_win_set_buf(winnr, mapped_bufnr)
        print("  -> Window buffer set successfully")
      else
        -- File doesn't exist in new worktree, open the equivalent path if possible
        local new_buf_path = new_path .. info.rel_path
        print(string.format("  -> No mapping found, trying to open: %s", new_buf_path))
        if vim.fn.filereadable(new_buf_path) == 1 then
          vim.api.nvim_win_call(winnr, function()
            vim.cmd('edit ' .. vim.fn.fnameescape(new_buf_path))
          end)
          print("  -> Opened new file in window")
        else
          print("  -> File not readable, leaving window as-is")
        end
      end
    else
      print("  -> Window no longer valid")
    end
  end
  
  print("=== END REMAP BUFFERS DEBUG ===\n")
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

return M
