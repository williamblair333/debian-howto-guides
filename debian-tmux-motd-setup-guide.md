# tmux Session Manager + Custom MOTD — Debian/Ubuntu Setup Guide

## Quick Setup (copy-paste all of this)

Run the four blocks below in order. Each block creates one file then installs it.

---

### 1. MOTD banner (`/etc/update-motd.d/99-custom`)

```bash
cat > /tmp/99-custom << 'EOF'
#!/bin/bash
DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
echo "
────────────────────────────────────────────────────
  $(hostname)
  Kernel  $(uname -r)
  Uptime  $(uptime -p | sed 's/up //')
${DRIVER:+  GPU     driver ${DRIVER}
}
  tm [name]   attach or create a tmux session
  Logs:       ~/logs/tmux/archive/
────────────────────────────────────────────────────
"
EOF
sudo install -m 755 /tmp/99-custom /etc/update-motd.d/99-custom
sudo truncate -s 0 /etc/motd
```

---

### 2. tmux config (`~/.tmux.conf`)

```bash
cat > ~/.tmux.conf << 'EOF'
# ── prefix ────────────────────────────────────────────────────
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# ── behavior ──────────────────────────────────────────────────
set -g mouse on
set -g history-limit 50000
set -sg escape-time 0
set -g base-index 1
setw -g pane-base-index 1

# ── status bar ────────────────────────────────────────────────
set -g status-style bg=colour235,fg=colour250
set -g status-left "#[fg=colour39,bold] #S #[fg=colour250]│ "
set -g status-left-length 30
set -g status-right "#[fg=colour250]%a %Y-%m-%d  %H:%M "
set -g window-status-current-style fg=colour39,bold
set -g window-status-format " #I:#W "
set -g window-status-current-format " #I:#W "

# ── split with same directory ─────────────────────────────────
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# ── reload config ─────────────────────────────────────────────
bind r source-file ~/.tmux.conf \; display "config reloaded"

# ── logging: start pipe-pane on every new window ──────────────
set-hook -g after-new-window \
  'run-shell "~/.tmux-log-window.sh #{session_name} #{window_index} #{window_name}"'
EOF
```

---

### 3. Per-window log starter (`~/.tmux-log-window.sh`)

```bash
cat > ~/.tmux-log-window.sh << 'EOF'
#!/bin/bash
SESSION="$1"
WIDX="$2"
WNAME="$3"

LOGDIR="$HOME/logs/tmux/active"
mkdir -p "$LOGDIR"

TS=$(date +%Y%m%d_%H%M%S)
LOGFILE="${LOGDIR}/${SESSION}__w${WIDX}_${WNAME}__${TS}.log"

tmux pipe-pane -t "${SESSION}:${WIDX}.0" -o "cat >> '${LOGFILE}'"
EOF
chmod +x ~/.tmux-log-window.sh
```

---

### 4. `tm` session wrapper (`/usr/local/bin/tm`)

```bash
cat > /tmp/tm << 'EOF'
#!/bin/bash
SESSION="${1:-main}"
LOG_ACTIVE="$HOME/logs/tmux/active"
LOG_ARCHIVE="$HOME/logs/tmux/archive"

mkdir -p "$LOG_ACTIVE" "$LOG_ARCHIVE"

tmux new-session -A -s "$SESSION"

# after detach/exit: archive this session's logs
shopt -s nullglob
files=("$LOG_ACTIVE/${SESSION}__"*.log)
if [[ ${#files[@]} -gt 0 ]]; then
    DEST="${LOG_ARCHIVE}/${SESSION}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$DEST"
    mv "${files[@]}" "$DEST/"
    echo "  logs archived → $DEST"
fi
EOF
sudo install -m 755 /tmp/tm /usr/local/bin/tm
```

---

### 5. Create log directories and verify

```bash
mkdir -p ~/logs/tmux/active ~/logs/tmux/archive

# verify everything is in place
echo "--- MOTD ---"
run-parts /etc/update-motd.d/

echo "--- tmux config ---"
tmux source-file ~/.tmux.conf 2>&1 || echo "(start a session first to test)"

echo "--- tm command ---"
which tm

echo "--- log dirs ---"
ls ~/logs/tmux/
```

---

## Daily Use

### Starting and stopping sessions

```bash
tm work          # create "work" session, or reattach if it already exists
tm               # same but session is named "main"
tm project       # any name — one per project, context, etc.
tmux ls          # list all running sessions
```

When you need to step away — **detach**, don't close the terminal:

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

> Prefix key is `Ctrl+A` (not the tmux default `Ctrl+B` — easier to reach).

Mouse is enabled — click windows in the status bar and drag pane borders to resize.

### Killing a session you no longer need

```bash
tmux kill-session -t work
```

---

## Logging

Every window automatically logs its output to:

```
~/logs/tmux/active/SESSION__wINDEX_WINDOWNAME__TIMESTAMP.log
```

On detach (`Ctrl+A, D`), `tm` archives that session's logs to:

```
~/logs/tmux/archive/SESSION_TIMESTAMP/
```

### Searching logs

```bash
grep -r "error" ~/logs/tmux/archive/          # search all archived sessions
ls ~/logs/tmux/archive/                        # list archived sessions
tail -f ~/logs/tmux/active/work__w1_*.log      # tail active window log
```

---

## How It Works

### MOTD

Scripts in `/etc/update-motd.d/` run at login in filename order. Their output is
collected into `/run/motd.dynamic` and displayed by PAM. `99-custom` runs last,
appearing at the bottom of the login screen. Edit it directly to change the banner.

### Auto-logging

`~/.tmux.conf` fires `~/.tmux-log-window.sh` via `after-new-window` hook every time
a window is created. The script calls `tmux pipe-pane` to capture all output from
that pane to a timestamped log file.

### Session archiving

`tm` wraps `tmux new-session -A -s NAME`. After tmux exits, it moves all matching
log files from `active/` into a timestamped subdirectory in `archive/`.

---

## Log Directory Layout

```
~/logs/tmux/
├── active/                          ← live logs for running sessions
│   └── work__w1_bash__20260430_143000.log
└── archive/                         ← moved here on detach
    ├── work_20260430_150000/
    │   ├── work__w1_bash__20260430_143000.log
    │   └── work__w2_vim__20260430_144500.log
    └── main_20260429_220000/
        └── main__w1_bash__20260429_210000.log
```

---

## Troubleshooting

**MOTD not showing on login**
```bash
grep pam_motd /etc/pam.d/login        # verify pam_motd.so is active
run-parts /etc/update-motd.d/         # test output without logging out
```

**Logs not being created**
```bash
ls -la ~/.tmux-log-window.sh          # must be executable (-rwxr-xr-x)
ls ~/logs/tmux/active/                # directory must exist
```
Then reload config inside tmux: `Ctrl+A, R`

**`tm` command not found**
```bash
which tm                                        # should print /usr/local/bin/tm
sudo install -m 755 /tmp/tm /usr/local/bin/tm   # reinstall if missing
```

**Reattaching without `tm`**
```bash
tmux ls                    # list sessions
tmux attach -t work        # attach by name
```

---

## Related guides in this repo

- [MX 25 First 10 Minutes](mx25-first-10-minutes.md) — the broader post-install pass
- [Linux Troubleshooting Instructions](linux-troubleshooting-guide.md) — the diagnostic method to pair with a working shell

[Back to the repository index](README.md)
