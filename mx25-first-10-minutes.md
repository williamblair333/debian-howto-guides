# MX Linux 25 "Infinity" — First 30 Minutes Setup

A quick housekeeping guide for sysadmins. Get the annoyances out of the way, take a snapshot, install essential tools, set sane system defaults, and have a usable workstation.

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

For your user only, in a drop-in file (keeps `/etc/sudoers` untouched):
```bash
sudo visudo -f /etc/sudoers.d/nopasswd-$USER
```

Add:
```
yourusername ALL=(ALL) NOPASSWD: ALL
```

Replace `yourusername` with your actual username. Save and exit — `visudo` refuses to save a file with a syntax error.

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

## 9. Bring Up Wi-Fi (If It Shows Unavailable)

The update and installs in §12–§13 need a network. If `nmcli dev status` shows the Wi-Fi interface as `unavailable`, the radio is usually rfkill-blocked:

```bash
rfkill list
sudo rfkill unblock all
nmcli radio wifi on
```

If `rfkill list` still says `Hard blocked: yes`, it's a physical switch, Fn key or BIOS setting, not software. The tray icon on Xfce is the NetworkManager applet (`nm-applet`); check it's installed with `dpkg -l | grep -E 'network-manager-gnome|nm-applet'`. Full procedure: [Wi-Fi Won't Come Up](debian-wifi-rfkill-bringup.md).

---

## 10. Check Time, Timezone and Hostname

Wrong clocks break TLS, apt and log correlation. Check NTP sync and the zone:

```bash
timedatectl
```

Want `System clock synchronized: yes` and the right `Time zone`. Fix the zone with:

```bash
sudo timedatectl set-timezone America/New_York   # list: timedatectl list-timezones
```

Give the box a real name (it shows up in prompts, SSH keys and logs):

```bash
sudo hostnamectl set-hostname mybox
```

Then edit the `127.0.1.1` line in `/etc/hosts` to the same name, or `sudo` warns `unable to resolve host`.

---

## 11. Take a Timeshift Snapshot

Do this before the first upgrade, so a bad one can be rolled back. Timeshift ships with MX 25.

**GUI method:** Menu → Timeshift → RSYNC, pick the root partition, then **Create**.

**CLI method:**
```bash
sudo timeshift --create --comments "fresh install, before first upgrade"
sudo timeshift --list
```

MX Snapshot is a different tool: it builds a live ISO of the system, not a rollback point.

---

## 12. Update System

```bash
sudo apt update
# use with extreme caution — take the snapshot in §11 first
# sudo apt full-upgrade -y
```

---

## 13. Install Essential Sysadmin Tools

One command to install the RHCSA-aligned essentials:

```bash
sudo apt install -y \
  vim tmux screen bash-completion git \
  tree ncdu mc plocate ripgrep fd-find fzf bat \
  htop iotop lsof strace sysstat \
  jq shellcheck \
  curl wget \
  net-tools traceroute mtr tcpdump rsync iftop nethogs ethtool nmap \
  parted gdisk lvm2 smartmontools \
  xfsprogs btrfs-progs \
  lshw dmidecode pciutils usbutils \
  tar gzip bzip2 xz-utils zip unzip zstd pigz 7zip \
  logwatch \
  pv dos2unix
```

### What You Get

| Category | Packages |
|----------|----------|
| **Shell & Editors** | `vim` `tmux` `screen` `bash-completion` `git` |
| **File Navigation & Search** | `tree` `ncdu` `mc` `plocate` `ripgrep` `fd-find` `fzf` `bat` |
| **Process Monitoring** | `htop` `iotop` `lsof` `strace` `sysstat` |
| **Text & Scripts** | `jq` `shellcheck` |
| **Networking** | `curl` `wget` `net-tools` `traceroute` `mtr` `tcpdump` `rsync` `iftop` `nethogs` `ethtool` `nmap` |
| **Disk & Filesystem** | `parted` `gdisk` `lvm2` `smartmontools` `xfsprogs` `btrfs-progs` |
| **Hardware Info** | `lshw` `dmidecode` `pciutils` `usbutils` |
| **Archiving** | `tar` `gzip` `bzip2` `xz-utils` `zip` `unzip` `zstd` `pigz` `7zip` |
| **Logs** | `logwatch` |
| **Misc** | `pv` `dos2unix` |

Already installed by default: `sed` `awk` `grep` `cut` `sort` `uniq` `diff` `ss` `ip` `dig` `journalctl` `systemctl` `watch` `time`

**Debian renames two binaries** to avoid clashes: `fd-find` installs `fdfind` and `bat` installs `batcat`. To get the usual names:

```bash
mkdir -p ~/.local/bin
ln -s "$(command -v fdfind)" ~/.local/bin/fd
ln -s "$(command -v batcat)" ~/.local/bin/bat
```

Other notes:
- `zstd` — fast compression; `tar --zstd -cf backup.tar.zst dir/`. `pigz` is multi-core gzip (`tar -I pigz`). `7zip` provides `7z` for `.7z` and odd archive formats.
- `fzf` — source `/usr/share/doc/fzf/examples/key-bindings.bash` from `~/.bashrc` for fuzzy Ctrl-R history search.
- `plocate` — `locate file`; its index rebuilds daily, or now with `sudo updatedb`.
- `sysstat` — `iostat`, `mpstat`, `pidstat` work at once; `sar` history needs `ENABLED="true"` in `/etc/default/sysstat`.

---

## 14. Enable the Firewall

MX ships `ufw` with the Gufw front end. Deny inbound, allow outbound:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo ufw status verbose
```

**GUI method:** Menu → Firewall Configuration (Gufw) → Status on.

Running an SSH server on this box? `sudo ufw allow ssh` **before** `ufw enable` if you're connected remotely.

---

## 15. Confirm SSD Trim

The weekly trim timer should already be on. Check:

```bash
systemctl is-enabled fstrim.timer
sudo fstrim -av    # one-off trim; lists each filesystem trimmed
```

If it says `disabled`: `sudo systemctl enable --now fstrim.timer`.

---

## 16. Cap the Journal Size

The systemd journal can grow to 10% of the filesystem. Cap it:

```bash
sudo mkdir -p /etc/systemd/journald.conf.d
sudo tee /etc/systemd/journald.conf.d/size.conf << 'EOF'
[Journal]
SystemMaxUse=500M
EOF
sudo systemctl restart systemd-journald
journalctl --disk-usage
```

---

## 17. Compressed Swap with zram (Optional)

Worth it on machines with 8 GB of RAM or less. zram keeps swap in compressed RAM, which is far faster than swapping to disk.

```bash
sudo apt install -y zram-tools
sudo tee /etc/default/zramswap << 'EOF'
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF
sudo systemctl restart zramswap
swapon --show
```

`PERCENT` is the zram size as a share of RAM and takes precedence over `SIZE`. `PRIORITY=100` makes the kernel use zram before any disk swap.

---

## 18. Create an SSH Key

Make a key now so it's ready for git hosts and servers:

```bash
ssh-keygen -t ed25519 -a 64 -C "$USER@$(hostname -s)"
```

Host entries and installing the key on a server: [SSH Client Setup](debian-ssh-client-setup.md).

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
which vim tmux git htop jq curl lvm smartctl zstd rg fdfind batcat

# Clock synced, snapshot taken?
timedatectl | grep synchronized
sudo timeshift --list

# Firewall on, trim scheduled, journal capped?
sudo ufw status
systemctl is-enabled fstrim.timer
journalctl --disk-usage

# zram active (if §17 done)?
swapon --show

# SSH key exists?
ls ~/.ssh/id_ed25519.pub
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

---

## Related guides in this repo

- [Python Development Environment Setup](debian-python3-setup-guide.md) — set up Python properly before the first venv
- [Docker Setup](debian-docker-setup-guide.md) — the usual next install on a fresh box
- [tmux Session Manager + Custom MOTD](debian-tmux-motd-setup-guide.md) — shell quality-of-life once the desktop is usable
- [Auto-Unlock Login Keyring](multi-keyring-prompt-fix.md) — fixes the duplicate password prompt this guide leaves in place
- [XFCE to KDE Plasma 6 Migration](kde-plasma-migration-guide.md) — if you would rather not stay on Xfce
- [Wi-Fi Won't Come Up](debian-wifi-rfkill-bringup.md) — rfkill blocks and NetworkManager, the long form of §9
- [SSH Client Setup](debian-ssh-client-setup.md) — what to do with the key from §18

[Back to the repository index](README.md)
