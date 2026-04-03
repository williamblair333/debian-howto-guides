# XFCE → KDE Plasma 6 Migration on MX Linux 25 (Debian Trixie)

**System:** MX Linux 25 / Debian Trixie (amd64, systemd)  
**Plasma Version:** 6.3.x  
**Date:** 2026-03-31  
**Status:** Complete — fully functional KDE Plasma desktop  

---

## Table of Contents

1. [Background & Motivation](#1-background--motivation)
2. [Understanding the Debian KDE Metapackage Hierarchy](#2-understanding-the-debian-kde-metapackage-hierarchy)
3. [Phase 1 — Install KDE Plasma](#3-phase-1--install-kde-plasma)
4. [Phase 2 — Remove XFCE](#4-phase-2--remove-xfce)
5. [Phase 3 — Switch to SDDM](#5-phase-3--switch-to-sddm)
6. [Phase 4 — Fix Missing Packages (Trixie KF6 Renames)](#6-phase-4--fix-missing-packages-trixie-kf6-renames)
7. [Phase 5 — System Tray & Hardware Widgets](#7-phase-5--system-tray--hardware-widgets)
8. [Phase 6 — Validation](#8-phase-6--validation)
9. [The KDE Audit Script](#9-the-kde-audit-script)
10. [Gotchas & Lessons Learned](#10-gotchas--lessons-learned)
11. [Post-Migration Checklist](#11-post-migration-checklist)
12. [Troubleshooting Reference](#12-troubleshooting-reference)

---

## 1. Background & Motivation

MX Linux 25 ships with XFCE as its default desktop environment. While XFCE is capable, KDE Plasma 6 offers significantly richer hardware integration — system tray widgets for battery, bluetooth, network, and power profiles; KDE Connect phone integration; Wayland readiness; and a deeply customizable interface.

However, installing KDE on top of an existing XFCE system is **not** a clean swap. The process involves:

- Installing the correct metapackages (there are multiple tiers)
- Resolving package name differences introduced by the KF5 → KF6 transition in Trixie
- Removing XFCE to avoid conflicting service frontends
- Switching the display manager from LightDM to SDDM
- Manually fixing system tray widget visibility
- Ensuring `powerdevil` (battery/power management daemon) starts as a systemd user service

This guide documents every step and every pitfall encountered during the migration.

---

## 2. Understanding the Debian KDE Metapackage Hierarchy

Debian provides a tiered set of metapackages for KDE. **This is the most important thing to understand before installing.** Choosing the wrong tier leaves you with a half-complete desktop.

| Metapackage | What It Includes | Recommended For |
|---|---|---|
| `kde-plasma-desktop` | Bare Plasma shell + minimal apps (Dolphin, Kate, System Settings) | Minimalists who want to hand-pick every app |
| `kde-standard` | Plasma + common apps (Konsole, Gwenview, Okular, etc.) | Users who want a usable desktop out of the box |
| `kde-full` | Everything KDE ships: multimedia, networking, graphics, education, games, PIM, admin tools | Users who want the complete KDE experience |
| `task-kde-desktop` | Same as what the Debian installer selects when you choose KDE | Fresh-install parity |

Each tier is a superset of the one above it. **`kde-full` is the recommended starting point** — it includes all sub-metapackages:

- `kde-baseapps` — core applications
- `kdegraphics` — image viewers, screenshot tools
- `kdemultimedia` — media players, audio tools
- `kdenetwork` — network utilities
- `kdepim` — personal information management (email, calendar)
- `kdeutils` — system utilities
- `kdegames` — games
- `kdeedu` — educational software
- `kdetoys` — desktop toys and screensavers
- `kdeadmin` — system administration tools
- `kdeaccessibility` — accessibility tools (screen reader, magnifier)

> **Key insight:** Even `kde-full` does not install everything needed for full hardware integration. Packages like `plasma-nm` (network), `powerdevil` (battery/power), `bluedevil` (bluetooth), and various system tray widgets must be verified separately. See [Phase 4](#6-phase-4--fix-missing-packages-trixie-kf6-renames).

---

## 3. Phase 1 — Install KDE Plasma

### 3.1 Install the complete KDE stack

```bash
clear

sudo apt install --yes kde-full task-kde-desktop
```

This pulls in ~1.5–2 GB of packages. Let it complete fully before proceeding.

### 3.2 Install supplementary packages not covered by metapackages

Even `kde-full` does not include everything needed for full hardware integration. The following single command installs all supplementary packages with correct Trixie/KF6 names:

```bash
clear

sudo apt install --yes \
  kwin-x11 \
  kwin-wayland \
  plasma-nm \
  plasma-pa \
  powerdevil \
  power-profiles-daemon \
  bluedevil \
  bluez \
  bluez-obexd \
  plasma-thunderbolt \
  plasma-disks \
  plasma-firewall \
  sddm \
  sddm-theme-breeze \
  sddm-theme-debian-breeze \
  kde-config-sddm \
  libpam-kwallet5 \
  libpam-kwallet-common \
  kde-config-screenlocker \
  dolphin-plugins \
  kio-extras \
  kio-gdrive \
  kio-fuse \
  ffmpegthumbs \
  kdegraphics-thumbnailers \
  kimageformat-plugins \
  konsole \
  ksystemstats \
  plasma-systemmonitor \
  kde-spectacle \
  partitionmanager \
  ksystemlog \
  kwalletmanager \
  plasma-vault \
  sweeper \
  kmenuedit \
  kfind \
  kdeconnect \
  upower \
  udisks2 \
  plasma-welcome \
  plasma-discover \
  plasma-discover-backend-flatpak \
  kde-config-plymouth \
  xdg-desktop-portal-kde \
  libkf6dbusaddons-bin \
  breeze \
  breeze-cursor-theme \
  breeze-icon-theme \
  breeze-gtk-theme \
  qt6-wayland \
  fonts-noto \
  fonts-hack \
  fonts-noto-color-emoji
```

> **Why `kwin-x11`?** Trixie's `kde-plasma-desktop` only pulls in `kwin-wayland` by default. Without `kwin-x11`, X11 sessions (including XRDP) will fail to start. Install both.
>
> **Why `libkf6dbusaddons-bin`?** Provides `kquitapp6` and `kstart`, needed to restart `plasmashell` without logging out.

> [!IMPORTANT]
> **Complete ALL installs in Phase 1 before logging into a KDE Plasma session for the first time.** Many Plasma components (especially `kwin-x11` and `powerdevil`) are launched by systemd user services at login. If the binaries aren't present when the session starts, systemd marks the services as failed and hits its restart limit. Installing the packages later won't fix this — a full reboot is required to clear the failed state and allow a clean session startup.

---

## 4. Phase 2 — Remove XFCE

### 4.1 Why full removal matters

Running two desktop environments simultaneously causes **service frontend conflicts**. Specific pairs that fight each other:

| Service | XFCE Frontend | KDE Frontend | Conflict |
|---|---|---|---|
| Bluetooth | `blueman` | `bluedevil` | Competing pairing dialogs, duplicate tray icons |
| Network | `nm-applet` | `plasma-nm` | Duplicate network icons, connection race conditions |
| Audio | `pavucontrol` / `pasystray` | `plasma-pa` | Duplicate volume icons |
| Power | `xfce4-power-manager` | `powerdevil` | **Critical** — competing lid-close, suspend, dimming actions |

**Rule: one frontend per service.** The underlying daemons (`bluez`, `NetworkManager`, `upower`, `PulseAudio/PipeWire`) are shared — only the GUI frontends conflict.

### 4.2 Remove XFCE packages

```bash
clear

sudo apt remove --yes --purge \
  xfce4 \
  xfce4-* \
  thunar \
  thunar-* \
  mousepad \
  ristretto \
  xfburn \
  xfdesktop4 \
  xfwm4 \
  xfce4-power-manager \
  xfce4-notifyd \
  xfce4-terminal \
  xfce4-screenshooter \
  xfce4-taskmanager \
  xfce4-panel \
  xfce4-session \
  xfce4-settings \
  nm-applet \
  network-manager-gnome \
  blueman \
  pavucontrol \
  pasystray \
  parole \
  catfish \
  engrampa
```

### 4.3 Clean up orphaned dependencies

```bash
clear

sudo apt autoremove --yes --purge
```

### 4.4 Remove leftover autostart entries

```bash
clear

# Check for stragglers
ls /etc/xdg/autostart/*xfce* /etc/xdg/autostart/nm-applet* /etc/xdg/autostart/blueman* 2>/dev/null

# Remove them
sudo rm -f /etc/xdg/autostart/*xfce*
sudo rm -f /etc/xdg/autostart/nm-applet.desktop
sudo rm -f /etc/xdg/autostart/blueman.desktop
```

### 4.5 Update session file

```bash
clear

# Set KDE as the session for XRDP and local logins
echo 'exec startplasma-x11' > ~/.xsession
```

> **Note:** MX Linux tools (`mx-tools`, `mx-tweak`, `mx-updater`, `mx-snapshot`, `ddm-mx`) are GTK-based but **not XFCE-specific**. Do not remove them — they work fine under KDE and some are genuinely useful (e.g., `ddm-mx` for NVIDIA driver management).

### 4.6 Verify clean removal

```bash
clear

# This should return nothing
dpkg -l | grep -i xfce | awk '{print $2}'

# Periodic check after apt updates
ls /etc/xdg/autostart/*xfce* 2>/dev/null
```

---

## 5. Phase 3 — Switch to SDDM

SDDM is KDE's native display manager. Plasma themes apply to it, the Wayland/X11 session picker is integrated, and KDE System Settings has a built-in SDDM configuration module.

```bash
clear

# Install SDDM and KDE theme
sudo apt install --yes sddm sddm-theme-breeze kde-config-sddm

# Switch from LightDM to SDDM
sudo dpkg-reconfigure sddm

# Verify
cat /etc/X11/default-display-manager
# Expected: /usr/bin/sddm

# Reboot to activate
sudo reboot
```

<details>
<summary><strong>Troubleshooting: SDDM blank screen (NVIDIA)</strong></summary>

If the SDDM login screen is blank or renders at the wrong resolution, enable early KMS for the NVIDIA driver:

```bash
clear

sudo vim /etc/default/grub
# Add nvidia-drm.modeset=1 to GRUB_CMDLINE_LINUX_DEFAULT

sudo update-grub
sudo reboot
```

</details>

---

## 6. Phase 4 — Fix Missing Packages (Trixie KF6 Renames)

Debian Trixie ships KDE Frameworks 6 (KF6), which renamed many packages from the KF5 era. Guides written for older Debian versions or other distros will reference package names that **do not exist** in Trixie.

### 6.1 Package name mapping

| Generic / KF5 Name | Trixie (KF6) Name | Notes |
|---|---|---|
| `kwallet-pam` | `libpam-kwallet5` + `libpam-kwallet-common` | Auto-unlocks KWallet at login |
| `kscreenlocker` | `kde-config-screenlocker` | Screen lock configuration |
| `kimageformats` | `kimageformat-plugins` | Extra image format support for Qt |
| `elisa-player` | `elisa` | KDE music player |
| `solid` | `libkf5solid5` | Hardware abstraction library |
| `baloo-kf6` | `baloo6` | File search/indexing |
| `purpose` | *(not available in Trixie)* | Share menu integration — non-essential |
| `kde-connect` | `kdeconnect` | One word, no hyphen |
| `nm-applet` | `network-manager-gnome` | XFCE/GNOME network tray icon (remove during migration) |

### 6.2 How to find the correct package name

When a package name doesn't resolve:

```bash
clear

# Search for the correct name
apt search <partial-name> 2>/dev/null | head -10

# Example
apt search kimageformat 2>/dev/null | head -5
# Returns: kimageformat-plugins/stable 5.116.0-1 amd64
```

---

## 7. Phase 5 — System Tray & Hardware Widgets

This is where the most troubleshooting time was spent. KDE system tray widgets have multiple layers of configuration, and tools like `kwriteconfig6` frequently write to the **wrong section** of the config file.

### 7.1 The battery widget problem

**Symptom:** Battery icon does not appear in the system tray despite `upower` detecting the battery and `powerdevil-data` providing the widget files.

**Root cause:** `powerdevil` was not running. In Plasma 6, powerdevil runs as a **systemd user service**, not a standalone daemon.

```bash
clear

# Check if powerdevil is running
systemctl --user status plasma-powerdevil.service

# Start it if not running
systemctl --user start plasma-powerdevil.service

# Enable it for future logins
systemctl --user enable plasma-powerdevil.service

# View errors
journalctl --user -u plasma-powerdevil.service -b --no-pager
```

> **Key finding:** On systems migrated from XFCE, the Plasma user services may not activate automatically because the session was originally configured for XFCE. Switching to SDDM and rebooting resolves this.

### 7.2 Making all system tray items visible

**Symptom:** Icons are hidden behind the system tray chevron (˅). Configuration via `kwriteconfig6` writes to the wrong section of the config file.

**The reliable method:** Use the GUI.

1. Right-click the **chevron (˅)** in the system tray
2. Select **"Configure System Tray"**
3. Go to the **"Entries"** tab
4. Set each desired item to **"Always Shown"**
5. Click **Apply**

**The nuclear method** (if the GUI option isn't available or the tray is misconfigured):

```bash
clear

# Back up the config
cp ~/.config/plasma-org.kde.plasma.desktop-appletsrc \
   ~/.config/plasma-org.kde.plasma.desktop-appletsrc.bak.$(date +%Y%m%d)

# Delete it entirely — Plasma will rebuild a fresh default panel
rm ~/.config/plasma-org.kde.plasma.desktop-appletsrc

# Clear cached state
rm -rf ~/.cache/plasmashell*
rm -rf ~/.cache/plasma_theme*
rm -rf ~/.cache/plasma-svgelements*

# Logout and login (more reliable than plasmashell restart)
```

After logging back in, use the GUI method above to set visibility.

### 7.3 Why `kwriteconfig6` fails for system tray configuration

The system tray config lives in `~/.config/plasma-org.kde.plasma.desktop-appletsrc` under a specific containment section (e.g., `[Containments][26][General]`). The `kwriteconfig6` tool does not reliably target the correct nested section and instead writes keys to the top of the file or a generic `[Configuration]` group, where Plasma ignores them.

**Recommendation:** For system tray changes, always use either:

- The **GUI** (right-click chevron → Configure System Tray)
- Direct `sed` edits to the correct `[Containments][N][General]` section
- The **nuclear reset** (delete the config file and let Plasma rebuild)

### 7.4 Understanding the system tray config structure

The config file uses numbered containments. To find your system tray's section:

```bash
clear

# Find the system tray containment number
grep -n 'org.kde.plasma.private.systemtray' \
    ~/.config/plasma-org.kde.plasma.desktop-appletsrc
# Note the [Containments][N] number from this output

# View its configuration
grep -A20 '\[Containments\]\[N\]\[General\]' \
    ~/.config/plasma-org.kde.plasma.desktop-appletsrc
```

Key configuration keys in `[Containments][N][General]`:

| Key | Purpose | Example Value |
|---|---|---|
| `extraItems` | Widgets available in the tray | Comma-separated plugin IDs |
| `knownItems` | Widgets Plasma knows about | Comma-separated plugin IDs |
| `shownItems` | Widgets forced to always visible | Comma-separated plugin IDs |
| `hiddenItems` | Widgets forced to hidden | Comma-separated plugin IDs |
| `showAllItems` | Override: show everything | `true` / `false` |

---

## 8. Phase 6 — Validation

### 8.1 Verify core services

```bash
clear

# Power management
systemctl --user status plasma-powerdevil.service
upower -e

# Bluetooth
systemctl status bluetooth
bluetoothctl show

# Display manager
cat /etc/X11/default-display-manager

# Session type
echo $XDG_SESSION_TYPE
echo $XDG_CURRENT_DESKTOP

# No XFCE remnants
ls /etc/xdg/autostart/*xfce* 2>/dev/null
dpkg -l | grep -i xfce
```

### 8.2 Run the KDE audit script

See [Section 9](#9-the-kde-audit-script) for the full audit script.

```bash
clear

bash kde-audit.sh
```

All categories should show **Missing: 0** (except `purpose`, which is not available in Trixie and is non-essential).

---

## 9. The KDE Audit Script

This script checks installed packages against a complete KDE Plasma desktop using **correct Trixie package names**.

> **Important:** Generic package names from upstream KDE or other distros do not match Trixie's naming. This script accounts for the KF5 → KF6 renames documented in [Phase 4](#6-phase-4--fix-missing-packages-trixie-kf6-renames).

<details>
<summary><strong>Click to expand: kde-audit.sh</strong></summary>

```bash
#!/bin/bash
# KDE/Plasma Completeness Audit for Debian Trixie (KF6/Plasma 6)
# Uses correct Trixie package names — not generic upstream names

check_group() {
    local group="$1"
    shift
    local missing=()
    local installed=()

    for pkg in "$@"; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
            installed+=("$pkg")
        else
            missing+=("$pkg")
        fi
    done

    echo "=== $group ==="
    echo "  Installed: ${#installed[@]}  |  Missing: ${#missing[@]}"
    if [ ${#missing[@]} -gt 0 ]; then
        printf '  MISSING: %s\n' "${missing[*]}"
    fi
    echo ""
}

echo "============================================="
echo " KDE/Plasma Audit — Debian Trixie (Plasma 6)"
echo "============================================="
echo ""

echo ">>> OFFICIAL DEBIAN METAPACKAGES <<<"
echo "    (Install kde-full for the complete experience)"
echo ""
check_group "Metapackages" \
    kde-plasma-desktop kde-standard kde-full \
    task-kde-desktop \
    kde-baseapps kdegraphics kdemultimedia \
    kdenetwork kdepim kdeutils \
    kdegames kdeedu kdetoys kdeadmin \
    kdeaccessibility

echo ""
echo ">>> INDIVIDUAL PACKAGE AUDIT <<<"
echo ""

check_group "Core Desktop" \
    plasma-desktop plasma-workspace plasma-workspace-wallpapers \
    kwin-x11 kwin-wayland kscreen kgamma kactivitymanagerd \
    systemsettings kde-cli-tools drkonqi

check_group "System Tray & Applets" \
    plasma-nm plasma-pa powerdevil bluedevil \
    plasma-thunderbolt plasma-vault plasma-disks \
    plasma-firewall plasma-browser-integration \
    xdg-desktop-portal-kde

check_group "Session & Login" \
    sddm sddm-theme-breeze kde-config-sddm \
    libpam-kwallet5 libpam-kwallet-common \
    kde-config-screenlocker

check_group "File Management" \
    dolphin dolphin-plugins kio-extras kio-fuse \
    kio-gdrive ffmpegthumbs kdegraphics-thumbnailers \
    kimageformat-plugins ark

check_group "System Utilities" \
    konsole ksystemstats plasma-systemmonitor \
    partitionmanager ksystemlog kwalletmanager \
    kmenuedit kfind sweeper kdeconnect

check_group "Graphics & Media" \
    gwenview okular kde-spectacle elisa \
    kamoso kolourpaint

check_group "Text & Productivity" \
    kate kcalc kcharselect

check_group "Backend Services" \
    upower udisks2 bluez bluez-obexd \
    power-profiles-daemon libkf5solid5 \
    baloo6

check_group "Printing" \
    print-manager cups system-config-printer

check_group "Fonts" \
    fonts-noto fonts-hack fonts-noto-color-emoji

check_group "Theming" \
    breeze breeze-cursor-theme breeze-icon-theme \
    breeze-gtk-theme qt6-wayland

check_group "Recommended Extras" \
    plasma-welcome plasma-discover \
    plasma-discover-backend-flatpak \
    sddm-theme-debian-breeze \
    kde-config-plymouth

echo "==========================================="
echo ""
echo "QUICK FIX: If metapackages are missing, the"
echo "fastest path to a complete KDE desktop is:"
echo ""
echo "  sudo apt install kde-full task-kde-desktop"
echo ""
echo "This is what the Debian installer uses when"
echo "you select KDE during installation."
echo "==========================================="
```

</details>

---

## 10. Gotchas & Lessons Learned

### 10.1 `kwriteconfig6` is unreliable for nested config sections

`kwriteconfig6` works well for flat config files but fails when targeting deeply nested sections like `[Containments][26][General]` in the Plasma applets config. It silently writes to the wrong location. **Use the GUI or direct `sed` edits instead.**

### 10.2 `kde-full` is necessary but not sufficient

Even after installing `kde-full`, the following required manual installation:

- `kwin-x11` (not pulled in by default — only `kwin-wayland` is; required for X11/XRDP sessions)
- `plasma-nm`, `plasma-pa`, `bluedevil` (system tray widgets)
- `powerdevil`, `power-profiles-daemon` (power management)
- `libpam-kwallet5` (auto-unlock KWallet at login)
- `ffmpegthumbs`, `kdegraphics-thumbnailers`, `kimageformat-plugins` (Dolphin thumbnails)
- `sddm`, `sddm-theme-breeze` (display manager)
- `kdeconnect` (phone integration)
- `libkf6dbusaddons-bin` (provides `kquitapp6` / `kstart` for plasmashell restarts)

### 10.3 Powerdevil is a systemd user service in Plasma 6

In older Plasma versions, powerdevil started as a standalone daemon. In Plasma 6, it is managed by systemd as a user service (`plasma-powerdevil.service`). If the battery widget is missing, check this service first.

### 10.4 Conflicting frontends cause real problems

Two bluetooth managers, two network applets, or two power managers running simultaneously cause unpredictable behavior — duplicate tray icons, competing connection handlers, and conflicting lid-close/suspend actions. **Always remove the old frontend before installing the new one.**

### 10.5 XRDP session file must be updated

After migrating, `~/.xsession` must contain `exec startplasma-x11` (not `exec xfce4-session`). This also requires `kwin-x11` to be installed — Trixie's `kde-plasma-desktop` only pulls in `kwin-wayland` by default.

### 10.6 MX Linux tools survive the migration

MX-specific tools (`mx-tools`, `mx-tweak`, `mx-updater`, `mx-snapshot`, `ddm-mx`) are GTK-based but work fine under KDE. They are not XFCE-specific and should not be removed — particularly `ddm-mx` for NVIDIA driver management.

### 10.7 The nuclear reset is your friend

When the system tray is misconfigured beyond repair:

```bash
rm ~/.config/plasma-org.kde.plasma.desktop-appletsrc
rm -rf ~/.cache/plasmashell*
```

Log out, log back in. Plasma rebuilds a clean default panel with auto-detected hardware widgets. Reconfigure visibility via the GUI afterward.

### 10.8 kwin won't autostart if installed after first login

`kwin_x11` is launched by the `plasma-workspace-x11.target` systemd user target at login via a `Wants=plasma-kwin_x11.service` directive. The service unit is `static` (no `[Install]` section) — it cannot be manually `enable`d.

If `kwin-x11` is not installed when you first log into Plasma, systemd tries to start the service, fails (binary missing), and hits its restart limit. Installing the package afterward does not clear the failed state. **A full reboot is required.**

```bash
clear

# Diagnose: is kwin running?
systemctl --user status plasma-kwin_x11.service

# If "inactive (dead)" or "failed", and the binary exists:
which kwin_x11

# Fix: reboot to get a clean session startup
sudo reboot

# After reboot, verify:
systemctl --user status plasma-kwin_x11.service
# Should show: active (running)
```

The same pattern applies to `powerdevil` (`plasma-powerdevil.service`). Always install all packages before the first KDE login.

---

## 11. Post-Migration Checklist

- [x] `kde-full` and `task-kde-desktop` installed
- [x] All supplementary packages installed (system tray, power, bluetooth, file management)
- [x] `kwin-x11` and `kwin-wayland` both installed
- [x] XFCE fully removed (packages, autostart entries, orphaned dependencies)
- [x] SDDM set as display manager (`/usr/bin/sddm` in `/etc/X11/default-display-manager`)
- [x] `~/.xsession` contains `exec startplasma-x11`
- [x] `kwin-x11` installed (required for X11/XRDP sessions)
- [x] `powerdevil` running as systemd user service
- [x] Battery, bluetooth, network visible in system tray
- [x] `libpam-kwallet5` installed (auto-unlock KWallet at login)
- [x] No XFCE autostart entries in `/etc/xdg/autostart/`
- [x] KDE audit script passes with no missing packages

---

## 12. Troubleshooting Reference

<details>
<summary><strong>kwin not running / no window decorations</strong></summary>

Symptoms: no title bars, no window borders, `org.kde.KWin was not provided by any .service files` errors in journal.

```bash
clear

# Is the service running?
systemctl --user status plasma-kwin_x11.service

# Is the binary installed?
which kwin_x11
dpkg -l | grep kwin-x11

# If installed but service is dead/failed — reboot clears the failed state
sudo reboot

# If you need it running RIGHT NOW without rebooting:
systemctl --user start plasma-kwin_x11.service
# or
kwin_x11 --replace &
```

If this keeps happening after reboot, check that `plasma-workspace-x11.target` is active:

```bash
systemctl --user status plasma-workspace-x11.target
```

</details>

<details>
<summary><strong>Battery widget not appearing</strong></summary>

```bash
clear

# 1. Is powerdevil running?
systemctl --user status plasma-powerdevil.service

# 2. Does upower see a battery?
upower -e
upower -i /org/freedesktop/UPower/devices/battery_BAT0

# 3. Is the widget plugin installed?
find /usr/share/plasma/plasmoids -name "*battery*"

# 4. Start powerdevil if not running
systemctl --user enable --now plasma-powerdevil.service

# 5. Restart plasmashell
kquitapp6 plasmashell && kstart plasmashell &
```

</details>

<details>
<summary><strong>System tray icons hidden</strong></summary>

1. Right-click the chevron (˅) in the system tray
2. "Configure System Tray" → "Entries" tab
3. Set each item to "Always Shown"
4. Click Apply

Do **not** use `kwriteconfig6` for this — it writes to the wrong config section.

</details>

<details>
<summary><strong>Duplicate tray icons (XFCE + KDE)</strong></summary>

```bash
clear

# Find and remove conflicting XFCE autostart entries
ls /etc/xdg/autostart/*xfce* /etc/xdg/autostart/nm-applet* /etc/xdg/autostart/blueman* 2>/dev/null
sudo rm -f /etc/xdg/autostart/*xfce*
sudo rm -f /etc/xdg/autostart/nm-applet.desktop
sudo rm -f /etc/xdg/autostart/blueman.desktop
```

</details>

<details>
<summary><strong>SDDM blank screen after install</strong></summary>

```bash
clear

# NVIDIA: enable early KMS
sudo vim /etc/default/grub
# Add: nvidia-drm.modeset=1 to GRUB_CMDLINE_LINUX_DEFAULT
sudo update-grub
sudo reboot
```

</details>

<details>
<summary><strong>Package name not found in Trixie</strong></summary>

```bash
clear

# Search for the correct Trixie name
apt search <partial-name> 2>/dev/null | head -10

# Check what's actually installed
dpkg -l | grep -i <partial-name>
```

Refer to the [package name mapping table](#61-package-name-mapping) for common renames.

</details>

<details>
<summary><strong>Baloo (file search) errors in journal</strong></summary>

```bash
clear

# These are non-critical — Baloo search indexing errors
# If they're annoying, disable Baloo:
balooctl6 disable

# Or re-enable and rebuild the index:
balooctl6 enable
balooctl6 purge
balooctl6 check
```

</details>

<details>
<summary><strong>Plasmashell restart commands</strong></summary>

```bash
clear

# Requires libkf6dbusaddons-bin
sudo apt install --yes libkf6dbusaddons-bin

# Restart without logout
kquitapp6 plasmashell && kstart plasmashell &

# If that fails, use:
killall plasmashell && kstart plasmashell &
```

</details>

---

*Document maintained alongside the KDE audit script. Update when packages change or new issues are encountered.*
