pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Touchpad workspace swipe progress (scripts/swipe.py replays Hyprland's swipe maths from libinput),
// so Workspaces.qml can move the pill 1:1 with the fingers. Without a touchpad the helper just exits.
Singleton {
    id: root
    property string monitor: ""     // output being swiped ("" = no swipe)
    property int startId: -1        // workspace the swipe started on
    property real progress: 0       // -1..1, negative = previous workspace
    property bool dragging: false   // fingers down: follow directly, no animations
    readonly property bool active: monitor !== ""

    // After lifting the fingers, keep the swipe state until the workspace changes (Workspaces.qml
    // calls done()) or, if Hyprland cancelled the swipe, until this runs out and the pill springs back.
    Timer { id: settle; interval: 250; onTriggered: root.done() }

    function done() {
        settle.stop();
        dragging = false;
        monitor = "";
        progress = 0;
        startId = -1;
    }

    Process {
        command: ["python3", Quickshell.shellDir + "/scripts/swipe.py"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                const p = line.split(" ");
                if (p[0] === "begin") {
                    settle.stop();
                    root.progress = 0;
                    root.startId = parseInt(p[2]);
                    root.monitor = p[1];
                    root.dragging = true;
                } else if (p[0] === "p" && root.dragging) {
                    root.progress = parseFloat(p[1]);
                } else if (p[0] === "end" && root.dragging) {
                    root.dragging = false;
                    settle.restart();
                }
            }
        }
    }
}
