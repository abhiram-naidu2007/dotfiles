#!/bin/bash
# The current mood as an icon (polybar restarts whenever `rice` changes it).
while IFS=' =' read -r k v; do
    case $k in mode) MODE=$v ;; bryellow) SUN=$v ;; accent) MOON=$v ;; fg) INK=$v ;; esac
done < "$HOME/.config/polybar/colors.ini"
case $MODE in
    day)   printf '%%{T2}%%{F%s}󰖨%%{F-}%%{T-}\n' "$SUN" ;;
    paper) printf '%%{T2}%%{F%s}󰂺%%{F-}%%{T-}\n' "$INK" ;;
    *)     printf '%%{T2}%%{F%s}󰖔%%{F-}%%{T-}\n' "$MOON" ;;
esac
