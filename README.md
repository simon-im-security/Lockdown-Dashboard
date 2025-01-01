# Ubuntu Desktop Kiosk Setup Script

## Overview
This script automates the configuration of Ubuntu Desktop for kiosk use. It simplifies the process of creating a restricted user environment with Firefox in kiosk mode and removes unnecessary applications for a minimal setup.

---

## Features
- **User Creation**: Creates a dedicated kiosk user with a password and auto-login setup.
- **Firefox Kiosk Mode**: Configures Firefox to launch in kiosk mode with a specified URL.
- **GNOME Customisation**: Disables the GNOME welcome screen and adjusts settings like hot corners.
- **Application Cleanup**: Removes unnecessary software to minimise distractions and resource usage.
- **Login Management**: Optionally hides the currently logged-in user from the login screen.

---

## Prerequisites
- Ubuntu Desktop with GNOME installed.
- Root or `sudo` privileges.

---

## Installation Instructions

### Step 1: Save and Prepare the Script
1. Save the script as `kiosk-setup.sh`.
2. Make it executable:
   chmod +x kiosk-setup.sh

### Step 2: Run the Script
Execute the script with:
   sudo ./kiosk-setup.sh

---

## Key Workflow

### 1. User Creation
The script will prompt you to create a dedicated user:
   Enter the username for the kiosk user: 
   Enter the password for [username]: 
   Enter the URL for kiosk mode (e.g., https://example.com):

### 2. Firefox Configuration
Sets up Firefox to run in kiosk mode:
   Configuring Firefox autostart...
This creates a `.desktop` file for Firefox in kiosk mode:
   [Desktop Entry]
   Type=Application
   Exec=firefox --kiosk "https://example.com"

### 3. GNOME Customisation
Disables unnecessary GNOME features:
- Hot corners.
- Overlay key (Super key menu).
- GNOME welcome screen for new users.

### 4. Application Cleanup
Removes unneeded software to reduce clutter:
   Removing unnecessary software...
Applications removed include:
- Thunderbird
- LibreOffice
- Cheese (Camera app)
- Simple Scan
- GNOME Calendar
- Transmission

### 5. User Login Management
Optionally hides the currently logged-in user from the login screen:
   Hide the currently logged-in user (e.g., admin) from the login window? (y/n):

### 6. System Restart
Prompts to restart the system after setup:
   Kiosk mode setup is complete. Do you want to restart the system now? (y/n):

---

## License
This project is licensed under the MIT License. Use and modify freely for your own projects.
