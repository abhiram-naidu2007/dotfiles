#!/bin/bash
# Run on every i3 start/restart. Restarts picom, polybar, dunst; xfsettingsd once.
pkill -x picom;   picom -b
pkill -x polybar; polybar -q main &
pkill -x dunst;   dunst &
pgrep -x xfsettingsd >/dev/null || xfsettingsd &
"$HOME/dotfiles/wallpaper/wallpaper.sh" &
