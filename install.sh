#!/bin/bash

TARGET_DIR="$HOME/.config/Quickshell/SecurityBar"

echo "=== Arch-Security-OSD Installer ==="

# 1. Check for pending system updates safely
echo "Checking for pending system updates..."
if command -v checkupdates &> /dev/null; then
    UPDATES=$(checkupdates 2>/dev/null)
else
    # Fallback if pacman-contrib isn't installed
    UPDATES=$(pacman -Qu 2>/dev/null)
fi

if [ -n "$UPDATES" ]; then
    echo "⚠️ Warning: Your Arch system has pending updates available."
    read -p "Would you like to run a full system upgrade now? (y/N): " update_choice
    case "$update_choice" in
        [yY][eE][sS]|[yY])
            echo "Running full system upgrade (sudo pacman -Syu)..."
            sudo pacman -Syu
            ;;
        *)
            echo "Skipping system upgrade. Proceeding cautiously..."
            ;;
    esac
else
    echo "✓ System is fully up to date."
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

# 3. Create directory and extract OSD files safely (-k keeps local edits)
mkdir -p "$TARGET_DIR"
echo "Downloading and installing OSD files..."
curl -sL https://github.com/ppkcomputers/Arch-Security-OSD/tarball/main | tar -xzkf - -C "$TARGET_DIR" --strip-components=1 2>/dev/null

echo "----------------------------------------"
echo "Installation process finished!"
echo "Files are located in: $TARGET_DIR"
echo "Note: Existing files were safely preserved and not overwritten."
