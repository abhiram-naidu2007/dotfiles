#!/bin/bash
# Runs on every i3 start/restart/reload (exec_always). Must be idempotent.
# No xfsettingsd here: it grabs XFCE shortcuts (Super_L etc.) and breaks i3 keys.
pkill -x picom;   picom -b
pkill -x polybar; setsid polybar -q main >/dev/null 2>&1 &
pgrep -x dunst >/dev/null || setsid dunst >/dev/null 2>&1 &
# system python only: a user-site python-xlib in ~/.local breaks i3ipc
pgrep -f "^/usr/bin/python3 -s /usr/bin/autotiling" >/dev/null || setsid /usr/bin/python3 -s /usr/bin/autotiling >/dev/null 2>&1 &
setsid "$HOME/dotfiles/wallpaper/wallpaper.sh" >/dev/null 2>&1 &
