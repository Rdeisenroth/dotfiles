local CFG = os.getenv("HOME") .. "/.config/hypr"
local mod = "SUPER"

local function k(keys) return mod .. " + " .. keys end
local exec = hl.dsp.exec_cmd

-- Apps
hl.bind(k("Return"),      exec("ghostty"), { description = "Apps: Terminal" })
hl.bind(k("E"),           exec("dolphin"), { description = "Apps: File manager" })
hl.bind(k("I"),           exec("firefox"), { description = "Apps: Firefox" })
hl.bind(k("SHIFT + I"),   exec("mullvad-browser"), { description = "Apps: Mullvad browser" })
-- hl.bind(k("space"),    exec("~/.config/polybar/shapes/scripts/launcher.sh"))  -- old rofi launcher
hl.bind(k("space"),       exec("caelestia shell drawers toggle launcher"), { description = "Apps: Launcher" })
-- KDE Plasma's emoji picker (copies the chosen emoji)
hl.bind(k("period"),      exec("plasma-emojier"), { description = "Apps: Emoji picker" })

-- Window management
hl.bind(k("W"),           hl.dsp.window.close(), { description = "Windows: Close" })
hl.bind(k("SHIFT + W"),   exec("hyprctl kill"), { description = "Windows: Kill (click a window)" })
hl.bind("SUPER + ALT + Q", hl.dsp.exit(), { description = "Session: Exit Hyprland" })
hl.bind(k("S"),           hl.dsp.window.float({ action = "enable" }), { description = "Windows: Float" }) -- was setfloating.sh true
hl.bind(k("T"),           hl.dsp.window.float({ action = "disable" }), { description = "Windows: Tile" }) -- was setfloating.sh false
hl.bind(k("F"),           hl.dsp.window.fullscreen({ mode = "fullscreen" }), { description = "Windows: Fullscreen" })
hl.bind(k("M"),           hl.dsp.window.fullscreen({ mode = "maximized" }), { description = "Windows: Maximize" })
hl.bind(k("SHIFT + Y"),   hl.dsp.window.pseudo(), { description = "Windows: Pseudotile" })
hl.bind(k("A"),           hl.dsp.layout("togglesplit"), { description = "Windows: Toggle split" })
-- Rotate the focused window's split 90° clockwise (bspwm Super+R, but per split, not the whole tree)
hl.bind(k("R"),           hl.dsp.layout("rotatesplit 90"), { description = "Windows: Rotate split 90°" })

-- Monitor input switching (ASUS_USBC lives in monitor-mode.conf)
hl.bind(k("P"),           exec(CFG .. "/monitor-mode.sh pc"),     { locked = true, description = "Monitors: ASUS input → PC" })
hl.bind(k("SHIFT + P"),   exec(CFG .. "/monitor-mode.sh laptop"), { locked = true, description = "Monitors: ASUS input → laptop" })

local dirs = { left = "left", right = "right", up = "up", down = "down" }
local short = { left = "l", right = "r", up = "u", down = "d" }
local resize = { left = { -20, 0 }, right = { 20, 0 }, up = { 0, -20 }, down = { 0, 20 } }

for key, dir in pairs(dirs) do
    hl.bind(k(key),                     hl.dsp.focus({ direction = dir }), { description = "Windows: Focus (arrows)" })
    hl.bind(k("CONTROL + " .. key),     hl.dsp.focus({ monitor = short[key] }), { description = "Monitors: Focus monitor (arrows)" })
    hl.bind(k("ALT + " .. key),         hl.dsp.window.resize({ x = resize[key][1], y = resize[key][2], relative = true }), { description = "Windows: Resize (arrows)" })
    hl.bind(k("SHIFT + " .. key),       hl.dsp.window.move({ direction = dir }), { description = "Windows: Move (arrows)" })
    hl.bind(k("CONTROL + SHIFT + " .. key), hl.dsp.window.move({ monitor = short[key] }), { description = "Monitors: Move window to monitor (arrows)" })
end

-- Mouse move/resize
hl.bind(k("mouse:272"), hl.dsp.window.drag(),   { mouse = true, description = "Windows: Drag with mouse" })
hl.bind(k("mouse:273"), hl.dsp.window.resize(), { mouse = true, description = "Windows: Resize with mouse" })

-- Scroll through existing workspaces
hl.bind(k("mouse_down"), hl.dsp.focus({ workspace = "e+1" }), { description = "Workspaces: Next (scroll)" })
hl.bind(k("mouse_up"),   hl.dsp.focus({ workspace = "e-1" }), { description = "Workspaces: Previous (scroll)" })

-- Per-monitor workspaces (see workspaces.lua)
for i = 1, 10 do
    local key = tostring(i % 10)
    hl.bind(k(key),             function() split_workspace(i) end, { description = "Workspaces: Go to 1–10" })
    hl.bind(k("SHIFT + " .. key), function() split_move_silent(i) end, { description = "Workspaces: Move window to 1–10" })
end

-- Audio
hl.bind("XF86AudioLowerVolume", exec("pactl set-sink-volume @DEFAULT_SINK@ -5%"), { description = "Media: Volume down" })
hl.bind("XF86AudioRaiseVolume", exec("pactl set-sink-volume @DEFAULT_SINK@ +5%"), { description = "Media: Volume up" })
hl.bind("XF86AudioMute",        exec("pactl set-sink-mute @DEFAULT_SINK@ toggle"), { description = "Media: Mute" })

-- Media
hl.bind("XF86AudioPlay", exec("playerctl play-pause"), { description = "Media: Play/pause" })
hl.bind("XF86AudioStop", exec("playerctl stop"), { description = "Media: Stop" })
hl.bind("XF86AudioNext", exec("playerctl next"), { description = "Media: Next track" })
hl.bind("XF86AudioPrev", exec("playerctl previous"), { description = "Media: Previous track" })
hl.bind(k("XF86AudioPlay"),        exec("playerctl --player=spotify play-pause"), { description = "Media: Spotify play/pause" })
hl.bind(k("XF86AudioStop"),        exec("playerctl --player=spotify stop"), { description = "Media: Spotify stop" })
hl.bind(k("XF86AudioNext"),        exec("playerctl --player=spotify next"), { description = "Media: Spotify next" })
hl.bind(k("XF86AudioPrev"),        exec("playerctl --player=spotify previous"), { description = "Media: Spotify previous" })
hl.bind(k("XF86AudioLowerVolume"), exec("playerctl --player=spotify volume 0.05-"), { description = "Media: Spotify volume down" })
hl.bind(k("XF86AudioRaiseVolume"), exec("playerctl --player=spotify volume 0.05+"), { description = "Media: Spotify volume up" })

-- Keybind cheat sheet (bar/ruboshapes/components/KeysOverlay.qml), end-4 style: binds on the Super key
-- itself are transparent (never swallow the key, all Super combos keep working). long_press fires only
-- when Super is held alone for input.repeat_delay; releasing Super always hides it.
hl.bind("SUPER_L", hl.dsp.global("ruboshapes:keys-show"), { ignore_mods = true, transparent = true, long_press = true })
hl.bind("SUPER_L", hl.dsp.global("ruboshapes:keys-hide"), { ignore_mods = true, transparent = true, release = true })

-- Window switcher
-- ruboshapes switcher (bar/ruboshapes/components/Switcher.qml): hold Alt, Tab to cycle (Left arrow
-- goes back), release Alt to focus; type to fuzzy-search (then Enter). Alt+Shift+Tab: current monitor only.
-- Old rofi version: window-switcher.sh
hl.bind("ALT + Tab",         hl.dsp.global("ruboshapes:switch-next"), { description = "Windows: Switcher (type to search)" })
hl.bind("ALT + SHIFT + Tab", hl.dsp.global("ruboshapes:switch-monitor"), { description = "Windows: Switcher, this monitor" })
hl.bind("ALT + ALT_L",       hl.dsp.global("ruboshapes:switch-commit"), { release = true })

-- Brightness
hl.bind("XF86MonBrightnessUp",      exec("light -A 5"), { description = "System: Brightness up" })
hl.bind("XF86MonBrightnessDown",    exec("light -U 5"), { description = "System: Brightness down" })
hl.bind(k("XF86MonBrightnessUp"),   exec("light -S 100"), { description = "System: Brightness max" })
hl.bind(k("XF86MonBrightnessDown"), exec("light -S 0"), { description = "System: Brightness min" })

-- Screenshots
hl.bind("Print",             exec("hyprshot -m output -m active --clipboard-only"), { description = "Screenshot: Monitor" })
hl.bind("SHIFT + Print",     exec("hyprshot -m region --clipboard-only"), { description = "Screenshot: Region" })
hl.bind("CONTROL + Print",   exec("hyprshot -m window -m active --clipboard-only"), { description = "Screenshot: Window" })
hl.bind(k("Print"),          exec("hyprshot -m output --clipboard-only"), { description = "Screenshot: Monitor (no cursor focus)" })
hl.bind("ALT + Print",       exec([[hyprshot -m region -r | tesseract -l "deu+eng" stdin stdout | wl-copy]]), { description = "Screenshot: OCR region → clipboard" })
hl.bind("ALT + SHIFT + Print", exec("hyprshot -m region -r | zbarimg --raw - | wl-copy"), { description = "Screenshot: QR code region → clipboard" })
hl.bind(k("ALT + SHIFT + Print"), exec("latexocr"), { description = "Screenshot: LaTeX OCR" })

-- Reload config + bar
hl.bind(k("ALT + R"), exec("hyprctl reload && " .. CFG .. "/bar/ruboshapes/launch"), { description = "Session: Reload config + bar" })

-- Plugins
hl.bind("SUPER + SHIFT + R", exec("hyprpm reload -n"), { description = "Session: Reload plugins" })
hl.bind("SUPER + SHIFT + U", exec("hyprpm update -n"), { description = "Session: Update plugins" })

-- Gamemode
hl.bind(k("SHIFT + G"), exec(CFG .. "/gamemode.sh"), { description = "System: Game mode" })

-- Wallpaper
hl.bind(k("N"),         exec("waypaper --backend awww"), { description = "System: Wallpaper picker" })
hl.bind(k("SHIFT + N"), exec("waypaper --backend awww --random"), { description = "System: Random wallpaper" })

-- Zoom
local zoomIncPM, zoomIncScroll = "0.3", "0.2"
hl.bind(k("plus"),             exec(CFG .. "/zoom.sh --inc " .. zoomIncPM), { repeating = true, description = "Zoom: In" })
hl.bind(k("minus"),            exec(CFG .. "/zoom.sh --dec " .. zoomIncPM), { repeating = true, description = "Zoom: Out" })
hl.bind(k("CONTROL + 0"),      exec(CFG .. "/zoom.sh --reset"), { description = "Zoom: Reset" })
hl.bind(k("SHIFT + mouse_down"), exec(CFG .. "/zoom.sh --inc " .. zoomIncScroll), { description = "Zoom: In (scroll)" })
hl.bind(k("SHIFT + mouse_up"),   exec(CFG .. "/zoom.sh --dec " .. zoomIncScroll), { description = "Zoom: Out (scroll)" })

-- Invert colors (toggle screen shader)
hl.bind(k("SHIFT + U"), function()
    local current = hl.get_config("decoration.screen_shader")
    local shader = CFG .. "/shaders/invert_colors.frag"
    if current == nil or current == "" or current == "[[EMPTY]]" then
        hl.config({ decoration = { screen_shader = shader } })
    else
        hl.config({ decoration = { screen_shader = "" } })
    end
end, { description = "System: Invert colours" })

-- Blue light filter
hl.bind(k("SHIFT + B"), exec("pgrep hyprsunset >/dev/null && pkill hyprsunset || (hyprsunset -t 4000 & disown)"), { description = "System: Blue light filter" })

-- Lock screen
hl.bind(k("L"), exec("swaylock --screenshots --clock --indicator-idle-visible --indicator-radius 100 --indicator-thickness 7 --ring-color 455a64 --key-hl-color be5046 --text-color ffc107 --line-color 00000000 --inside-color 00000088 --separator-color 00000000 --effect-scale 0.5 --effect-blur 7x3 --effect-scale 2 --effect-vignette 0.5:0.5"), { description = "Session: Lock screen" })

-- Notifications (Caelestia sidebar on the focused monitor) / do not disturb
hl.bind(k("ALT + N"),         exec("caelestia shell drawers toggle sidebar"), { description = "System: Notifications" })
hl.bind(k("ALT + SHIFT + N"), exec("qs -c caelestia ipc call notifs toggleDnd"), { description = "System: Do not disturb" })

-- Clipboard
hl.bind(k("V"),       exec("copyq menu"), { description = "Clipboard: History menu" })
hl.bind(k("SHIFT + V"), exec("copyq toggle"), { description = "Clipboard: History window" })
hl.bind(k("ALT + V"), exec([[sleep .5 && ydotool type "$(wl-paste)"]]), { description = "Clipboard: Type clipboard" })
