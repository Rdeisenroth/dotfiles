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

    // One continuous soft shadow along the arrow edge (both sides + the tip), cast by the lighter side
    // onto the darker one. Built from N nested chevron strips (edge -> offset k, mitred at the tip),
    // each faintly transparent; where they overlap they add up to a smooth falloff away from the edge.
    Item {
        id: shade
        readonly property bool selfCasts: Theme.lum(root.fill) >= Theme.lum(root.next)
        readonly property real ax: root.rightSide ? 0 : root.width          // edge top/bottom x
        readonly property real dir: root.rightSide ? -1 : 1                   // towards the tip
        readonly property real tx: ax + dir * root.t                          // tip x
        readonly property real s: (selfCasts ? 1 : -1) * dir                  // shadow side (x sign)
        readonly property real len: Math.sqrt(root.t * root.t + root.hh * root.hh / 4)
        readonly property real nx: (root.hh / 2) / len                        // edge normal, |x| part
        readonly property real ny: root.t / len                               //               |y| part
        readonly property real miter: len / (root.hh / 2)                      // tip offset per unit
        readonly property int n: 8                                            // reach in px
        readonly property real a: 1 - Math.pow(1 - Theme.shadow.a * 0.6, 1 / n) // per-strip alpha (60% of the theme shadow at the edge)
        Repeater {
            model: shade.n
            Shape {
                id: strip
                required property int index
                readonly property real k: index + 1
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillColor: Qt.rgba(Theme.shadow.r, Theme.shadow.g, Theme.shadow.b, shade.a)
                    // A -> T -> B along the edge, back along the edge offset by k (mitred at the tip)
                    startX: shade.ax; startY: 0
                    PathLine { x: shade.tx; y: root.hh / 2 }
                    PathLine { x: shade.ax; y: root.hh }
                    PathLine { x: shade.ax + shade.s * shade.nx * strip.k; y: root.hh + (shade.s * shade.dir) * shade.ny * strip.k }
                    PathLine { x: shade.tx + shade.s * shade.miter * strip.k; y: root.hh / 2 }
                    PathLine { x: shade.ax + shade.s * shade.nx * strip.k; y: -(shade.s * shade.dir) * shade.ny * strip.k }
                    PathLine { x: shade.ax; y: 0 }
                }
            }
        }
    }

    Row {
        id: row
        x: root.rightSide ? root.padL : root.notchW + root.padL
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
    }
}
