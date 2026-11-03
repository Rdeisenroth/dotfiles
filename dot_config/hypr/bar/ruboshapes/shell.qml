//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.services

// ruboshapes bar (Quickshell). Run:  qs -p ~/.config/hypr/bar/ruboshapes-qs
// RUBOSHAPES_SCREENS="DP-1,DP-2" limits it to some monitors (testing).
ShellRoot {
    id: root
    Component.onCompleted: HyprSync.touch()     // instantiate the event -> refresh bridge
    readonly property var only: (Quickshell.env("RUBOSHAPES_SCREENS") ?? "").split(",").filter(s => s)
    Variants {
        model: Quickshell.screens.filter(s => root.only.length === 0 || root.only.includes(s.name))
        Bar {}
    }
}
