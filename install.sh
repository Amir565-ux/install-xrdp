#!/bin/bash

# Clear terminal for clean dashboard view
clear

# ==========================================
# 🌟 CODINGBOYZ BLUE THEME COLOR CODES
# ==========================================
DARK_BLUE='\033[0;34m'
BRIGHT_BLUE='\033[1;34m'
LIGHT_BLUE='\033[0;36m' # Cyan-Blue
WHITE='\033[1;37m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# FUNCTION: TYPING EFFECT ANIMATION
type_effect() {
    local text="$1"
    local delay="$2"
    for (( i=0; i<${#text}; i++ )); do
        echo -n "${text:$i:1}"
        sleep "$delay"
    done
    echo ""
}

# FUNCTION: LOADING BAR ANIMATION
loading_bar() {
    local title="$1"
    echo -ne "${LIGHT_BLUE}⏳ $title ${NC}[          ]"
    sleep 0.3
    echo -ne "\b\b\b\b\b\b\b\b\b\b\b[===       ]"
    sleep 0.3
    echo -ne "\b\b\b\b\b\b\b\b\b\b\b[======     ]"
    sleep 0.3
    echo -ne "\b\b\b\b\b\b\b\b\b\b\b[=========  ]"
    sleep 0.3
    echo -ne "\b\b\b\b\b\b\b\b\b\b\b[==========]"
    echo -e " ${GREEN}DONE!${NC}"
}

# AUTOMATED ROOT/SUDO PRIVILEGE CHECK
if [ "$(id -u)" -eq 0 ]; then
    SUDO_CMD=""
else
    SUDO_CMD="sudo"
fi

# ==========================================
# MAIN INTERACTIVE MENU
# ==========================================
show_menu() {
    clear
    echo -e "${DARK_BLUE}==========================================================${NC}"
    echo -e "${BRIGHT_BLUE}              [💻 CODINGBOYZ VPS MANAGER 💻]              ${NC}"
    echo -e "${DARK_BLUE}==========================================================${NC}"
    echo -e "${LIGHT_BLUE}  ████████╗██╗  ██╗███████╗                       ${NC}"
    echo -e "${LIGHT_BLUE}  ╚══██╔══╝██║  ██║██╔════╝                       ${NC}"
    echo -e "${LIGHT_BLUE}     ██║   ███████║█████╗                         ${NC}"
    echo -e "${LIGHT_BLUE}     ██║   ██╔══██║██╔══╝                         ${NC}"
    echo -e "${LIGHT_BLUE}     ██║   ██║  ██║███████╝                       ${NC}"
    echo -e "${LIGHT_BLUE}     ╚═╝   ╚═╝  ╚═╝╚══════╝                       ${NC}"
    echo -e "${DARK_BLUE}==========================================================${NC}"
    echo -e "${WHITE}       Made by Deup Gaming | Modified by CodingBoyz       ${NC}"
    echo -e "${DARK_BLUE}==========================================================${NC}"
    echo ""
    echo -e "${YELLOW}👉 SELECT AN OPTION TO PROCEED:${NC}"
    echo ""
    echo -e "  ${BRIGHT_BLUE}[1]${NC} Create Ubuntu Instance"
    echo -e "  ${BRIGHT_BLUE}[2]${NC} Restart Instance"
    echo -e "  ${BRIGHT_BLUE}[3]${NC} Connect to Instance (Auto-Login)"
    echo -e "  ${BRIGHT_BLUE}[4]${NC} Exit"
    echo ""
    echo -e "${DARK_BLUE}==========================================================${NC}"
    echo -ne "${WHITE}🔹 Enter Choice [1-4]: ${NC}"
    read CHOICE
    
    case $CHOICE in
        1) create_vps ;;
        2) restart_vps ;;
        3) auto_connect ;;
        4) exit 0 ;;
        *) echo -e "${RED}❌ Invalid Choice! Please select 1-4.${NC}"; sleep 2; show_menu ;;
    esac
}

# STEP 1: CREATE & BOOT NEW UBUNTU VPS INSTANCE
create_vps() {
    clear
    echo -e "${DARK_BLUE}==========================================================${NC}"
    echo -e "${WHITE}⚙️  CONFIGURE YOUR VIRTUAL MACHINE SPECIFICATIONS${NC}"
    echo -e "${DARK_BLUE}==========================================================${NC}"
    echo ""
    
    echo -ne "${BRIGHT_BLUE}🔹 Enter RAM Size in GB (e.g., 4, 8, 16, 32): ${NC}"
    read RAM_GB
    echo -ne "${BRIGHT_BLUE}🔹 Enter CPU Cores (e.g., 2, 4, 8): ${NC}"
    read CPU_CORES
    echo -ne "${BRIGHT_BLUE}🔹 Enter Disk Space to ADD in GB (e.g., 10, 20): ${NC}"
    read DISK_ADD
    echo -ne "${BRIGHT_BLUE}🔹 Create Username (Default: ubuntu): ${NC}"
    read USER_NAME
    USER_NAME=${USER_NAME:-ubuntu}
    echo -ne "${BRIGHT_BLUE}🔹 Create Password (Default: 1234): ${NC}"
    read USER_PASS
    USER_PASS=${USER_PASS:-1234}
    
    # 2222 is set as the foundational port base
    TCP_HOST_PORT=${TCP_HOST_PORT:-2222}
    TCP_GUEST_PORT=22

    echo ""
    echo -e "${YELLOW}⏳ Background core dependencies are installing... Please wait.${NC}"
    echo ""
    
    $SUDO_CMD apt-get update -y > /dev/null 2>&1
    # Added openssh-client and sshpass here automatically
    $SUDO_CMD apt-get install -y qemu-system-x86 qemu-utils wget cloud-image-utils curl openssh-client sshpass > /dev/null 2>&1
    
    # Custom absolute path architecture build
    $SUDO_CMD mkdir -p /home/daytona > /dev/null 2>&1
    
    if [ ! -f "/home/daytona/ubuntu22.qcow2" ]; then
        echo -e "${YELLOW}📥 Downloading Ubuntu 22.04 Cloud Image to /home/daytona/...${NC}"
        $SUDO_CMD wget -q --show-progress https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -O /home/daytona/ubuntu22.qcow2
        $SUDO_CMD chmod 666 /home/daytona/ubuntu22.qcow2
    else
        echo -e "${GREEN}✅ Existing Ubuntu Image Cache Detected at /home/daytona/.${NC}"
    fi
    
    loading_bar "Generating Cloud-Init Matrix"
    cat <<EOF > user-data
#cloud-config
ssh_pwauth: True
chpasswd:
  list: |
    ${USER_NAME}:${USER_PASS}
  expire: False
EOF

    cloud-localds seed.img user-data > /dev/null 2>&1
    loading_bar "Expanding Server Hard Disk Allocation"
    $SUDO_CMD qemu-img resize /home/daytona/ubuntu22.qcow2 +${DISK_ADD}G > /dev/null 2>&1
    
    save_env
    boot_qemu
}

# SAVE ENVIRONMENT VARIABLES
save_env() {
    echo "RAM_GB=${RAM_GB:-32}" > .vps_env
    echo "CPU_CORES=${CPU_CORES:-4}" >> .vps_env
    echo "USER_NAME=${USER_NAME:-ubuntu}" >> .vps_env
    echo "USER_PASS=${USER_PASS:-1234}" >> .vps_env
    echo "TCP_HOST_PORT=${TCP_HOST_PORT:-2222}" >> .vps_env
    echo "TCP_GUEST_PORT=${TCP_GUEST_PORT:-22}" >> .vps_env
}

# BOOT QEMU INSTANCE (FIXED VERSION - HIDES FIREWALL ERRORS)
boot_qemu() {
    if [ -f ".vps_env" ]; then
        source .vps_env
    fi

    TCP_HOST_PORT=${TCP_HOST_PORT:-2222}
    TCP_GUEST_PORT=${TCP_GUEST_PORT:-22}
    RAM_VALUE="${RAM_GB:-32}G"

    clear
    echo -e "${DARK_BLUE}==========================================================${NC}"
    type_effect "💻 CODINGBOYZ SYSTEM SYNCHRONIZED! PIPING TERMINAL CHANNELS..." 0.02
    echo -e "${DARK_BLUE}==========================================================${NC}"
    echo ""
    
    # Run sshx in background and HIDE ALL ERRORS completely
    sshx_log=$(mktemp)
    { curl -sSf https://sshx.io/get | sh -s run > "$sshx_log" 2>&1 & } 2>/dev/null
    
    sleep 5
    SSHX_URL=$(grep -o 'https://sshx.io/s/[a-zA-Z0-9]*' "$sshx_log" | head -n 1)
    rm -f "$sshx_log"

    clear
    echo -e "${DARK_BLUE}==========================================================${NC}"
    echo -e "${BRIGHT_BLUE}🎉            CODINGBOYZ - VM NETWORK ACTIVE            ${NC}"
    echo -e "${DARK_BLUE}==========================================================${NC}"
    echo -e "${WHITE}👤 Username : ${LIGHT_BLUE}${USER_NAME:-ubuntu}${NC}"
    echo -e "${WHITE}🔑 Password : ${LIGHT_BLUE}${USER_PASS:-1234}${NC}"
    echo -e "${WHITE}⚙️  Resources: ${LIGHT_BLUE}${RAM_VALUE} RAM | ${CPU_CORES:-4} Cores${NC}"
    echo -e "${WHITE}🚀 Port Rule : ${YELLOW}Host Port ${TCP_HOST_PORT} -> VM Port ${TCP_GUEST_PORT}${NC}"
    echo -e "${DARK_BLUE}----------------------------------------------------------${NC}"
    
    if [ ! -z "$SSHX_URL" ]; then
        echo -e "${YELLOW}🔥 POPOUT LIVE ACCESS WEB LINK (Copy & Paste in Browser):${NC}"
        echo -e "${GREEN}👉 $SSHX_URL 👈${NC}"
    else
        echo -e "${YELLOW}ℹ️  Web tunnel skipped (Firewall/Network restriction).${NC}"
        echo -e "${GREEN}✅ Select Option 3 from main menu to Auto-Connect!${NC}"
    fi
    
    echo -e "${DARK_BLUE}----------------------------------------------------------${NC}"
    echo -e "${WHITE}👉 Connection Command : ${BRIGHT_BLUE}ssh ${USER_NAME:-ubuntu}@localhost -p ${TCP_HOST_PORT}${NC}"
    echo -e "${DARK_BLUE}==========================================================${NC}"
    echo ""
    
    # 🚀 EXECUTING INTEGRATED CORE NETDEV NETWORK COMMAND STRUCTURE
    qemu-system-x86_64 \
        -hda /home/daytona/ubuntu22.qcow2 \
        -m $RAM_VALUE \
        -smp ${CPU_CORES:-4} \
        -drive file=seed.img,format=raw \
        -nographic \
        -netdev user,id=net0,hostfwd=tcp::${TCP_HOST_PORT}-:${TCP_GUEST_PORT} \
        -device e1000,netdev=net0
}

# RESTART INSTANCE PIPELINE
restart_vps() {
    if [ -f "/home/daytona/ubuntu22.qcow2" ] && [ -f "seed.img" ]; then
        echo -e "${GREEN}🔄 Restarting existing server architecture...${NC}"
        sleep 1
        boot_qemu
    else
        echo -e "${RED}❌ No active configuration blocks found! Please build the instance using Option 1 first.${NC}"
        sleep 3
        show_menu
    fi
}

# AUTO-CONNECT PIPELINE (Uses sshpass so user doesn't have to type hidden passwords)
auto_connect() {
    if [ -f ".vps_env" ]; then
        source .vps_env
    else
        echo -e "${RED}❌ No instance found! Please create one using Option 1.${NC}"
        sleep 2
        show_menu
    fi

    # Ensure sshpass is installed
    if ! command -v sshpass &> /dev/null; then
        echo -e "${YELLOW}⏳ Installing auto-login dependency...${NC}"
        $SUDO_CMD apt-get install -y sshpass > /dev/null 2>&1
    fi

    echo -e "${LIGHT_BLUE}🔄 Connecting to ${USER_NAME} at localhost:${TCP_HOST_PORT}...${NC}"
    echo -e "${YELLOW}ℹ️  Type 'exit' to return to the CodingBoyz dashboard.${NC}"
    echo -e "${DARK_BLUE}----------------------------------------------------------${NC}"
    sleep 1

    # Automatically passes the password to SSH
    sshpass -p "${USER_PASS}" ssh -o StrictHostKeyChecking=no ${USER_NAME}@localhost -p ${TCP_HOST_PORT}
    
    # Returns to menu after user types 'exit' in the VM
    echo ""
    echo -e "${GREEN}✅ Disconnected from VM. Returning to menu...${NC}"
    sleep 2
    show_menu
}

# EXECUTE TRIGGER
show_menu
