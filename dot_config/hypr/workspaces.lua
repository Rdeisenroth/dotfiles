-- Per-monitor workspaces, replacing the split-monitor-workspaces plugin.
-- Each monitor gets its own workspaces 1..10, mapped to global IDs by a monitor "slot":
--   slot 0 -> 1..10, slot 1 -> 11..20, slot 2 -> 21..30, ...
-- machine.monitor_slots pins outputs to slots (PC: DP-1 -> 0, DP-2 -> 1, DP-3 -> 2).
-- Any other monitor uses its Hyprland monitor ID as slot (laptop: docks change all the time).
-- The bar (ruboshapes Workspaces.qml) uses the same slot * 10 math.

local COUNT = 10
local SLOTS = (machine and machine.monitor_slots) or {}
local done = {}

local function slot(mon)
    if mon == nil then return 0 end
    return SLOTS[mon.name] or mon.id or 0
end

local function base(mon)
    return slot(mon) * COUNT
end

local function add_rules(name, s)
    if done[name] then return end
    done[name] = true
    for i = 1, COUNT do
        hl.workspace_rule({
            workspace  = tostring(s * COUNT + i),
            monitor    = name,
            persistent = true,
            default    = (i == 1),
        })
    end
end

-- Pinned outputs get their rules up front, the rest when they are connected.
for name, s in pairs(SLOTS) do
    add_rules(name, s)
end
for _, mon in ipairs(hl.get_monitors()) do
    add_rules(mon.name, slot(mon))
end

hl.on("monitor.added", function(mon)
    add_rules(mon.name, slot(mon))
    -- A new monitor gets some free workspace first; move it onto its own range.
    local ws = mon.active_workspace
    local b = base(mon)
    if ws == nil or ws.id <= b or ws.id > b + COUNT then
        local prev = hl.get_active_monitor()
        hl.dispatch(hl.dsp.focus({ monitor = mon.name }))
        hl.dispatch(hl.dsp.focus({ workspace = b + 1 }))
        if prev ~= nil and prev.name ~= mon.name then
            hl.dispatch(hl.dsp.focus({ monitor = prev.name }))
        end
    end
end)

local function ws_id(i)
    return base(hl.get_active_monitor()) + i
end

-- Globals so the bar can call them: hyprctl eval 'split_workspace(3)'
function split_workspace(i)
    hl.dispatch(hl.dsp.focus({ workspace = ws_id(i) }))
end

function split_move_silent(i)
    hl.dispatch(hl.dsp.window.move({ workspace = ws_id(i), follow = false }))
end

-- step = 1 (next) or -1 (prev), wraps around within the monitor's 1..10.
function split_cycle(step)
    local mon = hl.get_active_monitor()
    local ws = hl.get_active_workspace()
    local b = base(mon)
    local cur = ws and (ws.id - b) or 1
    if cur < 1 or cur > COUNT then cur = 1 end
    local nxt = (cur - 1 + step) % COUNT + 1
    hl.dispatch(hl.dsp.focus({ workspace = b + nxt }))
end
