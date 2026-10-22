# debian-howto-guides — run `just` for this list.
# Each recipe is one line; the logic lives in the scripts it calls.

# list recipes
default:
    @just --list

# add a host to ~/.ssh/config with key login (--harden, --check, --remove)
ssh-host *args:
    ./ssh-add-host.sh {{args}}

# mount a server folder via sshfs (--ro, --persist, --boot, --status, --remove)
sshfs-mount *args:
    ./sshfs-add-mount.sh {{args}}

# diagnose/fix a USB printer that vanishes after reboot (--check, --fix, --create, --test)
printer-fix *args:
    ./cups-usb-printer-fix.sh {{args}}

# KDE/Plasma package completeness audit
kde-audit:
    bash kde-audit.sh

# force the backlight to maximum (needs sudo)
brightness-max:
    sudo ./brightness_set_max.sh
