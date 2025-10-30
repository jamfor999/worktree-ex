local M = {}
local git = require('worktree.git')

-- Cache for branch name to avoid excessive git calls
local branch_cache = {
  branch = nil,
  last_update = 0,
  cache_duration = 2000, -- 2 seconds
}

-- Get the branch icon (you can customize this)
local function get_branch_icon()
  -- Using a common git branch icon
  -- If you have a nerd font, this should display nicely
  return ''
end

-- Get current branch with caching
local function get_cached_branch()
  local now = vim.loop.now()

  if branch_cache.branch and (now - branch_cache.last_update) < branch_cache.cache_duration then
    return branch_cache.branch
  end

  local branch = git.get_current_branch()
  branch_cache.branch = branch
  branch_cache.last_update = now

  return branch
end

-- Get the statusline component as a string
function M.get_statusline_component()
  if not git.is_git_repo() then
    return ''
  end

  local branch = get_cached_branch()
  if not branch then
    return ''
  end

  local icon = get_branch_icon()
  return string.format('%s %s', icon, branch)
end

-- Set up click handler for statusline (if supported by your statusline plugin)
function M.setup_click_handler()
  -- Create a function that can be called when clicking the statusline
  vim.api.nvim_create_user_command('WorktreeStatuslineClick', function()
    require('worktree').switch_worktree()
  end, {})
end

-- For integration with lualine
function M.lualine_component()
  return {
    function()
      return M.get_statusline_component()
    end,
    on_click = function()
      require('worktree').switch_worktree()
    end,
  }
end

-- For integration with heirline
function M.heirline_component()
  local conditions = require('heirline.conditions')

  return {
    condition = conditions.is_git_repo,
    init = function(self)
      self.branch = get_cached_branch()
      self.icon = get_branch_icon()
    end,
    provider = function(self)
      return string.format(' %s %s ', self.icon, self.branch or '')
    end,
    on_click = {
      callback = function()
        require('worktree').switch_worktree()
      end,
      name = 'worktree_click',
    },
  }
end

-- Auto-refresh statusline when changing directories
function M.setup_auto_refresh()
  vim.api.nvim_create_autocmd({ 'DirChanged', 'BufEnter' }, {
    group = vim.api.nvim_create_augroup('WorktreeStatusline', { clear = true }),
    callback = function()
      -- Invalidate cache
      branch_cache.branch = nil
      branch_cache.last_update = 0

      -- Force statusline redraw
      vim.cmd('redrawstatus')
    end,
  })
end

return M
