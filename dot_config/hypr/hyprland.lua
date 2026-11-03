-- Hyprland config (Lua), laptop version.
-- Based on the PC config in chezmoi, plus the laptop-only parts.
-- Docs: https://wiki.hypr.land/configuring/

require("environment")

-- Fallback for any monitor that has no rule yet (e.g. before hyprdynamicmonitors runs).
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
-- monitors.lua is written by hyprdynamicmonitors (profiles in ~/.config/hyprdynamicmonitors).
local ok, err = pcall(require, "monitors")
if not ok then print("monitors.lua failed to load: " .. tostring(err)) end

require("autostart")
require("input")
require("look")
require("workspaces")
require("keybinds")
require("window-behaviour")
