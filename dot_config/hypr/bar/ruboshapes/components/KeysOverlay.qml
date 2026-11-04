import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.services

// Keybind cheat sheet ("Chevron Rail"). Two ways to open it (Hyprland side: keybinds.lua):
//   peek  - hold Super alone (long press) -> keys-show; releasing Super / any other key -> keys-hide.
//           Never takes input, so every Super combo keeps working. Shift/Ctrl/Alt while peeking arrive as
//           keys-<mod>-down/up and switch the keyboard map to that layer.
//   pinned - Super+K (keys-pin, toggles): keyboard focus, type to filter, Tab switches view, Esc / click
//           outside / Super+K closes. Held modifiers (Qt key events) switch the keyboard map layer.
// The list is read live from `hyprctl binds -j`; descriptions come from keybinds.lua ("Category: text").
// Binds with the same description (workspaces 1-10, arrow keys) and up/down style pairs are merged.
Scope {
    id: root
    readonly property var pal: Schemes.pal(Hyprland.focusedMonitor?.name ?? "")   // dark or light glass (ov* keys)
    // the sheet is always dark glass, also in light mode: keep its text light
    readonly property color fg: pal.ovText
    readonly property color fg2: pal.ovSub
    readonly property color acc: pal.ovAcc
    readonly property color warn: pal.ovWarn

    property bool held: false           // peek requested (Super held)
    property bool shown: false
    property bool pinned: false
    property string query: ""
    property string tab: "fn"           // "fn" = by function, "key" = by key

    // modifier state for the keyboard map
    property bool mShift: false
    property bool mCtrl: false
    property bool mAlt: false
    property bool mSuper: false         // pinned mode only (peek implies Super)
    readonly property int heldMask: (mShift ? 1 : 0) | (mCtrl ? 4 : 0) | (mAlt ? 8 : 0)
    readonly property int layerMask: pinned ? ((mSuper || heldMask === 0 ? 64 : 0) | heldMask) : (64 | heldMask)
    function resetMods() { mShift = false; mCtrl = false; mAlt = false; mSuper = false }

    // ------------------------------------------------------------------ data
    property var binds: []              // [{ mods, key, id, cat, text, desc, dup }]
    property var groups: []             // [{ name, rows: [row] }]   row = { chord, text, hot, dup, extra, hay }
    property var mxRows: []             // [{ label, cells: [cell|null x4], hay }]   cell = { text, dup }
    property var dupNotes: []

    readonly property var modBits: [[4, "Ctrl"], [8, "Alt"], [1, "Shift"]]
    readonly property var keyNames: ({
        "Return": "Enter", "space": "Space", "period": ".", "comma": ",", "plus": "+", "minus": "−", "Print": "Print",
        "left": "←", "right": "→", "up": "↑", "down": "↓", "Tab": "Tab", "ALT_L": "Alt",
        "mouse:272": "LMB", "mouse:273": "RMB", "mouse_down": "Scroll ↓", "mouse_up": "Scroll ↑",
        "XF86AudioRaiseVolume": "Vol +", "XF86AudioLowerVolume": "Vol −", "XF86AudioMute": "Mute",
        "XF86AudioPlay": "Play", "XF86AudioStop": "Stop", "XF86AudioNext": "Next", "XF86AudioPrev": "Prev",
        "XF86MonBrightnessUp": "Bright +", "XF86MonBrightnessDown": "Bright −"
    })
    readonly property var order: ["Apps", "Windows", "Workspaces", "Monitors", "Media", "Screenshot", "Clipboard", "System", "Zoom", "Session"]
    readonly property var icons: ({
        "Apps": "\u{f003b}", "Windows": "\u{f10ac}", "Workspaces": "\u{f0570}", "Monitors": "\u{f037a}",
        "Media": "\u{f0387}", "Screenshot": "\u{f0e51}", "Clipboard": "\u{f014d}", "System": "\u{f0493}",
        "Zoom": "\u{f034b}", "Session": "\u{f0425}"
    })
    readonly property string arch: "\u{f08c7}"
    // most used: drawn bold
    readonly property var hot: ["Apps: Terminal", "Apps: Launcher", "Apps: Firefox", "Apps: File manager", "Windows: Close",
        "Windows: Focus (arrows)", "Windows: Switcher (type to search)", "Workspaces: Go to 1–10", "Clipboard: History menu",
        "Screenshot: Monitor", "Screenshot: Region", "Session: Lock screen"]
    readonly property var pairs: [["down", "up"], ["in", "out"], ["min", "max"], ["previous", "next"]]
    readonly property var arrowOrder: ["←", "↑", "→", "↓"]

    function keyLabel(k) { return keyNames[k] ?? (k.length === 1 ? k.toUpperCase() : k) }
    function keyId(k) { return k === "mouse_up" || k === "mouse_down" ? "wheel" : k.toLowerCase() }
    function isExtraKey(k) { return k.startsWith("mouse") || k.startsWith("XF86") }
    function chordOf(b) {
        return { sup: !!(b.mods & 64), mods: modBits.filter(m => b.mods & m[0]).map(m => m[1]), key: keyLabel(b.key) };
    }
    function chordText(c) { return (c.sup ? ["Super"] : []).concat(c.mods).concat([c.key]).join("+") }
    // short label for the keyboard map / matrix: no "(…)", and say what "In" / "Reset" belong to
    function shortText(cat, text) {
        const t = text.replace(/\s*\([^)]*\)/g, "");
        return /^(In|Out|Reset)\b/.test(t) ? cat + " " + t.toLowerCase() : t;
    }
    function matches(hay) {
        const ws = query.toLowerCase().split(/\s+/).filter(w => w);
        return ws.every(w => hay.includes(w));
    }

    // "Volume down" + "Volume up" -> "Volume down / up" (one word differs, and it is a known pair)
    function pairText(s, t) {
        const ws = s.split(" "), wt = t.split(" ");
        if (ws.length !== wt.length) return null;
        let d = -1;
        for (let i = 0; i < ws.length; i++) if (ws[i] !== wt[i]) { if (d >= 0) return null; d = i; }
        if (d < 0) return null;
        const p = ws[d].toLowerCase(), q = wt[d].toLowerCase();
        for (const [x, y] of pairs) {
            if (!((p === x && q === y) || (p === y && q === x))) continue;
            const sFirst = p === x;
            const w = ws.slice();
            w[d] = (sFirst ? ws[d] : wt[d]) + " / " + (sFirst ? wt[d] : ws[d]).toLowerCase();
            return { text: w.join(" "), sFirst };
        }
        return null;
    }
    // "Vol −" + "Vol +" -> "Vol −/+"
    function joinKeys(a, b) {
        let i = 0;
        while (i < a.length && i < b.length && a[i] === b[i]) i++;
        const cut = a.slice(0, i).lastIndexOf(" ") + 1;
        return a + "/" + b.slice(cut);
    }

    function build(list) {
        const bs = [];
        for (const b of list) {
            if (!b.has_description || !b.description) continue;
            const i = b.description.indexOf(": ");
            const cat = i > 0 ? b.description.slice(0, i) : "Other";
            const text = (i > 0 ? b.description.slice(i + 2) : b.description).replace(/\s*\(arrows\)/, "");
            bs.push({ mods: b.modmask & 77, key: b.key, id: keyId(b.key), cat, text, desc: b.description, dup: false });
        }
        // the same chord bound to different things
        const byChord = new Map();
        for (const b of bs) {
            const c = b.mods + "|" + b.key;
            if (!byChord.has(c)) byChord.set(c, []);
            byChord.get(c).push(b);
        }
        const notes = [];
        for (const arr of byChord.values()) {
            const ds = [...new Set(arr.map(x => x.desc))];
            if (ds.length < 2) continue;
            for (const x of arr) x.dup = true;
            notes.push(chordText(chordOf(arr[0])) + " is bound " + (ds.length === 2 ? "twice" : ds.length + " times") + ": "
                       + arr.map(x => x.text).join(" + "));
        }
        binds = bs;
        dupNotes = notes;
        groups = buildGroups(bs);
        mxRows = buildMatrix(bs);
    }

    function buildGroups(bs) {
        const byDesc = new Map();
        for (const b of bs) {
            if (!byDesc.has(b.desc)) byDesc.set(b.desc, []);
            byDesc.get(b.desc).push(b);
        }
        const gs = new Map();
        for (const [desc, bl] of byDesc) {
            const b0 = bl[0], chord = chordOf(b0);
            // merge repeated binds into one chord: Super + 1…0, Super + ←↑→↓
            if (bl.length > 1 && bl.every(x => x.mods === b0.mods)) {
                const ls = bl.map(x => keyLabel(x.key));
                chord.key = ls.every(x => /^[0-9]$/.test(x)) ? "1…0"
                          : ls.every(x => arrowOrder.includes(x)) ? arrowOrder.filter(a => ls.includes(a)).join("")
                          : ls.join(" ");
            }
            const row = { chord, text: b0.text, cat: b0.cat, hot: hot.includes(desc), dup: bl.some(x => x.dup),
                          merged: bl.length > 1, extra: bl.every(x => isExtraKey(x.key)), keys: bl.map(x => x.key) };
            if (!gs.has(b0.cat)) gs.set(b0.cat, []);
            gs.get(b0.cat).push(row);
        }
        const out = [];
        for (const [name, rows] of gs) {
            // pair merges inside a category
            const used = new Set(), merged = [];
            for (let i = 0; i < rows.length; i++) {
                if (used.has(i)) continue;
                const a = rows[i];
                let m = null;
                for (let j = i + 1; j < rows.length && !a.merged && !m; j++) {
                    const b = rows[j];
                    if (used.has(j) || b.merged || a.chord.sup !== b.chord.sup || a.chord.mods.join() !== b.chord.mods.join()) continue;
                    const p = pairText(a.text, b.text);
                    if (!p) continue;
                    const x = p.sFirst ? a : b, y = p.sFirst ? b : a;
                    m = Object.assign({}, a, { text: p.text, hot: a.hot || b.hot, dup: a.dup || b.dup, merged: true,
                        extra: a.extra && b.extra, keys: x.keys.concat(y.keys),
                        chord: Object.assign({}, a.chord, { key: joinKeys(x.chord.key, y.chord.key) }) });
                    used.add(j);
                }
                merged.push(m ?? a);
            }
            for (const r of merged)
                r.hay = (name + " " + r.text + " " + (r.chord.sup ? "super " : "") + r.chord.mods.join(" ") + " "
                         + r.chord.key + " " + r.keys.join(" ")).toLowerCase();
            out.push({ name, rows: merged });
        }
        return out.sort((a, b) => (order.indexOf(a.name) + 1 || 99) - (order.indexOf(b.name) + 1 || 99));
    }

    // By key: one row per key, columns Super / +Shift / +Alt / +Ctrl (keyboard keys only)
    function buildMatrix(bs) {
        const colOf = { 0: 0, 1: 1, 8: 2, 4: 3 };
        const rows = new Map();
        for (const b of bs) {
            if (!(b.mods & 64) || isExtraKey(b.key)) continue;
            const c = colOf[b.mods & ~64];
            if (c === undefined) continue;
            if (!rows.has(b.key)) rows.set(b.key, { label: keyLabel(b.key), keys: [b.key], cells: [[], [], [], []] });
            rows.get(b.key).cells[c].push(b);
        }
        const cellText = l => l.length === 0 ? "" : [...new Set(l.map(x => shortText(x.cat, x.text)))].join(" / ");
        // families (1…0, arrows): what all members share becomes one row, the rest stays per key
        for (const [fam, label] of [[["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"], "1…0"], [["left", "up", "right", "down"], "←↑→↓"]]) {
            const ms = fam.filter(k => rows.has(k)).map(k => rows.get(k));
            if (ms.length < 2) continue;
            const famRow = { label, keys: fam, cells: [[], [], [], []] };
            for (let c = 0; c < 4; c++) {
                const t = cellText(ms[0].cells[c]);
                if (t && ms.length === fam.length && ms.every(m => cellText(m.cells[c]) === t)) {
                    famRow.cells[c] = ms[0].cells[c];
                    for (const m of ms) m.cells[c] = [];
                }
            }
            if (famRow.cells.some(l => l.length)) rows.set("@" + label, famRow);
        }
        const rank = r => /^[A-Z]$/.test(r.label) ? 0 : r.label === "1…0" ? 1 : /^[0-9]$/.test(r.label) ? 2 : r.label === "←↑→↓" ? 4 : 3;
        const colNames = ["super", "super shift", "super alt", "super ctrl"];
        return [...rows.values()]
            .filter(r => r.cells.some(l => l.length))
            .sort((a, b) => rank(a) - rank(b) || a.label.localeCompare(b.label))
            .map(r => {
                const cells = r.cells.map(l => l.length ? { text: cellText(l), dup: l.some(x => x.dup) } : null);
                const hay = (r.label + " " + r.keys.join(" ") + " "
                             + cells.map((c, i) => c ? colNames[i] + " " + c.text + " " + r.cells[i].map(x => x.cat).join(" ") : "").join(" ")).toLowerCase();
                return { label: r.label, cells, hay };
            });
    }

    // keyboard map layer: keyId -> { text, dup, on }
    function layerFor(mask) {
        const out = {};
        for (const b of binds) {
            if (b.mods !== mask) continue;
            const t = shortText(b.cat, b.text), hay = (b.cat + " " + b.text + " " + b.key).toLowerCase();
            const e = out[b.id];
            if (!e) out[b.id] = { texts: [t], dup: b.dup, on: matches(hay) };
            else {
                if (!e.texts.includes(t)) e.texts.push(t);
                e.dup = e.dup || b.dup; e.on = e.on || matches(hay);
            }
        }
        for (const id in out) out[id].text = out[id].texts.join(" / ");
        return out;
    }
    readonly property var layer: { query; binds; return layerFor(layerMask) }

    // ------------------------------------------------------------------ filtered views
    readonly property var fnGroups: {
        if (query.trim() === "") return groups;
        const out = [];
        for (const g of groups) {
            const rows = g.rows.filter(r => matches(r.hay));
            if (rows.length) out.push({ name: g.name, rows });
        }
        return out;
    }
    readonly property var mxRowsF: query.trim() === "" ? mxRows : mxRows.filter(r => matches(r.hay))
    // binds that don't fit the matrix: three-key chords, Super + mouse/media, no Super at all
    function extrasOf(gs) {
        const tri = [], mm = [], ns = [];
        for (const g of gs) for (const r of g.rows) {
            if (!r.chord.sup) ns.push(r);
            else if (r.chord.mods.length >= 2) tri.push(r);
            else if (r.extra) mm.push(r);
        }
        const out = [];
        for (const [title, icon, rs] of [["3-key chords", "\u{f030c}", tri], ["Mouse & media", "\u{f037d}", mm], ["Without Super", arch, ns]])
            if (rs.length) { out.push({ head: title, icon }); for (const r of rs) out.push({ row: r }); }
        return out;
    }
    readonly property var extras: extrasOf(groups)
    readonly property var extrasF: query.trim() === "" ? extras : extrasOf(fnGroups)

    // contiguous split of groups into n columns with the lowest tallest column
    function groupH(g) { return lay.hdr + g.rows.length * lay.rowH }
    function partition(gs, n) {
        const k = gs.length;
        if (k === 0) return [];
        n = Math.min(n, k);
        const pre = [0];
        for (const g of gs) pre.push(pre[pre.length - 1] + groupH(g));
        const span = (i, j) => pre[j] - pre[i] + lay.ggap * (j - i - 1);
        // best[c][j]: first j groups in c columns -> [max height, split index]
        const best = [[[0, 0]]];
        for (let j = 1; j <= k; j++) best[0][j] = [Infinity, 0];
        for (let c = 1; c <= n; c++) {
            best[c] = [[0, 0]];
            for (let j = 1; j <= k; j++) {
                let b = [Infinity, 0];
                for (let i = c - 1; i < j; i++) {
                    const v = Math.max(best[c - 1][i][0], span(i, j));
                    if (v < b[0]) b = [v, i];
                }
                best[c][j] = b;
            }
        }
        const cols = [];
        let j = k;
        for (let c = n; c >= 1; c--) { const i = best[c][j][1]; cols.unshift(gs.slice(i, j)); j = i; }
        return cols.filter(c => c.length);
    }
    function colsHeight(cols) {
        let m = 0;
        for (const c of cols) m = Math.max(m, c.reduce((s, g) => s + groupH(g), 0) + lay.ggap * (c.length - 1));
        return m;
    }
    // extras: entries column-major over n columns, never a heading at the bottom of a column
    function splitEntries(es, n) {
        const per = Math.max(1, Math.ceil(es.length / n));
        const cols = [[]];
        for (let i = 0; i < es.length; i++) {
            let cur = cols[cols.length - 1];
            const full = cur.length >= per || (es[i].head && cur.length >= per - 1 && cur.length > 0);
            if (full && cols.length < n) { cur = []; cols.push(cur); }
            cur.push(es[i]);
        }
        return cols;
    }

    // layout constants (natural size; the whole sheet is scaled down to fit small screens)
    readonly property QtObject lay: QtObject {
        // short screens (1080p laptop at 1.25 = 864 logical): tighter rows so less scaling is needed
        readonly property bool compact: panel.height < 1000
        readonly property int pad: compact ? 24 : 32
        readonly property int colW: 380
        readonly property int gap: 40
        readonly property int rowH: compact ? 27 : 32
        readonly property int hdr: compact ? 34 : 38
        readonly property int ggap: compact ? 10 : 16
        readonly property int segH: 22
        readonly property real kbPitch: 50
        readonly property int kbKeyH: 42
        readonly property int kbRowP: 46
        readonly property int bandH: 4 * kbRowP + kbKeyH
        readonly property int mxHead: 34
        readonly property int mxRowH: compact ? 23 : 26
        readonly property int mxKeyW: 84
        readonly property int exRowH: compact ? 25 : 28
        readonly property int foot: 22
    }
    function contentW(n) { return Math.max(n * lay.colW + (n - 1) * lay.gap, 18.5 * lay.kbPitch + 32 + 600) }
    function mxHeight(n) {
        const half = Math.ceil(mxRows.length / 2);
        const per = splitEntries(extras, n).reduce((m, c) => Math.max(m, c.length), 0);
        return lay.mxHead + half * lay.mxRowH + (per ? 24 + per * lay.exRowH : 0);
    }
    function contentH(n) { return Math.max(colsHeight(partition(groups, n)), mxHeight(n), 200) }
    function natW(n) { return 2 * lay.pad + contentW(n) }
    function natH(n) { return 2 * lay.pad + lay.bandH + 26 + contentH(n) + 18 + lay.foot }

    // ------------------------------------------------------------------ open / close
    Process {
        id: fetch
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { root.build(JSON.parse(text)) } catch (e) {} } }
    }
    Timer { id: delay; interval: 0; onTriggered: if (root.held && !root.pinned) { fetch.running = true; root.shown = true } }

    function peek() {
        if (pinned) return;
        if (!shown) resetMods();
        held = true; delay.restart();
    }
    function hidePeek() {
        if (pinned) return;
        held = false; shown = false; delay.stop(); resetMods();
    }
    function pin() {
        held = false; delay.stop();
        if (!shown) fetch.running = true;
        resetMods();
        query = "";
        pinned = true; shown = true;
    }
    function close() {
        pinned = false; held = false; shown = false; query = ""; delay.stop(); resetMods();
    }
    function togglePin() { if (pinned) close(); else pin() }

    GlobalShortcut { appid: "ruboshapes"; name: "keys-show"; onPressed: root.peek() }
    // Hyprland sends "released" instead of "pressed" when the dispatch happens outside a key press,
    // so the hide / modifier events are handled the same either way
    GlobalShortcut { appid: "ruboshapes"; name: "keys-hide"; onPressed: root.hidePeek(); onReleased: root.hidePeek() }
    GlobalShortcut { appid: "ruboshapes"; name: "keys-shift-down"; onPressed: root.mShift = true; onReleased: root.mShift = true }
    GlobalShortcut { appid: "ruboshapes"; name: "keys-shift-up"; onPressed: root.mShift = false; onReleased: root.mShift = false }
    GlobalShortcut { appid: "ruboshapes"; name: "keys-ctrl-down"; onPressed: root.mCtrl = true; onReleased: root.mCtrl = true }
    GlobalShortcut { appid: "ruboshapes"; name: "keys-ctrl-up"; onPressed: root.mCtrl = false; onReleased: root.mCtrl = false }
    GlobalShortcut { appid: "ruboshapes"; name: "keys-alt-down"; onPressed: root.mAlt = true; onReleased: root.mAlt = true }
    GlobalShortcut { appid: "ruboshapes"; name: "keys-alt-up"; onPressed: root.mAlt = false; onReleased: root.mAlt = false }
    // Super+K: a real key press sends pressed (+ maybe released later), a dispatch outside a key press
    // only released -> toggle once per press
    property bool pinPressSeen: false
    GlobalShortcut { appid: "ruboshapes"; name: "keys-pin"
        onPressed: { root.pinPressSeen = true; root.togglePin() }
        onReleased: { if (root.pinPressSeen) root.pinPressSeen = false; else root.togglePin() } }

    // a Super combo actually did something -> no cheat sheet (peek only)
    Connections {
        target: Hyprland
        function onRawEvent(e) {
            if (root.held && !root.pinned && ["activewindow", "workspace", "openwindow", "closewindow", "movewindow", "focusedmon",
                              "fullscreen", "changefloatingmode"].includes(e.name))
                root.hidePeek();
        }
    }

    // ------------------------------------------------------------------ window
    PanelWindow {
        id: panel
        visible: root.shown || fadeAnim.running
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "ruboshapes-keys"
        WlrLayershell.keyboardFocus: root.pinned ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"
        // peek never takes input (Super combos keep working); pinned takes the whole screen
        property Region noInput: Region {}
        mask: root.pinned ? null : noInput

        // the grab starts a moment after pinning: activated together with the input region / keyboard focus
        // change of an already mapped (peek) surface, Hyprland clears it right away
        property bool grabReady: false
        Timer { interval: 150; running: root.pinned; onTriggered: panel.grabReady = true }
        Connections { target: root; function onPinnedChanged() { if (!root.pinned) panel.grabReady = false } }
        HyprlandFocusGrab { windows: [panel]; active: root.pinned && panel.grabReady && panel.visible; onCleared: if (root.pinned) root.close() }

        // layout choice: the column count that needs the least scaling on this screen
        readonly property real availW: width - 48
        readonly property real availH: height - 48
        function fitFor(n) { return Math.min(1, availW / root.natW(n), availH / root.natH(n)) }
        readonly property int ncol: {
            root.groups; root.mxRows;
            let best = 4, bs = -1;
            for (const n of [4, 5, 3]) { const s = fitFor(n); if (s > bs + 0.005) { best = n; bs = s } }
            return best;
        }
        readonly property real fit: fitFor(ncol)

        MouseArea {     // click outside the sheet closes it (pinned)
            anchors.fill: parent
            enabled: root.pinned
            onClicked: m => {
                const p = mapToItem(frame, m.x, m.y);
                if (p.x < 0 || p.y < 0 || p.x > frame.width || p.y > frame.height) root.close();
            }
        }

        Item {
            id: keyTarget
            anchors.fill: parent
            focus: true
            Connections { target: root; function onPinnedChanged() { if (root.pinned) keyTarget.forceActiveFocus() } }
            function syncMods(e) {
                root.mShift = !!(e.modifiers & Qt.ShiftModifier);
                root.mCtrl = !!(e.modifiers & Qt.ControlModifier);
                root.mAlt = !!(e.modifiers & Qt.AltModifier);
                root.mSuper = !!(e.modifiers & Qt.MetaModifier);
            }
            function modKey(e, down) {
                switch (e.key) {
                case Qt.Key_Shift: root.mShift = down; return true;
                case Qt.Key_Control: root.mCtrl = down; return true;
                case Qt.Key_Alt: case Qt.Key_AltGr: root.mAlt = down; return true;
                case Qt.Key_Meta: case Qt.Key_Super_L: case Qt.Key_Super_R: root.mSuper = down; return true;
                }
                return false;
            }
            Keys.onReleased: e => { if (root.pinned && modKey(e, false)) e.accepted = true }
            Keys.onPressed: e => {
                if (!root.pinned) return;
                const ok = () => { e.accepted = true };
                if (modKey(e, true)) { ok(); return }
                syncMods(e);
                if (e.key === Qt.Key_Escape) { root.close(); ok() }
                else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) { root.tab = root.tab === "fn" ? "key" : "fn"; ok() }
                else if (e.key === Qt.Key_Backspace) {
                    root.query = (e.modifiers & Qt.ControlModifier) ? root.query.replace(/\S*\s*$/, "") : root.query.slice(0, -1);
                    ok();
                }
                else if (e.text && e.text.length === 1 && e.text >= " " && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                    root.query += e.text; ok();
                }
            }
        }

        Rectangle {
            id: frame
            anchors.centerIn: parent
            readonly property int n: panel.ncol
            readonly property real cw: root.contentW(n)
            readonly property real colW: (cw - (n - 1) * root.lay.gap) / n
            readonly property real ch: root.contentH(n)
            width: root.natW(n)
            height: root.natH(n)
            radius: 18
            color: root.pal.ovPanel
            opacity: root.shown ? 1 : 0
            scale: panel.fit * (root.shown ? 1 : 0.97)
            Behavior on opacity { NumberAnimation { id: fadeAnim; duration: 140 } }

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

            // ---------------- band: title, search, tabs, layer | keyboard map
            Item {
                id: band
                x: root.lay.pad; y: root.lay.pad
                width: frame.cw; height: root.lay.bandH

                KeyboardMap {
                    id: kbd
                    x: band.width - width
                    pal: root.pal; fg: root.fg; fg2: root.fg2; acc: root.acc; warn: root.warn
                    pitch: root.lay.kbPitch; keyH: root.lay.kbKeyH; rowP: root.lay.kbRowP
                    mask: root.layerMask
                    acts: root.layer
                }

                Column {
                    id: leftCol
                    width: band.width - kbd.width - 36
                    spacing: (band.height - 34 - 38 - 38 - 20) / 3

                    Item {      // title rail + legend
                        width: leftCol.width; height: 34
                        ArrowSegs {
                            h: 34; arr: 14; radius: 0; padFirst: 14; padNext: 10; padEnd: 12
                            family: Theme.sans
                            parts: [
                                { fill: root.pal.ovCap, text: root.arch, color: root.acc, family: Theme.monoIcons, size: 18, bold: false },
                                { fill: root.pal.mid, text: "KEYBINDS", color: root.pal.text, size: 14, spacing: 1.6 },
                                { fill: root.pal.inner, text: root.pinned ? "pinned · Esc closes" : "release Super to close",
                                  color: root.pal.light ? root.pal.text : root.acc, size: 12, spacing: 0.6 }
                            ]
                        }
                        Row {       // legend
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            spacing: 14
                            Repeater {
                                model: [[root.pal.ovCap, "Super"], [root.pal.mid, "modifiers"], [root.pal.inner, "key"]]
                                Row {
                                    required property var modelData
                                    spacing: 6
                                    ArrowSegs { h: 14; arr: 6; radius: 2; padFirst: 9; padEnd: 0; anchors.verticalCenter: parent.verticalCenter
                                        parts: [{ fill: modelData[0], text: "", color: "transparent" }] }
                                    Text { text: modelData[1]; font.family: Theme.sans; font.pixelSize: 12; color: root.fg2
                                        anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                        }
                    }

                    Rectangle {     // search field
                        width: leftCol.width; height: 38; radius: 19
                        color: root.pal.ovWell
                        border.width: 1
                        border.color: root.query !== "" ? Qt.alpha(Theme.border1, 0.75) : root.pinned ? Qt.alpha(root.acc, 0.35) : root.pal.ovStroke
                        opacity: root.pinned ? 1 : 0.6
                        Row {
                            x: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                            Text { text: "\u{f002}"; font.family: Theme.monoIcons; font.pixelSize: 14; color: root.acc; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: root.query; visible: root.query !== ""; font.family: Theme.mono; font.pixelSize: 15; color: root.fg
                                anchors.verticalCenter: parent.verticalCenter }
                            Rectangle { visible: root.pinned; width: 2; height: 18; radius: 1; color: root.acc; anchors.verticalCenter: parent.verticalCenter
                                SequentialAnimation on opacity { loops: Animation.Infinite; running: root.pinned
                                    NumberAnimation { to: 0; duration: 500 } NumberAnimation { to: 1; duration: 500 } } }
                            Text { visible: root.query === ""
                                text: root.pinned ? "type to filter — e.g. “scr”, “monitor”, “shift”" : "Super+K to search"
                                font.family: Theme.sans; font.pixelSize: 14; color: root.fg2; opacity: 0.7
                                anchors.verticalCenter: parent.verticalCenter }
                        }
                        Text { anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                            visible: root.pinned
                            text: root.query === "" ? "Esc" : (root.tab === "fn" ? root.fnGroups.reduce((s, g) => s + g.rows.length, 0) + " found"
                                                                                 : root.mxRowsF.length + " keys")
                            font.family: Theme.mono; font.pixelSize: 12; font.weight: Font.Bold; color: root.acc; opacity: 0.85 }
                    }

                    Item {      // tabs + current layer
                        width: leftCol.width; height: 38
                        Rectangle {     // segmented control (as in Switcher)
                            id: tabs
                            width: tabRow.implicitWidth + 8; height: 38; radius: 19
                            color: root.pal.ovWell
                            border.width: 1; border.color: root.pal.ovStroke
                            Rectangle {
                                y: 4; height: 30; radius: 15
                                x: 4 + (root.tab === "fn" ? 0 : tabFn.width)
                                width: root.tab === "fn" ? tabFn.width : tabKey.width
                                color: root.pal.pill
                                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            }
                            Row {
                                id: tabRow
                                x: 4; y: 4
                                Tab { id: tabFn; icon: "\u{f0279}"; label: "By function"; on: root.tab === "fn"; onClicked: root.tab = "fn" }
                                Tab { id: tabKey; icon: "\u{f030c}"; label: "By key"; on: root.tab === "key"; onClicked: root.tab = "key" }
                            }
                        }
                        Row {       // the layer the keyboard map shows
                            x: tabs.width + 22
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Text { text: "LAYER"; font.family: Theme.sans; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1.4
                                color: root.acc; anchors.verticalCenter: parent.verticalCenter }
                            ArrowSegs {
                                anchors.verticalCenter: parent.verticalCenter
                                h: 24; size: 12
                                parts: {
                                    const c = root.chordOf({ mods: root.layerMask, key: "" });
                                    const p = [];
                                    if (c.sup) p.push({ fill: root.pal.ovCap, text: root.arch, color: root.acc, family: Theme.monoIcons, size: 15, bold: false });
                                    if (c.mods.length) p.push({ fill: root.pal.mid, text: c.mods.join(" "), color: root.pal.text });
                                    p.push({ fill: root.pal.inner, text: "key", color: root.pal.text, bold: false });
                                    return p;
                                }
                            }
                        }
                    }

                    Text {
                        width: leftCol.width; height: 20
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: root.pinned ? "Hold Super / Shift / Ctrl / Alt to light up that layer  ·  Tab switches view  ·  Backspace edits"
                                          : "Add Shift / Ctrl / Alt to light up that layer  ·  Super+K keeps the sheet open"
                        font.family: Theme.sans; font.pixelSize: 12; color: root.fg2; opacity: 0.75
                    }
                }
            }

            Rectangle {     // divider
                x: root.lay.pad; y: band.y + band.height + 12
                width: frame.cw; height: 1
                gradient: Gradient { orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.alpha(root.acc, 0) }
                    GradientStop { position: 0.5; color: Qt.alpha(root.acc, 0.25) }
                    GradientStop { position: 1; color: Qt.alpha(root.acc, 0) } }
            }

            // ---------------- content
            Item {
                id: content
                x: root.lay.pad; y: band.y + band.height + 26
                width: frame.cw; height: frame.ch

                Text {
                    visible: root.query !== "" && (root.tab === "fn" ? root.fnGroups.length === 0 : root.mxRowsF.length === 0 && root.extrasF.length === 0)
                    anchors.centerIn: parent
                    text: "Nothing bound matches “" + root.query + "”"
                    font.family: Theme.sans; font.pixelSize: 15; color: root.fg2
                }

                Row {       // by function
                    visible: root.tab === "fn"
                    spacing: root.lay.gap
                    Repeater {
                        model: root.partition(root.fnGroups, frame.n)
                        Column {
                            required property var modelData
                            width: frame.colW
                            spacing: root.lay.ggap
                            Repeater {
                                model: modelData
                                Group { width: frame.colW }
                            }
                        }
                    }
                }

                Item {      // by key
                    visible: root.tab === "key"
                    anchors.fill: parent
                    readonly property real tblW: (width - root.lay.gap) / 2
                    readonly property int half: Math.ceil(root.mxRowsF.length / 2)
                    readonly property int activeCol: ({ 64: 0, 65: 1, 72: 2, 68: 3 })[root.layerMask] ?? -1
                    id: mx
                    Row {
                        id: tables
                        spacing: root.lay.gap
                        Repeater {
                            model: [root.mxRowsF.slice(0, mx.half), root.mxRowsF.slice(mx.half)]
                            Matrix { width: mx.tblW; rows: modelData; activeCol: mx.activeCol }
                        }
                    }
                    Row {       // extras
                        y: root.lay.mxHead + Math.ceil(root.mxRows.length / 2) * root.lay.mxRowH + 24
                        spacing: root.lay.gap
                        Repeater {
                            model: root.splitEntries(root.extrasF, frame.n)
                            Column {
                                required property var modelData
                                width: frame.colW
                                Repeater {
                                    model: modelData
                                    Item {
                                        id: ex
                                        required property var modelData
                                        width: frame.colW; height: root.lay.exRowH
                                        ArrowSegs {
                                            visible: !!ex.modelData.head
                                            anchors.verticalCenter: parent.verticalCenter
                                            h: 20; arr: 8; radius: 0; padFirst: 8; padNext: 7; padEnd: 8; family: Theme.sans
                                            parts: ex.modelData.head ? [
                                                { fill: root.pal.ovCap, text: ex.modelData.icon, color: root.acc, family: Theme.monoIcons, size: 12, bold: false },
                                                { fill: root.pal.mid, text: ex.modelData.head.toUpperCase(), color: root.pal.text, size: 10, spacing: 1.3 }] : []
                                        }
                                        BindRow { visible: !ex.modelData.head; row: ex.modelData.row ?? null; width: frame.colW; height: root.lay.exRowH; small: true }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---------------- footer: duplicates
            Row {
                x: root.lay.pad; y: frame.height - root.lay.pad - root.lay.foot + 6
                spacing: 8
                visible: root.dupNotes.length > 0
                Text { text: "\u{f0026}"; font.family: Theme.monoIcons; font.pixelSize: 13; color: root.warn; anchors.verticalCenter: parent.verticalCenter }
                Text { text: root.dupNotes.join("   ·   "); font.family: Theme.sans; font.pixelSize: 12; color: root.warn; anchors.verticalCenter: parent.verticalCenter }
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: root.lay.pad
                y: frame.height - root.lay.pad - root.lay.foot + 6
                text: root.pinned ? "Tab  view   ·   Esc  close" : "1–10 · arrows · pairs are merged into single rows"
                font.family: Theme.sans; font.pixelSize: 12; color: root.fg2; opacity: 0.6
            }
        }
    }

    // ------------------------------------------------------------------ pieces
    function chordParts(c, size) {
        const p = [];
        if (c.sup) p.push({ fill: pal.ovCap, text: arch, color: acc, family: Theme.monoIcons, size: size + 3, bold: false });
        if (c.mods.length) p.push({ fill: pal.mid, text: c.mods.join(" "), color: pal.text });
        p.push({ fill: pal.inner, text: c.key, color: pal.text });
        return p;
    }

    component Tab: Item {
        id: tab
        property string icon
        property string label
        property bool on
        signal clicked()
        width: tabInner.implicitWidth + 28; height: 30
        Row {
            id: tabInner
            anchors.centerIn: parent; spacing: 7
            Text { text: tab.icon; font.family: Theme.monoIcons; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter
                color: tab.on ? root.pal.pillText : root.fg2 }
            Text { text: tab.label; font.family: Theme.sans; font.pixelSize: 13; font.weight: tab.on ? Font.Bold : Font.Normal
                anchors.verticalCenter: parent.verticalCenter; color: tab.on ? root.pal.pillText : root.fg2 }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tab.clicked() }
    }

    // one action row: text left, chord right-aligned (small: chord first, for the extras list)
    component BindRow: Item {
        id: br
        property var row
        property bool small: false
        readonly property int sz: small ? 11 : 12
        ArrowSegs {
            id: chordSegs
            x: br.small ? 0 : br.width - width
            anchors.verticalCenter: parent.verticalCenter
            h: br.small ? 20 : root.lay.segH; size: br.sz; arr: br.small ? 7 : 8
            parts: br.row ? root.chordParts(br.row.chord, br.sz) : []
        }
        Row {
            x: br.small ? chordSegs.width + 8 : 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text {
                id: desc
                width: Math.min(implicitWidth, br.width - chordSegs.width - 12 - (br.row?.dup ? 20 : 0))
                elide: Text.ElideRight
                text: br.row?.text ?? ""
                font.family: Theme.sans; font.pixelSize: br.small ? 13 : 14
                font.weight: br.row?.hot && !br.small ? Font.DemiBold : Font.Normal
                color: br.row?.dup ? root.warn : br.row?.hot ? root.fg : root.fg2
            }
            Text { visible: !!br.row?.dup; text: "\u{f0026}"; font.family: Theme.monoIcons; font.pixelSize: 13; color: root.warn
                anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // category block: arrow rail heading + rows
    component Group: Column {
        id: grp
        required property var modelData
        Item {
            width: grp.width; height: root.lay.hdr
            ArrowSegs {
                id: rail
                y: 2
                h: 24; arr: 10; radius: 0; padFirst: 10; padNext: 9; padEnd: 10; family: Theme.sans
                parts: [{ fill: root.pal.ovCap, text: root.icons[grp.modelData.name] ?? "\u{f030c}", color: root.acc, family: Theme.monoIcons, size: 14, bold: false },
                        { fill: root.pal.mid, text: grp.modelData.name.toUpperCase(), color: root.pal.text, size: 11, spacing: 1.4 }]
            }
            Rectangle {
                x: rail.width + 8; y: rail.y + 11; height: 2
                width: grp.width - x
                gradient: Gradient { orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: root.pal.inner }
                    GradientStop { position: 1; color: Qt.alpha(root.pal.inner, 0) } }
            }
        }
        Repeater {
            model: grp.modelData.rows
            BindRow { required property var modelData; row: modelData; width: grp.width; height: root.lay.rowH }
        }
    }

    // by-key table: key | Super | +Shift | +Alt | +Ctrl
    component Matrix: Item {
        id: mt
        property var rows: []
        property int activeCol: -1
        readonly property real cellW: (width - root.lay.mxKeyW) / 4
        height: root.lay.mxHead + rows.length * root.lay.mxRowH
        Rectangle {     // column of the layer currently held
            visible: mt.activeCol >= 0
            x: root.lay.mxKeyW + mt.activeCol * mt.cellW; width: mt.cellW
            height: root.lay.mxHead + Math.max(mt.rows.length, 1) * root.lay.mxRowH
            radius: 8
            color: Qt.alpha(root.pal.mid, 0.16)
            Behavior on x { NumberAnimation { duration: 120 } }
        }
        Repeater {      // header
            model: ["Super", "Shift", "Alt", "Ctrl"]
            Row {
                required property string modelData
                required property int index
                x: root.lay.mxKeyW + index * mt.cellW + 8
                height: root.lay.mxHead
                spacing: 6
                Text { visible: index > 0; text: "+"; font.family: Theme.sans; font.pixelSize: 13; font.weight: Font.Bold; color: root.acc
                    anchors.verticalCenter: parent.verticalCenter }
                ArrowSegs {
                    anchors.verticalCenter: parent.verticalCenter
                    h: 20; size: 11; arr: 7
                    parts: index === 0 ? [{ fill: root.pal.ovCap, text: root.arch, color: root.acc, family: Theme.monoIcons, size: 14, bold: false }]
                                       : [{ fill: root.pal.mid, text: modelData, color: root.pal.text }]
                }
                Text { visible: index === 0; text: "Super"; font.family: Theme.sans; font.pixelSize: 13; font.weight: Font.Bold; color: root.fg
                    anchors.verticalCenter: parent.verticalCenter }
            }
        }
        Repeater {
            model: mt.rows
            Item {
                id: mr
                required property var modelData
                required property int index
                y: root.lay.mxHead + index * root.lay.mxRowH
                width: mt.width; height: root.lay.mxRowH
                Rectangle { anchors.fill: parent; radius: 6; visible: mr.index % 2 === 0; color: root.pal.ovStripe }
                ArrowSegs {
                    x: 6; anchors.verticalCenter: parent.verticalCenter
                    h: 20; size: 11; arr: 7
                    parts: [{ fill: root.pal.inner, text: mr.modelData.label, color: root.pal.text }]
                }
                Repeater {
                    model: mr.modelData.cells
                    Row {
                        id: cell
                        required property var modelData
                        required property int index
                        x: root.lay.mxKeyW + index * mt.cellW + 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        Text {
                            width: Math.min(implicitWidth, mt.cellW - 18 - (cell.modelData?.dup ? 18 : 0))
                            elide: Text.ElideRight
                            text: cell.modelData ? cell.modelData.text : "·"
                            font.family: Theme.sans; font.pixelSize: 13
                            font.weight: cell.index === 0 && cell.modelData ? Font.DemiBold : Font.Normal
                            color: cell.modelData?.dup ? root.warn : !cell.modelData ? root.fg2 : cell.index === 0 ? root.fg : root.fg2
                            opacity: !cell.modelData ? 0.35 : 1
                        }
                        Text { visible: !!cell.modelData?.dup; text: "\u{f0026}"; font.family: Theme.monoIcons; font.pixelSize: 12; color: root.warn
                            anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
}
