#!/bin/bash
# launcher.sh [apps|files|docs|web|calc|windows|keys [WORD]]: open the launcher on that tab.
#   keys = every key and command of this desktop; WORD pre-filters it (keys zathura).
#   docs = the Files tab already filtered to PDFs, newest first: the reading list.
# Ctrl+Tab / Shift+Left/Right change tab and keep what you typed.
LIB="$HOME/.local/lib/rofi"
show=combi filter= match=fuzzy   # fuzzy: ffx finds Firefox, sysmon System Monitor
case "${1:-apps}" in
  files)   show=files ;;
  docs)    show=files; filter="pdf: " ;;
  web)     show=web ;;
  calc)    show=calc ;;
  windows) show=window ;;
  keys)    show=help; match=normal; [ -n "$2" ] && filter="$2 " ;;
esac
WEB="web:$HOME/.config/rofi/scripts/web.sh"
KEYS="help:$HOME/.config/rofi/scripts/keys.sh"
SEARCH=search
[ -r "$LIB/search.so" ] || SEARCH="search:$HOME/.config/rofi/scripts/search.sh"
modes="combi,files,$WEB,calc,window,$KEYS"
if ! [ -r "$LIB/files.so" ] || ! command -v evry >/dev/null; then   # not built yet: plain launcher
  modes="combi,$WEB,window,$KEYS"
  case $show in files|calc) show=combi; filter= ;; esac
fi
# keep the file index fresh; the launcher never waits for it
(evry index --if-older 20 >/dev/null 2>&1 &)

DROP=
[ -e "$HOME/.config/loka/shell-on" ] && { pgrep -x quickshell >/dev/null || pgrep -x loka >/dev/null; } && DROP="window { location: north; anchor: north; y-offset: 46px; }"
# XDG_CURRENT_DESKTOP=XFCE: also list the XFCE settings apps
env ROFI_PLUGIN_PATH="$LIB" XDG_CURRENT_DESKTOP=XFCE rofi -sort -sorting-method fzf -matching $match \
  -modes "$modes" -show "$show" -combi-modes "$SEARCH,drun" -combi-hide-mode-prefix -display-combi "󰀻  Apps" -theme launcher ${filter:+-filter "$filter"} \
  -kb-custom-1 "Control+y" -kb-custom-2 "Control+t" -kb-custom-3 "Control+o" \
  -theme-str "textbox-caption { enabled: false; } $DROP"
rc=$?
[ "$rc" -eq 0 ] || [ "$rc" -ge 10 ] && pgrep -x loka >/dev/null && "$HOME/.local/bin/loka" msg launched >/dev/null 2>&1
exit "$rc"
