#!/bin/bash
# Power menu: five tiles. Asks again before logout, reboot and shutdown.
tile() { printf "<span font='JetBrainsMono Nerd Font 24'>%s</span>\n%s" "$1" "$2"; }
choice=$(printf '%s\0' "$(tile 󰌾 lock)" "$(tile 󰍃 logout)" "$(tile 󰤄 suspend)" "$(tile 󰜉 reboot)" "$(tile 󰐥 shutdown)" \
  | rofi -dmenu -sep '\0' -eh 4 -markup-rows -i -format i -theme tiles -mesg "$(uptime -p)")
confirm() { [ "$(printf 'No\nYes\n' | rofi -dmenu -i -p "?" -mesg "$1 now?" -theme-str 'window {width: 20em;} listview {lines: 2;}')" = Yes ]; }
case "$choice" in
  0) "$HOME/dotfiles/lockscreen/lock.sh" ;;
  1) confirm Logout && i3-msg exit ;;
  2) systemctl suspend ;;
  3) confirm Reboot && systemctl reboot ;;
  4) confirm Shutdown && systemctl poweroff ;;
esac
