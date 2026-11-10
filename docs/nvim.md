# Neovim: map of this config

Config: `~/dotfiles/nvim/.config/nvim` (linked to `~/.config/nvim`). 31 plugins, about 25 ms to start;
almost everything loads on first use. Old config: `~/dotfiles/.backup/2026-11-10/nvim`.

**Lost?** Press `Space` and wait: a popup lists every key that can follow. `Space f k` searches all keys.
`Space t l` lists tricks. `:Lazy` shows plugins, `:Mason` language servers, `:checkhealth` problems.

## Daily keys (`Space` = leader)
| Keys | What |
|---|---|
| `Space Space` | find a file in this project |
| `Space /` | search text in all files |
| `Space ,` or `Tab` / `Shift+Tab` | switch buffer |
| `Space e` or `Ctrl+N` | file tree. `-` opens the current folder as a buffer (rename = edit the name, `dd` deletes, `:w` applies) |
| `Space f e` | **Everything**: any file on the disk (same index as the desktop launcher; `pdf:` `notes/` work) |
| `Space f r` `f h` `f k` `f s` `f d` `f u` | recent files, help, key maps, symbols, problems, undo history |
| `Space w` / `Ctrl+S` | write |
| `Space x` | close buffer |
| `Space r` | **run this file** (python, rust, c, c++, lua, sh, fish, js). `input.txt` beside it is fed in. In a `.typ` file: live PDF in zathura |
| `Ctrl+/` | terminal (again to hide). `Esc Esc` leaves terminal mode |
| `Space s v` `s h` `s x` `s e` | split right, split below, close split, equal sizes. `Ctrl+h j k l` moves between splits |
| `s` + two characters | jump anywhere on screen (flash). `S` selects by syntax node |
| `gd` `grr` `K` `grn` `gra` | definition, references, docs, rename, code action |
| `Space c f` | format. `Space u f` toggles format-on-save (off at start) |
| `Space c d` | explain the problem on this line. `]d` `[d` next / previous problem |
| `Space g g` | lazygit. `]h` `[h` next / previous change, `Space g h` show it, `Space g r` undo it, `Space g b` blame |
| `Space d b` `d c` `d o` `d i` | debugger (Python): breakpoint, start / continue, step over, step into |
| `Space u …` | toggles: `w` wrap, `s` spelling, `d` diagnostics, `h` inlay hints, `z` zen, `a` animations |
| `Space q s` | restore the session of this folder |

Completion: `Enter` accepts, `Tab` / `Shift+Tab` walk the list, `Ctrl+Space` opens it, `Ctrl+E` closes it.

## Trainers (`Space t`)
| Keys | What |
|---|---|
| `Space t t` | one trick to practise (also on the start screen) |
| `Space t l` | all tricks, searchable (`lua/rice/tricks.lua`: add your own) |
| `Space t h` | habit hints on / off: after `jjjjj` or arrow keys it suggests the shorter motion. It never blocks a key |
| `Space t p` | show where `w b e ^ $ %` and `{ }` would land, as faint marks under the line |
| `Space t g` | motion practice game (`:VimBeGood`) |
| `Space t k` | this file |

## Ladder
Work one rung at a time; a rung is done when you use it without thinking.
1. **Words, not characters**: `w b e`, `0 ^ $`, `f t ; ,`, counts (`3w`, `5j`: relative numbers are in the margin).
2. **Verb + noun**: `d c y` with `iw i" i( ip`, and `a` versions. `ciw`, `ci"`, `dap`, `yip`. Then `.` to repeat.
3. **Search is a motion**: `/word`, `*`, `n`; `d/word`, `cgn` + `.`. `s` + two characters for anything on screen.
4. **Structure**: `daf` `cia` `vif` (function, argument), `Ctrl+Space` to grow a selection, `]f [f`, `gS`, `ysiw"` `cs"'` `ds"`.
5. **Registers and macros**: `"0p`, `"ay`, `Ctrl+R` in insert; `qa … q`, `@a`, `:'<,'>normal @a`.
6. **The command line**: `:%s/old/new/gc` (live preview), `:g/pat/d`, `:g/pat/normal …`, `:'<,'>!sort`, `q:`.
7. **Lists**: `Space /` then `Ctrl+Q` sends hits to quickfix; `:cdo s/a/b/ | update` changes them all.
8. **Jumps and marks**: `Ctrl+O` `Ctrl+I`, `g;`, `gi`, `ma` `'a`, `Ctrl+^`.

## Layout
| File | What |
|---|---|
| `init.lua` | entry: loads the four `config` files |
| `lua/config/options.lua` `keymaps.lua` `autocmds.lua` `lazy.lua` | settings, keys without a plugin, automatic behaviour, plugin manager |
| `lua/plugins/ui.lua` | snacks (start screen, pickers, tree, notifications, terminal), which-key, lualine, icons, smear cursor, markdown, drop |
| `lua/plugins/editor.lua` | mini (text objects, surround, pairs, move, split/join), flash, oil, gitsigns, sessions, the trainers |
| `lua/plugins/coding.lua` | treesitter, completion (blink), formatting (conform) |
| `lua/plugins/lsp.lua` | language servers: lua, python (basedpyright + ruff), rust, c/c++, typst, bash |
| `lua/plugins/tools.lua` | debugger |
| `lua/rice/` | own code: `run.lua` `evry.lua` `tricks.lua` `typst.lua` |
| `colors/rice.lua`, `lua/lualine/themes/rice.lua` | generated from the desktop palette by `rice`; follow night / day / paper live |

Add a plugin: a new table in one of `lua/plugins/*.lua`, with the key, command or event that should load it.
