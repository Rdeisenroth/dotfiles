import QtQuick
import QtQuick.Shapes
import qs.services

// Small ring gauge with a centred icon (narrow screens).
Item {
    id: root
    property real value: 0          // 0..100
    property string icon: ""
    implicitWidth: 26; implicitHeight: 26
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath { strokeColor: Theme.track; strokeWidth: 2.5; fillColor: "transparent"
            PathAngleArc { centerX: 13; centerY: 13; radiusX: 11.75; radiusY: 11.75; startAngle: 0; sweepAngle: 360 } }
        ShapePath { strokeColor: Theme.accent; strokeWidth: 2.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: 13; centerY: 13; radiusX: 11.75; radiusY: 11.75; startAngle: -90
                sweepAngle: Math.max(root.value, 3) * 3.6 } }
    }
    Text { anchors.centerIn: parent; text: root.icon; font.family: Theme.monoIcons; font.pixelSize: 13; color: Theme.text }
}
