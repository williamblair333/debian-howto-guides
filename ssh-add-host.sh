#!/bin/bash
# ssh-add-host.sh - Add a host to ~/.ssh/config and log in to it with a key
#
# Runs on your workstation, not on the server. One run per host:
#   1. makes an ed25519 key if you don't have one
#   2. writes ~/.ssh/config.d/<alias> (one file per host, easy to remove)
#   3. copies the public key to the host with ssh-copy-id
#   4. proves key login works with BatchMode (no password allowed)
#   5. optionally (--harden) turns off password login on the server,
#      only after step 4 passed
#
# Full write-up: debian-ssh-client-setup.md

set -euo pipefail

VERSION="1.0.0"
PROG="$(basename "$0")"
SSH_DIR="$HOME/.ssh"
CONFIG="$SSH_DIR/config"
CONFIG_D="$SSH_DIR/config.d"
INCLUDE_LINE="Include config.d/*"

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
Usage: $PROG [OPTIONS] [ALIAS HOST [USER] [PORT]]

Add a host to ~/.ssh/config, install your key on it, and prove key login works.
Missing arguments are prompted for.

Arguments:
  ALIAS                Short name you'll type: ssh ALIAS
  HOST                 IP address or hostname (name.local works with mDNS)
  USER                 Login user on the host (default: $USER)
  PORT                 SSH port (default: 22)

Options:
  -k, --key PATH       Private key to use (default: ~/.ssh/id_ed25519)
      --no-copy        Write the config only; don't run ssh-copy-id
      --harden         After key login is proven, disable password and root
                       login on the server for EVERY account (needs sudo there)
  -y, --yes            Don't ask before --harden
      --force          Overwrite an existing config.d/ALIAS file
      --remove ALIAS   Delete config.d/ALIAS and exit
      --check ALIAS    Test key login to ALIAS and exit (0 = works)
  -n, --dry-run        Print what would change; change nothing
  -h, --help           Show this help
  -V, --version        Show version

Examples:
  $PROG                                  # fully interactive
  $PROG pi5 192.168.1.50 bill            # add, copy key, test
  $PROG --harden nas nas.local admin 2222
  $PROG --check pi5
EOF
}

# ------------------------------------------------------------------ args ----
DRY_RUN=false
COPY_KEY=true
HARDEN=false
ASSUME_YES=false
FORCE=false
KEY="$SSH_DIR/id_ed25519"
MODE=add
TARGET=""
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -k|--key)     KEY="${2:?--key needs a path}"; shift 2 ;;
        --no-copy)    COPY_KEY=false; shift ;;
        --harden)     HARDEN=true; shift ;;
        -y|--yes)     ASSUME_YES=true; shift ;;
        --force)      FORCE=true; shift ;;
        --remove)     MODE=remove; TARGET="${2:?--remove needs an alias}"; shift 2 ;;
        --check)      MODE=check;  TARGET="${2:?--check needs an alias}";  shift 2 ;;
        -n|--dry-run) DRY_RUN=true; shift ;;
        -h|--help)    usage; exit 0 ;;
        -V|--version) echo "$PROG $VERSION"; exit 0 ;;
        --)           shift; POSITIONAL+=("$@"); break ;;
        -*)           die "Unknown option: $1 (see --help)" ;;
        *)            POSITIONAL+=("$1"); shift ;;
    esac
done

# --------------------------------------------------------------- helpers ----
valid_alias() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; }

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

# Prints the file that already defines "Host ALIAS", if any.
alias_defined_in() {
    local f
    for f in "$CONFIG" "$CONFIG_D"/*; do
        [[ -f "$f" ]] || continue
        if awk -v a="$1" 'tolower($1)=="host" { for (i=2;i<=NF;i++) if ($i==a) found=1 }
                          END { exit !found }' "$f"; then
            printf '%s\n' "$f"
            return 0
        fi
    done
    return 1
}

# ControlPath=none: always a fresh connection, never a reused master socket.
key_login_works() {
    ssh -o ControlPath=none -o BatchMode=yes -o ConnectTimeout=10 "$1" true 2>/dev/null
}

# -------------------------------------------------------------- commands ----
cmd_check() {
    if key_login_works "$1"; then
        ok "Key login to '$1' works"
        exit 0
    fi
    die "Key login to '$1' failed. Debug with: ssh -v $1" 1
}

cmd_remove() {
    local f="$CONFIG_D/$1"
    [[ -f "$f" ]] || die "No such file: $f"
    run rm -- "$f"
    ok "Removed $f"
    info "The public key is still in ~/.ssh/authorized_keys on the server; remove it there if needed."
}

ensure_ssh_dir() {
    [[ -d "$SSH_DIR" ]] || run mkdir -p "$SSH_DIR"
    run chmod 700 "$SSH_DIR"
    [[ -d "$CONFIG_D" ]] || run mkdir -p "$CONFIG_D"
    run chmod 700 "$CONFIG_D"
}

ensure_key() {
    if [[ -f "$KEY" ]]; then
        ok "Using key $KEY"
        return
    fi
    info "No key at $KEY - creating one. A passphrase is recommended; ssh-agent remembers it."
    run ssh-keygen -t ed25519 -a 64 -f "$KEY" -C "$USER@$(hostname -s)"
    $DRY_RUN || ok "Created $KEY"
}

# "Include" must come before any Host/Match block, or it is scoped to that block.
ensure_include() {
    if [[ -f "$CONFIG" ]] && grep -qxF "$INCLUDE_LINE" "$CONFIG"; then
        local first
        first="$(grep -vE '^[[:space:]]*(#|$)' "$CONFIG" | head -1)"
        [[ "$first" == "$INCLUDE_LINE" ]] \
            || warn "'$INCLUDE_LINE' is in $CONFIG but not first - move it above every Host line"
        return
    fi
    if $DRY_RUN; then
        printf '%s+ prepend "%s" to %s%s\n' "$C_BLD" "$INCLUDE_LINE" "$CONFIG" "$C_OFF"
        return
    fi
    local tmp
    tmp="$(mktemp "$SSH_DIR/config.XXXXXX")"
    { printf '%s\n\n' "$INCLUDE_LINE"; if [[ -f "$CONFIG" ]]; then cat "$CONFIG"; fi; } > "$tmp"
    if [[ -f "$CONFIG" ]]; then
        cp -p "$CONFIG" "$CONFIG.bak.$(date +%Y%m%d%H%M%S)"
    fi
    chmod 600 "$tmp"
    mv "$tmp" "$CONFIG"
    ok "Added '$INCLUDE_LINE' to the top of $CONFIG"
}

write_host_file() {
    local alias="$1" host="$2" user="$3" port="$4"
    local f="$CONFIG_D/$alias"
    local body
    body="$(cat <<EOF
# Written by $PROG on $(date +%F). Remove with: $PROG --remove $alias
Host $alias
    HostName $host
    User $user
    Port $port
    IdentityFile $KEY
    IdentitiesOnly yes
    # Keep idle sessions alive through NAT and Wi-Fi power save
    ServerAliveInterval 30
    ServerAliveCountMax 4
    # Reuse one connection for repeat logins, scp and rsync
    ControlMaster auto
    ControlPath ~/.ssh/cm-%C
    ControlPersist 10m
EOF
)"
    if $DRY_RUN; then
        printf '%s+ write %s:%s\n%s\n' "$C_BLD" "$f" "$C_OFF" "$body"
        return
    fi
    printf '%s\n' "$body" > "$f"
    chmod 600 "$f"
    ok "Wrote $f"
}

harden_server() {
    local alias="$1" ans
    warn "--harden turns off password login for EVERY account on '$alias', not just this one."
    warn "Anyone (or any other machine of yours) without a key installed will be locked out."
    if ! $ASSUME_YES && ! $DRY_RUN; then
        read -r -p "Disable password and root login on '$alias'? [y/N]: " ans
        [[ "$ans" =~ ^[Yy]$ ]] || { info "Skipped hardening."; return; }
    fi
    info "Hardening '$alias' (sudo will prompt there)..."
    # 10- sorts early: sshd keeps the FIRST value it reads, so this beats
    # later drop-ins such as cloud-init's 50-cloud-init.conf.
    local remote
    remote="$(cat <<'EOF'
set -e
f=/etc/ssh/sshd_config.d/10-keys-only.conf
printf '%s\n' '# Written by ssh-add-host.sh --harden' \
    'PasswordAuthentication no' 'KbdInteractiveAuthentication no' \
    'PermitRootLogin no' > "$f"
if ! sshd -t; then rm -f "$f"; echo 'sshd -t failed; change reverted' >&2; exit 1; fi
systemctl reload ssh 2>/dev/null || systemctl reload sshd
sshd -T | grep -E '^(passwordauthentication|kbdinteractiveauthentication|permitrootlogin) '
EOF
)"
    if $DRY_RUN; then
        printf '%s+ ssh -t %s sudo sh -c <<script>>%s\n%s\n' "$C_BLD" "$alias" "$C_OFF" "$remote"
        return
    fi
    ssh -o ControlPath=none -t "$alias" "sudo sh -c $(printf '%q' "$remote")" \
        || die "Hardening failed on '$alias'; password login is unchanged"
    if key_login_works "$alias"; then
        ok "Key login still works after hardening"
    else
        die "Key login FAILED after hardening. From an open session or the console: sudo rm /etc/ssh/sshd_config.d/10-keys-only.conf && sudo systemctl reload ssh" 1
    fi
}

cmd_add() {
    local alias="${POSITIONAL[0]:-}" host="${POSITIONAL[1]:-}"
    local user="${POSITIONAL[2]:-}" port="${POSITIONAL[3]:-}"

    [[ -n "$alias" ]] || ask alias "Alias (what you'll type after ssh)"
    [[ -n "$host"  ]] || ask host  "IP address or hostname"
    if [[ ${#POSITIONAL[@]} -lt 2 ]]; then
        [[ -n "$user" ]] || ask user "Login user" "$USER"
        [[ -n "$port" ]] || ask port "Port" "22"
    fi
    user="${user:-$USER}"
    port="${port:-22}"

    valid_alias "$alias" || die "Alias '$alias' must be letters, digits, dot, dash or underscore"
    [[ -n "$host" ]]     || die "Host is required"
    if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        die "Port '$port' is not 1-65535"
    fi

    local existing
    if existing="$(alias_defined_in "$alias")"; then
        if [[ "$existing" == "$CONFIG_D/$alias" ]] && $FORCE; then
            warn "Overwriting $existing (--force)"
        elif [[ "$existing" == "$CONFIG_D/$alias" ]]; then
            die "'$alias' already exists in $existing (use --force to overwrite, or --check $alias)"
        else
            die "'$alias' is already defined in $existing - edit or remove it there first"
        fi
    fi

    ensure_ssh_dir
    ensure_key
    ensure_include
    write_host_file "$alias" "$host" "$user" "$port"

    if ! $COPY_KEY; then
        info "Skipped ssh-copy-id (--no-copy). Test later with: $PROG --check $alias"
        return
    fi

    if ! $DRY_RUN && key_login_works "$alias"; then
        ok "Key already accepted by '$alias'"
    else
        info "Copying ${KEY}.pub to '$alias' - enter the account password once:"
        run ssh-copy-id -o ControlPath=none -i "${KEY}.pub" "$alias"
    fi

    if $DRY_RUN; then
        printf '%s+ ssh -o BatchMode=yes %s true%s\n' "$C_BLD" "$alias" "$C_OFF"
    elif key_login_works "$alias"; then
        ok "Key login works: ssh $alias"
    else
        die "Key login to '$alias' failed after copying the key. Debug with: ssh -v $alias" 1
    fi

    if $HARDEN; then
        harden_server "$alias"
    fi
}

# ------------------------------------------------------------------ main ----
command -v ssh >/dev/null || die "ssh not found: sudo apt install --yes openssh-client"

case "$MODE" in
    check)  cmd_check "$TARGET" ;;
    remove) valid_alias "$TARGET" || die "Bad alias '$TARGET'"; cmd_remove "$TARGET" ;;
    add)    cmd_add ;;
esac
