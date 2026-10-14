#!/bin/bash
# screenshot.sh full|area -> ~/Pictures/shot-<time>.png and clipboard
mkdir -p "$HOME/Pictures"
f="$HOME/Pictures/shot-$(date +%F_%H-%M-%S).png"
if [ "$1" = area ]; then maim -s "$f"; else maim "$f"; fi || exit 1
command -v xclip >/dev/null && xclip -selection clipboard -t image/png < "$f"
notify-send -t 2000 "Screenshot saved" "$f"
