pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Per-monitor brightness via the DDC/CI helper (serial pins, coalesced writes).
Singleton {
    id: root
    readonly property string helper: Quickshell.shellDir + "/scripts/brightness.py"
    property var values: ({})          // { "DP-1": 15, ... }

    function step(mon, up) {
        const cur = values[mon] ?? 50;
        const next = up ? (Math.floor(cur / 5) + 1) * 5 : (Math.ceil(cur / 5) - 1) * 5;
        set(mon, next);
    }
    function set(mon, v) {
        v = Math.max(0, Math.min(100, Math.round(v)));
        const o = Object.assign({}, values); o[mon] = v; values = o;     // instant UI
        Quickshell.execDetached(["python3", helper, "set", mon, String(v)]);
    }

    Process { id: get; command: ["python3", root.helper, "get"]; running: true
        stdout: StdioCollector { onStreamFinished: { try { root.values = JSON.parse(text) } catch (e) {} } } }
    Timer { interval: 120000; running: true; repeat: true; onTriggered: get.running = true }
}
