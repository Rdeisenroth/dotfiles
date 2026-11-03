import QtQuick
import qs.services

// Thin hover slider (volume / brightness). Emits moved(value 0..1) while dragging or on click.
Item {
    id: root
    property real value: 0
    signal moved(real v)
    implicitWidth: 80; implicitHeight: Theme.h
    Rectangle { id: track; x: 10; width: 70; height: 4; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(1, 1, 1, 0.2)
        Rectangle { width: track.width * Math.min(root.value, 1); height: 4; radius: 2; color: Theme.accent }
        Rectangle { x: track.width * Math.min(root.value, 1) - 5; anchors.verticalCenter: parent.verticalCenter
            width: 10; height: 10; radius: 5; color: Theme.text } }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
        function at(mx) { return Math.max(0, Math.min(1, (mx - track.x) / track.width)) }
        onPressed: e => root.moved(at(e.x)); onPositionChanged: e => { if (pressed) root.moved(at(e.x)) } }
}
