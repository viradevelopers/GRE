#!/bin/bash
# ============================================================
#  VIRA TUNNEL - Professional GRE Tunnel Setup Script
#  Version : 3.0
#  Author  : Vira Network Team
#  License : Free / Open Source
# ============================================================

# ──────────────────── COLORS & STYLES ────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

G1='\033[38;5;220m'
G2='\033[38;5;221m'
G3='\033[38;5;178m'
G4='\033[38;5;172m'
G5='\033[38;5;136m'
G6='\033[38;5;214m'
G7='\033[38;5;208m'
G8='\033[38;5;179m'
BG_GOLD='\033[48;5;136m'

# ──────────────────── GLOBAL VARIABLES ────────────────────
IRAN_IP=""
KHAREJ_IP=""
IRAN_PRIVATE_IP=""
KHAREJ_PRIVATE_IP=""
CONFIG_DIR="/etc/vira-tunnel"
CONFIG_FILE="${CONFIG_DIR}/config"
TUNNEL_SCRIPT="/usr/local/sbin/vira-gre.sh"
SERVICE_FILE="/etc/systemd/system/vira-gre.service"
TUNNEL_NAME="viraGRE"

# ──────────────────── BASIC FUNCTIONS ────────────────────

clear_screen() {
    clear
    echo ""
}

show_logo() {
    echo ""
    echo -e "${G1}    ╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${G1}    ║${NC}                                                              ${G1}║${NC}"
    echo -e "${G1}    ║${G2}    ██╗   ██╗ ██╗ ██████╗   █████╗                             ${G1}║${NC}"
    echo -e "${G1}    ║${G2}    ██║   ██║ ██║ ██╔══██╗ ██╔══██╗                            ${G1}║${NC}"
    echo -e "${G2}    ║${G3}    ██║   ██║ ██║ ██████╔╝ ███████║                            ${G2}║${NC}"
    echo -e "${G2}    ║${G3}    ╚██╗ ██╔╝ ██║ ██╔══██╗ ██╔══██║                            ${G2}║${NC}"
    echo -e "${G3}    ║${G4}     ╚████╔╝  ██║ ██║  ██║ ██║  ██║                            ${G3}║${NC}"
    echo -e "${G3}    ║${G4}      ╚═══╝   ╚═╝ ╚═╝  ╚═╝ ╚═╝  ╚═╝                            ${G3}║${NC}"
    echo -e "${G4}    ║${NC}                                                              ${G4}║${NC}"
    echo -e "${G4}    ║${G5}   ████████╗██╗   ██╗███╗   ██╗███╗   ██╗███████╗██╗          ${G4}║${NC}"
    echo -e "${G5}    ║${G6}   ╚══██╔══╝██║   ██║████╗  ██║████╗  ██║██╔════╝██║          ${G5}║${NC}"
    echo -e "${G5}    ║${G6}      ██║   ██║   ██║██╔██╗ ██║██╔██╗ ██║█████╗  ██║          ${G5}║${NC}"
    echo -e "${G6}    ║${G7}      ██║   ██║   ██║██║╚██╗██║██║╚██╗██║██╔══╝  ██║          ${G6}║${NC}"
    echo -e "${G6}    ║${G7}      ██║   ╚██████╔╝██║ ╚████║██║ ╚████║███████╗███████╗     ${G6}║${NC}"
    echo -e "${G7}    ║${G8}      ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝╚══════╝╚══════╝     ${G7}║${NC}"
    echo -e "${G7}    ║${NC}                                                              ${G7}║${NC}"
    echo -e "${G8}    ╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${G8}    ║${NC}  ${G2}★${NC} ${WHITE}Professional GRE Tunnel Manager${NC}          ${DIM}Version 3.0${NC}   ${G8}    ║${NC}"
    echo -e "${G8}    ║${NC}  ${G3}★${NC} ${DIM}Secure${NC} ${WHITE}•${NC} ${DIM}Fast${NC} ${WHITE}•${NC} ${DIM}Reliable${NC} ${WHITE}•${NC} ${DIM}Persistent${NC}                    ${G8}  ║${NC}"
    echo -e "${G8}    ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_main_menu() {
    clear_screen
    show_logo

    # Show current status if configured
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE" 2>/dev/null
        local role_icon=""
        [[ "$ROLE" == "IRAN" ]] && role_icon="🇮🇷" || role_icon="🌍"
        local svc_status="${RED}INACTIVE${NC}"
        systemctl is-active --quiet vira-gre.service 2>/dev/null && svc_status="${GREEN}ACTIVE${NC}"
        echo -e "    ${DIM}Current: ${WHITE}${ROLE}${NC} ${role_icon} ${DIM}| Service: ${svc_status} ${DIM}| Tunnel IP: ${CYAN}${IRAN_PRIVATE_IP}↔${KHAREJ_PRIVATE_IP}${NC}"
        echo ""
    fi

    echo -e "${G3}    ┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${G3}    │${NC}  ${G1}⚙${NC}  ${WHITE}${BOLD}MAIN MENU${NC}                                                 ${G3}│${NC}"
    echo -e "${G3}    ├──────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${G3}    │${NC}                                                              ${G3}│${NC}"
    echo -e "${G3}    │${NC}   ${G2}[1]${NC} ${WHITE}➤  Setup IRAN Server${NC}       ${DIM}(Local / Inside Server)${NC}      ${G3}│${NC}"
    echo -e "${G3}    │${NC}                                                              ${G3}│${NC}"
    echo -e "${G3}    │${NC}   ${G2}[2]${NC} ${WHITE}➤  Setup KHAREJ Server${NC}     ${DIM}(Remote / Outside Server)${NC}    ${G3}│${NC}"
    echo -e "${G3}    │${NC}                                                              ${G3}│${NC}"
    echo -e "${G3}    │${NC}   ${G2}[3]${NC} ${WHITE}➤  Check Tunnel Status${NC}     ${DIM}(Full Diagnostics + Ping)${NC}   ${G3}│${NC}"
    echo -e "${G3}    │${NC}                                                              ${G3}│${NC}"
    echo -e "${G3}    │${NC}   ${G2}[4]${NC} ${WHITE}➤  Restart Tunnel${NC}          ${DIM}(Restart GRE Service)${NC}       ${G3}│${NC}"
    echo -e "${G3}    │${NC}                                                              ${G3}│${NC}"
    echo -e "${G3}    │${NC}   ${G2}[5]${NC} ${WHITE}➤  Uninstall Tunnel${NC}        ${DIM}(Remove Everything)${NC}         ${G3}│${NC}"
    echo -e "${G3}    │${NC}                                                              ${G3}│${NC}"
    echo -e "${G3}    │${NC}   ${RED}[0]${NC} ${WHITE}➤  Exit${NC}                                                 ${G3}│${NC}"
    echo -e "${G3}    │${NC}                                                              ${G3}│${NC}"
    echo -e "${G3}    └──────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -ne "    ${G2}❯${NC} ${WHITE}Enter your choice: ${NC}"
}

print_step() {
    echo -e "    ${G2}[Step $1]${NC} ${WHITE}$2${NC}"
}

print_success() {
    echo -e "    ${GREEN}  ✔  $1${NC}"
}

print_error() {
    echo -e "    ${RED}  ✘  $1${NC}"
}

print_warning() {
    echo -e "    ${YELLOW}  ⚠  $1${NC}"
}

print_info() {
    echo -e "    ${CYAN}  ℹ  $1${NC}"
}

progress_bar() {
    local duration=$1
    local msg="$2"
    local width=40
    echo -ne "    ${DIM}${msg}${NC} ["
    for ((i=0; i<=width; i++)); do
        echo -ne "${G2}█${NC}"
        sleep "$(awk "BEGIN{printf \"%.3f\", $duration/$width}" 2>/dev/null || echo 0.05)"
    done
    echo -e "] ${GREEN}Done!${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo ""
        print_error "This script must be run as root!"
        echo -e "    ${YELLOW}  ➤  Please run: ${WHITE}sudo bash $0${NC}"
        echo ""
        exit 1
    fi
}

validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if ((i > 255)); then return 1; fi
        done
        return 0
    fi
    return 1
}

# ──────────────────── DETECT LOCAL IP ────────────────────

detect_local_ip() {
    # Get the main public IP of this server
    local detected=""

    # Method 1: Default route interface IP
    detected=$(ip -4 route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[0-9.]+' | head -1)

    if [[ -z "$detected" ]]; then
        # Method 2: First non-loopback IP
        detected=$(ip -4 addr show scope global 2>/dev/null | grep -oP 'inet \K[0-9.]+' | head -1)
    fi

    if [[ -z "$detected" ]]; then
        # Method 3: hostname
        detected=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi

    echo "$detected"
}

# ──────────────────── LOAD GRE MODULE ────────────────────

ensure_gre_module() {
    # Load GRE kernel module
    if ! lsmod | grep -q "^ip_gre"; then
        modprobe ip_gre 2>/dev/null || true
    fi

    # Make it persistent
    if [[ ! -f /etc/modules-load.d/gre.conf ]]; then
        echo "ip_gre" > /etc/modules-load.d/gre.conf
    fi

    # Also ensure generic GRE
    if ! lsmod | grep -q "^gre"; then
        modprobe gre 2>/dev/null || true
    fi
}

# ──────────────────── GET SERVER IPS ────────────────────

get_server_ips() {
    local role="$1"

    echo ""
    echo -e "${G3}    ┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${G3}    │${NC}  ${G1}🔧${NC} ${WHITE}${BOLD}IP ADDRESS CONFIGURATION${NC}                                    ${G3}│${NC}"
    echo -e "${G3}    └──────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Auto-detect local IP
    local auto_ip
    auto_ip=$(detect_local_ip)

    if [[ "$role" == "IRAN" ]]; then
        # IRAN IP
        if [[ -n "$auto_ip" ]]; then
            echo -ne "    ${G2}❯${NC} ${WHITE}Enter IRAN Server Public IP [${CYAN}${auto_ip}${NC}]: ${NC}"
            read input_ip
            IRAN_IP=${input_ip:-$auto_ip}
        else
            echo -ne "    ${G2}❯${NC} ${WHITE}Enter IRAN Server Public IP: ${NC}"
            read IRAN_IP
        fi

        while ! validate_ip "$IRAN_IP"; do
            print_error "Invalid IP! Try again."
            echo -ne "    ${G2}❯${NC} ${WHITE}Enter IRAN Server Public IP: ${NC}"
            read IRAN_IP
        done
        print_success "IRAN IP: ${CYAN}$IRAN_IP${NC}"
        echo ""

        # KHAREJ IP
        echo -ne "    ${G2}❯${NC} ${WHITE}Enter KHAREJ Server Public IP: ${NC}"
        read KHAREJ_IP
        while ! validate_ip "$KHAREJ_IP"; do
            print_error "Invalid IP! Try again."
            echo -ne "    ${G2}❯${NC} ${WHITE}Enter KHAREJ Server Public IP: ${NC}"
            read KHAREJ_IP
        done
        print_success "KHAREJ IP: ${CYAN}$KHAREJ_IP${NC}"

    else
        # KHAREJ setup
        # KHAREJ IP
        if [[ -n "$auto_ip" ]]; then
            echo -ne "    ${G2}❯${NC} ${WHITE}Enter KHAREJ Server Public IP [${CYAN}${auto_ip}${NC}]: ${NC}"
            read input_ip
            KHAREJ_IP=${input_ip:-$auto_ip}
        else
            echo -ne "    ${G2}❯${NC} ${WHITE}Enter KHAREJ Server Public IP: ${NC}"
            read KHAREJ_IP
        fi

        while ! validate_ip "$KHAREJ_IP"; do
            print_error "Invalid IP! Try again."
            echo -ne "    ${G2}❯${NC} ${WHITE}Enter KHAREJ Server Public IP: ${NC}"
            read KHAREJ_IP
        done
        print_success "KHAREJ IP: ${CYAN}$KHAREJ_IP${NC}"
        echo ""

        # IRAN IP
        echo -ne "    ${G2}❯${NC} ${WHITE}Enter IRAN Server Public IP: ${NC}"
        read IRAN_IP
        while ! validate_ip "$IRAN_IP"; do
            print_error "Invalid IP! Try again."
            echo -ne "    ${G2}❯${NC} ${WHITE}Enter IRAN Server Public IP: ${NC}"
            read IRAN_IP
        done
        print_success "IRAN IP: ${CYAN}$IRAN_IP${NC}"
    fi

    echo ""
    echo -e "    ${DIM}Press Enter for defaults: 10.10.10.1 (IRAN) / 10.10.10.2 (KHAREJ)${NC}"
    echo ""

    echo -ne "    ${G2}❯${NC} ${WHITE}IRAN Private Tunnel IP [${CYAN}10.10.10.1${NC}]: ${NC}"
    read IRAN_PRIVATE_IP
    IRAN_PRIVATE_IP=${IRAN_PRIVATE_IP:-10.10.10.1}
    if ! validate_ip "$IRAN_PRIVATE_IP"; then
        IRAN_PRIVATE_IP="10.10.10.1"
        print_warning "Using default: 10.10.10.1"
    fi

    echo -ne "    ${G2}❯${NC} ${WHITE}KHAREJ Private Tunnel IP [${CYAN}10.10.10.2${NC}]: ${NC}"
    read KHAREJ_PRIVATE_IP
    KHAREJ_PRIVATE_IP=${KHAREJ_PRIVATE_IP:-10.10.10.2}
    if ! validate_ip "$KHAREJ_PRIVATE_IP"; then
        KHAREJ_PRIVATE_IP="10.10.10.2"
        print_warning "Using default: 10.10.10.2"
    fi

    echo ""
    echo -e "${G3}    ┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${G3}    │${NC}  ${G1}📋${NC} ${WHITE}${BOLD}CONFIGURATION SUMMARY${NC}                                       ${G3}│${NC}"
    echo -e "${G3}    ├──────────────────────────────────────────────────────────────┤${NC}"
    printf "    ${G3}│${NC}   ${G2}IRAN Public IP${NC}        :  ${CYAN}%-30s${NC}${G3}│${NC}\n" "$IRAN_IP"
    printf "    ${G3}│${NC}   ${G2}KHAREJ Public IP${NC}      :  ${CYAN}%-30s${NC}${G3}│${NC}\n" "$KHAREJ_IP"
    printf "    ${G3}│${NC}   ${G2}IRAN Private IP${NC}       :  ${CYAN}%-30s${NC}${G3}│${NC}\n" "${IRAN_PRIVATE_IP}/30"
    printf "    ${G3}│${NC}   ${G2}KHAREJ Private IP${NC}     :  ${CYAN}%-30s${NC}${G3}│${NC}\n" "${KHAREJ_PRIVATE_IP}/30"
    echo -e "${G3}    └──────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -ne "    ${G2}❯${NC} ${WHITE}Confirm? ${GREEN}[Y/n]${NC}: "
    read confirm
    if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
        print_warning "Aborted."
        return 1
    fi
    return 0
}

# ──────────────────── SAVE / LOAD CONFIG ────────────────────

save_config() {
    local role="$1"
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << EOF
ROLE=${role}
IRAN_IP=${IRAN_IP}
KHAREJ_IP=${KHAREJ_IP}
IRAN_PRIVATE_IP=${IRAN_PRIVATE_IP}
KHAREJ_PRIVATE_IP=${KHAREJ_PRIVATE_IP}
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')
EOF
    chmod 600 "$CONFIG_FILE"
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        return 0
    fi
    return 1
}

# ──────────────────── ANIMATED PING ────────────────────

animated_ping() {
    local target_ip="$1"
    local label="$2"
    local count=4
    local success=0
    local fail=0
    local times=()

    echo -e "    ${G6}╭───────────────────────────────────────────────────────────╮${NC}"
    echo -e "    ${G6}│${NC}  ${G2}🏓${NC} ${WHITE}${BOLD}${label}${NC}"
    echo -e "    ${G6}│${NC}  ${DIM}Target: ${CYAN}${target_ip}${NC}"
    echo -e "    ${G6}├───────────────────────────────────────────────────────────┤${NC}"

    for ((i=1; i<=count; i++)); do
        echo -ne "    ${G6}│${NC}  ${DIM}Packet ${i}/${count}...${NC}"

        local ping_result
        ping_result=$(ping -c 1 -W 3 "$target_ip" 2>&1)
        local exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            local rtt
            rtt=$(echo "$ping_result" | grep -oP 'time=\K[0-9.]+' || echo "")
            success=$((success + 1))

            if [[ -n "$rtt" ]]; then
                times+=("$rtt")
                local rtt_int=${rtt%.*}
                rtt_int=${rtt_int:-0}
                local clr="${GREEN}"
                ((rtt_int > 100)) && clr="${YELLOW}"
                ((rtt_int > 300)) && clr="${RED}"
                echo -e "\r    ${G6}│${NC}  ${GREEN}✔${NC} Packet ${i}:  ${clr}${rtt} ms${NC}                              "
            else
                echo -e "\r    ${G6}│${NC}  ${GREEN}✔${NC} Packet ${i}:  ${GREEN}OK${NC}                                    "
            fi
        else
            fail=$((fail + 1))
            echo -e "\r    ${G6}│${NC}  ${RED}✘${NC} Packet ${i}:  ${RED}Timeout${NC}                                "
        fi
        sleep 0.2
    done

    echo -e "    ${G6}├───────────────────────────────────────────────────────────┤${NC}"

    local loss=$((fail * 100 / count))

    if ((success > 0)); then
        # Calculate stats
        local min_t="999999" max_t="0" sum_t="0"
        for t in "${times[@]}"; do
            sum_t=$(awk "BEGIN{printf \"%.2f\", $sum_t + $t}")
            local t_int=${t%.*}
            t_int=${t_int:-0}
            local min_int=${min_t%.*}
            min_int=${min_int:-999999}
            local max_int=${max_t%.*}
            max_int=${max_int:-0}
            ((t_int < min_int)) && min_t="$t"
            ((t_int > max_int)) && max_t="$t"
        done
        local avg_t
        avg_t=$(awk "BEGIN{printf \"%.2f\", $sum_t / ${#times[@]}}")

        local loss_clr="${GREEN}"
        ((loss > 0)) && loss_clr="${YELLOW}"
        ((loss >= 100)) && loss_clr="${RED}"

        echo -e "    ${G6}│${NC}  ${GREEN}✅ CONNECTED${NC}  |  ${success}/${count} received  ${loss_clr}(${loss}% loss)${NC}"

        if [[ ${#times[@]} -gt 0 ]]; then
            echo -e "    ${G6}│${NC}  ${G2}⏱${NC}  min=${CYAN}${min_t}ms${NC}  avg=${CYAN}${avg_t}ms${NC}  max=${CYAN}${max_t}ms${NC}"

            local avg_int=${avg_t%.*}
            avg_int=${avg_int:-0}
            local quality="" qbar=""
            if ((avg_int <= 30)); then
                quality="${GREEN}${BOLD}EXCELLENT${NC}"; qbar="${GREEN}██████████${NC}"
            elif ((avg_int <= 80)); then
                quality="${GREEN}VERY GOOD${NC}"; qbar="${GREEN}████████${NC}${DIM}██${NC}"
            elif ((avg_int <= 150)); then
                quality="${YELLOW}GOOD${NC}"; qbar="${YELLOW}██████${NC}${DIM}████${NC}"
            elif ((avg_int <= 300)); then
                quality="${YELLOW}FAIR${NC}"; qbar="${YELLOW}████${NC}${DIM}██████${NC}"
            else
                quality="${RED}POOR${NC}"; qbar="${RED}██${NC}${DIM}████████${NC}"
            fi
            echo -e "    ${G6}│${NC}  ${G2}📶${NC}  Quality: [${qbar}] ${quality}"
        fi
    else
        echo -e "    ${G6}│${NC}  ${RED}❌ DISCONNECTED${NC}  |  ${RED}${fail}/${count} lost (100% loss)${NC}"
        echo -e "    ${G6}│${NC}  ${YELLOW}💡${NC} ${DIM}Check config, firewall, remote server status${NC}"
    fi

    echo -e "    ${G6}╰───────────────────────────────────────────────────────────╯${NC}"
    echo ""
}

# ──────────────────── SETUP IRAN ────────────────────

setup_iran() {
    clear_screen
    show_logo
    echo -e "    ${BG_GOLD}${WHITE}${BOLD}  ⚡ Setting Up: IRAN Server 🇮🇷  ${NC}"
    echo ""

    get_server_ips "IRAN" || return

    echo ""
    echo -e "${G3}    ┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${G3}    │${NC}  ${G1}🚀${NC} ${WHITE}${BOLD}INSTALLING IRAN SERVER${NC}                                      ${G3}│${NC}"
    echo -e "${G3}    └──────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Step 1: Load GRE module
    print_step "1/9" "Loading GRE kernel module..."
    ensure_gre_module
    if lsmod | grep -q "ip_gre"; then
        print_success "GRE module loaded: $(lsmod | grep ip_gre | awk '{print $1, $3}')"
    else
        print_error "Failed to load GRE module! Kernel may not support GRE."
        print_info "Try: apt install linux-modules-extra-\$(uname -r)"
        echo -ne "    ${G2}❯${NC} ${WHITE}Continue anyway? [y/N]: ${NC}"
        read cont
        [[ "$cont" != "y" && "$cont" != "Y" ]] && return
    fi
    sleep 0.3

    # Step 2: Create tunnel script
    print_step "2/9" "Creating GRE tunnel script..."
    cat > "$TUNNEL_SCRIPT" << EOF
#!/bin/bash
set -e

# VIRA TUNNEL - IRAN Side
# Generated: $(date)

# Load GRE module
modprobe ip_gre 2>/dev/null || true

# Wait for network
sleep 2

# Remove old tunnel if exists
ip tunnel del ${TUNNEL_NAME} 2>/dev/null || true
ip link del ${TUNNEL_NAME} 2>/dev/null || true

# Create GRE tunnel
ip tunnel add ${TUNNEL_NAME} mode gre remote ${KHAREJ_IP} local ${IRAN_IP} ttl 255
ip link set ${TUNNEL_NAME} mtu 1476
ip addr add ${IRAN_PRIVATE_IP}/30 dev ${TUNNEL_NAME}
ip link set ${TUNNEL_NAME} up

# Verify
sleep 1
ip link show ${TUNNEL_NAME}
echo "VIRA TUNNEL (IRAN) is UP"
EOF
    chmod +x "$TUNNEL_SCRIPT"
    print_success "Script created: ${TUNNEL_SCRIPT}"
    sleep 0.3

    # Step 3: Save config
    print_step "3/9" "Saving configuration..."
    save_config "IRAN"
    print_success "Config saved: ${CONFIG_FILE}"
    sleep 0.3

    # Step 4: IP forwarding
    print_step "4/9" "Enabling IP forwarding..."
    sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
    local fwd=$(cat /proc/sys/net/ipv4/ip_forward)
    if [[ "$fwd" == "1" ]]; then
        print_success "IP forwarding: ENABLED"
    else
        print_error "Failed to enable IP forwarding!"
    fi
    sleep 0.3

    # Step 5: Install iptables-persistent
    print_step "5/9" "Installing iptables-persistent..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq > /dev/null 2>&1
    apt-get install -y -qq iptables-persistent netfilter-persistent > /dev/null 2>&1
    print_success "iptables-persistent installed"
    sleep 0.3

    # Step 6: NAT rules
    print_step "6/9" "Configuring iptables NAT rules..."

    # Clean old rules first
    iptables -t nat -F PREROUTING 2>/dev/null || true
    iptables -t nat -F POSTROUTING 2>/dev/null || true

    # SSH stays on this server
    iptables -t nat -A PREROUTING -p tcp --dport 22 -j DNAT --to-destination ${IRAN_PRIVATE_IP}
    # Everything else goes to KHAREJ
    iptables -t nat -A PREROUTING -j DNAT --to-destination ${KHAREJ_PRIVATE_IP}
    # MASQUERADE for return traffic
    iptables -t nat -A POSTROUTING -j MASQUERADE

    print_success "PREROUTING: SSH → ${IRAN_PRIVATE_IP}"
    print_success "PREROUTING: ALL → ${KHAREJ_PRIVATE_IP}"
    print_success "POSTROUTING: MASQUERADE"
    sleep 0.3

    # Step 7: Save rules
    print_step "7/9" "Saving iptables rules..."
    netfilter-persistent save > /dev/null 2>&1
    print_success "Rules saved permanently"
    sleep 0.3

    # Step 8: Create service
    print_step "8/9" "Creating systemd service..."
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=VIRA TUNNEL - GRE Tunnel (IRAN)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${TUNNEL_SCRIPT}
RemainAfterExit=yes
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    print_success "Service file created"
    sleep 0.3

    # Step 9: Start everything
    print_step "9/9" "Starting tunnel..."

    systemctl daemon-reload
    systemctl enable vira-gre.service > /dev/null 2>&1

    # Run the tunnel script directly first
    bash "$TUNNEL_SCRIPT" > /dev/null 2>&1
    local tunnel_up=$?

    # Also ensure systemd knows about it
    systemctl restart vira-gre.service > /dev/null 2>&1 || true

    echo ""

    # Verify tunnel is up
    if ip link show ${TUNNEL_NAME} 2>/dev/null | grep -q "UP\|UNKNOWN"; then
        print_success "${GREEN}${BOLD}Tunnel interface ${TUNNEL_NAME} is UP!${NC}"

        local assigned_ip
        assigned_ip=$(ip addr show ${TUNNEL_NAME} 2>/dev/null | grep -oP 'inet \K[0-9.]+')
        if [[ -n "$assigned_ip" ]]; then
            print_success "Assigned IP: ${CYAN}${assigned_ip}${NC}"
        fi
    else
        print_error "Tunnel may not be fully up yet"
        print_info "Checking detailed status..."
        echo ""
        ip tunnel show 2>/dev/null | head -5 | while read line; do
            echo -e "    ${DIM}  $line${NC}"
        done
    fi

    echo ""
    progress_bar 1 "Finalizing"
    echo ""

    # Quick local ping test
    echo -e "    ${G6}${BOLD}▸ Quick Local Test${NC}"
    echo ""
    if ping -c 1 -W 2 "$IRAN_PRIVATE_IP" > /dev/null 2>&1; then
        print_success "Local tunnel IP ${CYAN}${IRAN_PRIVATE_IP}${NC} is ${GREEN}reachable${NC}"
    else
        print_warning "Local tunnel IP not yet responding (may need remote side)"
    fi

    echo ""
    echo -e "${G3}    ╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${G3}    ║${NC}  ${GREEN}${BOLD}✅ IRAN SERVER SETUP COMPLETED!${NC}                               ${G3}║${NC}"
    echo -e "${G3}    ╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${G3}    ║${NC}                                                              ${G3}║${NC}"
    echo -e "${G3}    ║${NC}  ${YELLOW}📌 Now do this:${NC}                                             ${G3}║${NC}"
    echo -e "${G3}    ║${NC}  ${WHITE}  1. Run this script on KHAREJ server (option 2)${NC}             ${G3}║${NC}"
    echo -e "${G3}    ║${NC}  ${WHITE}  2. Use same IPs on both sides${NC}                              ${G3}║${NC}"
    echo -e "${G3}    ║${NC}  ${WHITE}  3. Check status with option 3${NC}                              ${G3}║${NC}"
    echo -e "${G3}    ║${NC}                                                              ${G3}║${NC}"
    echo -e "${G3}    ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -ne "    ${G2}❯${NC} ${WHITE}Press Enter to return to menu...${NC}"
    read
}

# ──────────────────── SETUP KHAREJ ────────────────────

setup_kharej() {
    clear_screen
    show_logo
    echo -e "    ${BG_GOLD}${WHITE}${BOLD}  ⚡ Setting Up: KHAREJ Server 🌍  ${NC}"
    echo ""

    get_server_ips "KHAREJ" || return

    echo ""
    echo -e "${G3}    ┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${G3}    │${NC}  ${G1}🚀${NC} ${WHITE}${BOLD}INSTALLING KHAREJ SERVER${NC}                                    ${G3}│${NC}"
    echo -e "${G3}    └──────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Step 1: Load GRE module
    print_step "1/8" "Loading GRE kernel module..."
    ensure_gre_module
    if lsmod | grep -q "ip_gre"; then
        print_success "GRE module loaded"
    else
        print_error "Failed to load GRE module!"
        echo -ne "    ${G2}❯${NC} ${WHITE}Continue anyway? [y/N]: ${NC}"
        read cont
        [[ "$cont" != "y" && "$cont" != "Y" ]] && return
    fi
    sleep 0.3

    # Step 2: Create tunnel script
    print_step "2/8" "Creating GRE tunnel script..."
    cat > "$TUNNEL_SCRIPT" << EOF
#!/bin/bash
set -e

# VIRA TUNNEL - KHAREJ Side
# Generated: $(date)

# Load GRE module
modprobe ip_gre 2>/dev/null || true

# Wait for network
sleep 2

# Remove old tunnel if exists
ip tunnel del ${TUNNEL_NAME} 2>/dev/null || true
ip link del ${TUNNEL_NAME} 2>/dev/null || true

# Create GRE tunnel
ip tunnel add ${TUNNEL_NAME} mode gre remote ${IRAN_IP} local ${KHAREJ_IP} ttl 255
ip link set ${TUNNEL_NAME} mtu 1476
ip addr add ${KHAREJ_PRIVATE_IP}/30 dev ${TUNNEL_NAME}
ip link set ${TUNNEL_NAME} up

# Verify
sleep 1
ip link show ${TUNNEL_NAME}
echo "VIRA TUNNEL (KHAREJ) is UP"
EOF
    chmod +x "$TUNNEL_SCRIPT"
    print_success "Script created: ${TUNNEL_SCRIPT}"
    sleep 0.3

    # Step 3: Save config
    print_step "3/8" "Saving configuration..."
    save_config "KHAREJ"
    print_success "Config saved: ${CONFIG_FILE}"
    sleep 0.3

    # Step 4: IP forwarding
    print_step "4/8" "Enabling IP forwarding..."
    sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
    print_success "IP forwarding: ENABLED"
    sleep 0.3

    # Step 5: Install iptables-persistent
    print_step "5/8" "Installing iptables-persistent..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq > /dev/null 2>&1
    apt-get install -y -qq iptables-persistent netfilter-persistent > /dev/null 2>&1
    print_success "iptables-persistent installed"
    sleep 0.3

    # Step 6: MASQUERADE
    print_step "6/8" "Configuring MASQUERADE..."
    iptables -t nat -F POSTROUTING 2>/dev/null || true
    iptables -t nat -A POSTROUTING -j MASQUERADE
    netfilter-persistent save > /dev/null 2>&1
    print_success "MASQUERADE rule set and saved"
    sleep 0.3

    # Step 7: Create service
    print_step "7/8" "Creating systemd service..."
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=VIRA TUNNEL - GRE Tunnel (KHAREJ)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${TUNNEL_SCRIPT}
RemainAfterExit=yes
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    print_success "Service file created"
    sleep 0.3

    # Step 8: Start
    print_step "8/8" "Starting tunnel..."
    systemctl daemon-reload
    systemctl enable vira-gre.service > /dev/null 2>&1

    # Run directly
    bash "$TUNNEL_SCRIPT" > /dev/null 2>&1
    systemctl restart vira-gre.service > /dev/null 2>&1 || true

    echo ""

    if ip link show ${TUNNEL_NAME} 2>/dev/null | grep -q "UP\|UNKNOWN"; then
        print_success "${GREEN}${BOLD}Tunnel interface ${TUNNEL_NAME} is UP!${NC}"
        local assigned_ip
        assigned_ip=$(ip addr show ${TUNNEL_NAME} 2>/dev/null | grep -oP 'inet \K[0-9.]+')
        [[ -n "$assigned_ip" ]] && print_success "Assigned IP: ${CYAN}${assigned_ip}${NC}"
    else
        print_error "Tunnel may not be fully up yet"
    fi

    echo ""
    progress_bar 1 "Finalizing"
    echo ""

    echo -e "    ${G6}${BOLD}▸ Quick Local Test${NC}"
    echo ""
    if ping -c 1 -W 2 "$KHAREJ_PRIVATE_IP" > /dev/null 2>&1; then
        print_success "Local tunnel IP ${CYAN}${KHAREJ_PRIVATE_IP}${NC} is ${GREEN}reachable${NC}"
    else
        print_warning "Local tunnel IP not yet responding (may need remote side)"
    fi

    echo ""
    echo -e "${G3}    ╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${G3}    ║${NC}  ${GREEN}${BOLD}✅ KHAREJ SERVER SETUP COMPLETED!${NC}                             ${G3}║${NC}"
    echo -e "${G3}    ╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${G3}    ║${NC}                                                              ${G3}║${NC}"
    echo -e "${G3}    ║${NC}  ${YELLOW}📌 Make sure IRAN server is also configured${NC}                  ${G3}║${NC}"
    echo -e "${G3}    ║${NC}  ${WHITE}  Then check status with option 3${NC}                            ${G3}║${NC}"
    echo -e "${G3}    ║${NC}                                                              ${G3}║${NC}"
    echo -e "${G3}    ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -ne "    ${G2}❯${NC} ${WHITE}Press Enter to return to menu...${NC}"
    read
}

# ──────────────────── STATUS CHECK ────────────────────

check_status() {
    clear_screen
    show_logo

    echo -e "${G3}    ╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${G3}    ║${NC}  ${G1}📊${NC} ${WHITE}${BOLD}VIRA TUNNEL - FULL DIAGNOSTICS${NC}                              ${G3}║${NC}"
    echo -e "${G3}    ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local config_loaded=false
    local saved_role="" saved_iran_ip="" saved_kharej_ip=""
    local saved_iran_priv="" saved_kharej_priv="" saved_date=""

    if load_config; then
        config_loaded=true
        saved_role="$ROLE"
        saved_iran_ip="$IRAN_IP"
        saved_kharej_ip="$KHAREJ_IP"
        saved_iran_priv="$IRAN_PRIVATE_IP"
        saved_kharej_priv="$KHAREJ_PRIVATE_IP"
        saved_date="$INSTALL_DATE"
    fi

    # ═══ 1. SERVER INFO ═══
    echo -e "    ${G2}━━━ 1. SERVER INFORMATION ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if $config_loaded; then
        local ri=""
        [[ "$saved_role" == "IRAN" ]] && ri="🇮🇷" || ri="🌍"
        printf "    ${WHITE}Role${NC}           : ${CYAN}${BOLD}%-20s${NC} %s\n" "$saved_role" "$ri"
        printf "    ${WHITE}IRAN IP${NC}        : ${CYAN}%-20s${NC}\n" "$saved_iran_ip"
        printf "    ${WHITE}KHAREJ IP${NC}      : ${CYAN}%-20s${NC}\n" "$saved_kharej_ip"
        printf "    ${WHITE}IRAN Private${NC}   : ${CYAN}%-20s${NC}\n" "${saved_iran_priv}/30"
        printf "    ${WHITE}KHAREJ Private${NC} : ${CYAN}%-20s${NC}\n" "${saved_kharej_priv}/30"
        printf "    ${WHITE}Installed${NC}      : ${DIM}%-20s${NC}\n" "$saved_date"
    else
        print_warning "No config found at ${CONFIG_FILE}"
    fi
    echo ""

    # ═══ 2. GRE MODULE ═══
    echo -e "    ${G2}━━━ 2. KERNEL MODULE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    if lsmod | grep -q "ip_gre"; then
        print_success "ip_gre module: ${GREEN}LOADED${NC}"
    else
        print_error "ip_gre module: ${RED}NOT LOADED${NC}"
        print_info "Run: modprobe ip_gre"
    fi
    echo ""

    # ═══ 3. TUNNEL INTERFACE ═══
    echo -e "    ${G2}━━━ 3. TUNNEL INTERFACE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local tunnel_exists=false
    if ip tunnel show 2>/dev/null | grep -q "${TUNNEL_NAME}"; then
        tunnel_exists=true
        local tun_info
        tun_info=$(ip tunnel show ${TUNNEL_NAME} 2>/dev/null)
        print_success "Interface: ${WHITE}${tun_info}${NC}"

        local tun_ip
        tun_ip=$(ip addr show ${TUNNEL_NAME} 2>/dev/null | grep -oP 'inet \K[0-9./]+')
        if [[ -n "$tun_ip" ]]; then
            print_success "IP Address: ${CYAN}${tun_ip}${NC}"
        else
            print_warning "No IP assigned to ${TUNNEL_NAME}"
        fi

        local link_state
        link_state=$(ip link show ${TUNNEL_NAME} 2>/dev/null | grep -oP 'state \K\w+')
        if [[ "$link_state" == "UP" || "$link_state" == "UNKNOWN" ]]; then
            print_success "Link State: ${GREEN}${BOLD}UP${NC}"
        else
            print_error "Link State: ${RED}${link_state:-DOWN}${NC}"
        fi

        local mtu
        mtu=$(ip link show ${TUNNEL_NAME} 2>/dev/null | grep -oP 'mtu \K\d+')
        print_info "MTU: ${CYAN}${mtu:-N/A}${NC}"
    else
        print_error "Tunnel ${WHITE}${TUNNEL_NAME}${NC} ${RED}NOT FOUND${NC}"

        # Show all tunnels
        local all_tun
        all_tun=$(ip tunnel show 2>/dev/null)
        if [[ -n "$all_tun" ]]; then
            print_info "Existing tunnels:"
            echo "$all_tun" | while read line; do
                echo -e "    ${DIM}    $line${NC}"
            done
        fi
    fi
    echo ""

    # ═══ 4. SERVICE STATUS ═══
    echo -e "    ${G2}━━━ 4. SERVICE STATUS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [[ -f "$SERVICE_FILE" ]]; then
        if systemctl is-active --quiet vira-gre.service 2>/dev/null; then
            print_success "Service: ${GREEN}${BOLD}● ACTIVE${NC}"
        else
            print_error "Service: ${RED}${BOLD}● INACTIVE${NC}"
            local svc_status
            svc_status=$(systemctl status vira-gre.service 2>/dev/null | grep "Active:" | head -1)
            [[ -n "$svc_status" ]] && echo -e "    ${DIM}    $svc_status${NC}"
        fi

        if systemctl is-enabled --quiet vira-gre.service 2>/dev/null; then
            print_success "Boot: ${GREEN}ENABLED${NC}"
        else
            print_warning "Boot: ${YELLOW}DISABLED${NC}"
        fi
    else
        print_error "Service file not found"
    fi
    echo ""

    # ═══ 5. IP FORWARDING & NAT ═══
    echo -e "    ${G2}━━━ 5. IP FORWARDING & NAT ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    [[ "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" == "1" ]] && \
        print_success "IP Forward: ${GREEN}ENABLED${NC}" || \
        print_error "IP Forward: ${RED}DISABLED${NC}"

    if iptables -t nat -C POSTROUTING -j MASQUERADE 2>/dev/null; then
        print_success "MASQUERADE: ${GREEN}Active${NC}"
    else
        print_error "MASQUERADE: ${RED}Missing${NC}"
    fi

    local pre_count
    pre_count=$(iptables -t nat -L PREROUTING -n 2>/dev/null | tail -n +3 | wc -l)
    print_info "PREROUTING rules: ${CYAN}${pre_count}${NC}"

    if ((pre_count > 0)); then
        iptables -t nat -L PREROUTING -n 2>/dev/null | tail -n +3 | while read line; do
            echo -e "    ${DIM}      → $line${NC}"
        done
    fi
    echo ""

    # ═══ 6. PING TESTS ═══
    echo -e "    ${G2}━━━ 6. CONNECTIVITY TESTS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local local_priv="" remote_priv="" current_role=""

    if $config_loaded; then
        current_role="$saved_role"
        if [[ "$saved_role" == "IRAN" ]]; then
            local_priv="$saved_iran_priv"
            remote_priv="$saved_kharej_priv"
        else
            local_priv="$saved_kharej_priv"
            remote_priv="$saved_iran_priv"
        fi
    else
        # Try to detect from script
        if [[ -f "$TUNNEL_SCRIPT" ]]; then
            local_priv=$(grep "ip addr add" "$TUNNEL_SCRIPT" 2>/dev/null | awk '{print $4}' | cut -d'/' -f1)
            if [[ -n "$local_priv" ]]; then
                local net=$(echo "$local_priv" | cut -d'.' -f1-3)
                local last=$(echo "$local_priv" | cut -d'.' -f4)
                [[ "$last" == "1" ]] && remote_priv="${net}.2" && current_role="IRAN"
                [[ "$last" == "2" ]] && remote_priv="${net}.1" && current_role="KHAREJ"
            fi
        fi
    fi

    if [[ -n "$local_priv" ]]; then
        # TEST 1: Local self-ping
        echo -e "    ${G6}${BOLD}▸ TEST 1: Local Self-Ping (${current_role})${NC}"
        echo ""
        animated_ping "$local_priv" "LOCAL → ${local_priv} (Self)"

        # TEST 2: Remote tunnel ping
        echo -e "    ${G6}${BOLD}▸ TEST 2: Remote Tunnel Ping${NC}"
        echo ""
        if [[ "$current_role" == "IRAN" ]]; then
            animated_ping "$remote_priv" "IRAN (${local_priv}) → KHAREJ (${remote_priv})"
        else
            animated_ping "$remote_priv" "KHAREJ (${local_priv}) → IRAN (${remote_priv})"
        fi

        # TEST 3: Remote public IP
        if $config_loaded; then
            local remote_pub=""
            [[ "$saved_role" == "IRAN" ]] && remote_pub="$saved_kharej_ip" || remote_pub="$saved_iran_ip"

            if [[ -n "$remote_pub" ]]; then
                echo -e "    ${G6}${BOLD}▸ TEST 3: Remote Public IP${NC}"
                echo ""
                animated_ping "$remote_pub" "Public → ${remote_pub}"
            fi
        fi

        # TEST 4: Internet
        echo -e "    ${G6}${BOLD}▸ TEST 4: Internet Connectivity${NC}"
        echo ""
        animated_ping "8.8.8.8" "Internet → 8.8.8.8 (Google DNS)"
    else
        print_warning "Cannot determine tunnel IPs"
        echo ""
        echo -e "    ${G6}${BOLD}▸ Internet Test Only${NC}"
        echo ""
        animated_ping "8.8.8.8" "Internet → 8.8.8.8"
    fi

    # ═══ 7. HEALTH SCORE ═══
    echo -e "    ${G2}━━━ 7. HEALTH SCORE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local total=0 passed=0

    # Check 1: GRE module
    total=$((total+1))
    if lsmod | grep -q "ip_gre"; then
        passed=$((passed+1))
        echo -e "    ${GREEN}✔${NC} GRE Module           ${GREEN}PASS${NC}"
    else
        echo -e "    ${RED}✘${NC} GRE Module           ${RED}FAIL${NC}"
    fi

    # Check 2: Tunnel exists
    total=$((total+1))
    if $tunnel_exists; then
        passed=$((passed+1))
        echo -e "    ${GREEN}✔${NC} Tunnel Interface     ${GREEN}PASS${NC}"
    else
        echo -e "    ${RED}✘${NC} Tunnel Interface     ${RED}FAIL${NC}"
    fi

    # Check 3: Service
    total=$((total+1))
    if systemctl is-active --quiet vira-gre.service 2>/dev/null; then
        passed=$((passed+1))
        echo -e "    ${GREEN}✔${NC} Service Active       ${GREEN}PASS${NC}"
    else
        echo -e "    ${RED}✘${NC} Service Active       ${RED}FAIL${NC}"
    fi

    # Check 4: IP Forward
    total=$((total+1))
    if [[ "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" == "1" ]]; then
        passed=$((passed+1))
        echo -e "    ${GREEN}✔${NC} IP Forwarding        ${GREEN}PASS${NC}"
    else
        echo -e "    ${RED}✘${NC} IP Forwarding        ${RED}FAIL${NC}"
    fi

    # Check 5: MASQUERADE
    total=$((total+1))
    if iptables -t nat -C POSTROUTING -j MASQUERADE 2>/dev/null; then
        passed=$((passed+1))
        echo -e "    ${GREEN}✔${NC} MASQUERADE           ${GREEN}PASS${NC}"
    else
        echo -e "    ${RED}✘${NC} MASQUERADE           ${RED}FAIL${NC}"
    fi

    # Check 6: Local ping
    total=$((total+1))
    if [[ -n "$local_priv" ]] && ping -c 1 -W 2 "$local_priv" > /dev/null 2>&1; then
        passed=$((passed+1))
        echo -e "    ${GREEN}✔${NC} Local Tunnel Ping    ${GREEN}PASS${NC}"
    else
        echo -e "    ${RED}✘${NC} Local Tunnel Ping    ${RED}FAIL${NC}"
    fi

    # Check 7: Remote ping
    total=$((total+1))
    if [[ -n "$remote_priv" ]] && ping -c 1 -W 3 "$remote_priv" > /dev/null 2>&1; then
        passed=$((passed+1))
        echo -e "    ${GREEN}✔${NC} Remote Tunnel Ping   ${GREEN}PASS${NC}"
    else
        echo -e "    ${RED}✘${NC} Remote Tunnel Ping   ${RED}FAIL${NC}"
    fi

    echo ""

    local pct=$((passed * 100 / total))
    local health_clr="${RED}" health_txt="CRITICAL" health_bar=""

    if ((pct >= 100)); then
        health_clr="${GREEN}"; health_txt="PERFECT"
        health_bar="${GREEN}██████████████████████████████${NC}"
    elif ((pct >= 85)); then
        health_clr="${GREEN}"; health_txt="HEALTHY"
        health_bar="${GREEN}████████████████████████${NC}${DIM}██████${NC}"
    elif ((pct >= 70)); then
        health_clr="${YELLOW}"; health_txt="GOOD"
        health_bar="${YELLOW}██████████████████${NC}${DIM}████████████${NC}"
    elif ((pct >= 50)); then
        health_clr="${YELLOW}"; health_txt="DEGRADED"
        health_bar="${YELLOW}████████████${NC}${DIM}██████████████████${NC}"
    else
        health_clr="${RED}"; health_txt="CRITICAL"
        health_bar="${RED}██████${NC}${DIM}████████████████████████${NC}"
    fi

    echo -e "    ${G3}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "    ${G3}║${NC}                                                      ${G3}║${NC}"
    echo -e "    ${G3}║${NC}  Score: ${health_clr}${BOLD}${passed}/${total}${NC} passed ${health_clr}(${pct}%)${NC}                          ${G3}║${NC}"
    echo -e "    ${G3}║${NC}  [${health_bar}]  ${G3}║${NC}"
    echo -e "    ${G3}║${NC}  Status: ${health_clr}${BOLD}⬤ ${health_txt}${NC}                                    ${G3}║${NC}"
    echo -e "    ${G3}║${NC}                                                      ${G3}║${NC}"
    echo -e "    ${G3}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -ne "    ${G2}❯${NC} ${WHITE}Press Enter to return to menu...${NC}"
    read
}

# ──────────────────── RESTART ────────────────────

restart_tunnel() {
    clear_screen
    show_logo

    echo -e "${G3}    ┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${G3}    │${NC}  ${G1}🔄${NC} ${WHITE}${BOLD}RESTARTING TUNNEL${NC}                                           ${G3}│${NC}"
    echo -e "${G3}    └──────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    if [[ ! -f "$TUNNEL_SCRIPT" ]]; then
        print_error "Tunnel script not found at ${TUNNEL_SCRIPT}"
        print_info "Please install the tunnel first"
        echo ""
        echo -ne "    ${G2}❯${NC} ${WHITE}Press Enter...${NC}"
        read
        return
    fi

    # Ensure GRE module
    print_step "1/4" "Loading GRE module..."
    ensure_gre_module
    print_success "GRE module ready"

    # Stop
    print_step "2/4" "Stopping tunnel..."
    systemctl stop vira-gre.service 2>/dev/null || true
    ip tunnel del ${TUNNEL_NAME} 2>/dev/null || true
    ip link del ${TUNNEL_NAME} 2>/dev/null || true
    sleep 1
    print_success "Tunnel stopped"

    # Start by running script directly
    print_step "3/4" "Starting tunnel..."
    local output
    output=$(bash "$TUNNEL_SCRIPT" 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        print_success "Tunnel script executed successfully"
    else
        print_error "Tunnel script failed (exit code: $exit_code)"
        echo -e "    ${DIM}$output${NC}"
    fi

    # Also restart service
    systemctl restart vira-gre.service 2>/dev/null || true

    # Verify
    print_step "4/4" "Verifying..."
    sleep 1

    if ip link show ${TUNNEL_NAME} 2>/dev/null | grep -q "UP\|UNKNOWN"; then
        local tun_ip
        tun_ip=$(ip addr show ${TUNNEL_NAME} 2>/dev/null | grep -oP 'inet \K[0-9.]+')
        print_success "${GREEN}${BOLD}Tunnel is UP!${NC} IP: ${CYAN}${tun_ip}${NC}"
    else
        print_error "Tunnel interface not found after restart"
        echo ""
        print_info "Debug info:"
        ip tunnel show 2>/dev/null | while read l; do echo -e "    ${DIM}  $l${NC}"; done
        echo ""
        journalctl -u vira-gre.service --no-pager -n 5 2>/dev/null | while read l; do
            echo -e "    ${DIM}  $l${NC}"
        done
    fi

    echo ""

    # Quick ping test
    if load_config; then
        local test_ip=""
        [[ "$ROLE" == "IRAN" ]] && test_ip="$KHAREJ_PRIVATE_IP" || test_ip="$IRAN_PRIVATE_IP"
        local my_ip=""
        [[ "$ROLE" == "IRAN" ]] && my_ip="$IRAN_PRIVATE_IP" || my_ip="$KHAREJ_PRIVATE_IP"

        if [[ -n "$my_ip" ]]; then
            echo -e "    ${G6}${BOLD}▸ Local Test${NC}"
            echo ""
            animated_ping "$my_ip" "Local Self-Ping"
        fi

        if [[ -n "$test_ip" ]]; then
            echo -e "    ${G6}${BOLD}▸ Remote Test${NC}"
            echo ""
            animated_ping "$test_ip" "Remote Tunnel Endpoint"
        fi
    fi

    echo -ne "    ${G2}❯${NC} ${WHITE}Press Enter to return to menu...${NC}"
    read
}

# ──────────────────── UNINSTALL ────────────────────

uninstall_tunnel() {
    clear_screen
    show_logo

    echo -e "${RED}    ┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${RED}    │${NC}  ${RED}⚠${NC}  ${WHITE}${BOLD}UNINSTALL VIRA TUNNEL${NC}                                      ${RED}│${NC}"
    echo -e "${RED}    └──────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    print_warning "This removes ALL VIRA tunnel configurations!"
    echo ""
    echo -ne "    ${RED}❯${NC} ${WHITE}Type '${RED}YES${NC}' to confirm: ${NC}"
    read confirm
    [[ "$confirm" != "YES" ]] && { print_info "Cancelled."; echo -ne "\n    Press Enter..."; read; return; }

    echo ""

    print_step "1/6" "Stopping service..."
    systemctl stop vira-gre.service 2>/dev/null || true
    systemctl disable vira-gre.service 2>/dev/null || true
    print_success "Service stopped"

    print_step "2/6" "Removing tunnel interface..."
    ip tunnel del ${TUNNEL_NAME} 2>/dev/null || true
    ip link del ${TUNNEL_NAME} 2>/dev/null || true
    print_success "Interface removed"

    print_step "3/6" "Removing files..."
    rm -f "$TUNNEL_SCRIPT"
    rm -f "$SERVICE_FILE"
    rm -rf "$CONFIG_DIR"
    rm -f /etc/modules-load.d/gre.conf
    systemctl daemon-reload
    print_success "Files removed"

    print_step "4/6" "Cleaning iptables..."
    iptables -t nat -F PREROUTING 2>/dev/null || true
    iptables -t nat -F POSTROUTING 2>/dev/null || true
    iptables -t nat -A POSTROUTING -j MASQUERADE 2>/dev/null || true
    netfilter-persistent save > /dev/null 2>&1 || true
    print_success "NAT rules cleaned"

    print_step "5/6" "Unloading module..."
    rmmod ip_gre 2>/dev/null || true
    print_success "GRE module unloaded"

    print_step "6/6" "Verifying..."
    ! ip tunnel show 2>/dev/null | grep -q "${TUNNEL_NAME}" && print_success "Tunnel gone"
    [[ ! -f "$SERVICE_FILE" ]] && print_success "Service gone"
    [[ ! -d "$CONFIG_DIR" ]] && print_success "Config gone"

    echo ""
    echo -e "${GREEN}    ╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}    ║${NC}  ${GREEN}✅ VIRA TUNNEL uninstalled successfully!${NC}                     ${GREEN}║${NC}"
    echo -e "${GREEN}    ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -ne "    ${G2}❯${NC} ${WHITE}Press Enter...${NC}"
    read
}

# ──────────────────── MAIN ────────────────────

main() {
    check_root

    while true; do
        show_main_menu
        read choice

        case $choice in
            1) setup_iran ;;
            2) setup_kharej ;;
            3) check_status ;;
            4) restart_tunnel ;;
            5) uninstall_tunnel ;;
            0)
                clear_screen
                echo -e "${G3}    ╔══════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${G3}    ║${NC}  ${G2}★${NC} ${WHITE}Thank you for using ${G1}VIRA TUNNEL${NC}${WHITE}!${NC}                          ${G3}║${NC}"
                echo -e "${G3}    ║${NC}  ${DIM}  Secure connections, powered by VIRA.${NC}                      ${G3}║${NC}"
                echo -e "${G3}    ╚══════════════════════════════════════════════════════════════╝${NC}"
                echo ""
                exit 0
                ;;
            *) print_error "Invalid option!"; sleep 1 ;;
        esac
    done
}

main "$@"
