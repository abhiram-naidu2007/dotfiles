#!/bin/sh
# Drop-down terminal: Super+` shows it over whatever is open, the same key hides it again.
# It is one terminal that keeps running in the scratchpad, so its shell and history stay.
SEL='[class="^dev\.rice\.dropterm$"]'
if ! i3-msg -t get_tree | grep -q '"class":"dev.rice.dropterm"'; then
    setsid ghostty --class=dev.rice.dropterm --gtk-single-instance=false >/dev/null 2>&1 &
    i=0
    while [ $i -lt 40 ]; do                    # the for_window rule in the i3 config parks it; then show it
        sleep 0.15
        i3-msg "$SEL scratchpad show" 2>/dev/null | grep -q '"success":true' && exit 0
        i=$((i+1))
    done
    exit 1
fi
i3-msg "$SEL scratchpad show" >/dev/null
