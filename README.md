# dotfiles

Ubuntu 26.04, X11. i3 + the loka shell (one Rust binary, `~/.local/bin/loka`: bar, island, control centre, notifications, tray; the Quickshell version in `loka/panacea` is the fallback) + rofi + picom + ghostty + fish/starship + zathura + Neovim. polybar and dunst come back when the shell is off (`rm ~/.config/loka/shell-on`).
One palette for everything, in four worlds (Meridian, Katha, Sakuga, Toon): each world brings its own hues, except Sakuga, whose hues are read from the wallpaper (accent hues only; lightness and contrast are fixed in OKLCH). Two moods: **night** (the world's own theme) and **paper** (e-ink).

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
| Super+Space | launcher: **Apps** (no app match = search the web). Ctrl+Tab moves to Files, Web, Calc, Windows, Keys and keeps what you typed |
| Super+O | **Files**: every file on the disk, as you type (like Everything on Windows) |
| Super+D | **Documents**: PDFs, newest first; Enter opens zathura |
| Super+U | **Web**: bookmarks of every browser profile; anything else is opened or searched |
| Super+= | **Calc**: qalc answers while you type; Enter copies. `=2^10` works in the Files tab too |
| Super+Shift+S | screenshot: drag an area or click a window. Super+Ctrl+S: capture menu. Super+Ctrl+R: record the screen (again to stop) |
| Super+C | clipboard history. Super+`: drop-down terminal |
| Super+T | worlds: wallpaper cards per world (←→ wallpaper, ↑↓ world, Enter). Super+Shift+T: next world |
| Super+Ctrl+W | the same world switcher. Super+Ctrl+A: draw a new mathematical wallpaper |
| Super+Ctrl+D | live wallpapers move / hold still. Super+Ctrl+N: next live wallpaper |
| Super+X | shell control centre. Super+Shift+N notifications, Super+Y calendar, Super+Shift+D do not disturb, Super+, shell settings |
| Super+Z | WhatsApp (ZapFast; Super+Shift+Z quits). Super+. kaomoji. Super+N the desktop cat |
| Super+/ | **every key and command**, searchable (the launcher's Keys tab). Sources: the `## text` lines in the i3 config and `rice/.local/share/rice/keys.tsv`. Printed sheets: `docs/i3-survival.txt`, `docs/nvim.md` |

- Look: `rice` (see `rice help`). Never edit generated files (`colors.*`, `starship.toml`, `gtk.css`, `nvim/colors/rice.lua` ...): edit `theme/templates/*` and run `rice`.
- Wallpapers: each world's folder `wallpaper/WORLD/` (pictures and videos). Preview a palette: `theme/apply.py --check --world sakuga IMAGE`.
- Validate i3 after edits: `i3 -C -c ~/.config/i3/config`, reload with Super+Shift+C.
- Rollback to XFCE: choose "Xfce Session" in SDDM; nothing there was modified.

## Shell (`loka`)
One Rust binary, `~/.local/bin/loka` (source `loka/shell/`, `cargo build --release` then `install -m755 target/release/loka ~/.local/bin/`), draws the bar, the island (clock, toasts, OSD), the control centre and its pages (Wi-Fi, Bluetooth, audio, battery, recording, calendar, notifications, clipboard, settings, power), owns `org.freedesktop.Notifications` and is the tray's StatusNotifier watcher. About 20 MB of RAM. Every page works from the keyboard: Tab / arrows move, Enter acts, Esc goes back.

- Start / switch: `loka-shell` runs the Rust shell, or the Quickshell fallback when `~/.config/loka/shell-impl` is `quickshell`. `autostart.sh` starts it when `~/.config/loka/shell-on` exists; without that file polybar and dunst run instead.
- Commands: `loka-key NAME` (or `loka msg NAME`): controls, wifi, bluetooth, audio, battery, record, calendar, notifications, clipboard, settings, powermenu, worlds, worldNext, worldWalls, dnd, close.
- Worlds: `rice world NAME [FILE]` or `loka-world NAME`; the current world is in `~/.config/loka/world`.
- Test without touching the desktop: `loka/dev/run.sh` opens a nested i3 in Xephyr on `:7`.

## File search (`evry/`)
`evry index` walks the disk (about 865 000 entries in 2.7 s) and writes one flat file. Each query memory-maps it and runs a SIMD substring scan over every name: about 10 ms, no daemon, nothing kept in RAM. A systemd user timer refreshes the index every 20 minutes at idle priority; the launcher also refreshes it in the background.

- Words: `thesis pdf` (all must match, at least one in the file name). A capital letter makes a word case sensitive.
- Folders: `notes/` (anything inside a folder named like that), `docs/intro`.
- Filters: `pdf: doc: img: vid: audio: code: zip: dir: file: home: sys: ext:rs *.png`. Without a plain word the newest come first.
- Ranking: name matches beat path matches; your own files beat system files and package caches; recent and often-opened files rise.
- Launcher keys: Enter open, Shift+Enter show in folder, Ctrl+Y copy path, Ctrl+T terminal there, Ctrl+O edit in Neovim (`evry/rofi/act.sh`).
- Terminal: `evry WORDS`, or `ev` in fish for the same search live in fzf with a preview.
- Settings: `~/.config/evry/config` (`skip PATH`, `skip-name NAME`, `junk-name NAME`, `root PATH`).

`evry/rofi/evry.c` builds two rofi modes (`files.so`, `calc.so`) that ask a helper on every keystroke and replace the list when it answers. `search.c` builds `search.so`, the web-search row of the Apps tab (prefixes yt gh w te aw pkg maps tr mal dex ai). `mouseup.c` makes `~/.local/bin/rofi` wait until no mouse button is held.

## Music (`limusic/`)
Super+M shows or hides limusic (YouTube Music), started on first use. `limusic/rice.so` is preloaded into it and adds a stylesheet (`theme/templates/limusic-css`) that maps the mood's palette onto limusic's own colour variables: frosted glass, the launcher's gradient on the play button and seek bar, Inter and JetBrains Mono. The stylesheet is watched, so a mood change restyles it live; it applies only to limusic's own page, never to the Google sign-in. Its WebKit renders on the Intel GPU: on NVIDIA's EGL it crashed whenever the window was shown or hidden.

## Moods (`rice mode night|paper|next`)
| Mood | Base | Extra |
|---|---|---|
| night | the world's own theme | |
| paper | e-ink: neutral paper and ink, fixed palette | the wallpaper is reprinted in 16 grey levels; picom runs every window through an e-ink shader (`picom/.config/picom/shaders/paper.glsl`: 16 levels, 15:1 contrast, ordered dither, ink spread, paper fibre); the bar, island and wallpaper are left out of it |

A change reaches open windows at once: the shell, i3, ghostty, fish, Neovim (colorscheme `rice`), zathura, GTK apps, cava, the live wallpaper, the browser's next new tab. Thorium's frame colours change on restart.

## Wallpapers: normal and live
There are two kinds. Super+T and Super+Ctrl+W open the shell's world switcher (this world's pictures and videos); `rice pick` (terminal, or the wallpaper tile of `rice menu` when no shell runs) shows live scenes and pictures in one rofi grid:

- **Normal**: a picture, still. Put yours in a world's folder `wallpaper/WORLD/` or `~/Pictures/wallpapers`. `rice world WORLD FILE`, or `rice wall PATH|next|prev|random`.
- **Live**: a scene drawn by the graphics card, `rice scene NAME|next|none`. Scenes are the `.frag` files in `rice/.local/share/mathwall/scenes/` (linked to `~/.local/share/mathwall/scenes/`) and the built-in ones of the program in `mathwall/`. `rice live on|off|always|toggle` decides whether a live scene moves (off: a still frame of it). It moves only while the workspace is empty, on mains and with the screen on: nothing runs otherwise.

**Live or still:** the wallpaper card in the control centre (Super+X) has a live button, a mood button and a button for the world switcher. Same on the keyboard: Super+Ctrl+D, and Super+Ctrl+N for the next live wallpaper. Choosing a picture shows the picture; choosing a live scene turns live on. Changing the mood never changes what is shown.

| Live scene | What |
|---|---|
| temple | a temple town across its tank, drawn in code: a seven-storey gopuram with barrel roof and pot finials, palms, hills, all mirrored in the water; dusk with oil lamps, or dawn with mist and birds |
| aizawa, lorenz, thomas, halvorsen, dadras | one orbit of a chaotic system as a 240 000-vertex line, slowly turning, pulses running along it |
| harmonograph, phyllotaxis | a pendulum figure that keeps retuning itself; a sunflower spiral breathing around the golden angle |
| chladni | sand figures of a vibrating plate whose modes drift |

A scene is one `.frag` file (`_common.glsl` documents what it can use); a new file there is a new live wallpaper. Cost at 1080p (`mathwall --bench 60 --scene NAME`): 1 to 3 ms of GPU time per frame for the mathematical ones, about 4.5 ms for temple, at 30 frames a second.

Switching: a change of world or wallpaper opens the new picture as a soft circle from the island (0.9 s, drawn by mathwall below the windows); mathwall exits once a still picture is in. Videos in `wallpaper/meridian/` (`sea-loop.mp4`) play as live wallpapers; the other worlds list pictures only.

## Neovim (`nvim/`)
Own config, 31 plugins, about 25 ms to start. Keys, trainers and a learning ladder: `docs/nvim.md`.

## Browser (Thorium)
`theme/templates/thorium-*` generate two unpacked extensions into `~/.local/share/thorium-ext`: the colour theme, and a new-tab page (wallpaper, clock, search, bookmark tiles, a wild Pokémon, a harmonograph that draws itself once). The same extension themes text selection and scrollbars on every page. Colours follow the mood on the next new tab; a changed manifest needs a browser restart.

## Layout
| Dir | What |
|---|---|
| `i3/` | window manager config and scripts (power menu, screenshot, key list, browser profile picker, display layouts, showcase, compositor start) |
| `loka/` | the shell's dotfiles side: `bin/` (`loka-shell` starts Rust or Quickshell per `~/.config/loka/shell-impl`; `loka-key` / `loka-ipc` send commands to whichever runs; `loka-world`, `loka-art`, `loka-stats`, `loka-zapfast`), the Rust shell's source (`shell/`), the Quickshell fallback (`panacea/`, `qml/` Hyprland stub, X11 shims in `shim/`), nested test session `dev/` (`run.sh` builds its i3 config from the live one). |
| `polybar/ rofi/ dunst/ picom/ ghostty/ fish/ gtk/ zathura/ fastfetch/` | bar and notifications when the shell is off, launcher, compositor, terminal, shell, cursor, PDF reader, system info |
| `evry/` | file index + search (Rust) and the live rofi tabs (C). `make -C evry install` |
| `mathwall/` | the live wallpaper (C, OpenGL) and `rice-curtain`, the dissolve between two looks. `make -C mathwall install` |
| `nvim/` | Neovim config |
| `rice/` | `rice` (worlds, wallpaper, mood, math art, menus), `rice-greet` (the Pokémon greeting in each new terminal), `rice-preview` |
| `art/` | `mathart.py`: wallpapers from mathematics (Clifford attractor, harmonograph, Julia set, Sacks prime spiral, Maurer rose), drawn in the palette's own colour system. `sprites.py`: Pokémon data for the new-tab page |
| `theme/` | `apply.py [--mode night\|paper] [--world W] WALLPAPER`: world hues (Sakuga: pywal16 hues from the wallpaper) -> OKLCH palette -> every file in `templates/` rendered into `~/.config` |
| `wallpaper/` | one folder per world (`meridian/ katha/ sakuga/ toon/`): pictures, plus the Meridian video |
| `lockscreen/` | `lock.sh` (i3lock): one lock for Super+G, idle, suspend |
| `mochi/` | the desktop cat (Super+N) |
| `apps/` | desktop entries: `nvim-ghostty` (text files open in Neovim inside Ghostty), `limusic` |
| `sddm/` | Dog Samurai login theme (video re-encoded to 3 MB) |
| `docs/` | `i3-survival.txt` (keys), `fish.md` (shell cheat sheet), `nvim.md` (Neovim keys and ladder) |

Not in the repo: Pokémon sprites (`~/.local/share/pokemon-colorscripts`, fetched by `install.sh extras`) and the pictures in `~/Pictures/wallpapers`.

## Shapes and type
One rule each, everywhere: windows and notifications have a 12 px radius; menus and the launcher 16 px, with everything inside them 12 px; bar pills are fully round. Text is Inter; the bar, the terminal, keys and code are JetBrains Mono. Icons are Papirus (files, apps) and Nerd Font Material glyphs (bar, menus). Menus and workspace switches fade and rise; only opening and closing a window scales it.

## Capture (`i3/.config/i3/scripts/capture.sh`)
Screenshots go through `slop` (a 2 px frame in the accent colour) and `maim`. Recordings use ffmpeg with the Intel VAAPI encoder: the frame is uploaded, converted and encoded on the GPU (about 19% of one core at 1080p30; converting on the CPU cost a whole core), with x264 as the fallback. OBS Studio is installed for anything longer.

## Compositor rules (`picom/`)
Only managed windows get shadows, rounded corners and motion. Anything that places itself (menus, tooltips, drag icons, the screenshot selection) is shown exactly as its program drew it, and nothing but the launcher is blurred: a blur method without those rules blurs behind every translucent window, which put a smeared box around right-click menus and into area screenshots.

## Cost
Always running: the loka shell (about 20 MB, under 1% CPU idle), xsettingsd (idle, 5 MB), autotiling and blueman-applet; mathwall only when live is on (asleep unless the workspace is empty). Blur is on for rofi only, so it costs nothing until a menu is open. The paper shader is a few arithmetic operations per pixel and is loaded only in paper mood. The terminal greeting takes 3 ms.
