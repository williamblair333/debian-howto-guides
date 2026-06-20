#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
  echo "Must be run as root."
  exit 1
fi

BACKLIGHT_DIR=$(find /sys/class/backlight -mindepth 1 -maxdepth 1 | head -n 1)

if [ -z "$BACKLIGHT_DIR" ]; then
  echo "No standard backlight controller found."
  exit 1
fi

CONTROLLER=$(basename "$BACKLIGHT_DIR")
MAX_VAL=$(cat "$BACKLIGHT_DIR/max_brightness")

echo "$MAX_VAL" > "$BACKLIGHT_DIR/brightness"
echo "Applied $MAX_VAL to $CONTROLLER."

SERVICE_PATH="/etc/systemd/system/force-max-brightness.service"

cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=Enforce Maximum Brightness
After=systemd-backlight@backlight:$CONTROLLER.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo $MAX_VAL > /sys/class/backlight/$CONTROLLER/brightness'

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable force-max-brightness.service

echo "Persistent systemd service installed and enabled."
