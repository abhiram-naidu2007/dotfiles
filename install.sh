#!/bin/bash
# Idempotent setup. Usage: ./install.sh [--dry-run] <step...>
#   packages  apt + uv packages for the i3 desktop      (sudo)
#   link      back up clashing files, then stow every package into ~
#   build     compile evry (file search + rofi tabs), mochi (desktop cat), mathwall (live wallpaper); Neovim plugins
#   extras    Pokémon terminal sprites, a first set of mathematical wallpapers
#   theme     generate colours from the current wallpaper
#   user      default apps, timers, lock hooks, XFCE keybinding (no sudo)
#   system    SDDM + Dog Samurai theme                  (sudo)
#   all       packages link build extras theme user system
set -euo pipefail
DOT="$(cd "$(dirname "$0")" && pwd)"
LOCK="$DOT/lockscreen/lock.sh"
STOW_PKGS=(i3 polybar rofi dunst picom ghostty fish gtk thorium systemd zathura fastfetch rice apps nvim)
APT_PKGS=(i3 polybar rofi dunst picom fish starship stow fonts-inter autotiling feh
          policykit-1-gnome brightnessctl playerctl maim slop xdotool ffmpeg obs-studio xclip xfce4-clipman network-manager-gnome
          btop tty-clock ncal fastfetch cava
          i3lock xss-lock imagemagick libnotify-bin x11-xserver-utils xinput
          pipewire-pulse wireplumber pavucontrol blueman arandr
          papirus-icon-theme bibata-cursor-theme gnome-themes-extra xsettingsd
          exo-utils xfce4-settings xfce4-power-manager neovim
          zathura zathura-pdf-poppler zathura-djvu zathura-cb poppler-utils
          fzf bat eza zoxide chafa qalc jq
          rofi-dev libglib2.0-dev libcairo2-dev libx11-dev libxext-dev libgl-dev build-essential lazygit
          python3-numpy python3-pil python3-cairo python3-venv
          fonts-dejavu-core fonts-noto-cjk fonts-noto-color-emoji)
# Not in apt: JetBrainsMono Nerd Font (~/.local/share/fonts), ghostty, thorium, limusic AppImage, cargo (rustup.rs, for evry)
DRY=0

run() { if [ "$DRY" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }

packages() {
  run sudo apt-get install -y "${APT_PKGS[@]}"
  command -v wal >/dev/null || run uv tool install pywal16
}

link() {
  local backup="$DOT/.backup/$(date +%F)" pkg f rel target
  for pkg in "${STOW_PKGS[@]}"; do
    while IFS= read -r f; do
      rel="${f#"$DOT/$pkg/"}"; target="$HOME/$rel"
      if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo "backup: $target"
        run mkdir -p "$backup/$(dirname "$rel")"
        run mv "$target" "$backup/$rel"
      fi
    done < <(find "$DOT/$pkg" -type f)
  done
  run stow --no-folding -d "$DOT" -t "$HOME" -R "${STOW_PKGS[@]}"
}

build() {
  run make -C "$DOT/evry" install      # ~/.local/bin/evry, ~/.local/lib/rofi/{files,calc}.so
  run make -C "$DOT/mochi" install     # ~/.local/bin/mochi
  run make -C "$DOT/mathwall" install  # ~/.local/bin/mathwall (live wallpaper)
  run make -C "$DOT/limusic" install   # ~/.local/lib/limusic-rice/rice.so (limusic in the desktop colours)
  run "$HOME/.local/bin/evry" index
  # Neovim: Python language server and debugger through uv; the rest installs itself on first start
  command -v basedpyright-langserver >/dev/null || run uv tool install basedpyright
  [ -x "$HOME/.local/share/nvim/debugpy/bin/python" ] || {
    run uv venv "$HOME/.local/share/nvim/debugpy"
    run uv pip install --python "$HOME/.local/share/nvim/debugpy/bin/python" debugpy
  }
  run nvim --headless "+Lazy! restore" +qa
}

extras() {
  local sprites="$HOME/.local/share/pokemon-colorscripts" art="$HOME/Pictures/wallpapers/mathart" kind
  [ -d "$sprites" ] || run git clone --depth 1 https://gitlab.com/phoneybadger/pokemon-colorscripts.git "$sprites"
  run mkdir -p "$art"
  for kind in attractor harmonograph julia sacks rose; do
    [ -e "$art/$kind-7.png" ] || run python3 "$DOT/art/mathart.py" "$kind" "$art/$kind-7.png" --seed 7
  done
}

theme() { run "$HOME/.local/bin/rice" apply; }

user() {
  # One lock for everything: xflock4 (Ctrl+Alt+L, session menu) -> lock.sh
  run xfconf-query -c xfce4-session -p /general/LockCommand -n -t string -s "$LOCK"
  run xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Super>g" -n -t string -s "$LOCK"
  # Lock before suspend / on loginctl lock-session (XFCE session; i3 starts its own)
  run mkdir -p ~/.config/autostart
  if [ "$DRY" = 0 ]; then
    printf '[Desktop Entry]\nType=Application\nName=xss-lock\nExec=xss-lock --transfer-sleep-lock -- %s\n' "$LOCK" > ~/.config/autostart/xss-lock.desktop
  fi
  run xfconf-query -c xfce4-screensaver -p /lock/enabled -n -t bool -s false
  # Day/night wallpaper swap (06:00 / 18:00) and the file index refresh (every 20 min);
  # unit files come from the systemd stow package
  run systemctl --user daemon-reload
  run systemctl --user enable --now wallpaper.timer evry-index.timer
  # Default apps: PDFs in zathura, text in Neovim inside Ghostty
  run xdg-mime default org.pwmt.zathura.desktop application/pdf image/vnd.djvu application/x-cbz application/x-cbr application/vnd.comicbook+zip
  run xdg-mime default nvim-ghostty.desktop text/plain text/markdown text/x-python text/x-csrc text/x-chdr text/x-c++src text/x-c++hdr \
    text/x-rust text/x-lua text/x-tex text/x-makefile text/x-shellscript application/x-shellscript application/json application/toml \
    application/x-yaml text/css text/x-log
  # Thorium flags hold absolute extension paths
  if [ "$DRY" = 0 ]; then
    sed "s|@HOME@|$HOME|g" "$DOT/thorium/thorium-flags.conf.in" > ~/.config/thorium/thorium-flags.conf
  fi
  # btop: the generated palette, on the terminal's own background
  if [ -f ~/.config/btop/btop.conf ]; then
    run sed -i 's/^color_theme = .*/color_theme = "rice"/; s/^theme_background = .*/theme_background = false/' ~/.config/btop/btop.conf
  fi
}

system() {
  run sudo apt-get install -y --no-install-recommends sddm \
    qml6-module-qtquick qml6-module-qtquick-window qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts qml6-module-qtmultimedia \
    qml6-module-qt5compat-graphicaleffects qml6-module-qt-labs-folderlistmodel
  run sudo install -d /usr/share/sddm/themes /etc/sddm.conf.d
  run sudo rm -rf /usr/share/sddm/themes/dog-samurai
  run sudo cp -r "$DOT/sddm/dog-samurai" /usr/share/sddm/themes/dog-samurai
  run sudo install -m644 "$DOT/sddm/sddm.conf.d/theme.conf" /etc/sddm.conf.d/theme.conf
  echo "Switch display manager: sudo dpkg-reconfigure sddm   (rollback: lightdm)"
}

[ "${1:-}" = "--dry-run" ] && { DRY=1; shift; }
[ $# -eq 0 ] && { sed -n '2,10p' "$0"; exit 1; }
for step in "$@"; do
  case "$step" in
    packages|link|build|extras|theme|user|system) "$step" ;;
    all) packages; link; build; extras; theme; user; system ;;
    *) echo "unknown step: $step"; exit 1 ;;
  esac
done
