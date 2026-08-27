# 🖨️ CUPS: USB Printer "Works Once, Then Disappears" — Serial-Pinned Device URI

> **Purpose**: fix a CUPS queue that prints fine when you create it, then reports the printer as missing after a reboot, power-cycle, or cable replug — forcing you to delete and re-add the printer every time.
> **Audience**: Debian / MX Linux users with a USB printer whose device URI contains `?serial=`.
> **Root cause in one line**: the queue is pinned to a USB serial number that the printer does not always report.

---

> **In a hurry?** [`cups-usb-printer-fix.sh`](cups-usb-printer-fix.sh) in this repo does everything
> below automatically:
> ```bash
> ./cups-usb-printer-fix.sh          # diagnose, show the fix, prompt before applying
> ./cups-usb-printer-fix.sh --fix    # repair without prompting
> ```
> Read on if you want to understand or do it by hand.

---

## ✅ Quick Index
- [1. Symptom](#1-symptom)
- [2. Why it happens](#2-why-it-happens)
- [3. Confirm this is your problem](#3-confirm-this-is-your-problem)
- [4. The fix](#4-the-fix)
- [5. Verify it](#5-verify-it)
- [6. Setting this up on another computer](#6-setting-this-up-on-another-computer)
- [7. Alternative: share one machine's printer](#7-alternative-share-one-machines-printer)
- [8. Generalizing to other printers](#8-generalizing-to-other-printers)
- [9. Gotchas](#9-gotchas)
- [10. What was not the cause](#10-what-was-not-the-cause)

---

## 1. Symptom

- You add a USB printer. It prints.
- After a reboot (or power-cycle, or unplug/replug) the queue is still listed, but jobs never print — or the printer shows as unavailable.
- Deleting the queue and re-adding the identical printer fixes it, until the next reboot.

The giveaway is that **re-adding works**. Nothing about the hardware or driver changed; only the stored device address did.

---

## 2. Why it happens

When you add a printer, CUPS stores a **device URI** — the address of the physical device. Both common USB backends put the printer's USB serial number in that URI:

```text
usb://HP/LaserJet%20Professional%20P1102w?serial=000000000Q91PC40SI1c
hp:/usb/HP_LaserJet_Professional_P1102w?serial=000000000Q91PC40SI1c
```

That is fine if the serial is stable. Some printers report a **different serial string across re-enumerations** — commonly a fixed prefix with a varying tail. When the reported serial no longer matches the one baked into the queue, CUPS is looking for a device that does not exist, and reports the printer as missing.

Re-adding the printer captures whatever serial is current, which is why it appears to fix things.

Two details worth knowing:

- The serial comes from the **USB string descriptor**. It is not necessarily present in the printer's IEEE-1284 device ID at all — on the HP P1102w tested here, the 1284 ID has no `SN:` field whatsoever.
- The serial can track the **printer's power state** rather than the USB connection. On the test unit, a full USB unplug/replug preserved the serial (the printer never lost power), while a power-cycle did not.

---

## 3. Confirm this is your problem

Two commands. First, what the queue is pinned to:

```bash
lpstat -v
```

```text
device for HPLJ: hp:/usb/HP_LaserJet_Professional_P1102w?serial=000000000Q91PC40SI1c
```

**If there is no `?serial=` in your URI, this guide is not your problem** — stop here and use [`linux-troubleshooting-guide.md`](linux-troubleshooting-guide.md).

Second, what the printer reports right now:

```bash
lpinfo -v | grep -i usb
```

```text
direct usb://HP/LaserJet%20Professional%20P1102w?serial=000000000Q91PC40PR1a
```

Different serials in those two outputs (`SI1c` vs `PR1a`) confirms the diagnosis. You can also read the kernel's view directly, without touching CUPS:

```bash
for d in /sys/bus/usb/devices/*/; do
  [ -f "$d/idVendor" ] && grep -qi 'PRINTER' "$d"/*/ieee1284_id 2>/dev/null && \
    echo "$(cat $d/manufacturer) $(cat $d/product) serial=$(cat $d/serial)"
done
```

---

## 4. The fix

Drop the serial from the URI. The CUPS `usb` backend matches a serial-less URI against **any** device of that make and model, so whatever serial the printer invents will match.

```bash
lpadmin -p QUEUENAME -v 'usb://VENDOR/MODEL'
```

For the tested printer:

```bash
lpadmin -p HPLJ -v 'usb://HP/LaserJet%20Professional%20P1102w'
```

Build your own URI by taking the `usb://` line from `lpinfo -v` and **deleting everything from `?` onward**. Keep the URL-encoding exactly as `lpinfo` printed it — spaces are `%20`.

Notes:

- You need to be in the `lpadmin` group (`id | grep lpadmin`). No `sudo` required if you are.
- The driver/PPD is untouched. You are changing only the transport.
- If your queue used the `hp:` backend, switching to `usb://` is safe **when your driver does not need bidirectional communication**. A foomatic/foo2zjs or other raw-raster driver only needs a byte pipe. If you use HPLIP's own `hpcups` driver with ink-level reporting, prefer keeping `hp:` and see [§8](#8-generalizing-to-other-printers).

---

## 5. Verify it

Do not trust "the queue looks fine." Print across an actual re-enumeration:

```bash
lp -d QUEUENAME /usr/share/cups/data/testprint
sleep 10
lpstat -W not-completed -o QUEUENAME   # blank means nothing is stuck
lpstat -W completed -o QUEUENAME | head -3
```

Then repeat that after each of: a printer power-cycle, a machine reboot, and a USB unplug/replug. On the test unit all three passed on one queue, across two different reported serials.

---

## 6. Setting this up on another computer

The fix is a property of how you *create* the queue, so on a new machine simply create it right the first time.

### 6.1 Install the driver

```bash
sudo apt update
sudo apt install cups printer-driver-all
sudo usermod -aG lpadmin "$USER"     # log out/in for this to take effect
```

### 6.2 Find the model string CUPS knows

Plug in and power on the printer, then:

```bash
lpinfo -v | grep -i usb          # the device URI
lpinfo -m | grep -i 'MODEL'      # the driver, e.g. grep -i p1102
```

### 6.3 Create the queue with a serial-less URI

```bash
lpadmin -p QUEUENAME \
        -v 'usb://VENDOR/MODEL' \
        -m 'DRIVER-FROM-lpinfo-m' \
        -E
```

Worked example for the tested printer:

```bash
lpadmin -p HPLJ \
        -v 'usb://HP/LaserJet%20Professional%20P1102w' \
        -m 'foo2zjs:0/ppd/foo2zjs/HP-LaserJet_Pro_P1102w.ppd' \
        -E
```

`-E` enables the queue and makes it accept jobs. Set it as default with `lpoptions -d QUEUENAME`.

### 6.4 Or copy the queue from a working machine

The queue definition lives in `/etc/cups/printers.conf` and its PPD in `/etc/cups/ppd/QUEUENAME.ppd`. Copying both to an identically-driver'd machine works, but **check the `DeviceURI` line after copying** — that is the whole point of this guide.

```bash
sudo systemctl stop cups
sudo grep -A5 '<Printer QUEUENAME>' /etc/cups/printers.conf   # confirm DeviceURI
sudo systemctl start cups
```

Creating the queue fresh with §6.3 is less fragile than copying.

---

## 7. Alternative: share one machine's printer

If the goal is *other computers can print*, rather than *move the cable*, share it instead of repeating the setup:

```bash
sudo cupsctl --share-printers --remote-any
sudo lpadmin -p QUEUENAME -o printer-is-shared=true
sudo systemctl restart cups
```

Other Linux/macOS clients then find it over mDNS with no driver install, because CUPS advertises it as a driverless IPP queue. Clients that do not auto-discover can use `ipp://SERVER-IP:631/printers/QUEUENAME`.

This sidesteps the USB serial problem entirely for every machine except the one holding the cable.

---

## 8. Generalizing to other printers

The mechanism is not HP-specific — any printer with an unstable USB serial hits it, and the fix is the same shape.

| Situation | What to do |
| :--- | :--- |
| Any vendor, raw/raster driver | Serial-less `usb://VENDOR/MODEL` as above |
| Two identical printers on one machine | **Do not** use this fix — the serial is the only thing telling them apart. Keep the serials and accept the re-add, or move one to the network |
| HPLIP `hpcups` driver, want ink levels | Keep `hp:`, and re-point the queue after a serial change: `lpadmin -p Q -v "$(lpinfo -v \| awk '/^direct hp:/{print $2}')"` |
| Printer has Ethernet or Wi-Fi | Use `socket://IP:9100` or `ipp://IP/ipp/print` — no USB matching at all, and the most durable option |
| Printer supports IPP-over-USB | `sudo apt install ipp-usb` gives a driverless queue that ignores serials **(untested here — the tested P1102w advertises `URF` and `PCLm`, which suggests it would work, but this guide did not verify it)** |

> [!IMPORTANT]
> `lpadmin -m <ppd>` now prints *"Printer drivers are deprecated and will stop working in a
> future version of CUPS."* PPD-based queues still work on CUPS 2.4, but CUPS 3.x drops them.
> When that lands, the durable options are the driverless ones — `ipp-usb` for USB, or
> `ipp://` / `socket://` over the network. Re-prove any queue after a CUPS major upgrade with
> `./cups-usb-printer-fix.sh --test QUEUENAME`.

---

## 9. Gotchas

**Re-adding through a GUI undoes the fix.** The GNOME/KDE printer tools and the CUPS web UI at `http://localhost:631` all populate the URI from discovery, which means they bake the current serial back in. After using a GUI, re-check `lpstat -v` and re-apply §4 if a `?serial=` reappeared.

**`lpinfo -v` resets HP USB devices.** On HP hardware, probing via the `hp`/hpmud backend resets the device, which re-enumerates it. You will see the kernel's `devnum` jump every time you run `lpinfo -v`, and udev re-runs `hp-config_usb_printer` (from `/lib/udev/rules.d/56-hpmud.rules`) on the resulting `add` event. **This is caused by your probe, not by a fault.** To tell genuine USB instability apart from probe-induced churn, poll passively and touch nothing:

```bash
# 60s passive watch — no CUPS or HPLIP calls
prev=""; for i in $(seq 1 30); do
  for d in /sys/bus/usb/devices/*/; do
    [ -f "$d/idVendor" ] && [ "$(cat $d/idVendor)" = "YOUR_VID" ] && \
      cur="devnum=$(cat $d/devnum) serial=$(cat $d/serial)"
  done
  [ "$cur" != "$prev" ] && { echo "[$(date +%H:%M:%S)] $cur"; prev="$cur"; }
  sleep 2
done
```

A stable device produces exactly one line. Anything more is real churn worth chasing.

**Don't chase the USB bus path.** `/dev/usb/lp0`, bus numbers and `devnum` all shift around and none of them matter — CUPS matches on the URI, not on a device path. A persistent `udev` symlink does not help here.

---

## 10. What was not the cause

Ruled out during the original diagnosis, so you can skip them:

| Suspected | Verdict |
| :--- | :--- |
| Firmware re-upload needed each power-cycle | No. Real for some host-based HP LaserJets (1000/1005/1018/1020, P1005–P1008, P1505 — see `/lib/udev/rules.d/85-hplj10xx.rules`), but the P1102 is absent from that list and needs no per-boot firmware |
| Flaky USB cable / hub / power | No. Left alone the device was stable for a 60-second passive poll with zero changes |
| Unstable USB device path | No. The path was constant, and it is not what CUPS matches on |
| Driver or PPD problem | No. The same driver printed before and after, unchanged |

---

## Final state (target)

| Item | Target |
| :--- | :--- |
| Device URI | `usb://VENDOR/MODEL` — **no** `?serial=` |
| Survives printer power-cycle | Yes |
| Survives machine reboot | Yes |
| Survives USB replug | Yes |
| Re-add after reboot | No longer needed |
| Driver / PPD | Unchanged |

---

## Verified vs. not

**Verified on the test host** (MX 25 / Debian 13 Trixie, CUPS 2.4.10, HP LaserJet Professional P1102w over USB, foo2zjs-z2 via foomatic-rip): the §4 fix, across a printer power-cycle, a full machine reboot, and a USB unplug/replug — four test pages on one queue spanning two different reported serials.

**Not verified here**: `ipp-usb`, the Wi-Fi/network path, the printer sharing in §7, and the behaviour of non-HP printers. Those are extrapolations from the same mechanism and are marked as such where they appear.

---

## Related guides in this repo

- [Linux Troubleshooting Instructions](linux-troubleshooting-guide.md) — the general diagnose-before-prescribing method this followed
- [MX 25 First 10 Minutes](mx25-first-10-minutes.md) — baseline desktop setup
- [Chrome Freezing Fix on AMD](chrome-gpu-amd-freeze.md) — another "known-good config, wrong stored setting" fix

[Back to the repository index](README.md)
