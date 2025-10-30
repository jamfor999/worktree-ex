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

-- For integration with lualine
function M.lualine_component(opts)
  opts = opts or {}
  local enable_click = opts.enable_click ~= false -- default true
  
  local component = {
    function()
      return M.get_statusline_component()
    end,
    color = opts.color,
    icon = opts.icon,
  }
  
  if enable_click then
    component.on_click = function()
      require('worktree').switch_worktree()
    end
  end
  
  return component
end

-- For integration with heirline (creates a standalone component)
function M.heirline_component(opts)
  opts = opts or {}
  local enable_click = opts.enable_click ~= false -- default true
  
  local component = {
    condition = function()
      return git.is_git_repo()
    end,
    init = function(self)
      self.branch = get_cached_branch()
      self.icon = get_branch_icon()
    end,
    provider = function(self)
      if not self.branch then return '' end
      return string.format(' %s %s ', self.icon, self.branch)
    end,
    hl = opts.hl or { fg = 'git_branch', bold = true },
    update = { 'DirChanged', 'BufEnter' },
  }
  
  if enable_click then
    component.on_click = {
      callback = function()
        require('worktree').switch_worktree()
      end,
      name = 'worktree_branch_click',
    }
  end
  
  return component
end

-- Safely override the git_branch component's on_click in heirline/AstroNvim
-- This is optional and will only work if the statusline structure is compatible
function M.try_override_astronvim_click()
  -- Try to override after a delay to ensure heirline is loaded
  vim.defer_fn(function()
    -- Check if we're in AstroNvim with heirline
    local ok_heirline, heirline = pcall(require, 'heirline')
    local ok_astro = pcall(require, 'astroui.status')
    
    if not (ok_heirline and ok_astro) then
      return -- Not in AstroNvim, nothing to do
    end
    
    local statusline = heirline.statusline
    if not statusline then return end
    
    -- Recursively search for git_branch components and override their on_click
    local function override_component(component)
      if type(component) ~= 'table' then return end
      
      -- Check if this looks like a git_branch component
      -- We'll look for components that have specific characteristics
      if component.on_click and type(component.on_click) == 'table' then
        -- Check if the component has git-related highlighting
        local hl = component.hl
        if type(hl) == 'table' and (hl.fg == 'git_branch' or hl.fg == 'git_branch_fg') then
          -- Override the click callback
          component.on_click.callback = function()
            require('worktree').switch_worktree()
          end
          component.on_click.name = 'worktree_override_click'
        elseif type(hl) == 'function' then
          -- hl is a function, we need to be more careful
          -- We'll wrap the on_click only if it exists
          local original_callback = component.on_click.callback
          component.on_click.callback = function(...)
            -- Try to determine if this is a git branch component by calling the original
            -- If it errors or doesn't work, fall back to worktree
            local ok = pcall(original_callback, ...)
            if not ok then
              require('worktree').switch_worktree()
            end
          end
        end
      end
      
      -- Recursively check nested components
      for _, child in ipairs(component) do
        override_component(child)
      end
    end
    
    override_component(statusline)
  end, 1000) -- 1 second delay to ensure everything is loaded
end

return M
