#!/bin/bash
# Render the i3lock background once (not per lock: suspend waits on the locker).
# No clock on the image: i3lock shows a still picture, so a time would be stale.
# Output lives in the user's cache, not a world-writable /tmp path.
WALLPAPER="$HOME/dotfiles/lockscreen/assets/lock-wallpaper-edit.png"
OUTPUT="${1:-$HOME/.cache/theme/lock.png}"
INK="#24364a"   # dark blue-grey: readable on the sky area of the picture

mkdir -p "$(dirname "$OUTPUT")"
magick "$WALLPAPER" -resize 1920x1080^ -gravity center -extent 1920x1080 \
    -gravity east \
    -font Inter-Display-Bold -pointsize 88 -fill "$INK" -annotate +150-40 "Locked" \
    -font Inter-Medium -pointsize 26 -fill "${INK}cc" -annotate +152+40 "Type your password, then Enter" \
    "$OUTPUT.tmp.png" && mv "$OUTPUT.tmp.png" "$OUTPUT"
