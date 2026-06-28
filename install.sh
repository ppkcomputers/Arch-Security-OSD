#!/bin/bash

TARGET_DIR="$HOME/.config/Quickshell/SecurityBar"
# List of known conflicting network management tools
CONFLICTING_TOOLS=("wicd" "connman" "netctl" "dhcpcd")

echo "=== Arch-Security-OSD Installer ==="

# 1. Check for conflicting network tools
echo "Checking for conflicting network managers..."
for tool in "${CONFLICTING_TOOLS[@]}"; do
    if pacman -Qs "$tool" > /dev/null; then
        echo "❌ Error: Conflicting network manager found: $tool"
        echo "Please remove $tool before installing this OSD to avoid conflicts."
        exit 1
    fi
done

# 2. Check/Install/Enable NetworkManager
if ! command -v nmcli &> /dev/null; then
    echo "⚠️ NetworkManager is required but not installed."
    read -p "Would you like to install NetworkManager now? (y/N): " nm_choice
    case "$nm_choice" in
        [yY][eE][sS]|[yY])
            echo "Installing NetworkManager..."
            sudo pacman -S --needed networkmanager
            ;;
        *)
            echo "NetworkManager is required for this OSD. Exiting."
            exit 1
            ;;
    esac
fi

# Ensure NetworkManager is active
if ! systemctl is-active --quiet NetworkManager; then
    echo "Enabling and starting NetworkManager..."
    sudo systemctl enable --now NetworkManager
fi

echo "----------------------------------------"

# 3. Sync databases and check for updates
echo "Syncing package databases..."
sudo pacman -Sy

echo "Checking for pending system updates..."
if pacman -Qu &>/dev/null; then
    echo "⚠️ Pending updates were found for your system."
    read -p "Would you like to run a full system upgrade now? (y/N): " update_choice
    case "$update_choice" in
        [yY][eE][sS]|[yY])
            echo "Running full system upgrade (sudo pacman -Su)..."
            sudo pacman -Su
            ;;
        *)
            echo "Skipping system upgrade."
            ;;
    esac
else
    echo "✓ Your system is already up to date."
fi

echo "----------------------------------------"

# 4. Check for Quickshell dependency
if ! command -v quickshell &> /dev/null; then
    echo "Notice: Quickshell is required."
    read -p "Would you like to install quickshell now? (y/N): " qs_choice
    case "$qs_choice" in
        [yY][eE][sS]|[yY])
            sudo pacman -S --needed quickshell
            ;;
        *)
            echo "Skipping quickshell installation."
            ;;
    esac
else
    echo "✓ Quickshell is already installed."
fi

echo "----------------------------------------"

# 5. Create directory and extract OSD files
mkdir -p "$TARGET_DIR"
echo "Downloading and installing OSD files..."
curl -sL https://github.com/ppkcomputers/Arch-Security-OSD/tarball/main | tar -xzf - -C "$TARGET_DIR" --strip-components=1

# Apply execution permissions
echo "Setting permissions for script files..."
chmod +x "$TARGET_DIR/SecurityBar.sh" "$TARGET_DIR/scan-aur-package.sh"

echo "----------------------------------------"
echo "Installation process finished!"
echo "Files are located in: $TARGET_DIR"
