import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services

// One window in the Alt+Tab switcher: live thumbnail, app icon badge, app name + window title,
// and an optional tag chip on the thumbnail (e.g. "3 · DP-1").
Item {
    id: card
    required property var win
    property bool active: false
    property bool compact: false
    property bool live: true
    property string tag: ""
    signal picked()

    readonly property string cls: win?.lastIpcObject?.class ?? ""
    readonly property var entry: DesktopEntries.heuristicLookup(cls)

    width: compact ? 210 : 260
    height: thumb.height + 60

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: card.active ? Qt.rgba(0.18, 0.83, 0.75, 0.15) : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.20))
        border.width: card.active ? 2 : 1
        border.color: card.active ? Theme.border1 : Qt.rgba(1, 1, 1, 0.07)
        Behavior on color { ColorAnimation { duration: 110 } }
    }

    ClippingRectangle {
        id: thumb
        x: 8; y: 8
        width: card.width - 16; height: card.compact ? 114 : 144
        radius: 9
        color: Qt.rgba(0, 0, 0, 0.40)
        ScreencopyView {
            anchors.centerIn: parent
            // keep the window's aspect ratio inside the box
            readonly property real ar: sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 16 / 9
            width: Math.min(thumb.width, thumb.height * ar)
            height: Math.min(thumb.height, thumb.width / ar)
            captureSource: card.win?.wayland ?? null
            live: card.live
        }
        Rectangle {     // tag chip
            visible: card.tag !== ""
            anchors { top: parent.top; right: parent.right; margins: 6 }
            height: 18; width: tagText.implicitWidth + 12; radius: 9
            color: Qt.rgba(0.01, 0.05, 0.05, 0.82)
            Text { id: tagText; anchors.centerIn: parent; text: card.tag
                font.family: Theme.mono; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.text2 }
        }
    }

    Rectangle {         // app icon badge, overlapping the thumbnail's bottom edge
        x: 16; y: thumb.y + thumb.height - 15
        width: 32; height: 32; radius: 10
        color: Qt.rgba(0.02, 0.07, 0.07, 0.94)
        border.width: 1; border.color: card.active ? Theme.border1 : Qt.rgba(1, 1, 1, 0.12)
        IconImage { anchors.centerIn: parent; implicitSize: 20
            source: Quickshell.iconPath(card.entry?.icon ?? card.cls.toLowerCase(), "application-x-executable") }
    }

    Column {
        x: 56; y: thumb.y + thumb.height + 5
        width: card.width - 56 - 12
        spacing: 1
        Text { width: parent.width; text: card.entry?.name ?? (card.cls || "Window"); elide: Text.ElideRight
            font.family: Theme.sans; font.pixelSize: 13; font.weight: Font.Bold
            color: card.active ? Theme.text : Theme.text2 }
        Text { width: parent.width; text: card.win?.title ?? ""; elide: Text.ElideRight
            font.family: Theme.sans; font.pixelSize: 11; color: Theme.text2; opacity: card.active ? 0.9 : 0.6 }
    }

    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: card.picked() }
}
