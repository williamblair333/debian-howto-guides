#!/bin/bash
# cups-usb-printer-fix.sh - Diagnose and fix CUPS queues pinned to an unstable USB serial
#
# Symptom this solves:
#   A USB printer prints once, then "disappears" after a reboot or power-cycle,
#   and only comes back if you delete and re-add the queue.
#
# Cause:
#   The queue's device URI contains ?serial=XXXX. Some printers report a
#   different USB serial across re-enumerations, so CUPS looks for a device
#   that no longer exists.
#
# Fix:
#   Drop the serial from the URI. The CUPS usb backend then matches any device
#   of that make/model.
#
# After a CUPS major upgrade, re-prove the fix with --test: serial-less matching
# is a property of the current usb backend, not a guarantee.
#
# Full write-up: cups-printer-usb-serial-fix.md

set -euo pipefail

VERSION="1.0.0"
PROG="$(basename "$0")"
LOGFILE="${XDG_CACHE_HOME:-$HOME/.cache}/cups-usb-printer-fix.log"

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
bad()  { printf '%s[FAIL]%s %s\n' "$C_RED" "$C_OFF" "$*"; }
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
Usage: $PROG [OPTIONS]

Diagnose and fix CUPS queues pinned to an unstable USB printer serial number.

With no options: diagnoses every queue, shows the exact fix, and prompts before
applying it.

Options:
  -f, --fix            Apply fixes without prompting (for automation)
  -c, --check          Diagnose only, never write. Exit 1 if any queue needs
                       attention. Cron-safe.
  -p, --printer NAME   Operate on one queue only
  -n, --dry-run        Print the commands that would run, change nothing
      --create NAME    Create a new queue from scratch with a serial-less URI
      --test NAME      Send a test page and verify it completed
      --share NAME     Share one queue on the local network
      --share --all    Share every queue (must be explicit)
      --remote-any     With --share: accept jobs from ANY host, not just the
                       local subnet. Increases exposure - see WARNING below.
  -h, --help           Show this help
  -V, --version        Show version

Exit codes:
  0  clean / success        2  usage error
  1  problems found         3  missing dependency

Examples:
  $PROG                        # diagnose everything, prompt to fix
  $PROG --fix                  # fix everything, no prompt
  $PROG --check                # cron-safe health check, writes nothing
  $PROG -n --fix               # show what --fix would do
  $PROG -p HPLJ --fix          # fix one queue
  $PROG --create HPLJ          # set up a printer correctly on a new machine
  $PROG --test HPLJ            # prove it works with a real page
  $PROG --share HPLJ           # let other computers on this subnet print

WARNING on --remote-any:
  This makes cupsd accept print jobs from any host that can reach it, not just
  your local subnet. If cups-browsed is installed, that daemon has a history of
  remote-input vulnerabilities. Do not use it on an untrusted network.
  Undo with: sudo cupsctl --no-remote-any

Notes:
  * Applying fixes needs the 'lpadmin' group (or root). Sharing needs root.
  * Re-adding a printer through any GUI re-bakes the serial into the URI.
    Re-run this afterwards.
  * 'lpinfo -v' resets HP USB devices, so this script calls it exactly once.
  * Every change is appended to $LOGFILE with the previous URI, so a fix can
    always be rolled back.
EOF
    exit "${1:-0}"
}

# ------------------------------------------------------------- arg parse ----
MODE="interactive"
DRY_RUN=false
TARGET=""
ARG=""
SHARE_ALL=false
REMOTE_ANY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--fix)      MODE="fix"; shift ;;
        -c|--check)    MODE="check"; shift ;;
        -n|--dry-run)  DRY_RUN=true; shift ;;
        --all)         SHARE_ALL=true; shift ;;
        --remote-any)  REMOTE_ANY=true; shift ;;
        -p|--printer)
            [[ $# -ge 2 ]] || die "--printer needs a queue name"
            TARGET="$2"; shift 2 ;;
        --create)
            [[ $# -ge 2 ]] || die "--create needs a queue name"
            MODE="create"; ARG="$2"; shift 2 ;;
        --test)
            [[ $# -ge 2 ]] || die "--test needs a queue name"
            MODE="test"; ARG="$2"; shift 2 ;;
        --share)
            MODE="share"
            if [[ $# -ge 2 && "$2" != -* ]]; then ARG="$2"; shift 2; else shift; fi ;;
        -h|--help)     usage ;;
        -V|--version)  echo "$PROG $VERSION"; exit 0 ;;
        -*)            echo "Unknown option: $1" >&2; echo >&2; usage 2 ;;
        *)             echo "Unexpected argument: $1" >&2; echo >&2; usage 2 ;;
    esac
done

# ----------------------------------------------------------- preflight ------
for c in lpstat lpinfo lpadmin; do
    command -v "$c" >/dev/null 2>&1 || die "'$c' not found. Install cups-client." 3
done
lpstat -r >/dev/null 2>&1 || die "CUPS scheduler is not running (try: sudo systemctl start cups)" 3

can_admin() {
    [[ $EUID -eq 0 ]] && return 0
    id -nG 2>/dev/null | tr ' ' '\n' | grep -qx lpadmin
}

# Mitigation (ENVIRONMENTAL): never block on an invisible sudo password prompt.
as_root() {
    if [[ $EUID -eq 0 ]]; then
        run "$@"
    elif command -v sudo >/dev/null 2>&1 && { sudo -n true 2>/dev/null || [[ -t 0 ]]; }; then
        run sudo "$@"
    else
        die "This needs root and no usable sudo is available (no tty, no cached credential).
      Re-run as root: sudo $PROG ..." 1
    fi
}

# Mitigation (RECOVERY): persist every change so it can be rolled back.
audit() {
    $DRY_RUN && return 0
    mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null || return 0
    printf '%s\t%s\told=%s\tnew=%s\n' \
        "$(date -Is)" "$1" "$2" "$3" >> "$LOGFILE" 2>/dev/null || true
}

# ------------------------------------------------------------- helpers ------
LPINFO_CACHE=""
LPINFO_LOADED=false
lpinfo_v() {
    if ! $LPINFO_LOADED; then
        LPINFO_CACHE="$(lpinfo -v 2>/dev/null || true)"
        LPINFO_LOADED=true
    fi
    printf '%s\n' "$LPINFO_CACHE"
}

queues()    { lpstat -v 2>/dev/null | sed -n 's/^device for \([^:]*\):.*/\1/p'; }
queue_uri() { lpstat -v 2>/dev/null | sed -n "s|^device for $1: ||p" | head -1; }
strip_serial() { printf '%s\n' "${1%%\?*}"; }

# Reduce make/model to a comparable key so hp:/usb/HP_LaserJet_x and
# usb://HP/LaserJet%20x collapse to the same string.
modelkey() {
    printf '%s' "$1" \
        | sed -e 's/?.*$//' -e 's|^[a-z]*:/*||' -e 's|^usb/*||' -e 's/%20/ /g' \
        | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9'
}

usb_devices() { lpinfo_v | sed -n 's/^direct \(usb:\/\/[^ ]*\).*/\1/p'; }

# The distinctive model token from a device URI - the last word containing a
# digit (P1102w, HL-2270DW, ET-2800). Vendors abbreviate the prose around it
# ("LaserJet Professional" in the device vs "LaserJet Pro" in the driver name),
# so the model number is the only reliable join key.
modeltokens() {
    printf '%s' "$1" \
        | sed -e 's/?.*$//' -e 's|^[a-z]*:/*||' -e 's|^usb/*||' \
              -e 's/%20/ /g' -e 's|/| |g' \
        | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9-' ' ' | tr ' ' '\n' \
        | grep '[0-9]' || true
}

# For a device URI the model number is the last digit-bearing token.
modeltoken() { modeltokens "$1" | tail -1; }

# A driver description carries extra digit-bearing noise (foo2zjs-z2, version
# numbers), so match on whether the device's model token appears among its
# tokens rather than on position.
driver_matches() { modeltokens "$1" | grep -Fxq "$2"; }

match_usb_base() {
    local want d base; want="$(modelkey "$1")"
    while read -r d; do
        [[ -n "$d" ]] || continue
        base="$(strip_serial "$d")"
        [[ "$(modelkey "$base")" == "$want" ]] && { printf '%s\n' "$base"; return 0; }
    done < <(usb_devices)
    return 1
}

count_same_model() {
    local want n=0 d; want="$(modelkey "$1")"
    while read -r d; do
        [[ -n "$d" ]] || continue
        [[ "$(modelkey "$(strip_serial "$d")")" == "$want" ]] && n=$((n+1))
    done < <(usb_devices)
    printf '%s\n' "$n"
}

confirm() {
    local reply
    [[ -t 0 ]] || return 1
    read -r -p "$1 [y/N] " reply </dev/tty || return 1
    [[ "$reply" =~ ^[Yy]$ ]]
}

# --------------------------------------------------------------- actions ----
# diagnose() return codes:
#   0 healthy   1 serial-pinned, fixable   2 needs attention, not auto-fixable
#   3 printer absent (informational only - NOT a misconfiguration)
FIX_URI=""
diagnose() {
    local q="$1" uri base n
    FIX_URI=""
    uri="$(queue_uri "$q")"

    [[ -n "$uri" ]] || { warn "$q: no device URI found"; return 2; }

    if [[ "$uri" != usb://* && "$uri" != usb:* && "$uri" != hp:* ]]; then
        ok "$q: not a USB queue - nothing to do"
        return 0
    fi

    if [[ "$uri" != *"?serial="* ]]; then
        # Mitigation (CASCADE): a fixed queue still breaks if a second
        # identical printer appears later. Re-test on every run.
        n="$(count_same_model "$uri")"
        if [[ "$n" -gt 1 ]]; then
            bad "$q: URI has no serial, but $n identical devices are attached."
            info "      Both queues now match the same make/model - jobs may go to"
            info "      the wrong printer. Put one on the network (socket://IP:9100)."
            return 2
        fi
        ok "$q: URI carries no serial - already correct"
        return 0
    fi

    bad "$q: pinned to a serial"
    info "      current: $uri"

    if ! base="$(match_usb_base "$uri")"; then
        # A pinned URI is a real misconfiguration whether or not the printer
        # happens to be attached right now - absence only blocks auto-fixing.
        info "      printer not currently attached - cannot resolve the new URI."
        info "      Power it on and re-run to fix automatically."
        return 2
    fi

    n="$(count_same_model "$uri")"
    if [[ "$n" -gt 1 ]]; then
        warn "$q: $n devices share this make/model."
        warn "      The serial is the only thing telling them apart - refusing to strip it."
        warn "      Put one on the network instead (socket://IP:9100)."
        return 2
    fi

    info "      fix:     $base"
    FIX_URI="$base"
    return 1
}

apply_fix() {
    local q="$1" new="$2" old
    old="$(queue_uri "$q")"
    can_admin || { warn "$q: need root or the 'lpadmin' group to change queues"; return 1; }
    run lpadmin -p "$q" -v "$new" || return 1
    audit "$q" "$old" "$new"
    $DRY_RUN || ok "$q: device URI updated"
    return 0
}

do_scan() {
    local prompt_ok="$1" write="$2"
    local list problems=0 fixed=0 rc

    if [[ -n "$TARGET" ]]; then
        queues | grep -qx "$TARGET" || die "No such queue: $TARGET" 2
        list="$TARGET"
    else
        list="$(queues)"
    fi
    [[ -n "$list" ]] || { warn "No print queues configured."; return 0; }

    while read -r q; do
        [[ -n "$q" ]] || continue
        set +e; diagnose "$q"; rc=$?; set -e
        case "$rc" in
            0) ;;
            2) problems=$((problems+1)) ;;
            1)
                problems=$((problems+1))
                if ! $write; then
                    info "      run: $PROG -p $q --fix"
                elif $prompt_ok && ! $DRY_RUN; then
                    if confirm "      Apply this fix to '$q'?"; then
                        # Mitigation (OBSERVABILITY): one failure must not
                        # abort the scan.
                        set +e; apply_fix "$q" "$FIX_URI"; rc=$?; set -e
                        [[ $rc -eq 0 ]] && { fixed=$((fixed+1)); problems=$((problems-1)); }
                    else
                        info "      skipped"
                    fi
                else
                    set +e; apply_fix "$q" "$FIX_URI"; rc=$?; set -e
                    [[ $rc -eq 0 ]] && { fixed=$((fixed+1)); problems=$((problems-1)); }
                fi
                ;;
        esac
    done <<< "$list"

    echo
    if $DRY_RUN; then
        info "Summary (dry run - nothing changed): ${fixed} would be fixed, ${problems} would still need attention."
    else
        info "Summary: ${fixed} fixed, ${problems} still needing attention."
    fi
    [[ "$problems" -gt 0 ]] && return 1
    ok "Nothing outstanding."
    return 0
}

do_create() {
    local q="$1" dev base drv key n

    can_admin || die "Need root or the 'lpadmin' group to create queues." 1
    if queues | grep -qx "$q"; then
        die "Queue '$q' already exists. Use --fix, or pick another name." 2
    fi

    n="$(usb_devices | grep -c . || true)"
    [[ "$n" -ge 1 ]] || die "No USB printer found. Is it powered on and connected?" 1
    if [[ "$n" -gt 1 ]]; then
        warn "More than one USB printer detected:"
        usb_devices | sed 's/^/      /'
        die "Refusing to guess. Create it manually with the URI you want." 2
    fi

    dev="$(usb_devices | head -1)"
    base="$(strip_serial "$dev")"
    key="$(modeltoken "$base")"
    [[ -n "$key" ]] || key="$(modelkey "$base")"

    # Prefer a driver the distro marks '(recommended)' for this exact model
    # token; fall back to any driver matching the token.
    local matches
    matches="$(lpinfo -m 2>/dev/null | while read -r line; do
                 [[ -n "$line" ]] || continue
                 if driver_matches "$line" "$key"; then
                     printf '%s\t%s\n' "${line%% *}" "${line#* }"
                 fi
               done || true)"

    # Note the trailing '|| true' on each: a non-matching grep returns 1, and
    # under 'set -e' that would abort the script before any diagnostic prints.
    drv="$(printf '%s\n' "$matches" | grep -i 'recommended' | head -1 | cut -f1 || true)"
    [[ -n "$drv" ]] || drv="$(printf '%s\n' "$matches" | grep -v '^[[:space:]]*$' | head -1 | cut -f1 || true)"

    if [[ -z "$drv" ]]; then
        warn "No driver matched model '$key' automatically. Candidates:"
        lpinfo -m 2>/dev/null | grep -i "$key" | sed 's/^/      /' | head -10
        die "Pick one and run: lpadmin -p $q -v '$base' -m <ppd> -E" 1
    fi

    info "Device: $base"
    info "Driver: $drv"
    run lpadmin -p "$q" -v "$base" -m "$drv" -E || die "lpadmin failed" 1
    audit "$q" "(new)" "$base"
    $DRY_RUN && return 0
    ok "Queue '$q' created with a serial-less URI."
    info "Set as default with: lpoptions -d $q"
    info "Prove it works with:  $PROG --test $q"
}

do_share() {
    local q="${1:-}"

    # Mitigation (SECURITY): never share everything implicitly, and never
    # widen to remote-any without an explicit flag.
    if [[ -z "$q" ]] && ! $SHARE_ALL; then
        die "--share needs a queue name, or --all to share every queue.
      Example: $PROG --share HPLJ" 2
    fi

    if $REMOTE_ANY; then
        warn "--remote-any accepts print jobs from ANY host, not just this subnet."
        warn "If cups-browsed is installed, that widens a known remote-input surface."
        if [[ -t 0 ]] && ! $DRY_RUN; then
            confirm "      Continue with --remote-any?" || die "Aborted." 2
        fi
        as_root cupsctl --share-printers --remote-any
    else
        as_root cupsctl --share-printers
    fi

    if [[ -n "$q" ]]; then
        queues | grep -qx "$q" || die "No such queue: $q" 2
        run lpadmin -p "$q" -o printer-is-shared=true || die "lpadmin failed for $q" 1
    else
        while read -r p; do
            [[ -n "$p" ]] || continue
            set +e; run lpadmin -p "$p" -o printer-is-shared=true; set -e
        done <<< "$(queues)"
    fi

    $DRY_RUN && return 0
    local ip; ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    ok "Sharing enabled."
    info "Clients: ipp://${ip:-<this-host>}:631/printers/<queue>"
    $REMOTE_ANY && info "Undo remote access with: sudo cupsctl --no-remote-any"
    return 0
}

do_test() {
    local q="$1" page="/usr/share/cups/data/testprint" job i

    queues | grep -qx "$q" || die "No such queue: $q" 2
    [[ -f "$page" ]] || die "Test page not found at $page" 3

    if $DRY_RUN; then run lp -d "$q" "$page"; return 0; fi

    job="$(lp -d "$q" "$page" 2>&1 | sed -n 's/.*request id is \([^ ]*\).*/\1/p')"
    [[ -n "$job" ]] || die "Failed to submit a job to '$q'" 1
    info "Submitted $job - waiting up to 30s..."

    for i in $(seq 1 15); do
        sleep 2
        if lpstat -W completed -o "$q" 2>/dev/null | grep -q "^$job "; then
            ok "$job completed. Check the output tray for a page."
            return 0
        fi
        lpstat -W not-completed -o "$q" 2>/dev/null | grep -q "^$job " || break
    done

    if lpstat -W not-completed -o "$q" 2>/dev/null | grep -q "^$job "; then
        bad "$job is still queued after 30s - the printer is not accepting data."
        info "Check: lpstat -p $q"
        return 1
    fi
    warn "$job left the queue but was not seen as completed. Check the tray."
    return 0
}

# ------------------------------------------------------------------ main ----
case "$MODE" in
    check)       do_scan false false ;;
    fix)         do_scan false true  ;;
    interactive) do_scan true  true  ;;
    create)      do_create "$ARG" ;;
    share)       do_share "$ARG" ;;
    test)        do_test "$ARG" ;;
esac
