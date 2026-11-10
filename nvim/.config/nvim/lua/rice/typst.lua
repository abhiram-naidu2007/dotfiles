-- Typst live preview: <Space>r in a .typ file compiles on every save and shows the PDF in
-- zathura, which reloads by itself. The watcher stops when the buffer closes or Neovim exits.
local M = {}
local jobs = {}

function M.watch()
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  local pdf = file:gsub("%.typ$", ".pdf")
  if jobs[buf] then
    vim.fn.jobstop(jobs[buf])
    jobs[buf] = nil
    return vim.notify("Typst preview stopped")
  end
  jobs[buf] = vim.fn.jobstart({ "typst", "watch", file, pdf }, {
    on_stderr = function(_, lines)
      local text = table.concat(lines, "\n")
      if text:find("error") then
        vim.schedule(function() vim.notify(text, vim.log.levels.ERROR, { title = "typst" }) end)
      end
    end,
    on_exit = function() jobs[buf] = nil end,
  })
  vim.defer_fn(function()
    if vim.uv.fs_stat(pdf) then
      vim.fn.jobstart({ "zathura", pdf }, { detach = true })
    end
  end, 900)
  vim.api.nvim_create_autocmd({ "BufDelete", "VimLeavePre" }, {
    buffer = buf,
    once = true,
    callback = function()
      if jobs[buf] then vim.fn.jobstop(jobs[buf]) end
    end,
  })
  vim.notify("Typst preview: compiles on save, <Space>r again stops it")
end

return M
