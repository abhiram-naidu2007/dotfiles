#!/bin/bash
# External monitor layout. Usage: display.sh mirror|extend|monitor|laptop|auto|menu
# Laptop panel = eDP*, external = first other connected output (name changes with GPU driver).
xr=$(xrandr)
int=$(awk '/^eDP[^ ]* connected/ {print $1; exit}' <<<"$xr")
ext=$(awk '/^[^ ]+ connected/ && $1 !~ /^eDP/ {print $1; exit}' <<<"$xr")

# Modes an output supports, from the indented lines under its header.
modes() { awk -v o="$1" '$1 == o {f = 1; next} /^[^ ]/ {f = 0} f {print $1}' <<<"$xr"; }

apply() {
  if [ -z "$int" ] && [ -z "$ext" ]; then
    notify-send -u critical "Display" "No connected output found"; exit 1
  fi
  if [ -z "$ext" ]; then
    notify-send -u low "Display" "No external monitor connected"
    exec xrandr --output "$int" --auto --primary
  fi
  if [ -z "$int" ]; then     # lid closed / panel off: the monitor is all there is
    exec xrandr --output "$ext" --auto --primary
  fi
  case "$1" in
    mirror)
      # largest mode both outputs support, so neither gets scaled or refused
      m=$(grep -Fxf <(modes "$int") <(modes "$ext") | sort -t x -k1,1nr -k2,2nr | head -1)
      [ -z "$m" ] && { notify-send "Display" "No common mode to mirror; extending instead"; apply extend; return; }
      xrandr --output "$int" --mode "$m" --primary --output "$ext" --mode "$m" --same-as "$int" ;;
    extend)  xrandr --output "$int" --auto --primary --output "$ext" --auto --right-of "$int" ;;
    monitor) xrandr --output "$ext" --auto --primary --output "$int" --off ;;
    laptop)  xrandr --output "$int" --auto --primary --output "$ext" --off ;;
  esac
}

mode=${1:-menu}
if [ "$mode" = menu ]; then
  mode=$(printf '%s\n' "󰍺  mirror" "󰍹  extend" "󰹑  monitor" "󰌢  laptop" \
    | rofi -dmenu -i -p "󰍹" -mesg "display layout" -theme-str 'window {width: 22em;} listview {lines: 4;}' \
    | awk '{print $NF}')
fi
case "$mode" in
  auto)                          [ -n "$ext" ] && apply mirror ;;
  mirror|extend|monitor|laptop)  apply "$mode" ;;
esac
