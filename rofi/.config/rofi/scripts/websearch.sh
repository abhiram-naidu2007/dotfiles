#!/bin/bash
q=$*
[ -n "${q// }" ] || exit 0
enc() { jq -rn --arg q "$1" '$q|@uri'; }
key=${q%% *}; rest=${q#* }
[ "$key" = "$q" ] && rest=
case "$key" in
    g)    base="https://www.google.com/search?q=" ;;
    ddg)  base="https://duckduckgo.com/?q=" ;;
    yt)   base="https://www.youtube.com/results?search_query=" ;;
    gh)   base="https://github.com/search?type=repositories&q=" ;;
    w)    base="https://en.wikipedia.org/w/index.php?search=" ;;
    te)   base="https://te.wikipedia.org/w/index.php?search=" ;;
    aw)   base="https://wiki.archlinux.org/index.php?search=" ;;
    pkg)  base="https://packages.ubuntu.com/search?keywords=" ;;
    maps) base="https://www.google.com/maps/search/" ;;
    tr)   base="https://translate.google.com/?sl=auto&tl=en&text=" ;;
    mal)  base="https://myanimelist.net/search/all?q=" ;;
    dex)  base="https://bulbapedia.bulbagarden.net/w/index.php?search=" ;;
    ai)   base="https://claude.ai/new?q=" ;;
    *)    base= ;;
esac
url=
if [ -n "$base" ] && [ -n "$rest" ]; then
    url="$base$(enc "$rest")"
else
    case "$q" in
        *" "*) url="https://www.google.com/search?q=$(enc "$q")" ;;
        http://*|https://*) url=$q ;;
        localhost|localhost[:/]*) url="http://$q" ;;
        *) # an address only when the host ends in a real domain ending: file.py and node.js are searched
           host=${q%%/*}; host=${host%%:*}; tld=${host##*.}
           case "${tld,,}" in
               com|org|net|edu|gov|io|dev|app|ai|co|in|uk|us|de|fr|jp|me|info|xyz|tv|gg|so|sh|ly|to|fm|page|site|blog|wiki|tech)
                   [ "$host" != "$tld" ] && url="https://$q" ;;
           esac
           [ -n "$url" ] || url="https://www.google.com/search?q=$(enc "$q")" ;;
    esac
fi
setsid xdg-open "$url" >/dev/null 2>&1 &
