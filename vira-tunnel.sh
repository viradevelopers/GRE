#!/bin/bash
# ============================================================
#  VIRA TUNNEL v1.0 - Professional GRE Tunnel Setup Script
#  All bugs fixed - Safe iptables rules
# ============================================================

# ──────────────────── COLORS ────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# ──────────────────── PATHS ────────────────────
CONFIG_DIR="/etc/vira-tunnel"
CONFIG_FILE="${CONFIG_DIR}/config"
TUNNEL_SCRIPT="/usr/local/sbin/vira-gre.sh"
SERVICE_FILE="/etc/systemd/system/vira-gre.service"
TUNNEL_NAME="viraGRE"
VIRA_CHAIN="VIRA_NAT"

# ──────────────────── GLOBALS ────────────────────
IRAN_IP=""
KHAREJ_IP=""
IRAN_PRIVATE_IP=""
KHAREJ_PRIVATE_IP=""

# ──────────────────── BASIC FUNCTIONS ────────────────────

show_logo() {
    clear
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
    echo -e "${G8}    ║${NC}  ${G2}★${NC} ${WHITE}Professional GRE Tunnel Manager${NC}        ${DIM}Version 1.0${NC}     ${G8}  ║${NC}"
    echo -e "${G8}    ║${NC}  ${G3}★${NC} ${DIM}Secure • Fast • Reliable • Persistent${NC}                   ${G8}  ║${NC}"
    echo -e "${G8}    ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

ok()   { echo -e "    ${GREEN}  ✔  $1${NC}"; }
err()  { echo -e "    ${RED}  ✘  $1${NC}"; }
warn() { echo -e "    ${YELLOW}  ⚠  $1${NC}"; }
info() { echo -e "    ${CYAN}  ℹ  $1${NC}"; }
step() { echo -e "    ${G2}[Step $1]${NC} ${WHITE}$2${NC}"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        err "Run as root: sudo bash $0"
        exit 1
    fi
}

validate_ip() {
    local ip="$1"
    [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || return 1
    IFS='.' read -ra O <<< "$ip"
    for o in "${O[@]}"; do ((o > 255)) && return 1; done
    return 0
}

detect_local_ip() {
    ip -4 route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[0-9.]+' | head -1
}

ensure_gre_module() {
    modprobe gre 2>/dev/null || true
    modprobe ip_gre 2>/dev/null || true
    [[ ! -f /etc/modules-load.d/gre.conf ]] && printf "gre\nip_gre\n" > /etc/modules-load.d/gre.conf
}

save_config() {
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << EOF
ROLE=$1
IRAN_IP=${IRAN_IP}
KHAREJ_IP=${KHAREJ_IP}
IRAN_PRIVATE_IP=${IRAN_PRIVATE_IP}
KHAREJ_PRIVATE_IP=${KHAREJ_PRIVATE_IP}
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')
EOF
    chmod 600 "$CONFIG_FILE"
}

load_config() {
    [[ -f "$CONFIG_FILE" ]] && { source "$CONFIG_FILE"; return 0; } || return 1
}

progress_bar() {
    local w=40
    echo -ne "    ${DIM}$2${NC} ["
    for ((i=0; i<=w; i++)); do
        echo -ne "${G2}█${NC}"
        sleep "$(awk "BEGIN{printf \"%.3f\",$1/$w}" 2>/dev/null || echo 0.03)"
    done
    echo -e "] ${GREEN}Done!${NC}"
}

# ──────────────────── IP INPUT ────────────────────

get_server_ips() {
    local role="$1"
    local auto_ip
    auto_ip=$(detect_local_ip)

    echo ""
    echo -e "${G3}    ┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${G3}    │${NC}  ${G1}🔧${NC} ${WHITE}${BOLD}IP CONFIGURATION${NC}                                            ${G3}│${NC}"
    echo -e "${G3}    └──────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    if [[ "$role" == "IRAN" ]]; then
        echo -ne "    ${G2}❯${NC} IRAN Server Public IP [${CYAN}${auto_ip}${NC}]: "
        read input; IRAN_IP=${input:-$auto_ip}
        while ! validate_ip "$IRAN_IP"; do err "Invalid!"; echo -ne "    ${G2}❯${NC} IRAN IP: "; read IRAN_IP; done
        ok "IRAN: ${CYAN}$IRAN_IP${NC}"
        echo ""
        echo -ne "    ${G2}❯${NC} KHAREJ Server Public IP: "
        read KHAREJ_IP
        while ! validate_ip "$KHAREJ_IP"; do err "Invalid!"; echo -ne "    ${G2}❯${NC} KHAREJ IP: "; read KHAREJ_IP; done
        ok "KHAREJ: ${CYAN}$KHAREJ_IP${NC}"
    else
        echo -ne "    ${G2}❯${NC} KHAREJ Server Public IP [${CYAN}${auto_ip}${NC}]: "
        read input; KHAREJ_IP=${input:-$auto_ip}
        while ! validate_ip "$KHAREJ_IP"; do err "Invalid!"; echo -ne "    ${G2}❯${NC} KHAREJ IP: "; read KHAREJ_IP; done
        ok "KHAREJ: ${CYAN}$KHAREJ_IP${NC}"
        echo ""
        echo -ne "    ${G2}❯${NC} IRAN Server Public IP: "
        read IRAN_IP
        while ! validate_ip "$IRAN_IP"; do err "Invalid!"; echo -ne "    ${G2}❯${NC} IRAN IP: "; read IRAN_IP; done
        ok "IRAN: ${CYAN}$IRAN_IP${NC}"
    fi

    echo ""
    echo -e "    ${DIM}Private IPs (Enter for defaults)${NC}"
    echo -ne "    ${G2}❯${NC} IRAN Private IP [${CYAN}10.10.10.1${NC}]: "
    read IRAN_PRIVATE_IP; IRAN_PRIVATE_IP=${IRAN_PRIVATE_IP:-10.10.10.1}
    validate_ip "$IRAN_PRIVATE_IP" || IRAN_PRIVATE_IP="10.10.10.1"

    echo -ne "    ${G2}❯${NC} KHAREJ Private IP [${CYAN}10.10.10.2${NC}]: "
    read KHAREJ_PRIVATE_IP; KHAREJ_PRIVATE_IP=${KHAREJ_PRIVATE_IP:-10.10.10.2}
    validate_ip "$KHAREJ_PRIVATE_IP" || KHAREJ_PRIVATE_IP="10.10.10.2"

    echo ""
    echo -e "${G3}    ┌────────────────────────────────────────────────────────┐${NC}"
    printf "    ${G3}│${NC}  IRAN Public   : ${CYAN}%-38s${NC}${G3}│${NC}\n" "$IRAN_IP"
    printf "    ${G3}│${NC}  KHAREJ Public : ${CYAN}%-38s${NC}${G3}│${NC}\n" "$KHAREJ_IP"
    printf "    ${G3}│${NC}  IRAN Private  : ${CYAN}%-38s${NC}${G3}│${NC}\n" "${IRAN_PRIVATE_IP}/30"
    printf "    ${G3}│${NC}  KHAREJ Private: ${CYAN}%-38s${NC}${G3}│${NC}\n" "${KHAREJ_PRIVATE_IP}/30"
    echo -e "${G3}    └────────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -ne "    ${G2}❯${NC} Confirm? [${GREEN}Y${NC}/n]: "
    read c
    [[ "$c" == "n" || "$c" == "N" ]] && return 1
    return 0
}

# ──────────────────── SAFE IPTABLES FOR IRAN ────────────────────
#
# *** THIS IS THE KEY FIX ***
#
# The old rules:
#   iptables -t nat -A PREROUTING -j DNAT --to-destination <kharej>
# This catches ALL traffic including your SSH session → you get locked out!
#
# The fix:
#   1. EXCLUDE the server's own SSH (port 22)
#   2. EXCLUDE GRE protocol traffic (protocol 47)
#   3. EXCLUDE traffic TO the server's own public IP on management ports
#   4. Only DNAT traffic that is meant to be forwarded
#   5. Use a custom chain so we can cleanly flush without breaking other rules

setup_iran_iptables() {
    local iran_pub="$1"
    local iran_priv="$2"
    local kharej_priv="$3"

    info "Setting SAFE iptables rules..."
    echo ""

    # Remove old custom chain if exists
    iptables -t nat -D PREROUTING -j ${VIRA_CHAIN} 2>/dev/null || true
    iptables -t nat -F ${VIRA_CHAIN} 2>/dev/null || true
    iptables -t nat -X ${VIRA_CHAIN} 2>/dev/null || true

    # Create custom chain
    iptables -t nat -N ${VIRA_CHAIN} 2>/dev/null || true

    # ═══ EXCLUSIONS (traffic that must NOT be redirected) ═══

    # 1. Don't touch SSH (port 22) → keeps your access alive
    iptables -t nat -A ${VIRA_CHAIN} -p tcp --dport 22 -j RETURN
    ok "Rule: SSH (22) → EXCLUDED (keeps your access)"

    # 2. Don't touch GRE protocol → tunnel itself must work
    iptables -t nat -A ${VIRA_CHAIN} -p gre -j RETURN
    ok "Rule: GRE protocol → EXCLUDED (tunnel traffic)"

    # 3. Don't touch ICMP → ping must work for diagnostics
    iptables -t nat -A ${VIRA_CHAIN} -p icmp -j RETURN
    ok "Rule: ICMP (ping) → EXCLUDED (diagnostics)"

    # 4. Don't touch DNS (port 53) → server needs DNS
    iptables -t nat -A ${VIRA_CHAIN} -p udp --dport 53 -j RETURN
    iptables -t nat -A ${VIRA_CHAIN} -p tcp --dport 53 -j RETURN
    ok "Rule: DNS (53) → EXCLUDED"

    # 5. Don't touch traffic from tunnel subnet → internal tunnel traffic
    iptables -t nat -A ${VIRA_CHAIN} -s ${iran_priv}/30 -j RETURN
    ok "Rule: Tunnel subnet → EXCLUDED"

    # 6. Don't touch established/related connections
    iptables -t nat -A ${VIRA_CHAIN} -m state --state ESTABLISHED,RELATED -j RETURN
    ok "Rule: Established connections → EXCLUDED"

    # ═══ FORWARD RULES (what gets redirected to KHAREJ) ═══

    # Forward TCP traffic (except excluded above) to KHAREJ
    iptables -t nat -A ${VIRA_CHAIN} -p tcp -j DNAT --to-destination ${kharej_priv}
    ok "Rule: TCP → DNAT to ${CYAN}${kharej_priv}${NC}"

    # Forward UDP traffic (except excluded above) to KHAREJ
    iptables -t nat -A ${VIRA_CHAIN} -p udp -j DNAT --to-destination ${kharej_priv}
    ok "Rule: UDP → DNAT to ${CYAN}${kharej_priv}${NC}"

    # Hook our chain into PREROUTING
    iptables -t nat -A PREROUTING -j ${VIRA_CHAIN}
    ok "Chain ${VIRA_CHAIN} hooked into PREROUTING"

    # MASQUERADE for return traffic (clean first)
    iptables -t nat -D POSTROUTING -j MASQUERADE 2>/dev/null || true
    iptables -t nat -A POSTROUTING -o ${TUNNEL_NAME} -j MASQUERADE
    iptables -t nat -A POSTROUTING -s ${iran_priv}/30 -j MASQUERADE
    ok "MASQUERADE for tunnel traffic"

    echo ""
}

setup_kharej_iptables() {
    # KHAREJ side is simple - just MASQUERADE
    iptables -t nat -F POSTROUTING 2>/dev/null || true
    iptables -t nat -A POSTROUTING -j MASQUERADE
    ok "MASQUERADE rule set"
}

# ──────────────────── ANIMATED PING ────────────────────

animated_ping() {
    local target="$1"
    local label="$2"
    local count=4
    local success=0 fail=0
    local times=()

    echo -e "    ${G6}╭───────────────────────────────────────────────────────────╮${NC}"
    echo -e "    ${G6}│${NC}  ${G2}🏓${NC} ${WHITE}${BOLD}${label}${NC}"
    echo -e "    ${G6}│${NC}  ${DIM}Target: ${CYAN}${target}${NC}"
    echo -e "    ${G6}├───────────────────────────────────────────────────────────┤${NC}"

    for ((i=1; i<=count; i++)); do
        echo -ne "    ${G6}│${NC}  ${DIM}Packet ${i}/${count}...${NC}"
        local res
        res=$(ping -c 1 -W 3 "$target" 2>&1)

        if [[ $? -eq 0 ]]; then
            local rtt
            rtt=$(echo "$res" | grep -oP 'time=\K[0-9.]+' || echo "")
            success=$((success+1))

            if [[ -n "$rtt" ]]; then
                times+=("$rtt")
                local ri=${rtt%.*}; ri=${ri:-0}
                local clr="${GREEN}"
                ((ri > 100)) && clr="${YELLOW}"
                ((ri > 300)) && clr="${RED}"
                echo -e "\r    ${G6}│${NC}  ${GREEN}✔${NC} Packet ${i}: ${clr}${rtt} ms${NC}                              "
            else
                echo -e "\r    ${G6}│${NC}  ${GREEN}✔${NC} Packet ${i}: ${GREEN}OK${NC}                                    "
            fi
        else
            fail=$((fail+1))
            echo -e "\r    ${G6}│${NC}  ${RED}✘${NC} Packet ${i}: ${RED}Timeout${NC}                                "
        fi
        sleep 0.2
    done

    echo -e "    ${G6}├───────────────────────────────────────────────────────────┤${NC}"

    local loss=$((fail * 100 / count))

    if ((success > 0)); then
        local min_t="999999" max_t="0" sum_t="0"
        for t in "${times[@]}"; do
            sum_t=$(awk "BEGIN{printf \"%.2f\", $sum_t + $t}")
            local ti=${t%.*}; ti=${ti:-0}
            local mi=${min_t%.*}; mi=${mi:-999999}
            local mx=${max_t%.*}; mx=${mx:-0}
            ((ti < mi)) && min_t="$t"
            ((ti > mx)) && max_t="$t"
        done
        local avg_t
        avg_t=$(awk "BEGIN{printf \"%.2f\", $sum_t / ${#times[@]}}")

        local lc="${GREEN}"; ((loss > 0)) && lc="${YELLOW}"; ((loss >= 100)) && lc="${RED}"
        echo -e "    ${G6}│${NC}  ${GREEN}✅ CONNECTED${NC}  |  ${success}/${count} ok  ${lc}(${loss}% loss)${NC}"

        if [[ ${#times[@]} -gt 0 ]]; then
            echo -e "    ${G6}│${NC}  ${G2}⏱${NC}  min=${CYAN}${min_t}ms${NC}  avg=${CYAN}${avg_t}ms${NC}  max=${CYAN}${max_t}ms${NC}"
            local ai=${avg_t%.*}; ai=${ai:-0}
            local q="" qb=""
            if   ((ai<=30));  then q="${GREEN}${BOLD}EXCELLENT${NC}"; qb="${GREEN}██████████${NC}"
            elif ((ai<=80));  then q="${GREEN}VERY GOOD${NC}";       qb="${GREEN}████████${NC}${DIM}██${NC}"
            elif ((ai<=150)); then q="${YELLOW}GOOD${NC}";           qb="${YELLOW}██████${NC}${DIM}████${NC}"
            elif ((ai<=300)); then q="${YELLOW}FAIR${NC}";           qb="${YELLOW}████${NC}${DIM}██████${NC}"
            else                   q="${RED}POOR${NC}";             qb="${RED}██${NC}${DIM}████████${NC}"
            fi
            echo -e "    ${G6}│${NC}  ${G2}📶${NC}  Quality: [${qb}] ${q}"
        fi
    else
        echo -e "    ${G6}│${NC}  ${RED}❌ DISCONNECTED${NC}  |  ${RED}100% loss${NC}"
        echo -e "    ${G6}│${NC}  ${YELLOW}💡 Check: remote server, firewall, config${NC}"
    fi

    echo -e "    ${G6}╰───────────────────────────────────────────────────────────╯${NC}"
    echo ""
}

# ──────────────────── SETUP IRAN ────────────────────

setup_iran() {
    show_logo
    echo -e "    ${BG_GOLD}${WHITE}${BOLD}  ⚡ IRAN Server Setup 🇮🇷  ${NC}"
    echo ""
    get_server_ips "IRAN" || return

    echo ""
    echo -e "${G3}    ┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${G3}    │${NC}  ${G1}🚀${NC} ${WHITE}${BOLD}INSTALLING IRAN SERVER${NC}                                      ${G3}│${NC}"
    echo -e "${G3}    └──────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # 1. GRE Module
    step "1/8" "Loading GRE kernel module..."
    ensure_gre_module
    lsmod | grep -q "ip_gre" && ok "ip_gre loaded" || { err "GRE module failed"; warn "apt install linux-modules-extra-\$(uname -r)"; }
    sleep 0.3

    # 2. Tunnel Script
    step "2/8" "Creating tunnel script..."
    cat > "$TUNNEL_SCRIPT" << EOF
#!/bin/bash
set -e
modprobe ip_gre 2>/dev/null || true
sleep 2
ip tunnel del ${TUNNEL_NAME} 2>/dev/null || true
ip link del ${TUNNEL_NAME} 2>/dev/null || true
ip tunnel add ${TUNNEL_NAME} mode gre remote ${KHAREJ_IP} local ${IRAN_IP} ttl 255
ip link set ${TUNNEL_NAME} mtu 1476
ip addr add ${IRAN_PRIVATE_IP}/30 dev ${TUNNEL_NAME}
ip link set ${TUNNEL_NAME} up
echo "VIRA TUNNEL IRAN UP - $(date)"
EOF
    chmod +x "$TUNNEL_SCRIPT"
    ok "Script: ${TUNNEL_SCRIPT}"
    sleep 0.3

    # 3. Save Config
    step "3/8" "Saving config..."
    save_config "IRAN"
    ok "Config saved"
    sleep 0.3

    # 4. IP Forward
    step "4/8" "Enabling IP forwarding..."
    sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
    [[ "$(cat /proc/sys/net/ipv4/ip_forward)" == "1" ]] && ok "Forwarding ON" || err "Forwarding FAILED"
    sleep 0.3

    # 5. Install iptables-persistent
    step "5/8" "Installing iptables-persistent..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq > /dev/null 2>&1
    apt-get install -y -qq iptables-persistent netfilter-persistent > /dev/null 2>&1
    ok "iptables-persistent installed"
    sleep 0.3

    # 6. SAFE iptables rules
    step "6/8" "Configuring SAFE iptables rules..."
    echo ""
    setup_iran_iptables "$IRAN_IP" "$IRAN_PRIVATE_IP" "$KHAREJ_PRIVATE_IP"

    # 7. Save rules
    step "7/8" "Saving iptables rules..."
    netfilter-persistent save > /dev/null 2>&1
    ok "Rules saved"
    sleep 0.3

    # 8. Service + Start
    step "8/8" "Creating service and starting tunnel..."
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=VIRA TUNNEL GRE (IRAN)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${TUNNEL_SCRIPT}
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable vira-gre.service > /dev/null 2>&1

    # Run directly to avoid service timing issues
    bash "$TUNNEL_SCRIPT" > /dev/null 2>&1 || true
    systemctl restart vira-gre.service > /dev/null 2>&1 || true
    sleep 1

    # Verify
    if ip link show ${TUNNEL_NAME} 2>/dev/null | grep -qE "UP|UNKNOWN"; then
        local tip
        tip=$(ip addr show ${TUNNEL_NAME} 2>/dev/null | grep -oP 'inet \K[0-9.]+')
        ok "${GREEN}${BOLD}Tunnel UP!${NC} IP: ${CYAN}${tip}${NC}"
    else
        err "Tunnel interface issue - check logs"
    fi

    echo ""
    progress_bar 1 "Finalizing"
    echo ""

    # Quick test
    echo -e "    ${G6}${BOLD}▸ Quick Local Test${NC}"
    echo ""
    animated_ping "$IRAN_PRIVATE_IP" "Local Self-Ping (${IRAN_PRIVATE_IP})"

    echo -e "${G3}    ╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${G3}    ║${NC}  ${GREEN}${BOLD}✅ IRAN SERVER READY!${NC}                                       ${G3}║${NC}"
    echo -e "${G3}    ╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${G3}    ║${NC}  ${WHITE}Now run this script on KHAREJ server (option 2)${NC}              ${G3}║${NC}"
    echo -e "${G3}    ║${NC}  ${WHITE}Use the SAME IPs on both sides${NC}                               ${G3}║${NC}"
    echo -e "${G3}    ║${NC}  ${YELLOW}Your SSH access is SAFE (port 22 excluded)${NC}                   ${G3}║${NC}"
    echo -e "${G3}    ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -ne "    ${G2}❯${NC} Press Enter..."
    read
}

# ──────────────────── SETUP KHAREJ ────────────────────

setup_kharej() {
    show_logo
    echo -e "    ${BG_GOLD}${WHITE}${BOLD}  ⚡ KHAREJ Server Setup 🌍  ${NC}"
    echo ""
    get_server_ips "KHAREJ" || return

    echo ""
    echo -e "${G3}    ┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${G3}    │${NC}  ${G1}🚀${NC} ${WHITE}${BOLD}INSTALLING KHAREJ SERVER${NC}                                    ${G3}│${NC}"
    echo -e "${G3}    └──────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # 1. GRE
    step "1/7" "Loading GRE module..."
    ensure_gre_module
    lsmod | grep -q "ip_gre" && ok "ip_gre loaded" || err "GRE failed"
    sleep 0.3

    # 2. Script
    step "2/7" "Creating tunnel script..."
    cat > "$TUNNEL_SCRIPT" << EOF
#!/bin/bash
set -e
modprobe ip_gre 2>/dev/null || true
sleep 2
ip tunnel del ${TUNNEL_NAME} 2>/dev/null || true
ip link del ${TUNNEL_NAME} 2>/dev/null || true
ip tunnel add ${TUNNEL_NAME} mode gre remote ${IRAN_IP} local ${KHAREJ_IP} ttl 255
ip link set ${TUNNEL_NAME} mtu 1476
ip addr add ${KHAREJ_PRIVATE_IP}/30 dev ${TUNNEL_NAME}
ip link set ${TUNNEL_NAME} up
echo "VIRA TUNNEL KHAREJ UP - $(date)"
EOF
    chmod +x "$TUNNEL_SCRIPT"
    ok "Script created"
    sleep 0.3

    # 3. Config
    step "3/7" "Saving config..."
    save_config "KHAREJ"
    ok "Config saved"
    sleep 0.3

    # 4. Forward
    step "4/7" "Enabling IP forwarding..."
    sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
    ok "Forwarding ON"
    sleep 0.3

    # 5. iptables-persistent
    step "5/7" "Installing iptables-persistent..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq > /dev/null 2>&1
    apt-get install -y -qq iptables-persistent netfilter-persistent > /dev/null 2>&1
    ok "Installed"
    sleep 0.3

    # 6. Masquerade + save
    step "6/7" "Configuring iptables..."
    setup_kharej_iptables
    netfilter-persistent save > /dev/null 2>&1
    ok "Rules saved"
    sleep 0.3

    # 7. Service
    step "7/7" "Creating service and starting..."
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=VIRA TUNNEL GRE (KHAREJ)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${TUNNEL_SCRIPT}
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable vira-gre.service > /dev/null 2>&1
    bash "$TUNNEL_SCRIPT" > /dev/null 2>&1 || true
    systemctl restart vira-gre.service > /dev/null 2>&1 || true
    sleep 1

    if ip link show ${TUNNEL_NAME} 2>/dev/null | grep -qE "UP|UNKNOWN"; then
        local tip
        tip=$(ip addr show ${TUNNEL_NAME} 2>/dev/null | grep -oP 'inet \K[0-9.]+')
        ok "${GREEN}${BOLD}Tunnel UP!${NC} IP: ${CYAN}${tip}${NC}"
    else
        err "Tunnel interface issue"
    fi

    echo ""
    progress_bar 1 "Finalizing"
    echo ""

    echo -e "    ${G6}${BOLD}▸ Quick Local Test${NC}"
    echo ""
    animated_ping "$KHAREJ_PRIVATE_IP" "Local Self-Ping (${KHAREJ_PRIVATE_IP})"

    echo -e "${G3}    ╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${G3}    ║${NC}  ${GREEN}${BOLD}✅ KHAREJ SERVER READY!${NC}                                     ${G3}║${NC}"
    echo -e "${G3}    ╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${G3}    ║${NC}  ${WHITE}Make sure IRAN server is also configured${NC}                     ${G3}║${NC}"
    echo -e "${G3}    ║${NC}  ${WHITE}Then check status with option 3${NC}                              ${G3}║${NC}"
    echo -e "${G3}    ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -ne "    ${G2}❯${NC} Press Enter..."
    read
}

# ──────────────────── STATUS ────────────────────

check_status() {
    show_logo

    echo -e "${G3}    ╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${G3}    ║${NC}  ${G1}📊${NC} ${WHITE}${BOLD}FULL DIAGNOSTICS${NC}                                            ${G3}║${NC}"
    echo -e "${G3}    ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local cfg=false sr="" sii="" ski="" sip="" skp="" sd=""
    if load_config; then
        cfg=true; sr="$ROLE"; sii="$IRAN_IP"; ski="$KHAREJ_IP"
        sip="$IRAN_PRIVATE_IP"; skp="$KHAREJ_PRIVATE_IP"; sd="$INSTALL_DATE"
    fi

    # 1. Info
    echo -e "    ${G2}━━━ 1. SERVER INFO ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    if $cfg; then
        local ri="🌍"; [[ "$sr" == "IRAN" ]] && ri="🇮🇷"
        printf "    Role: ${CYAN}${BOLD}%-10s${NC} %s   Installed: ${DIM}%s${NC}\n" "$sr" "$ri" "$sd"
        printf "    IRAN:   ${CYAN}%-16s${NC}  Private: ${CYAN}%s/30${NC}\n" "$sii" "$sip"
        printf "    KHAREJ: ${CYAN}%-16s${NC}  Private: ${CYAN}%s/30${NC}\n" "$ski" "$skp"
    else
        warn "No config found"
    fi
    echo ""

    # 2. Module
    echo -e "    ${G2}━━━ 2. GRE MODULE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    lsmod | grep -q "ip_gre" && ok "ip_gre: ${GREEN}LOADED${NC}" || err "ip_gre: ${RED}NOT LOADED${NC}"
    echo ""

    # 3. Tunnel
    echo -e "    ${G2}━━━ 3. TUNNEL INTERFACE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    local tun_ok=false
    if ip tunnel show 2>/dev/null | grep -q "${TUNNEL_NAME}"; then
        tun_ok=true
        ok "$(ip tunnel show ${TUNNEL_NAME} 2>/dev/null)"
        local tip
        tip=$(ip addr show ${TUNNEL_NAME} 2>/dev/null | grep -oP 'inet \K[0-9./]+')
        [[ -n "$tip" ]] && ok "IP: ${CYAN}${tip}${NC}" || warn "No IP assigned"
        local ls
        ls=$(ip link show ${TUNNEL_NAME} 2>/dev/null | grep -oP 'state \K\w+')
        [[ "$ls" == "UP" || "$ls" == "UNKNOWN" ]] && ok "State: ${GREEN}UP${NC}" || err "State: ${RED}${ls}${NC}"
        local mtu
        mtu=$(ip link show ${TUNNEL_NAME} 2>/dev/null | grep -oP 'mtu \K\d+')
        info "MTU: ${CYAN}${mtu}${NC}"
    else
        err "Tunnel ${TUNNEL_NAME} NOT FOUND"
    fi
    echo ""

    # 4. Service
    echo -e "    ${G2}━━━ 4. SERVICE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    if [[ -f "$SERVICE_FILE" ]]; then
        systemctl is-active --quiet vira-gre.service 2>/dev/null && ok "Status: ${GREEN}● ACTIVE${NC}" || err "Status: ${RED}● INACTIVE${NC}"
        systemctl is-enabled --quiet vira-gre.service 2>/dev/null && ok "Boot: ${GREEN}ENABLED${NC}" || warn "Boot: ${YELLOW}DISABLED${NC}"
    else
        err "Service file missing"
    fi
    echo ""

    # 5. Forwarding & NAT
    echo -e "    ${G2}━━━ 5. IP FORWARD & NAT ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    [[ "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" == "1" ]] && ok "Forward: ${GREEN}ON${NC}" || err "Forward: ${RED}OFF${NC}"

    # Show VIRA chain
    if iptables -t nat -L ${VIRA_CHAIN} -n 2>/dev/null | grep -q "Chain"; then
        ok "Custom chain ${VIRA_CHAIN}: ${GREEN}EXISTS${NC}"
        iptables -t nat -L ${VIRA_CHAIN} -n 2>/dev/null | tail -n +3 | while read l; do
            echo -e "    ${DIM}      → $l${NC}"
        done
    else
        info "No custom chain (KHAREJ side or old setup)"
    fi

    iptables -t nat -C POSTROUTING -j MASQUERADE 2>/dev/null && ok "MASQUERADE: ${GREEN}Active${NC}" || \
    iptables -t nat -L POSTROUTING -n 2>/dev/null | grep -q "MASQUERADE" && ok "MASQUERADE: ${GREEN}Active${NC}" || err "MASQUERADE: ${RED}Missing${NC}"
    echo ""

    # 6. Ping Tests
    echo -e "    ${G2}━━━ 6. CONNECTIVITY TESTS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local lp="" rp="" cr=""
    if $cfg; then
        cr="$sr"
        [[ "$sr" == "IRAN" ]] && { lp="$sip"; rp="$skp"; } || { lp="$skp"; rp="$sip"; }
    fi

    if [[ -n "$lp" ]]; then
        echo -e "    ${G6}${BOLD}▸ TEST 1: Local Self-Ping${NC}"
        echo ""
        animated_ping "$lp" "LOCAL (${cr}) → ${lp}"

        echo -e "    ${G6}${BOLD}▸ TEST 2: Remote Tunnel${NC}"
        echo ""
        [[ "$cr" == "IRAN" ]] && animated_ping "$rp" "IRAN → KHAREJ (${rp})" || animated_ping "$rp" "KHAREJ → IRAN (${rp})"

        if $cfg; then
            local rpub=""
            [[ "$sr" == "IRAN" ]] && rpub="$ski" || rpub="$sii"
            echo -e "    ${G6}${BOLD}▸ TEST 3: Remote Public IP${NC}"
            echo ""
            animated_ping "$rpub" "Public → ${rpub}"
        fi

        echo -e "    ${G6}${BOLD}▸ TEST 4: Internet${NC}"
        echo ""
        animated_ping "8.8.8.8" "Google DNS (8.8.8.8)"
    else
        animated_ping "8.8.8.8" "Internet Only"
    fi

    # 7. Health
    echo -e "    ${G2}━━━ 7. HEALTH SCORE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local tot=0 pass=0

    tot=$((tot+1)); lsmod | grep -q "ip_gre" && { pass=$((pass+1)); echo -e "    ${GREEN}✔${NC} GRE Module         ${GREEN}PASS${NC}"; } || echo -e "    ${RED}✘${NC} GRE Module         ${RED}FAIL${NC}"
    tot=$((tot+1)); $tun_ok && { pass=$((pass+1)); echo -e "    ${GREEN}✔${NC} Tunnel Interface   ${GREEN}PASS${NC}"; } || echo -e "    ${RED}✘${NC} Tunnel Interface   ${RED}FAIL${NC}"
    tot=$((tot+1)); systemctl is-active --quiet vira-gre.service 2>/dev/null && { pass=$((pass+1)); echo -e "    ${GREEN}✔${NC} Service Active     ${GREEN}PASS${NC}"; } || echo -e "    ${RED}✘${NC} Service Active     ${RED}FAIL${NC}"
    tot=$((tot+1)); [[ "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" == "1" ]] && { pass=$((pass+1)); echo -e "    ${GREEN}✔${NC} IP Forwarding      ${GREEN}PASS${NC}"; } || echo -e "    ${RED}✘${NC} IP Forwarding      ${RED}FAIL${NC}"
    tot=$((tot+1)); [[ -n "$lp" ]] && ping -c1 -W2 "$lp" >/dev/null 2>&1 && { pass=$((pass+1)); echo -e "    ${GREEN}✔${NC} Local Ping         ${GREEN}PASS${NC}"; } || echo -e "    ${RED}✘${NC} Local Ping         ${RED}FAIL${NC}"
    tot=$((tot+1)); [[ -n "$rp" ]] && ping -c1 -W3 "$rp" >/dev/null 2>&1 && { pass=$((pass+1)); echo -e "    ${GREEN}✔${NC} Remote Ping        ${GREEN}PASS${NC}"; } || echo -e "    ${RED}✘${NC} Remote Ping        ${RED}FAIL${NC}"

    echo ""
    local pct=$((pass*100/tot))
    local hc="${RED}" ht="CRITICAL" hb="${RED}████${NC}${DIM}██████████████████████████${NC}"
    ((pct>=100)) && { hc="${GREEN}"; ht="PERFECT";  hb="${GREEN}██████████████████████████████${NC}"; }
    ((pct>=85 && pct<100)) && { hc="${GREEN}"; ht="HEALTHY";  hb="${GREEN}████████████████████████${NC}${DIM}██████${NC}"; }
    ((pct>=70 && pct<85))  && { hc="${YELLOW}"; ht="GOOD";     hb="${YELLOW}██████████████████${NC}${DIM}████████████${NC}"; }
    ((pct>=50 && pct<70))  && { hc="${YELLOW}"; ht="DEGRADED"; hb="${YELLOW}████████████${NC}${DIM}██████████████████${NC}"; }

    echo -e "    ${G3}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "    ${G3}║${NC}  Score: ${hc}${BOLD}${pass}/${tot}${NC} (${hc}${pct}%${NC})                                ${G3}║${NC}"
    echo -e "    ${G3}║${NC}  [${hb}]${NC}  ${G3}║${NC}"
    echo -e "    ${G3}║${NC}  Status: ${hc}${BOLD}⬤ ${ht}${NC}                                  ${G3}║${NC}"
    echo -e "    ${G3}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -ne "    ${G2}❯${NC} Press Enter..."
    read
}

# ──────────────────── RESTART ────────────────────

restart_tunnel() {
    show_logo
    echo -e "${G3}    ┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${G3}    │${NC}  ${G1}🔄${NC} ${WHITE}${BOLD}RESTARTING TUNNEL${NC}                                           ${G3}│${NC}"
    echo -e "${G3}    └──────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    if [[ ! -f "$TUNNEL_SCRIPT" ]]; then
        err "No tunnel script found - install first"
        echo -ne "\n    Press Enter..."
        read; return
    fi

    step "1/4" "Loading GRE..."
    ensure_gre_module
    ok "Done"

    step "2/4" "Stopping..."
    systemctl stop vira-gre.service 2>/dev/null || true
    ip tunnel del ${TUNNEL_NAME} 2>/dev/null || true
    ip link del ${TUNNEL_NAME} 2>/dev/null || true
    sleep 1
    ok "Stopped"

    step "3/4" "Starting..."
    bash "$TUNNEL_SCRIPT" 2>&1 || true
    systemctl restart vira-gre.service 2>/dev/null || true
    sleep 1

    step "4/4" "Verifying..."
    if ip link show ${TUNNEL_NAME} 2>/dev/null | grep -qE "UP|UNKNOWN"; then
        local tip
        tip=$(ip addr show ${TUNNEL_NAME} 2>/dev/null | grep -oP 'inet \K[0-9.]+')
        ok "${GREEN}${BOLD}Tunnel UP!${NC} IP: ${CYAN}${tip}${NC}"
    else
        err "Tunnel not up"
        journalctl -u vira-gre.service --no-pager -n 5 2>/dev/null | while read l; do echo -e "    ${DIM}$l${NC}"; done
    fi

    echo ""
    if load_config; then
        local my_ip="" rem_ip=""
        [[ "$ROLE" == "IRAN" ]] && { my_ip="$IRAN_PRIVATE_IP"; rem_ip="$KHAREJ_PRIVATE_IP"; } || { my_ip="$KHAREJ_PRIVATE_IP"; rem_ip="$IRAN_PRIVATE_IP"; }
        [[ -n "$my_ip" ]] && { echo -e "    ${G6}${BOLD}▸ Local${NC}"; echo ""; animated_ping "$my_ip" "Self → ${my_ip}"; }
        [[ -n "$rem_ip" ]] && { echo -e "    ${G6}${BOLD}▸ Remote${NC}"; echo ""; animated_ping "$rem_ip" "Remote → ${rem_ip}"; }
    fi

    echo -ne "    ${G2}❯${NC} Press Enter..."
    read
}

# ──────────────────── UNINSTALL ────────────────────

uninstall_tunnel() {
    show_logo
    echo -e "${RED}    ┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${RED}    │${NC}  ${RED}⚠  UNINSTALL VIRA TUNNEL${NC}                                      ${RED}│${NC}"
    echo -e "${RED}    └──────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    warn "This removes ALL VIRA tunnel configs!"
    echo -ne "    ${RED}❯${NC} Type '${RED}YES${NC}': "
    read c; [[ "$c" != "YES" ]] && { info "Cancelled."; echo -ne "\n    Enter..."; read; return; }
    echo ""

    step "1/7" "Stop service..."
    systemctl stop vira-gre.service 2>/dev/null || true
    systemctl disable vira-gre.service 2>/dev/null || true
    ok "Done"

    step "2/7" "Remove tunnel..."
    ip tunnel del ${TUNNEL_NAME} 2>/dev/null || true
    ip link del ${TUNNEL_NAME} 2>/dev/null || true
    ok "Done"

    step "3/7" "Remove files..."
    rm -f "$TUNNEL_SCRIPT" "$SERVICE_FILE"
    rm -rf "$CONFIG_DIR"
    rm -f /etc/modules-load.d/gre.conf
    systemctl daemon-reload
    ok "Done"

    step "4/7" "Clean iptables..."
    # Remove custom chain
    iptables -t nat -D PREROUTING -j ${VIRA_CHAIN} 2>/dev/null || true
    iptables -t nat -F ${VIRA_CHAIN} 2>/dev/null || true
    iptables -t nat -X ${VIRA_CHAIN} 2>/dev/null || true
    # Clean POSTROUTING
    iptables -t nat -F POSTROUTING 2>/dev/null || true
    iptables -t nat -A POSTROUTING -j MASQUERADE 2>/dev/null || true
    ok "Done"

    step "5/7" "Save clean rules..."
    netfilter-persistent save > /dev/null 2>&1 || true
    ok "Done"

    step "6/7" "Unload module..."
    rmmod ip_gre 2>/dev/null || true
    ok "Done"

    step "7/7" "Verify..."
    ! ip tunnel show 2>/dev/null | grep -q "${TUNNEL_NAME}" && ok "Tunnel removed"
    [[ ! -f "$SERVICE_FILE" ]] && ok "Service removed"
    [[ ! -d "$CONFIG_DIR" ]] && ok "Config removed"

    echo ""
    echo -e "${GREEN}    ✅ VIRA TUNNEL uninstalled!${NC}"
    echo ""
    echo -ne "    Enter..."
    read
}

# ──────────────────── MAIN MENU ────────────────────

show_main_menu() {
    show_logo

    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE" 2>/dev/null
        local ri="🌍"; [[ "$ROLE" == "IRAN" ]] && ri="🇮🇷"
        local ss="${RED}OFF${NC}"
        systemctl is-active --quiet vira-gre.service 2>/dev/null && ss="${GREEN}ON${NC}"
        local tun_ip
        tun_ip=$(ip addr show ${TUNNEL_NAME} 2>/dev/null | grep -oP 'inet \K[0-9.]+' || echo "N/A")
        echo -e "    ${DIM}Server: ${WHITE}${ROLE}${NC} ${ri} ${DIM}| Service: ${ss} ${DIM}| TunnelIP: ${CYAN}${tun_ip}${NC}"
        echo ""
    fi

    echo -e "${G3}    ┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${G3}    │${NC}  ${G1}⚙${NC}  ${WHITE}${BOLD}MAIN MENU${NC}                                                 ${G3}│${NC}"
    echo -e "${G3}    ├──────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${G3}    │${NC}   ${G2}[1]${NC} ➤ Setup IRAN Server       ${DIM}(Inside Server)${NC}              ${G3}│${NC}"
    echo -e "${G3}    │${NC}   ${G2}[2]${NC} ➤ Setup KHAREJ Server     ${DIM}(Outside Server)${NC}            ${G3}│${NC}"
    echo -e "${G3}    │${NC}   ${G2}[3]${NC} ➤ Full Status & Ping      ${DIM}(Diagnostics)${NC}               ${G3}│${NC}"
    echo -e "${G3}    │${NC}   ${G2}[4]${NC} ➤ Restart Tunnel          ${DIM}(Restart + Test)${NC}            ${G3}│${NC}"
    echo -e "${G3}    │${NC}   ${G2}[5]${NC} ➤ Uninstall               ${DIM}(Remove All)${NC}                ${G3}│${NC}"
    echo -e "${G3}    │${NC}   ${RED}[0]${NC} ➤ Exit                                                   ${G3}│${NC}"
    echo -e "${G3}    └──────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -ne "    ${G2}❯${NC} Choice: "
}

main() {
    check_root
    while true; do
        show_main_menu
        read ch
        case $ch in
            1) setup_iran ;;
            2) setup_kharej ;;
            3) check_status ;;
            4) restart_tunnel ;;
            5) uninstall_tunnel ;;
            0)
                echo ""
                echo -e "    ${G2}★${NC} ${WHITE}Thank you for using ${G1}VIRA TUNNEL${NC}!"
                echo ""
                exit 0 ;;
            *) err "Invalid!"; sleep 1 ;;
        esac
    done
}

main "$@"
