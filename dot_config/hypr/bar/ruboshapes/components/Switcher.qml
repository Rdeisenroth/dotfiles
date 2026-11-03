import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import qs.services

// Alt+Tab switcher with live window thumbnails (most recently used first).
// Hyprland binds (keybinds.lua) send global shortcuts:
//   ruboshapes:switch-next (Alt+Tab), ruboshapes:switch-prev (Alt+Shift+Tab),
//   ruboshapes:switch-commit (Alt released). Escape cancels, a click picks a window.
Scope {
    id: root
    property bool open: false
    property int sel: 0
    property var wins: []

    function rebuild() {
        wins = Hyprland.toplevels.values
            .filter(t => (t.workspace?.id ?? -1) > 0 && (t.lastIpcObject?.mapped ?? true))
            .sort((a, b) => (a.lastIpcObject?.focusHistoryID ?? 999) - (b.lastIpcObject?.focusHistoryID ?? 999));
    }
    function step(d) {
        if (!open) {
            rebuild();
            if (wins.length === 0) return;
            sel = wins.length > 1 ? (d > 0 ? 1 : wins.length - 1) : 0;
            open = true;
        } else if (wins.length > 0) {
            sel = (sel + d + wins.length) % wins.length;
        }
    }
    function commit() {
        if (!open) return;
        const t = wins[sel];
        open = false;
        if (t) Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${t.address}" })`);
    }
    function pick(i) { sel = i; commit() }

    IpcHandler { target: "switcher"          // also scriptable: qs -p <dir> ipc call switcher next|prev|commit|cancel
        function next(): void { root.step(1) }
        function prev(): void { root.step(-1) }
        function commit(): void { root.commit() }
        function cancel(): void { root.open = false } }
    GlobalShortcut { appid: "ruboshapes"; name: "switch-next"; onPressed: root.step(1) }
    GlobalShortcut { appid: "ruboshapes"; name: "switch-prev"; onPressed: root.step(-1) }
    GlobalShortcut { appid: "ruboshapes"; name: "switch-commit"; onPressed: root.commit() }

    PanelWindow {
        id: panel
        visible: root.open
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "ruboshapes-switcher"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"
        // only the card panel takes input/blur; the rest of the screen stays visible and click-through-ish
        mask: Region { item: frame }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.open = false
            Keys.onReturnPressed: root.commit()
            Keys.onLeftPressed: root.step(-1)
            Keys.onRightPressed: root.step(1)
        }

        Rectangle {
            id: frame
            anchors.centerIn: parent
            readonly property int cardW: 260
            readonly property int cols: Math.max(1, Math.min(root.wins.length, Math.floor((panel.width * 0.85 - 40) / (cardW + 14))))
            width: grid.implicitWidth + 40
            height: grid.implicitHeight + 40
            radius: 18
            color: Theme.popup
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.96
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            // Hyprland window border look (teal top-left -> purple bottom-right)
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1; fillRule: ShapePath.OddEvenFill
                    fillGradient: LinearGradient { x1: 0; y1: 0; x2: frame.width; y2: frame.height
                        GradientStop { position: 0; color: Theme.border1 }
                        GradientStop { position: 1; color: Qt.alpha(Theme.border2, 0.93) } }
                    PathRectangle { width: frame.width; height: frame.height; radius: 18 }
                    PathRectangle { x: 2; y: 2; width: frame.width - 4; height: frame.height - 4; radius: 16 }
                }
            }

            Grid {
                id: grid
                anchors.centerIn: parent
                columns: frame.cols
                spacing: 14
                Repeater {
                    model: root.open ? root.wins : []
                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property bool active: index === root.sel
                        readonly property string cls: modelData.lastIpcObject?.class ?? ""
                        width: frame.cardW; height: 196
                        radius: 12
                        color: active ? Qt.rgba(0.18, 0.83, 0.75, 0.16) : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.22))
                        border.width: active ? 2 : 1
                        border.color: active ? Theme.border1 : Qt.rgba(1, 1, 1, 0.08)
                        Behavior on color { ColorAnimation { duration: 120 } }

                        ClippingRectangle {
                            id: thumb
                            x: 8; y: 8; width: parent.width - 16; height: 146
                            radius: 8
                            color: Qt.rgba(0, 0, 0, 0.35)
                            ScreencopyView {
                                anchors.centerIn: parent
                                // keep the window's aspect ratio inside the thumbnail box
                                readonly property real ar: sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 16 / 9
                                width: Math.min(thumb.width, thumb.height * ar)
                                height: Math.min(thumb.height, thumb.width / ar)
                                captureSource: card.modelData.wayland
                                live: root.open
                            }
                        }
                        Row {
                            anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12; bottom: parent.bottom; bottomMargin: 10 }
                            spacing: 8
                            IconImage { implicitSize: 18; anchors.verticalCenter: parent.verticalCenter
                                source: Quickshell.iconPath(DesktopEntries.heuristicLookup(card.cls)?.icon ?? card.cls.toLowerCase(), "application-x-executable") }
                            Text {
                                width: parent.width - 26; anchors.verticalCenter: parent.verticalCenter
                                text: card.modelData.title || card.cls
                                elide: Text.ElideRight
                                font.family: Theme.sans; font.pixelSize: 13; font.weight: card.active ? Font.Bold : Font.Normal
                                color: card.active ? Theme.text : Theme.text2
                            }
                        }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.pick(card.index) }
                    }
                }
            }
        }
    }
}
