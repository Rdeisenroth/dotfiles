local CFG = os.getenv("HOME") .. "/.config/hypr"
local mod = "SUPER"

local function k(keys) return mod .. " + " .. keys end
local exec = hl.dsp.exec_cmd

-- Apps
hl.bind(k("Return"),      exec("ghostty"))
hl.bind(k("E"),           exec("dolphin"))
hl.bind(k("I"),           exec("firefox"))
hl.bind(k("SHIFT + I"),   exec("mullvad-browser"))
-- hl.bind(k("space"),    exec("~/.config/polybar/shapes/scripts/launcher.sh"))  -- old rofi launcher
hl.bind(k("space"),       exec("caelestia shell drawers toggle launcher"))
-- KDE Plasma's emoji picker (copies the chosen emoji)
hl.bind(k("period"),      exec("plasma-emojier"))

-- Window management
hl.bind(k("W"),           hl.dsp.window.close())
hl.bind(k("SHIFT + W"),   exec("hyprctl kill"))
hl.bind("SUPER + ALT + Q", hl.dsp.exit())
hl.bind(k("S"),           hl.dsp.window.float({ action = "enable" }))   -- was setfloating.sh true
hl.bind(k("T"),           hl.dsp.window.float({ action = "disable" }))  -- was setfloating.sh false
hl.bind(k("F"),           hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(k("M"),           hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(k("SHIFT + Y"),   hl.dsp.window.pseudo())
hl.bind(k("A"),           hl.dsp.layout("togglesplit"))
-- Rotate the focused window's split 90° clockwise (bspwm Super+R, but per split, not the whole tree)
hl.bind(k("R"),           hl.dsp.layout("rotatesplit 90"))

-- Monitor input switching (ASUS_USBC lives in monitor-mode.conf)
hl.bind(k("P"),           exec(CFG .. "/monitor-mode.sh pc"),     { locked = true })
hl.bind(k("SHIFT + P"),   exec(CFG .. "/monitor-mode.sh laptop"), { locked = true })

local dirs = { left = "left", right = "right", up = "up", down = "down" }
local short = { left = "l", right = "r", up = "u", down = "d" }
local resize = { left = { -20, 0 }, right = { 20, 0 }, up = { 0, -20 }, down = { 0, 20 } }

for key, dir in pairs(dirs) do
    hl.bind(k(key),                     hl.dsp.focus({ direction = dir }))
    hl.bind(k("CONTROL + " .. key),     hl.dsp.focus({ monitor = short[key] }))
    hl.bind(k("ALT + " .. key),         hl.dsp.window.resize({ x = resize[key][1], y = resize[key][2], relative = true }))
    hl.bind(k("SHIFT + " .. key),       hl.dsp.window.move({ direction = dir }))
    hl.bind(k("CONTROL + SHIFT + " .. key), hl.dsp.window.move({ monitor = short[key] }))
end

-- Mouse move/resize
hl.bind(k("mouse:272"), hl.dsp.window.drag(),   { mouse = true })
hl.bind(k("mouse:273"), hl.dsp.window.resize(), { mouse = true })

-- Scroll through existing workspaces
hl.bind(k("mouse_down"), hl.dsp.focus({ workspace = "e+1" }))
hl.bind(k("mouse_up"),   hl.dsp.focus({ workspace = "e-1" }))

-- Per-monitor workspaces (see workspaces.lua)
for i = 1, 10 do
    local key = tostring(i % 10)
    hl.bind(k(key),             function() split_workspace(i) end)
    hl.bind(k("SHIFT + " .. key), function() split_move_silent(i) end)
end

-- Audio
hl.bind("XF86AudioLowerVolume", exec("pactl set-sink-volume @DEFAULT_SINK@ -5%"))
hl.bind("XF86AudioRaiseVolume", exec("pactl set-sink-volume @DEFAULT_SINK@ +5%"))
hl.bind("XF86AudioMute",        exec("pactl set-sink-mute @DEFAULT_SINK@ toggle"))

-- Media
hl.bind("XF86AudioPlay", exec("playerctl play-pause"))
hl.bind("XF86AudioStop", exec("playerctl stop"))
hl.bind("XF86AudioNext", exec("playerctl next"))
hl.bind("XF86AudioPrev", exec("playerctl previous"))
hl.bind(k("XF86AudioPlay"),        exec("playerctl --player=spotify play-pause"))
hl.bind(k("XF86AudioStop"),        exec("playerctl --player=spotify stop"))
hl.bind(k("XF86AudioNext"),        exec("playerctl --player=spotify next"))
hl.bind(k("XF86AudioPrev"),        exec("playerctl --player=spotify previous"))
hl.bind(k("XF86AudioLowerVolume"), exec("playerctl --player=spotify volume 0.05-"))
hl.bind(k("XF86AudioRaiseVolume"), exec("playerctl --player=spotify volume 0.05+"))

-- Window switcher
-- ruboshapes switcher (bar/ruboshapes/components/Switcher.qml): hold Alt, Tab / Shift+Tab to cycle,
-- release Alt to focus. Old rofi version: window-switcher.sh
hl.bind("ALT + Tab",         hl.dsp.global("ruboshapes:switch-next"))
hl.bind("ALT + SHIFT + Tab", hl.dsp.global("ruboshapes:switch-prev"))
hl.bind("ALT + ALT_L",       hl.dsp.global("ruboshapes:switch-commit"), { release = true })

-- Brightness
hl.bind("XF86MonBrightnessUp",      exec("light -A 5"))
hl.bind("XF86MonBrightnessDown",    exec("light -U 5"))
hl.bind(k("XF86MonBrightnessUp"),   exec("light -S 100"))
hl.bind(k("XF86MonBrightnessDown"), exec("light -S 0"))

-- Screenshots
hl.bind("Print",             exec("hyprshot -m output -m active --clipboard-only"))
hl.bind("SHIFT + Print",     exec("hyprshot -m region --clipboard-only"))
hl.bind("CONTROL + Print",   exec("hyprshot -m window -m active --clipboard-only"))
hl.bind(k("Print"),          exec("hyprshot -m output --clipboard-only"))
hl.bind("ALT + Print",       exec([[hyprshot -m region -r | tesseract -l "deu+eng" stdin stdout | wl-copy]]))
hl.bind("ALT + SHIFT + Print", exec("hyprshot -m region -r | zbarimg --raw - | wl-copy"))
hl.bind(k("ALT + SHIFT + Print"), exec("latexocr"))

-- Reload config + bar
hl.bind(k("ALT + R"), exec("hyprctl reload && " .. CFG .. "/bar/saimoomedits/eww/bar/launch_bar"))

-- Plugins
hl.bind("SUPER + SHIFT + R", exec("hyprpm reload -n"))
hl.bind("SUPER + SHIFT + U", exec("hyprpm update -n"))

-- Gamemode
hl.bind(k("SHIFT + G"), exec(CFG .. "/gamemode.sh"))

-- Wallpaper
hl.bind(k("N"),         exec("waypaper --backend awww"))
hl.bind(k("SHIFT + N"), exec("waypaper --backend awww --random"))

-- Zoom
local zoomIncPM, zoomIncScroll = "0.3", "0.2"
hl.bind(k("plus"),             exec(CFG .. "/zoom.sh --inc " .. zoomIncPM), { repeating = true })
hl.bind(k("minus"),            exec(CFG .. "/zoom.sh --dec " .. zoomIncPM), { repeating = true })
hl.bind(k("CONTROL + 0"),      exec(CFG .. "/zoom.sh --reset"))
hl.bind(k("SHIFT + mouse_down"), exec(CFG .. "/zoom.sh --inc " .. zoomIncScroll))
hl.bind(k("SHIFT + mouse_up"),   exec(CFG .. "/zoom.sh --dec " .. zoomIncScroll))

-- Invert colors (toggle screen shader)
hl.bind(k("SHIFT + U"), function()
    local current = hl.get_config("decoration.screen_shader")
    local shader = CFG .. "/shaders/invert_colors.frag"
    if current == nil or current == "" or current == "[[EMPTY]]" then
        hl.config({ decoration = { screen_shader = shader } })
    else
        hl.config({ decoration = { screen_shader = "" } })
    end
end)

-- Blue light filter
hl.bind(k("SHIFT + B"), exec("pgrep hyprsunset >/dev/null && pkill hyprsunset || (hyprsunset -t 4000 & disown)"))

-- Lock screen
hl.bind(k("L"), exec("swaylock --screenshots --clock --indicator-idle-visible --indicator-radius 100 --indicator-thickness 7 --ring-color 455a64 --key-hl-color be5046 --text-color ffc107 --line-color 00000000 --inside-color 00000088 --separator-color 00000000 --effect-scale 0.5 --effect-blur 7x3 --effect-scale 2 --effect-vignette 0.5:0.5"))

-- Notifications (Caelestia sidebar on the focused monitor) / do not disturb
hl.bind(k("ALT + N"),         exec("caelestia shell drawers toggle sidebar"))
hl.bind(k("ALT + SHIFT + N"), exec("qs -c caelestia ipc call notifs toggleDnd"))

-- Clipboard
hl.bind(k("V"),       exec("copyq menu"))
hl.bind(k("SHIFT + V"), exec("copyq toggle"))
hl.bind(k("ALT + V"), exec([[sleep .5 && ydotool type "$(wl-paste)"]]))
