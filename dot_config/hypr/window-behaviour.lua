local rule = hl.window_rule

-- KDE file portal dialog
rule({ match = { class = [[^(org\.freedesktop\.impl\.portal\.desktop\.kde)$]] },
       float = true, size = "70% 70%", center = true })

-- Rofi
rule({ match = { class = "(Rofi)" }, float = true, stay_focused = true })
rule({ match = { class = "^(Rofi)$" }, animation = "popin" })

-- KDE emoji picker: centered floating popup
rule({ match = { class = [[^(org\.kde\.plasma\.emojier|org\.kde\.plasma\.emoji\.app)$]] },
       float = true, center = true, size = { 680, 520 }, animation = "popin" })

-- Monitor placement
rule({ match = { class = "^(discord)$" }, monitor = "2" })
-- Spotify's class is "Spotify"; the old lowercase match never applied.
rule({ match = { class = "^([Ss]potify)$" }, monitor = "1", tile = true })
rule({ match = { title = "^(FopBot)$" }, monitor = "DP-3" })
rule({ match = { title = "^(Fo(p|P)Bot)$" }, tile = true })

-- JetBrains: no focus stealing from tooltips/autocomplete popups
rule({ match = { class = "^(jetbrains-.*)", title = "^(win.*)" }, no_initial_focus = true })

-- Zoom
rule({ match = { class = "^(Zoom Workplace)$", title = "^(.*menu window)$" }, float = true })
rule({ match = { class = "(^Zoom)$", title = "^Zoom - Licensed Account$" }, size = { 360, 690 } })
rule({ match = { title = "^(Zoom - Licensed Account)$" }, float = true })
rule({ match = { class = "(^Zoom)$" }, no_anim = true, no_dim = true })
rule({ match = { class = "(^Zoom.*)$" }, no_blur = true })
rule({ match = { class = "(^Zoom.*)$", title = "^as_toolbar$" },
       float = true, decorate = false, no_shadow = true, no_blur = true, pin = true, min_size = { 1, 1 } })
for _, cls in ipairs({ "^(Zoom Workplace)$", "^(zoom)$", "^(Zoom Workpkace)$" }) do
    rule({ match = { class = cls, title = "^(Zoom Workplace.*)$" }, min_size = { 1, 1 } })
end
for _, cls in ipairs({ "^(Zoom Workplace)$", "^(zoom)$" }) do
    rule({ match = { class = cls, title = "^(.*menu window)$" },          min_size = { 1, 1 }, move = { "cursor_x", "cursor_y" } })
    rule({ match = { class = cls, title = "^(meeting bottombar popup)$" }, min_size = { 1, 1 }, move = { "cursor_x", "cursor_y" } })
end
rule({ match = { class = "^(zoom)$", title = "^(Zoom Workplace)$" }, move = { "cursor_x", "cursor_y" } })
rule({ match = { class = "^(Zoom Workplace)$", title = "^(zoom)$" }, float = true })
rule({ match = { class = "^(Zoom Workplace)$", title = "^(Zoom Workplace)$" }, float = true, move = { "cursor_x", "cursor_y" } })

-- xwaylandvideobridge: invisible helper window
rule({ match = { class = "^(xwaylandvideobridge)$" },
       opacity = "0.0 override", no_anim = true, no_initial_focus = true, max_size = { 1, 1 }, no_blur = true })

rule({ match = { class = [[^(cemu.exe)$]] },     no_max_size = true })
rule({ match = { class = [[^(rexprint.exe)$]] }, no_max_size = true })

-- CopyQ: centered floating window
rule({ match = { class = [[^(com.github.hluk.copyq)$]] }, float = true, center = true, size = { 904, 526 } })

-- Nextcloud: don't steal focus
rule({ match = { class = [[^(com.nextcloud.desktopclient.nextcloud)$]] },
       no_initial_focus = true, suppress_event = "activate" })

-- Flameshot overlay
rule({ match = { class = "(flameshot)", title = "(flameshot)" },
       float = true, pin = true, move = { 0, 0 }, fullscreen_state = "3" })

-- Games: allow tearing
rule({ match = { class = "^([Ss]team_app_*)$" }, immediate = true })

-- Steam app 252950 (Rocket League): fullscreen, ignore its own fullscreen requests
rule({ match = { class = "^(steam_app_252950)$" }, fullscreen = true, suppress_event = "fullscreen" })

-- Trackmania
rule({ match = { title = "^(Trackmania)$" },
       fullscreen_state = "2", monitor = "2", no_follow_mouse = true, sync_fullscreen = false })

-- Layer rules
local layer = hl.layer_rule
layer({ match = { namespace = "gtk-layer-shell" }, blur = true })
layer({ match = { namespace = "rofi" }, blur = true })
layer({ match = { namespace = "swaync-control-center" },     blur = true, ignore_alpha = 0.5 })
layer({ match = { namespace = "swaync-notification-window" }, blur = true, ignore_alpha = 0.5 })
