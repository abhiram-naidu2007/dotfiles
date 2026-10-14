#!/bin/bash
# Pick wallpaper by hour, apply it (feh in i3, xfconf in XFCE), re-theme everything.
export PATH="$HOME/.local/bin:$PATH"
DIR="$HOME/dotfiles/wallpaper"
HOUR=$(date +%H)
if [ "$HOUR" -ge 6 ] && [ "$HOUR" -lt 18 ]; then WALLPAPER="$DIR/morning.jpg"; else WALLPAPER="$DIR/night.png"; fi

if pgrep -x i3 >/dev/null; then
    feh --no-fehbg --bg-fill "$WALLPAPER"
else
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitoreDP-1/workspace0/last-image -s "$WALLPAPER"
fi

# Colours for i3/polybar/rofi/dunst/ghostty/fish/starship
before=$(md5sum "$HOME/.config/i3/colors.conf" 2>/dev/null)
python3 -I "$HOME/dotfiles/theme/apply.py" "$WALLPAPER" >/dev/null
after=$(md5sum "$HOME/.config/i3/colors.conf" 2>/dev/null)
if pgrep -x i3 >/dev/null; then
    pkill -USR1 -x polybar            # polybar reload
    dunstctl reload 2>/dev/null       # dunst reload
    # reload i3 only if colours changed (autostart runs this script: avoid reload loop)
    [ "$before" != "$after" ] && i3-msg reload >/dev/null
fi
exit 0
