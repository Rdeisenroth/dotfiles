#!/usr/bin/env bash
# Toggle a Caelestia drawer on the monitor whose bar was clicked.
# Args: <output name, e.g. DP-1> [drawer: dashboard (default) | session]
# Clicks are serialised (flock) so fast clicking always alternates open/close, in click order.
# GTK reports the 2nd click of a double-click twice (~45ms apart): events < 90ms after the
# previous one on the same monitor are dropped.
mon=${1:-}; drawer=${2:-dashboard}
RUN="${XDG_RUNTIME_DIR:-/tmp}"
exec 9>"$RUN/ruboshapes-dash.lock"
flock 9
now=$(date +%s%3N)
last=$(cat "$RUN/ruboshapes-dash.last.$mon.$drawer" 2>/dev/null || echo 0)
(( now - last < 90 )) && exit 0
echo "$now" > "$RUN/ruboshapes-dash.last.$mon.$drawer"
if pgrep -x qs >/dev/null; then
  # drawers with a focus grab (launcher, session, sidebar) close at once if another monitor has
  # focus: focus the clicked monitor first (cursor:no_warps is on, so the mouse doesn't move)
  if [[ -n $mon && $drawer != dashboard ]]; then
    hyprctl dispatch "hl.dsp.focus({ monitor = \"$mon\" })" >/dev/null
  fi
  qs -c caelestia ipc call drawers toggleOn "$drawer" "$mon" 2>/dev/null || caelestia shell drawers toggle "$drawer"
  exit 0
fi
hyprctl dispatch "hl.dsp.focus({ window = \"class:spotify\" })" >/dev/null
