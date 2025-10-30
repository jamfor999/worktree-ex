# worktree.nvim

An intelligent Neovim plugin for seamless git worktree management. Easily switch between worktrees, create new ones, and have your buffers automatically remapped to the corresponding files in the new worktree.
master branch

## Features

- **Intelligent Worktree Detection**: Automatically detects when you're in a git worktree
- **Seamless Switching**: Switch between worktrees with a simple keymap
- **Buffer Remapping**: Automatically updates open buffers to point to files in the new worktree
- **Easy Creation**: Create new worktrees with an interactive UI
- **Statusline Integration**: Shows current branch with git icon (lualine/heirline/custom)
- **Click-to-Switch**: Optional click handler override for AstroNvim statusline
- **File Explorer Support**: Automatically refreshes neo-tree when switching worktrees
- **User Commands**: Provides `:WorktreeSwitch`, `:WorktreeCreate`, and `:WorktreeList` commands

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'yourusername/worktree.nvim',
  config = function()
    require('worktree').setup()
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'yourusername/worktree.nvim',
  config = function()
    require('worktree').setup()
  end,
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'yourusername/worktree.nvim'
```

Then in your config:

```lua
require('worktree').setup()
```

## Configuration

Default configuration:

```lua
require('worktree').setup({
  -- Keymaps
  keymaps = {
    switch = '<leader>gws',  -- Switch worktree
    create = '<leader>gwc',  -- Create new worktree
  },
  -- Automatically remap buffers when switching worktrees
  auto_remap_buffers = true,
  -- Show notifications
  notify = true,
  -- Enable statusline auto-refresh (set to true if you use the statusline component)
  enable_statusline = false,
  -- Try to override AstroNvim's git branch click handler (experimental)
  override_astronvim_click = false,
})
```

## Usage

### Switching Worktrees

Press `<leader>gws` (or your configured keymap) to open the worktree selector. You can also use the command:

```vim
:WorktreeSwitch
```

When you switch worktrees:
- Your current directory changes to the new worktree
- All open buffers are remapped to their corresponding files in the new worktree
- If a file doesn't exist in the new worktree, its buffer is closed (unless modified)
- File explorers (like neo-tree) are automatically refreshed

### Creating Worktrees

Press `<leader>gwc` (or your configured keymap) to create a new worktree. You can also use:

```vim
:WorktreeCreate
```

The interactive UI will guide you through:
1. Specifying the path for the new worktree (relative to the repo parent directory)
2. Choosing whether to create a new branch or checkout an existing one
3. Selecting/entering the branch name
4. Optionally switching to the newly created worktree

### Listing Worktrees

To see all available worktrees:

```vim
:WorktreeList
```

This will print all worktrees with their branches and paths, marking the current one.

### Statusline Integration

The plugin provides statusline components that show the current branch with a git icon.

**Important**: Set `enable_statusline = true` in your config when using any statusline integration.

#### Lualine Integration

Add the worktree component to your lualine config:

```lua
require('lualine').setup {
  sections = {
    lualine_b = {
      -- Replace the default branch component with worktree
      require('worktree').statusline.lualine_component(),
      -- Or add it in addition to the default branch
    },
    -- or in any other section
  },
}
```

The component supports click-to-switch by default. To disable:

```lua
require('worktree').statusline.lualine_component({ enable_click = false })
```

#### Heirline Integration

Add the worktree component to your heirline config:

```lua
local worktree_component = require('worktree').statusline.heirline_component()

-- Add to your statusline config
-- Example: table.insert(statusline, worktree_component)
```

The component supports click-to-switch by default. To disable:

```lua
require('worktree').statusline.heirline_component({ enable_click = false })
```

#### AstroNvim Integration

For AstroNvim users, you can optionally override the default git branch click behavior:

```lua
require('worktree').setup({
  enable_statusline = true,
  override_astronvim_click = true,  -- Clicking branch will open worktree switcher
})
```

This will make clicking on the git branch in the statusline open the worktree switcher instead of the default AstroNvim behavior.

#### Custom Statusline

For any statusline plugin or custom statuslines:

```lua
local statusline_text = require('worktree').statusline.get_statusline_component()
-- Returns a string like " main" with the branch icon
```

For a complete AstroNvim example, see `examples/astronvim-simple.lua`.

### Manual API Usage

You can also use the plugin programmatically:

```lua
local worktree = require('worktree')

-- Get current worktree info
local current = worktree.get_current_worktree()
-- Returns: { path = "/path/to/worktree", branch = "main", ... }

-- List all worktrees
local worktrees = worktree.list_worktrees()
-- Returns: array of worktree objects

-- Switch to a specific worktree by path
worktree.switch_worktree('/path/to/worktree')

-- Create a new worktree (opens UI)
worktree.create_worktree()
```

## How It Works

### Worktree Detection

The plugin uses `git worktree list --porcelain` to detect all worktrees in your repository. When you open Neovim in a worktree directory, it automatically detects which worktree you're in.

### Buffer Remapping

When switching worktrees, the plugin:

1. Identifies all open buffers that belong to the current worktree
2. Calculates the relative path of each file within the worktree
3. Constructs the new path in the target worktree
4. Updates the buffer to point to the new path
5. Reloads the buffer content

For example, if you have:
- Current worktree: `/repo/feature-branch`
- Open file: `/repo/feature-branch/src/main.lua`
- Target worktree: `/repo/main`

The buffer will be remapped to: `/repo/main/src/main.lua`

### File Explorer Integration

The plugin automatically refreshes neo-tree when switching worktrees. Support for other file explorers can be added.

## Requirements

- Neovim >= 0.7.0
- Git with worktree support
- (Optional) Nerd Font for the branch icon in statusline

## Tips

### Recommended Workflow

1. Create a bare repository:
   ```bash
   git clone --bare <repo-url> repo.git
   ```

2. Create worktrees for different branches:
   ```bash
   git worktree add ../feature-1 feature-1
   git worktree add ../main main
   ```

3. Open Neovim in any worktree and use `<leader>gws` to switch between them

### Integration with Telescope

While this plugin uses `vim.ui.select` by default (which works with telescope-ui-select), you can create custom pickers:

```lua
-- Custom telescope picker for worktrees
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

local function worktree_picker()
  local worktrees = require('worktree').list_worktrees()

  pickers.new({}, {
    prompt_title = 'Git Worktrees',
    finder = finders.new_table {
      results = worktrees,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.branch or entry.path,
          ordinal = entry.branch or entry.path,
        }
      end,
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        require('worktree').switch_worktree(selection.value.path)
      end)
      return true
    end,
  }):find()
end

vim.keymap.set('n', '<leader>gw', worktree_picker, { desc = 'Find worktrees' })
```

## Troubleshooting

### Buffers not remapping correctly

Make sure `auto_remap_buffers` is enabled in your config. If issues persist, check that:
- File paths are consistent (no symlinks causing path mismatches)
- Files exist in both worktrees at the same relative path

### Statusline not showing branch

If you want to use the statusline component:
- Make sure you're in a git repository
- Add the statusline component to your statusline config (see examples above)
- Set `enable_statusline = true` in the plugin config

### Click handler not working

If the click handler doesn't work:
- Make sure your statusline plugin supports click handlers
- For AstroNvim, try enabling `override_astronvim_click = true`
- The override happens after a 1-second delay to ensure heirline is loaded

### Neo-tree not refreshing

The plugin currently has specific support for neo-tree. If you use a different file explorer, you may need to manually refresh it after switching, or open an issue for support.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT License

## Acknowledgments

Inspired by the workflow of using git worktrees for managing multiple branches simultaneously.
