#!/bin/bash
check=http://connectivitycheck.gstatic.com/generate_204
for _ in 1 2 3 4; do
    out=$(curl -s -m 5 -o /dev/null -w '%{http_code} %{redirect_url}' "$check" 2>/dev/null)
    code=${out%% *}
    [ "$code" = 204 ] && exit 0
    [ -n "$code" ] && [ "$code" != 000 ] && break
    sleep 3
done
[ -z "$code" ] || [ "$code" = 000 ] && exit 0
url=${out#* }
act=$(notify-send -a Wi-Fi -i network-wireless -u critical -A "open=Sign in" "Network sign-in required" "${1:+$1 — }Open the sign-in page to get internet access")
[ "$act" = open ] && setsid xdg-open "${url:-$check}" >/dev/null 2>&1
