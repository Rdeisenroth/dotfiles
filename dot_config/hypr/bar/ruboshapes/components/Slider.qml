import QtQuick
import qs.services

// Thin hover slider (volume / brightness). Emits moved(value 0..1) while dragging or on click.
Item {
    property var pal: Schemes.pal("")
    id: root
    property real value: 0
    signal moved(real v)
    implicitWidth: 80; implicitHeight: Theme.h   // track 5..75 + knob radius
    Rectangle { id: track; x: 5; width: 70;   // close to the label (it has a fixed width with spare room)
        height: 4; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(1, 1, 1, 0.2)
        Rectangle { width: track.width * Math.min(root.value, 1); height: 4; radius: 2; color: pal.accent }
        Rectangle { x: track.width * Math.min(root.value, 1) - 5; anchors.verticalCenter: parent.verticalCenter
            width: 10; height: 10; radius: 5; color: pal.text } }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
        function at(mx) { return Math.max(0, Math.min(1, (mx - track.x) / track.width)) }
        onPressed: e => root.moved(at(e.x)); onPositionChanged: e => { if (pressed) root.moved(at(e.x)) } }
}
