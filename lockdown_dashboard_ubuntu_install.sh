#!/bin/bash

# Title: Lockdown Dashboard
# Description: Configures Ubuntu Desktop to display dashboards securely.
# Author: Simon .I
# Version: 2025.01.14

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
            apt install -y yad
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
            apt install -y caffeine
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
Exec=bash -c 'while ! ping -c 1 -W 1 8.8.8.8 &>/dev/null; do sleep 1; done; firefox --private-window "$url"'
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
Exec=bash -c 'while ! ping -c 1 -W 1 8.8.8.8 &>/dev/null; do sleep 1; done; firefox --private-window "$url"'
Icon=firefox
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

        # Adjust permissions
        chown -R "$dashboard_user:$dashboard_user" /home/$dashboard_user/.local/share/applications
        chown -R "$dashboard_user:$dashboard_user" /home/$dashboard_user/.config/autostart

        log_message "Shortcut and autostart entry created for $url."
    done

    echo "Firefox shortcuts and autostart entries created successfully with internet connectivity check."
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
                apt install -y gnome-control-center && break
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
SESSION_FILE="/tmp/lockdown_dashboard_session"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Fetch system information for display
last_restart=$(who -b | awk '{print $3, $4}')
last_update_checked=$(stat -c %y /var/lib/apt/periodic/update-success-stamp 2>/dev/null | cut -d'.' -f1 || echo "Never")
ubuntu_version=$(lsb_release -d | awk -F'\t' '{print $2}')

log_message "Starting Lockdown Dashboard."

# Function to display the main YAD dialog
display_main_dialog() {
    GTK_THEME=Adwaita:dark yad --title="🔒 Lockdown Dashboard" \
        --width=1000 \
        --height=600 \
        --button="Lock:0" \
        --text="\n
<span foreground='#5DADE2' weight='bold' font='36'>🔒 LOCKDOWN DASHBOARD</span>\n\n
<span font='18'>Clicking <b>Lock</b> will secure your device by disabling input devices and ensuring the system is locked in dashboard mode.</span>\n
<span font='18'>The <b>Lock</b> button is located at the bottom right corner of this window.</span>\n\n
<span font='16'>Ensure your dashboard is ready before proceeding.</span>\n\n
<b><span font='20'>System Information:</span></b>\n
<span font='12'>- Last Restart: <b>$last_restart</b></span>\n
<span font='12'>- Last Update Checked: <b>$last_update_checked</b></span>\n
<span font='12'>- Ubuntu Version: <b>$ubuntu_version</b></span>" \
        --text-align=center || exit 1

    # Show the confirmation dialog if "Lock" is clicked
    if [[ $? -eq 0 ]]; then
        log_message "Lock button clicked. Showing confirmation prompt."
        display_confirmation_dialog
    fi
}

# Function to display the confirmation dialog
display_confirmation_dialog() {
    GTK_THEME=Adwaita:dark yad --title="🔒 Lockdown Dashboard" \
        --width=800 \
        --height=350 \
        --button="Back:1" \
        --button="Lock Now:0" \
        --text="\n
<span font='16'>This will <b>lock the device</b> until the next restart</span>\n
<span font='16'>(ensure your dashboard is ready before proceeding)</span>\n\n
<span font='18' foreground='#5DADE2'>Do you want to lock the device now?</span>\n\n
<span foreground='#5DADE2' font='48'>🔒</span>" \
        --text-align=center

    # Handle user decision
    if [[ $? -eq 0 ]]; then
        log_message "User confirmed lock operation. Executing input disable script..."
        sudo /usr/local/bin/lockdown_maintenance.sh
        log_message "Inputs disabled."
    else
        log_message "User opted to go back to the main dialog."
        display_main_dialog # Return to the main dialog
    fi
}

# Check if this is the first run in the session
if [[ ! -f "$SESSION_FILE" ]]; then
    log_message "First run of YAD dialog for this session. Adding 10-second delay."
    touch "$SESSION_FILE"
    sleep 10
else
    log_message "YAD dialog already run this session. Skipping delay."
fi

# Start the main dialog
display_main_dialog
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

# Function to add Lockdown Maintenance script
add_lockdown_maintenance_script() {
    log_message "Adding Lockdown Maintenance script."
    local maintenance_script="/usr/local/bin/lockdown_maintenance.sh"

    cat <<'EOF' > "$maintenance_script"
#!/bin/bash

# Function to log messages
log_message() {
    local LOG_TAG="lockdown_dashboard" # Custom tag for logs
    logger -t "$LOG_TAG" "$1"      # Log the message with the custom tag
}

log_message "Starting Lockdown Maintenance tasks..."

# Remove unwanted shortcuts that re-appears after a system update
log_message "Removing unwanted shortcuts..."
rm -f /usr/share/applications/software-properties-drivers.desktop
rm -f /usr/share/applications/software-properties-gtk.desktop
rm -f /usr/share/applications/update-manager.desktop
log_message "Unwanted shortcuts removed."

# Infinite loop to monitor and disable USB and PCI input devices
log_message "Starting USB and PCI input device disabler loop..."
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

    chmod +x "$maintenance_script"
    log_message "Lockdown Maintenance script added at $maintenance_script."
}

# Function to configure update scheduler with user prompt
configure_update_scheduler() {
    clear
    log_message "Prompting the user for daily auto updates and restarts."
    
    # Explain the purpose to the user
    echo "Enable daily automatic updates and restarts?"
    echo "Skipping means updates and restarts must be manual."
    read -p "Your choice (y/n): " enable_updates
    
    if [[ "$enable_updates" =~ ^[Yy]$ ]]; then
        log_message "User opted to enable daily auto updates and restarts."
        
        # Path to the update script
        local update_script="/usr/local/bin/dashboard_update.sh"

        # Create the update script
        if [[ ! -f "$update_script" ]]; then
            log_message "Creating the update script at $update_script."
            cat <<'EOF' > "$update_script"
#!/bin/bash

# Log the update operation
log_file="/var/log/dashboard_update.log"

# Kill Firefox processes directly
echo "[$(date)] Terminating Firefox processes (firefox and firefox-bin)..." >> "$log_file"
pkill -9 -x "firefox" 2>/dev/null
pkill -9 -x "firefox-bin" 2>/dev/null

echo "[$(date)] Starting dashboard update process..." >> "$log_file"
# Perform the update and upgrade
apt -y update && apt -y upgrade && snap refresh >> "$log_file" 2>&1

# Wait for 30 seconds to allow processes to settle
sleep 30

# Force a restart
echo "[$(date)] Update complete. Restarting system..." >> "$log_file"
shutdown -r now
EOF

            # Set executable permissions for the script
            chmod +x "$update_script"
            log_message "Update script created and marked as executable."
        else
            log_message "Update script already exists at $update_script. Skipping creation."
        fi

        # Schedule the script using a cron job
        local cron_file="/etc/cron.d/dashboard_update"

        if [[ -f "$cron_file" ]] && grep -q "$update_script" "$cron_file"; then
            log_message "Cron job already exists for the update scheduler in $cron_file. Skipping addition."
        else
            log_message "Adding cron job for the update scheduler."
            
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
            log_message "Cron job added to $cron_file. Updates will occur daily at 1:$random_minute AM."
            echo "The update scheduler has been configured. Updates will occur at 1:$random_minute AM daily."
        fi
    else
        log_message "User declined to enable daily auto updates and restarts."
        echo "Auto updates and restarts have not been enabled. You will need to manually update and restart the system."
    fi
}

# Function to configure sudoers for input disabling
configure_sudoers_for_inputs() {
    log_message "Configuring sudoers for input disabling."
    local sudoers_entry="/etc/sudoers.d/disable_inputs"

    echo "# Allow disabling inputs without password" > "$sudoers_entry"
    echo "$dashboard_user ALL=(ALL) NOPASSWD: /usr/local/bin/lockdown_maintenance.sh" >> "$sudoers_entry"
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

    # Create the reset script with expanded variables
    cat <<EOF > "$reset_script"
#!/bin/bash

log_message() {
    logger -t "lockdown_dashboard" "\$1"
}

log_message "Resetting Firefox settings for the user: $dashboard_user..."

# Path for Snap-based Firefox profiles
firefox_profile_path="/home/$dashboard_user/snap/firefox/common/.mozilla/firefox"

# Check if the Firefox profile path exists
if [ ! -d "\$firefox_profile_path" ]; then
    log_message "Snap-based Firefox profile directory not found for $dashboard_user. Skipping reset."
    exit 0
fi

# Find the default Firefox profile directory
profile_dir=\$(find "\$firefox_profile_path" -type d -name "*.default-release" 2>/dev/null)
if [ -z "\$profile_dir" ]; then
    log_message "No default Firefox profile found in \$firefox_profile_path. Skipping reset."
    exit 0
fi

log_message "Found Firefox profile: \$profile_dir"

# Clear unwanted contents while preserving certain directories
log_message "Clearing Firefox profile contents except 'extensions'..."
find "\$profile_dir" -mindepth 1 -maxdepth 1 ! -name "extensions" -exec rm -rf {} \;

# Adjust permissions
chown -R "$dashboard_user:$dashboard_user" "\$firefox_profile_path"
log_message "Firefox settings reset completed for $dashboard_user."
EOF

    # Ensure the reset script is executable
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
add_lockdown_maintenance_script
configure_sudoers_for_inputs
add_lockdown_app_to_menu
configure_caffeine_autostart
configure_reset_autostart
confirm_and_restart
