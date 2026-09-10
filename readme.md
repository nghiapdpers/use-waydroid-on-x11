# Waydroid Installation and Usage Guide for X11

## Table of Contents

1. [Introduction](#introduction)
2. [System Requirements](#system-requirements)
3. [Installation](#installation)
   - [Auto](#auto-install)
   - [Manual](#manual-install)
     - [Installing a nested Wayland compositor](#installing-a-nested-wayland-compositor)
     - [Installing Waydroid](#installing-waydroid)
     - [Initializing Waydroid](#initializing-waydroid)
4. [Usage](#usage)
   - [Launching Waydroid](#launching-waydroid)
   - [Stopping Waydroid](#stopping-waydroid)
5. [Additional Configuration](#additional-configuration)
   - [Hiding Waydroid Apps](#hiding-waydroid-apps)
   - [ARM Support](#arm-support-libhoudini--libndk)
   - [Clipboard Integration](#clipboard-integration)
6. [Automation](#automation)
   - [Startup Scripts](#startup-scripts)
7. [Uninstallation](#uninstallation)
8. [Security Notes](#security-notes)
9. [Troubleshooting](#troubleshooting)
10. [References](#references)

---

## Introduction

This comprehensive guide walks you through setting up and optimizing **Waydroid** on an X11-based Linux system. Waydroid offers a seamless Android container experience, tightly integrated into your desktop environment.

---

## System Requirements

Ensure your system meets these prerequisites:

- Running an **X11 desktop environment**.
- Administrative privileges (sudo).
- Essential packages: **curl**, **ca-certificates**, and **python3-pip**.

Install the prerequisites:

```bash
sudo apt install curl ca-certificates python3-pip wl-clipboard -y
```

---

## Installation

### Auto Install

You can use the following one-liner to install and set up Waydroid directly with **security verification**:

```bash
curl -sSL https://raw.githubusercontent.com/nghiapdpers/use-waydroid-on-x11/master/install.sh | sudo bash
```

**Note:** The installation script will prompt you to review the repository setup script before execution for security purposes. When prompted, type **`yes`** and press **Enter** to continue.

### Manual Install

#### Installing a nested Wayland compositor

Install **Cage** (recommended for many X11 setups, especially around suspend/resume) and **Weston** (optional legacy path):

```bash
sudo apt install cage weston -y
```

#### Installing Waydroid

##### Step 1: Add the Waydroid Repository (Securely)

**Secure method** (recommended - review before execution):

```bash
repo_script=$(mktemp)
curl -fsSL https://repo.waydro.id -o "$repo_script"
# Review the script
head -n 20 "$repo_script"
# Then execute it
sudo bash "$repo_script"
rm "$repo_script"
```

**Quick method** (if you trust the source):

```bash
curl https://repo.waydro.id | sudo bash
```

##### Step 2: Install Waydroid

Install Waydroid:

```bash
sudo apt install waydroid -y
```

---

#### Initializing Waydroid

Follow these steps with Weston running (nested on X11 is the expected case here):

1. **Start Weston** (default Wayland socket is `wayland-0` under `$XDG_RUNTIME_DIR`; that matches Wayland clients when `WAYLAND_DISPLAY` is unset):
   
   ```bash
   weston --xwayland
   ```

   If you use a custom socket (`weston --socket=NAME`), set `export WAYLAND_DISPLAY=NAME` in any terminal where you run Waydroid.

2. **Initialize Waydroid**:
   
   - Without Google Apps:
     
     ```bash
     sudo waydroid init
     ```
   - With Google Apps:
     
     ```bash
     sudo waydroid init -f -s GAPPS
     ```

#### Troubleshooting Binder Module Errors

For issues like:

```bash
[21:15:53] Failed to load binder driver
[21:15:53] ERROR: Binder node "binder" for waydroid not found
```

Follow [this guide](https://github.com/choff/anbox-modules).

---

## Usage

### Launching Waydroid

1. Start Weston (same defaults as above; on a typical X11 session this is `wayland-0`):
   
   ```bash
   weston --xwayland
   ```

2. From another terminal, if needed set `export WAYLAND_DISPLAY=wayland-0`, then launch Waydroid:
   
   ```bash
   waydroid show-full-ui
   ```

### Stopping Waydroid

Stop Waydroid gracefully:

```bash
waydroid session stop
```

---

## Additional Configuration

### Hiding Waydroid Apps

Run this script to hide Waydroid apps from the system launcher:

```bash
bash hide_waydroid_apps.sh
```

Or manually:

```bash
for app in ~/.local/share/applications/waydroid.*.desktop; do
    grep -q NoDisplay "$app" || sed '/^Icon=/a NoDisplay=true' -i "$app"
done
```

### ARM Support (libhoudini / libndk)

To enable ARM support on x86 for Waydroid, use the `waydroid_script` tool:

```bash
git clone https://github.com/casualsnek/waydroid_script
cd waydroid_script
python3 -m venv venv
venv/bin/pip install -r requirements.txt
sudo venv/bin/pip install InquirerPy tqdm
sudo venv/bin/python3 main.py
```

1. Run the script as shown above.
2. Choose `libhoudini` or `libndk` from the menu to install ARM translation layers.

### Clipboard Integration

Enable clipboard sharing:

1. Install pyclip:
   
   ```bash
   sudo pip install pyclip
   ```

2. Install wl-clipboard:
   
   ```bash
   sudo apt install wl-clipboard
   ```

---

## Automation

### Startup Scripts

#### 1. Configure Weston

Create `~/.config/weston.ini`:

```ini
[libinput]
enable-tap=true

[shell]
panel-position=none
```

#### 2. Create a Startup Script

Save the repository `waydroid-session.sh` as `/usr/bin/waydroid-session.sh` (or copy the same file from this project). It defaults to **Cage** and uses a proper `cleanup` trap on `EXIT`, `INT`, etc.

Make it executable:

```bash
chmod +x /usr/bin/waydroid-session.sh
```

#### 3. Add a Desktop Entry

Create `/usr/share/applications/waydroid-session.desktop`:

```ini
[Desktop Entry]
Version=1.0
Type=Application
Name=Waydroid Session
Comment=Start Waydroid in Cage (set WAYDROID_COMPOSITOR=weston for Weston)
Exec=/usr/bin/waydroid-session.sh
Icon=waydroid
Terminal=false
Categories=System;Emulator;
```

Make it executable:

```bash
chmod +x /usr/share/applications/waydroid-session.desktop
```

---

## Uninstallation

### Full Removal

Run the `clean-removal.sh` script:

1. Make it executable:
   
   ```bash
   chmod +x clean-removal.sh
   ```

2. Execute:
   
   ```bash
   sudo ./clean-removal.sh
   ```

---

## Security Notes

### Best Practices Implemented

✅ **Repository Script Verification**: The install script now downloads the repository setup script to a temporary file and prompts you to review it before execution.

✅ **Removed Redundant sudo**: Scripts that are meant to run with elevated privileges no longer call `sudo` internally.

✅ **Improved Error Handling**: All scripts now include proper error checking and informative error messages using `set -e`.

✅ **Safe File Operations**: Find commands use null separators (`-print0` with `xargs -0`) to safely handle filenames with spaces.

✅ **Variable Quoting**: All variables are properly quoted to prevent word splitting and globbing issues.

✅ **Input Validation**: Compositor selection is validated early in the session script to prevent injection attacks.

✅ **Backup Creation**: Configuration modifications create backup files (`.bak`) before changes.

### Important Recommendations

1. **Always review scripts** before executing them, especially those downloaded from the internet.
2. **Use the secure installation method** if you're unsure about the repository script.
3. **Keep your system updated** with the latest security patches (`sudo apt update && sudo apt upgrade`).
4. **Monitor running processes** - Waydroid runs Android containers with elevated privileges.
5. **Use strong credentials** if configuring Google Play on Waydroid.

---

## Troubleshooting

### Installation Script Hanging at Repository Review

If the auto-install script hangs after displaying:
```
Repository script downloaded to /tmp/tmp.roAYqckh1B
Please review the script before proceeding:
---
```

**Solution**: This is expected behavior! The script pauses for your security review. Simply type **`yes`** and press **Enter** to continue with the installation.

**Why this happens**: The script includes a security feature that requires you to confirm before adding the Waydroid repository. This prevents unauthorized automatic repository additions.

**Full interaction example**:
```bash
$ curl -sSL https://raw.githubusercontent.com/nghiapdpers/use-waydroid-on-x11/master/install.sh | sudo bash

[... script outputs ...]

Repository script downloaded to /tmp/tmp.roAYqckh1B
Please review the script before proceeding:
---
#!/usr/bin/env bash
# [... script content ...]
---
Do you want to continue? (yes/no): yes    ← Type 'yes' here
```

### Skip Confirmation (Not Recommended)

If you absolutely trust the repository and want to skip the prompt, you can manually run the Waydroid repository setup:

```bash
curl https://repo.waydro.id | sudo bash
apt update
sudo apt install waydroid -y
sudo waydroid init
```

However, **we strongly recommend** reviewing scripts before running them for security reasons.

### Black Screen on NVIDIA GPUs (SurfaceFlinger Crash)

If you have an **NVIDIA GPU** using the proprietary NVIDIA driver (e.g. `nvidia-driver-390`, `nvidia-driver-470`, `nvidia-driver-535`, etc.), Waydroid will open to a black screen because the proprietary NVIDIA driver does not support GBM/Mesa hardware acceleration in the Android container. Android's `surfaceflinger` will crash in an endless loop, causing Cage/Weston to receive invalid geometry and remain black.

**Fix: Enable CPU Software Rendering (SwiftShader)**:

1. Stop any running session:
   ```bash
   waydroid session stop
   ```

2. Configure Waydroid to use SwiftShader:
   ```bash
   sudo waydroid prop set ro.hardware.gralloc default
   sudo waydroid prop set ro.hardware.egl swiftshader
   ```

   *(Alternatively, edit `/var/lib/waydroid/waydroid.cfg` and under `[properties]` add `ro.hardware.gralloc = default` and `ro.hardware.egl = swiftshader`)*

3. Apply the properties and restart the container:
   ```bash
   sudo waydroid upgrade -o
   sudo systemctl restart waydroid-container
   ```

4. Launch Waydroid again:
   ```bash
   waydroid-session.sh
   # Or using Weston if Cage exhibits glitches:
   WAYDROID_COMPOSITOR=weston waydroid-session.sh
   ```

### Other Common Issues

- **Weston startup issues**: Verify Weston and X11 configurations.
- **Waydroid launch failures**: Ensure a running Weston session.
- **Performance problems**: Allocate more system resources.
- **Suspend/resume and `libwayland` client errors**: Weston can lose nested-Wayland state after repeated suspend cycles under some X11 window managers. The default session script uses **Cage** which handles this better.

### Fixing Play Store Uncertified Device Issue

If you are using the GApps version of Waydroid and see a "Device is not certified by Google" error in the Play Store, here is a potential fix.

1. **Enter the Waydroid Shell**
   
   Open a terminal on your computer and run:
   
   ```bash
   sudo waydroid shell
   ```
   
   You will now be inside the Android container's shell.

2. **Get Your GSF Android ID**
   
   Inside the `waydroid shell`, run this command to get your Google Services Framework ID:
   
   ```bash
   sqlite3 /data/data/com.google.android.gsf/databases/gservices.db "SELECT * FROM main WHERE name = 'android_id';"
   ```
   
   This will output a long number, which is your `android_id`. Copy this number.

3. **Register Your ID**
   
   Go to the Google Device Registration page: [https://www.google.com/android/uncertified/](https://www.google.com/android/uncertified/)
   
   Paste the `android_id` you copied into the input box and click "Register".

4. **Verify and Restart**
   
   Go back to the `waydroid shell` and run:
   
   ```bash
   ANDROID_RUNTIME_ROOT=/apex/com.android.runtime ANDROID_DATA=/data ANDROID_TZDATA_ROOT=/apex/com.android.tzdata ANDROID_I18N_ROOT=/apex/com.android.i18n sqlite3 /data/data/com.google.android.gm[...]
   ```
   
   After this, fully stop and restart Waydroid for the changes to take effect.
   
   ```bash
   # On your main linux terminal, not the waydroid shell
   waydroid session stop
   # Then restart it using your preferred method
   ```

Good luck!

---

## References

- [Waydroid Documentation](https://docs.waydro.id/)
- [Weston Documentation](https://wayland.freedesktop.org/)
- [Bash Scripting Best Practices](https://mywiki.wooledge.org/BashGuide)
- [Repository](https://github.com/nghiapdpers/use-waydroid-on-x11)

---
