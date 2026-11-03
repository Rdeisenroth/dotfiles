#!/usr/bin/env bash
# User copy of the Caelestia shell with one tweak for the ruboshapes bar:
#   the drawers window respects other layers' exclusive zones, so the dashboard opens *below*
#   the ruboshapes bar and its blob melts into the bar's bottom edge (the "teardrop" flares).
# Quickshell prefers ~/.config/quickshell/caelestia over /etc/xdg/quickshell/caelestia.
# Re-run after every caelestia-shell update:  ~/.config/hypr/bar/ruboshapes/caelestia/apply-patch.sh
set -euo pipefail
SRC=/etc/xdg/quickshell/caelestia
DST="$HOME/.config/quickshell/caelestia"
rm -rf "$DST"; mkdir -p "$(dirname "$DST")"; cp -r "$SRC" "$DST"
f="$DST/modules/drawers/ContentWindow.qml"
grep -q 'WlrLayershell.exclusionMode: ExclusionMode.Ignore' "$f"
sed -i 's/WlrLayershell.exclusionMode: ExclusionMode.Ignore/WlrLayershell.exclusionMode: ExclusionMode.Normal  \/\/ ruboshapes: open below the eww bar/' "$f"
echo "patched $f"

# 2) IPC: toggle a drawer on a named monitor (the bar is clicked on a monitor that may not have focus)
#    qs -c caelestia ipc call drawers toggleOn dashboard DP-1
f="$DST/modules/Shortcuts.qml"
python3 - "$f" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
anchor = "        function toggle(drawer: string): void {"
assert s.count(anchor) == 1, "Shortcuts.qml changed upstream; update apply-patch.sh"
fn = """        // ruboshapes: toggle a drawer on a specific monitor (by output name)
        function toggleOn(drawer: string, monitor: string): void {
            const scr = Quickshell.screens.find(s => s.name === monitor);
            const screenState = scr ? ShellState.forScreen(scr) : ShellState.forActive();
            if (screenState && typeof screenState[drawer] === "boolean")
                screenState[drawer] = !screenState[drawer];
        }

"""
open(p, "w").write(s.replace(anchor, fn + anchor))
PY
echo "patched $f"
# 3) no focus grab for the dashboard: across monitors Hyprland cleared the grab right after opening,
#    which closed the dashboard again. It now stays open until toggled from the bar (island / clock).
python3 - "$DST" <<'PY'
import sys, pathlib
d = pathlib.Path(sys.argv[1])
cw = d / "modules/drawers/ContentWindow.qml"; s = cw.read_text()
a = "            if (!conf.dashboard.showOnHover && s.dashboard && conf.dashboard.enabled)\n                return true;\n"
assert s.count(a) == 1, "ContentWindow.qml focus grab changed upstream"
cw.write_text(s.replace(a, "            // ruboshapes: no focus grab for the dashboard (toggled from the ruboshapes bar instead)\n", 1))
PY
echo "patched dashboard focus grab"

# 3b) with dashboard.showOnHover off, the dashboard is toggled from the bar only: pointer movement
#     (entering/leaving it) must not close it.
python3 - "$DST" <<'PY'
import sys, pathlib
f = pathlib.Path(sys.argv[1]) / "modules/drawers/Interactions.qml"; s = f.read_text()
a = """        if (!dashboardShortcutActive) {
            screenState.dashboard = showDashboard;
        } else if (showDashboard) {
            // If hovering over dashboard area while in shortcut mode, transition to hover control
            dashboardShortcutActive = false;
        }
"""
b = """            if (!dashboardShortcutActive)
                screenState.dashboard = false;
"""
assert s.count(a) == 1 and s.count(b) == 1, "Interactions.qml changed upstream"
s = s.replace(a, "        if (Config.dashboard.showOnHover) {  // ruboshapes: hover control only when hover-open is on\n"
                 + "".join("    " + l + "\n" for l in a.rstrip("\n").split("\n")) + "        }\n", 1)
s = s.replace(b, "            if (!dashboardShortcutActive && Config.dashboard.showOnHover)  // ruboshapes\n"
                 "                screenState.dashboard = false;\n", 1)
f.write_text(s)
PY
echo "patched dashboard hover control"

# 3c) session menu (opened from the bar clock) sits in the top-right corner, right under the clock,
#     instead of the vertical middle of the right edge.
python3 - "$DST" <<'PY'
import sys, pathlib
f = pathlib.Path(sys.argv[1]) / "modules/drawers/Panels.qml"; s = f.read_text()
a = """        id: sessionWrapper

        anchors.verticalCenter: parent.verticalCenter
"""
assert s.count(a) == 1, "Panels.qml sessionWrapper changed upstream"
f.write_text(s.replace(a, """        id: sessionWrapper

        anchors.top: parent.top  // ruboshapes: under the bar clock
""", 1))
PY
echo "patched session position"

# 3d) no full-screen dimming behind the session menu: keeps it a blurred glass panel like the dashboard
python3 - "$DST" <<'PY'
import sys, pathlib
f = pathlib.Path(sys.argv[1]) / "modules/drawers/ContentWindow.qml"; s = f.read_text()
a = "opacity: (root.screenState.session && Config.session.enabled) || panels.popouts.detachedMode !== \"\" ? 0.5 : 0"
assert s.count(a) == 1, "ContentWindow.qml scrim changed upstream"
f.write_text(s.replace(a, "opacity: panels.popouts.detachedMode !== \"\" ? 0.5 : 0  // ruboshapes: no dim for the session menu", 1))
PY
echo "patched session scrim"

# 3e) launcher search: rank by text match *plus* how often an app was launched (upstream sorts by the
#     match score only, so "code" always put "Code - OSS" above a far more used "Visual Studio Code")
python3 - "$DST" <<'PY'
import sys, pathlib
f = pathlib.Path(sys.argv[1]) / "modules/launcher/services/Apps.qml"; s = f.read_text()
a = """            if (!search.startsWith(`${prefix}t `))
                return query(search).map(e => e.entry);"""
assert s.count(a) == 1, "Apps.qml search changed upstream"
s = s.replace(a, """            if (!search.startsWith(`${prefix}t `))
                return ranked(search).map(e => e.entry);  // ruboshapes: frequency-aware""", 1)
b = """    function selector(item: var): string {"""
assert s.count(b) == 1
s = s.replace(b, """    // ruboshapes: text-match score + log-scaled launch count (fzf path; fuzzy mode keeps upstream order)
    function ranked(search: string): var {
        const s = transformSearch(search.trim().replace(/\\s+/g, " "));
        if (!s || useFuzzy)
            return query(search);
        return fzf.find(s).map(r => ({ r, v: r.score + 14 * Math.log2(1 + (r.item.frequency ?? 0)) }))
            .sort((a, b) => b.v - a.v || selector(a.r.item).length - selector(b.r.item).length)
            .map(x => x.r.item);
    }

""" + b, 1)
f.write_text(s)
PY
echo "patched launcher ranking"

# 3f) launcher in the middle of the screen (upstream: stuck to the bottom edge). It slides up from the
#     bottom into the center; its input/blur region follows the panel instead of the bottom strip.
python3 - "$DST" <<'PY'
import sys, pathlib
d = pathlib.Path(sys.argv[1])
p = d / "modules/drawers/Panels.qml"; s = p.read_text()
a = """        panels: root

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }

    Dashboard.Wrapper {"""
assert s.count(a) == 1, "Panels.qml launcher changed upstream"
p.write_text(s.replace(a, a.replace("anchors.bottom: parent.bottom", "anchors.verticalCenter: parent.verticalCenter  // ruboshapes: centered"), 1))
w = d / "modules/launcher/Wrapper.qml"; s = w.read_text()
a = "    anchors.bottomMargin: (-implicitHeight - 5) * offsetScale\n"
assert s.count(a) == 1, "launcher/Wrapper.qml changed upstream"
w.write_text(s.replace(a, "    anchors.verticalCenterOffset: ((parent?.height ?? 0) + implicitHeight + 10) / 2 * offsetScale  // ruboshapes\n", 1))
r = d / "modules/drawers/Regions.qml"; s = r.read_text()
a = """        panel: root.panels.launcher
        y: root.win.height - height
        height: panel.height * (1 - root.panels.launcher.offsetScale) + root.borderThickness
"""
assert s.count(a) == 1, "Regions.qml launcher changed upstream"
r.write_text(s.replace(a, "        panel: root.panels.launcher  // ruboshapes: centered, region follows the panel\n", 1))
# Hyprland-style window border around the launcher (look.lua: 2px, #53e2ae -> #6603fc at 45°)
s = w.read_text()
a = "    Loader {\n        id: content\n"
assert s.count(a) == 1, "launcher/Wrapper.qml content changed upstream"
s = s.replace("import QtQuick\n", "import QtQuick\nimport QtQuick.Shapes\n", 1)
s = s.replace(a, """    Shape {  // ruboshapes: Hyprland window border look
        anchors.fill: parent
        z: 1
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillRule: ShapePath.OddEvenFill
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: root.width; y2: root.height
                GradientStop { position: 0; color: "#53e2ae" }
                GradientStop { position: 1; color: "#ee6603fc" }
            }
            PathRectangle { width: root.width; height: root.height; radius: Tokens.rounding.extraLarge }
            PathRectangle { x: 2; y: 2; width: root.width - 4; height: root.height - 4; radius: Tokens.rounding.extraLarge - 2 }
        }
    }

""" + a, 1)
w.write_text(s)
# plain slide without springy overshoot (the squash/stretch is off globally: appearance.deformScale = 0)
s = w.read_text()
a = "    Behavior on offsetScale {\n        Anim {}\n    }\n"
assert s.count(a) == 1, "launcher/Wrapper.qml animation changed upstream"
w.write_text(s.replace(a, "    Behavior on offsetScale {  // ruboshapes: plain ease, no overshoot\n"
                          "        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }\n    }\n", 1))
PY
echo "patched launcher position"

python3 - "$DST" <<'PY'
import sys, pathlib
d = pathlib.Path(sys.argv[1])
# 4) no audio capture from the dashboard: beat tracking (bongo cat) and the cover visualiser open a
#    PipeWire capture stream when shown, which makes playback stutter. The cat plays at a fixed speed.
m = d / "modules/dashboard/dash/Media.qml"; s = m.read_text()
a = "    ServiceRef {\n        service: Audio.beatTracker\n    }\n"
assert s.count(a) == 1, "dash/Media.qml changed upstream"
s = s.replace(a, "    // ruboshapes: beat tracker disabled (audio capture made playback stutter)\n", 1)
b = "speed: Audio.beatTracker.bpm / Config.general.mediaGifSpeedAdjustment"
assert s.count(b) == 1
m.write_text(s.replace(b, "speed: 1", 1))
v = d / "modules/dashboard/media/CoverVisualiser.qml"; s = v.read_text()
a = "    ServiceRef {\n        service: Audio.cava\n    }\n"
assert s.count(a) == 1, "CoverVisualiser.qml changed upstream"
v.write_text(s.replace(a, "    // ruboshapes: cava disabled (audio capture made playback stutter)\n", 1))
PY
echo "patched grab/toggle race + audio capture"

if pgrep -f "qs -c caelestia" >/dev/null; then
  caelestia shell -k >/dev/null 2>&1 || true; sleep 1; pkill -f "qs -c caelestia" || true; sleep 0.5   # only Caelestia, not the bar
  setsid caelestia shell -d >/dev/null 2>&1 < /dev/null &
fi
