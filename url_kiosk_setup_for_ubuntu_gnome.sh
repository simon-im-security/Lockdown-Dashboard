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

# Stage 4: Prompt the user to set up autologin manually
stage4_autologin_setup() {
    log_info "Stage 4: Autologin setup instructions"
    zenity --info --title="Autologin Setup Required" --text="To enable autologin for the kiosk account, please:\n\n1. Open 'Settings'.\n2. Search for 'Users'.\n3. Select the kiosk user: $KIOSK_USER.\n4. Unlock (if required) and enable 'Automatic Login'.\n\nClick OK once done."
}

# Stage 5: Install necessary tools
stage5_install_tools() {
    log_info "Stage 5: Installing necessary tools"
    apt update && apt install -y xinput usb_modeswitch caffeine firefox | tee -a "$LOG_FILE"
}

# Stage 6: Disable notifications and updates
stage6_disable_notifications() {
    log_info "Stage 6: Disabling notifications and update prompts"
    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.desktop.notifications show-banners false
    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.software download-updates false
    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.software allow-updates false
    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.software enable-notifications false
}

# Stage 7: Set GNOME preferences for the kiosk session
stage7_set_gnome_preferences() {
    log_info "Stage 7: Setting GNOME preferences for kiosk user"
    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.desktop.session idle-delay 0
    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
}

# Stage 8: Ensure Firefox is installed
stage8_install_firefox() {
    log_info "Stage 8: Ensuring Firefox is installed"
    if ! command -v firefox &>/dev/null; then
        apt install -y firefox | tee -a "$LOG_FILE"
    fi
}

# Stage 9: Update options and URL setup integrated in first login
# Stage 10: Configure kiosk mode with URL prompt on first login
# Stage 11: Install and configure Caffeine
stage11_install_caffeine() {
    log_info "Stage 11: Installing and configuring Caffeine"
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

# Stage 12: Check Full Disk Encryption (optional)
stage12_check_fde() {
    log_info "Stage 12: Checking Full Disk Encryption"
    if ! lsblk -o name,type,fstype,mountpoint | grep -q "crypto_LUKS"; then
        zenity --info --title="Security Notice" --text="Full-disk encryption (FDE) is not enabled. Recommended but optional." | tee -a "$LOG_FILE"
    fi
}

# Stage 13: Disable SSH service
stage13_disable_ssh() {
    log_info "Stage 13: Disabling SSH service if running"
    if systemctl is-active --quiet ssh; then
        systemctl disable --now ssh | tee -a "$LOG_FILE"
    fi
}

# Stage 14: Setup first-login script and URL prompt
stage14_setup_first_login() {
    log_info "Stage 14: Setting up first login script"

    # Create a flag to indicate first login setup
    echo "first_login=true" > "/home/$KIOSK_USER/.first_login_flag"

    # Append first-login code to .bashrc to prompt for URL and updates on first login
    cat << 'EOF' >> "/home/$KIOSK_USER/.bashrc"
if [ -f "$HOME/.first_login_flag" ]; then
    zenity --question --title="Welcome to Kiosk Setup" --text="Welcome to Kiosk setup. Click OK to proceed or Cancel to exit." || exit 0

    # Ask if user wants to update OS or Firefox
    UPDATE_OPTION=$(zenity --list --title="Kiosk Setup - Update Options" \
        --text="Would you like to update Firefox, the OS, or skip updates?\n\n*Default to skip after 5 minutes.*" \
        --radiolist --column="Select" --column="Option" FALSE "Firefox" FALSE "OS" TRUE "Skip" --timeout=300)

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

    # Remove the first login flag to prevent re-running on subsequent logins
    rm -f "$HOME/.first_login_flag"
fi
EOF

    # Set ownership for the first login flag and updated .bashrc
    chown "$KIOSK_USER":"$KIOSK_USER" "/home/$KIOSK_USER/.first_login_flag" "/home/$KIOSK_USER/.bashrc"
}

# Execute all stages
stage1_check_root
stage2_check_gnome_ubuntu
stage3_get_kiosk_user
stage4_autologin_setup
stage5_install_tools
stage6_disable_notifications
stage7_set_gnome_preferences
stage8_install_firefox
stage11_install_caffeine
stage12_check_fde
stage13_disable_ssh
stage14_setup_first_login

zenity --info --title="Kiosk Setup Complete" --text="Initial setup complete. Log in as the kiosk user to continue with configuration." | tee -a "$LOG_FILE"
