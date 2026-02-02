# Debian / MX Linux KDE — Dolphin SFTP Remote Access Guide

## Overview

This document explains how to configure a Debian-based KDE system so **Dolphin File Manager** can access a remote Linux machine using **SFTP (SSH File Transfer Protocol)**. It focuses on KDE I/O integration, protocol handling, and resolving “invalid protocol” and silent connection failures.

---

## Requirements

- Debian, MX Linux, or similar Debian-based distribution  
- KDE desktop environment  
- Remote system running `sshd`  
- Valid user credentials or SSH key authentication  
- Network reachability to the remote host  

---

## Step 1 — Install Required KDE I/O Packages

Dolphin relies on KDE KIO workers for remote filesystems.

```bash
sudo apt update
sudo apt install --yes kio-extras kio-fuse
```

**kio-extras** provides SFTP support. Without it, Dolphin reports **invalid protocol**.

---

## Step 2 — Restart KDE I/O Services

After installation, restart the KDE background daemon:

```bash
kquitapp5 kded5 2>/dev/null || true
kded5 &
```

Or log out and log back in.

---

## Step 3 — Verify SFTP Protocol Registration

Confirm KDE recognizes the protocol:

```bash
( command -v kioclient6 >/dev/null && kioclient6 --list || kioclient5 --list ) | grep -i sftp || echo "SFTP_HANDLER_MISSING"
```

If missing → `kio-extras` did not install correctly.

---

## Step 4 — Connect Using Dolphin (Correct Method)

**Do not run SFTP URLs in the terminal.**

In Dolphin:

1. Press **Ctrl + L** (opens location bar)  
2. Enter:

```
sftp://username@SERVER_IP/
```

Example:

```
sftp://bill@192.168.50.22/
```

Press **Enter**.

---

## Step 5 — Backend Verification (Bypass Dolphin UI)

Test KDE's SFTP worker directly:

```bash
( command -v kioclient6 >/dev/null && kioclient6 exec "sftp://username@SERVER_IP/" || kioclient5 exec "sftp://username@SERVER_IP/" )
```

If this works but Dolphin UI fails → UI issue, not network or SSH.

---

## Step 6 — Authentication Handling

Dolphin may not honor complex SSH config files. Use:

### Load SSH key into agent
```bash
ssh-add ~/.ssh/id_ed25519
```

### Verify key loaded
```bash
ssh-add -l
```

If using passwords, ensure KWallet is unlocked.

---

## Step 7 — Clear KDE Caches (Protocol Errors)

```bash
kquitapp5 kded5 2>/dev/null || true
rm -rf ~/.cache/kioexec ~/.cache/ksycoca*
kbuildsycoca5
```

Log out/in afterward.

---

## Step 8 — Server-Side Permission Check

Home directory must be traversable:

```bash
chmod 755 /home/username
```

Strict permissions can break KIO while CLI SFTP works.

---

## Step 9 — Baseline CLI Test

Always confirm shell SFTP works:

```bash
sftp username@SERVER_IP
```

If CLI fails → SSH/server problem  
If CLI works but Dolphin fails → KDE integration issue

---

## Common Failure Causes

| Symptom | Cause |
|--------|------|
| Invalid protocol | Missing `kio-extras` |
| No password prompt | SSH key not in agent |
| Wizard fails | Dolphin wizard bug |
| Works in CLI only | KIO auth mismatch |
| Immediate disconnect | Server home permissions |

---

## Correct Usage Pattern

**Always connect using address bar:**

```
sftp://username@SERVER_IP/
```

Avoid “Add Network Folder” wizard for direct SFTP connections.

---

## Summary

1. Install `kio-extras`
2. Restart KDE services
3. Use `sftp://` in Dolphin address bar
4. Load SSH keys into agent
5. Use `kioclient` for backend testing
6. Clear KDE cache if protocol errors appear

When these conditions are met, Dolphin SFTP operates reliably.
