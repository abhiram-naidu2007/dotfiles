local o = vim.opt

-- look
o.number = true
o.relativenumber = true      -- 5j, 12k, d3j: the distance is always on screen
o.cursorline = true
o.signcolumn = "yes"
o.termguicolors = true
o.showmode = false           -- the status line shows it
o.laststatus = 3             -- one status line for all windows
o.cmdheight = 1
o.pumheight = 12
o.winborder = "rounded"
o.scrolloff = 6
o.sidescrolloff = 8
o.wrap = false
o.linebreak = true           -- when wrap is on (<Space>uw), break at words
o.smoothscroll = true
o.list = true
o.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
o.fillchars = { eob = " ", fold = " ", foldopen = "▾", foldclose = "▸", foldsep = " " }
o.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"

-- editing
o.expandtab = true           -- spaces by default; guess-indent.nvim follows each file's own style
o.shiftwidth = 4
o.tabstop = 4
o.softtabstop = 4
o.shiftround = true
o.smartindent = true
o.breakindent = true
o.virtualedit = "block"      -- Ctrl-v can select past the end of short lines
o.formatoptions = "jcroqlnt"
o.clipboard = "unnamedplus"  -- y and p use the system clipboard
o.mouse = "a"
o.confirm = true             -- ask instead of failing on :q with unsaved changes
o.undofile = true            -- undo survives closing the file
o.undolevels = 10000
o.swapfile = false
o.spelllang = { "en" }

-- search
o.ignorecase = true
o.smartcase = true           -- a capital letter makes the search case sensitive
o.inccommand = "split"       -- :s/old/new shows every change live, before Enter
o.grepprg = "rg --vimgrep --smart-case"
o.grepformat = "%f:%l:%c:%m"

-- windows
o.splitright = true
o.splitbelow = true
o.splitkeep = "screen"

-- timing
o.updatetime = 250
o.timeoutlen = 350           -- how long the key-hint popup waits

-- folds follow the syntax tree; everything starts open
o.foldmethod = "expr"
o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
o.foldtext = ""
o.foldlevel = 99

o.shortmess:append({ I = true, c = true, C = true, W = true })
o.completeopt = "menu,menuone,noselect"
o.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" }

vim.filetype.add({ extension = { h = "c", typ = "typst" } })

vim.diagnostic.config({
  severity_sort = true,
  virtual_text = { spacing = 2, prefix = "●" },
  float = { source = true },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "\u{f057}",
      [vim.diagnostic.severity.WARN] = "\u{f071}",
      [vim.diagnostic.severity.INFO] = "\u{f05a}",
      [vim.diagnostic.severity.HINT] = "\u{f0eb}",
    },
  },
})
