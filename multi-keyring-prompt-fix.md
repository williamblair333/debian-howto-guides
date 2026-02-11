# 🔑 How to Auto-Unlock Login Keyring on MX Linux 25 (systemd + startx)

This guide fixes the annoying password prompt by bridging your **TTY login** with your **X session**.

---

### 📋 Phase 1: Preparation
Ensure the PAM module for the keyring is installed:
`sudo apt update && sudo apt install libpam-gnome-keyring seahorse`

---

### 🛠️ Phase 2: Configure PAM (The Handshake)
We need to tell the console login to "hold" your password and pass it to the keyring daemon.

1.  Open the login config: `sudo nano /etc/pam.d/login`
2.  Add `auth optional pam_gnome_keyring.so` to the end of the **auth** section.
3.  Add `session optional pam_gnome_keyring.so auto_start` to the end of the **session** section.

---

### 🛠️ Phase 3: Configure .xinitrc (The Bridge)
Since you use `startx`, your graphical environment needs to know where the "unlocked" keyring lives. Add this to your `~/.xinitrc` **above** your `exec` line:

```bash
# Start the GNOME Keyring Daemon
eval $(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)

# Export variables so apps can find the keyring
export GNOME_KEYRING_CONTROL
export SSH_AUTH_SOCK

# Ensure D-Bus is connected to the session
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax --exit-with-session)
fi
```

---

### 🛠️ Phase 4: Sync the Passwords
If you are still prompted, your "Login" keyring password likely doesn't match your user password.

1.  Open **Passwords and Keys** (Seahorse) from your app menu.
2.  Right-click the **Login** keyring (on the left sidebar).
3.  Select **Change Password**.
4.  Enter your **current user login password** for both the "Old" and "New" fields.

---

### ✅ Verification
After your next `startx`, run this in a terminal:
`echo $GNOME_KEYRING_CONTROL`

If you see a path like `/run/user/1000/keyring/...`, your keyring is successfully unlocked!
