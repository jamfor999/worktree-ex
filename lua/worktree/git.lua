local M = {}

-- Execute a git command and return the output
local function exec_git(args, cwd)
  local cmd = 'git ' .. table.concat(args, ' ')
  local handle = io.popen('cd ' .. vim.fn.shellescape(cwd or vim.fn.getcwd()) .. ' && ' .. cmd .. ' 2>&1')
  if not handle then
    return nil, 'Failed to execute git command'
  end

  local result = handle:read('*a')
  local success = handle:close()

  return success and result or nil, result
end

-- Check if we're in a git repository
function M.is_git_repo()
  local result = exec_git({ 'rev-parse', '--git-dir' })
  return result ~= nil
end

-- Get the root of the git repository
function M.get_git_root()
  local result = exec_git({ 'rev-parse', '--show-toplevel' })
  if result then
    return vim.trim(result)
  end
  return nil
end

-- Parse worktree list output
local function parse_worktree_list(output)
  local worktrees = {}

  for line in output:gmatch('[^\r\n]+') do
    -- Format: worktree /path/to/worktree
    --         HEAD abcd1234
    --         branch refs/heads/branch-name
    -- or
    -- worktree /path/to/worktree (bare)

    local path = line:match('^worktree%s+(.+)$')
    if path then
      -- Remove any trailing annotations like (bare) or (detached)
      path = path:gsub('%s*%([^)]+%)$', '')

      table.insert(worktrees, {
        path = path,
        branch = nil,
        head = nil,
        is_bare = line:match('%(bare%)') ~= nil,
        is_detached = false,
      })
    elseif #worktrees > 0 then
      -- This is a detail line for the last worktree
      local current = worktrees[#worktrees]

      local head = line:match('^%s*HEAD%s+(.+)$')
      if head then
        current.head = head
      end

      local branch = line:match('^%s*branch%s+refs/heads/(.+)$')
      if branch then
        current.branch = branch
      end

      if line:match('^%s*detached$') then
        current.is_detached = true
      end
    end
  end

  return worktrees
end

-- List all worktrees
function M.list_worktrees()
  if not M.is_git_repo() then
    return {}
  end

  local output = exec_git({ 'worktree', 'list', '--porcelain' })
  if not output then
    return {}
  end

  return parse_worktree_list(output)
end

-- Get the current worktree
function M.get_current_worktree()
  local cwd = vim.fn.getcwd()
  local worktrees = M.list_worktrees()

  for _, wt in ipairs(worktrees) do
    -- Normalize paths for comparison
    local wt_path = vim.fn.resolve(wt.path)
    local current_path = vim.fn.resolve(cwd)

    -- Check if cwd is within this worktree
    if current_path:sub(1, #wt_path) == wt_path then
      return wt
    end
  end

  return nil
end

-- Get the current branch name
function M.get_current_branch()
  local output = exec_git({ 'branch', '--show-current' })
  if output and output ~= '' then
    return vim.trim(output)
  end

  -- Fallback for detached HEAD
  local head_output = exec_git({ 'rev-parse', '--short', 'HEAD' })
  if head_output then
    return 'detached:' .. vim.trim(head_output)
  end

  return nil
end

-- Create a new worktree
function M.create_worktree(path, branch, create_branch)
  if not M.is_git_repo() then
    return false, 'Not in a git repository'
  end

  -- Expand path relative to git root
  local git_root = M.get_git_root()
  if not path:match('^/') and not path:match('^~') then
    -- Relative path, make it relative to git root parent
    path = vim.fn.fnamemodify(git_root, ':h') .. '/' .. path
  end

  path = vim.fn.expand(path)

  local args = { 'worktree', 'add' }

  if create_branch then
    table.insert(args, '-b')
    table.insert(args, branch)
  end

  table.insert(args, vim.fn.shellescape(path))

  if not create_branch then
    table.insert(args, branch)
  end

  local output, err = exec_git(args)

  if output then
    return true, { path = path, branch = branch }
  else
    return false, err
  end
end

-- Remove a worktree
function M.remove_worktree(path, force)
  if not M.is_git_repo() then
    return false, 'Not in a git repository'
  end

  local args = { 'worktree', 'remove' }

  if force then
    table.insert(args, '--force')
  end

  table.insert(args, vim.fn.shellescape(path))

  local output, err = exec_git(args)

  if output then
    return true
  else
    return false, err
  end
end

-- List all branches (for creating new worktrees)
function M.list_branches(include_remotes)
  local args = { 'branch' }

  if include_remotes then
    table.insert(args, '-a')
  end

  local output = exec_git(args)
  if not output then
    return {}
  end

  local branches = {}
  for line in output:gmatch('[^\r\n]+') do
    -- Remove leading * and whitespace
    local branch = line:gsub('^%s*%*?%s*', '')
    -- Remove -> origin/HEAD markers
    if not branch:match('->') then
      table.insert(branches, branch)
    end
  end

  return branches
end

return M
