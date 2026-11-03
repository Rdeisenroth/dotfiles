import QtQuick
import QtQuick.Shapes
import qs.services

// One coloured bar segment with an arrow tip pointing towards the middle of the bar.
//   right: false = left half (tip on the right edge), true = right half (tip on the left edge)
//   notch: the outer neighbour's tip sits in this segment (shape is cut out, so translucent
//          colours never overlap)
//   next:  colour on the other side of this segment's tip (neighbour or bar background); the
//          lighter of the two casts a soft shadow onto the darker one along the arrow edge.
Item {
    id: root
    property color fill
    property bool rightSide: false
    property bool notch: false
    property color next: Theme.bar
    property real padL: 10
    property real padR: 10
    default property alias content: row.data
    property alias spacing: row.spacing

    readonly property real t: Theme.tip
    readonly property real hh: Theme.h
    readonly property real notchW: notch ? t : 0

    implicitHeight: hh
    implicitWidth: row.implicitWidth + padL + padR + notchW


    Shape {
        id: body
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.fill
            strokeWidth: -1
            // left half: notch on the left, tip on the right. right half: tip left, notch right.
            startX: root.rightSide ? 0 : 0; startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.rightSide ? root.width - root.notchW : root.width + root.t; y: root.hh / 2 }
            PathLine { x: root.width; y: root.hh }
            PathLine { x: 0; y: root.hh }
            PathLine { x: root.rightSide ? -root.t : root.notchW; y: root.hh / 2 }
            PathLine { x: 0; y: 0 }
        }
    }

    // shadow band along this segment's tip edges, on the darker side
    Shape {
        id: shade
        preferredRendererType: Shape.CurveRenderer
        readonly property bool selfCasts: Theme.lum(root.fill) >= Theme.lum(root.next)
        // edge points: A (top) -> T (tip) -> B (bottom)
        readonly property real ax: root.rightSide ? 0 : root.width
        readonly property real tx: root.rightSide ? -root.t : root.width + root.t
        readonly property real len: Math.sqrt(root.t * root.t + root.hh * root.hh / 4)
        // unit normal of the upper edge pointing to the neighbour side (mirror for the lower edge)
        // upper edge normal towards the neighbour: (±H/2, -t)/len; flipped when the neighbour casts
        readonly property real s: selfCasts ? 1 : -1
        readonly property real nx: s * (root.rightSide ? -1 : 1) * (root.hh / 2) / len
        readonly property real ny: -s * root.t / len
        readonly property real d: 7

        ShapePath {     // upper half
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: (shade.ax + shade.tx) / 2; y1: root.hh / 4
                x2: x1 + shade.nx * shade.d; y2: y1 + shade.ny * shade.d
                GradientStop { position: 0; color: Theme.shadow }
                GradientStop { position: 1; color: "transparent" }
            }
            startX: shade.ax; startY: 0
            PathLine { x: shade.tx; y: root.hh / 2 }
            PathLine { x: shade.tx + shade.nx * shade.d; y: root.hh / 2 + shade.ny * shade.d }
            PathLine { x: shade.ax + shade.nx * shade.d; y: shade.ny * shade.d }
            PathLine { x: shade.ax; y: 0 }
        }
        ShapePath {     // lower half (mirror of the upper normal in y)
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: (shade.ax + shade.tx) / 2; y1: root.hh * 3 / 4
                x2: x1 + shade.nx * shade.d; y2: y1 - shade.ny * shade.d
                GradientStop { position: 0; color: Theme.shadow }
                GradientStop { position: 1; color: "transparent" }
            }
            startX: shade.tx; startY: root.hh / 2
            PathLine { x: shade.ax; y: root.hh }
            PathLine { x: shade.ax + shade.nx * shade.d; y: root.hh - shade.ny * shade.d }
            PathLine { x: shade.tx + shade.nx * shade.d; y: root.hh / 2 - shade.ny * shade.d }
            PathLine { x: shade.tx; y: root.hh / 2 }
        }
    }

    Row {
        id: row
        x: root.rightSide ? root.padL : root.notchW + root.padL
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
    }
}
