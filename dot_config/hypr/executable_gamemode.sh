#!/usr/bin/env sh
# Toggle "game mode": turn off animations, blur, shadows, gaps and rounding.
# Running it again reloads the config, which restores everything.
ENABLED=$(hyprctl getoption animations:enabled -j | jq -r '.int // .bool')
if [ "$ENABLED" = "1" ] || [ "$ENABLED" = "true" ]; then
    hyprctl eval 'hl.config({
        animations = { enabled = false },
        decoration = { shadow = { enabled = false }, blur = { enabled = false }, rounding = 0 },
        general    = { gaps_in = 0, gaps_out = 0, border_size = 1 },
    })'
    exit
fi
hyprctl reload
