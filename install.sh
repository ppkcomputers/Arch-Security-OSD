#!/bin/bash
# Check for Quickshell
if ! command -v quickshell &> /dev/null; then
    echo "Quickshell not found. Installing via pacman..."
    sudo pacman -S --needed quickshell
fi

# Create directory and extract OSD files
echo "Installing Arch-Security-OSD..."
mkdir -p "$HOME/.config/Quickshell/SecurityBar"
curl -sL https://github.com/ppkcomputers/Arch-Security-OSD/tarball/main | tar -xzf - -C "$HOME/.config/Quickshell/SecurityBar" --strip-components=1

echo "Done! Installation complete."
