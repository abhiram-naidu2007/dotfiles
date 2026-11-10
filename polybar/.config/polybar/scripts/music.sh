#!/bin/bash
# Animated now-playing pill: equalizer bars plus a scrolling title.
# Bash builtins only, so the animation forks nothing. Blocks without a timer unless playing.
# Empty output when limusic is not running.
while IFS=' =' read -r k v; do
    case $k in accent2) S=$v ;; bg-solid) A=$v; T=$v ;; esac
done < "$HOME/.config/polybar/colors.ini"

CL=$'' CR=$''
BARS=(▂ ▄ ▆ █ ▅ ▃)
WIDTH=14
TICK=0.25

coproc PC { exec playerctl -p limusic --follow metadata --format '{{status}}|{{artist}} · {{title}}' 2>/dev/null; }

status= text= tick=0 last=
while :; do
    if [ "$status" = Playing ]; then
        IFS= read -r -t "$TICK" line <&"${PC[0]}"; rc=$?
    else
        IFS= read -r line <&"${PC[0]}"; rc=$?
    fi
    if [ "$rc" = 0 ]; then
        status=${line%%|*}; text=${line#*|}; text=${text//%\{/}; tick=0
    elif [ "$rc" -le 128 ]; then
        break   # playerctl exited
    fi

    if [ -z "$status" ] || [ -z "$text" ]; then
        out=
    else
        shown=$text
        if [ "${#text}" -gt "$WIDTH" ]; then
            ring="$text   ·   "
            pos=$(( (tick / 2) % ${#ring} ))
            shown=${ring:pos}${ring:0:pos}
            shown=${shown:0:WIDTH}
        fi
        if [ "$status" = Playing ]; then
            eq=${BARS[tick % 6]}${BARS[(tick + 2) % 6]}${BARS[(tick + 4) % 6]}
        else
            eq=▂▂▂
        fi
        out="%{F$S}%{T7}$CL%{T-}%{F-}%{B$S} %{F$A}$eq%{F-} %{F$T}$shown%{F-} %{B-}%{F$S}%{T7}$CR%{T-}%{F-}   "
    fi
    [ "$out" != "$last" ] && { printf '%s\n' "$out"; last=$out; }
    tick=$((tick + 1))
done
echo
