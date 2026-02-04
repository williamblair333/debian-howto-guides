# 🚀 CHROME FREEZE FIX — MX LINUX 23 + AMD GPU  
**Eliminate UI hangs. Stabilize rendering. Zero guesswork.**

---

## 🎯 WHAT THIS DOES
Fixes Google Chrome freezing caused by the **ANGLE → Mesa → AMD Polaris** graphics stack.

**Outcome:**  
Stable browser, no GPU lockups, no compositor deadlocks, smooth video + tabs.

---

## 🧠 WHY CHROME FREEZES HERE

Chrome on Linux uses:

ANGLE layer → Mesa OpenGL → AMD Polaris driver  

This path is unstable on Mesa 22.x and causes:
- GPU context loss  
- UI thread stalls  
- Browser window freeze while system still runs  

We bypass the broken layer.

---

# 🛠 STEP-BY-STEP FIX

---

## 🥇 1. FORCE STABLE RENDERING (CRITICAL FIX)

**Test first**

google-chrome --use-gl=desktop --disable-gpu-driver-bug-workarounds

If Chrome becomes stable → lock it in:

sudo sed -i 's|Exec=.*|Exec=google-chrome --use-gl=desktop --disable-gpu-driver-bug-workarounds %U|' /usr/share/applications/google-chrome.desktop

✔ Uses native Mesa OpenGL  
❌ Bypasses unstable ANGLE layer  

---

## 🥈 2. DISABLE WEBGL (STOPS GPU RESET PATHS)

Some sites trigger crash-prone paths.

sudo sed -i 's|Exec=.*|Exec=google-chrome --use-gl=desktop --disable-gpu-driver-bug-workarounds --disable-webgl %U|' /usr/share/applications/google-chrome.desktop

---

## 🥉 3. STOP CHROME BACKGROUND RESOURCE ABUSE

Address bar:

chrome://settings/performance  
Turn OFF:
• Preload pages

chrome://settings/system  
Turn OFF:
• Continue running background apps

---

## 4. SUSPEND UNUSED TABS

chrome://discards  
Discard heavy tabs manually.

---

## 5. DISABLE DESKTOP COMPOSITOR (XFCE ONLY)

Settings → Window Manager Tweaks → **Compositor tab**  
Uncheck: **Enable display compositing**  
Log out / log in.

Removes Chrome ↔ compositor deadlocks.

---

## 6. REDUCE LINUX SWAPPING (PREVENT UI STALLS)

echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf  
sudo sysctl -p /etc/sysctl.d/99-swappiness.conf

---

## 7. ENSURE SWAP EXISTS (SYSTEM SAFETY)

Check:

free -h

If swap = 0:

sudo fallocate -l 4G /swapfile  
sudo chmod 600 /swapfile  
sudo mkswap /swapfile  
sudo swapon /swapfile  
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

---

## 8. VERIFY GPU IS ACTUALLY USED

glxinfo | grep "OpenGL renderer"

❌ Bad:
llvmpipe

✔ Good:
AMD Radeon RX 550 (or similar)

---

## 9. CONFIRM STABLE GRAPHICS PATH

chrome://gpu

You want:
✔ OpenGL enabled  
✔ No rising GPU crash count  
✔ No “ANGLE” renderer string  

---

# ✅ FINAL SYSTEM STATE

| Layer | Status |
|------|-------|
| Rendering Engine | Native Mesa OpenGL |
| ANGLE Layer | Removed |
| WebGL Crash Path | Disabled |
| Desktop Compositor Conflict | Removed |
| Swap Thrash | Controlled |
| GPU Context Loss | Eliminated |

---

## 🧊 RESULT

Chrome stable under:
• Many tabs  
• Video playback  
• Long sessions  

No freezes. No driver lockups. No UI stalls.

