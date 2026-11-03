import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.services

// Keybind cheat sheet: hold Super alone (Hyprland long-press bind) to show it, release to hide. The list is read live from
// `hyprctl binds -j`; descriptions come from keybinds.lua ("Category: text"). Binds with the same
// description (workspaces 1-10, arrow keys) are merged into one row.
Scope {
    id: root
    property bool held: false
    property bool shown: false
    property var groups: []           // [{ name, rows: [{ keys: [[chip,...], ...], desc }] }]

    readonly property var modNames: [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]]
    readonly property var keyNames: ({
        "Return": "Enter", "space": "Space", "period": ".", "plus": "+", "minus": "−", "Print": "Print",
        "left": "←", "right": "→", "up": "↑", "down": "↓", "Tab": "Tab", "ALT_L": "Alt",
        "mouse:272": "LMB", "mouse:273": "RMB", "mouse_down": "Scroll ↓", "mouse_up": "Scroll ↑",
        "XF86AudioRaiseVolume": "Vol +", "XF86AudioLowerVolume": "Vol −", "XF86AudioMute": "Mute",
        "XF86AudioPlay": "Play", "XF86AudioStop": "Stop", "XF86AudioNext": "Next", "XF86AudioPrev": "Prev",
        "XF86MonBrightnessUp": "Bright +", "XF86MonBrightnessDown": "Bright −"
    })
    readonly property var order: ["Apps", "Windows", "Workspaces", "Monitors", "Media", "Screenshot", "Clipboard", "System", "Zoom", "Session"]

    function chips(b) {
        const out = [];
        for (const [m, n] of modNames) if (b.modmask & m) out.push(n);
        out.push(keyNames[b.key] ?? (b.key.length === 1 ? b.key.toUpperCase() : b.key));
        return out;
    }
    function build(list) {
        const byDesc = new Map();
        for (const b of list) {
            if (!b.has_description || !b.description) continue;
            if (!byDesc.has(b.description)) byDesc.set(b.description, []);
            byDesc.get(b.description).push(chips(b));
        }
        const gs = new Map();
        for (const [desc, ks] of byDesc) {
            const i = desc.indexOf(": ");
            const cat = i > 0 ? desc.slice(0, i) : "Other", text = i > 0 ? desc.slice(i + 2) : desc;
            // merge repeated binds into one chip set: Super + 1…0, Super + ←↑→↓
            let keys = ks;
            if (ks.length > 2) {
                const mods = ks[0].slice(0, -1), last = ks.map(k => k[k.length - 1]);
                const sameMods = ks.every(k => k.slice(0, -1).join() === mods.join());
                if (sameMods) keys = [mods.concat([last.every(x => /^[0-9]$/.test(x)) ? "1 … 0" : last.join(" ")])];
            }
            if (!gs.has(cat)) gs.set(cat, []);
            gs.get(cat).push({ keys, desc: text });
        }
        groups = [...gs.entries()]
            .sort((a, b) => (order.indexOf(a[0]) + 1 || 99) - (order.indexOf(b[0]) + 1 || 99))
            .map(([name, rows]) => ({ name, rows }));
    }

    Process {
        id: fetch
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { root.build(JSON.parse(text)) } catch (e) {} } }
    }
    Timer { id: delay; interval: 0; onTriggered: if (root.held) { fetch.running = true; root.shown = true } }

    GlobalShortcut { appid: "ruboshapes"; name: "keys-show"; onPressed: { root.held = true; delay.restart() } }
    // Hyprland sends "released" instead of "pressed" when the dispatch happens outside a key press
    GlobalShortcut { appid: "ruboshapes"; name: "keys-hide"; onPressed: root.hide(); onReleased: root.hide() }
    function hide() { held = false; shown = false; delay.stop() }
    // a Super combo actually did something -> no cheat sheet
    Connections {
        target: Hyprland
        function onRawEvent(e) {
            if (root.held && ["activewindow", "workspace", "openwindow", "closewindow", "movewindow", "focusedmon",
                              "fullscreen", "changefloatingmode"].includes(e.name)) {
                root.held = false; root.shown = false; delay.stop();
            }
        }
    }

    PanelWindow {
        id: panel
        visible: root.shown || fadeAnim.running
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "ruboshapes-keys"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        mask: Region {}                  // never takes input: Super combos keep working

        Rectangle {
            id: frame
            anchors.centerIn: parent
            width: Math.min(cols.implicitWidth + 48, panel.width - 80)
            height: cols.implicitHeight + 70
            radius: 18
            color: Theme.popup
            opacity: root.shown ? 1 : 0
            scale: root.shown ? 1 : 0.97
            Behavior on opacity { NumberAnimation { id: fadeAnim; duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            Shape {     // Hyprland window border look
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1; fillRule: ShapePath.OddEvenFill
                    fillGradient: LinearGradient { x1: 0; y1: 0; x2: frame.width; y2: frame.height
                        GradientStop { position: 0; color: Theme.border1 }
                        GradientStop { position: 1; color: Qt.alpha(Theme.border2, 0.93) } }
                    PathRectangle { width: frame.width; height: frame.height; radius: 18 }
                    PathRectangle { x: 2; y: 2; width: frame.width - 4; height: frame.height - 4; radius: 16 }
                }
            }
            Text { x: 24; y: 18; text: "Keybinds"; font.family: Theme.sans; font.pixelSize: 18; font.weight: Font.Bold; color: Theme.text }
            Text { anchors.right: parent.right; anchors.rightMargin: 24; y: 22; text: "release Super to close"
                font.family: Theme.sans; font.pixelSize: 12; color: Theme.text2; opacity: 0.7 }

            Flow {      // category blocks, flowing into columns
                id: cols
                x: 24; y: 52
                width: Math.min(1500, panel.width - 128)
                spacing: 28
                Repeater {
                    model: root.groups
                    Column {
                        required property var modelData
                        width: 370
                        spacing: 5
                        Text { text: modelData.name.toUpperCase(); font.family: Theme.sans; font.pixelSize: 11; font.weight: Font.Bold
                            font.letterSpacing: 1.2; color: Theme.accent; bottomPadding: 3 }
                        Repeater {
                            model: modelData.rows
                            Row {
                                required property var modelData
                                spacing: 10
                                Row {   // key chips
                                    width: 182; spacing: 3
                                    Repeater {
                                        model: modelData.keys[0]
                                        Rectangle {
                                            required property string modelData
                                            height: 20; width: chip.implicitWidth + 10; radius: 5
                                            color: Qt.rgba(1, 1, 1, 0.09); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
                                            Text { id: chip; anchors.centerIn: parent; text: modelData
                                                font.family: Theme.mono; font.pixelSize: 11; font.weight: Font.Bold; color: Theme.text }
                                        }
                                    }
                                }
                                Text { width: 178; text: modelData.desc; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter
                                    font.family: Theme.sans; font.pixelSize: 13; color: Theme.text2 }
                            }
                        }
                    }
                }
            }
        }
    }
}
