-- Plugin manager. Every plugin is lazy: it loads on the key, command, file type
-- or event named in its spec, so start-up only pays for what the first screen needs.
-- :Lazy shows what is loaded and why; :Lazy profile shows where start-up time goes.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", "https://github.com/folke/lazy.nvim.git", lazypath })
  if vim.v.shell_error ~= 0 then
    error("could not clone lazy.nvim:\n" .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = { { import = "plugins" } },
  defaults = { lazy = true },
  install = { colorscheme = { "rice", "habamax" } },
  checker = { enabled = false },
  change_detection = { notify = false },
  ui = { border = "rounded" },
  performance = {
    rtp = { disabled_plugins = { "gzip", "netrwPlugin", "rplugin", "tarPlugin", "tohtml", "tutor", "zipPlugin" } },
  },
})

-- The desktop palette. Until `rice` has written it once, a built-in scheme stands in.
if not pcall(vim.cmd.colorscheme, "rice") then
  vim.cmd.colorscheme("habamax")
end
