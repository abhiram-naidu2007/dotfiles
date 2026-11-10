#!/bin/bash
# act.sh ACTION ARG: what the launcher's Files and Calc tabs do with the chosen row.
# Called by the rofi plugin (evry/rofi/evry.c). Edit freely; nothing needs rebuilding.
SEARCH_URL="https://www.google.com/search?q="
action=$1 arg=$2
folder() { if [ -d "$arg" ]; then printf %s "$arg"; else dirname "$arg"; fi; }
case "$action" in
  open)   exec evry open "$arg" ;;                                    # Enter
  reveal) exec exo-open --launch FileManager "$(folder)" ;;           # Shift+Enter
  copy)   printf %s "$arg" | xclip -selection clipboard               # Ctrl+Y
          notify-send -t 1500 -i edit-copy "path copied" "$arg" ;;
  term)   exec ghostty --working-directory="$(folder)" ;;             # Ctrl+T
  edit)   exec ghostty -e nvim "$arg" ;;                              # Ctrl+O
  calc)   result=${arg##* = }                                         # "2^10 = 1024" or a history row
          printf %s "$result" | xclip -selection clipboard
          if [ "$result" != "$arg" ]; then
            hist="${XDG_STATE_HOME:-$HOME/.local/state}/rice/calc-history"
            mkdir -p "${hist%/*}"
            { grep -vxF -- "$arg" "$hist" 2>/dev/null | tail -n 199; printf '%s\n' "$arg"; } > "$hist.tmp" && mv "$hist.tmp" "$hist"
          fi
          notify-send -t 2000 -i accessories-calculator "= $result" "copied" ;;
  web)    exec xdg-open "$SEARCH_URL$(jq -rn --arg q "$arg" '$q|@uri')" ;;
esac
