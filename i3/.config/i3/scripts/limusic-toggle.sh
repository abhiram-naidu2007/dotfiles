#!/bin/sh
# Toggle limusic scratchpad. Launch on demand (no autostart = no idle RAM).
SEL='[class="(?i)limusic"]'
if ! pgrep -x limusic-app >/dev/null; then
    setsid "$HOME/.local/bin/limusic.AppImage" >/dev/null 2>&1 &
    i=0
    while [ $i -lt 40 ]; do
        sleep 0.5
        i3-msg "$SEL scratchpad show" 2>/dev/null | grep -q '"success":true' && exit 0
        i=$((i+1))
    done
    exit 1
fi
i3-msg "$SEL scratchpad show" >/dev/null
