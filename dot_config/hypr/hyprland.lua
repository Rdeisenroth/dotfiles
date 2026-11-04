-- Hyprland config (Lua), shared by the PC and the laptop.
-- Machine differences live in machines/pc.lua and machines/laptop.lua; machine.lua
-- (rendered by chezmoi from the `laptop` data flag) says which one this is.
-- Docs: https://wiki.hypr.land/configuring/

-- Global, so the shared modules can read machine data (e.g. machine.monitor_slots).
machine = require("machines." .. require("machine"))

require("environment")
-- monitors.lua: static on the PC, written by hyprdynamicmonitors on the laptop.
local ok, err = pcall(require, "monitors")
if not ok then print("monitors.lua failed to load: " .. tostring(err)) end
require("autostart")
require("input")
require("look")
require("workspaces")
require("keybinds")
require("window-behaviour")

-- Machine-specific settings last, so they can override the shared ones.
machine.setup()
