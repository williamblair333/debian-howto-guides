# Virtual Machine Manager Setup - MX Linux Trixie

Complete setup for KVM/QEMU virtualization with virt-manager on MX Linux Trixie (systemd).

## Prerequisites

- MX Linux Trixie (Debian Trixie-based)
- Systemd init system
- ≥ 2 GB RAM for VM host
- CPU with virtualization support (VT-x/AMD-V)
- Root or sudo access

## Verify CPU Virtualization Support

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
```

**Result should be > 0.** If 0, enable VT-x/AMD-V in BIOS.

## Installation

```bash
sudo apt update
sudo apt install -y virt-manager libvirt-daemon-system libvirt-clients \
  qemu-kvm qemu-utils bridge-utils gir1.2-spiceclientgtk-3.0 virt-viewer
```

## User Permissions & Service

```bash
# Add current user to required groups
sudo usermod -aG libvirt,kvm $(whoami)

# Enable and start libvirt service
sudo systemctl enable --now libvirtd

# Verify service status
systemctl status libvirtd
```

**⚠️ Log out and back in** for group membership to take effect.

## Default Network Setup

```bash
# Start the default NAT network
sudo virsh net-start default

# Enable autostart on boot
sudo virsh net-autostart default

# Verify network is active
sudo virsh net-list --all
```

Expected output: `default` should show `active` and `yes` for autostart.

## SPICE Console Fix

If you encounter SPICE-related errors in VM consoles:

```bash
sudo apt install --reinstall gir1.2-spiceclientgtk-3.0
sudo systemctl restart libvirtd
```

## Storage Pool Configuration

### Using Default Pool

The default pool (`/var/lib/libvirt/images`) works out of the box. Verify:

```bash
sudo virsh pool-list --all
```

### Custom Storage Pools (Optional)

For separate VM disk and ISO storage:

```bash
# Create directories
sudo mkdir -p /mnt/vm-disks /mnt/vm-isos

# Define pools
sudo virsh pool-define-as vm-disks dir --target /mnt/vm-disks
sudo virsh pool-define-as vm-isos  dir --target /mnt/vm-isos

# Build, start, and enable autostart
sudo virsh pool-build vm-disks
sudo virsh pool-build vm-isos
sudo virsh pool-start vm-disks
sudo virsh pool-start vm-isos
sudo virsh pool-autostart vm-disks
sudo virsh pool-autostart vm-isos

# Verify
sudo virsh pool-list --all
```

**Note:** For persistent storage on a dedicated partition:

1. Format: `sudo mkfs.ext4 /dev/sdXN`
2. Add to `/etc/fstab`: `UUID=<uuid> /mnt/vm-disks ext4 defaults 0 2`
3. Mount: `sudo mount -a`
4. Then follow custom pool steps above

## Verification

```bash
# Check virtualization support
virt-host-validate

# Launch virt-manager
virt-manager
```

All checks should return `PASS` or `WARN` (warnings are typically non-critical).

## Remote Host Management

Connect to remote KVM hosts via SSH:

```bash
virt-manager --connect qemu+ssh://user@hostname/system
```

## Troubleshooting

### Permission Denied Errors

```bash
# Verify group membership (logout/login required after usermod)
groups | grep -E 'libvirt|kvm'

# Check service status
systemctl status libvirtd
```

### Network Not Starting

```bash
# Check for conflicts with existing bridges
ip link show

# Restart network
sudo virsh net-destroy default
sudo virsh net-start default
```

### QEMU/KVM Not Found

```bash
# Verify installation
which qemu-system-x86_64
ls -l /usr/bin/qemu-system-*
```

## Quick Start

1. Launch: `virt-manager`
2. Click "Create a new virtual machine"
3. Choose ISO or network install
4. Allocate RAM/CPU (≤ 50% of host resources recommended)
5. Create virtual disk (qcow2 format for thin provisioning)
6. Finish and install OS

## Recommended Settings

- **CPU:** Pass-through host CPU for best performance
- **Disk format:** qcow2 (supports snapshots, thin provisioning)
- **Network:** Default NAT for simple setups, Bridge for server VMs
- **Display:** Spice (better integration) or VNC (wider compatibility)

---

**Tested on:** MX Linux 23.6 (Trixie) with systemd  
**Last updated:** 2025-01-25
