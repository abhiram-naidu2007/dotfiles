#!/bin/bash
# Battery for polybar, drawn as a hit-point bar: HP ━━━━━━━━ 72%
# The bar is green above half, yellow below, red under a fifth. Charging = bolt, on AC but full = plug.
# Reads sysfs directly, so it never claims "charging" unless the kernel does.
PS=/sys/class/power_supply
bat=$(ls -d $PS/BAT* 2>/dev/null | head -1); [ -z "$bat" ] && exit 0
status=$(<"$bat/status")
ac=0; for f in $PS/*/online; do [ -r "$f" ] && [ "$(<"$f")" = 1 ] && ac=1; done

# one pass over colors.ini (no per-colour subprocesses)
while IFS=' =' read -r k v; do
    case $k in ok) OK=$v ;; warn) WARN=$v ;; crit) CRIT=$v ;; accent) ACC=$v ;; dim) DIM=$v ;; surface2) EMPTY=$v ;; esac
done < "$HOME/.config/polybar/colors.ini"

# fallback when the kernel reports no percentage: icon in font 2, coloured; value in the bar's text colour
out() { printf '%%{T2}%%{F%s}%s%%{F-}%%{T-} %s\n' "$1" "$2" "$3"; }

# Percentage = charge now / what the pack holds today (energy_full), same as the
# kernel's capacity file and upower. Not / energy_full_design: a worn pack
# (this one holds ~30 of 70 Wh) would then read 42% while the charger says Full.
# HP firmware: after a full drain the boot-time _BIX fails (divide by zero) and the
# kernel leaves out capacity/energy_full until the battery driver is re-probed.
# Remember the last good energy_full and use it when that happens.
FULL_CACHE="$HOME/.cache/theme/battery-energy-full"
full=
if [ -r "$bat/energy_full" ] && [ "$(<"$bat/energy_full")" -gt 0 ]; then
    full=$(<"$bat/energy_full")
    [ "$(cat "$FULL_CACHE" 2>/dev/null)" = "$full" ] || { mkdir -p "${FULL_CACHE%/*}"; echo "$full" > "$FULL_CACHE"; }
fi
[ -z "$full" ] && full=$(cat "$FULL_CACHE" 2>/dev/null)
if [ -r "$bat/capacity" ]; then
    cap=$(<"$bat/capacity")
elif [ -n "$full" ] && [ "$full" -gt 0 ] && [ -r "$bat/energy_now" ]; then
    cap=$(( $(<"$bat/energy_now") * 100 / full ))
elif [ -r "$bat/energy_now" ]; then        # no full value ever seen: show stored energy
    wh=$(( $(<"$bat/energy_now") / 100000 ))
    ic=󰂑; col=$DIM
    [ "$ac" = 1 ] && { ic=󰚥; col=$OK; }; [ "$status" = Charging ] && { ic=󰂄; col=$OK; }
    out "$col" "$ic" "$(( wh / 10 )).$(( wh % 10 )) Wh"; exit 0
else out "$DIM" "󰂑" "?"; exit 0; fi
[ "$cap" -gt 100 ] && cap=100
[ "$status" = Full ] && cap=100

# eight segments; a nearly empty pack still shows one
col=$OK; [ "$cap" -lt 50 ] && col=$WARN; [ "$cap" -lt 20 ] && col=$CRIT
seg=$(( (cap + 6) / 12 )); [ $seg -gt 8 ] && seg=8; [ $seg -lt 1 ] && seg=1
full=━━━━━━━━
bar="%{F$col}${full:0:seg}%{F$EMPTY}${full:seg}%{F-}"
icon=
if [ "$status" = Charging ]; then icon="%{T2}%{F$OK}󱐋%{F-}%{T-}"
elif [ "$ac" = 1 ]; then icon="%{T2}%{F$OK}󰚥%{F-}%{T-}"; fi
printf '%s%%{T3}%%{F%s}HP%%{F-}%%{T-} %s %s%%\n' "${icon:+$icon }" "$col" "$bar" "$cap"
