#!/bin/bash

# ======================================================
#   UNIVERSAL MASTER SCRIPT: CodingBoyz XRDP Installer
#   Supports: Systemd, OpenRC (Alpine), SysVinit
# ======================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# ------------------------------------------------------
# STEP 0: Big Title + Small Subscribe
# ------------------------------------------------------
clear

# Detect package manager to install figlet temporarily
if command -v apt-get &> /dev/null; then
    apt-get update -y > /dev/null 2>&1
    apt-get install -y figlet > /dev/null 2>&1
elif command -v apk &> /dev/null; then
    apk add --no-cache figlet > /dev/null 2>&1
fi

echo -e "${CYAN}"
figlet -w 120 -c "CodingBoyz"
echo -e "${NC}"
echo -e "${DIM}                     Subscribe to CodingBoyz${NC}"
echo ""
echo -e "${YELLOW}============================================================${NC}"
echo ""

# Remove figlet
if command -v apt-get &> /dev/null; then
    apt-get remove -y figlet > /dev/null 2>&1
    apt-get autoremove -y > /dev/null 2>&1
elif command -v apk &> /dev/null; then
    apk del figlet > /dev/null 2>&1
fi

# ------------------------------------------------------
# STEP 1: Detect OS, Package Manager & Init System
# ------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Please run this script as root.${NC}"
    exit 1
fi

# Detect Package Manager
if command -v apt-get &> /dev/null; then
    PKG_MGR="apt"
    INSTALL_CMD="apt-get install -y"
    UPDATE_CMD="apt-get update -y"
    export DEBIAN_FRONTEND=noninteractive
elif command -v apk &> /dev/null; then
    PKG_MGR="apk"
    INSTALL_CMD="apk add --no-cache"
    UPDATE_CMD="apk update"
else
    echo -e "${RED}[ERROR] Unsupported package manager. Only apt and apk are supported.${NC}"
    exit 1
fi

# Detect Init System (Systemd vs OpenRC vs SysVinit)
if command -v systemctl &> /dev/null; then
    INIT_SYS="systemd"
elif command -v rc-update &> /dev/null; then
    INIT_SYS="openrc"
elif command -v service &> /dev/null; then
    INIT_SYS="sysvinit"
else
    echo -e "${RED}[ERROR] Could not detect init system (systemd/openrc/sysvinit).${NC}"
    exit 1
fi

echo -e "${GREEN}[INFO] Detected Package Manager: $PKG_MGR | Init System: $INIT_SYS${NC}"
echo ""

# ------------------------------------------------------
# Universal Service Controller Function
# ------------------------------------------------------
enable_service() {
    local service_name=$1
    case "$INIT_SYS" in
        systemd)   systemctl enable "$service_name" > /dev/null 2>&1 ;;
        openrc)    rc-update add "$service_name" default > /dev/null 2>&1 ;;
        sysvinit)  update-rc.d "$service_name" defaults > /dev/null 2>&1 ;;
    esac
}

start_service() {
    local service_name=$1
    case "$INIT_SYS" in
        systemd)   systemctl start "$service_name" > /dev/null 2>&1 ;;
        openrc)    rc-service "$service_name" start > /dev/null 2>&1 ;;
        sysvinit)  service "$service_name" start > /dev/null 2>&1 ;;
    esac
}

restart_service() {
    local service_name=$1
    case "$INIT_SYS" in
        systemd)   systemctl restart "$service_name" > /dev/null 2>&1 ;;
        openrc)    rc-service "$service_name" restart > /dev/null 2>&1 ;;
        sysvinit)  service "$service_name" restart > /dev/null 2>&1 ;;
    esac
}

# ------------------------------------------------------
# STEP 2: Ask Username & Password (Visible)
# ------------------------------------------------------
echo -e "${CYAN}============================================================${NC}"
echo -e "${BOLD}${WHITE}                      XRDP USER SETUP${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""

while true; do
    read -p "$(echo -e ${GREEN}Enter XRDP Username : ${NC})" USERNAME
    if [ -z "$USERNAME" ]; then
        echo -e "${RED}[ERROR] Username cannot be empty!${NC}"
        continue
    fi
    break
done

while true; do
    read -p "$(echo -e ${GREEN}Enter XRDP Password : ${NC})" PASSWORD
    if [ -z "$PASSWORD" ]; then
        echo -e "${RED}[ERROR] Password cannot be empty!${NC}"
        continue
    fi
    break
done

echo ""
echo -e "${YELLOW}============================================================${NC}"
echo ""

# ------------------------------------------------------
# STEP 3: Update System
# ------------------------------------------------------
echo -e "${BOLD}${WHITE}[1/5] Updating System Packages...${NC}"
 $UPDATE_CMD > /dev/null 2>&1
echo -e "${GREEN}       [DONE] System Updated.${NC}"
echo ""

# ------------------------------------------------------
# STEP 4: Install Desktop Environment & XRDP
# ------------------------------------------------------
echo -e "${BOLD}${WHITE}[2/5] Installing XFCE4 Desktop & XRDP...${NC}"

if [ "$PKG_MGR" = "apt" ]; then
    apt-get install -y xfce4 xfce4-goodies xrdp sudo > /dev/null 2>&1
elif [ "$PKG_MGR" = "apk" ]; then
    # Alpine needs specific desktop packages and dbus
    apk add --no-cache xfce4 xfce4-terminal dbus xrdp sudo > /dev/null 2>&1
    rc-update add dbus default > /dev/null 2>&1
    rc-service dbus start > /dev/null 2>&1
fi

# Force XRDP to use XFCE universally
echo "xfce4-session" > /root/.xsession

# Fix startwm.sh if it exists (Debian/Ubuntu)
if [ -f /etc/xrdp/startwm.sh ]; then
    sed -i 's/test -x \/etc\/X11\/Xsession \&\& exec \/etc\/X11\/Xsession/exec \/etc\/X11\/Xsession/g' /etc/xrdp/startwm.sh
fi

# Enable and start XRDP using universal functions
enable_service xrdp
start_service xrdp
restart_service xrdp

echo -e "${GREEN}       [DONE] Desktop & XRDP Installed on Port 3389.${NC}"
echo ""

# ------------------------------------------------------
# STEP 5: Create User
# ------------------------------------------------------
echo -e "${BOLD}${WHITE}[3/5] Creating User '$USERNAME'...${NC}"

if id "$USERNAME" &>/dev/null; then
    echo "$USERNAME:$PASSWORD" | chpasswd
else
    if [ "$PKG_MGR" = "apk" ]; then
        adduser -D -s /bin/ash "$USERNAME" > /dev/null 2>&1
    else
        useradd -m -s /bin/bash "$USERNAME" > /dev/null 2>&1
    fi
    echo "$USERNAME:$PASSWORD" | chpasswd
    usermod -aG video,audio,input "$USERNAME" 2>/dev/null || addgroup "$USERNAME" video audio input 2>/dev/null
fi

# Give sudo rights
if [ "$PKG_MGR" = "apt" ]; then
    usermod -aG sudo "$USERNAME" 2>/dev/null
elif [ "$PKG_MGR" = "apk" ]; then
    echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/"$USERNAME"
    chmod 0440 /etc/sudoers.d/"$USERNAME"
fi

# Set XFCE session for user
USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)
echo "xfce4-session" > "$USER_HOME/.xsession"
chown "$USERNAME:$USERNAME" "$USER_HOME/.xsession"

echo -e "${GREEN}       [DONE] User '$USERNAME' created.${NC}"
echo ""

# ------------------------------------------------------
# STEP 6: Install Tailscale
# ------------------------------------------------------
echo -e "${BOLD}${WHITE}[4/5] Installing Tailscale...${NC}"

if [ "$PKG_MGR" = "apt" ]; then
    curl -fsSL https://tailscale.com/install.sh | sh > /dev/null 2>&1
elif [ "$PKG_MGR" = "apk" ]; then
    apk add --no-cache tailscale > /dev/null 2>&1
fi

# Enable and start Tailscaled
enable_service tailscaled
start_service tailscaled

echo -e "${GREEN}       [DONE] Tailscale Installed.${NC}"
echo ""

# ------------------------------------------------------
# STEP 7: Get Login URL & Wait for Connection
# ------------------------------------------------------
echo -e "${BOLD}${WHITE}[5/5] Generating Tailscale Login URL...${NC}"
echo ""

TS_OUTPUT=$(tailscale up 2>&1)
TS_LOGIN_URL=$(echo "$TS_OUTPUT" | grep -oP 'https://login\.tailscale\.com/a/[a-zA-Z0-9]+' | head -1)

if [ -n "$TS_LOGIN_URL" ]; then
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${BOLD}${WHITE}              CONNECT THIS VPS TO TAILSCALE${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo -e "${YELLOW}  Click this link in your browser to authenticate:${NC}"
    echo ""
    echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │${NC} ${BOLD}${GREEN}$TS_LOGIN_URL${NC}"
    echo -e "${CYAN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${WHITE}  Don't have Tailscale on your PC? Download it:${NC}"
    echo -e "${GREEN}  https://tailscale.com/download${NC}"
    echo ""
    echo -e "${YELLOW}  Waiting for you to click and connect..........${NC}"

    # Wait loop (checks every 2 secs, max 2 mins)
    CONNECTED=0
    for i in $(seq 1 60); do
        if tailscale status 2>/dev/null | grep -q "connected"; then
            CONNECTED=1
            break
        fi
        sleep 2
        printf "${DIM}."
    done
    echo ""
    echo ""

    if [ $CONNECTED -eq 1 ]; then
        TS_IP=$(tailscale ip -4 2>/dev/null)
        echo -e "${GREEN}  [SUCCESS] Tailscale connected! IP: $TS_IP${NC}"
    else
        echo -e "${RED}  [TIMEOUT] Tailscale did not connect in time.${NC}"
    fi
    echo ""
else
    echo -e "${RED}  [ERROR] Could not generate Tailscale URL.${NC}"
    echo ""
fi

# ------------------------------------------------------
# Gather Public IP
# ------------------------------------------------------
PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || wget -qO- ifconfig.me 2>/dev/null || echo "Could not fetch IP")

# ------------------------------------------------------
# FINAL OUTPUT SCREEN
# ------------------------------------------------------
echo -e "${CYAN}============================================================${NC}"
echo ""
echo -e "${BOLD}${GREEN}              ██  XRDP INSTALLED  ██${NC}"
echo ""
echo -e "${CYAN}============================================================${NC}"
echo ""

if [ -n "$TS_IP" ]; then
    echo -e "${BOLD}${WHITE}  Connect via Tailscale (Recommended):${NC}"
    echo ""
    echo -e "${CYAN}  ┌────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │${NC} ${WHITE}Tailscale IP : ${GREEN}$TS_IP${NC}"
    echo -e "${CYAN}  │${NC} ${WHITE}Port        : ${GREEN}3389${NC}"
    echo -e "${CYAN}  │${NC} ${WHITE}Username    : ${GREEN}$USERNAME${NC}"
    echo -e "${CYAN}  │${NC} ${WHITE}Password    : ${GREEN}$PASSWORD${NC}"
    echo -e "${CYAN}  └────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${WHITE}  RDP Link : ${GREEN}rdp://$TS_IP:3389${NC}"
    echo ""
fi

echo -e "${BOLD}${WHITE}  Connect via Public IP (Alternative):${NC}"
echo ""
echo -e "${CYAN}  ┌────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}  │${NC} ${WHITE}Public IP   : ${GREEN}$PUBLIC_IP${NC}"
echo -e "${CYAN}  │${NC} ${WHITE}Port        : ${GREEN}3389${NC}"
echo -e "${CYAN}  │${NC} ${WHITE}Username    : ${GREEN}$USERNAME${NC}"
echo -e "${CYAN}  │${NC} ${WHITE}Password    : ${GREEN}$PASSWORD${NC}"
echo -e "${CYAN}  └────────────────────────────────────────────┘${NC}"
echo ""
echo -e "${WHITE}  RDP Link : ${GREEN}rdp://$PUBLIC_IP:3389${NC}"
echo ""

echo -e "${CYAN}============================================================${NC}"
echo -e "${DIM}                     Subscribe to CodingBoyz${NC}"
echo -e "${CYAN}============================================================${NC}"
