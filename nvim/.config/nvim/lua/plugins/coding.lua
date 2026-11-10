-- Understanding code: syntax tree, completion, formatting.
return {
  -- treesitter: real parsing for highlight, indent, folds and text objects
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "TSInstall", "TSUpdate", "TSInstallInfo" },
    dependencies = { { "nvim-treesitter/nvim-treesitter-textobjects", branch = "master" } },
    main = "nvim-treesitter.configs",
    opts = {
      ensure_installed = {
        "bash", "c", "cpp", "css", "diff", "fish", "gitcommit", "html", "javascript", "json", "lua", "luadoc",
        "markdown", "markdown_inline", "python", "query", "regex", "rust", "toml", "typescript", "typst", "vim", "vimdoc", "yaml",
      },
      auto_install = true,
      highlight = { enable = true },
      indent = { enable = true },
      -- Ctrl+Space grows the selection one syntax node at a time, Backspace shrinks it
      incremental_selection = {
        enable = true,
        keymaps = { init_selection = "<C-space>", node_incremental = "<C-space>", scope_incremental = false, node_decremental = "<bs>" },
      },
      textobjects = {
        move = {
          enable = true,
          set_jumps = true,
          goto_next_start = { ["]f"] = "@function.outer", ["]c"] = "@class.outer", ["]a"] = "@parameter.inner" },
          goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer", ["[a"] = "@parameter.inner" },
        },
        swap = {
          enable = true,
          swap_next = { ["<leader>cl"] = "@parameter.inner" },
          swap_previous = { ["<leader>ch"] = "@parameter.inner" },
        },
      },
    },
  },

  -- completion: Enter accepts, Tab / Shift+Tab walk the list and snippet fields,
  -- Ctrl+Space opens it by hand, Ctrl+E closes it
  {
    "saghen/blink.cmp",
    version = "1.*",
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = { "rafamadriz/friendly-snippets" },
    opts = {
      keymap = {
        preset = "enter",
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
      },
      appearance = { nerd_font_variant = "mono" },
      completion = {
        list = { selection = { preselect = false, auto_insert = true } },
        documentation = { auto_show = true, auto_show_delay_ms = 250 },
        menu = { draw = { treesitter = { "lsp" } } },
      },
      signature = { enabled = true },
      sources = {
        default = { "lazydev", "lsp", "path", "snippets", "buffer" },
        providers = { lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 } },
      },
      cmdline = { completion = { menu = { auto_show = true } } },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
  },

  -- formatting: <Space>cf formats now; <Space>uf turns format-on-save on or off (off at start)
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    keys = { { "<leader>cf", function() require("conform").format({ async = true, lsp_format = "fallback" }) end, mode = { "n", "x" }, desc = "Format file / selection" } },
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        python = { "ruff_organize_imports", "ruff_format" },
        rust = { "rustfmt" },
        c = { "clang-format" },
        cpp = { "clang-format" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        fish = { "fish_indent" },
        typst = { "typstyle" },
      },
      format_on_save = function()
        if vim.g.autoformat then
          return { timeout_ms = 1500, lsp_format = "fallback" }
        end
      end,
    },
  },
}
