#!/bin/bash
# A small cat on the bar, in a pill whose color follows its mood. It sleeps when the CPU is idle, dances when busy, panics under
# full load, and shows hearts when clicked. Bash builtins only, so animating forks nothing.
while IFS=' =' read -r k v; do
    case $k in
        blue) IDLE=$v ;; green) CHILL=$v ;; yellow) BUSY=$v ;; crit) PANIC=$v ;; magenta) LOVE=$v ;; bg-solid) INK=$v ;;
    esac
done < "$HOME/.config/polybar/colors.ini"

CL=$'\ue0b6' CR=$'\ue0b4'
exec 9<> <(:)   # a pipe that never delivers, so read -t can sleep without forking

hearts=0
trap 'hearts=8' USR1

prev_active=0 prev_total=0 load=0 tick=0
while :; do
    if (( tick % 6 == 0 )); then
        read -r _ u n s i w q sq st _ < /proc/stat
        active=$((u + n + s + q + sq + st)); total=$((active + i + w))
        dt=$((total - prev_total))
        (( dt > 0 && prev_total > 0 )) && load=$(( 100 * (active - prev_active) / dt ))
        prev_active=$active prev_total=$total
    fi

    if (( hearts > 0 )); then
        hearts=$((hearts - 1)); col=$LOVE; delay=0.25
        frames=('(=^ω^=) ♡' '(=^ω^=)♡ ')
    elif (( load < 12 )); then
        col=$IDLE; delay=0.9
        frames=('(=-ω-=) zZ' '(=-ω-=) Zz')
    elif (( load < 40 )); then
        col=$CHILL; delay=0.7
        frames=('(=^･ω･^=)' '(=^･ω･^=)' '(=^-ω-^=)')
    elif (( load < 75 )); then
        col=$BUSY; delay=0.3
        frames=('ヽ(=^ω^=)ノ' 'ノ(=^ω^=)ヽ')
    else
        col=$PANIC; delay=0.25
        frames=('(=ﾟДﾟ=) !!' '(=ﾟДﾟ=)!! ')
    fi

    printf '%%{F%s}%%{T7}%s%%{T-}%%{B%s}%%{F%s} %s %%{F-}%%{B-}%%{F%s}%%{T7}%s%%{T-}%%{F-}\n' \
        "$col" "$CL" "$col" "$INK" "${frames[tick % ${#frames[@]}]}" "$col" "$CR"
    tick=$((tick + 1))
    read -r -t "$delay" -u 9 _
done
