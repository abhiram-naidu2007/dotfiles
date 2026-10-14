#!/bin/bash
# Showcase layout on workspace 3 (btop, fastfetch, clock, calendar; no browser).
# Run again to close it (toggle). Needs: btop tty-clock
WS=3
LAYOUT="$HOME/.config/i3/layouts/showcase.json"
T="ghostty --window-padding-x=16 --window-padding-y=12"

if [ "$1" = stop ] || i3-msg -t get_tree | grep -q '"class":"dev.showcase.'; then
    i3-msg '[class="^dev\.showcase\..*"] kill' >/dev/null
    exit 0
fi
for c in btop tty-clock fastfetch cal; do
    command -v "$c" >/dev/null || { notify-send "showcase" "missing: $c"; exit 1; }
done

i3-msg "workspace number $WS; append_layout $LAYOUT" >/dev/null
$T --class=dev.showcase.fetch  -e fish -C 'sleep 0.7; clear; fastfetch' &
$T --class=dev.showcase.clock  --font-size=10 -e fish -C 'sleep 0.7; exec tty-clock -c -s -C 4 -f "%A %d %B"' &
$T --class=dev.showcase.cal    --font-size=10 -e fish -C 'sleep 0.7; clear; cal -3' &
$T --class=dev.showcase.btop   --font-size=11 -e btop &
