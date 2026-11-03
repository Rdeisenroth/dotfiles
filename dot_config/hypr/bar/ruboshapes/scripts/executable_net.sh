#!/usr/bin/env bash
# Network status as JSON: {"type":"wifi|ethernet|none","name":"...","signal":0-100}
line=$(nmcli -t -f TYPE,STATE,CONNECTION device 2>/dev/null | awk -F: '$2=="connected"{print; exit}')
type=${line%%:*}; name=${line##*:}
case $type in
  wifi) sig=$(nmcli -t -f ACTIVE,SIGNAL device wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}')
        printf '{"type":"wifi","name":"%s","signal":%s}\n' "$name" "${sig:-0}" ;;
  ethernet) printf '{"type":"ethernet","name":"%s","signal":100}\n' "$name" ;;
  "") echo '{"type":"none","name":"Disconnected","signal":0}' ;;
  *) printf '{"type":"other","name":"%s","signal":100}\n' "$name" ;;
esac
