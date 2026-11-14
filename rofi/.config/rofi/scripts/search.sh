#!/bin/bash
if [ "${ROFI_RETV:-0}" = 0 ]; then
    exit 0
fi
[ -n "$1" ] && exec "$HOME/.config/rofi/scripts/websearch.sh" "$1"
