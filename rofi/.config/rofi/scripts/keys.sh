#!/bin/bash
# rofi mode "help" (the Keys tab): every key and command of this desktop in one searchable list.
# Opened by Super+/ and by F1 in zathura (already filtered to zathura).
#   desktop rows come straight from the i3 config: each "## text" line above a bindsym
#   the rest from ~/.local/share/rice/keys.tsv:  section <tab> keys <tab> what
# Type a section name (desktop launcher files bar terminal nvim zathura browser) to see only that part.
[ "${ROFI_RETV:-0}" = 0 ] || exit 0          # Enter on a row just closes the list
printf '\0markup-rows\x1ftrue\n'
printf '\0message\x1f<b>keys and commands</b>   type to filter: desktop launcher files bar terminal nvim zathura browser\n'
{
  awk '/^## /{d=substr($0,4); next}
       /^bindsym /{ if (d != "") { k=$2; print "desktop\t" k "\t" d }; d="" }
       !/^## / && !/^bindsym /{d=""}' "$HOME/.config/i3/config" \
    | sed -e 's/\$mod/Super/; s/Control/Ctrl/g; s/Mod1/Alt/g; s/Return/Enter/; s/Escape/Esc/; s/grave/`/; s/equal/=/; s/period/./; s/slash/\//; s/Print/PrtSc/; s/space/Space/'
  cat "$HOME/.local/share/rice/keys.tsv" 2>/dev/null
} | awk -F'\t' '
  function esc(s) { gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s); return s }
  NF == 3 { printf "<span font_family=\"JetBrainsMono Nerd Font\" size=\"small\" alpha=\"55%%\">%-9s</span> <span font_family=\"JetBrainsMono Nerd Font\"><b>%s</b></span>\r<span size=\"small\" alpha=\"72%%\">%s</span>\n", $1, esc($2), esc($3) }'
