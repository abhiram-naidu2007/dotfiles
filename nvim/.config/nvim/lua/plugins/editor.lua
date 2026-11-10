-- Moving and editing: text objects, surround, jumps, files as a buffer, git in the margin,
-- and the trainers that point out a better way to do what you just did.
return {
  -- mini.nvim: small modules, one repository
  {
    "echasnovski/mini.nvim",
    event = "VeryLazy",
    config = function()
      -- text objects: f function, c class (syntax tree), a argument, q quote, b bracket ...
      --   daf = delete a function, cia = change an argument, yiq = yank inside quotes
      local ai = require("mini.ai")
      ai.setup({
        n_lines = 500,
        custom_textobjects = {
          f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
          c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
        },
      })
      -- surround with the classic keys: ysiw" add, cs"' change, ds" delete, S in visual
      require("mini.surround").setup({
        mappings = { add = "ys", delete = "ds", replace = "cs", find = "", find_left = "", highlight = "", update_n_lines = "", suffix_last = "", suffix_next = "" },
        search_method = "cover_or_next",
      })
      vim.keymap.del("x", "ys")
      vim.keymap.set("x", "S", [[:<C-u>lua MiniSurround.add('visual')<CR>]], { silent = true, desc = "Surround selection" })
      vim.keymap.set("n", "yss", "ys_", { remap = true, desc = "Surround line" })
      require("mini.pairs").setup()        -- closes brackets and quotes
      require("mini.move").setup()         -- Alt+h j k l moves the line or the selection
      require("mini.splitjoin").setup()    -- gS: one line of arguments <-> one per line
      local hi = require("mini.hipatterns")
      hi.setup({
        highlighters = {
          fixme = { pattern = "%f[%w]()FIXME()%f[%W]", group = "MiniHipatternsFixme" },
          hack = { pattern = "%f[%w]()HACK()%f[%W]", group = "MiniHipatternsHack" },
          todo = { pattern = "%f[%w]()TODO()%f[%W]", group = "MiniHipatternsTodo" },
          note = { pattern = "%f[%w]()NOTE()%f[%W]", group = "MiniHipatternsNote" },
          hex_color = hi.gen_highlighter.hex_color(),   -- #a2bcfe is shown in its own colour
        },
      })
    end,
  },

  -- flash: s + two characters jumps anywhere on screen; S selects by syntax node
  {
    "folke/flash.nvim",
    opts = {},
    keys = {
      { "s", function() require("flash").jump() end, mode = { "n", "x", "o" }, desc = "Jump to (flash)" },
      { "S", function() require("flash").treesitter() end, mode = { "n", "o" }, desc = "Select a syntax node (flash)" },
      { "r", function() require("flash").remote() end, mode = "o", desc = "Operate somewhere else, come back (flash)" },
    },
  },

  -- oil: a folder is a buffer. Rename = edit the name, delete = dd, then :w applies it.
  {
    "stevearc/oil.nvim",
    lazy = false,
    opts = { view_options = { show_hidden = true }, skip_confirm_for_simple_edits = true, keymaps = { ["q"] = "actions.close" } },
    keys = { { "-", "<cmd>Oil<cr>", desc = "Open the folder of this file" } },
  },

  -- git: changed lines in the margin, hunks as text objects
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      on_attach = function(buf)
        local gs = require("gitsigns")
        local function map(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc }) end
        map("n", "]h", function() gs.nav_hunk("next") end, "Next changed hunk")
        map("n", "[h", function() gs.nav_hunk("prev") end, "Previous changed hunk")
        map("n", "<leader>gh", gs.preview_hunk_inline, "Show what changed here")
        map({ "n", "x" }, "<leader>ga", ":Gitsigns stage_hunk<cr>", "Stage hunk")
        map({ "n", "x" }, "<leader>gr", ":Gitsigns reset_hunk<cr>", "Undo hunk")
        map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Who wrote this line")
        map({ "o", "x" }, "ih", ":<C-u>Gitsigns select_hunk<cr>", "Changed hunk")
      end,
    },
  },

  -- follow each file's own indentation (tabs or spaces, 2 or 4 or 8)
  { "NMAC427/guess-indent.nvim", event = "BufReadPre", opts = {} },

  -- sessions: <Space>qs brings back the windows and buffers of this folder
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore the session of this folder" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore the last session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Do not save this session" },
    },
  },

  -- TRAINERS -------------------------------------------------------------
  -- hardtime: watches for habits (jjjjj, arrow keys, x x x x) and suggests the shorter way.
  -- It only hints, it never blocks a key.  <Space>th turns it off and on.
  {
    "m4xshen/hardtime.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      restriction_mode = "hint",
      disable_mouse = false,
      max_count = 5,
      -- the plugin's default blocks the arrow keys outright; false removes each default entry
      disabled_keys = { ["<Up>"] = false, ["<Down>"] = false, ["<Left>"] = false, ["<Right>"] = false },
      restricted_keys = {
        ["<Up>"] = { "n", "x" }, ["<Down>"] = { "n", "x" }, ["<Left>"] = { "n", "x" }, ["<Right>"] = { "n", "x" },
      },
      disabled_filetypes = { "lazy", "mason", "oil", "qf", "help", "snacks_dashboard", "snacks_picker_list", "snacks_picker_input", "snacks_terminal", "dap-repl" },
    },
    keys = { { "<leader>th", "<cmd>Hardtime toggle<cr>", desc = "Habit hints on / off" } },
  },
  -- precognition: shows where w b e ^ $ % and { } would land, as faint marks. <Space>tp
  {
    "tris203/precognition.nvim",
    opts = { startVisible = false },
    keys = { { "<leader>tp", function() require("precognition").toggle() end, desc = "Show where motions land" } },
  },
  -- a game for drilling motions: :VimBeGood
  { "ThePrimeagen/vim-be-good", cmd = "VimBeGood", keys = { { "<leader>tg", "<cmd>VimBeGood<cr>", desc = "Motion practice game" } } },
}
