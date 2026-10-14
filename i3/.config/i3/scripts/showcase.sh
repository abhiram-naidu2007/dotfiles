#!/bin/bash
# Showcase layout on workspace 3 (browser, fastfetch, clock, cmatrix, cava).
# Run again to close it (toggle). Needs: cava cmatrix tty-clock
WS=3
LAYOUT="$HOME/.config/i3/layouts/showcase.json"
T="ghostty --background-opacity=0.78 --window-padding-x=16 --window-padding-y=12"

if [ "$1" = stop ] || i3-msg -t get_tree | grep -q '"class":"showcase-'; then
    i3-msg '[class="^showcase-.*"] kill' >/dev/null
    exit 0
fi
for c in cava cmatrix tty-clock fastfetch; do
    command -v "$c" >/dev/null || { notify-send "showcase" "missing: $c"; exit 1; }
done

i3-msg "workspace number $WS; append_layout $LAYOUT" >/dev/null
$T --class=showcase-fetch  -e fish -C 'fastfetch' &
$T --class=showcase-clock  --font-size=10 -e tty-clock -c -s -C 7 -f '%A %d %B' &
$T --class=showcase-matrix -e cmatrix -b -C blue &
$T --class=showcase-cava   -e cava &
thorium-browser --new-window &
