import QtQuick
import Quickshell.Services.UPower
import qs.services

// Phone-style battery: level fill, number inside (dark on the fill, light on the empty part),
// bolt when charging. Hidden on machines without a battery.
Item {
    property var pal: Schemes.pal("")
    id: root
    readonly property var dev: UPower.displayDevice
    readonly property real pct: Math.round((dev?.percentage ?? 0) * 100)
    readonly property bool charging: dev?.state === UPowerDeviceState.Charging || dev?.state === UPowerDeviceState.FullyCharged
    visible: dev?.isLaptopBattery ?? false
    implicitWidth: 40; implicitHeight: 18
    readonly property color lvl: pct > 20 ? "#5eead4" : pct > 10 ? "#fbbf24" : "#f87171"
    Rectangle { id: body; width: 36; height: 18; radius: 5; color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1.25; border.color: Qt.alpha(pal.text, 0.7)
        Item { id: clip; x: 2; y: 2; height: 14; width: (32) * root.pct / 100; clip: true
            Rectangle { width: 32; height: 14; radius: 3; color: root.lvl }
            Text { x: -2; y: -2; width: 36; height: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: (root.charging ? "\u{f0e7}" : "") + root.pct; color: "#041a19"; font.family: Theme.mono; font.weight: 800; font.pixelSize: 11 } }
        Text { anchors.fill: parent; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; z: -1
            text: (root.charging ? "\u{f0e7}" : "") + root.pct; color: pal.text; font.family: Theme.mono; font.weight: 800; font.pixelSize: 11 } }
    Rectangle { x: 37; y: 6; width: 3; height: 6; radius: 1.5; color: Qt.alpha(pal.text, 0.7) }
}
