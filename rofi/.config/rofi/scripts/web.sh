#!/bin/bash
# rofi mode "web": every bookmark of every Thorium profile. Type to filter, Enter opens it in
# the profile it belongs to. Anything that matches no bookmark is opened as an address
# (if it looks like one) or searched for.
SEARCH_URL="https://www.google.com/search?q="
THORIUM="$HOME/.config/thorium"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/rice/bookmarks.rofi"

if [ "${ROFI_RETV:-0}" = 0 ]; then
    # List. Rebuilt only when a profile's Bookmarks file is newer than the cached list.
    fresh=1
    [ -s "$CACHE" ] || fresh=0
    for f in "$THORIUM"/*/Bookmarks; do [ "$f" -nt "$CACHE" ] && fresh=0; done
    if [ "$fresh" = 0 ]; then
        mkdir -p "${CACHE%/*}"
        for f in "$THORIUM"/*/Bookmarks; do
            [ -r "$f" ] || continue
            profile=${f%/Bookmarks}; profile=${profile##*/}
            jq -r --arg p "$profile" '
              [.roots[] | .. | objects | select(.type? == "url")] | .[]
              | (.url | sub("^[a-z]+://(www\\.)?"; "") | sub("/.*$"; "")) as $host
              | "\((if .name == "" then .url else .name end) | gsub("[[:cntrl:]]"; " ") | @html)\r<span size=\"small\" alpha=\"62%\">\($host | @html)  ·  \($p | @html)</span>\u0000icon\u001fweb-browser\u001finfo\u001f\($p)\t\(.url)\u001fmeta\u001f\(.url)"
            ' "$f"
        done > "$CACHE.tmp" && mv "$CACHE.tmp" "$CACHE"
    fi
    printf '\0markup-rows\x1ftrue\n\0message\x1f<b>⏎</b> open bookmark     no match: an address opens, anything else is searched\n'
    cat "$CACHE"
    exit 0
fi

if [ "$ROFI_RETV" = 1 ] && [ -n "$ROFI_INFO" ]; then          # a bookmark
    profile=${ROFI_INFO%%$'\t'*}; url=${ROFI_INFO#*$'\t'}
    setsid thorium-browser --profile-directory="$profile" "$url" >/dev/null 2>&1 &
    exit 0
fi
text=$1                                                        # typed text
[ -n "$text" ] || exit 0
case "$text" in
    *" "*) url="$SEARCH_URL$(jq -rn --arg q "$text" '$q|@uri')" ;;
    http://*|https://*) url=$text ;;
    *.*) url="https://$text" ;;
    *) url="$SEARCH_URL$(jq -rn --arg q "$text" '$q|@uri')" ;;
esac
setsid xdg-open "$url" >/dev/null 2>&1 &
