#!/usr/bin/env python3
"""Workspace swipe progress for the bar (services/Swipe.qml), so the workspace pill follows the fingers 1:1.

Hyprland doesn't report the progress of its built-in workspace swipe, and a second gesture on the same
fingers/direction is refused ("overshadowed"). So this reads the touchpad's own gesture events through
`libinput debug-events` (needs the `input` group) and replays Hyprland 0.57's maths
(TrackpadGestures.cpp + UnifiedWorkspaceSwipeGesture.cpp):
  - a gesture starts once |total dx| or |total dy| reaches 5; the larger axis decides, the event that
    crosses the threshold already counts
  - each update adds scale * dx (negated with workspace_swipe_invert), clamped to +-workspace_swipe_distance
  - swiping left past workspace 1 is blocked (delta reset to 0), like Hyprland's "m-1 wraps" check
  - direction lock: after the threshold, swiping back past the start resets the delta to 0
Where the swipe lands is not predicted: the bar waits for Hyprland's workspace change after "end".

Output, one line per event:
  begin <monitor> <workspace id>
  p <progress>          -1..1, negative = previous workspace
  end
Exits quietly when there is no touchpad (e.g. on the PC), so the bar just never animates.
"""
import ctypes, json, re, signal, subprocess, sys

FINGERS = 3          # the workspace gesture in machines/*.lua


def die_with_parent():
    """Quickshell doesn't stop child processes when the bar exits or restarts: end with the parent."""
    try:
        ctypes.CDLL("libc.so.6", use_errno=True).prctl(1, signal.SIGTERM)   # PR_SET_PDEATHSIG
    except OSError:
        pass


def hypr(*args):
    try:
        return subprocess.run(["hyprctl", *args], capture_output=True, text=True, timeout=2).stdout.strip()
    except Exception:
        return ""


def opt(name, key, default):
    try:
        return json.loads(hypr("getoption", name, "-j")).get(key, default)
    except Exception:
        return default


def touchpads():
    out = subprocess.run(["libinput", "list-devices"], capture_output=True, text=True).stdout
    devs, node = [], None
    for line in out.splitlines():
        if line.startswith("Kernel:"):
            node = line.split()[-1]
        elif line.startswith("Capabilities:") and "gesture" in line and node:
            devs.append(node)
    return devs


def main():
    die_with_parent()
    try:
        devs = touchpads()
    except FileNotFoundError:
        return                      # libinput-tools not installed
    if not devs:
        return

    distance = max(1, int(opt("gestures:workspace_swipe_distance", "int", 300)))
    invert = bool(opt("gestures:workspace_swipe_invert", "int", opt("gestures:workspace_swipe_invert", "bool", True)))
    dirlock = bool(opt("gestures:workspace_swipe_direction_lock", "int", opt("gestures:workspace_swipe_direction_lock", "bool", True)))
    lock_threshold = int(opt("gestures:workspace_swipe_direction_lock_threshold", "int", 10))
    try:
        scale = float(hypr("repl", "return (machine and machine.workspace_swipe_scale) or 1") or 1)
    except ValueError:
        scale = 1.0
    profile = opt("input:accel_profile", "str", "") or "adaptive"
    speed = float(opt("input:sensitivity", "float", 0.0))

    cmd = ["stdbuf", "-oL", "libinput", "debug-events", f"--set-profile={profile}", f"--set-speed={speed}"]
    for d in devs:
        cmd += ["--device", d]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, bufsize=1,
                            preexec_fn=die_with_parent)

    # repeated events of one type get a running counter column before the timestamp ("UPDATE   12  +1.9s")
    rx = re.compile(r"GESTURE_SWIPE_(BEGIN|UPDATE|END)\s+(?:\d+\s+)?\+?[\d.]+s\s+(\d+)\s*(.*)")
    rxd = re.compile(r"(-?\d+(?:\.\d+)?)/\s*(-?\d+(?:\.\d+)?)")
    total_x = total_y = delta = 0.0
    state = "idle"                  # idle | waiting | active | ignored
    initial_dir = 0
    first = False                   # swiping left is blocked on the monitor's first workspace

    def emit(s):
        print(s, flush=True)

    for line in proc.stdout:
        m = rx.search(line)
        if not m:
            continue
        kind, fingers, rest = m.group(1), int(m.group(2)), m.group(3)
        if kind == "BEGIN":
            total_x = total_y = delta = 0.0
            initial_dir = 0
            state = "waiting" if fingers == FINGERS else "ignored"
            continue
        if kind == "END":
            if state == "active":
                emit("end")
            state = "idle"
            continue
        if state not in ("waiting", "active"):
            continue
        d = rxd.search(rest)
        if not d:
            continue
        dx, dy = float(d.group(1)), float(d.group(2))
        total_x += dx
        total_y += dy
        if state == "waiting":
            if abs(total_x) < 5 and abs(total_y) < 5:
                continue
            if abs(total_x) <= abs(total_y):
                state = "ignored"   # vertical: that's hyprexpo's gesture
                continue
            try:
                ws = json.loads(hypr("activeworkspace", "-j"))
            except Exception:
                state = "ignored"
                continue
            first = (ws["id"] - 1) % 10 == 0
            state = "active"
            emit(f"begin {ws['monitor']} {ws['id']}")
        # one update, as in CWorkspaceSwipeGesture::update + CUnifiedWorkspaceSwipeGesture::update
        step = scale * dx
        delta += -step if invert else step
        delta = max(-distance, min(distance, delta))
        if delta < 0 and first:
            delta = 0.0
        if dirlock:
            if initial_dir != 0 and initial_dir != (-1 if delta < 0 else 1):
                delta = 0.0
            elif initial_dir == 0 and abs(delta) > lock_threshold:
                initial_dir = -1 if delta < 0 else 1
        emit(f"p {delta / distance:.4f}")


if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        sys.exit(0)
