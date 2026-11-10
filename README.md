# dotfiles

Ubuntu 26.04, X11. i3 + polybar + rofi + dunst + picom + ghostty + fish/starship + zathura.
One palette for everything, read from the wallpaper (accent hues only; lightness and contrast are fixed in OKLCH), in three moods: **night**, **day**, **paper**.

## Install on a fresh machine
```
git clone <this repo> ~/dotfiles && cd ~/dotfiles
./install.sh --dry-run all                          # print what would happen
./install.sh packages link build extras theme user  # desktop (system = SDDM login, optional)
```
Each step is idempotent. `link` moves any clashing file to `.backup/<date>/` first. Undo a package: `stow -D -t ~ <pkg>`.

## Everyday
| Key | What |
|---|---|
| Super+Space | launcher: **Apps**. Ctrl+Tab moves to Files, Calc, Windows and keeps what you typed |
| Super+O | **Files**: every file on the disk, as you type (like Everything on Windows) |
| Super+D | **Documents**: PDFs, newest first; Enter opens zathura |
| Super+= | **Calc**: qalc answers while you type; Enter copies. `=2^10` works in the Files tab too |
| Super+T | mood: night, day, paper. Super+Shift+T: mood and wallpaper menu |
| Super+Ctrl+W | wallpaper picker. Super+Ctrl+A: draw a new mathematical wallpaper |
| Super+/ | every key (live list); also `docs/i3-survival.txt` |

- Look: `rice` (see `rice help`). Never edit generated files (`colors.*`, `starship.toml`, `gtk.css`, `nvim/colors/rice.lua` ...): edit `theme/templates/*` and run `rice`.
- Wallpapers: anything in `wallpaper/` or `~/Pictures/wallpapers/`. Preview a palette: `theme/apply.py --check --mode day IMAGE`.
- Validate i3 after edits: `i3 -C -c ~/.config/i3/config`, reload with Super+Shift+C.
- Rollback to XFCE: choose "Xfce Session" in SDDM; nothing there was modified.

## File search (`evry/`)
`evry index` walks the disk (about 850 000 entries in 2.6 s) and writes one flat file. Each query memory-maps it and runs a SIMD substring scan over every name: about 12 ms, no daemon, nothing kept in RAM. A systemd user timer refreshes the index every 20 minutes at idle priority; the launcher also refreshes it in the background.

- Words: `thesis pdf` (all must match, at least one in the file name). A capital letter makes a word case sensitive.
- Folders: `notes/` (anything inside a folder named like that), `docs/intro`.
- Filters: `pdf: doc: img: vid: audio: code: zip: dir: file: home: sys: ext:rs *.png`. Without a plain word the newest come first.
- Ranking: name matches beat path matches; your own files beat system files and package caches; recent and often-opened files rise.
- Launcher keys: Enter open, Shift+Enter show in folder, Ctrl+Y copy path, Ctrl+T terminal there, Ctrl+O edit in Neovim (`rofi/.config/rofi/scripts/act.sh`).
- Terminal: `evry WORDS`, or `ev` in fish for the same search live in fzf with a preview.
- Settings: `~/.config/evry/config` (`skip PATH`, `skip-name NAME`, `junk-name NAME`, `root PATH`).

`evry/rofi/evry.c` builds two rofi modes (`files.so`, `calc.so`) that ask a helper on every keystroke and replace the list when it answers.

## Moods (`rice mode night|day|paper|next`)
| Mood | Base | Extra |
|---|---|---|
| night | near-black, pastel accents | |
| day | near-white, deeper accents | GTK apps switch to the light theme live (xsettingsd) |
| paper | cream and ink, fixed palette | the wallpaper is reprinted in ink; picom runs every window through an e-ink shader (`picom/.config/picom/shaders/paper.glsl`); zathura reads like a book |

A change reaches open windows at once: polybar, i3, dunst, ghostty, fish, Neovim (colorscheme `rice`), zathura, GTK apps, cava. Thorium picks its theme up on restart.

## Layout
| Dir | What |
|---|---|
| `i3/` | window manager config and scripts (power menu, screenshot, key list, browser profile picker, display layouts, showcase, compositor start) |
| `polybar/ rofi/ dunst/ picom/ ghostty/ fish/ gtk/ zathura/ fastfetch/` | bar, launcher, notifications, compositor, terminal, shell, cursor, PDF reader, system info |
| `evry/` | file index + search (Rust) and the live rofi tabs (C). `make -C evry install` |
| `rice/` | `rice` (wallpaper, mood, math art, menus), `rice-greet` (the Pokémon and the line of mathematics in each new terminal), `rice-preview`, `math.txt` |
| `art/` | `mathart.py`: wallpapers from mathematics (Clifford attractor, harmonograph, Julia set, Sacks prime spiral, Maurer rose), drawn in the palette's own colour system |
| `theme/` | `apply.py [--mode M] WALLPAPER`: pywal16 hues -> OKLCH palette -> every file in `templates/` rendered into `~/.config` |
| `wallpaper/` | the day and night pictures (`rice wall auto` swaps them at 06:00 / 18:00 via `systemd/`) |
| `lockscreen/` | `lock.sh` (i3lock): one lock for Super+G, idle, suspend |
| `mochi/` | the desktop cat (Super+N) |
| `apps/` | desktop entry: text files open in Neovim inside Ghostty |
| `sddm/` | Dog Samurai login theme (video re-encoded to 3 MB) |
| `docs/` | `i3-survival.txt` (keys), `fish.md` (shell cheat sheet) |

Not in the repo: Pokémon sprites (`~/.local/share/pokemon-colorscripts`, fetched by `install.sh extras`) and the pictures in `~/Pictures/wallpapers`.

## Cost
Nothing new runs all the time except xsettingsd (idle, 1 MB). Blur is on for rofi only, so it costs nothing until a menu is open. The paper shader is a few arithmetic operations per pixel and is loaded only in paper mood. The terminal greeting takes 3 ms.
