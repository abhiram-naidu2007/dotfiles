#!/bin/bash
# A red pill with the elapsed time while a screen recording runs; nothing otherwise.
PID="${XDG_RUNTIME_DIR:-/tmp}/rice-rec.pid"
[ -s "$PID" ] && kill -0 "$(<"$PID")" 2>/dev/null || { echo; exit 0; }
while IFS=' =' read -r k v; do case $k in crit) C=$v ;; bg-solid) A=$v ;; esac; done < "$HOME/.config/polybar/colors.ini"
printf -v now '%(%s)T' -1
start=$(stat -c %Y "$PID")
t=$((now - start))
printf '%%{F%s}%%{T7}\ue0b6%%{T-}%%{F-}%%{B%s}%%{F%s}%%{T3} ● REC %d:%02d %%{T-}%%{F-}%%{B-}%%{F%s}%%{T7}\ue0b4%%{T-}%%{F-} \n' "$C" "$C" "$A" $((t / 60)) $((t % 60)) "$C"
