# Debian / MX Linux KDE — Dolphin SFTP Remote Access & “Invalid protocol” Fix Guide

---

## Overview

This guide provides a complete, structured procedure for enabling **Dolphin File Manager** to access remote systems over **SFTP (SSH File Transfer Protocol)** and resolving the common:

> **“Invalid protocol”**

error — even when SSH/SFTP works from the command line.

Applies to:

- Debian-based systems  
- MX Linux  
- KDE applications running inside **Plasma** or **XFCE**

---

## Architecture Background

| Layer | Role | Must Work |
|------|------|-----------|
| SSH daemon | Remote file transport | ✔ |
| CLI `sftp` | Protocol baseline test | ✔ |
| KIO SFTP worker | KDE network filesystem layer | ✔ |
| Dolphin UI | Frontend only | Optional failure point |

If CLI SFTP works but Dolphin fails → **UI / KIO cache issue**, not network.

---

## Step 1 — Install Required KDE Components

```bash
sudo apt update
sudo apt install --yes kio-extras kio-fuse kde-cli-tools
```

**Purpose**

| Package | Function |
|---------|----------|
| kio-extras | Provides SFTP protocol worker |
| kio-fuse | Allows mounting KIO paths |
| kde-cli-tools | Provides kioclient (diagnostics) |

---

## Step 2 — Verify KDE Can Handle SFTP (Backend Test)

This bypasses Dolphin.

```bash
kioclient ls "sftp://USERNAME@SERVER_IP/"
```

If directories list → KDE supports SFTP correctly.

---

## Step 3 — Baseline CLI Test

```bash
sftp USERNAME@SERVER_IP
```

If this fails → SSH/server problem. Stop here.

---

## Step 4 — Fix “Invalid protocol” in Dolphin (Critical Step)

This resolves stale KDE service caches and broken Dolphin configs.

```bash
kquitapp5 dolphin 2>/dev/null || true
rm -f "$HOME/.config/dolphinrc"
rm -rf "$HOME/.cache/ksycoca"* "$HOME/.cache/kioexec"
kbuildsycoca5
dolphin
```

**Why this works**

| File | Problem |
|------|---------|
| dolphinrc | Corrupted protocol/UI state |
| ksycoca cache | Stale KDE service database |
| kioexec cache | Old worker mappings |

XFCE sessions are especially prone because KDE daemons are not fully session-managed.

---

## Step 5 — Connect Correctly in Dolphin

Open Dolphin → Press **Ctrl + L**

```
sftp://USERNAME@SERVER_IP/
```

Example:

```
sftp://bill@100.118.143.57/
```

---

## Step 6 — Authentication Handling

If no password prompt appears:

```bash
ssh-add ~/.ssh/id_ed25519
ssh-add -l
```

KIO relies on the SSH agent.

---

## Troubleshooting Matrix

| Symptom | Meaning | Fix |
|---------|--------|-----|
| CLI works, kioclient works, Dolphin fails | UI/config corruption | Step 4 |
| “Invalid protocol” | KIO cache issue | Step 4 |
| kioclient fails | Missing kio-extras | Step 1 |
| CLI fails | SSH/server issue | Fix SSH |
| Immediate disconnect | Home dir permissions | `chmod 755 /home/user` |

---

## Verification Checklist

All must succeed:

```bash
sftp USERNAME@SERVER_IP
```

```bash
kioclient ls "sftp://USERNAME@SERVER_IP/"
```

Dolphin:

```
sftp://USERNAME@SERVER_IP/
```

---

## Optional Backup Before Reset

```bash
cp -a "$HOME/.config/dolphinrc" "$HOME/.config/dolphinrc.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
```

---

## Summary

The “Invalid protocol” error in Dolphin is **not a networking issue** when CLI SFTP works. It is almost always:

> **A stale KDE service cache or corrupted Dolphin user configuration**

Resetting Dolphin config + rebuilding `ksycoca` restores proper protocol registration.
