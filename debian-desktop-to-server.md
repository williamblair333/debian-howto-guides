# 🖥️ Turning a Desktop, Laptop or Raspberry Pi into an Always-On Server

> **Purpose**: take a machine built to be used in front of you, and make it run unattended: no sleep, no desktop, reachable by SSH, back up by itself after a power cut, patched, and diagnosable when it does die.
> **Audience**: anyone repurposing an old PC, a laptop or a Pi as a home server.
> **Scope**: Debian 13 (Trixie), MX 25 booted with **systemd**, and Raspberry Pi OS (Bookworm / Trixie). NetworkManager for networking. MX boots sysVinit by default; most of this guide needs systemd (pick it in the GRUB menu, or set it as default in MX Boot Options).
> **SSH from your workstation**: [debian-ssh-client-setup.md](debian-ssh-client-setup.md).

Run §1–§13 on the box being converted, in order. §14 checks all of it in one block. Hardware-specific steps are marked **Laptop** or **Pi**.

> [!IMPORTANT]
> Several steps change sleep, boot target and firmware settings. None of them need a reboot to be *written*, but some only take effect after one. The guide says where. **You** do the reboot.

---

## 1. Before you start

```bash
cat /etc/os-release | head -3
systemctl --version | head -1       # must print a systemd version; "not found" = sysVinit (MX default)
ip -br addr                         # current interfaces and addresses
```

Keep a console (keyboard and monitor, or the Pi's HDMI) available until §6 is done. If SSH breaks halfway, that's how you get back in.

---

## 2. Hostname and time

```bash
sudo hostnamectl set-hostname pi5          # short, lowercase, no dots
sudo sed -i "s/^127\.0\.1\.1.*/127.0.1.1\tpi5/" /etc/hosts
hostnamectl
timedatectl                                 # "System clock synchronized: yes", "NTP service: active"
sudo timedatectl set-timezone America/New_York   # if wrong; list with: timedatectl list-timezones
```

A wrong clock breaks TLS, apt and log correlation. If NTP shows `inactive`: `sudo apt install --yes systemd-timesyncd`.

**mDNS** lets every machine on the LAN reach it as `pi5.local` without a DNS server:

```bash
sudo apt install --yes avahi-daemon        # on the server (Pi OS already has it)
sudo apt install --yes libnss-mdns         # on each client that should resolve .local
```

---

## 3. Give it a fixed address

Your SSH config ([client guide §4](debian-ssh-client-setup.md#4-a-host-entry)) and any port forwards point at an address. It must not change.

**Preferred: DHCP reservation on the router.** Map the server's MAC to an IP in the router's DHCP settings. Nothing changes on the server, and the router stays the one place addresses are managed.

```bash
ip -br link        # MAC address of the interface you'll use
```

**Alternative: static on the server**, with NetworkManager. Running this over SSH drops your session when the address changes. Do it from the console, or use the new address to reconnect.

```bash
nmcli -f NAME,DEVICE,TYPE con show
CON="Wired connection 1"                        # change me
sudo nmcli con mod "$CON" ipv4.method manual \
    ipv4.addresses 192.168.1.50/24 ipv4.gateway 192.168.1.1 ipv4.dns 192.168.1.1
sudo nmcli con up "$CON"
```

Pick an address **outside** the router's DHCP pool, or the router will eventually hand it to something else.

---

## 4. Never sleep

A desktop or laptop suspends after idle time, on lid close, or when the power button is pressed. A server must do none of these.

**Block every sleep state** at the systemd level. This wins over any desktop power manager, which has to ask systemd to suspend:

```bash
sudo systemctl mask sleep.target suspend.target hibernate.target \
    hybrid-sleep.target suspend-then-hibernate.target
```

**Laptop: ignore the lid**, and tell `logind` not to act on idle:

```bash
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/10-server.conf >/dev/null <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
IdleAction=ignore
EOF
sudo systemctl reload systemd-logind
```

On Debian 13 (systemd 257), `reload` re-reads the file without ending sessions. If `reload` is refused on an older release, the setting applies at next boot.

**Screen**: after §5 there's only a text console, and it may never blank (`cat /sys/module/kernel/parameters/consoleblank` prints `0`). To turn the panel off after a minute, add `consoleblank=60` to the kernel command line (§5 shows where).

Check: `systemctl status sleep.target` must say `masked`. `systemctl suspend` must fail with `Unit suspend.target is masked`.

> [!NOTE]
> Undo: `sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target` and delete the logind drop-in.

---

## 5. Boot without a desktop

The desktop uses RAM and CPU, and runs things you don't want unattended (update notifiers, sleep timers, screen lockers).

```bash
sudo systemctl set-default multi-user.target
systemctl get-default          # multi-user.target
```

Takes effect at next boot. The desktop is still installed; `sudo systemctl isolate graphical.target` starts it once, and `sudo systemctl set-default graphical.target` brings it back permanently.

Remove it entirely only once the server has run headless for a while and you're sure. Purging task-* metapackages can pull out more than you expect, so read `apt`'s list before saying yes.

**Kernel command line** (for `consoleblank=` and similar):

| Hardware | File | Then |
| :--- | :--- | :--- |
| PC / laptop | `GRUB_CMDLINE_LINUX_DEFAULT=` in `/etc/default/grub` | `sudo update-grub` |
| Pi | the single line in `/boot/firmware/cmdline.txt` | nothing; read at boot |

**Pi**: Raspberry Pi OS **Lite** has no desktop at all. For a fresh Pi server, flash Lite, and set hostname, user, SSH key and Wi-Fi in Raspberry Pi Imager's settings before writing the card.

---

## 6. SSH server

```bash
sudo apt install --yes openssh-server
sudo systemctl enable --now ssh
systemctl is-active ssh       # active
```

Then, **from your workstation**, follow [debian-ssh-client-setup.md](debian-ssh-client-setup.md), or run:

```bash
./ssh-add-host.sh pi5 192.168.1.50 bill
```

Once key login works, turn off password login ([client guide §6](debian-ssh-client-setup.md#6-turn-off-password-login-on-the-server), or `--harden`). Do that before §8 opens anything to the network.

**Brute-force protection** (fail2ban). Debian 12+ logs to the journal, not `/var/log/auth.log`, so fail2ban must be told to read the journal:

```bash
sudo apt install --yes fail2ban python3-systemd
sudo tee /etc/fail2ban/jail.d/10-sshd-journal.local >/dev/null <<'EOF'
[sshd]
enabled = true
backend = systemd
EOF
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd     # "Currently banned" etc.; an error here means the jail didn't load
```

On a LAN-only box with password login off, fail2ban is optional. It matters when port 22 is forwarded from the internet.

---

## 7. Security updates without you

```bash
sudo apt install --yes unattended-upgrades apt-listchanges
sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
sudo tee /etc/apt/apt.conf.d/52unattended-upgrades-local >/dev/null <<'EOF'
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
EOF
sudo unattended-upgrade --dry-run --debug 2>&1 | grep -E 'Allowed origins|Packages that will be upgraded'
```

- The default only installs from **Debian security** (and Pi OS's equivalent). MX's own repo isn't in the allowed origins; MX packages still need a manual `apt upgrade`.
- `Automatic-Reboot "false"`: kernel and libc updates install but don't apply until a reboot. When one is waiting, `/var/run/reboot-required` exists. Check for it when you log in, and reboot at a time you choose.
- Logs: `/var/log/unattended-upgrades/`.

---

## 8. Firewall

Allow SSH from your LAN only, deny other inbound, allow all outbound:

```bash
sudo apt install --yes ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp     # your LAN; change me
sudo ufw enable                                                  # prompts once; your SSH session survives
sudo ufw status verbose
```

Open each service you add the same way: `sudo ufw allow from 192.168.1.0/24 to any port 8080 proto tcp`.

> [!WARNING]
> **Docker bypasses ufw.** A container port published with `-p 8080:8080` is reachable from anywhere ufw would have blocked, because Docker inserts its own rules ahead of ufw's. Publish to a specific address (`-p 192.168.1.50:8080:8080`) or `127.0.0.1`, and put a reverse proxy in front. See [Docker setup](debian-docker-setup-guide.md).

---

## 9. Wi-Fi servers

Wired is better: lower latency, no power-save stalls, and bridged VMs work. If Wi-Fi is the only option:

- **Turn off Wi-Fi power save.** It's what makes inbound SSH lag by seconds and sessions drop. Full fix: [uplink guide §5](debian-wifi-uplink-guide.md#5-required-fix-disable-wifi-power-save). Short version, for any NetworkManager system including the Pi:

  ```bash
  sudo tee /etc/NetworkManager/conf.d/99-wifi-powersave-off.conf >/dev/null <<'EOF'
  [connection]
  wifi.powersave = 2
  EOF
  sudo systemctl restart NetworkManager
  iw dev wlan0 get power_save        # Power save: off  (interface name: ip -br link)
  ```

- **Pi**: the onboard Broadcom chip (`brcmfmac`) has power save **on** by default, and Pi servers on Wi-Fi are where it bites most. The NetworkManager drop-in above covers Raspberry Pi OS Bookworm and later. The uplink guide's Intel `iwlmvm` step does not apply to a Pi.
- What else breaks on Wi-Fi (bridged VMs, macvlan containers, Wake-on-LAN): [debian-wifi-uplink-guide.md](debian-wifi-uplink-guide.md).
- Wi-Fi shows `unavailable`: [debian-wifi-rfkill-bringup.md](debian-wifi-rfkill-bringup.md).

---

## 10. Come back after a power cut

| Hardware | Setting | Where |
| :--- | :--- | :--- |
| Desktop PC | **Restore on AC power loss** = *Power On* (also called *AC Power Recovery*, *After Power Failure*, *AC Back*) | BIOS/UEFI setup, usually under Power or Advanced |
| Laptop | The battery rides out short cuts. For long ones that drain it: **Power on with AC attach** (Lenovo), **Wake on AC** (Dell), where offered | BIOS/UEFI setup; many laptops don't have it |
| Pi | Boots whenever power is applied; nothing to set. Pi 5 only: after a clean `shutdown` with power left connected it stays off until you press its power button or cycle the power. | — |

Test it: with the server running, pull the plug, wait 10 s, plug it back in. It should come up and answer `ssh pi5` without anyone touching it.

**Wake-on-LAN** (wired PCs only, enabled in BIOS too) lets you power it on remotely after a clean shutdown:

```bash
ethtool enp3s0 | grep Wake-on            # "g" in Supports Wake-on = magic packet supported
sudo nmcli con mod "$CON" 802-3-ethernet.wake-on-lan magic
# from another machine: sudo apt install --yes wakeonlan && wakeonlan <MAC>
```

---

## 11. Laptop: protect the battery

A laptop plugged in permanently holds its battery at 100 %, which ages it fastest and can make it swell. Cap the charge if the hardware supports it:

```bash
ls /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null \
    || echo "No charge limit exposed by this laptop's driver"
```

If the file exists (most ThinkPads, many ASUS, some Dell, LG and Huawei), make an 80 % cap survive reboots:

```bash
sudo tee /etc/systemd/system/battery-charge-limit.service >/dev/null <<'EOF'
[Unit]
Description=Cap battery charge at 80%

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for f in /sys/class/power_supply/BAT*/charge_control_end_threshold; do echo 80 > "$f"; done'

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now battery-charge-limit.service
cat /sys/class/power_supply/BAT*/charge_control_end_threshold    # 80
```

No file? Check the BIOS for a charge limit or "primarily AC use" setting (Dell, HP and Lenovo often have one). If there's nothing, consider running it with the battery removed, if the model allows. A swollen battery is a fire risk; replace it, don't ignore it.

---

## 12. Pi: power and storage

**Power supply.** Undervoltage causes random crashes and SD-card corruption that look like software bugs.

```bash
vcgencmd get_throttled        # throttled=0x0 = never undervolted or throttled since boot
```

Anything else: use the official supply (5 V 3 A for Pi 4, 5 V 5 A for Pi 5), a shorter cable, or a powered USB hub for drives.

**SD cards wear out under constant writes.** In order of benefit:

1. **Boot from an SSD** (USB 3, or NVMe on a Pi 5 HAT). Removes the problem.
2. Use a high-endurance card, and keep `apt` caches and logs from filling it.
3. Cap the journal so it can't grow unbounded. §13 makes it persistent, and this limits how much it keeps:

   ```bash
   sudo mkdir -p /etc/systemd/journald.conf.d
   printf '[Journal]\nSystemMaxUse=100M\n' | sudo tee /etc/systemd/journald.conf.d/20-size.conf
   sudo systemctl restart systemd-journald
   ```

Keep a full image of the card once it's set up, so a dead card is a 10-minute reflash, not a rebuild.

---

## 13. When it dies: watchdog and logs

**Persistent journal**, so `journalctl -b -1` shows what happened before the last crash:

```bash
sudo mkdir -p /etc/systemd/journald.conf.d
printf '[Journal]\nStorage=persistent\n' | sudo tee /etc/systemd/journald.conf.d/10-persistent.conf
sudo systemctl restart systemd-journald
journalctl --list-boots | tail -3      # more than one line after the next reboot
```

**Hardware watchdog**: if the kernel hangs, the board resets itself instead of sitting frozen until you notice.

```bash
ls /dev/watchdog* 2>/dev/null || echo "No watchdog device"
# PCs: iTCO_wdt (Intel) or sp5100_tco (AMD) drivers; Pi: bcm2835_wdt, built in
sudo mkdir -p /etc/systemd/system.conf.d
sudo tee /etc/systemd/system.conf.d/10-watchdog.conf >/dev/null <<'EOF'
[Manager]
RuntimeWatchdogSec=30s
RebootWatchdogSec=10min
EOF
```

Takes effect at next boot. Check afterwards: `wdctl` shows a timeout of 30 s, and `systemctl show -p RuntimeWatchdogUSec` shows `30s`.

> [!CAUTION]
> Don't test the watchdog by crashing the kernel on a box you care about. If you want proof, do it on a spare.

---

## 14. Verify everything

One block. Each line prints `OK` or what's wrong. Run it after the reboot that §4, §5 and §13 need.

```bash
chk() { if eval "$2" >/dev/null 2>&1; then echo "OK    $1"; else echo "FAIL  $1"; fi; }
chk "systemd is init"            '[ "$(ps -p1 -o comm=)" = systemd ]'
chk "sleep masked"               '[ "$(systemctl is-enabled sleep.target)" = masked ]'
chk "suspend masked"             '[ "$(systemctl is-enabled suspend.target)" = masked ]'
chk "headless default target"    '[ "$(systemctl get-default)" = multi-user.target ]'
chk "time synchronized"          'timedatectl show -p NTPSynchronized --value | grep -qx yes'
chk "ssh active"                 'systemctl is-active --quiet ssh'
chk "ssh password login off"     'sudo sshd -T | grep -qx "passwordauthentication no"'
chk "ssh root login off"         'sudo sshd -T | grep -qx "permitrootlogin no"'
chk "unattended-upgrades on"     'apt-config dump | grep -q "APT::Periodic::Unattended-Upgrade \"1\""'
chk "firewall active"            'sudo ufw status | grep -q "Status: active"'
chk "journal persistent"         '[ -d /var/log/journal ]'
chk "watchdog armed"             '[ "$(systemctl show -p RuntimeWatchdogUSec --value)" != 0 ]'
chk "no reboot pending"          '[ ! -e /var/run/reboot-required ]'
chk "wifi power save off (if wifi)" '! iw dev 2>/dev/null | grep -q Interface || iw dev | awk "/Interface/{print \$2}" | xargs -I{} iw dev {} get power_save | grep -qv on'
chk "lid ignored (laptop)"       '! ls /proc/acpi/button/lid >/dev/null 2>&1 || grep -rqs "^HandleLidSwitch=ignore" /etc/systemd/logind.conf.d/'
chk "pi not throttled (pi)"      '! command -v vcgencmd || vcgencmd get_throttled | grep -qx "throttled=0x0"'
```

Then the real test, from §10: pull the plug, plug it back in, and `ssh pi5` from your workstation without touching the server.

---

## 15. Verified vs. not

**Checked on the machine this was written on** (Debian 13, systemd 257, OpenSSH 10.0): `systemd-logind` supports `reload` (`Type=notify-reload`). The §14 block runs and reports correctly line by line (on a workstation, so the server checks report `FAIL` as expected). The sleep-target names, logind keys, journald and watchdog options are the systemd 257 names. The fail2ban journal backend requirement follows from Debian 12+ shipping without rsyslog.

**Not run end-to-end for this guide**: the whole procedure on one real laptop or Pi, the §14 block on a converted box, and the vendor BIOS setting names in §10, which vary by model and firmware version. Treat §10–§12 as a checklist of what to look for, not exact menu paths.

---

## Related guides in this repo

- [SSH client setup](debian-ssh-client-setup.md) — keys, `~/.ssh/config`, and turning off password login
- [Server on WiFi](debian-wifi-uplink-guide.md) — power save in full, and what breaks without a wired uplink
- [Wi-Fi won't come up](debian-wifi-rfkill-bringup.md) — rfkill and `nmcli` bring-up
- [Docker setup](debian-docker-setup-guide.md) — the usual next step on a home server
- [tmux + MOTD](debian-tmux-motd-setup-guide.md) — a login banner that shows server status
- [MX 25 first 30 minutes](mx25-first-10-minutes.md) — base install cleanup before any of this

[Back to the repository index](README.md)
