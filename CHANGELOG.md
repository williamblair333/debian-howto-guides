# Changelog

Notable changes to this collection. Newest first.

This file was started on 2026-08-27, well after the repository itself
(first commit 2026-01-25, 43 commits). Entries before that date are
reconstructed from commit history and are deliberately coarse — the early
history is a long run of `Add files via upload` commits with no detail to
recover.

Format follows [Keep a Changelog](https://keepachangelog.com/) loosely:
**Added** / **Changed** / **Fixed** / **Removed**.

---

## 2026-10-19 — sshfs mounts guide and script

### Added
- `sshfs-add-mount.sh` — mounts `ALIAS:PATH` at `~/mnt/NAME` with
  `reconnect`, 15 s keepalives, `BatchMode`, `ControlPath=none` and
  `idmap=user`; several named mounts per host. `--persist` writes a
  systemd user service (`Restart=always`, `SuccessExitStatus=1` because
  sshfs exits 1 on a clean stop); `--boot` adds linger. Also `--ro`,
  `--allow-other` (checks `/etc/fuse.conf`), `-o`, `--force`,
  `--umount`, `--remove` (`rmdir` only, never `rm -r`), `--check`,
  `--status`, `-n`. Login and folder checks go over SFTP, so they work
  with a key restricted to `command="internal-sftp"`.
- `debian-sshfs-mounts.md` — mounting by hand, the options and why, an
  SFTP-only key for unattended mounts, the user service line by line,
  linger, why not fstab, safe unmount, troubleshooting.

### Changed
- `README.md` — registered the guide and script; badge 29 guides ·
  768 sections; tags `sshfs`, `systemd`.
- `debian-ssh-client-setup.md` — related-guides link to the sshfs guide.

## 2026-10-19 — Desktop-to-server and SSH client guides

### Added
- `debian-desktop-to-server.md` — making a desktop, laptop or Pi run
  unattended: hostname/mDNS, fixed address, masked sleep targets and lid
  handling, headless boot, SSH + fail2ban (journal backend),
  unattended-upgrades without auto-reboot, ufw (and the Docker bypass),
  Wi-Fi power save, power-loss recovery, laptop charge cap, Pi power and
  SD wear, persistent journal, hardware watchdog, and a one-block verify.
- `debian-ssh-client-setup.md` — ed25519 key, `Include config.d/*` with
  one file per host, `ssh-copy-id`, BatchMode proof, then password login
  off via an early-sorting `sshd_config.d` drop-in.
- `ssh-add-host.sh` — does the SSH guide for one host per run; `-n`,
  `--check`, `--remove`, `--harden` (asks first, reverts on `sshd -t`
  failure, re-tests on a fresh connection).
- `README.md` — registered all three; guide count 28, badge 755 sections.

### Changed
- `debian-wifi-uplink-guide.md` — related-guides link to the server guide.

---

## 2026-10-18 — Wi-Fi rfkill bring-up guide

### Added
- `debian-wifi-rfkill-bringup.md` — getting a Wi-Fi interface from
  `unavailable` to connected: rfkill soft/hard blocks, the Dell
  `dell-wifi` / `phy0` desync, `nmcli` connect, system-wide secrets, the
  KDE tray icon, firmware, and whether the unblock survives a reboot.
  Tested on Debian 11 only.
- `mx25-first-10-minutes.md` — new §9 "Bring Up Wi-Fi", before the update
  step that needs a network.
- `README.md` — registered the guide in the tree, symptom lookup, tested
  environments and tags.

### Changed
- `mx25-first-10-minutes.md` — Update System is now §10, Essential Tools §11.
- `debian-wifi-uplink-guide.md` — points to the new guide when Wi-Fi isn't
  up at all.
- `README.md` — guide count 25 → 26; badge section count corrected from a
  stale 682 to 724.

### Fixed (relative to the draft the guide was written from)
- `--ask` moved before the `nmcli` object, where nmcli parses it.
- Making a tray-created connection system-wide now sets `wifi-sec.psk`
  along with `psk-flags 0`; changing the flags alone leaves no password.
- Module reload removes `iwlmvm` before `iwlwifi`.
- `dmesg` uses `sudo` throughout (Debian restricts it).
- rfkill persistence is scoped to systemd; MX can boot sysVinit.

---

## 2026-10-06 — Server-on-WiFi guide

### Added
- `debian-wifi-uplink-guide.md` — what stops working when a Debian 13
  server's only uplink is WiFi (bridging, macvlan, WoL, interface-pinned
  config), the power-save fix, and a routed `br0` + nftables NAT workaround,
  with a parprouted alternative and a rollback.
- `README.md` — registered the guide in the tree, setup table, symptom
  lookup and tags.

### Fixed (relative to the draft the guide was written from)
- NAT rules live in their own file and unit; restarting `nftables` with
  Debian's `flush ruleset` config would have wiped Docker and libvirt rules.
- Port-forward DNAT limited to `fib daddr type local`, so containers'
  outbound mail is no longer hijacked; forwarded inbound connections are
  now accepted (`ct status dnat`).
- Docker's FORWARD DROP handled with `"ip-forward-no-drop": true`.
- Rollback no longer turns off `ip_forward` (breaks Docker/libvirt), and the
  backup now saves the NetworkManager profiles themselves, not just names.
- Warned against cabling the LAN port to the upstream network (rogue DHCP);
  dnsmasq is DHCP-only (`port=0`) with `bind-dynamic`.
- Predictable interface names instead of `eth0`/`wlan0`; `iwlmvm
  power_scheme=1` replaces the no-op `iwlwifi power_save=0`; parprouted gets
  its missing `ip_forward`, `/32` address and `dhcp-helper` config.

---

## 2026-10-05 — Python guide moves to uv

### Changed
- `debian-python3-setup-guide.md` — rewritten around uv as the default tool:
  projects (`uv init` / `uv add` / `uv run`), CLI tools (`uv tool`, `uvx`),
  other Python versions (`uv python install`), and plain venvs (`uv venv`).
  Poetry moves to an appendix for existing projects, with a Poetry → uv
  migration note. Every command was run on uv 0.10.9 / Poetry 2.3.1.
- `README.md` — updated the guide's description and section count.

### Fixed
- `debian-python3-setup-guide.md` — `poetry shell` no longer exists
  (removed in Poetry 2.0); replaced with `eval "$(poetry env activate)"`.
  Trixie's Python is 3.13, not "3.11+". Dropped the unneeded
  `python3-wheel` / `python3-setuptools` / `python3-pip` installs.

---

## 2026-08-27 — CUPS USB printer serial fix

### Added
- `cups-printer-usb-serial-fix.md` — full write-up of a USB printer that
  prints once, then has to be deleted and re-added after every reboot.
  Covers diagnosis, the one-line fix, new-machine setup, network sharing,
  generalization to other vendors, and the dead ends that were ruled out.
- `cups-usb-printer-fix.sh` — automation for the above.
  Modes: `--check` (cron-safe, writes nothing), `--fix`, `--create`,
  `--test`, `--share`, plus `-n` dry-run and `-p` single-queue.
  Diagnoses first and prompts before writing; logs every change with the
  previous URI to `~/.cache/cups-usb-printer-fix.log` for rollback.

### Changed
- `README.md` — registered both files in the repository tree, the
  symptom→guide table, the Scripts section, and the topic tags.

### Notes
- Root cause: both CUPS backends bake `?serial=` into the device URI at
  discovery time. Some printers report a different USB serial across
  re-enumerations, so the queue resolves to a device that no longer exists.
  Diagnosed on an HP LaserJet Professional P1102w alternating between
  serial tails `PR1a` and `SI1c`.
- Verified on one queue across a printer power-cycle, a machine reboot and
  a USB unplug/replug, spanning two different reported serials.
- CUPS now warns that PPD-based drivers are deprecated and will stop
  working in a future major version. The driverless migration path
  (`ipp-usb`, `ipp://`, `socket://`) is recorded in the guide.

---

## 2026-08-25 — Repository structure

### Added
- Root `README.md` — repository index, guide tables, symptom→guide
  lookup, conventions, tested environments, and topic tags.
- Root `LICENSE`.

### Changed
- Cross-linked every guide with a "Related guides in this repo" footer
  and a "Back to the repository index" link.

### Fixed
- Dead in-page anchors across the collection.

### Removed
- `review/` and `reviewed/` from version control (now gitignored); they
  hold working material that is not part of the published collection.

---

## 2026-06-20 — Backlight

### Added
- `brightness_set_max.sh` — sets backlight to maximum, enforced by a
  systemd unit.

---

## 2026-05-04 — Consolidation

### Changed
- Merged the `claude_help`, `codex`, and `open-webui` collections into
  this repository as subdirectories, each keeping its own README and
  license where they differed.

### Fixed
- Replaced example tokens with placeholders to clear a secret-scanning
  alert. No live credential was ever committed, but the sample values
  were close enough in shape to trip detection.

---

## 2026-01-25 → 2026-05-01 — Initial collection

### Added
The bulk of the guides, uploaded incrementally: MX 25 first-run setup,
Docker, NVIDIA, Python 3 / PEP 668, Remmina, tmux + MOTD, virt-manager,
XRDP, CrowdStrike Falcon, the KDE Plasma 6 migration record, Dolphin
under XFCE, the Chrome/AMD freeze fix, the keyring auto-unlock fix, the
`virsh` reference, and the Linux troubleshooting system prompt.

### Fixed
- Typo in the `network-manager-gnome` package name.
