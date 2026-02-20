# CrowdStrike Falcon Sensor (Linux) — Start-to-Finish HOWTO / Reference
**Package:** `falcon-sensor_7.34.0-18708_amd64.deb`  
**Goal:** Install, configure via `.env`, start, verify, troubleshoot, and cleanly uninstall.  
**Scope:** Debian/Ubuntu-family systems using `systemd`.

---

## 0) Assumptions / Preconditions

### Required inputs (from CrowdStrike Console)
- **CID** (Customer ID) — required.
- **Provisioning token / Install token** — optional; only if Your org configured it as required.
- **Tags** — optional (used for grouping/targeting in the console).

### Files used
- DEB package in the current directory: `./falcon-sensor_7.34.0-18708_amd64.deb`
- Environment file: `/etc/crowdstrike/falcon.env`

### Paths (typical)
- `falconctl`: `/opt/CrowdStrike/falconctl`
- systemd unit: `falcon-sensor.service`

---

## 1) Disclaimer

- This guide assumes You have authorization to install endpoint security software on this host.
- Keep CID/tokens confidential. Do not paste them into tickets or chat logs.
- If Your org has a strict change-control process, follow it.

---

## 2) Create the `.env` file (authoritative configuration source)

### 2.1 Create `/etc/crowdstrike/falcon.env`
- Use strict permissions.
- Put only what You need.

```bash
clear
sudo install --directory --mode 0750 /etc/crowdstrike
sudo install --mode 0640 /dev/null /etc/crowdstrike/falcon.env
sudo chown root:root /etc/crowdstrike/falcon.env

sudo tee /etc/crowdstrike/falcon.env >/dev/null <<'EOF'
# CrowdStrike Falcon Sensor configuration
#
# REQUIRED:
FALCON_CID=REPLACE_ME_WITH_CID

# OPTIONAL (only if Your org requires an install/provisioning token):
# FALCON_PROVISIONING_TOKEN=REPLACE_ME_WITH_TOKEN

# OPTIONAL: Sensor tags (comma-separated). Examples:
# FALCON_TAGS=prod,linux,dtfd-console
EOF
```

### 2.2 Verify file permissions
```bash
clear
sudo ls -l /etc/crowdstrike/falcon.env
sudo stat -c 'mode=%a owner=%U group=%G path=%n' /etc/crowdstrike/falcon.env
```

---

## 3) Install the DEB package

### 3.1 Sanity-check the package file exists
```bash
clear
ls -lh ./falcon-sensor_7.34.0-18708_amd64.deb
dpkg-deb --info ./falcon-sensor_7.34.0-18708_amd64.deb | sed -n '1,80p'
```

### 3.2 Install
```bash
clear
sudo dpkg -i ./falcon-sensor_7.34.0-18708_amd64.deb || true
sudo apt-get update
sudo apt-get install --yes --fix-broken
```

### 3.3 Confirm binaries and unit exist
```bash
clear
command -v dpkg >/dev/null && dpkg -l | grep -i falcon || true
sudo test -x /opt/CrowdStrike/falconctl && echo "falconctl present" || echo "falconctl missing"
sudo systemctl cat falcon-sensor.service || true
```

---

## 4) Apply configuration from `.env` to the sensor

### 4.1 Load `.env` safely and set CID / optional token / tags
This step:
- Reads `/etc/crowdstrike/falcon.env`
- Requires `FALCON_CID`
- Conditionally sets token and tags if present

```bash
clear

# Load env file in a controlled way (no shell injection protection exists for arbitrary env files)
# Therefore: file must be root-owned and not writable by non-root (enforced above).
set -a
. /etc/crowdstrike/falcon.env
set +a

# Validate required values
if [ -z "${FALCON_CID:-}" ] || [ "${FALCON_CID}" = "REPLACE_ME_WITH_CID" ]; then
  echo "ERROR: FALCON_CID is not set in /etc/crowdstrike/falcon.env"
  exit 1
fi

# Set CID
sudo /opt/CrowdStrike/falconctl -s --cid="${FALCON_CID}"

# Optional: provisioning token (some tenants require it)
if [ -n "${FALCON_PROVISIONING_TOKEN:-}" ] && [ "${FALCON_PROVISIONING_TOKEN}" != "REPLACE_ME_WITH_TOKEN" ]; then
  sudo /opt/CrowdStrike/falconctl -s --provisioning-token="${FALCON_PROVISIONING_TOKEN}"
fi

# Optional: tags
if [ -n "${FALCON_TAGS:-}" ]; then
  sudo /opt/CrowdStrike/falconctl -s --tags="${FALCON_TAGS}"
fi
```

### 4.2 Confirm configuration took effect
```bash
clear
sudo /opt/CrowdStrike/falconctl -g --cid
sudo /opt/CrowdStrike/falconctl -g --tags || true
sudo /opt/CrowdStrike/falconctl -g --provisioning-token || true
```

**Expected:** CID prints a value (not “CID is not set”).

---

## 5) Start and enable the service

```bash
clear
sudo systemctl daemon-reload
sudo systemctl enable falcon-sensor.service
sudo systemctl start falcon-sensor.service
sudo systemctl status falcon-sensor.service --no-pager
```

---

## 6) Verification checklist

### 6.1 Systemd status must be active
```bash
clear
sudo systemctl is-active falcon-sensor.service
sudo systemctl is-enabled falcon-sensor.service
```

### 6.2 Process-level check
```bash
clear
ps aux | grep -i '[f]alcon' || true
```

### 6.3 Log check
```bash
clear
sudo journalctl -u falcon-sensor.service --no-pager -n 200
```

### 6.4 Network/registration sanity (best-effort)
Exact endpoints vary by region/tenant; verify in the CrowdStrike console if needed.
```bash
clear
ss -tulpn | grep -i falcon || true
```

---

## 7) Troubleshooting (fast mapping from symptom → fix)

### 7.1 Symptom: `CID is not set. Use falconctl to set the CID`
**Cause:** CID not configured.  
**Fix:** Set CID and restart.

```bash
clear
set -a
. /etc/crowdstrike/falcon.env
set +a
sudo /opt/CrowdStrike/falconctl -s --cid="${FALCON_CID}"
sudo systemctl restart falcon-sensor.service
sudo systemctl status falcon-sensor.service --no-pager
```

### 7.2 Symptom: Service fails immediately after setting CID
**Do this in order (collect evidence):**
```bash
clear
sudo systemctl status falcon-sensor.service --no-pager || true
sudo journalctl -u falcon-sensor.service --no-pager -n 400 || true
sudo /opt/CrowdStrike/falconctl -g --cid || true
sudo /opt/CrowdStrike/falconctl -g --provisioning-token || true
sudo /opt/CrowdStrike/falconctl -g --tags || true
```

Common causes:
- Tenant requires provisioning token but it was not set.
- Wrong CID (copy/paste error).
- Corrupt install / missing deps (rare on modern Debian/Ubuntu; re-run `apt-get --fix-broken`).

### 7.3 Symptom: Console does not show host after service is active
Common causes:
- Egress blocked by firewall/proxy.
- Wrong CID/token.
- Host clock skew (TLS issues).
- Wrong sensor build for distro/kernel (less common on amd64 Debian/Ubuntu).

Collect:
```bash
clear
timedatectl status
sudo journalctl -u falcon-sensor.service --no-pager -n 500
```

---

## 8) Operational tasks (reference)

### 8.1 Restart
```bash
clear
sudo systemctl restart falcon-sensor.service
sudo systemctl status falcon-sensor.service --no-pager
```

### 8.2 Stop
```bash
clear
sudo systemctl stop falcon-sensor.service
sudo systemctl status falcon-sensor.service --no-pager
```

### 8.3 View unit file and overrides
```bash
clear
sudo systemctl cat falcon-sensor.service
sudo systemctl show falcon-sensor.service | sed -n '1,120p'
```

### 8.4 Upgrade (install newer `.deb`)
```bash
clear
# Replace filename with the newer package
sudo dpkg -i ./falcon-sensor_NEWVERSION_amd64.deb || true
sudo apt-get install --yes --fix-broken
sudo systemctl restart falcon-sensor.service
sudo systemctl status falcon-sensor.service --no-pager
```

---

## 9) Uninstall / removal

> Warning: Removing endpoint security agents may require approval in Your environment.

### 9.1 Stop + disable
```bash
clear
sudo systemctl stop falcon-sensor.service || true
sudo systemctl disable falcon-sensor.service || true
```

### 9.2 Remove package
```bash
clear
# Determine exact package name (may vary)
dpkg -l | grep -i falcon || true

# Try common names
sudo apt-get remove --yes falcon-sensor || true
sudo dpkg --remove falcon-sensor || true
```

### 9.3 Purge config (optional)
```bash
clear
sudo rm -f /etc/crowdstrike/falcon.env
sudo rmdir /etc/crowdstrike 2>/dev/null || true
```

---

## 10) Minimal “do it all” runbook (copy/paste)

```bash
clear

# A) Create env
sudo install --directory --mode 0750 /etc/crowdstrike
sudo tee /etc/crowdstrike/falcon.env >/dev/null <<'EOF'
FALCON_CID=REPLACE_ME_WITH_CID
# FALCON_PROVISIONING_TOKEN=REPLACE_ME_WITH_TOKEN
# FALCON_TAGS=prod,linux
EOF
sudo chmod 0640 /etc/crowdstrike/falcon.env
sudo chown root:root /etc/crowdstrike/falcon.env

# B) Install
sudo dpkg -i ./falcon-sensor_7.34.0-18708_amd64.deb || true
sudo apt-get update
sudo apt-get install --yes --fix-broken

# C) Configure from env
set -a
. /etc/crowdstrike/falcon.env
set +a
sudo /opt/CrowdStrike/falconctl -s --cid="${FALCON_CID}"
if [ -n "${FALCON_PROVISIONING_TOKEN:-}" ]; then
  sudo /opt/CrowdStrike/falconctl -s --provisioning-token="${FALCON_PROVISIONING_TOKEN}"
fi
if [ -n "${FALCON_TAGS:-}" ]; then
  sudo /opt/CrowdStrike/falconctl -s --tags="${FALCON_TAGS}"
fi

# D) Start + verify
sudo systemctl enable falcon-sensor.service
sudo systemctl start falcon-sensor.service
sudo systemctl status falcon-sensor.service --no-pager
sudo /opt/CrowdStrike/falconctl -g --cid
sudo journalctl -u falcon-sensor.service --no-pager -n 100
```

---

## 11) Notes on correctness (what matters)
- If `falcon-sensor` fails with `CID is not set`, the fix is always: `falconctl -s --cid=<CID>` then restart.
- `.env` is for Your operational convenience; the sensor stores settings via `falconctl`.
- Treat `/etc/crowdstrike/falcon.env` as sensitive material.

---