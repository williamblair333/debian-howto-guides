# Remmina RDP Setup Guide for MX Linux Trixie

## Client Setup (Your Machine)

### Install Remmina with RDP Support
```bash
sudo apt update
sudo apt install --yes remmina remmina-plugin-rdp
```

### Launch Remmina
```bash
remmina &
```

### Connect to Windows Machine

1. Click **+** (New connection)
2. **Protocol**: RDP - Remote Desktop Protocol
3. **Server**: `192.168.1.100:3389` (Windows IP)
4. **Username**: Windows username
5. **Password**: Windows password
6. **Color depth**: True color (24 bpp) or better
7. **Resolution**: Use client resolution or custom
8. **Advanced** tab:
   - Quality: Best (LAN)
   - Security: Negotiate
9. Save and connect

### Connect to Linux XRDP Server

Same as Windows, but:
- **Username**: Linux username on remote box
- **Password**: Linux user password
- **Note**: First login creates session, logout properly to avoid stuck sessions

---

## Server Setup (Remote Linux Box)

### Install XRDP on Remote Linux Server
```bash
sudo apt update
sudo apt install xrdp xorgxrdp
```

### Enable and Start XRDP
```bash
sudo systemctl enable xrdp
sudo systemctl start xrdp
```

### Verify XRDP is Running
```bash
sudo systemctl status xrdp
ss -tlnp | grep 3389
```

Should show XRDP listening on port 3389.

### Configure Desktop Environment

Create `~/.xsession` on the **remote server** for your user:
```bash
# For Xfce (MX Linux default)
echo "startxfce4" > ~/.xsession

# For MATE
# echo "mate-session" > ~/.xsession

# For KDE
# echo "startkde" > ~/.xsession

chmod +x ~/.xsession
```

### Firewall Configuration (if enabled)
```bash
# UFW
sudo ufw allow 3389/tcp

# Firewalld
sudo firewall-cmd --permanent --add-port=3389/tcp
sudo firewall-cmd --reload
```

### Security Hardening (Optional but Recommended)

**Restrict to LAN only** - Edit `/etc/xrdp/xrdp.ini`:
```ini
[Globals]
address=192.168.1.0
port=3389
```

**Use certificate** (auto-generated on install):
```bash
sudo ls -l /etc/xrdp/cert.pem /etc/xrdp/key.pem
```

**Restart after config changes:**
```bash
sudo systemctl restart xrdp
```

---

## Troubleshooting

### Can't Connect
```bash
# On server, check logs
sudo journalctl -u xrdp -f

# Check if listening
sudo ss -tlnp | grep 3389

# Test from client
telnet server-ip 3389
```

### Black Screen After Login
```bash
# On server, ensure ~/.xsession exists and is executable
ls -l ~/.xsession

# Check XRDP logs
cat /var/log/xrdp.log
cat /var/log/xrdp-sesman.log
```

### Session Already Active Error

Previous session didn't terminate properly:
```bash
# On server, kill user sessions
pkill -u username -9

# Or reboot the server
sudo systemctl reboot
```

### Keyboard Layout Wrong

In Remmina connection settings:
- **Advanced** → **Keyboard layout**: `en-us` (or your layout)

---

## Performance Tuning

### Remmina Client Settings

For **LAN** (fast):
- Color depth: True color (32 bpp)
- Quality: Best
- Disable compression

For **WAN/slow links**:
- Color depth: True color (16 bpp)
- Quality: Medium or Poor
- Enable compression
- Disable wallpaper/animations

### XRDP Server Optimization

Edit `/etc/xrdp/xrdp.ini`:
```ini
[Globals]
max_bpp=32
xserverbpp=24
```

Restart XRDP:
```bash
sudo systemctl restart xrdp
```

---

## Quick Reference

### Client Commands
```bash
# Install Remmina
sudo apt install remmina remmina-plugin-rdp

# Launch
remmina &
```

### Server Commands
```bash
# Install XRDP
sudo apt install xrdp xorgxrdp

# Enable/start service
sudo systemctl enable --now xrdp

# Check status
sudo systemctl status xrdp

# View logs
sudo journalctl -u xrdp -f
sudo tail -f /var/log/xrdp.log

# Restart service
sudo systemctl restart xrdp
```

### Connection String Format
```
rdp://username:password@192.168.1.100:3389
```

Can use this in Remmina's quick connect bar.

---

## Notes

- **Port 3389** must be accessible (firewall/network)
- **First connection** to XRDP server creates desktop session
- **Always logout properly** from XRDP to avoid stuck sessions
- **Windows RDP** works out of the box, no server setup needed
- **MX Linux** uses Xfce by default - ensure `startxfce4` in `~/.xsession`
