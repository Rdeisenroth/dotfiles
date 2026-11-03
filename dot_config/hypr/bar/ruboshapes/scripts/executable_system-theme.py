#!/usr/bin/env python3
"""Apply the main monitor's ruboshapes colour scheme to the rest of the system.

Called by services/Schemes.qml with one JSON argument:
  {"terminal": true|false, "targets": {"borders"|"qt"|"gtk"|"caelestia"|"vesktop"|"spicetify": SPEC}}
  SPEC = {"monitor": "DP-3", "mode": "dark"|"light", "seed": "#rrggbb",
          "shades": [11 x "#rrggbb" (Tailwind 50..950)], "border1": "#rrggbb", "border2": "#rrggbb"}
Each part can follow a different monitor's scheme; parts whose SPEC didn't change are skipped.

Targets: Hyprland window border gradient (live + ~/.local/state/ruboshapes/hypr-scheme.lua, read by
look.lua), Qt (qt6ct/qt5ct colour scheme + KDE accent + a recoloured copy of the Kvantum theme), GTK
(dark/light preference + accent overrides), Caelestia (its panels and, optionally, terminal colours).
The first run backs up every file it changes to ~/.local/state/ruboshapes/backup/.
"""
import configparser, json, os, re, shutil, subprocess, sys
from pathlib import Path

HOME = Path.home()
CFG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "ruboshapes"
BACKUP = STATE / "backup"
LOG = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "ruboshapes-system.log"

KV_BASE = "Sweet-transparent-toolbar"       # Kvantum theme the dark Qt look is based on
KV_BASE_LIGHT = "WhiteSur"                # light glass counterpart (github.com/vinceliuice/WhiteSur-kde)
KV_LIGHT_OPACITY = 20                     # reduce_window_opacity: how see-through light windows are
KV_LIGHT_ALT_BASE = "#ffffff38"           # translucent alternate rows, like Sweet (an opaque one stripes Dolphin)
KV_SOURCES = {                            # where to fetch a base theme that isn't installed yet
    "Sweet-transparent-toolbar": "EliverLara/Sweet/nova/kde/Kvantum/Sweet-transparent-toolbar",
    "WhiteSur": "vinceliuice/WhiteSur-kde/master/Kvantum/WhiteSur",
}
GTK_DARK, GTK_LIGHT = "Sweet-Dark", "Breeze"
ICONS_DARK, ICONS_LIGHT = "Tela-dark", "Tela"     # ~/.local/share/icons

def log(*a):
    with LOG.open("a") as f:
        print(*a, file=f)

def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def csv(h):
    return ",".join(map(str, rgb(h)))

def run(*cmd):
    try:
        subprocess.run(cmd, check=False, timeout=30, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception as e:
        log("run failed", cmd, e)

def backup_once():
    if BACKUP.exists():
        return
    BACKUP.mkdir(parents=True)
    for rel in ["qt6ct/qt6ct.conf", "qt5ct/qt5ct.conf", "Kvantum/kvantum.kvconfig", "kdeglobals",
                "gtk-3.0/gtk.css", "gtk-4.0/gtk.css", "gtk-3.0/settings.ini", "gtk-4.0/settings.ini",
                "caelestia/cli.json", "vesktop/themes/rubos-new.theme.css", "spicetify/config-xpui.ini"]:
        src = CFG / rel
        if src.exists():
            dst = BACKUP / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
    gs = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", "gtk-theme"], capture_output=True, text=True)
    (BACKUP / "gtk-theme.txt").write_text(gs.stdout.strip())

def set_ini(path, section, key, value):
    """Change one key in an ini file without reformatting the rest."""
    text = path.read_text() if path.exists() else ""
    lines = text.splitlines()
    out, in_sec, done = [], False, False
    for line in lines:
        if line.strip().startswith("["):
            if in_sec and not done:
                out.append(f"{key}={value}"); done = True
            in_sec = line.strip() == f"[{section}]"
        elif in_sec and re.match(rf"^{re.escape(key)}\s*=", line):
            line = f"{key}={value}"; done = True
        out.append(line)
    if not done:
        if not in_sec:
            out += ["", f"[{section}]"]
        out.append(f"{key}={value}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(out) + "\n")

# ---------------------------------------------------------------------------------------- targets
def hypr(spec):
    b1, b2 = spec["border1"].lstrip("#"), spec["border2"].lstrip("#")
    STATE.mkdir(parents=True, exist_ok=True)
    (STATE / "hypr-scheme.lua").write_text(
        "-- written by bar/ruboshapes/scripts/system-theme.py (main monitor colour scheme)\n"
        f'return {{ border1 = "rgba({b1}ff)", border2 = "rgba({b2}ee)" }}\n')
    run("hyprctl", "eval", f'hl.config({{ general = {{ col = {{ active_border = {{ colors = {{ "rgba({b1}ff)", "rgba({b2}ee)" }}, angle = 45 }} }} }} }})')

def qt(spec):
    S, light = spec["shades"], spec["mode"] == "light"
    # Breeze colour scheme with its blue accents swapped for the scheme colour
    base = Path("/usr/share/color-schemes") / ("BreezeLight.colors" if light else "BreezeDark.colors")
    swap = ({"61,174,233": S[5], "41,128,185": S[7], "163,212,250": S[2], "29,153,243": S[6]} if light else
            {"61,174,233": S[4], "29,153,243": S[3], "30,87,116": S[8]})
    text = base.read_text()
    for old, new in swap.items():
        text = re.sub(rf"(?<![0-9]){old}(?![0-9])", csv(new), text)
    name = "RuboshapesLight" if light else "RuboshapesDark"
    text = re.sub(r"^Name=.*$", f"Name=Ruboshapes {'Light' if light else 'Dark'}", text, flags=re.M)
    dest = HOME / ".local/share/color-schemes" / f"{name}.colors"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(text)
    for tool in ("qt6ct", "qt5ct"):
        conf = CFG / tool / f"{tool}.conf"
        if conf.exists():
            set_ini(conf, "Appearance", "color_scheme_path", str(dest))
            # light: let the Kvantum theme's own (recoloured, translucent) palette rule; the Breeze one
            # mixes opaque colours in and Tela's folders take whatever Highlight ends up being
            set_ini(conf, "Appearance", "custom_palette", "false" if light else "true")
            set_ini(conf, "Appearance", "style", "kvantum" if light else "kvantum-dark")
            set_ini(conf, "Appearance", "icon_theme", ICONS_LIGHT if light else ICONS_DARK)
    run("kwriteconfig6", "--file", "kdeglobals", "--group", "Icons", "--key", "Theme", ICONS_LIGHT if light else ICONS_DARK)
    accent = S[6] if light else S[4]
    for key in ("AccentColor", "LastUsedCustomAccentColor"):
        run("kwriteconfig6", "--file", "kdeglobals", "--group", "General", "--key", key, csv(accent))
    kvantum(S, light)                                   # first: the style-changed signal below reloads it
    kde_globals(dest, name, light, ICONS_LIGHT if light else ICONS_DARK)

def fetch_kvantum(base):
    """Download a base Kvantum theme (kvconfig + svg) into ~/.config/Kvantum/<base>/ if it's missing."""
    src = CFG / "Kvantum" / base
    if (src / f"{base}.kvconfig").exists() or base not in KV_SOURCES:
        return src
    import urllib.request
    try:
        files = {}
        for ext in ("kvconfig", "svg"):
            url = f"https://raw.githubusercontent.com/{KV_SOURCES[base]}/{base}.{ext}"
            with urllib.request.urlopen(url, timeout=30) as r:
                files[ext] = r.read()
        src.mkdir(parents=True, exist_ok=True)
        for ext, data in files.items():
            (src / f"{base}.{ext}").write_bytes(data)
        log("downloaded Kvantum theme", base)
    except Exception as e:
        log("Kvantum download failed", base, e)
    return src

KDE_FONT = "DejaVu LGC Sans,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"   # same as the old qt6ct setup

def read_sections(text):
    """kdeglobals-style ini -> ordered [(header, [lines])] (header None = lines before the first section)."""
    out, cur = [], (None, [])
    for line in text.splitlines():
        if line.startswith("[") and line.rstrip().endswith("]"):
            out.append(cur); cur = (line.strip(), [])
        else:
            cur[1].append(line)
    out.append(cur)
    return [x for x in out if x[0] is not None or any(l.strip() for l in x[1])]

def kde_globals(scheme_file, name, light, icons):
    """Live Qt theming: Qt apps use the KDE platform theme (QT_QPA_PLATFORMTHEME=kde) with Kvantum as the widget
    style (Sweet copy for dark, WhiteSur copy for light; see kvantum()). Write the colour scheme into kdeglobals
    and broadcast KDE's palette/style-changed signals: open apps switch theme instantly. View alternate rows get
    alpha, since Dolphin paints them from the KDE colour scheme (otherwise opaque stripes)."""
    kg = CFG / "kdeglobals"
    secs = read_sections(kg.read_text() if kg.exists() else "")
    scheme = read_sections(scheme_file.read_text())
    alt = "226,231,238,210" if light else "37,42,63,120"   # light: soft tinted grey; dark: Sweet's alt.base (#252a3f78)
    new = {}
    for h, lines in scheme:
        if h is None or not (h.startswith("[Colors:") or h.startswith("[ColorEffects:") or h == "[WM]"):
            continue
        if h == "[Colors:View]":
            lines = [("BackgroundAlternate=" + alt) if l.startswith("BackgroundAlternate=") else l for l in lines]
        new[h] = lines
    out, seen = [], set()
    for h, lines in secs:
        if h in new:
            out.append((h, new[h])); seen.add(h)
        elif h is not None and (h.startswith("[Colors:") or h.startswith("[ColorEffects:")):
            continue                                  # stale section of another scheme
        else:
            out.append((h, lines))
    out += [(h, l) for h, l in new.items() if h not in seen]
    text = "\n".join("\n".join(([h] if h else []) + lines).rstrip("\n") + "\n" for h, lines in out)
    kg.write_text(text)
    style = "kvantum" if light else "kvantum-dark"   # Kvantum themes (Sweet / WhiteSur copies); swapped live on StyleChanged
    for group, key, value in (("General", "ColorScheme", name), ("KDE", "ColorScheme", name), ("General", "widgetStyle", style),
                              ("KDE", "widgetStyle", style), ("Icons", "Theme", icons)):
        set_ini(kg, group, key, value)
    if "font=" not in kg.read_text():
        set_ini(kg, "General", "font", KDE_FONT)
        set_ini(kg, "General", "fixed", KDE_FONT)
    darkly = CFG / "darklyrc"
    if not darkly.exists():                           # glass like Sweet; tweak in darkly-settings6
        darkly.write_text("[Style]\nDolphinSidebarOpacity=55\nDolphinViewOpacity=55\nMenuBarOpacity=55\n"
                          "ToolBarOpacity=55\nTabBarOpacity=55\nMenuOpacity=70\n")
    # KGlobalSettings.notifyChange(PaletteChanged=0 / StyleChanged=2): running KDE-platform Qt apps reload
    for kind in ("0", "2"):
        run("dbus-send", "--session", "--type=signal", "/KGlobalSettings", "org.kde.KGlobalSettings.notifyChange",
            f"int32:{kind}", "int32:0")

def kvantum(S, light):
    """Recoloured copy of the base Kvantum theme: Sweet (dark) or WhiteSur (light, made glassy like Sweet)."""
    base, name = (KV_BASE_LIGHT, "RuboshapesLight") if light else (KV_BASE, "Ruboshapes")
    src = fetch_kvantum(base)
    if not (src / f"{base}.kvconfig").exists():
        return
    dst = CFG / "Kvantum" / name
    dst.mkdir(parents=True, exist_ok=True)
    # accents -> scheme shades (Sweet: magenta/purple, WhiteSur: macOS blues; alpha suffixes are kept)
    swap = ({"#0860f2": S[6], "#0852ce": S[7], "#0e4bb4": S[8], "#77aff1": S[4], "#3daee9": S[5], "#3484e2": S[6]}
            if light else
            {"#c50ed2": S[6], "#e323f0": S[5], "#ff00ff": S[4], "#ff00cc": S[4], "#bd93f9": S[3], "#654ea3": S[8]})
    for ext in ("kvconfig", "svg"):
        text = (src / f"{base}.{ext}").read_text()
        for old, new in swap.items():
            text = re.sub(re.escape(old), new, text, flags=re.I)
        if light and ext == "kvconfig":     # glassy like Sweet: see-through windows (Hyprland blurs behind)
            text = re.sub(r"^reduce_window_opacity=.*$", f"reduce_window_opacity={KV_LIGHT_OPACITY}", text, flags=re.M)
            text = re.sub(r"^((?:inactive\.)?alt\.base\.color)=.*$", rf"\1={KV_LIGHT_ALT_BASE}", text, flags=re.M)
            text = re.sub(r"^(opaque=.*?),kate\b", r"\1", text, flags=re.M)     # Kate is see-through in Sweet too
            # readable content: file/text views get an almost solid white base (glass stays on the frame,
            # sidebar and toolbars); Dolphin's view is no longer made fully transparent
            text = re.sub(r"^transparent_dolphin_view=.*$", "transparent_dolphin_view=false", text, flags=re.M)
            text = re.sub(r"^base\.color=.*$", f"base.color={mix_hex('#eef1f5', S[1], 0.25)}d4", text, flags=re.M)
            # column headers: a brighter translucent white + a faint line below (custom "rsheader" SVG
            # element added below) instead of WhiteSur's opaque white button
            text = re.sub(r"^\[HeaderSection\]\n(?:(?!\[).*\n)*",
                          "[HeaderSection]\ninherits=PanelButtonCommand\ninterior=true\nframe=true\n"
                          "interior.element=rsheader\nframe.element=rsheader\nframe.top=0\nframe.bottom=1\n"
                          "frame.left=0\nframe.right=0\ntext.margin.top=2\ntext.margin.bottom=2\n"
                          "text.margin.left=4\ntext.margin.right=4\n\n", text, flags=re.M)
        if light and ext == "svg":
            wash, line = "#ffffff", S[4]      # brighter, a bit more opaque than the view: reads as a header
            parts = "".join(
                f'<rect id="rsheader-{st}" x="{-300 - i * 40}" y="-300" width="20" height="20" fill="{wash}" fill-opacity="0.55"/>'
                f'<rect id="rsheader-{st}-bottom" x="{-300 - i * 40}" y="-270" width="20" height="1" fill="{line}" fill-opacity="0.35"/>'
                for i, st in enumerate(("normal", "focused", "pressed", "toggled")))
            text = text.replace("</svg>", parts + "</svg>", 1)
        (dst / f"{name}.{ext}").write_text(text)
    set_ini(CFG / "Kvantum" / "kvantum.kvconfig", "General", "theme", name)

def gtk(spec):
    S, light = spec["shades"], spec["mode"] == "light"
    accent = S[6] if light else S[4]
    css = ("/* written by bar/ruboshapes/scripts/system-theme.py */\n"
           f"@define-color accent_color {accent};\n@define-color accent_bg_color {accent};\n"
           f"@define-color accent_fg_color {'#ffffff' if light else S[10]};\n"
           f"@define-color theme_selected_bg_color {accent};\n@define-color selected_bg_color {accent};\n")
    for d in ("gtk-3.0", "gtk-4.0"):
        folder = CFG / d
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "ruboshapes.css").write_text(css)
        main = folder / "gtk.css"
        text = main.read_text() if main.exists() else ""
        if "ruboshapes.css" not in text:
            text = text.rstrip("\n") + ("\n" if text else "") + "@import 'ruboshapes.css';\n"
        # colors.css (generated by KDE once) holds Breeze *Dark* colours for the Breeze GTK theme: only import it
        # in dark mode; in light mode Breeze uses its own light colours (+ our accent above)
        on, off = "@import 'colors.css';", "/* @import 'colors.css'; (dark mode only, ruboshapes) */"
        text = text.replace(off, on) if not light else text
        text = text.replace(on, off) if light else text
        main.write_text(text)
        ini = folder / "settings.ini"
        if ini.exists():
            set_ini(ini, "Settings", "gtk-application-prefer-dark-theme", "false" if light else "true")
            if d == "gtk-3.0":
                set_ini(ini, "Settings", "gtk-theme-name", GTK_LIGHT if light else GTK_DARK)
            set_ini(ini, "Settings", "gtk-icon-theme-name", ICONS_LIGHT if light else ICONS_DARK)
    run("gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "prefer-light" if light else "prefer-dark")
    run("gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", GTK_LIGHT if light else GTK_DARK)
    run("gsettings", "set", "org.gnome.desktop.interface", "icon-theme", ICONS_LIGHT if light else ICONS_DARK)

VESKTOP_THEME = CFG / "vesktop/themes/rubos-new.theme.css"
def mix_hex(a, b, t):
    ra, rb = rgb(a), rgb(b)
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(ra, rb))

def vesktop(spec):
    """Accent variables of the FrostedGlass/ClearVision theme, as a marked block at the end of the
    theme file (Vesktop reloads theme files live). In light mode the block also carries the light glass
    (vesktop-light.css next to this script), which repaints Discord's dark theme light: Discord stays in
    Dark (FrostedGlass needs it), so nothing has to be switched inside Discord."""
    if not VESKTOP_THEME.exists():
        return
    S = spec["shades"]
    light_css = Path(__file__).with_name("vesktop-light.css")
    light = spec["mode"] == "light" and light_css.exists()
    # light: deeper accent shades, for contrast on the white glass
    grad1, grad2, link, main, hover, brand560 = ((S[4], S[6], S[7], S[6], S[7], S[7]) if light else
                                                 (S[7], S[9], S[4], S[5], S[4], S[6]))
    block = ("/* ruboshapes:begin - accent of the system colour scheme (bar/ruboshapes/scripts/system-theme.py) */\n"
             ":root {\n"
             f"  --gradient-primary: {csv(grad1)};\n  --gradient-secondary: {csv(grad2)};\n"
             f"  --tint-colour: {csv(S[5])};\n  --link-colour: {link};\n"
             f"  --main-color: {main};\n  --hover-color: {hover};\n"
             f"  --brand-500: {main};\n  --brand-560: {brand560};\n  --brand-experiment: {main};\n"
             "}\n" + (light_css.read_text().rstrip("\n") + "\n" if light else "")
             # light glass tint: cool grey-blue with a touch of the scheme colour instead of plain white
             + (f":root {{ --rs-glass: {csv(mix_hex('#e6ebf1', S[1], 0.35))}; }}\n" if light else "")
             + "/* ruboshapes:end */\n")
    text = VESKTOP_THEME.read_text()
    text = re.sub(r"\n?/\* ruboshapes:begin.*?/\* ruboshapes:end \*/\n?", "\n", text, flags=re.S).rstrip("\n")
    VESKTOP_THEME.write_text(text + "\n\n" + block)

VSCODE_SETTINGS = CFG / "Code/User/settings.json"
VSCODE_THEMES = {"dark": "Evondev Dracula Darker Contrast New Color", "light": "Catppuccin Latte"}
def vscode(spec):
    """Set workbench.colorTheme directly (VS Code reloads settings.json live). Electron's own dark/light
    detection is unreliable here, so autoDetectColorScheme is switched off. Only these two lines change."""
    if not VSCODE_SETTINGS.exists():
        return
    text = VSCODE_SETTINGS.read_text()
    theme = VSCODE_THEMES["light" if spec["mode"] == "light" else "dark"]
    new = re.sub(r'^(\s*"workbench\.colorTheme"\s*:\s*)"[^"]*"', lambda m: m.group(1) + json.dumps(theme), text, count=1, flags=re.M)
    new = re.sub(r'^(\s*"window\.autoDetectColorScheme"\s*:\s*)true', r"\1false", new, count=1, flags=re.M)
    if new != text:
        VSCODE_SETTINGS.write_text(new)

SPOTIFY_CDP = ("127.0.0.1", 9229)     # --remote-debugging-port in ~/.config/spotify-launcher.conf (localhost only)

def cdp_eval(js):
    """Run JS in Spotify's UI page through Chromium's DevTools protocol (minimal stdlib WebSocket client).
    Returns False when Spotify isn't running with the debugging port."""
    import base64, socket, struct, urllib.request
    host, port = SPOTIFY_CDP
    try:
        targets = json.loads(urllib.request.urlopen(f"http://{host}:{port}/json", timeout=2).read())
    except Exception:
        return False
    pages = [t for t in targets if t.get("type") == "page" and t.get("webSocketDebuggerUrl")]
    pages.sort(key=lambda t: "xpui" not in t.get("url", ""))
    if not pages:
        return False
    path = pages[0]["webSocketDebuggerUrl"].split(f"{port}", 1)[1]
    sock = socket.create_connection((host, port), timeout=3)
    try:
        key = base64.b64encode(os.urandom(16)).decode()
        sock.sendall((f"GET {path} HTTP/1.1\r\nHost: {host}:{port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                      f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
        if b" 101 " not in sock.recv(4096).split(b"\r\n", 1)[0]:
            return False
        payload = json.dumps({"id": 1, "method": "Runtime.evaluate", "params": {"expression": js}}).encode()
        mask = os.urandom(4)
        n = len(payload)
        head = bytes([0x81]) + (bytes([0x80 | n]) if n < 126 else bytes([0x80 | 126]) + struct.pack(">H", n) if n < 65536
                                else bytes([0x80 | 127]) + struct.pack(">Q", n))
        sock.sendall(head + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(payload)))
        sock.recv(65536)          # the reply; we only need it to have been processed
        return True
    except OSError:
        return False
    finally:
        sock.close()

def spotify_live(colors):
    """Push the colour.ini values into the running Spotify as Spicetify's CSS variables (inline on :root, which
    wins over Spicetify's stylesheet): instant theme change, no reload, music keeps playing."""
    props = {}
    for k, v in colors.items():
        props[f"--spice-{k}"] = "#" + v
        props[f"--spice-rgb-{k}"] = csv("#" + v)
    js = ("(() => { const s = document.documentElement.style; const p = " + json.dumps(props) +
          "; for (const k in p) s.setProperty(k, p[k]); return Object.keys(p).length })()")
    if not cdp_eval(js):
        log("spotify live update skipped (not running with the debugging port)")

def spicetify(spec):
    """Copy of the Sleek theme ("Greener" layout) with the scheme's accent; `spicetify refresh` updates
    Spotify's theme files without restarting it (the new colours show the next time Spotify starts)."""
    base = Path("/opt/spicetify-cli/Themes/Sleek")
    if not base.exists() or not shutil.which("spicetify"):
        return
    S = spec["shades"]
    dst = CFG / "spicetify/Themes/Ruboshapes"
    dst.mkdir(parents=True, exist_ok=True)
    shutil.copy2(base / "user.css", dst / "user.css")
    a, h = S[5].lstrip("#"), S[4].lstrip("#")
    if spec["mode"] == "light":     # light: white surfaces, dark text, deeper accent for contrast
        a, h = S[6].lstrip("#"), S[7].lstrip("#")
        body = ("text = 1e1e1e\nsubtext = 4a4a4a\nnav-active-text = 1e1e1e\n"
                f"main = f6f7f9\nsidebar = eceef2\nplayer = eceef2\ncard = ffffff\nshadow = b8bcc4\n"
                f"main-secondary = {S[1].lstrip('#')}\nbutton = {a}\nbutton-secondary = 1e1e1e\nbutton-active = {h}\n"
                f"button-disabled = c8ccd2\nnav-active = {a}\nplay-button = {a}\ntab-active = {S[2].lstrip('#')}\n"
                f"notification = eceef2\nnotification-error = fde2e2\nplayback-bar = {a}\nmisc = 1e1e1e\n")
    else:
        body = ("text = ffffff\nsubtext = ffffff\nnav-active-text = ffffff\n"
                "main = 020816\nsidebar = 020816\nplayer = 020816\ncard = 020816\nshadow = 000000\n"
                f"main-secondary = {S[8].lstrip('#')}\nbutton = {a}\nbutton-secondary = ffffff\nbutton-active = {h}\n"
                f"button-disabled = 21282f\nnav-active = {a}\nplay-button = {a}\ntab-active = {S[6].lstrip('#')}\n"
                f"notification = 051024\nnotification-error = 051024\nplayback-bar = {a}\nmisc = FFFFFF\n")
    (dst / "color.ini").write_text(
        "; written by bar/ruboshapes/scripts/system-theme.py (Sleek \"Greener\" layout with the system accent)\n"
        "[Base]\n" + body)
    run("spicetify", "config", "current_theme", "Ruboshapes", "color_scheme", "Base")
    run("spicetify", "refresh")
    colors = dict(l.split(" = ", 1) for l in body.splitlines() if " = " in l)
    spotify_live({k.strip(): v.strip() for k, v in colors.items()})

def caelestia(spec):
    # Caelestia panels (+ terminal colours if enabled) from a solid image of the seed colour
    cli = CFG / "caelestia/cli.json"
    try:
        data = json.loads(cli.read_text()) if cli.exists() else {}
    except Exception:
        data = {}
    theme = data.setdefault("theme", {})
    if theme.get("enableTerm") != bool(spec["terminal"]):
        theme["enableTerm"] = bool(spec["terminal"])
        cli.write_text(json.dumps(data, indent=2) + "\n")
    seed_img = STATE / "seed.png"
    try:
        from PIL import Image
        Image.new("RGB", (64, 64), rgb(spec["seed"])).save(seed_img)
    except Exception as e:
        log("seed image failed", e)
        return
    run("caelestia", "wallpaper", "-f", str(seed_img), "-N")
    run("caelestia", "scheme", "set", "-n", "dynamic", "-m", spec["mode"], "-v", "tonalspot")
    ghostty(spec["terminal"])
    if not spec["terminal"]:
        reset_terminals()

def ghostty(on):
    """Colours for new Ghostty windows (~/.config/ghostty/config includes this file, optional).
    Empty when terminal colours are off, so Ghostty's own theme applies."""
    out = STATE / "ghostty-colors"
    lines = ["# written by bar/ruboshapes/scripts/system-theme.py"]
    if on:
        try:
            c = json.loads((HOME / ".local/state/caelestia/scheme.json").read_text())["colours"]
            lines += [f"palette = {i}=#{c[f'term{i}']}" for i in range(16)]
            lines += [f"background = #{c['background']}", f"foreground = #{c['onSurface']}",
                      f"cursor-color = #{c['primary']}", f"selection-background = #{c['primaryContainer']}",
                      f"selection-foreground = #{c['onPrimaryContainer']}"]
        except Exception as e:
            log("ghostty colours failed", e)
    out.write_text("\n".join(lines) + "\n")
    # Ghostty keeps one process for all windows and reads its config once: ask it to reload (SIGUSR2),
    # so open and new windows switch to (or back from) these colours
    run("pkill", "-USR2", "-x", "ghostty")

def reset_terminals():
    """Terminal colours off: ask every open terminal to restore its own palette (OSC 104/110/111)."""
    for pts in Path("/dev/pts").iterdir():
        if pts.name.isdigit() and pts.stat().st_uid == os.getuid():
            try:   # non-blocking, like Caelestia: a busy terminal must not hang this script
                fd = os.open(str(pts), os.O_WRONLY | os.O_NONBLOCK | os.O_NOCTTY)
                try:
                    os.write(fd, b"\033]104\007\033]110\007\033]111\007")
                finally:
                    os.close(fd)
            except OSError:
                pass
    (STATE / "term").unlink(missing_ok=True)

def main():
    arg = json.loads(sys.argv[1])
    log("apply", json.dumps(arg))
    backup_once()
    STATE.mkdir(parents=True, exist_ok=True)
    terminal = bool(arg.get("terminal"))
    if terminal:
        (STATE / "term").touch()
    # every system part can follow a different monitor; only re-apply parts whose colours changed
    applied_path = STATE / "applied.json"
    try:
        applied = json.loads(applied_path.read_text())
    except Exception:
        applied = {}
    steps = {"borders": hypr, "qt": qt, "gtk": gtk, "vesktop": vesktop, "spicetify": spicetify, "vscode": vscode,
             "caelestia": caelestia}
    for name, step in steps.items():
        if name not in arg["targets"]:
            continue
        spec = dict(arg["targets"][name])
        if name == "caelestia":
            spec["terminal"] = terminal        # terminal colours come from Caelestia's scheme
        key = json.dumps(spec, sort_keys=True)
        if applied.get(name) == key:
            continue
        try:
            step(spec)
            applied[name] = key
        except Exception as e:
            log(name, "failed:", e)
    applied_path.write_text(json.dumps(applied, indent=1))

if __name__ == "__main__":
    main()
