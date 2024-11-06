#!/bin/bash
# Ubuntu TTY Auto-login Configuration Script with FDE acknowledgment, optional SSH disable, and automatic restart
# Author: Simon .I
# Version: 2024.11.06

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Step 1: Prompt for the TTY username
KIOSK_USER=$(zenity --entry --title="Kiosk Username" --text="Enter the username for TTY auto-login:")
if [[ -z "$KIOSK_USER" ]]; then
    zenity --error --text="No username provided. Exiting setup."
    exit 1
fi

# Step 2: Ensure the user exists
echo "Creating or verifying kiosk user account with username: $KIOSK_USER..."
if id "$KIOSK_USER" &>/dev/null; then
    echo "User '$KIOSK_USER' already exists. Skipping creation."
else
    useradd -m -s /bin/bash "$KIOSK_USER"
    echo "$KIOSK_USER:$KIOSK_PASSWORD" | chpasswd
    echo "Kiosk user created with username: $KIOSK_USER"
fi

# Step 3: Configure auto-login for the TTY
echo "Configuring TTY auto-login for user $KIOSK_USER..."
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
cat << EOF > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --autologin $KIOSK_USER %I \$TERM
Type=idle
EOF

# Step 4: Edit logind.conf for TTY management
echo "Configuring /etc/systemd/logind.conf for TTY auto-allocation..."
sed -i 's/^#NAutoVTs=.*/NAutoVTs=6/' /etc/systemd/logind.conf
sed -i 's/^#ReserveVT=.*/ReserveVT=7/' /etc/systemd/logind.conf

# Step 5: Check and disable SSH if available
if systemctl list-units --type=service | grep -q "ssh.service"; then
    echo "Disabling SSH service..."
    systemctl disable --now ssh
else
    echo "SSH service not found, skipping disable step."
fi

# Step 6: Check for Full-Disk Encryption (FDE) - Warn with OK Button Only
echo "Checking for full-disk encryption..."
if ! lsblk -o name,type,fstype,mountpoint | grep -q "crypto_LUKS"; then
    zenity --info --title="Security Notice" --text="Full-disk encryption (FDE) not detected. We recommend enabling FDE for additional security." --ok-label="OK"
fi

# Step 7: Restart the system to apply changes
echo "Setup complete. Restarting system..."
sleep 2
shutdown -r now
