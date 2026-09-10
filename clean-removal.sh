#!/bin/bash

# Waydroid and Weston Uninstallation Script for Ubuntu-based Systems
# This script will remove Waydroid, Weston, associated packages, and custom desktop files and configuration directories.

# Function to check for root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root. Use sudo." >&2
        exit 1
    fi
}

echo "Starting Waydroid and Weston uninstallation..."

check_root

# Stop and disable Waydroid service if running
systemctl stop waydroid-container 2>/dev/null || true
systemctl disable waydroid-container 2>/dev/null || true

# Remove Waydroid package and its dependencies
apt purge -y waydroid
apt autoremove -y

# Remove nested compositor packages installed by this guide
apt purge -y cage weston
apt autoremove -y

# Delete user configuration and cache related to Waydroid
if [ -n "$SUDO_USER" ]; then
    user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    rm -rf "$user_home/.config/waydroid"
    rm -rf "$user_home/.local/share/waydroid"
    rm -rf "$user_home/.cache/waydroid"
    find "$user_home/.local/share/applications" -type f -name '*waydroid*.desktop' -print0 2>/dev/null | xargs -0 rm -f
fi
rm -rf ~/.config/waydroid
rm -rf ~/.local/share/waydroid
rm -rf ~/.cache/waydroid

# Remove custom .desktop files (e.g., launchers) - using find with proper null separator
find ~/.local/share/applications -type f -name '*waydroid*.desktop' -print0 2>/dev/null | xargs -0 rm -f

# Remove any system-wide .desktop files related to Waydroid (if present)
find /usr/share/applications -type f -name '*waydroid*.desktop' -print0 2>/dev/null | xargs -0 rm -f
rm -f /usr/bin/waydroid-session.sh

# Clean up remaining Waydroid directories (safety check)
rm -rf /var/lib/waydroid
rm -rf /etc/waydroid

echo ""
echo "=========================================="
echo "Waydroid and related files have been successfully removed from your system."
echo "=========================================="
echo ""
echo "Uninstallation complete. It is recommended to restart your system to apply changes."
