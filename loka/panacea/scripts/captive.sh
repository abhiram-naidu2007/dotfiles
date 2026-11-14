#!/bin/bash

ssid="$1"
for i in 1 2 3 4; do
    out=$(curl -s -m 5 -o /dev/null -w '%{http_code} %{redirect_url}' \
          http://connectivitycheck.gstatic.com/generate_204 2>/dev/null)
    code=${out%% *}
    [ "$code" = "204" ] && exit 0
    [ -n "$code" ] && [ "$code" != "000" ] && break
    sleep 3
done
[ -z "$code" ] || [ "$code" = "000" ] && exit 0

url=${out#* }
[ -n "$url" ] || url="http://connectivitycheck.gstatic.com/generate_204"
printf '%s\n' "$url"

title="${PANACEA_CAPTIVE_TITLE:-Network sign-in required}"
body="${PANACEA_CAPTIVE_BODY:-Open the sign-in page to get internet access}"
[ -n "$ssid" ] && body="$ssid — $body"
btn="${PANACEA_CAPTIVE_BTN:-Sign in}"
act=$(notify-send -a "Wi-Fi" -i network-wireless -u critical \
        -A "open=$btn" "$title" "$body" 2>/dev/null)
[ "$act" = "open" ] && setsid xdg-open "$url" >/dev/null 2>&1 &
wait
