pragma Singleton
import QtQuick
import Quickshell

// Opens Caelestia drawers (dashboard / session / sidebar) on a given monitor via scripts/dashboard.sh
// (serialised clicks + double-click debounce + toggleOn IPC from our Caelestia patch).
Singleton {
    readonly property string helper: Quickshell.shellDir + "/scripts/dashboard.sh"
    function toggle(drawer, mon) { Quickshell.execDetached(["setsid", "-f", helper, mon, drawer]) }
}
