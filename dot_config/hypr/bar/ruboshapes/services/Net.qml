pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string type: "none"
    property string name: ""
    property int signal: 0
    Process { id: p; command: [Quickshell.shellDir + "/scripts/net.sh"]; running: true
        stdout: StdioCollector { onStreamFinished: { try { const d = JSON.parse(text); root.type = d.type; root.name = d.name; root.signal = d.signal } catch (e) {} } } }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: p.running = true }
}
