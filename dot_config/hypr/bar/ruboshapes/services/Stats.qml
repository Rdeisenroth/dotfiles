pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU (total + per core) and RAM usage, sampled once a second, last 60 s kept for the inline charts.
Singleton {
    id: root
    readonly property int keep: 60
    property real cpu: 0
    property var cpuHist: []
    property var cores: []            // current per-core load 0..100
    property real memUsed: 0          // bytes
    property real memTotal: 1
    property var memHist: []
    property var _prev: ({})

    function push(arr, v) { const a = arr.concat([v]); return a.length > keep ? a.slice(a.length - keep) : a }

    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { stat.reload(); mem.reload() } }

    FileView { id: stat; path: "/proc/stat"
        onLoaded: {
            const lines = text().split("\n");
            const cores = [];
            for (const line of lines) {
                if (!line.startsWith("cpu")) break;
                const p = line.trim().split(/\s+/);
                const v = p.slice(1).map(Number);
                const total = v.reduce((a, b) => a + b, 0), idle = v[3] + v[4];
                const prev = root._prev[p[0]] ?? [total, idle];
                const dt = total - prev[0];
                const use = dt > 0 ? 100 * (1 - (idle - prev[1]) / dt) : 0;
                root._prev[p[0]] = [total, idle];
                if (p[0] === "cpu") { root.cpu = use; root.cpuHist = root.push(root.cpuHist, use) }
                else cores.push(use);
            }
            root.cores = cores;
        }
    }
    FileView { id: mem; path: "/proc/meminfo"
        onLoaded: {
            const m = {};
            for (const line of text().split("\n")) {
                const [k, v] = line.split(":");
                if (v) m[k] = parseInt(v) * 1024;
            }
            root.memTotal = m.MemTotal; root.memUsed = m.MemTotal - m.MemAvailable;
            root.memHist = root.push(root.memHist, 100 * root.memUsed / root.memTotal);
        }
    }
}
