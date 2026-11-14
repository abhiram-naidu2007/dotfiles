#!/bin/bash
setsid picom --backend xrender --no-vsync --shadow --corner-radius 0 >/dev/null 2>&1 &
sleep 0.5
feh --bg-fill "${LOKA_WALL:-$HOME/dotfiles/wallpaper/meridian/meridian.png}" 2>/dev/null || xsetroot -solid '#0b3a4a'
