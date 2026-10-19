# 📶 Debian Wi-Fi Won't Come Up: rfkill Blocks and NetworkManager

> **Purpose**: get a Wi-Fi interface from `unavailable` to connected.
> **Scope**: tested on Debian 11 (Bullseye), KDE Plasma 5, NetworkManager, systemd, Dell laptop with Intel Wireless 7260 (`iwlwifi`). The commands are expected to carry over to Debian 13 / MX 25 / Plasma 6 but have **not** been re-tested there.
> **Root cause in one line**: the radio was rfkill-blocked. On Dell laptops a *soft* block on `dell-wifi` can surface as a *hard* block on `phy0`.

Tags: **[V]** verified on the test host or from a cited source · **[U]** unverified. See [Verified vs. not](#9-verified-vs-not).

---

## 1. Interface name

The test host used legacy names (`wlan0`). Debian 12 and later use predictable names (`wlp2s0`). Find yours and set it once per shell, as in [debian-wifi-uplink-guide.md §1](debian-wifi-uplink-guide.md#1-interface-names-used-in-this-guide):

```bash
nmcli dev status            # the row with TYPE wifi
WIFI_IF=wlp2s0              # change me
```

## 2. Symptoms

```text
$ networkctl status wlan0
WARNING: systemd-networkd is not running, output will be incomplete.
State: n/a (unmanaged)

$ nmcli dev status
wlan0   wifi   unavailable   --
```

`networkctl` is the wrong tool on a NetworkManager system: "unmanaged" there only means `systemd-networkd` is not running **[V]**. Use `nmcli`.

## 3. Diagnose

```bash
systemctl status NetworkManager
nmcli dev status
rfkill list
sudo dmesg | grep -i iwlwifi
```

Failing state on the test host:

```text
1: dell-wifi: Wireless LAN
        Soft blocked: yes
        Hard blocked: no
3: phy0: Wireless LAN
        Soft blocked: yes
        Hard blocked: yes
```

## 4. Fix: unblock

```bash
sudo rfkill unblock wifi    # or: unblock all (also unblocks Bluetooth)
nmcli radio wifi on
rfkill list                 # expect: no / no on every Wireless LAN entry
nmcli dev status            # expect: your Wi-Fi interface "disconnected"
```

**[V]** On the test host `sudo rfkill unblock all` also cleared the `phy0` hard block, because the block came from `dell-wifi`. This dual-switch desync is a known `dell_laptop` behaviour (kernel bug 14098, Launchpad 523143).

If `phy0` is still `Hard blocked: yes`, software can't clear it:

- Physical wireless slider (side or front edge on many Latitudes) **[U]**
- Fn wireless key, often Fn+F2 or Fn+PrtScr; the combination varies by model **[U]**
- BIOS → Wireless → enable WLAN in both the switch and device settings; also check any "disable WLAN when LAN connected" option **[U]**

## 5. Connect

```bash
nmcli dev wifi list
nmcli --ask dev wifi connect "<ssid>"
```

A connection made this way from a terminal is system-wide with the password stored in the profile, so it comes up before login.

A connection made from the KDE tray is owned by your user and keeps the password in KWallet, so it doesn't connect until you log in. To make it system-wide (headless or Docker hosts), set the password in the same command. Changing the flags alone leaves the profile with no password:

```bash
sudo nmcli con mod "<ssid>" connection.permissions '' \
     wifi-sec.psk-flags 0 wifi-sec.psk '<password>'
```

## 6. Tray icon (KDE)

```bash
sudo apt install --yes plasma-nm
```

Then right-click the tray `^` → **Configure System Tray** → **Entries** → **Networks** → *Always shown* **[U]**. If there is no tray, right-click the panel → **Add Widgets** → **System Tray**.

To restart the shell: `plasmashell --replace & disown` on Plasma 5; `systemctl --user restart plasma-plasmashell` on Plasma 6 **[U]**.

On Xfce (MX Linux), the tray icon is the NetworkManager applet (`nm-applet`) instead.

## 7. Firmware (only if no networks are listed)

If `sudo dmesg | grep -i iwlwifi` shows a firmware load failure, enable `non-free` (Bullseye) or `non-free-firmware` (Bookworm and later) and install it:

```bash
sudo apt update && sudo apt install --yes firmware-iwlwifi
sudo modprobe -r iwlmvm iwlwifi && sudo modprobe iwlwifi
```

`iwlmvm` has to come out first; removing `iwlwifi` alone fails with "in use by: iwlmvm".

## 8. Does it stay unblocked?

**[V]** `systemd-rfkill.service` restores rfkill state at early boot and saves it on every change (`/var/lib/systemd/rfkill/`). Once unblocked, it stays unblocked unless the slider, Fn key or airplane mode toggles it again. This needs systemd: on an MX install booted with sysVinit, check the state after a reboot rather than assuming it.

After a reboot:

```bash
rfkill list
grep WirelessEnabled /var/lib/NetworkManager/NetworkManager.state   # expect true [U]
```

## 9. Verified vs. not

| Claim | Status |
| :--- | :--- |
| `networkctl` "unmanaged" is meaningless when `systemd-networkd` isn't running | **[V]** on the test host |
| A `dell-wifi` soft block caused a `phy0` hard block; `rfkill unblock all` cleared both | **[V]** on the test host; known `dell_laptop` bug |
| `systemd-rfkill` restores and saves rfkill state | **[V]** `systemd-rfkill.service(8)` |
| NetworkManager keeps radio state in `NetworkManager.state` (`WirelessEnabled=`) | **[U]** |
| Dell Fn combination and BIOS menu names | **[U]** model-dependent |
| BIOS disables Wi-Fi while Ethernet is connected | **[U]** reported on a Latitude (Arch forum thread 186625) |
| The whole procedure on Debian 13 / MX 25 / Plasma 6 | **Not tested** |

## 10. Next

- Laggy inbound connections or drops: disable power save. See [debian-wifi-uplink-guide.md §5](debian-wifi-uplink-guide.md#5-required-fix-disable-wifi-power-save).
- Running VMs or macvlan containers over this link: read the rest of [debian-wifi-uplink-guide.md](debian-wifi-uplink-guide.md).

## References

- `systemd-rfkill.service(8)`: https://www.mankier.com/8/systemd-rfkill.service
- Dell `dell_laptop` rfkill state bug: https://bugzilla.kernel.org/show_bug.cgi?id=14098
- Dell `dell-wifi` / `phy0` desync: https://bugs.launchpad.net/bugs/523143
- Hard block means switch, key or BIOS: https://claudiokuenzler.com/blog/1338/how-to-solve-wifi-unavailable-linux-mint-dell-latitude-notebook
- BIOS LAN/WLAN switching on a Latitude: https://bbs.archlinux.org/viewtopic.php?id=186625

---

## Related guides in this repo

- [Running a Debian Server on WiFi](debian-wifi-uplink-guide.md) — what to do once Wi-Fi is up
- [MX 25 First 30 Minutes](mx25-first-10-minutes.md) — post-install checklist; links here
- [Docker Setup](debian-docker-setup-guide.md) — Docker on the same host

[Back to the repository index](README.md)
