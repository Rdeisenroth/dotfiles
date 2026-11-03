import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.services

// Music island, pinned to the exact screen centre by Bar.qml. Hover: grows with prev/play/next.
// Click: Caelestia dashboard. Middle: play/pause. Scroll: previous/next track.
Rectangle {
    id: root
    required property string monitorName
    property bool narrow: false
    readonly property var player: Mpris.players.values.find(p => p.dbusName?.includes("spotify"))
        ?? Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
    property bool forced: false
    readonly property bool hovered: hover.hovered || forced

    visible: player !== null && (player.trackTitle ?? "") !== ""
    height: 30
    width: (narrow ? 165 : 330) + (hovered ? 96 : 0)
    radius: 15
    color: Theme.island
    border.width: 1
    border.color: hovered ? Qt.alpha(Theme.eq, 0.55) : Theme.islandStroke
    Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
    Behavior on border.color { ColorAnimation { duration: 200 } }

    HoverHandler { id: hover }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => e.button === Qt.MiddleButton ? root.player?.togglePlaying() : Caelestia.toggle("dashboard", root.monitorName)
        onWheel: e => e.angleDelta.y > 0 ? root.player?.previous() : root.player?.next()
    }

    ClippingRectangle {
        id: cover
        x: 4; anchors.verticalCenter: parent.verticalCenter
        width: 22; height: 22; radius: 11
        color: Theme.eq
        Image { anchors.fill: parent; source: root.player?.trackArtUrl ?? ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
    }
    Row {
        anchors { left: cover.right; leftMargin: 8; right: right_.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 8
        clip: true
        Text { id: song; text: root.player?.trackTitle ?? ""; color: Theme.islandText
            font.family: Theme.sans; font.pixelSize: 14; font.weight: 600
            width: Math.min(implicitWidth, parent.width - (artist.visible ? Math.min(artist.implicitWidth, 120) + 8 : 0)); elide: Text.ElideRight }
        Text { id: artist; visible: !root.narrow; text: root.player?.trackArtist ?? ""; color: Theme.islandSub
            font.family: Theme.sans; font.pixelSize: 14
            width: Math.min(implicitWidth, parent.width - song.width - 8); elide: Text.ElideRight }
    }
    Row {
        id: right_
        anchors { right: parent.right; rightMargin: 11; verticalCenter: parent.verticalCenter }
        spacing: 6
        Row {
            spacing: 4
            opacity: root.hovered ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            anchors.verticalCenter: parent.verticalCenter
            component Btn: Rectangle {
                property string glyph; property bool main: false; signal hit()
                width: 24; height: 24; radius: 12
                color: main ? (ma.containsMouse ? Qt.lighter(Theme.eq, 1.15) : Theme.eq) : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
                Text { anchors.centerIn: parent; text: parent.glyph; font.family: Theme.monoIcons; font.pixelSize: 14
                    color: parent.main ? Theme.pillText : Theme.islandText }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: parent.hit() }
            }
            Btn { glyph: "\u{f04ae}"; onHit: root.player?.previous() }
            Btn { glyph: root.player?.isPlaying ? "\u{f04c}" : "\u{f04b}"; main: true; onHit: root.player?.togglePlaying() }
            Btn { glyph: "\u{f04ad}"; onHit: root.player?.next() }
        }
        Row {       // equaliser: smooth 60 fps bounce while playing, flat when paused
            id: eq
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            height: 14
            readonly property bool playing: root.player?.isPlaying ?? false
            Repeater { model: [[5, 13, 900], [12, 4, 700], [8, 14, 1100], [12, 4, 800], [5, 13, 1000]]
                Rectangle {
                    id: bar_
                    required property var modelData
                    width: 3; radius: 1.5; anchors.bottom: parent.bottom
                    color: eq.playing ? Theme.eq : Qt.alpha(Theme.eq, 0.5)
                    height: 3
                    SequentialAnimation on height {
                        running: eq.playing; loops: Animation.Infinite
                        onRunningChanged: if (!running) bar_.height = 3
                        NumberAnimation { from: bar_.modelData[0]; to: bar_.modelData[1]; duration: bar_.modelData[2] / 2; easing.type: Easing.InOutSine }
                        NumberAnimation { from: bar_.modelData[1]; to: bar_.modelData[0]; duration: bar_.modelData[2] / 2; easing.type: Easing.InOutSine }
                    }
                }
            }
        }
    }
}
