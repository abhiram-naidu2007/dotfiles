#!/bin/bash
# Pick wallpaper by hour, apply it (feh in i3, xfconf in XFCE), re-theme everything.
export PATH="$HOME/.local/bin:$PATH"
DIR="$HOME/dotfiles/wallpaper"
HOUR=$(date +%H)
if [ "$HOUR" -ge 6 ] && [ "$HOUR" -lt 18 ]; then WALLPAPER="$DIR/morning.jpg"; else WALLPAPER="$DIR/night.jpg"; fi

if pgrep -x i3 >/dev/null; then
    feh --no-fehbg --bg-fill "$WALLPAPER"
else
    for p in $(xfconf-query -c xfce4-desktop -l | grep '/last-image$'); do
        xfconf-query -c xfce4-desktop -p "$p" -s "$WALLPAPER"
    done
fi

# Colours for i3/polybar/rofi/dunst/ghostty/fish/starship/gtk4
before=$(md5sum "$HOME/.config/i3/colors.conf" 2>/dev/null)
python3 -I "$HOME/dotfiles/theme/apply.py" "$WALLPAPER" >/dev/null
after=$(md5sum "$HOME/.config/i3/colors.conf" 2>/dev/null)
if pgrep -x i3 >/dev/null; then
    pkill -USR1 -x polybar            # polybar reload
    dunstctl reload 2>/dev/null       # dunst reload
    # reload i3 (new border colours) only when the palette actually changed
    [ "$before" != "$after" ] && i3-msg reload >/dev/null
fi
# Lock image is rendered ahead of time so locking (and suspend) stays instant
[ -s "$HOME/.cache/theme/lock.png" ] || "$HOME/dotfiles/lockscreen/generate-lockscreen.sh"
exit 0
