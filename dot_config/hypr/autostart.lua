local CFG = os.getenv("HOME") .. "/.config/hypr"

hl.on("hyprland.start", function()
    -- Plugins
    -- reload the config afterwards: plugin options (plugins.lua) only exist once they are loaded
    hl.exec_cmd("hyprpm reload -n && hyprctl reload")
    hl.exec_cmd("hyprctl setcursor breeze_cursors 24")

    -- Session / system
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("nm-applet --indicator")
    -- hl.exec_cmd("swaync")  -- replaced by Caelestia notifications (popups + sidebar)
    hl.exec_cmd("copyq --start-server")
    hl.exec_cmd("wl-clip-persist --clipboard regular")
    -- hl.exec_cmd(CFG .. "/bar/saimoomedits/eww/bar/launch_bar")  -- previous bar
    hl.exec_cmd(CFG .. "/bar/ruboshapes/launch")
    -- Caelestia: dashboard, power menu and notifications (its bar/launcher are off in
    -- ~/.config/caelestia/shell.json).
    hl.exec_cmd("caelestia shell -d")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("/usr/lib/pam_kwallet_init")
    hl.exec_cmd("/usr/lib/kf6/baloo_file")
    hl.exec_cmd("xwaylandvideobridge")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("polychromatic-helper --autostart")
    hl.exec_cmd("easyeffects --gapplication-service")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("xsettingsd -c " .. os.getenv("HOME") .. "/.config/xsettingsd/xsettingsd.conf")   -- live GTK theme for XWayland apps (incl. root GParted), written by the bar's theme script

    -- Apps (machine-specific extras: machines/*.lua)
    hl.exec_cmd("spotify-launcher") -- Wayland flags live in ~/.config/spotify-launcher.conf
    hl.exec_cmd("vesktop")
    hl.exec_cmd("nextcloud --background")
    hl.exec_cmd("sleep 3; waypaper --restore --backend awww")
end)
