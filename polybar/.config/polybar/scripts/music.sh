#!/bin/bash
# Now-playing pill for any MPRIS player (limusic, browser tabs, mpv ...):
#   note  title (scrolls inside a fixed width)   previous  play/pause  next
# The pill is always the same width while it is shown, so the rest of the bar never shifts.
# Bash builtins only: scrolling forks nothing, and with nothing playing the script sleeps on a pipe.
#   music.sh ctl play|prev|next|forward|back   act on the player shown (used by the click areas)
#   music.sh ctl hide                          show / hide the title (right click); the buttons stay
RUN="${XDG_RUNTIME_DIR:-/tmp}/rice-music"      # line 1: player instance, line 2: status (read by `ctl`)
SELF="$HOME/.config/polybar/scripts/music.sh"
HIDE="${XDG_STATE_HOME:-$HOME/.local/state}/rice/music-hide-title"

if [ "$1" = ctl ] && [ "$2" = hide ]; then
    if [ -e "$HIDE" ]; then rm -f "$HIDE"; else mkdir -p "${HIDE%/*}"; : > "$HIDE"; fi
    pkill -USR1 -f "^/bin/bash $SELF\$" 2>/dev/null     # wake the running copy so it redraws
    exit 0
fi
if [ "$1" = ctl ]; then
    { read -r player; } < "$RUN" 2>/dev/null
    [ -n "$player" ] || exit 0
    case "$2" in
        play)    exec playerctl -p "$player" play-pause ;;
        prev)    exec playerctl -p "$player" previous ;;
        next)    exec playerctl -p "$player" next ;;
        forward) exec playerctl -p "$player" position 5+ ;;
        back)    exec playerctl -p "$player" position 5- ;;
    esac
    exit 0
fi

while IFS=' =' read -r k v; do
    case $k in surface) S=$v ;; accent2) NOTE=$v ;; fg) FG=$v ;; subtext) SUB=$v ;; accent) ACC=$v ;; esac
done < "$HOME/.config/polybar/colors.ini"
CL=$'\ue0b6' CR=$'\ue0b4'
WIDTH=14
TICK=0.5

declare -A status text
order=()                                   # players, most recently changed last
coproc PC { exec playerctl -a --follow metadata --format '{{playerInstance}}|{{status}}|{{artist}}|{{title}}' 2>/dev/null; }

cur= state= tick=0 last=
trap 'rm -f "$RUN"' EXIT
trap ':' USR1                              # interrupts the read below; the loop then redraws
while :; do
    if [ "$state" = Playing ]; then
        IFS= read -r -t "$TICK" line <&"${PC[0]}"; rc=$?
    else
        IFS= read -r line <&"${PC[0]}"; rc=$?
    fi
    if [ "$rc" = 0 ]; then
        if [ -z "$line" ]; then             # a player went away: forget those that no longer exist
            alive=$(playerctl -l 2>/dev/null)
            for p in "${!status[@]}"; do
                case $'\n'"$alive"$'\n' in *$'\n'"$p"$'\n'*) ;; *) unset "status[$p]" "text[$p]" ;; esac
            done
        else
            IFS='|' read -r p st artist title <<< "$line"
            if [ -n "$p" ]; then
                status[$p]=$st
                t=$title; [ -n "$artist" ] && t="$artist · $title"
                text[$p]=${t//%\{/}
                new=(); for q in "${order[@]}"; do [ "$q" != "$p" ] && new+=("$q"); done
                order=("${new[@]}" "$p")
            fi
        fi
        # show the newest player that is playing, else the newest one at all
        cur=
        for q in "${order[@]}"; do [ -n "${status[$q]}" ] && cur=$q; done
        for q in "${order[@]}"; do [ "${status[$q]}" = Playing ] && cur=$q; done
        state=; [ -n "$cur" ] && state=${status[$cur]}
        printf '%s\n%s\n' "$cur" "$state" > "$RUN"
        tick=0
    elif [ "$rc" -le 128 ]; then
        break                               # playerctl itself exited
    fi

    if [ -z "$cur" ] || [ -z "${text[$cur]}" ]; then
        out=
    else
        t=${text[$cur]}
        shown=$t
        if [ "${#t}" -gt "$WIDTH" ]; then
            ring="$t   ·   "
            pos=$(( tick % ${#ring} ))
            shown=${ring:pos}${ring:0:pos}
            shown=${shown:0:WIDTH}
        fi
        [ -e "$HIDE" ] && shown='· · ·'
        if [ "$state" = Playing ]; then button=󰏤; else button=󰐊; fi
        printf -v shown '%-*s' "$WIDTH" "$shown"            # short titles are padded: the pill keeps its width
        out="%{F$S}%{T7}$CL%{T-}%{F-}%{B$S} %{T2}%{F$NOTE}󰎈%{F-}%{T-} %{F$FG}%{A1:$SELF ctl play:}%{A3:$SELF ctl hide:}$shown%{A}%{A}%{F-} %{T2}%{F$SUB}%{A1:$SELF ctl prev:}󰒮%{A} %{F$ACC}%{A1:$SELF ctl play:}$button%{A}%{F$SUB} %{A1:$SELF ctl next:}󰒭%{A}%{F-}%{T-} %{B-}%{F$S}%{T7}$CR%{T-}%{F-} "
    fi
    [ "$out" != "$last" ] && { printf '%s\n' "$out"; last=$out; }
    tick=$((tick + 1))
done
echo
