# fish in 10 lines (vs bash)
- Type, then press -> (right arrow) to accept the grey suggestion; Alt+-> accepts one word.
- Up arrow after typing "git" = history search for commands starting with git.
- Variables: `set name value` (not `name=value`); use `$name`. Export: `set -gx NAME value`.
- Command substitution: `(cmd)` not `$(cmd)`.
- if/for end with `end` (no `fi`/`done`):  `for f in *.png; echo $f; end`
- `&&` and `||` work. Use `; and` / `; or` in old docs.
- Abbreviations expand when you press space: `gs` -> `git status`. List: `abbr`. Add: `abbr -a name 'cmd'`.
- Config: ~/.config/fish/config.fish (linked from ~/dotfiles/fish). Reload: `exec fish`.
- Help: `help <command>` opens the docs in the browser. Scripts you copy from the web are bash: run with `bash script.sh`.
- Back to bash any time: `bash`. Make fish the login shell later: `chsh -s /usr/bin/fish`.

## Added tools
- `ev [words]`: every file on the disk, live, with a preview. Enter open, Alt+Enter cd there, Ctrl+O edit, Ctrl+Y copy path.
- `z name`: jump to a folder you have visited (zoxide). `zi`: pick one from a list.
- Ctrl+R history search, Ctrl+T insert a file, Alt+C cd into a folder (fzf).
- `ls` `ll` `lt` are eza (icons, git column, tree); `cat` is bat (syntax colours). Both use the terminal's palette.
- `pokefetch`: system info beside a random Pokémon. `rice-greet`: the greeting again.
- `pdf file.pdf`: zathura.
