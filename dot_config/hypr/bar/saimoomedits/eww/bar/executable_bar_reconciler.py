#!/usr/bin/env python3

import fcntl
import json
import os
import re
import signal
import subprocess
import sys
import time
from pathlib import Path


BAR_HOME = Path.home() / ".config/hypr/bar/saimoomedits/eww/bar"
EWW = ["eww", "-c", str(BAR_HOME)]
UPDATE = BAR_HOME / "update_bar_windows.sh"
LOCK_PATH = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "eww-bar-reconciler.lock"
BAR_NAME = re.compile(r"^bar[0-9]+$")


def run(command, timeout=3):
    try:
        return subprocess.run(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=timeout,
            close_fds=True,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None


def monitor_signature():
    result = run(["hyprctl", "monitors", "-j"])
    if result is None or result.returncode != 0:
        return None
    try:
        monitors = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None
    return tuple(sorted((str(m.get("id")), m.get("name", "")) for m in monitors))


def stable_monitor_signature():
    previous = monitor_signature()
    if previous is None:
        return None
    equal_samples = 0
    for _ in range(8):
        time.sleep(0.06)
        current = monitor_signature()
        if current is None:
            equal_samples = 0
            continue
        if current == previous:
            equal_samples += 1
            if equal_samples >= 2:
                return current
        else:
            previous = current
            equal_samples = 0
    return previous


def lid_is_closed():
    result = run([
        "gdbus", "call", "--system", "--dest", "org.freedesktop.UPower",
        "--object-path", "/org/freedesktop/UPower",
        "--method", "org.freedesktop.DBus.Properties.Get",
        "org.freedesktop.UPower", "LidIsClosed",
    ])
    return result is not None and "<true>" in result.stdout


def wait_for_lid_topology():
    deadline = time.monotonic() + 3.0
    while time.monotonic() < deadline:
        signature = monitor_signature()
        if signature is not None:
            has_laptop = any(name == "eDP-1" for _, name in signature)
            if has_laptop == (not lid_is_closed()):
                return stable_monitor_signature()
        time.sleep(0.05)
    return stable_monitor_signature()


def eww_ping():
    result = run(EWW + ["ping"])
    return result is not None and result.returncode == 0


def active_bars():
    result = run(EWW + ["active-windows"])
    if result is None:
        return set()
    bars = set()
    for line in result.stdout.splitlines():
        name = line.split(":", 1)[0].strip()
        if BAR_NAME.fullmatch(name):
            bars.add(name)
    return bars


def stop_config_processes():
    """Remove old detached Eww clients/daemons for this config."""
    try:
        output = subprocess.check_output(
            ["ps", "-eo", "pid=,comm=,args="], text=True, stderr=subprocess.DEVNULL
        )
    except (OSError, subprocess.CalledProcessError):
        return

    for line in output.splitlines():
        fields = line.strip().split(None, 2)
        if len(fields) != 3:
            continue
        pid, command, args = fields
        if command != "eww" or f"eww -c {BAR_HOME}" not in args:
            continue
        try:
            os.kill(int(pid), signal.SIGTERM)
        except (ProcessLookupError, PermissionError, ValueError):
            pass
    time.sleep(0.2)


def start_daemon():
    if eww_ping():
        return True
    try:
        subprocess.Popen(
            EWW + ["daemon"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            close_fds=True,
            start_new_session=True,
        )
    except OSError:
        return False
    for _ in range(25):
        if eww_ping():
            return True
        time.sleep(0.05)
    return False


def close_bars():
    bars = sorted(active_bars())
    if bars:
        run(EWW + ["close-many", *bars])


def open_bar(name):
    for _ in range(20):
        if name in active_bars():
            return True
        run(EWW + ["open", name], timeout=1)
        time.sleep(0.05)
    return name in active_bars()


def reconcile(count):
    expected = {f"bar{i}" for i in range(count)}
    for _ in range(8):
        if not start_daemon():
            time.sleep(0.2)
            continue
        close_bars()
        for name in sorted(expected):
            open_bar(name)
        if active_bars() == expected:
            return True
        time.sleep(0.15)
    return False


def main():
    LOCK_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOCK_PATH.open("w") as lock:
        try:
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return

        signature = wait_for_lid_topology() if "--lid" in sys.argv else stable_monitor_signature()
        if signature is None:
            return
        expected = {f"bar{i}" for i in range(len(signature))}
        if eww_ping() and active_bars() == expected:
            return

        # Only touch Eww when the current bar set is missing or stale.
        run([str(UPDATE)])
        stop_config_processes()
        start_daemon()
        reconcile(len(signature))


if __name__ == "__main__":
    main()
