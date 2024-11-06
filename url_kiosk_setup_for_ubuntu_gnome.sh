#!/bin/bash
# create-kiosk-setup.sh - Ubuntu GNOME Kiosk Setup Script with conditional USB disablement, auto-login, and user-prompted updates using Firefox
# Author: Simon .I
# Version: 2024.11.06

# Check for Ubuntu and GNOME environment
if ! grep -qi "ubuntu" /etc/os-release || ! echo "$XDG_CURRENT_DESKTOP" | grep -qi "GNOME"; then
    echo "This script is intended for Ubuntu with GNOME desktop only."
    yad --title="Setup Error" --text="This script is intended for Ubuntu with GNOME desktop only. Exiting setup." --button="OK:0"
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root." 
   exit 1
fi

# Step 1: Prompt for Kiosk Username and Password
KIOSK_USER=$(yad --entry --title="Kiosk Username" --text="Enter the username for the kiosk account:")
if [[ -z "$KIOSK_USER" ]]; then
    yad --title="Setup Error" --text="No username provided. Exiting setup." --button="OK:0"
    exit 1
fi

KIOSK_PASSWORD=$(yad --entry --title="Kiosk Password" --text="Enter the password for the kiosk account:" --hide-text)
if [[ -z "$KIOSK_PASSWORD" ]]; then
    yad --title="Setup Error" --text="No password provided. Exiting setup." --button="OK:0"
    exit 1
fi

# Step 2: Create Kiosk User Account
echo "Creating kiosk user account with username: $KIOSK_USER..."
if id "$KIOSK_USER" &>/dev/null; then
    echo "User '$KIOSK_USER' already exists. Skipping creation."
else
    useradd -m -s /bin/bash "$KIOSK_USER"
    echo "$KIOSK_USER:$KIOSK_PASSWORD" | chpasswd
    usermod -aG sudo "$KIOSK_USER"
    echo "Kiosk user created with username: $KIOSK_USER"
fi

# Step 3: Disable GNOME Notifications for Kiosk User
echo "Disabling GNOME notifications for kiosk user..."
sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.desktop.notifications show-banners false

# Step 4: Set Up Auto-Login for Kiosk User
echo "Configuring auto-login for kiosk user..."
AUTOLOGIN_CONFIG="/etc/gdm3/custom.conf"
if ! grep -q "AutomaticLoginEnable = true" "$AUTOLOGIN_CONFIG"; then
    echo -e "\n[daemon]\nAutomaticLoginEnable = true\nAutomaticLogin = $KIOSK_USER" >> "$AUTOLOGIN_CONFIG"
else
    sed -i "s/^AutomaticLogin = .*/AutomaticLogin = $KIOSK_USER/" "$AUTOLOGIN_CONFIG"
    sed -i "s/^AutomaticLoginEnable = .*/AutomaticLoginEnable = true/" "$AUTOLOGIN_CONFIG"
fi

# Step 5: Kiosk Script with Update Prompt and Restart Countdown using `yad`
KIOSK_SCRIPT_PATH="/home/$KIOSK_USER/start-kiosk.sh"

cat << EOF > "$KIOSK_SCRIPT_PATH"
#!/bin/bash
# start-kiosk.sh - Kiosk startup script for updates, then prompting URL, running in fullscreen, and disabling USB

# Prompt to run system and Firefox updates first
if yad --question --title="System Update" --text="Would you like to check for and install system and Firefox updates?"; then
    yad --info --title="Updating System" --text="Updating system and Firefox. This may take a while."

    # Start the update process with a detailed progress bar
    ( 
        echo "10"; echo "# Updating package list..."; sudo apt update
        echo "50"; echo "# Upgrading packages..."; sudo apt -y upgrade
        echo "80"; echo "# Installing latest Firefox..."; sudo apt install -y firefox
        echo "100"; echo "# Updates complete."
    ) | yad --progress --title="System Update" --text="Applying updates..." --percentage=0 --auto-close --width=300

    # Show a countdown before restarting
    for i in {10..1}; do
        echo "$i seconds remaining until restart..."
        yad --notification --text="$i seconds remaining until restart..."
        sleep 1
    done

    yad --info --title="Restarting" --text="The system will now restart to apply updates."
    sudo reboot
    exit 0
fi

# Prompt for URL if no updates are applied
URL=\$(yad --entry --title="Kiosk URL" --text="Enter the URL for kiosk mode:" --entry-text="https://example.splunkcloud.com")
if [[ -z "\$URL" ]]; then
    yad --warning --title="Kiosk Setup" --text="No URL provided. Exiting setup."
    exit 1
fi

# Confirm URL Setup
yad --info --title="Kiosk Mode" --text="URL set to: \$URL. The browser will now open in kiosk mode."

# Launch Firefox in Kiosk Mode with the Specified URL
firefox --kiosk "\$URL"

# Disable all USB ports except HDMI and Ethernet
echo "Disabling all USB ports except for HDMI and Ethernet..."
UDEV_RULES_FILE="/etc/udev/rules.d/99-disable-usb.rules"
cat << 'RULES' > "\$UDEV_RULES_FILE"
# Disable all USB devices except for HDMI and Ethernet
ACTION=="add", SUBSYSTEM=="usb", ATTR{authorized}="0"
# Allow USB devices based on specific conditions (e.g., Ethernet and HDMI adapters)
RULES

# Reload udev rules to apply changes
udevadm control --reload-rules
udevadm trigger

yad --info --title="Kiosk Setup" --text="USB ports are now disabled until the next reboot."
EOF

# Make Kiosk Script Executable
chmod +x "$KIOSK_SCRIPT_PATH"
chown "$KIOSK_USER":"$KIOSK_USER" "$KIOSK_SCRIPT_PATH"

# Step 6: Configure Kiosk Script to Run on Startup
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
Name[en_US]=KioskMode
Name=KioskMode
Comment[en_US]=Launch Kiosk Mode
Comment=Launch Kiosk Mode
EOF

chown -R "$KIOSK_USER":"$KIOSK_USER" "$AUTOSTART_DIR"

# Step 7: Install and Start Caffeine to Prevent Sleep/Dimming
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

# Step 8: Check for Full-Disk Encryption (Warn Only)
echo "Checking for full-disk encryption..."
if ! lsblk -o name,type,fstype,mountpoint | grep -q "crypto_LUKS"; then
    yad --warning --title="Security Notice" --text="Full-disk encryption (FDE) not detected. We recommend enabling FDE for additional security."
fi

# Step 9: Disable Additional Services and Limit System Access
echo "Disabling unnecessary services and restricting system access..."

# Disable CUPS (printing services)
systemctl disable --now cups

# Restrict terminal access for kiosk user
chmod -s /usr/bin/gnome-terminal

# Disable SSH to enhance security
echo "Disabling SSH service..."
systemctl disable --now ssh

# Step 10: Final Message
echo "Kiosk setup complete. The system will auto-login as the kiosk user and prompt for a URL on each startup."
echo "USB ports will be disabled after confirming the URL each startup. Please reboot the system to apply all settings."
