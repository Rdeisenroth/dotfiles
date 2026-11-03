import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.services

// Alt+Tab switcher with live window thumbnails and two views:
//   Recent      most recently used first (grid)
//   Workspaces  grouped by monitor (left to right) and workspace
// Hyprland binds (keybinds.lua) send global shortcuts:
//   ruboshapes:switch-next (Alt+Tab), ruboshapes:switch-monitor (Alt+Shift+Tab: this monitor only),
//   ruboshapes:switch-commit (Alt released).
// Keys while open: type to search, ^ (key left of 1) switches view, arrows move, Enter opens, Esc closes.
Scope {
    id: root
    property bool open: false
    property var wins: []                // MRU order
    property bool monOnly: false
    property string view: "recent"       // "recent" | "grouped"; remembered between opens
    property string selAddr: ""
    // typing filters; once you type, releasing Alt no longer jumps (so you can type with Alt released)
    property string query: ""
    property bool searching: false

    // ---- search -------------------------------------------------------------------------------
    function score(t) {
        const cls = t.lastIpcObject?.class ?? "";
        return Math.max(fuzzy(query, cls.split(".").pop()) + 40, fuzzy(query, cls) + 20, fuzzy(query, t.title ?? ""));
    }
    // subsequence match; bonus for consecutive letters and word starts, penalty for gaps
    function fuzzy(q, text) {
        q = q.toLowerCase(); const t = text.toLowerCase();
        let s = 0, ti = 0, last = -2;
        for (const ch of q) {
            const at = t.indexOf(ch, ti);
            if (at < 0) return -1e9;
            s += 10;
            if (at === last + 1) s += 15;
            if (at === 0 || " -_./:".includes(t[at - 1])) s += 20;
            s -= Math.min(at - ti, 10);
            last = at; ti = at + 1;
        }
        return s - t.length * 0.1;
    }
    readonly property var ranked: {         // matches, best first (MRU order without a query)
        if (query === "") return wins;
        return wins.map((t, i) => ({ t, i, s: score(t) })).filter(x => x.s > -1e6)
            .sort((a, b) => b.s - a.s || a.i - b.i).map(x => x.t);
    }

    // ---- grouping -----------------------------------------------------------------------------
    function wsNum(id) { return ((id - 1) % 10) + 1 }      // per-monitor workspaces: slot*10 + n
    readonly property var groups: {
        const mons = Hyprland.monitors.values.slice().sort((a, b) => (a.x ?? 0) - (b.x ?? 0));
        const out = [];
        for (const m of mons) {
            const ws = new Map();
            for (const t of ranked) {
                if ((t.workspace?.monitor?.name ?? t.monitor?.name) !== m.name) continue;
                const id = t.workspace.id;
                if (!ws.has(id)) ws.set(id, { id, wins: [] });
                ws.get(id).wins.push(t);
            }
            if (ws.size === 0) continue;
            for (const w of ws.values())    // keep MRU order inside a workspace even while searching
                w.wins.sort((a, b) => wins.indexOf(a) - wins.indexOf(b));
            out.push({ name: m.name, model: m.lastIpcObject?.model ?? "", focused: m.focused,
                       activeWs: m.activeWorkspace?.id ?? -1, workspaces: [...ws.values()].sort((a, b) => a.id - b.id) });
        }
        return out;
    }
    readonly property var order: {
        if (view === "recent") return ranked;
        const out = [];             // no Array.flatMap in Qt's JS engine
        for (const g of groups) for (const w of g.workspaces) for (const t of w.wins) out.push(t);
        return out;
    }
    readonly property int sel: order.findIndex(t => t.address === selAddr)
    onQueryChanged: selAddr = ranked.length ? ranked[0].address : ""

    // ---- actions ------------------------------------------------------------------------------
    function rebuild() {
        wins = Hyprland.toplevels.values
            .filter(t => (t.workspace?.id ?? -1) > 0 && (t.lastIpcObject?.mapped ?? true))
            .filter(t => !monOnly || t.monitor?.name === Hyprland.focusedMonitor?.name)
            .sort((a, b) => (a.lastIpcObject?.focusHistoryID ?? 999) - (b.lastIpcObject?.focusHistoryID ?? 999));
    }
    function step(d, mon) {
        if (!open) {
            monOnly = mon ?? false;
            query = ""; searching = false;
            rebuild();
            if (wins.length === 0) return;
            selAddr = (wins.length > 1 ? (d > 0 ? wins[1] : wins[wins.length - 1]) : wins[0]).address;
            open = true;
            return;
        }
        const n = order.length;
        if (n === 0) return;
        const i = sel < 0 ? (d > 0 ? -1 : 0) : sel;
        selAddr = order[((i + d) % n + n) % n].address;
    }
    function move(d) {      // arrows: clamp instead of wrapping
        if (order.length === 0) return;
        selAddr = order[Math.max(0, Math.min(order.length - 1, (sel < 0 ? 0 : sel) + d))].address;
    }
    function toggleView() {
        view = view === "recent" ? "grouped" : "recent";
    }
    // fromAlt: the Alt-release binding; ignored once a search was started
    function commit(fromAlt) {
        if (!open || (fromAlt && searching)) return;
        const t = order[sel] ?? ranked[0];
        open = false;
        if (t) Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${t.address}" })`);
    }
    function pick(t) { selAddr = t.address; commit() }

    IpcHandler { target: "switcher"          // also scriptable: qs -p <dir> ipc call switcher next|prev|commit|cancel|view
        function next(): void { root.step(1) }
        function prev(): void { root.step(-1) }
        function commit(): void { root.commit() }
        function cancel(): void { root.open = false }
        function view(): void { root.toggleView() } }
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
        mask: Region { item: frame }     // only the panel takes input/blur

        Connections { target: root
            function onOpenChanged() { if (root.open) flick.contentY = 0 }
            function onViewChanged() { flick.contentY = 0 } }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                const ok = () => { e.accepted = true };
                if (e.nativeScanCode === 49) { root.toggleView(); ok() }     // key left of 1 (^ on DE, ` on US)
                else if (e.key === Qt.Key_Escape) { root.open = false; ok() }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.commit(false); ok() }
                else if (e.key === Qt.Key_Tab) { root.step(1); ok() }
                else if (e.key === Qt.Key_Backtab) { root.step(-1); ok() }
                else if (e.key === Qt.Key_Left) { root.move(-1); ok() }
                else if (e.key === Qt.Key_Right) { root.move(1); ok() }
                else if (e.key === Qt.Key_Up) { root.move(root.view === "recent" ? -frame.cols : -1); ok() }
                else if (e.key === Qt.Key_Down) { root.move(root.view === "recent" ? frame.cols : 1); ok() }
                else if (e.key === Qt.Key_Backspace) { root.query = (e.modifiers & Qt.ControlModifier) ? "" : root.query.slice(0, -1); ok() }
                else {
                    // letters/digits also while Alt is still held (event.text is empty then)
                    let ch = e.text;
                    if ((!ch || e.modifiers & Qt.AltModifier) && e.key >= Qt.Key_A && e.key <= Qt.Key_Z) ch = String.fromCharCode(e.key).toLowerCase();
                    else if ((!ch || e.modifiers & Qt.AltModifier) && e.key >= Qt.Key_0 && e.key <= Qt.Key_9) ch = String.fromCharCode(e.key);
                    if (ch && ch.length === 1 && ch >= " " && !(e.modifiers & Qt.ControlModifier)) {
                        root.query += ch; root.searching = true; ok();
                    }
                }
            }
        }

        Rectangle {
            id: frame
            anchors.centerIn: parent
            readonly property int pad: 22
            // Recent grid
            readonly property int cols: Math.max(1, Math.min(Math.max(root.ranked.length, 1), Math.floor((panel.width * 0.86 - 2 * pad) / (260 + 12))))
            // Workspaces view: monitor columns, cards per row inside one column
            readonly property int nMon: Math.max(1, root.groups.length)
            readonly property int perRow: Math.max(1, Math.min(nMon === 1 ? 4 : nMon === 2 ? 3 : 2,
                                                              Math.floor(((panel.width * 0.9 - 2 * pad) / nMon - 28 + 10) / 220)))
            readonly property real contentW: root.order.length === 0 ? 0 : root.view === "recent" ? recentGrid.implicitWidth : groupRow.implicitWidth
            readonly property real contentH: root.order.length === 0 ? 120 : root.view === "recent" ? recentGrid.implicitHeight : groupRow.implicitHeight
            readonly property real maxViewH: panel.height * 0.78 - 140

            width: Math.max(contentW, 640) + 2 * pad
            height: pad + 40 + 16 + flick.height + 14 + 20 + 16
            radius: 20
            color: Theme.popup
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.96
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on width { enabled: root.open; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on height { enabled: root.open; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Shape {     // Hyprland window border look (teal top-left -> purple bottom-right)
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1; fillRule: ShapePath.OddEvenFill
                    fillGradient: LinearGradient { x1: 0; y1: 0; x2: frame.width; y2: frame.height
                        GradientStop { position: 0; color: Theme.border1 }
                        GradientStop { position: 1; color: Qt.alpha(Theme.border2, 0.93) } }
                    PathRectangle { width: frame.width; height: frame.height; radius: 20 }
                    PathRectangle { x: 2; y: 2; width: frame.width - 4; height: frame.height - 4; radius: 18 }
                }
            }

            // ---- header: search field + view tabs ----
            Rectangle {
                id: search
                x: frame.pad; y: frame.pad
                width: frame.width - 2 * frame.pad - tabs.width - 12; height: 40; radius: 20
                color: Qt.rgba(0, 0, 0, 0.32)
                border.width: 1; border.color: root.query !== "" ? Qt.alpha(Theme.border1, 0.75) : Qt.rgba(1, 1, 1, 0.09)
                Behavior on border.color { ColorAnimation { duration: 120 } }
                Row {
                    x: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    Text { text: "\u{f002}"; font.family: Theme.monoIcons; font.pixelSize: 14; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: root.query; visible: root.query !== ""; font.family: Theme.mono; font.pixelSize: 15; color: Theme.text
                        anchors.verticalCenter: parent.verticalCenter }
                    Rectangle { width: 2; height: 18; radius: 1; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on opacity { loops: Animation.Infinite; running: root.open
                            NumberAnimation { to: 0; duration: 500 } NumberAnimation { to: 1; duration: 500 } } }
                    Text { text: "Type to search windows"; visible: root.query === ""; font.family: Theme.sans; font.pixelSize: 14
                        color: Theme.text2; opacity: 0.55; anchors.verticalCenter: parent.verticalCenter }
                }
                Text { anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    text: root.query === "" ? root.wins.length + (root.wins.length === 1 ? " window" : " windows")
                                            : root.ranked.length + " / " + root.wins.length
                    font.family: Theme.mono; font.pixelSize: 12; color: Theme.text2; opacity: 0.8 }
            }
            Rectangle {     // segmented control
                id: tabs
                x: frame.width - frame.pad - width; y: frame.pad
                width: tabRow.implicitWidth + 8; height: 40; radius: 20
                color: Qt.rgba(0, 0, 0, 0.32)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.09)
                Rectangle {     // sliding highlight
                    y: 4; height: 32; radius: 16
                    x: 4 + (root.view === "recent" ? 0 : tabRecent.width)
                    width: root.view === "recent" ? tabRecent.width : tabGrouped.width
                    color: Theme.pill
                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }
                Row {
                    id: tabRow
                    x: 4; y: 4
                    Tab { id: tabRecent; icon: "\u{f017}"; label: "Recent"; on: root.view === "recent"; onClicked: root.view = "recent" }
                    Tab { id: tabGrouped; icon: "\u{f0379}"; label: "Workspaces"; on: root.view === "grouped"; onClicked: root.view = "grouped" }
                }
            }

            // ---- content ----
            Flickable {
                id: flick
                x: frame.pad; y: frame.pad + 40 + 16
                width: frame.width - 2 * frame.pad
                height: Math.min(frame.contentH, frame.maxViewH)
                contentWidth: width; contentHeight: frame.contentH
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Behavior on contentY { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                readonly property real maxY: Math.max(0, contentHeight - height)
                // keep the scroll position valid while cards are still being laid out
                onMaxYChanged: if (contentY > maxY) contentY = maxY
                function ensure(item) {
                    if (height <= 0) return;
                    const p = item.mapToItem(flick.contentItem, 0, 0);
                    let y = contentY;
                    if (p.y < y) y = p.y - 8;
                    else if (p.y + item.height > y + height) y = p.y + item.height - height + 8;
                    contentY = Math.max(0, Math.min(maxY, y));
                }

                Text {
                    visible: root.order.length === 0
                    width: flick.width; height: 120
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    text: root.query === "" ? "No windows" : `No window matches “${root.query}”`
                    font.family: Theme.sans; font.pixelSize: 14; color: Theme.text2; opacity: 0.7
                }

                Grid {      // Recent
                    id: recentGrid
                    visible: root.view === "recent"
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: frame.cols
                    spacing: 12
                    Repeater {
                        model: root.open && root.view === "recent" ? root.ranked : []
                        SwitchCard {
                            id: rc
                            required property var modelData
                            win: modelData
                            active: modelData.address === root.selAddr
                            live: root.open
                            tag: root.wsNum(modelData.workspace?.id ?? 1) + " · " + (modelData.monitor?.name ?? "")
                            onPicked: root.pick(modelData)
                            onActiveChanged: if (active) Qt.callLater(() => flick.ensure(rc))
                        }
                    }
                }

                Row {       // Workspaces: one column per monitor
                    id: groupRow
                    visible: root.view === "grouped"
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 28
                    Repeater {
                        model: root.open && root.view === "grouped" ? root.groups : []
                        Column {
                            id: monCol
                            required property var modelData
                            readonly property real colW: frame.perRow * 210 + (frame.perRow - 1) * 10
                            width: colW
                            spacing: 12
                            Row {   // monitor header
                                spacing: 8
                                Text { text: "\u{f0379}"; font.family: Theme.monoIcons; font.pixelSize: 16
                                    color: monCol.modelData.focused ? Theme.accent : Theme.text2; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: monCol.modelData.name; font.family: Theme.sans; font.pixelSize: 14; font.weight: Font.Bold
                                    color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: monCol.modelData.model; font.family: Theme.sans; font.pixelSize: 12; color: Theme.text2; opacity: 0.6
                                    anchors.verticalCenter: parent.verticalCenter }
                            }
                            Rectangle { width: monCol.colW; height: 1
                                gradient: Gradient { orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: Qt.alpha(Theme.sep1, 0.55) }
                                    GradientStop { position: 1; color: Qt.alpha(Theme.sep2, 0) } } }
                            Repeater {
                                model: monCol.modelData.workspaces
                                Column {
                                    id: wsCol
                                    required property var modelData
                                    readonly property bool shown: modelData.id === monCol.modelData.activeWs
                                    spacing: 8
                                    Row {   // workspace header
                                        spacing: 8
                                        Rectangle { width: 22; height: 22; radius: 11; anchors.verticalCenter: parent.verticalCenter
                                            color: wsCol.shown ? Theme.pill : Qt.rgba(1, 1, 1, 0.08)
                                            Text { anchors.centerIn: parent; text: root.wsNum(wsCol.modelData.id)
                                                font.family: Theme.mono; font.pixelSize: 11; font.weight: Font.Bold
                                                color: wsCol.shown ? Theme.pillText : Theme.text2 } }
                                        Text { text: "Workspace " + root.wsNum(wsCol.modelData.id) + (wsCol.shown ? "  · visible" : "")
                                            font.family: Theme.sans; font.pixelSize: 12; color: Theme.text2; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    Flow {
                                        width: monCol.colW
                                        spacing: 10
                                        Repeater {
                                            model: wsCol.modelData.wins
                                            SwitchCard {
                                                id: groupCard
                                                required property var modelData
                                                win: modelData
                                                compact: true
                                                active: modelData.address === root.selAddr
                                                live: root.open
                                                onPicked: root.pick(modelData)
                                                onActiveChanged: if (active) Qt.callLater(() => flick.ensure(groupCard))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---- footer: key hints ----
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: flick.y + flick.height + 14
                spacing: 18
                Hint { keys: "Tab"; label: "next" }
                Hint { keys: "↑↓←→"; label: "move" }
                Hint { keys: "Enter"; label: "open" }
                Hint { keys: "^"; label: "switch view" }
                Hint { keys: "Esc"; label: "close" }
            }
        }
    }

    component Tab: Item {
        id: tab
        property string icon
        property string label
        property bool on
        signal clicked()
        width: tabInner.implicitWidth + 28; height: 32
        Row {
            id: tabInner
            anchors.centerIn: parent; spacing: 7
            Text { text: tab.icon; font.family: Theme.monoIcons; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter
                color: tab.on ? Theme.pillText : Theme.text2 }
            Text { text: tab.label; font.family: Theme.sans; font.pixelSize: 13; font.weight: tab.on ? Font.Bold : Font.Normal
                anchors.verticalCenter: parent.verticalCenter; color: tab.on ? Theme.pillText : Theme.text2 }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tab.clicked() }
    }

    component Hint: Row {
        property string keys
        property string label
        spacing: 6
        Rectangle { height: 20; width: keyText.implicitWidth + 12; radius: 5; anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(1, 1, 1, 0.08); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
            Text { id: keyText; anchors.centerIn: parent; text: parent.parent.keys
                font.family: Theme.mono; font.pixelSize: 11; font.weight: Font.Bold; color: Theme.text } }
        Text { text: parent.label; font.family: Theme.sans; font.pixelSize: 12; color: Theme.text2; opacity: 0.75
            anchors.verticalCenter: parent.verticalCenter }
    }
}
