#!/bin/bash

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/panacea/thumbs"
WALLS="$HOME/.config/hypr/wallpaper"
WIDTH=1100

mkdir -p "$CACHE"

make_thumb() {
    local src="$1"
    [ -f "$src" ] || return 1

    local name
    name=$(basename "$src")
    name="${name%.*}.jpg"
    local dst="$CACHE/$name"

    if [ ! -f "$dst" ] || [ "$src" -nt "$dst" ]; then
        ffmpeg -loglevel error -y -i "$src" \
               -vf "scale=$WIDTH:-1" -q:v 5 "$dst" </dev/null || return 1
    fi
    printf '%s\n' "$dst"
}

LOCKBG="${XDG_CACHE_HOME:-$HOME/.cache}/panacea/lockbg"
LOCK_WIDTH=1920

make_lockbg() {
    local src="$1"
    [ -f "$src" ] || return 1
    mkdir -p "$LOCKBG"

    local name
    name=$(basename "$src")
    name="${name%.*}.jpg"
    local dst="$LOCKBG/$name"

    if [ ! -f "$dst" ] || [ "$src" -nt "$dst" ]; then
        ffmpeg -loglevel error -y -i "$src" \
               -vf "scale='min($LOCK_WIDTH,iw)':-2" -q:v 2 "$dst" </dev/null || return 1
    fi
    printf '%s\n' "$dst"
}

case "$1" in
    thumb)
        make_thumb "$2"
        ;;
    lockbg)
        make_lockbg "$2"
        ;;
    path)
        src="$2"
        [ -f "$src" ] || exit 1
        name=$(basename "$src"); name="${name%.*}.jpg"
        dst="$CACHE/$name"
        [ -f "$dst" ] && [ ! "$src" -nt "$dst" ] && printf '%s\n' "$dst"
        ;;
    all)
        find "$WALLS" -maxdepth 2 -type f \
             \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        | while read -r f; do
            make_thumb "$f" >/dev/null
        done
        ;;
    *)
        echo "usage: thumbs.sh thumb <path> | lockbg <path> | all" >&2
        exit 1
        ;;
esac
