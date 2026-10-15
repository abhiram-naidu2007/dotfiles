#!/bin/bash
# Quick settings menu (Super+I). Entries run the tools that work under i3.
declare -A CMD=(
  ["󰍹  Display"]="arandr"
  ["󰕾  Sound"]="pavucontrol"
  ["󰖩  Network"]="nm-connection-editor"
  ["󰂯  Bluetooth"]="blueman-manager"
  ["󰁹  Power"]="xfce4-power-manager-settings"
  ["󰌌  Keyboard"]="xfce4-keyboard-settings"
  ["󰆍  Open i3 config"]="ghostty -e nvim $HOME/dotfiles/i3/.config/i3/config"
  ["󰑓  Re-theme from wallpaper"]="$HOME/dotfiles/wallpaper/wallpaper.sh"
)
choice=$(printf '%s\n' "${!CMD[@]}" | sort | rofi -dmenu -i -p "settings" -theme-str 'window {width: 24em;} listview {lines: 8;}')
[ -n "$choice" ] && exec ${CMD[$choice]}
