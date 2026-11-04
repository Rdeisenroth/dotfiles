-- Laptop: NVIDIA Optimus, eDP-1 panel plus changing docks.
-- Monitor layouts come from hyprdynamicmonitors (~/.config/hyprdynamicmonitors), which
-- writes monitors.lua. Loaded by hyprland.lua; setup() runs after the shared modules.
local M = {}

-- No fixed slots: dock outputs (DP-1, DP-2, ...) change, so workspaces.lua uses the monitor ID.
M.monitor_slots = {}

function M.setup()
    local HOME = os.getenv("HOME")
    local CFG = HOME .. "/.config/hypr"
    local exec = hl.dsp.exec_cmd

    -- Nvidia / Optimus
    -- Keep NVIDIA selection per app (prime-run, gamescope args, Steam launch options).
    -- AQ_MGPU_NO_EXPLICIT avoids explicit sync on multi-GPU buffers, which is a
    -- narrower workaround for NVIDIA Optimus crashes than disabling atomic DRM.
    hl.env("AQ_MGPU_NO_EXPLICIT", "1")
    hl.env("__GL_GSYNC_ALLOWED", "0")
    hl.env("__GL_VRR_ALLOWED", "0")

    hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
    hl.env("GDK_BACKEND", "wayland,x11,*")
    hl.env("SDL_VIDEODRIVER", "wayland")
    hl.env("GTK_IM_MODULE", "simple")

    -- Private env vars (tokens), kept outside the dotfiles. Optional.
    local secrets = HOME .. "/.local/state/hypr-secrets.lua"
    local f = io.open(secrets, "r")
    if f then
        f:close()
        local ok, err = pcall(dofile, secrets)
        if not ok then print("hypr-secrets.lua failed to load: " .. tostring(err)) end
    end

    -- Fallback for any monitor without a rule (e.g. before hyprdynamicmonitors has run).
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

    hl.config({
        render = {
            direct_scanout = 0,
            cm_enabled     = true,
            cm_auto_hdr    = 0,
        },
        quirks = { prefer_hdr = 0 },
        input = {
            touchdevice = { output = "DP-4" },
        },
    })

    hl.gesture({ fingers = 3, direction = "horizontal", scale = 0.5, action = "workspace" })

    hl.on("hyprland.start", function()
        -- Monitor profiles (writes monitors.lua) + SDDM handoff workaround for the right Dell
        hl.exec_cmd("hyprdynamicmonitors run --enable-lid-events")
        hl.exec_cmd(CFG .. "/scripts/retrain-right-dell-after-sddm.sh")
        -- Apps
        hl.exec_cmd(HOME .. "/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox --minimize")
        hl.exec_cmd("'/opt/Mullvad VPN/mullvad-vpn'")
    end)

    -- Lock screen + suspend (hyprlock, see hyprlock.conf / hypridle.conf)
    hl.bind("SUPER + L",         exec("pidof hyprlock >/dev/null || hyprlock"), { description = "Session: Lock screen" })
    hl.bind("SUPER + SHIFT + L", exec("systemctl suspend"), { locked = true, description = "Session: Suspend" })

    -- Refresh all active monitor links (like Windows Win+Ctrl+Shift+B)
    hl.bind("SUPER + CONTROL + SHIFT + B", exec(CFG .. "/scripts/refresh-monitors.sh"), { description = "Monitors: Refresh all links" })
    -- Recover the parents'-dock ASUS OLED from an NVIDIA page-flip stall
    hl.bind("SUPER + SHIFT + ALT + B",     exec(CFG .. "/scripts/reset-asus-oled.sh"), { description = "Monitors: Reset parents' ASUS OLED" })
end

return M
