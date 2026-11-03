#!/usr/bin/env python3
"""Apply the main monitor's ruboshapes colour scheme to the rest of the system.

Called by services/Schemes.qml with one JSON argument:
  {"mode": "dark"|"light", "seed": "#rrggbb", "shades": [11 x "#rrggbb" (Tailwind 50..950)],
   "border1": "#rrggbb", "border2": "#rrggbb", "terminal": true|false}

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
GTK_DARK, GTK_LIGHT = "Sweet-Dark", "Breeze"

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
                "caelestia/cli.json"]:
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
            set_ini(conf, "Appearance", "custom_palette", "true")
            set_ini(conf, "Appearance", "style", "Breeze" if light else "kvantum-dark")
    accent = S[6] if light else S[4]
    for key in ("AccentColor", "LastUsedCustomAccentColor"):
        run("kwriteconfig6", "--file", "kdeglobals", "--group", "General", "--key", key, csv(accent))
    if not light:
        kvantum(S)

def kvantum(S):
    src = CFG / "Kvantum" / KV_BASE
    if not src.exists():
        return
    dst = CFG / "Kvantum" / "Ruboshapes"
    dst.mkdir(parents=True, exist_ok=True)
    # Sweet's magenta/purple accents -> scheme shades
    swap = {"#c50ed2": S[6], "#e323f0": S[5], "#ff00ff": S[4], "#ff00cc": S[4], "#bd93f9": S[3], "#654ea3": S[8]}
    for ext in ("kvconfig", "svg"):
        text = (src / f"{KV_BASE}.{ext}").read_text()
        for old, new in swap.items():
            text = re.sub(re.escape(old), new, text, flags=re.I)
        (dst / f"Ruboshapes.{ext}").write_text(text)
    set_ini(CFG / "Kvantum" / "kvantum.kvconfig", "General", "theme", "Ruboshapes")

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
            main.write_text(text.rstrip("\n") + ("\n" if text else "") + "@import 'ruboshapes.css';\n")
        ini = folder / "settings.ini"
        if ini.exists():
            set_ini(ini, "Settings", "gtk-application-prefer-dark-theme", "false" if light else "true")
            if d == "gtk-3.0":
                set_ini(ini, "Settings", "gtk-theme-name", GTK_LIGHT if light else GTK_DARK)
    run("gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "prefer-light" if light else "prefer-dark")
    run("gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", GTK_LIGHT if light else GTK_DARK)

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
    spec = json.loads(sys.argv[1])
    log("apply", json.dumps(spec))
    backup_once()
    STATE.mkdir(parents=True, exist_ok=True)
    if spec["terminal"]:
        (STATE / "term").touch()        # .zshrc replays Caelestia's terminal colours when this exists
    for step in (hypr, qt, gtk, caelestia):
        try:
            step(spec)
        except Exception as e:
            log(step.__name__, "failed:", e)

if __name__ == "__main__":
    main()
