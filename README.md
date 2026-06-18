# Arch-Security-OSD

# Security & Network Status OSD (Quickshell)

An elegant, system-security-focused overlay panel (OSD) designed for desktop environments using Wayland. Built using **Quickshell** and **QML**, this utility runs light background shell processes to continuously audit and display critical system security, firewall, network health, and update matrices in real-time.

---

## 🚀 Key Features

The sidebar is divided into dedicated, modular monitoring sections:

### 🔄 System & Package Updates
* **Pacman Status:** Tracks your last full system upgrade from `/var/log/pacman.log` and alerts you dynamically if your system hasn't been updated in over 2 days.
* **Pending Packages:** Counts outstanding Arch Linux packages (`checkupdates`) and Flatpak updates.
* **Visual Urgency & Alerts:** The text blinks and turns red if updates are critical, and fires desktop notifications via `dunstify` when updates are severely overdue.
* **Quick Upgrade Helper:** One-click copy button to quickly grab `sudo pacman -Syu && flatpak update` directly to your Wayland clipboard.

### 🌐 Real-Time Network Analytics
* **Bandwidth Tracker:** Calculates exact live download and upload speeds dynamically through interface packet deltas.
* **Local Interface IP:** Automatically targets and extracts your active hardware interface's local IP address.
* **Connectivity Integrity:** Interfaces directly with NetworkManager (`nmcli`) to test global internet state (*Full UP, Limited, Portal, or Down*).
* **Sub-Panel Bridging:** Features a quick launch action to toggle a deeper network sub-panel utility directly from the interface.

### 🛡️ Firewall & Integrity Status
* **Automated Detection:** Dynamically detects whether `UFW` or `firewalld` is running as your main routing boundary.
* **Contextual Assistance:** * If a firewall is active, it offers custom commands to audit strict rules verbose logs.
    * If no firewall is detected, it shifts into warning mode and populates explicit installation script macros for both UFW and firewalld alongside a helper clipboard button.

### 🦠 Anti-Malware Safeguards
* **ClamAV Verification:** Scans package structures to confirm if `clamav` is safely deployed.
* **Dynamic Layout UI:** If installed, it quietly indicates a secure `"Clamav installed"` state. If missing, it dynamically generates an installation and systemd unit enablement sequence box with immediate clipboard capture logic.

### 🏰 Arch Fortress Mode (Lynis Audit)
* **Lynis Scanner Engine:** Dedicated automated gateway button at the bottom of the OSD block.
* **Smart Fallback:** Checks if the robust Lynis auditing suite is native on your system path.
* **Interactive Terminal Run:** If present, clicking "Scan System" fires up a brand new `kitty` terminal instance executing a live root level `sudo lynis audit system` verification and holds the stdout wrapper open for your inspection.

---

## 📋 System Dependencies

To unlock the full functionality of the processes wired into the UI loop, ensure the following core tools are installed on your Arch Linux environment:

| Dependency | Purpose |
| :--- | :--- |
| `quickshell` | QML Wayland Shell Component Engine |
| `kitty` | Fast terminal emulator used to run the interactive system audit |
| `wl-copy` | Wayland utility backend for quick-copy buttons (`wl-clipboard`) |
| `networkmanager` | Leveraged for network tracking metrics via `nmcli` |
| `pacman-contrib` | Provides `checkupdates` safely without refreshing root dbs |
| `dunst` | Handles the background critical update desktop notifications |
| `lynis` | *(Optional)* Powers the localized security fortress audit loop |
| `clamav` | *(Optional)* Local binary database signature virus scanner |

---

## 🛠️ Configuration & Customization

The script maps processes straight to configuration pathways. If you host components or secondary screens across different targets, look into the following `Process` initializations at the top of the file:

```qml
// Launcher for your secondary Network panel path:
Process {
    id: openNetworkPanel
    command: [ "quickshell", "--path", "/home/YOUR_USER/.config/quickshell/NetworkSecurityBar/NetworkSecurityBar.qml" ]
}
