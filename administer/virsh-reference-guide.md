# 🖥️ Virsh Reference Guide for KVM/QEMU Administration

```
╔═══════════════════════════════════════════════════════════════╗
║  Complete Virsh Command Reference for Daily Operations       ║
║  Target: RHEL/Rocky Linux KVM Administrators                  ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 📋 Quick Navigation

| Section | Description |
|:--------|:------------|
| [1. VM Lifecycle](#-1-vm-lifecycle-management) | Start, stop, reboot, autostart |
| [2. VM Information](#-2-vm-information--listing) | List, info, status queries |
| [3. Snapshots](#-3-snapshot-management) | Create, restore, delete snapshots |
| [4. Storage](#-4-storage-management) | Pools, volumes, disk operations |
| [5. Networking](#-5-network-management) | Networks, bridges, DHCP |
| [6. Resource Management](#-6-resource-management) | CPU, memory, disk adjustments |
| [7. Console Access](#-7-console--display-access) | VNC, serial console, graphics |
| [8. Cloning & Migration](#-8-vm-cloning--migration) | Clone VMs, live migration |
| [9. Backup & Export](#-9-backup--export) | XML export, disk backup |
| [10. Troubleshooting](#-10-troubleshooting) | Common issues and fixes |

---

## 🚀 1. VM Lifecycle Management

### Start, Stop, and Restart VMs

```bash
# Start a VM
virsh start <vm-name>

# Start a VM and attach to console
virsh start <vm-name> --console

# Graceful shutdown (requires guest agent or ACPI)
virsh shutdown <vm-name>

# Force power off (like pulling the plug)
virsh destroy <vm-name>

# Reboot VM (graceful)
virsh reboot <vm-name>

# Force reset (hard reboot)
virsh reset <vm-name>

# Suspend (save state to RAM)
virsh suspend <vm-name>

# Resume from suspension
virsh resume <vm-name>

# Save VM state to disk (hibernate)
virsh save <vm-name> /var/lib/libvirt/images/<vm-name>.save

# Restore VM from saved state
virsh restore /var/lib/libvirt/images/<vm-name>.save
```

### Autostart Configuration

```bash
# Enable autostart (VM starts on host boot)
virsh autostart <vm-name>

# Disable autostart
virsh autostart <vm-name> --disable

# Check autostart status
virsh dominfo <vm-name> | grep Autostart
```

### Delete/Remove VMs

```bash
# Undefine VM (removes config, keeps disks)
virsh undefine <vm-name>

# Undefine and remove all storage
virsh undefine <vm-name> --remove-all-storage

# Undefine and remove snapshots
virsh undefine <vm-name> --snapshots-metadata

# Complete removal (config + disks + snapshots)
virsh undefine <vm-name> --remove-all-storage --snapshots-metadata
```

---

## 📊 2. VM Information & Listing

### List VMs

```bash
# List all running VMs
virsh list

# List all VMs (running and stopped)
virsh list --all

# List inactive (stopped) VMs only
virsh list --inactive

# List with autostart status
virsh list --all --autostart

# List with UUID
virsh list --all --uuid

# List with title and description
virsh list --all --title
```

### VM Details

```bash
# Show VM configuration summary
virsh dominfo <vm-name>

# Show VM state only
virsh domstate <vm-name>

# Show VM ID (when running)
virsh domid <vm-name>

# Show VM UUID
virsh domuuid <vm-name>

# Show VM block devices
virsh domblklist <vm-name>

# Show VM network interfaces
virsh domiflist <vm-name>

# Show VM statistics
virsh domstats <vm-name>

# Show CPU statistics
virsh cpu-stats <vm-name>

# Show memory statistics
virsh dommemstat <vm-name>

# Show disk I/O statistics
virsh domblkstat <vm-name> vda

# Show network I/O statistics
virsh domifstat <vm-name> vnet0
```

### XML Configuration

```bash
# Dump full VM XML configuration
virsh dumpxml <vm-name>

# Dump XML to file
virsh dumpxml <vm-name> > <vm-name>.xml

# Dump XML without MAC addresses (useful for cloning)
virsh dumpxml <vm-name> --inactive

# Edit VM configuration
virsh edit <vm-name>

# Validate VM configuration
virsh validate <vm-name>
```

---

## 📸 3. Snapshot Management

### Create Snapshots

```bash
# Create snapshot with automatic name
virsh snapshot-create-as <vm-name>

# Create snapshot with custom name and description
virsh snapshot-create-as <vm-name> \
  snapshot-name \
  "Description of this snapshot"

# Create snapshot while VM is running (live snapshot)
virsh snapshot-create-as <vm-name> snap1 "Before update"

# Create snapshot with specific disk only
virsh snapshot-create-as <vm-name> snap2 \
  --description "System disk only" \
  --diskspec vda,snapshot=external

# Create snapshot from XML file
virsh snapshot-create <vm-name> snapshot.xml
```

### List Snapshots

```bash
# List all snapshots for a VM
virsh snapshot-list <vm-name>

# List snapshots with creation time
virsh snapshot-list <vm-name> --tree

# List snapshot names only
virsh snapshot-list <vm-name> --name

# Show current snapshot
virsh snapshot-current <vm-name>

# Count total snapshots
virsh snapshot-list <vm-name> | wc -l
```

### View Snapshot Details

```bash
# Show snapshot information
virsh snapshot-info <vm-name> snapshot-name

# Show snapshot XML configuration
virsh snapshot-dumpxml <vm-name> snapshot-name

# Show parent snapshot
virsh snapshot-parent <vm-name> snapshot-name
```

### Restore/Revert to Snapshots

```bash
# Revert to most recent snapshot
virsh snapshot-revert <vm-name> --current

# Revert to specific snapshot
virsh snapshot-revert <vm-name> snapshot-name

# Revert and start VM if it was running
virsh snapshot-revert <vm-name> snapshot-name --running

# Revert and force (even if VM is running)
virsh snapshot-revert <vm-name> snapshot-name --force
```

### Delete Snapshots

```bash
# Delete specific snapshot
virsh snapshot-delete <vm-name> snapshot-name

# Delete snapshot and all children
virsh snapshot-delete <vm-name> snapshot-name --children

# Delete snapshot metadata only (keep disk files)
virsh snapshot-delete <vm-name> snapshot-name --metadata

# Delete all snapshots for a VM
for snap in $(virsh snapshot-list <vm-name> --name); do
  virsh snapshot-delete <vm-name> "$snap"
done
```

### Snapshot Example Workflow

```bash
# 1. Create baseline snapshot
virsh snapshot-create-as myvm baseline "Clean install"

# 2. Make changes to VM
# ... do work ...

# 3. Create snapshot after changes
virsh snapshot-create-as myvm post-update "After package updates"

# 4. List snapshots to verify
virsh snapshot-list myvm

# 5. Test changes, if bad, rollback
virsh snapshot-revert myvm baseline --running

# 6. If good, delete old snapshot
virsh snapshot-delete myvm baseline
```

---

## 💾 4. Storage Management

### Storage Pools

```bash
# List all storage pools
virsh pool-list --all

# Show storage pool details
virsh pool-info <pool-name>

# Show pool XML configuration
virsh pool-dumpxml <pool-name>

# Start storage pool
virsh pool-start <pool-name>

# Enable pool autostart
virsh pool-autostart <pool-name>

# Refresh pool (rescan for new volumes)
virsh pool-refresh <pool-name>

# Stop storage pool
virsh pool-destroy <pool-name>

# Delete storage pool
virsh pool-delete <pool-name>

# Undefine storage pool
virsh pool-undefine <pool-name>
```

### Create Storage Pools

```bash
# Create directory-based pool
virsh pool-define-as mypool dir \
  --target /var/lib/libvirt/images/mypool

# Create LVM-based pool
virsh pool-define-as lvmpool logical \
  --source-name vg_vms \
  --target /dev/vg_vms

# Create NFS-based pool
virsh pool-define-as nfspool netfs \
  --source-host nfs.example.com \
  --source-path /exports/vms \
  --target /mnt/nfs-vms

# Build and start new pool
virsh pool-build mypool
virsh pool-start mypool
virsh pool-autostart mypool
```

### Volume Management

```bash
# List volumes in a pool
virsh vol-list <pool-name>

# Show volume details
virsh vol-info <volume-name> --pool <pool-name>

# Show volume path
virsh vol-path <volume-name> --pool <pool-name>

# Create new volume (qcow2)
virsh vol-create-as <pool-name> <vol-name>.qcow2 20G \
  --format qcow2

# Create new volume (raw)
virsh vol-create-as <pool-name> <vol-name>.img 20G \
  --format raw

# Clone volume
virsh vol-clone <source-vol> <new-vol> --pool <pool-name>

# Delete volume
virsh vol-delete <volume-name> --pool <pool-name>

# Wipe volume (secure delete)
virsh vol-wipe <volume-name> --pool <pool-name>

# Resize volume
virsh vol-resize <volume-name> 30G --pool <pool-name>
```

### Disk Operations on Running VMs

```bash
# Attach new disk to running VM
virsh attach-disk <vm-name> \
  /var/lib/libvirt/images/newdisk.qcow2 vdb \
  --driver qemu \
  --subdriver qcow2 \
  --persistent

# Detach disk from running VM
virsh detach-disk <vm-name> vdb --persistent

# Resize VM disk (VM must be off)
virsh shutdown <vm-name>
qemu-img resize /var/lib/libvirt/images/vm-disk.qcow2 +10G
virsh start <vm-name>

# Check disk usage
virsh domblkinfo <vm-name> vda

# Live block commit (merge snapshot into base)
virsh blockcommit <vm-name> vda --active --pivot
```

---

## 🌐 5. Network Management

### List Networks

```bash
# List all networks
virsh net-list --all

# Show network details
virsh net-info <network-name>

# Show network XML configuration
virsh net-dumpxml <network-name>

# Show DHCP leases
virsh net-dhcp-leases <network-name>
```

### Network Lifecycle

```bash
# Start network
virsh net-start <network-name>

# Enable network autostart
virsh net-autostart <network-name>

# Stop network
virsh net-destroy <network-name>

# Delete network
virsh net-undefine <network-name>
```

### Create Networks

```bash
# Create NAT network
cat > nat-network.xml <<EOF
<network>
  <name>nat-network</name>
  <forward mode='nat'/>
  <bridge name='virbr1' stp='on' delay='0'/>
  <ip address='192.168.100.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.100.100' end='192.168.100.200'/>
    </dhcp>
  </ip>
</network>
EOF

virsh net-define nat-network.xml
virsh net-start nat-network
virsh net-autostart nat-network

# Create isolated network (no external access)
cat > isolated-network.xml <<EOF
<network>
  <name>isolated-net</name>
  <bridge name='virbr2' stp='on' delay='0'/>
  <ip address='192.168.200.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.200.50' end='192.168.200.150'/>
    </dhcp>
  </ip>
</network>
EOF

virsh net-define isolated-network.xml
virsh net-start isolated-net
```

### VM Network Interface Management

```bash
# List VM network interfaces
virsh domiflist <vm-name>

# Show interface statistics
virsh domifstat <vm-name> vnet0

# Attach new network interface
virsh attach-interface <vm-name> network default \
  --model virtio \
  --persistent

# Detach network interface
virsh detach-interface <vm-name> network --mac 52:54:00:xx:xx:xx

# Change network interface link state
virsh domif-setlink <vm-name> vnet0 down
virsh domif-setlink <vm-name> vnet0 up

# Get interface MAC address
virsh domiflist <vm-name> | grep vnet0

# Update interface bandwidth
virsh domiftune <vm-name> vnet0 --inbound 100,200,300 --outbound 100,200,300
```

---

## ⚙️ 6. Resource Management

### CPU Management

```bash
# Show CPU count
virsh vcpucount <vm-name>

# Show current CPU pinning
virsh vcpupin <vm-name>

# Pin vCPU to physical CPU
virsh vcpupin <vm-name> 0 1-2

# Set vCPU count (VM must be off)
virsh setvcpus <vm-name> 4 --config --maximum
virsh setvcpus <vm-name> 4 --config

# Hot-plug vCPUs (add while running)
virsh setvcpus <vm-name> 4 --live

# Show CPU statistics
virsh cpu-stats <vm-name>
```

### Memory Management

```bash
# Show current memory allocation
virsh dommemstat <vm-name>

# Set maximum memory (VM must be off)
virsh setmaxmem <vm-name> 4G --config

# Set current memory
virsh setmem <vm-name> 2G --config

# Live memory adjustment (balloon)
virsh setmem <vm-name> 2G --live

# Show memory statistics
virsh dommemstat <vm-name>
```

### Resource Limits

```bash
# Set CPU shares (relative weight)
virsh schedinfo <vm-name> --set cpu_shares=2048

# Set CPU quota (% of one physical CPU)
virsh schedinfo <vm-name> --set vcpu_quota=80000

# Set block I/O weight
virsh blkiotune <vm-name> --weight 500

# Set network bandwidth
virsh domiftune <vm-name> vnet0 \
  --inbound 100,200,300 \
  --outbound 100,200,300
```

---

## 🖥️ 7. Console & Display Access

### Console Access

```bash
# Connect to VM serial console
virsh console <vm-name>

# Exit console: Ctrl + ]

# Enable serial console in VM (Rocky/RHEL)
# Add to /etc/default/grub:
# GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8"
# Then: grub2-mkconfig -o /boot/grub2/grub.cfg
```

### VNC/Graphics Access

```bash
# Show VNC display port
virsh vncdisplay <vm-name>

# Show graphics info
virsh domdisplay <vm-name>

# Change VNC password
virsh domsetpass <vm-name> --password "newpassword"

# Disable VNC graphics (edit XML)
virsh edit <vm-name>
# Remove or comment out <graphics type='vnc'.../>
```

### Screenshot

```bash
# Capture VM screenshot
virsh screenshot <vm-name> /tmp/vm-screenshot.ppm

# Convert to PNG (requires ImageMagick)
convert /tmp/vm-screenshot.ppm /tmp/vm-screenshot.png
```

---

## 📋 8. VM Cloning & Migration

### Clone VMs

```bash
# Clone VM (full copy)
virt-clone \
  --original <source-vm> \
  --name <new-vm> \
  --auto-clone

# Clone with specific disk location
virt-clone \
  --original <source-vm> \
  --name <new-vm> \
  --file /var/lib/libvirt/images/<new-vm>.qcow2

# Clone without storage (linked clone)
virt-clone \
  --original <source-vm> \
  --name <new-vm> \
  --preserve-data
```

### Migration

```bash
# Live migration to another host
virsh migrate --live <vm-name> qemu+ssh://desthost/system

# Offline migration
virsh migrate <vm-name> qemu+ssh://desthost/system

# Migration with storage
virsh migrate --live <vm-name> \
  qemu+ssh://desthost/system \
  --copy-storage-all

# Migration with specific URI
virsh migrate --live <vm-name> \
  qemu+ssh://user@desthost/system \
  --persistent \
  --undefinesource
```

---

## 💼 9. Backup & Export

### Export VM Configuration

```bash
# Export VM XML definition
virsh dumpxml <vm-name> > /backups/<vm-name>.xml

# Export without MAC/UUID (for portability)
virsh dumpxml <vm-name> --inactive | \
  grep -v '<uuid>' | \
  grep -v '<mac address' > /backups/<vm-name>-clean.xml

# Import VM from XML
virsh define /backups/<vm-name>.xml
```

### Backup VM Disks

```bash
# Backup disk with VM shutdown
virsh shutdown <vm-name>
cp /var/lib/libvirt/images/<vm-name>.qcow2 \
   /backups/<vm-name>-$(date +%F).qcow2
virsh start <vm-name>

# Backup disk while VM is running (create snapshot first)
virsh snapshot-create-as <vm-name> backup-snapshot "Pre-backup snapshot"
cp /var/lib/libvirt/images/<vm-name>.qcow2 /backups/
virsh snapshot-delete <vm-name> backup-snapshot

# Use qemu-img for efficient backup (sparse files)
qemu-img convert -O qcow2 \
  /var/lib/libvirt/images/<vm-name>.qcow2 \
  /backups/<vm-name>-compressed.qcow2
```

### Complete Backup Script

```bash
#!/bin/bash
VM_NAME="$1"
BACKUP_DIR="/backups/vms"
DATE=$(date +%F-%H%M)

mkdir -p "$BACKUP_DIR/$VM_NAME"

# Export XML
virsh dumpxml "$VM_NAME" > "$BACKUP_DIR/$VM_NAME/${VM_NAME}-${DATE}.xml"

# Create snapshot
virsh snapshot-create-as "$VM_NAME" "backup-$DATE" "Automated backup"

# Backup disks
for disk in $(virsh domblklist "$VM_NAME" --details | grep disk | awk '{print $4}'); do
    filename=$(basename "$disk")
    cp "$disk" "$BACKUP_DIR/$VM_NAME/${filename}-${DATE}"
done

# Delete snapshot
virsh snapshot-delete "$VM_NAME" "backup-$DATE"

echo "Backup completed: $BACKUP_DIR/$VM_NAME/"
```

---

## 🔧 10. Troubleshooting

### Common Issues

```bash
# VM won't start - check logs
virsh start <vm-name>
journalctl -u libvirtd -f

# Check VM configuration for errors
virt-xml-validate /etc/libvirt/qemu/<vm-name>.xml

# Reset VM (hard reset)
virsh destroy <vm-name>
virsh start <vm-name>

# Check if VM is responsive
virsh domstate <vm-name>

# Check resource usage
virsh domstats <vm-name>
virsh dommemstat <vm-name>
virsh cpu-stats <vm-name>
```

### Network Troubleshooting

```bash
# Check network status
virsh net-list --all

# Restart default network
virsh net-destroy default
virsh net-start default

# Check bridge configuration
ip link show virbr0
brctl show

# Check DHCP leases
virsh net-dhcp-leases default

# Verify VM can reach network
virsh domiflist <vm-name>
virsh console <vm-name>
# Inside VM: ip addr, ping 8.8.8.8
```

### Storage Troubleshooting

```bash
# Check pool status
virsh pool-list --all

# Refresh pool if volumes missing
virsh pool-refresh default

# Check disk permissions
ls -la /var/lib/libvirt/images/

# Fix permissions
chown qemu:qemu /var/lib/libvirt/images/*.qcow2

# Check disk integrity
qemu-img check /var/lib/libvirt/images/<vm-name>.qcow2

# Get disk info
qemu-img info /var/lib/libvirt/images/<vm-name>.qcow2
```

### Service Management

```bash
# Restart libvirt daemon
systemctl restart libvirtd

# Check libvirt status
systemctl status libvirtd

# Enable debug logging
virsh log-level debug

# View logs
journalctl -u libvirtd -xe
```

---

## 🔐 11. Security & Permissions

### SELinux Contexts

```bash
# Check SELinux context
ls -Z /var/lib/libvirt/images/

# Restore default contexts
restorecon -Rv /var/lib/libvirt/images/

# Set custom context
chcon -t virt_image_t /var/lib/libvirt/images/<vm-name>.qcow2
```

### User Permissions

```bash
# Add user to libvirt group
usermod -aG libvirt username

# Grant user KVM access
usermod -aG kvm username

# Check access
groups username
```

---

## 📝 12. Useful One-Liners

```bash
# List all VMs with their state
virsh list --all | tail -n +3 | awk '{print $2, $3}'

# Get all VM IP addresses
for vm in $(virsh list --name); do
    echo -n "$vm: "
    virsh domifaddr "$vm" | grep -oP '(\d+\.){3}\d+'
done

# Shutdown all running VMs
virsh list --name | xargs -I {} virsh shutdown {}

# Start all VMs with autostart enabled
for vm in $(virsh list --all --autostart --name); do
    virsh start "$vm"
done

# Check disk usage for all VMs
for vm in $(virsh list --all --name); do
    echo "=== $vm ==="
    virsh domblklist "$vm" --details
done

# Generate VM inventory
virsh list --all | awk 'NR>2 {print $2}' | while read vm; do
    echo "VM: $vm"
    virsh dominfo "$vm" | grep -E "CPU|Memory|State"
    echo ""
done

# Find VMs using specific network
virsh list --all --name | while read vm; do
    virsh domiflist "$vm" | grep -q "default" && echo "$vm"
done

# Backup all VM configs
for vm in $(virsh list --all --name); do
    virsh dumpxml "$vm" > "/backups/${vm}-$(date +%F).xml"
done
```

---

## 📚 Quick Reference Tables

### VM States

| State | Description |
|:------|:------------|
| `running` | VM is actively running |
| `paused` | VM is suspended (RAM preserved) |
| `shut off` | VM is powered off |
| `crashed` | VM has crashed |
| `pmsuspended` | VM is suspended to disk |
| `in shutdown` | VM is shutting down |

### Common Options

| Option | Description |
|:-------|:------------|
| `--live` | Apply changes to running VM |
| `--config` | Save to config (persistent) |
| `--current` | Apply to current state |
| `--persistent` | Make changes permanent |
| `--force` | Force operation |
| `--all` | Apply to all VMs/resources |

### Exit Codes

| Code | Meaning |
|:-----|:--------|
| `0` | Success |
| `1` | General error |
| `2` | Invalid command |
| `3` | Connection failed |

---

## 🎯 Best Practices Checklist

```
[ ] Always use snapshots before major changes
[ ] Test VM operations in non-production first
[ ] Document custom VM configurations
[ ] Regular backups of VM XML configs
[ ] Monitor disk space in storage pools
[ ] Keep QEMU/KVM packages updated
[ ] Use descriptive VM and snapshot names
[ ] Enable autostart only for critical VMs
[ ] Set resource limits appropriately
[ ] Use graceful shutdown before destroy
[ ] Verify backups with test restores
[ ] Keep libvirt logs for troubleshooting
```

---

## 📖 Additional Resources

- **Official Docs**: https://libvirt.org/manpages/virsh.html
- **Red Hat Virtualization Guide**: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/configuring_and_managing_virtualization/
- **KVM Forum**: https://www.linux-kvm.org/
- **Community Wiki**: https://wiki.libvirt.org/

---

**Document Version**: 1.0  
**Last Updated**: January 2026  
**Target Platform**: RHEL 9/10, Rocky Linux 9/10, Fedora 39+

---

```
╔═══════════════════════════════════════════════════════════════╗
║  Pro Tip: Always test destructive operations in a test       ║
║  environment first. Use `--help` after any command for        ║
║  detailed options. Happy virtualizing! 🚀                     ║
╚═══════════════════════════════════════════════════════════════╝
```
