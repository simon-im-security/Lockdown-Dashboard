#!/bin/bash
# ubuntu-kiosk-setup.sh - Ubuntu GNOME Kiosk Setup with First-Login Configuration
# Author: Simon .I
# Version: 2024.11.07

LOG_FILE="/var/log/kiosk_setup.log"
echo "Kiosk setup started at $(date)" > "$LOG_FILE"

log_info() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - INFO - $1" | tee -a "$LOG_FILE"
}

# Stage 1: Check if script is run as root
stage1_check_root() {
    log_info "Stage 1: Checking if script is run as root"
    if [[ $EUID -ne 0 ]]; then
        zenity --error --text="This script must be run as root." | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Stage 2: Check for Ubuntu GNOME environment
stage2_check_gnome_ubuntu() {
    log_info "Stage 2: Checking for Ubuntu GNOME environment"
    if ! grep -qi "ubuntu" /etc/os-release || ! echo "$XDG_CURRENT_DESKTOP" | grep -qi "GNOME"; then
        zenity --error --text="This script is intended for Ubuntu with GNOME desktop only. Exiting setup." | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Stage 3: Get kiosk username and password
stage3_get_kiosk_user() {
    log_info "Stage 3: Getting kiosk username and password"
    KIOSK_USER=$(zenity --entry --title="Kiosk Setup - Username" --text="Enter the username for the kiosk account:")
    if [[ ! "$KIOSK_USER" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        zenity --error --text="Invalid username. Only alphanumeric characters, dots, hyphens, and underscores are allowed."
        exit 1
    fi

    KIOSK_PASSWORD=$(zenity --password --title="Kiosk Setup - Password" --text="Enter the password for the kiosk account:")
    if [[ -z "$KIOSK_PASSWORD" ]]; then
        zenity --error --text="No password provided. Exiting setup."
        exit 1
    fi

    if id "$KIOSK_USER" &>/dev/null; then
        log_info "User '$KIOSK_USER' already exists."
    else
        useradd -m -s /bin/bash "$KIOSK_USER"
        echo "$KIOSK_USER:$KIOSK_PASSWORD" | chpasswd
        log_info "Kiosk user created with username: $KIOSK_USER."
    fi
}

# Stage 4: Suppress initial GNOME setup prompts for kiosk user
stage4_suppress_initial_setup() {
    log_info "Stage 4: Suppressing GNOME initial setup prompts for kiosk user"
    sudo -u "$KIOSK_USER" mkdir -p "/home/$KIOSK_USER/.config"
    sudo -u "$KIOSK_USER" touch "/home/$KIOSK_USER/.config/gnome-initial-setup-done"
    rm -f /home/"$KIOSK_USER"/.config/autostart/gnome-getting-started*
    chown -R "$KIOSK_USER":"$KIOSK_USER" "/home/$KIOSK_USER/.config"
}

# Stage 5: Prompt the user to set up autologin manually
stage5_autologin_setup() {
    log_info "Stage 5: Autologin setup instructions"
    zenity --info --title="Autologin Setup Required" --text="To enable autologin for the kiosk account, please:\n\n1. Open 'Settings'.\n2. Search for 'Users'.\n3. Select the kiosk user: $KIOSK_USER.\n4. Unlock (if required) and enable 'Automatic Login'.\n\nClick OK once done."
}

# Stage 6: Install necessary tools
stage6_install_tools() {
    log_info "Stage 6: Installing necessary tools"
    apt update && apt install -y xinput usb_modeswitch caffeine firefox | tee -a "$LOG_FILE"
}

# Stage 7: Disable notifications and updates
stage7_disable_notifications() {
    log_info "Stage 7: Disabling notifications and update prompts"
    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.desktop.notifications show-banners false
    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.software download-updates false
    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.software allow-updates false
    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.software enable-notifications false
}

# Stage 8: Set GNOME preferences for the kiosk session
stage8_set_gnome_preferences() {
    log_info "Stage 8: Setting GNOME preferences for kiosk user"
    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.desktop.session idle-delay 0
    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
}

# Stage 9: Ensure Firefox is installed
stage9_install_firefox() {
    log_info "Stage 9: Ensuring Firefox is installed"
    if ! command -v firefox &>/dev/null; then
        apt install -y firefox | tee -a "$LOG_FILE"
    fi
}

# Stage 10: Install and configure Caffeine
stage10_install_caffeine() {
    log_info "Stage 10: Installing and configuring Caffeine"
    apt install -y caffeine | tee -a "$LOG_FILE"
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
}

# Stage 11: Check Full Disk Encryption (optional)
stage11_check_fde() {
    log_info "Stage 11: Checking Full Disk Encryption"
    if ! lsblk -o name,type,fstype,mountpoint | grep -q "crypto_LUKS"; then
        zenity --info --title="Security Notice" --text="Full-disk encryption (FDE) is not enabled. Recommended but optional." | tee -a "$LOG_FILE"
    fi
}

# Stage 12: Disable SSH service
stage12_disable_ssh() {
    log_info "Stage 12: Disabling SSH service if running"
    if systemctl is-active --quiet ssh; then
        systemctl disable --now ssh | tee -a "$LOG_FILE"
    fi
}

# Stage 13: Setup first-login service with systemd to avoid terminal dependency
stage13_setup_first_login_service() {
    log_info "Stage 13: Setting up first login service with systemd"

    # Create first-login script
    cat << 'EOF' > "/home/$KIOSK_USER/first-login.sh"
#!/bin/bash

# Welcome prompt
zenity --question --title="Welcome to Kiosk Setup" --text="Welcome to Kiosk setup. Click OK to proceed or Cancel to exit." || exit 0

# Update options prompt
UPDATE_OPTION=$(zenity --list --title="Kiosk Setup - Update Options" \
    --text="Would you like to update Firefox, the OS, or skip updates?\n\n*Default to skip after 5 minutes.*" \
    --radiolist --column="Select" --column="Option" FALSE "Firefox" FALSE "OS" TRUE "Skip" --timeout=300)

# Execute based on choice
case "$UPDATE_OPTION" in
    "Firefox")
        zenity --info --title="Updating Firefox" --text="Updating Firefox. Please wait..."
        sudo apt install -y firefox
        zenity --info --title="Update Complete" --text="Firefox update complete."
        ;;
    "OS")
        zenity --info --title="Updating OS" --text="Updating system. Please wait..."
        sudo apt update && sudo apt -y upgrade && sudo apt -y autoremove
        zenity --info --title="Update Complete" --text="OS update complete. Restart recommended."
        ;;
    "Skip"|"")
        ;;
esac

# Prompt for URL to start in kiosk mode
URL=$(zenity --entry --title="Kiosk Setup - URL" --text="Enter the URL for kiosk mode:")
echo "$URL" > "$HOME/.kiosk_url"
firefox --kiosk "$URL" &

# Final lock confirmation
zenity --question --title="Lock System" --text="Ready to lock the system? USB devices and peripherals will be disabled." || exit 0

# Disable all input devices using xinput
for id in $(xinput --list --id-only); do
    xinput disable "$id"
done

# Disable USB storage
sudo modprobe -r usb_storage
EOF

    # Make script executable and set ownership
    chmod +x "/home/$KIOSK_USER/first-login.sh"
    chown "$KIOSK_USER":"$KIOSK_USER" "/home/$KIOSK_USER/first-login.sh"

    # Create systemd service to run on login
    cat << EOF > "/etc/systemd/system/kiosk-first-login.service"
[Unit]
Description=First Login Kiosk Setup
After=graphical.target

[Service]
User=$KIOSK_USER
ExecStart=/home/$KIOSK_USER/first-login.sh
Type=oneshot
RemainAfterExit=true

[Install]
WantedBy=default.target
EOF

    # Enable systemd service for the kiosk user
    systemctl enable kiosk-first-login.service
}

# Execute all stages
stage1_check_root
stage2_check_gnome_ubuntu
stage3_get_kiosk_user
stage4_suppress_initial_setup
stage5_autologin_setup
stage6_install_tools
stage7_disable_notifications
stage8_set_gnome_preferences
stage9_install_firefox
stage10_install_caffeine
stage11_check_fde
stage12_disable_ssh
stage13_setup_first_login_service

zenity --info --title="Kiosk Setup Complete" --text="Initial setup complete. Log in as the kiosk user to continue with configuration." | tee -a "$LOG_FILE"
