#!/bin/bash
# Showcase layout on workspace 3 (browser, fastfetch, clock, calendar, btop).
# Run again to close it (toggle). Needs: btop tty-clock
WS=3
LAYOUT="$HOME/.config/i3/layouts/showcase.json"
T="ghostty --background-opacity=0.78 --window-padding-x=16 --window-padding-y=12"

if [ "$1" = stop ] || i3-msg -t get_tree | grep -q '"class":"showcase-'; then
    i3-msg '[class="^showcase-.*"] kill' >/dev/null
    exit 0
fi
for c in btop tty-clock fastfetch cal; do
    command -v "$c" >/dev/null || { notify-send "showcase" "missing: $c"; exit 1; }
done

i3-msg "workspace number $WS; append_layout $LAYOUT" >/dev/null
$T --class=showcase-fetch  -e fish -C 'fastfetch' &
$T --class=showcase-clock  --font-size=10 -e tty-clock -c -s -C 7 -f '%A %d %B' &
$T --class=showcase-cal    -e fish -C 'cal -3; read -P "" -n 1' &
$T --class=showcase-btop   -e btop &
thorium-browser --new-window &
