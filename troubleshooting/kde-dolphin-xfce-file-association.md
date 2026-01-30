# Troubleshooting Guide: Restoring Application Visibility in Dolphin (XFCE)

## Overview
Dolphin (KDE) may fail to show installed applications in **Open With** or forget file associations under XFCE. Cause: KDE components expect `applications.menu`, while XFCE provides `xfce-applications.menu`.

---

## Phase 1 — Fix Menu File Mismatch

Create a compatibility symlink so KDE tools can locate the menu definition.

```bash
sudo ln --symbolic /etc/xdg/menus/xfce-applications.menu /etc/xdg/menus/applications.menu
```

---

## Phase 2 — Rebuild KDE System Configuration Cache

Dolphin uses the **KSycoca** cache to map MIME types to applications. Rebuild it:

```bash
kbuildsycoca6 --noincremental
```

If the above binary does not exist, try:

```bash
kbuildsycoca5 --noincremental
```

---

## Phase 3 — Verify

1. Fully close Dolphin.
2. Reopen Dolphin.
3. Right-click any file → **Open With**.
4. Installed applications should now appear.

---

## Optional — Persist Menu Prefix (Rare Cases)

If the issue returns after reboot:

```bash
echo 'export XDG_MENU_PREFIX=xfce-' >> ~/.profile
```

Log out and back in.

---

## If File Associations Are Still Missing

Check MIME app config consistency:

```bash
ls ~/.config/mimeapps.list
ls ~/.local/share/applications/mimeapps.list
```

If one exists and the other does not:

```bash
ln --symbolic ~/.config/mimeapps.list ~/.local/share/applications/mimeapps.list
```

---

## KDE Integration Packages (If Dolphin Behaves Erratically)

Ensure KDE runtime components are installed.

**Debian/Ubuntu:**
```bash
sudo apt install --yes kio kio-extras kde-cli-tools
```

---

## Summary

| Problem | Cause | Fix |
|--------|------|-----|
| Empty “Open With” | KDE cannot read XFCE menu | Create symlink |
| Apps still missing | KSycoca cache outdated | Rebuild cache |
| Resets after reboot | Menu prefix not set | Export XDG variable |
| MIME associations lost | Config path mismatch | Symlink mimeapps.list |

---
