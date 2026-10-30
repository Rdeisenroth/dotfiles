local HOME = os.getenv("HOME")
local RUNTIME = os.getenv("XDG_RUNTIME_DIR") or ("/run/user/" .. (os.getenv("UID") or "1000"))

local env = {
    -- Nvidia
    LIBVA_DRIVER_NAME = "nvidia",
    XDG_SESSION_TYPE = "wayland",
    __GLX_VENDOR_LIBRARY_NAME = "nvidia",
    NVD_BACKEND = "direct",
    -- WLR_DRM_NO_ATOMIC is intentionally left unset (breaks nested Gamescope on current NVIDIA).
    __GL_GSYNC_ALLOWED = "1",
    __GL_VRR_ALLOWED = "1",

    -- Cursor
    XCURSOR_THEME = "breeze_cursors",
    XCURSOR_SIZE = "24",
    HYPRCURSOR_THEME = "breeze_cursors",
    HYPRCURSOR_SIZE = "24",

    -- Qt
    QT_AUTO_SCREEN_SCALE_FACTOR = "1",
    QT_QPA_PLATFORM = "wayland;xcb",
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1",
    QT_QPA_PLATFORMTHEME = "qt5ct:qt6ct",

    -- Firefox hardware acceleration
    MOZ_DISABLE_RDD_SANDBOX = "1",
    EGL_PLATFORM = "wayland",
    MOZ_ENABLE_WAYLAND = "1",

    -- Java
    _JAVA_AWT_WM_NONEREPARENTING = "1",

    -- Other
    CLUTTER_BACKEND = "wayland",
    HYPRLAND_CONFIG_HOME = HOME .. "/.config/hypr/",
    XDG_CONFIG_HOME = HOME .. "/.config",
    GTK_USE_PORTAL = "1",
    AWWW_TRANSITION_FPS = "144",
    SSH_AUTH_SOCK = RUNTIME .. "/ssh-agent.socket",

    -- Electron
    ELECTRON_OZONE_PLATFORM_HINT = "auto",
    -- Steam is an XWayland client; scale its UI internally to stay sharp at 1.5x.
    STEAM_FORCE_DESKTOPUI_SCALING = "1.5",
    XDG_MENU_PREFIX = "arch-",

    -- Ansible
    ANSIBLE_NOCOWS = "1",
}

for name, value in pairs(env) do
    hl.env(name, value)
end
