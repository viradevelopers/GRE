#!/bin/bash

# ═══════════════════════════════════════════════════════════════════
#  VIRA TUNNEL - GRE Tunnel Auto Installer
#  Version: 1.0
#  Supported OS: Ubuntu / Debian
# ═══════════════════════════════════════════════════════════════════

set -e

# ─── Colors ───────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Logo ─────────────────────────────────────────────────────────
show_logo() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo -e "║   ${WHITE}██╗   ██╗${PURPLE}██╗${RED}██████╗  ${GREEN}█████╗ ${YELLOW}  ████████╗██╗   ██╗███╗   ██╗${CYAN}    ║"
    echo -e "║   ${WHITE}██║   ██║${PURPLE}██║${RED}██╔══██╗${GREEN}██╔══██╗${YELLOW}  ╚══██╔══╝██║   ██║████╗  ██║${CYAN}    ║"
    echo -e "║   ${WHITE}██║   ██║${PURPLE}██║${RED}██████╔╝${GREEN}███████║${YELLOW}     ██║   ██║   ██║██╔██╗ ██║${CYAN}    ║"
    echo -e "║   ${WHITE}╚██╗ ██╔╝${PURPLE}██║${RED}██╔══██╗${GREEN}██╔══██║${YELLOW}     ██║   ██║   ██║██║╚██╗██║${CYAN}    ║"
    echo -e "║   ${WHITE} ╚████╔╝ ${PURPLE}██║${RED}██║  ██║${GREEN}██║  ██║${YELLOW}     ██║   ╚██████╔╝██║ ╚████║${CYAN}    ║"
    echo -e "║   ${WHITE}  ╚═══╝  ${PURPLE}╚═╝${RED}╚═╝  ╚═╝${GREEN}╚═╝  ╚═╝${YELLOW}     ╚═╝    ╚═════╝ ╚═╝  ╚═══╝${CYAN}    ║"
    echo "║                                                                   ║"
    echo -e "║           ${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CYAN}           ║"
    echo -e "║           ${YELLOW}⚡  GRE Tunnel Auto Installer v1.0  ⚡${CYAN}              ║"
    echo -e "║           ${GREEN}            Vira Developers${CYAN}                           ║"
    echo -e "║           ${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CYAN}           ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ─── Separator ────────────────────────────────────────────────────
separator() {
    echo -e "${CYAN}  ──────────────────────────────────────────────────────────${NC}"
}

# ─── Info Box ─────────────────────────────────────────────────────
info_box() {
    echo -e "${BLUE}  ℹ  ${WHITE}$1${NC}"
}

# ─── Success Box ──────────────────────────────────────────────────
success_box() {
    echo -e "${GREEN}  ✔  ${WHITE}$1${NC}"
}

# ─── Error Box ────────────────────────────────────────────────────
error_box() {
    echo -e "${RED}  ✘  ${WHITE}$1${NC}"
}

# ─── Warning Box ─────────────────────────────────────────────────
warn_box() {
    echo -e "${YELLOW}  ⚠  ${WHITE}$1${NC}"
}

# ─── Step Counter ────────────────────────────────────────────────
STEP=0
show_step() {
    STEP=$((STEP + 1))
    echo ""
    echo -e "${PURPLE}  ┌─────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}  │  ${YELLOW}Step ${STEP}: ${WHITE}${BOLD}$1${NC}${PURPLE}"
    echo -e "${PURPLE}  └─────────────────────────────────────────────────────┘${NC}"
}

# ─── Spinner ──────────────────────────────────────────────────────
spinner() {
    local pid=$1
    local msg=$2
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while kill -0 "$pid" 2>/dev/null; do
        for (( i=0; i<${#spinstr}; i++ )); do
            echo -ne "\r${CYAN}  ${spinstr:$i:1}  ${WHITE}${msg}${NC}"
            sleep 0.1
        done
    done
    echo -ne "\r${GREEN}  ✔  ${WHITE}${msg} - Done!${NC}\n"
}

# ─── Progress Bar ────────────────────────────────────────────────
progress_bar() {
    local duration=$1
    local msg=$2
    local width=40
    echo -ne "\n"
    for ((i=0; i<=width; i++)); do
        local percent=$((i * 100 / width))
        local filled=$i
        local empty=$((width - i))
        local bar=""
        for ((j=0; j<filled; j++)); do bar+="█"; done
        for ((j=0; j<empty; j++)); do bar+="░"; done
        echo -ne "\r${CYAN}  [${GREEN}${bar}${CYAN}] ${WHITE}${percent}%  ${msg}${NC}"
        sleep $(echo "scale=3; $duration/$width" | bc 2>/dev/null || echo "0.02")
    done
    echo ""
}

# ─── Root Check ───────────────────────────────────────────────────
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_box "This script must be run as root!"
        echo -e "${YELLOW}  Run: ${WHITE}sudo bash $0${NC}"
        exit 1
    fi
}

# ─── Detect Server IP ────────────────────────────────────────────
detect_ip() {
    local ip=""
    ip=$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    if [[ -z "$ip" ]]; then
        ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "")
    fi
    echo "$ip"
}

# ─── Validate IP ─────────────────────────────────────────────────
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [[ $i -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# ─── Install Dependencies ────────────────────────────────────────
install_deps() {
    show_step "Installing Dependencies"
    
    (apt update -y > /dev/null 2>&1) &
    spinner $! "Updating package lists"
    
    (apt install -y iptables-persistent iproute2 > /dev/null 2>&1) &
    spinner $! "Installing required packages"
    
    success_box "All dependencies installed successfully"
}

# ─── Enable IP Forwarding ────────────────────────────────────────
enable_forwarding() {
    show_step "Enabling IP Forwarding"
    
    # Remove duplicates
    sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p > /dev/null 2>&1
    
    success_box "IP forwarding enabled permanently"
}

# ─── Setup KHAREJ (Foreign Server) ───────────────────────────────
setup_kharej() {
    show_logo
    
    echo -e "${GREEN}${BOLD}"
    echo "  ┌─────────────────────────────────────────────────────┐"
    echo "  │          🌍  KHAREJ (Foreign) Server Setup          │"
    echo "  └─────────────────────────────────────────────────────┘"
    echo -e "${NC}"
    separator
    
    local MY_IP
    MY_IP=$(detect_ip)
    
    # ─── Get IPs ─────────────────────────────────────────────
    echo ""
    info_box "Detected this server's IP: ${GREEN}${MY_IP}${NC}"
    echo ""
    
    echo -ne "${YELLOW}  ➤  ${WHITE}Enter this server's (Kharej) public IP [${GREEN}${MY_IP}${WHITE}]: ${NC}"
    read -r KHAREJ_IP
    KHAREJ_IP=${KHAREJ_IP:-$MY_IP}
    
    if ! validate_ip "$KHAREJ_IP"; then
        error_box "Invalid IP address: $KHAREJ_IP"
        exit 1
    fi
    
    echo -ne "${YELLOW}  ➤  ${WHITE}Enter Iran server's public IP: ${NC}"
    read -r IRAN_IP
    
    if [[ -z "$IRAN_IP" ]] || ! validate_ip "$IRAN_IP"; then
        error_box "Invalid IP address: $IRAN_IP"
        exit 1
    fi
    
    # ─── Tunnel IPs ──────────────────────────────────────────
    echo ""
    info_box "Default tunnel IPs: Iran=${GREEN}102.230.9.1/30${NC}  Kharej=${GREEN}102.230.9.2/30${NC}"
    echo -ne "${YELLOW}  ➤  ${WHITE}Enter Kharej tunnel IP [${GREEN}102.230.9.2/30${WHITE}]: ${NC}"
    read -r KH_TUN_IP
    KH_TUN_IP=${KH_TUN_IP:-"102.230.9.2/30"}
    
    echo ""
    separator
    echo ""
    echo -e "${WHITE}${BOLD}  📋  Configuration Summary:${NC}"
    echo -e "${WHITE}  ┌───────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}  │  ${CYAN}Server Role    : ${WHITE}KHAREJ (Foreign)        ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${CYAN}Kharej IP      : ${GREEN}${KHAREJ_IP}${WHITE}              │${NC}"
    echo -e "${WHITE}  │  ${CYAN}Iran IP        : ${GREEN}${IRAN_IP}${WHITE}              │${NC}"
    echo -e "${WHITE}  │  ${CYAN}Tunnel IP      : ${GREEN}${KH_TUN_IP}${WHITE}          │${NC}"
    echo -e "${WHITE}  └───────────────────────────────────────────┘${NC}"
    echo ""
    
    echo -ne "${YELLOW}  ➤  ${WHITE}Proceed with installation? [${GREEN}y${WHITE}/${RED}n${WHITE}]: ${NC}"
    read -r CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        warn_box "Installation cancelled by user"
        exit 0
    fi
    
    # ─── Install ─────────────────────────────────────────────
    install_deps
    enable_forwarding
    
    # ─── Create GRE Script ───────────────────────────────────
    show_step "Creating GRE Tunnel Script"
    
    cat > /usr/local/sbin/greKH.sh << EOF
#!/bin/bash
set -e

ip tunnel del greKH 2>/dev/null || true

ip tunnel add greKH mode gre remote ${IRAN_IP} local ${KHAREJ_IP} ttl 255
ip link set greKH mtu 1476
ip addr add ${KH_TUN_IP} dev greKH
ip link set greKH up
EOF
    
    chmod +x /usr/local/sbin/greKH.sh
    success_box "GRE tunnel script created at /usr/local/sbin/greKH.sh"
    
    # ─── IPTables ────────────────────────────────────────────
    show_step "Configuring IPTables NAT Rules"
    
    # Flush existing NAT rules to avoid duplicates
    iptables -t nat -F 2>/dev/null || true
    iptables -t nat -A POSTROUTING -j MASQUERADE
    
    (netfilter-persistent save > /dev/null 2>&1) &
    spinner $! "Saving IPTables rules"
    
    success_box "NAT rules configured and saved"
    
    # ─── Systemd Service ─────────────────────────────────────
    show_step "Creating Systemd Service"
    
    cat > /etc/systemd/system/greKH.service << 'EOF'
[Unit]
Description=VIRA TUNNEL - GRE Tunnel KH
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/greKH.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable --now greKH.service > /dev/null 2>&1
    
    success_box "Systemd service created and enabled"
    
    # ─── Final ───────────────────────────────────────────────
    progress_bar 1 "Finalizing installation"
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                   ║${NC}"
    echo -e "${GREEN}║   ${WHITE}${BOLD}✅  KHAREJ SERVER SETUP COMPLETED SUCCESSFULLY!${NC}${GREEN}               ║${NC}"
    echo -e "${GREEN}║                                                                   ║${NC}"
    echo -e "${GREEN}║   ${CYAN}Tunnel Script  : ${WHITE}/usr/local/sbin/greKH.sh${GREEN}                       ║${NC}"
    echo -e "${GREEN}║   ${CYAN}Service Name   : ${WHITE}greKH.service${GREEN}                                  ║${NC}"
    echo -e "${GREEN}║   ${CYAN}Service Status : ${WHITE}$(systemctl is-active greKH.service 2>/dev/null || echo 'unknown')${GREEN}                                     ║${NC}"
    echo -e "${GREEN}║                                                                   ║${NC}"
    echo -e "${GREEN}║   ${YELLOW}⚠  Now run this script on your IRAN server${GREEN}                     ║${NC}"
    echo -e "${GREEN}║   ${YELLOW}⚠  Then reboot BOTH servers${GREEN}                                    ║${NC}"
    echo -e "${GREEN}║                                                                   ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    show_verification
}

# ─── Setup IRAN Server ───────────────────────────────────────────
setup_iran() {
    show_logo
    
    echo -e "${BLUE}${BOLD}"
    echo "  ┌─────────────────────────────────────────────────────┐"
    echo "  │            🇮🇷  IRAN Server Setup                    │"
    echo "  └─────────────────────────────────────────────────────┘"
    echo -e "${NC}"
    separator
    
    local MY_IP
    MY_IP=$(detect_ip)
    
    # ─── Get IPs ─────────────────────────────────────────────
    echo ""
    info_box "Detected this server's IP: ${GREEN}${MY_IP}${NC}"
    echo ""
    
    echo -ne "${YELLOW}  ➤  ${WHITE}Enter this server's (Iran) public IP [${GREEN}${MY_IP}${WHITE}]: ${NC}"
    read -r IRAN_IP
    IRAN_IP=${IRAN_IP:-$MY_IP}
    
    if ! validate_ip "$IRAN_IP"; then
        error_box "Invalid IP address: $IRAN_IP"
        exit 1
    fi
    
    echo -ne "${YELLOW}  ➤  ${WHITE}Enter Kharej (Foreign) server's public IP: ${NC}"
    read -r KHAREJ_IP
    
    if [[ -z "$KHAREJ_IP" ]] || ! validate_ip "$KHAREJ_IP"; then
        error_box "Invalid IP address: $KHAREJ_IP"
        exit 1
    fi
    
    # ─── Tunnel IPs ──────────────────────────────────────────
    echo ""
    info_box "Default tunnel IPs: Iran=${GREEN}102.230.9.1/30${NC}  Kharej=${GREEN}102.230.9.2/30${NC}"
    echo -ne "${YELLOW}  ➤  ${WHITE}Enter Iran tunnel IP [${GREEN}102.230.9.1/30${WHITE}]: ${NC}"
    read -r IR_TUN_IP
    IR_TUN_IP=${IR_TUN_IP:-"102.230.9.1/30"}
    
    echo -ne "${YELLOW}  ➤  ${WHITE}Enter Kharej tunnel IP (without subnet) [${GREEN}102.230.9.2${WHITE}]: ${NC}"
    read -r KH_TUN_REMOTE
    KH_TUN_REMOTE=${KH_TUN_REMOTE:-"102.230.9.2"}
    
    echo -ne "${YELLOW}  ➤  ${WHITE}Enter Iran tunnel IP (without subnet) [${GREEN}102.230.9.1${WHITE}]: ${NC}"
    read -r IR_TUN_LOCAL
    IR_TUN_LOCAL=${IR_TUN_LOCAL:-"102.230.9.1"}
    
    echo ""
    separator
    echo ""
    echo -e "${WHITE}${BOLD}  📋  Configuration Summary:${NC}"
    echo -e "${WHITE}  ┌───────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}  │  ${CYAN}Server Role    : ${WHITE}IRAN                    ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${CYAN}Iran IP        : ${GREEN}${IRAN_IP}${WHITE}              │${NC}"
    echo -e "${WHITE}  │  ${CYAN}Kharej IP      : ${GREEN}${KHAREJ_IP}${WHITE}              │${NC}"
    echo -e "${WHITE}  │  ${CYAN}Tunnel IP      : ${GREEN}${IR_TUN_IP}${WHITE}          │${NC}"
    echo -e "${WHITE}  │  ${CYAN}Forward To     : ${GREEN}${KH_TUN_REMOTE}${WHITE}            │${NC}"
    echo -e "${WHITE}  └───────────────────────────────────────────┘${NC}"
    echo ""
    
    echo -ne "${YELLOW}  ➤  ${WHITE}Proceed with installation? [${GREEN}y${WHITE}/${RED}n${WHITE}]: ${NC}"
    read -r CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        warn_box "Installation cancelled by user"
        exit 0
    fi
    
    # ─── Install ─────────────────────────────────────────────
    install_deps
    enable_forwarding
    
    # ─── Create GRE Script ───────────────────────────────────
    show_step "Creating GRE Tunnel Script"
    
    cat > /usr/local/sbin/greIR.sh << EOF
#!/bin/bash
set -e

ip tunnel del greIR 2>/dev/null || true

ip tunnel add greIR mode gre remote ${KHAREJ_IP} local ${IRAN_IP} ttl 255
ip link set greIR mtu 1476
ip addr add ${IR_TUN_IP} dev greIR
ip link set greIR up
EOF
    
    chmod +x /usr/local/sbin/greIR.sh
    success_box "GRE tunnel script created at /usr/local/sbin/greIR.sh"
    
    # ─── IPTables ────────────────────────────────────────────
    show_step "Configuring IPTables NAT Rules"
    
    # Flush existing NAT rules to avoid duplicates
    iptables -t nat -F 2>/dev/null || true
    
    iptables -t nat -A PREROUTING -p tcp --dport 22 -j DNAT --to-destination ${IR_TUN_LOCAL}
    iptables -t nat -A PREROUTING -j DNAT --to-destination ${KH_TUN_REMOTE}
    iptables -t nat -A POSTROUTING -j MASQUERADE
    
    (netfilter-persistent save > /dev/null 2>&1) &
    spinner $! "Saving IPTables rules"
    
    success_box "NAT rules configured and saved"
    info_box "Port 22 (SSH) stays on this server"
    info_box "All other traffic forwarded to ${KH_TUN_REMOTE}"
    
    # ─── Systemd Service ─────────────────────────────────────
    show_step "Creating Systemd Service"
    
    cat > /etc/systemd/system/greIR.service << 'EOF'
[Unit]
Description=VIRA TUNNEL - GRE Tunnel IR
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/greIR.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable --now greIR.service > /dev/null 2>&1
    
    success_box "Systemd service created and enabled"
    
    # ─── Final ───────────────────────────────────────────────
    progress_bar 1 "Finalizing installation"
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                   ║${NC}"
    echo -e "${GREEN}║   ${WHITE}${BOLD}✅  IRAN SERVER SETUP COMPLETED SUCCESSFULLY!${NC}${GREEN}                  ║${NC}"
    echo -e "${GREEN}║                                                                   ║${NC}"
    echo -e "${GREEN}║   ${CYAN}Tunnel Script  : ${WHITE}/usr/local/sbin/greIR.sh${GREEN}                       ║${NC}"
    echo -e "${GREEN}║   ${CYAN}Service Name   : ${WHITE}greIR.service${GREEN}                                  ║${NC}"
    echo -e "${GREEN}║   ${CYAN}Service Status : ${WHITE}$(systemctl is-active greIR.service 2>/dev/null || echo 'unknown')${GREEN}                                     ║${NC}"
    echo -e "${GREEN}║                                                                   ║${NC}"
    echo -e "${GREEN}║   ${YELLOW}⚠  Make sure Kharej server is also configured${GREEN}                 ║${NC}"
    echo -e "${GREEN}║   ${YELLOW}⚠  Then reboot BOTH servers${GREEN}                                    ║${NC}"
    echo -e "${GREEN}║                                                                   ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    show_verification
}

# ─── Uninstall ────────────────────────────────────────────────────
uninstall_tunnel() {
    show_logo
    
    echo -e "${RED}${BOLD}"
    echo "  ┌─────────────────────────────────────────────────────┐"
    echo "  │           🗑️   Uninstall VIRA TUNNEL                │"
    echo "  └─────────────────────────────────────────────────────┘"
    echo -e "${NC}"
    
    echo -ne "${YELLOW}  ➤  ${WHITE}Are you sure you want to uninstall? [${GREEN}y${WHITE}/${RED}n${WHITE}]: ${NC}"
    read -r CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        warn_box "Uninstall cancelled"
        exit 0
    fi
    
    echo ""
    
    # Stop and disable services
    info_box "Stopping services..."
    systemctl stop greKH.service 2>/dev/null || true
    systemctl stop greIR.service 2>/dev/null || true
    systemctl disable greKH.service 2>/dev/null || true
    systemctl disable greIR.service 2>/dev/null || true
    success_box "Services stopped"
    
    # Remove service files
    info_box "Removing service files..."
    rm -f /etc/systemd/system/greKH.service
    rm -f /etc/systemd/system/greIR.service
    systemctl daemon-reload
    success_box "Service files removed"
    
    # Remove tunnel scripts
    info_box "Removing tunnel scripts..."
    rm -f /usr/local/sbin/greKH.sh
    rm -f /usr/local/sbin/greIR.sh
    success_box "Tunnel scripts removed"
    
    # Remove tunnels
    info_box "Removing GRE tunnels..."
    ip tunnel del greKH 2>/dev/null || true
    ip tunnel del greIR 2>/dev/null || true
    success_box "GRE tunnels removed"
    
    # Flush NAT rules
    info_box "Flushing NAT rules..."
    iptables -t nat -F 2>/dev/null || true
    netfilter-persistent save > /dev/null 2>&1 || true
    success_box "NAT rules flushed"
    
    echo ""
    echo -e "${GREEN}  ✔  ${WHITE}${BOLD}VIRA TUNNEL has been completely uninstalled!${NC}"
    echo ""
}

# ─── Check Status ────────────────────────────────────────────────
check_status() {
    show_logo
    
    echo -e "${CYAN}${BOLD}"
    echo "  ┌─────────────────────────────────────────────────────┐"
    echo "  │            📊  Tunnel Status Check                  │"
    echo "  └─────────────────────────────────────────────────────┘"
    echo -e "${NC}"
    echo ""
    
    # Check GRE Tunnels
    echo -e "${WHITE}${BOLD}  🔗  GRE Tunnel Interfaces:${NC}"
    separator
    local tunnel_output
    tunnel_output=$(ip tunnel show 2>/dev/null)
    if [[ -n "$tunnel_output" ]]; then
        echo -e "${GREEN}$tunnel_output${NC}" | while read -r line; do
            echo -e "  ${GREEN}  ✔  ${WHITE}$line${NC}"
        done
    else
        echo -e "  ${RED}  ✘  No GRE tunnels found${NC}"
    fi
    
    echo ""
    
    # Check Services
    echo -e "${WHITE}${BOLD}  ⚙️   Service Status:${NC}"
    separator
    
    for svc in greKH.service greIR.service; do
        if systemctl is-active "$svc" > /dev/null 2>&1; then
            echo -e "  ${GREEN}  ✔  ${WHITE}$svc: ${GREEN}ACTIVE${NC}"
        elif systemctl is-enabled "$svc" > /dev/null 2>&1; then
            echo -e "  ${YELLOW}  ⚠  ${WHITE}$svc: ${YELLOW}ENABLED but INACTIVE${NC}"
        else
            echo -e "  ${RED}  ─  ${WHITE}$svc: ${RED}NOT CONFIGURED${NC}"
        fi
    done
    
    echo ""
    
    # Check IP Forwarding
    echo -e "${WHITE}${BOLD}  🔀  IP Forwarding:${NC}"
    separator
    local fwd
    fwd=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)
    if [[ "$fwd" == "1" ]]; then
        echo -e "  ${GREEN}  ✔  ${WHITE}IP Forwarding is ${GREEN}ENABLED${NC}"
    else
        echo -e "  ${RED}  ✘  ${WHITE}IP Forwarding is ${RED}DISABLED${NC}"
    fi
    
    echo ""
    
    # Check NAT Rules
    echo -e "${WHITE}${BOLD}  🛡️   NAT Rules:${NC}"
    separator
    iptables -t nat -L -n -v 2>/dev/null | while read -r line; do
        echo -e "  ${CYAN}  $line${NC}"
    done
    
    echo ""
    
    # Ping Test
    echo -e "${WHITE}${BOLD}  📡  Connectivity Test:${NC}"
    separator
    
    for target in 102.230.9.1 102.230.9.2; do
        if ping -c 1 -W 2 "$target" > /dev/null 2>&1; then
            echo -e "  ${GREEN}  ✔  ${WHITE}Ping to ${GREEN}$target${WHITE}: ${GREEN}SUCCESS${NC}"
        else
            echo -e "  ${RED}  ✘  ${WHITE}Ping to ${RED}$target${WHITE}: ${RED}FAILED${NC}"
        fi
    done
    
    echo ""
}

# ─── Show Verification Commands ──────────────────────────────────
show_verification() {
    echo -e "${CYAN}${BOLD}  📝  Verification Commands:${NC}"
    echo -e "${WHITE}  ┌───────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}  │  ${CYAN}ip tunnel show${NC}${WHITE}                            │${NC}"
    echo -e "${WHITE}  │  ${CYAN}iptables -t nat -L -n -v${NC}${WHITE}                  │${NC}"
    echo -e "${WHITE}  │  ${CYAN}ping 102.230.9.1${NC}${WHITE}  (from Kharej)           │${NC}"
    echo -e "${WHITE}  │  ${CYAN}ping 102.230.9.2${NC}${WHITE}  (from Iran)             │${NC}"
    echo -e "${WHITE}  └───────────────────────────────────────────┘${NC}"
    echo ""
}

# ─── Main Menu ────────────────────────────────────────────────────
main_menu() {
    show_logo
    
    echo -e "${WHITE}${BOLD}  Please select your server role:${NC}"
    echo ""
    echo -e "${WHITE}  ┌─────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}  │                                                     │${NC}"
    echo -e "${WHITE}  │   ${GREEN}[1]${WHITE}  🌍  Setup ${GREEN}KHAREJ${WHITE} (Foreign) Server              │${NC}"
    echo -e "${WHITE}  │                                                     │${NC}"
    echo -e "${WHITE}  │   ${BLUE}[2]${WHITE}  🏠  Setup ${BLUE}IRAN${WHITE} Server                          │${NC}"
    echo -e "${WHITE}  │                                                     │${NC}"
    echo -e "${WHITE}  │   ${CYAN}[3]${WHITE}  📊  Check Tunnel ${CYAN}Status${WHITE}                        │${NC}"
    echo -e "${WHITE}  │                                                     │${NC}"
    echo -e "${WHITE}  │   ${RED}[4]${WHITE}  🗑️   ${RED}Uninstall${WHITE} Tunnel                            │${NC}"
    echo -e "${WHITE}  │                                                     │${NC}"
    echo -e "${WHITE}  │   ${YELLOW}[0]${WHITE}  🚪  ${YELLOW}Exit${WHITE}                                       │${NC}"
    echo -e "${WHITE}  │                                                     │${NC}"
    echo -e "${WHITE}  └─────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -ne "${YELLOW}  ➤  ${WHITE}Enter your choice [0-4]: ${NC}"
    read -r choice
    
    case $choice in
        1) setup_kharej ;;
        2) setup_iran ;;
        3) check_status ;;
        4) uninstall_tunnel ;;
        0) 
            echo ""
            echo -e "${GREEN}  👋  Thank you for using ${BOLD}VIRA TUNNEL${NC}${GREEN}! Goodbye!${NC}"
            echo ""
            exit 0
            ;;
        *)
            error_box "Invalid option! Please try again."
            sleep 2
            main_menu
            ;;
    esac
}

# ─── Entry Point ─────────────────────────────────────────────────
check_root
main_menu
