local HOME = os.getenv("HOME")
local RUNTIME = os.getenv("XDG_RUNTIME_DIR") or ("/run/user/" .. (os.getenv("UID") or "1000"))

local env = {
    -- GPU variables (desktop NVIDIA vs. laptop Optimus) live in machines/*.lua.
    XDG_SESSION_TYPE = "wayland",

    -- Cursor
    XCURSOR_THEME = "breeze_cursors",
    XCURSOR_SIZE = "24",
    HYPRCURSOR_THEME = "breeze_cursors",
    HYPRCURSOR_SIZE = "24",

    -- Qt
    QT_AUTO_SCREEN_SCALE_FACTOR = "1",
    QT_QPA_PLATFORM = "wayland;xcb",
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1",
    -- Qt6: KDE platform theme (Darkly + live colour switching, see bar/ruboshapes/scripts/system-theme.py); Qt5 via plasma5-integration
    QT_QPA_PLATFORMTHEME = "kde",   -- not "kde:qt5ct": a fallback list breaks live palette updates

    -- Firefox hardware acceleration
    MOZ_DISABLE_RDD_SANDBOX = "1",
    EGL_PLATFORM = "wayland",
    MOZ_ENABLE_WAYLAND = "1",

    -- Java
    _JAVA_AWT_WM_NONREPARENTING = "1",

    -- Other
    CLUTTER_BACKEND = "wayland",
    HYPRLAND_CONFIG_HOME = HOME .. "/.config/hypr/",
    XDG_CONFIG_HOME = HOME .. "/.config",
    GTK_USE_PORTAL = "1",
    AWWW_TRANSITION_FPS = "144",
    SSH_AUTH_SOCK = RUNTIME .. "/ssh-agent.socket",

    -- Electron
    ELECTRON_OZONE_PLATFORM_HINT = "auto",
    XDG_MENU_PREFIX = "arch-",

    -- Ansible
    ANSIBLE_NOCOWS = "1",
}

for name, value in pairs(env) do
    hl.env(name, value)
end
