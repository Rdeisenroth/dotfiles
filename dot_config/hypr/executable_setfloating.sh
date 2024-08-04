#! /bin/bash
# This script is used to set the floating status of a window. It gets one boolean argument, which is the new floating status of the window. If the argument is true, the window will be set to floating, otherwise it will be set to tiling. The script will also set the window to the correct layer, depending on the floating status.

# Check if the script is called with the correct number of arguments
if [ $# -ne 1 ]; then
    echo "Usage: $0 <shouldFloat>"
    exit 1
fi

# Check if the argument is a boolean
# Accept either true or false, or 0 or 1, or yes or no, or y or n, or t or f, or on or off
if [[ $1 =~ ^(true|1|yes|y|t|on)$ ]]; then
    shouldFloat=true
elif [[ $1 =~ ^(false|0|no|n|f|off)$ ]]; then
    shouldFloat=false
else
    echo "Invalid argument: $1"
    exit 1
fi

# Check if the window is already in the correct floating status
windowFloating="$(hyprctl -j activewindow | jq -r '.floating')"

# Check if we need to change the floating status
if [ "$windowFloating" != "$shouldFloat" ]; then
    hyprctl dispatch togglefloating active
fi