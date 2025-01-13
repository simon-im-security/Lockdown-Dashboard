<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body>
    <h1>🚀 Lockdown Dashboard Setup</h1>
    <h2>Description</h2>
    <p>This script sets up a <strong>custom lockdown dashboard</strong> on Ubuntu Desktop, designed to secure and display dashboards or other webpages by locking down the device, including input devices. Ideal for use cases requiring secure, automated dashboards.</p>
    <div style="display: flex; gap: 20px; justify-content: center; margin: 20px 0;">
        <img src="https://github.com/simon-im-security/Lockdown-Dashboard/blob/main/before.png" alt="Before Lockdown" style="width:48%; border:1px solid #ccc; box-shadow: 2px 2px 5px #aaa;">
        <img src="https://github.com/simon-im-security/Lockdown-Dashboard/blob/main/after.png" alt="After Lockdown" style="width:48%; border:1px solid #ccc; box-shadow: 2px 2px 5px #aaa;">
    </div>
    <hr>
    <h2>🛠️ Features</h2>
    <h3>User Management</h3>
    <ul>
        <li><strong>Lockdown Dashboard User Creation</strong>: Automatically create a dedicated user with a custom username and password.</li>
    </ul>
    <h3>Dashboard Configuration</h3>
    <ul>
        <li><strong>Firefox Shortcuts</strong>: 
            <ul>
                <li>Create desktop and autostart shortcuts for specific URLs.</li>
                <li>Automatically launch these websites in private new windows using Firefox.</li>
                <li>Checks for internet connectivity before opening URLs.</li>
                <li>Note: Any extensions used in Firefox must be enabled for private window mode in their management options.</li>
            </ul>
        </li>
        <li><strong>GNOME Power &amp; Screen Settings</strong>: Disable screen blanking, sleep, and lock screens to ensure uninterrupted operation.</li>
    </ul>
    <h3>Lockdown Features</h3>
    <ul>
        <li><strong>Lockdown Dashboard</strong>: 
            <ul>
                <li>A graphical interface to lock the system when the dashboard is set up.</li>
                <li>Displays system information:
                    <ul>
                        <li>Last system restart time.</li>
                        <li>Last update check time.</li>
                        <li>Ubuntu version.</li>
                    </ul>
                </li>
                <li>Lock button disables user inputs for lockdown mode.</li>
            </ul>
        </li>
        <li><strong>Input Disabling</strong>: Disable all USB, PCI, and built-in input devices while the system is in lockdown mode.</li>
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
        <li><strong>Caffeine Integration</strong>: Prevents the system from sleeping or displaying power-saving notifications.</li>
        <li><strong>Autostart Configuration</strong>: Automatically start the Lockdown Dashboard, Firefox shortcuts, and other necessary services at login.</li>
    </ul>
    <hr>
    <h2>📝 Setup Process</h2>
    <h3>Before You Begin</h3>
    <p>Install a fresh Ubuntu Desktop and log into the admin user account before running the script.</p>
    <h3>1. Run the Script as Root</h3>
    <p>Open a terminal and run:</p>
    <pre><code>sudo wget -O lockdown_dashboard_ubuntu_install.sh https://raw.githubusercontent.com/simon-im-security/Lockdown-Dashboard/refs/heads/main/lockdown_dashboard_ubuntu_install.sh && sudo bash lockdown_dashboard_ubuntu_install.sh</code></pre>
    <p>This will download the script and execute it with the necessary privileges.</p>
    <h3>2. Follow Prompts</h3>
    <ul>
        <li>Set up the lockdown dashboard user.</li>
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
        <li>Firefox (in private new windows), Caffeine, and the Lockdown Dashboard will start automatically upon login.</li>
    </ul>
    <hr>
    <h2>ℹ️ Additional Notes</h2>
    <ul>
        <li><strong>Websites with Timeouts</strong>: If you use a website that times out due to inactivity, we recommend installing a Firefox extension that keeps webpages alive (e.g., <i>tab reloader</i> or <i>auto refresh</i> extensions).</li>
        <li><strong>No Enforced Lockdown Mode</strong>: This script avoids enforcing strict lockdown mode to provide flexibility. For example, you can switch tabs, install browser extensions, or access system settings as needed. This approach is ideal for scenarios requiring more control over the lockdown environment.</li>
    </ul>
    <hr>
    <h2>🎉 Get Started Today</h2>
    <p>Use this script to create a secure and reliable lockdown system tailored to your needs. Let me know if you encounter any issues or have suggestions for improvements!</p>
</body>
</html>
