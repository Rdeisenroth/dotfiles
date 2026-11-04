-- Window border gradient follows the main monitor's bar colour scheme (written by
-- bar/ruboshapes/scripts/system-theme.py); falls back to the original teal -> purple.
local ok, scheme = pcall(dofile, os.getenv("HOME") .. "/.local/state/ruboshapes/hypr-scheme.lua")
if not ok or type(scheme) ~= "table" then scheme = { border1 = "rgba(53e2aeff)", border2 = "rgba(6603fcee)" } end

hl.config({
    general = {
        gaps_in       = 5,
        gaps_out      = 12,
        border_size   = 2,
        snap = {
            enabled = true,
        },
        col = {
            active_border = { colors = { scheme.border1, scheme.border2 }, angle = 45 },
        },
    },

    cursor = {
        no_warps = true,
    },

    decoration = {
        rounding     = 10,
        dim_strength = 0.25,
        shadow = {
            enabled = true,
            range   = 7,
        },
        blur = {
            enabled           = true,
            new_optimizations = true,
            size              = 6,
            passes            = 4,
            xray              = false,
            popups            = true,   -- blur popups too (bar tray dropdown, menus)
        },
    },

    misc = {
        -- Adaptive-Sync / G-Sync only for a Hyprland-fullscreen window.
        -- Keep games borderless at native resolution, then use Super+F.
        vrr                     = 3,
        focus_on_activate       = true,
        disable_autoreload      = false,
    },

    animations = {
        enabled = true,
    },

    opengl = {
        nvidia_anti_flicker = true,
    },

    xwayland = {
        force_zero_scaling = true,
    },

    debug = {
        disable_logs = false,
    },

    ecosystem = {
        no_donation_nag = true,
    },

    dwindle = {
        preserve_split     = true,
        precise_mouse_move = true,
        force_split        = 0,
    },
})

hl.curve("overshot", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.1 } } })
hl.curve("linear",   { type = "bezier", points = { { 0, 0 },      { 1, 1 } } })

hl.animation({ leaf = "windows",    enabled = true, speed = 4, bezier = "default", style = "popin" })
hl.animation({ leaf = "border",     enabled = true, speed = 2, bezier = "default" })
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "default", style = "slide" })

-- Tearing, cursor, DPMS and render settings are per machine (machines/*.lua).
-- Plugins: hyprfocus etc. are disabled in hyprpm. split-monitor-workspaces is
-- replaced by plain Lua in workspaces.lua, so no plugin config is needed here.
