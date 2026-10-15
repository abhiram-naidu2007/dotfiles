#!/bin/bash
# Runs on every i3 start/restart/reload (exec_always). Must be idempotent.
# No xfsettingsd here: it grabs XFCE shortcuts (Super_L etc.) and breaks i3 keys.
pkill -x picom;   picom -b
pkill -x polybar; setsid polybar -q main >/dev/null 2>&1 &
pgrep -x dunst >/dev/null || setsid dunst >/dev/null 2>&1 &
# system python only: a user-site python-xlib in ~/.local breaks i3ipc
pgrep -f "^/usr/bin/python3 -s /usr/bin/autotiling" >/dev/null || setsid /usr/bin/python3 -s /usr/bin/autotiling >/dev/null 2>&1 &
pgrep -x blueman-applet >/dev/null || setsid blueman-applet >/dev/null 2>&1 &
setsid "$HOME/dotfiles/wallpaper/wallpaper.sh" >/dev/null 2>&1 &

# Settings XFCE used to apply (xfsettingsd is off in i3)
xset s 600 600            # screensaver (xss-lock locks) after 10 min idle
xset dpms 0 0 900         # screen off after 15 min
xset r rate 300 40        # key repeat: 300 ms delay, 40/s
tp=$(xinput list --name-only | grep -i touchpad | head -1)
if [ -n "$tp" ]; then
    xinput set-prop "$tp" "libinput Tapping Enabled" 1
    xinput set-prop "$tp" "libinput Natural Scrolling Enabled" 0
fi
