#!/bin/bash

# Start Waydroid inside a nested Wayland compositor on X11.
#
# Default compositor is Cage (more stable across suspend/resume than Weston
# for many setups). Override with:
#   WAYDROID_COMPOSITOR=weston waydroid-session.sh

set -e

cd "$(dirname "$0")" || exit 1

# Default compositor is Cage, but proprietary NVIDIA drivers on X11 do not support
# wlroots/cage EGL rendering. If NVIDIA driver is detected, default to Weston.
DEFAULT_COMPOSITOR="cage"
if lspci -k 2>/dev/null | grep -q "Kernel driver in use: nvidia"; then
  DEFAULT_COMPOSITOR="weston"
fi

COMPOSITOR="${WAYDROID_COMPOSITOR:-$DEFAULT_COMPOSITOR}"
COMPOSITOR=$(printf '%s' "$COMPOSITOR" | tr '[:upper:]' '[:lower:]')

# Validate compositor choice early
case "$COMPOSITOR" in
  cage|weston)
    : # Valid choice
    ;;
  *)
    echo "Error: Unknown WAYDROID_COMPOSITOR=$COMPOSITOR" >&2
    echo "Supported compositors: cage, weston" >&2
    exit 1
    ;;
esac

COMPOSITOR_PID=
WAYDROID_PID=

cleanup() {
  trap - EXIT INT TERM HUP

  waydroid session stop 2>/dev/null || true

  if [ -n "${WAYDROID_PID:-}" ]; then
    kill "$WAYDROID_PID" 2>/dev/null || true
    wait "$WAYDROID_PID" 2>/dev/null || true
  fi

  if [ -n "${COMPOSITOR_PID:-}" ]; then
    kill "$COMPOSITOR_PID" 2>/dev/null || true
    wait "$COMPOSITOR_PID" 2>/dev/null || true
  fi

  killall waydroid 2>/dev/null || true

  case "$COMPOSITOR" in
    weston) killall weston 2>/dev/null || true ;;
    cage)   killall cage 2>/dev/null || true ;;
  esac
}

trap cleanup EXIT INT TERM HUP

run_cage() {
  if ! command -v cage >/dev/null 2>&1; then
    echo "Error: cage not found" >&2
    echo "Install it with: sudo apt install cage" >&2
    echo "Or use Weston: WAYDROID_COMPOSITOR=weston waydroid-session.sh" >&2
    exit 1
  fi
  if lspci -k 2>/dev/null | grep -q "Kernel driver in use: nvidia"; then
    echo "Warning: Cage (wlroots) often fails with EGL errors on proprietary NVIDIA drivers on X11." >&2
    echo "If you experience a black screen or crash, run with Weston:" >&2
    echo "  WAYDROID_COMPOSITOR=weston waydroid-session.sh" >&2
  fi
  # Foreground: do not exec, so EXIT trap still runs when Cage exits.
  cage -s -- waydroid show-full-ui
}

run_weston() {
  if ! command -v weston >/dev/null 2>&1; then
    echo "Error: weston not found" >&2
    echo "Install it with: sudo apt install weston" >&2
    exit 1
  fi
  local socket_name="${WAYDROID_WAYLAND_DISPLAY:-wayland-0}"
  local win_width="${WAYDROID_WIDTH:-600}"
  local win_height="${WAYDROID_HEIGHT:-1000}"
  rm -f "$XDG_RUNTIME_DIR/$socket_name" "$XDG_RUNTIME_DIR/$socket_name.lock" 2>/dev/null || true

  # Ensure WAYLAND_DISPLAY is not passed to Weston so it uses x11-backend.so instead of trying to nest inside Wayland
  env -u WAYLAND_DISPLAY weston \
    --backend=x11-backend.so \
    --width="$win_width" \
    --height="$win_height" \
    --socket="$socket_name" \
    --xwayland &
  COMPOSITOR_PID=$!

  # Wait for Weston wayland socket to be ready
  for _ in $(seq 1 50); do
    if [ -S "$XDG_RUNTIME_DIR/$socket_name" ]; then
      break
    fi
    sleep 0.1
  done

  export WAYLAND_DISPLAY="$socket_name"
  waydroid show-full-ui &
  WAYDROID_PID=$!
  wait "$COMPOSITOR_PID"
}

case "$COMPOSITOR" in
  cage)  run_cage ;;
  weston) run_weston ;;
esac
