-- What you see: start screen, pickers, notifications, key hints, status line, motion.
return {
  -- snacks: one plugin for the start screen, fuzzy pickers, file tree, notifications,
  -- indent guides, smooth scrolling, terminal, lazygit and the toggles under <Space>u.
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      bigfile = { enabled = true },      -- huge files open without syntax work
      quickfile = { enabled = true },    -- `nvim file` paints the file before plugins load
      input = { enabled = true },
      notifier = { enabled = true, timeout = 3500 },
      indent = { enabled = true, animate = { duration = { step = 15, total = 200 } } },
      scope = { enabled = true },
      scroll = { enabled = true },
      statuscolumn = { enabled = true },
      words = { enabled = true },        -- other uses of the word under the cursor; ]] and [[ jump
      explorer = { enabled = true, replace_netrw = false },
      picker = {
        enabled = true,
        sources = { explorer = { hidden = true } },
        win = { input = { keys = { ["<Esc>"] = { "close", mode = { "n", "i" } } } } },
      },
      dashboard = {
        width = 60,
        preset = {
          keys = {
            { icon = "\u{f002} ", key = "f", desc = "Find file", action = ":lua Snacks.dashboard.pick('files')" },
            { icon = "\u{f0c5} ", key = "r", desc = "Recent files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = "\u{f022} ", key = "g", desc = "Search in files", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = "󰈞 ", key = "e", desc = "Everything on the disk", action = ":lua require('rice.evry').pick()" },
            { icon = "\u{f15b} ", key = "n", desc = "New file", action = ":ene | startinsert" },
            { icon = "\u{f1da} ", key = "s", desc = "Restore last session", section = "session" },
            { icon = "\u{f0eb} ", key = "t", desc = "Tricks to practise", action = ":lua require('rice.tricks').pick()" },
            { icon = "\u{f013} ", key = "c", desc = "This config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = "\u{f011} ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
        sections = {
          -- a wild Pokémon (rice-greet picks one that fits; cached, so it costs nothing to draw)
          { section = "terminal", cmd = "rice-greet --sprite 14 60", height = 15, padding = 1, random = 60, ttl = 3600 },
          { section = "keys", gap = 0, padding = 1 },
          function()
            local keys, what = require("rice.tricks").random()
            return {
              align = "center",
              padding = 1,
              text = { { keys, hl = "SnacksDashboardKey" }, { "   " .. what, hl = "SnacksDashboardDesc" } },
            }
          end,
          { section = "startup" },
        },
      },
    },
    keys = {
      -- find
      { "<leader><space>", function() Snacks.picker.smart() end, desc = "Find files" },
      { "<leader>/", function() Snacks.picker.grep() end, desc = "Search in files" },
      { "<leader>,", function() Snacks.picker.buffers() end, desc = "Open buffers" },
      { "<leader>:", function() Snacks.picker.command_history() end, desc = "Command history" },
      { "<leader>ff", function() Snacks.picker.files() end, desc = "Files" },
      { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent files" },
      { "<leader>fg", function() Snacks.picker.grep() end, desc = "Grep" },
      { "<leader>fw", function() Snacks.picker.grep_word() end, mode = { "n", "x" }, desc = "Word under cursor / selection" },
      { "<leader>fl", function() Snacks.picker.lines() end, desc = "Lines of this buffer" },
      { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Config files" },
      { "<leader>fh", function() Snacks.picker.help() end, desc = "Help pages" },
      { "<leader>fk", function() Snacks.picker.keymaps() end, desc = "Key maps" },
      { "<leader>fd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
      { "<leader>fs", function() Snacks.picker.lsp_symbols() end, desc = "Symbols in this file" },
      { "<leader>fS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "Symbols in the project" },
      { "<leader>ft", function() Snacks.picker.grep({ search = [[\b(TODO|FIXME|HACK|NOTE)\b]], regex = true, live = false }) end, desc = "TODO / FIXME / NOTE" },
      { "<leader>fu", function() Snacks.picker.undo() end, desc = "Undo history" },
      { "<leader>fm", function() Snacks.picker.marks() end, desc = "Marks" },
      { "<leader>fj", function() Snacks.picker.jumps() end, desc = "Jump list" },
      { "<leader>fq", function() Snacks.picker.qflist() end, desc = "Quickfix list" },
      { '<leader>f"', function() Snacks.picker.registers() end, desc = "Registers" },
      { "<leader>fn", function() Snacks.picker.notifications() end, desc = "Notifications" },
      { "<leader>fp", function() Snacks.picker.projects() end, desc = "Projects" },
      { "<leader>fR", function() Snacks.picker.resume() end, desc = "Reopen the last picker" },
      -- files
      { "<leader>e", function() Snacks.explorer() end, desc = "File tree" },
      { "<C-n>", function() Snacks.explorer() end, desc = "File tree" },
      { "<leader>x", function() Snacks.bufdelete() end, desc = "Close buffer" },
      { "<leader>bo", function() Snacks.bufdelete.other() end, desc = "Close the other buffers" },
      { "<leader>cR", function() Snacks.rename.rename_file() end, desc = "Rename file (updates imports)" },
      -- git
      { "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit" },
      { "<leader>gl", function() Snacks.picker.git_log() end, desc = "Log" },
      { "<leader>gf", function() Snacks.picker.git_log_file() end, desc = "Log of this file" },
      { "<leader>gs", function() Snacks.picker.git_status() end, desc = "Status" },
      { "<leader>gd", function() Snacks.picker.git_diff() end, desc = "Changed hunks" },
      { "<leader>gB", function() Snacks.gitbrowse() end, mode = { "n", "x" }, desc = "Open on GitHub" },
      -- terminal, focus, notifications
      { "<C-/>", function() Snacks.terminal() end, mode = { "n", "t" }, desc = "Terminal" },
      { "<C-_>", function() Snacks.terminal() end, mode = { "n", "t" }, desc = "which_key_ignore" },
      { "<leader>un", function() Snacks.notifier.hide() end, desc = "Dismiss notifications" },
      { "]]", function() Snacks.words.jump(vim.v.count1) end, mode = { "n", "t" }, desc = "Next use of this word" },
      { "[[", function() Snacks.words.jump(-vim.v.count1) end, mode = { "n", "t" }, desc = "Previous use of this word" },
    },
    init = function()
      -- no buffer tabs over the start screen
      vim.api.nvim_create_autocmd("User", { pattern = "SnacksDashboardOpened", callback = function() vim.o.showtabline = 0 end })
      vim.api.nvim_create_autocmd("User", { pattern = "SnacksDashboardClosed", callback = function() vim.o.showtabline = 2 end })
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        callback = function()
          Snacks.toggle.option("wrap", { name = "wrap" }):map("<leader>uw")
          Snacks.toggle.option("spell", { name = "spelling" }):map("<leader>us")
          Snacks.toggle.option("relativenumber", { name = "relative numbers" }):map("<leader>ul")
          Snacks.toggle.diagnostics():map("<leader>ud")
          Snacks.toggle.inlay_hints():map("<leader>uh")
          Snacks.toggle.zen():map("<leader>uz")
          Snacks.toggle.dim():map("<leader>uD")
          Snacks.toggle.animate():map("<leader>ua")
          Snacks.toggle.scroll():map("<leader>uS")
          Snacks.toggle({
            name = "format on save",
            get = function() return vim.g.autoformat == true end,
            set = function(on) vim.g.autoformat = on end,
          }):map("<leader>uf")
        end,
      })
    end,
  },

  -- which-key: press <Space> (or g, z, ], [, ", ') and wait: it lists what can follow.
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix",
      spec = {
        { "<leader>f", group = "find" },
        { "<leader>s", group = "split" },
        { "<leader>g", group = "git" },
        { "<leader>c", group = "code" },
        { "<leader>d", group = "debug" },
        { "<leader>u", group = "toggle" },
        { "<leader>t", group = "trainer" },
        { "<leader>q", group = "session" },
        { "<leader>b", group = "buffer" },
        { "<leader>x", group = "close / lists" },
      },
    },
    keys = { { "<leader>?", function() require("which-key").show({ global = false }) end, desc = "Keys of this buffer" } },
  },

  -- status line and buffer tabs, drawn as pills like the desktop bar
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function()
      local left, right = "\u{e0b6}", "\u{e0b4}"
      local theme = pcall(require, "lualine.themes.rice") and "rice" or "auto"
      return {
        options = {
          theme = theme,
          globalstatus = true,
          component_separators = "",
          section_separators = { left = right, right = left },
          disabled_filetypes = { statusline = { "snacks_dashboard" } },
        },
        sections = {
          lualine_a = { { "mode", separator = { left = left }, right_padding = 2 } },
          lualine_b = { "branch", { "diff", symbols = { added = "\u{f0fe} ", modified = "\u{f14b} ", removed = "\u{f146} " } } },
          lualine_c = { { "filename", path = 1 }, "diagnostics" },
          lualine_x = {
            { function() return "rec @" .. vim.fn.reg_recording() end, cond = function() return vim.fn.reg_recording() ~= "" end },
            { "lsp_status", ignore_lsp = {} },
            "filetype",
          },
          lualine_y = { "progress" },
          lualine_z = { { "location", separator = { right = right }, left_padding = 2 } },
        },
        tabline = {
          lualine_a = { { "buffers", separator = { left = left, right = right }, symbols = { alternate_file = "" }, max_length = function() return vim.o.columns end } },
        },
        extensions = { "lazy", "mason", "oil", "quickfix" },
      }
    end,
  },

  -- icons (also answers for nvim-web-devicons, so only one icon set is loaded)
  {
    "echasnovski/mini.icons",
    opts = {},
    init = function()
      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end
    end,
  },

  -- the cursor leaves a short smear when it jumps, so the eye can follow it
  { "sphamba/smear-cursor.nvim", event = "VeryLazy", opts = { stiffness = 0.8, trailing_stiffness = 0.55, distance_stop_animating = 0.5 } },

  -- markdown rendered in place (headings, tables, code blocks, check boxes)
  { "MeanderingProgrammer/render-markdown.nvim", ft = { "markdown" }, opts = {} },

  -- after five idle minutes, leaves / snow / stars drift over the buffer
  { "folke/drop.nvim", event = "VeryLazy", opts = { theme = "auto", screensaver = 1000 * 60 * 5, filetypes = {} } },
}
