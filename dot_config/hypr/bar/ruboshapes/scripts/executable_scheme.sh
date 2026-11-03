#!/usr/bin/env bash
# Bar colour scheme on the focused monitor (used by the Caelestia launcher ">bar ..." actions).
#   scheme.sh <scheme>   ruboshapes | wallpaper | red | blue | ... (see: ipc call schemes list)
#   scheme.sh dark|light   (all monitors + system)
#   scheme.sh cycle      next colour option of this monitor's wallpaper
#   scheme.sh picker     open the picker under the Arch logo
DIR="$(cd "$(dirname "$0")/.." && pwd)"
mon=$(hyprctl monitors -j | python3 -c 'import json,sys; print(next(m["name"] for m in json.load(sys.stdin) if m["focused"]))')
ipc() { qs -p "$DIR" ipc call "$@" >/dev/null; }
case "${1:-picker}" in
  dark|light) ipc schemes mode "*" "$1" ;;      # system-wide
  cycle)      ipc schemes cycle "$mon" ;;
  picker)     ipc "bar-$mon" schemes ;;
  *)          ipc schemes set "$mon" "$1" ;;
esac
