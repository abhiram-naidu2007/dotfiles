# dotfiles

Ubuntu 26.04, X11. i3 + polybar + rofi + dunst + picom + ghostty + fish/starship.
Colours come from the wallpaper; day/night wallpapers swap at 06:00/18:00.

## Install on a fresh machine
```
git clone <this repo> ~/dotfiles && cd ~/dotfiles
./install.sh --dry-run all      # print what would happen
./install.sh packages link theme user    # desktop (system = SDDM login, optional)
```
Each step is idempotent. `link` moves any clashing file to `.backup/<date>/` first. Undo a package: `stow -D -t ~ <pkg>`.

## Layout
| Dir | What |
|---|---|
| `i3/` | window manager config, scripts (power menu, screenshot, key list, browser profile picker, workspace-3 showcase) |
| `polybar/ rofi/ dunst/ picom/ ghostty/ fish/ gtk/` | bar, launcher, notifications, compositor, terminal, shell, GTK theme |
| `theme/` | `apply.py WALLPAPER`: pywal16 palette -> enforced contrast -> `templates/*` rendered into `~/.config` |
| `wallpaper/` | `wallpaper.sh` picks day/night image, applies it, re-themes everything |
| `lockscreen/` | `lock.sh` (i3lock): one lock for Super+G, idle, suspend |
| `sddm/` | Dog Samurai login theme (video re-encoded to 3 MB) |
| `docs/` | `i3-survival.txt` (keys), `fish.md` (shell cheat sheet) |

## Everyday
- Keys: **Super+/** (live list) or `docs/i3-survival.txt`.
- Change colours: swap a wallpaper, run `wallpaper/wallpaper.sh`. Never edit generated files (`colors.*`, `starship.toml`).
- Terminal transparency: `ghostty/.config/ghostty/config` (`background-opacity`, 0.80 keeps text above 6:1 contrast even over bright wallpapers).
- Validate i3 after edits: `i3 -C -c ~/.config/i3/config`, reload with Super+Shift+C.
- Rollback to XFCE: choose "Xfce Session" in SDDM; nothing there was modified.
