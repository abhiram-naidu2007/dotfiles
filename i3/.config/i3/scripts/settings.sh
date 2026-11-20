#!/bin/bash
# Quick settings menu (Super+I). Entries run the tools that work under i3.
declare -A CMD=(
  ["󰍹  Display"]="arandr"
  ["󰕾  Sound"]="pavucontrol"
  ["󰖩  Wi-Fi networks"]="~/.config/i3/scripts/wifi.sh"
  ["󰖩  Saved connections"]="nm-connection-editor"
  ["󰒓  All settings (XFCE)"]="xfce4-settings-manager"
  ["󰂯  Bluetooth"]="blueman-manager"
  ["󰆍  Open i3 config"]="ghostty -e nvim ~/dotfiles/i3/.config/i3/config"
  ["󰸉  Mood and wallpaper"]="~/.local/bin/rice menu"
  ["󰑓  Re-theme from wallpaper"]="~/.local/bin/rice apply"
)
choice=$(printf '%s\n' "${!CMD[@]}" | sort | rofi -dmenu -i -p "󰒓" -mesg "quick settings" -theme-str 'window {width: 26em;} listview {lines: 9;}')
[ -n "$choice" ] || exit 0
cmd=${CMD[$choice]}
command -v "${cmd%% *}" >/dev/null || [ "${cmd:0:1}" = "~" ] \
  || { notify-send -u critical "Settings" "${cmd%% *} is not installed"; exit 1; }
exec bash -c "$cmd"
