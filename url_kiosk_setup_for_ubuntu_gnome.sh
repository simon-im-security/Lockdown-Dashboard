#!/bin/bash
# create-kiosk-setup.sh - Ubuntu GNOME Kiosk Setup Script with improved autologin, conditional input lockdown, and Firefox kiosk mode
# Author: Simon .I
# Version: 2024.11.07

# Check for Ubuntu and GNOME environment
if ! grep -qi "ubuntu" /etc/os-release || ! echo "$XDG_CURRENT_DESKTOP" | grep -qi "GNOME"; then
    zenity --error --text="This script is intended for Ubuntu with GNOME desktop only. Exiting setup."
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

# Step 2: Prompt for Kiosk Username and Password without Cancel Option
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

# Step 3: Create Kiosk User Account
echo "Creating kiosk user account with username: $KIOSK_USER..."
if id "$KIOSK_USER" &>/dev/null; then
    echo "User '$KIOSK_USER' already exists. Skipping creation."
else
    useradd -m -s /bin/bash "$KIOSK_USER"
    echo "$KIOSK_USER:$KIOSK_PASSWORD" | chpasswd
    usermod -aG sudo "$KIOSK_USER"
    echo "Kiosk user created with username: $KIOSK_USER"
fi

# Step 4: Disable GNOME Notifications for Kiosk User
echo "Disabling GNOME notifications for kiosk user..."
sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.desktop.notifications show-banners false

# Step 5: Set Up Improved Auto-Login for Kiosk User
echo "Configuring auto-login for kiosk user..."
AUTOLOGIN_CONFIG="/etc/gdm3/custom.conf"
if ! grep -q "AutomaticLoginEnable = true" "$AUTOLOGIN_CONFIG"; then
    echo -e "\n[daemon]\nAutomaticLoginEnable = true\nAutomaticLogin = $KIOSK_USER" >> "$AUTOLOGIN_CONFIG"
else
    sed -i "s/^AutomaticLogin = .*/AutomaticLogin = $KIOSK_USER/" "$AUTOLOGIN_CONFIG"
    sed -i "s/^AutomaticLoginEnable = .*/AutomaticLoginEnable = true/" "$AUTOLOGIN_CONFIG"
fi

# Additional configuration for LightDM (alternative method)
sudo mkdir -p /etc/lightdm/lightdm.conf.d
sudo bash -c "cat > /etc/lightdm/lightdm.conf.d/50-myconfig.conf <<EOF
[Seat:*]
autologin-user=$KIOSK_USER
EOF
"

# Step 6: Ensure Firefox is Installed
if ! command -v firefox &> /dev/null; then
    echo "Firefox not found. Installing Firefox..."
    apt update && apt install -y firefox
fi

# Step 7: Create Kiosk Script with Update Prompt, Firefox Kiosk Mode, and Conditional Input Lockdown
KIOSK_SCRIPT_PATH="/home/$KIOSK_USER/start-kiosk.sh"

cat << 'EOF' > "$KIOSK_SCRIPT_PATH"
#!/bin/bash
# start-kiosk.sh - Kiosk startup script with Firefox Kiosk Mode and Conditional Input Lockdown

# Enable all inputs on startup to allow for configuration
for id in $(xinput --list --id-only); do
    xinput enable "$id"
done

# Prompt to run system and Firefox updates first
if zenity --question --title="Kiosk Setup - System Update" --text="Would you like to check for and install system and Firefox updates?"; then
    zenity --info --title="Kiosk Setup - Updating System" --text="Updating system and Firefox. Please wait..."

    # Start the update process with a detailed progress bar using zenity
    (
        echo "10" ; echo "# Updating package list..." ; sudo apt update
        echo "50" ; echo "# Upgrading packages..." ; sudo apt -y upgrade
        echo "80" ; echo "# Installing latest Firefox..." ; sudo apt install -y firefox
        echo "100" ; echo "# Updates complete."
    ) | zenity --progress --title="Kiosk Setup - System Update" --text="Applying updates..." --percentage=0 --auto-close --no-cancel --width=300
fi

# Prompt for URL after updates
URL=$(zenity --entry --title="Kiosk Setup - URL" --text="Enter the URL for kiosk mode:" --entry-text="https://example.splunkcloud.com")
if [[ -z "$URL" ]]; then
    zenity --warning --title="Kiosk Setup" --text="No URL provided. Exiting setup."
    exit 1
fi

# Confirm URL setup
zenity --info --title="Kiosk Mode" --text="URL set to: $URL. The browser will now open in kiosk mode."

# Launch Firefox in Kiosk Mode with the specified URL
firefox --kiosk "$URL" &

# Wait for confirmation before disabling inputs
zenity --info --title="Kiosk Setup - Confirm" --text="Once the page is loaded and authentication (if any) is complete, click OK to disable keyboard and mouse."

# Disable all input devices (keyboard, mouse, etc.) to prevent exiting kiosk mode
for id in $(xinput --list --id-only); do
    xinput disable "$id"
done

zenity --info --title="Kiosk Setup" --text="Keyboard and mouse inputs are now disabled."
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
