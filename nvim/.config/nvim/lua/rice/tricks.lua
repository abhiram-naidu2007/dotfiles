-- Tricks to practise. One is shown on the start screen; <Space>tt shows another,
-- <Space>tl lists them all (type to filter). Pick one, use it ten times today.
-- Ordered from daily bread to showing off.
local M = {}

M.list = {
  -- moving
  { "w b e ge", "next word, back a word, end of word, end of the previous word" },
  { "f{c} t{c} ; ,", "jump onto / just before a character on the line; ; repeats, , goes back" },
  { "0 ^ $ g_", "line start, first non-blank, line end, last non-blank" },
  { "{ }", "previous / next blank line" },
  { "%", "jump to the matching bracket" },
  { "* #", "search the word under the cursor, forward / backward" },
  { "gg G 42G", "first line, last line, line 42" },
  { "H M L", "top, middle, bottom of the window" },
  { "Ctrl-o Ctrl-i", "back / forward through the places you jumped from" },
  { "g; g,", "back / forward through the places you edited" },
  { "gi", "insert again where you last left insert mode" },
  { "'' ``", "back to the line / the exact spot before the last jump" },
  { "ma 'a `a", "set mark a; jump to its line / its exact spot" },
  { "zz zt zb", "put the cursor line at the centre / top / bottom of the window" },
  { "s{c}{c}", "flash: jump to any spot on screen: two characters, then the label" },
  { "]f [f ]c [c", "next / previous function, next / previous class" },
  { "]h [h ]d [d", "next / previous changed hunk, next / previous problem" },
  -- operators and text objects
  { "ciw", "change the word under the cursor, from anywhere inside it" },
  { 'ci" ci( ci{ cit', "change inside quotes, parentheses, braces, an HTML tag" },
  { "dap yip", "delete a paragraph with its blank line; yank a paragraph" },
  { "daf vif", "delete a whole function; select a function body" },
  { "cia daa", "change an argument; delete an argument and its comma" },
  { "dt, ct)", "delete up to a comma; change up to a closing parenthesis" },
  { "D C Y", "delete, change, yank from here to the end of the line" },
  { "cc", "change the whole line and keep its indent" },
  { "xp ddp", "swap two characters; swap two lines" },
  { "J gJ", "join the next line with / without a space" },
  { "gUiw guiw g~~", "upper-case a word, lower-case a word, flip the case of a line" },
  { "> < =", "indent, dedent, re-indent; with a motion: >ap, =ip, gg=G" },
  { "gcc gc{motion}", "comment a line / a motion: gcap comments a paragraph" },
  { 'ysiw" cs"\' ds"', "surround a word with quotes; change them to '; delete them" },
  { "gS", "split one line of arguments into one per line, or join them back" },
  { "Alt-j Alt-k", "move the line (or the selection) down / up" },
  { ".", "repeat the last change: make one good edit, then . . ." },
  { "u Ctrl-r U", "undo, redo, undo every change on the line" },
  { ":earlier 5m  :later 5m", "travel back / forward in time by minutes" },
  -- visual
  { "v V Ctrl-v", "select characters, whole lines, a rectangle" },
  { "o (visual)", "jump to the other end of the selection" },
  { "gv", "reselect the last selection" },
  { "Ctrl-space", "grow the selection one syntax node at a time; Backspace shrinks it" },
  { "Ctrl-v jj I text Esc", "type the same text at the start of every line of a block" },
  { "Ctrl-v jj $ A text Esc", "append text to the end of every selected line" },
  { "vip :sort", "sort the lines of a paragraph" },
  { "Ctrl-a Ctrl-x", "add / subtract 1 from the number under the cursor" },
  { "g Ctrl-a (visual)", "turn a column of 0 0 0 0 into 1 2 3 4" },
  -- registers and macros
  { '"ayy "ap', "yank a line into register a; paste from it" },
  { '"0p', "paste the last yank, even after you deleted something" },
  { "Ctrl-r {reg} (insert)", "paste a register while typing; Ctrl-r = is a calculator" },
  { "Ctrl-r Ctrl-w (command line)", "insert the word under the cursor" },
  { "qa ... q   @a   @@", "record a macro into a; run it; run it again" },
  { "5@a   :'<,'>normal @a", "run a macro 5 times; run it on every selected line" },
  { "qA ... q", "append more keys to macro a" },
  -- search and replace
  { "/word  n N", "search; next / previous match" },
  { "cgn then .", "change the next match; . changes each following one" },
  { ":%s/old/new/gc", "replace in the whole file, asking each time; the preview is live" },
  { ":'<,'>s/old/new/g", "replace inside the selection only" },
  { ":%s//new/g", "an empty pattern means: the last search" },
  { [[:s/\v(\w+) (\w+)/\2 \1/]], [[swap two words with capture groups; \v needs fewer backslashes]] },
  { "& g&", "repeat the last substitute on this line / on every line" },
  { ":g/pattern/d", "delete every line that matches" },
  { ":v/pattern/d", "delete every line that does not match" },
  { ":g/TODO/normal A !", "run normal-mode keys on every matching line" },
  { "Space cs", "substitute the word under the cursor, pattern already typed" },
  -- command line and files
  { ":w :q :x", "write, quit, write only if changed and quit (ZZ does the same)" },
  { "q: q/", "command / search history as a window you can edit and rerun" },
  { "@:", "repeat the last : command" },
  { ":r !date", "insert the output of a shell command" },
  { ":'<,'>!sort -u", "pass the selection through a shell command" },
  { ":%!jq .", "reformat the whole buffer with an external tool" },
  { "!ip", "filter a paragraph through a command (then type the command)" },
  { "gf gx", "open the file / the URL under the cursor" },
  { "Ctrl-^", "switch to the buffer you were in before" },
  { "-", "open the folder of this file as a buffer: rename by editing, dd deletes, :w applies" },
  { ":cdo s/a/b/ | update", "after a grep sent to quickfix: change every hit" },
  -- windows and folds
  { "Ctrl-w v s q o", "split right, split below, close the window, keep only this one" },
  { "Ctrl-h j k l", "move between windows" },
  { "Ctrl-w = _ |", "equal sizes, full height, full width" },
  { "Ctrl-w T", "move this window to a tab of its own" },
  { "za zR zM", "toggle a fold, open all, close all" },
  -- insert mode
  { "Ctrl-w Ctrl-u (insert)", "delete the word / the line before the cursor" },
  { "Ctrl-o {command} (insert)", "run one normal-mode command and stay in insert" },
  { "Ctrl-t Ctrl-d (insert)", "indent / dedent the current line" },
  { "Ctrl-k a* p* (insert)", "digraphs: a* is α, p* is π, DG is °, -> is →, RT is √, 2S is ²" },
  { "Ctrl-v u2202 (insert)", "insert any character by its code point: ∂" },
  -- language server
  { "K gd grr", "documentation, go to definition, list the references" },
  { "grn gra", "rename a symbol everywhere; code actions (quick fixes)" },
  { "Space cf", "format the file or the selection" },
  { "Space r", "save and run this file (input.txt beside it becomes its input)" },
}

function M.random()
  local t = M.list[math.random(#M.list)]
  return t[1], t[2]
end

function M.show()
  local keys, what = M.random()
  vim.notify(what, vim.log.levels.INFO, { title = keys, timeout = 8000 })
end

function M.pick()
  local items = {}
  for i, t in ipairs(M.list) do
    items[i] = { idx = i, text = t[1] .. "  " .. t[2], keys = t[1], what = t[2] }
  end
  Snacks.picker.pick({
    title = "Tricks",
    items = items,
    layout = { preset = "select" },
    format = function(item)
      return { { ("%-30s"):format(item.keys), "SnacksPickerSpecial" }, { item.what } }
    end,
    confirm = function(picker, item)
      picker:close()
      if item then
        vim.notify(item.what, vim.log.levels.INFO, { title = item.keys, timeout = 8000 })
      end
    end,
  })
end

math.randomseed(os.time())
return M
