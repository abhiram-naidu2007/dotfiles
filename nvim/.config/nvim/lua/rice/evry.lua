-- <Space>fe: every file on the disk, as you type (the `evry` index behind the desktop launcher).
-- Same query language: words, notes/ , pdf: img: dir: ext:rs
local M = {}

function M.pick()
  Snacks.picker.pick({
    title = "Everything",
    live = true,
    supports_live = true,
    format = "file",
    finder = function(_, ctx)
      return require("snacks.picker.source.proc").proc(
        ctx:opts({
          cmd = "evry",
          args = { "-l", "400", "--", ctx.filter.search },
          transform = function(item) item.file = item.text end,
        }),
        ctx
      )
    end,
  })
end

return M
