hl.config({
    input = {
        kb_layout  = "de",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse       = 1,
        numlock_by_default = true,
        accel_profile      = "flat",

        touchpad = {
            natural_scroll = true,
            scroll_factor  = 0.5,
        },
        -- touchdevice / tablet outputs: machines/*.lua
    },
    binds = {
        scroll_event_delay = 0,
    },
})

hl.device({
    name       = "ydotoold-virtual-device",
    kb_layout  = "us",
    kb_variant = "",
    kb_options = "",
})

-- Touchpad gestures: machines/*.lua
