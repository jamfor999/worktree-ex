local M = {}
local git = require('worktree.git')

-- Show worktree selector using vim.ui.select
function M.show_worktree_selector(callback)
  local worktrees = git.list_worktrees()

  -- Filter out bare repositories
  local non_bare_worktrees = {}
  for _, wt in ipairs(worktrees) do
    if not wt.is_bare then
      table.insert(non_bare_worktrees, wt)
    end
  end

  if #non_bare_worktrees == 0 then
    vim.notify('No worktrees found', vim.log.levels.WARN)
    return
  end

  if #non_bare_worktrees == 1 then
    vim.notify('Only one worktree exists', vim.log.levels.INFO)
    return
  end

  local current = git.get_current_worktree()
  local current_path = current and current.path or nil

  -- Format worktrees for display
  local items = {}
  local paths = {}

  for _, wt in ipairs(non_bare_worktrees) do
    local display = wt.branch or wt.path
    local is_current = wt.path == current_path

    if is_current then
      display = display .. ' (current)'
    end

    if wt.is_detached then
      display = display .. ' [detached]'
    end

    table.insert(items, display)
    table.insert(paths, wt.path)
  end

  vim.ui.select(items, {
    prompt = 'Select worktree:',
    format_item = function(item)
      return item
    end,
  }, function(choice, idx)
    if choice and idx then
      callback(paths[idx])
    else
      callback(nil)
    end
  end)
end

-- Show UI to create first worktree in a bare repository
function M.show_bare_repo_worktree_prompt(callback)
  vim.ui.select({ 'Yes', 'No' }, {
    prompt = 'Bare repository detected. Create first worktree?',
  }, function(choice)
    if choice ~= 'Yes' then
      callback(nil, nil)
      return
    end

    -- Ask for worktree name
    vim.ui.input({
      prompt = 'Worktree name: ',
      default = 'main',
    }, function(path)
      if not path or path == '' then
        callback(nil, nil)
        return
      end

      -- Ask for branch name
      vim.ui.input({
        prompt = 'Branch name: ',
        default = 'main',
      }, function(branch)
        if not branch or branch == '' then
          callback(nil, nil)
          return
        end

        -- Execute the creation
        local success, result = git.create_worktree(path, branch, true)
        if success then
          callback(result.path, branch)
        else
          vim.notify('Failed to create worktree: ' .. (result or 'unknown error'), vim.log.levels.ERROR)
          callback(nil, nil)
        end
      end)
    end)
  end)
end

-- Show UI to create a new worktree
function M.show_create_worktree_ui(callback)
  -- First, ask for the worktree name
  vim.ui.input({
    prompt = 'Worktree name: ',
    default = '',
  }, function(path)
    if not path or path == '' then
      callback(nil, nil)
      return
    end

    -- Then ask if creating new branch or checking out existing
    vim.ui.select({ 'Create new branch', 'Checkout existing branch' }, {
      prompt = 'Branch option:',
    }, function(choice)
      if not choice then
        callback(nil, nil)
        return
      end

      local create_new = choice == 'Create new branch'

      if create_new then
        -- Ask for new branch name
        vim.ui.input({
          prompt = 'New branch name: ',
        }, function(branch)
          if not branch or branch == '' then
            callback(nil, nil)
            return
          end

          -- Execute the creation
          local success, result = git.create_worktree(path, branch, true)
          if success then
            callback(result.path, branch)
          else
            vim.notify('Failed to create worktree: ' .. (result or 'unknown error'), vim.log.levels.ERROR)
            callback(nil, nil)
          end
        end)
      else
        -- Show list of branches to checkout
        local branches = git.list_branches(false)

        if #branches == 0 then
          vim.notify('No branches found', vim.log.levels.ERROR)
          callback(nil, nil)
          return
        end

        vim.ui.select(branches, {
          prompt = 'Select branch to checkout:',
        }, function(branch)
          if not branch then
            callback(nil, nil)
            return
          end

          -- Execute the creation
          local success, result = git.create_worktree(path, branch, false)
          if success then
            callback(result.path, branch)
          else
            vim.notify('Failed to create worktree: ' .. (result or 'unknown error'), vim.log.levels.ERROR)
            callback(nil, nil)
          end
        end)
      end
    end)
  end)
end

return M
