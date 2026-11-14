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
if [ -n "$base" ] && [ -n "$rest" ]; then
    url="$base$(enc "$rest")"
else
    case "$q" in
        *" "*) url="https://www.google.com/search?q=$(enc "$q")" ;;
        http://*|https://*) url=$q ;;
        localhost*|*.[a-z][a-z]|*.[a-z][a-z][a-z]|*.[a-z][a-z][a-z][a-z]|*.[a-z]*/*) url="https://$q" ;;
        *) url="https://www.google.com/search?q=$(enc "$q")" ;;
    esac
fi
setsid xdg-open "$url" >/dev/null 2>&1 &
