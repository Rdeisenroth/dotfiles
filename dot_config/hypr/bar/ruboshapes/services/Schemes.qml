pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Per-monitor colour schemes.
//   scheme: "ruboshapes" (the hand-tuned teal default), any Tailwind palette name ("blue", "rose", ...),
//           or "wallpaper" (follows the most vivid colour of that monitor's wallpaper)
//   mode:   "dark" | "light"
// Every scheme maps the same Tailwind shades onto the bar roles the teal design uses (600 for the
// middle segments, 900 for the inner ones, 300 accents, ...), so all presets keep the 07g look.
// Settings: ~/.local/state/ruboshapes/schemes.json   IPC: qs -p <dir> ipc call schemes set|mode|list
Singleton {
    id: root

    // ---------------------------------------------------------------- data
    // Tailwind v3 palettes: 50 100 200 300 400 500 600 700 800 900 950
    readonly property var tw: ({
        red:     ["#fef2f2", "#fee2e2", "#fecaca", "#fca5a5", "#f87171", "#ef4444", "#dc2626", "#b91c1c", "#991b1b", "#7f1d1d", "#450a0a"],
        orange:  ["#fff7ed", "#ffedd5", "#fed7aa", "#fdba74", "#fb923c", "#f97316", "#ea580c", "#c2410c", "#9a3412", "#7c2d12", "#431407"],
        amber:   ["#fffbeb", "#fef3c7", "#fde68a", "#fcd34d", "#fbbf24", "#f59e0b", "#d97706", "#b45309", "#92400e", "#78350f", "#451a03"],
        yellow:  ["#fefce8", "#fef9c3", "#fef08a", "#fde047", "#facc15", "#eab308", "#ca8a04", "#a16207", "#854d0e", "#713f12", "#422006"],
        lime:    ["#f7fee7", "#ecfccb", "#d9f99d", "#bef264", "#a3e635", "#84cc16", "#65a30d", "#4d7c0f", "#3f6212", "#365314", "#1a2e05"],
        green:   ["#f0fdf4", "#dcfce7", "#bbf7d0", "#86efac", "#4ade80", "#22c55e", "#16a34a", "#15803d", "#166534", "#14532d", "#052e16"],
        emerald: ["#ecfdf5", "#d1fae5", "#a7f3d0", "#6ee7b7", "#34d399", "#10b981", "#059669", "#047857", "#065f46", "#064e3b", "#022c22"],
        teal:    ["#f0fdfa", "#ccfbf1", "#99f6e4", "#5eead4", "#2dd4bf", "#14b8a6", "#0d9488", "#0f766e", "#115e59", "#134e4a", "#042f2e"],
        cyan:    ["#ecfeff", "#cffafe", "#a5f3fc", "#67e8f9", "#22d3ee", "#06b6d4", "#0891b2", "#0e7490", "#155e75", "#164e63", "#083344"],
        sky:     ["#f0f9ff", "#e0f2fe", "#bae6fd", "#7dd3fc", "#38bdf8", "#0ea5e9", "#0284c7", "#0369a1", "#075985", "#0c4a6e", "#082f49"],
        blue:    ["#eff6ff", "#dbeafe", "#bfdbfe", "#93c5fd", "#60a5fa", "#3b82f6", "#2563eb", "#1d4ed8", "#1e40af", "#1e3a8a", "#172554"],
        indigo:  ["#eef2ff", "#e0e7ff", "#c7d2fe", "#a5b4fc", "#818cf8", "#6366f1", "#4f46e5", "#4338ca", "#3730a3", "#312e81", "#1e1b4b"],
        violet:  ["#f5f3ff", "#ede9fe", "#ddd6fe", "#c4b5fd", "#a78bfa", "#8b5cf6", "#7c3aed", "#6d28d9", "#5b21b6", "#4c1d95", "#2e1065"],
        purple:  ["#faf5ff", "#f3e8ff", "#e9d5ff", "#d8b4fe", "#c084fc", "#a855f7", "#9333ea", "#7e22ce", "#6b21a8", "#581c87", "#3b0764"],
        fuchsia: ["#fdf4ff", "#fae8ff", "#f5d0fe", "#f0abfc", "#e879f9", "#d946ef", "#c026d3", "#a21caf", "#86198f", "#701a75", "#4a044e"],
        pink:    ["#fdf2f8", "#fce7f3", "#fbcfe8", "#f9a8d4", "#f472b6", "#ec4899", "#db2777", "#be185d", "#9d174d", "#831843", "#500724"],
        rose:    ["#fff1f2", "#ffe4e6", "#fecdd3", "#fda4af", "#fb7185", "#f43f5e", "#e11d48", "#be123c", "#9f1239", "#881337", "#4c0519"],
        slate:   ["#f8fafc", "#f1f5f9", "#e2e8f0", "#cbd5e1", "#94a3b8", "#64748b", "#475569", "#334155", "#1e293b", "#0f172a", "#020617"],
        gray:    ["#f9fafb", "#f3f4f6", "#e5e7eb", "#d1d5db", "#9ca3af", "#6b7280", "#4b5563", "#374151", "#1f2937", "#111827", "#030712"],
        stone:   ["#fafaf9", "#f5f5f4", "#e7e5e4", "#d6d3d1", "#a8a29e", "#78716c", "#57534e", "#44403c", "#292524", "#1c1917", "#0c0a09"]
    })
    readonly property var chromatic: ["red", "orange", "amber", "yellow", "lime", "green", "emerald", "teal", "cyan", "sky", "blue",
                                      "indigo", "violet", "purple", "fuchsia", "pink", "rose"]
    // picker order: special entries first, then the colour wheel, then the neutrals
    readonly property var presets: ["wallpaper", "ruboshapes"].concat(chromatic).concat(["slate", "gray", "stone"])
    function title(id) {
        return id === "wallpaper" ? "Wallpaper" : id === "ruboshapes" ? "Ruboshapes" : id.charAt(0).toUpperCase() + id.slice(1);
    }

    // ---------------------------------------------------------------- settings (per monitor)
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/ruboshapes"
    property var settings: ({})                 // { "DP-1": { scheme, mode }, ... }
    readonly property var defaults: ({ scheme: "ruboshapes", mode: Quickshell.env("RUBOSHAPES_THEME") === "light" ? "light" : "dark" })
    function settingFor(mon) { return Object.assign({}, defaults, settings[mon] ?? {}) }
    function set(mon, key, value) {
        const s = Object.assign({}, settings);
        const mons = mon === "*" ? Quickshell.screens.map(x => x.name) : [mon];
        for (const m of mons) s[m] = Object.assign({}, settingFor(m), { [key]: value });
        settings = s;
        store.setText(JSON.stringify(settings, null, 2) + "\n");
    }

    FileView {
        id: store
        path: root.stateDir + "/schemes.json"
        // no watchChanges: this service is the only writer (reloading mid-write raced with quick changes)
        onLoaded: { try { root.settings = JSON.parse(text()) } catch (e) {} }
    }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", stateDir])

    IpcHandler {
        target: "schemes"
        function set(monitor: string, scheme: string): void { root.set(monitor, "scheme", scheme) }      // monitor "*" = all
        function mode(monitor: string, mode: string): void { root.set(monitor, "mode", mode) }
        function list(): string { return root.presets.join(" ") }
        function cycle(monitor: string): void {     // next wallpaper colour option
            const c = root.wpCandidates[monitor] ?? [];
            if (c.length === 0) return;
            const i = c.findIndex(x => root.sameColor(x, root.wpColor[monitor]));
            root.pickWallpaperColor(monitor, c[(i + 1) % c.length]);
        }
        function main(monitor: string): void { root.setSystem("monitor", monitor) }        // system follows this monitor
        function terminal(on: bool): void { root.setSystem("terminal", on) }
        function part(name: string, monitor: string): void { root.setTarget(name, monitor) }   // borders|qt|gtk|caelestia|vesktop|spicetify
        function system(): string { return root.mainMonitor + " " + root.systemSig }
        function pick(monitor: string, index: int): void { const c = (root.wpCandidates[monitor] ?? [])[index]; if (c) root.pickWallpaperColor(monitor, c) }   // wallpaper colour option
        function wallpaper(monitor: string): string { return (root.wallpapers[monitor] ?? "") + " " + (root.wpColor[monitor] ?? "") + " [" + (root.wpCandidates[monitor] ?? []).join(" ") + "]" }
    }

    // ---------------------------------------------------------------- wallpaper colours
    property var wallpapers: ({})               // monitor -> image path (from `awww query`)
    property var wpCandidates: ({})             // monitor -> distinct vivid colours of its wallpaper, best first
    // chosen colour per wallpaper image (remembered in the settings file under "_wallpapers")
    readonly property var wpChoice: settings._wallpapers ?? ({})
    // monitor -> colour used by the "wallpaper" scheme: the remembered pick for this image, else the best one
    readonly property var wpColor: {
        const out = {};
        for (const mon in wallpapers) {
            const picked = wpChoice[wallpapers[mon]];
            const c = picked ? Qt.color(picked) : (wpCandidates[mon] ?? [])[0];
            if (c) out[mon] = c;
        }
        return out;
    }
    // pick one of the wallpaper's colours for this monitor (and remember it for this image)
    function pickWallpaperColor(mon, color) {
        const path = wallpapers[mon];
        if (!path) return;
        const s = Object.assign({}, settings);
        s._wallpapers = Object.assign({}, s._wallpapers ?? {}, { [path]: color.toString() });
        s[mon] = Object.assign({}, settingFor(mon), { scheme: "wallpaper" });
        settings = s;
        store.setText(JSON.stringify(settings, null, 2) + "\n");
    }
    function sameColor(a, b) { return !!a && !!b && a.toString() === b.toString() }
    Process {
        id: query
        command: ["awww", "query"]
        stdout: StdioCollector { onStreamFinished: {
            // ": DP-1: 2560x1440, scale: 1, currently displaying: image: /path/to/file.jpg"
            const w = {};
            for (const line of text.split("\n")) {
                const m = line.match(/^:?\s*([^:]+):.*image:\s*(.+)$/);
                if (m) w[m[1].trim()] = m[2].trim();
            }
            if (JSON.stringify(w) !== JSON.stringify(root.wallpapers)) root.wallpapers = w;
        } }
    }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: query.running = true }

    Instantiator {
        model: Object.keys(root.wallpapers)
        delegate: ColorQuantizer {
            required property string modelData
            source: "file://" + root.wallpapers[modelData]
            depth: 5                    // 32 colour buckets
            rescaleSize: 128
            onColorsChanged: {
                // vivid = saturated and neither too dark nor too bright; keep up to 5 clearly different hues
                const scored = [];
                for (const c of colors)
                    if (c.hslLightness >= 0.14) scored.push({ c, s: c.hslSaturation * (1 - Math.abs(c.hslLightness - 0.5) * 1.6) });
                scored.sort((a, b) => b.s - a.s);
                const picks = [];
                for (const x of scored) {
                    if (picks.length >= 5) break;
                    if (picks.length > 0 && x.s < 0.12) break;
                    const far = picks.every(p => { const d = Math.abs(p.hslHue - x.c.hslHue); return Math.min(d, 1 - d) > 0.09 });
                    if (far) picks.push(x.c);
                }
                const m = Object.assign({}, root.wpCandidates);
                m[modelData] = picks;
                root.wpCandidates = m;
            }
        }
    }

    // ---------------------------------------------------------------- palette building
    function rgb(hex) { return Qt.color(hex) }
    function mix(x, y, t) { return Qt.rgba(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t, 1) }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function shades(name) { return tw[name].map(rgb) }
    function blend(a, b, t) { return a.map((c, i) => mix(c, b[i], t)) }

    // Tailwind palettes sorted by the hue of their 500 shade
    readonly property var hueRing: chromatic.map(n => ({ n, h: rgb(tw[n][5]).hslHue })).sort((a, b) => a.h - b.h)
    // shades for any hue: blend the two neighbouring palettes on the colour wheel
    function shadesAtHue(h) {
        h = ((h % 1) + 1) % 1;
        const r = hueRing;
        for (let i = 0; i < r.length; i++) {
            const a = r[i], b = r[(i + 1) % r.length];
            const hb = b.h < a.h ? b.h + 1 : b.h;
            const hh = h < a.h ? h + 1 : h;
            if (hh >= a.h && hh <= hb)
                return blend(shades(a.n), shades(b.n), hb === a.h ? 0 : (hh - a.h) / (hb - a.h));
        }
        return shades("teal");
    }

    function build(S, P, light) {
        const black = Qt.rgba(0, 0, 0, 1);
        if (!light) return {
            light: false,
            bar: Qt.rgba(0.043, 0.059, 0.078, 0.78),
            cap: alpha(mix(S[10], black, 0.8), 0.82),
            mid: alpha(S[6], 0.88), inner: alpha(S[9], 0.88),
            sep1: S[4], sep2: P[3],
            logo: S[0], dots: S[0], tray: S[0],
            pill: S[4], pillText: mix(S[10], black, 0.45),
            accent: S[3], text: S[0], text2: S[2],
            island: Qt.rgba(0.008, 0.024, 0.090, 0.90), islandStroke: alpha(S[4], 0.20),
            islandText: "#ffffff", islandSub: "#94a3b8",
            eq: S[4], track: Qt.rgba(1, 1, 1, 0.15), shadow: Qt.rgba(0, 0, 0, 0.55),
            popup: alpha(mix(S[10], black, 0.5), 0.62), swatch: [S[6], S[9], S[3]],
            // small popups (picker, tray dropdown, tooltips)
            menu: Qt.rgba(0.02, 0.04, 0.05, 0.72), menuSolid: Qt.rgba(0.02, 0.05, 0.06, 0.94),
            menuText: rgb("#ecfeff"), menuSub: rgb("#cbd5e1"), menuDim: rgb("#94a3b8"),
            menuWell: Qt.rgba(0, 0, 0, 0.25), menuHover: Qt.rgba(1, 1, 1, 0.08)
        };
        return {
            light: true,
            bar: Qt.rgba(0.97, 0.98, 0.99, 0.80),
            cap: Qt.rgba(1, 1, 1, 0.85),
            mid: alpha(S[1], 0.88), inner: alpha(S[3], 0.90),
            sep1: S[5], sep2: P[4],
            logo: S[7], dots: mix(S[10], black, 0.45), tray: mix(S[10], black, 0.45),
            pill: mix(S[10], black, 0.45), pillText: S[3],
            accent: S[7], text: S[10], text2: S[7],
            island: Qt.rgba(1, 1, 1, 0.92), islandStroke: alpha(S[6], 0.25),
            islandText: "#0f172a", islandSub: "#64748b",
            eq: S[6], track: Qt.rgba(0, 0, 0, 0.10), shadow: Qt.rgba(0.06, 0.09, 0.16, 0.22),
            popup: alpha(mix(S[10], black, 0.5), 0.62), swatch: [S[1], S[3], S[7]],
            menu: alpha(mix(S[0], Qt.rgba(1, 1, 1, 1), 0.5), 0.80), menuSolid: alpha(mix(S[0], Qt.rgba(1, 1, 1, 1), 0.5), 0.96),
            menuText: S[10], menuSub: rgb("#334155"), menuDim: rgb("#64748b"),
            menuWell: Qt.rgba(0, 0, 0, 0.06), menuHover: Qt.rgba(0, 0, 0, 0.06)
        };
    }

    // shade sets for a scheme: [main, partner (for the green-ish separator end)]
    function sources(scheme, wp) {
        if (scheme === "wallpaper" && wp) {
            const h = wp.hslHue, s = wp.hslSaturation;
            let S = shadesAtHue(h), P = shadesAtHue(h - 0.1);
            // greyish wallpaper -> fade towards slate
            const grey = Math.max(0, Math.min(1, (0.32 - s) / 0.22));
            if (grey > 0) { S = blend(S, shades("slate"), grey); P = blend(P, shades("slate"), grey) }
            return [S, P];
        }
        if (!tw[scheme]) return [shades("teal"), shades("green")];         // ruboshapes (and fallback)
        const i = chromatic.indexOf(scheme);
        const partner = i < 0 ? scheme : chromatic[(i + chromatic.length - 2) % chromatic.length];   // two steps back on the wheel
        return [shades(scheme), shades(partner)];
    }
    function isRuboshapes(scheme, wp) { return scheme === "ruboshapes" || (scheme === "wallpaper" && !wp) || (!tw[scheme] && scheme !== "wallpaper") }

    // palette for a scheme id; wp = wallpaper colour for "wallpaper"
    function make(scheme, mode, wp) {
        const light = mode === "light";
        const [S, P] = sources(scheme, wp);
        const p = build(S, P, light);
        if (isRuboshapes(scheme, wp)) {
            // the original hand-tuned teal (07g)
            if (!light) Object.assign(p, { cap: Qt.rgba(0.012, 0.024, 0.024, 0.82), text: rgb("#ecfeff"), logo: rgb("#ecfeff"),
                                           dots: rgb("#ecfeff"), tray: rgb("#ecfeff"), pillText: rgb("#041a19"),
                                           popup: Qt.rgba(0.016, 0.086, 0.082, 0.62) });
            else Object.assign(p, { pill: rgb("#041a19"), dots: rgb("#041a19"), tray: rgb("#041a19"), sep1: rgb("#14b8a6") });
        }
        return p;
    }

    // ---------------------------------------------------------------- system (main monitor)
    // The main monitor's scheme is the system scheme: window borders, Qt/KDE, GTK, Caelestia, terminal.
    // Other monitors only recolour their own bar. Settings: _system { monitor, terminal }.
    readonly property string mainMonitor: {
        const m = settings._system?.monitor;
        if (m && Quickshell.screens.some(s => s.name === m)) return m;
        // default: the biggest screen
        const sc = Quickshell.screens.slice().sort((a, b) => b.width * b.height * b.devicePixelRatio ** 2 - a.width * a.height * a.devicePixelRatio ** 2);
        return sc[0]?.name ?? "";
    }
    readonly property bool terminalColours: settings._system?.terminal ?? false
    function setSystem(key, value) {
        const s = Object.assign({}, settings);
        s._system = Object.assign({}, s._system ?? {}, { [key]: value });
        if (key === "monitor") s._system.targets = {};          // new main monitor: every part follows it
        settings = s;
        store.setText(JSON.stringify(settings, null, 2) + "\n");
    }
    // system parts; each follows the main monitor unless pinned to another one (_system.targets)
    readonly property var targets: [["borders", "Borders", "\u{f0e9e}"], ["qt", "Qt / KDE", "\u{f0835}"], ["gtk", "GTK", "\u{f08d7}"],
                                    ["caelestia", "Caelestia", "\u{f0d4f}"], ["vesktop", "Vesktop", "\u{f066f}"], ["spicetify", "Spotify", "\u{f04c7}"],
                                    ["vscode", "VS Code", "\u{f0a1e}"]]
    function sourceOf(t) {
        const m = settings._system?.targets?.[t];
        return m && Quickshell.screens.some(s => s.name === m) ? m : mainMonitor;
    }
    function setTarget(t, mon) {
        const s = Object.assign({}, settings);
        s._system = Object.assign({}, s._system ?? {});
        s._system.targets = Object.assign({}, s._system.targets ?? {}, { [t]: mon });
        settings = s;
        store.setText(JSON.stringify(settings, null, 2) + "\n");
    }
    function hex(c) { const h = x => Math.round(x * 255).toString(16).padStart(2, "0"); return "#" + h(c.r) + h(c.g) + h(c.b) }
    // what a system part needs from a monitor's scheme
    function specFor(mon) {
        const st = settingFor(mon), wp = wpColor[mon];
        const [S, P] = sources(st.scheme, wp);
        const rubo = isRuboshapes(st.scheme, wp);
        const seed = rubo ? rgb("#0d9488") : st.scheme === "wallpaper" ? wp : S[5];
        const neutral = S[5].hslSaturation < 0.25;
        return {
            mode: st.mode, seed: hex(seed), shades: S.map(hex),
            border1: rubo ? "#53e2ae" : hex(mix(S[4], P[4], 0.4)),
            border2: rubo ? "#6603fc" : hex(neutral ? S[7] : shadesAtHue(S[5].hslHue + 0.27)[6])
        };
    }
    readonly property var system: specFor(sourceOf("borders"))       // bar popups use the window border colours
    readonly property var systemTargets: {
        const out = {};
        for (const [t] of targets) out[t] = Object.assign({ monitor: sourceOf(t) }, specFor(sourceOf(t)));
        return out;
    }
    // apply on change (debounced: wallpaper colours arrive a moment after start)
    readonly property string systemSig: JSON.stringify({ terminal: terminalColours, targets: systemTargets })
    onSystemSigChanged: systemTimer.restart()
    Timer { id: systemTimer; interval: 1200
        onTriggered: Quickshell.execDetached([Quickshell.shellDir + "/scripts/system-theme.py", root.systemSig]) }

    // all monitors' palettes; "" = focused monitor (used by the switcher / keybind sheet)
    readonly property var palettes: {
        const out = {};
        for (const sc of Quickshell.screens) {
            const st = settingFor(sc.name);
            out[sc.name] = make(st.scheme, st.mode, wpColor[sc.name]);
        }
        return out;
    }
    // dark variant of a monitor's scheme (overlays designed as dark glass: switcher, keybind sheet)
    function palDark(mon) {
        const m = mon || (Hyprland.focusedMonitor?.name ?? "");
        const st = settingFor(m);
        return make(st.scheme, "dark", wpColor[m]);
    }
    function pal(mon) {
        return palettes[mon] ?? palettes[Hyprland.focusedMonitor?.name ?? ""] ?? make("ruboshapes", "dark");
    }
}
