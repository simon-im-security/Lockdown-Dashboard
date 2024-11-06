#!/bin/bash
# create-kiosk-setup.sh - Ubuntu GNOME Kiosk Setup Script with Autologin Instructions, Update Options, URL Memory, Timeout, Input Lockdown, USB Disable, Caffeine, FDE Check, and Logging
# Author: Simon .I
# Version: 2024.11.07

# Log file
LOG_FILE="/var/log/kiosk_setup.log"
echo "Kiosk setup started at $(date)" > "$LOG_FILE"

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    zenity --error --text="This script must be run as root." | tee -a "$LOG_FILE"
    exit 1
fi

# Check for Ubuntu and GNOME environment
if ! grep -qi "ubuntu" /etc/os-release || ! echo "$XDG_CURRENT_DESKTOP" | grep -qi "GNOME"; then
    zenity --error --text="This script is intended for Ubuntu with GNOME desktop only. Exiting setup." | tee -a "$LOG_FILE"
    exit 1
fi

# Define file paths for config and last URL storage
KIOSK_CONFIG_DIR="/home/$KIOSK_USER/.kiosk_config"
LAST_URL_FILE="$KIOSK_CONFIG_DIR/last_url"
mkdir -p "$KIOSK_CONFIG_DIR"

# Load the last URL if available
if [[ -f "$LAST_URL_FILE" ]]; then
    last_url=$(cat "$LAST_URL_FILE")
else
    last_url="https://example.splunkcloud.com"
fi

# Step 1: Prompt for Kiosk Username and Password
KIOSK_USER=$(zenity --entry --title="Kiosk Setup - Username" --text="Enter the username for the kiosk account:")
if [[ -z "$KIOSK_USER" ]]; then
    zenity --error --text="No username provided. Exiting setup." | tee -a "$LOG_FILE"
    exit 1
fi

KIOSK_PASSWORD=$(zenity --password --title="Kiosk Setup - Password" --text="Enter the password for the kiosk account:")
if [[ -z "$KIOSK_PASSWORD" ]]; then
    zenity --error --text="No password provided. Exiting setup." | tee -a "$LOG_FILE"
    exit 1
fi

# Create the kiosk user account as a standard user
if id "$KIOSK_USER" &>/dev/null; then
    echo "User '$KIOSK_USER' already exists." | tee -a "$LOG_FILE"
else
    useradd -m -s /bin/bash "$KIOSK_USER"
    echo "$KIOSK_USER:$KIOSK_PASSWORD" | chpasswd
    echo "Kiosk user created with username: $KIOSK_USER as a standard user." | tee -a "$LOG_FILE"
fi

# Step 2: Prompt the User to Set Up Autologin Manually
zenity --info --title="Autologin Setup Required" --text="To enable autologin for the kiosk account, please:\n\n1. Open 'Settings'.\n2. Search for 'Users'.\n3. Select the kiosk user: $KIOSK_USER.\n4. Unlock (if required) and enable 'Automatic Login'.\n\nClick OK once done." --ok-label="OK"

# Confirm that the user has set up autologin
zenity --info --title="Autologin Confirmation" --text="Click OK if you have completed the autologin setup for the kiosk user."

# Step 3: Install necessary tools if missing
echo "Checking for required tools..." | tee -a "$LOG_FILE"
if ! command -v xinput &> /dev/null; then
    echo "Installing xinput..." | tee -a "$LOG_FILE"
    apt install -y xinput | tee -a "$LOG_FILE"
fi

if ! command -v usb_modeswitch &> /dev/null; then
    echo "Installing usb-modeswitch..." | tee -a "$LOG_FILE"
    apt install -y usb-modeswitch | tee -a "$LOG_FILE"
fi

# Step 4: Disable GNOME Notifications and Update Notifications for Kiosk User
echo "Disabling notifications and update prompts for kiosk user..." | tee -a "$LOG_FILE"
sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.desktop.notifications show-banners false
sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.software download-updates false
sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.software allow-updates false
sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.software enable-notifications false

# Step 5: Disable Initial Setup Prompts and Set Default GNOME Preferences for Kiosk User
echo "Disabling GNOME initial setup for $KIOSK_USER..." | tee -a "$LOG_FILE"
sudo -u "$KIOSK_USER" mkdir -p "/home/$KIOSK_USER/.config"
sudo -u "$KIOSK_USER" touch "/home/$KIOSK_USER/.config/gnome-initial-setup-done"
rm -f /home/"$KIOSK_USER"/.config/autostart/gnome-getting-started*

# Set GNOME preferences for the kiosk session
sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.desktop.session idle-delay 0
sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0

# Step 6: Ensure Firefox is Installed
if ! command -v firefox &> /dev/null; then
    echo "Installing Firefox..." | tee -a "$LOG_FILE"
    apt update && apt install -y firefox | tee -a "$LOG_FILE"
fi

# Step 7: Prompt for Update Option (Firefox, OS, or Kiosk Mode) with 5-Minute Timeout to Default to Kiosk Mode
UPDATE_OPTION=$(zenity --list --title="Kiosk Setup - Update Options" \
    --text="Do you want to update Firefox, update the operating system, or continue to kiosk mode?\n\n*This prompt will default to Kiosk Mode after 5 minutes.*" \
    --radiolist --column="Select" --column="Option" \
    FALSE "Firefox" FALSE "OS" TRUE "Kiosk" --timeout=300)

if [[ -z "$UPDATE_OPTION" ]]; then
    UPDATE_OPTION="Kiosk"
    echo "Timeout reached, defaulting to Kiosk Mode" | tee -a "$LOG_FILE"
fi

case "$UPDATE_OPTION" in
    "Firefox")
        sudo apt install -y firefox &> /dev/null &
        APT_PID=$!
        (
            echo "10"; echo "# Preparing to install Firefox..."
            while kill -0 $APT_PID 2>/dev/null; do
                echo "50"; echo "# Installing Firefox... Please wait"
                sleep 5
            done
            echo "100"; echo "# Firefox update complete."
        ) | zenity --progress --title="Kiosk Setup - Firefox Update" --text="Updating Firefox. Please wait..." --percentage=0 --auto-close --no-cancel --width=300
        FIREFOX_VERSION=$(firefox --version)
        INSTALL_DATE=$(date +"%Y-%m-%d %H:%M:%S")
        zenity --info --title="Kiosk Setup - Update Complete" --text="Firefox update complete:\n\nVersion: $FIREFOX_VERSION\nInstalled on: $INSTALL_DATE"
        ;;
    "OS")
        zenity --info --title="Kiosk Setup - OS Update" --text="System updating. Please restart once completed." | tee -a "$LOG_FILE"
        sudo apt update && sudo apt -y upgrade && sudo apt -y autoremove | tee -a "$LOG_FILE"
        zenity --info --title="Kiosk Setup - OS Update Complete" --text="System update complete. Restart the system to continue with kiosk mode."
        exit 0
        ;;
esac

# Step 9: Prompt for URL input with 5-Minute Timeout and Memory of Last URL
URL=$(zenity --entry --title="Kiosk Setup - URL" --text="Enter the URL for kiosk mode:\n\n*This prompt will default to the last used URL after 5 minutes.*" \
    --entry-text="$last_url" --no-cancel --timeout=300)

if [[ -z "$URL" ]]; then
    URL="$last_url"
    echo "Timeout reached, defaulting to last URL: $last_url" | tee -a "$LOG_FILE"
fi

echo "$URL" > "$LAST_URL_FILE"
firefox --kiosk "$URL" &
sleep 3

# Disable inputs and USB after confirmation
zenity --info --title="Kiosk Mode - Confirm" --text="Click OK to disable keyboard, mouse, and USB devices once URL is loaded."
for id in $(xinput --list --id-only); do
    xinput disable "$id"
done
sudo rmmod usb_storage

# Step 10: Additional configurations - Caffeine, FDE check, and SSH disable
echo "Installing and configuring Caffeine..." | tee -a "$LOG_FILE"
apt-get install -y caffeine | tee -a "$LOG_FILE"
mkdir -p "/home/$KIOSK_USER/.config/autostart"
cat << EOF > "/home/$KIOSK_USER/.config/autostart/caffeine.desktop"
[Desktop Entry]
Type=Application
Exec=caffeine
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Caffeine
Comment=Prevent sleep or dimming
EOF
if ! lsblk -o name,type,fstype,mountpoint | grep -q "crypto_LUKS"; then
    zenity --info --title="Kiosk Setup - Security Notice" --text="Full-disk encryption (FDE) is not enabled. Recommended but optional." | tee -a "$LOG_FILE"
fi
if systemctl list-units --type=service | grep -q "ssh.service"; then
    systemctl disable --now ssh | tee -a "$LOG_FILE"
fi

zenity --info --title="Kiosk Setup Complete" --text="Setup complete. Restart system to apply changes." | tee -a "$LOG_FILE"
