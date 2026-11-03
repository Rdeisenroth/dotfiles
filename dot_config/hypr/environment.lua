local HOME = os.getenv("HOME")
local RUNTIME = os.getenv("XDG_RUNTIME_DIR") or ("/run/user/" .. (os.getenv("UID") or "1000"))

local env = {
    -- Nvidia / Optimus
    -- Keep NVIDIA selection per app (prime-run, gamescope args, Steam launch options).
    -- AQ_MGPU_NO_EXPLICIT avoids explicit sync on multi-GPU buffers, which is a
    -- narrower workaround for NVIDIA Optimus crashes than disabling atomic DRM.
    AQ_MGPU_NO_EXPLICIT = "1",
    __GL_GSYNC_ALLOWED = "0",
    __GL_VRR_ALLOWED = "0",

    -- XDG
    XDG_SESSION_TYPE = "wayland",
    XDG_CURRENT_DESKTOP = "Hyprland",
    XDG_CONFIG_HOME = HOME .. "/.config",
    XDG_MENU_PREFIX = "arch-",

    -- Cursor
    XCURSOR_THEME = "breeze_cursors",
    XCURSOR_SIZE = "24",
    HYPRCURSOR_THEME = "breeze_cursors",
    HYPRCURSOR_SIZE = "24",

    -- Toolkits
    QT_AUTO_SCREEN_SCALE_FACTOR = "1",
    QT_QPA_PLATFORM = "wayland;xcb",
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1",
    QT_QPA_PLATFORMTHEME = "qt5ct:qt6ct",
    GDK_BACKEND = "wayland,x11,*",
    SDL_VIDEODRIVER = "wayland",
    CLUTTER_BACKEND = "wayland",

    -- Firefox hardware acceleration
    MOZ_DISABLE_RDD_SANDBOX = "1",
    EGL_PLATFORM = "wayland",
    MOZ_ENABLE_WAYLAND = "1",

    -- Java
    _JAVA_AWT_WM_NONREPARENTING = "1",

    -- Other
    HYPRLAND_CONFIG_HOME = HOME .. "/.config/hypr/",
    GTK_USE_PORTAL = "1",
    GTK_IM_MODULE = "simple",
    AWWW_TRANSITION_FPS = "144",
    SSH_AUTH_SOCK = RUNTIME .. "/ssh-agent.socket",

    -- Electron
    ELECTRON_OZONE_PLATFORM_HINT = "auto",

    -- Ansible
    ANSIBLE_NOCOWS = "1",
}

for name, value in pairs(env) do
    hl.env(name, value)
end

-- Private env vars (tokens), kept outside this folder. Optional.
local secrets = HOME .. "/.local/state/hypr-secrets.lua"
local f = io.open(secrets, "r")
if f then
    f:close()
    local ok, err = pcall(dofile, secrets)
    if not ok then print("hypr-secrets.lua failed to load: " .. tostring(err)) end
end
