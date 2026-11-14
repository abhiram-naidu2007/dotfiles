#!/bin/bash

BUS="net.hadess.PowerProfiles"
OBJ="/net/hadess/PowerProfiles"

case "$1" in
    get)
        busctl --system get-property "$BUS" "$OBJ" "$BUS" ActiveProfile 2>/dev/null \
            | sed 's/^s //; s/"//g'
        ;;
    set)
        case "${2:-}" in power-saver|balanced|performance) ;; *) exit 1 ;; esac
        busctl --system set-property "$BUS" "$OBJ" "$BUS" ActiveProfile s "$2" || exit 1
        for ((i=0; i<50; i++)); do
            active=$(busctl --system get-property "$BUS" "$OBJ" "$BUS" ActiveProfile 2>/dev/null | sed 's/^s //; s/"//g')
            [ "$active" = "$2" ] && exit 0
            sleep 0.1
        done
        echo "Power profile did not change to $2" >&2
        exit 1
        ;;
    *)
        echo "usage: power.sh get | set <power-saver|balanced|performance>" >&2
        exit 1
        ;;
esac
