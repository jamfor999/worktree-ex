# worktree.nvim for AstroNvim

Complete guide for installing and using worktree.nvim with AstroNvim.

## Quick Install

### Step 1: Install the plugin locally

Since this plugin is currently local, you need to make it accessible to Neovim:

**Option A: Symlink (Recommended for development)**
```bash
# From the worktree-nvim directory
ln -s "$(pwd)" ~/.local/share/nvim/lazy/worktree.nvim
```

**Option B: Copy the plugin**
```bash
# From the worktree-nvim directory
cp -r . ~/.local/share/nvim/lazy/worktree.nvim
```

**Option C: Use a local path in your config**
```lua
return {
  {
    dir = "/Users/jamesforward/worktree-nvim",
    -- ... rest of config
  }
}
```

### Step 2: Create the plugin configuration

Create a new file in your AstroNvim config:

```bash
touch ~/.config/nvim/lua/plugins/worktree.lua
```

### Step 3: Choose a configuration

Copy one of the configurations below into `~/.config/nvim/lua/plugins/worktree.lua`:

## Configuration Options

### Simple Configuration (Recommended)

Perfect for most users - includes all essential features:

```lua
return {
  {
    "yourusername/worktree.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "nvim-telescope/telescope-ui-select.nvim",
    },
    config = function()
      require("worktree").setup({
        keymaps = {
          switch = "<leader>gws",
          create = "<leader>gwc",
        },
        auto_remap_buffers = true,
        notify = true,
        enable_statusline = true,
      })

      -- Setup telescope ui-select for better UI
      require("telescope").load_extension("ui-select")
    end,
    keys = {
      { "<leader>gws", function() require("worktree").switch_worktree() end, desc = "Switch worktree" },
      { "<leader>gwc", function() require("worktree").create_worktree() end, desc = "Create worktree" },
      { "<leader>gwl", "<cmd>WorktreeList<cr>", desc = "List worktrees" },
    },
  },
}
```

### Full Configuration (Advanced)

Includes all features, statusline integration, and custom Telescope picker:

```lua
return {
  -- Main worktree plugin
  {
    "yourusername/worktree.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("worktree").setup({
        keymaps = {
          switch = "<leader>gws",
          create = "<leader>gwc",
        },
        auto_remap_buffers = true,
        notify = true,
        enable_statusline = true,
      })
    end,
    keys = {
      { "<leader>gws", function() require("worktree").switch_worktree() end, desc = "Switch worktree" },
      { "<leader>gwc", function() require("worktree").create_worktree() end, desc = "Create worktree" },
      { "<leader>gwl", "<cmd>WorktreeList<cr>", desc = "List worktrees" },
    },
  },

  -- Telescope ui-select integration
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-telescope/telescope-ui-select.nvim" },
    opts = function(_, opts)
      opts = opts or {}
      opts.extensions = opts.extensions or {}
      opts.extensions["ui-select"] = {
        require("telescope.themes").get_dropdown({
          previewer = false,
          initial_mode = "normal",
          layout_config = { height = 0.4, width = 0.5 },
        }),
      }
      return opts
    end,
    config = function(_, opts)
      require("telescope").setup(opts)
      require("telescope").load_extension("ui-select")
    end,
  },

  -- Which-key integration for key descriptions
  {
    "folke/which-key.nvim",
    optional = true,
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { "<leader>gw", group = "Worktree", icon = "" })
      return opts
    end,
  },
}
```

### Using Local Path (For Development)

If you want to use the local version directly:

```lua
return {
  {
    dir = "/Users/jamesforward/worktree-nvim",
    event = "VeryLazy",
    config = function()
      require("worktree").setup({
        keymaps = {
          switch = "<leader>gws",
          create = "<leader>gwc",
        },
        auto_remap_buffers = true,
        notify = true,
        enable_statusline = true,
      })
    end,
    keys = {
      { "<leader>gws", function() require("worktree").switch_worktree() end, desc = "Switch worktree" },
      { "<leader>gwc", function() require("worktree").create_worktree() end, desc = "Create worktree" },
      { "<leader>gwl", "<cmd>WorktreeList<cr>", desc = "List worktrees" },
    },
  },
}
```

## Usage in AstroNvim

Once installed, you'll have these keybindings:

- `<leader>gws` - **Switch worktree** - Opens a selector to switch between worktrees
- `<leader>gwc` - **Create worktree** - Interactively create a new worktree
- `<leader>gwl` - **List worktrees** - Show all worktrees in the command area

### Using with AstroNvim's Key System

The keybindings will automatically appear in:
- Which-key menu (press `<leader>gw` to see the group)
- AstroNvim's built-in key descriptions

### Statusline Integration

The plugin will automatically integrate with AstroNvim's statusline (Heirline), showing:
- Git branch icon with branch name
- Click the branch to open the worktree switcher

## Workflow Example

Here's a typical workflow with AstroNvim:

```bash
# 1. Create a bare repository (one-time setup)
cd ~/projects
git clone --bare git@github.com:user/repo.git repo.git

# 2. Create worktrees for different features
cd repo.git
git worktree add ../repo-main main
git worktree add ../repo-feature-1 feature-1
git worktree add ../repo-feature-2 feature-2

# 3. Open Neovim in any worktree
cd ../repo-main
nvim .

# 4. Use the plugin
# - Press <leader>gws to switch between worktrees
# - Press <leader>gwc to create a new worktree
# - Press <leader>o to open Neo-tree (it will show the current worktree)
# - Click the branch in the statusline to switch
```

## Customization

### Change Keybindings

Modify the `keymaps` in your config:

```lua
config = function()
  require("worktree").setup({
    keymaps = {
      switch = "<leader>gw", -- Shorter keymap
      create = "<leader>gn", -- Different keymap
    },
  })
end,
```

### Disable Notifications

```lua
config = function()
  require("worktree").setup({
    notify = false,
  })
end,
```

### Disable Auto Buffer Remapping

If you want to manually manage buffers:

```lua
config = function()
  require("worktree").setup({
    auto_remap_buffers = false,
  })
end,
```

## Troubleshooting

### Plugin not loading

1. Make sure the plugin files are in the correct location
2. Run `:Lazy` to check if the plugin is loaded
3. Run `:checkhealth lazy` to check for issues

### Keybindings not working

1. Check if keybindings conflict with other plugins using `:map <leader>gw`
2. Try `:WorktreeSwitch` command directly
3. Check which-key menu with `<leader>` to see if the keys are registered

### Statusline not showing

1. The statusline component requires being in a git repository
2. Run `:lua print(require('worktree.git').is_git_repo())` to check
3. Try manually refreshing with `:e` or `:cd .`

### Buffers not remapping

1. Make sure `auto_remap_buffers = true` in config
2. Check that files exist at the same relative path in both worktrees
3. Modified buffers won't be closed automatically

## Commands Reference

Even without keybindings, you can use these commands:

```vim
:WorktreeSwitch  " Open worktree selector
:WorktreeCreate  " Create new worktree
:WorktreeList    " List all worktrees
```

## Publishing to GitHub

To share this plugin:

```bash
cd /Users/jamesforward/worktree-nvim
git init
git add .
git commit -m "Initial commit"
gh repo create worktree.nvim --public --source=. --push
```

Then update your config to use: `"yourusername/worktree.nvim"`

## Support

For issues, check:
- Plugin health: `:checkhealth worktree`
- Git status: `git worktree list`
- Neovim version: `:version` (requires >= 0.7.0)
