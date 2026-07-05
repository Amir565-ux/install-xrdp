#!/bin/bash

# ======================================================
#   MASTER SCRIPT: CodingBoyz XRDP Auto-Installer
#   Run via: bash <(curl -sL <YOUR_GITHUB_RAW_LINK>)
# ======================================================

# Prevent interactive prompts from blocking the curl pipe
export DEBIAN_FRONTEND=noninteractive

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# ------------------------------------------------------
# STEP 0: Setup Screen & Big Title
# ------------------------------------------------------
clear

# Install figlet silently for the big title
apt-get update -y > /dev/null 2>&1
apt-get install -y figlet > /dev/null 2>&1

# BIG TITLE
echo -e "${CYAN}"
figlet -w 120 -c "CodingBoyz"
echo -e "${NC}"

# SMALL SUBSCRIBE TEXT
echo -e "${DIM}                     Subscribe to CodingBoyz${NC}"
echo ""
echo -e "${YELLOW}============================================================${NC}"
echo ""

# Remove figlet to keep the VPS clean
apt-get remove -y figlet > /dev/null 2>&1
apt-get autoremove -y > /dev/null 2>&1

# ------------------------------------------------------
# STEP 1: Root Check
# ------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Please run this script as root (sudo).${NC}"
    exit 1
fi

# ------------------------------------------------------
# STEP 2: Ask for Username and Password (Visible)
# ------------------------------------------------------
echo -e "${CYAN}============================================================${NC}"
echo -e "${BOLD}${WHITE}                      XRDP USER SETUP${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""

# Ask Username
while true; do
    read -p "$(echo -e ${GREEN}Enter XRDP Username : ${NC})" USERNAME
    if [ -z "$USERNAME" ]; then
        echo -e "${RED}[ERROR] Username cannot be empty!${NC}"
        continue
    fi
    if [[ "$USERNAME" =~ [^a-zA-Z0-9_] ]]; then
        echo -e "${RED}[ERROR] Only letters, numbers, and underscores allowed!${NC}"
        continue
    fi
    break
done

# Ask Password
while true; do
    read -p "$(echo -e ${GREEN}Enter XRDP Password : ${NC})" PASSWORD
    if [ -z "$PASSWORD" ]; then
        echo -e "${RED}[ERROR] Password cannot be empty!${NC}"
        continue
    fi
    if [ ${#PASSWORD} -lt 4 ]; then
        echo -e "${RED}[ERROR] Password must be at least 4 characters!${NC}"
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
echo -e "${GREEN}       [DONE] System Updated Successfully.${NC}"
echo ""

# ------------------------------------------------------
# STEP 4: Install Desktop Environment
# ------------------------------------------------------
echo -e "${BOLD}${WHITE}[2/5] Installing XFCE4 Desktop Environment...${NC}"
apt-get install -y xfce4 xfce4-goodies > /dev/null 2>&1
echo -e "${GREEN}       [DONE] Desktop Environment Installed.${NC}"
echo ""

# ------------------------------------------------------
# STEP 5: Install and Configure XRDP
# ------------------------------------------------------
echo -e "${BOLD}${WHITE}[3/5] Installing and Configuring XRDP...${NC}"
apt-get install -y xrdp > /dev/null 2>&1

# Force XRDP to use XFCE
echo "xfce4-session" > /root/.xsession

# Fix common blank screen issues on Ubuntu/Debian
if [ -f /etc/xrdp/startwm.sh ]; then
    sed -i 's/test -x \/etc\/X11\/Xsession \&\& exec \/etc\/X11\/Xsession/exec \/etc\/X11\/Xsession/g' /etc/xrdp/startwm.sh
fi

# Add xrdp to ssl-cert group for key access
usermod -aG ssl-cert xrdp > /dev/null 2>&1

# Enable and Restart XRDP
systemctl enable xrdp > /dev/null 2>&1
systemctl restart xrdp > /dev/null 2>&1

# Open Port 3389 on UFW if active
if command -v ufw &> /dev/null; then
    ufw allow 3389/tcp > /dev/null 2>&1
fi

echo -e "${GREEN}       [DONE] XRDP Installed and Running on Port 3389.${NC}"
echo ""

# ------------------------------------------------------
# STEP 6: Create User
# ------------------------------------------------------
echo -e "${BOLD}${WHITE}[4/5] Creating User '$USERNAME'...${NC}"

if id "$USERNAME" &>/dev/null; then
    echo -e "${YELLOW}       [WARN] User already exists. Updating password...${NC}"
    echo "$USERNAME:$PASSWORD" | chpasswd
else
    useradd -m -s /bin/bash "$USERNAME" > /dev/null 2>&1
    echo "$USERNAME:$PASSWORD" | chpasswd
    usermod -aG sudo "$USERNAME" > /dev/null 2>&1
fi

# Set XFCE as default session for the user
echo "xfce4-session" > /home/$USERNAME/.xsession
chown $USERNAME:$USERNAME /home/$USERNAME/.xsession

echo -e "${GREEN}       [DONE] User '$USERNAME' is ready for login.${NC}"
echo ""

# ------------------------------------------------------
# STEP 7: Install Tailscale & Get Link
# ------------------------------------------------------
echo -e "${BOLD}${WHITE}[5/5] Installing Tailscale...${NC}"
curl -fsSL https://tailscale.com/install.sh | sh > /dev/null 2>&1
systemctl enable tailscaled > /dev/null 2>&1
systemctl start tailscaled > /dev/null 2>&1

# Extract the login link
TS_LINK=$(tailscale up 2>&1 | grep -oP 'https://login\.tailscale\.com/a/[a-zA-Z0-9]+' | head -1)

echo -e "${GREEN}       [DONE] Tailscale Installed.${NC}"
echo ""

# ------------------------------------------------------
# STEP 8: Gather IPs
# ------------------------------------------------------
PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 icanhazip.com 2>/dev/null || echo "Could not fetch IP")

# ------------------------------------------------------
# FINAL OUTPUT SCREEN
# ------------------------------------------------------
echo -e "${CYAN}============================================================${NC}"
echo ""
echo -e "${BOLD}${GREEN}              ██  XRDP INSTALLED  ██${NC}"
echo ""
echo -e "${CYAN}============================================================${NC}"
echo ""
echo -e "${BOLD}${WHITE}  Connection Details:${NC}"
echo ""
echo -e "${CYAN}  ┌────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}  │${NC} ${WHITE}Public IP  : ${GREEN}$PUBLIC_IP${NC}"
echo -e "${CYAN}  │${NC} ${WHITE}Port       : ${GREEN}3389${NC}"
echo -e "${CYAN}  │${NC} ${WHITE}Username   : ${GREEN}$USERNAME${NC}"
echo -e "${CYAN}  │${NC} ${WHITE}Password   : ${GREEN}$PASSWORD${NC}"
echo -e "${CYAN}  └────────────────────────────────────────────┘${NC}"
echo ""
echo -e "${WHITE}  RDP Connection String : ${GREEN}rdp://$PUBLIC_IP:3389${NC}"
echo ""

if [ -n "$TS_LINK" ]; then
    echo -e "${WHITE}  Tailscale Login Link   :${NC}"
    echo -e "${GREEN}  $TS_LINK${NC}"
    echo ""
    echo -e "${YELLOW}  [!] Open the Tailscale link above in your browser to connect.${NC}"
    echo ""
fi

echo -e "${CYAN}============================================================${NC}"
echo -e "${DIM}                     Subscribe to CodingBoyz${NC}"
echo -e "${CYAN}============================================================${NC}"