#!/bin/bash

# Waydroid Complete Auto Installer Script

set -e

# Function to check for root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root. Use sudo." >&2
        exit 1
    fi
}

# Function to install prerequisites
install_prerequisites() {
    echo "Installing prerequisites..."
    apt update
    apt install -y curl ca-certificates python3-pip wl-clipboard gnupg
}

# Function to install nested Wayland compositors (Cage default in session script; Weston optional)
install_compositors() {
    echo "Installing Cage and Weston..."
    apt install -y cage weston
}

# Function to install Waydroid with repository verification
install_waydroid() {
    echo "Downloading Waydroid repository setup script..."
    local repo_script
    repo_script=$(mktemp)
    trap "rm -f '$repo_script'" RETURN
    
    if ! curl -fsSL https://repo.waydro.id -o "$repo_script"; then
        echo "Error: Failed to download Waydroid repository script" >&2
        return 1
    fi
    
    # Verify the script before execution (read from /dev/tty if available)
    echo "Repository script downloaded to $repo_script"
    echo "Please review the script before proceeding:"
    echo "---"
    head -n 20 "$repo_script"
    echo "---"
    
    # Read from /dev/tty if available (for pipe compatibility), else fall back to stdin
    if [ -t 0 ] || [ -c /dev/tty ]; then
        read -rp "Do you want to continue? (yes/no): " confirm < /dev/tty || confirm=""
    else
        read -rp "Do you want to continue? (yes/no): " confirm || confirm=""
    fi
    
    if [ "$confirm" != "yes" ]; then
        echo "Installation cancelled."
        return 1
    fi
    
    echo "Adding Waydroid repository..."
    bash "$repo_script"

    echo "Installing Waydroid..."
    apt install -y waydroid
}

# Function to initialize Waydroid
initialize_waydroid() {
    echo "Choose Android mode for Waydroid:"
    echo "1) Vanilla (No Google Apps)"
    echo "2) GApps (With Google Apps)"
    
    # Read from /dev/tty if available (for pipe compatibility), else fall back to stdin
    if [ -t 0 ] || [ -c /dev/tty ]; then
        read -rp "Enter your choice (1 or 2): " choice < /dev/tty || choice=""
    else
        read -rp "Enter your choice (1 or 2): " choice || choice=""
    fi

    case $choice in
        1)
            echo "Initializing Waydroid without Google Apps..."
            waydroid init
            ;;
        2)
            echo "Initializing Waydroid with Google Apps..."
            waydroid init -f -s GAPPS
            ;;
        *)
            echo "Invalid choice. Please run the script again."
            exit 1
            ;;
    esac
}

# Function to configure additional settings
configure_additional_settings() {
    echo "Configuring clipboard integration..."
    pip3 install pyclip

    echo "Creating Weston configuration..."
    mkdir -p ~/.config
    cat <<EOF > ~/.config/weston.ini
[libinput]
enable-tap=true

[shell]
panel-position=none
EOF

    echo "Creating Waydroid automation script..."
    _install_dir=""
    if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "bash" ] && [ "${BASH_SOURCE[0]}" != "-bash" ]; then
        _install_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    if [ -n "$_install_dir" ] && [ -f "$_install_dir/waydroid-session.sh" ]; then
        install -m 755 "$_install_dir/waydroid-session.sh" /usr/bin/waydroid-session.sh
    else
        tee /usr/bin/waydroid-session.sh > /dev/null <<'EOS'
#!/bin/bash

# Start Waydroid inside a nested Wayland compositor on X11.
#
# Default compositor is Cage (more stable across suspend/resume than Weston
# for many setups). Override with:
#   WAYDROID_COMPOSITOR=weston waydroid-session.sh

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
    echo "cage not found; install it (e.g. sudo apt install cage) or use WAYDROID_COMPOSITOR=weston" >&2
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
    echo "weston not found" >&2
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
  *)
    echo "Unknown WAYDROID_COMPOSITOR=$COMPOSITOR (use cage or weston)" >&2
    exit 1
    ;;
esac
EOS
        chmod +x /usr/bin/waydroid-session.sh
    fi

    echo "Creating Waydroid desktop entry..."
    bash -c 'cat <<EOF > /usr/share/applications/waydroid-session.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Waydroid Session
Comment=Start Waydroid in Cage (WAYDROID_COMPOSITOR=weston for Weston)
Exec=/usr/bin/waydroid-session.sh
Icon=waydroid
Terminal=false
Categories=System;Emulator;
EOF'
    chmod +x /usr/share/applications/waydroid-session.desktop
}

# Main script execution
main() {
    check_root
    install_prerequisites
    install_compositors
    install_waydroid || { echo "Waydroid installation failed" >&2; exit 1; }
    initialize_waydroid
    configure_additional_settings

    echo ""
    echo "=========================================="
    echo "Waydroid installation and configuration complete!"
    echo "=========================================="
    echo ""
    echo "To start Waydroid, use one of these methods:"
    echo "  1. Find 'Waydroid Session' in your applications menu"
    echo "  2. Run: waydroid-session.sh"
    echo "  3. Run with Weston: WAYDROID_COMPOSITOR=weston waydroid-session.sh"
    echo ""
}

main
