#!/usr/bin/env bash

set -Eeuo pipefail

# This workaround is specific to the SDDM compositor handoff. Do not flash the
# display when Hyprland is started directly from a TTY or another launcher.
[[ ${HYPRLAND_SDDM_HANDOFF:-0} == 1 ]] || exit 0

readonly target_description='Dell Inc. DELL U2715H GH85D89L0J9S'
readonly log_tag='hyprland-dell-retrain'

exec {lock_fd}>"${XDG_RUNTIME_DIR:?}/hypr-retrain-right-dell.lock"
flock -n "$lock_fd" || exit 0

# Let HyprDynamicMonitors finish applying the selected lid profile first.
sleep 5

output="$({ hyprctl monitors all -j 2>/dev/null || true; } | jq -r \
    --arg description "$target_description" \
    '[.[] | select(.description == $description and (.disabled | not))][0].name // empty')"

if [[ -z "$output" ]]; then
    logger -t "$log_tag" -- 'right Dell is not active; skipping retrain' 2>/dev/null || true
    exit 0
fi

logger -t "$log_tag" -- "retraining $output after SDDM handoff" 2>/dev/null || true
hyprctl eval "hl.monitor({ output = \"$output\", disabled = true })" >/dev/null
sleep 3
hyprctl eval "hl.monitor({ output = \"$output\", mode = \"2560x1440@60\", position = \"2560x0\", scale = 1, bitdepth = 8 })" >/dev/null
logger -t "$log_tag" -- "retrain complete for $output" 2>/dev/null || true
