# dotfiles (Ubuntu 26.04, X11)

Packages are GNU stow dirs mirroring `~`. Link: `stow --no-folding -t ~ i3 polybar rofi dunst picom ghostty fish`. Unlink: `stow -D -t ~ <pkg>`.

| Dir | What |
|---|---|
| `i3/` | window manager; keys listed by **Super+/** (from `## text` comments in the config) |
| `polybar/ rofi/ dunst/ picom/ ghostty/ fish/` | bar, launcher, notifications, compositor, terminal, shell |
| `theme/` | `apply.py WALLPAPER` extracts a palette (pywal16), enforces contrast, renders `templates/*` into `~/.config/**` |
| `wallpaper/` | `wallpaper.sh` picks day/night image, applies it, re-themes (systemd timer 06:00/18:00) |
| `lockscreen/` | `lock.sh` (i3lock), Super+G |
| `sddm/` | Dog Samurai login theme |
| `docs/fish.md` | fish cheat sheet |

Change colours: swap a wallpaper (or edit role logic in `theme/apply.py`), run `wallpaper.sh`. Never edit generated files (`colors.*`, `starship.toml`).

Rollback to XFCE: choose "Xfce Session" in SDDM. Nothing in the XFCE session is modified.
