#!/bin/bash
# osd.sh vol up|down|mute | mic mute | bri up|down  -> change + OSD (loka island when the shell runs, dunstify otherwise)
# Volume: wpctl (PipeWire). Brightness: logind D-Bus (no root / video group needed).
STEP=5
# Held keys speed up: 5 % steps, then 10 % after 4 repeats and 20 % after 10, when the
# presses come less than 280 ms apart. Values snap to the step, so they stay round.
accel() {
    local f="${XDG_RUNTIME_DIR:-/tmp}/osd-repeat-$1" now last n
    now=$(date +%s%3N)
    read -r last n < "$f" 2>/dev/null || { last=0; n=0; }
    if [ $((now - last)) -lt 280 ]; then n=$((n + 1)); else n=0; fi
    echo "$now $n" > "$f"
    if [ "$n" -ge 10 ]; then STEP=20; elif [ "$n" -ge 4 ]; then STEP=10; fi
}
notify() { # tag icon title value text
    if [ -e "$HOME/.config/loka/shell-on" ] && pgrep -x loka >/dev/null; then
        [ "$1" = bri ] && "$HOME/.local/bin/loka" msg brightness "$4" >/dev/null 2>&1
        return
    fi
    dunstify -r 9911 -u normal -a osd -h "string:x-dunst-stack-tag:osd-$1" -h "int:value:$4" -i "$2" "$3" "$5"
}
vol() {
    case "$1" in
        up|down)
            accel vol
            cur=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%.0f", $2*100}')
            if [ "$1" = up ]; then t=$(( (cur / STEP + 1) * STEP )); else t=$(( (cur + STEP - 1) / STEP * STEP - STEP )); fi
            [ "$t" -gt 100 ] && t=100; [ "$t" -lt 0 ] && t=0
            [ "$1" = up ] && wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
            wpctl set-volume @DEFAULT_AUDIO_SINK@ "$t%" ;;
        mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
    esac
    out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)          # "Volume: 0.45 [MUTED]"
    pct=$(awk '{printf "%.0f", $2*100}' <<<"$out")
    if grep -q MUTED <<<"$out"; then notify vol audio-volume-muted "Volume" 0 "muted"
    else notify vol audio-volume-high "Volume" "$pct" "${pct}%"; fi
}
mic() {
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED; then
        notify mic microphone-sensitivity-muted "Microphone" 0 "muted"
    else notify mic microphone-sensitivity-high "Microphone" 100 "on"; fi
}
bri() {
    accel bri
    d=/sys/class/backlight/$(ls /sys/class/backlight | head -1)
    cur=$(<"$d/brightness"); max=$(<"$d/max_brightness")
    step=$((max * STEP / 100)); min=$((max / 100))
    if [ "$1" = up ]; then new=$((cur + step)); else new=$((cur - step)); fi
    [ "$new" -gt "$max" ] && new=$max
    [ "$new" -lt "$min" ] && new=$min
    busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto \
        org.freedesktop.login1.Session SetBrightness ssu backlight "$(basename "$d")" "$new" >/dev/null
    notify bri display-brightness "Brightness" $((new * 100 / max)) "$((new * 100 / max))%"
}
case "$1" in vol) vol "$2" ;; mic) mic ;; bri) bri "$2" ;; *) echo "usage: osd.sh vol up|down|mute | mic | bri up|down"; exit 1 ;; esac
