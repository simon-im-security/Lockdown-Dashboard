# Ubuntu Desktop Kiosk Setup Script

## Description
This script configures Ubuntu Desktop to run in kiosk mode with the following features:
- Firefox in kiosk mode for a specified URL.
- Disables the GNOME welcome screen for new users.
- Removes unnecessary applications for a minimal setup.
- Adds a Zenity dialog accessible through the app grid.

### Script Details
- **Title**: Ubuntu Desktop Kiosk Setup
- **Author**: Simon .I
- **Version**: 2025.01.01

---

## Features
1. **Kiosk User Creation**:
   - Creates a dedicated kiosk user.
   - Sets up the Firefox browser to run in kiosk mode at startup.

2. **Zenity Integration**:
   - Adds a custom Zenity script for user interaction.
   - The Zenity app is accessible via the GNOME app grid.

3. **GNOME Customisations**:
   - Disables hot corners and overlay key.
   - Removes the GNOME welcome screen.

4. **Unnecessary Software Removal**:
   - Removes default applications like Thunderbird, LibreOffice, and more.
   - Cleans up Snap packages for a minimal environment.

5. **Optional Login Hiding**:
   - Prompts to hide the currently logged-in user from the login window.

---

## Installation Instructions

### 1. Prerequisites
- Ensure the script is executed as `root` or with `sudo` privileges.
- Recommended for Ubuntu Desktop installations with GNOME.

### 2. Usage
1. Save the script as `kiosk-setup.sh`.
2. Make it executable:
   ```bash
   chmod +x kiosk-setup.sh
