# tmux Session Manager + Custom MOTD — Debian/Ubuntu Setup Guide

## What This Sets Up

| Component | What It Does |
|-----------|-------------|
| Custom MOTD | Displays a clean info banner (kernel, uptime, GPU driver) at login |
| `~/.tmux.conf` | tmux config with auto-logging hooks and a friendlier prefix key |
| `~/.tmux-log-window.sh` | Per-window log starter called automatically by tmux |
| `tm` command | Session wrapper: creates or reattaches, and archives logs on detach |

---

## Files

| File | Installed To | Purpose |
|------|-------------|---------|
| `motd-99-custom` | `/etc/update-motd.d/99-custom` | Custom login banner |
| `.tmux.conf` | `~/.tmux.conf` | tmux config + auto-logging hooks |
| `.tmux-log-window.sh` | `~/.tmux-log-window.sh` | Per-window log starter |
| `tm` | `/usr/local/bin/tm` | Session wrapper with log archiving |

---

## Installation

Run these once to put everything in place:

```bash
# MOTD
sudo install -m 755 ~/motd-99-custom /etc/update-motd.d/99-custom
sudo truncate -s 0 /etc/motd

# tmux helper and tm command
chmod +x ~/.tmux-log-window.sh
sudo install -m 755 ~/tm /usr/local/bin/tm

# log directories
mkdir -p ~/logs/tmux/active ~/logs/tmux/archive
```

Test the MOTD without logging out:

```bash
run-parts /etc/update-motd.d/
```

---

## Daily Use

### Starting and stopping sessions

```bash
tm work          # create "work" session, or reattach if it already exists
tm               # same but session is named "main"
tm project       # any name — one session per project, context, etc.
tmux ls          # list all running sessions
```

When you're done or need to step away — **detach**, don't close the terminal:

```
Ctrl+A, D        detach — session keeps running in the background
```

Run `tm work` again later to pick up exactly where you left off.

### Inside a session

| Keys | Action |
|------|--------|
| `Ctrl+A, C` | New window |
| `Ctrl+A, 1` / `2` / `3` … | Switch to window by number |
| `Ctrl+A, ,` | Rename current window |
| `Ctrl+A, \|` | Split pane left/right |
| `Ctrl+A, -` | Split pane top/bottom |
| `Ctrl+A, arrow` | Move between panes |
| `Ctrl+A, D` | Detach session |
| `Ctrl+A, R` | Reload `~/.tmux.conf` |

> **Note:** The prefix key is `Ctrl+A` (not the tmux default `Ctrl+B` — easier to reach on most keyboards).

Mouse is enabled — you can click windows in the status bar and drag pane borders to resize.

### Killing a session you no longer need

```bash
tmux kill-session -t work
```

---

## Logging

Every window you open automatically logs its output to:

```
~/logs/tmux/active/SESSION__wINDEX_WINDOWNAME__TIMESTAMP.log
```

No configuration needed — the tmux hook handles it transparently.

When you detach with `Ctrl+A, D`, the `tm` script moves all logs for that session into:

```
~/logs/tmux/archive/SESSION_TIMESTAMP/
```

### Searching logs

```bash
# search across all archived sessions
grep -r "error" ~/logs/tmux/archive/

# list archived sessions
ls ~/logs/tmux/archive/

# read a specific session's window log
cat ~/logs/tmux/archive/work_20260430_150000/work__w1_bash__20260430_143000.log

# tail the active log for the current window (while inside tmux)
tail -f ~/logs/tmux/active/work__w1_bash__*.log
```

---

## How It Works

### MOTD

`/etc/update-motd.d/` contains scripts that run at login. Their output is collected
into `/run/motd.dynamic`, which PAM displays via `pam_motd.so`. Scripts run in
filename order — `99-custom` runs last so it appears at the bottom of the login screen.

To update what the banner shows, edit `/etc/update-motd.d/99-custom` directly.

### tmux auto-logging

`~/.tmux.conf` sets this hook:

```
set-hook -g after-new-window \
  'run-shell "~/.tmux-log-window.sh #{session_name} #{window_index} #{window_name}"'
```

Every time a window is created (including the first one when a session starts),
tmux calls `~/.tmux-log-window.sh`, which runs:

```bash
tmux pipe-pane -t SESSION:WINDOW.0 -o "cat >> LOGFILE"
```

`pipe-pane` captures all terminal output from that pane and appends it to the
log file. It runs until the window closes.

### Session archiving

`tm` is a thin wrapper around `tmux new-session -A -s NAME`. After tmux exits
(on detach or session end), it moves all log files matching
`~/logs/tmux/active/SESSIONNAME__*.log` into a timestamped subdirectory under
`~/logs/tmux/archive/`.

---

## Reference: Log Directory Layout

```
~/logs/tmux/
├── active/                          ← logs for currently running sessions
│   └── work__w1_bash__20260430_143000.log
└── archive/                         ← logs moved here on detach
    ├── work_20260430_150000/
    │   ├── work__w1_bash__20260430_143000.log
    │   └── work__w2_vim__20260430_144500.log
    └── main_20260429_220000/
        └── main__w1_bash__20260429_210000.log
```

---

## Troubleshooting

**MOTD not showing on login**
Verify `pam_motd.so` is active in your PAM config:
```bash
grep pam_motd /etc/pam.d/login
```
Test output without logging out: `run-parts /etc/update-motd.d/`

**Logs not being created**
```bash
ls -la ~/.tmux-log-window.sh    # must be executable
ls ~/logs/tmux/active/          # directory must exist
```
Then reload config inside tmux: `Ctrl+A, R`

**`tm` command not found**
```bash
which tm                                        # should print /usr/local/bin/tm
sudo install -m 755 ~/tm /usr/local/bin/tm      # reinstall if missing
```

**Reattaching to a session when `tm` isn't available**
```bash
tmux ls                    # list sessions
tmux attach -t work        # attach to a session by name
```
