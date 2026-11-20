#!/bin/bash
# Nearby wifi list (zenity). Pick one to connect; asks for a password or an enterprise login (PEAP/MSCHAPv2) when needed.
# A failed new connection is deleted again, so a wrong password is never kept; a saved one that fails can be forgotten and retyped.
nmcli dev wifi rescan 2>/dev/null; sleep 1
show() { zenity --info --title="Wifi" --width=400 --text="$1" 2>/dev/null; }

# nmcli -t escapes ':' inside a field as '\:'; swap it for \x01 before splitting, put it back after.
sel=$(nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list | sed 's/\\:/\x01/g' |
  awk -F: '$4 != "" && !seen[$4]++ {
    for (i = 1; i <= 4; i++) gsub(/\x01/, ":", $i)
    print ($1 == "*" ? "connected" : ""); print $2; print $3; print $4 }' |
  zenity --list --title="Wifi networks" --width=520 --height=420 \
    --column="Status" --column="Signal" --column="Security" --column="Network" --print-column=4 2>/dev/null) || exit 0
[ -z "$sel" ] && exit 0
sec=$(nmcli -t -f SSID,SECURITY dev wifi list | sed 's/\\:/\x01/g' |
  awk -F: -v want="$sel" '{s = $1; gsub(/\x01/, ":", s)} s == want {print $2; exit}')
dev=$(nmcli -t -f DEVICE,TYPE dev | awk -F: '$2 == "wifi" {print $1; exit}')
ifname=(); [ -n "$dev" ] && ifname=(ifname "$dev")

if nmcli -t -f NAME con show | grep -qxF "$sel"; then
  out=$(nmcli con up id "$sel" 2>&1) && { show "$out"; exit 0; }
  zenity --question --title="Wifi" --width=400 \
    --text="Could not connect to $sel:\n$out\n\nForget the saved login and type it again?" 2>/dev/null || exit 0
  nmcli con delete id "$sel" >/dev/null 2>&1
fi

# New profiles are written through `nmcli con edit` on stdin, so passwords never appear in a
# command line (where `ps` would show them).
newcon() {   # newcon "set key value" ...
  printf '%s\n' "set wifi.ssid $sel" ${dev:+"set connection.interface-name $dev"} "$@" save quit |
    nmcli con edit type wifi con-name "$sel" >/dev/null 2>&1
}
if [[ "$sec" == *802.1X* ]]; then
  creds=$(zenity --forms --title="$sel login" --text="Enterprise wifi login" \
    --add-entry="Username (roll no)" --add-password="Password" 2>/dev/null) || exit 0
  user=${creds%%|*}; pass=${creds#*|}
  newcon "set wifi-sec.key-mgmt wpa-eap" "set 802-1x.eap peap" "set 802-1x.phase2-auth mschapv2" \
    "set 802-1x.identity $user" "set 802-1x.password $pass"
  out=$(nmcli con up id "$sel" 2>&1); rc=$?
elif [[ -z "$sec" || "$sec" == "--" ]]; then
  out=$(nmcli dev wifi connect "$sel" "${ifname[@]}" 2>&1); rc=$?
else
  pass=$(zenity --password --title="Password for $sel" 2>/dev/null) || exit 0
  km=wpa-psk; [[ "$sec" == *WPA3* && "$sec" != *WPA2* ]] && km=sae      # WPA3-only networks
  newcon "set wifi-sec.key-mgmt $km" "set wifi-sec.psk $pass"
  out=$(nmcli con up id "$sel" 2>&1); rc=$?
fi
# Failed: drop the profile just made, so the next try asks for the password again.
[ "$rc" -eq 0 ] || nmcli con delete id "$sel" >/dev/null 2>&1
show "$out"
