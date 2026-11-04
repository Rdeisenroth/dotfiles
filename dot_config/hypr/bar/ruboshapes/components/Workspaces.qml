import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.services

// 10 workspaces of one monitor (global ids slot*10+1..slot*10+10, see workspaces.lua).
// Normal: dots (filled = has windows), active = pill with number. Hover: every workspace morphs
// into a pill with its number + up to 3 app icons.
Row {
    property var pal: Schemes.pal("")
    id: root
    required property var monitor            // HyprlandMonitor
    property bool narrow: false
    property bool peek: false
    spacing: peek ? 4 : (narrow ? 4 : 7)
    Behavior on spacing { NumberAnimation { duration: 180 } }

    // During a switch Hyprland briefly reports no active workspace (the new one isn't created yet).
    // Keep the last valid id, so the old pill hands over to the new one without collapsing in between.
    readonly property int liveId: monitor?.activeWorkspace?.id ?? -1
    property int activeId: 1
    onLiveIdChanged: {
        if (liveId > 0) activeId = liveId;
        // the swipe landed: hand over to the normal switch animation
        if (Swipe.active && !Swipe.dragging && Swipe.monitor === (monitor?.name ?? "")) Swipe.done();
    }
    Component.onCompleted: if (liveId > 0) activeId = liveId
    readonly property int slot: Math.floor(Math.max(activeId - 1, 0) / 10)

    // Touchpad swipe (services/Swipe.qml): the pill moves 1:1 with the fingers. While they are down the
    // animations are off; after lifting, they are back on and the pill settles on wherever Hyprland lands.
    readonly property bool swiping: Swipe.active && !peek && Swipe.monitor === (monitor?.name ?? "")
                                    && Swipe.startId === activeId
    readonly property bool following: swiping && Swipe.dragging
    readonly property int swipeFrom: Swipe.startId - slot * 10 - 1
    readonly property int swipeTo: swipeFrom + (Swipe.progress < 0 ? -1 : 1)
    readonly property real swipeT: (swipeTo >= 0 && swipeTo <= 9) ? Math.min(1, Math.abs(Swipe.progress)) : 0

    function mix(a, b, f) {
        const x = Qt.lighter(a, 1.0), y = Qt.lighter(b, 1.0);
        return Qt.rgba(x.r + (y.r - x.r) * f, x.g + (y.g - x.g) * f, x.b + (y.b - x.b) * f, x.a + (y.a - x.a) * f);
    }

    function iconFor(cls) {
        const e = DesktopEntries.heuristicLookup(cls);
        return Quickshell.iconPath(e?.icon ?? cls.toLowerCase(), "application-x-executable");
    }

    Repeater {
        model: 10
        delegate: Item {
            id: w
            required property int index
            readonly property int wid: root.slot * 10 + index + 1
            readonly property var ws: Hyprland.workspaces.values.find(x => x.id === wid) ?? null
            readonly property var tops: ws?.toplevels.values ?? []
            readonly property bool occ: tops.length > 0
            readonly property bool cur: root.activeId === wid
            readonly property var classes: {
                const seen = [];
                for (const t of tops) { const c = t.lastIpcObject?.class ?? ""; if (c && !seen.includes(c)) seen.push(c) }
                return seen;
            }
            readonly property bool pill: cur || root.peek
            // 0 = dot, 1 = pill; in between while swiping
            readonly property real f: !root.swiping ? (cur ? 1 : 0)
                                    : index === root.swipeFrom ? 1 - root.swipeT
                                    : index === root.swipeTo ? root.swipeT : 0
            readonly property color dotColor: occ ? pal.dots : Qt.alpha(pal.dots, 0)
            readonly property color pillColor: hov ? Qt.lighter(pal.pill, 1.15) : pal.pill
            implicitHeight: Theme.h
            // width = the animated pill/dot itself: old pill shrinks while the new one grows on the same
            // curve, so the segment (and its arrow edge) keeps a constant width during a switch
            implicitWidth: pillBox.width

            Rectangle {     // dot / ring / pill background
                id: pillBox
                anchors.verticalCenter: parent.verticalCenter
                readonly property real dotSize: root.narrow ? 8 : 13
                readonly property real pillW: content.implicitWidth + (root.narrow ? 12 : 28)
                readonly property real pillH: root.narrow ? 18 : 26
                width: root.peek ? content.implicitWidth + (root.narrow ? 12 : (w.cur ? 28 : 18))
                                 : dotSize + (pillW - dotSize) * w.f
                height: root.peek ? pillH : dotSize + (pillH - dotSize) * w.f
                radius: height / 2
                color: root.peek ? (w.cur ? w.pillColor : Qt.rgba(0, 0, 0, w.hov ? 0.5 : (w.occ ? 0.32 : 0.18)))
                                 : root.mix(w.dotColor, w.pillColor, w.f)
                border.width: (!root.peek && !w.occ) ? 1.5 * (1 - w.f) : 0
                border.color: Qt.alpha(pal.dots, 0.6)
                Behavior on width { enabled: !root.following; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on height { enabled: !root.following; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on color { enabled: !root.following; ColorAnimation { duration: 180 } }

                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: 6
                    opacity: root.peek ? 1 : w.f
                    Behavior on opacity { enabled: !root.following; NumberAnimation { duration: 150 } }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: w.wid - root.slot * 10
                        font.family: Theme.mono; font.weight: 800; font.pixelSize: root.narrow ? 11 : 13
                        color: root.peek ? (w.cur ? pal.pillText : Qt.alpha(pal.dots, w.occ ? 1 : 0.55))
                                         : root.mix(Qt.alpha(pal.dots, w.occ ? 1 : 0.55), pal.pillText, w.f)
                    }
                    Row {
                        visible: root.peek && w.classes.length > 0
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Repeater {
                            model: w.classes.slice(0, 3)
                            IconImage { required property string modelData; implicitSize: 16; source: root.iconFor(modelData) }
                        }
                        Text {
                            visible: w.classes.length > 3
                            text: "+" + (w.classes.length - 3)
                            font.family: Theme.mono; font.weight: 800; font.pixelSize: 11; color: pal.dots
                        }
                    }
                }
            }
            readonly property bool hov: ma.containsMouse
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${w.wid} })`)
            }
        }
    }
}
