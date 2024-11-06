#!/bin/bash
# create-kiosk-setup.sh - Ubuntu GNOME Kiosk Setup with LightDM, Firefox Update, Input Lockdown, and USB Disable
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

# Step 1: Install LightDM for Autologin Support
echo "Installing LightDM for GNOME kiosk autologin setup..."
apt update && apt install -y lightdm
systemctl enable lightdm

# Configure LightDM for Autologin
echo "Configuring LightDM for autologin..."
sudo mkdir -p /etc/lightdm/lightdm.conf.d
sudo bash -c "cat > /etc/lightdm/lightdm.conf.d/01-autologin.conf <<EOF
[Seat:*]
autologin-user=$KIOSK_USER
autologin-user-timeout=0
EOF
"

# Step 2: Check and Install xinput and usb-modeswitch if missing
if ! command -v xinput &> /dev/null; then
    echo "xinput not found. Installing xinput..."
    apt install -y xinput
fi

if ! command -v usb_modeswitch &> /dev/null; then
    echo "usb-modeswitch not found. Installing usb-modeswitch..."
    apt install -y usb-modeswitch
fi

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

# Step 5: Disable GNOME Notifications and System Update Notifications for Kiosk User
echo "Disabling notifications and update prompts for kiosk user..."
sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.desktop.notifications show-banners false
# Disable automatic update notifications (Ubuntu/Debian-based method)
echo 'APT::Periodic::Update-Package-Lists "0";' | sudo tee /etc/apt/apt.conf.d/10periodic > /dev/null

# Step 6: Ensure Firefox is Installed
if ! command -v firefox &> /dev/null; then
    echo "Firefox not found. Installing Firefox..."
    apt update && apt install -y firefox
fi

# Step 7: Create Kiosk Script with Firefox Update, Firefox Kiosk Mode, Input Lockdown, and USB Disable
KIOSK_SCRIPT_PATH="/home/$KIOSK_USER/start-kiosk.sh"

cat << 'EOF' > "$KIOSK_SCRIPT_PATH"
#!/bin/bash
# start-kiosk.sh - Kiosk startup script with Firefox Update, Firefox Kiosk Mode, Input Lockdown, and USB Disable

# Prompt to Update Firefox
if zenity --question --title="Kiosk Setup - Firefox Update" --text="Do you want to update Firefox before launching the kiosk mode?"; then
    zenity --info --title="Kiosk Setup - Updating Firefox" --text="Updating Firefox. Please wait..."
    (
        echo "20"; echo "# Installing latest Firefox..."; sudo apt install -y firefox
        echo "100"; echo "# Firefox update complete."
    ) | zenity --progress --title="Kiosk Setup - Firefox Update" --text="Updating Firefox. Please wait..." --percentage=0 --auto-close --no-cancel --width=300

    # Display Firefox version and installation date after update
    FIREFOX_VERSION=$(firefox --version)
    INSTALL_DATE=$(date +"%Y-%m-%d %H:%M:%S")
    zenity --info --title="Kiosk Setup - Update Complete" --text="Firefox update complete:\n\nVersion: $FIREFOX_VERSION\nInstalled on: $INSTALL_DATE"
fi

# Enable all inputs on startup to allow for configuration
for id in $(xinput --list --id-only); do
    xinput enable "$id"
done

# Prompt for URL for kiosk mode without a cancel button
URL=$(zenity --entry --title="Kiosk Setup - URL" --text="Enter the URL for kiosk mode:" --entry-text="https://example.splunkcloud.com" --no-cancel)
if [[ -z "$URL" ]]; then
    zenity --warning --title="Kiosk Setup" --text="No URL provided. Exiting setup."
    exit 1
fi

# Launch Firefox in Kiosk Mode with the specified URL and wait 3 seconds before showing confirmation
firefox --kiosk "$URL" &
sleep 3

# Confirmation to disable inputs once URL is loaded
zenity --info --title="Kiosk Mode - Confirm" --text="Once the page is loaded and authentication (if any) is complete, click OK to disable keyboard and mouse."

# Disable all input devices (keyboard, mouse, etc.) to prevent exiting kiosk mode
for id in $(xinput --list --id-only); do
    xinput disable "$id"
done

# Disable all USB ports except for critical ones
echo "Disabling USB storage devices..."
sudo rmmod usb_storage  # Disables all USB storage devices

# To disable specific USB devices by ID, use the following approach:
# Example for a specific USB device:
# echo '1-1' | sudo tee /sys/bus/usb/drivers/usb/unbind  # Replace '1-1' with the correct USB device ID
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
Comment=Launch Firefox in kiosk mode
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

# Final message indicating setup completion
zenity --info --title="Kiosk Setup Complete" --text="Kiosk setup is complete. Please log out and log in as the kiosk user to start the kiosk environment."
