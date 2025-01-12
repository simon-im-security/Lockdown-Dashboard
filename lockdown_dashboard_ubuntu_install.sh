#!/bin/bash

# Title: Lockdown Dashboard
# Description: Configures Ubuntu Desktop to display dashboards securely.
# Author: Simon .I
# Version: 2025.01.12

# Function to ensure the script is run as root
check_root() {
    clear
    if [ "$EUID" -ne 0 ]; then
        log_message "Error: Script must be run as root."
        echo "Please run this script as root or with sudo."
        read -p "Press Enter to acknowledge and exit: "
        exit 1
    fi
}

# Function to log messages
log_message() {
    local LOG_TAG="lockdown_dashboard" # Custom tag for logs

    # Ensure logger is installed
    if ! command -v logger &>/dev/null; then
        echo "'logger' not found. Installing..."
        apt install -y bsdutils || {
            echo "Failed to install 'logger'. Exiting."
            exit 1
        }
    fi

    # Log the message
    logger -t "$LOG_TAG" "$1"
}

# Function to set up exit watch and handle cleanup on interruption
setup_exit_watch() {
    # Function to handle cleanup when the script is interrupted
    cleanup() {
        echo -e "\nScript interrupted by user. Performing cleanup..."
        log_message "Script interrupted by user. Performing cleanup."
        # Add any additional cleanup tasks here if needed
        exit 1
    }

    # Set the trap for SIGINT (Ctrl+C)
    trap cleanup SIGINT
    log_message "Exit watch set up successfully."
}

# Function to display the welcome message
display_welcome_message() {
    clear
    log_message "Starting the Lockdown Dashboard Setup."
    read -p "Begin Lockdown Dashboard setup? (y/n): " setup_start
    clear
    if [[ ! "$setup_start" =~ ^[Yy]$ ]]; then
        log_message "Setup aborted by user."
        echo "Setup aborted. Exiting."
        exit 0
    fi
}

# Function to ensure YAD and Caffeine are installed
ensure_yad_and_caffeine_installed() {
    clear
    # Check and install YAD
    if ! command -v yad &>/dev/null; then
        echo "YAD is required to proceed with this script."
        read -p "Do you want to install YAD now? (y/n): " install_yad
        clear
        if [[ "$install_yad" =~ ^[Yy]$ ]]; then
            log_message "Installing YAD..."
            apt update && apt install -y yad
            if ! command -v yad &>/dev/null; then
                log_message "Failed to install YAD."
                echo "Failed to install YAD. Please install it manually and rerun the script."
                exit 1
            fi
            log_message "YAD installed successfully."
        else
            log_message "User declined to install YAD."
            echo "YAD installation is required. Exiting."
            exit 0
        fi
    fi

    # Check and install Caffeine
    if ! dpkg -l | grep -q caffeine; then
        clear
        echo "Caffeine is recommended to prevent the system from sleeping."
        read -p "Do you want to install Caffeine now? (y/n): " install_caffeine
        clear
        if [[ "$install_caffeine" =~ ^[Yy]$ ]]; then
            log_message "Installing Caffeine..."
            apt update && apt install -y caffeine
            if ! dpkg -l | grep -q caffeine; then
                log_message "Failed to install Caffeine."
                echo "Failed to install Caffeine. Please manually configure your power settings to prevent sleep."
            else
                log_message "Caffeine installed successfully."
            fi
        else
            log_message "User declined to install Caffeine."
            echo "Please manually configure your power settings to prevent sleep."
        fi
    else
        log_message "Caffeine is already installed."
    fi
}

# Function to create a dashboard user
create_dashboard_user() {
    clear
    echo "Let's create the dashboard user."
    read -p "Enter the username for the dashboard user: " dashboard_user
    clear
    read -s -p "Enter the password for $dashboard_user: " dashboard_password
    clear

    log_message "Creating dashboard user: $dashboard_user."
    useradd -m -s /bin/bash "$dashboard_user"
    echo "$dashboard_user:$dashboard_password" | chpasswd
    log_message "Dashboard user $dashboard_user created."

    # Disable GNOME Initial Setup for the new user
    log_message "Disabling GNOME Initial Setup for dashboard user."
    mkdir -p /home/$dashboard_user/.config
    echo "yes" > /home/$dashboard_user/.config/gnome-initial-setup-done
    chown -R "$dashboard_user:$dashboard_user" /home/$dashboard_user/.config
}

configure_firefox_shortcuts() {
    clear
    log_message "Creating Firefox shortcuts for provided URLs."

    # Prompt the user for URLs
    read -p "Enter URLs separated by commas (e.g., https://www.google.com, www.microsoft.com): " input_urls

    # Split URLs into an array
    IFS=',' read -ra url_array <<< "$input_urls"

    # Loop through each URL and create a shortcut
    for url in "${url_array[@]}"; do
        # Trim any leading/trailing spaces
        url=$(echo "$url" | xargs)

        # Extract a friendly name for the app
        app_name=$(echo "$url" | sed 's|https\?://||;s|www\.||;s|/.*||')

        # Define the .desktop file paths
        desktop_file="/home/$dashboard_user/.local/share/applications/${app_name}.desktop"
        autostart_file="/home/$dashboard_user/.config/autostart/${app_name}.desktop"

        # Create the .desktop shortcut
        mkdir -p /home/$dashboard_user/.local/share/applications
        cat <<EOF > "$desktop_file"
[Desktop Entry]
Type=Application
Name=$app_name
Exec=firefox --new-window "$url"
Icon=firefox
Terminal=false
Categories=Network;WebBrowser;
EOF

        # Create the autostart shortcut
        mkdir -p /home/$dashboard_user/.config/autostart
        cat <<EOF > "$autostart_file"
[Desktop Entry]
Type=Application
Name=$app_name
Exec=firefox --new-window "$url"
Icon=firefox
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

        # Adjust permissions
        chown -R "$dashboard_user:$dashboard_user" /home/$dashboard_user/.local/share/applications
        chown -R "$dashboard_user:$dashboard_user" /home/$dashboard_user/.config/autostart

        log_message "Shortcut and autostart entry created for $url."
    done

    echo "Firefox shortcuts and autostart entries created successfully."
}

# Function to remove unnecessary software
remove_unnecessary_software() {
    clear
    read -p "Do you want to remove unnecessary software and packages? This is recommended for streamlining the dashboard environment. (y/n): " remove_choice
    if [[ "$remove_choice" =~ ^[Yy]$ ]]; then
        log_message "Removing unnecessary software."
        apt purge -y \
            thunderbird rhythmbox libreoffice-common libreoffice-help-* transmission-common \
            remmina remmina-plugin-* gimp shotwell gnome-calculator gnome-calendar gnome-disk-utility \
            gnome-software gnome-text-editor gnome-user-guide gnome-contacts eog usb-creator-gtk \
            usb-creator-common gnome-characters totem cheese yelp gnome-snapshot simple-scan evince \
            gnome-clocks gnome-startup-applications language-selector-gnome nautilus baobab deja-dup seahorse gnome-font-viewer \
            fwupd gnome-firmware file-roller
        apt autoremove -y
        apt clean

        log_message "Removing unnecessary Snap packages."
        snap remove --purge thunderbird libreoffice gimp shotwell rhythmbox snap-store \
            eog gnome-calculator gnome-calendar totem cheese yelp simple-scan evince gnome-clocks firmware-updater || true

        log_message "Ensuring GNOME Settings App is properly installed."
        while true; do
            if ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
                apt update && apt install -y gnome-control-center && break
            fi
            echo "Waiting for APT lock to be released..."
            sleep 5
        done
        log_message "GNOME Settings App has been successfully installed and is ready for use."

        log_message "Final cleanup: Removing redundant GNOME Help App (if reinstalled)."
        apt purge -y yelp
        log_message "GNOME Help App (yelp) successfully removed as part of the final cleanup."

        # Remove unnecessary application shortcuts
        local shortcuts=(
            /usr/share/applications/org.gnome.PowerStats.desktop
            /usr/share/applications/org.gnome.SystemMonitor.desktop
            /usr/share/applications/update-manager.desktop
            /usr/share/applications/org.gnome.FileRoller.desktop
            /usr/share/applications/gcr-prompter.desktop
            /usr/share/applications/gcr-viewer.desktop
            /usr/share/applications/geoclue-demo-agent.desktop
            /usr/share/applications/gkbd-keyboard-display.desktop
            /usr/share/applications/gnome-initial-setup.desktop
            /usr/share/applications/io.snapcraft.SessionAgent.desktop
            /usr/share/applications/org.freedesktop.IBus.*.desktop
            /usr/share/applications/org.gnome.Logs.desktop
            /usr/share/applications/org.gnome.RemoteDesktop.Handover.desktop
            /usr/share/applications/org.gnome.Tecla.desktop
            /usr/share/applications/org.gnome.Zenity.desktop
            /usr/share/applications/python3.12.desktop
            /usr/share/applications/snap-handle-link.desktop
            /usr/share/applications/software-properties-drivers.desktop
            /usr/share/applications/gnome-language-selector.desktop
            /usr/share/applications/software-properties-gtk.desktop
            /usr/share/applications/nm-connection-editor.desktop
            /usr/share/applications/yad-icon-browser.desktop
            /usr/share/applications/caffeine.desktop
            /usr/share/applications/caffeine-indicator.desktop
        )
        for shortcut in "${shortcuts[@]}"; do
            rm -f "$shortcut"
        done
        log_message "Unnecessary software and shortcuts removed."
    else
        log_message "User opted to skip software removal."
    fi
}

# Function to configure the firewall
configure_firewall() {
    clear
    read -p "Do you want to configure the firewall to allow only necessary ports (DNS, HTTPS, HTTP, and NTP)? (y/n): " firewall_choice
    if [[ "$firewall_choice" =~ ^[Yy]$ ]]; then
        log_message "Configuring firewall to restrict unnecessary traffic."
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing

        # Allow required ports
        ufw allow out 53 comment 'Allow DNS'
        ufw allow out 443 comment 'Allow HTTPS'
        ufw allow out 80 comment 'Allow HTTP'
        ufw allow out 123 comment 'Allow NTP'

        # Enable the firewall
        ufw --force enable
        log_message "Firewall configured: Only DNS, HTTPS, HTTP, and NTP allowed."
    else
        log_message "User opted to skip firewall configuration."
    fi
}

# Function to configure GNOME power and screen lock settings
configure_gnome_power_and_screen() {
    log_message "Configuring GNOME power and screen lock settings."

    # Apply settings for the dashboard user if specified
    if [[ -n "$dashboard_user" ]]; then
        log_message "Applying settings for dashboard user: $dashboard_user"
        su - "$dashboard_user" -c 'gsettings set org.gnome.desktop.session idle-delay 0'
        su - "$dashboard_user" -c 'gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0'
        su - "$dashboard_user" -c 'gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0'
        su - "$dashboard_user" -c 'gsettings set org.gnome.desktop.lockdown disable-lock-screen true'
        su - "$dashboard_user" -c 'gsettings set org.gnome.desktop.screensaver lock-enabled false'
        su - "$dashboard_user" -c 'gsettings set org.gnome.desktop.screensaver idle-activation-enabled false'
        log_message "Settings applied successfully for dashboard user: $dashboard_user"
    fi

    # Apply settings for all users in /home
    log_message "Applying settings for all users in /home."
    for user in $(ls /home); do
        if id "$user" &>/dev/null; then
            log_message "Applying settings for user: $user"
            su - "$user" -c 'gsettings set org.gnome.desktop.session idle-delay 0'
            su - "$user" -c 'gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0'
            su - "$user" -c 'gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0'
            su - "$user" -c 'gsettings set org.gnome.desktop.lockdown disable-lock-screen true'
            su - "$user" -c 'gsettings set org.gnome.desktop.screensaver lock-enabled false'
            su - "$user" -c 'gsettings set org.gnome.desktop.screensaver idle-activation-enabled false'
            log_message "Settings applied successfully for user: $user"
        else
            log_message "User $user does not exist or is invalid. Skipping."
        fi
    done

    log_message "GNOME power and screen lock settings configuration completed."
}

# Function to hide the currently logged-in user
hide_logged_in_user() {
    clear
    local current_user=$(logname)
    read -p "Hide the currently logged-in user ($current_user) from the login window? (y/n): " hide_choice
    if [[ "$hide_choice" =~ ^[Yy]$ ]]; then
        log_message "Hiding user $current_user from the login window."
        echo "[User]" > /var/lib/AccountsService/users/$current_user
        echo "SystemAccount=true" >> /var/lib/AccountsService/users/$current_user
        chmod 600 /var/lib/AccountsService/users/$current_user
        log_message "User $current_user hidden from the login window."
    else
        log_message "User opted not to hide $current_user from the login window."
    fi
}

# Function to modify GNOME Terminal permissions to sudo only
restrict_terminal_access() {
    clear
    read -p "Restrict GNOME Terminal access to sudo users only? (Recommended) (y/n): " restrict_choice
    if [[ "$restrict_choice" =~ ^[Yy]$ ]]; then
        log_message "Restricting GNOME Terminal access to sudo users..."
        chgrp sudo /usr/bin/gnome-terminal
        chmod o-x /usr/bin/gnome-terminal
        log_message "GNOME Terminal access restricted to sudo users."
        echo "GNOME Terminal access has been restricted to sudo users only."
    else
        log_message "User opted not to restrict GNOME Terminal access."
        echo "GNOME Terminal access remains unrestricted."
    fi
}

add_lockdown_dashboard_script() {
    log_message "Adding Lockdown Dashboard script."
    local lockdown_dashboard="/usr/local/bin/lockdown_dashboard.sh"

    # Create the Lockdown Dashboard script
    cat <<'EOF' > "$lockdown_dashboard"
#!/bin/bash
LOG_FILE="$HOME/lockdown_dashboard.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Fetch system information for display
last_restart=$(who -b | awk '{print $3, $4}')
last_update_checked=$(stat -c %y /var/lib/apt/periodic/update-success-stamp 2>/dev/null | cut -d'.' -f1 || echo "Never")
ubuntu_version=$(lsb_release -d | awk -F'\t' '{print $2}')

log_message "Starting Lockdown Dashboard."

# Wait for Firefox processes to start
log_message "Waiting for Firefox windows to launch..."
while ! pgrep -x firefox >/dev/null; do
    log_message "No Firefox process detected. Retrying..."
    sleep 1
done
log_message "Firefox processes detected. Proceeding with dashboard popup after 10 seconds."
sleep 10

# Display the YAD dialog
GTK_THEME=Adwaita:dark yad --title="🔒 Lockdown Dashboard" \
    --width=1000 \
    --height=600 \
    --button="Lock:0" \
    --text="<span foreground='#5DADE2' weight='bold' font='36'>🔒 LOCKDOWN DASHBOARD</span>\n\n
<span font='18'>Clicking <b>Lock</b> will secure your device by disabling input devices and ensuring the system is locked in dashboard mode.</span>\n
<span font='18'>The <b>Lock</b> button is located at the bottom right corner of this window.</span>\n\n
<span font='16'>Ensure your dashboard is ready before proceeding.</span>\n\n
<b><span font='20'>System Information:</span></b>\n
<span font='12'>- Last Restart: <b>$last_restart</b></span>\n
<span font='12'>- Last Update Checked: <b>$last_update_checked</b></span>\n
<span font='12'>- Ubuntu Version: <b>$ubuntu_version</b></span>" \
    --text-align=center || exit 1

# Proceed with locking logic
if [[ $? -eq 0 ]]; then
    log_message "Lock button clicked. Executing input disable script..."
    sudo /usr/local/bin/disable_inputs.sh
    log_message "Inputs disabled."
else
    log_message "YAD window closed without action. No inputs disabled."
fi
EOF

    # Make the script executable
    chmod +x "$lockdown_dashboard"
    log_message "Lockdown Dashboard script added at $lockdown_dashboard."
}

# Function to configure Lockdown Dashboard autostart
configure_lockdown_autostart() {
    log_message "Configuring Lockdown Dashboard to start at login."
    local autostart_file="/home/$dashboard_user/.config/autostart/lockdown_dashboard.desktop"

    mkdir -p /home/$dashboard_user/.config/autostart
    cat <<EOF > "$autostart_file"
[Desktop Entry]
Type=Application
Exec=/usr/local/bin/lockdown_dashboard.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Lockdown Dashboard
Comment=Start Lockdown Dashboard at login
EOF

    chown -R "$dashboard_user:$dashboard_user" /home/$dashboard_user/.config
    log_message "Lockdown Dashboard autostart configured for $dashboard_user."
}

# Function to add Lockdown script to disable inputs
add_lockdown_disable_inputs_script() {
    log_message "Adding Lockdown script to disable inputs."
    local disable_inputs_script="/usr/local/bin/disable_inputs.sh"

    cat <<'EOF' > "$disable_inputs_script"
#!/bin/bash

# Function to log messages
log_message() {
    local LOG_TAG="lockdown_dashboard" # Custom tag for logs
    logger -t "$LOG_TAG" "$1"      # Log the message with the custom tag
}

log_message "Starting USB and PCI input device disabler loop..."

# Infinite loop to monitor and disable USB and PCI input devices
while true; do
    for device in $(find /sys/devices/* -name "inhibited" | grep -E "usb|pci|i8042"); do
        if [ -w "$device" ]; then
            echo 1 > "$device" 2>/dev/null
            if [ $? -eq 0 ]; then
                log_message "Disabled input device: $device"
            else
                log_message "Failed to disable input device: $device"
            fi
        else
            log_message "Device not writable or already disabled: $device"
        fi
    done
    sleep 1  # Avoid excessive CPU usage
done
EOF

    chmod +x "$disable_inputs_script"
    log_message "Lockdown input disable script added at $disable_inputs_script."
}

# Function to configure update scheduler
configure_update_scheduler() {
    log_message "Configuring the update scheduler."

    # Path to the update script
    local update_script="/usr/local/bin/dashboard_update.sh"

    # Create the update script
    cat <<'EOF' > "$update_script"
#!/bin/bash

# Log the update operation
log_file="/var/log/dashboard_update.log"
echo "[$(date)] Starting dashboard update process..." >> "$log_file"

# Perform the update and upgrade
apt -y update ; apt -y upgrade ; snap refresh >> "$log_file" 2>&1

# Wait for 30 seconds to allow processes to settle
sleep 30

# Force a restart
echo "[$(date)] Update complete. Restarting system..." >> "$log_file"
shutdown -r now
EOF

    # Set executable permissions for the script
    chmod +x "$update_script"

    log_message "Update script created at $update_script."

    # Schedule the script using a cron job
    local cron_file="/etc/cron.d/dashboard_update"

    # Generate a random minute between 0 and 59
    local random_minute=$((RANDOM % 60))

    # Write the cron job to run at a random time between 1 AM and 2 AM
    cat <<EOF > "$cron_file"
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
$random_minute 1 * * * root $update_script
EOF

    # Set permissions for the cron file
    chmod 644 "$cron_file"

    log_message "Update scheduler configured. The system will update and restart daily at 1:$random_minute AM."
    echo "The update scheduler has been configured. Updates will occur at 1:$random_minute AM daily."
}

# Function to configure sudoers for input disabling
configure_sudoers_for_inputs() {
    log_message "Configuring sudoers for input disabling."
    local sudoers_entry="/etc/sudoers.d/disable_inputs"

    echo "# Allow disabling inputs without password" > "$sudoers_entry"
    echo "$dashboard_user ALL=(ALL) NOPASSWD: /usr/local/bin/disable_inputs.sh" >> "$sudoers_entry"
    chmod 440 "$sudoers_entry"
    log_message "Sudoers entry configured for $dashboard_user to disable inputs."
}

# Function to add Lockdown app to the menu
add_lockdown_app_to_menu() {
    log_message "Adding Lockdown app to the menu."
    local menu_entry="/usr/share/applications/lockdown.desktop"

    cat <<EOF > "$menu_entry"
[Desktop Entry]
Type=Application
Exec=/usr/local/bin/lockdown_dashboard.sh
Hidden=false
NoDisplay=false
Name=Lockdown Dashboard
Comment=Start the Lockdown Dashboard manually
EOF

    log_message "Lockdown app added to the menu at $menu_entry."
}

configure_caffeine_autostart() {
    log_message "Configuring Caffeine to autostart with gsettings setup after login."

    local autostart_file="/home/$dashboard_user/.config/autostart/caffeine.desktop"
    local script_file="/home/$dashboard_user/start_caffeine_with_gsettings.sh"

    if [[ -z "$dashboard_user" || ! -d "/home/$dashboard_user" ]]; then
        log_message "Error: Invalid or unset dashboard_user: $dashboard_user"
        echo "Dashboard user is invalid or not set. Exiting function."
        return 1
    fi

    log_message "Creating caffeine autostart script at $script_file"
    # Create the script that runs gsettings and starts caffeine
    cat <<EOF > "$script_file"
#!/bin/bash

# Apply GNOME session settings to disable screen blanking
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.screensaver idle-activation-enabled false

# Start Caffeine
caffeine
EOF

    if [[ ! -f "$script_file" ]]; then
        log_message "Failed to create $script_file"
        echo "Error: $script_file was not created. Exiting function."
        return 1
    fi

    chmod +x "$script_file"
    chown "$dashboard_user:$dashboard_user" "$script_file"

    log_message "Creating autostart entry at $autostart_file"
    # Create the autostart .desktop entry
    mkdir -p /home/$dashboard_user/.config/autostart
    cat <<EOF > "$autostart_file"
[Desktop Entry]
Type=Application
Exec=$script_file
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Start Caffeine with GSettings
Comment=Apply GNOME settings and start Caffeine
EOF

    if [[ ! -f "$autostart_file" ]]; then
        log_message "Failed to create $autostart_file"
        echo "Error: $autostart_file was not created. Exiting function."
        return 1
    fi

    chown -R "$dashboard_user:$dashboard_user" /home/$dashboard_user/.config

    log_message "Caffeine autostart configured with GNOME settings setup at $autostart_file."
    echo "Caffeine has been configured to autostart with additional gsettings commands after login."
}

configure_reset_autostart() {
    echo "Adding reset_firefox_settings to autostart..."
    local reset_script="/usr/local/bin/reset_firefox_settings.sh"

    # Create the reset script
    cat <<EOF > "$reset_script"
#!/bin/bash
$(declare -f reset_firefox_settings) # Embed the reset_firefox_settings function
reset_firefox_settings
EOF

    chmod +x "$reset_script"

    # Create an autostart entry
    mkdir -p "/home/$dashboard_user/.config/autostart"
    cat <<EOF > "/home/$dashboard_user/.config/autostart/reset_firefox_settings.desktop"
[Desktop Entry]
Type=Application
Exec=$reset_script
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Reset Firefox Settings
Comment=Resets Firefox settings at login
EOF

    chown -R "$dashboard_user:$dashboard_user" "/home/$dashboard_user/.config/autostart"
    echo "Reset Firefox settings added to autostart for $dashboard_user."
    log_message "Reset Firefox settings added to autostart for $dashboard_user."
}

# Function to reset Firefox settings
reset_firefox_settings() {
    echo "Resetting Firefox settings for the user: $dashboard_user..."
    log_message "Resetting Firefox settings for the user: $dashboard_user..."

    # Path for Snap-based Firefox profiles
    firefox_profile_path="/home/$dashboard_user/snap/firefox/common/.mozilla/firefox"

    # Check if the Firefox profile path exists
    if [ ! -d "$firefox_profile_path" ]; then
        echo "Snap-based Firefox profile directory does not exist. Skipping reset."
        log_message "Snap-based Firefox profile directory not found for $dashboard_user. Skipping reset."
        return
    fi

    # Find the default Firefox profile directory
    profile_dir=$(find "$firefox_profile_path" -type d -name "*.default-release" 2>/dev/null)
    if [ -z "$profile_dir" ]; then
        echo "No default Firefox profile found. Skipping reset."
        log_message "No default Firefox profile found for $dashboard_user. Skipping reset."
        return
    fi

    echo "Found Firefox profile: $profile_dir"

    # Remove all files except the "extensions" folder
    echo "Clearing Firefox profile contents while preserving extensions..."
    find "$profile_dir" -mindepth 1 -maxdepth 1 ! -name "extensions" -exec rm -rf {} \;

    # Adjust permissions
    chown -R "$dashboard_user:$dashboard_user" "$firefox_profile_path"
    echo "Firefox settings reset completed for $dashboard_user."
    log_message "Firefox settings reset completed for $dashboard_user."
}

# Function to confirm and restart the system
confirm_and_restart() {
    clear
    read -p "Setup is complete. Do you want to restart the system now? (y/n): " restart_choice
    if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
        log_message "Restarting the system."
        shutdown -r now
    else
        log_message "Setup complete. User opted to restart later."
        echo "Setup complete. Please restart the system manually to apply changes."
    fi
}

# Orchestrate the script by calling all the functions in sequence
check_root
setup_exit_watch
display_welcome_message
ensure_yad_and_caffeine_installed
create_dashboard_user
configure_firefox_shortcuts
remove_unnecessary_software
configure_firewall
configure_gnome_power_and_screen
hide_logged_in_user
restrict_terminal_access
add_lockdown_dashboard_script
configure_update_scheduler
configure_lockdown_autostart
add_lockdown_disable_inputs_script
configure_sudoers_for_inputs
add_lockdown_app_to_menu
configure_caffeine_autostart
configure_reset_autostart
confirm_and_restart
