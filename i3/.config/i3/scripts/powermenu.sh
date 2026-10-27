#!/bin/bash
# Power menu. Asks again before reboot/poweroff.
choice=$(printf '%s\n' "󰌾  Lock" "󰍃  Logout" "󰤄  Suspend" "󰜉  Reboot" "󰐥  Shutdown" \
  | rofi -dmenu -i -p "⏻" -mesg "$(uptime -p)" -theme-str 'window {width: 20em;} listview {lines: 5;}' | awk '{print $NF}')
confirm() { [ "$(printf 'No\nYes\n' | rofi -dmenu -i -p "?" -mesg "$1 now?" -theme-str 'window {width: 20em;} listview {lines: 2;}')" = Yes ]; }
case "$choice" in
  Lock) "$HOME/dotfiles/lockscreen/lock.sh" ;;
  Logout) confirm Logout && i3-msg exit ;;
  Suspend) systemctl suspend ;;
  Reboot) confirm Reboot && systemctl reboot ;;
  Shutdown) confirm Shutdown && systemctl poweroff ;;
esac
