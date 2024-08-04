#!/bin/zsh
zoomInc=0.2
ZOOM_FACTOR=$(hyprctl getoption misc:cursor_zoom_factor -j | jq -r '.float')
# if zoom.tmp exists and has at least one non-whitespace char, read the value from it
if [ -f $HYPRLAND_CONFIG_HOME/zoom.tmp ] && [ -n "$(cat $HYPRLAND_CONFIG_HOME/zoom.tmp)" ]; then
    ZOOM_FACTOR=$(cat $HYPRLAND_CONFIG_HOME/zoom.tmp)
fi
# if --inc is passed, increment the zoom factor by the value of $zoomInc
if [ "$1" = "--inc" ]; then
    # if a factor is passed, use it instead of $zoomInc
    if [ -n "$2" ]; then
        zoomInc=$2
    fi
    echo "Old zoom factor: $ZOOM_FACTOR"
    ZOOM_FACTOR=$(python -c "print($ZOOM_FACTOR*(1+$zoomInc))")
# if --dec is passed, decrement the zoom factor by the value of $zoomInc
elif [ "$1" = "--dec" ]; then
    # if a factor is passed, use it instead of $zoomInc
    if [ -n "$2" ]; then
        zoomInc=$2
    fi
    ZOOM_FACTOR=$(python -c "print($ZOOM_FACTOR/(1+$zoomInc))")
# if --reset is passed, reset the zoom factor to 1
elif [ "$1" = "--reset" ]; then
    ZOOM_FACTOR=1
    rm $HYPRLAND_CONFIG_HOME/zoom.tmp
else
    echo "Usage: zoom.sh [--inc|--dec|--reset]"
    exit 1
fi

# if zoom factor <= 1, reset it to 1 and delete zoom.tmp
if [ $(python -c "print($ZOOM_FACTOR <= 1)") = "True" ]; then
    ZOOM_FACTOR=1
    rm $HYPRLAND_CONFIG_HOME/zoom.tmp
else
    echo $ZOOM_FACTOR > $HYPRLAND_CONFIG_HOME/zoom.tmp
fi

echo "Zoom factor: $ZOOM_FACTOR"

# set the zoom factor
hyprctl keyword misc:cursor_zoom_factor $ZOOM_FACTOR