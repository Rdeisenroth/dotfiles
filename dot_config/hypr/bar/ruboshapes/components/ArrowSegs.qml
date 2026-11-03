import QtQuick
import QtQuick.Shapes
import qs.services

// A row of arrow-ended segments, like a tiny ruboshape bar: [first] > [second] > [third] >
// Used by the keybind sheet for key chords (Super cap -> modifiers -> key), category rails and the title.
// Each later segment is notched where the previous tip sits, so translucent colours never overlap.
//   parts: [{ fill, text, color, family?, size?, bold?, spacing? }]
Item {
    id: segs
    property var parts: []
    property int h: 22
    property real arr: 8                // arrow depth
    property real radius: 4             // rounded left end of the first segment
    property real padFirst: 8
    property real padNext: 5            // text gap after the notch
    property real padEnd: 6
    property string family: Theme.mono
    property int size: 12

    implicitWidth: row.implicitWidth + arr
    implicitHeight: h

    Row {
        id: row
        Repeater {
            model: segs.parts
            Item {
                id: seg
                required property var modelData
                required property int index
                readonly property bool first: index === 0
                readonly property real padL: first ? segs.padFirst : segs.arr + segs.padNext
                width: padL + lbl.implicitWidth + segs.padEnd
                height: segs.h

                Shape {
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: seg.modelData.fill
                        strokeWidth: -1
                        readonly property real r: seg.first ? segs.radius : 0
                        startX: r; startY: 0
                        PathLine { x: seg.width; y: 0 }
                        PathLine { x: seg.width + segs.arr; y: segs.h / 2 }
                        PathLine { x: seg.width; y: segs.h }
                        PathLine { x: seg.first ? segs.radius : 0; y: segs.h }
                        PathQuad { x: 0; y: segs.h - (seg.first ? segs.radius : 0); controlX: 0; controlY: segs.h }
                        PathLine { x: seg.first ? 0 : segs.arr; y: segs.h / 2 }
                        PathLine { x: 0; y: seg.first ? segs.radius : 0 }
                        PathQuad { x: seg.first ? segs.radius : 0; y: 0; controlX: 0; controlY: 0 }
                    }
                }
                Text {
                    id: lbl
                    x: seg.padL
                    anchors.verticalCenter: parent.verticalCenter
                    text: seg.modelData.text
                    color: seg.modelData.color
                    font.family: seg.modelData.family ?? segs.family
                    font.pixelSize: seg.modelData.size ?? segs.size
                    font.weight: (seg.modelData.bold ?? true) ? Font.Bold : Font.Normal
                    font.letterSpacing: seg.modelData.spacing ?? 0
                }
            }
        }
    }
}
