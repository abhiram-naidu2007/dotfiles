#!/bin/bash
# Screenshots and screen recordings.
#   capture.sh shot area|window|screen    -> ~/Pictures/shot-<time>.png, also on the clipboard
#   capture.sh rec area|screen [sound]    start recording -> ~/Videos/rec-<time>.mp4 (sound = what the speakers play)
#   capture.sh rec stop                   stop it (also: click the red REC pill on the bar)
#   capture.sh rec toggle                 stop if recording, else select an area and start
#   capture.sh menu                       all of the above as tiles
# Area: drag a rectangle, or click a window to take exactly that window. Esc or right click cancels.
. "$HOME/.cache/theme/colors.sh" 2>/dev/null
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/rice-rec.pid"
OUTFILE="${XDG_RUNTIME_DIR:-/tmp}/rice-rec.path"

# x y w h of a dragged rectangle or a clicked window. -o: plain X drawing, so the compositor
# has nothing to blur or animate; the frame is 2 px in the accent colour.
select_area() {
  local c=${accent_rgb:-162, 188, 254} r g b
  IFS=', ' read -r r g b <<< "$c"
  slop -o -b 2 -c "$(awk -v r="$r" -v g="$g" -v b="$b" 'BEGIN{printf "%.3f,%.3f,%.3f,1", r/255, g/255, b/255}')" -f '%x %y %w %h' 2>/dev/null
}

shot() {
  local f geom x y w h
  mkdir -p "$HOME/Pictures"
  f="$HOME/Pictures/shot-$(date +%F_%H-%M-%S).png"
  case "$1" in
    area)   geom=$(select_area) || exit 0               # Esc or right click: nothing happens
            read -r x y w h <<< "$geom"
            [ -n "$w" ] && [ "$w" -gt 2 ] || exit 0
            sleep 0.15                                   # let the selection frame leave the screen
            maim -u -g "${w}x${h}+${x}+${y}" "$f" ;;
    window) maim -u -i "$(xdotool getactivewindow)" "$f" ;;
    *)      maim -u "$f" ;;
  esac || exit 1
  xclip -selection clipboard -t image/png < "$f"
  dunstify -a capture -t 3500 -i "$f" "Screenshot" "on the clipboard · ${f/#$HOME/\~}"
}

recording() { [ -s "$PIDFILE" ] && kill -0 "$(<"$PIDFILE")" 2>/dev/null; }

rec_stop() {
  recording || return 0
  local pid f
  pid=$(<"$PIDFILE"); f=$(cat "$OUTFILE" 2>/dev/null)
  kill -INT "$pid"                                       # ffmpeg finishes the file on SIGINT
  for _ in $(seq 50); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  rm -f "$PIDFILE" "$OUTFILE"
  printf %s "$f" | xclip -selection clipboard
  dunstify -a capture -t 5000 -i video-x-generic "Recording saved" "${f/#$HOME/\~}  ($(du -h "$f" 2>/dev/null | cut -f1))
path is on the clipboard"
}

rec_start() {
  local geom x=0 y=0 w h f sink audio=()
  recording && { rec_stop; return; }
  if [ "$1" = area ]; then
    geom=$(select_area) || exit 0
    read -r x y w h <<< "$geom"
    [ -n "$w" ] && [ "$w" -gt 16 ] || exit 0
    sleep 0.15
  else
    read -r w h < <(xdotool getdisplaygeometry)
  fi
  w=$(( w / 2 * 2 )); h=$(( h / 2 * 2 ))                 # H.264 needs even sizes
  if [ "$2" = sound ]; then
    sink=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk -F'"' '/node.name/ {print $2; exit}')
    [ -n "$sink" ] && audio=(-f pulse -i "$sink.monitor" -c:a aac -b:a 160k)
  fi
  if [ "$w" -lt 160 ] || [ "$h" -lt 120 ]; then          # a stray click on the bar or a tiny drag
    dunstify -a capture -t 3500 -i dialog-warning "Recording not started" "area ${w}x${h} is too small: drag a rectangle or click a window"
    exit 0
  fi
  mkdir -p "$HOME/Videos"
  f="$HOME/Videos/rec-$(date +%F_%H-%M-%S).mp4"
  # Hardware path (Intel/AMD VAAPI): the frame is uploaded as it is and converted and encoded on
  # the GPU, about 17% of one core at 1080p30. Converting on the CPU costs a whole core, so
  # x264 is only the fallback for machines without a VAAPI encoder.
  local node gpu=
  for node in /dev/dri/renderD*; do
    case "$(basename "$(readlink -f "/sys/class/drm/${node##*/}/device/driver")")" in i915|xe|amdgpu|radeon) gpu=$node; break ;; esac
  done
  local grab=(-f x11grab -framerate 30 -video_size "${w}x${h}" -i "${DISPLAY:-:0}+${x},${y}")
  if [ -n "$gpu" ]; then
    setsid ffmpeg -loglevel error -vaapi_device "$gpu" "${grab[@]}" "${audio[@]}" \
      -vf 'format=bgr0,hwupload,scale_vaapi=format=nv12' -c:v h264_vaapi -qp 22 -movflags +faststart "$f" >/dev/null 2>&1 &
    echo $! > "$PIDFILE"; echo "$f" > "$OUTFILE"
    sleep 0.7
  fi
  if ! recording; then
    rm -f "$f"
    setsid ffmpeg -loglevel error "${grab[@]}" "${audio[@]}" \
      -c:v libx264 -preset ultrafast -crf 22 -pix_fmt yuv420p -movflags +faststart "$f" >/dev/null 2>&1 &
    echo $! > "$PIDFILE"; echo "$f" > "$OUTFILE"
    sleep 0.5
  fi
  if recording; then dunstify -a capture -t 2500 -i media-record "Recording" "click REC on the bar, or Super+Ctrl+R, to stop"
  else rm -f "$PIDFILE" "$OUTFILE"; dunstify -a capture -u critical "Recording did not start" "ffmpeg exited"; fi
}

menu() {
  local choice tile
  tile() { printf "<span font='JetBrainsMono Nerd Font 24'>%s</span>\n%s" "$1" "$2"; }
  if recording; then
    choice=$(printf '%s\0' "$(tile 󰙧 'stop recording')" | rofi -dmenu -sep '\0' -eh 4 -markup-rows -i -format i -theme tiles -theme-str 'window {width: 240px;} listview {columns: 1;}' -mesg "recording…")
    [ "$choice" = 0 ] && rec_stop
    return
  fi
  choice=$(printf '%s\0' "$(tile 󰆞 area)" "$(tile 󰖯 window)" "$(tile 󰍹 screen)" "$(tile 󰻃 'record area')" "$(tile 󰕧 'record screen')" "$(tile 󰕾 'record + sound')" \
    | rofi -dmenu -sep '\0' -eh 4 -markup-rows -i -format i -theme tiles -theme-str 'window {width: 900px;} listview {columns: 6;}' -mesg "capture: pictures go to ~/Pictures and the clipboard, recordings to ~/Videos")
  sleep 0.25                                             # the menu fades out first
  case "$choice" in
    0) shot area ;; 1) shot window ;; 2) shot screen ;;
    3) rec_start area ;; 4) rec_start screen ;; 5) rec_start screen sound ;;
  esac
}

case "$1" in
  shot) shot "${2:-screen}" ;;
  rec)  case "${2:-toggle}" in
          stop)   rec_stop ;;
          toggle) if recording; then rec_stop; else rec_start area; fi ;;
          *)      rec_start "$2" "$3" ;;
        esac ;;
  menu) menu ;;
  *)    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
