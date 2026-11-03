pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Hyprland

// Microphone / screen privacy for the bar:
//   micMuted     default microphone muted (sends a notification when it changes, from anywhere)
//   micUsers     apps with an audio capture stream open (desktop-audio captures and EasyEffects'
//                own processing are left out)
//   sharing      the screen is being shared/recorded (Hyprland screencast event)
Singleton {
    id: root

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool micMuted: source?.audio?.muted ?? false
    PwObjectTracker { objects: [root.source].concat(root.streams) }

    readonly property var streams: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioInStream)
    function ignored(n) {
        const p = n.properties ?? {};
        const app = (p["application.name"] ?? "") + " " + (p["application.process.binary"] ?? "") + " " + (n.name ?? "");
        return p["stream.capture.sink"] === "true" || p["stream.monitor"] === "true"   // recording desktop audio, not the mic
            || /easyeffects|peak detect|pavucontrol|cava/i.test(app);
    }
    readonly property var micUsers: {
        const names = [];
        for (const n of streams) {
            if (ignored(n)) continue;
            const p = n.properties ?? {};
            const name = p["application.name"] || n.description || p["application.process.binary"] || n.name || "Unknown app";
            if (!names.includes(name)) names.push(name);
        }
        return names;
    }
    readonly property bool micInUse: micUsers.length > 0

    // notify on mute changes (only real changes: not while starting up, not when the default mic switches)
    property bool armed: false
    property string lastSource: ""
    property bool lastMuted: false
    function remember() { lastSource = source ? String(source.id) : ""; lastMuted = micMuted }
    Timer { running: true; interval: 3000; onTriggered: { root.remember(); root.armed = true } }
    onSourceChanged: remember()
    onMicMutedChanged: {
        const id = source ? String(source.id) : "";
        if (armed && id === lastSource && micMuted !== lastMuted) {
            Quickshell.execDetached(["notify-send", "-a", "Microphone", "-u", micMuted ? "normal" : "low",
                                     "-i", micMuted ? "microphone-sensitivity-muted" : "microphone-sensitivity-high",
                                     micMuted ? "Microphone muted" : "Microphone on",
                                     (source.description || source.name) + (micMuted ? " is muted." : " is live again.")]);
        }
        remember();
    }

    function toggleMute() { if (source?.audio) source.audio.muted = !source.audio.muted }

    // screen sharing: Hyprland sends "screencast>>1,<owner>" when it starts and "screencast>>0,..." when it stops
    property bool sharing: false
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "screencast") root.sharing = e.data.split(",")[0] === "1" }
    }
}
