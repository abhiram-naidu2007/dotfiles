#!/usr/bin/env bash
set -u

RUN="${XDG_RUNTIME_DIR:-/tmp}"
CACHE="$RUN/panacea-brightness.map"
STATE="$RUN/panacea-bright.streak"

MIN=1
MAX=100

have() { command -v "$1" >/dev/null 2>&1; }

has_battery() {
    local d
    for d in /sys/class/power_supply/*; do
        [ -r "$d/type" ] || continue
        [ "$(cat "$d/type" 2>/dev/null)" = "Battery" ] && return 0
    done
    return 1
}

has_touchpad() {
    have hyprctl || return 1
    hyprctl -j devices 2>/dev/null | grep -qiE '"name": *"[^"]*(touchpad|synaptics|trackpad)' && return 0
    grep -qiE 'touchpad|synaptics' /proc/bus/input/devices 2>/dev/null
}

backlight_dev() {
    local d
    for d in /sys/class/backlight/*; do
        [ -d "$d" ] || continue
        basename "$d"; return 0
    done
    return 1
}

backend() {
    backlight_dev >/dev/null 2>&1 && { echo backlight; return; }
    have ddcutil && [ -e /dev/i2c-0 ] && { echo ddc; return; }
    echo none
}

cmd_detect() {
    local b; b="$(backend)"
    echo "backend=$b"
    if has_battery; then echo "battery=1"; echo "chassis=laptop"
    else echo "battery=0"; echo "chassis=desktop"; fi
    has_touchpad && echo "touchpad=1" || echo "touchpad=0"
    have ddcutil && echo "ddcutil=1" || echo "ddcutil=0"
}

bl_get() { brightnessctl -d "$1" -m 2>/dev/null | LC_ALL=C awk -F, '{gsub("%","",$4); print $4}'; }
bl_set() { brightnessctl -d "$1" -q s "$2%" 2>/dev/null; }

ddc_scan() {
    local bus="" conn=""
    ddcutil detect --brief 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            *"I2C bus:"*)       bus="${line##*/dev/i2c-}" ;;
            *"DRM connector:"*)
                conn="${line##*: }"
                conn="$(echo "$conn" | tr -d ' \t')"
                conn="${conn#card*-}"
                [ -n "$bus" ] && [ -n "$conn" ] && printf '%s\t%s\n' "$bus" "$conn"
                bus=""; conn=""
                ;;
        esac
    done
}

ddc_map() {
    [ -s "$CACHE" ] || ddc_scan > "$CACHE" 2>/dev/null
    cat "$CACHE" 2>/dev/null
}

ddc_get() { ddcutil --bus "$1" getvcp 10 --brief 2>/dev/null | LC_ALL=C awk '{print $4}'; }
ddc_set() { ddcutil --bus "$1" setvcp 10 "$2" >/dev/null 2>&1; }

clamp() {
    local p="$1"
    [ "$p" -lt "$MIN" ] && p="$MIN"
    [ "$p" -gt "$MAX" ] && p="$MAX"
    echo "$p"
}

cmd_list() {
    case "$(backend)" in
        backlight)
            local d; d="$(backlight_dev)" || return 0
            printf 'bl:%s\t%s\t%s\n' "$d" "$(tr -d '\n' <<<"${DISPLAY_LABEL:-Built-in display}")" "$(bl_get "$d")"
            ;;
        ddc)
            local bus conn pct
            while IFS=$'\t' read -r bus conn; do
                [ -n "$bus" ] || continue
                pct="$(ddc_get "$bus")"
                [ -n "$pct" ] || continue
                printf 'ddc:%s\t%s\t%s\n' "$bus" "$conn" "$pct"
            done < <(ddc_map)
            ;;
    esac
}

cmd_get() {
    case "$1" in
        bl:*)  bl_get "${1#bl:}" ;;
        ddc:*) ddc_get "${1#ddc:}" ;;
    esac
}

cmd_set() {
    local id="$1" pct; pct="$(clamp "$2")"
    case "$id" in
        bl:*)  bl_set "${id#bl:}" "$pct" ;;
        ddc:*) ddc_set "${id#ddc:}" "$pct" ;;
    esac
    echo "$pct"
}

first_id() { cmd_list | head -1 | cut -f1; }

step_now() {
    local now streak=0 last prev
    now="$(date +%s%3N)"
    if [ -f "$STATE" ]; then
        read -r last prev < "$STATE" 2>/dev/null
        if [ -n "${last:-}" ] && [ $(( now - last )) -lt 280 ]; then
            streak=$(( ${prev:-0} + 1 ))
        fi
    fi
    echo "$now $streak" > "$STATE"
    if   [ "$streak" -lt 4 ];  then echo 5
    elif [ "$streak" -lt 10 ]; then echo 10
    else                            echo 20
    fi
}

cmd_step() {
    local dir="$1" id cur step pct
    id="$(first_id)"; [ -n "$id" ] || exit 1
    cur="$(cmd_get "$id")"; [ -n "$cur" ] || exit 1
    step="$(step_now)"
    if [ "$dir" = up ]; then
        pct=$(( (cur / step) * step + step ))
    else
        pct=$(( ( (cur + step - 1) / step ) * step - step ))
    fi
    pct="$(cmd_set "$id" "$pct")"

    if pgrep -x qs >/dev/null 2>&1; then
        "$HOME/.local/bin/loka-ipc" brightness "$pct" 2>/dev/null &
    fi
}

case "${1:-}" in
    detect)  cmd_detect ;;
    list)    cmd_list ;;
    rescan)  rm -f "$CACHE"; ddc_map >/dev/null; cmd_list ;;
    get)     cmd_get "${2:-}" ;;
    set)     cmd_set "${2:-}" "${3:-0}" ;;
    up)      cmd_step up ;;
    down)    cmd_step down ;;
    *)       echo "usage: brightness.sh detect|list|rescan|get <id>|set <id> <pct>|up|down" >&2; exit 1 ;;
esac
