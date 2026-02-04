# 🚀 Chrome Freezing Fix — MX Linux 23 + AMD (Polaris / RX 550)

> **Purpose**: eliminate Chrome UI freezes caused by the Linux AMD graphics path (ANGLE → Mesa → Polaris).  
> **Audience**: MX Linux 23 desktop users (Debian 12 base) running Chrome on AMD GPUs who see frequent Chrome hangs/freezes.

---

## ✅ Quick Index
- [1. Primary fix: bypass ANGLE](#1-primary-fix-bypass-angle)
- [2. Optional: disable WebGL](#2-optional-disable-webgl)
- [3. Chrome background + preload](#3-chrome-background--preload)
- [4. Tab discarding](#4-tab-discarding)
- [5. Xfce compositor (only if Xfce)](#5-xfce-compositor-only-if-xfce)
- [6. Linux swappiness = 10](#6-linux-swappiness--10)
- [7. Ensure swap exists](#7-ensure-swap-exists)
- [8. Verify GPU renderer](#8-verify-gpu-renderer)
- [9. Validate in chrome://gpu](#9-validate-in-chromegpu)

---

## 1. Primary fix: bypass ANGLE

### 1.1 Test (do this first)
```bash
google-chrome --use-gl=desktop --disable-gpu-driver-bug-workarounds
```

If stability improves, persist it:

### 1.2 Make permanent (system-wide desktop launcher)
```bash
sudo sed -i 's|Exec=.*|Exec=google-chrome --use-gl=desktop --disable-gpu-driver-bug-workarounds %U|' /usr/share/applications/google-chrome.desktop
```

---

## 2. Optional: disable WebGL

Use this if some sites still trigger freezes or the GPU path still misbehaves.

```bash
sudo sed -i 's|Exec=.*|Exec=google-chrome --use-gl=desktop --disable-gpu-driver-bug-workarounds --disable-webgl %U|' /usr/share/applications/google-chrome.desktop
```

---

## 3. Chrome background + preload

### 3.1 Turn OFF preload
Open:
```text
chrome://settings/performance
```
Turn OFF:
- **Preload pages**

### 3.2 Stop background apps
Open:
```text
chrome://settings/system
```
Turn OFF:
- **Continue running background apps when Google Chrome is closed**

---

## 4. Tab discarding

Open:
```text
chrome://discards
```
Use “Discard” on high-impact tabs.

---

## 5. Xfce compositor (only if Xfce)

If You are on Xfce:  
Settings → **Window Manager Tweaks** → **Compositor**  
Disable: **Enable display compositing**  
Log out/in.

---

## 6. Linux swappiness = 10

```bash
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf
sudo sysctl -p /etc/sysctl.d/99-swappiness.conf
```

Verify:
```bash
sysctl vm.swappiness
```

---

## 7. Ensure swap exists

Check:
```bash
free -h
```

If swap is 0 or very small, add 4G:

```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

Verify:
```bash
swapon --show
```

---

## 8. Verify GPU renderer (must not be llvmpipe)

```bash
glxinfo | grep -i "OpenGL renderer"
```

Bad:
- `llvmpipe`

Good:
- `AMD Radeon RX 550 ...` (or similar)

---

## 9. Validate in chrome://gpu

Open:
```text
chrome://gpu
```

Check:
- GPU crash count is not rising
- No ANGLE renderer string (or overall stability improved)
- No repeated context-loss behavior under normal use

---

## Expected harmless log noise

If You launch from terminal, these are typically non-fatal:
- `DEPRECATED_ENDPOINT` (push/messaging endpoint changes)
- EGL context warnings when Chrome probes backends
- WebGL fallback warnings (especially if WebGL disabled)

---

## Final state (target)

| Item | Target |
|------|--------|
| Rendering | `--use-gl=desktop` |
| ANGLE instability | bypassed |
| WebGL | optional disable |
| Swapping stalls | reduced via swappiness=10 |
| System safety | swap present |

