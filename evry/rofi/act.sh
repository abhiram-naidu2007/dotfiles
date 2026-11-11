#!/bin/bash
# act.sh ACTION ARG: what the rofi modes do with the chosen row. Edit freely; nothing needs rebuilding.
# Override the path with EVRY_ACT, the terminal with TERMINAL.
term=${TERMINAL:-ghostty}
search="https://www.google.com/search?q="
action=$1 arg=$2
folder() { if [ -d "$arg" ]; then printf %s "$arg"; else dirname "$arg"; fi; }
case "$action" in
  open)   exec evry open "$arg" ;;                          # Enter
  reveal) exec xdg-open "$(folder)" ;;                      # Shift+Enter
  copy)   printf %s "$arg" | xclip -selection clipboard     # Ctrl+Y
          notify-send -t 1500 -i edit-copy "path copied" "$arg" ;;
  term)   cd "$(folder)" && exec "$term" ;;                 # Ctrl+T
  edit)   exec "$term" -e "${EDITOR:-nvim}" "$arg" ;;       # Ctrl+O
  calc)   result=${arg##* = }                               # "2^10 = 1024" or a history row
          printf %s "$result" | xclip -selection clipboard
          if [ "$result" != "$arg" ]; then
            hist="${XDG_STATE_HOME:-$HOME/.local/state}/evry/calc-history"
            mkdir -p "${hist%/*}"
            { grep -vxF -- "$arg" "$hist" 2>/dev/null | tail -n 199; printf '%s\n' "$arg"; } > "$hist.tmp" && mv "$hist.tmp" "$hist"
          fi
          notify-send -t 2000 -i accessories-calculator "= $result" "copied" ;;
  web)    exec xdg-open "$search$(jq -rn --arg q "$arg" '$q|@uri')" ;;
esac
