#!/usr/bin/env bash

# 1. Path to your OSD
QML_PATH="$HOME/.config/quickshell/SecurityBar/SecurityBar.qml"

# 2. Toggle Logic: If it's running, kill it and exit
if pgrep -f "quickshell.*SecurityBar/SecurityBar.qml" >/dev/null; then
    pkill -f "quickshell.*SecurityBar/SecurityBar.qml"
    exit 0
fi

# 3. Dependency Check: NetworkManager Service
if ! systemctl is-active --quiet NetworkManager; then
    if pgrep -x "dunst" > /dev/null; then
        # -t 10000 ensures the error notification stays for 10 seconds
        notify-send -u critical -t 10000 "SecurityBar Error" "NetworkManager is not running.\nStart it with: sudo systemctl start NetworkManager"
    else
        echo -e "\033[0;31mError: NetworkManager service is not active.\033[0m"
    fi
    exit 1
fi

# 4. Launch OSD (Restoring Software Backend for Layout Consistency)
# This matches the environment used for your other OSDs in hyprland.conf
QT_QUICK_BACKEND=software quickshell -p "$QML_PATH" &
