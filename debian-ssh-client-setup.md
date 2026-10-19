# 🔑 SSH Client Setup: Keys, `~/.ssh/config` and Passwordless Login

> **Purpose**: type `ssh pi5` instead of `ssh -p 2222 bill@192.168.1.50`, log in with a key instead of a password, and turn password login off once the key is proven.
> **Audience**: anyone with more than one Linux box to reach from a workstation.
> **Scope**: OpenSSH client on Debian 13 (Trixie) / MX 25 (OpenSSH 10.0); servers running Debian, MX or Raspberry Pi OS with `openssh-server`. Works the same on Debian 12.
> **Script**: [`ssh-add-host.sh`](ssh-add-host.sh) does §2–§6 for one host per run.

Everything here runs on your **workstation** except §6, which changes the server.

> [!TIP]
> Setting up a box to *be* the server first? See [debian-desktop-to-server.md](debian-desktop-to-server.md). It links back here for the SSH part.

---

## 1. Quick path: the script

```bash
./ssh-add-host.sh                                # asks for alias, host, user, port
./ssh-add-host.sh pi5 192.168.1.50 bill          # same, no prompts
./ssh-add-host.sh --harden pi5 192.168.1.50 bill # also turn off password login (§6)
./ssh-add-host.sh --check pi5                    # exit 0 if key login works
./ssh-add-host.sh --remove pi5                   # delete the config entry
./ssh-add-host.sh -n pi5 192.168.1.50 bill       # dry run: print, change nothing
```

What a run does, in order:

1. Creates `~/.ssh/id_ed25519` if you don't have a key (§2).
2. Puts `Include config.d/*` at the top of `~/.ssh/config`, backing the old file up first (§3).
3. Writes `~/.ssh/config.d/<alias>`, one file per host (§4).
4. Runs `ssh-copy-id`. You type the server password once (§5).
5. Proves key login with `BatchMode=yes`, which forbids password fallback. It stops here with a failure if the key isn't accepted.
6. With `--harden`, and only after step 5 passed, turns off password and root login on the server (§6). It asks first unless you pass `--yes`.

Refuses to overwrite an alias that already exists, in `config` or `config.d/`. `--force` overwrites only its own `config.d/<alias>` file.

---

## 2. Make a key

One key per workstation is enough. Use ed25519.

```bash
ssh-keygen -t ed25519 -a 64 -C "$USER@$(hostname -s)"
# accept the default path ~/.ssh/id_ed25519
```

- **Use a passphrase.** Without one, anyone who copies the file is you on every server.
- `-a 64` makes passphrase guessing slower. It costs a fraction of a second when you unlock the key.
- The comment (`-C`) is what shows in the server's `authorized_keys`. Make it say which machine the key lives on.

Type the passphrase once per login session, not once per connection:

- **KDE / GNOME**: the desktop's agent picks the key up. KDE needs `ksshaskpass` to remember it in KWallet.
- **Anywhere else**: `eval "$(ssh-agent -s)" && ssh-add`.

Check it's loaded: `ssh-add -l`.

---

## 3. One file per host: `config.d/`

Put this as the **first line** of `~/.ssh/config`:

```text
Include config.d/*
```

```bash
mkdir -p ~/.ssh/config.d
chmod 700 ~/.ssh ~/.ssh/config.d
chmod 600 ~/.ssh/config
```

> [!IMPORTANT]
> `Include` must come before every `Host` or `Match` line. Placed after one, it only applies inside that block, and your included hosts silently don't exist.

Why one file per host: adding a host is creating a file, removing one is deleting it, and nothing else in your config moves.

---

## 4. A host entry

`~/.ssh/config.d/pi5`:

```text
Host pi5
    HostName 192.168.1.50
    User bill
    Port 22
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    # Keep idle sessions alive through NAT and Wi-Fi power save
    ServerAliveInterval 30
    ServerAliveCountMax 4
    # Reuse one connection for repeat logins, scp and rsync
    ControlMaster auto
    ControlPath ~/.ssh/cm-%C
    ControlPersist 10m
```

| Option | Why |
| :--- | :--- |
| `HostName` | Use a fixed IP or DHCP reservation, or `name.local` with mDNS. See [Desktop to server §3](debian-desktop-to-server.md#3-give-it-a-fixed-address). |
| `IdentitiesOnly yes` | Offers only this key. Without it, an agent holding many keys can hit the server's `MaxAuthTries` (6) before reaching the right one. |
| `ServerAliveInterval 30` | A keepalive every 30 s. A silent session is dropped after 4 misses (2 min), instead of hanging forever. |
| `ControlMaster` / `ControlPersist` | The second `ssh pi5` within 10 minutes reuses the first connection and opens instantly. |

> [!NOTE]
> `ssh` uses the **first** value it finds for each option. Specific `Host` blocks therefore go *above* any `Host *` defaults. The `Include` at the top of the file guarantees that for everything in `config.d/`.

See what ssh will actually use, without connecting:

```bash
ssh -G pi5 | grep -E '^(hostname|user|port|identityfile) '
```

---

## 5. Install the key on the server

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub pi5
```

It uses the alias, so the port and user from §4 apply. You type the account password once. It appends the key to `~/.ssh/authorized_keys` on the server and fixes permissions.

Prove it, with password fallback forbidden:

```bash
ssh -o BatchMode=yes -o ControlPath=none pi5 true && echo KEY-OK
```

`ControlPath=none` matters: without it, a connection that is still open from `ssh-copy-id` can make the test pass without testing anything.

**No password login available at all?** Raspberry Pi Imager can put your public key on the SD card ("Enable SSH → Allow public-key authentication only"). Or paste the `.pub` line into `~/.ssh/authorized_keys` on the server from its console.

---

## 6. Turn off password login on the server

Do this **only after §5 printed `KEY-OK`**. Keep your current SSH session open until the end of this section; a reload doesn't drop it.

> [!WARNING]
> This applies to **every account on the server**. Anyone without a key installed is locked out, including you from a second workstation that hasn't had §5 done yet.

On the server:

```bash
sudo tee /etc/ssh/sshd_config.d/10-keys-only.conf >/dev/null <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
EOF
sudo sshd -t && sudo systemctl reload ssh
sudo sshd -T | grep -E '^(passwordauthentication|kbdinteractiveauthentication|permitrootlogin) '
# expect all three: no
```

Why `10-`: like the client, `sshd` keeps the **first** value it reads. Debian's `sshd_config` includes `sshd_config.d/*.conf` before its own settings, in filename order. `10-` beats later drop-ins such as cloud-init's `50-cloud-init.conf`, which can set `PasswordAuthentication yes`.

From the workstation, in a **new** terminal:

```bash
ssh -o ControlPath=none pi5 true && echo STILL-OK
ssh -o ControlPath=none -o PubkeyAuthentication=no pi5    # expect: Permission denied (publickey)
```

Undo, from the open session or the console:

```bash
sudo rm /etc/ssh/sshd_config.d/10-keys-only.conf && sudo systemctl reload ssh
```

---

## 7. Troubleshooting

| Symptom | Cause | Fix |
| :--- | :--- | :--- |
| `ssh pi5`: `Could not resolve hostname pi5` | Alias not loaded | `Include` missing or not first in `~/.ssh/config` (§3); check with `ssh -G pi5`. |
| Still asks for a password after `ssh-copy-id` | Server-side permissions | On the server: `chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys`; home dir must not be group-writable. Then `sudo journalctl -u ssh -n 20`. |
| `Too many authentication failures` | Agent offers too many keys | `IdentitiesOnly yes` in the host entry (§4). |
| `Bad owner or permissions on ~/.ssh/config` | File is group/world-writable | `chmod 600 ~/.ssh/config ~/.ssh/config.d/*` |
| `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED` | Server reinstalled, or IP reused by another box | If you know it was reinstalled: `ssh-keygen -R 192.168.1.50`. If you don't, stop and find out why. |
| Session freezes after idling | NAT or Wi-Fi drops idle flows | `ServerAliveInterval` (§4); on a Wi-Fi server also disable power save ([uplink guide §5](debian-wifi-uplink-guide.md#5-required-fix-disable-wifi-power-save)). |
| `ssh pi5` hangs, but a fresh terminal with `-o ControlPath=none` works | Stale master connection | `ssh -O exit pi5` |
| Anything else | — | `ssh -vvv pi5` on the client; `sudo journalctl -u ssh -f` on the server. |

---

## 8. Verified vs. not

**Checked for this guide**: `ssh-add-host.sh` passes `bash -n` and shellcheck 0.11. Its argument validation was run: unknown option, bad alias and out-of-range port each exit 2 before touching `~/.ssh`. OpenSSH version and `Include` / first-value-wins behaviour are from OpenSSH 10.0 on Debian 13.

**Not run end-to-end**: a full `ssh-add-host.sh` session against a real server, including `--harden`. Run it with `-n` first and read the output.

---

## Related guides in this repo

- [Desktop / laptop / Pi to server](debian-desktop-to-server.md) — preparing the box this connects to
- [Server on WiFi](debian-wifi-uplink-guide.md) — power save and why inbound SSH lags on WiFi
- [Dolphin SFTP under XFCE](debian-kde-dolphin-xfce.md) — `sftp://pi5` in a file manager uses this same config
- [sshfs mounts](debian-sshfs-mounts.md) — the host's folder as a local one, kept mounted across logins and drops

[Back to the repository index](README.md)
