#!/usr/bin/env bash

set -Eeuo pipefail

BAR_HOME="${HOME}/.config/hypr/bar/saimoomedits/eww/bar"
TARGET="$BAR_HOME/bar_windows.yuck"
TEMP="$(mktemp "$TARGET.XXXXXX")"
trap 'rm -f "$TEMP"' EXIT

for monitor_index in {0..7}; do
  cat >>"$TEMP" <<EOF
; Bar for Eww monitor index $monitor_index
(defwindow bar$monitor_index
  :exclusive true
  :monitor $monitor_index
  :windowtype "dock"
  :stacking "fg"
  :vexpand false
  :hexpand false
  :geometry (geometry :x "0%"
    :y "0%"
    :width "100%"
    :height "4%"
  :anchor "top center")
  ; :reserve (struts :side "top" :distance "4%")
  (bar_1))

EOF
done

mv -f "$TEMP" "$TARGET"
