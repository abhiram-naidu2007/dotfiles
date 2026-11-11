#!/bin/sh
# Show / hide limusic (scratchpad). Started on first use, never at login.
# rice.so restyles it in the desktop palette (dotfiles/limusic).
SEL='[class="(?i)limusic" title="^Limusic$"]'
if ! pgrep -x limusic-app >/dev/null; then
    # WebKit on NVIDIA's EGL segfaults (SkiaGPUWorker in libnvidia-eglcore) and wakes the dGPU;
    # the Intel GPU drives the screen, so render there.
    mesa=/usr/share/glvnd/egl_vendor.d/50_mesa.json
    [ -r "$mesa" ] && export __EGL_VENDOR_LIBRARY_FILENAMES="$mesa"
    rice="$HOME/.local/lib/limusic-rice/rice.so"
    [ -r "$rice" ] && export LD_PRELOAD="$rice${LD_PRELOAD:+:$LD_PRELOAD}"
    setsid "$HOME/.local/bin/limusic.AppImage" >/dev/null 2>&1 < /dev/null &
    i=0
    while [ $i -lt 100 ]; do
        sleep 0.2
        i3-msg "$SEL scratchpad show" 2>/dev/null | grep -q '"success":true' && exit 0
        i=$((i+1))
    done
    exit 1
fi
i3-msg "$SEL scratchpad show" >/dev/null
