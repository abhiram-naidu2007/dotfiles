
#!/bin/bash

HOUR=$(date +%H)

if [ "$HOUR" -ge 6 ] && [ "$HOUR" -lt 18 ]; then
    WALLPAPER="$HOME/dotfiles/wallpaper/morning.jpg"
else
    WALLPAPER="$HOME/dotfiles/wallpaper/night.png"
fi

xfconf-query \
    -c xfce4-desktop \
    -p /backdrop/screen0/monitoreDP-1/workspace0/last-image \
    -s "$WALLPAPER"
