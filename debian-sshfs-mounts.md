# 📂 sshfs Mounts: A Server Folder That Acts Local

> **Purpose**: work on files on another box as if they were local — open, edit, save — instead of `scp`-ing them back and forth. Optionally keep the mount up across logins, reboots and network drops.
> **Audience**: anyone who already logs in to a box with `ssh <alias>` and a key.
> **Scope**: sshfs 3.7 / FUSE 3 on Debian 13 (Trixie) / MX 25 (systemd); any server with SFTP enabled, which is every stock `openssh-server`. Nothing is installed on the server.
> **Script**: [`sshfs-add-mount.sh`](sshfs-add-mount.sh) does §3–§7 for one mount per run.

Everything here runs on your **workstation**. Key login to the host must already work — if it doesn't, do [debian-ssh-client-setup.md](debian-ssh-client-setup.md) first.

> [!TIP]
> **sshfs is not the only answer.** If you only want repeat `scp`/`ssh` to start instantly, `ControlMaster` in `~/.ssh/config` already does that (see [debian-ssh-client-setup.md §4](debian-ssh-client-setup.md#4-a-host-entry)). If you want a shell that survives a disconnect, run `tmux` on the server ([debian-tmux-motd-setup-guide.md](debian-tmux-motd-setup-guide.md)). sshfs is for "I want the folder".

---

## 1. Quick path: the script

```bash
sudo apt install --yes sshfs

./sshfs-add-mount.sh pi5                      # pi5:~ at ~/mnt/pi5, until logout/reboot
./sshfs-add-mount.sh --ro pi5 /srv/media media   # pi5:/srv/media at ~/mnt/media, read-only
./sshfs-add-mount.sh --persist pi5            # remount at every login and after drops
./sshfs-add-mount.sh --boot nas backups       # nas:~/backups, mounted at boot, before login

./sshfs-add-mount.sh --status                 # everything this script mounted
./sshfs-add-mount.sh --check media            # exit 0 if mounted and responding
./sshfs-add-mount.sh --umount media           # unmount (a --persist one returns at next login)
./sshfs-add-mount.sh --remove media           # unmount, delete its service and empty folder
```

Run any of it with `-n` first to see exactly what it would do. Missing arguments are prompted for.

What one run does:

1. Logs in over **SFTP** (what sshfs actually uses) with `BatchMode`, so a broken key fails now instead of at mount time.
2. Checks the remote folder exists.
3. With `--persist`, checks login also works with **no agent and no desktop session** — what the service will see (§5).
4. Refuses if the mount folder is non-empty or already in use.
5. Mounts with the options in §4, or writes and starts the service in §6.

It keeps one small record per mount in `~/.config/sshfs-mounts/NAME.conf`, which is how `--status`, `--umount` and `--remove` find it.

---

## 2. Mount by hand

```bash
mkdir -p ~/mnt/pi5
sshfs pi5: ~/mnt/pi5 -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3
ls ~/mnt/pi5

fusermount3 -u ~/mnt/pi5                     # unmount
```

- `pi5:` with nothing after the colon is your home folder there. `pi5:/srv/media` is an absolute path; `pi5:media` is relative to your home. `~` is **not** expanded — leave it off.
- sshfs reads `~/.ssh/config`, so the alias's host, user, port and key all apply.
- No root needed. The mount belongs to you and, by default, only you can see it.

---

## 3. Mount names and folders

The script mounts at `~/mnt/NAME`. NAME defaults to the alias for a home mount, or `ALIAS-<last folder>` otherwise (`pi5 /srv/media` → `pi5-media`). Pass a third argument to choose it, or `-m DIR` for a different folder entirely.

Several mounts per host are fine — each has its own name, folder and (with `--persist`) service.

> [!WARNING]
> **Never `rm -r` a mount folder while it is mounted.** That deletes the files **on the server**. Unmount first, check with `findmnt ~/mnt/NAME` (no output = unmounted), then `rmdir`. `--remove` does exactly this and only ever uses `rmdir`, which refuses non-empty folders.

---

## 4. Options that matter

The script always mounts with these:

| Option | Why |
| :--- | :--- |
| `reconnect` | Re-establishes the SSH link after a drop instead of leaving a dead mount. |
| `ServerAliveInterval=15`, `ServerAliveCountMax=3` | Detects a dead link in ~45 s. Without them, anything touching the mount **hangs indefinitely** after a drop (sshfs man page, *SSHFS hangs after the connection was interrupted*). |
| `BatchMode=yes` | Never stops to ask for a password — a reconnect that can't authenticate fails instead of hanging. |
| `ControlMaster=no`, `ControlPath=none` | The mount owns its own connection. Without this, if your host block has `ControlMaster auto`, the mount can ride — or become — the shared master socket, and its lifetime and reconnects get tangled with your interactive sessions. |
| `idmap=user` | Files owned by your remote user show as owned by you locally, so permissions read sensibly. |

Optional:

| Flag | Option | Notes |
| :--- | :--- | :--- |
| `--ro` | `ro` | Read-only. Good for media and backups. |
| `--allow-other` | `allow_other` | Lets other local users and services (Plex, Docker, Samba) see the mount. Needs `user_allow_other` uncommented in `/etc/fuse.conf` — the script checks and prints the one-line fix rather than editing it. |
| `-o OPTS` | anything | Passed through, comma-separated. E.g. `-o follow_symlinks`, or `-o max_conns=4` for faster big transfers. |

---

## 5. A key for unattended mounts

A `--persist` service runs with **no ssh-agent and no desktop keyring**. If your key has a passphrase, login works in your terminal (the agent unlocks it) but the service can never mount. The script tests this with a stripped environment and refuses `--persist` if it fails.

The fix is a second key, without a passphrase, used only for this host — and locked down on the server so it can do SFTP and nothing else:

```bash
# On the workstation: a dedicated key (press Enter at the passphrase prompt)
./ssh-add-host.sh -k ~/.ssh/id_ed25519_mount --force pi5 192.168.1.50 bill
```

Then on the server, edit `~/.ssh/authorized_keys` and put this **in front of** the `id_ed25519_mount` line:

```
restrict,command="internal-sftp" ssh-ed25519 AAAA...  bill@workstation
```

- `restrict` turns off port forwarding, agent forwarding, X11 and a terminal.
- `command="internal-sftp"` means the key can only start the SFTP server. `ssh pi5` with it prints *This service allows sftp connections only.*
- If the key leaks, the thief gets your files on that host — not a shell. Keep it at `chmod 600` like any key.

The script's checks use SFTP rather than `ssh host true`, so they work with a restricted key.

> [!NOTE]
> After restricting the key, `ssh pi5` (shell) uses it too, because the alias's `IdentityFile` points at it. Keep a second alias with your normal key for shell access, e.g. `./ssh-add-host.sh pi5-shell 192.168.1.50 bill`.

---

## 6. Persistent mounts: a systemd user service

`--persist` writes `~/.config/systemd/user/sshfs-NAME.service`:

```ini
[Unit]
Description=sshfs pi5:/srv/media on /home/bill/mnt/media
StartLimitIntervalSec=0

[Service]
Type=exec
ExecStartPre=-/usr/bin/fusermount3 -uz "/home/bill/mnt/media"
ExecStart=/usr/bin/sshfs -f "pi5:/srv/media" "/home/bill/mnt/media" -o reconnect,ServerAliveInterval=15,...
ExecStopPost=-/usr/bin/fusermount3 -uz "/home/bill/mnt/media"
SuccessExitStatus=1
Restart=always
RestartSec=15

[Install]
WantedBy=default.target
```

| Line | Why |
| :--- | :--- |
| `sshfs -f`, `Type=exec` | sshfs stays in the foreground, so systemd watches the real process. |
| `ExecStartPre`/`ExecStopPost` lazy unmount | Clears a stale *Transport endpoint is not connected* mount left by a crash. The leading `-` ignores "not mounted". |
| `SuccessExitStatus=1` | sshfs exits 1 even on a clean stop; without this every `systemctl stop` leaves the unit `failed`. |
| `Restart=always`, `RestartSec=15`, `StartLimitIntervalSec=0` | Retry every 15 s, forever, after any exit except a deliberate stop. Covers booting before the network is up and the host being down for a while. |
| `WantedBy=default.target` | Starts when your user session starts. |

It's a **user** unit — no root, your own key and `~/.ssh/config`.

```bash
systemctl --user status sshfs-media
journalctl --user -u sshfs-media -n 20
```

### Mount at boot, before you log in (`--boot`)

A user's services normally start at login and stop at logout. **Linger** keeps that user's service manager running from boot:

```bash
loginctl enable-linger "$USER"
loginctl show-user "$USER" -p Linger      # Linger=yes
```

`--boot` does this for you. It is per user, not per mount, so `--remove` leaves it on (other services may rely on it) and tells you how to turn it off: `loginctl disable-linger`.

> [!NOTE]
> **Why not `/etc/fstab`?** An fstab sshfs mount runs as root — root needs its own key, its own `known_hosts` entry, and `allow_other` for you to see the files. The user service avoids all three. fstab's one advantage is `x-systemd.automount` (mount on first access); if you need that, the sshfs man page's *MOUNTING FROM /ETC/FSTAB* section covers it.

---

## 7. Unmount and remove

| Command | Effect |
| :--- | :--- |
| `--umount NAME` | Stops the service (if any) and unmounts. A `--persist` mount stays enabled and comes back at next login. |
| `--remove NAME` | Disables and deletes the service, unmounts, verifies it's unmounted, `rmdir`s the folder (left alone if not empty), deletes the record. Never deletes files. |

By hand: `fusermount3 -u ~/mnt/NAME`. If it says *Device or resource busy*, something has a file or shell open in there — `fuser -vm ~/mnt/NAME` shows what.

---

## 8. Troubleshooting

| Symptom | Cause | Fix |
| :--- | :--- | :--- |
| `ls ~/mnt/NAME` freezes | Link dropped; the 45 s keepalive hasn't fired yet, or the mount was made without keepalives | Wait ~45 s. To unfreeze now, kill the sshfs process: `pkill -x sshfs` (or `systemctl --user restart sshfs-NAME`). A lazy unmount (`fusermount3 -uz`) does **not** free calls that are already stuck. |
| *Transport endpoint is not connected* | sshfs died and left the mount behind | `fusermount3 -uz ~/mnt/NAME`, then remount. The service does this itself. |
| `--persist` refused: *only works through your agent* | Key has a passphrase | §5. |
| Service `activating (auto-restart)` forever | Host down, wrong path, or key rejected | `journalctl --user -u sshfs-NAME -n 20` shows the sshfs error. |
| *fusermount3: option allow_other only allowed if 'user_allow_other' is set* | `--allow-other` without `/etc/fuse.conf` change | `sudo sed -i 's/^#[[:space:]]*user_allow_other/user_allow_other/' /etc/fuse.conf` |
| File manager slow to open the folder | It reads thumbnails and metadata for every file over the network | Turn off previews for remote folders, or open a subfolder directly. |
| `mv` across folders fails with *Permission denied* | Server can't rename across filesystems | Add `-o workaround=renamexdev`. |

---

## 9. Verified vs. not

**Run end-to-end for this guide** (sshfs 3.7.3, FUSE 3.17.2, systemd 257, OpenSSH 10.0 on Debian 13), against a throwaway `sshd` on the same machine:

- Mount, read, `--check`, `--status`, `--ro` (writes refused), `--force` replace, `--umount`, `--remove` (folder removed, remote files untouched).
- Refusals: duplicate name, mount folder in use, non-empty folder, missing remote folder, a file given as the folder, bad alias/name/options/path characters.
- `--persist`: unit written and started; after `kill` of the sshfs process systemd remounted it 15 s later; clean stop leaves the unit `inactive`, not `failed`; `--remove` leaves no unit or symlink behind.
- A key restricted with `restrict,command="internal-sftp"`: shell refused, mount works, `--persist` works.
- shellcheck 0.11 clean.

**Not run**: `--boot` from a real reboot (linger was already on on the test machine, so the `enable-linger` step itself wasn't exercised); `--allow-other`; a real network drop and `reconnect` against a remote host (only process-kill recovery was tested); a Raspberry Pi as the server.

---

## Related guides in this repo

- [SSH client setup](debian-ssh-client-setup.md) — the alias and key this builds on
- [Desktop / laptop / Pi to server](debian-desktop-to-server.md) — preparing the box you mount from
- [Dolphin SFTP under XFCE](debian-kde-dolphin-xfce.md) — `sftp://pi5` in a file manager, when you don't need a real mount
- [tmux + MOTD](debian-tmux-motd-setup-guide.md) — a shell that survives disconnects

[Back to the repository index](README.md)
