#!/bin/bash
# create-kiosk-setup.sh - Ubuntu XFCE Kiosk Setup with LightDM, Conditional Input Lockdown, and Firefox Kiosk Mode
# Author: Simon .I
# Version: 2024.11.07

# Check for Ubuntu environment
if ! grep -qi "ubuntu" /etc/os-release; then
    zenity --error --text="This script is intended for Ubuntu only. Exiting setup."
    exit 1
fi

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    zenity --error --text="This script must be run as root."
    exit 1
fi

# Step 1: Check and Install xinput if missing
if ! command -v xinput &> /dev/null; then
    echo "xinput not found. Installing xinput..."
    apt update && apt install -y xinput
fi

# Step 2: Install LightDM and XFCE for Easier Autologin Setup
echo "Installing LightDM and XFCE for lightweight autologin setup..."
apt update
apt install -y lightdm xfce4

# Configure LightDM for Autologin
sudo bash -c "cat > /etc/lightdm/lightdm.conf <<EOF
[Seat:*]
autologin-user=$KIOSK_USER
EOF
"

# Step 3: Prompt for Kiosk Username and Password without Cancel Option
KIOSK_USER=$(zenity --entry --title="Kiosk Setup - Username" --text="Enter the username for the kiosk account:")
if [[ -z "$KIOSK_USER" ]]; then
    zenity --error --text="No username provided. Exiting setup."
    exit 1
fi

KIOSK_PASSWORD=$(zenity --password --title="Kiosk Setup - Password" --text="Enter the password for the kiosk account:")
if [[ -z "$KIOSK_PASSWORD" ]]; then
    zenity --error --text="No password provided. Exiting setup."
    exit 1
fi

# Step 4: Create Kiosk User Account
echo "Creating kiosk user account with username: $KIOSK_USER..."
if id "$KIOSK_USER" &>/dev/null; then
    echo "User '$KIOSK_USER' already exists. Skipping creation."
else
    useradd -m -s /bin/bash "$KIOSK_USER"
    echo "$KIOSK_USER:$KIOSK_PASSWORD" | chpasswd
    usermod -aG sudo "$KIOSK_USER"
    echo "Kiosk user created with username: $KIOSK_USER"
fi

# Step 5: Disable XFCE Notifications for Kiosk User
echo "Disabling notifications for kiosk user..."
sudo -u "$KIOSK_USER" dbus-launch xfconf-query -c xfce4-notifyd -p /do-not-disturb -s true

# Step 6: Ensure Firefox is Installed
if ! command -v firefox &> /dev/null; then
    echo "Firefox not found. Installing Firefox..."
    apt update && apt install -y firefox
fi

# Step 7: Create Kiosk Script with Firefox Kiosk Mode and Conditional Input Lockdown
KIOSK_SCRIPT_PATH="/home/$KIOSK_USER/start-kiosk.sh"

cat << 'EOF' > "$KIOSK_SCRIPT_PATH"
#!/bin/bash
# start-kiosk.sh - Kiosk startup script with Firefox Kiosk Mode and Conditional Input Lockdown

# Enable all inputs on startup to allow for configuration
for id in $(xinput --list --id-only); do
    xinput enable "$id"
done

# Prompt for URL for kiosk mode
URL=$(zenity --entry --title="Kiosk Setup - URL" --text="Enter the URL for kiosk mode:" --entry-text="https://example.splunkcloud.com")
if [[ -z "$URL" ]]; then
    zenity --warning --title="Kiosk Setup" --text="No URL provided. Exiting setup."
    exit 1
fi

# Launch Firefox in Kiosk Mode with the specified URL and wait 3 seconds before showing confirmation
firefox --kiosk "$URL" &
sleep 3

# Confirmation to disable inputs once URL is loaded
zenity --info --title="Kiosk Mode - Confirm" --text="Once the page has loaded and authentication (if any) is complete, click OK to disable keyboard and mouse."

# Disable all input devices (keyboard, mouse, etc.) to prevent exiting kiosk mode
for id in $(xinput --list --id-only); do
    xinput disable "$id"
done
EOF

# Make Kiosk Script Executable
chmod +x "$KIOSK_SCRIPT_PATH"
chown "$KIOSK_USER":"$KIOSK_USER" "$KIOSK_SCRIPT_PATH"

# Step 8: Configure Kiosk Script to Run on Startup
echo "Configuring kiosk script to run on startup..."
AUTOSTART_DIR="/home/$KIOSK_USER/.config/autostart"
mkdir -p "$AUTOSTART_DIR"
cat << EOF > "$AUTOSTART_DIR/kiosk.desktop"
[Desktop Entry]
Type=Application
Exec=$KIOSK_SCRIPT_PATH
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=KioskMode
Comment=Launch Kiosk Mode
EOF

chown -R "$KIOSK_USER":"$KIOSK_USER" "$AUTOSTART_DIR"

# Step 9: Install and Start Caffeine to Prevent Sleep/Dimming
echo "Installing and configuring Caffeine to prevent sleep and dimming..."
apt-get install -y caffeine

# Create Caffeine startup script
CAFFEINE_SCRIPT_PATH="/home/$KIOSK_USER/start-caffeine.sh"
echo "caffeine &" > "$CAFFEINE_SCRIPT_PATH"
chmod +x "$CAFFEINE_SCRIPT_PATH"
chown "$KIOSK_USER":"$KIOSK_USER" "$CAFFEINE_SCRIPT_PATH"

# Add Caffeine to autostart
cat << EOF > "$AUTOSTART_DIR/caffeine.desktop"
[Desktop Entry]
Type=Application
Exec=$CAFFEINE_SCRIPT_PATH
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Caffeine
Comment=Prevent the system from going to sleep or dimming
EOF

# Step 10: Check for Full-Disk Encryption (Warn Only with OK Button)
echo "Checking for full-disk encryption..."
if ! lsblk -o name,type,fstype,mountpoint | grep -q "crypto_LUKS"; then
    zenity --info --title="Kiosk Setup - Security Notice" --text="Full-disk encryption (FDE) not detected. We recommend enabling FDE for additional security." --ok-label="OK"
fi

# Step 11: Disable SSH Service if Installed
if systemctl list-units --type=service | grep -q "ssh.service"; then
    echo "Disabling SSH service..."
    systemctl disable --now ssh
else
    echo "SSH service not found, skipping disable step."
fi

# Step 12: One-Time Restart to Apply All Setup Changes
echo "Initial setup complete. Restarting system to apply changes."
sleep 2
shutdown -r now
