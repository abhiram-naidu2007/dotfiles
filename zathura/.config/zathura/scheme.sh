#!/bin/sh
# scheme.sh BUS desktop|paper|night|own: recolour the pages of one running zathura.
# Called by Alt+1..4 (zathurarc); BUS is that window's D-Bus name, which zathura fills in.
bus=$1
tell() { dbus-send --session --dest="$bus" --type=method_call /org/pwmt/zathura org.pwmt.zathura.ExecuteCommand string:"$1"; }
case "$2" in
  desktop) . "$HOME/.cache/theme/colors.sh"; light=$bg; dark=$fg ;;   # the current palette
  paper)   light='#f1e7d2'; dark='#2b261b' ;;                          # cream and ink
  night)   light='#0b0c10'; dark='#c9ccd6' ;;                          # black and soft white
  *)       tell "set recolor false"; exit 0 ;;                         # the document's own colours
esac
tell "set recolor-lightcolor \"$light\""       # quoted: a bare # would start a comment
tell "set recolor-darkcolor \"$dark\""
tell "set recolor false"      # off and on again: pages are only redrawn when this changes
tell "set recolor true"
