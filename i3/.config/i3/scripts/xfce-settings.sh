#!/bin/bash
# Apply the XFCE settings that xfsettingsd would apply, without running xfsettingsd
# (it grabs Super and breaks i3 keys). The XFCE dialogs (Mouse and Touchpad, Keyboard)
# keep working: they write to xfconf, and `--watch` re-applies on every change.
# The look (GTK theme, icons, cursor, fonts) stays with the dotfiles (xsettingsd).

apply_pointers() {
    local key dev prop val
    while IFS= read -r key; do
        # /ELAN078800_04F3321A_Mouse/Acceleration -> device "ELAN0788:00 04F3:321A Mouse"
        dev=$(xinput list --name-only | while IFS= read -r n; do
            [ "$(printf '%s' "$n" | tr -cd 'A-Za-z0-9 ' | tr ' ' '_')" = "$(printf '%s' "${key#/}" | cut -d/ -f1)" ] && { echo "$n"; break; }
        done)
        [ -n "$dev" ] || continue
        val=$(xfconf-query -c pointers -p "$key")
        case "$key" in
            */Acceleration)   # XFCE 0.1..10 -> libinput -1..1
                xinput set-prop "$dev" "libinput Accel Speed" "$(awk -v a="$val" 'BEGIN{s=(a-5)/5; if(s<-1)s=-1; if(s>1)s=1; print s}')" 2>/dev/null ;;
            */RightHanded)
                xinput set-prop "$dev" "libinput Left Handed Enabled" "$([ "$val" = true ] && echo 0 || echo 1)" 2>/dev/null ;;
            */ReverseScrolling)
                xinput set-prop "$dev" "libinput Natural Scrolling Enabled" "$([ "$val" = true ] && echo 1 || echo 0)" 2>/dev/null ;;
            */Properties/*)   # libinput_Foo_Bar -> "libinput Foo Bar"
                prop=${key##*/Properties/}; prop=${prop//_/ }
                val=$(xfconf-query -c pointers -p "$key" | tail -n +3 | tr -d ' ' | grep -v '^$' | paste -sd,)
                [ -n "$val" ] || val=$(xfconf-query -c pointers -p "$key")
                IFS=, read -ra vals <<<"$val"
                xinput set-prop "$dev" "$prop" "${vals[@]}" 2>/dev/null ;;
        esac
    done < <(xfconf-query -c pointers -l 2>/dev/null)
}

apply_keyboard() {
    [ "$(xfconf-query -c keyboards -p /Default/Numlock 2>/dev/null)" = true ] && numlockx on
    local delay rate
    delay=$(xfconf-query -c keyboards -p /Default/KeyRepeat/Delay 2>/dev/null)
    rate=$(xfconf-query -c keyboards -p /Default/KeyRepeat/Rate 2>/dev/null)
    [ -n "$delay" ] && [ -n "$rate" ] && xset r rate "$delay" "$rate"
}

apply() { apply_pointers; apply_keyboard; }

apply
if [ "$1" = --watch ]; then
    # stop an older watcher: once both its monitors exit, its read loop ends too
    pkill -f "xfconf-query -c (pointers|keyboards) -m" 2>/dev/null
    { xfconf-query -c pointers -m & xfconf-query -c keyboards -m; } 2>/dev/null |
        while read -r _; do sleep 0.2; apply; done
fi
