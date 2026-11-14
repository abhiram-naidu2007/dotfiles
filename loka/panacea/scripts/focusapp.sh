#!/bin/bash
hint="$1"
[ -n "$hint" ] || exit 0
base="${hint%.desktop}"
short="${base##*.}"
i3-msg -q "[class=\"(?i)$short\"] focus" 2>/dev/null && exit 0
exit 1
