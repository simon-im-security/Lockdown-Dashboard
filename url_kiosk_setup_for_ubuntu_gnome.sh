#!/bin/bash
# create-kiosk-setup.sh - Ubuntu GNOME Kiosk Setup Script with Autologin Instructions, Update Options, URL Memory, Timeout, Input Lockdown, USB Disable, Caffeine, FDE Check, and Logging
# Author: Simon .I
# Version: 2024.11.07

# Log file
LOG_FILE="/var/log/kiosk_setup.log"
echo "Kiosk setup started at $(date)" > "$LOG_FILE"

# Helper function to log messages
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

# Stage 2: Check Ubuntu GNOME environment
stage2_check_gnome_ubuntu() {
    log_info "Stage 2: Checking for Ubuntu GNOME environment"
    if ! grep -qi "ubuntu" /etc/os-release || ! echo "$XDG_CURRENT_DESKTOP" | grep -qi "GNOME"; then
        zenity --error --text="This script is intended for Ubuntu with GNOME desktop only. Exiting setup." | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Stage 3: Get and validate kiosk username and password
stage3_get_kiosk_user() {
    log_info "Stage 3: Getting kiosk username and password"
    KIOSK_USER=$(zenity --entry --title="Kiosk Setup - Username" --text="Enter the username for the kiosk account:")
    if [[ ! "$KIOSK_USER" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        zenity --error --text="Invalid username. Only alphanumeric characters, dots, hyphens, and underscores are allowed." | tee -a "$LOG_FILE"
        exit 1
    fi

    KIOSK_PASSWORD=$(zenity --password --title="Kiosk Setup - Password" --text="Enter the password for the kiosk account:")
    if [[ -z "$KIOSK_PASSWORD" ]]; then
        zenity --error --text="No password provided. Exiting setup." | tee -a "$LOG_FILE"
        exit 1
    fi

    # Create the kiosk user if not existing
    if id "$KIOSK_USER" &>/dev/null; then
        log_info "User '$KIOSK_USER' already exists."
    else
        useradd -m -s /bin/bash "$KIOSK_USER"
        echo "$KIOSK_USER:$KIOSK_PASSWORD" | chpasswd
        log_info "Kiosk user created with username: $KIOSK_USER as a standard user."
    fi
}

# Stage 4: Guide user through autologin setup
stage4_autologin_setup() {
    log_info "Stage 4: Autologin setup instructions"
    zenity --info --title="Autologin Setup Required" --text="To enable autologin for the kiosk account, please:\n\n1. Open 'Settings'.\n2. Search for 'Users'.\n3. Select the kiosk user: $KIOSK_USER.\n4. Unlock (if required) and enable 'Automatic Login'.\n\nClick OK once done."
}

# Stage 5: Install necessary tools
stage5_install_tools() {
    log_info "Stage 5: Installing necessary tools"
    apt install -y xinput usb_modeswitch | tee -a "$LOG_FILE"
}

# Stage 6: Disable GNOME notifications and updates
stage6_disable_notifications() {
    log_info "Stage 6: Disabling notifications and update prompts"
    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.desktop.notifications show-banners false
    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.software download-updates false
    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.software allow-updates false
    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.software enable-notifications false
}

# Stage 7: Configure GNOME preferences for the kiosk user
stage7_set_gnome_preferences() {
    log_info "Stage 7: Setting GNOME preferences for kiosk user"
    sudo -u "$KIOSK_USER" mkdir -p "/home/$KIOSK_USER/.config"
    sudo -u "$KIOSK_USER" touch "/home/$KIOSK_USER/.config/gnome-initial-setup-done"
    rm -f /home/"$KIOSK_USER"/.config/autostart/gnome-getting-started*

    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.desktop.session idle-delay 0
    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
    sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
}

# Stage 8: Ensure Firefox is installed
stage8_install_firefox() {
    log_info "Stage 8: Ensuring Firefox is installed"
    if ! command -v firefox &>/dev/null; then
        apt update && apt install -y firefox | tee -a "$LOG_FILE"
    fi
}

# Stage 9: Prompt for update option and handle accordingly
stage9_update_options() {
    log_info "Stage 9: Prompting for update options"
    UPDATE_OPTION=$(zenity --list --title="Kiosk Setup - Update Options" \
        --text="Do you want to update Firefox, update the OS, or continue to kiosk mode?\n\n*Defaults to Kiosk Mode after 5 minutes.*" \
        --radiolist --column="Select" --column="Option" FALSE "Firefox" FALSE "OS" TRUE "Kiosk" --timeout=300)

    if [[ -z "$UPDATE_OPTION" ]]; then
        UPDATE_OPTION="Kiosk"
        log_info "Timeout reached, defaulting to Kiosk Mode"
    fi

    if [[ "$UPDATE_OPTION" == "Firefox" ]]; then
        log_info "Updating Firefox"
        apt install -y firefox | tee -a "$LOG_FILE"
    elif [[ "$UPDATE_OPTION" == "OS" ]]; then
        log_info "Updating operating system"
        apt update && apt -y upgrade && apt -y autoremove | tee -a "$LOG_FILE"
        zenity --info --title="OS Update Complete" --text="System update complete. Restart to apply changes."
        exit 0
    fi
}

# Stage 10: Configure kiosk URL, input lockdown, and USB disable
stage10_configure_kiosk_mode() {
    log_info "Stage 10: Configuring kiosk mode with URL and input lockdown"
    LAST_URL_FILE="/home/$KIOSK_USER/.kiosk_config/last_url"
    mkdir -p "/home/$KIOSK_USER/.kiosk_config"
    last_url="https://example.splunkcloud.com"
    [[ -f "$LAST_URL_FILE" ]] && last_url=$(cat "$LAST_URL_FILE")

    URL=$(zenity --entry --title="Kiosk Setup - URL" --text="Enter the URL for kiosk mode:\n\n*Defaults to last used URL after 5 minutes.*" --entry-text="$last_url" --timeout=300)
    [[ -z "$URL" ]] && URL="$last_url"
    echo "$URL" > "$LAST_URL_FILE"
    
    firefox --kiosk "$URL" &
    sleep 3
    
    for id in $(xinput --list --id-only); do
        xinput disable "$id"
    done
    sudo rmmod usb_storage
}

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

# Stage 12: Check if Full Disk Encryption is enabled
stage12_check_fde() {
    log_info "Stage 12: Checking for Full Disk Encryption"
    if ! lsblk -o name,type,fstype,mountpoint | grep -q "crypto_LUKS"; then
        zenity --info --title="Security Notice" --text="Full-disk encryption (FDE) is not enabled. Recommended but optional." | tee -a "$LOG_FILE"
    fi
}

# Stage 13: Disable SSH if enabled
stage13_disable_ssh() {
    log_info "Stage 13: Disabling SSH if running"
    if systemctl is-active --quiet ssh; then
        systemctl disable --now ssh | tee -a "$LOG_FILE"
    fi
}

# Execute stages
stage1_check_root
stage2_check_gnome_ubuntu
stage3_get_kiosk_user
stage4_autologin_setup
stage5_install_tools
stage6_disable_notifications
stage7_set_gnome_preferences
stage8_install_firefox
stage9_update_options
stage10_configure_kiosk_mode
stage11_install_caffeine
stage12_check_fde
stage13_disable_ssh

zenity --info --title="Kiosk Setup Complete" --text="Setup complete. Restart system to apply changes." | tee -a "$LOG_FILE"
