#!/usr/bin/env bash

# Resolve the absolute directory path where this specific script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if a package argument was provided
if [ -z "$1" ]; then
    echo -e "\033;31m[-] Error: Please specify an AUR package name.\033[0m"
    echo "Usage: $(basename "$0") <package-name>"
    exit 1
fi

TARGET_PKG="$1"

# Move execution context inside the target folder implicitly
cd "$SCRIPT_DIR" || exit 1

# Terminal formatting colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ======================================================================
# 1. Perform System Update Before Proceeding
# ======================================================================
echo -e "${BLUE}[*] Initializing full system update (Repositories + AUR)...${NC}"
if ! yay -Syu; then
    echo -e "${RED}[-] System upgrade failed. Aborting script to avoid partial upgrade state.${NC}"
    exit 1
fi
echo -e "${GREEN}[+] System is fully up-to-date.${NC}\n"

# ======================================================================
# 2. Fetch live compromised package feeds (Atomic Arch Tracking Lists)
# ======================================================================
echo -e "${BLUE}[*] Fetching latest community lists of compromised AUR packages...${NC}"

# We pull from reliable community text repositories tracking the 1,500+ hijacked items
MALICIOUS_LIST_URL="https://raw.githubusercontent.com/aur-general/malware-tracking/main/compromised-packages.txt"
TMP_BLACKLIST=$(mktemp)

# Download the blacklist silently (with a 5-second timeout so your install isn't hung up)
curl -s --max-time 5 "$MALICIOUS_LIST_URL" -o "$TMP_BLACKLIST"

# Fallback mechanism if the live URL fails or is blocked
if [ ! -s "$TMP_BLACKLIST" ]; then
    echo -e "${YELLOW}[!] Warning: Could not fetch the live online threat list. Proceeding directly to AI evaluation layer...${NC}"
else
    # Match the user's package against the blacklist
    echo -e "${BLUE}[*] Cross-referencing '${TARGET_PKG}' against known-bad repositories...${NC}"

    if grep -Fxq "$TARGET_PKG" "$TMP_BLACKLIST"; then
        echo -e "\n${RED}############################################################"
        echo -e "[-] CRITICAL SECURITY ALERT: ${TARGET_PKG} IS ON THE MALICIOUS LIST!"
        echo -e "This package was verified as hijacked or compromised during the recent attacks."
        echo -e "DO NOT PROCEED. Aborting installation immediately to protect your host."
        echo -e "############################################################${NC}\n"
        rm -f "$TMP_BLACKLIST"
        exit 1
    fi
    echo -e "${GREEN}[+] Package is clean from known automated blacklist signatures.${NC}"
fi
rm -f "$TMP_BLACKLIST"

# ======================================================================
# 3. Dynamic LLM Environment Assessment
# ======================================================================
RUN_AI_AUDIT=true
CHOSEN_MODEL=""

# Check if ollama command exists and the daemon is running
if ! command -v ollama &> /dev/null || ! curl -s http://localhost:11434/api/tags &> /dev/null; then
    echo -e "${YELLOW}[!] Warning: Ollama is either not installed or the daemon is not running.${NC}"
    echo -e "${YELLOW}[!] Skipping AI security audit phase.${NC}"
    RUN_AI_AUDIT=false
fi

if [ "$RUN_AI_AUDIT" = true ]; then
    echo -e "${BLUE}[*] Checking local Ollama instance for usable models...${NC}"

    # Check specifically for llama3.2:latest first
    if ollama list | grep -q -E "llama3\.2:latest"; then
        CHOSEN_MODEL="llama3.2:latest"
        echo -e "${GREEN}[+] Found preferred model: ${CHOSEN_MODEL}${NC}"
    else
        # If llama3.2:latest isn't there, look for ANY other model containing the word "llama"
        ANY_LLAMA=$(ollama list | grep -i "llama" | awk '{print $1}' | head -n 1)

        if [ -n "$ANY_LLAMA" ]; then
            CHOSEN_MODEL="$ANY_LLAMA"
            echo -e "${YELLOW}[!] llama3.2:latest not found, but detected alternative fallback: ${CHOSEN_MODEL}${NC}"
        else
            # No llama models exist at all. Prompt user to install llama3.2:latest
            echo -e "${YELLOW}[!] No 'llama' models detected on your local system.${NC}"
            while true; do
                read -p "Would you like to pull/install 'llama3.2:latest' now? (y/n): " download_confirm
                case "$download_confirm" in
                    [yY] )
                        echo -e "${BLUE}[*] Pulling llama3.2:latest via Ollama... (This might take a moment)${NC}"
                        if ollama pull llama3.2:latest; then
                            CHOSEN_MODEL="llama3.2:latest"
                            echo -e "${GREEN}[+] Successfully downloaded llama3.2:latest.${NC}"
                        else
                            echo -e "${RED}[-] Failed to download model. Skipping AI audit layer.${NC}"
                            RUN_AI_AUDIT=false
                        fi
                        break
                        ;;
                    [nN] )
                        echo -e "${YELLOW}[!] Skipping AI audit layer by user request.${NC}"
                        RUN_AI_AUDIT=false
                        break
                        ;;
                    * )
                        echo "Please type 'y' (yes) or 'n' (no)."
                        ;;
                esac
            done
        fi
    fi
fi

# ======================================================================
# Prompt to Skip Scan (Only if AI environment is actually available)
# ======================================================================
if [ "$RUN_AI_AUDIT" = true ] && [ -n "$CHOSEN_MODEL" ]; then
    while true; do
        read -p "Do you want to run the AI security scan on this package? (y/n): " scan_confirm
        case "$scan_confirm" in
            [yY] )
                break
                ;;
            [nN] )
                echo -e "${YELLOW}[!] Bypassing AI scan by user choice.${NC}"
                RUN_AI_AUDIT=false
                break
                ;;
            * )
                echo "Please type 'y' (yes) or 'n' (no)."
                ;;
        esac
    done
fi

# ======================================================================
# 4. Download, Show, and Scan Package Blueprints
# ======================================================================
if [ "$RUN_AI_AUDIT" = true ] && [ -n "$CHOSEN_MODEL" ]; then
    echo -e "${BLUE}[*] Fetching package repository targets using yay...${NC}"

    # Create a unique temporary directory to download the PKGBUILD securely
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR" || exit 1

    # Native Fetch Command: Gets the official package folder cleanly
    if ! yay -Gq "$TARGET_PKG" &> /dev/null || [ ! -f "$TARGET_PKG/PKGBUILD" ]; then
        echo -e "${RED}[-] Failed to download source files. Is '${TARGET_PKG}' a valid AUR package name?${NC}"
        rm -rf "$TMP_DIR"
        exit 1
    fi

    # Read the file data into a variable
    pkg_data=$(cat "$TARGET_PKG/PKGBUILD")

    # --- PRINT PKGBUILD TO TERMINAL IMMEDIATELY ---
    echo -e "\n${BLUE}========================= TARGET PKGBUILD SOURCE =========================${NC}"
    echo "$pkg_data"
    echo -e "${BLUE}==========================================================================${NC}\n"

    # --- HIGH-SPEED STATIC PRE-SCAN ---
    echo -e "${BLUE}[*] Running high-speed static scan for anomalies...${NC}"
    SUSPICIOUS_LINES=$(echo "$pkg_data" | grep -E -n "(curl|wget|base64|eval|chmod \+x|/tmp/|\.sh)")

    if [ -z "$SUSPICIOUS_LINES" ]; then
        echo -e "${GREEN}STATUS: CLEAN (Instant Static Pass - No risky network/obfuscation hooks detected)${NC}"
        echo "----------------------------------------------------------------------"
    else
        echo -e "${YELLOW}[!] Static scan found potential triggers. Escalating to local AI for structural audit...${NC}"
        echo -e "${RED}Flagged Line(s):\n$SUSPICIOUS_LINES${NC}\n"
        echo -e "${YELLOW}[*] Feeding above build structure to local ${CHOSEN_MODEL} model...${NC}"
        echo "----------------------------------------------------------------------"

        AI_PROMPT="You are an expert Linux security auditor. Inspect the following Arch Linux AUR PKGBUILD for malicious code injections, supply chain attacks, hidden backdoors, or privilege escalations. Check for unexpected network calls (curl/wget), malicious package managers pulling unauthorized tracking code, obfuscated bash strings (base64, hex, eval), or unauthorized modifications to system profiles. Keep your analysis concise. CRITICAL INSTRUCTION: If everything looks completely standard and safe, output ONLY the string 'STATUS: CLEAN' and absolutely nothing else. Do not explain your reasoning unless you find a genuine vulnerability or threat."

        (echo "$AI_PROMPT"; echo -e "\n--- BEGIN PKGBUILD FOR $TARGET_PKG ---"; echo "$pkg_data") | ollama run "$CHOSEN_MODEL"
        echo "----------------------------------------------------------------------"
        echo -e "${YELLOW}[?] Review the local model's risk assessment above.${NC}"
    fi

    # Clean up the temp directory
    rm -rf "$TMP_DIR"
    cd "$SCRIPT_DIR" || exit 1

    # Request manual evaluation confirmation after AI output
    while true; do
        read -p "Are you completely satisfied with the AI output? Proceed with installation? (y/n): " confirm
        case "$confirm" in
            [yY] )
                break
                ;;
            [nN] )
                echo -e "${RED}[!] Installation safely aborted by user.${NC}"
                exit 0
                ;;
            * )
                echo "Please type 'y' (yes) or 'n' (no)."
                ;;
        esac
    done
else
    # Fallback gatekeeper if AI scanning was skipped or disabled
    echo -e "${YELLOW}[!] Proceeding without an AI security audit.${NC}"
    while true; do
        read -p "Do you want to proceed with installing ${TARGET_PKG} anyway? (y/n): " raw_confirm
        case "$raw_confirm" in
            [yY] )
                break
                ;;
            [nN] )
                echo -e "${RED}[!] Installation safely aborted by user.${NC}"
                exit 0
                ;;
            * )
                echo "Please type 'y' (yes) or 'n' (no)."
                ;;
        esac
    done
fi

# ======================================================================
# 5. Execute Package Build Pipeline
# ======================================================================
echo -e "${GREEN}[+] Triggering build pipeline for ${TARGET_PKG}...${NC}"
# Bypasses diff and edit prompts cleanly on modern versions of yay
yay -S --aur --diffmenu=false --editmenu=false "$TARGET_PKG"
