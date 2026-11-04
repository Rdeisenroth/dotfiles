#!/usr/bin/env python3
"""Per-monitor brightness for the ruboshapes bar.

  brightness.py get                 -> {"DP-1": 15, ...} (also refreshes the cache)
  brightness.py step <MON> up|down  -> ±5 %
  brightness.py set <MON> <0-100>
  brightness.py map                 -> {"DP-1": "3", ...} DDC bus per output (for Caelestia's OSD)

External monitors use DDC/CI (ddcutil, ~250 ms per call); laptop panels (eDP*) use brightnessctl.
The bar updates its own value immediately; a single background worker applies only the
latest requested value per monitor, so fast scrolling never queues up slow DDC calls.
"""
import fcntl
import json
import os
import re
import subprocess
import sys
import time

RUN = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
CACHE = os.path.join(RUN, "ruboshapes-bright.json")      # {"map": {mon: bus}, "val": {mon: pct}}
WANT = os.path.join(RUN, "ruboshapes-bright.want.json")  # pending target values
LOCK = os.path.join(RUN, "ruboshapes-bright.lock")
DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STEP = 5


def sh(*cmd, timeout=15):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return ""


def load(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def save(path, data):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f)
    os.replace(tmp, path)


def monitors():
    try:
        return json.loads(sh("hyprctl", "-j", "monitors"))
    except ValueError:
        return []


def build_map():
    """Hyprland output name -> ddcutil bus (or 'backlight')."""
    mons = monitors()
    out = {m["name"]: "backlight" for m in mons if m["name"].startswith(("eDP", "LVDS"))}
    displays = []
    for block in sh("ddcutil", "detect", "--brief", timeout=30).split("\n\n"):
        bus = re.search(r"/dev/i2c-(\d+)", block)
        if not bus:
            continue
        conn = re.search(r"DRM connector:\s+\S+?-(\S+)", block)
        mon = re.search(r"Monitor:\s+[^:]*:([^:]*):(\S*)", block)
        displays.append({"bus": bus.group(1), "conn": conn.group(1) if conn else "",
                         "model": mon.group(1) if mon else "", "serial": mon.group(2) if mon else ""})
    # 0) explicit pins (output -> DDC serial) for monitors that report identical EDIDs
    pins = load(os.path.join(DIR, "brightness-overrides.json"), {})
    for name, serial in pins.items():
        hits = [d for d in displays if d["serial"] == serial]
        if not name.startswith("_") and len(hits) == 1 and any(m["name"] == name for m in mons):
            out[name] = hits[0]["bus"]
            displays.remove(hits[0])
    todo = [m for m in mons if m["name"] not in out]
    # 1) connector name, 2) serial, 3) model, 4) the only one left
    for key in ("conn", "serial", "model"):
        for m in list(todo):
            want = {"conn": m["name"], "serial": m.get("serial", ""), "model": m.get("model", "")}[key]
            hits = [d for d in displays if want and d[key] == want]
            if len(hits) == 1:
                out[m["name"]] = hits[0]["bus"]
                displays.remove(hits[0])
                todo.remove(m)
    if len(todo) == 1 and len(displays) == 1:
        out[todo[0]["name"]] = displays[0]["bus"]
    return out


def panel_backlight():
    """The panel's backlight device. With several (Optimus mode: intel_backlight, often acpi_video0 too)
    brightnessctl would just take the first one; prefer the native driver (type raw), then platform, then firmware."""
    rank = {"raw": 0, "platform": 1, "firmware": 2}
    devs = []
    for d in sorted(os.listdir("/sys/class/backlight")) if os.path.isdir("/sys/class/backlight") else []:
        try:
            t = open(f"/sys/class/backlight/{d}/type").read().strip()
        except OSError:
            t = ""
        devs.append((rank.get(t, 3), d))
    return min(devs)[1] if devs else None


def read(target):
    if target == "backlight":
        dev = panel_backlight()
        if not dev:
            return None
        cur, mx = sh("brightnessctl", "-d", dev, "g").strip(), sh("brightnessctl", "-d", dev, "m").strip()
        return round(int(cur) * 100 / int(mx)) if cur and mx else None
    m = re.search(r"VCP 10 C (\d+) (\d+)", sh("ddcutil", "-b", target, "getvcp", "10", "--brief"))
    return round(int(m.group(1)) * 100 / int(m.group(2))) if m else None


def write(target, pct):
    if target == "backlight":
        dev = panel_backlight()
        if dev:
            sh("brightnessctl", "-q", "-d", dev, "s", f"{pct}%")
    else:
        sh("ddcutil", "-b", target, "--noverify", "setvcp", "10", str(pct))


def cmd_get():
    cache = load(CACHE, {})
    mp = cache.get("map") or build_map()
    vals = {}
    for mon, target in mp.items():
        v = read(target)
        if v is not None:
            vals[mon] = v
    save(CACHE, {"map": mp, "val": vals})
    print(json.dumps(vals))


def cmd_map():
    cache = load(CACHE, {})
    mp = cache.get("map") or build_map()
    if not cache.get("map"):
        save(CACHE, {"map": mp, "val": cache.get("val", {})})
    print(json.dumps({m: b for m, b in mp.items() if b != "backlight"}))


def request(mon, pct):
    cache = load(CACHE, {})
    if not cache.get("map"):
        cache = {"map": build_map(), "val": {}}
    if mon not in cache["map"]:
        return
    pct = max(0, min(100, pct))
    cache.setdefault("val", {})[mon] = pct
    save(CACHE, cache)
    want = load(WANT, {})
    want[mon] = pct
    save(WANT, want)
    # single worker: whoever gets the lock applies the latest wanted values until nothing changes
    with open(LOCK, "w") as lk:
        try:
            fcntl.flock(lk, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            return                         # a worker is already running and will pick this up
        applied = {}
        while True:
            want = load(WANT, {})
            todo = {m: v for m, v in want.items() if applied.get(m) != v}
            if not todo:
                break
            for m, v in todo.items():
                write(cache["map"][m], v)
                applied[m] = v
            time.sleep(0.05)
        save(WANT, {})


def main():
    if len(sys.argv) < 2 or sys.argv[1] == "get":
        return cmd_get()
    if sys.argv[1] == "map":
        return cmd_map()
    mon = sys.argv[2]
    cur = load(CACHE, {}).get("val", {}).get(mon, 50)
    if sys.argv[1] == "step":
        # snap to the 5 % grid: 13 -> 15 (up) / 10 (down)
        up = sys.argv[3] == "up"
        request(mon, (cur // STEP + 1) * STEP if up else (-(-cur // STEP) - 1) * STEP)
    elif sys.argv[1] == "set":
        request(mon, round(float(sys.argv[3])))


if __name__ == "__main__":
    main()
