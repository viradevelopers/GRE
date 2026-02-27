#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#  VIRA TUNNEL v2 — Hybrid Tunnel Manager
#  iptables + HAProxy + GRE + Hysteria2
#  Designed for Ubuntu 22.04
# ═══════════════════════════════════════════════════════════════════

VERSION="2"
CONFIG_DIR="/etc/vira-tunnel"
CONFIG_FILE="${CONFIG_DIR}/config.env"
LOG_FILE="/var/log/vira-tunnel.log"
HYSTERIA_DIR="/etc/hysteria"
WATCHDOG_SCRIPT="/usr/local/bin/vira-watchdog.sh"

# GRE Private IPs
GRE_IRAN="102.230.9.1"
GRE_KHAREJ="102.230.9.2"
GRE_SUBNET="102.230.9.0/30"

# ─── Color Palette ─────────────────────────────
RST='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

G1='\033[38;5;220m'
G2='\033[38;5;214m'
G3='\033[38;5;208m'
G4='\033[38;5;172m'
G5='\033[38;5;178m'
G6='\033[38;5;228m'

GR1='\033[38;5;255m'
GR2='\033[38;5;250m'
GR3='\033[38;5;245m'
GR4='\033[38;5;240m'
GR5='\033[38;5;235m'

RED='\033[38;5;196m'
GRN='\033[38;5;46m'
YLW='\033[38;5;226m'
CYN='\033[38;5;51m'
MGN='\033[38;5;201m'
BLU='\033[38;5;39m'
WHT='\033[38;5;15m'

TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
(( TERM_WIDTH > 90 )) && TERM_WIDTH=90

# ─── UI Functions ──────────────────────────────

print_line() {
    local ch="${1:-─}" cl="${2:-$GR4}"
    printf "${cl}%*s${RST}\n" "$TERM_WIDTH" "" | sed "s/ /${ch}/g"
}

print_gradient_line() {
    local cols=("$G1" "$G2" "$G3" "$G4" "$G3" "$G2" "$G1")
    local seg=$(( TERM_WIDTH / ${#cols[@]} ))
    for c in "${cols[@]}"; do
        printf "${c}"
        printf '%*s' "$seg" '' | tr ' ' '━'
    done
    printf "${RST}\n"
}

center_text() {
    local txt="$1" cl="${2:-$GR2}"
    local len=${#txt}
    local pad=$(( (TERM_WIDTH - len) / 2 ))
    (( pad < 0 )) && pad=0
    printf "%*s${cl}%s${RST}\n" "$pad" "" "$txt"
}

print_menu() {
    local n="$1" txt="$2" ico="${3:-▸}"
    printf "  ${GR4}│${RST}  ${G2}${BOLD}[${G1}%2s${G2}]${RST}  ${G5}${ico}${RST}  ${GR1}%s${RST}\n" "$n" "$txt"
}

print_stat() {
    local lbl="$1" val="$2" ico="$3"
    printf "  ${GR4}│${RST} ${G5}${ico}${RST}  ${GR2}%-28s${RST}" "$lbl"
    case "$val" in
        OK|UP|ACTIVE|RUNNING)    printf "${GRN}${BOLD}● %s${RST}\n" "$val" ;;
        FAIL|DOWN|DEAD|INACTIVE) printf "${RED}${BOLD}● %s${RST}\n" "$val" ;;
        *)                       printf "${YLW}${BOLD}● %s${RST}\n" "$val" ;;
    esac
}

msg_ok()   { printf "  ${GRN}✔${RST}  ${GR1}%s${RST}\n" "$1"; }
msg_err()  { printf "  ${RED}✘${RST}  ${RED}%s${RST}\n" "$1"; }
msg_warn() { printf "  ${YLW}⚠${RST}  ${G5}%s${RST}\n" "$1"; }
msg_info() { printf "  ${CYN}ℹ${RST}  ${GR2}%s${RST}\n" "$1"; }

ask() {
    local prompt="$1" var="$2" def="${3:-}"
    if [[ -n "$def" ]]; then
        printf "  ${G5}▸${RST}  ${GR2}%s ${GR4}[${GR3}%s${GR4}]${RST}: " "$prompt" "$def"
    else
        printf "  ${G5}▸${RST}  ${GR2}%s${RST}: " "$prompt"
    fi
    read -r input
    eval "${var}='${input:-$def}'"
}

confirm() {
    printf "  ${G5}▸${RST}  ${GR2}%s ${GR4}[${GRN}y${GR4}/${RED}n${GR4}]${RST}: " "$1"
    read -r ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

press_key() {
    echo ""
    printf "  ${GR4}── ${GR3}Press Enter to continue${GR4} ──${RST}"
    read -r
}

spinner() {
    local pid=$1 msg="${2:-Working...}"
    local sp='⣾⣽⣻⢿⡿⣟⣯⣷'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${G2}%s${RST}  ${GR3}%s${RST}" "${sp:i%${#sp}:1}" "$msg"
        (( i++ ))
        sleep 0.1
    done
    wait "$pid" 2>/dev/null
    local rc=$?
    printf "\r%*s\r" $(( ${#msg} + 10 )) ""
    return $rc
}

progress_bar() {
    local cur=$1 total=$2 label="${3:-Progress}"
    local pct=$(( cur * 100 / total ))
    local bw=35
    local filled=$(( cur * bw / total ))
    local empty=$(( bw - filled ))

    printf "\r  ${GR3}%-12s${RST} ${GR5}[${RST}" "$label"
    printf "${GRN}"
    for (( i=0; i<filled; i++ )); do printf "█"; done
    printf "${GR5}"
    for (( i=0; i<empty; i++ )); do printf "░"; done
    printf "${GR5}]${RST} ${GRN}${BOLD}%3d%%${RST}" "$pct"
}

draw_bar() {
    local val=$1 mx=$2 width=${3:-25} lbl="${4:-}"
    local pct=0 filled=0 empty=0
    (( mx > 0 )) && pct=$(( val * 100 / mx ))
    (( pct > 100 )) && pct=100
    filled=$(( pct * width / 100 ))
    empty=$(( width - filled ))
    local color="$GRN"
    (( pct > 70 )) && color="$YLW"
    (( pct > 90 )) && color="$RED"

    printf "  ${GR4}│${RST}  ${GR3}%-14s${RST} " "$lbl"
    printf "${color}"
    for (( i=0; i<filled; i++ )); do printf "█"; done
    printf "${GR5}"
    for (( i=0; i<empty; i++ )); do printf "░"; done
    printf "${RST} ${color}%3d%%${RST}\n" "$pct"
}

format_bytes() {
    local b=$1
    if (( b >= 1073741824 )); then
        echo "$(( b / 1073741824 )).$(( (b % 1073741824) * 10 / 1073741824 )) GiB"
    elif (( b >= 1048576 )); then
        echo "$(( b / 1048576 )).$(( (b % 1048576) * 10 / 1048576 )) MiB"
    elif (( b >= 1024 )); then
        echo "$(( b / 1024 )) KiB"
    else
        echo "${b} B"
    fi
}

# ─── Logo ──────────────────────────────────────
show_logo() {
    clear
    echo ""
    print_gradient_line
    echo ""
    printf "${G1}${BOLD}"
    center_text '██╗   ██╗██╗██████╗  █████╗ ' "$G1"
    center_text '██║   ██║██║██╔══██╗██╔══██╗' "$G2"
    center_text '██║   ██║██║██████╔╝███████║' "$G3"
    center_text '╚██╗ ██╔╝██║██╔══██╗██╔══██║' "$G4"
    center_text ' ╚████╔╝ ██║██║  ██║██║  ██║' "$G5"
    center_text '  ╚═══╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝' "$G2"
    printf "${RST}\n"
    center_text "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GR4"
    center_text "T U N N E L   v${VERSION}" "$GR3"
    center_text "iptables + HAProxy + GRE + Hysteria2" "$GR4"
    center_text "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GR4"
    echo ""
    print_gradient_line
}

# ─── System Detection ──────────────────────────
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "ERROR: Run as root (sudo bash $0)"
        exit 1
    fi
}

detect_interface() {
    local iface
    iface=$(ip -4 route show default 2>/dev/null | awk '/default/{print $5; exit}')
    [[ -z "$iface" ]] && iface=$(ls /sys/class/net/ 2>/dev/null | grep -vE '^(lo|gre|tun|veth)' | head -1)
    echo "${iface:-eth0}"
}

get_public_ip() {
    local ip=""
    local apis=(
        "https://api.ipify.org"
        "https://ipecho.net/plain"
        "https://icanhazip.com"
        "https://ident.me"
        "https://checkip.amazonaws.com"
        "https://ifconfig.io/ip"
        "https://ipinfo.io/ip"
        "https://api.my-ip.io/v2/ip.txt"
    )
    for api in "${apis[@]}"; do
        ip=$(curl -4s --max-time 4 -A "curl/8.0" -H "Accept: text/plain" "$api" 2>/dev/null)
        ip=$(echo "$ip" | tr -d '[:space:]')
        if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            echo "$ip"
            return 0
        fi
        ip=""
    done
    ip=$(ip -4 addr show scope global 2>/dev/null | awk '/inet /{gsub(/\/.*$/,"",$2); print $2; exit}')
    if [[ -n "$ip" && "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "$ip"
        return 0
    fi
    echo "Unavailable"
    return 1
}

get_link_speed() {
    local iface
    iface=$(detect_interface)
    if [[ -f "/sys/class/net/${iface}/speed" ]]; then
        local spd
        spd=$(cat "/sys/class/net/${iface}/speed" 2>/dev/null)
        if [[ -n "$spd" && "$spd" != "-1" ]] && (( spd > 0 )) 2>/dev/null; then
            if (( spd >= 1000 )); then
                echo "$(( spd / 1000 )) Gbps"
            else
                echo "${spd} Mbps"
            fi
            return
        fi
    fi
    if command -v ethtool &>/dev/null; then
        local s
        s=$(ethtool "$iface" 2>/dev/null | awk '/Speed:/{print $2}')
        [[ -n "$s" && "$s" != "Unknown!" ]] && { echo "$s"; return; }
    fi
    echo "N/A"
}

load_config() { [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"; }

save_config() {
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << CFEOF
INSTALLED=1
SERVER_ROLE=${SERVER_ROLE}
IRAN_IP=${IRAN_IP}
KHAREJ_IP=${KHAREJ_IP}
HYSTERIA_PORT=${HYSTERIA_PORT}
HYSTERIA_PASSWORD=${HYSTERIA_PASSWORD}
OBFS_PASSWORD=${OBFS_PASSWORD}
NET_IFACE=${NET_IFACE}
V2RAY_PORTS=${V2RAY_PORTS}
CFEOF
    chmod 600 "$CONFIG_FILE"
}

is_installed() {
    [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE" 2>/dev/null && [[ "${INSTALLED:-0}" == "1" ]]
}

gen_pass() {
    openssl rand -base64 48 2>/dev/null | tr -dc 'A-Za-z0-9' | head -c "${1:-24}"
}

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2" >> "$LOG_FILE"
}

# ─── Server Info Display ──────────────────────
show_server_info() {
    local pub_ip iface link_spd uptime_str
    pub_ip=$(get_public_ip)
    iface=$(detect_interface)
    link_spd=$(get_link_speed)
    uptime_str=$(uptime -p 2>/dev/null | sed 's/up //' || echo "N/A")

    local cpu_pct mem_used mem_total mem_pct disk_pct
    cpu_pct=$(awk '/^cpu /{u=$2+$4; t=$2+$4+$5; if(t>0) printf "%.0f", u*100/t; else print 0}' /proc/stat 2>/dev/null || echo "0")
    mem_used=$(free -m 2>/dev/null | awk '/^Mem:/{print $3}')
    mem_total=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
    mem_used=${mem_used:-0}
    mem_total=${mem_total:-1}
    mem_pct=0
    (( mem_total > 0 )) && mem_pct=$(( mem_used * 100 / mem_total ))
    disk_pct=$(df / 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}')
    disk_pct=${disk_pct:-0}

    local role_label="Not Configured" role_color="$YLW"
    if is_installed; then
        load_config
        if [[ "$SERVER_ROLE" == "iran" ]]; then
            role_label="IRAN (Entry)"
            role_color="$GRN"
        else
            role_label="KHAREJ (Exit)"
            role_color="$CYN"
        fi
    fi

    local box_w=$(( TERM_WIDTH - 4 ))

    printf "\n${G3}  ╔$(printf '%*s' "$box_w" '' | tr ' ' '═')╗${RST}\n"
    printf "  ${G3}║${RST} ${G5}IP:${RST} ${G1}${BOLD}%-16s${RST}" "$pub_ip"
    printf " ${G5}IF:${RST} ${GR1}%-8s${RST}" "$iface"
    printf " ${G5}BW:${RST} ${GRN}${BOLD}%-10s${RST}" "$link_spd"
    printf " ${G5}Role:${RST} ${role_color}%-12s${RST}" "$role_label"
    printf "${G3}║${RST}\n"
    printf "  ${G3}║${RST} ${G5}Uptime:${RST} ${GR1}%-${box_w}s${RST}\n" "$uptime_str"
    printf "  ${G3}╠$(printf '%*s' "$box_w" '' | tr ' ' '═')╣${RST}\n"

    local bar_w=18

    local cpu_filled=$(( cpu_pct * bar_w / 100 ))
    (( cpu_filled > bar_w )) && cpu_filled=$bar_w
    local cpu_empty=$(( bar_w - cpu_filled ))
    local cpu_c="$GRN"; (( cpu_pct > 70 )) && cpu_c="$YLW"; (( cpu_pct > 90 )) && cpu_c="$RED"

    local ram_filled=$(( mem_pct * bar_w / 100 ))
    (( ram_filled > bar_w )) && ram_filled=$bar_w
    local ram_empty=$(( bar_w - ram_filled ))
    local ram_c="$GRN"; (( mem_pct > 70 )) && ram_c="$YLW"; (( mem_pct > 90 )) && ram_c="$RED"

    local dsk_filled=$(( disk_pct * bar_w / 100 ))
    (( dsk_filled > bar_w )) && dsk_filled=$bar_w
    local dsk_empty=$(( bar_w - dsk_filled ))
    local dsk_c="$GRN"; (( disk_pct > 70 )) && dsk_c="$YLW"; (( disk_pct > 90 )) && dsk_c="$RED"

    printf "  ${G3}║${RST} ${GR3}CPU${RST} ${cpu_c}"
    for (( i=0; i<cpu_filled; i++ )); do printf "█"; done
    printf "${GR5}"; for (( i=0; i<cpu_empty; i++ )); do printf "░"; done
    printf "${RST}${cpu_c}%3d%%${RST}" "$cpu_pct"

    printf " ${GR3}RAM${RST} ${ram_c}"
    for (( i=0; i<ram_filled; i++ )); do printf "█"; done
    printf "${GR5}"; for (( i=0; i<ram_empty; i++ )); do printf "░"; done
    printf "${RST}${ram_c}%3d%%${RST}" "$mem_pct"

    printf " ${GR3}DSK${RST} ${dsk_c}"
    for (( i=0; i<dsk_filled; i++ )); do printf "█"; done
    printf "${GR5}"; for (( i=0; i<dsk_empty; i++ )); do printf "░"; done
    printf "${RST}${dsk_c}%3d%%${RST}" "$disk_pct"

    printf " ${G3}║${RST}\n"
    printf "  ${G3}╚$(printf '%*s' "$box_w" '' | tr ' ' '═')╝${RST}\n"
}

# ─── Kernel Optimization ──────────────────────
apply_kernel() {
    cat > /etc/sysctl.d/99-vira-tunnel.conf << 'KEOF'
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_keepalive_time=60
net.ipv4.tcp_keepalive_intvl=10
net.ipv4.tcp_keepalive_probes=6
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_max_syn_backlog=65536
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_max_tw_buckets=2000000
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.core.rmem_default=2097152
net.core.wmem_default=2097152
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
net.core.netdev_max_backlog=65536
net.core.somaxconn=65535
net.core.optmem_max=25165824
net.netfilter.nf_conntrack_max=2000000
net.netfilter.nf_conntrack_tcp_timeout_established=7200
net.netfilter.nf_conntrack_udp_timeout=60
net.netfilter.nf_conntrack_udp_timeout_stream=180
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.rp_filter=1
net.ipv4.icmp_echo_ignore_broadcasts=1
KEOF
    sysctl --system > /dev/null 2>&1
    msg_ok "Kernel optimized (BBR + TCP/UDP tuning)"
    log_msg "INFO" "Kernel optimization applied"
}

# ─── Install Prerequisites ────────────────────
install_prereqs() {
    local role="$1"
    export DEBIAN_FRONTEND=noninteractive
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections 2>/dev/null
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections 2>/dev/null

    apt-get update -qq > /dev/null 2>&1 &
    spinner $! "Updating package lists..."
    msg_ok "Package lists updated"

    local pkgs="curl wget net-tools openssl iproute2 jq iptables-persistent socat mtr-tiny iperf3 bc ethtool"
    [[ "$role" == "iran" ]] && pkgs+=" haproxy"

    apt-get install -y -qq $pkgs > /dev/null 2>&1 &
    spinner $! "Installing packages..."
    msg_ok "All packages installed"

    modprobe ip_gre 2>/dev/null || true
    modprobe nf_conntrack 2>/dev/null || true
    grep -q "^ip_gre" /etc/modules 2>/dev/null || echo "ip_gre" >> /etc/modules
    grep -q "^nf_conntrack" /etc/modules 2>/dev/null || echo "nf_conntrack" >> /etc/modules
    msg_ok "Kernel modules loaded"
    log_msg "INFO" "Prerequisites installed (role=$role)"
}

# ─── GRE Tunnel ────────────────────────────────
setup_gre() {
    local role="$1" local_pub="$2" remote_pub="$3"
    local gre_local gre_remote
    if [[ "$role" == "iran" ]]; then
        gre_local="$GRE_IRAN"
        gre_remote="$GRE_KHAREJ"
    else
        gre_local="$GRE_KHAREJ"
        gre_remote="$GRE_IRAN"
    fi

    ip tunnel del gre1 2>/dev/null || true

    cat > /etc/systemd/system/vira-gre.service << EOF
[Unit]
Description=VIRA GRE Tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/ip tunnel add gre1 mode gre remote ${remote_pub} local ${local_pub} ttl 255
ExecStart=/sbin/ip addr add ${gre_local}/30 dev gre1
ExecStart=/sbin/ip link set gre1 up
ExecStart=/sbin/ip link set gre1 mtu 1400
ExecStop=/sbin/ip tunnel del gre1

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable vira-gre.service > /dev/null 2>&1
    systemctl restart vira-gre.service 2>/dev/null
    sleep 2

    if ip link show gre1 &>/dev/null; then
        msg_ok "GRE tunnel UP (${gre_local} <-> ${gre_remote})"
    else
        msg_err "GRE tunnel creation FAILED"
        return 1
    fi
    log_msg "INFO" "GRE tunnel: ${gre_local} <-> ${gre_remote}"
}

# ─── Hysteria2 Server (Kharej) ────────────────
setup_hy2_server() {
    local port="$1" pass="$2" obfs="$3"

    bash <(curl -fsSL https://get.hy2.sh/) > /dev/null 2>&1 &
    spinner $! "Installing Hysteria2..."
    msg_ok "Hysteria2 binary installed"

    mkdir -p "$HYSTERIA_DIR"
    openssl req -x509 -nodes \
        -newkey ec:<(openssl ecparam -name prime256v1) \
        -keyout "${HYSTERIA_DIR}/server.key" \
        -out "${HYSTERIA_DIR}/server.crt" \
        -subj "/CN=www.microsoft.com" -days 36500 2>/dev/null
    chmod 644 "${HYSTERIA_DIR}/server.crt"
    chmod 600 "${HYSTERIA_DIR}/server.key"
    msg_ok "TLS certificate generated"

    cat > "${HYSTERIA_DIR}/config.yaml" << EOF
listen: :${port}

tls:
  cert: ${HYSTERIA_DIR}/server.crt
  key: ${HYSTERIA_DIR}/server.key

obfs:
  type: salamander
  salamander:
    password: "${obfs}"

auth:
  type: password
  password: "${pass}"

quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520

bandwidth:
  up: 1 gbps
  down: 1 gbps

masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true

disablePathMTUDiscovery: false
EOF

    cat > /etc/systemd/system/vira-hysteria.service << 'EOF'
[Unit]
Description=VIRA Hysteria2 Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable vira-hysteria.service > /dev/null 2>&1
    systemctl restart vira-hysteria.service
    sleep 2

    if systemctl is-active --quiet vira-hysteria.service; then
        msg_ok "Hysteria2 Server RUNNING (port ${port}/UDP)"
    else
        msg_err "Hysteria2 Server FAILED to start"
        journalctl -u vira-hysteria --no-pager -n 5
        return 1
    fi
    log_msg "INFO" "Hysteria2 server on port ${port}"
}

# ─── Hysteria2 Client (Iran) ──────────────────
setup_hy2_client() {
    local kharej_ip="$1" port="$2" pass="$3" obfs="$4" ports_csv="$5"

    bash <(curl -fsSL https://get.hy2.sh/) > /dev/null 2>&1 &
    spinner $! "Installing Hysteria2..."
    msg_ok "Hysteria2 binary installed"

    mkdir -p "$HYSTERIA_DIR"

    cat > "${HYSTERIA_DIR}/config.yaml" << EOF
server: ${kharej_ip}:${port}

auth: "${pass}"

obfs:
  type: salamander
  salamander:
    password: "${obfs}"

tls:
  insecure: true

quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520

bandwidth:
  up: 200 mbps
  down: 200 mbps

fastOpen: true

EOF

    echo "tcpForwarding:" >> "${HYSTERIA_DIR}/config.yaml"
    local IFS_BAK="$IFS"
    IFS=',' read -ra PLIST <<< "$ports_csv"
    IFS="$IFS_BAK"
    for p in "${PLIST[@]}"; do
        p=$(echo "$p" | tr -d ' ')
        local lp=$(( 20000 + p ))
        echo "  - listen: 127.0.0.1:${lp}" >> "${HYSTERIA_DIR}/config.yaml"
        echo "    remote: 127.0.0.1:${p}" >> "${HYSTERIA_DIR}/config.yaml"
    done

    echo "" >> "${HYSTERIA_DIR}/config.yaml"
    echo "udpForwarding:" >> "${HYSTERIA_DIR}/config.yaml"
    for p in "${PLIST[@]}"; do
        p=$(echo "$p" | tr -d ' ')
        local lp=$(( 20000 + p ))
        echo "  - listen: 127.0.0.1:${lp}" >> "${HYSTERIA_DIR}/config.yaml"
        echo "    remote: 127.0.0.1:${p}" >> "${HYSTERIA_DIR}/config.yaml"
    done

    cat > /etc/systemd/system/vira-hysteria.service << 'EOF'
[Unit]
Description=VIRA Hysteria2 Client
After=network-online.target vira-gre.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria client -c /etc/hysteria/config.yaml
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable vira-hysteria.service > /dev/null 2>&1
    systemctl restart vira-hysteria.service
    sleep 3

    if systemctl is-active --quiet vira-hysteria.service; then
        msg_ok "Hysteria2 Client RUNNING"
    else
        msg_err "Hysteria2 Client FAILED to start"
        journalctl -u vira-hysteria --no-pager -n 5
        return 1
    fi
    log_msg "INFO" "Hysteria2 client configured"
}

# ─── HAProxy (Iran) ───────────────────────────
setup_haproxy() {
    local ports_csv="$1"
    cp /etc/haproxy/haproxy.cfg "/etc/haproxy/haproxy.cfg.bak.$(date +%s)" 2>/dev/null || true

    cat > /etc/haproxy/haproxy.cfg << 'HAHDR'
# VIRA TUNNEL - HAProxy Config (auto-generated)
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 100000
    tune.bufsize 32768
    nbthread 4

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    option  tcp-smart-accept
    option  tcp-smart-connect
    timeout connect 10s
    timeout client  300s
    timeout server  300s
    timeout tunnel  3600s
    timeout client-fin 30s
    timeout server-fin 30s
    retries 3
    option  redispatch

listen stats
    bind 127.0.0.1:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 5s
    stats admin if TRUE

HAHDR

    local IFS_BAK="$IFS"
    IFS=',' read -ra PLIST <<< "$ports_csv"
    IFS="$IFS_BAK"
    for p in "${PLIST[@]}"; do
        p=$(echo "$p" | tr -d ' ')
        local lp=$(( 20000 + p ))
        cat >> /etc/haproxy/haproxy.cfg << EOF

frontend ft_${p}
    bind *:${p}
    mode tcp
    tcp-request inspect-delay 5s
    tcp-request content accept if { req.len gt 0 }
    default_backend bk_${p}

backend bk_${p}
    mode tcp
    balance first
    option tcp-check
    server hy2-${p} 127.0.0.1:${lp} check inter 3s fall 3 rise 2 weight 100
    server gre-${p} ${GRE_KHAREJ}:${p} check inter 3s fall 3 rise 2 weight 50 backup
EOF
    done

    if haproxy -c -f /etc/haproxy/haproxy.cfg > /dev/null 2>&1; then
        systemctl restart haproxy
        systemctl enable haproxy > /dev/null 2>&1
        sleep 1
        if systemctl is-active --quiet haproxy; then
            msg_ok "HAProxy RUNNING (${#PLIST[@]} ports configured)"
        else
            msg_err "HAProxy failed to start"
            return 1
        fi
    else
        msg_err "HAProxy config validation FAILED"
        haproxy -c -f /etc/haproxy/haproxy.cfg 2>&1 | head -5
        return 1
    fi
    log_msg "INFO" "HAProxy configured: ${ports_csv}"
}

# ─── iptables Iran ─────────────────────────────
setup_ipt_iran() {
    local kharej_ip="$1" hy_port="$2" ports_csv="$3" iface="$4"

    iptables -F; iptables -t nat -F; iptables -t mangle -F
    iptables -P INPUT ACCEPT; iptables -P FORWARD ACCEPT; iptables -P OUTPUT ACCEPT

    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    iptables -A INPUT -p gre -s "${kharej_ip}" -j ACCEPT
    iptables -A OUTPUT -p gre -d "${kharej_ip}" -j ACCEPT
    iptables -A OUTPUT -p udp --dport "${hy_port}" -d "${kharej_ip}" -j ACCEPT
    iptables -A FORWARD -i gre1 -j ACCEPT
    iptables -A FORWARD -o gre1 -j ACCEPT
    iptables -t nat -A POSTROUTING -s ${GRE_SUBNET} -j MASQUERADE
    iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    iptables -t mangle -A OUTPUT -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1360
    iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
    iptables -A FORWARD -m conntrack --ctstate INVALID -j DROP
    iptables -A INPUT -p tcp --syn -m limit --limit 200/s --limit-burst 400 -j ACCEPT

    local IFS_BAK="$IFS"; IFS=',' read -ra PLIST <<< "$ports_csv"; IFS="$IFS_BAK"
    for p in "${PLIST[@]}"; do
        p=$(echo "$p" | tr -d ' ')
        iptables -A INPUT -p tcp --dport "$p" -j ACCEPT
    done
    iptables -A INPUT -p tcp --dport 8404 -s 127.0.0.1 -j ACCEPT

    netfilter-persistent save > /dev/null 2>&1
    msg_ok "iptables rules applied (Iran)"
    log_msg "INFO" "iptables Iran configured"
}

# ─── iptables Kharej ───────────────────────────
setup_ipt_kharej() {
    local iran_ip="$1" hy_port="$2" ports_csv="$3" iface="$4"

    iptables -F; iptables -t nat -F; iptables -t mangle -F
    iptables -P INPUT ACCEPT; iptables -P FORWARD ACCEPT; iptables -P OUTPUT ACCEPT

    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    iptables -A INPUT -p gre -s "${iran_ip}" -j ACCEPT
    iptables -A OUTPUT -p gre -d "${iran_ip}" -j ACCEPT
    iptables -A INPUT -p udp --dport "${hy_port}" -j ACCEPT
    iptables -A FORWARD -i gre1 -j ACCEPT
    iptables -A FORWARD -o gre1 -j ACCEPT
    iptables -t nat -A POSTROUTING -s ${GRE_SUBNET} -o "${iface}" -j MASQUERADE
    iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

    local IFS_BAK="$IFS"; IFS=',' read -ra PLIST <<< "$ports_csv"; IFS="$IFS_BAK"
    for p in "${PLIST[@]}"; do
        p=$(echo "$p" | tr -d ' ')
        iptables -A INPUT -p tcp --dport "$p" -j ACCEPT
    done

    netfilter-persistent save > /dev/null 2>&1
    msg_ok "iptables rules applied (Kharej)"
    log_msg "INFO" "iptables Kharej configured"
}

# ─── Watchdog ──────────────────────────────────
setup_watchdog() {
    cat > "$WATCHDOG_SCRIPT" << WEOF
#!/bin/bash
LOG="/var/log/vira-watchdog.log"
ts() { echo "\$(date '+%Y-%m-%d %H:%M:%S') \$1" >> "\$LOG"; }
if ! systemctl is-active --quiet vira-hysteria 2>/dev/null; then
    ts "WARN: Hysteria2 down, restarting"; systemctl restart vira-hysteria 2>/dev/null
fi
if ! ping -c1 -W3 ${GRE_KHAREJ} &>/dev/null && ! ping -c1 -W3 ${GRE_IRAN} &>/dev/null; then
    ts "WARN: GRE down, restarting"; systemctl restart vira-gre 2>/dev/null
fi
if systemctl list-units --type=service 2>/dev/null | grep -q haproxy; then
    if ! systemctl is-active --quiet haproxy 2>/dev/null; then
        ts "WARN: HAProxy down, restarting"; systemctl restart haproxy 2>/dev/null
    fi
fi
[[ \$(wc -l < "\$LOG" 2>/dev/null || echo 0) -gt 10000 ]] && tail -5000 "\$LOG" > "\${LOG}.tmp" && mv "\${LOG}.tmp" "\$LOG"
WEOF
    chmod +x "$WATCHDOG_SCRIPT"
    ( crontab -l 2>/dev/null | grep -v "vira-watchdog"; echo "*/2 * * * * ${WATCHDOG_SCRIPT}" ) | crontab -
    msg_ok "Watchdog enabled (every 2 min)"
    log_msg "INFO" "Watchdog installed"
}

# ═══════════════════════════════════════════════
#  INSTALL WIZARD
# ═══════════════════════════════════════════════
install_wizard() {
    show_logo
    echo ""
    printf "  ${G2}╔══${BOLD} INSTALLATION WIZARD ${G2}$(printf '%*s' $((TERM_WIDTH - 28)) '' | tr ' ' '═')╗${RST}\n"
    echo ""

    printf "  ${G2}${BOLD}Step 1:${RST} ${GR1}Select this server role${RST}\n\n"
    print_menu "1" "IRAN Server  (Entry Point - users connect here)"
    print_menu "2" "KHAREJ Server (Exit Point - V2Ray panel here)"
    echo ""
    ask "Your choice" ROLE_CHOICE ""
    case "$ROLE_CHOICE" in
        1) SERVER_ROLE="iran" ;;
        2) SERVER_ROLE="kharej" ;;
        *) msg_err "Invalid choice"; return 1 ;;
    esac

    echo ""; print_line

    printf "\n  ${G2}${BOLD}Step 2:${RST} ${GR1}Server IP Addresses${RST}\n\n"
    local my_ip
    my_ip=$(get_public_ip)

    if [[ "$SERVER_ROLE" == "iran" ]]; then
        ask "Iran server public IP (this server)" IRAN_IP "$my_ip"
        ask "Kharej server public IP" KHAREJ_IP ""
    else
        ask "Iran server public IP" IRAN_IP ""
        ask "Kharej server public IP (this server)" KHAREJ_IP "$my_ip"
    fi

    if [[ -z "$IRAN_IP" || -z "$KHAREJ_IP" ]]; then
        msg_err "IPs cannot be empty"; return 1
    fi

    echo ""; print_line

    printf "\n  ${G2}${BOLD}Step 3:${RST} ${GR1}Hysteria2 Settings${RST}\n\n"
    local def_pass def_obfs
    def_pass=$(gen_pass 20)
    def_obfs=$(gen_pass 16)
    ask "Hysteria2 port (UDP)" HYSTERIA_PORT "4443"
    ask "Hysteria2 password" HYSTERIA_PASSWORD "$def_pass"
    ask "Obfuscation password (Salamander)" OBFS_PASSWORD "$def_obfs"

    echo ""; print_line

    printf "\n  ${G2}${BOLD}Step 4:${RST} ${GR1}V2Ray Panel Ports${RST}\n\n"
    msg_info "Enter ports used by your V2Ray panel (comma-separated)"
    msg_info "Example: 443,80,8443,2053,2083,2087,2096,54321"
    echo ""
    ask "V2Ray ports" V2RAY_PORTS "443,80,8443,2053,2083,2087,2096,54321"

    NET_IFACE=$(detect_interface)

    echo ""; print_line

    printf "\n  ${G2}${BOLD}Summary:${RST}\n\n"
    printf "  ${GR4}┌─────────────────────────────────────────────────┐${RST}\n"
    printf "  ${GR4}│${RST}  ${GR3}Role:${RST}          ${G1}%-34s${RST}${GR4}│${RST}\n" "$([ "$SERVER_ROLE" = "iran" ] && echo "IRAN (Entry)" || echo "KHAREJ (Exit)")"
    printf "  ${GR4}│${RST}  ${GR3}Iran IP:${RST}       ${GR1}%-34s${RST}${GR4}│${RST}\n" "$IRAN_IP"
    printf "  ${GR4}│${RST}  ${GR3}Kharej IP:${RST}     ${GR1}%-34s${RST}${GR4}│${RST}\n" "$KHAREJ_IP"
    printf "  ${GR4}│${RST}  ${GR3}GRE Iran:${RST}      ${GR1}%-34s${RST}${GR4}│${RST}\n" "$GRE_IRAN"
    printf "  ${GR4}│${RST}  ${GR3}GRE Kharej:${RST}    ${GR1}%-34s${RST}${GR4}│${RST}\n" "$GRE_KHAREJ"
    printf "  ${GR4}│${RST}  ${GR3}Hy2 Port:${RST}      ${GR1}%-34s${RST}${GR4}│${RST}\n" "$HYSTERIA_PORT"
    printf "  ${GR4}│${RST}  ${GR3}V2Ray Ports:${RST}   ${GR1}%-34s${RST}${GR4}│${RST}\n" "$V2RAY_PORTS"
    printf "  ${GR4}│${RST}  ${GR3}Interface:${RST}     ${GR1}%-34s${RST}${GR4}│${RST}\n" "$NET_IFACE"
    printf "  ${GR4}└─────────────────────────────────────────────────┘${RST}\n"
    echo ""

    if ! confirm "Proceed with installation?"; then
        msg_warn "Cancelled"; return 0
    fi

    echo ""
    printf "  ${G1}${BOLD}━━━ Starting Installation ━━━${RST}\n\n"

    local steps
    [[ "$SERVER_ROLE" == "iran" ]] && steps=7 || steps=6
    local s=1

    progress_bar $s $steps "Kernel"
    echo ""
    apply_kernel
    (( s++ ))

    progress_bar $s $steps "Packages"
    echo ""
    install_prereqs "$SERVER_ROLE"
    (( s++ ))

    progress_bar $s $steps "GRE Tunnel"
    echo ""
    if [[ "$SERVER_ROLE" == "iran" ]]; then
        setup_gre "iran" "$IRAN_IP" "$KHAREJ_IP"
    else
        setup_gre "kharej" "$KHAREJ_IP" "$IRAN_IP"
    fi
    (( s++ ))

    progress_bar $s $steps "Hysteria2"
    echo ""
    if [[ "$SERVER_ROLE" == "iran" ]]; then
        setup_hy2_client "$KHAREJ_IP" "$HYSTERIA_PORT" "$HYSTERIA_PASSWORD" "$OBFS_PASSWORD" "$V2RAY_PORTS"
    else
        setup_hy2_server "$HYSTERIA_PORT" "$HYSTERIA_PASSWORD" "$OBFS_PASSWORD"
    fi
    (( s++ ))

    if [[ "$SERVER_ROLE" == "iran" ]]; then
        progress_bar $s $steps "HAProxy"
        echo ""
        setup_haproxy "$V2RAY_PORTS"
        (( s++ ))
    fi

    progress_bar $s $steps "iptables"
    echo ""
    if [[ "$SERVER_ROLE" == "iran" ]]; then
        setup_ipt_iran "$KHAREJ_IP" "$HYSTERIA_PORT" "$V2RAY_PORTS" "$NET_IFACE"
    else
        setup_ipt_kharej "$IRAN_IP" "$HYSTERIA_PORT" "$V2RAY_PORTS" "$NET_IFACE"
    fi
    (( s++ ))

    progress_bar $s $steps "Watchdog"
    echo ""
    setup_watchdog

    save_config

    echo ""
    printf "  ${GRN}${BOLD}━━━ Installation Complete ━━━${RST}\n\n"

    if [[ "$SERVER_ROLE" == "iran" ]]; then
        printf "  ${G5}╔═════════════════════════════════════════════════════╗${RST}\n"
        printf "  ${G5}║${RST}  ${YLW}${BOLD}IMPORTANT:${RST}                                         ${G5}║${RST}\n"
        printf "  ${G5}║${RST}  Run this script on the KHAREJ server too,          ${G5}║${RST}\n"
        printf "  ${G5}║${RST}  using the SAME passwords below:                    ${G5}║${RST}\n"
        printf "  ${G5}║${RST}                                                     ${G5}║${RST}\n"
        printf "  ${G5}║${RST}  ${GR3}Hy2 Password:${RST}  ${G1}%-30s${RST}  ${G5}║${RST}\n" "$HYSTERIA_PASSWORD"
        printf "  ${G5}║${RST}  ${GR3}Obfs Password:${RST} ${G1}%-30s${RST}  ${G5}║${RST}\n" "$OBFS_PASSWORD"
        printf "  ${G5}║${RST}                                                     ${G5}║${RST}\n"
        printf "  ${G5}║${RST}  ${GRN}In V2Ray configs, use Iran IP: ${G1}${BOLD}%-15s${RST}  ${G5}║${RST}\n" "$IRAN_IP"
        printf "  ${G5}╚═════════════════════════════════════════════════════╝${RST}\n"
    else
        printf "  ${G5}╔═════════════════════════════════════════════════════╗${RST}\n"
        printf "  ${G5}║${RST}  ${GRN}Kharej server is ready!${RST}                              ${G5}║${RST}\n"
        printf "  ${G5}║${RST}  Now run this script on the Iran server too.         ${G5}║${RST}\n"
        printf "  ${G5}╚═════════════════════════════════════════════════════╝${RST}\n"
    fi
    press_key
}

# ═══════════════════════════════════════════════
#  STATUS with Charts
# ═══════════════════════════════════════════════
show_status() {
    show_logo
    load_config
    if ! is_installed; then msg_warn "Tunnel not installed"; press_key; return; fi

    printf "\n  ${G2}╔══${BOLD} SERVICE STATUS ${G2}$(printf '%*s' $((TERM_WIDTH - 22)) '' | tr ' ' '═')╗${RST}\n"
    echo ""

    local peer_ip
    [[ "$SERVER_ROLE" == "iran" ]] && peer_ip="$GRE_KHAREJ" || peer_ip="$GRE_IRAN"

    local gre_s="DOWN"
    if ip link show gre1 &>/dev/null; then
        ping -c1 -W2 "$peer_ip" &>/dev/null && gre_s="UP" || gre_s="LINK UP (no ping)"
    fi
    print_stat "GRE Tunnel ($peer_ip)" "$gre_s" "🔗"

    local hy_s="DEAD"
    systemctl is-active --quiet vira-hysteria 2>/dev/null && hy_s="RUNNING"
    print_stat "Hysteria2" "$hy_s" "🚀"

    if [[ "$SERVER_ROLE" == "iran" ]]; then
        local ha_s="DEAD"
        systemctl is-active --quiet haproxy 2>/dev/null && ha_s="RUNNING"
        print_stat "HAProxy" "$ha_s" "⚖️"
    fi

    local ipt_n
    ipt_n=$(iptables -L -n 2>/dev/null | wc -l)
    (( ipt_n > 10 )) && print_stat "iptables" "ACTIVE (${ipt_n} rules)" "🛡️" || print_stat "iptables" "MINIMAL" "🛡️"

    local wd_s="INACTIVE"
    crontab -l 2>/dev/null | grep -q "vira-watchdog" && wd_s="ACTIVE"
    print_stat "Watchdog" "$wd_s" "🐕"

    if [[ "$SERVER_ROLE" == "iran" ]] && [[ -S /run/haproxy/admin.sock ]]; then
        echo ""
        printf "  ${G3}├── ${G2}${BOLD}HAProxy Backends${RST}\n"
        echo "show stat" | socat /run/haproxy/admin.sock stdio 2>/dev/null | \
        grep -E "^bk_" | while IFS=',' read -r px sv _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ st _rest; do
            local ic
            [[ "$st" == "UP" ]] && ic="${GRN}█ UP  ${RST}" || ic="${RED}█ DOWN${RST}"
            printf "  ${GR4}│${RST}     ${ic} ${GR2}%-25s${RST}\n" "${sv}"
        done
    fi

    echo ""
    printf "  ${G3}├── ${G2}${BOLD}System Resources${RST}\n"

    local cpu_pct
    cpu_pct=$(awk '/^cpu /{u=$2+$4;t=$2+$4+$5;if(t>0)printf "%.0f",u*100/t;else print 0}' /proc/stat 2>/dev/null || echo 0)
    draw_bar "$cpu_pct" 100 25 "CPU"

    local mem_u mem_t
    mem_u=$(free -m 2>/dev/null | awk '/^Mem:/{print $3}')
    mem_t=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
    mem_u=${mem_u:-0}; mem_t=${mem_t:-1}
    draw_bar "$mem_u" "$mem_t" 25 "Memory"

    local dsk_pct
    dsk_pct=$(df / 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5);print $5}')
    dsk_pct=${dsk_pct:-0}
    draw_bar "$dsk_pct" 100 25 "Disk"

    if [[ -f /proc/sys/net/netfilter/nf_conntrack_count ]]; then
        local ct_c ct_m
        ct_c=$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo 0)
        ct_m=$(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || echo 1)
        draw_bar "$ct_c" "$ct_m" 25 "Conntrack"
    fi

    echo ""
    printf "  ${G3}├── ${G2}${BOLD}Network Traffic${RST}\n"

    if ip link show gre1 &>/dev/null; then
        local grx gtx
        grx=$(cat /sys/class/net/gre1/statistics/rx_bytes 2>/dev/null || echo 0)
        gtx=$(cat /sys/class/net/gre1/statistics/tx_bytes 2>/dev/null || echo 0)
        printf "  ${GR4}│${RST}  ${GR3}GRE  RX:${RST} ${G1}$(format_bytes "$grx")${RST}    ${GR3}TX:${RST} ${G1}$(format_bytes "$gtx")${RST}\n"
    fi

    local estab
    estab=$(ss -t state established 2>/dev/null | tail -n +2 | wc -l)
    printf "  ${GR4}│${RST}  ${GR3}Established TCP:${RST} ${G1}${estab}${RST}\n"

    local load_a
    load_a=$(awk '{print $1" "$2" "$3}' /proc/loadavg 2>/dev/null || echo "N/A")
    printf "  ${GR4}│${RST}  ${GR3}Load Average:${RST}    ${G1}${load_a}${RST}\n"

    echo ""
    printf "  ${G2}╚$(printf '%*s' $((TERM_WIDTH - 4)) '' | tr ' ' '═')╝${RST}\n"
    press_key
}

# ═══════════════════════════════════════════════
#  PING & PACKET LOSS
# ═══════════════════════════════════════════════
test_ping() {
    show_logo
    load_config

    printf "\n  ${G2}╔══${BOLD} PING & PACKET LOSS TEST ${G2}$(printf '%*s' $((TERM_WIDTH - 30)) '' | tr ' ' '═')╗${RST}\n\n"

    local targets=() labels=()
    if is_installed; then
        if [[ "$SERVER_ROLE" == "iran" ]]; then
            targets+=("$GRE_KHAREJ" "$KHAREJ_IP" "8.8.8.8" "1.1.1.1")
            labels+=("GRE Tunnel ($GRE_KHAREJ)" "Kharej (Direct)" "Google DNS" "Cloudflare DNS")
        else
            targets+=("$GRE_IRAN" "$IRAN_IP" "8.8.8.8" "1.1.1.1")
            labels+=("GRE Tunnel ($GRE_IRAN)" "Iran (Direct)" "Google DNS" "Cloudflare DNS")
        fi
    else
        targets+=("8.8.8.8" "1.1.1.1" "4.2.2.4")
        labels+=("Google DNS" "Cloudflare DNS" "Level3 DNS")
    fi

    local pkt_count=20
    msg_info "Sending ${pkt_count} packets to each target..."
    echo ""

    for i in "${!targets[@]}"; do
        local tgt="${targets[$i]}" lbl="${labels[$i]}"
        printf "  ${G2}▸${RST}  ${GR1}${lbl}${RST} ${GR4}(${tgt})${RST}\n"

        local res
        res=$(ping -c "$pkt_count" -W 3 -q "$tgt" 2>&1)

        if echo "$res" | grep -q "packets transmitted"; then
            local sent rcvd loss
            sent=$(echo "$res" | awk '/transmitted/{print $1}')
            rcvd=$(echo "$res" | awk '/transmitted/{print $4}')
            loss=$(echo "$res" | grep -oP '\d+(\.\d+)?%' | head -1)
            local loss_n=${loss%%%*}
            loss_n=${loss_n%%.*}

            local lc="$GRN"
            (( loss_n > 0 )) && lc="$YLW"
            (( loss_n > 5 )) && lc="$RED"

            printf "     ${GR3}├─${RST} ${GR3}Sent:${RST} ${G1}${sent}${RST}  ${GR3}Recv:${RST} ${G1}${rcvd}${RST}  ${GR3}Loss:${RST} ${lc}${BOLD}${loss}${RST}\n"

            local rtt_line
            rtt_line=$(echo "$res" | grep -E "rtt|round-trip")
            if [[ -n "$rtt_line" ]]; then
                local mn avg mx
                mn=$(echo "$rtt_line" | awk -F'[/ =]' '{for(i=1;i<=NF;i++)if($i~/^[0-9]+\.[0-9]+$/){print $i;exit}}')
                avg=$(echo "$rtt_line" | awk -F'/' '{print $5}')
                mx=$(echo "$rtt_line" | awk -F'/' '{print $6}' | awk '{print $1}')

                local pc="$GRN"
                local avg_i=${avg%%.*}
                (( avg_i > 50 )) && pc="$YLW"
                (( avg_i > 150 )) && pc="$RED"

                local lat_bar_w=20
                local lat_fill=$(( avg_i * lat_bar_w / 300 ))
                (( lat_fill > lat_bar_w )) && lat_fill=$lat_bar_w
                local lat_empty=$(( lat_bar_w - lat_fill ))

                printf "     ${GR3}└─${RST} ${GR3}Min:${RST} ${GR1}${mn}ms${RST}  ${GR3}Avg:${RST} ${pc}${BOLD}${avg}ms${RST}  ${GR3}Max:${RST} ${GR1}${mx}ms${RST}  "
                printf "${pc}"
                for (( j=0; j<lat_fill; j++ )); do printf "█"; done
                printf "${GR5}"
                for (( j=0; j<lat_empty; j++ )); do printf "░"; done
                printf "${RST}\n"
            fi
        else
            printf "     ${GR3}└─${RST} ${RED}${BOLD}Unreachable${RST}\n"
        fi
        echo ""
    done
    press_key
}

# ═══════════════════════════════════════════════
#  SPEED TEST
# ═══════════════════════════════════════════════
test_speed() {
    show_logo
    load_config

    printf "\n  ${G2}╔══${BOLD} SPEED TEST ${G2}$(printf '%*s' $((TERM_WIDTH - 18)) '' | tr ' ' '═')╗${RST}\n\n"

    print_menu "1" "Internet Speed Test (speedtest-cli)" "🌐"
    print_menu "2" "GRE Tunnel Speed (iperf3)" "🔗"
    print_menu "3" "Simple Download Test (curl)" "📥"
    print_menu "0" "Back" "↩️"
    echo ""
    ask "Choice" sp_ch ""

    case "$sp_ch" in
        1)
            echo ""
            if ! command -v speedtest-cli &>/dev/null; then
                msg_info "Installing speedtest-cli..."
                pip3 install speedtest-cli > /dev/null 2>&1 || apt-get install -y -qq speedtest-cli > /dev/null 2>&1
            fi
            if command -v speedtest-cli &>/dev/null; then
                msg_info "Running speed test... (may take 30 seconds)"
                echo ""
                local sres
                sres=$(speedtest-cli --simple 2>&1)
                echo "$sres" | while IFS=: read -r key val; do
                    key=$(echo "$key" | xargs)
                    val=$(echo "$val" | xargs)
                    case "$key" in
                        Ping)     printf "  ${G5}📡${RST}  ${GR3}Ping:${RST}     ${G1}${BOLD}%s${RST}\n" "$val" ;;
                        Download) printf "  ${G5}📥${RST}  ${GR3}Download:${RST} ${GRN}${BOLD}%s${RST}\n" "$val" ;;
                        Upload)   printf "  ${G5}📤${RST}  ${GR3}Upload:${RST}   ${CYN}${BOLD}%s${RST}\n" "$val" ;;
                    esac
                done
            else
                msg_err "Could not install speedtest-cli"
            fi
            ;;
        2)
            echo ""
            if ! is_installed; then msg_warn "Install tunnel first"; press_key; return; fi
            local pr_ip
            [[ "$SERVER_ROLE" == "iran" ]] && pr_ip="$GRE_KHAREJ" || pr_ip="$GRE_IRAN"
            msg_info "GRE tunnel speed test to $pr_ip"
            msg_info "Run 'iperf3 -s' on the other server first"
            echo ""
            if confirm "Is iperf3 -s running on the other server?"; then
                echo ""
                printf "  ${G2}${BOLD}TCP Test:${RST}\n"
                iperf3 -c "$pr_ip" -t 10 -P 4 2>&1 | tail -5 | while IFS= read -r l; do
                    printf "  ${GR2}  %s${RST}\n" "$l"
                done
                echo ""
                printf "  ${G2}${BOLD}UDP Test:${RST}\n"
                iperf3 -c "$pr_ip" -t 10 -u -b 100M 2>&1 | tail -5 | while IFS= read -r l; do
                    printf "  ${GR2}  %s${RST}\n" "$l"
                done
            fi
            ;;
        3)
            echo ""
            msg_info "Download test..."
            echo ""
            local urls=("https://speed.cloudflare.com/__down?bytes=10000000" "https://proof.ovh.net/files/10Mb.dat")
            local names=("Cloudflare 10MB" "OVH 10MB")
            for i in "${!urls[@]}"; do
                printf "  ${G5}▸${RST}  ${GR2}${names[$i]}:${RST} "
                local sp
                sp=$(curl -4so /dev/null -w "%{speed_download}" -A "curl/8.0" --max-time 30 "${urls[$i]}" 2>/dev/null)
                if [[ -n "$sp" ]] && (( $(echo "$sp > 0" | bc -l 2>/dev/null || echo 0) )); then
                    local mbps
                    mbps=$(echo "scale=2; $sp / 1048576" | bc 2>/dev/null || echo "N/A")
                    printf "${GRN}${BOLD}%s MB/s${RST}\n" "$mbps"
                else
                    printf "${RED}Failed${RST}\n"
                fi
            done
            ;;
        0) return ;;
    esac
    press_key
}

# ═══════════════════════════════════════════════
#  LIVE MONITORING
# ═══════════════════════════════════════════════
live_monitor() {
    load_config
    if ! is_installed; then msg_warn "Install tunnel first"; press_key; return; fi

    local peer_ip
    [[ "$SERVER_ROLE" == "iran" ]] && peer_ip="$GRE_KHAREJ" || peer_ip="$GRE_IRAN"

    cat > /tmp/vira_mon.sh << 'MEOF'
#!/bin/bash
PEER="$1"; ROLE="$2"
R='\033[0m'; B='\033[1m'; G='\033[38;5;46m'; RD='\033[38;5;196m'; Y='\033[38;5;226m'
GL='\033[38;5;214m'; GR='\033[38;5;245m'; GK='\033[38;5;240m'; C='\033[38;5;51m'; W='\033[38;5;255m'

clear
echo ""
printf "${GL}${B}  ╔═══ VIRA TUNNEL ═══ Live Monitor ════════════════════════╗${R}\n"
printf "${GL}  ║${R}  ${GR}%s${R}   ${GR}Role: ${C}%s${R}                            ${GL}║${R}\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$ROLE"
printf "${GL}${B}  ╚════════════════════════════════════════════════════════════╝${R}\n\n"

printf "  ${GL}━━━ Services ━━━${R}\n"
for svc in vira-gre vira-hysteria haproxy; do
    if systemctl list-units --type=service 2>/dev/null | grep -q "$svc"; then
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            printf "  ${G}●${R} %-20s ${G}RUNNING${R}\n" "$svc"
        else
            printf "  ${RD}●${R} %-20s ${RD}DEAD${R}\n" "$svc"
        fi
    fi
done

echo ""
printf "  ${GL}━━━ GRE Tunnel ━━━${R}\n"
if ip link show gre1 &>/dev/null; then
    P=$(ping -c1 -W1 "$PEER" 2>/dev/null | grep -oP 'time=\K[0-9.]+')
    if [[ -n "$P" ]]; then
        PC="${G}"; PI=${P%%.*}
        (( PI > 50 )) && PC="${Y}"; (( PI > 150 )) && PC="${RD}"
        BW=15; BF=$((PI * BW / 300)); (( BF > BW )) && BF=$BW; BE=$((BW - BF))
        printf "  ${G}●${R} Peer: ${W}%s${R}  Latency: ${PC}${B}%s ms${R}  " "$PEER" "$P"
        printf "${PC}"; for ((i=0;i<BF;i++)); do printf "█"; done
        printf "${GK}"; for ((i=0;i<BE;i++)); do printf "░"; done; printf "${R}\n"
    else
        printf "  ${RD}●${R} Peer: ${W}%s${R}  ${RD}No Response${R}\n" "$PEER"
    fi
    RX=$(cat /sys/class/net/gre1/statistics/rx_bytes 2>/dev/null || echo 0)
    TX=$(cat /sys/class/net/gre1/statistics/tx_bytes 2>/dev/null || echo 0)
    RH=$(numfmt --to=iec-i --suffix=B "$RX" 2>/dev/null || echo "${RX}B")
    TH=$(numfmt --to=iec-i --suffix=B "$TX" 2>/dev/null || echo "${TX}B")
    printf "  📥 RX: ${W}%-14s${R} 📤 TX: ${W}%-14s${R}\n" "$RH" "$TH"
else
    printf "  ${RD}●${R} GRE: ${RD}DOWN${R}\n"
fi

echo ""
printf "  ${GL}━━━ Resources ━━━${R}\n"
CPU=$(awk '/^cpu /{u=$2+$4;t=$2+$4+$5;if(t>0)printf "%.0f",u*100/t;else print 0}' /proc/stat 2>/dev/null || echo 0)
MU=$(free -m 2>/dev/null | awk '/^Mem:/{print $3}')
MT=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
MU=${MU:-0}; MT=${MT:-1}
MP=0; (( MT > 0 )) && MP=$((MU*100/MT))

BW=20
CF=$((CPU*BW/100)); CE=$((BW-CF)); CC="${G}"; ((CPU>70))&&CC="${Y}"; ((CPU>90))&&CC="${RD}"
printf "  CPU  ${CC}"; for((i=0;i<CF;i++)); do printf "█"; done
printf "${GK}"; for((i=0;i<CE;i++)); do printf "░"; done; printf "${R} ${CC}%3d%%${R}  " "$CPU"

MF=$((MP*BW/100)); ME=$((BW-MF)); MC="${G}"; ((MP>70))&&MC="${Y}"; ((MP>90))&&MC="${RD}"
printf "RAM  ${MC}"; for((i=0;i<MF;i++)); do printf "█"; done
printf "${GK}"; for((i=0;i<ME;i++)); do printf "░"; done; printf "${R} ${MC}%3d%%${R}\n" "$MP"

echo ""
printf "  ${GL}━━━ Connections ━━━${R}\n"
EST=$(ss -t state established 2>/dev/null | tail -n+2 | wc -l)
printf "  🔌 Established: ${W}${B}%s${R}\n" "$EST"
LD=$(awk '{print $1" "$2" "$3}' /proc/loadavg 2>/dev/null)
printf "  📊 Load: ${W}%s${R}\n" "$LD"
echo ""
printf "  ${GK}Press Ctrl+C to exit${R}\n"
MEOF
    chmod +x /tmp/vira_mon.sh
    watch -tn 2 -c "bash /tmp/vira_mon.sh '${peer_ip}' '${SERVER_ROLE}'"
}

# ═══════════════════════════════════════════════
#  TROUBLESHOOTING
# ═══════════════════════════════════════════════
troubleshoot() {
    show_logo
    load_config
    if ! is_installed; then msg_warn "Tunnel not installed"; press_key; return; fi

    printf "\n  ${G2}╔══${BOLD} TROUBLESHOOTING ${G2}$(printf '%*s' $((TERM_WIDTH - 24)) '' | tr ' ' '═')╗${RST}\n\n"

    local issues=0
    local peer_ip
    [[ "$SERVER_ROLE" == "iran" ]] && peer_ip="$GRE_KHAREJ" || peer_ip="$GRE_IRAN"

    printf "  ${G2}[1/8]${RST} ${GR2}GRE Interface...${RST}\n"
    if ip link show gre1 &>/dev/null; then
        msg_ok "GRE interface exists"
    else
        msg_err "GRE interface missing"
        printf "       ${YLW}Fix: systemctl restart vira-gre${RST}\n"
        (( issues++ ))
    fi

    printf "  ${G2}[2/8]${RST} ${GR2}GRE Connectivity...${RST}\n"
    if ping -c2 -W3 "$peer_ip" &>/dev/null; then
        msg_ok "GRE ping to ${peer_ip}: OK"
    else
        msg_err "GRE ping to ${peer_ip}: FAILED"
        printf "       ${YLW}Fix: Check firewall & IPs on both servers${RST}\n"
        (( issues++ ))
    fi

    printf "  ${G2}[3/8]${RST} ${GR2}Hysteria2 Service...${RST}\n"
    if systemctl is-active --quiet vira-hysteria 2>/dev/null; then
        msg_ok "Hysteria2: Running"
    else
        msg_err "Hysteria2: Not running"
        printf "       ${YLW}Fix: systemctl restart vira-hysteria${RST}\n"
        journalctl -u vira-hysteria --no-pager -n 3 2>/dev/null | while IFS= read -r l; do
            printf "       ${GR5}%s${RST}\n" "$l"
        done
        (( issues++ ))
    fi

    printf "  ${G2}[4/8]${RST} ${GR2}HAProxy...${RST}\n"
    if [[ "$SERVER_ROLE" == "iran" ]]; then
        if systemctl is-active --quiet haproxy 2>/dev/null; then
            msg_ok "HAProxy: Running"
        else
            msg_err "HAProxy: Not running"
            printf "       ${YLW}Fix: systemctl restart haproxy${RST}\n"
            (( issues++ ))
        fi
    else
        printf "       ${GR4}N/A (Kharej server)${RST}\n"
    fi

    printf "  ${G2}[5/8]${RST} ${GR2}Port Forwarding...${RST}\n"
    if [[ "$SERVER_ROLE" == "iran" ]]; then
        local pok=0 pfail=0
        local IFS_B="$IFS"; IFS=',' read -ra PTS <<< "$V2RAY_PORTS"; IFS="$IFS_B"
        for p in "${PTS[@]}"; do
            p=$(echo "$p" | tr -d ' ')
            if ss -tlnp 2>/dev/null | grep -q ":${p} "; then
                (( pok++ ))
            else
                (( pfail++ ))
            fi
        done
        if (( pfail == 0 )); then
            msg_ok "All ${pok} ports listening"
        else
            msg_warn "${pok} OK, ${pfail} not listening"
            (( issues++ ))
        fi
    else
        msg_ok "N/A (Kharej)"
    fi

    printf "  ${G2}[6/8]${RST} ${GR2}IP Forwarding...${RST}\n"
    local fwd
    fwd=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)
    if [[ "$fwd" == "1" ]]; then
        msg_ok "IP Forwarding: Enabled"
    else
        msg_err "IP Forwarding: Disabled"
        (( issues++ ))
    fi

    printf "  ${G2}[7/8]${RST} ${GR2}TCP Congestion Control...${RST}\n"
    local cc
    cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    [[ "$cc" == "bbr" ]] && msg_ok "BBR: Active" || msg_warn "Current: ${cc} (BBR recommended)"

    printf "  ${G2}[8/8]${RST} ${GR2}DNS Resolution...${RST}\n"
    if nslookup google.com &>/dev/null 2>&1 || host google.com &>/dev/null 2>&1 || ping -c1 -W2 8.8.8.8 &>/dev/null; then
        msg_ok "DNS: OK"
    else
        msg_err "DNS: FAILED"
        (( issues++ ))
    fi

    echo ""
    print_line "─" "$GR5"
    echo ""
    if (( issues == 0 )); then
        printf "  ${GRN}${BOLD}All checks passed! No issues found.${RST}\n"
    else
        printf "  ${YLW}${BOLD}${issues} issue(s) found!${RST}\n\n"
        if confirm "Attempt auto-fix?"; then
            echo ""
            auto_fix
        fi
    fi
    press_key
}

auto_fix() {
    load_config
    msg_info "Attempting automatic fixes..."
    echo ""

    sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
    msg_ok "IP Forwarding enabled"

    systemctl restart vira-gre 2>/dev/null
    sleep 2
    msg_ok "GRE restarted"

    systemctl restart vira-hysteria 2>/dev/null
    sleep 2
    msg_ok "Hysteria2 restarted"

    if [[ "$SERVER_ROLE" == "iran" ]]; then
        systemctl restart haproxy 2>/dev/null
        sleep 1
        msg_ok "HAProxy restarted"
    fi

    sysctl --system > /dev/null 2>&1
    msg_ok "Kernel settings reapplied"

    echo ""
    local ok=true
    ip link show gre1 &>/dev/null && msg_ok "GRE: UP" || { msg_err "GRE: Still DOWN"; ok=false; }
    systemctl is-active --quiet vira-hysteria 2>/dev/null && msg_ok "Hysteria2: Running" || { msg_err "Hysteria2: Still down"; ok=false; }
    if [[ "$SERVER_ROLE" == "iran" ]]; then
        systemctl is-active --quiet haproxy 2>/dev/null && msg_ok "HAProxy: Running" || { msg_err "HAProxy: Still down"; ok=false; }
    fi
    echo ""
    $ok && msg_ok "All issues fixed!" || msg_warn "Some issues remain. Check logs manually."
}

# ═══════════════════════════════════════════════
#  LOG VIEWER
# ═══════════════════════════════════════════════
view_logs() {
    show_logo
    load_config

    printf "\n  ${G2}╔══${BOLD} LOG VIEWER ${G2}$(printf '%*s' $((TERM_WIDTH - 18)) '' | tr ' ' '═')╗${RST}\n\n"
    print_menu "1" "Hysteria2 logs" "🚀"
    print_menu "2" "HAProxy logs" "⚖️"
    print_menu "3" "GRE Tunnel logs" "🔗"
    print_menu "4" "Watchdog logs" "🐕"
    print_menu "5" "VIRA Tunnel logs" "📝"
    print_menu "6" "Live logs (follow Hysteria2)" "📡"
    print_menu "0" "Back" "↩️"
    echo ""
    ask "Choice" lc ""

    echo ""
    case "$lc" in
        1) journalctl -u vira-hysteria --no-pager -n 50 2>/dev/null | tail -40 ;;
        2) journalctl -u haproxy --no-pager -n 50 2>/dev/null | tail -40 ;;
        3) journalctl -u vira-gre --no-pager -n 30 2>/dev/null ;;
        4) [[ -f /var/log/vira-watchdog.log ]] && tail -40 /var/log/vira-watchdog.log || echo "  No watchdog log" ;;
        5) [[ -f "$LOG_FILE" ]] && tail -40 "$LOG_FILE" || echo "  No log" ;;
        6) msg_info "Following Hysteria2 logs (Ctrl+C to stop)"; echo ""; journalctl -u vira-hysteria -f --no-pager ;;
        0) return ;;
    esac
    press_key
}

# ═══════════════════════════════════════════════
#  SERVICE MANAGEMENT
# ═══════════════════════════════════════════════
manage_services() {
    show_logo
    load_config
    if ! is_installed; then msg_warn "Tunnel not installed"; press_key; return; fi

    printf "\n  ${G2}╔══${BOLD} SERVICE MANAGEMENT ${G2}$(printf '%*s' $((TERM_WIDTH - 26)) '' | tr ' ' '═')╗${RST}\n\n"
    print_menu "1" "Restart ALL services" "🔄"
    print_menu "2" "Stop ALL services" "⏹️"
    print_menu "3" "Start ALL services" "▶️"
    print_menu "4" "Restart GRE only" "🔗"
    print_menu "5" "Restart Hysteria2 only" "🚀"
    print_menu "6" "Restart HAProxy only" "⚖️"
    print_menu "7" "Run iperf3 server (for speed test)" "📡"
    print_menu "0" "Back" "↩️"
    echo ""
    ask "Choice" sc ""

    echo ""
    case "$sc" in
        1)
            systemctl restart vira-gre 2>/dev/null; sleep 1; msg_ok "GRE restarted"
            systemctl restart vira-hysteria 2>/dev/null; sleep 1; msg_ok "Hysteria2 restarted"
            [[ "$SERVER_ROLE" == "iran" ]] && { systemctl restart haproxy 2>/dev/null; msg_ok "HAProxy restarted"; }
            ;;
        2)
            [[ "$SERVER_ROLE" == "iran" ]] && systemctl stop haproxy 2>/dev/null
            systemctl stop vira-hysteria 2>/dev/null
            systemctl stop vira-gre 2>/dev/null
            msg_ok "All services stopped"
            ;;
        3)
            systemctl start vira-gre 2>/dev/null; sleep 1
            systemctl start vira-hysteria 2>/dev/null; sleep 1
            [[ "$SERVER_ROLE" == "iran" ]] && systemctl start haproxy 2>/dev/null
            msg_ok "All services started"
            ;;
        4) systemctl restart vira-gre 2>/dev/null && msg_ok "GRE restarted" || msg_err "Failed" ;;
        5) systemctl restart vira-hysteria 2>/dev/null && msg_ok "Hysteria2 restarted" || msg_err "Failed" ;;
        6)
            if [[ "$SERVER_ROLE" == "iran" ]]; then
                systemctl restart haproxy 2>/dev/null && msg_ok "HAProxy restarted" || msg_err "Failed"
            else
                msg_warn "HAProxy only runs on Iran server"
            fi
            ;;
        7)
            msg_info "Starting iperf3 server on port 5201..."
            msg_info "From other server run: iperf3 -c ${GRE_IRAN} -t 10  (or ${GRE_KHAREJ})"
            msg_info "Ctrl+C to stop"; echo ""
            iperf3 -s
            ;;
        0) return ;;
    esac
    press_key
}

# ═══════════════════════════════════════════════
#  SHOW CONFIG
# ═══════════════════════════════════════════════
show_config() {
    show_logo
    load_config
    if ! is_installed; then msg_warn "Not installed"; press_key; return; fi

    printf "\n  ${G2}╔══${BOLD} CURRENT CONFIGURATION ${G2}$(printf '%*s' $((TERM_WIDTH - 29)) '' | tr ' ' '═')╗${RST}\n\n"
    printf "  ${GR4}┌──────────────────────────────────────────────────┐${RST}\n"
    printf "  ${GR4}│${RST}  ${GR3}Role:${RST}           ${G1}${BOLD}%-32s${RST}${GR4}│${RST}\n" "$([ "$SERVER_ROLE" = "iran" ] && echo "IRAN (Entry)" || echo "KHAREJ (Exit)")"
    printf "  ${GR4}│${RST}  ${GR3}Iran IP:${RST}        ${GR1}%-32s${RST}${GR4}│${RST}\n" "$IRAN_IP"
    printf "  ${GR4}│${RST}  ${GR3}Kharej IP:${RST}      ${GR1}%-32s${RST}${GR4}│${RST}\n" "$KHAREJ_IP"
    printf "  ${GR4}│${RST}  ${GR3}GRE Iran:${RST}       ${GR1}%-32s${RST}${GR4}│${RST}\n" "$GRE_IRAN"
    printf "  ${GR4}│${RST}  ${GR3}GRE Kharej:${RST}     ${GR1}%-32s${RST}${GR4}│${RST}\n" "$GRE_KHAREJ"
    printf "  ${GR4}│${RST}  ${GR3}Hy2 Port:${RST}       ${GR1}%-32s${RST}${GR4}│${RST}\n" "$HYSTERIA_PORT"
    printf "  ${GR4}│${RST}  ${GR3}Hy2 Password:${RST}   ${G5}%-32s${RST}${GR4}│${RST}\n" "$HYSTERIA_PASSWORD"
    printf "  ${GR4}│${RST}  ${GR3}Obfs Password:${RST}  ${G5}%-32s${RST}${GR4}│${RST}\n" "$OBFS_PASSWORD"
    printf "  ${GR4}│${RST}  ${GR3}V2Ray Ports:${RST}    ${GR1}%-32s${RST}${GR4}│${RST}\n" "$V2RAY_PORTS"
    printf "  ${GR4}│${RST}  ${GR3}Interface:${RST}      ${GR1}%-32s${RST}${GR4}│${RST}\n" "$NET_IFACE"
    printf "  ${GR4}└──────────────────────────────────────────────────┘${RST}\n"

    echo ""
    printf "  ${G5}${BOLD}Config Files:${RST}\n"
    printf "  ${GR3}▸${RST} ${GR1}%s${RST}\n" "$CONFIG_FILE"
    printf "  ${GR3}▸${RST} ${GR1}%s${RST}\n" "${HYSTERIA_DIR}/config.yaml"
    [[ "$SERVER_ROLE" == "iran" ]] && printf "  ${GR3}▸${RST} ${GR1}/etc/haproxy/haproxy.cfg${RST}\n"
    printf "  ${GR3}▸${RST} ${GR1}/etc/sysctl.d/99-vira-tunnel.conf${RST}\n"
    press_key
}

# ═══════════════════════════════════════════════
#  EDIT PORTS
# ═══════════════════════════════════════════════
edit_ports() {
    show_logo
    load_config
    if ! is_installed; then msg_warn "Not installed"; press_key; return; fi
    if [[ "$SERVER_ROLE" != "iran" ]]; then msg_warn "Port editing only on Iran server"; press_key; return; fi

    printf "\n  ${GR3}Current ports:${RST} ${G1}${V2RAY_PORTS}${RST}\n\n"
    ask "New ports (comma-separated)" NP "$V2RAY_PORTS"

    if [[ "$NP" == "$V2RAY_PORTS" ]]; then msg_info "No changes"; press_key; return; fi

    V2RAY_PORTS="$NP"
    save_config

    echo ""
    msg_info "Rebuilding configuration..."
    setup_hy2_client "$KHAREJ_IP" "$HYSTERIA_PORT" "$HYSTERIA_PASSWORD" "$OBFS_PASSWORD" "$V2RAY_PORTS"
    setup_haproxy "$V2RAY_PORTS"
    setup_ipt_iran "$KHAREJ_IP" "$HYSTERIA_PORT" "$V2RAY_PORTS" "$NET_IFACE"
    echo ""
    msg_ok "Ports updated successfully"
    press_key
}

# ═══════════════════════════════════════════════
#  ADVANCED TOOLS
# ═══════════════════════════════════════════════
advanced_menu() {
    while true; do
        show_logo
        load_config

        printf "\n  ${G2}╔══${BOLD} ADVANCED TOOLS ${G2}$(printf '%*s' $((TERM_WIDTH - 22)) '' | tr ' ' '═')╗${RST}\n\n"
        print_menu "1" "MTR Traceroute" "🗺️"
        print_menu "2" "View iptables rules" "🛡️"
        print_menu "3" "View active connections (ss)" "🔌"
        print_menu "4" "View conntrack stats" "📊"
        print_menu "5" "GRE interface details" "🔗"
        print_menu "6" "Edit V2Ray ports" "✏️"
        print_menu "7" "Reset & reapply iptables" "🔄"
        print_menu "8" "Update Hysteria2" "⬆️"
        print_menu "0" "Back" "↩️"
        echo ""
        ask "Choice" ac ""

        case "$ac" in
            1)
                local dt="8.8.8.8"
                if is_installed; then
                    [[ "$SERVER_ROLE" == "iran" ]] && dt="$KHAREJ_IP" || dt="$IRAN_IP"
                fi
                ask "Target" mt "$dt"
                echo ""
                msg_info "Running MTR to ${mt} (10 packets)..."
                echo ""
                if command -v mtr &>/dev/null; then
                    mtr -r -c 10 -w "$mt" 2>&1 | while IFS= read -r l; do printf "  ${GR2}%s${RST}\n" "$l"; done
                else
                    msg_err "mtr not found. Install: apt install mtr-tiny"
                fi
                press_key
                ;;
            2)
                show_logo
                printf "\n  ${G2}${BOLD}=== FILTER ===${RST}\n"
                iptables -L -n -v --line-numbers 2>&1 | head -40 | while IFS= read -r l; do printf "  ${GR2}%s${RST}\n" "$l"; done
                printf "\n  ${G2}${BOLD}=== NAT ===${RST}\n"
                iptables -t nat -L -n -v 2>&1 | head -20 | while IFS= read -r l; do printf "  ${GR2}%s${RST}\n" "$l"; done
                printf "\n  ${G2}${BOLD}=== MANGLE ===${RST}\n"
                iptables -t mangle -L -n -v 2>&1 | head -15 | while IFS= read -r l; do printf "  ${GR2}%s${RST}\n" "$l"; done
                press_key
                ;;
            3)
                show_logo
                printf "\n  ${G2}${BOLD}Listening Ports:${RST}\n"
                ss -tlnp 2>&1 | while IFS= read -r l; do printf "  ${GR2}%s${RST}\n" "$l"; done
                printf "\n  ${G2}${BOLD}Established (first 30):${RST}\n"
                ss -t state established 2>&1 | head -30 | while IFS= read -r l; do printf "  ${GR2}%s${RST}\n" "$l"; done
                press_key
                ;;
            4)
                show_logo
                if [[ -f /proc/sys/net/netfilter/nf_conntrack_count ]]; then
                    local cc cm
                    cc=$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo 0)
                    cm=$(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || echo 1)
                    printf "\n  ${GR3}Connections:${RST} ${G1}%s${RST} / ${GR1}%s${RST}\n" "$cc" "$cm"
                    draw_bar "$cc" "$cm" 30 "Usage"
                else
                    msg_warn "Conntrack not available"
                fi
                press_key
                ;;
            5)
                show_logo
                echo ""
                ip tunnel show 2>&1 | while IFS= read -r l; do printf "  ${GR2}%s${RST}\n" "$l"; done
                echo ""
                ip -s link show gre1 2>&1 | while IFS= read -r l; do printf "  ${GR2}%s${RST}\n" "$l"; done
                press_key
                ;;
            6) edit_ports ;;
            7)
                if is_installed; then
                    msg_info "Reapplying iptables..."
                    if [[ "$SERVER_ROLE" == "iran" ]]; then
                        setup_ipt_iran "$KHAREJ_IP" "$HYSTERIA_PORT" "$V2RAY_PORTS" "$NET_IFACE"
                    else
                        setup_ipt_kharej "$IRAN_IP" "$HYSTERIA_PORT" "$V2RAY_PORTS" "$NET_IFACE"
                    fi
                else
                    msg_warn "Not installed"
                fi
                press_key
                ;;
            8)
                msg_info "Updating Hysteria2..."
                bash <(curl -fsSL https://get.hy2.sh/) > /dev/null 2>&1 &
                spinner $! "Downloading update..."
                systemctl restart vira-hysteria 2>/dev/null
                msg_ok "Hysteria2 updated"
                press_key
                ;;
            0) return ;;
        esac
    done
}

# ═══════════════════════════════════════════════
#  UNINSTALL
# ═══════════════════════════════════════════════
uninstall_tunnel() {
    show_logo
    printf "\n  ${RED}${BOLD}WARNING: This will remove ALL tunnel configurations!${RST}\n\n"
    if ! confirm "Are you sure?"; then msg_info "Cancelled"; press_key; return; fi
    if ! confirm "Final confirmation - proceed?"; then msg_info "Cancelled"; press_key; return; fi

    echo ""
    systemctl stop vira-hysteria 2>/dev/null; systemctl disable vira-hysteria 2>/dev/null
    systemctl stop haproxy 2>/dev/null
    systemctl stop vira-gre 2>/dev/null; systemctl disable vira-gre 2>/dev/null
    msg_ok "Services stopped"

    rm -f /etc/systemd/system/vira-gre.service /etc/systemd/system/vira-hysteria.service
    systemctl daemon-reload
    msg_ok "Service files removed"

    rm -rf "$HYSTERIA_DIR" "$CONFIG_DIR"
    rm -f /usr/local/bin/hysteria
    rm -f /etc/sysctl.d/99-vira-tunnel.conf
    msg_ok "Config files removed"

    ( crontab -l 2>/dev/null | grep -v "vira-watchdog" ) | crontab - 2>/dev/null
    rm -f "$WATCHDOG_SCRIPT" /var/log/vira-watchdog.log
    msg_ok "Watchdog removed"

    iptables -F; iptables -t nat -F; iptables -t mangle -F
    iptables -P INPUT ACCEPT; iptables -P FORWARD ACCEPT; iptables -P OUTPUT ACCEPT
    netfilter-persistent save > /dev/null 2>&1
    msg_ok "iptables flushed"

    ip tunnel del gre1 2>/dev/null
    msg_ok "GRE tunnel removed"

    sysctl --system > /dev/null 2>&1
    msg_ok "Kernel settings reset"

    echo ""
    printf "  ${GRN}${BOLD}VIRA TUNNEL successfully uninstalled.${RST}\n"
    press_key
}

# ═══════════════════════════════════════════════
#  MAIN MENU
# ═══════════════════════════════════════════════
main_menu() {
    while true; do
        show_logo
        show_server_info

        if is_installed; then
            load_config
            local g_s h_s a_s
            ip link show gre1 &>/dev/null && g_s="${GRN}●${RST}" || g_s="${RED}●${RST}"
            systemctl is-active --quiet vira-hysteria 2>/dev/null && h_s="${GRN}●${RST}" || h_s="${RED}●${RST}"
            if [[ "$SERVER_ROLE" == "iran" ]]; then
                systemctl is-active --quiet haproxy 2>/dev/null && a_s="${GRN}●${RST}" || a_s="${RED}●${RST}"
                printf "\n  ${GR4}┃${RST} ${g_s} GRE  ${h_s} Hysteria2  ${a_s} HAProxy ${GR4}┃${RST}\n"
            else
                printf "\n  ${GR4}┃${RST} ${g_s} GRE  ${h_s} Hysteria2 ${GR4}┃${RST}\n"
            fi
        fi

        printf "\n  ${G2}╔══${BOLD} MAIN MENU ${G2}$(printf '%*s' $((TERM_WIDTH - 18)) '' | tr ' ' '═')╗${RST}\n\n"

        if ! is_installed; then
            print_menu "1"  "Install & Setup Tunnel                         " "🚀"
        else
            print_menu "1"  "Reinstall / Update Configuration               " "🚀"
        fi
        print_menu "2"  "Service Status & Charts                        " "📊"
        print_menu "3"  "Live Monitoring                                " "📡"
        print_menu "4"  "Ping & Packet Loss Test                        " "🏓"
        print_menu "5"  "Speed Test                                     " "⚡"
        print_menu "6"  "Troubleshooting                                " "🔧"
        print_menu "7"  "View Logs                                      " "📋"
        print_menu "8"  "Service Management                             " "⚙️"
        print_menu "9"  "View Configuration                             " "📄"
        print_menu "10" "Advanced Tools                                 " "🔬"
        print_menu "11" "Uninstall                                      " "🗑️"
        echo ""
        print_line "─" "$GR5"
        print_menu "0"  "Exit                                           " "🚪"
        echo ""
        printf "  ${G2}╚$(printf '%*s' $((TERM_WIDTH - 4)) '' | tr ' ' '═')╝${RST}\n\n"

        ask "Your choice" MC ""

        case "$MC" in
            1)  install_wizard ;;
            2)  show_status ;;
            3)  live_monitor ;;
            4)  test_ping ;;
            5)  test_speed ;;
            6)  troubleshoot ;;
            7)  view_logs ;;
            8)  manage_services ;;
            9)  show_config ;;
            10) advanced_menu ;;
            11) uninstall_tunnel ;;
            0)  echo ""; center_text "Goodbye!" "$G2"; echo ""; exit 0 ;;
            *)  msg_warn "Invalid choice"; sleep 1 ;;
        esac
    done
}

# ═══════════════════════════════════════════════
#  ENTRY POINT
# ═══════════════════════════════════════════════
main() {
    check_root
    mkdir -p "$CONFIG_DIR"
    touch "$LOG_FILE"

    case "${1:-}" in
        --status)  load_config; show_status; exit 0 ;;
        --monitor) load_config; live_monitor; exit 0 ;;
        --fix)     load_config; auto_fix; exit 0 ;;
        --help|-h)
            echo "VIRA TUNNEL v${VERSION}"
            echo "Usage: $0 [--status|--monitor|--fix|--help]"
            exit 0
            ;;
        *) main_menu ;;
    esac
}

main "$@"

