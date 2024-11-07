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

# Stage 5: Enable autologin
stage5_autologin_setup() {
    log_info "Stage 5: Enabling autologin for kiosk user"
    sed -i "s/^#  AutomaticLoginEnable = true/AutomaticLoginEnable = true/" /etc/gdm3/custom.conf
    sed -i "s/^#  AutomaticLogin = .*/AutomaticLogin = $KIOSK_USER/" /etc/gdm3/custom.conf
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

# Stage 9: Create the GNOME Kiosk Session
stage9_create_kiosk_session() {
    log_info "Stage 9: Creating custom GNOME kiosk session"

    # Create kiosk session file
    cat << EOF > /usr/share/xsessions/kiosk.desktop
[Desktop Entry]
Name=Kiosk
Comment=Custom kiosk session
Exec=gnome-session --session=kiosk
Type=Application
DesktopNames=Kiosk;GNOME
EOF

    # Define the custom session
    cat << EOF > /usr/share/gnome-session/sessions/kiosk.session
[GNOME Session]
Name=Kiosk
RequiredComponents=run-my-app;
EOF

    # Set the kiosk session as the default session for the user
    mkdir -p /var/lib/AccountsService/users/
    cat << EOF > /var/lib/AccountsService/users/$KIOSK_USER
[User]
XSession=kiosk
SystemAccount=false
EOF
}

# Stage 10: Create a Desktop Entry to Run the Kiosk Application
stage10_create_application_entry() {
    log_info "Stage 10: Creating desktop entry for the kiosk application"
    cat << EOF > /usr/share/applications/run-my-app.desktop
[Desktop Entry]
Name=My-Application
Exec=bash /home/$KIOSK_USER/first-login.sh
Type=Application
NoDisplay=true
EOF
}

# Stage 11: Create the First-Login Script with Zenity Messages and Logic
stage11_create_first_login_script() {
    log_info "Stage 11: Setting up the first-login script for kiosk"

    # Create first-login script
    cat << 'EOF' > "/home/$KIOSK_USER/first-login.sh"
#!/bin/bash

# Allow access to the display for xinput commands
xhost +local:

# Welcome prompt
zenity --question --title="Welcome to Kiosk Setup" --text="Welcome to Kiosk setup. Click OK to proceed or Cancel to exit." --ok-label="OK" --cancel-label="Cancel" || exit 0

# Update options prompt
UPDATE_OPTION=$(zenity --list --title="Kiosk Setup - Update Options" \
    --text="Would you like to update Firefox, the OS, or skip updates?\n\n*Default to skip after 5 minutes.*" \
    --radiolist --column="Select" --column="Option" FALSE "Firefox" FALSE "OS" TRUE "Skip" --timeout=300 --width=600 --height=400)

case "$UPDATE_OPTION" in
    "Firefox")
        zenity --progress --title="Updating Firefox" --text="Updating Firefox... Please wait." --percentage=0 --pulsate --no-cancel --width=600 &
        APT_PID=$!
        sudo apt-get install -y firefox &> /dev/null &
        wait $APT_PID
        zenity --info --title="Update Complete" --text="Firefox update complete." --width=400
        ;;
    "OS")
        gnome-software --mode=updates &
        zenity --info --title="System Update" --text="The system update app has opened.\n\nPlease complete the update and restart the device. Once restarted, log in again to continue with the kiosk setup." --width=400
        exit 0
        ;;
    "Skip"|"")
        ;;
esac

# URL prompt for kiosk mode
URL=$(zenity --entry --title="Kiosk Setup - URL" --text="Enter the URL for kiosk mode:")
echo "$URL" > "$HOME/.kiosk_url"
firefox --kiosk "$URL" &
sleep 3

# Lock system prompt
zenity --info --title="Lock System" --text="Click OK to lock the system and disable peripherals." --ok-label="OK"

# Disable input devices
for id in $(xinput --list --id-only); do
    xinput disable "$id"
done

# Disable USB storage
sudo modprobe -r usb_storage
EOF

    chmod +x "/home/$KIOSK_USER/first-login.sh"
    chown "$KIOSK_USER":"$KIOSK_USER" "/home/$KIOSK_USER/first-login.sh"
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
stage9_create_kiosk_session
stage10_create_application_entry
stage11_create_first_login_script

zenity --info --title="Kiosk Setup Complete" --text="Initial setup complete. Please restart the system and log in as the kiosk user ($KIOSK_USER) to continue." | tee -a "$LOG_FILE"
