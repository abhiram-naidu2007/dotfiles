#!/bin/bash
# Showcase: system monitor, a Pokémon with the machine's details, clock, calendar with a line
# of mathematics, and bars that follow whatever is playing.
# It opens on the workspace you are on when that one is empty, otherwise on the first empty
# one, so it never rearranges windows you already have. Run again to close it (toggle).
# Needs: btop tty-clock fastfetch cava
LAYOUT="$HOME/.config/i3/layouts/showcase.json"
PANE="$HOME/.config/i3/scripts/showcase-pane.sh"
T="ghostty --gtk-single-instance=false --window-padding-x=18 --window-padding-y=14 --confirm-close-surface=false"

if [ "$1" = stop ] || i3-msg -t get_tree | grep -q '"class":"dev.showcase.'; then
    i3-msg '[class="^dev\.showcase\..*"] kill' >/dev/null
    exit 0
fi
for c in btop tty-clock fastfetch cava; do
    command -v "$c" >/dev/null || { notify-send "showcase" "missing: $c"; exit 1; }
done

# the focused workspace if it has no windows, else the lowest number not in use
WS=$(i3-msg -t get_tree | jq -r '
  [.. | objects | select(.type? == "workspace" and .name != "__i3_scratch")] as $all
  | ($all[] | select([.. | objects | select(.focused? == true)] | length > 0)) as $here
  | if ([$here | .. | objects | select(.window? != null)] | length) == 0 then $here.num
    else ([range(1; 11)] - [$all[].num])[0] // $here.num end')
i3-msg "workspace number ${WS:-3}; append_layout $LAYOUT" >/dev/null
$T --class=dev.showcase.btop  --font-size=10 -e btop &
$T --class=dev.showcase.fetch --font-size=10 -e "$PANE" fetch &
$T --class=dev.showcase.clock --font-size=13 -e tty-clock -c -C 4 -f "%A, %d %B" &
$T --class=dev.showcase.cal   --font-size=14 -e "$PANE" cal &
$T --class=dev.showcase.cava  --font-size=10 -e cava &
