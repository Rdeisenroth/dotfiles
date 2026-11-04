#!/usr/bin/env bash

set -Eeuo pipefail

readonly target_description='ASUSTek COMPUTER INC XG27AQDMGR W3LMTF178243'

# Ignore repeated key presses while the link-training sequence is still active.
exec {lock_fd}>"${XDG_RUNTIME_DIR:?}/hypr-reset-asus-oled.lock"
flock -n "$lock_fd" || exit 0

# Resolve the connector dynamically because dock connector names can change.
# With any other dock or display set this exits without touching an output.
output="$({ hyprctl monitors all -j 2>/dev/null || true; } | jq -r \
    --arg description "$target_description" \
    '[.[] | select(.description == $description and (.disabled | not))][0].name // empty')"

if [[ -z "$output" ]]; then
    exit 0
fi

recover_output() {
    hyprctl eval "hl.monitor({ output = \"$output\", mode = \"2560x1440@60\", position = \"0x0\", scale = 1, bitdepth = 8 })" >/dev/null 2>&1 || true
}

# A plain DPMS cycle and recreating 120 Hz/10-bit did not reliably retrain the
# dock's DisplayPort link. A conservative 60 Hz/8-bit link recovered the image,
# while promoting that working link back to 120 Hz/10-bit lost signal again.
# Leave the emergency recovery at the mode that is confirmed to display.
trap recover_output EXIT
hyprctl eval "hl.monitor({ output = \"$output\", disabled = true })" >/dev/null
sleep 2
recover_output
trap - EXIT
