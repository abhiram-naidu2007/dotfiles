#!/bin/bash
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/loka"
STATE="$STATE_DIR/record.state"
mkdir -p "$STATE_DIR"

read_state() {
    PID=""; STARTED=""; PAUSED_AT=""; PAUSED_TOTAL=0; FILE=""; MODULES=""
    if [ ! -f "$STATE" ]; then
        local rp="${XDG_RUNTIME_DIR:-/tmp}/rice-rec.pid" rf="${XDG_RUNTIME_DIR:-/tmp}/rice-rec.path"
        [ -s "$rp" ] || return 1
        PID=$(<"$rp")
        kill -0 "$PID" 2>/dev/null || return 1
        FILE=$(cat "$rf" 2>/dev/null)
        STARTED=$(( $(date +%s) - $(ps -o etimes= -p "$PID" | tr -d ' ') ))
        LEGACY=1
        return 0
    fi
    . "$STATE"
    [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null
}

write_state() {
    cat > "$STATE" <<EOF
PID=$PID
STARTED=$STARTED
PAUSED_AT=$PAUSED_AT
PAUSED_TOTAL=$PAUSED_TOTAL
FILE="$FILE"
MODULES="$MODULES"
EOF
}

default_monitor() {
    local sink
    sink=$(pactl get-default-sink 2>/dev/null)
    [ -n "$sink" ] && printf '%s.monitor\n' "$sink"
}

default_mic() { pactl get-default-source 2>/dev/null; }

unload_modules() {
    local ids="$1"
    for id in $ids; do pactl unload-module "$id" 2>/dev/null; done
}

finalize() {
    f="$1"
    [ -s "$f" ] || return 0
    has_audio=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$f" 2>/dev/null | head -1)
    tmp="${f%.mp4}.tmp.mp4"
    if [ -n "$has_audio" ]; then
        ffmpeg -y -v error -i "$f" -c copy -movflags +faststart "$tmp" 2>/dev/null
    else
        ffmpeg -y -v error -i "$f" \
               -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 \
               -shortest -c:v copy -c:a aac -b:a 96k \
               -movflags +faststart "$tmp" 2>/dev/null
    fi

    if [ -s "$tmp" ]; then mv -f "$tmp" "$f"; else rm -f "$tmp"; fi
}

case "$1" in
    start)
        if read_state; then echo "already" >&2; exit 1; fi
        FPS="${2:-60}"
        DIR="${3:-$HOME/Videos}"
        SYS="${4:-0}"
        MIC="${5:-0}"
        MIC_DEV="${6:-}"
        OUTPUT="${7:-}"

        DIR="${DIR/#\~/$HOME}"
        mkdir -p "$DIR" || exit 1
        FILE="$DIR/rec-$(date +%F_%H-%M-%S).mp4"

        [ -z "$MIC_DEV" ] && MIC_DEV=$(default_mic)
        SYS_DEV=$(default_monitor)

        MODULES=""
        AUDIO_DEV=""

        if [ "$SYS" = "1" ] && [ "$MIC" = "1" ]; then
            m=$(pactl load-module module-null-sink sink_name=loka_mix \
                    sink_properties=device.description=LokaMix 2>/dev/null) || m=""
            if [ -n "$m" ]; then
                MODULES="$m"
                l1=$(pactl load-module module-loopback source="$SYS_DEV" \
                        sink=loka_mix latency_msec=40 2>/dev/null) && MODULES="$MODULES $l1"
                l2=$(pactl load-module module-loopback source="$MIC_DEV" \
                        sink=loka_mix latency_msec=40 2>/dev/null) && MODULES="$MODULES $l2"
                AUDIO_DEV="loka_mix.monitor"
            else
                AUDIO_DEV="$SYS_DEV"
            fi
        elif [ "$SYS" = "1" ]; then
            AUDIO_DEV="$SYS_DEV"
        elif [ "$MIC" = "1" ]; then
            AUDIO_DEV="$MIC_DEV"
        fi

        X=0; Y=0
        read -r W H < <(xdotool getdisplaygeometry)
        if [ "$OUTPUT" = area ]; then
            sel=$(slop -o -b 2 -c 1,1,1,1 -f '%x %y %w %h' 2>/dev/null) || { unload_modules "$MODULES"; exit 1; }
            read -r X Y W H <<< "$sel"
            sleep 0.15
        elif [ -n "$OUTPUT" ]; then
            geo=$(xrandr --listmonitors 2>/dev/null | awk -v o="$OUTPUT" '$NF == o { print $3 }')
            if [ -n "$geo" ]; then
                W=${geo%%/*}; rest=${geo#*x}; H=${rest%%/*}
                X=$(sed -E 's/.*\+([0-9]+)\+([0-9]+)$/\1/' <<< "$geo"); Y=$(sed -E 's/.*\+([0-9]+)\+([0-9]+)$/\2/' <<< "$geo")
            fi
        fi
        W=$(( W / 2 * 2 )); H=$(( H / 2 * 2 ))
        if [ "$W" -lt 160 ] || [ "$H" -lt 120 ]; then
            unload_modules "$MODULES"
            notify-send -a Recording -i dialog-warning "Recording not started" "area ${W}x${H} is too small"
            exit 1
        fi
        grab=(-f x11grab -framerate "$FPS" -video_size "${W}x${H}" -i "${DISPLAY:-:0}+${X},${Y}")
        audio=()
        [ -n "$AUDIO_DEV" ] && audio=(-f pulse -i "$AUDIO_DEV" -c:a aac -b:a 160k)

        gpu=""
        for node in /dev/dri/renderD*; do
            case "$(basename "$(readlink -f "/sys/class/drm/${node##*/}/device/driver")")" in i915|xe|amdgpu|radeon) gpu=$node; break ;; esac
        done

        attempt() {
            setsid ffmpeg -loglevel error "$@" >"$STATE_DIR/record.log" 2>&1 < /dev/null &
            PID=$!
            sleep 0.6
            kill -0 "$PID" 2>/dev/null
        }

        started=0
        if [ -n "$gpu" ]; then
            attempt -vaapi_device "$gpu" "${grab[@]}" "${audio[@]}" \
                -vf 'format=bgr0,hwupload,scale_vaapi=format=nv12' -c:v h264_vaapi -qp 22 -movflags +faststart "$FILE" && started=1
        fi
        if [ "$started" = 0 ]; then
            rm -f "$FILE"
            attempt "${grab[@]}" "${audio[@]}" -c:v libx264 -preset ultrafast -crf 22 -pix_fmt yuv420p -movflags +faststart "$FILE" && started=1
        fi

        if [ "$started" = 0 ]; then
            unload_modules "$MODULES"
            echo "failed" >&2
            tail -4 "$STATE_DIR/record.log" >&2
            notify-send -a Recording -u critical "Recording did not start" "$(tail -2 "$STATE_DIR/record.log" 2>/dev/null | tr '\n' ' ')"
            exit 1
        fi

        STARTED=$(date +%s)
        PAUSED_AT=""
        PAUSED_TOTAL=0
        write_state
        echo "$FILE"
        ;;

    pause)
        read_state || { echo "idle" >&2; exit 1; }
        if [ -n "$PAUSED_AT" ]; then
            kill -CONT "$PID"
            PAUSED_TOTAL=$(( PAUSED_TOTAL + $(date +%s) - PAUSED_AT ))
            PAUSED_AT=""
        else
            kill -STOP "$PID"
            PAUSED_AT=$(date +%s)
        fi
        write_state
        ;;

    stop)
        read_state || { echo "idle" >&2; exit 1; }
        [ -n "$PAUSED_AT" ] && kill -CONT "$PID"
        kill -INT "$PID" 2>/dev/null
        for _ in $(seq 1 50); do
            kill -0 "$PID" 2>/dev/null || break
            sleep 0.1
        done
        kill -0 "$PID" 2>/dev/null && kill -TERM "$PID" 2>/dev/null
        unload_modules "$MODULES"
        rm -f "$STATE"
        [ -n "$LEGACY" ] && rm -f "${XDG_RUNTIME_DIR:-/tmp}/rice-rec.pid" "${XDG_RUNTIME_DIR:-/tmp}/rice-rec.path"
        finalize "$FILE"
        echo "$FILE"
        ;;

    status)
        if read_state; then
            if [ -n "$PAUSED_AT" ]; then
                echo "paused|$PID|$STARTED|$(( PAUSED_TOTAL + $(date +%s) - PAUSED_AT ))|$FILE"
            else
                echo "rec|$PID|$STARTED|$PAUSED_TOTAL|$FILE"
            fi
        else
            if [ -f "$STATE" ]; then
                . "$STATE"
                unload_modules "$MODULES"
                rm -f "$STATE"
            fi
            echo "idle"
        fi
        ;;

    *)
        echo "usage: record.sh start FPS DIR SYS MIC [MIC_DEV [OUTPUT|area]] | pause | stop | status" >&2
        exit 1
        ;;
esac
