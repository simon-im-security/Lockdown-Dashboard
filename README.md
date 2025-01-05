# 🚀 Lockdown Kiosk Setup

## Description
This script configures Ubuntu for **Kiosk Mode**, removes unnecessary apps, and locks down the system by disabling inputs. 

---

### 🛠️ Features

- **Kiosk Mode Setup**: Set up a dedicated kiosk user.
- **Autostart Firefox**: Launch Firefox in kiosk mode at login.
- **Software Cleanup**: Optionally remove unneeded software.
- **Firewall Setup**: Configure firewall to allow only necessary ports.
- **Screen Settings**: Disable screen blanking, sleep, and lock.
- **Lockdown Dashboard**: Lock down the system with a button.
- **Input Disable**: Disable all user input when locked down.

---

### 📝 Setup Process

1. **Run the Script as Root**:
   - Open a terminal and run:
     ```bash
     sudo -s
     ```
   
   - Then copy and paste the entire script into terminal.

2. **Script Setup**:
   - Follow the prompts to set up the kiosk mode.
  
3. **Restart System**:
   - After completing the setup, restart the system to apply changes.

---

### ⚙️ Automatic Login

- After your first login to the kiosk, you can enable automatic login by navigating to the Settings menu, selecting the User Accounts section, and then enabling the Automatic Login option for the kiosk user. Once you manually set this up, the kiosk will automatically log in on subsequent restarts.

---
