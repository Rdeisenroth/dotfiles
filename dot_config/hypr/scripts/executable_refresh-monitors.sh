#!/usr/bin/env bash

set -Eeuo pipefail

mapfile -t monitors < <(hyprctl monitors -j | jq -r '.[].name')

for monitor in "${monitors[@]}"; do
  hyprctl dispatch "hl.dsp.dpms({ action = \"off\", monitor = \"$monitor\" })" >/dev/null
done

sleep 1

for monitor in "${monitors[@]}"; do
  hyprctl dispatch "hl.dsp.dpms({ action = \"on\", monitor = \"$monitor\" })" >/dev/null
done
