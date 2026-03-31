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

# --- Official Debian KDE Metapackages ---
# This is the "as intended" installation hierarchy
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

# --- Core Plasma Desktop ---
check_group "Core Desktop" \
    plasma-desktop plasma-workspace plasma-workspace-wallpapers \
    kwin-x11 kwin-wayland kscreen kgamma kactivitymanagerd \
    systemsettings kde-cli-tools drkonqi

# --- System Tray Widgets ---
check_group "System Tray & Applets" \
    plasma-nm plasma-pa powerdevil bluedevil \
    plasma-thunderbolt plasma-vault plasma-disks \
    plasma-firewall plasma-browser-integration \
    xdg-desktop-portal-kde

# --- Session & Login (Trixie names) ---
check_group "Session & Login" \
    sddm sddm-theme-breeze kde-config-sddm \
    libpam-kwallet5 libpam-kwallet-common \
    kde-config-screenlocker

# --- File Management (Trixie names) ---
check_group "File Management" \
    dolphin dolphin-plugins kio-extras kio-fuse \
    kio-gdrive ffmpegthumbs kdegraphics-thumbnailers \
    kimageformat-plugins ark

# --- System Utilities ---
check_group "System Utilities" \
    konsole ksystemstats plasma-systemmonitor \
    partitionmanager ksystemlog kwalletmanager \
    kmenuedit kfind sweeper kde-connect

# --- Graphics & Media (Trixie names) ---
check_group "Graphics & Media" \
    gwenview okular kde-spectacle elisa \
    kamoso kolourpaint

# --- Text & Productivity ---
check_group "Text & Productivity" \
    kate kcalc kcharselect

# --- Backend Services (Trixie names) ---
check_group "Backend Services" \
    upower udisks2 bluez bluez-obexd \
    power-profiles-daemon libkf5solid5 \
    baloo6

# --- Print ---
check_group "Printing" \
    print-manager cups system-config-printer

# --- Fonts ---
check_group "Fonts" \
    fonts-noto fonts-hack fonts-noto-color-emoji

# --- Theming & Appearance ---
check_group "Theming" \
    breeze breeze-cursor-theme breeze-icon-theme \
    breeze-gtk-theme qt6-wayland

# --- Extras not in metapackages but useful ---
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
