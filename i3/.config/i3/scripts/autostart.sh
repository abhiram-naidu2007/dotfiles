#!/bin/bash
# Run on every i3 start/restart. No xfsettingsd here: it grabs XFCE shortcuts (Super_L etc.) and breaks i3 keys.
pkill -x picom;   picom -b
pkill -x polybar; polybar -q main &
pkill -x dunst;   dunst &
"$HOME/dotfiles/wallpaper/wallpaper.sh" &
