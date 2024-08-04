#! /bin/bash

# Arguments
# --dry-run, -d: Print the wallpaper path without setting it
# --wallpaper-dir, -w: Set the wallpaper directory
# --next, -n: Set the next wallpaper from the wallpaper directory
# --random, -r: Set a random wallpaper from the wallpaper directory
# --set -s: Set the wallpaper to the given path
# --help -h: Print help message
# --monitor -m: Set the wallpaper for the given monitor or "*","all" for all monitors or "current" for the current monitor
# --list, -l: List all available wallpapers
# --list-monitors, -lm: List all available monitors
# --force, -f: Force setting the wallpaper even if it is currently locked

# Default values
WALLPAPER_DIR="$HOME/Bilder/wallpapers/"
WALLPAPER=""
DRY_RUN=false
NEXT=false
USE_RANDOM=false
SET=false
LIST=false
LIST_MONITORS=false
MONITORS="current"
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
    -d | --dry-run)
        DRY_RUN=true
        shift
        ;;
    -w | --wallpaper-dir)
        WALLPAPER_DIR="$2"
        shift
        shift
        ;;
    -n | --next)
        NEXT=true
        shift
        ;;
    -r | --random)
        USE_RANDOM=true
        shift
        ;;
    -s | --set)
        SET=true
        USE_RANDOM=false
        WALLPAPER="$2"
        shift
        shift
        ;;
    -h | --help)
        echo "Usage: load-wallpaper.sh [OPTION]..."
        echo "Set the wallpaper."
        echo ""
        echo "  -d, --dry-run          Print the wallpaper path without setting it"
        echo "  -w, --wallpaper-dir    Set the wallpaper directory"
        echo "  -n, --next             Set the next wallpaper from the wallpaper directory"
        echo "  -r, --random           Set a random wallpaper from the wallpaper directory"
        echo "  -s, --set              Set the wallpaper to the given path"
        echo "  -h, --help             Print help message"
        echo "  -m, --monitor          Set the wallpaper for the given monitor or \"*\",\"all\" for all monitors or \"current\" for the current monitor"
        echo "  -l, --list             List all available wallpapers"
        echo "  -lm, --list-monitors   List all available monitors"
        echo "  -f, --force            Force setting the wallpaper even if it is currently locked"
        exit 0
        ;;
    -m | --monitor)
        MONITORS="$2"
        shift
        shift
        ;;
    -l | --list)
        LIST=true
        shift
        ;;
    -lm | --list-monitors)
        LIST_MONITORS=true
        shift
        ;;
    -f | --force)
        FORCE=true
        shift
        ;;
    *)
        echo "Unknown argument: $key"
        exit 1
        ;;
    esac
done

# List all available wallpapers
if $LIST; then
    find $WALLPAPER_DIR -type f
    exit 0
fi

# List all available monitors
if $LIST_MONITORS; then
    hyprctl monitors -j | jq -r '.[] | .name'
    exit 0
fi

# Set the wallpaper for the given monitor
if [ "$MONITORS" == "current" ]; then
    MONITORS=`hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name'`
elif [ "$MONITORS" == "*" ] || [ "$MONITORS" == "all" ]; then
    MONITORS=`hyprctl monitors -j | jq -r '.[] | .name'`
fi

# Set the wallpaper
set_wallpaper() {
    echo -e "Setting wallpaper to $WALLPAPER for monitor(s)\n$MONITORS"
    if $FORCE; then
        if $DRY_RUN; then
            echo "rm -f \"wallpaper.lock\""
        else
            rm -f "wallpaper.lock"
        fi
    fi
    # if wallpaper.lock exists, and force is not set, exit
    if [ -f "wallpaper.lock" ] && ! $FORCE; then
        echo "Wallpaper is locked by another instance of this script."
        exit 1
    fi
    # create wallpaper.lock file to prevent wallpaper from being changed by hyprpaper
    if $DRY_RUN; then
        echo "touch \"wallpaper.lock\""
    else
        touch "wallpaper.lock"
    fi
    # check if hyprpaper is running
    if ! pgrep -x "hyprpaper" > /dev/null; then
        echo "hyprpaper is not running, starting it"
        if $DRY_RUN; then
            echo "hyprpaper&"
            echo "disown"
        else
            hyprpaper&
            disown
        fi
    fi
    if $DRY_RUN; then
            echo "hyprctl hyprpaper preload \"$WALLPAPER\""
        else
            hyprctl hyprpaper preload "$WALLPAPER"
        fi
    for monitor in $MONITORS; do
        if $DRY_RUN; then
            echo "hyprctl hyprpaper wallpaper \"$monitor\",\"$WALLPAPER\""
        else
            hyprctl hyprpaper wallpaper "$monitor","$WALLPAPER"
        fi
    done
    # sleep 2;
    # echo "unloading wallpaper(s) that are not used to free memory"
    # if $DRY_RUN; then
    #     echo "hyprctl hyprpaper unload all"
    # else
    #     hyprctl hyprpaper unload all
    # fi
    # remove wallpaper.lock file
    if $DRY_RUN; then
        echo "rm -f \"wallpaper.lock\""
    else
        rm -f "wallpaper.lock"
    fi
    echo "done"
    exit 0
}

# Set the next wallpaper
if $NEXT; then
    CURRENT_WALLPAPER=$(hyprctl hyprpaper wallpaper -j | jq -r '.[] | .wallpaper')
    WALLPAPER=$(find $WALLPAPER_DIR -type f | grep -A 1 "$CURRENT_WALLPAPER" | tail -n 1)
    if [ -z "$WALLPAPER" ]; then
        WALLPAPER=$(find $WALLPAPER_DIR -type f | head -n 1)
    fi
    set_wallpaper
fi

# Set a random wallpaper
if $USE_RANDOM; then
    WALLPAPER=$(find $WALLPAPER_DIR -type f | shuf -n1)
    set_wallpaper
fi

# Set the wallpaper to the given path
if $SET; then
    set_wallpaper
fi

# no arguments given
if [ -z "$WALLPAPER" ]; then
    echo "No wallpaper specified"
    exit 1
fi