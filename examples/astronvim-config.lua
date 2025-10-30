-- AstroNvim configuration for worktree.nvim
-- Place this file in: ~/.config/nvim/lua/plugins/worktree.lua

return {
  -- Main worktree plugin
  {
    "yourusername/worktree.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim", -- For better UI selection
    },
    config = function()
      require("worktree").setup({
        -- Keymaps
        keymaps = {
          switch = "<leader>gws", -- Git Worktree Switch
          create = "<leader>gwc", -- Git Worktree Create
        },
        -- Auto-remap buffers when switching worktrees
        auto_remap_buffers = true,
        -- Show notifications
        notify = true,
        -- Enable statusline component
        enable_statusline = true,
      })
    end,
    keys = {
      {
        "<leader>gws",
        function() require("worktree").switch_worktree() end,
        desc = "Switch worktree",
      },
      {
        "<leader>gwc",
        function() require("worktree").create_worktree() end,
        desc = "Create worktree",
      },
      {
        "<leader>gwl",
        "<cmd>WorktreeList<cr>",
        desc = "List worktrees",
      },
    },
  },

  -- Enhance vim.ui.select with telescope
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-telescope/telescope-ui-select.nvim",
    },
    opts = function(_, opts)
      -- Extend existing telescope config
      local telescope_config = opts or {}

      -- Add ui-select extension
      telescope_config.extensions = telescope_config.extensions or {}
      telescope_config.extensions["ui-select"] = {
        require("telescope.themes").get_dropdown({
          -- Options for dropdown theme
          previewer = false,
          initial_mode = "normal",
          sorting_strategy = "ascending",
          layout_strategy = "center",
          layout_config = {
            height = 0.4,
            width = 0.5,
          },
        }),
      }

      return telescope_config
    end,
    config = function(_, opts)
      local telescope = require("telescope")
      telescope.setup(opts)
      -- Load the ui-select extension
      telescope.load_extension("ui-select")
    end,
  },

  -- Integrate with AstroNvim's lualine/heirline statusline
  {
    "rebelot/heirline.nvim",
    optional = true,
    opts = function(_, opts)
      local status = require("astroui.status")

      -- Create worktree component for heirline
      local worktree_component = {
        condition = function()
          local git = require("worktree.git")
          return git.is_git_repo()
        end,
        init = function(self)
          local statusline = require("worktree.statusline")
          self.worktree_text = statusline.get_statusline_component()
        end,
        provider = function(self)
          return self.worktree_text ~= "" and " " .. self.worktree_text .. " " or ""
        end,
        hl = { fg = "git_branch_fg", bg = "statusline_bg", bold = true },
        on_click = {
          callback = function()
            require("worktree").switch_worktree()
          end,
          name = "worktree_statusline_click",
        },
        update = { "DirChanged", "BufEnter" },
      }

      -- Add to statusline (typically in section_x or section_b)
      -- This adds it after the git branch in the statusline
      if opts.statusline then
        -- Find git_branch component and add worktree after it
        for i, component in ipairs(opts.statusline) do
          if component.condition and type(component.condition) == "function" then
            -- Try to detect if this is a git-related component
            local success, result = pcall(component.condition)
            if success and component.provider then
              -- Insert worktree component after git components
              if i < #opts.statusline then
                table.insert(opts.statusline, i + 1, worktree_component)
                break
              end
            end
          end
        end
      end

      return opts
    end,
  },

  -- Integrate with AstroNvim's which-key for better key descriptions
  {
    "folke/which-key.nvim",
    optional = true,
    opts = function(_, opts)
      if not opts.spec then opts.spec = {} end

      -- Add worktree key group
      table.insert(opts.spec, {
        { "<leader>gw", group = "Worktree", icon = "" },
      })

      return opts
    end,
  },

  -- Ensure neo-tree support (AstroNvim uses neo-tree by default)
  {
    "nvim-neo-tree/neo-tree.nvim",
    optional = true,
    opts = function(_, opts)
      -- Neo-tree will automatically refresh when directory changes
      -- The worktree plugin handles the cd and neo-tree refresh
      return opts
    end,
  },

  -- Optional: Add telescope integration for a custom worktree picker
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    opts = function(_, opts)
      -- Add custom worktree picker
      local telescope_loaded, telescope = pcall(require, "telescope")
      if telescope_loaded then
        local pickers = require("telescope.pickers")
        local finders = require("telescope.finders")
        local conf = require("telescope.config").values
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")

        -- Custom telescope picker for worktrees
        local function worktree_picker()
          local worktrees = require("worktree").list_worktrees()
          local current = require("worktree").get_current_worktree()

          if #worktrees == 0 then
            vim.notify("No worktrees found", vim.log.levels.WARN)
            return
          end

          pickers
            .new({}, {
              prompt_title = "Git Worktrees",
              finder = finders.new_table({
                results = worktrees,
                entry_maker = function(entry)
                  local display = entry.branch or entry.path
                  local is_current = current and entry.path == current.path

                  if is_current then display = display .. " (current)" end
                  if entry.is_bare then
                    display = display .. " [bare]"
                  elseif entry.is_detached then
                    display = display .. " [detached]"
                  end

                  return {
                    value = entry,
                    display = display,
                    ordinal = entry.branch or entry.path,
                    path = entry.path,
                  }
                end,
              }),
              sorter = conf.generic_sorter({}),
              attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                  actions.close(prompt_bufnr)
                  local selection = action_state.get_selected_entry()
                  if selection and selection.value then
                    require("worktree").switch_worktree(selection.value.path)
                  end
                end)
                return true
              end,
            })
            :find()
        end

        -- Register the picker as a command
        vim.api.nvim_create_user_command("WorktreeTelescope", worktree_picker, {
          desc = "Open telescope worktree picker",
        })

        -- Optional: Override the default switch keymap to use telescope
        -- Uncomment the following to use telescope instead of vim.ui.select:
        --
        -- vim.keymap.set('n', '<leader>gws', worktree_picker, { desc = 'Switch worktree (Telescope)' })
      end

      return opts
    end,
  },

  -- Optional: Better notifications with nvim-notify
  {
    "rcarriga/nvim-notify",
    optional = true,
    opts = function(_, opts)
      -- nvim-notify will automatically be used by vim.notify
      -- which is used by the worktree plugin
      return opts
    end,
  },
}
