#!/bin/bash
# Pick a Thorium profile in rofi and open a new window in it.
cd ~/.config/thorium || exit 1
choice=$(python3 -I -c "
import json
for k, v in json.load(open('Local State'))['profile']['info_cache'].items():
    print(v.get('name', k) + ' [' + k + ']')" | rofi -dmenu -i -p "profile" -theme-str 'window {width: 24em;} listview {lines: 4;}')
[ -z "$choice" ] && exit 0
dir=${choice##*[}; dir=${dir%]}
exec thorium-browser --profile-directory="$dir" --new-window
