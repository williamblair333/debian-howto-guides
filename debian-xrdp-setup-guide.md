# XRDP Setup Guide for MX Linux

> **Complete guide for setting up XRDP remote desktop on MX Linux with XFCE**
> 
> Tested on: MX Linux (Debian Trixie-based) with systemd and XFCE desktop

---

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Firewall Setup](#firewall-setup)
- [Testing the Connection](#testing-the-connection)
- [Troubleshooting](#troubleshooting)
- [Optional Enhancements](#optional-enhancements)
- [Security Considerations](#security-considerations)
- [References](#references)

---

## 🎯 Overview

XRDP is an open-source implementation of Microsoft's Remote Desktop Protocol (RDP), allowing you to remotely access your Linux desktop from Windows, macOS, or Linux clients using standard RDP clients.

### What You'll Get

- Full XFCE desktop environment accessible remotely
- Support for multiple concurrent user sessions
- Audio redirection support
- Clipboard sharing between local and remote machines
- Native RDP client compatibility (no VNC needed)

### Important Notes

- XRDP creates **separate sessions** from your physical login
- Each RDP connection gets its own display number (`:10`, `:11`, etc.)
- This guide uses only official MX/Debian repository packages

---

## ✅ Prerequisites

### System Requirements

- MX Linux with systemd enabled
- XFCE desktop environment installed
- Sudo/root access
- Network connectivity

### Verify Your System

```bash
# Check distro and version
cat /etc/os-release

# Confirm desktop environment
echo $XDG_CURRENT_DESKTOP
# Should output: XFCE

# Verify systemd is active
pidof systemd && echo "systemd is running"
```

---

## 📦 Installation

### Step 1: Update Package Lists and Install XRDP

```bash
sudo apt update
sudo apt install -y xrdp xorgxrdp
```

**What gets installed:**
- `xrdp` - The main RDP server
- `xorgxrdp` - Xorg server module for XRDP (prevents black screen issues)

### Step 2: Verify Installation

```bash
# Check if services are installed
systemctl status xrdp --no-pager
systemctl status xrdp-sesman --no-pager

# Verify XRDP is listening on port 3389
sudo ss -tlnp | grep 3389
```

---

## ⚙️ Configuration

### Step 1: Allow Non-Console X Sessions

By default, X server on Debian/MX is restricted to console use only. XRDP needs to start X sessions for remote users.

```bash
# Edit Xwrapper configuration
sudo sed -i 's/^allowed_users=.*/allowed_users=anybody/' /etc/X11/Xwrapper.config

# Verify the change
grep allowed_users /etc/X11/Xwrapper.config
```

**Expected output:** `allowed_users=anybody`

### Step 2: Create Session Startup File

Create a `~/.xsession` file to tell XRDP which desktop environment to launch.

```bash
# For XFCE (use exec to ensure proper session management)
echo "exec xfce4-session" > ~/.xsession

# Set correct permissions
chmod 644 ~/.xsession
chmod 755 ~/

# Verify the file
cat ~/.xsession
```

**⚠️ Critical Detail:** Use `exec xfce4-session`, not `startxfce4`. The `startxfce4` wrapper checks for existing X servers and will fail if you have a local session running on `:0`.

#### Alternative Desktop Environments

If you're using a different desktop environment:

```bash
# KDE Plasma
echo "exec startplasma-x11" > ~/.xsession

# GNOME
echo "exec gnome-session" > ~/.xsession

# MATE
echo "exec mate-session" > ~/.xsession

# Cinnamon
echo "exec cinnamon-session" > ~/.xsession
```

### Step 3: Add XRDP to SSL Certificate Group

Allow XRDP to access TLS certificates for encrypted connections.

```bash
sudo adduser xrdp ssl-cert
```

### Step 4: Enable and Start XRDP Services

```bash
# Enable services to start on boot and start them now
sudo systemctl enable xrdp --now
sudo systemctl enable xrdp-sesman --now

# Verify both services are running
systemctl status xrdp --no-pager
systemctl status xrdp-sesman --no-pager
```

**Expected output:** Both services should show `active (running)`

---

## 🔥 Firewall Setup

### Open RDP Port

XRDP listens on TCP port 3389. You must allow this through your firewall.

#### For UFW (Uncomplicated Firewall)

```bash
# Allow RDP from anywhere (less secure)
sudo ufw allow 3389/tcp

# OR - Allow only from your local network (more secure)
sudo ufw allow from 192.168.1.0/24 to any port 3389 proto tcp

# Verify rule was added
sudo ufw status numbered
```

#### For iptables

```bash
# Allow RDP traffic
sudo iptables -A INPUT -p tcp --dport 3389 -j ACCEPT

# Save rules (Debian/MX)
sudo netfilter-persistent save
```

### Verify Port is Open

```bash
# Check if XRDP is listening
sudo netstat -tlnp | grep 3389
# OR
sudo ss -tlnp | grep 3389
```

**Expected output:** Should show `xrdp` listening on `0.0.0.0:3389`

---

## 🧪 Testing the Connection

### From Windows

1. Open **Remote Desktop Connection** (`mstsc.exe`)
2. Enter your MX Linux IP address or hostname
3. Click **Connect**
4. At the XRDP login screen:
   - **Session:** Select `Xorg` (default)
   - **Username:** Your Linux username
   - **Password:** Your Linux password
5. Click **OK**

### From Linux

#### Using Remmina (GUI)

```bash
# Install Remmina if not already installed
sudo apt install remmina remmina-plugin-rdp

# Launch Remmina
remmina
```

1. Click **New connection profile**
2. Set **Protocol** to `RDP`
3. Enter server address
4. Enter username and password
5. Click **Connect**

#### Using xfreerdp (CLI)

```bash
# Install FreeRDP
sudo apt install freerdp2-x11

# Connect
xfreerdp /v:<MX_LINUX_IP> /u:<username> /p:<password> /cert:ignore
```

### From macOS

1. Install **Microsoft Remote Desktop** from App Store
2. Add new PC with your MX Linux IP
3. Connect with your Linux credentials

---

## 🔧 Troubleshooting

### Issue 1: Black Screen After Login

**Cause:** `xorgxrdp` module not installed or `~/.xsession` incorrect

**Solution:**
```bash
# Ensure xorgxrdp is installed
sudo apt install xorgxrdp

# Verify .xsession is correct
cat ~/.xsession
# Should show: exec xfce4-session

# Restart XRDP
sudo systemctl restart xrdp xrdp-sesman
```

### Issue 2: Session Immediately Disconnects

**Symptom:** Logs in, shows brief loading, then exits

**Diagnosis:**
```bash
# Check session errors
cat ~/.xsession-errors

# Look for the actual error at the end of the file
tail -20 ~/.xsession-errors
```

**Common causes and fixes:**

#### "startxfce4: X server already running on display :0"

```bash
# Fix: Use direct session manager instead of wrapper
echo "exec xfce4-session" > ~/.xsession
```

#### "startplasma-x11: command not found" (or similar)

```bash
# You specified the wrong desktop environment
# For XFCE, use:
echo "exec xfce4-session" > ~/.xsession

# For other DEs, verify they're installed:
which startxfce4       # XFCE
which startplasma-x11  # KDE
which gnome-session    # GNOME
```

### Issue 3: Cannot Connect (Connection Refused)

**Diagnosis:**
```bash
# Check if XRDP is running
systemctl status xrdp

# Check if port is listening
sudo ss -tlnp | grep 3389

# Check firewall
sudo ufw status
```

**Solution:**
```bash
# Start XRDP if not running
sudo systemctl start xrdp xrdp-sesman

# Enable if not enabled
sudo systemctl enable xrdp xrdp-sesman

# Open firewall port
sudo ufw allow 3389/tcp
```

### Issue 4: Authentication Failures

**Diagnosis:**
```bash
# Check XRDP logs
sudo journalctl -u xrdp -n 50 --no-pager
sudo journalctl -u xrdp-sesman -n 50 --no-pager

# Check PAM configuration
ls -la /etc/pam.d/xrdp-sesman
```

**Common causes:**
- Wrong username/password
- User account locked
- PAM configuration issues

### Issue 5: Slow Performance / Lag

**Solutions:**

```bash
# Disable XFCE compositor (compositing causes lag over RDP)
xfconf-query -c xfwm4 -p /general/use_compositing -s false

# Or via GUI: Settings → Window Manager Tweaks → Compositor → 
# Uncheck "Enable display compositing"
```

### Real-Time Log Monitoring

When troubleshooting, watch logs in real-time during connection attempts:

```bash
# Terminal 1: Watch all XRDP logs
sudo journalctl -u xrdp -u xrdp-sesman -f

# Terminal 2: Watch session errors
tail -f ~/.xsession-errors

# Then attempt your RDP connection
```
### Issue 6: Black Screen → Long Hang → Eventually Logs In (or Disconnects)

**Environment Pattern Observed**

- XFCE starts  
- Repeated Xsession starts on `DISPLAY=:10.0`  
- Errors referencing:  
  `/home/bill/thinclient_drives`  
  `Transport endpoint is not connected`

This is **not** primarily CPU slowness. It is a **broken XRDP drive redirection mount (FUSE)** that stalls the desktop while the file manager and GTK volume services wait on a dead mount.

---

### Root Cause

XRDP drive redirection creates:

```
~/thinclient_drives
```

If that mount becomes invalid (disconnect, crash, network glitch), the path remains but the FUSE endpoint is dead. Desktop components (Thunar, GVFS, GTK volume monitors) block on it → black screen or extreme login delay.

---

### Permanent Fix (Recommended)

#### 1. Stop XRDP

```
sudo systemctl stop xrdp xrdp-sesman
```

#### 2. Force-remove the broken mount

```
sudo umount -lf /home/$USER/thinclient_drives 2>/dev/null || true
sudo rm -rf /home/$USER/thinclient_drives
sudo mkdir -p /home/$USER/thinclient_drives
sudo chown $USER:$USER /home/$USER/thinclient_drives
```

#### 3. Disable XRDP Drive Redirection

Prevents the mount from being recreated.

```
sudo cp -a /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.bak.$(date +%F-%H%M%S)
sudo sed -i 's/^[[:space:]]*drives[[:space:]]*=.*/drives=false/' /etc/xrdp/xrdp.ini
```

#### 4. Restart XRDP

```
sudo systemctl restart xrdp xrdp-sesman
```

---

### Result

- No more `thinclient_drives` mount  
- XFCE session loads immediately  
- Black screen hang eliminated  
- Session stability improves dramatically  

---

### When to Suspect This Issue

| Symptom | Strong Indicator |
|--------|------------------|
| Black screen before desktop | Yes |
| Login takes 30–120+ seconds | Yes |
| Intermittent disconnects | Yes |
| Log shows `Transport endpoint is not connected` | Definitive |
| Only happens over XRDP | Yes |

---

### Performance Note (Secondary)

On slow hardware, XRDP startup can be delayed, **but it should never hang**. True performance issues look like:

- Gradual desktop draw  
- Sluggish UI  
- High CPU usage  

They do **not** produce FUSE transport errors.

If performance tuning is needed, see **Issue 5: Slow Performance / Lag**.

---

### Living Document Note

If XRDP drive redirection is required in the future:

- Expect occasional session corruption  
- First diagnostic step: check `~/thinclient_drives`  
- Quick recovery: force unmount + XRDP restart  

---

Add this under Troubleshooting. This is a high-impact, real-world failure mode.

---

## 🎨 Optional Enhancements

### 1. Optimize Performance Settings

```bash
# Disable XFCE compositor for better RDP performance
xfconf-query -c xfwm4 -p /general/use_compositing -s false

# Reduce visual effects
xfconf-query -c xfwm4 -p /general/use_compositing -s false
xfconf-query -c xfwm4 -p /general/frame_opacity -s 100
```

### 2. Custom XRDP Color Depth

Edit `/etc/xrdp/xrdp.ini`:

```bash
sudo nano /etc/xrdp/xrdp.ini

# Find and modify:
max_bpp=24          # Set to 16 for slower connections
                    # Set to 32 for best quality on fast networks
```

### 3. Change Default RDP Port

If you want XRDP to listen on a different port:

```bash
sudo nano /etc/xrdp/xrdp.ini

# Find and change:
port=3389           # Change to desired port (e.g., 13389)

# Restart XRDP
sudo systemctl restart xrdp

# Update firewall
sudo ufw allow <NEW_PORT>/tcp
sudo ufw delete allow 3389/tcp
```

### 4. Multi-Monitor Support

XRDP supports multiple monitors. In your RDP client:

**Windows:** Settings → Display → Use all my monitors

**Linux (xfreerdp):**
```bash
xfreerdp /v:<host> /u:<user> /multimon
```

---

## 🔒 Security Considerations

### 1. Restrict Access by IP

```bash
# Only allow RDP from specific network
sudo ufw delete allow 3389/tcp
sudo ufw allow from 192.168.1.0/24 to any port 3389 proto tcp

# Or single IP
sudo ufw allow from 192.168.1.100 to any port 3389 proto tcp
```

### 2. SSH Tunnel for Remote Access

For connections over the internet, use an SSH tunnel instead of exposing port 3389:

#### From Linux Client:

```bash
# Create SSH tunnel
ssh -L 3390:localhost:3389 user@mx-linux-host

# Keep that terminal open, then connect RDP to:
# localhost:3390
```

#### From Windows Client (PowerShell):

```powershell
# Create SSH tunnel
ssh -L 3390:localhost:3389 user@mx-linux-host

# Then connect Remote Desktop to: localhost:3390
```

With this method, you can firewall block port 3389 completely:

```bash
sudo ufw delete allow 3389/tcp
```

### 3. Use Key-Based SSH Authentication

If using SSH tunneling, disable password authentication:

```bash
sudo nano /etc/ssh/sshd_config

# Set:
PasswordAuthentication no
PubkeyAuthentication yes

sudo systemctl restart sshd
```

### 4. Certificate Warnings

XRDP uses a self-signed certificate by default. To avoid warnings:

**Option A:** Accept the certificate once (it will be remembered)

**Option B:** Generate your own certificate:

```bash
cd /etc/xrdp

# Backup existing cert
sudo mv cert.pem cert.pem.bak
sudo mv key.pem key.pem.bak

# Generate new certificate
sudo openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem \
  -days 365 -nodes -subj "/CN=$(hostname)"

# Set permissions
sudo chown xrdp:xrdp key.pem cert.pem
sudo chmod 640 key.pem

# Restart XRDP
sudo systemctl restart xrdp
```

### 5. Fail2ban Integration

Protect against brute force attacks:

```bash
# Install fail2ban
sudo apt install fail2ban

# Create XRDP jail
sudo nano /etc/fail2ban/jail.d/xrdp.conf
```

Add this configuration:

```ini
[xrdp]
enabled = true
port = 3389
filter = xrdp
logpath = /var/log/xrdp-sesman.log
maxretry = 5
findtime = 600
bantime = 3600
```

Create filter:

```bash
sudo nano /etc/fail2ban/filter.d/xrdp.conf
```

```ini
[Definition]
failregex = ^\[\d+\]: \[ERROR\] SECURITY: Access denied for user <HOST>
            ^\[\d+\]: \[WARN \] Failed login attempt for user.*from <HOST>
ignoreregex =
```

Restart fail2ban:

```bash
sudo systemctl restart fail2ban
sudo fail2ban-client status xrdp
```

---

## 📚 References

### Official Documentation

- [XRDP GitHub Repository](https://github.com/neutrinolabs/xrdp)
- [Debian Wiki - XRDP](https://wiki.debian.org/XRDP)
- [MX Linux Documentation](https://mxlinux.org/wiki/)

### Related Guides

- [Xorg Documentation](https://www.x.org/wiki/)
- [XFCE Documentation](https://docs.xfce.org/)
- [UFW Firewall Guide](https://help.ubuntu.com/community/UFW)

---

## 🎓 Key Lessons Learned

### The `~/.xsession` Saga

The most common issue with XRDP on XFCE is the session startup configuration:

❌ **Wrong:** `echo "startxfce4" > ~/.xsession`
- This uses a wrapper script that detects existing X servers
- Fails when you have a local desktop session active on `:0`
- Error: "X server already running on display :0"

✅ **Correct:** `echo "exec xfce4-session" > ~/.xsession`
- Directly invokes the session manager
- Works regardless of other X sessions
- The `exec` ensures proper process replacement and cleanup

### Display Numbers

- Physical console: `:0`
- First XRDP session: `:10`
- Second XRDP session: `:11`
- Each session is independent and isolated

### Log Files Are Your Friend

When troubleshooting:
1. `~/.xsession-errors` - Session startup errors
2. `sudo journalctl -u xrdp` - XRDP server logs
3. `sudo journalctl -u xrdp-sesman` - Session manager logs
4. `/var/log/Xorg.10.log` - X server logs for display :10

---

## 🤝 Contributing

Found an issue or have an improvement? Contributions welcome!

### Testing Checklist

- [ ] Fresh MX Linux installation
- [ ] XRDP installs without errors
- [ ] Can connect from Windows RDP client
- [ ] Can connect from Linux RDP client (Remmina/xfreerdp)
- [ ] Multiple concurrent sessions work
- [ ] Audio redirection works
- [ ] Clipboard sharing works
- [ ] Session survives reboot

---

## 📝 License

This guide is released under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)

---

## 📞 Support

If you're stuck:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review your `~/.xsession-errors` file
3. Check XRDP logs: `sudo journalctl -u xrdp -u xrdp-sesman`
4. Search [XRDP GitHub Issues](https://github.com/neutrinolabs/xrdp/issues)
5. Ask on [MX Linux Forums](https://forum.mxlinux.org/)

---

**Last Updated:** January 25, 2026  
**Tested On:** MX Linux 25 (Debian Trixie-based) with XFCE 4.18
