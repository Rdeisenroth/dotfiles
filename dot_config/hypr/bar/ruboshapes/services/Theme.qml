pragma Singleton
import QtQuick
import Quickshell

// ruboshapes constants. Colours are per monitor: see Schemes.qml (components get a `pal` object).
Singleton {
    readonly property int h: 40               // bar height
    readonly property int tip: 13             // arrow depth
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property string monoIcons: "JetBrainsMono Nerd Font Mono"
    readonly property string sans: "Noto Sans"

    readonly property color border1: "#53e2ae"        // Hyprland window border (look.lua)
    readonly property color border2: "#6603fc"

    function lum(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }
}
