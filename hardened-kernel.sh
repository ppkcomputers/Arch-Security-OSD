#!/usr/bin/env bash

# Terminal Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0;34m' # No Color
BOLD='\033[1m'
UNDERLINE='\033[4m'

clear
echo -e "${CYAN}${BOLD}========================================================================"
echo -e "                       KERNEL HARDENING INTERACTIVE                      "
echo -e "========================================================================${NC}\n"

echo -e "${YELLOW}${BOLD}Reviewing Security Hardening Flags:${NC}\n"

# 1. unprivileged_bpf_disabled
echo -e "${CYAN}${BOLD}[1] kernel.unprivileged_bpf_disabled${NC}"
echo -e "    ${BOLD}Explanation:${NC} Disables unprivileged users from using the extended Berkeley Packet"
echo -e "                 Filter (eBPF) system. Modern eBPF components can easily be exploited"
echo -e "                 by unprivileged local malware to execute kernel memory escapes."
echo -e "    ${GREEN}Hardened Value:${NC} 1 (Restricted to CAP_SYS_ADMIN)\n"

# 2. bpf_jit_harden
echo -e "${CYAN}${BOLD}[2] net.core.bpf_jit_harden${NC}"
echo -e "    ${BOLD}Explanation:${NC} Enables Just-In-Time compiler hardening for the packet filter. "
echo -e "                 Setting this to '2' forces constant blinding for all unprivileged"
echo -e "                 JIT operations, heavily mitigating 'JIT spraying' exploits."
echo -e "    ${GREEN}Hardened Value:${NC} 2\n"

# 3. ldisc_autoload
echo -e "${CYAN}${BOLD}[3] dev.tty.ldisc_autoload${NC}"
echo -e "    ${BOLD}Explanation:${NC} Prevents malicious userspace tasks from automatically loading exotic"
echo -e "                 line discipline tty drivers over the network or background handles."
echo -e "                 Restricts driver initialization exploits."
echo -e "    ${GREEN}Hardened Value:${NC} 0\n"

# 4. protected_fifos & protected_regular
echo -e "${CYAN}${BOLD}[4] fs.protected_fifos & fs.protected_regular${NC}"
echo -e "    ${BOLD}Explanation:${NC} Fixes architectural directory exploits in sticky public folders"
echo -e "                 (like /tmp). Prevents unauthorized writing to pipes or structural"
echo -e "                 files owned by alternative target users (mitigates spoof data race conditions)."
echo -e "    ${GREEN}Hardened Value:${NC} 2\n"

echo -e "${CYAN}========================================================================${NC}"
echo -e "${YELLOW}${BOLD}Would you like to write these parameters to /etc/sysctl.d/99-hardened.conf?${NC}"
read -p "Apply hardening? (y/N): " choice

case "$choice" in
    [yY][eE][sS]|[yY])
        echo -e "\n${YELLOW}Requesting root privileges to configure sysctl parameters...${NC}"

        # Write config using a temporary heredoc block
        sudo bash -c 'cat > /etc/sysctl.d/99-hardened.conf << EOF
# Hardening parameters generated via OSD UI Helper
kernel.unprivileged_bpf_disabled=1
net.core.bpf_jit_harden=2
dev.tty.ldisc_autoload=0
fs.protected_fifos=2
fs.protected_regular=2
EOF'

        if [ $? -eq 0 ]; then
            echo -e "${YELLOW}Applying system rules live via sysctl...${NC}"
            sudo sysctl --system
            echo -e "\n${GREEN}${BOLD}✔ Success! Kernel features hardened successfully.${NC}"
        else
            echo -e "\n${RED}${BOLD}✘ Configuration failed. System variables unchanged.${NC}"
        fi
        ;;
    *)
        echo -e "\n${RED}Hardening skipped. Exiting script safely.${NC}"
        ;;
esac

echo -e "\nPress Enter to return to OSD..."
read
