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
