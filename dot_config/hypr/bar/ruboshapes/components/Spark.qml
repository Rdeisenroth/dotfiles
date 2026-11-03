import QtQuick
import QtQuick.Shapes
import qs.services

// Area sparkline of 0..100 values (newest right), btop style.
Shape {
    id: root
    property var values: []
    property int keep: 60
    property color color: Theme.accent
    preferredRendererType: Shape.CurveRenderer
    readonly property real step: width / (keep - 1)
    readonly property var pts: {
        const v = values.slice(-keep), x0 = (keep - v.length) * step, out = [];
        for (let i = 0; i < v.length; i++) out.push(Qt.point(x0 + i * step, height - height * Math.min(Math.max(v[i], 0), 100) / 100));
        return out;
    }
    ShapePath {
        strokeWidth: -1
        fillGradient: LinearGradient { y1: 0; y2: root.height
            GradientStop { position: 0; color: Qt.alpha(root.color, 0.55) }
            GradientStop { position: 1; color: Qt.alpha(root.color, 0.05) } }
        startX: root.pts.length ? root.pts[0].x : 0; startY: root.height
        PathPolyline { path: root.pts }
        PathLine { x: root.width; y: root.height }
    }
    ShapePath {
        strokeColor: root.color; strokeWidth: 1.4; fillColor: "transparent"; joinStyle: ShapePath.RoundJoin
        PathPolyline { path: root.pts }
    }
}
