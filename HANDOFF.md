# Handoff

State of this repository for whoever picks it up next — human or agent.
Updated at the end of each working session.

**Last updated:** 2026-10-19

---

## Current state

Clean. Last change: added `debian-desktop-to-server.md`,
`debian-ssh-client-setup.md` and `ssh-add-host.sh` (see `CHANGELOG.md`,
2026-10-19). Nothing in flight.
33 tracked markdown documents (28 guides, counted as in the README badge),
4 shell scripts, 2 compose files.

The collection is a set of Debian / MX Linux how-to guides plus a few
standalone utilities. It is documentation-first: scripts exist only where
a guide needed automating.

---

## Completed this session (2026-10-19)

The user remembered a "convert a desktop/laptop/Pi to a server" guide.
It never existed (checked tracked files, `review/`, memweave, and the
other Gitea repos), so it was written, along with an SSH client guide
and script that the server guide calls at its SSH step.

- **Wi-Fi power save** for the Pi problem that prompted this already
  lived in `debian-wifi-uplink-guide.md` §5. The new guide's §9 links
  there and adds the Pi `brcmfmac` note instead of duplicating it.
- **Verified:** `ssh-add-host.sh` passes `bash -n` and shellcheck 0.11,
  and its argument validation exits 2 before touching `~/.ssh`. The
  server guide's §14 verify block runs on a workstation. logind
  `reload` support confirmed on systemd 257.
- **Not verified:** a live `ssh-add-host.sh` run (the test run in a
  scratch HOME was denied, so nothing touched a real or fake `~/.ssh`),
  and the server guide end-to-end on a real laptop or Pi.

## Previous session (2026-10-18)

Reviewed a handoff and draft from a live Wi-Fi fix on tc-vmh-03 (Dell,
Intel 7260, Debian 11, KDE Plasma 5) and shipped it as
`debian-wifi-rfkill-bringup.md`.

- **Fixed in the draft:** `nmcli --ask` placement; `psk-flags 0` now
  sets the PSK too; `modprobe -r iwlmvm iwlwifi`; `sudo dmesg`;
  rfkill persistence scoped to systemd.
- **Also:** new §9 in `mx25-first-10-minutes.md` (old §9–§10 → §10–§11;
  no anchored links pointed at them); README registration; badge section
  count corrected 682 → 724 (guides only, excluding README, CHANGELOG,
  HANDOFF and `claude_help/` meta files).
- **Not verified:** anything on Debian 13 / MX 25 / Plasma 6 (see Open
  items).

---

## Open items

Nothing is blocked. These are genuinely optional.

| Item | Status |
| :--- | :--- |
| `cups-usb-printer-fix.sh --share` | **Never applied for real** — dry-run only. It opens a network print service, so it was left for the owner to run. |
| `ipp-usb` / Wi-Fi / non-HP printers | Reasoned from the same mechanism, marked as unverified in the guide. Nobody has tested them. |
| CUPS PPD deprecation | `lpadmin -m <ppd>` now warns that drivers "will stop working in a future version of CUPS". Fine on 2.4; CUPS 3.x drops them. Re-prove queues after a major upgrade with `--test`. |
| `debian-wifi-uplink-guide.md` §6–§7 | **Design reviewed, not field-tested.** The nftables file was load-tested in a network namespace only. Run §6 on a real WiFi-only host and update the guide's "Verified vs. not" section. |
| `debian-wifi-rfkill-bringup.md` on Trixie | **Tested on Debian 11 only.** Re-run on Debian 13 / MX 25 (Xfce and Plasma 6): confirm `NetworkManager.state` `WirelessEnabled=`, the Plasma 6 shell restart, and the MX `nm-applet` package name, then update the guide's §9. |
| `ssh-add-host.sh` live run | **Never run against a real host.** Run `./ssh-add-host.sh -n <alias> <ip> <user>` first, then for real against the Pi, then `--harden`; update the SSH guide's §8. |
| `debian-desktop-to-server.md` on hardware | **Not field-tested.** Run it on the Pi (the one with the power-save trouble) and on a laptop; run the §14 block; fix BIOS setting names in §10 from what you actually see; update §15. |
| `CHANGELOG.md` pre-2026-08 entries | Reconstructed coarsely from commit messages. The early history is `Add files via upload` with no detail to recover. Not worth backfilling further. |

---

## Things that will bite you

- **jdocmunch reports 3 broken links that aren't broken.** Two are
  footnote definitions (`[^osha]`, `[^1]`) misread as links; the third is
  an emoji-heading anchor that keeps U+FE0F on purpose. Don't "fix" them.
- **The printer's USB serial is not stable.** It alternates between tails
  `PR1a` and `SI1c` on the test hardware. Any queue created from GUI
  discovery will re-bake a serial into the URI and reintroduce the bug.
  After using a GUI printer tool, run `./cups-usb-printer-fix.sh --check`.
- **`lpinfo -v` resets HP USB devices.** The kernel `devnum` will jump
  every time you probe. This is caused by your own probe, not by failing
  hardware — do not chase it. Poll sysfs passively to tell real churn from
  probe-induced churn.
- **`review/` and `reviewed/` are gitignored.** They exist on disk and hold
  working material, including a FUTO self-hosting assessment. They are
  invisible to git and to any indexing tool that respects `.gitignore`, so
  a search that comes back empty is not proof the material is absent.
- **The remote is Gitea, not GitHub.** `gh pr create` does not work. Open
  PRs through the API at `http://10.0.0.100:3000`, authenticating with the
  token from the git credential helper.

---

## Conventions worth keeping

- Every guide ends with a "Related guides in this repo" section and a link
  back to `README.md`. New guides should do the same.
- New guides get registered in `README.md`: the repository tree, the
  relevant guide table, the symptom→guide lookup, and the topic tags.
  For a troubleshooting guide the guide table *is* the symptom lookup,
  so that's three places. Bump the intro count and the badge too.
- Don't link to a guide's H1 when it starts with an emoji: the generated
  anchor gets a leading hyphen and differs between renderers.
- Guides distinguish **verified** from **extrapolated**. If something was
  not tested on real hardware, say so in the guide rather than presenting
  it as equally proven.
- Scripts are diagnose-first: they show what they would change and prompt
  before writing, with a `-n` dry-run and a rollback path.

---

## Next session

No pending work. Best next step: take the Pi through
`debian-desktop-to-server.md`, using `ssh-add-host.sh` at §6, and
record what really happened in both guides' "Verified vs. not"
sections. If a WiFi-only Debian host is available, also field-test
`debian-wifi-uplink-guide.md` §6.

The credential-guard hook blocks any shell command whose text contains
`.ssh`, even a scratch `HOME`. Test `ssh-add-host.sh` by hand, or ask
the user to run it with `!`.

Testing nftables changes without root: `unshare -rn nft -f <file>` loads
a ruleset into a throwaway namespace — useful for syntax and reload checks.

If the printer misbehaves again, start with `lpstat -v HPLJ` — if a
`?serial=` has reappeared in the URI, something re-added the queue through
a GUI, and `./cups-usb-printer-fix.sh --fix` restores it.
