-- Language servers: go to definition, rename, errors as you type.
-- Neovim 0.11 already maps: K docs, grn rename, gra code action, grr references,
-- gri implementation, gO symbols, ]d [d next / previous problem, Ctrl+S signature (insert).
-- mason installs the servers (<Space>m); the ones listed below are installed by themselves.
return {
  { "mason-org/mason.nvim", cmd = "Mason", build = ":MasonUpdate", opts = { ui = { border = "rounded" } } },

  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason-org/mason.nvim",
      {
        "mason-org/mason-lspconfig.nvim",
        opts = { ensure_installed = { "lua_ls", "ruff", "clangd", "rust_analyzer", "tinymist", "bashls" } },
      },
    },
    config = function()
      vim.lsp.config("lua_ls", {
        settings = { Lua = { workspace = { checkThirdParty = false }, completion = { callSnippet = "Replace" }, hint = { enable = true } } },
      })
      vim.lsp.config("basedpyright", {
        settings = { basedpyright = { analysis = { typeCheckingMode = "standard" } } },
      })
      vim.lsp.config("tinymist", { settings = { formatterMode = "typstyle" } })
      -- Python types: basedpyright comes from `uv tool install basedpyright` (mason would need
      -- python3-venv, which Ubuntu does not ship by default)
      if vim.fn.executable("basedpyright-langserver") == 1 then
        vim.lsp.enable("basedpyright")
      end

      -- formatters, installed once in the background
      local registry = require("mason-registry")
      registry.refresh(function()
        for _, name in ipairs({ "stylua", "shfmt", "typstyle" }) do
          local ok, pkg = pcall(registry.get_package, name)
          if ok and not pkg:is_installed() then
            pkg:install()
          end
        end
      end)

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("rice_lsp", { clear = true }),
        callback = function(ev)
          local function map(lhs, rhs, desc) vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = desc }) end
          map("gd", function() Snacks.picker.lsp_definitions() end, "Go to definition")
          map("gD", function() Snacks.picker.lsp_declarations() end, "Go to declaration")
          map("gy", function() Snacks.picker.lsp_type_definitions() end, "Go to the type")
          map("grr", function() Snacks.picker.lsp_references() end, "References")
          map("gri", function() Snacks.picker.lsp_implementations() end, "Implementations")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("<leader>cr", vim.lsp.buf.rename, "Rename symbol")
          map("<leader>ci", vim.lsp.buf.incoming_calls, "Who calls this")
          map("<leader>co", vim.lsp.buf.outgoing_calls, "What this calls")
        end,
      })
    end,
  },

  -- completion and docs for the Neovim Lua API while editing this config
  { "folke/lazydev.nvim", ft = "lua", opts = { library = { { path = "${3rd}/luv/library", words = { "vim%.uv" } }, { path = "snacks.nvim", words = { "Snacks" } } } } },
}
