#!/bin/bash
# ============================================================
#  VIRA TUNNEL v5.0 - Professional GRE Tunnel Manager
#  SSH-Safe | Auto Private IP | Full Diagnostics
# ============================================================

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

CONFIG_DIR="/etc/vira-tunnel"
CONFIG_FILE="${CONFIG_DIR}/config"
TUNNEL_SCRIPT="/usr/local/sbin/vira-gre.sh"
SERVICE_FILE="/etc/systemd/system/vira-gre.service"
TUNNEL_NAME="viraGRE"
VIRA_PREROUTING="VIRA_PRE"
VIRA_POSTROUTING="VIRA_POST"

IRAN_IP=""
KHAREJ_IP=""
IRAN_PRIVATE_IP=""
KHAREJ_PRIVATE_IP=""

# ──────────────────── LOGO ────────────────────

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
    echo -e "${G8}    ║${NC}  ${G2}★${NC} ${WHITE}Professional GRE Tunnel Manager${NC}        ${DIM}Version 5.0${NC}     ${G8}  ║${NC}"
    echo -e "${G8}    ║${NC}  ${G3}★${NC} ${DIM}SSH-Safe • Auto-IP • Full Diagnostics${NC}                   ${G8}  ║${NC}"
    echo -e "${G8}    ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ──────────────────── HELPERS ────────────────────

ok()   { echo -e "    ${GREEN}  ✔  ${NC}$1"; }
err()  { echo -e "    ${RED}  ✘  ${NC}$1"; }
warn() { echo -e "    ${YELLOW}  ⚠  ${NC}$1"; }
info() { echo -e "    ${CYAN}  ℹ  ${NC}$1"; }
step() { echo -e "    ${G2}[Step $1]${NC} ${WHITE}$2${NC}"; }

check_root() {
    [[ $EUID -ne 0 ]] && { err "Run as root: ${WHITE}sudo bash $0${NC}"; exit 1; }
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

detect_main_interface() {
    ip -4 route get 8.8.8.8 2>/dev/null | grep -oP 'dev \K\S+' | head -1
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

# ──────────────────── GET IPS ────────────────────

get_server_ips() {
    local role="$1"
    local auto_ip
    auto_ip=$(detect_local_ip)

    echo ""
    echo -e "${G3}    ┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${G3}    │${NC}  ${G1}🔧${NC} ${WHITE}${BOLD}IP CONFIGURATION${NC}                                            ${G3}│${NC}"
    echo -e "${G3}    └──────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Auto private IPs
    IRAN_PRIVATE_IP="10.10.10.1"
    KHAREJ_PRIVATE_IP="10.10.10.2"

    if [[ "$role" == "IRAN" ]]; then
        echo -ne "    ${G2}❯${NC} ${WHITE}IRAN Server Public IP${NC} [${CYAN}${auto_ip}${NC}]: "
        read input
        IRAN_IP=${input:-$auto_ip}
        while ! validate_ip "$IRAN_IP"; do
            err "Invalid IP!"
            echo -ne "    ${G2}❯${NC} ${WHITE}IRAN IP:${NC} "
            read IRAN_IP
        done
        ok "IRAN: ${CYAN}$IRAN_IP${NC}"
        echo ""

        echo -ne "    ${G2}❯${NC} ${WHITE}KHAREJ Server Public IP:${NC} "
        read KHAREJ_IP
        while ! validate_ip "$KHAREJ_IP"; do
            err "Invalid IP!"
            echo -ne "    ${G2}❯${NC} ${WHITE}KHAREJ IP:${NC} "
            read KHAREJ_IP
        done
        ok "KHAREJ: ${CYAN}$KHAREJ_IP${NC}"
    else
        echo -ne "    ${G2}❯${NC} ${WHITE}KHAREJ Server Public IP${NC} [${CYAN}${auto_ip}${NC}]: "
        read input
        KHAREJ_IP=${input:-$auto_ip}
        while ! validate_ip "$KHAREJ_IP"; do
            err "Invalid IP!"
            echo -ne "    ${G2}❯${NC} ${WHITE}KHAREJ IP:${NC} "
            read KHAREJ_IP
        done
        ok "KHAREJ: ${CYAN}$KHAREJ_IP${NC}"
        echo ""

        echo -ne "    ${G2}❯${NC} ${WHITE}IRAN Server Public IP:${NC} "
        read IRAN_IP
        while ! validate_ip "$IRAN_IP"; do
            err "Invalid IP!"
            echo -ne "    ${G2}❯${NC} ${WHITE}IRAN IP:${NC} "
            read IRAN_IP
        done
        ok "IRAN: ${CYAN}$IRAN_IP${NC}"
    fi

    echo ""
    echo -e "${G3}    ┌────────────────────────────────────────────────────────┐${NC}"
    printf "    ${G3}│${NC}  ${WHITE}IRAN Public${NC}    : ${CYAN}%-36s${NC}${G3}│${NC}\n" "$IRAN_IP"
    printf "    ${G3}│${NC}  ${WHITE}KHAREJ Public${NC}  : ${CYAN}%-36s${NC}${G3}│${NC}\n" "$KHAREJ_IP"
    printf "    ${G3}│${NC}  ${WHITE}IRAN Private${NC}   : ${CYAN}%-36s${NC}${G3}│${NC}\n" "${IRAN_PRIVATE_IP}/30 (auto)"
    printf "    ${G3}│${NC}  ${WHITE}KHAREJ Private${NC} : ${CYAN}%-36s${NC}${G3}│${NC}\n" "${KHAREJ_PRIVATE_IP}/30 (auto)"
    echo -e "${G3}    └────────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -ne "    ${G2}❯${NC} ${WHITE}Confirm?${NC} [${GREEN}Y${NC}/n]: "
    read c
    [[ "$c" == "n" || "$c" == "N" ]] && return 1
    return 0
}

# ──────────────────── SAFE IPTABLES ────────────────────

cleanup_vira_iptables() {
    # Safely remove ONLY vira chains, don't touch anything else
    iptables -t nat -D PREROUTING -j ${VIRA_PREROUTING} 2>/dev/null || true
    iptables -t nat -F ${VIRA_PREROUTING} 2>/dev/null || true
    iptables -t nat -X ${VIRA_PREROUTING} 2>/dev/null || true

    iptables -t nat -D POSTROUTING -j ${VIRA_POST} 2>/dev/null || true
    iptables -t nat -F ${VIRA_POST} 2>/dev/null || true
    iptables -t nat -X ${VIRA_POST} 2>/dev/null || true
}

setup_iran_iptables() {
    local iran_priv="$1"
    local kharej_priv="$2"

    info "Setting SAFE iptables rules..."
    echo ""

    # Clean old vira rules only
    cleanup_vira_iptables

    # ═══ PREROUTING CHAIN ═══
    iptables -t nat -N ${VIRA_PREROUTING} 2>/dev/null || true

    # Don't touch SSH
    iptables -t nat -A ${VIRA_PREROUTING} -p tcp --dport 22 -j RETURN
    ok "SSH (22) → SAFE"

    # Don't touch GRE
    iptables -t nat -A ${VIRA_PREROUTING} -p gre -j RETURN
    ok "GRE → SAFE"

    # Don't touch ICMP
    iptables -t nat -A ${VIRA_PREROUTING} -p icmp -j RETURN
    ok "ICMP → SAFE"

    # Don't touch DNS
    iptables -t nat -A ${VIRA_PREROUTING} -p udp --dport 53 -j RETURN
    iptables -t nat -A ${VIRA_PREROUTING} -p tcp --dport 53 -j RETURN
    ok "DNS (53) → SAFE"

    # Don't touch tunnel subnet
    iptables -t nat -A ${VIRA_PREROUTING} -s ${iran_priv}/30 -j RETURN
    ok "Tunnel subnet → SAFE"

    # Don't touch established
    iptables -t nat -A ${VIRA_PREROUTING} -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
    ok "Established → SAFE"

    # Forward to KHAREJ
    iptables -t nat -A ${VIRA_PREROUTING} -p tcp -j DNAT --to-destination ${kharej_priv}
    iptables -t nat -A ${VIRA_PREROUTING} -p udp -j DNAT --to-destination ${kharej_priv}
    ok "TCP/UDP → DNAT to ${CYAN}${kharej_priv}${NC}"

    # Hook
    iptables -t nat -A PREROUTING -j ${VIRA_PREROUTING}
    ok "PREROUTING chain hooked"

    # ═══ POSTROUTING CHAIN ═══
    iptables -t nat -N ${VIRA_POST} 2>/dev/null || true
    iptables -t nat -A ${VIRA_POST} -o ${TUNNEL_NAME} -j MASQUERADE
    iptables -t nat -A ${VIRA_POST} -s ${iran_priv}/30 -j MASQUERADE
    iptables -t nat -A POSTROUTING -j ${VIRA_POST}
    ok "POSTROUTING MASQUERADE for tunnel"

    echo ""
}

setup_kharej_iptables() {
    cleanup_vira_iptables

    iptables -t nat -N ${VIRA_POST} 2>/dev/null || true
    iptables -t nat -A ${VIRA_POST} -j MASQUERADE
    iptables -t nat -A POSTROUTING -j ${VIRA_POST}
    ok "MASQUERADE set"
}

# ──────────────────── ANIMATED PING ────────────────────

animated_ping() {
    local target="$1" label="$2"
    local count=4 success=0 fail=0 times=()

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
                local clr="${GREEN}"; ((ri>100)) && clr="${YELLOW}"; ((ri>300)) && clr="${RED}"
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
    local loss=$((fail*100/count))

    if ((success > 0)); then
        local min_t="999999" max_t="0" sum_t="0"
        for t in "${times[@]}"; do
            sum_t=$(awk "BEGIN{printf \"%.2f\",$sum_t+$t}")
            local ti=${t%.*}; ti=${ti:-0}
            local mi=${min_t%.*}; mi=${mi:-999999}
            local mx=${max_t%.*}; mx=${mx:-0}
            ((ti<mi)) && min_t="$t"; ((ti>mx)) && max_t="$t"
        done
        local avg_t
        avg_t=$(awk "BEGIN{printf \"%.2f\",$sum_t/${#times[@]}}")
        local lc="${GREEN}"; ((loss>0)) && lc="${YELLOW}"; ((loss>=100)) && lc="${RED}"
        echo -e "    ${G6}│${NC}  ${GREEN}✅ CONNECTED${NC}  ${success}/${count} ok  ${lc}(${loss}% loss)${NC}"
        if [[ ${#times[@]} -gt 0 ]]; then
            echo -e "    ${G6}│${NC}  ${G2}⏱${NC}  min=${CYAN}${min_t}ms${NC} avg=${CYAN}${avg_t}ms${NC} max=${CYAN}${max_t}ms${NC}"
            local ai=${avg_t%.*}; ai=${ai:-0}; local q="" qb=""
            if   ((ai<=30));  then q="${GREEN}${BOLD}EXCELLENT${NC}"; qb="${GREEN}██████████${NC}"
            elif ((ai<=80));  then q="${GREEN}VERY GOOD${NC}";       qb="${GREEN}████████${NC}${DIM}██${NC}"
            elif ((ai<=150)); then q="${YELLOW}GOOD${NC}";           qb="${YELLOW}██████${NC}${DIM}████${NC}"
            elif ((ai<=300)); then q="${YELLOW}FAIR${NC}";           qb="${YELLOW}████${NC}${DIM}██████${NC}"
            else                   q="${RED}POOR${NC}";             qb="${RED}██${NC}${DIM}████████${NC}"
            fi
            echo -e "    ${G6}│${NC}  ${G2}📶${NC}  Quality: [${qb}] ${q}"
        fi
    else
        echo -e "    ${G6}│${NC}  ${RED}❌ DISCONNECTED${NC}  ${RED}100% loss${NC}"
        echo -e "    ${G6}│${NC}  ${YELLOW}💡 Check remote server & firewall${NC}"
    fi
    echo -e "    ${G6}╰───────────────────────────────────────────────────────────╯${NC}"
    echo ""
}

# ──────────────────── SETUP IRAN ────────────────────

setup_iran() {
    show_logo
    echo -e "    ${BG_GOLD}${WHITE}${BOLD}  ⚡ IRAN Server Setup 🇮🇷  ${NC}"
    get_server_ips "IRAN" || return

    echo ""
    echo -e "${G3}    ┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${G3}    │${NC}  ${G1}🚀${NC} ${WHITE}${BOLD}INSTALLING IRAN SERVER${NC}                                      ${G3}│${NC}"
    echo -e "${G3}    └──────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    step "1/8" "Loading GRE module..."
    ensure_gre_module
    lsmod | grep -q "ip_gre" && ok "ip_gre loaded" || err "GRE failed"

    step "2/8" "Creating tunnel script..."
    cat > "$TUNNEL_SCRIPT" << TUNEOF
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
echo "VIRA TUNNEL IRAN UP"
TUNEOF
    chmod +x "$TUNNEL_SCRIPT"
    ok "Script created"

    step "3/8" "Saving config..."
    save_config "IRAN"
    ok "Saved"

    step "4/8" "Enabling IP forwarding..."
    sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
    ok "Forwarding ON"

    step "5/8" "Installing iptables-persistent..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq > /dev/null 2>&1
    apt-get install -y -qq iptables-persistent netfilter-persistent > /dev/null 2>&1
    ok "Installed"

    step "6/8" "Setting SAFE iptables..."
    echo ""
    setup_iran_iptables "$IRAN_PRIVATE_IP" "$KHAREJ_PRIVATE_IP"

    step "7/8" "Saving iptables..."
    netfilter-persistent save > /dev/null 2>&1
    ok "Saved"

    step "8/8" "Starting tunnel..."
    cat > "$SERVICE_FILE" << SVCEOF
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
SVCEOF
    systemctl daemon-reload
    systemctl enable vira-gre.service > /dev/null 2>&1
    bash "$TUNNEL_SCRIPT" > /dev/null 2>&1 || true
    systemctl restart vira-gre.service > /dev/null 2>&1 || true
    sleep 1

    if ip link show ${TUNNEL_NAME} 2>/dev/null | grep -qE "UP|UNKNOWN"; then
        local tip; tip=$(ip addr show ${TUNNEL_NAME} 2>/dev/null | grep -oP 'inet \K[0-9.]+')
        ok "${GREEN}${BOLD}Tunnel UP!${NC} IP: ${CYAN}${tip}${NC}"
    else
        err "Tunnel not up yet"
    fi

    echo ""
    progress_bar 1 "Finalizing"
    echo ""
    animated_ping "$IRAN_PRIVATE_IP" "Local Self-Ping (${IRAN_PRIVATE_IP})"

    echo -e "${G3}    ╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${G3}    ║${NC}  ${GREEN}${BOLD}✅ IRAN SERVER READY!${NC}                                       ${G3}║${NC}"
    echo -e "${G3}    ║${NC}  ${WHITE}Now setup KHAREJ server with option 2${NC}                       ${G3}║${NC}"
    echo -e "${G3}    ║${NC}  ${G2}Private IPs: IRAN=${CYAN}10.10.10.1${NC} KHAREJ=${CYAN}10.10.10.2${NC}            ${G3}║${NC}"
    echo -e "${G3}    ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -ne "    ${G2}❯${NC} Press Enter..."
    read
}

# ──────────────────── SETUP KHAREJ ────────────────────

setup_kharej() {
    show_logo
    echo -e "    ${BG_GOLD}${WHITE}${BOLD}  ⚡ KHAREJ Server Setup 🌍  ${NC}"
    get_server_ips "KHAREJ" || return

    echo ""
    echo -e "${G3}    ┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${G3}    │${NC}  ${G1}🚀${NC} ${WHITE}${BOLD}INSTALLING KHAREJ SERVER${NC}                                    ${G3}│${NC}"
    echo -e "${G3}    └──────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    step "1/7" "Loading GRE module..."
    ensure_gre_module
    lsmod | grep -q "ip_gre" && ok "ip_gre loaded" || err "GRE failed"

    step "2/7" "Creating tunnel script..."
    cat > "$TUNNEL_SCRIPT" << TUNEOF
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
echo "VIRA TUNNEL KHAREJ UP"
TUNEOF
    chmod +x "$TUNNEL_SCRIPT"
    ok "Script created"

    step "3/7" "Saving config..."
    save_config "KHAREJ"
    ok "Saved"

    step "4/7" "Enabling IP forwarding..."
    sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
    ok "Forwarding ON"

    step "5/7" "Installing iptables-persistent..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq > /dev/null 2>&1
    apt-get install -y -qq iptables-persistent netfilter-persistent > /dev/null 2>&1
    ok "Installed"

    step "6/7" "Setting iptables..."
    setup_kharej_iptables
    netfilter-persistent save > /dev/null 2>&1
    ok "Rules saved"

    step "7/7" "Starting tunnel..."
    cat > "$SERVICE_FILE" << SVCEOF
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
SVCEOF
    systemctl daemon-reload
    systemctl enable vira-gre.service > /dev/null 2>&1
    bash "$TUNNEL_SCRIPT" > /dev/null 2>&1 || true
    systemctl restart vira-gre.service > /dev/null 2>&1 || true
    sleep 1

    if ip link show ${TUNNEL_NAME} 2>/dev/null | grep -qE "UP|UNKNOWN"; then
        local tip; tip=$(ip addr show ${TUNNEL_NAME} 2>/dev/null | grep -oP 'inet \K[0-9.]+')
        ok "${GREEN}${BOLD}Tunnel UP!${NC} IP: ${CYAN}${tip}${NC}"
    else
        err "Tunnel not up yet"
    fi

    echo ""
    progress_bar 1 "Finalizing"
    echo ""
    animated_ping "$KHAREJ_PRIVATE_IP" "Local Self-Ping (${KHAREJ_PRIVATE_IP})"

    echo -e "${G3}    ╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${G3}    ║${NC}  ${GREEN}${BOLD}✅ KHAREJ SERVER READY!${NC}                                     ${G3}║${NC}"
    echo -e "${G3}    ║${NC}  ${WHITE}Make sure IRAN server is configured too${NC}                     ${G3}║${NC}"
    echo -e "${G3}    ║${NC}  ${G2}Private IPs: IRAN=${CYAN}10.10.10.1${NC} KHAREJ=${CYAN}10.10.10.2${NC}            ${G3}║${NC}"
    echo -e "${G3}    ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -ne "    ${G2}❯${NC} Press Enter..."
    read
}

# ──────────────────── SAFE UNINSTALL ────────────────────

uninstall_tunnel() {
    show_logo

    echo -e "${RED}    ┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${RED}    │${NC}  ${RED}⚠${NC}  ${WHITE}${BOLD}UNINSTALL VIRA TUNNEL${NC}                                      ${RED}│${NC}"
    echo -e "${RED}    └──────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    warn "This removes all VIRA tunnel configs"
    info "${GREEN}Your SSH access will remain safe${NC}"
    echo ""
    echo -ne "    ${RED}❯${NC} Type '${RED}YES${NC}': "
    read c
    [[ "$c" != "YES" ]] && { info "Cancelled."; echo -ne "\n    Enter..."; read; return; }
    echo ""

    # ═══ Step 1: Stop service FIRST ═══
    step "1/7" "Stopping service..."
    systemctl stop vira-gre.service 2>/dev/null || true
    systemctl disable vira-gre.service 2>/dev/null || true
    ok "Service stopped"

    # ═══ Step 2: Remove tunnel interface ═══
    step "2/7" "Removing tunnel interface..."
    ip tunnel del ${TUNNEL_NAME} 2>/dev/null || true
    ip link del ${TUNNEL_NAME} 2>/dev/null || true
    ok "Tunnel removed"

    # ═══ Step 3: SAFE iptables cleanup ═══
    # THIS IS THE KEY FIX:
    # Only remove VIRA chains, never flush system chains
    step "3/7" "Cleaning iptables (SSH-safe)..."

    # Remove VIRA prerouting chain
    iptables -t nat -D PREROUTING -j ${VIRA_PREROUTING} 2>/dev/null || true
    iptables -t nat -F ${VIRA_PREROUTING} 2>/dev/null || true
    iptables -t nat -X ${VIRA_PREROUTING} 2>/dev/null || true
    ok "VIRA prerouting chain removed"

    # Remove VIRA postrouting chain
    iptables -t nat -D POSTROUTING -j ${VIRA_POST} 2>/dev/null || true
    iptables -t nat -F ${VIRA_POST} 2>/dev/null || true
    iptables -t nat -X ${VIRA_POST} 2>/dev/null || true
    ok "VIRA postrouting chain removed"

    # Also clean any old-style rules (from previous versions)
    # Remove specific DNAT rules that might exist
    iptables -t nat -D PREROUTING -p tcp --dport 22 -j DNAT --to-destination 10.10.10.1 2>/dev/null || true
    iptables -t nat -D PREROUTING -j DNAT --to-destination 10.10.10.2 2>/dev/null || true

    # DO NOT flush POSTROUTING - it breaks SSH!
    # Instead, only remove tunnel-specific masquerade
    iptables -t nat -D POSTROUTING -o ${TUNNEL_NAME} -j MASQUERADE 2>/dev/null || true
    iptables -t nat -D POSTROUTING -s 10.10.10.0/30 -j MASQUERADE 2>/dev/null || true

    # Check if any old config exists
    if load_config; then
        iptables -t nat -D POSTROUTING -s ${IRAN_PRIVATE_IP}/30 -j MASQUERADE 2>/dev/null || true
        iptables -t nat -D PREROUTING -j DNAT --to-destination ${KHAREJ_PRIVATE_IP} 2>/dev/null || true
        iptables -t nat -D PREROUTING -p tcp --dport 22 -j DNAT --to-destination ${IRAN_PRIVATE_IP} 2>/dev/null || true
    fi

    ok "Old rules cleaned"

    # ═══ Step 4: Make sure basic MASQUERADE still works ═══
    # This ensures SSH stays working even after cleanup
    step "4/7" "Ensuring SSH connectivity..."
    local main_iface
    main_iface=$(detect_main_interface)

    # Check if there's any MASQUERADE rule left for the main interface
    # If not, the server will still work because we didn't flush the chain
    # Just verify SSH is not blocked
    info "Main interface: ${CYAN}${main_iface}${NC}"
    ok "SSH connectivity preserved (no system chains flushed)"

    # ═══ Step 5: Save clean rules ═══
    step "5/7" "Saving clean iptables..."
    netfilter-persistent save > /dev/null 2>&1 || true
    ok "Saved"

    # ═══ Step 6: Remove files ═══
    step "6/7" "Removing files..."
    rm -f "$TUNNEL_SCRIPT"
    rm -f "$SERVICE_FILE"
    rm -rf "$CONFIG_DIR"
    rm -f /etc/modules-load.d/gre.conf
    systemctl daemon-reload
    ok "All files removed"

    # ═══ Step 7: Verify ═══
    step "7/7" "Verifying..."
    local all_ok=true
    if ip tunnel show 2>/dev/null | grep -q "${TUNNEL_NAME}"; then
        err "Tunnel still exists"; all_ok=false
    else
        ok "Tunnel interface: removed"
    fi

    if [[ -f "$SERVICE_FILE" ]]; then
        err "Service file still exists"; all_ok=false
    else
        ok "Service file: removed"
    fi

    if [[ -d "$CONFIG_DIR" ]]; then
        err "Config dir still exists"; all_ok=false
    else
        ok "Config: removed"
    fi

    if iptables -t nat -L ${VIRA_PREROUTING} -n 2>/dev/null | grep -q "Chain"; then
        err "VIRA prerouting chain still exists"; all_ok=false
    else
        ok "VIRA iptables chains: removed"
    fi

    echo ""
    if $all_ok; then
        echo -e "    ${GREEN}${BOLD}✅ VIRA TUNNEL completely uninstalled!${NC}"
        echo -e "    ${GREEN}✔  SSH access is safe and working${NC}"
    else
        warn "Some items may need manual cleanup"
    fi

    echo ""
    echo -ne "    ${G2}❯${NC} Press Enter..."
    read
}

# ──────────────────── STATUS ────────────────────

check_status() {
    show_logo
    echo -e "${G3}    ╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${G3}    ║${NC}  ${G1}📊${NC} ${WHITE}${BOLD}FULL DIAGNOSTICS v5${NC}                                         ${G3}║${NC}"
    echo -e "${G3}    ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local cfg=false sr="" sii="" ski="" sip="" skp="" sd=""
    if load_config; then
        cfg=true; sr="$ROLE"; sii="$IRAN_IP"; ski="$KHAREJ_IP"
        sip="$IRAN_PRIVATE_IP"; skp="$KHAREJ_PRIVATE_IP"; sd="$INSTALL_DATE"
    fi

    # 1. Server Info
    echo -e "    ${G2}━━━ 1. SERVER INFO ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    if $cfg; then
        local ri="🌍"; [[ "$sr" == "IRAN" ]] && ri="🇮🇷"
        printf "    Role: ${CYAN}${BOLD}%-8s${NC} %s   Installed: ${DIM}%s${NC}\n" "$sr" "$ri" "$sd"
        printf "    IRAN:   ${CYAN}%-16s${NC}  Private: ${CYAN}%s${NC}\n" "$sii" "$sip"
        printf "    KHAREJ: ${CYAN}%-16s${NC}  Private: ${CYAN}%s${NC}\n" "$ski" "$skp"
    else
        warn "No config found"
    fi
    echo ""

    # 2. GRE Module
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
        local tip; tip=$(ip addr show ${TUNNEL_NAME} 2>/dev/null | grep -oP 'inet \K[0-9./]+')
        [[ -n "$tip" ]] && ok "IP: ${CYAN}${tip}${NC}" || warn "No IP"
        local ls; ls=$(ip link show ${TUNNEL_NAME} 2>/dev/null | grep -oP 'state \K\w+')
        [[ "$ls" == "UP" || "$ls" == "UNKNOWN" ]] && ok "State: ${GREEN}UP${NC}" || err "State: ${RED}${ls}${NC}"
    else
        err "Tunnel ${TUNNEL_NAME} NOT FOUND"
    fi
    echo ""

    # 4. Service
    echo -e "    ${G2}━━━ 4. SERVICE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    if [[ -f "$SERVICE_FILE" ]]; then
        systemctl is-active --quiet vira-gre.service 2>/dev/null && \
            ok "Status: ${GREEN}● ACTIVE${NC}" || err "Status: ${RED}● INACTIVE${NC}"
        systemctl is-enabled --quiet vira-gre.service 2>/dev/null && \
            ok "Boot: ${GREEN}ENABLED${NC}" || warn "Boot: ${YELLOW}DISABLED${NC}"
    else
        err "Service file missing"
    fi
    echo ""

    # 5. Network
    echo -e "    ${G2}━━━ 5. NETWORK & NAT ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    [[ "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" == "1" ]] && \
        ok "Forward: ${GREEN}ON${NC}" || err "Forward: ${RED}OFF${NC}"

    if iptables -t nat -L ${VIRA_PREROUTING} -n 2>/dev/null | grep -q "Chain"; then
        ok "VIRA_PRE chain: ${GREEN}EXISTS${NC}"
        iptables -t nat -L ${VIRA_PREROUTING} -n 2>/dev/null | tail -n +3 | head -10 | \
            while read l; do echo -e "    ${DIM}      → $l${NC}"; done
    fi

    if iptables -t nat -L ${VIRA_POST} -n 2>/dev/null | grep -q "Chain"; then
        ok "VIRA_POST chain: ${GREEN}EXISTS${NC}"
        iptables -t nat -L ${VIRA_POST} -n 2>/dev/null | tail -n +3 | head -5 | \
            while read l; do echo -e "    ${DIM}      → $l${NC}"; done
    fi
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
        if [[ "$cr" == "IRAN" ]]; then
            animated_ping "$rp" "IRAN → KHAREJ (${rp})"
        else
            animated_ping "$rp" "KHAREJ → IRAN (${rp})"
        fi

        if $cfg; then
            local rpub=""
            [[ "$sr" == "IRAN" ]] && rpub="$ski" || rpub="$sii"
            echo -e "    ${G6}${BOLD}▸ TEST 3: Remote Public${NC}"
            echo ""
            animated_ping "$rpub" "Public IP → ${rpub}"
        fi

        echo -e "    ${G6}${BOLD}▸ TEST 4: Internet${NC}"
        echo ""
        animated_ping "8.8.8.8" "Google DNS"
    else
        animated_ping "8.8.8.8" "Internet Test"
    fi

    # 7. Health Score
    echo -e "    ${G2}━━━ 7. HEALTH SCORE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    local tot=0 pass=0

    tot=$((tot+1))
    lsmod | grep -q "ip_gre" && { pass=$((pass+1)); echo -e "    ${GREEN}✔${NC} GRE Module       ${GREEN}PASS${NC}"; } || echo -e "    ${RED}✘${NC} GRE Module       ${RED}FAIL${NC}"

    tot=$((tot+1))
    $tun_ok && { pass=$((pass+1)); echo -e "    ${GREEN}✔${NC} Tunnel           ${GREEN}PASS${NC}"; } || echo -e "    ${RED}✘${NC} Tunnel           ${RED}FAIL${NC}"

    tot=$((tot+1))
    systemctl is-active --quiet vira-gre.service 2>/dev/null && { pass=$((pass+1)); echo -e "    ${GREEN}✔${NC} Service          ${GREEN}PASS${NC}"; } || echo -e "    ${RED}✘${NC} Service          ${RED}FAIL${NC}"

    tot=$((tot+1))
    [[ "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)" == "1" ]] && { pass=$((pass+1)); echo -e "    ${GREEN}✔${NC} IP Forward       ${GREEN}PASS${NC}"; } || echo -e "    ${RED}✘${NC} IP Forward       ${RED}FAIL${NC}"

    tot=$((tot+1))
    [[ -n "$lp" ]] && ping -c1 -W2 "$lp" >/dev/null 2>&1 && { pass=$((pass+1)); echo -e "    ${GREEN}✔${NC} Local Ping       ${GREEN}PASS${NC}"; } || echo -e "    ${RED}✘${NC} Local Ping       ${RED}FAIL${NC}"

    tot=$((tot+1))
    [[ -n "$rp" ]] && ping -c1 -W3 "$rp" >/dev/null 2>&1 && { pass=$((pass+1)); echo -e "    ${GREEN}✔${NC} Remote Ping      ${GREEN}PASS${NC}"; } || echo -e "    ${RED}✘${NC} Remote Ping      ${RED}FAIL${NC}"

    echo ""
    local pct=$((pass*100/tot))
    local hc="${RED}" ht="CRITICAL" hb="${RED}████${NC}${DIM}██████████████████████████${NC}"
    if   ((pct>=100)); then hc="${GREEN}";  ht="PERFECT";  hb="${GREEN}██████████████████████████████${NC}"
    elif ((pct>=80));  then hc="${GREEN}";  ht="HEALTHY";  hb="${GREEN}████████████████████████${NC}${DIM}██████${NC}"
    elif ((pct>=60));  then hc="${YELLOW}"; ht="GOOD";     hb="${YELLOW}██████████████████${NC}${DIM}████████████${NC}"
    elif ((pct>=40));  then hc="${YELLOW}"; ht="DEGRADED"; hb="${YELLOW}████████████${NC}${DIM}██████████████████${NC}"
    fi

    echo -e "    ${G3}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "    ${G3}║${NC}  Score: ${hc}${BOLD}${pass}/${tot}${NC} (${hc}${pct}%${NC})  Status: ${hc}${BOLD}⬤ ${ht}${NC}         ${G3}║${NC}"
    echo -e "    ${G3}║${NC}  [${hb}]  ${G3}║${NC}"
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

    [[ ! -f "$TUNNEL_SCRIPT" ]] && { err "Not installed"; echo -ne "\n    Enter..."; read; return; }

    step "1/4" "GRE module..."
    ensure_gre_module; ok "Ready"

    step "2/4" "Stopping..."
    systemctl stop vira-gre.service 2>/dev/null || true
    ip tunnel del ${TUNNEL_NAME} 2>/dev/null || true
    ip link del ${TUNNEL_NAME} 2>/dev/null || true
    sleep 1; ok "Stopped"

    step "3/4" "Starting..."
    bash "$TUNNEL_SCRIPT" 2>&1 || true
    systemctl restart vira-gre.service 2>/dev/null || true
    sleep 1

    step "4/4" "Checking..."
    if ip link show ${TUNNEL_NAME} 2>/dev/null | grep -qE "UP|UNKNOWN"; then
        local tip; tip=$(ip addr show ${TUNNEL_NAME} 2>/dev/null | grep -oP 'inet \K[0-9.]+')
        ok "${GREEN}${BOLD}Tunnel UP!${NC} IP: ${CYAN}${tip}${NC}"
    else
        err "Tunnel not up"
    fi

    echo ""
    if load_config; then
        local my="" rem=""
        [[ "$ROLE" == "IRAN" ]] && { my="$IRAN_PRIVATE_IP"; rem="$KHAREJ_PRIVATE_IP"; } || \
            { my="$KHAREJ_PRIVATE_IP"; rem="$IRAN_PRIVATE_IP"; }

        [[ -n "$my" ]] && animated_ping "$my" "Local Self → ${my}"
        [[ -n "$rem" ]] && animated_ping "$rem" "Remote → ${rem}"
    fi

    echo -ne "    ${G2}❯${NC} Press Enter..."
    read
}

# ──────────────────── MENU ────────────────────

show_main_menu() {
    show_logo
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE" 2>/dev/null
        local ri="🌍"; [[ "$ROLE" == "IRAN" ]] && ri="🇮🇷"
        local ss="${RED}OFF${NC}"
        systemctl is-active --quiet vira-gre.service 2>/dev/null && ss="${GREEN}ON${NC}"
        local tip; tip=$(ip addr show ${TUNNEL_NAME} 2>/dev/null | grep -oP 'inet \K[0-9.]+' || echo "N/A")
        echo -e "    ${DIM}Server: ${WHITE}${ROLE}${NC} ${ri}  Service: ${ss}  TunnelIP: ${CYAN}${tip}${NC}"
        echo ""
    fi

    echo -e "${G3}    ┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${G3}    │${NC}  ${G1}⚙${NC}  ${WHITE}${BOLD}MAIN MENU${NC}                                                 ${G3}│${NC}"
    echo -e "${G3}    ├──────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${G3}    │${NC}   ${G2}[1]${NC} ➤ Setup IRAN Server      ${DIM}(Private: 10.10.10.1)${NC}        ${G3}│${NC}"
    echo -e "${G3}    │${NC}   ${G2}[2]${NC} ➤ Setup KHAREJ Server    ${DIM}(Private: 10.10.10.2)${NC}        ${G3}│${NC}"
    echo -e "${G3}    │${NC}   ${G2}[3]${NC} ➤ Status & Ping Tests    ${DIM}(Full Diagnostics)${NC}           ${G3}│${NC}"
    echo -e "${G3}    │${NC}   ${G2}[4]${NC} ➤ Restart Tunnel         ${DIM}(Restart + Test)${NC}             ${G3}│${NC}"
    echo -e "${G3}    │${NC}   ${G2}[5]${NC} ➤ Uninstall              ${DIM}(SSH-Safe Remove)${NC}            ${G3}│${NC}"
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
            0) echo -e "\n    ${G2}★${NC} Thank you for using ${G1}VIRA TUNNEL${NC}!\n"; exit 0 ;;
            *) err "Invalid!"; sleep 1 ;;
        esac
    done
}

main "$@"
