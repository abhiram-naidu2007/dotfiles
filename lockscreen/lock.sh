#!/bin/bash

IMG="$HOME/.cache/theme/lock.png"
GEN="$HOME/dotfiles/lockscreen/generate-lockscreen.sh"
# -e: ignore empty password   -f: show failed attempts   -c: fill colour behind the image
LOCK=(i3lock -e -f -c 15192a -i "$IMG")

# Regenerate only when missing or older than the generator / picture.
if [ ! -s "$IMG" ] || [ "$GEN" -nt "$IMG" ] || [ "$HOME/dotfiles/lockscreen/assets/lock-wallpaper-edit.png" -nt "$IMG" ]; then
    "$GEN"
fi

# xss-lock --transfer-sleep-lock passes a sleep-delay lock in XSS_SLEEP_LOCK_FD.
# Release it once i3lock has locked the screen, or suspend waits the full
# logind InhibitDelayMaxSec (30s) on every lid close.
if [[ -e /dev/fd/${XSS_SLEEP_LOCK_FD:--1} ]]; then
    kill_i3lock() { pkill -xu "$EUID" "$@" i3lock; }
    trap kill_i3lock TERM INT

    # i3lock forks after the screen is locked; it must not inherit the fd
    "${LOCK[@]}" {XSS_SLEEP_LOCK_FD}<&-

    exec {XSS_SLEEP_LOCK_FD}<&-

    # stay alive until unlock so xss-lock tracks the locker
    while kill_i3lock -0; do
        sleep 0.5
    done
else
    trap 'kill %%' TERM INT
    "${LOCK[@]}" -n &
    wait
fi
