# dotfiles

Ubuntu 26.04, X11. i3 + polybar + rofi + dunst + picom + ghostty + fish/starship + zathura + Neovim.
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
| Super+U | **Web**: bookmarks of every browser profile; anything else is opened or searched |
| Super+= | **Calc**: qalc answers while you type; Enter copies. `=2^10` works in the Files tab too |
| Super+Shift+S | screenshot: drag an area or click a window. Super+Ctrl+S: capture menu. Super+Ctrl+R: record the screen (again to stop) |
| Super+C | clipboard history. Super+`: drop-down terminal |
| Super+T | mood: night, day, paper. Super+Shift+T: mood and wallpaper menu |
| Super+Ctrl+W | wallpaper picker: live and normal wallpapers. Super+Ctrl+A: draw a new mathematical wallpaper |
| Super+Ctrl+D | live wallpapers move / hold still. Super+Ctrl+N: next live wallpaper |
| Super+/ | **every key and command**, searchable (the launcher's Keys tab). Sources: the `## text` lines in the i3 config and `rice/.local/share/rice/keys.tsv`. Printed sheets: `docs/i3-survival.txt`, `docs/nvim.md` |

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

A change reaches open windows at once: polybar, i3, dunst, ghostty, fish, Neovim (colorscheme `rice`), zathura, GTK apps, cava, the live wallpaper, the browser's next new tab. Thorium's frame colours change on restart.

## Wallpapers: normal and live
There are two kinds, and `rice pick` (Super+Ctrl+W) shows both in one grid (click or Enter; the wheel or two fingers scroll):

- **Normal**: a picture, still. Put yours in `~/Pictures/wallpapers` (any depth) or `wallpaper/`. `rice wall PATH|next|prev|random|auto`.
- **Live**: a scene drawn by the graphics card, `rice scene NAME|next|none`. Scenes are the `.frag` files in `rice/.local/share/mathwall/scenes/` (linked to `~/.local/share/mathwall/scenes/`) and the built-in ones of the program in `mathwall/`. `rice live on|off|always|toggle` decides whether a live scene moves (off: a still frame of it). It moves only while the workspace is empty, on mains and with the screen on: nothing runs otherwise.

**Live or still:** the bar has a live button next to the mood icon (play + "live" = moving, pause + "still" = held, picture icon = a normal wallpaper is shown). Click it to switch; right click opens the picker; the wheel changes live wallpaper. Same on the keyboard: Super+Ctrl+D. In the picker it is the second tile. Choosing a picture shows the picture; choosing a live scene turns live on. Changing the mood never changes what is shown.

| Live scene | What |
|---|---|
| train | the sea railway at dusk (Spirited Away): clouds drift, the water ripples, the windows glow; the painting is otherwise left as painted |
| castle | the moving castle on the moor (Howl): storm clouds roll, steam rises from the stacks, the castle heaves, the grass bends |
| temple | a temple town across its tank, drawn in code: a seven-storey gopuram with barrel roof and pot finials, palms, hills, all mirrored in the water; dusk with oil lamps, or dawn with mist and birds |
| aizawa, lorenz, thomas, halvorsen, dadras | one orbit of a chaotic system as a 240 000-vertex line, slowly turning, pulses running along it |
| harmonograph, phyllotaxis | a pendulum figure that keeps retuning itself; a sunflower spiral breathing around the golden angle |
| chladni | sand figures of a vibrating plate whose modes drift |

`train` and `castle` are made from stills that Studio Ghibli publishes for personal use. They are not in this repository: `rice ghibli` fetches them (list in `rice/.local/share/rice/ghibli.txt`) and the two scenes only appear once they are there. A scene file says which picture it is made of on its first line (`// picture ghibli/NAME.jpg`); `_common.glsl` documents what a scene can use, and a new `.frag` file is a new live wallpaper. Cost at 1080p (`mathwall --bench 60 --scene NAME`): 1 to 3 ms of GPU time per frame for the mathematical ones, 3.5 to 4.5 ms for temple, train and castle, at 30 to 60 frames a second.

Switching: a change of mood or wallpaper takes 0.3 to 0.6 s. While the bar, window manager and compositor reload underneath, `rice-curtain` (`mathwall/curtain.c`) holds a copy of the screen on top and dissolves it away, so the old look melts into the new one. A change of live scene is a cross-fade inside the running program (`$XDG_RUNTIME_DIR/mathwall.goto`).

## Neovim (`nvim/`)
Own config, 31 plugins, about 25 ms to start. Keys, trainers and a learning ladder: `docs/nvim.md`.

## Browser (Thorium)
`theme/templates/thorium-*` generate two unpacked extensions into `~/.local/share/thorium-ext`: the colour theme, and a new-tab page (wallpaper, clock, search, bookmark tiles, a wild Pokémon, a line of mathematics, a harmonograph that draws itself once). The same extension themes text selection and scrollbars on every page. Colours follow the mood on the next new tab; a changed manifest needs a browser restart.

## Layout
| Dir | What |
|---|---|
| `i3/` | window manager config and scripts (power menu, screenshot, key list, browser profile picker, display layouts, showcase, compositor start) |
| `polybar/ rofi/ dunst/ picom/ ghostty/ fish/ gtk/ zathura/ fastfetch/` | bar, launcher, notifications, compositor, terminal, shell, cursor, PDF reader, system info |
| `evry/` | file index + search (Rust) and the live rofi tabs (C). `make -C evry install` |
| `mathwall/` | the live wallpaper (C, OpenGL) and `rice-curtain`, the dissolve between two looks. `make -C mathwall install` |
| `nvim/` | Neovim config |
| `rice/` | `rice` (wallpaper, mood, math art, menus), `rice-greet` (the Pokémon and the line of mathematics in each new terminal), `rice-preview`, `math.txt` |
| `art/` | `mathart.py`: wallpapers from mathematics (Clifford attractor, harmonograph, Julia set, Sacks prime spiral, Maurer rose), drawn in the palette's own colour system. `sprites.py`: Pokémon and mathematics data for the new-tab page |
| `theme/` | `apply.py [--mode M] WALLPAPER`: pywal16 hues -> OKLCH palette -> every file in `templates/` rendered into `~/.config` |
| `wallpaper/` | the day and night pictures (`rice wall auto` swaps them at 06:00 / 18:00 via `systemd/`) |
| `lockscreen/` | `lock.sh` (i3lock): one lock for Super+G, idle, suspend |
| `mochi/` | the desktop cat (Super+N) |
| `apps/` | desktop entry: text files open in Neovim inside Ghostty |
| `sddm/` | Dog Samurai login theme (video re-encoded to 3 MB) |
| `docs/` | `i3-survival.txt` (keys), `fish.md` (shell cheat sheet) |

Not in the repo: Pokémon sprites (`~/.local/share/pokemon-colorscripts`, fetched by `install.sh extras`) and the pictures in `~/Pictures/wallpapers`.

## Shapes and type
One rule each, everywhere: windows and notifications have a 12 px radius; menus and the launcher 16 px, with everything inside them 12 px; bar pills are fully round. Text is Inter; the bar, the terminal, keys and code are JetBrains Mono. Icons are Papirus (files, apps) and Nerd Font Material glyphs (bar, menus). Menus and workspace switches fade and rise; only opening and closing a window scales it.

## Capture (`i3/.config/i3/scripts/capture.sh`)
Screenshots go through `slop` (a 2 px frame in the accent colour) and `maim`. Recordings use ffmpeg with the Intel VAAPI encoder: the frame is uploaded, converted and encoded on the GPU (about 19% of one core at 1080p30; converting on the CPU cost a whole core), with x264 as the fallback. OBS Studio is installed for anything longer.

## Compositor rules (`picom/`)
Only managed windows get shadows, rounded corners and motion. Anything that places itself (menus, tooltips, drag icons, the screenshot selection) is shown exactly as its program drew it, and nothing but the launcher is blurred: a blur method without those rules blurs behind every translucent window, which put a smeared box around right-click menus and into area screenshots.

## Cost
Nothing new runs all the time except xsettingsd (idle, 5 MB) and, when switched on, mathwall (asleep unless the workspace is empty). Blur is on for rofi only, so it costs nothing until a menu is open. The paper shader is a few arithmetic operations per pixel and is loaded only in paper mood. The terminal greeting takes 3 ms.
