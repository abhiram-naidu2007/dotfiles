#!/bin/bash

WALLPAPER="$HOME/dotfiles/lockscreen/assets/lock-wallpaper-edit.png"
OUTPUT="/tmp/lockscreen.png"

TIME=$(date '+%I:%M %p')
DATE=$(date '+%A, %d %B')

convert "$WALLPAPER" \
    -gravity southeast \
    -font "DejaVu-Sans" \
    -fill white \
    -pointsize 96 \
    -annotate +100+120 "$TIME" \
    -pointsize 32 \
    -annotate +100+55 "$DATE" \
    "$OUTPUT"
