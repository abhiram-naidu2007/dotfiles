#!/bin/bash
# launcher.sh [apps|files|docs|calc|windows]: open the launcher on that tab.
#   docs = the Files tab already filtered to PDFs, newest first: the reading list.
# Ctrl+Tab / Shift+Left/Right change tab and keep what you typed.
LIB="$HOME/.local/lib/rofi"
show=drun filter=
case "${1:-apps}" in
  files)   show=files ;;
  docs)    show=files; filter="pdf: " ;;
  calc)    show=calc ;;
  windows) show=window ;;
esac
modes=drun,files,calc,window
if ! [ -r "$LIB/files.so" ] || ! command -v evry >/dev/null; then   # not built yet: plain launcher
  modes=drun,window
  case $show in files|calc) show=drun; filter= ;; esac
fi
# keep the file index fresh; the launcher never waits for it
(evry index --if-older 900 >/dev/null 2>&1 &)

# a line of mathematics under the picture
IFS=$'\t' read -r formula name < <(shuf -n1 "$HOME/.local/share/rice/math.txt" 2>/dev/null)
esc() { local s=$1; s=${s//&/\&amp;}; s=${s//</\&lt;}; s=${s//>/\&gt;}; printf %s "$s"; }
caption="<b>$(esc "${formula:-(=^･ω･^=)}")</b>&#10;<span size='small' alpha='70%'>$(esc "$name")</span>"

# XDG_CURRENT_DESKTOP=XFCE: also list the XFCE settings apps
exec env ROFI_PLUGIN_PATH="$LIB" XDG_CURRENT_DESKTOP=XFCE rofi -no-sort \
  -modes "$modes" -show "$show" -theme launcher ${filter:+-filter "$filter"} \
  -kb-custom-1 "Control+y" -kb-custom-2 "Control+t" -kb-custom-3 "Control+o" \
  -theme-str "textbox-caption { content: \"$caption\"; }"
