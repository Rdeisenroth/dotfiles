-- Per-monitor workspaces, replacing the split-monitor-workspaces plugin.
-- Each monitor gets its own workspaces 1..10, mapped to global IDs by monitor ID:
--   monitor 0 -> 1..10, monitor 1 -> 11..20, monitor 2 -> 21..30, ...
-- Same scheme as the plugin (count = 10), so the eww bar math still works.
-- Unlike the PC, the laptop's monitors change, so rules are made per connected monitor.

local COUNT = 10
local done = {}

local function base(mon)
    return ((mon and mon.id) or 0) * COUNT
end

local function add_rules(mon)
    if mon == nil or done[mon.name] then return end
    done[mon.name] = true
    local b = base(mon)
    for i = 1, COUNT do
        hl.workspace_rule({
            workspace  = tostring(b + i),
            monitor    = mon.name,
            persistent = true,
            default    = (i == 1),
        })
    end
end

for _, mon in ipairs(hl.get_monitors()) do
    add_rules(mon)
end

hl.on("monitor.added", function(mon)
    add_rules(mon)
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

-- Globals so the eww bar can call them: hyprctl eval 'split_workspace(3)'
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
