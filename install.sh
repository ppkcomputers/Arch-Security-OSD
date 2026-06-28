#!/bin/bash

TARGET_DIR="$HOME/.config/Quickshell/SecurityBar"

echo "=== Arch-Security-OSD Installer ==="

# 1. Sync databases and check for updates
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
            echo "Skipping system upgrade. Jumping to Quickshell installation check..."
            ;;
    esac
else
    echo "✓ Your system is already up to date."
fi

echo "----------------------------------------"

# 2. Check for Quickshell dependency
if ! command -v quickshell &> /dev/null; then
    echo "Notice: Quickshell is required to run this OSD, but it is not installed."
    read -p "Would you like to install quickshell via pacman now? (y/N): " qs_choice
    
    case "$qs_choice" in 
        [yY][eE][sS]|[yY]) 
            echo "Installing quickshell..."
            sudo pacman -S --needed quickshell
            ;;
        *)
            echo "Skipping quickshell installation. Note: The OSD may not function without it."
            ;;
    esac
else
    echo "✓ Quickshell is already installed."
fi

echo "----------------------------------------"

# 3. Create directory and extract OSD files (OVERWRITE MODE active)
mkdir -p "$TARGET_DIR"
echo "Downloading and installing OSD files (Overwriting existing files)..."

# Using -xzf without -k ensures clean overwrites every time you test
curl -sL https://github.com/ppkcomputers/Arch-Security-OSD/tarball/main | tar -xzf - -C "$TARGET_DIR" --strip-components=1

echo "----------------------------------------"
echo "Installation process finished!"
echo "Files are located in: $TARGET_DIR"
