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
- Root or sudo privileges.

---

## Installation Instructions

### Step 1: Save and Prepare the Script
1. Save the script as `kiosk-setup.sh`.
2. Make it executable with the command: `chmod +x kiosk-setup.sh`.

### Step 2: Run the Script
Run the script using: `sudo ./kiosk-setup.sh`.

---

## Key Workflow

### 1. User Creation
The script will prompt you to create a dedicated user by entering the username, password, and kiosk URL.

### 2. Firefox Configuration
Configures Firefox to run in kiosk mode and automatically launch with the specified URL.

### 3. GNOME Customisation
Customises GNOME settings to improve the user experience:
- Disables hot corners.
- Disables the overlay key (Super key menu).
- Disables the GNOME welcome screen for new users.

### 4. Application Cleanup
Removes unnecessary applications, including:
- Thunderbird
- Rhythmbox
- LibreOffice (all components)
- Transmission
- Remmina (and related plugins)
- GIMP
- Shotwell
- GNOME Calculator
- GNOME Calendar
- GNOME Disk Utility
- GNOME Software Center
- GNOME Text Editor
- GNOME Characters
- Eye of GNOME (Image Viewer)
- Cheese (Camera App)
- Yelp (Help App)
- GNOME Snapshot (Camera)
- Simple Scan
- Evince (Document Viewer)
- USB Creator

Snap packages for these applications are also removed.

### 5. User Login Management
The script can hide the currently logged-in user from the login screen.

### 6. System Restart
Prompts you to restart the system to apply all changes.

---

## Notes
- To debug any issues, use the log command: `journalctl -xe`.
- To test kiosk setup for another user, create a new test user using: `sudo useradd -m -s /bin/bash testuser`.

---

## License
This project is licensed under the MIT License. Use and modify freely for your own projects.
