#!/usr/bin/env bash
# Network status as JSON: {"type":"wifi|ethernet|other|none","name":"...","signal":0-100,"vpn":"<names>"}
# The physical connection (ethernet/wifi) wins over VPN tunnels and bridges, whatever order nmcli lists
# them in; active VPNs (NM vpn/wireguard/tun, Mullvad) are reported separately.
devs=$(nmcli -t -f TYPE,STATE,CONNECTION device 2>/dev/null)
pick() { awk -F: -v t="$1" '$1==t && $2=="connected"{sub(/^[^:]*:[^:]*:/,""); print; exit}' <<<"$devs"; }
if name=$(pick ethernet) && [[ -n $name ]]; then type=ethernet
elif name=$(pick wifi) && [[ -n $name ]]; then type=wifi
else
  line=$(awk -F: '$2=="connected" && $1!="loopback" && $1!="bridge" && $1!="wireguard" && $1!="tun"{print; exit}' <<<"$devs")
  type=${line:+other}; name=${line##*:}
fi
vpn=$( { awk -F: '($1=="wireguard" || $1=="tun") && $2=="connected"{sub(/^[^:]*:[^:]*:/,""); print}' <<<"$devs"
         nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | awk -F: '$1=="vpn"{print $2}'
         ip -br link 2>/dev/null | awk '$1 ~ /mullvad/ {print "Mullvad"}'; } | sort -u | paste -sd, - | sed 's/,/, /g')
esc() { sed 's/\\/\\\\/g; s/"/\\"/g' <<<"$1"; }
case $type in
  wifi) sig=$(nmcli -t -f ACTIVE,SIGNAL device wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}') ;;
  "")   type=none; name=Disconnected ;;
esac
printf '{"type":"%s","name":"%s","signal":%s,"vpn":"%s"}\n' "$type" "$(esc "$name")" "${sig:-100}" "$(esc "$vpn")"
