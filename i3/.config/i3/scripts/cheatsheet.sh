#!/bin/bash
# Show every "## text" + following bindsym from the i3 config in rofi.
awk '/^## /{d=substr($0,4); next} /^bindsym /{ if (d!="") {print $2 "\t" d}; d="" } !/^## /&&!/^bindsym /{d=""}' "$HOME/.config/i3/config" \
  | sed 's/\$mod/Super/g' | column -t -s $'\t' | rofi -dmenu -i -p "󰌌" -mesg "i3 keys" -theme-str 'window {width: 60%;} listview {lines: 14;} element-text {font: "JetBrainsMono Nerd Font 10";}'
