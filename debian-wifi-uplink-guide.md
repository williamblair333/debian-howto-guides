# 📶 Running a Debian Server on WiFi: Limitations and the Routed-Uplink Workaround

> **Purpose**: know what stops working when a server's only uplink is WiFi, and set up a routed LAN bridge so VMs, containers and services keep working anyway.
> **Audience**: Debian sysadmins with a host whose only working uplink is a WiFi interface.
> **Scope**: Debian 13 (Trixie) with NetworkManager, IPv4 only. Proxmox uses ifupdown2, not NetworkManager, so §6's commands do not apply there; the design does.
> **Root cause in one line**: an access point accepts frames only from the one MAC address that authenticated with it.

Each limitation is tagged **[V]** (verified, source in [References](#13-references)) or **[U]** (unverified, reasoned from the same root cause). The procedure in §6–§8 is reasoned from documented behaviour and has **not** been run end-to-end on real hardware for this guide — see [Verified vs. not](#12-verified-vs-not).

---

## 1. Interface names used in this guide

Debian 13 uses predictable names (`enp3s0`, `wlp2s0`), not `eth0` / `wlan0`. This guide writes:

| Placeholder | Meaning | Find it with |
| :--- | :--- | :--- |
| `<wifi-if>` | The WiFi uplink | `ip -br link \| grep -E '^wl'` |
| `<lan-if>` | The wired port that becomes the LAN side | `ip -br link \| grep -E '^(en\|eth)'` |

Set them once per shell so the blocks below paste cleanly:

```bash
WIFI_IF=wlp2s0     # change me
LAN_IF=enp3s0      # change me
```

---

## 2. Root cause

In 802.11 client (station) mode, the AP accepts frames only from the single MAC address that authenticated with it. Any design that puts additional MAC addresses on the uplink fails. Port, IP and service configuration that names the old wired interface also breaks when the uplink changes.

---

## 3. What does not work over WiFi

### 3.1 Hard limits (independent of configuration)

| Feature | Status | Reason |
| :--- | :--- | :--- |
| Linux bridge with WiFi as a member (libvirt/KVM bridged, Proxmox `vmbr0`, LXC/Incus bridges) | **[V]** | AP rejects guest MACs. 4-address mode (`iw dev <wifi-if> set 4addr on`) works only if the AP allows it — most consumer APs don't, but an AP you control (OpenWrt `wds` option, hostapd `wds_sta=1`) can. |
| macvlan (Docker, LXC, Podman, CNI) | **[V]** | Each subinterface has its own MAC, and the AP drops unauthenticated MACs. |
| Wake-on-LAN | **[V]** | Wired NIC feature. WoWLAN depends on driver support and may offer only some triggers. |
| VRRP/CARP with virtual MAC (`use_vmac`) | **[U]** | Second MAC on the link. |
| 802.1Q VLAN subinterfaces | **[U]** | APs do not pass client-tagged frames. |
| LACP bonding (802.3ad) | **[U]** | Requires switch-port negotiation. |
| IDS/capture on SPAN/mirror port | **[U]** | Port mirroring is a wired switch feature. |
| PTP hardware timestamping | **[U]** | Depends on NIC support; check with `ethtool -T <wifi-if>`. |

### 3.2 Works, but with caveats

| Feature | Status | Notes |
| :--- | :--- | :--- |
| ipvlan | **[V]** | Shares the host MAC, so it works over WiFi. DHCP is awkward because every endpoint has the same MAC (use client-IDs or static IPs). ipvlan endpoints cannot reach the host. |
| Inbound services (SSH, HTTP, SMTP, etc.) | **[V]** | WiFi power save adds wake-up latency to inbound connections. Fix in §5. |
| Email server | — | Not affected by WiFi. Mail delivery failures come from the uplink's IP (port 25 blocking, reverse DNS, dynamic/residential IP), not the link medium. |

### 3.3 Configuration that breaks when the uplink changes

- Services bound to the old wired IP: sshd `ListenAddress`, nginx/apache `listen IP:port`, bind9 `listen-on`, postfix `inet_interfaces`, Samba `interfaces =`.
- Docker ports published to a specific IP. If the IP is absent, the container fails to start with `bind: cannot assign requested address` **[V]**.
- DHCP servers bound to the wired port: isc-dhcp-server `INTERFACESv4`, dnsmasq `interface=`.
- Firewall/NAT rules naming the wired port: iptables `-i/-o`, nftables `iifname/oifname`, ufw `on <if>`.
- keepalived `interface`, routes pinned to `dev <if>`, `/etc/network/interfaces` stanzas.
- External dependencies on the old IP or MAC: DHCP reservations, DNS A/PTR records, remote ACLs, MAC-locked licenses.
- A NetworkManager WiFi profile that isn't system-wide, or whose secret lives in a user keyring: no network until a user logs in. Fix:

  ```bash
  sudo nmcli con mod "<ssid-profile>" connection.permissions '' wifi-sec.psk-flags 0
  ```

---

## 4. Audit

```bash
ip -br link; ip -br addr; ip route
# Every interface name the host has ever had, searched in /etc:
for i in $(ls /sys/class/net); do echo "== $i"; sudo grep -rnwF "$i" /etc 2>/dev/null; done
sudo grep -rnwE 'eth[0-9]+' /etc 2>/dev/null          # legacy names from older configs
sudo ss -tulpn
sudo nft list ruleset | grep -E 'iifname|oifname'
sudo iptables-save 2>/dev/null | grep -E -- '-[io] '
bridge link; ip -d link show type macvlan
docker network ls --filter driver=macvlan
docker ps --format '{{.Names}}\t{{.Ports}}'
virsh net-list --all
nmcli -f NAME,DEVICE,AUTOCONNECT,TYPE con show
iw dev "$WIFI_IF" get power_save
iw list | grep -A10 'WoWLAN support'
```

---

## 5. Required fix: disable WiFi power save

Running `iw ... set power_save off` alone does not persist. The driver default comes back when NetworkManager reconnects, on network change, on resume, and at boot **[V]**.

```bash
sudo tee /etc/NetworkManager/conf.d/99-wifi-powersave-off.conf >/dev/null <<'EOF'
[connection]
wifi.powersave = 2
EOF
sudo systemctl restart NetworkManager
iw dev "$WIFI_IF" get power_save        # expect: Power save: off
```

`2` means *disable*. Intel cards have a second, firmware-level power scheme in the `iwlmvm` driver that operates below NetworkManager (`modinfo -p iwlmvm`: `power_scheme` 1-active, 2-balanced, 3-low power; default 2). To force it to "active" (no firmware power save):

```bash
echo 'options iwlmvm power_scheme=1' | sudo tee /etc/modprobe.d/iwlmvm-power.conf
# takes effect on next module load / boot
```

> [!NOTE]
> The often-quoted `options iwlwifi power_save=0` is a no-op on current kernels — that parameter already defaults to off, and modern Intel cards are driven by `iwlmvm`, which ignores it.

---

## 6. Workaround A (recommended): wired port as LAN, any uplink as WAN

VMs and services sit on a bridge built on the wired port. The host routes and NATs to whichever uplink is live. No AP support is required.

```text
 VMs / services ── br0 (<lan-if>, 192.168.100.1/24)
                     │  ip_forward + nftables NAT
                     ↓
                  <wifi-if> / second NIC / usb0 (whatever is up) ── upstream network
```

> [!WARNING]
> **`<lan-if>` must not be cabled to the upstream network.** It becomes the gateway and (in §6.6) DHCP server for 192.168.100.0/24. Plugged into your existing LAN, it hands out rogue leases to every machine on it. Connect it to a separate switch for physical devices, or leave it unplugged. If you only need VMs, you don't need a physical port at all — a bridge with no ports works, and libvirt's `default` network (`virbr0`) is exactly that.

### 6.1 Backup

```bash
B=~/wifi-uplink-backup.$(date +%Y%m%d)
mkdir -p "$B"
sudo cp -a /etc/NetworkManager/system-connections "$B"/
sudo cp -a /etc/nftables.conf "$B"/ 2>/dev/null
[ -f /etc/docker/daemon.json ] && sudo cp -a /etc/docker/daemon.json "$B"/
nmcli -f NAME,UUID,TYPE,DEVICE con show > "$B"/nm-connections.txt
```

> [!CAUTION]
> Enslaving `<lan-if>` to `br0` removes any IP on it. If you are connected over that port, you lose the session. Do §6.2 from a local console or over the WiFi address.

### 6.2 Bridge

Retire whatever profile currently owns the wired port, so it doesn't fight the bridge for it:

```bash
nmcli -f NAME,DEVICE con show | grep -w "$LAN_IF"
sudo nmcli con mod "<that-profile>" connection.autoconnect no
sudo nmcli con down "<that-profile>"
```

Create the bridge and attach the port:

```bash
sudo nmcli con add type bridge ifname br0 con-name br0 bridge.stp no \
  ipv4.method manual ipv4.addresses 192.168.100.1/24 ipv6.method disabled
sudo nmcli con add type ethernet ifname "$LAN_IF" master br0 con-name br0-port
sudo nmcli con up br0
```

### 6.3 Forwarding

```bash
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/90-forward.conf
sudo sysctl --system
```

### 6.4 NAT and port forwards

Use a **separate file**, not `/etc/nftables.conf`. Debian's stock `/etc/nftables.conf` starts with `flush ruleset`, and restarting the `nftables` service with that file wipes Docker's and libvirt's rules until those services restart.

```bash
sudo mkdir -p /etc/nftables.d
sudo tee /etc/nftables.d/lan-nat.nft >/dev/null <<'EOF'
#!/usr/sbin/nft -f
# Routed LAN on br0 → NAT out of any uplink. Safe to reload: replaces only this table.
destroy table ip lan_nat

table ip lan_nat {
  chain prerouting {
    type nat hook prerouting priority dstnat;
    # Port forwards. "fib daddr type local" = only traffic addressed to this host,
    # so containers' outbound mail to remote servers is not hijacked.
    iifname != "br0" fib daddr type local tcp dport { 25, 587 } dnat to 192.168.100.10
  }
  chain postrouting {
    type nat hook postrouting priority srcnat;
    ip saddr 192.168.100.0/24 oifname != { "br0", "lo" } masquerade
  }
  chain forward {
    type filter hook forward priority filter; policy accept;
    iifname "br0" accept
    oifname "br0" ct state established,related accept
    oifname "br0" ct status dnat accept
    oifname "br0" drop
  }
}
EOF
sudo nft -c -f /etc/nftables.d/lan-nat.nft && sudo nft -f /etc/nftables.d/lan-nat.nft
```

`!= "br0"` matches any uplink, so failover between WiFi, a second NIC or tethering needs no rule changes. The `forward` chain lets the LAN out, lets replies and forwarded ports in, and blocks everything else from reaching it.

Load it at boot with its own unit, independent of the `nftables` service:

```bash
sudo tee /etc/systemd/system/lan-nat.service >/dev/null <<'EOF'
[Unit]
Description=nftables NAT for br0 routed LAN
Wants=network-pre.target
Before=network-pre.target
After=nftables.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/nft -f /etc/nftables.d/lan-nat.nft
ExecStop=/usr/sbin/nft destroy table ip lan_nat

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now lan-nat.service
```

> [!IMPORTANT]
> In nftables a packet must be accepted by **every** base chain on a hook. A `policy drop` forward chain in any other table — yours, ufw's, or Docker's — drops this traffic even though `lan_nat` accepts it. Check with `sudo nft list ruleset | grep -B2 'hook forward'`.

### 6.5 Docker on the same host

Docker sets the iptables `FORWARD` policy to **DROP** when Docker itself turns on IP forwarding **[V]**. That silently kills routing between `br0` and the uplink. Tell Docker not to:

```bash
sudo mkdir -p /etc/docker
# Merge by hand if daemon.json already exists — it must stay one JSON object.
[ -f /etc/docker/daemon.json ] && cat /etc/docker/daemon.json
echo '{ "ip-forward-no-drop": true }' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker
sudo iptables -S FORWARD | head -1     # expect: -P FORWARD ACCEPT
```

If the policy still reads `DROP` (it was set before the change), `sudo iptables -P FORWARD ACCEPT` clears it for this boot. Docker still blocks unpublished container ports with its own rules; this only stops it dropping traffic that isn't Docker's.

### 6.6 Attaching workloads

| Workload | Action |
| :--- | :--- |
| libvirt VMs | Attach the NIC to bridge `br0`. Use a static IP in `192.168.100.0/24` or run DHCP on `br0` (§6.7). Alternative: libvirt's built-in `default` NAT network (`virbr0`) implements the same pattern; inbound forwards still need DNAT. |
| Docker | Publish on `0.0.0.0` (not a specific IP). Docker's own NAT handles egress. |
| Host services | Bind to `0.0.0.0` or `192.168.100.1`. Restrict access by source subnet in nftables, not by interface name. |

### 6.7 Optional DHCP on br0

```bash
sudo apt install --yes dnsmasq
sudo tee /etc/dnsmasq.d/br0.conf >/dev/null <<'EOF'
# DHCP only for br0. port=0 disables dnsmasq's DNS server, so it can't
# collide with libvirt's dnsmasq or systemd-resolved on port 53.
port=0
interface=br0
bind-dynamic
dhcp-range=192.168.100.100,192.168.100.200,12h
dhcp-option=option:router,192.168.100.1
dhcp-option=option:dns-server,1.1.1.1,9.9.9.9
EOF
sudo systemctl restart dnsmasq
```

`bind-dynamic` (not `bind-interfaces`) lets dnsmasq start before `br0` exists at boot and pick it up when it appears. Keep the DHCP range out of any static IPs you assign (e.g. `.10` in §6.4).

### 6.8 Verify

```bash
ip -br addr show br0
sysctl net.ipv4.ip_forward                     # = 1
systemctl is-active lan-nat                    # active
sudo nft list table ip lan_nat
iw dev "$WIFI_IF" get power_save               # off
# From a VM on br0:
ping -c3 192.168.100.1 && ping -c3 1.1.1.1
# From another machine upstream:
nc -vz <uplink-ip> 25
```

If the upstream network is itself behind a router (home WiFi), that router also needs a port forward to `<uplink-ip>` for inbound services to reach you from outside.

---

## 7. Workaround B: proxy-ARP bridge (parprouted)

Use this when VMs or devices must keep their own IPs directly on the WiFi LAN. parprouted is in Debian Trixie **[V]** and bridges Ethernet behind a wireless node without WDS or L2 bridging **[V]**.

```bash
sudo apt install --yes parprouted dhcp-helper
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/90-forward.conf
sudo sysctl --system
# Give the wired port the WiFi address as a /32 so it has an IP to ARP from:
WIFI_IP=$(ip -4 -o addr show "$WIFI_IF" | awk '{print $4}' | cut -d/ -f1)
sudo ip addr add "$WIFI_IP/32" dev "$LAN_IF"
sudo ip link set "$LAN_IF" up
# Relay DHCP from the wired side to the upstream DHCP server:
echo "DHCPHELPER_OPTS=\"-b $WIFI_IF\"" | sudo tee /etc/default/dhcp-helper
sudo systemctl restart dhcp-helper
sudo parprouted "$LAN_IF" "$WIFI_IF"
```

None of that survives a reboot or a DHCP address change on `<wifi-if>` — you'd need a NetworkManager dispatcher script to re-apply the `/32` and restart parprouted. Limitations **[V]**:

- IPv4/ARP only. DHCP is not carried; relay it with `dhcp-helper` (above) or `dhcrelay`.
- The upstream man page states the tool was designed and tested only on Linux 2.4 kernels. It is still packaged but unmaintained upstream.
- Docker's FORWARD DROP (§6.5) applies here too.

Prefer Workaround A for durability.

---

## 8. Rollback (Workaround A)

```bash
B=~/wifi-uplink-backup.<YYYYMMDD>
sudo systemctl disable --now lan-nat.service        # ExecStop removes the table
sudo rm /etc/systemd/system/lan-nat.service /etc/nftables.d/lan-nat.nft
sudo systemctl daemon-reload
sudo nmcli con del br0-port br0
sudo nmcli con mod "<old-wired-profile>" connection.autoconnect yes
sudo nmcli con up "<old-wired-profile>"
sudo rm /etc/sysctl.d/90-forward.conf               # takes effect at next boot
sudo rm -f /etc/dnsmasq.d/br0.conf && sudo systemctl restart dnsmasq
# daemon.json: restore "$B"/daemon.json, or delete the file if there was none
```

> [!WARNING]
> Do **not** run `sysctl -w net.ipv4.ip_forward=0` to undo §6.3. Docker and libvirt NAT both need forwarding; turning it off live breaks every container and VM network on the host. Removing the drop-in is enough.

If the old wired profile is gone, restore it from the backup: `sudo cp -a "$B"/system-connections/<file>.nmconnection /etc/NetworkManager/system-connections/ && sudo nmcli con reload`.

---

## 9. Prevention

- Never bind services or publish container ports to a NIC-specific IP. Bind to `0.0.0.0` or a stable internal address, and filter by source subnet.
- Write firewall/NAT rules against the LAN side (`br0`) or interface sets, not the uplink name.
- Keep guests on a host-internal bridge (Workaround A) so uplink changes never touch guest config.
- Make WiFi profiles system-wide with system-stored secrets on headless hosts (§3.3).
- Disable WiFi power save on any host that accepts inbound connections (§5).
- Never put your own rules in a file that starts with `flush ruleset` on a host running Docker or libvirt.

---

## 10. Logs

```bash
journalctl -u NetworkManager -b
journalctl -u lan-nat -b
journalctl -u dnsmasq -b
journalctl -u docker -b | grep -i forward
journalctl -k -b | grep -iE 'wl|iwlwifi|iwlmvm|br0'
```

---

## 11. Limits of this design

- **IPv4 only.** The bridge has IPv6 disabled and there is no NAT66 or prefix delegation. VMs get no IPv6.
- **Double NAT** if the upstream is a home router: inbound services need forwards on both the router and this host.
- **One uplink at a time.** Failover is whatever NetworkManager's default route does; there is no load balancing.

---

## 12. Verified vs. not

**Verified from sources** (see References): everything tagged **[V]** in §3–§7, Docker's FORWARD-DROP behaviour and the `ip-forward-no-drop` option, and NetworkManager's `wifi.powersave` values.

**Not verified on hardware for this guide**: the §6 procedure end-to-end, the `lan-nat.service` boot ordering, the `iwlmvm power_scheme` effect on a specific card, and all of §7. The §6.4 nftables file was loaded twice in a throwaway network namespace on nftables 1.1.3 — it parses, and reloading it replaces the table instead of duplicating rules. The `iwlmvm` / `iwlwifi` parameter defaults in §5 were read from `modinfo` on a Trixie kernel. Treat the rest as a reviewed design, not a field-tested one.

---

## 13. References

- Bridging over WiFi / 4-addr limits: https://github.com/tomjanowski/bridge
- macvlan vs ipvlan on WiFi: https://github.com/librespot-org/librespot/wiki/librespot%2C-mDNS%2C-networking-and-containers
- macvlan rejected by APs: https://lists.linuxcontainers.org/pipermail/lxc-users/2017-December/013901.html
- ipvlan shared MAC / DHCP / host isolation: https://pkg.go.dev/github.com/rancher/plugins@v0.6.0/plugins/main/ipvlan
- Docker bind to absent IP: https://www.github.com/docker/compose/issues/8106
- Docker FORWARD policy and `ip-forward-no-drop`: https://www.docker.com/blog/docker-engine-28-hardening-container-networking-by-default/
- WoWLAN driver dependency: https://documentation.ubuntu.com/core/explanation/system-snaps/network-manager/how-to-guides/configure-the-snap/wake-on-wlan/
- WiFi power save latency: https://www.ctrl.blog/entry/linux-wifi-dpm-latency
- Power save layers (NM vs iwlwifi): https://slightfuture.com/technote/linux-wifi-dpm-latency/
- parprouted man page: https://dyn.manpages.debian.org/buster/parprouted/parprouted.8
- parprouted package (Trixie): https://packages.debian.org/parprouted

---

## Related guides in this repo

- [Debian Docker Setup](debian-docker-setup-guide.md) — Docker install; see §6.5 here before routing through a Docker host
- [KVM/QEMU with virt-manager](debian-virtman-setup-guide.md) — the VMs you'd attach to `br0`
- [virsh reference](administer/virsh-reference-guide.md) — network and interface commands for libvirt

[Back to the repository index](README.md)
