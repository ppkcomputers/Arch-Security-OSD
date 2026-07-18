import os
import sys
import shutil
import subprocess

class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    BOLD = '\033[1m'
    ENDC = '\033[0m'

FIX_DATABASE = {
    "KRNL-5830": "A kernel update was applied. Simply reboot your machine to initialize the new kernel image.",
    "PKGS-7322": "Run 'arch-audit' in your terminal to see the CVE list, then sync your system: sudo pacman -Syu",
    "BOOT-5264": "Run 'systemd-analyze security <service>' to check individual flaws, or use hardened overrides in /etc/systemd/system/.",
    "PROC-3614": "Check which processes are stuck in disk sleep (D state) using 'ps aux | grep \" D \"' or 'iotop'.",
    "AUTH-9328": "Edit /etc/login.defs and change the 'UMASK' value from 022 to 027 to restrict default file creation permissions.",
    "NAME-4028": "Set your local search domain name or verify systemd-resolved profiles in /etc/hosts or /etc/resolv.conf.",
    "PKGS-7312": "Your local database index is lagging. Pull down fresh sync chains: sudo pacman -Syy",
    "PKGS-7398": "Install arch-audit to let Lynis parse security tracking flags directly: yay -S arch-audit",
    "CRYP-7902": "Check local security certificates or validation authorities via 'trust list' or check open SSL directories.",
    "FINT-4350": "Install an intrusion monitoring framework like AIDE or Tripwire to alert you to changes in critical system binaries.",
    "TOOL-5002": "Automation tracking notice. (Safe to ignore if you manage scripts and playbooks manually).",
    "FILE-7524": "Check system cron directory structures. Tighten loose operational paths: sudo chmod 700 /etc/cron.*",
    "HOME-9304": "Tighten permission sets on user storage structures so other accounts can't skim them: chmod 700 /home/ppk",
    "HOME-9306": "Ensure ownership properties match user contexts: sudo chown -R ppk:ppk /home/ppk",
    "KRNL-6000": "Your sysctl rules differ from the basic Lynis scan profile (e.g., sysrq, core dumps, or packet routing). Tune them in /etc/sysctl.d/99-security.conf."
}

def check_lynis_installed():
    """Verify if Lynis is installed on the host machine system path."""
    if shutil.which("lynis") is None:
        print(f"{Colors.BOLD}====== 📊 LYNIS CRITICAL COMPLIANCE PARSER ====== {Colors.ENDC}")
        print(f"\n{Colors.FAIL}[✗] Error:{Colors.ENDC} Lynis is not installed on this system.")
        print(f"\n{Colors.BLUE}👉 To install it on Arch/CachyOS, run:{Colors.ENDC}")
        print(f"   {Colors.BOLD}sudo pacman -S lynis{Colors.ENDC}")
        print(f"\n{Colors.BLUE}👉 After installing, run your first audit system check using:{Colors.ENDC}")
        print(f"   {Colors.BOLD}sudo lynis audit system{Colors.ENDC}\n")
        return False
    return True

# ─── CHECK IMPLEMENTATIONS ──────────────────────────────────────

def is_umask_already_tightened():
    login_defs_path = "/etc/login.defs"
    if not os.path.exists(login_defs_path):
        return False
    try:
        with open(login_defs_path, "r") as f:
            for line in f:
                if line.strip().startswith("UMASK") and not line.strip().startswith("#"):
                    parts = line.split()
                    if len(parts) >= 2 and parts[1] == "027":
                        return True
    except Exception:
        pass
    return False

def is_sysctl_already_hardened():
    sysctl_file = "/etc/sysctl.d/99-security.conf"
    if not os.path.exists(sysctl_file):
        return False

    required_keys = [
        "net.ipv4.conf.all.accept_redirects",
        "net.ipv4.conf.all.log_martians",
        "fs.suid_dumpable",
        "kernel.kptr_restrict",
        "kernel.sysrq"
    ]

    try:
        with open(sysctl_file, "r") as f:
            content = f.read()
        return all(key in content for key in required_keys)
    except Exception:
        pass
    return False

def is_permissions_already_locked():
    grub_path = "/boot/grub/grub.cfg"
    cron_path = "/etc/cron.hourly"

    grub_ok = True
    cron_ok = True

    if os.path.exists(grub_path):
        grub_ok = (os.stat(grub_path).st_mode & 0o777) == 0o600
    if os.path.exists(cron_path):
        cron_ok = (os.stat(cron_path).st_mode & 0o777) == 0o700

    return grub_ok and cron_ok

def is_ssh_already_hardened():
    ssh_config = "/etc/ssh/sshd_config"
    if not os.path.exists(ssh_config):
        return True # If it doesn't exist, don't try prompting to append

    required_params = ["PermitRootLogin no", "MaxAuthTries 3", "AllowTcpForwarding no"]
    try:
        with open(ssh_config, "r") as f:
            content = f.read()
        return all(param in content for param in required_params)
    except Exception:
        pass
    return False

# ─── FIX EXECUTION ENGINE ───────────────────────────────────────

def apply_umask_fix():
    if is_umask_already_tightened():
        print(f"\n{Colors.GREEN}[✓] Umask Tightening already applied.{Colors.ENDC}")
        return True

    print(f"\n{Colors.BOLD}[📝 FEATURE: Umask Tightening]{Colors.ENDC}")
    print("   What it does: Changes default file permissions from 022 to 027.")
    print("   Why it matters: Prevents newly created files and folders from being readable by other unprivileged non-root users.")
    choice = input(f"   👉 Apply Umask tightening? (y/N): ").strip().lower()
    if choice != 'y':
        return False

    login_defs_path = "/etc/login.defs"
    if not os.path.exists(login_defs_path):
        print(f"  {Colors.FAIL}[✗] Could not find {login_defs_path}{Colors.ENDC}")
        return False

    try:
        with open(login_defs_path, "r") as f:
            lines = f.readlines()

        modified = False
        for i, line in enumerate(lines):
            if line.strip().startswith("UMASK") and not line.strip().startswith("#"):
                parts = line.split()
                if len(parts) >= 2 and parts[1] == "022":
                    lines[i] = line.replace("022", "027")
                    modified = True
                    break

        if modified:
            with open(login_defs_path, "w") as f:
                f.writelines(lines)
            print(f"  {Colors.GREEN}[✓] Successfully updated UMASK to 027 in {login_defs_path}{Colors.ENDC}")
            return True
        else:
            print(f"  {Colors.BLUE}[i] UMASK is already modified or alternative rule is defined.{Colors.ENDC}")
            return False
    except Exception as e:
        print(f"  {Colors.FAIL}[✗] Failed updating umask entries: {e}{Colors.ENDC}")
        return False

def apply_sysctl_fix():
    if is_sysctl_already_hardened():
        print(f"\n{Colors.GREEN}[✓] Kernel / Network Hardening parameters are already present.{Colors.ENDC}")
        return True

    print(f"\n{Colors.BOLD}[🛡️  FEATURE: Kernel / Network Hardening via sysctl]{Colors.ENDC}")
    print("   What it does: Injects several core network defense and local restriction flags:")
    print("     - Blocks ICMP Redirects: Prevents attackers from routing your internet traffic through their device.")
    print("     - Logs Martian Packets: Tells the kernel to log packets with impossible or fake source addresses.")
    print("     - Restricts Core Dumps (fs.suid_dumpable=0): Stops setuid programs from leaking memory data to disk.")
    print("     - Hides Kernel Pointers (kernel.kptr_restrict=2): Obfuscates internal kernel addresses from unprivileged users.")
    print("     - Disables Magic SysRq (kernel.sysrq=0): Stops physical interlopers from executing raw kernel actions.")
    choice = input(f"   👉 Append safe sysctl configurations to 99-security.conf? (y/N): ").strip().lower()
    if choice != 'y':
        return False

    sysctl_dir = "/etc/sysctl.d"
    sysctl_file = os.path.join(sysctl_dir, "99-security.conf")

    security_params = [
        "\n# Hardening parameters injected via Lynis Parser tool",
        "net.ipv4.conf.all.accept_redirects = 0",
        "net.ipv4.conf.default.accept_redirects = 0",
        "net.ipv6.conf.all.accept_redirects = 0",
        "net.ipv6.conf.default.accept_redirects = 0",
        "net.ipv4.conf.all.send_redirects = 0",
        "net.ipv4.conf.all.log_martians = 1",
        "net.ipv4.conf.default.log_martians = 1",
        "fs.suid_dumpable = 0",
        "kernel.kptr_restrict = 2",
        "kernel.sysrq = 0\n"
    ]

    try:
        os.makedirs(sysctl_dir, exist_ok=True)
        with open(sysctl_file, "a") as f:
            f.write("\n".join(security_params))
        print(f"  {Colors.GREEN}[✓] Hardening rules appended to {sysctl_file}{Colors.ENDC}")

        subprocess.run(["sysctl", "--system"], check=True, stdout=subprocess.DEVNULL)
        print(f"  {Colors.GREEN}[✓] Active sysctl configurations reloaded successfully.{Colors.ENDC}")
        return True
    except Exception as e:
        print(f"  {Colors.FAIL}[✗] Failed writing sysctl configuration parameters: {e}{Colors.ENDC}")
        return False

def apply_permissions_fix():
    if is_permissions_already_locked():
        print(f"\n{Colors.GREEN}[✓] File Permissions Lockdowns are already set securely.{Colors.ENDC}")
        return True

    print(f"\n{Colors.BOLD}[🔒 FEATURE: File Permissions Lockdowns]{Colors.ENDC}")
    print("   What it does: Restricts access to highly sensitive configuration paths:")
    print("     - Sets /boot/grub/grub.cfg to 600 (Only root can read/write boot configuration parameters).")
    print("     - Sets /etc/cron.hourly to 700 (Only root can touch or view system maintenance routines).")
    choice = input(f"   👉 Apply strict permissions constraints to GRUB and cron.hourly configs? (y/N): ").strip().lower()
    if choice != 'y':
        return False

    try:
        grub_path = "/boot/grub/grub.cfg"
        cron_path = "/etc/cron.hourly"

        if os.path.exists(grub_path):
            os.chmod(grub_path, 0o600)
            print(f"  {Colors.GREEN}[✓] Set 600 permissions on {grub_path}{Colors.ENDC}")
        else:
            print(f"  {Colors.BLUE}[i] {grub_path} not found (skipping).{Colors.ENDC}")

        if os.path.exists(cron_path):
            os.chmod(cron_path, 0o700)
            print(f"  {Colors.GREEN}[✓] Set 700 permissions on {cron_path}{Colors.ENDC}")
        else:
            print(f"  {Colors.BLUE}[i] {cron_path} not found (skipping).{Colors.ENDC}")
        return True
    except Exception as e:
        print(f"  {Colors.FAIL}[✗] Failed updating file path permissions: {e}{Colors.ENDC}")
        return False

def apply_ssh_hardening():
    if is_ssh_already_hardened():
        print(f"\n{Colors.GREEN}[✓] OpenSSH Configuration appears already hardened.{Colors.ENDC}")
        return True

    print(f"\n{Colors.BOLD}[🔑 FEATURE: OpenSSH Hardening]{Colors.ENDC}")
    print("   What it does: Hardens your SSH service settings to prevent remote brute force or exploitation.")
    print("     - Disables remote root logins.")
    print("     - Drops connection after 3 failed password attempts.")
    print("     - Automatically terminates inactive connections.")
    print("     - Disables unneeded X11 and TCP tunneling over SSH connections.")
    choice = input(f"   👉 Append security parameters to /etc/ssh/sshd_config? (y/N): ").strip().lower()
    if choice != 'y':
        return False

    ssh_config = "/etc/ssh/sshd_config"
    if not os.path.exists(ssh_config):
        print(f"  {Colors.FAIL}[✗] OpenSSH config file not found at {ssh_config}{Colors.ENDC}")
        return False

    ssh_params = [
        "\n# Hardening variables injected via Custom Lynis Parser",
        "PermitRootLogin no",
        "MaxAuthTries 3",
        "ClientAliveInterval 300",
        "ClientAliveCountMax 2",
        "AllowTcpForwarding no",
        "X11Forwarding no\n"
    ]

    try:
        with open(ssh_config, "a") as f:
            f.write("\n".join(ssh_params))
        print(f"  {Colors.GREEN}[✓] OpenSSH security variables written to {ssh_config}{Colors.ENDC}")
        return True
    except Exception as e:
        print(f"  {Colors.FAIL}[✗] Failed updating OpenSSH config profile: {e}{Colors.ENDC}")
        return False

def apply_arch_audit_fix():
    if shutil.which("arch-audit"):
        print(f"\n{Colors.GREEN}[✓] arch-audit tracking engine is already installed.{Colors.ENDC}")
        return True

    print(f"\n{Colors.BOLD}[📦 FEATURE: Install arch-audit Tracking Engine]{Colors.ENDC}")
    print("   What it does: Automates the deployment of the 'arch-audit' framework.")
    print("   Why it matters: Installs a local tracking tool that parses package metadata against active CVE records")
    print("                   so you can instantly check if your installed applications have vulnerabilities.")
    choice = input(f"   👉 Bootstrap 'arch-audit' package using pacman? (y/N): ").strip().lower()
    if choice != 'y':
        return False

    try:
        subprocess.run(["pacman", "-S", "--noconfirm", "arch-audit"], check=True)
        print(f"  {Colors.GREEN}[✓] arch-audit successfully deployed on system environment.{Colors.ENDC}")
        return True
    except Exception as e:
        print(f"  {Colors.FAIL}[✗] Failed targeting native deployment hooks: {e}{Colors.ENDC}")
        return False

def parse_lynis_report(report_path="/var/log/lynis-report.dat"):
    print(f"{Colors.BOLD}====== 📊 LYNIS CRITICAL COMPLIANCE PARSER ====== {Colors.ENDC}")

    if not os.path.exists(report_path):
        print(f"\n{Colors.WARNING}[!] Notice:{Colors.ENDC} Could not find Lynis report data at {report_path}")
        print(f"👉 Since Lynis is installed, generate your initial report by running:")
        print(f"   {Colors.BOLD}sudo lynis audit system{Colors.ENDC}\n")
        return

    warnings = []
    suggestions = []
    hardening_index = "N/A"

    try:
        with open(report_path, "r") as f:
            for line in f:
                if line.startswith("warning[]="):
                    content = line.split("=")[1].strip().split("|")
                    warnings.append({"tag": content[0], "text": content[1]})
                elif line.startswith("suggestion[]="):
                    content = line.split("=")[1].strip().split("|")
                    tag = content[0]
                    suggestions.append({"tag": tag, "text": content[1]})
                elif line.startswith("hardening_index="):
                    hardening_index = line.split("=")[1].strip()
    except PermissionError:
        print(f"\n{Colors.FAIL}[✗] Permission Denied:{Colors.ENDC} Execute using {Colors.BOLD}sudo{Colors.ENDC}.")
        return
    except Exception as e:
        print(f"[✗] Error parsing file: {e}")
        return

    print(f"\n{Colors.BLUE}🛡️ Overall System Hardening Index:{Colors.ENDC} {Colors.BOLD}{Colors.GREEN}{hardening_index}/100{Colors.ENDC}")
    print("─" * 65)

    print(f"\n{Colors.FAIL}{Colors.BOLD}🚨 CRITICAL WARNINGS ({len(warnings)}){Colors.ENDC}")
    if not warnings:
        print(f"  {Colors.GREEN}[✓] Zero critical security warnings found!{Colors.ENDC}")
    else:
        for w in warnings:
            print(f"\n  ⚠️  {Colors.BOLD}{w['text']}{Colors.ENDC} [{w['tag']}]")
            fix = FIX_DATABASE.get(w['tag'], "Review system variables associated with this configuration block.")
            print(f"     {Colors.GREEN}👉 Suggested Fix:{Colors.ENDC} {fix}")

    print("\n" + "─" * 65)

    print(f"\n{Colors.WARNING}{Colors.BOLD}💡 HARDENING SUGGESTIONS ({len(suggestions)}){Colors.ENDC}")
    if not suggestions:
        print("  [✓] No optimization suggestions generated.")
    else:
        for s in suggestions:
            print(f"\n  ▪ {s['text']} [{s['tag']}]")
            fix = FIX_DATABASE.get(s['tag'], "Review configuration parameters or adjust systemd flags for this item.")
            print(f"    {Colors.BLUE}👉 Action:{Colors.ENDC} {fix}")

    print(f"\n{Colors.BOLD}=================== ANALYSIS FINISHED ==================={Colors.ENDC}\n")

    print(f"{Colors.BOLD}🛠️  INTERACTIVE RECOVERY AND HARDENING TOOLKIT{Colors.ENDC}")
    print("─" * 65)

    # Interactively run the functions (will now self-check state first)
    apply_umask_fix()
    apply_sysctl_fix()
    apply_permissions_fix()
    apply_ssh_hardening()
    apply_arch_audit_fix()

    print(f"\n{Colors.BOLD}========================================================={Colors.ENDC}\n")

if __name__ == "__main__":
    if os.geteuid() != 0:
        print(f"{Colors.FAIL}[!] Access Denied:{Colors.ENDC} Run with {Colors.BOLD}sudo python3 <script_name>.py{Colors.ENDC}")
        sys.exit(1)

    if check_lynis_installed():
        parse_lynis_report()
