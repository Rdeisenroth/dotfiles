import QtQuick
import qs.services

// Small German QWERTZ keyboard for the keybind sheet. Keys that do something in the current modifier
// layer light up and carry a tiny action label when it fits; held modifiers light up too.
//   acts:  keyId -> { text, dup, on }   (keyId = lower-case xkb name: "e", "return", "left", "mouse:272", ...)
//   mask:  modmask of the shown layer (64 Super, 4 Ctrl, 8 Alt, 1 Shift)
Item {
    id: kb
    required property var pal
    property color fg: pal.text
    property color fg2: pal.text2
    property color acc: pal.accent
    property color warn: "#fbbf24"
    property var acts: ({})
    property int mask: 64
    property real pitch: 50
    property real keyH: 40
    property real rowP: 44
    readonly property real gap: 4

    implicitWidth: 18.5 * pitch - gap
    implicitHeight: 4 * rowP + keyH

    // [legend, id, width(u)] per row; x positions are accumulated
    readonly property var rows: [
        [["^", "dead_circumflex", 1], ["1", "1", 1], ["2", "2", 1], ["3", "3", 1], ["4", "4", 1], ["5", "5", 1],
         ["6", "6", 1], ["7", "7", 1], ["8", "8", 1], ["9", "9", 1], ["0", "0", 1], ["ß", "ssharp", 1],
         ["´", "dead_acute", 1], ["⌫", "backspace", 2]],
        [["Tab", "tab", 1.5], ["Q", "q", 1], ["W", "w", 1], ["E", "e", 1], ["R", "r", 1], ["T", "t", 1], ["Z", "z", 1],
         ["U", "u", 1], ["I", "i", 1], ["O", "o", 1], ["P", "p", 1], ["Ü", "udiaeresis", 1], ["+", "plus", 1]],
        [["Caps", "caps_lock", 1.5], ["A", "a", 1], ["S", "s", 1], ["D", "d", 1], ["F", "f", 1], ["G", "g", 1],
         ["H", "h", 1], ["J", "j", 1], ["K", "k", 1], ["L", "l", 1], ["Ö", "odiaeresis", 1], ["Ä", "adiaeresis", 1],
         ["#", "numbersign", 1]],
        [["⇧", "@shift", 1.25], ["<", "less", 1], ["Y", "y", 1], ["X", "x", 1], ["C", "c", 1], ["V", "v", 1],
         ["B", "b", 1], ["N", "n", 1], ["M", "m", 1], [",", "comma", 1], [".", "period", 1], ["-", "minus", 1],
         ["⇧", "@shift", 2.75]],
        [["Ctrl", "@ctrl", 1.5], ["", "@super", 1.5], ["Alt", "@alt", 1.5], ["Space", "space", 6],
         ["AltGr", "iso_level3_shift", 1.5], ["Menu", "menu", 1.5], ["Ctrl", "@ctrl", 1.5]]
    ]
    readonly property var keys: {
        const out = [];
        rows.forEach((row, r) => {
            let x = 0;
            for (const [leg, id, w] of row) { out.push({ leg, id, x, r, w, hr: 1 }); x += w; }
        });
        out.push({ leg: "Enter", id: "return", x: 13.5, r: 1, w: 1.5, hr: 2 });   // ISO enter
        // right cluster: Print, mouse, arrows
        out.push({ leg: "Print", id: "print", x: 15.5, r: 0, w: 1, hr: 1 });
        out.push({ leg: "LMB", id: "mouse:272", x: 15.5, r: 1, w: 1, hr: 1 });
        out.push({ leg: "RMB", id: "mouse:273", x: 16.5, r: 1, w: 1, hr: 1 });
        out.push({ leg: "Wheel", id: "wheel", x: 17.5, r: 1, w: 1, hr: 1 });
        out.push({ leg: "↑", id: "up", x: 16.5, r: 3, w: 1, hr: 1 });
        out.push({ leg: "←", id: "left", x: 15.5, r: 4, w: 1, hr: 1 });
        out.push({ leg: "↓", id: "down", x: 16.5, r: 4, w: 1, hr: 1 });
        out.push({ leg: "→", id: "right", x: 17.5, r: 4, w: 1, hr: 1 });
        return out;
    }
    // 1…0 all doing the same thing -> one label across the number row instead of ten
    readonly property string digitSpan: {
        const t = acts["1"]?.text;
        if (!t) return "";
        for (const d of "234567890") if (acts[d]?.text !== t) return "";
        return t;
    }
    readonly property bool digitsOn: digitSpan !== "" && !!acts["1"]?.on

    function modOn(id) {
        return id === "@shift" ? !!(mask & 1) : id === "@ctrl" ? !!(mask & 4) : id === "@alt" ? !!(mask & 8) : id === "@super" ? !!(mask & 64) : false;
    }

    Repeater {
        model: kb.keys
        Rectangle {
            id: cap
            required property var modelData
            readonly property bool isMod: modelData.id.startsWith("@")
            readonly property bool held: isMod && kb.modOn(modelData.id)
            readonly property var act: isMod ? null : kb.acts[modelData.id]
            readonly property bool lit: !!act && act.on
            readonly property bool isDigit: /^[0-9]$/.test(modelData.id)
            x: modelData.x * kb.pitch
            y: modelData.r * kb.rowP
            width: modelData.w * kb.pitch - kb.gap
            height: (modelData.hr - 1) * kb.rowP + kb.keyH
            radius: 6
            color: held ? kb.pal.mid
                 : lit ? kb.pal.inner
                 : act ? Qt.alpha(kb.pal.inner, 0.22)
                 : Qt.rgba(1, 1, 1, 0.035)
            border.width: 1
            border.color: lit && act.dup ? kb.warn
                        : lit || held ? Qt.alpha(kb.acc, 0.45)
                        : Qt.rgba(1, 1, 1, 0.07)
            Behavior on color { ColorAnimation { duration: 90 } }

            Text {      // legend
                visible: cap.modelData.id !== "@super"
                x: 6; y: 3
                text: cap.modelData.leg
                font.family: Theme.mono
                font.pixelSize: cap.modelData.leg.length > 2 ? 9 : 11
                font.weight: Font.Bold
                color: cap.lit || cap.held ? kb.acc : kb.fg2
                opacity: cap.lit || cap.held ? 1 : 0.35
            }
            Text {      // Super: Arch glyph
                visible: cap.modelData.id === "@super"
                anchors.centerIn: parent
                text: "\u{f08c7}"
                font.family: Theme.monoIcons; font.pixelSize: 18
                color: cap.held ? kb.pal.text : kb.fg2
                opacity: cap.held ? 1 : 0.4
            }
            Text {      // tiny action label, only when it fits
                id: lbl
                x: 5; width: parent.width - 9
                anchors.bottom: parent.bottom; anchors.bottomMargin: 3
                text: cap.act?.text ?? ""
                visible: cap.lit && !(cap.isDigit && kb.digitSpan !== "") && !truncated && contentWidth <= width + 0.5 && contentHeight <= cap.height - 16
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                lineHeight: 0.9
                font.family: Theme.sans; font.pixelSize: 9; font.weight: Font.DemiBold
                color: cap.act?.dup ? kb.warn : kb.fg
            }
        }
    }

    Rectangle {     // label across the number row (Super + 1…0)
        visible: kb.digitsOn
        x: kb.pitch + 4; width: 10 * kb.pitch - kb.gap - 8
        y: kb.keyH - height - 4; height: 15; radius: 4
        color: Qt.alpha(kb.pal.cap, 0.55)
        border.width: 1; border.color: Qt.alpha(kb.acc, 0.25)
        Text {
            anchors.centerIn: parent
            text: kb.digitSpan
            font.family: Theme.sans; font.pixelSize: 10; font.weight: Font.DemiBold
            color: kb.fg
        }
    }
}
