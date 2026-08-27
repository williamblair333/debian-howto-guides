# Handoff

State of this repository for whoever picks it up next — human or agent.
Updated at the end of each working session.

**Last updated:** 2026-08-27

---

## Current state

Clean. `main` is at `a3f48de`, working tree empty, nothing in flight.
43 commits, 27 tracked markdown documents, 3 shell scripts, 2 compose files.

The collection is a set of Debian / MX Linux how-to guides plus a few
standalone utilities. It is documentation-first: scripts exist only where
a guide needed automating.

---

## Completed this session (2026-08-27)

Diagnosed and fixed a USB printer that printed once, then had to be
deleted and re-added after every reboot.

- **Root cause:** the CUPS queue was pinned to a USB serial number that the
  printer does not consistently report. Both backends bake `?serial=` into
  the device URI at discovery time.
- **Fix:** drop the serial so the `usb` backend matches on make/model:
  `lpadmin -p HPLJ -v 'usb://HP/LaserJet%20Professional%20P1102w'`
- **Shipped:** `cups-printer-usb-serial-fix.md` (the guide) and
  `cups-usb-printer-fix.sh` (the automation), merged as PR #3.

Verified across a printer power-cycle, a machine reboot, and a USB
unplug/replug — one queue, two different reported serials, four test
pages.

---

## Open items

Nothing is blocked. These are genuinely optional.

| Item | Status |
| :--- | :--- |
| `cups-usb-printer-fix.sh --share` | **Never applied for real** — dry-run only. It opens a network print service, so it was left for the owner to run. |
| `ipp-usb` / Wi-Fi / non-HP printers | Reasoned from the same mechanism, marked as unverified in the guide. Nobody has tested them. |
| CUPS PPD deprecation | `lpadmin -m <ppd>` now warns that drivers "will stop working in a future version of CUPS". Fine on 2.4; CUPS 3.x drops them. Re-prove queues after a major upgrade with `--test`. |
| `CHANGELOG.md` pre-2026-08 entries | Reconstructed coarsely from commit messages. The early history is `Add files via upload` with no detail to recover. Not worth backfilling further. |

---

## Things that will bite you

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
- New guides get registered in `README.md` in four places: the repository
  tree, the relevant guide table, the symptom→guide lookup, and the topic
  tags.
- Guides distinguish **verified** from **extrapolated**. If something was
  not tested on real hardware, say so in the guide rather than presenting
  it as equally proven.
- Scripts are diagnose-first: they show what they would change and prompt
  before writing, with a `-n` dry-run and a rollback path.

---

## Next session

No pending work. Pick up whatever is in front of you.

If the printer misbehaves again, start with `lpstat -v HPLJ` — if a
`?serial=` has reappeared in the URI, something re-added the queue through
a GUI, and `./cups-usb-printer-fix.sh --fix` restores it.
