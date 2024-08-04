#!/bin/zsh
# Get workspace, window class, and window title for each window
# Get the current workspace
activeMonitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused==true)')
activeMonitorName=$(jq -r '.name' <<< $activeMonitor)
activeMonitorId=$(jq -r '.id' <<< $activeMonitor)
activeWorkspaceId=$(jq -r '.activeWorkspace | .id' <<< $activeMonitor)
windows=$(hyprctl clients -j | jq -r '.[] | select(.class!="")')
# if --monitor is passed, filter the windows to only those on the current monitor
if [ "$1" = "--monitor" ]; then
    windows=$(jq -r -n --arg activeMonitorID "$activeMonitorId" '[inputs] | .[] | select((.monitor|tostring)==$activeMonitorID)' <<< $windows)
fi
windowsString=$(jq -r '(.workspace.id | tostring | (. + " " * (20 - length))) + (.class | tostring | (. + " " * (20 - length))) + .title' <<< $windows)

# Get the active window
activeWindow=$(hyprctl activewindow -j)
activeWindowAddress=$(jq -r '.address' <<< $activeWindow)
activeWindowIndex=$(jq -r -n --arg activeWindowAddress "$activeWindowAddress" '[inputs] | to_entries | .[] | select(.value.address==$activeWindowAddress) .key' <<< $windows)
echo "Active window index: $activeWindowIndex"

# Use rofi to select a window
#rofi -no-config -no-lazy-grab -show window -modi window -theme ~/.config/polybar/shapes/scripts/rofi/window_switcher.rasi
selectedWindowID=$(echo $windowsString | rofi -no-config -no-lazy-grab -dmenu -i -matching fuzzy -format i -p 'windows:' -padding 20 -theme ~/.config/polybar/shapes/scripts/rofi/window_switcher.rasi -selected-row $activeWindowIndex)
# If no window was selected, exit (empty string)
if [ -z "$selectedWindowID" ]; then
    exit 0
fi
echo "Selected window ID: $selectedWindowID"
selectedWindow=$(jq -r -n --arg selectedWindowID "$selectedWindowID" '[inputs][$selectedWindowID | tonumber]' <<< $windows)
echo $selectedWindow
# Get the address of the selected window
selectedWindowAddress=$(jq -r '.address' <<< $selectedWindow)
# Focus the selected window
echo "Focusing window with Address $selectedWindowAddress"
hyprctl dispatch focuswindow address:$selectedWindowAddress