#!/bin/bash
# create-kiosk-setup.sh - Ubuntu GNOME Kiosk Setup Script
# Author: Simon .I
# Version: 2024.11.07

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    zenity --error --text="This script must be run as root."
    exit 1
fi

# Check for Ubuntu and GNOME environment
if ! grep -qi "ubuntu" /etc/os-release || ! echo "$XDG_CURRENT_DESKTOP" | grep -qi "GNOME"; then
    zenity --error --text="This script is intended for Ubuntu with GNOME desktop only. Exiting setup."
    exit 1
fi

# Step 1: Prompt for Kiosk Username and Password
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

# Create the kiosk user account as a standard user
if id "$KIOSK_USER" &>/dev/null; then
    echo "User '$KIOSK_USER' already exists."
else
    useradd -m -s /bin/bash "$KIOSK_USER"
    echo "$KIOSK_USER:$KIOSK_PASSWORD" | chpasswd
    echo "Kiosk user created with username: $KIOSK_USER as a standard user."
fi

# Step 2: Prompt the User to Set Up Autologin Manually
zenity --info --title="Autologin Setup Required" --text="To enable autologin for the kiosk account, please:\n\n1. Open 'Settings'.\n2. Search for 'Users'.\n3. Select the kiosk user: $KIOSK_USER.\n4. Unlock (if required) and enable 'Automatic Login'.\n\nClick OK once done." --ok-label="OK"

# Step 3: Install necessary tools if missing
if ! command -v xinput &> /dev/null; then
    echo "xinput not found. Installing xinput..."
    apt install -y xinput
fi

if ! command -v usb_modeswitch &> /dev/null; then
    echo "usb-modeswitch not found. Installing usb-modeswitch..."
    apt install -y usb-modeswitch
fi

# Step 4: Disable GNOME Notifications and Update Notifications for Kiosk User
echo "Disabling notifications and update prompts for kiosk user..."
sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.desktop.notifications show-banners false
echo 'APT::Periodic::Update-Package-Lists "0";' | sudo tee /etc/apt/apt.conf.d/10periodic > /dev/null

# Step 5: Disable Initial Setup Prompts and Set Default GNOME Preferences for Kiosk User
echo "Disabling GNOME initial setup for $KIOSK_USER..."
sudo -u "$KIOSK_USER" mkdir -p "/home/$KIOSK_USER/.config"
sudo -u "$KIOSK_USER" touch "/home/$KIOSK_USER/.config/gnome-initial-setup-done"
rm -f /home/"$KIOSK_USER"/.config/autostart/gnome-getting-started*  # Remove GNOME Tour

# Set GNOME preferences for the kiosk session
sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.desktop.session idle-delay 0  # Disable screen idle delay
sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0  # Prevent sleep when idle
sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0

# Step 6: Ensure Firefox is Installed
if ! command -v firefox &> /dev/null; then
    echo "Firefox not found. Installing Firefox..."
    apt update && apt install -y firefox
fi

# Step 7: Install Caffeine to Prevent Sleep/Dimming
echo "Installing and configuring Caffeine to prevent sleep and dimming..."
apt-get install -y caffeine

# Create Caffeine startup script
CAFFEINE_SCRIPT_PATH="/home/$KIOSK_USER/start-caffeine.sh"
echo "caffeine &" > "$CAFFEINE_SCRIPT_PATH"
chmod +x "$CAFFEINE_SCRIPT_PATH"
chown "$KIOSK_USER":"$KIOSK_USER" "$CAFFEINE_SCRIPT_PATH"

# Add Caffeine to autostart
AUTOSTART_DIR="/home/$KIOSK_USER/.config/autostart"
mkdir -p "$AUTOSTART_DIR"
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

# Step 8: Check for Full-Disk Encryption (Warn Only with OK Button)
echo "Checking for full-disk encryption..."
if ! lsblk -o name,type,fstype,mountpoint | grep -q "crypto_LUKS"; then
    zenity --info --title="Kiosk Setup - Security Notice" --text="Full-disk encryption (FDE) is not enabled. FDE can only be set up during OS installation, but it is not required to proceed." --ok-label="OK"
fi

# Step 9: Disable SSH Service if Installed
if systemctl list-units --type=service | grep -q "ssh.service"; then
    echo "Disabling SSH service..."
    systemctl disable --now ssh
else
    echo "SSH service not found, skipping disable step."
fi

# Step 10: Restart Prompt
zenity --info --title="Kiosk Setup Complete" --text="Kiosk setup is complete. Please restart the system to apply all changes."

# ------- Log in as Kiosk User, Launch Kiosk Mode ------- #

# Step 11: Create Kiosk Mode Script with Firefox Update, Input Lockdown, USB Disable, and URL Prompt
KIOSK_SCRIPT_PATH="/home/$KIOSK_USER/start-kiosk.sh"

cat << 'EOF' > "$KIOSK_SCRIPT_PATH"
#!/bin/bash
# start-kiosk.sh - Kiosk Mode with Firefox Update, URL Prompt, Input Lockdown, and USB Disable

# Prompt to Update Firefox or OS, or go straight to Kiosk Mode
UPDATE_OPTION=$(zenity --list --title="Kiosk Setup - Update Options" \
    --text="Do you want to update Firefox, update the operating system, or continue to kiosk mode?" \
    --radiolist --column="Select" --column="Option" \
    FALSE "Firefox" FALSE "OS" TRUE "Kiosk")

if [[ "$UPDATE_OPTION" == "Firefox" ]]; then
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

elif [[ "$UPDATE_OPTION" == "OS" ]]; then
    zenity --info --title="Kiosk Setup - OS Update" --text="The system will now update. Restart after completion."
    sudo apt update && sudo apt -y upgrade && sudo apt -y autoremove
    exit 0
elif [[ "$UPDATE_OPTION" == "Kiosk" ]]; then
    URL=$(zenity --entry --title="Kiosk Setup - URL" --text="Enter the URL for kiosk mode:" --entry-text="https://example.splunkcloud.com" --no-cancel)
    if [[ -z "$URL" ]]; then
        zenity --warning --title="Kiosk Setup" --text="No URL provided. Exiting setup."
        exit 1
    fi

    firefox --kiosk "$URL" &
    sleep 3

    zenity --info --title="Kiosk Mode - Confirm" --text="Once the page is loaded, click OK to disable keyboard and mouse."
    for id in $(xinput --list --id-only); do
        xinput disable "$id"
    done

    echo "Disabling USB storage devices..."
    sudo rmmod usb_storage
fi
EOF

chmod +x "$KIOSK_SCRIPT_PATH"
chown "$KIOSK_USER":"$KIOSK_USER" "$KIOSK_SCRIPT_PATH"

# Configuring the kiosk script to run on startup
cat << EOF > "$AUTOSTART_DIR/kiosk.desktop"
[Desktop Entry]
Type=Application
Exec=$KIOSK_SCRIPT_PATH
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=KioskMode
Comment=Launch Firefox in kiosk mode
EOF

chown -R "$KIOSK_USER":"$KIOSK_USER" "$AUTOSTART_DIR"

# Final confirmation to restart system to apply changes
zenity --info --title="Kiosk Setup Complete" --text="Kiosk setup complete. Please restart the system for changes to take effect."
