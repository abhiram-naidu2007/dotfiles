local function on(event, opts)
  opts.group = vim.api.nvim_create_augroup("rice_" .. (opts.name or event[1] or event), { clear = true })
  opts.name = nil
  vim.api.nvim_create_autocmd(event, opts)
end

-- flash what was yanked
on("TextYankPost", { callback = function() vim.hl.on_yank({ timeout = 160 }) end })

-- reopen a file where you left it
on("BufReadPost", {
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) and vim.bo[ev.buf].filetype ~= "gitcommit" then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- the file changed on disk (git, a formatter, another editor): reload it
on({ "FocusGained", "TermClose", "TermLeave" }, { name = "checktime", command = "checktime" })

-- keep splits even when the terminal is resized
on("VimResized", { command = "tabdo wincmd =" })

-- q closes windows that are only there to be read
on("FileType", {
  name = "close_with_q",
  pattern = { "help", "qf", "man", "checkhealth", "lspinfo", "notify", "startuptime", "git" },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true })
  end,
})

-- prose: wrap and spell-check
on("FileType", {
  name = "prose",
  pattern = { "markdown", "typst", "text", "gitcommit" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

-- two-space languages
on("FileType", {
  name = "indent2",
  pattern = { "lua", "json", "yaml", "toml", "html", "css", "javascript", "typescript", "typst", "markdown" },
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
  end,
})

-- :w into a folder that does not exist yet creates it
on("BufWritePre", {
  name = "mkdir",
  callback = function(ev)
    if not ev.match:match("^%w%w+:[\\/][\\/]") then
      vim.fn.mkdir(vim.fn.fnamemodify(vim.uv.fs_realpath(ev.match) or ev.match, ":p:h"), "p")
    end
  end,
})

-- `rice` changed the desktop palette (SIGUSR1): reload it here too
on("Signal", {
  pattern = "SIGUSR1",
  callback = function()
    if vim.g.colors_name ~= "rice" then
      return
    end
    package.loaded["lualine.themes.rice"] = nil
    vim.cmd.colorscheme("rice")
    local ok, lualine = pcall(require, "lualine")
    if ok then
      lualine.setup(lualine.get_config())
    end
  end,
})
