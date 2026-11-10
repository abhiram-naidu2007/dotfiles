#!/bin/bash
# (Re)start picom for the current mood. Called at i3 start and by `rice` when the mood changes.
# The mood decides the shadow strength and, for paper, the e-ink window shader.
. "$HOME/.cache/theme/colors.sh" 2>/dev/null
pkill -x picom
for _ in $(seq 40); do pgrep -x picom >/dev/null || break; sleep 0.05; done
pkill -9 -x picom 2>/dev/null   # a second picom cannot start while the first holds the screen
exec picom -b --shadow-opacity "${shadow_opacity:-0.42}" ${picom_shader:+--window-shader-fg "$picom_shader"}
