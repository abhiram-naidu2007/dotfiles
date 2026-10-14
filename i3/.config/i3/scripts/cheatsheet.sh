#!/bin/bash
# Show every "## text" binding from the i3 config in rofi.
grep -E '^bindsym .*##' "$HOME/.config/i3/config" \
  | sed -E 's/^bindsym +([^ ]+) .*## *(.*)$/\1\t\2/; s/\$mod/Super/g' \
  | column -t -s $'\t' | rofi -dmenu -i -p "keys" -theme-str 'window {width: 60%;}'
