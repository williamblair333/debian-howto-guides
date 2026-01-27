# MX Linux 25 "Infinity" — First 10 Minutes Setup

A quick housekeeping guide for sysadmins. Get the annoyances out of the way, install essential tools, and have a usable workstation.

**Assumes:** MX Linux 25 (Trixie/stable), amd64, systemd edition, Xfce desktop.

---

## 1. Set Default Editor to Vim

MX/Debian defaults to nano. Fix this system-wide for `visudo`, `git`, `crontab -e`, etc.

```bash
sudo update-alternatives --config editor
```

---

## 2. Disable Sudo Lecture

Kill the "We trust you have received the usual lecture..." message.

```bash
sudo tee /etc/sudoers.d/disable-lecture << 'EOF'
Defaults lecture=never
EOF
sudo chmod 440 /etc/sudoers.d/disable-lecture
```

---

## 3. Configure Sudo NOPASSWD (Optional)

**Security tradeoff.** Only do this on personal machines, not shared/production systems.

For your user only:
```bash
sudo visudo -f /etc/sudoers.d/nopasswd-$USER
```

Add:
```
yourusername ALL=(ALL) NOPASSWD: ALL
```

Replace `yourusername` with your actual username. Save and exit.

```bash
sudo chmod 440 /etc/sudoers.d/nopasswd-$USER
```

**Alternative — extend timeout instead:**
```bash
sudo tee /etc/sudoers.d/timeout << 'EOF'
Defaults timestamp_timeout=60
EOF
sudo chmod 440 /etc/sudoers.d/timeout
```

This caches credentials for 60 minutes instead of 15.

---

## 4. Ensure ~/.local/bin is in PATH

MX's `~/.profile` should handle this, but verify:

```bash
echo $PATH | grep -q "$HOME/.local/bin" && echo "OK" || echo "Missing"
```

If missing, add to `~/.bashrc`:
```bash
cat >> ~/.bashrc << 'EOF'

# Local bin
[[ -d "$HOME/.local/bin" ]] && PATH="$HOME/.local/bin:$PATH"
EOF

mkdir -p ~/.local/bin
source ~/.bashrc
```

---

## 5. Disable GRUB Timeout (Single-Boot Only)

If MX is your only OS, skip the boot menu.

**GUI method:** MX Tools → Boot Options → Set timeout to 0

**CLI method:**
```bash
sudo cp /etc/default/grub /etc/default/grub.bak.$(date +%Y%m%d)
sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
sudo update-grub
```

---

## 6. Switch to Double-Click for Files (Xfce)

MX defaults to single-click. If you prefer double-click:

**GUI method:** MX Tools → Tweak → Config Options → Disable both:
- Enable single-click on desktop
- Enable single-click in Thunar File Manager

**CLI method:**
```bash
xfconf-query -c thunar -p /misc-single-click -s false
xfconf-query -c xfce4-desktop -p /desktop-icons/single-click -s false
```

---

## 7. Fix Screen Tearing (Xfce)

If you see horizontal tearing during video or scrolling:

**GUI method:** MX Tools → Tweaks → Compositor

Try: VBlank = "xpresent", Compositor = "Xfwm (Xfce) Compositor"

Settings vary by hardware — experiment.

---

## 8. Enable Backports Repo (Optional)

MX 25 has backports commented out by default. Enable if you need newer packages:

```bash
sudo cp /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.bak.$(date +%Y%m%d)
```

Edit `/etc/apt/sources.list.d/debian.sources` and uncomment the backports section, or use MX Repo Manager from the menu.

---

## 9. Update System

```bash
sudo apt update
# use with extreme caution
# sudo apt full-upgrade -y
```

---

## 10. Install Essential Sysadmin Tools

One command to install the RHCSA-aligned essentials:

```bash
sudo apt install -y \
  vim tmux screen bash-completion \
  tree ncdu mc \
  htop iotop lsof strace \
  jq \
  curl wget \
  net-tools traceroute mtr tcpdump rsync \
  parted gdisk lvm2 smartmontools \
  xfsprogs btrfs-progs \
  lshw dmidecode pciutils usbutils \
  tar gzip bzip2 xz-utils zip unzip \
  logwatch \
  pv dos2unix
```

### What You Get

| Category | Packages |
|----------|----------|
| **Shell & Editors** | `vim` `tmux` `screen` `bash-completion` |
| **File Navigation** | `tree` `ncdu` `mc` |
| **Process Monitoring** | `htop` `iotop` `lsof` `strace` |
| **Text Processing** | `jq` |
| **Networking** | `curl` `wget` `net-tools` `traceroute` `mtr` `tcpdump` `rsync` |
| **Disk & Filesystem** | `parted` `gdisk` `lvm2` `smartmontools` `xfsprogs` `btrfs-progs` |
| **Hardware Info** | `lshw` `dmidecode` `pciutils` `usbutils` |
| **Archiving** | `tar` `gzip` `bzip2` `xz-utils` `zip` `unzip` |
| **Logs** | `logwatch` |
| **Misc** | `pv` `dos2unix` |

Already installed by default: `sed` `awk` `grep` `cut` `sort` `uniq` `diff` `ss` `ip` `dig` `journalctl` `systemctl` `watch` `time`

---

## Quick Verification

After completing the above:

```bash
# Editor set?
echo $EDITOR

# Sudo lecture disabled?
sudo -k && sudo true  # Should not lecture

# PATH includes local bin?
echo $PATH | grep -o "$HOME/.local/bin"

# Tools installed?
which vim tmux htop jq curl lvm smartctl
```

---

## What's NOT in This Guide

These deserve their own dedicated howtos:

- NVIDIA driver installation
- Docker/Podman setup
- SSH server hardening
- Virtualization (KVM/QEMU/libvirt)
- Git configuration and workflows
- Ansible automation
- Security hardening (fail2ban, auditd, lynis)
- PipeWire/PulseAudio troubleshooting
- Wayland vs X11 configuration
- Flatpak/Snap setup
- systemd vs sysVinit differences

---

## References

- [MX Linux Wiki](https://mxlinux.org/wiki/)
- [MX Linux Forum](https://forum.mxlinux.org/)
- [Debian Wiki - sudo](https://wiki.debian.org/sudo)
- [RHCSA Objectives](https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam)
