#!/bin/bash
# Battery for polybar. Charging = bolt + green, on AC but full = plug, else level icon.
# Reads sysfs directly, so it never claims "charging" unless the kernel does.
PS=/sys/class/power_supply
bat=$(ls -d $PS/BAT* 2>/dev/null | head -1); [ -z "$bat" ] && exit 0
status=$(<"$bat/status")
ac=0; for f in $PS/*/online; do [ -r "$f" ] && [ "$(<"$f")" = 1 ] && ac=1; done

# one pass over colors.ini (no per-colour subprocesses)
while IFS=' =' read -r k v; do
    case $k in ok) OK=$v ;; warn) WARN=$v ;; crit) CRIT=$v ;; accent) ACC=$v ;; dim) DIM=$v ;; esac
done < "$HOME/.config/polybar/colors.ini"

# icon in font 2 (the larger icon font), coloured; value in the bar's text colour
out() { printf '%%{T2}%%{F%s}%s%%{F-}%%{T-} %s\n' "$1" "$2" "$3"; }

# HP firmware: after a full drain the boot-time _BIX fails (divide by zero) and the
# kernel leaves out capacity/energy_full until the battery driver is re-probed.
# Remember the last good full-charge energy and use it when that happens.
# The same firmware can also report a bogus small energy_full (26 Wh on a 70 Wh pack),
# which makes capacity read 100% early: below 60% of design, it is not trusted.
FULL_CACHE="$HOME/.cache/theme/battery-energy-full"
design=$(cat "$bat/energy_full_design" 2>/dev/null || echo 0)
full=
if [ -r "$bat/energy_full" ] && [ "$(<"$bat/energy_full")" -gt 0 ]; then
    f=$(<"$bat/energy_full")
    if [ "$design" -eq 0 ] || [ $(( f * 10 )) -ge $(( design * 6 )) ]; then
        full=$f
        [ "$(cat "$FULL_CACHE" 2>/dev/null)" = "$full" ] || { mkdir -p "${FULL_CACHE%/*}"; echo "$full" > "$FULL_CACHE"; }
    fi
fi
[ -z "$full" ] && full=$(cat "$FULL_CACHE" 2>/dev/null)
[ -z "$full" ] && [ "$design" -gt 0 ] && full=$design
if [ -r "$bat/energy_full" ] && [ "$full" = "$(<"$bat/energy_full")" ] && [ -r "$bat/capacity" ]; then
    cap=$(<"$bat/capacity")
elif [ -n "$full" ] && [ -r "$bat/energy_now" ]; then
    cap=$(( $(<"$bat/energy_now") * 100 / full )); [ "$cap" -gt 100 ] && cap=100
elif [ -r "$bat/energy_now" ]; then        # no full value ever seen: show stored energy
    wh=$(( $(<"$bat/energy_now") / 100000 ))
    ic=󰂑; col=$DIM
    [ "$ac" = 1 ] && { ic=󰚥; col=$OK; }; [ "$status" = Charging ] && { ic=󰂄; col=$OK; }
    out "$col" "$ic" "$(( wh / 10 )).$(( wh % 10 )) Wh"; exit 0
else out "$DIM" "󰂑" "?"; exit 0; fi

lv=(󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹)
ch=(󰢜 󰂆 󰂇 󰂈 󰢝 󰂉 󰢞 󰂊 󰂋 󰂅)
i=$(( cap / 10 )); [ $i -gt 9 ] && i=9

if [ "$status" = Charging ]; then
    out "$OK" "${ch[$i]}" "$cap%"
elif [ "$ac" = 1 ]; then                      # plugged in, not charging (full / limit)
    out "$OK" "󰚥" "$cap%"
else
    col=$ACC; [ "$cap" -lt 30 ] && col=$WARN; [ "$cap" -lt 15 ] && col=$CRIT
    out "$col" "${lv[$i]}" "$cap%"
fi
