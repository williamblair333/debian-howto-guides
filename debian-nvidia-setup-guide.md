# NVIDIA Driver Installation for MX Linux 25 (Official Method)

## Step 1: Identify Your GPU
```bash
# Check your NVIDIA GPU
lspci | grep -i nvidia

# Check current status
inxi -G
```

## Step 2: Install NVIDIA Driver Using ddm-mx

MX Linux has its own tool called `ddm-mx` (Debian Driver Manager for MX). This is the recommended method.

### Simple Installation (Recommended)
```bash
# Standard installation (auto-detects GPU and installs appropriate driver)
sudo ddm-mx -i nvidia
```

The tool will:
1. Detect your NVIDIA GPU
2. Show available driver versions from MX/Debian repos
3. Prompt you to choose (usually just press Enter for default)
4. Install driver + DKMS modules
5. Prompt for reboot

### Advanced Installation (Choose Specific Version)

For MX Linux 25 with ddm-mx 25.01.02+, you can access NVIDIA Developer Repository:
```bash
# Install with access to multiple driver versions
sudo ddm-mx -i nvidia -N
```

The `-N` switch:
- Enables NVIDIA Developer Repository
- Lets you choose from multiple driver versions (390, 470, 525, 535, 550, etc.)
- Automatically handles cleanup afterward

### GUI Method
```bash
# Or use MX Tools GUI
# Application Menu → MX Tools → NVIDIA Driver Installer
```

## Step 3: Reboot
```bash
sudo reboot
```

## Step 4: Verify Installation
```bash
# Check driver loaded
nvidia-smi

# Verify in system info
inxi -G

# Should show something like:
# Graphics:
#   Device-1: NVIDIA [Your GPU] driver: nvidia v: 535.xxx
#   Display: x11 server: X.Org driver: nvidia
#   OpenGL: renderer: [Your GPU] v: 4.6.0 NVIDIA 535.xxx
```

## Post-Installation Optimization

### NVIDIA Settings
```bash
# Launch NVIDIA control panel
nvidia-settings
```

Key settings:
- **PowerMizer**: "Prefer Maximum Performance" (desktop) or "Adaptive" (laptop)
- **Force Composition Pipeline**: Enable to eliminate screen tearing
- Save to X Configuration File when done

### Fix Screen Tearing (If Present)
```bash
# Create Xorg config snippet
sudo vim /etc/X11/xorg.conf.d/20-nvidia.conf
```

Paste:
```
Section "Device"
    Identifier     "NVIDIA Card"
    Driver         "nvidia"
    VendorName     "NVIDIA Corporation"
    Option         "NoFlip" "false"
    Option         "TripleBuffer" "true"
EndSection

Section "Screen"
    Identifier     "Screen0"
    Option         "metamodes" "nvidia-auto-select +0+0 {ForceCompositionPipeline=On}"
EndSection
```

Or in nvidia-settings:
1. X Server Display Configuration → Advanced
2. Enable "Force Composition Pipeline"
3. Save to X Configuration File

### Enable DRM Kernel Mode Setting
```bash
# Edit GRUB
sudo vim /etc/default/grub
```

Add `nvidia-drm.modeset=1` to kernel parameters:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash nvidia-drm.modeset=1"
```
```bash
sudo update-grub
sudo reboot
```

## Troubleshooting

### Black Screen / Blinking Cursor After Install
```bash
# Press Ctrl+Alt+F1 to get to console
# Login

# First try removing xorg.conf
sudo mv /etc/X11/xorg.conf /etc/X11/xorg.conf.bak
sudo reboot
```

If that doesn't work:
```bash
# Remove NVIDIA driver and revert to nouveau
sudo ddm-mx -p nvidia
sudo reboot
```

### Check Installation Log
```bash
# View ddm-mx log for errors
cat /var/log/ddm.log
```

### Driver Not Loading After Kernel Update
```bash
# DKMS should rebuild automatically, but if not:
sudo dkms autoinstall
sudo reboot
```

## Advanced: Install Specific Driver Version

If you need a specific version (e.g., 550 series):
```bash
# Use the -N switch to access NVIDIA Developer Repository
sudo ddm-mx -i nvidia -N

# During installation, choose option 2 (NVIDIA Direct/Developer)
# Then select the version you need
```

## Removal / Rollback

### Remove NVIDIA Driver
```bash
# Purge NVIDIA driver and revert to open-source nouveau
sudo ddm-mx -p nvidia

# Clean up leftover packages
sudo apt autoremove

sudo reboot
```

## Optimus Laptops (Intel + NVIDIA)

If you have an Optimus laptop with both Intel and NVIDIA GPUs:
```bash
# ddm-mx will detect this and offer to install Bumblebee
sudo ddm-mx -i nvidia

# For newer systems, use PRIME instead
# Run apps with NVIDIA GPU:
nvidia-run-mx your-application
```

## Maintenance

### Update Driver
```bash
# Drivers update automatically with system updates
sudo apt update
sudo apt upgrade

# If you want to check for newer versions:
sudo ddm-mx -i nvidia
```

DKMS automatically rebuilds driver modules when kernel is updated.

## Why Use ddm-mx Instead of Manual Installation?

MX Linux's `ddm-mx` tool:
- Auto-detects your GPU
- Handles DKMS setup correctly
- Manages conflicts with nouveau
- Configures X server properly
- Provides easy rollback with `-p` flag
- Maintains MX-specific configurations
- Logs everything to `/var/log/ddm.log`
