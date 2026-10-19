#!/bin/bash
# sshfs-add-mount.sh - Mount a folder from an SSH host, optionally for good
#
# Runs on your workstation. Needs a host that key login already works for
# (set one up with ssh-add-host.sh first). One run per mount:
#   1. checks key login and the remote folder
#   2. mounts ALIAS:PATH at ~/mnt/NAME with reconnect + keepalives
#   3. optionally (--persist) writes a systemd user service that remounts
#      it at every login and after network drops; --boot also mounts it
#      at boot, before you log in
#
# Full write-up: debian-sshfs-mounts.md

set -euo pipefail

VERSION="1.0.0"
PROG="$(basename "$0")"
CONF_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="$CONF_HOME/sshfs-mounts"
UNIT_DIR="$CONF_HOME/systemd/user"
MNT_BASE="$HOME/mnt"

# reconnect + keepalives: a dead link errors out after ~45s instead of
# hanging forever. ControlPath=none: the mount owns its connection rather
# than riding (or becoming) the shared ControlMaster socket.
BASE_OPTS="reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,BatchMode=yes,ControlMaster=no,ControlPath=none,idmap=user"

# ---------------------------------------------------------------- output ----
if [[ -t 1 ]]; then
    C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
    C_BLD=$'\033[1m';  C_OFF=$'\033[0m'
else
    C_RED=""; C_GRN=""; C_YEL=""; C_BLD=""; C_OFF=""
fi

info() { printf '%s\n' "$*"; }
ok()   { printf '%s[ OK ]%s %s\n' "$C_GRN" "$C_OFF" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$C_YEL" "$C_OFF" "$*" >&2; }
die()  { printf '%s[FAIL]%s %s\n' "$C_RED" "$C_OFF" "$1" >&2; exit "${2:-2}"; }

run() {
    if $DRY_RUN; then
        printf '%s+ %s%s\n' "$C_BLD" "$*" "$C_OFF"
        return 0
    fi
    "$@"
}

usage() {
    cat <<EOF
Usage: $PROG [OPTIONS] [ALIAS [REMOTE_PATH] [NAME]]

Mount REMOTE_PATH from an SSH host at ~/mnt/NAME. Missing arguments are
prompted for. Key login to ALIAS must already work (see ssh-add-host.sh).

Arguments:
  ALIAS                Host alias from ~/.ssh/config
  REMOTE_PATH          Folder on the host; relative paths start in your
                       home there (default: your home)
  NAME                 Mount name (default: ALIAS, or ALIAS-<last folder>)

Options:
  -m, --mountpoint DIR Mount here instead of ~/mnt/NAME
      --persist        Remount at every login and after drops (systemd
                       user service; needs a key that works without a
                       passphrase prompt)
      --boot           --persist, and mount at boot before you log in
                       (enables systemd linger for your user)
      --ro             Mount read-only
      --allow-other    Let other local users and services see the mount
                       (needs user_allow_other in /etc/fuse.conf)
  -o, --options OPTS   Extra sshfs options, comma-separated
      --force          Replace an existing mount of the same NAME
      --umount NAME    Unmount NAME (a --persist mount returns at next login)
      --remove NAME    Unmount NAME, delete its service and empty mount folder
      --check NAME     Test that NAME is mounted and responding (0 = yes)
      --status         List mounts made by this script
  -n, --dry-run        Print what would change; change nothing
  -h, --help           Show this help
  -V, --version        Show version

Examples:
  $PROG pi5                              # pi5:~ at ~/mnt/pi5
  $PROG --ro pi5 /srv/media media        # pi5:/srv/media at ~/mnt/media
  $PROG --boot nas backups               # nas:~/backups, mounted at boot
  $PROG --check media
EOF
}

# ------------------------------------------------------------------ args ----
DRY_RUN=false
PERSIST=false
BOOT=false
RO=false
ALLOW_OTHER=false
FORCE=false
EXTRA_OPTS=""
MOUNTPOINT=""
MODE=add
TARGET=""
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--mountpoint) MOUNTPOINT="${2:?--mountpoint needs a path}"; shift 2 ;;
        --persist)       PERSIST=true; shift ;;
        --boot)          PERSIST=true; BOOT=true; shift ;;
        --ro)            RO=true; shift ;;
        --allow-other)   ALLOW_OTHER=true; shift ;;
        -o|--options)    EXTRA_OPTS="${2:?--options needs a value}"; shift 2 ;;
        --force)         FORCE=true; shift ;;
        --umount)        MODE=umount; TARGET="${2:?--umount needs a name}"; shift 2 ;;
        --remove)        MODE=remove; TARGET="${2:?--remove needs a name}"; shift 2 ;;
        --check)         MODE=check;  TARGET="${2:?--check needs a name}";  shift 2 ;;
        --status)        MODE=status; shift ;;
        -n|--dry-run)    DRY_RUN=true; shift ;;
        -h|--help)       usage; exit 0 ;;
        -V|--version)    echo "$PROG $VERSION"; exit 0 ;;
        --)              shift; POSITIONAL+=("$@"); break ;;
        -*)              die "Unknown option: $1 (see --help)" ;;
        *)               POSITIONAL+=("$1"); shift ;;
    esac
done

# --------------------------------------------------------------- helpers ----
valid_name() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; }

# Paths end up inside a systemd unit's ExecStart; these characters would
# need unit-level escaping, so refuse them rather than get it subtly wrong.
safe_path() { [[ "$1" != *[\"\\\$%\`]* && "$1" != *$'\n'* ]]; }

ask() {   # ask VAR "Prompt" [default]
    local __var="$1" __prompt="$2" __def="${3:-}" __ans
    if [[ -n "$__def" ]]; then
        read -r -p "$__prompt [$__def]: " __ans
        __ans="${__ans:-$__def}"
    else
        read -r -p "$__prompt: " __ans
    fi
    printf -v "$__var" '%s' "$__ans"
}

state_file() { printf '%s/%s.conf' "$STATE_DIR" "$1"; }
unit_name()  { printf 'sshfs-%s.service' "$1"; }
unit_file()  { printf '%s/%s' "$UNIT_DIR" "$(unit_name "$1")"; }
linger_on()  { [[ "$(loginctl show-user "$USER" -p Linger --value 2>/dev/null)" == yes ]]; }

# Loads S_ALIAS / S_REMOTE / S_MOUNTPOINT for a saved mount. Parsed, not sourced.
load_state() {
    local f k v
    f="$(state_file "$1")"
    [[ -f "$f" ]] || die "No mount named '$1' (see --status)"
    S_ALIAS=""; S_REMOTE=""; S_MOUNTPOINT=""
    while IFS='=' read -r k v; do
        case "$k" in
            ALIAS)      S_ALIAS="$v" ;;
            REMOTE)     S_REMOTE="$v" ;;
            MOUNTPOINT) S_MOUNTPOINT="$v" ;;
        esac
    done < "$f"
    [[ -n "$S_ALIAS" && -n "$S_MOUNTPOINT" ]] || die "Corrupt state file: $f"
}

# Reads /proc/self/mountinfo instead of stat'ing the path: stat on a dead
# FUSE mount hangs or fails, which is exactly when we need the answer.
is_mounted() {
    local m
    while read -r _ _ _ _ m _; do
        [[ "${m//\\040/ }" == "$1" ]] && return 0
    done < /proc/self/mountinfo
    return 1
}

responds() { timeout 10 stat -t -- "$1" >/dev/null 2>&1; }

# Runs sftp batch CMDS on ALIAS, optionally under a command prefix. SFTP is
# the subsystem sshfs uses, and unlike "ssh host true" it also works for
# keys restricted to command="internal-sftp".
sftp_run() {   # sftp_run ALIAS CMDS [PREFIX...]
    local alias="$1" cmds="$2"
    shift 2
    printf '%s\n' "$cmds" | "$@" sftp -q -b - -S "$SSH_BIN" -o ControlPath=none \
        -o BatchMode=yes -o ConnectTimeout=10 "$alias" >/dev/null 2>&1
}

key_login_works() { sftp_run "$1" pwd; }

# What the systemd service will see: no agent, no desktop session.
unattended_login_works() {
    sftp_run "$1" pwd env -i HOME="$HOME" USER="$USER" PATH=/usr/bin:/bin
}

unit_active()  { systemctl --user is-active  --quiet "$(unit_name "$1")" 2>/dev/null; }
unit_enabled() { systemctl --user is-enabled --quiet "$(unit_name "$1")" 2>/dev/null; }

do_umount() {
    local mp="$1"
    is_mounted "$mp" || return 0
    if run fusermount3 -u -- "$mp" 2>/dev/null; then
        return 0
    fi
    warn "$mp is busy or not responding - detaching it lazily (fusermount3 -uz)"
    run fusermount3 -uz -- "$mp"
}

# Disables and deletes a saved mount's service, if it has one.
drop_unit() {
    local uf
    uf="$(unit_file "$1")"
    [[ -f "$uf" ]] || return 0
    run systemctl --user disable --now "$(unit_name "$1")" 2>/dev/null || true
    run rm -- "$uf"
    run systemctl --user daemon-reload
}

# -------------------------------------------------------------- commands ----
cmd_check() {
    load_state "$1"
    is_mounted "$S_MOUNTPOINT" || die "'$1' is not mounted at $S_MOUNTPOINT" 1
    responds "$S_MOUNTPOINT"   || die "'$1' is mounted but not responding (link down?)" 1
    ok "'$1' is mounted at $S_MOUNTPOINT and responding"
}

cmd_status() {
    local f name state unit
    local files=()
    shopt -s nullglob
    files=("$STATE_DIR"/*.conf)
    shopt -u nullglob
    if (( ${#files[@]} == 0 )); then
        info "No mounts made by $PROG."
        return
    fi
    printf '%-14s %-28s %-24s %-15s %s\n' NAME SOURCE MOUNTPOINT STATE SERVICE
    for f in "${files[@]}"; do
        name="$(basename "$f" .conf)"
        load_state "$name"
        if ! is_mounted "$S_MOUNTPOINT"; then state="not mounted"
        elif responds "$S_MOUNTPOINT";  then state="mounted"
        else                                 state="NOT RESPONDING"
        fi
        unit="-"
        if [[ -f "$(unit_file "$name")" ]]; then
            unit="$(systemctl --user is-enabled "$(unit_name "$name")" 2>/dev/null || true)"
            unit+="/$(systemctl --user is-active "$(unit_name "$name")" 2>/dev/null || true)"
        fi
        printf '%-14s %-28s %-24s %-15s %s\n' "$name" "$S_ALIAS:${S_REMOTE:-~}" \
            "${S_MOUNTPOINT/#"$HOME"/\~}" "$state" "$unit"
    done
}

cmd_umount() {
    load_state "$1"
    if [[ -f "$(unit_file "$1")" ]] && unit_active "$1"; then
        run systemctl --user stop "$(unit_name "$1")"
        if unit_enabled "$1"; then
            info "The service is still enabled; '$1' mounts again at next login. Use --remove to stop that."
        fi
    fi
    do_umount "$S_MOUNTPOINT"
    if ! $DRY_RUN && is_mounted "$S_MOUNTPOINT"; then
        die "$S_MOUNTPOINT is still mounted. Find what holds it: fuser -vm '$S_MOUNTPOINT'" 1
    fi
    ok "Unmounted '$1'"
}

# Never deletes files: rm on a mounted folder deletes them on the server.
cmd_remove() {
    local had_unit=false
    load_state "$1"
    [[ -f "$(unit_file "$1")" ]] && had_unit=true
    drop_unit "$1"
    do_umount "$S_MOUNTPOINT"
    if ! $DRY_RUN && is_mounted "$S_MOUNTPOINT"; then
        die "$S_MOUNTPOINT is still mounted; not touching it. Find what holds it: fuser -vm '$S_MOUNTPOINT'" 1
    fi
    if [[ -d "$S_MOUNTPOINT" ]]; then
        run rmdir -- "$S_MOUNTPOINT" 2>/dev/null \
            || warn "$S_MOUNTPOINT is not empty - left in place"
    fi
    run rm -- "$(state_file "$1")"
    ok "Removed '$1'"
    if $had_unit && linger_on; then
        info "Linger is still on for $USER (other services may rely on it). Turn off with: loginctl disable-linger"
    fi
}

write_state() {
    local f
    f="$(state_file "$1")"
    if $DRY_RUN; then
        printf '%s+ write %s%s\n' "$C_BLD" "$f" "$C_OFF"
        return
    fi
    mkdir -p "$STATE_DIR"
    printf 'ALIAS=%s\nREMOTE=%s\nMOUNTPOINT=%s\n' "$2" "$3" "$4" > "$f"
}

write_unit() {
    local name="$1" alias="$2" remote="$3" mp="$4" opts="$5"
    local f sshfs_bin fm_bin body
    f="$(unit_file "$name")"
    sshfs_bin="$(command -v sshfs)"
    fm_bin="$(command -v fusermount3)"
    # sshfs -f stays in the foreground, so systemd tracks the real process.
    # The lazy unmounts clear a stale "Transport endpoint is not connected"
    # mount left behind by a crash, before start and after stop.
    # sshfs exits 1 on a clean SIGTERM too, so 1 counts as success (no
    # "failed" after a stop) and Restart=always still retries every exit
    # except a deliberate systemctl stop.
    body="$(cat <<EOF
# Written by $PROG on $(date +%F). Remove with: $PROG --remove $name
[Unit]
Description=sshfs $alias:$remote on $mp
StartLimitIntervalSec=0

[Service]
Type=exec
ExecStartPre=-$fm_bin -uz "$mp"
ExecStart=$sshfs_bin -f "$alias:$remote" "$mp" -o $opts
ExecStopPost=-$fm_bin -uz "$mp"
SuccessExitStatus=1
Restart=always
RestartSec=15

[Install]
WantedBy=default.target
EOF
)"
    if $DRY_RUN; then
        printf '%s+ write %s:%s\n%s\n' "$C_BLD" "$f" "$C_OFF" "$body"
        return
    fi
    mkdir -p "$UNIT_DIR"
    printf '%s\n' "$body" > "$f"
    ok "Wrote $f"
}

cmd_add() {
    local alias="${POSITIONAL[0]:-}" remote="${POSITIONAL[1]:-}" name="${POSITIONAL[2]:-}"
    local mp opts i

    [[ -n "$alias" ]] || ask alias "Host alias (from ~/.ssh/config)"
    if [[ ${#POSITIONAL[@]} -lt 2 ]]; then
        ask remote "Remote folder (blank = your home there)"
    fi
    remote="${remote#\~/}"
    [[ "$remote" == "~" ]] && remote=""
    if [[ -z "$name" ]]; then
        name="$alias"
        [[ -n "$remote" ]] && name="$alias-$(basename "$remote")"
        name="${name//[^A-Za-z0-9._-]/-}"
        if [[ ${#POSITIONAL[@]} -lt 2 ]]; then
            ask name "Mount name" "$name"
        fi
    fi

    valid_name "$alias" || die "Alias '$alias' must be letters, digits, dot, dash or underscore"
    valid_name "$name"  || die "Name '$name' must be letters, digits, dot, dash or underscore"
    mp="$(realpath -m -- "${MOUNTPOINT:-$MNT_BASE/$name}")"
    safe_path "$remote" || die "Remote path contains one of: \" \\ \$ % \` or a newline"
    safe_path "$mp"     || die "Mount point contains one of: \" \\ \$ % \` or a newline"
    [[ "$EXTRA_OPTS" =~ ^[A-Za-z0-9_.,=/@:+-]*$ ]] \
        || die "--options '$EXTRA_OPTS' has characters sshfs options never need"

    if [[ -f "$(state_file "$name")" ]]; then
        $FORCE || die "A mount named '$name' exists (use --force to replace it, or --check $name)"
        warn "Replacing '$name' (--force)"
        load_state "$name"
        drop_unit "$name"
        do_umount "$S_MOUNTPOINT"
    fi

    key_login_works "$alias" \
        || die "Key login to '$alias' failed. Set it up first: ./ssh-add-host.sh $alias <host> <user>"
    ok "Key login to '$alias' works"

    if [[ -n "$remote" ]]; then
        sftp_run "$alias" "cd \"$remote\"" \
            || die "'$remote' is not a folder on '$alias'"
        ok "Remote folder '$remote' exists"
    fi

    if $PERSIST; then
        systemctl --user show-environment >/dev/null 2>&1 \
            || die "No systemd user manager reachable (systemctl --user); --persist needs one"
        unattended_login_works "$alias" || die "Key login to '$alias' only works through your agent or desktop session.
       The service runs without either, so it could never mount. Give this
       host a key with no passphrase (see debian-sshfs-mounts.md, section 5):
         ./ssh-add-host.sh -k ~/.ssh/id_ed25519_mount --force $alias <host> <user>"
        ok "Key login works unattended"
    fi

    if $ALLOW_OTHER && ! grep -qE '^[[:space:]]*user_allow_other' /etc/fuse.conf 2>/dev/null; then
        die "--allow-other needs user_allow_other in /etc/fuse.conf:
         sudo sed -i 's/^#[[:space:]]*user_allow_other/user_allow_other/' /etc/fuse.conf"
    fi

    is_mounted "$mp" && die "Something is already mounted at $mp"
    if [[ -d "$mp" && -n "$(ls -A -- "$mp")" ]]; then
        die "$mp is not empty; mounting over it would hide its files"
    fi
    [[ -d "$mp" ]] || run mkdir -p -- "$mp"

    opts="$BASE_OPTS"
    $RO          && opts+=",ro"
    $ALLOW_OTHER && opts+=",allow_other"
    [[ -n "$EXTRA_OPTS" ]] && opts+=",$EXTRA_OPTS"

    write_state "$name" "$alias" "$remote" "$mp"

    if ! $PERSIST; then
        run sshfs "$alias:$remote" "$mp" -o "$opts" \
            || die "sshfs could not mount $alias:${remote:-~} (state kept; retry or --remove $name)" 1
    else
        write_unit "$name" "$alias" "$remote" "$mp" "$opts"
        run systemctl --user daemon-reload
        run systemctl --user enable --now "$(unit_name "$name")"
        if $BOOT; then
            if linger_on; then
                ok "Linger already on: '$name' mounts at boot"
            else
                run loginctl enable-linger "$USER" \
                    || die "loginctl enable-linger failed; try: sudo loginctl enable-linger $USER" 1
                $DRY_RUN || ok "Linger on: '$name' mounts at boot, before you log in"
            fi
        fi
        if ! $DRY_RUN; then
            for (( i = 0; i < 20; i++ )); do
                is_mounted "$mp" && break
                sleep 0.5
            done
        fi
    fi

    $DRY_RUN && return 0
    if is_mounted "$mp" && responds "$mp"; then
        ok "Mounted $alias:${remote:-~} at $mp"
    elif $PERSIST; then
        die "Service started but $mp is not mounted. Look at: journalctl --user -u $(unit_name "$name") -n 20" 1
    else
        die "$mp did not come up" 1
    fi
    if $PERSIST && ! $BOOT; then
        info "Mounts again at every login. Check with: $PROG --status"
    fi
}

# ------------------------------------------------------------------ main ----
command -v ssh         >/dev/null || die "ssh not found: sudo apt install --yes openssh-client"
command -v sshfs       >/dev/null || die "sshfs not found: sudo apt install --yes sshfs"
command -v fusermount3 >/dev/null || die "fusermount3 not found: sudo apt install --yes fuse3"
# sftp runs /usr/bin/ssh by default; sshfs runs whichever ssh is on PATH.
# Hand sftp the same one so the checks test what the mount will use.
SSH_BIN="$(command -v ssh)"

case "$MODE" in
    check|umount|remove) valid_name "$TARGET" || die "Bad name '$TARGET'" ;;
esac

case "$MODE" in
    check)  cmd_check  "$TARGET" ;;
    status) cmd_status ;;
    umount) cmd_umount "$TARGET" ;;
    remove) cmd_remove "$TARGET" ;;
    add)    cmd_add ;;
esac
