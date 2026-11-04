-- Main PC: desktop NVIDIA GPU, DP-1 / ASUS PG32UCDP (DP-3) / DP-2 side by side.
-- Loaded by hyprland.lua; setup() runs after the shared modules, so it can override them.
local M = {}

-- Fixed workspace slots per output (see workspaces.lua): DP-1 1..10, DP-2 11..20, DP-3 21..30.
M.monitor_slots = { ["DP-1"] = 0, ["DP-2"] = 1, ["DP-3"] = 2 }

function M.setup()
    local CFG = os.getenv("HOME") .. "/.config/hypr"
    local exec = hl.dsp.exec_cmd

    -- Nvidia
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
    -- WLR_DRM_NO_ATOMIC is intentionally left unset (breaks nested Gamescope on current NVIDIA).
    hl.env("__GL_GSYNC_ALLOWED", "1")
    hl.env("__GL_VRR_ALLOWED", "1")
    -- Steam is an XWayland client; scale its UI internally to stay sharp at 1.5x.
    hl.env("STEAM_FORCE_DESKTOPUI_SCALING", "1.5")

    hl.config({
        general = { allow_tearing = true },
        cursor = {
            no_hardware_cursors = true,
            use_cpu_buffer      = false,
        },
        misc = {
            mouse_move_enables_dpms = true,
            key_press_enables_dpms  = true,
        },
        render = { direct_scanout = 1 },
        input = {
            touchdevice = {
                output  = "DP-3",
                enabled = false,
            },
            tablet = {
                output = "DP-3",
                -- old region_size 5120x1440 is over the new 4000 limit; dropped.
                -- region_position = { 0, 0 },
                -- region_size     = { 4000, 1440 },
            },
        },
    })

    hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

    -- Monitor input switching (ASUS_USBC lives in monitor-mode.conf)
    hl.bind("SUPER + P",         exec(CFG .. "/monitor-mode.sh pc"),     { locked = true, description = "Monitors: ASUS input → PC" })
    hl.bind("SUPER + SHIFT + P", exec(CFG .. "/monitor-mode.sh laptop"), { locked = true, description = "Monitors: ASUS input → laptop" })

    -- Lock screen (Caelestia's; it also answers `loginctl lock-session`, see hypridle.conf)
    hl.bind("SUPER + L", exec("qs -c caelestia ipc call lock lock"), { description = "Session: Lock screen" })
end

return M
