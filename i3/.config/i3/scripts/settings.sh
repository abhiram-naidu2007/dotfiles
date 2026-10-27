#!/bin/bash
# Quick settings menu (Super+I). Entries run the tools that work under i3.
declare -A CMD=(
  ["󰍹  Display"]="arandr"
  ["󰕾  Sound"]="pavucontrol"
  ["󰖩  Network"]="nm-connection-editor"
  ["󰂯  Bluetooth"]="blueman-manager"
  ["󰁹  Power"]="xfce4-power-manager-settings"
  ["󰌌  Keyboard"]="xfce4-keyboard-settings"
  ["󰆍  Open i3 config"]="ghostty -e nvim ~/dotfiles/i3/.config/i3/config"
  ["󰑓  Re-theme from wallpaper"]="~/dotfiles/wallpaper/wallpaper.sh"
)
choice=$(printf '%s\n' "${!CMD[@]}" | sort | rofi -dmenu -i -p "󰒓" -mesg "quick settings" -theme-str 'window {width: 26em;} listview {lines: 8;}')
[ -n "$choice" ] || exit 0
cmd=${CMD[$choice]}
command -v "${cmd%% *}" >/dev/null || [ "${cmd:0:1}" = "~" ] \
  || { notify-send -u critical "Settings" "${cmd%% *} is not installed"; exit 1; }
exec bash -c "$cmd"
