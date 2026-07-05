#!/bin/bash

# ======================================================
#   MASTER SCRIPT: CodingBoyz XRDP Installer
#   Forces Tailscaled to run as a raw background daemon
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

apt-get update -y > /dev/null 2>&1
apt-get install -y figlet > /dev/null 2>&1

echo -e "${CYAN}"
figlet -w 110 -c "CodingBoyz"
echo -e "${NC}"
echo -e "${DIM}                     Subscribe to CodingBoyz${NC}"
echo ""
echo -e "${YELLOW}============================================================${NC}"
echo ""

apt-get remove -y figlet > /dev/null 2>&1
apt-get autoremove -y > /dev/null 2>&1

# ------------------------------------------------------
# STEP 1: Check Root & Detect Init System
# ------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Please run this script as root.${NC}"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

if systemctl is-system-running &> /dev/null; then
    INIT_SYS="systemd"
else
    INIT_SYS="sysvinit"
fi

echo -e "${GREEN}[INFO] Init System detected: $INIT_SYS${NC}"
echo ""

# ------------------------------------------------------
# Smart Service Controller (For XRDP only)
# ------------------------------------------------------
enable_service() {
    local service_name=$1
    if [ "$INIT_SYS" = "systemd" ]; then
        systemctl enable "$service_name" > /dev/null 2>&1
    else
        update-rc.d "$service_name" defaults > /dev/null 2>&1
    fi
}

start_service() {
    local service_name=$1
    if [ "$INIT_SYS" = "systemd" ]; then
        systemctl start "$service_name" > /dev/null 2>&1
    else
        if [ -f "/etc/init.d/$service_name" ]; then
            /etc/init.d/$service_name start > /dev/null 2>&1
        else
            service "$service_name" start > /dev/null 2>&1
        fi
    fi
}

restart_service() {
    local service_name=$1
    if [ "$INIT_SYS" = "systemd" ]; then
        systemctl restart "$service_name" > /dev/null 2>&1
    else
        if [ -f "/etc/init.d/$service_name" ]; then
            /etc/init.d/$service_name restart > /dev/null 2>&1
        else
            service "$service_name" restart > /dev/null 2>&1
        fi
    fi
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
apt-get update -y > /dev/null 2>&1
apt-get upgrade -y > /dev/null 2>&1
echo -e "${GREEN}       [DONE] System Updated.${NC}"
echo ""

# ------------------------------------------------------
# STEP 4: Install Desktop Environment & XRDP
# ------------------------------------------------------
echo -e "${BOLD}${WHITE}[2/5] Installing XFCE4 Desktop & XRDP...${NC}"
apt-get install -y xfce4 xfce4-goodies xrdp > /dev/null 2>&1

echo "xfce4-session" > /root/.xsession

if [ -f /etc/xrdp/startwm.sh ]; then
    sed -i 's/test -x \/etc\/X11\/Xsession \&\& exec \/etc\/X11\/Xsession/exec \/etc\/X11\/Xsession/g' /etc/xrdp/startwm.sh
fi

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
    useradd -m -s /bin/bash "$USERNAME" > /dev/null 2>&1
    echo "$USERNAME:$PASSWORD" | chpasswd
    usermod -aG sudo "$USERNAME" > /dev/null 2>&1
fi

echo "xfce4-session" > /home/$USERNAME/.xsession
chown $USERNAME:$USERNAME /home/$USERNAME/.xsession

echo -e "${GREEN}       [DONE] User '$USERNAME' created.${NC}"
echo ""

# ------------------------------------------------------
# STEP 6: Install Tailscale & Start as RAW Daemon
# ------------------------------------------------------
echo -e "${BOLD}${WHITE}[4/5] Installing Tailscale...${NC}"
curl -fsSL https://tailscale.com/install.sh | sh > /dev/null 2>&1

# KILL any existing tailscaled processes to avoid conflicts
pkill -9 tailscaled 2>/dev/null
sleep 1

echo -e "${YELLOW}       Starting Tailscaled directly as a background daemon...${NC}"

# FORCE START: Run tailscaled directly in the background with a temp state file
# This completely ignores systemctl/service/init.d failures
mkdir -p /var/run/tailscale
/usr/sbin/tailscaled --state=/tmp/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock > /dev/null 2>&1 &

# Give the raw daemon 3 seconds to bind to the socket
sleep 3

# Verify the raw process is running
if pgrep -x "tailscaled" > /dev/null; then
    echo -e "${GREEN}       [DONE] Tailscale Daemon running successfully in background.${NC}"
    TS_DAEMON_OK=1
else
    echo -e "${RED}       [ERROR] Tailscaled daemon failed to start.${NC}"
    TS_DAEMON_OK=0
fi
echo ""

# ------------------------------------------------------
# STEP 7: Get Login URL & Wait for Connection
# ------------------------------------------------------
TS_IP=""
TS_LOGIN_URL=""

if [ $TS_DAEMON_OK -eq 1 ]; then
    echo -e "${BOLD}${WHITE}[5/5] Generating Tailscale Login URL...${NC}"
    echo ""
    
    # Tell tailscale CLI to use the socket we manually started
    export TS_SOCKET="/var/run/tailscale/tailscaled.sock"
    
    # Capture output
    TS_OUTPUT=$(tailscale up 2>&1)
    
    # Extract the URL
    TS_LOGIN_URL=$(echo "$TS_OUTPUT" | grep -oE 'https://login\.tailscale\.com/a/[a-zA-Z0-9]+' | head -1)
    
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
        echo -e "${DIM}  Debug output: $TS_OUTPUT${NC}"
        echo ""
    fi
else
    echo -e "${BOLD}${WHITE}[5/5] Skipped URL generation (Daemon failed).${NC}"
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
