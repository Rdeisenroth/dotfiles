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

# 3g) launcher: ruboshapes bar colour schemes as actions. ">" shows one "Bar colours" entry, ">bar ..."
#     lists every scheme (+ dark/light, next wallpaper colour, picker) for the focused monitor.
python3 - "$DST" <<'PY'
import sys, pathlib
d = pathlib.Path(sys.argv[1])
f = d / "modules/launcher/services/Actions.qml"; s = f.read_text()
a = "            return GlobalConfig.launcher.actions.values.filter(a => a.enabled && (enableDangerous || !a.dangerous));"
assert s.count(a) == 1, "launcher Actions.qml changed upstream"
s = s.replace(a, a.replace(";", ".concat(root.barActions);  // ruboshapes"), 1)
b = "    list: variants.instances\n"
assert s.count(b) == 1
s = s.replace(b, b + """
    // ruboshapes: bar colour schemes on the focused monitor (bar/ruboshapes/scripts/scheme.sh)
    readonly property string barScript: Quickshell.env("HOME") + "/.config/hypr/bar/ruboshapes/scripts/scheme.sh"
    readonly property var barActions: {
        const act = (name, description, icon, command) => ({ name, description, icon, command, enabled: true, dangerous: false });
        const out = [
            act("Bar colours", "Colour scheme of the bar on this monitor", "palette", ["autocomplete", "bar"]),
            act("Bar: Open picker", "Show the colour picker under the Arch logo", "palette", [barScript, "picker"]),
            act("Bar: Wallpaper", "Follow this monitor's wallpaper", "wallpaper", [barScript, "wallpaper"]),
            act("Bar: Next wallpaper colour", "Cycle through the wallpaper's colour options", "shuffle", [barScript, "cycle"]),
            act("Bar: Dark", "Dark mode everywhere (all bars, apps, Caelestia)", "dark_mode", [barScript, "dark"]),
            act("Bar: Light", "Light mode everywhere (all bars, apps, Caelestia)", "light_mode", [barScript, "light"]),
            act("Bar: Ruboshapes", "The original teal", "format_color_fill", [barScript, "ruboshapes"])
        ];
        for (const id of ["red", "orange", "amber", "yellow", "lime", "green", "emerald", "teal", "cyan", "sky", "blue", "indigo",
                          "violet", "purple", "fuchsia", "pink", "rose", "slate", "gray", "stone"])
            out.push(act("Bar: " + id.charAt(0).toUpperCase() + id.slice(1), "Bar colour scheme on this monitor", "format_color_fill", [barScript, id]));
        return out;
    }
""", 1)
f.write_text(s)
f = d / "modules/launcher/AppList.qml"; s = f.read_text()
a = """        case "actions":
            return Actions.query(text);"""
assert s.count(a) == 1, "launcher AppList.qml changed upstream"
s = s.replace(a, """        case "actions": {   // ruboshapes: "Bar: ..." entries only after typing ">bar"
            const q = text.slice(GlobalConfig.launcher.actionPrefix.length).toLowerCase();
            return Actions.query(text).filter(a => !a.name.startsWith("Bar: ") || q.startsWith("bar"));
        }""", 1)
f.write_text(s)
PY
echo "patched launcher bar-colour actions"

# 3h) brightness (OSD + keys) uses the bar's DDC map: upstream parses `ddcutil detect`, which throws
#     when a display has no "DRM connector" line (daisy-chained Dells with identical EDIDs) and then
#     treats every monitor as a laptop backlight (brightness 0, nothing works). The bar's helper pins
#     outputs by serial, writes coalesced, and shares its value cache with the bar's slider.
python3 - "$DST" <<'PY'
import sys, pathlib
d = pathlib.Path(sys.argv[1])
f = d / "services/Brightness.qml"; s = f.read_text()
i = s.index('        command: ["ddcutil", "detect", "--brief"]')
j = s.index("        }\n", s.index("onStreamFinished: root.ddcMonitors", i)) + len("        }\n")
s = s[:i] + """        command: ["python3", root.barHelper, "map"]   // ruboshapes: {"DP-1": "3", ...}
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.ddcMonitors = Object.entries(JSON.parse(text)).map(([connector, busNum]) => ({ connector, busNum }));
                } catch (e) {}
            }
        }
""" + s[j:]
a = "    property bool appleDisplayPresent: false\n"
assert s.count(a) == 1, "services/Brightness.qml changed upstream"
s = s.replace(a, a + """
    // ruboshapes: DDC through the bar's helper; follow changes made from the bar's slider
    readonly property string barHelper: Quickshell.env("HOME") + "/.config/hypr/bar/ruboshapes/scripts/brightness.py"
    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ruboshapes-bright.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let val;
            try { val = JSON.parse(text()).val ?? {}; } catch (e) { return; }
            for (const m of root.monitors)
                if (m.isDdc && val[m.modelData.name] !== undefined && isNaN(m.queuedBrightness) && !m.timer.running)
                    m.brightness = val[m.modelData.name] / 100;
        }
    }
""", 1)
a = '                Quickshell.execDetached(["ddcutil", "-b", busNum, "setvcp", "10", rounded]);'
assert s.count(a) == 1, "services/Brightness.qml (setvcp) changed upstream"
s = s.replace(a, '                Quickshell.execDetached(["python3", root.barHelper, "set", modelData.name, String(rounded)]);   // ruboshapes', 1)
f.write_text(s)
PY
echo "patched brightness (bar DDC map)"

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

python3 - "$DST" <<'PY'
import sys, pathlib
d = pathlib.Path(sys.argv[1])
# 5) lock screen notifications like GrapheneOS: app name, time and count stay visible, the content
#    doesn't. Every line reads "Contents hidden", the notification image (in chat apps usually the
#    sender's avatar) gives way to the app icon, and the fallback icon no longer depends on the summary.
g = d / "modules/lock/NotifGroup.qml"; s = g.read_text()
def sub(a, b):
    global s
    assert s.count(a) == 1, "lock/NotifGroup.qml changed upstream: " + a[:60]
    s = s.replace(a, b, 1)
sub("    readonly property string image: props.img\n",
    "    readonly property string image: \"\"   // ruboshapes: no notification images (sender avatars) on the lock screen\n")
sub("text: Icons.getNotifIcon(root.notifs[0]?.summary, root.urgency)",
    "text: Icons.getNotifIcon(\"\", root.urgency)   // ruboshapes: not derived from the content")
a = s[s.index("        text: {\n            const summary = modelData.summary"):]
a = a[:a.index("        }\n") + len("        }\n")]
sub(a, "        text: qsTr(\"Contents hidden\")   // ruboshapes: no notification content on the lock screen\n")
g.write_text(s)
PY
echo "patched lock screen notification privacy"

python3 - "$DST" <<'PY'
import sys, pathlib, re
d = pathlib.Path(sys.argv[1])
# 6) German for the lock screen, dashboard and notification centre incl. its utilities (+ the shared texts they show: weather
#    conditions, notification ages, uptime). Caelestia has gettext support but ships no catalogues yet (it
#    would pick de_DE by itself once one exists); until then the strings are translated in place. Only text
#    inside Tr.tr / Tr.trCtx / Tr.trN / Tr.trCtxN / qsTr calls is touched, and Tr passes unknown text through. Terms that
#    are the same in German (CPU, GPU, Download, Upload, Wind, Dashboard) and the caelestiafetch labels stay.
#    Every English original must still exist, so upstream changes stop this loudly.
de = {
    # lock screen
    "FP ERROR: %1": "FINGERABDRUCK-FEHLER: %1",
    "FACE ERROR: %1": "GESICHTSERKENNUNG-FEHLER: %1",
    "PW ERROR: %1": "PASSWORT-FEHLER: %1",
    "Enter your password": "Passwort eingeben",
    "Scanning face...": "Gesicht wird gescannt …",
    "Max tries reached": "Maximale Versuche erreicht",
    "Incorrect password. Please try again.": "Falsches Passwort. Bitte erneut versuchen.",
    "Incorrect password. Please try again or use fingerprint.": "Falsches Passwort. Bitte erneut versuchen oder Fingerabdruck verwenden.",
    "Incorrect password. Please try again or use face.": "Falsches Passwort. Bitte erneut versuchen oder Gesichtserkennung verwenden.",
    "Fingerprint not recognised (%1/%2). Please try again.": "Fingerabdruck nicht erkannt (%1/%2). Bitte erneut versuchen.",
    "Fingerprint not recognised (%1/%2). Please try again or use password.": "Fingerabdruck nicht erkannt (%1/%2). Bitte erneut versuchen oder Passwort verwenden.",
    "Face not recognised (%1/%2). Please try again.": "Gesicht nicht erkannt (%1/%2). Bitte erneut versuchen.",
    "Face not recognised (%1/%2). Please try again or use password.": "Gesicht nicht erkannt (%1/%2). Bitte erneut versuchen oder Passwort verwenden.",
    "Maximum password attempts reached.": "Maximale Anzahl an Passwortversuchen erreicht.",
    "Maximum password attempts reached. Please use fingerprint.": "Maximale Anzahl an Passwortversuchen erreicht. Bitte Fingerabdruck verwenden.",
    "Maximum password attempts reached. Please use face.": "Maximale Anzahl an Passwortversuchen erreicht. Bitte Gesichtserkennung verwenden.",
    "Maximum fingerprint attempts reached. Please use password.": "Maximale Anzahl an Fingerabdruckversuchen erreicht. Bitte Passwort verwenden.",
    "Maximum face attempts reached. Please use password.": "Maximale Anzahl an Gesichtserkennungsversuchen erreicht. Bitte Passwort verwenden.",
    "Maximum attempts for all authentication methods reached.": "Maximale Anzahl an Versuchen für alle Anmeldemethoden erreicht.",
    "Caps lock is ON.": "Feststelltaste ist AN.",
    "Num lock is ON.": "Num-Lock ist AN.",
    "Caps lock and Num lock are ON.": "Feststelltaste und Num-Lock sind AN.",
    "Keyboard layout: %1": "Tastaturlayout: %1",
    "Caps lock is ON. Keyboard layout: %1": "Feststelltaste ist AN. Tastaturlayout: %1",
    "Num lock is ON. Keyboard layout: %1": "Num-Lock ist AN. Tastaturlayout: %1",
    r"Caps lock and Num lock are ON.\nKeyboard layout: %1": r"Feststelltaste und Num-Lock sind AN.\nTastaturlayout: %1",
    "Try playing some music!": "Spiel doch etwas Musik ab!",
    "Unknown track": "Unbekannter Titel",
    "Feels like %1": "Gefühlt %1",
    "High %1 • Low %2": "Max. %1 • Min. %2",
    "Hourly forecast": "Stündliche Vorhersage",
    "Contents hidden": "Inhalt ausgeblendet",
    # notifications (lock screen + notification centre)
    "Notifications": "Benachrichtigungen",
    "No notifications": "Keine Benachrichtigungen",
    "Unlock for notifications": "Entsperren, um Benachrichtigungen zu sehen",
    "All up to date!": "Alles erledigt!",
    "No body here! :/": "Kein Inhalt :/",
    "now": "jetzt",
    "%1m": "%1 Min.",          # notification age, battery time remaining
    "%1h": "%1 Std.",
    "%1d": "%1 T.",
    # dashboard
    "Media": "Medien",
    "Performance": "Leistung",
    "Weather": "Wetter",
    "Loading...": "Wird geladen …",
    "Nothing playing": "Keine Wiedergabe",
    "No players": "Keine Player",
    "No media": "Keine Medien",
    "Play something for it to show up here!": "Spiel etwas ab, damit es hier erscheint!",
    "Unknown title": "Unbekannter Titel",
    "Unknown artist": "Unbekannter Interpret",
    "Unknown album": "Unbekanntes Album",
    "Lyrics": "Songtext",
    "Loading lyrics...": "Songtext wird geladen …",
    "No lyrics found": "Kein Songtext gefunden",
    "Offset: %1 ms": "Versatz: %1 ms",
    "Selected candidate: %1 | %2 | %3": "Gewählter Kandidat: %1 | %2 | %3",
    "up %1": "seit %1",
    "Battery": "Akku",
    "Charging": "Lädt",
    "Full": "Voll",
    "Memory": "Arbeitsspeicher",
    "Storage": "Speicher",
    "Network": "Netzwerk",
    "Usage": "Auslastung",
    "Used": "Belegt",
    "Total": "Gesamt",
    "None": "Keine",
    "Collecting data...": "Daten werden gesammelt …",
    "Detecting GPU...": "GPU wird erkannt …",
    "No disks": "Keine Laufwerke",
    "No disks detected": "Keine Laufwerke erkannt",
    "No widgets enabled": "Keine Widgets aktiviert",
    "Enable widgets in the dashboard settings": "Widgets in den Dashboard-Einstellungen aktivieren",
    "Select a profile picture": "Profilbild auswählen",
    "Image files": "Bilddateien",
    "Profile picture changed": "Profilbild geändert",
    "Profile picture changed to %1": "Profilbild auf %1 geändert",
    "Unable to change profile picture": "Profilbild konnte nicht geändert werden",
    "Failed to change profile picture to %1": "Profilbild konnte nicht auf %1 geändert werden",
    "7-day forecast": "7-Tage-Vorhersage",
    "Today": "Heute",
    "Feels like": "Gefühlt",
    "Humidity": "Luftfeuchtigkeit",
    "Sunrise": "Sonnenaufgang",
    "Sunset": "Sonnenuntergang",
    # notification centre, lower half (modules/utilities)
    "Quick toggles": "Schnelleinstellungen",
    "Keep awake": "Wach halten",
    "Normal power management": "Normale Energieverwaltung",
    "Preventing sleep mode": "Ruhezustand wird verhindert",
    "Active since %1": "Aktiv seit %1",
    "Screen recorder": "Rekorder",              # "Bildschirmaufnahme" gets cut off
    "Ready": "Bereit",
    "Running...": "Läuft …",
    "Paused": "Pausiert",
    "PAUSED": "PAUSIERT",
    "Fullscreen": "Vollbild",
    "Region": "Bereich",
    "Record fullscreen": "Vollbild aufnehmen",
    "Record fullscreen with sound": "Vollbild mit Ton aufnehmen",
    "Record region": "Bereich aufnehmen",
    "Record region with sound": "Bereich mit Ton aufnehmen",
    "Recording for %1": "Aufnahme läuft seit %1",
    "Recordings": "Aufnahmen",
    "No recordings found": "Keine Aufnahmen gefunden",
    "Recording at %1": "Aufnahme vom %1",
    "Delete recording?": "Aufnahme löschen?",
    "Recording '%1' will be permanently deleted.": "Aufnahme „%1“ wird endgültig gelöscht.",
    "Delete": "Löschen",
    "Cancel": "Abbrechen",
    # weather conditions (services/Weather.qml, shown on the lock screen and the dashboard)
    "Clear": "Klar",
    "Partly cloudy": "Teilweise bewölkt",
    "Overcast": "Bedeckt",
    "Fog": "Nebel",
    "Drizzle": "Nieselregen",
    "Freezing drizzle": "Gefrierender Nieselregen",
    "Light rain": "Leichter Regen",
    "Rain": "Regen",
    "Heavy rain": "Starker Regen",
    "Light snow": "Leichter Schneefall",
    "Snow": "Schneefall",
    "Heavy snow": "Starker Schneefall",
    "Light snow showers": "Leichte Schneeschauer",
    "Heavy snow showers": "Starke Schneeschauer",
    "Thunderstorm": "Gewitter",
    "Thunderstorm with hail": "Gewitter mit Hagel",
    "Unknown": "Unbekannt",
    "No weather": "Kein Wetter",
}
plurals = {   # Tr.trN / Tr.trCtxN(singular, plural, n, ...)
    ("%n notification", "%n notifications"): ("%n Benachrichtigung", "%n Benachrichtigungen"),
    ("notification", "notifications"): ("Benachrichtigung", "Benachrichtigungen"),   # sidebar header
    ("%n day", "%n days"): ("%n Tag", "%n Tage"),
    ("%n hour", "%n hours"): ("%n Stunde", "%n Stunden"),
    ("%n minute", "%n minutes"): ("%n Minute", "%n Minuten"),
}
files = sorted([*(d / "modules/lock").rglob("*.qml"), *(d / "modules/dashboard").rglob("*.qml"),
                *(d / "modules/sidebar").rglob("*.qml"), *(d / "modules/utilities").rglob("*.qml"), d / "services/Weather.qml", d / "services/NotifData.qml",
                d / "utils/SysInfo.qml"])
texts = {f: f.read_text() for f in files}
call = r'((?:Tr\.tr|Tr\.trCtx|qsTr)\(\s*)'
for en, ger in de.items():
    rx = re.compile(call + '"' + re.escape(en) + r'"(?=\s*[,)])')
    hits = 0
    for f in files:
        texts[f], n = rx.subn(lambda m: m.group(1) + '"' + ger + '"', texts[f])
        hits += n
    assert hits >= 1, "Caelestia string changed upstream: " + en
for (s1, p1), (s2, p2) in plurals.items():
    rx = re.compile(r'(Tr\.(?:trN|trCtxN)\(\s*)"' + re.escape(s1) + r'",\s*"' + re.escape(p1) + '"')
    hits = 0
    for f in files:
        texts[f], n = rx.subn(lambda m: m.group(1) + f'"{s2}", "{p2}"', texts[f])
        hits += n
    assert hits >= 1, "Caelestia plural changed upstream: " + s1
# lock screen date line: German day/month names ("MITTWOCH • 4. NOV."); the dashboard already uses Qt.locale()
c = d / "modules/lock/Center.qml"
a = 'Time.format("dddd • d MMM").toUpperCase()'
assert texts[c].count(a) == 1, "lock/Center.qml date changed upstream"
texts[c] = texts[c].replace(a, 'Qt.locale("de_DE").toString(Time.date, "dddd • d. MMM").toUpperCase()   // ruboshapes: German', 1)
for f in files:
    f.write_text(texts[f])
PY
echo "patched German (lock screen, dashboard, notification centre)"

# Machine-local patches that stay out of this public repo (e.g. authentication). Optional; gets $DST.
LOCAL="${XDG_STATE_HOME:-$HOME/.local/state}/ruboshapes/apply-patch.local.sh"
if [ -x "$LOCAL" ]; then "$LOCAL" "$DST"; fi

# restart Caelestia only (not the bar). Ask it to quit via its own IPC instead of matching the process
# name: after Caelestia restarts itself (e.g. after a crash) its process is just "quickshell".
if qs -c caelestia ipc show >/dev/null 2>&1; then
  caelestia shell -k >/dev/null 2>&1 || qs -c caelestia kill >/dev/null 2>&1 || true
  sleep 1
  QT_QPA_PLATFORMTHEME=kde setsid caelestia shell -d >/dev/null 2>&1 < /dev/null &   # apps it launches inherit this
fi
