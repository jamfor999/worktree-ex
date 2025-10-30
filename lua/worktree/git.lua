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

-- Parse worktree list output (porcelain format for reliable parsing)
local function parse_worktree_list(output)
  local worktrees = {}
  local current_worktree = nil

  for line in output:gmatch('[^\r\n]+') do
    -- Porcelain format:
    -- worktree /path/to/worktree
    -- HEAD commit_hash
    -- branch refs/heads/branch_name
    -- bare (if bare repo)
    -- (blank line between worktrees)

    local path = line:match('^worktree%s+(.+)$')
    if path then
      -- New worktree entry
      current_worktree = {
        path = vim.fn.fnamemodify(path, ':p'):gsub('/$', ''),
        branch = nil,
        head = nil,
        is_bare = false,
        is_detached = false,
      }
      table.insert(worktrees, current_worktree)
    elseif current_worktree then
      -- Details for current worktree
      if line:match('^bare$') then
        current_worktree.is_bare = true
      elseif line:match('^detached$') then
        current_worktree.is_detached = true
      else
        local head = line:match('^HEAD%s+(.+)$')
        if head then
          current_worktree.head = head
        else
          local branch = line:match('^branch%s+refs/heads/(.+)$')
          if branch then
            current_worktree.branch = branch
          end
        end
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
  -- Use git to directly get the worktree path
  local toplevel = exec_git({ 'rev-parse', '--show-toplevel' })
  if not toplevel then
    return nil
  end
  
  toplevel = vim.trim(toplevel)
  toplevel = vim.fn.fnamemodify(toplevel, ':p'):gsub('/$', '')
  
  -- Get the list of all worktrees and find the one matching our toplevel
  local worktrees = M.list_worktrees()
  
  for _, wt in ipairs(worktrees) do
    if wt.path == toplevel then
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

-- Get the bare repository path from worktree list
local function get_bare_repo_path()
  local worktrees = M.list_worktrees()
  for _, wt in ipairs(worktrees) do
    if wt.is_bare then
      return wt.path
    end
  end
  return nil
end

-- Create a new worktree
function M.create_worktree(path, branch, create_branch)
  if not M.is_git_repo() then
    return false, 'Not in a git repository'
  end

  -- Get the bare repo path
  local bare_repo = get_bare_repo_path()
  if not bare_repo then
    return false, 'Cannot find bare repository'
  end

  -- Expand path relative to bare repository's parent
  if not path:match('^/') and not path:match('^~') then
    -- Relative path, make it relative to bare repo parent
    path = vim.fn.fnamemodify(bare_repo, ':h') .. '/' .. path
  end

  path = vim.fn.expand(path)
  -- Resolve to absolute path
  path = vim.fn.fnamemodify(path, ':p'):gsub('/$', '')

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
