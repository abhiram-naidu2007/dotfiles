#!/bin/bash
# Pick a kaomoji in rofi and copy it to the clipboard.
choice=$(printf '%s\n' \
  '(=^･ω･^=)' '(=^-ω-^=)' 'ヽ(=^ω^=)ノ' '(=-ω-=) zZ' '(=；ω；=)' '(=ﾟДﾟ=)' \
  '(◕‿◕)' '(｡♥‿♥｡)' '(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧' '(╯°□°)╯︵ ┻━┻' '┬─┬ノ( º _ ºノ)' '¯\_(ツ)_/¯' \
  '(•̀ᴗ•́)و' '(๑˃ᴗ˂)ﻭ' '(っ˘ω˘ς)' '(づ｡◕‿‿◕｡)づ' '( •_•)>⌐■-■' '(⌐■_■)' \
  '(＾▽＾)' '(≧◡≦)' '(´；ω；`)' '(¬‿¬)' '(ಠ_ಠ)' 'ʕ•ᴥ•ʔ' \
  | rofi -dmenu -i -p "♡" -mesg "copy a face" -theme-str 'window {width: 44em;} listview {lines: 6; columns: 4;} element-icon {enabled: false;} element-text {horizontal-align: 0.5; font: "Noto Sans CJK JP 13";}')
[ -n "$choice" ] || exit 0
printf '%s' "$choice" | xclip -selection clipboard
notify-send -t 1500 "$choice" "copied"
