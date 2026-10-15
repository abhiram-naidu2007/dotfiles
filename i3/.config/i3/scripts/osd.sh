#!/bin/bash
# osd.sh vol up|down|mute | mic mute | bri up|down  -> change + dunst progress popup
# Volume: wpctl (PipeWire). Brightness: logind D-Bus (no root / video group needed).
STEP=5
notify() { # tag icon title value text
    dunstify -r 9911 -u low -a osd -h "string:x-dunst-stack-tag:osd-$1" -h "int:value:$4" -i "$2" "$3" "$5"
}
vol() {
    case "$1" in
        up)   wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ ${STEP}%+ ;;
        down) wpctl set-volume @DEFAULT_AUDIO_SINK@ ${STEP}%- ;;
        mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
    esac
    out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)          # "Volume: 0.45 [MUTED]"
    pct=$(awk '{printf "%d", $2*100}' <<<"$out")
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
