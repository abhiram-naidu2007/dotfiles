#!/bin/bash
# Idempotent. Usage: ./install.sh [user|system|all]   (default: all)
# user   = keybindings + idle/suspend hook (no sudo)
# system = SDDM + Dog Samurai theme + switch display manager (sudo)
set -euo pipefail
DOT="$(cd "$(dirname "$0")" && pwd)"
LOCK="$DOT/lockscreen/lock.sh"

user() {
  # One lock for everything: xflock4 (Ctrl+Alt+L, session menu) -> lock.sh
  xfconf-query -c xfce4-session -p /general/LockCommand -n -t string -s "$LOCK"
  xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Super>g" -n -t string -s "$LOCK"
  # Drop old Super+L override; default xflock4 now resolves to lock.sh too
  xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Super>l" -r 2>/dev/null || true
  # Lock before suspend / on loginctl lock-session
  mkdir -p ~/.config/autostart
  cat > ~/.config/autostart/xss-lock.desktop <<DESK
[Desktop Entry]
Type=Application
Name=xss-lock
Exec=xss-lock --transfer-sleep-lock -- $LOCK
DESK
  # Stock XFCE screensaver must not show a second lock
  xfconf-query -c xfce4-screensaver -p /lock/enabled -n -t bool -s false 2>/dev/null || true
}

system() {
  sudo apt-get install -y --no-install-recommends sddm \
    qml6-module-qtquick qml6-module-qtquick-window qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts qml6-module-qtmultimedia \
    qml6-module-qt5compat-graphicaleffects qml6-module-qt-labs-folderlistmodel
  sudo install -d /usr/share/sddm/themes /etc/sddm.conf.d
  sudo rm -rf /usr/share/sddm/themes/dog-samurai
  sudo cp -r "$DOT/sddm/dog-samurai" /usr/share/sddm/themes/dog-samurai
  sudo install -m644 "$DOT/sddm/sddm.conf.d/theme.conf" /etc/sddm.conf.d/theme.conf
  echo "Test:   sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/dog-samurai"
  echo "Switch: sudo dpkg-reconfigure sddm   (rollback: sudo dpkg-reconfigure lightdm)"
}

case "${1:-all}" in
  user) user ;; system) system ;; all) user; system ;;
  *) echo "usage: $0 [user|system|all]"; exit 1 ;;
esac
