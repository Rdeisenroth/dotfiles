pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Quickshell only re-reads Hyprland's clients/workspaces when asked: refresh on the relevant events
// (same scheme as Caelestia's Hypr service) so workspace icons and titles stay live.
Singleton {
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (n.endsWith("v2")) return;
            if (["openwindow", "closewindow", "movewindow"].includes(n)) {
                Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces();
            } else if (["workspace", "moveworkspace", "focusedmon", "createworkspace", "destroyworkspace"].includes(n)) {
                Hyprland.refreshWorkspaces(); Hyprland.refreshMonitors();
            } else if (n.includes("window") || ["fullscreen", "changefloatingmode", "pin"].includes(n)) {
                Hyprland.refreshToplevels();
            }
        }
    }
    function touch() {}
}
