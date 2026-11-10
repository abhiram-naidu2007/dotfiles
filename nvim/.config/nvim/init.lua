-- Neovim, kept small on purpose: fast to start, easy to read, and built to teach.
-- Map of this config and every key: ~/dotfiles/docs/nvim.md   (inside nvim: <Space>tk)
--   lua/config   options, keys, autocommands, plugin manager
--   lua/plugins  one file per job: ui, editor, coding, lsp, tools
--   lua/rice     own code: run the file, search the whole disk, trick of the day, Typst preview
-- Colours: colors/rice.lua is written by ~/dotfiles/theme/apply.py (the desktop palette).
vim.loader.enable()
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
