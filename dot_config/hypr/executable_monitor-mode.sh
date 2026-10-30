#!/usr/bin/env bash

set -u

# Monitor EDID serials. These are more stable than /dev/i2c-N bus numbers.
DELL_LEFT="GH85D72P126S"
DELL_RIGHT="GH85D89R048S"
ASUS="SALMQS179542"

INPUT_VCP="0x60"

# Dell U2715H input values
DELL_DP="0x0f"
DELL_HDMI1="0x11"

# ASUS PG32UCDP: DisplayPort is normally 0x0f. USB-C is model-specific.
ASUS_DP="0x0f"
ASUS_USBC=""

# Keep the optional override beside this Hyprland configuration.
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/monitor-mode.conf"
if [[ -r "$CONFIG" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG"
fi

notify() {
    command -v notify-send >/dev/null 2>&1 && notify-send -a "Monitor Mode" "$1"
}

set_input() {
    local serial="$1"
    local value="$2"
    local description="$3"

    printf 'Switching %-14s -> %s\n' "$serial" "$description"
    if ! ddcutil --sn "$serial" setvcp "$INPUT_VCP" "$value"; then
        printf 'ERROR: failed to switch %s\n' "$serial" >&2
        return 1
    fi
}

pc_mode() {
    echo "Switching monitors to PC mode..."
    local failed=0
    set_input "$DELL_LEFT"  "$DELL_DP"    "DisplayPort" || failed=1
    set_input "$DELL_RIGHT" "$DELL_DP"    "DisplayPort" || failed=1
    set_input "$ASUS"       "$ASUS_DP"    "DisplayPort" || failed=1

    if (( failed )); then
        notify "PC mode: one or more monitors failed"
        return 1
    fi
    notify "PC mode"
}

laptop_mode() {
    if [[ -z "$ASUS_USBC" ]]; then
        notify "Laptop mode: configure ASUS USB-C input value"
        cat >&2 <<EOF
ASUS USB-C input value has not been configured.

Switch the ASUS manually to USB-C, then run:
    ddcutil --sn $ASUS getvcp $INPUT_VCP

Put the reported sl=0x?? value in:
    $CONFIG

Example: ASUS_USBC="0x13"
EOF
        return 2
    fi

    echo "Switching monitors to laptop mode..."
    local failed=0
    set_input "$DELL_LEFT"  "$DELL_HDMI1" "HDMI (MHL) 1" || failed=1
    set_input "$DELL_RIGHT" "$DELL_HDMI1" "HDMI (MHL) 1" || failed=1
    set_input "$ASUS"       "$ASUS_USBC"  "USB-C"        || failed=1

    if (( failed )); then
        notify "Laptop mode: one or more monitors failed"
        return 1
    fi
    notify "Laptop mode"
}

probe() {
    for pair in "Dell left:$DELL_LEFT" "Dell right:$DELL_RIGHT" "ASUS:$ASUS"; do
        name=${pair%%:*}
        serial=${pair#*:}
        echo "=== $name ==="
        ddcutil --sn "$serial" getvcp "$INPUT_VCP" || true
        echo
    done
}

case "${1:-}" in
    pc) pc_mode ;;
    laptop) laptop_mode ;;
    probe) probe ;;
    *) echo "Usage: $0 {pc|laptop|probe}" >&2; exit 2 ;;
esac
