-- <Space>r: save and run the current file in a terminal below.
-- If input.txt sits next to the file, it is fed to the program (handy for contest problems).
local M = {}

local function root_with(name, from)
  local found = vim.fs.find(name, { upward = true, path = from })[1]
  return found and vim.fs.dirname(found)
end

-- file type -> shell command (%s = quoted file path)
local runners = {
  python = function(file, dir)
    local venv = root_with(".venv", dir)
    return (venv and (venv .. "/.venv/bin/python") or "python3") .. " %s"
  end,
  lua = function() return "nvim -l %s" end,
  sh = function() return "bash %s" end,
  bash = function() return "bash %s" end,
  fish = function() return "fish %s" end,
  javascript = function() return "node %s" end,
  rust = function(_, dir)
    local crate = root_with("Cargo.toml", dir)
    return crate and ("cd " .. vim.fn.shellescape(crate) .. " && cargo run") or "rustc -O %s -o /tmp/nvim-run && /tmp/nvim-run"
  end,
  c = function(_, dir)
    return root_with("Makefile", dir) and "make" or "gcc -O2 -Wall -Wextra %s -o /tmp/nvim-run -lm && /tmp/nvim-run"
  end,
  cpp = function() return "g++ -std=c++20 -O2 -Wall -Wextra %s -o /tmp/nvim-run && /tmp/nvim-run" end,
  typst = function() return nil end, -- handled below: live preview instead of a one-off run
}

function M.file()
  local file = vim.api.nvim_buf_get_name(0)
  local ft = vim.bo.filetype
  if file == "" then
    return vim.notify("Save the file first", vim.log.levels.WARN)
  end
  vim.cmd("silent update")
  if ft == "typst" then
    return require("rice.typst").watch()
  end
  local make = runners[ft]
  if not make then
    return vim.notify("No runner for file type '" .. ft .. "' (add one in lua/rice/run.lua)", vim.log.levels.WARN)
  end
  local dir = vim.fs.dirname(file)
  local cmd = make(file, dir):gsub("%%s", function() return vim.fn.shellescape(file) end)
  local input = dir .. "/input.txt"
  if vim.uv.fs_stat(input) and not cmd:find("^make") and not cmd:find("cargo run") then
    cmd = cmd .. " < " .. vim.fn.shellescape(input)
  end
  Snacks.terminal(cmd, { cwd = dir, interactive = false, auto_close = false, win = { position = "bottom", height = 0.35 } })
end

return M
