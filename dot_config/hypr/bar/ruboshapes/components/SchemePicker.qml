import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

// Colour scheme picker for one monitor (right-click the Arch logo). Each tile previews the scheme as
// a tiny bar: cap -> middle -> inner arrow segments. Clicking applies it to this monitor right away.
Scope {
    id: root
    required property var screen
    required property string mon
    property bool open: false        // driven by the bar; never assigned here (that would break the binding)
    signal closeRequested()
    property real leftMargin: 6

    readonly property var st: Schemes.settingFor(mon)
    readonly property var pal: Schemes.pal(mon)

    PanelWindow {
        id: pop
        screen: root.screen
        anchors { top: true; left: true }
        margins.top: 6
        margins.left: root.leftMargin
        exclusionMode: ExclusionMode.Normal
        WlrLayershell.namespace: "ruboshapes-tray"      // same blur rule as the tray dropdown
        WlrLayershell.layer: WlrLayer.Overlay
        implicitWidth: frame.width; implicitHeight: frame.height + 12
        visible: root.open || fade.running
        color: "transparent"

        HyprlandFocusGrab { windows: [pop]; active: root.open; onCleared: root.closeRequested() }

        Rectangle {
            id: frame
            readonly property int cols: 6
            width: grid.implicitWidth + 32
            height: col.implicitHeight + 30
            radius: 14
            color: Qt.rgba(0.02, 0.04, 0.05, 0.72)
            opacity: root.open ? 1 : 0
            y: root.open ? 0 : -10
            Behavior on opacity { NumberAnimation { id: fade; duration: 180 } }
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Shape {     // Hyprland window border look
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1; fillRule: ShapePath.OddEvenFill
                    fillGradient: LinearGradient { x1: 0; y1: 0; x2: frame.width; y2: frame.height
                        GradientStop { position: 0; color: Theme.border1 }
                        GradientStop { position: 1; color: Qt.alpha(Theme.border2, 0.93) } }
                    PathRectangle { width: frame.width; height: frame.height; radius: 14 }
                    PathRectangle { x: 2; y: 2; width: frame.width - 4; height: frame.height - 4; radius: 12 }
                }
            }

            Column {
                id: col
                x: 16; y: 15
                spacing: 12

                Item {      // header: title + dark/light toggle
                    width: grid.implicitWidth; height: 30
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Text { text: "\u{f03d8}"; font.family: Theme.monoIcons; font.pixelSize: 16; color: root.pal.accent
                            anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Colours"; font.family: Theme.sans; font.pixelSize: 15; font.weight: Font.Bold; color: "#ecfeff"
                            anchors.verticalCenter: parent.verticalCenter }
                        Text { text: root.mon; font.family: Theme.mono; font.pixelSize: 12; color: "#94a3b8"
                            anchors.verticalCenter: parent.verticalCenter }
                    }
                    Rectangle {     // dark / light
                        id: modeBox
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 2 * 76 + 6; height: 30; radius: 15
                        color: Qt.rgba(0, 0, 0, 0.35); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                        Rectangle {
                            x: 3 + (root.st.mode === "light" ? 76 : 0); y: 3; width: 76; height: 24; radius: 12
                            color: root.pal.pill
                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }
                        Row {
                            x: 3; y: 3
                            Repeater {
                                model: [["dark", "\u{f0594}", "Dark"], ["light", "\u{f0599}", "Light"]]
                                Item {
                                    required property var modelData
                                    readonly property bool on: root.st.mode === modelData[0]
                                    width: 76; height: 24
                                    Row { anchors.centerIn: parent; spacing: 5
                                        Text { text: modelData[1]; font.family: Theme.monoIcons; font.pixelSize: 12
                                            color: parent.parent.on ? root.pal.pillText : "#cbd5e1"; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: modelData[2]; font.family: Theme.sans; font.pixelSize: 12; font.weight: parent.parent.on ? Font.Bold : Font.Normal
                                            color: parent.parent.on ? root.pal.pillText : "#cbd5e1"; anchors.verticalCenter: parent.verticalCenter } }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: Schemes.set(root.mon, "mode", parent.modelData[0]) }
                                }
                            }
                        }
                    }
                }

                Column {    // the wallpaper's own colours: pick one, it is remembered for this image
                    visible: (Schemes.wpCandidates[root.mon] ?? []).length > 0
                    spacing: 6
                    Text { text: "FROM THIS WALLPAPER"; font.family: Theme.sans; font.pixelSize: 10; font.weight: Font.Bold
                        font.letterSpacing: 1.2; color: root.pal.accent }
                    Row {
                        spacing: 8
                        Repeater {
                            model: Schemes.wpCandidates[root.mon] ?? []
                            Rectangle {
                                id: cand
                                required property var modelData
                                readonly property bool sel: root.st.scheme === "wallpaper" && Schemes.sameColor(Schemes.wpColor[root.mon], modelData)
                                readonly property var p: Schemes.make("wallpaper", root.st.mode, modelData)
                                width: 84; height: 46; radius: 10
                                color: candMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.25)
                                border.width: cand.sel ? 2 : 1
                                border.color: cand.sel ? Theme.border1 : Qt.rgba(1, 1, 1, 0.07)
                                Behavior on color { ColorAnimation { duration: 110 } }
                                MiniBar { x: 8; y: 8; width: cand.width - 16; p: cand.p }
                                Rectangle {     // the picked wallpaper colour itself
                                    anchors.horizontalCenter: parent.horizontalCenter; y: 34
                                    width: 28; height: 5; radius: 2.5; color: cand.modelData
                                }
                                MouseArea { id: candMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: Schemes.pickWallpaperColor(root.mon, cand.modelData) }
                            }
                        }
                    }
                }

                Grid {
                    id: grid
                    columns: frame.cols
                    spacing: 8
                    Repeater {
                        model: Schemes.presets
                        Rectangle {
                            id: tile
                            required property string modelData
                            readonly property bool sel: root.st.scheme === modelData
                            readonly property var p: Schemes.make(modelData, root.st.mode, Schemes.wpColor[root.mon])
                            width: 84; height: 62; radius: 10
                            color: tileMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.25)
                            border.width: sel ? 2 : 1
                            border.color: sel ? Theme.border1 : Qt.rgba(1, 1, 1, 0.07)
                            Behavior on color { ColorAnimation { duration: 110 } }

                            // mini bar: bar background with cap -> mid -> inner arrows
                            MiniBar { x: 8; y: 8; width: tile.width - 16; p: tile.p }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 37
                                spacing: 4
                                Text { visible: tile.modelData === "wallpaper"; text: "\u{f0e09}"; font.family: Theme.monoIcons; font.pixelSize: 11
                                    color: tile.p.accent; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: Schemes.title(tile.modelData); font.family: Theme.sans; font.pixelSize: 11
                                    font.weight: tile.sel ? Font.Bold : Font.Normal
                                    color: tile.sel ? "#ecfeff" : "#cbd5e1"; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea { id: tileMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: Schemes.set(root.mon, "scheme", tile.modelData) }
                        }
                    }
                }

                Row {       // system: the main monitor's scheme also colours apps, borders, terminal
                    spacing: 8
                    readonly property bool isMain: Schemes.mainMonitor === root.mon
                    Chip {
                        on: parent.isMain
                        icon: "\u{f0379}"
                        label: parent.isMain ? "Main monitor: system colours follow" : "Make main monitor (system colours)"
                        onClicked: if (!parent.isMain) Schemes.setSystem("monitor", root.mon)
                    }
                    Chip {
                        visible: parent.isMain
                        on: Schemes.terminalColours
                        icon: "\u{f018d}"
                        label: "Terminal colours"
                        onClicked: Schemes.setSystem("terminal", !Schemes.terminalColours)
                    }
                }

                Item {      // footer
                    width: grid.implicitWidth; height: 26
                    Text { anchors.verticalCenter: parent.verticalCenter
                        text: Schemes.mainMonitor === root.mon ? "Also recolours apps and window borders" : "Only this monitor's bar"
                        font.family: Theme.sans; font.pixelSize: 11; color: "#94a3b8" }
                    Rectangle {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: allTxt.implicitWidth + 22; height: 26; radius: 13
                        color: allMa.containsMouse ? Qt.alpha(root.pal.accent, 0.22) : Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1; border.color: Qt.alpha(root.pal.accent, 0.4)
                        Text { id: allTxt; anchors.centerIn: parent; text: "Use on all monitors"
                            font.family: Theme.sans; font.pixelSize: 11; font.weight: Font.Bold; color: root.pal.accent }
                        MouseArea { id: allMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { Schemes.set("*", "scheme", root.st.scheme); Schemes.set("*", "mode", root.st.mode) } }
                    }
                }
            }
        }
    }

    component MiniBar: Item {
        id: mini
        property var p
        height: 22
        Rectangle { anchors.fill: parent; radius: 4; color: mini.p.bar }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeWidth: -1; fillColor: mini.p.inner
                startX: 0; startY: 0
                PathLine { x: 50; y: 0 } PathLine { x: 56; y: 11 } PathLine { x: 50; y: 22 } PathLine { x: 0; y: 22 } }
            ShapePath { strokeWidth: -1; fillColor: mini.p.mid
                startX: 0; startY: 0
                PathLine { x: 32; y: 0 } PathLine { x: 38; y: 11 } PathLine { x: 32; y: 22 } PathLine { x: 0; y: 22 } }
            ShapePath { strokeWidth: -1; fillColor: mini.p.cap
                startX: 0; startY: 0
                PathLine { x: 14; y: 0 } PathLine { x: 20; y: 11 } PathLine { x: 14; y: 22 } PathLine { x: 0; y: 22 } }
        }
        Rectangle { x: 23; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: mini.p.pill }
        Rectangle { x: mini.width - 12; anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: mini.p.accent }
    }

    component Chip: Rectangle {
        id: chip
        property bool on
        property string icon
        property string label
        signal clicked()
        width: chipRow.implicitWidth + 22; height: 28; radius: 14
        color: on ? Qt.alpha(root.pal.accent, 0.20) : chipMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.25)
        border.width: 1; border.color: on ? Qt.alpha(root.pal.accent, 0.6) : Qt.rgba(1, 1, 1, 0.08)
        Behavior on color { ColorAnimation { duration: 110 } }
        Row { id: chipRow; anchors.centerIn: parent; spacing: 6
            Text { text: chip.icon; font.family: Theme.monoIcons; font.pixelSize: 12; color: chip.on ? root.pal.accent : "#94a3b8"
                anchors.verticalCenter: parent.verticalCenter }
            Text { text: chip.label; font.family: Theme.sans; font.pixelSize: 11; font.weight: chip.on ? Font.Bold : Font.Normal
                color: chip.on ? "#ecfeff" : "#cbd5e1"; anchors.verticalCenter: parent.verticalCenter } }
        MouseArea { id: chipMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
    }
}
