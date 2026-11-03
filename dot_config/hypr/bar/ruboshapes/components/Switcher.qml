import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import qs.services

// Alt+Tab switcher with live window thumbnails (most recently used first).
// Hyprland binds (keybinds.lua) send global shortcuts:
//   ruboshapes:switch-next (Alt+Tab), ruboshapes:switch-monitor (Alt+Shift+Tab: this monitor only),
//   ruboshapes:switch-commit (Alt released). Escape cancels, a click picks a window.
Scope {
    id: root
    property bool open: false
    property int sel: 0
    property var wins: []
    property bool monOnly: false        // Alt+Shift+Tab: only windows on the current monitor
    // fuzzy search (like the old rofi switcher): typing filters, Enter focuses the best match.
    // Once you type, releasing Alt no longer jumps (so you can type with Alt released).
    property string query: ""
    property bool searching: false
    readonly property var shown: {
        if (query === "") return wins;
        const scored = [];
        for (let i = 0; i < wins.length; i++) {
            const t = wins[i], cls = (t.lastIpcObject?.class ?? "");
            const sc = Math.max(fuzzy(query, cls.split(".").pop()) + 40, fuzzy(query, cls) + 20, fuzzy(query, t.title ?? ""));
            if (sc > -1e6) scored.push({ t, sc, i });
        }
        scored.sort((a, b) => b.sc - a.sc || a.i - b.i);
        return scored.map(x => x.t);
    }
    // subsequence match; bonus for consecutive letters and word starts, penalty for gaps
    function fuzzy(q, text) {
        q = q.toLowerCase(); const t = text.toLowerCase();
        let score = 0, ti = 0, last = -2;
        for (const ch of q) {
            const at = t.indexOf(ch, ti);
            if (at < 0) return -1e9;
            score += 10;
            if (at === last + 1) score += 15;
            if (at === 0 || " -_./:".includes(t[at - 1])) score += 20;
            score -= Math.min(at - ti, 10);
            last = at; ti = at + 1;
        }
        return score - t.length * 0.1;
    }
    onQueryChanged: sel = 0

    function rebuild() {
        wins = Hyprland.toplevels.values
            .filter(t => (t.workspace?.id ?? -1) > 0 && (t.lastIpcObject?.mapped ?? true))
            .filter(t => !monOnly || t.monitor?.name === Hyprland.focusedMonitor?.name)
            .sort((a, b) => (a.lastIpcObject?.focusHistoryID ?? 999) - (b.lastIpcObject?.focusHistoryID ?? 999));
    }
    function step(d, mon, search) {
        if (!open) {
            monOnly = mon ?? false;
            query = ""; searching = search ?? false;
            rebuild();
            if (wins.length === 0) return;
            sel = wins.length > 1 ? (d > 0 ? 1 : wins.length - 1) : 0;
            open = true;
        } else if (shown.length > 0) {
            sel = (sel + d + shown.length) % shown.length;
        }
    }
    // fromAlt: the Alt-release binding; ignored once a search was started
    function commit(fromAlt) {
        if (!open || (fromAlt && searching)) return;
        const t = shown[sel];
        open = false;
        if (t) Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${t.address}" })`);
    }
    function pick(i) { sel = i; commit() }

    IpcHandler { target: "switcher"          // also scriptable: qs -p <dir> ipc call switcher next|prev|commit|cancel
        function next(): void { root.step(1) }
        function prev(): void { root.step(-1) }
        function commit(): void { root.commit() }
        function cancel(): void { root.open = false } }
    GlobalShortcut { appid: "ruboshapes"; name: "switch-next"; onPressed: root.step(1) }
    GlobalShortcut { appid: "ruboshapes"; name: "switch-prev"; onPressed: root.step(-1) }
    GlobalShortcut { appid: "ruboshapes"; name: "switch-monitor"; onPressed: root.step(1, true) }
    GlobalShortcut { appid: "ruboshapes"; name: "switch-commit"; onPressed: root.commit(true); onReleased: root.commit(true) }   // release binds send "released"

    PanelWindow {
        id: panel
        visible: root.open
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "ruboshapes-switcher"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"
        // only the card panel takes input/blur; the rest of the screen stays visible and click-through-ish
        mask: Region { item: frame }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) { root.open = false; e.accepted = true }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.commit(false); e.accepted = true }
                else if (e.key === Qt.Key_Left || e.key === Qt.Key_Up) { root.step(-1); e.accepted = true }
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down) { root.step(1); e.accepted = true }
                else if (e.key === Qt.Key_Backspace) { root.query = root.query.slice(0, -1); e.accepted = true }
                else {
                    // letters/digits also while Alt is still held (event.text is empty then)
                    let ch = e.text;
                    if ((!ch || e.modifiers & Qt.AltModifier) && e.key >= Qt.Key_A && e.key <= Qt.Key_Z) ch = String.fromCharCode(e.key).toLowerCase();
                    else if ((!ch || e.modifiers & Qt.AltModifier) && e.key >= Qt.Key_0 && e.key <= Qt.Key_9) ch = String.fromCharCode(e.key);
                    if (ch && ch.length === 1 && ch >= " " && !(e.modifiers & Qt.ControlModifier)) {
                        root.query += ch; root.searching = true; e.accepted = true;
                    }
                }
            }
        }

        Rectangle {
            id: frame
            anchors.centerIn: parent
            readonly property int cardW: 260
            readonly property int cols: Math.max(1, Math.min(root.wins.length, Math.floor((panel.width * 0.85 - 40) / (cardW + 14))))
            width: Math.max(grid.implicitWidth, 320) + 40
            height: grid.implicitHeight + 40 + (root.searching ? 52 : 0)
            radius: 18
            color: Theme.popup
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.96
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            // Hyprland window border look (teal top-left -> purple bottom-right)
            Shape {
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

            Rectangle {     // search field (shown once you start typing)
                visible: root.searching
                x: 20; y: 18; width: parent.width - 40; height: 38; radius: 19
                color: Qt.rgba(0, 0, 0, 0.30)
                border.width: 1; border.color: Qt.alpha(Theme.border1, 0.5)
                Row { anchors.verticalCenter: parent.verticalCenter; x: 14; spacing: 10
                    Text { text: "\u{f002}"; font.family: Theme.monoIcons; font.pixelSize: 14; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: root.query === "" ? "Type to search windows…" : root.query
                        font.family: Theme.mono; font.pixelSize: 15; color: root.query === "" ? Theme.text2 : Theme.text
                        opacity: root.query === "" ? 0.6 : 1; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle { width: 2; height: 18; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on opacity { loops: Animation.Infinite; running: root.searching
                            NumberAnimation { to: 0; duration: 500 } NumberAnimation { to: 1; duration: 500 } } }
                }
                Text { anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    text: root.shown.length + " / " + root.wins.length; font.family: Theme.mono; font.pixelSize: 12; color: Theme.text2 }
            }
            Grid {
                id: grid
                anchors.horizontalCenter: parent.horizontalCenter
                y: 20 + (root.searching ? 52 : 0)
                columns: frame.cols
                spacing: 14
                Repeater {
                    model: root.open ? root.shown : []
                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property bool active: index === root.sel
                        readonly property string cls: modelData.lastIpcObject?.class ?? ""
                        width: frame.cardW; height: 196
                        radius: 12
                        color: active ? Qt.rgba(0.18, 0.83, 0.75, 0.16) : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.22))
                        border.width: active ? 2 : 1
                        border.color: active ? Theme.border1 : Qt.rgba(1, 1, 1, 0.08)
                        Behavior on color { ColorAnimation { duration: 120 } }

                        ClippingRectangle {
                            id: thumb
                            x: 8; y: 8; width: parent.width - 16; height: 146
                            radius: 8
                            color: Qt.rgba(0, 0, 0, 0.35)
                            ScreencopyView {
                                anchors.centerIn: parent
                                // keep the window's aspect ratio inside the thumbnail box
                                readonly property real ar: sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 16 / 9
                                width: Math.min(thumb.width, thumb.height * ar)
                                height: Math.min(thumb.height, thumb.width / ar)
                                captureSource: card.modelData.wayland
                                live: root.open
                            }
                        }
                        Row {
                            anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12; bottom: parent.bottom; bottomMargin: 10 }
                            spacing: 8
                            IconImage { implicitSize: 18; anchors.verticalCenter: parent.verticalCenter
                                source: Quickshell.iconPath(DesktopEntries.heuristicLookup(card.cls)?.icon ?? card.cls.toLowerCase(), "application-x-executable") }
                            Text {
                                width: parent.width - 26; anchors.verticalCenter: parent.verticalCenter
                                text: card.modelData.title || card.cls
                                elide: Text.ElideRight
                                font.family: Theme.sans; font.pixelSize: 13; font.weight: card.active ? Font.Bold : Font.Normal
                                color: card.active ? Theme.text : Theme.text2
                            }
                        }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.pick(card.index) }
                    }
                }
            }
        }
    }
}
