<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body>
    <h1>🚀 Lockdown Kiosk Setup</h1>
    <h2>Description</h2>
    <p>This script sets up a <strong>custom kiosk mode</strong> on Ubuntu Desktop, designed to display webpages, making it perfect for dashboards and similar applications. Additionally, it provides a <strong>lockdown feature</strong> to secure the system by disabling USB keyboards and other input devices:</p>
    <img src="https://github.com/simon-im-security/Ubuntu-Desktop-Kiosk-Setup/blob/main/screenshot.png" alt="Lockdown Kiosk Screenshot" style="width:100%;max-width:800px;margin-top:20px;">
    <hr>
    <h2>🛠️ Features</h2>
    <h3>User Management</h3>
    <ul>
        <li><strong>Kiosk User Creation</strong>: Automatically create a dedicated kiosk user with a custom username and password.</li>
    </ul>
    <h3>Kiosk Configuration</h3>
    <ul>
        <li><strong>Firefox Shortcuts</strong>: 
            <ul>
                <li>Create desktop and autostart shortcuts for specific URLs.</li>
                <li>Automatically launch these websites in Firefox at login.</li>
            </ul>
        </li>
        <li><strong>GNOME Power &amp; Screen Settings</strong>: Disable screen blanking, sleep, and lock screens to ensure uninterrupted operation.</li>
    </ul>
    <h3>Lockdown Features</h3>
    <ul>
        <li><strong>Lockdown Dashboard</strong>: 
            <ul>
                <li>A graphical interface to lock the system when the kiosk is set up.</li>
                <li>Displays real-time system information:
                    <ul>
                        <li>Last system restart time.</li>
                        <li>Last update check time.</li>
                        <li>Ubuntu version.</li>
                    </ul>
                </li>
                <li>Lock button disables user inputs for lockdown mode.</li>
            </ul>
        </li>
        <li><strong>Input Disabling</strong>: Disable all USB, PCI, and built-in input devices while the system is in lockdown.</li>
    </ul>
    <h3>System Security</h3>
    <ul>
        <li><strong>Firewall Configuration</strong>: Restrict all incoming connections and allow only outgoing DNS, HTTPS, HTTP, and NTP traffic.</li>
        <li><strong>Restrict Terminal Access</strong>: GNOME Terminal access is restricted to sudo users only.</li>
    </ul>
    <h3>System Optimisation</h3>
    <ul>
        <li><strong>Remove Unnecessary Software</strong>: Clean up unused packages, snaps, and GNOME applications to free up space and simplify the system.</li>
        <li><strong>Software Updates</strong>: 
            <ul>
                <li>Schedule daily updates using APT and Snap to keep the system secure and up-to-date.</li>
                <li>System restarts automatically after updates.</li>
            </ul>
        </li>
    </ul>
    <h3>Advanced Automation</h3>
    <ul>
        <li><strong>Reset Firefox Settings</strong>: Resets Firefox profiles automatically at login to ensure a consistent kiosk experience.</li>
        <li><strong>Caffeine Integration</strong>: Prevents the system from sleeping or displaying power-saving notifications.</li>
        <li><strong>Autostart Configuration</strong>: Automatically start the Lockdown Dashboard, Firefox shortcuts, and other necessary services at login.</li>
    </ul>
    <hr>
    <h2>📝 Setup Process</h2>
    <h3>1. Run the Script as Root</h3>
    <p>Open a terminal and run:</p>
    <pre><code>sudo curl -o ubuntu_desktop_kiosk_setup.sh https://raw.githubusercontent.com/simon-im-security/Ubuntu-Desktop-Kiosk-Setup/refs/heads/main/ubuntu_desktop_kiosk_setup && sudo bash ubuntu_desktop_kiosk_setup.sh</code></pre>
    <p>This will download the script and execute it with the necessary privileges.</p>
    <h3>2. Follow Prompts</h3>
    <ul>
        <li>Set up the kiosk user.</li>
        <li>Configure URLs for Firefox shortcuts.</li>
        <li>Choose whether to remove unnecessary software or configure the firewall.</li>
    </ul>
    <h3>3. Restart the System</h3>
    <p>Restart the system after completing the setup to apply all changes.</p>
    <hr>
    <h2>⚙️ Post-Setup Configuration</h2>
    <h3>System Maintenance</h3>
    <ul>
        <li>Updates are scheduled to run daily at a random time between 1:00 AM and 2:00 AM.</li>
    </ul>
    <h3>Autostart</h3>
    <ul>
        <li>Firefox, Caffeine, and the Lockdown Dashboard will start automatically upon login.</li>
    </ul>
    <hr>
    <h2>ℹ️ Additional Notes</h2>
    <ul>
        <li><strong>Websites with Timeouts</strong>: If you use a website that times out due to inactivity, we recommend installing a Firefox extension that keeps webpages alive (e.g., <i>tab reloader</i> or <i>auto refresh</i> extensions). There are several options available, so choose one that fits your needs.</li>
        <li><strong>No Enforced Kiosk Mode</strong>: This script avoids enforcing strict kiosk mode to provide flexibility. For example, you can switch tabs, install browser extensions, or access system settings as needed. This approach is ideal for scenarios requiring more control over the kiosk environment.</li>
    </ul>
    <hr>
    <h2>🎉 Get Started Today</h2>
    <p>Use this script to create a secure and reliable kiosk system tailored to your needs. Let me know if you encounter any issues or have suggestions for improvements!</p>
</body>
</html>
