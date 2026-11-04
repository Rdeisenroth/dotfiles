-- Workspace overview (hyprpm plugin, loaded by `hyprpm reload` in autostart.lua):
--   Super+Shift+O  hyprexpo: grid of this monitor's 10 workspaces (5x2), click or drag to move
--   touchpad: 3 fingers up / down opens / closes it
-- (Tried and removed: Hyprspace, covered by the Alt+Tab switcher's workspace view; hyprglass, invisible
--  behind the mostly opaque dark windows and the solid bar arrows.)
-- Plugin options only exist once the plugin is loaded. At login the config is parsed before
-- hyprpm loads them, so the settings are applied only when the plugin is there, and autostart.lua
-- (and Super+Shift+R) run `hyprctl reload` right after `hyprpm reload`.

-- same gradient as the window borders (main monitor's colour scheme, see look.lua)
local ok, scheme = pcall(dofile, os.getenv("HOME") .. "/.local/state/ruboshapes/hypr-scheme.lua")
if not ok or type(scheme) ~= "table" then scheme = { border1 = "rgba(53e2aeff)", border2 = "rgba(6603fcee)" } end
local gradient = scheme.border1 .. " " .. scheme.border2 .. " 45deg"

local function has(ns) return hl.plugin ~= nil and hl.plugin[ns] ~= nil end

if has("hyprexpo") then
    hl.config({ plugin = { hyprexpo = {
        columns          = 5,
        rows             = 2,              -- ten fixed tiles = one monitor's workspaces
        skip_empty       = 0,
        workspace_method = "center current",   -- stays inside the monitor's own range (11..20, ...)
        gaps_in          = 12,
        gaps_out         = 24,
        bg_col           = "rgba(0d0f17ee)",
        tile_rounding    = 10,
        border_width     = 2,
        border_color         = "rgba(ffffff18)",
        border_color_current = gradient,
        border_color_hover   = "rgba(ffffff66)",
        border_color_focus   = scheme.border1,
        label_enable     = 1,
        label_text_mode  = "index",        -- 1..10 like the bar, not the global IDs
        label_position   = "top-left",
        label_offset_x   = 14,
        label_offset_y   = 10,
        label_color_current = scheme.border1:gsub("rgba%((%x%x%x%x%x%x)%x*%)", "rgb(%1)"),
    } } })

    -- Touchpad: 3 fingers up opens the grid (follows the fingers), 3 fingers down closes it
    -- without switching. 3 fingers sideways stays the workspace swipe (machines/*.lua).
    hl.plugin.hyprexpo.gesture({ fingers = 3, direction = "up",   action = "expo" })
    hl.plugin.hyprexpo.gesture({ fingers = 3, direction = "down", action = "cancel" })
end

hl.bind("SUPER + SHIFT + O", function()
    if has("hyprexpo") then hl.plugin.hyprexpo.expo("toggle") end
end, { description = "Windows: Workspace grid (hyprexpo)" })
