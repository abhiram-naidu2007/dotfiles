#!/bin/bash
[ -n "${I3SOCK:-}" ] && exit 0

WALL_DIR="$HOME/.config/hypr/wallpaper"
CUSTOM="$WALL_DIR/custom"
STATE="$HOME/.config/hypr/wallpaper.conf"
SWITCH="$HOME/.config/hypr/scripts/switch_theme.sh"
THUMBS="$(dirname "$0")/thumbs.sh"
THUMB_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/panacea/thumbs"

current() {
    grep -m1 '^\$wallpaper' "$STATE" 2>/dev/null \
        | cut -d= -f2- | sed 's/^ *//; s/ *$//'
}

case "$1" in
list)
    cur=$(current)
    find "$WALL_DIR" -maxdepth 2 -type f \
         \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
         | sort | while read -r w; do
        base=${w##*/}
        name=${base%.*}
        [ "$w" = "$cur" ] && act=yes || act=no
        case "$w" in "$CUSTOM"/*) own=yes ;; *) own=no ;; esac
        thumb="$THUMB_DIR/$name.jpg"
        [ -f "$thumb" ] && [ ! "$w" -nt "$thumb" ] || thumb="$w"
        printf '%s|%s|%s|%s|%s\n' "$name" "$thumb" "$act" "$own" "$w"
    done
    ;;

warm)
    exec "$THUMBS" all
    ;;

set)
    [ -z "$2" ] && exit 1
    exec "$SWITCH" "$2"
    ;;

add)
    src="$2"
    [ -f "$src" ] || { echo "error" >&2; exit 1; }
    mkdir -p "$CUSTOM"

    for existing in "$CUSTOM"/*; do
        if [ -f "$existing" ] && cmp -s "$src" "$existing"; then
            "$SWITCH" "$existing" >/dev/null 2>&1
            basename "$existing" | sed 's/\.[^.]*$//'
            exit 0
        fi
    done

    base=$(basename "$src")
    slug=$(printf '%s' "${base%.*}" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' \
           | tr -cd '[:alnum:]_-')
    [ -z "$slug" ] && slug="wall_$(date +%s)"
    ext="${base##*.}"
    dest="$CUSTOM/$slug.$ext"
    [ -e "$dest" ] && dest="$CUSTOM/${slug}_$(date +%s).$ext"
    cp -f "$src" "$dest" || exit 1
    "$SWITCH" "$dest" >/dev/null 2>&1
    basename "$dest" | sed 's/\.[^.]*$//'
    ;;

del)
    [ -z "$2" ] && exit 1
    rm -f "$CUSTOM/$2".* 2>/dev/null
    ;;

*)
    echo "usage: themes.sh list | set <name> | add <file> | del <name>" >&2
    exit 1
    ;;
esac
