#!/bin/bash
# One pane of the showcase (showcase.sh). Each draws once, hides the cursor and redraws on a
# timer; no shell prompt, no greeting. Panes: fetch | cal
export PATH="$HOME/.local/bin:$PATH"
printf '\033[?25l'                       # no cursor
trap 'printf "\033[?25h"' EXIT
centre() {                               # print stdin centred in the pane, COLS wide content
  local width=$1 pad
  pad=$(( ($(tput cols) - width) / 2 )); (( pad < 0 )) && pad=0
  sed "s/^/$(printf '%*s' "$pad" '')/"
}
case "$1" in
  fetch)   # a random Pokémon above the machine's details; a new one every 15 minutes
    while :; do
      clear
      sprite=$(rice-greet --path)
      fastfetch --logo-position top --logo-padding-left $(( ($(tput cols) - 34) / 2 )) ${sprite:+--file-raw "$sprite"}
      sleep 900
    done ;;
  cal)     # this month, today marked, and a line of mathematics; redrawn every 10 minutes
    while :; do
      clear
      IFS=$'\t' read -r formula who < <(shuf -n1 "$HOME/.local/share/rice/math.txt" 2>/dev/null)
      rows=$(tput lines)
      printf '%*s' $(( (rows - 13) / 2 )) '' | tr ' ' '\n'
      today=$(date +%-d)
      cal | sed -E "s/(^| )($today)( |$)/\1\x1b[1;7m\2\x1b[0m\3/" | centre 20
      printf '\n'
      printf '\033[1m%s\033[0m\n' "$formula" | centre ${#formula}
      printf '\033[2;3m%s\033[0m\n' "$who" | centre ${#who}
      sleep 600
    done ;;
esac
