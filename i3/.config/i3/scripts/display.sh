#!/bin/bash
# External monitor layout. Usage: display.sh mirror|extend|monitor|laptop|auto|menu
# Laptop panel = eDP*, external = first other connected output (name changes with GPU driver).
int=$(xrandr | awk '/^eDP[^ ]* connected/ {print $1; exit}')
ext=$(xrandr | awk '/^[^ ]+ connected/ && $1 !~ /^eDP/ {print $1; exit}')

apply() {
  if [ -z "$ext" ]; then
    notify-send -u low "Display" "No external monitor connected"
    exec xrandr --output "$int" --auto --primary
  fi
  case "$1" in
    mirror)  xrandr --output "$int" --mode 1920x1080 --rate 60 --primary --output "$ext" --mode 1920x1080 --rate 60 --same-as "$int" ;;
    extend)  xrandr --output "$int" --mode 1920x1080 --rate 144 --primary --output "$ext" --auto --right-of "$int" ;;
    monitor) xrandr --output "$ext" --auto --primary --output "$int" --off ;;
    laptop)  xrandr --output "$int" --auto --primary --output "$ext" --off ;;
  esac
}

mode=${1:-menu}
if [ "$mode" = menu ]; then
  mode=$(printf '%s\n' mirror extend monitor laptop | rofi -dmenu -i -p "display" -theme-str 'window {width: 18em;} listview {lines: 4;}')
fi
case "$mode" in
  auto)                          [ -n "$ext" ] && apply mirror ;;
  mirror|extend|monitor|laptop)  apply "$mode" ;;
esac
