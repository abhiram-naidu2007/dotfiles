#!/bin/bash
# Battery for polybar. Charging = bolt + green, on AC but full = plug, else level icon.
# Reads sysfs directly, so it never claims "charging" unless the kernel does.
PS=/sys/class/power_supply
bat=$(ls -d $PS/BAT* 2>/dev/null | head -1); [ -z "$bat" ] && exit 0
cap=$(<"$bat/capacity"); status=$(<"$bat/status")
ac=0; for f in $PS/*/online; do [ -r "$f" ] && [ "$(<"$f")" = 1 ] && ac=1; done

c() { grep -m1 "^$1 *=" "$HOME/.config/polybar/colors.ini" | sed 's/.*= *//'; }
OK=$(c ok); WARN=$(c warn); CRIT=$(c crit); ACC=$(c accent)

lv=(󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹)
ch=(󰢜 󰂆 󰂇 󰂈 󰢝 󰂉 󰢞 󰂊 󰂋 󰂅)
i=$(( cap / 10 )); [ $i -gt 9 ] && i=9

if [ "$status" = Charging ]; then
    printf '%%{F%s}%s 󱐋%%{F-} %s%%\n' "$OK" "${ch[$i]}" "$cap"
elif [ "$ac" = 1 ]; then                      # plugged in, not charging (full / limit)
    printf '%%{F%s}󰚥%%{F-} %s%%\n' "$ACC" "$cap"
else
    col=$ACC; [ "$cap" -lt 30 ] && col=$WARN; [ "$cap" -lt 15 ] && col=$CRIT
    printf '%%{F%s}%s%%{F-} %s%%\n' "$col" "${lv[$i]}" "$cap"
fi
