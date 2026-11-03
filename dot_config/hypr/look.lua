hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 12,
        border_size = 2,
        snap = {
            enabled = true,
        },
        col = {
            active_border = { colors = { "rgba(53e2aeff)", "rgba(6603fcee)" }, angle = 45 },
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
        },
    },

    misc = {
        vrr                = 3,
        focus_on_activate  = true,
        disable_autoreload = false,
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

    render = {
        direct_scanout = 0,
        cm_enabled     = true,
        cm_auto_hdr    = 0,
    },

    quirks = {
        prefer_hdr = 0,
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

-- hyprfocus is disabled in hyprpm, so its old config is dropped.
-- split-monitor-workspaces is replaced by plain Lua in workspaces.lua.
