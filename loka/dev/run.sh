#!/bin/bash
D=:7
CONF="${XDG_RUNTIME_DIR:-/tmp}/loka-i3-test.conf"
grep -vE '^exec(_always)? ' "$HOME/.config/i3/config" > "$CONF"
cat >> "$CONF" <<'EXTRA'
bindsym $mod+Mod1+w exec --no-startup-id ~/.local/bin/loka-key wifi
bindsym $mod+Mod1+b exec --no-startup-id ~/.local/bin/loka-key bluetooth
bindsym $mod+Mod1+v exec --no-startup-id ~/.local/bin/loka-key audio
exec --no-startup-id ~/dotfiles/loka/dev/session.sh
EXTRA
pgrep -f "Xephyr $D" >/dev/null || {
    setsid Xephyr $D -screen 1920x1080 -no-host-grab -title loka-test >/dev/null 2>&1 &
    for _ in $(seq 1 25); do sleep 0.2; i3-msg -q '[title="loka-test"] floating enable, move to workspace 16' 2>/dev/null && break; done
}
env -u I3SOCK DISPLAY=$D LOKA_WALL="${LOKA_WALL:-$HOME/dotfiles/wallpaper/meridian/meridian.png}" setsid i3 -c "$CONF" >/tmp/loka-i3-test.log 2>&1 &
