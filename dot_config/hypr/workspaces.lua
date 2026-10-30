-- Per-monitor workspaces, replacing the split-monitor-workspaces plugin.
-- Each monitor gets its own workspaces 1..10, mapped to global IDs:
--   DP-1 -> 1..10, DP-2 -> 11..20, DP-3 (ASUS) -> 21..30
-- This matches what the plugin did (count = 10, ordered by monitor ID).

local COUNT = 10
local MONITOR_SLOT = { ["DP-1"] = 0, ["DP-2"] = 1, ["DP-3"] = 2 }

local function slot(mon)
    if mon == nil then return 0 end
    return MONITOR_SLOT[mon.name] or mon.id or 0
end

local function ws_id(i)
    return slot(hl.get_active_monitor()) * COUNT + i
end

-- Persistent workspaces bound to their monitors (enable_persistent_workspaces = 1).
for name, s in pairs(MONITOR_SLOT) do
    for i = 1, COUNT do
        hl.workspace_rule({
            workspace  = tostring(s * COUNT + i),
            monitor    = name,
            persistent = true,
            default    = (i == 1),
        })
    end
end

-- Global so the eww bar can call it: hyprctl eval 'split_workspace(3)'
function split_workspace(i)
    hl.dispatch(hl.dsp.focus({ workspace = ws_id(i) }))
end

function split_move_silent(i)
    hl.dispatch(hl.dsp.window.move({ workspace = ws_id(i), follow = false }))
end
