pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Caelestia owns notifications: count = entries in its store, DND via its IPC.
Singleton {
    id: root
    property int count: 0
    property bool dnd: false

    FileView { path: Quickshell.env("HOME") + "/.local/state/caelestia/notifs.json"
        watchChanges: true; onFileChanged: reload()
        onLoaded: { try { root.count = JSON.parse(text()).length } catch (e) { root.count = 0 } } }
    Process { id: dndq; command: ["qs", "-c", "caelestia", "ipc", "call", "notifs", "isDndEnabled"]; running: true
        stdout: StdioCollector { onStreamFinished: root.dnd = text.trim() === "true" } }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: dndq.running = true }

    function toggleDnd() { Quickshell.execDetached(["qs", "-c", "caelestia", "ipc", "call", "notifs", "toggleDnd"]); dnd = !dnd }
    function clear() { Quickshell.execDetached(["qs", "-c", "caelestia", "ipc", "call", "notifs", "clear"]) }
}
