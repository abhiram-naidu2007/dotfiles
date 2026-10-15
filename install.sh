#!/bin/bash
# Idempotent setup. Usage: ./install.sh [--dry-run] <step...>
#   packages  apt + uv packages for the i3 desktop      (sudo)
#   link      back up clashing files, then stow every package into ~
#   theme     generate colours from the current wallpaper
#   user      XFCE keybinding + lock command + idle lock hook (no sudo)
#   system    SDDM + Dog Samurai theme                  (sudo)
#   all       packages link theme user system
set -euo pipefail
DOT="$(cd "$(dirname "$0")" && pwd)"
LOCK="$DOT/lockscreen/lock.sh"
STOW_PKGS=(i3 polybar rofi dunst picom ghostty fish gtk thorium)
APT_PKGS=(i3 polybar rofi dunst picom fish starship stow fonts-inter autotiling feh
          policykit-1-gnome brightnessctl playerctl maim xclip network-manager-gnome
          btop tty-clock ncal)
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

theme() { run "$DOT/wallpaper/wallpaper.sh"; }

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
[ $# -eq 0 ] && { sed -n '2,9p' "$0"; exit 1; }
for step in "$@"; do
  case "$step" in
    packages|link|theme|user|system) "$step" ;;
    all) packages; link; theme; user; system ;;
    *) echo "unknown step: $step"; exit 1 ;;
  esac
done
