import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Io
import qs.services
import qs.components

PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property string mon: modelData.name
    readonly property var pal: Schemes.pal(mon)      // this monitor's colour scheme
    // layout by logical width: wide >= 2560, medium >= 1600, narrow below
    readonly property real lw: modelData.width
    readonly property string mode: lw >= 2560 ? "wide" : lw >= 1600 ? "medium" : "narrow"
    readonly property bool narrow: mode === "narrow"
    // padding inside the metric arrows: tighter on medium screens (labels have fixed widths)
    readonly property real metricPadL: mode === "wide" ? 7 : 4
    readonly property real metricPadR: mode === "wide" ? 11 : 7

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.h
    exclusiveZone: Theme.h
    color: "transparent"
    WlrLayershell.namespace: "ruboshapes"

    property bool trayOpen: false
    property bool schemeOpen: false
    property real schemeClosedAt: 0
    SchemePicker { screen: win.modelData; mon: win.mon; open: win.schemeOpen
        onCloseRequested: { win.schemeOpen = false; win.schemeClosedAt = Date.now() } }
    // the click that closed the picker (outside click on the logo) must not reopen it right away
    function toggleSchemes() {
        if (!schemeOpen && Date.now() - schemeClosedAt < 350) return;
        schemeOpen = !schemeOpen;
    }
    // debug/screenshots: force a hover state:  qs -p <dir> ipc call bar-DP-1 hover island|os|ws|cpu|ram|vol|bright|clock|""
    property string forced: ""
    IpcHandler { target: "bar-" + win.mon
        function hover(what: string): void { win.forced = what }
        function tray(): void { win.trayOpen = !win.trayOpen }
        function schemes(): void { win.schemeOpen = !win.schemeOpen } }   // schemes(): picker on this monitor

    Rectangle { anchors.fill: parent; color: win.pal.bar }

    // ---------------------------------------------------------------- separator (open middle only)
    Rectangle {
        x: left.x + left.width + 1; width: right.x - x - 1
        y: Theme.h - 2; height: 2
        gradient: Gradient { orientation: Gradient.Horizontal
            GradientStop { position: 0; color: win.pal.sep1 }
            GradientStop { position: 0.5; color: win.pal.sep2 }
            GradientStop { position: 1; color: win.pal.sep1 } }
    }

    // ---------------------------------------------------------------- left: os | workspaces | window
    Row {
        id: left
        spacing: 0
        Seg { pal: win.pal;       // Arch logo; hover reveals "Arch Linux", click opens the launcher
            id: os
            z: 3; fill: win.pal.cap; next: win.pal.mid; padL: 14; padR: 6
            HoverHandler { id: osHover }
            readonly property bool hov: osHover.hovered || win.forced === "os"
            Text { text: "\u{f303}"; font.family: Theme.mono; font.pixelSize: 23
                color: os.hov ? win.pal.accent : win.pal.logo; anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 200 } } }
            Item { clip: true; height: Theme.h; width: os.hov ? osName.implicitWidth + 4 : 0
                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.InOutCubic } }
                Text { id: osName; x: 4; anchors.verticalCenter: parent.verticalCenter; text: "Arch Linux"
                    font.family: Theme.sans; font.pixelSize: 15; font.weight: 700; color: win.pal.logo } }
            MouseArea { parent: os; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton      // right-click: colour schemes
                onClicked: e => e.button === Qt.RightButton ? win.toggleSchemes() : Caelestia.toggle("launcher", win.mon) }
        }
        Seg { pal: win.pal;
            id: wsSeg
            z: 2; fill: win.pal.mid; next: win.pal.inner; notch: true; padL: 8; padR: 6
            HoverHandler { id: wsHover }
            Workspaces { pal: win.pal; monitor: win.monitor; narrow: win.narrow; peek: wsHover.hovered || win.forced === "ws" }
            WheelHandler { onWheel: e => {
                const cur = win.monitor?.activeWorkspace?.id ?? 1, base = Math.floor((cur - 1) / 10) * 10;
                const idx = Math.max(1, Math.min(10, cur - base + (e.angleDelta.y > 0 ? -1 : 1)));
                Hyprland.dispatch(`hl.dsp.focus({ workspace = ${base + idx} })`);
            } }
        }
        Seg { pal: win.pal;       // focused app of this monitor + window title (full when there's room)
            id: winSeg
            z: 1; fill: win.pal.inner; next: win.pal.bar; notch: true; padL: 8; padR: 2; spacing: 9
            readonly property var ws: win.monitor?.activeWorkspace ?? null
            readonly property var topLevel: {
                const a = Hyprland.activeToplevel;
                if (a && a.workspace === ws) return a;
                const last = ws?.lastIpcObject?.lastwindow ?? "";
                return ws?.toplevels.values.find(t => ("0x" + t.address) === last || t.address === last) ?? ws?.toplevels.values[0] ?? null;
            }
            readonly property string cls: topLevel?.lastIpcObject?.class ?? ""
            // apps with a Nerd Font glyph are drawn in the theme accent (as before); others keep their real icon
            readonly property var glyphs: [["ghostty", "\u{f120}"], ["kitty", "\u{f120}"], ["alacritty", "\u{f120}"], ["konsole", "\u{f120}"],
                ["foot", "\u{f120}"], ["wezterm", "\u{f120}"], ["steam", "\u{f1b6}"], ["firefox", "\u{f269}"], ["zen", "\u{f269}"],
                ["chrom", "\u{f268}"], ["code", "\u{f0a1e}"], ["jetbrains", "\u{e7b5}"], ["idea", "\u{e7b5}"], ["spotify", "\u{f1bc}"],
                ["vesktop", "\u{f392}"], ["discord", "\u{f392}"], ["dolphin", "\u{f07b}"], ["nautilus", "\u{f07b}"], ["thunar", "\u{f07b}"],
                ["obsidian", "\u{f0b1e}"], ["nextcloud", "\u{f0c2}"], ["thunderbird", "\u{f0e0}"], ["vlc", "\u{f057c}"], ["mpv", "\u{f057c}"],
                ["gimp", "\u{f1fc}"], ["krita", "\u{f1fc}"]]
            readonly property string glyph: { const c = cls.toLowerCase(); return (glyphs.find(g => c.includes(g[0])) ?? ["", ""])[1] }
            readonly property string app: cls === "" ? "Desktop" : (cls.includes(".") ? cls.split(".").pop() : cls)
            readonly property string title: (topLevel?.title ?? "").toLowerCase() === app.toLowerCase() ? "" : (topLevel?.title ?? "")
            // everything up to the centred island minus a 16 px margin
            readonly property real budget: Math.max(60, island.x - 16 - x - padL - notchW - 30)
            // shown* lag behind the live values: on a change the old text slides up and fades out,
            // then the new one slides in from below; the box width glides to the new length
            property string shownCls: cls
            property string shownGlyph: glyph
            property string shownApp: app
            property string shownTitle: title
            // animate when a different window gets focus; title changes of the same window apply instantly
            // (only the window address: Hyprland reports the class a moment later, which must not restart it)
            readonly property string key: topLevel?.address ?? ""
            onKeyChanged: swap.restart()
            onTitleChanged: if (!swap.running) shownTitle = title
            onAppChanged: if (!swap.running) shownApp = app
            onClsChanged: if (!swap.running) { shownCls = cls; shownGlyph = glyph }
            SequentialAnimation {
                id: swap
                ParallelAnimation {
                    NumberAnimation { target: winRow; property: "opacity"; to: 0; duration: 70; easing.type: Easing.InQuad }
                    NumberAnimation { target: winRow; property: "y"; to: -6; duration: 70; easing.type: Easing.InQuad }
                }
                ScriptAction { script: {
                    winSeg.shownCls = winSeg.cls; winSeg.shownGlyph = winSeg.glyph
                    winSeg.shownApp = winSeg.app; winSeg.shownTitle = winSeg.title
                    winRow.y = 6
                } }
                ParallelAnimation {
                    NumberAnimation { target: winRow; property: "opacity"; to: 1; duration: 130; easing.type: Easing.OutCubic }
                    NumberAnimation { target: winRow; property: "y"; to: 0; duration: 130; easing.type: Easing.OutCubic }
                }
            }
            Item {
                id: winBox
                height: Theme.h
                clip: true
                width: winRow.implicitWidth
                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Row {
                    id: winRow
                    height: Theme.h
                    spacing: 9
                    Text { visible: winSeg.shownGlyph !== ""; text: winSeg.shownGlyph; font.family: Theme.mono; font.pixelSize: 16; color: win.pal.accent
                        anchors.verticalCenter: parent.verticalCenter }
                    IconImage { visible: winSeg.shownCls !== "" && winSeg.shownGlyph === ""; implicitSize: 16; anchors.verticalCenter: parent.verticalCenter
                        source: Quickshell.iconPath(DesktopEntries.heuristicLookup(winSeg.shownCls)?.icon ?? winSeg.shownCls.toLowerCase(), "application-x-executable") }
                    Text { id: appName; text: winSeg.shownApp; font.family: Theme.sans; font.pixelSize: 15; font.weight: Font.Bold; color: win.pal.text
                        anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                        width: Math.min(implicitWidth, win.narrow ? 140 : winSeg.budget) }
                    Text { visible: !win.narrow && winSeg.shownTitle !== ""; text: winSeg.shownTitle; font.family: Theme.mono; font.pixelSize: 14; color: win.pal.text2
                        anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                        width: Math.max(0, Math.min(implicitWidth, winSeg.budget - appName.width - 10)) }
                }
            }
        }
    }

    // ---------------------------------------------------------------- centre: music island
    Island { pal: win.pal;
        id: island
        monitorName: win.mon; narrow: win.narrow; forced: win.forced === "island"
        anchors.verticalCenter: parent.verticalCenter
        x: (win.width - (win.narrow ? 165 : 330)) / 2 - (hovered ? 48 : 0)   // grows symmetrically
        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
    }

    // ---------------------------------------------------------------- right: stats | tray | clock
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink?.audio ?? null
    readonly property int volPct: Math.round((sink?.volume ?? 0) * 100)   // same rounded value the label shows
    // metric arrows (left to right) and their shades: inner colour -> towards the tray (mid) colour
    readonly property var metrics: ["cpu", "ram", "vol"].concat(Brightness.values[mon] !== undefined ? ["bright"] : [])
                                   .concat((UPower.displayDevice?.isLaptopBattery ?? false) ? ["bat"] : [])
    function metricFill(key) {
        const i = Math.max(0, metrics.indexOf(key));
        return Schemes.alpha(Schemes.mix(pal.inner, pal.mid, i / (metrics.length + 0.6)), pal.inner.a);
    }
    function metricNext(key) { const i = metrics.indexOf(key); return i <= 0 ? pal.bar : metricFill(metrics[i - 1]) }
    readonly property color lastMetricFill: narrow ? pal.inner : metricFill(metrics[metrics.length - 1])

    Row {
        id: right
        anchors.right: parent.right
        spacing: 0
        // metrics: on wide/medium screens every metric is its own arrow, like the polybar "shapes" theme,
        // shaded from the inner colour (towards the middle) up to the tray colour. Narrow screens: rings.
        component Stat: Item {
            id: st
            property string icon; property real gap: 4; property string iconFont: Theme.mono; property string label; property string widest: "100%"; property var icons: [icon]; property string key; property bool hover: hh.hovered || win.forced === key
            default property alias extra: extraBox.data
            signal clicked(); signal scrolled(bool up)
            implicitWidth: strow.implicitWidth; implicitHeight: Theme.h
            anchors.verticalCenter: parent?.verticalCenter
            HoverHandler { id: hh }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton
                onClicked: st.clicked(); onWheel: e => st.scrolled(e.angleDelta.y > 0) }
            Row { id: strow; spacing: st.gap; height: Theme.h
            Text { text: st.icon; font.family: st.iconFont; font.pixelSize: 15; color: win.pal.accent; anchors.verticalCenter: parent.verticalCenter
                // only icons that change (volume): widest glyph's width, right-aligned for an even gap to the number
                width: st.icons.length > 1 ? stIconMeasure.implicitWidth : implicitWidth
                horizontalAlignment: st.icons.length > 1 ? Text.AlignRight : Text.AlignLeft
                // hidden stack of all its glyphs, rendered like the icon: its width is the widest one
                Column { id: stIconMeasure; visible: false
                    Repeater { model: st.icons; Text { required property string modelData; text: modelData; font.family: st.iconFont; font.pixelSize: 15 } } } }
            // fixed width (widest possible value), so 9% -> 10% -> 100% doesn't resize the bar
            Text { text: st.label; font.family: Theme.mono; font.pixelSize: 14; font.weight: 700; color: win.pal.text; anchors.verticalCenter: parent.verticalCenter
                width: Math.ceil(stWidest.advanceWidth); horizontalAlignment: Text.AlignLeft   // longer values (vol > 100%) may overflow
                TextMetrics { id: stWidest; font.family: Theme.mono; font.pixelSize: 14; font.weight: 700; text: st.widest } }
            Item { id: extraBox; clip: true; height: Theme.h; anchors.verticalCenter: parent.verticalCenter
                width: st.hover ? (children[0]?.implicitWidth ?? 0) : 0
                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.InOutCubic } } }
            }
        }

        Seg { pal: win.pal; visible: !win.narrow; z: 1.0; rightSide: true; notch: true; padL: win.metricPadL; padR: win.metricPadR
            fill: win.metricFill("cpu"); next: win.metricNext("cpu")
                Stat { key: "cpu"; icon: "\u{f4bc}"; label: Math.round(Stats.cpu) + "%"
                    onClicked: Quickshell.execDetached(["missioncenter"])
                    Row { spacing: 8; anchors.verticalCenter: parent.verticalCenter; leftPadding: 3
                        Rectangle { width: 96; height: 26; radius: 5; color: Qt.rgba(1, 1, 1, 0.06)
                            Spark { pal: win.pal; anchors.fill: parent; anchors.margins: 2; values: Stats.cpuHist } }
                        Row { spacing: 1; anchors.verticalCenter: parent.verticalCenter
                            Repeater { model: Stats.cores
                                Rectangle { required property real modelData; width: 3; height: 22; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.08)
                                    Rectangle { anchors.bottom: parent.bottom; width: 3; radius: 1.5; height: Math.max(2, 22 * modelData / 100)
                                        color: modelData > 85 ? "#fbbf24" : win.pal.accent } } } } } }
        }
        Seg { pal: win.pal; visible: !win.narrow; z: 1.1; rightSide: true; notch: true; padL: win.metricPadL; padR: win.metricPadR
            fill: win.metricFill("ram"); next: win.metricNext("ram")
                Stat { key: "ram"; icon: "\u{efc5}"; iconFont: "CaskaydiaCove Nerd Font"; label: (Stats.memUsed / 1073741824).toFixed(1) + "G"; widest: (Stats.memTotal / 1073741824).toFixed(1) + "G"
                    onClicked: Quickshell.execDetached(["missioncenter"])
                    Item { implicitWidth: 113; height: Theme.h
                        Rectangle { x: 3; anchors.verticalCenter: parent.verticalCenter; width: 110; height: 26; radius: 5; color: Qt.rgba(1, 1, 1, 0.06)
                            Spark { pal: win.pal; anchors.fill: parent; anchors.margins: 2; values: Stats.memHist } } } }
        }
        Seg { pal: win.pal; visible: !win.narrow; z: 1.2; rightSide: true; notch: true; padL: win.metricPadL; padR: win.metricPadR
            fill: win.metricFill("vol"); next: win.metricNext("vol")
                Stat { key: "vol"; icons: ["\u{f0581}", "\u{f057f}", "\u{f0580}", "\u{f057e}"]; icon: !win.sink || win.sink.muted ? "\u{f0581}" : win.volPct < 34 ? "\u{f057f}" : win.volPct < 67 ? "\u{f0580}" : "\u{f057e}"
                    label: win.volPct + "%"
                    opacity: win.sink?.muted ? 0.5 : 1
                    onClicked: if (win.sink) win.sink.muted = !win.sink.muted
                    onScrolled: up => { if (win.sink) win.sink.volume = Math.max(0, Math.min(1.5, win.sink.volume + (up ? 0.05 : -0.05))) }
                    Slider { pal: win.pal; value: win.sink?.volume ?? 0; onMoved: v => { if (win.sink) win.sink.volume = v } } }
        }
        Seg { pal: win.pal; visible: !win.narrow && win.metrics.includes("bright"); z: 1.3; rightSide: true; notch: true; padL: win.metricPadL; padR: win.metricPadR
            fill: win.metricFill("bright"); next: win.metricNext("bright")
                Stat {
                    key: "bright"; icon: "\u{f00e0}"; label: (Brightness.values[win.mon] ?? 0) + "%"
                    onScrolled: up => Brightness.step(win.mon, up)
                    Slider { pal: win.pal; value: (Brightness.values[win.mon] ?? 0) / 100; onMoved: v => Brightness.set(win.mon, v * 100) } }
        }
        Seg { pal: win.pal; visible: !win.narrow && win.metrics.includes("bat"); z: 1.4; rightSide: true; notch: true; padL: win.metricPadL; padR: win.metricPadR
            fill: win.metricFill("bat"); next: win.metricNext("bat")
                Battery { pal: win.pal; anchors.verticalCenter: parent.verticalCenter }
        }
        Seg { pal: win.pal;
            id: ringSeg
            visible: win.narrow
            z: 1; rightSide: true; fill: win.pal.inner; next: win.pal.bar; notch: true; padL: 11; padR: 20; spacing: 7
            Ring { pal: win.pal; value: Stats.cpu; icon: "\u{f4bc}" }
            Ring { pal: win.pal; value: 100 * Stats.memUsed / Stats.memTotal; icon: "\u{f035b}" }
            Ring { pal: win.pal; value: win.volPct; icon: win.sink?.muted ? "\u{f0581}" : win.volPct < 34 ? "\u{f057f}" : win.volPct < 67 ? "\u{f0580}" : "\u{f057e}"
                MouseArea { anchors.fill: parent; onClicked: if (win.sink) win.sink.muted = !win.sink.muted
                    onWheel: e => { if (win.sink) win.sink.volume = Math.max(0, Math.min(1.5, win.sink.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05))) } } }
            Ring { pal: win.pal; visible: Brightness.values[win.mon] !== undefined; value: Brightness.values[win.mon] ?? 0; icon: "\u{f00e0}"
                MouseArea { anchors.fill: parent; onWheel: e => Brightness.step(win.mon, e.angleDelta.y > 0) } }
            Battery { pal: win.pal; anchors.verticalCenter: parent.verticalCenter }
        }
        Seg { pal: win.pal;       // our own status icons + chevron for the app tray dropdown
            id: traySeg
            z: 2; rightSide: true; fill: win.pal.mid; next: win.lastMetricFill; notch: true; padL: 4; padR: 6; spacing: 4
            component Ti: Rectangle {
                id: ti
                property string glyph; property bool off: false; property string tip; default property alias extra: extraRow.data
                property color tint: win.pal.tray
                property bool alert: false          // privacy icons: dark pill so red/amber reads on any scheme
                signal leftClick(); signal rightClick(); signal middle()
                width: row_.implicitWidth + 10; height: 28; radius: 14; anchors.verticalCenter: parent.verticalCenter
                color: ti.alert ? Qt.rgba(0, 0, 0, ma.containsMouse ? 0.55 : 0.42) : ma.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
                Row { id: row_; anchors.centerIn: parent; spacing: 5; height: 28
                    Text { text: ti.glyph; font.family: Theme.monoIcons; font.pixelSize: 16; color: Qt.alpha(ti.tint, ti.off ? 0.45 : 1)
                        anchors.verticalCenter: parent.verticalCenter }
                    Row { id: extraRow; anchors.verticalCenter: parent.verticalCenter } }
                PopupWindow {   // hover tooltip (tip text), centred under the icon
                    visible: ma.containsMouse && ti.tip !== ""
                    anchor.item: ti
                    anchor.rect.x: (ti.width - implicitWidth) / 2
                    anchor.rect.y: ti.height + 10
                    implicitWidth: tipText.implicitWidth + 22; implicitHeight: tipText.implicitHeight + 14
                    color: "transparent"
                    Rectangle { anchors.fill: parent; radius: 8; color: win.pal.menuSolid
                        border.width: 1; border.color: Qt.alpha(Theme.border1, 0.6)
                        Text { id: tipText; anchors.centerIn: parent; text: ti.tip; textFormat: Text.StyledText
                            font.family: Theme.sans; font.pixelSize: 12; color: win.pal.menuText; lineHeight: 1.15 } }
                }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.AllButtons; cursorShape: Qt.PointingHandCursor
                    onClicked: e => e.button === Qt.RightButton ? ti.rightClick() : e.button === Qt.MiddleButton ? ti.middle() : ti.leftClick() }
            }
            // privacy: screen shared / microphone muted or in use (hidden otherwise)
            Ti { visible: Privacy.sharing; glyph: "\u{f1483}"; tint: "#f87171"; alert: true
                tip: "<b>Screen is being shared</b>" }
            Ti { visible: Privacy.micMuted || Privacy.micInUse
                glyph: Privacy.micMuted ? "\u{f036d}" : "\u{f036c}"
                tint: Privacy.micMuted ? "#f87171" : "#fbbf24"; alert: true
                tip: (Privacy.micMuted ? "<b>Microphone muted</b>" : "<b>Microphone in use</b>")
                     + (Privacy.micUsers.length ? "<br>" + Privacy.micUsers.map(n => "• " + n).join("<br>") : "")
                     + "<br><font color='" + win.pal.menuDim + "'>" + (Privacy.micMuted ? "Click to unmute" : "Click to mute") + " · right click: mixer</font>"
                onLeftClick: Privacy.toggleMute()
                onRightClick: Quickshell.execDetached(["pavucontrol-qt"])
                SequentialAnimation on opacity {   // gentle pulse while an app listens
                    running: Privacy.micInUse && !Privacy.micMuted; loops: Animation.Infinite
                    onRunningChanged: if (!running) parent.opacity = 1
                    NumberAnimation { to: 0.55; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine } } }
            readonly property var adapter: Bluetooth.defaultAdapter
            readonly property int btConnected: Bluetooth.devices.values.filter(d => d.connected).length
            Ti { glyph: !traySeg.adapter?.enabled ? "\u{f00b2}" : traySeg.btConnected > 0 ? "\u{f00b1}" : "\u{f293}"; off: !traySeg.adapter?.enabled
                onLeftClick: Quickshell.execDetached(["blueman-manager"])
                onRightClick: if (traySeg.adapter) traySeg.adapter.enabled = !traySeg.adapter.enabled }
            Ti { glyph: Net.type === "ethernet" ? "\u{f0200}" : Net.type === "wifi" ? (Net.signal > 66 ? "\u{f0928}" : Net.signal > 33 ? "\u{f0925}" : "\u{f091f}") : "\u{f092e}"
                off: Net.type === "none"
                // nm-applet lives here instead of the tray dropdown: right click = its menu, click = connection editor
                readonly property var nm: SystemTray.items.values.find(i => i.id === "nm-applet") ?? null
                tip: "<b>" + (Net.type === "wifi" ? "WLAN" : Net.type === "ethernet" ? "Ethernet" : "Network") + "</b><br>"
                     + Net.name + (Net.type === "wifi" ? " · " + Net.signal + "%" : "")
                     + (Net.vpn ? "<br>VPN: " + Net.vpn : "")
                     + "<br><font color='" + win.pal.menuDim + "'>Click: connection editor · right click: networks</font>"
                Text { visible: Net.vpn !== ""; text: "\u{f033e}"; font.family: Theme.monoIcons; font.pixelSize: 11   // VPN lock
                    color: win.pal.tray; anchors.verticalCenter: parent.verticalCenter }
                onLeftClick: Quickshell.execDetached(["nm-connection-editor"])
                onRightClick: {
                    if (nm?.hasMenu) { const pt = mapToItem(null, 0, height + 6); nm.display(win, pt.x, pt.y) }
                    else Quickshell.execDetached(["nm-connection-editor"]);
                } }
            Ti { glyph: Notifs.dnd ? "\u{f009b}" : "\u{f009a}"; off: Notifs.dnd
                onLeftClick: Caelestia.toggle("sidebar", win.mon); onRightClick: Notifs.toggleDnd(); onMiddle: Notifs.clear()
                Text { visible: Notifs.count > 0 && !Notifs.dnd; text: Notifs.count > 99 ? "99+" : Notifs.count
                    font.family: Theme.mono; font.weight: 800; font.pixelSize: 14; color: win.pal.tray } }
            Ti { id: chev; glyph: ""; onLeftClick: win.trayOpen = !win.trayOpen
                color: win.trayOpen ? Qt.rgba(0.016, 0.086, 0.082, 0.55) : "transparent"
                Image { source: "file://" + Quickshell.shellDir + "/assets/chev-" + (win.pal.light ? "light" : "dark") + ".svg"
                    sourceSize: Qt.size(16, 16); width: 16; height: 16; smooth: true
                    rotation: win.trayOpen ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } } }
            }
        }
        Seg { pal: win.pal;       // clock: hover shows the date, click opens the power menu
            id: clock
            z: 3; rightSide: true; fill: win.pal.cap; next: win.pal.mid; padL: 4; padR: 14; spacing: 2
            HoverHandler { id: clockHover }
            readonly property bool hov: clockHover.hovered || win.forced === "clock"
            SystemClock { id: sc; precision: SystemClock.Seconds }
            Item { clip: true; height: Theme.h; width: clock.hov ? date.implicitWidth + 9 : 0
                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.InOutCubic } }
                Text { id: date; anchors.verticalCenter: parent.verticalCenter; text: Qt.locale().toString(sc.date, "ddd d. MMM")
                    font.family: Theme.sans; font.pixelSize: 14; font.weight: 600; color: win.pal.accent } }
            Text { text: Qt.formatTime(sc.date, "hh:mm"); font.family: Theme.mono; font.pixelSize: 15; font.weight: 800; color: win.pal.text; anchors.verticalCenter: parent.verticalCenter }
            Text { visible: !win.narrow; text: ":" + Qt.formatTime(sc.date, "ss"); font.family: Theme.mono; font.pixelSize: 15; font.weight: 800
                color: Qt.alpha(win.pal.text, 0.6); anchors.verticalCenter: parent.verticalCenter }
            MouseArea { parent: clock; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Caelestia.toggle("session", win.mon) }
        }
    }

    // ---------------------------------------------------------------- tray dropdown
    // its own layer window (not an xdg popup) so Hyprland's layer blur rule applies to it
    PanelWindow {
        id: trayPop
        screen: win.modelData
        anchors { top: true; right: true }
        margins.top: 6
        margins.right: win.width - (right.x + traySeg.x + chev.x + chev.width + 10)
        exclusionMode: ExclusionMode.Normal
        WlrLayershell.namespace: "ruboshapes-tray"
        WlrLayershell.layer: WlrLayer.Overlay
        implicitWidth: trayFrame.width; implicitHeight: trayFrame.height + 10
        visible: win.trayOpen || fade.running
        color: "transparent"
        Rectangle {
            id: trayFrame
            width: trayRow.implicitWidth + 28; height: 40; radius: 10
            color: win.pal.menu
            opacity: win.trayOpen ? 1 : 0
            y: win.trayOpen ? 0 : -10
            Behavior on opacity { NumberAnimation { id: fade; duration: 180 } }
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
            // Hyprland window border look (look.lua): 2 px, teal top-left -> purple bottom-right
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillRule: ShapePath.OddEvenFill
                    fillGradient: LinearGradient { x1: 0; y1: 0; x2: trayFrame.width; y2: trayFrame.height
                        GradientStop { position: 0; color: Theme.border1 }
                        GradientStop { position: 1; color: Qt.alpha(Theme.border2, 0.93) } }
                    PathRectangle { width: trayFrame.width; height: trayFrame.height; radius: 10 }
                    PathRectangle { x: 2; y: 2; width: trayFrame.width - 4; height: trayFrame.height - 4; radius: 8 }
                }
            }
            Row {
                id: trayRow
                anchors.centerIn: parent
                spacing: 14
                Repeater {
                    // blueman-tray ignores its StatusIcon setting; Bluetooth and network have pinned icons in the bar
                    model: SystemTray.items.values.filter(i => i.id !== "blueman" && i.id !== "nm-applet")   // both have pinned icons
                    MouseArea {
                        id: trayItem
                        required property var modelData
                        width: 18; height: 18
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        // hover: which app this is (+ its own tooltip text, e.g. the playing track)
                        readonly property string appName: {
                            // desktop entry name, else a short tooltip title ("Vesktop", "Easy Effects"), else title/id
                            const tt = (modelData.tooltipTitle ?? "").trim();
                            const n = DesktopEntries.heuristicLookup(modelData.id)?.name
                                      || (tt && tt.length <= 30 && !/[:\n]/.test(tt) ? tt : "") || modelData.title || modelData.id;
                            return n.charAt(0).toUpperCase() + n.slice(1);
                        }
                        readonly property string tipText: {
                            const clean = t => (t ?? "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
                            const esc = t => t.replace(/&/g, "&amp;").replace(/</g, "&lt;");
                            const lines = ["<b>" + esc(appName) + "</b>"];
                            for (const t of [clean(modelData.tooltipTitle), clean(modelData.tooltipDescription)])
                                if (t && t !== appName && !lines.some(l => l.includes(esc(t))))
                                    lines.push("<font color='" + win.pal.menuDim + "'>" + esc(t.length > 60 ? t.slice(0, 57) + "…" : t) + "</font>");
                            return lines.join("<br>");
                        }
                        PopupWindow {
                            visible: trayItem.containsMouse
                            anchor.item: trayItem
                            anchor.rect.x: (trayItem.width - implicitWidth) / 2
                            anchor.rect.y: trayItem.height + 16
                            implicitWidth: trayTip.implicitWidth + 22; implicitHeight: trayTip.implicitHeight + 14
                            color: "transparent"
                            Rectangle { anchors.fill: parent; radius: 8; color: win.pal.menuSolid
                                border.width: 1; border.color: Qt.alpha(Theme.border1, 0.6)
                                Text { id: trayTip; anchors.centerIn: parent; text: trayItem.tipText; textFormat: Text.StyledText
                                    font.family: Theme.sans; font.pixelSize: 12; color: win.pal.menuText; lineHeight: 1.15 } }
                        }
                        cursorShape: Qt.PointingHandCursor
                        onClicked: e => {
                            if (e.button === Qt.RightButton && modelData.hasMenu) {
                                const p = mapToItem(null, 0, height);
                                modelData.display(trayPop, p.x, p.y + 4);
                            } else modelData.activate();
                        }
                        IconImage { anchors.fill: parent; source: {
                            let i = parent.modelData.icon;
                            if (i.includes("?path=")) { const [n, p] = i.split("?path="); const f = n.slice(n.lastIndexOf("/") + 1);
                                i = Quickshell.iconPath(f, true) || `file://${p}/${f}`; }
                            return i; } }
                    }
                }
            }
        }
    }
}
