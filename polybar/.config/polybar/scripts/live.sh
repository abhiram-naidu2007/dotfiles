#!/bin/bash
# The live wallpaper as a button: what is on the desktop and whether it moves.
#   live   a live wallpaper is on and moves          still  one is chosen but held still
#   (icon) a normal picture is shown, nothing to move
# Reads the state files `rice` keeps; polybar re-runs this whenever `rice` changes something.
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/rice"
scene=$(cat "$STATE/scene" 2>/dev/null)
live=$(cat "$STATE/live" 2>/dev/null)
while IFS=' =' read -r k v; do
    case $k in accent) ACC=$v ;; dim) DIM=$v ;; fg) INK=$v ;; esac
done < "$HOME/.config/polybar/colors.ini"
if [ -z "$scene" ] || [ "$scene" = picture ]; then
    printf '%%{T2}%%{F%s}󰋩%%{F-}%%{T-}\n' "$DIM"
elif [ "$live" = on ] || [ "$live" = always ]; then
    printf '%%{T2}%%{F%s}󰐊%%{F-}%%{T-} %%{F%s}live%%{F-}\n' "$ACC" "$INK"
else
    printf '%%{T2}%%{F%s}󰏤%%{F-}%%{T-} %%{F%s}still%%{F-}\n' "$DIM" "$DIM"
fi
