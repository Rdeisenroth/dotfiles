local CFG = os.getenv("HOME") .. "/.config/hypr"
local mod = "SUPER"

local function k(keys) return mod .. " + " .. keys end
local exec = hl.dsp.exec_cmd

-- Every Super combo first hides the keybind cheat sheet (bar/ruboshapes/components/KeysOverlay.qml),
-- so holding Super a bit and then pressing e.g. Space closes it. Mouse and release binds stay as they are.
local function bind(keys, action, opts)
    opts = opts or {}
    if keys:find("^SUPER") and not opts.mouse and not opts.release and keys ~= "SUPER + SUPER_L" then
        local act = action
        action = function()
            hl.dispatch(hl.dsp.global("ruboshapes:keys-hide"))
            if type(act) == "function" then act() else hl.dispatch(act) end
        end
    end
    return hl.bind(keys, action, opts)
end

-- Apps
bind(k("Return"),      exec("ghostty"), { description = "Apps: Terminal" })
bind(k("E"),           exec("dolphin"), { description = "Apps: File manager" })
bind(k("I"),           exec("firefox"), { description = "Apps: Firefox" })
bind(k("SHIFT + I"),   exec("mullvad-browser"), { description = "Apps: Mullvad browser" })
-- hl.bind(k("space"),    exec("~/.config/polybar/shapes/scripts/launcher.sh"))  -- old rofi launcher
bind(k("space"),       exec("caelestia shell drawers toggle launcher"), { description = "Apps: Launcher" })
-- KDE Plasma's emoji picker (copies the chosen emoji)
bind(k("period"),      exec("plasma-emojier"), { description = "Apps: Emoji picker" })

-- Window management
bind(k("W"),           hl.dsp.window.close(), { description = "Windows: Close" })
bind(k("SHIFT + W"),   exec("hyprctl kill"), { description = "Windows: Kill (click a window)" })
bind("SUPER + ALT + Q", hl.dsp.exit(), { description = "Session: Exit Hyprland" })
bind(k("S"),           hl.dsp.window.float({ action = "enable" }), { description = "Windows: Float" }) -- was setfloating.sh true
bind(k("T"),           hl.dsp.window.float({ action = "disable" }), { description = "Windows: Tile" }) -- was setfloating.sh false
bind(k("F"),           hl.dsp.window.fullscreen({ mode = "fullscreen" }), { description = "Windows: Fullscreen" })
bind(k("M"),           hl.dsp.window.fullscreen({ mode = "maximized" }), { description = "Windows: Maximize" })
bind(k("SHIFT + Y"),   hl.dsp.window.pseudo(), { description = "Windows: Pseudotile" })
bind(k("A"),           hl.dsp.layout("togglesplit"), { description = "Windows: Toggle split" })
-- Rotate the focused window's split 90° clockwise (bspwm Super+R, but per split, not the whole tree)
bind(k("R"),           hl.dsp.layout("rotatesplit 90"), { description = "Windows: Rotate split 90°" })

-- Monitor input switching (ASUS_USBC lives in monitor-mode.conf)
bind(k("P"),           exec(CFG .. "/monitor-mode.sh pc"),     { locked = true, description = "Monitors: ASUS input → PC" })
bind(k("SHIFT + P"),   exec(CFG .. "/monitor-mode.sh laptop"), { locked = true, description = "Monitors: ASUS input → laptop" })

local dirs = { left = "left", right = "right", up = "up", down = "down" }
local short = { left = "l", right = "r", up = "u", down = "d" }
local resize = { left = { -20, 0 }, right = { 20, 0 }, up = { 0, -20 }, down = { 0, 20 } }

for key, dir in pairs(dirs) do
    bind(k(key),                     hl.dsp.focus({ direction = dir }), { description = "Windows: Focus (arrows)" })
    bind(k("CONTROL + " .. key),     hl.dsp.focus({ monitor = short[key] }), { description = "Monitors: Focus monitor (arrows)" })
    bind(k("ALT + " .. key),         hl.dsp.window.resize({ x = resize[key][1], y = resize[key][2], relative = true }), { description = "Windows: Resize (arrows)" })
    bind(k("SHIFT + " .. key),       hl.dsp.window.move({ direction = dir }), { description = "Windows: Move (arrows)" })
    bind(k("CONTROL + SHIFT + " .. key), hl.dsp.window.move({ monitor = short[key] }), { description = "Monitors: Move window to monitor (arrows)" })
end

-- Mouse move/resize
bind(k("mouse:272"), hl.dsp.window.drag(),   { mouse = true, description = "Windows: Drag with mouse" })
bind(k("mouse:273"), hl.dsp.window.resize(), { mouse = true, description = "Windows: Resize with mouse" })

-- Scroll through existing workspaces
bind(k("mouse_down"), hl.dsp.focus({ workspace = "e+1" }), { description = "Workspaces: Next (scroll)" })
bind(k("mouse_up"),   hl.dsp.focus({ workspace = "e-1" }), { description = "Workspaces: Previous (scroll)" })

-- Per-monitor workspaces (see workspaces.lua)
for i = 1, 10 do
    local key = tostring(i % 10)
    bind(k(key),             function() split_workspace(i) end, { description = "Workspaces: Go to 1–10" })
    bind(k("SHIFT + " .. key), function() split_move_silent(i) end, { description = "Workspaces: Move window to 1–10" })
end

-- Audio
bind("XF86AudioLowerVolume", exec("pactl set-sink-volume @DEFAULT_SINK@ -5%"), { description = "Media: Volume down" })
bind("XF86AudioRaiseVolume", exec("pactl set-sink-volume @DEFAULT_SINK@ +5%"), { description = "Media: Volume up" })
bind("XF86AudioMute",        exec("pactl set-sink-mute @DEFAULT_SINK@ toggle"), { description = "Media: Mute" })

-- Media
bind("XF86AudioPlay", exec("playerctl play-pause"), { description = "Media: Play/pause" })
bind("XF86AudioStop", exec("playerctl stop"), { description = "Media: Stop" })
bind("XF86AudioNext", exec("playerctl next"), { description = "Media: Next track" })
bind("XF86AudioPrev", exec("playerctl previous"), { description = "Media: Previous track" })
bind(k("XF86AudioPlay"),        exec("playerctl --player=spotify play-pause"), { description = "Media: Spotify play/pause" })
bind(k("XF86AudioStop"),        exec("playerctl --player=spotify stop"), { description = "Media: Spotify stop" })
bind(k("XF86AudioNext"),        exec("playerctl --player=spotify next"), { description = "Media: Spotify next" })
bind(k("XF86AudioPrev"),        exec("playerctl --player=spotify previous"), { description = "Media: Spotify previous" })
bind(k("XF86AudioLowerVolume"), exec("playerctl --player=spotify volume 0.05-"), { description = "Media: Spotify volume down" })
bind(k("XF86AudioRaiseVolume"), exec("playerctl --player=spotify volume 0.05+"), { description = "Media: Spotify volume up" })

-- Keybind cheat sheet (bar/ruboshapes/components/KeysOverlay.qml): hold Super, release to hide
bind("SUPER + SUPER_L", hl.dsp.global("ruboshapes:keys-show"))
bind("SUPER + SUPER_L", hl.dsp.global("ruboshapes:keys-hide"), { release = true })

-- Window switcher
-- ruboshapes switcher (bar/ruboshapes/components/Switcher.qml): hold Alt, Tab to cycle (Left arrow
-- goes back), release Alt to focus; type to fuzzy-search (then Enter). Alt+Shift+Tab: current monitor only.
-- Old rofi version: window-switcher.sh
bind("ALT + Tab",         hl.dsp.global("ruboshapes:switch-next"), { description = "Windows: Switcher (type to search)" })
bind("ALT + SHIFT + Tab", hl.dsp.global("ruboshapes:switch-monitor"), { description = "Windows: Switcher, this monitor" })
bind("ALT + ALT_L",       hl.dsp.global("ruboshapes:switch-commit"), { release = true })

-- Brightness
bind("XF86MonBrightnessUp",      exec("light -A 5"), { description = "System: Brightness up" })
bind("XF86MonBrightnessDown",    exec("light -U 5"), { description = "System: Brightness down" })
bind(k("XF86MonBrightnessUp"),   exec("light -S 100"), { description = "System: Brightness max" })
bind(k("XF86MonBrightnessDown"), exec("light -S 0"), { description = "System: Brightness min" })

-- Screenshots
bind("Print",             exec("hyprshot -m output -m active --clipboard-only"), { description = "Screenshot: Monitor" })
bind("SHIFT + Print",     exec("hyprshot -m region --clipboard-only"), { description = "Screenshot: Region" })
bind("CONTROL + Print",   exec("hyprshot -m window -m active --clipboard-only"), { description = "Screenshot: Window" })
bind(k("Print"),          exec("hyprshot -m output --clipboard-only"), { description = "Screenshot: Monitor (no cursor focus)" })
bind("ALT + Print",       exec([[hyprshot -m region -r | tesseract -l "deu+eng" stdin stdout | wl-copy]]), { description = "Screenshot: OCR region → clipboard" })
bind("ALT + SHIFT + Print", exec("hyprshot -m region -r | zbarimg --raw - | wl-copy"), { description = "Screenshot: QR code region → clipboard" })
bind(k("ALT + SHIFT + Print"), exec("latexocr"), { description = "Screenshot: LaTeX OCR" })

-- Reload config + bar
bind(k("ALT + R"), exec("hyprctl reload && " .. CFG .. "/bar/ruboshapes/launch"), { description = "Session: Reload config + bar" })

-- Plugins
bind("SUPER + SHIFT + R", exec("hyprpm reload -n"), { description = "Session: Reload plugins" })
bind("SUPER + SHIFT + U", exec("hyprpm update -n"), { description = "Session: Update plugins" })

-- Gamemode
bind(k("SHIFT + G"), exec(CFG .. "/gamemode.sh"), { description = "System: Game mode" })

-- Wallpaper
bind(k("N"),         exec("waypaper --backend awww"), { description = "System: Wallpaper picker" })
bind(k("SHIFT + N"), exec("waypaper --backend awww --random"), { description = "System: Random wallpaper" })

-- Zoom
local zoomIncPM, zoomIncScroll = "0.3", "0.2"
bind(k("plus"),             exec(CFG .. "/zoom.sh --inc " .. zoomIncPM), { repeating = true, description = "Zoom: In" })
bind(k("minus"),            exec(CFG .. "/zoom.sh --dec " .. zoomIncPM), { repeating = true, description = "Zoom: Out" })
bind(k("CONTROL + 0"),      exec(CFG .. "/zoom.sh --reset"), { description = "Zoom: Reset" })
bind(k("SHIFT + mouse_down"), exec(CFG .. "/zoom.sh --inc " .. zoomIncScroll), { description = "Zoom: In (scroll)" })
bind(k("SHIFT + mouse_up"),   exec(CFG .. "/zoom.sh --dec " .. zoomIncScroll), { description = "Zoom: Out (scroll)" })

-- Invert colors (toggle screen shader)
bind(k("SHIFT + U"), function()
    local current = hl.get_config("decoration.screen_shader")
    local shader = CFG .. "/shaders/invert_colors.frag"
    if current == nil or current == "" or current == "[[EMPTY]]" then
        hl.config({ decoration = { screen_shader = shader } })
    else
        hl.config({ decoration = { screen_shader = "" } })
    end
end, { description = "System: Invert colours" })

-- Blue light filter
bind(k("SHIFT + B"), exec("pgrep hyprsunset >/dev/null && pkill hyprsunset || (hyprsunset -t 4000 & disown)"), { description = "System: Blue light filter" })

-- Lock screen
bind(k("L"), exec("swaylock --screenshots --clock --indicator-idle-visible --indicator-radius 100 --indicator-thickness 7 --ring-color 455a64 --key-hl-color be5046 --text-color ffc107 --line-color 00000000 --inside-color 00000088 --separator-color 00000000 --effect-scale 0.5 --effect-blur 7x3 --effect-scale 2 --effect-vignette 0.5:0.5"), { description = "Session: Lock screen" })

-- Notifications (Caelestia sidebar on the focused monitor) / do not disturb
bind(k("ALT + N"),         exec("caelestia shell drawers toggle sidebar"), { description = "System: Notifications" })
bind(k("ALT + SHIFT + N"), exec("qs -c caelestia ipc call notifs toggleDnd"), { description = "System: Do not disturb" })

-- Clipboard
bind(k("V"),       exec("copyq menu"), { description = "Clipboard: History menu" })
bind(k("SHIFT + V"), exec("copyq toggle"), { description = "Clipboard: History window" })
bind(k("ALT + V"), exec([[sleep .5 && ydotool type "$(wl-paste)"]]), { description = "Clipboard: Type clipboard" })
