pragma Singleton
import QtQuick
import Quickshell

// ruboshapes colours. Dark: near-black caps -> teal -> deep teal towards the middle; light mirrors it.
Singleton {
    property bool light: Quickshell.env("RUBOSHAPES_THEME") === "light"

    readonly property int h: 40               // bar height
    readonly property int tip: 13             // arrow depth
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property string monoIcons: "JetBrainsMono Nerd Font Mono"
    readonly property string sans: "Noto Sans"

    readonly property color bar: light ? Qt.rgba(0.97, 0.98, 0.99, 0.80) : Qt.rgba(0.043, 0.059, 0.078, 0.78)
    readonly property color cap: light ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(0.012, 0.024, 0.024, 0.82)
    readonly property color mid: light ? Qt.rgba(0.80, 0.98, 0.95, 0.88) : Qt.rgba(0.051, 0.580, 0.533, 0.88)
    readonly property color inner: light ? Qt.rgba(0.37, 0.92, 0.83, 0.90) : Qt.rgba(0.075, 0.306, 0.290, 0.88)
    readonly property color sep1: light ? "#14b8a6" : "#2dd4bf"
    readonly property color sep2: light ? "#4ade80" : "#86efac"

    readonly property color logo: light ? "#0f766e" : "#ecfeff"
    readonly property color dots: light ? "#041a19" : "#ecfeff"
    readonly property color pill: light ? "#041a19" : "#2dd4bf"
    readonly property color pillText: light ? "#5eead4" : "#041a19"
    readonly property color accent: light ? "#0f766e" : "#5eead4"
    readonly property color text: light ? "#042f2e" : "#ecfeff"
    readonly property color text2: light ? "#0f766e" : "#99f6e4"
    readonly property color tray: light ? "#041a19" : "#ecfeff"
    readonly property color island: light ? Qt.rgba(1, 1, 1, 0.92) : Qt.rgba(0.008, 0.024, 0.090, 0.90)
    readonly property color islandStroke: light ? Qt.rgba(0.05, 0.58, 0.53, 0.25) : Qt.rgba(0.18, 0.83, 0.75, 0.20)
    readonly property color islandText: light ? "#0f172a" : "#ffffff"
    readonly property color islandSub: light ? "#64748b" : "#94a3b8"
    readonly property color eq: light ? "#0d9488" : "#2dd4bf"
    readonly property color track: light ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.15)
    readonly property color shadow: light ? Qt.rgba(0.06, 0.09, 0.16, 0.22) : Qt.rgba(0, 0, 0, 0.55)
    readonly property color popup: Qt.rgba(0.016, 0.086, 0.082, 0.62)
    readonly property color border1: "#53e2ae"        // Hyprland window border (look.lua)
    readonly property color border2: "#6603fc"

    function lum(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }
}
