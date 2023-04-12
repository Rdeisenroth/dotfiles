#! /bin/bash

read -r -d '' Template << \
_______________________________________________________________________________
(defwindow bar{{mon_id}}
  :exclusive true
  :monitor {{mon_id}}
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

_______________________________________________________________________________

MONITORS=`hyprctl monitors -j | jq -r '.[] | .id'`
RESULT=""
for MONITOR in $MONITORS; do
    RESULT="$RESULT; Bar for monitor $MONITOR\n"
    RESULT="$RESULT$(echo "$Template" | sed "s/{{mon_id}}/$MONITOR/g")\n"
done
echo -e "$RESULT" > bar_windows.yuck