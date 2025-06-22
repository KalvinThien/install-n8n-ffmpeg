#!/bin/bash

# =============================================================================
# Script cÃ i Ä‘áº·t N8N tá»± Ä‘á»™ng vá»›i FFmpeg, yt-dlp, Puppeteer, SSL vÃ  cÃ¡c tÃ­nh nÄƒng má»›i
# TÃ¡c giáº£: Nguyá»…n Ngá»c Thiá»‡n
# YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1
# Facebook: https://www.facebook.com/Ban.Thien.Handsome/
# Zalo/SDT: 08.8888.4749
# =============================================================================

echo "======================================================================"
echo "     ðŸš€ Script CÃ i Äáº·t N8N Tá»± Äá»™ng PhiÃªn Báº£n Cáº£i Tiáº¿n ðŸš€  "
echo "     âœ¨ Vá»›i FFmpeg, yt-dlp, Puppeteer, SSL vÃ  FastAPI âœ¨"
echo "======================================================================"
echo ""
echo "ðŸ“º KÃªnh YouTube hÆ°á»›ng dáº«n: https://www.youtube.com/@kalvinthiensocial"
echo "ðŸ”¥ HÃ£y ÄÄ‚NG KÃ kÃªnh Ä‘á»ƒ á»§ng há»™ vÃ  nháº­n thÃ´ng bÃ¡o video má»›i!"
echo "ðŸ“± LiÃªn há»‡: 08.8888.4749 (Zalo/Phone)"
echo "ðŸ“§ Facebook: https://www.facebook.com/Ban.Thien.Handsome/"
echo ""
echo "======================================================================"

# Kiá»ƒm tra xem script cÃ³ Ä‘Æ°á»£c cháº¡y vá»›i quyá»n root khÃ´ng
if [[ $EUID -ne 0 ]]; then
   echo "âŒ Script nÃ y cáº§n Ä‘Æ°á»£c cháº¡y vá»›i quyá»n root" 
   exit 1
fi

# Biáº¿n cáº¥u hÃ¬nh toÃ n cá»¥c
SCRIPT_VERSION="2.0"
AUTHOR_NAME="Nguyá»…n Ngá»c Thiá»‡n"
YOUTUBE_CHANNEL="https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1"
FACEBOOK_LINK="https://www.facebook.com/Ban.Thien.Handsome/"
CONTACT_INFO="08.8888.4749"

# Biáº¿n cáº¥u hÃ¬nh Telegram
ENABLE_TELEGRAM_BACKUP=false
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# Biáº¿n cáº¥u hÃ¬nh FastAPI
ENABLE_FASTAPI=false
FASTAPI_PASSWORD=""
FASTAPI_PORT="8000"

# HÃ m thiáº¿t láº­p swap tá»± Ä‘á»™ng
setup_swap() {
    echo "ðŸ”„ Kiá»ƒm tra vÃ  thiáº¿t láº­p swap tá»± Ä‘á»™ng..."
    
    # Kiá»ƒm tra náº¿u swap Ä‘Ã£ Ä‘Æ°á»£c báº­t
    if [ "$(swapon --show | wc -l)" -gt 0 ]; then
        SWAP_SIZE=$(free -h | grep Swap | awk '{print $2}')
        echo "âœ… Swap Ä‘Ã£ Ä‘Æ°á»£c báº­t vá»›i kÃ­ch thÆ°á»›c ${SWAP_SIZE}. Bá» qua thiáº¿t láº­p."
        return
    fi
    
    # Láº¥y thÃ´ng tin RAM (Ä‘Æ¡n vá»‹ MB)
    RAM_MB=$(free -m | grep Mem | awk '{print $2}')
    
    # TÃ­nh toÃ¡n kÃ­ch thÆ°á»›c swap dá»±a trÃªn RAM
    if [ "$RAM_MB" -le 2048 ]; then
        # Vá»›i RAM <= 2GB, swap = 2x RAM
        SWAP_SIZE=$((RAM_MB * 2))
    elif [ "$RAM_MB" -gt 2048 ] && [ "$RAM_MB" -le 8192 ]; then
        # Vá»›i 2GB < RAM <= 8GB, swap = RAM
        SWAP_SIZE=$RAM_MB
    else
        # Vá»›i RAM > 8GB, swap = 4GB
        SWAP_SIZE=4096
    fi
    
    # Chuyá»ƒn Ä‘á»•i sang GB cho dá»… nhÃ¬n (lÃ m trÃ²n lÃªn)
    SWAP_GB=$(( (SWAP_SIZE + 1023) / 1024 ))
    
    echo "âš™ï¸  Äang thiáº¿t láº­p swap vá»›i kÃ­ch thÆ°á»›c ${SWAP_GB}GB (${SWAP_SIZE}MB)..."
    
    # Táº¡o swap file vá»›i Ä‘Æ¡n vá»‹ MB
    dd if=/dev/zero of=/swapfile bs=1M count=$SWAP_SIZE status=progress
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    
    # ThÃªm vÃ o fstab Ä‘á»ƒ swap Ä‘Æ°á»£c kÃ­ch hoáº¡t sau khi khá»Ÿi Ä‘á»™ng láº¡i
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    
    # Cáº¥u hÃ¬nh swappiness vÃ  cache pressure
    sysctl vm.swappiness=10
    sysctl vm.vfs_cache_pressure=50
    
    # LÆ°u cáº¥u hÃ¬nh vÃ o sysctl.conf náº¿u chÆ°a cÃ³
    if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
        echo "vm.swappiness=10" >> /etc/sysctl.conf
    fi
    
    if ! grep -q "vm.vfs_cache_pressure" /etc/sysctl.conf; then
        echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
    fi
    
    echo "âœ… ÄÃ£ thiáº¿t láº­p swap vá»›i kÃ­ch thÆ°á»›c ${SWAP_GB}GB thÃ nh cÃ´ng."
    echo "ðŸ”§ Swappiness Ä‘Ã£ Ä‘Æ°á»£c Ä‘áº·t thÃ nh 10 (máº·c Ä‘á»‹nh: 60)"
    echo "ðŸ”§ Vfs_cache_pressure Ä‘Ã£ Ä‘Æ°á»£c Ä‘áº·t thÃ nh 50 (máº·c Ä‘á»‹nh: 100)"
}

# HÃ m hiá»ƒn thá»‹ trá»£ giÃºp
show_help() {
    echo "ðŸ“‹ CÃ¡ch sá»­ dá»¥ng: $0 [tÃ¹y chá»n]"
    echo "ðŸ“– TÃ¹y chá»n:"
    echo "  -h, --help      Hiá»ƒn thá»‹ trá»£ giÃºp nÃ y"
    echo "  -d, --dir DIR   Chá»‰ Ä‘á»‹nh thÆ° má»¥c cÃ i Ä‘áº·t n8n (máº·c Ä‘á»‹nh: /home/n8n)"
    echo "  -s, --skip-docker Bá» qua cÃ i Ä‘áº·t Docker (náº¿u Ä‘Ã£ cÃ³)"
    echo "  --enable-telegram  KÃ­ch hoáº¡t gá»­i backup qua Telegram"
    echo "  --enable-fastapi   KÃ­ch hoáº¡t API FastAPI Ä‘á»ƒ láº¥y ná»™i dung bÃ i viáº¿t"
    echo ""
    echo "ðŸŽ¥ KÃªnh YouTube: $YOUTUBE_CHANNEL"
    echo "ðŸ“ž LiÃªn há»‡: $CONTACT_INFO"
    exit 0
}

# HÃ m cáº¥u hÃ¬nh Telegram
setup_telegram_config() {
    echo ""
    echo "ðŸ¤– === Cáº¤U HÃŒNH TELEGRAM BOT ==="
    echo "ðŸ“ Äá»ƒ nháº­n backup tá»± Ä‘á»™ng qua Telegram, báº¡n cáº§n:"
    echo "   1. Táº¡o bot má»›i vá»›i @BotFather trÃªn Telegram"
    echo "   2. Láº¥y Bot Token"
    echo "   3. Láº¥y Chat ID (ID cuá»™c trÃ² chuyá»‡n)"
    echo ""
    
    read -p "ðŸ”‘ Nháº­p Bot Token cá»§a báº¡n: " TELEGRAM_BOT_TOKEN
    if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
        echo "âš ï¸  Bot Token khÃ´ng Ä‘Æ°á»£c Ä‘á»ƒ trá»‘ng. Táº¯t tÃ­nh nÄƒng Telegram."
        ENABLE_TELEGRAM_BACKUP=false
        return
    fi
    
    read -p "ðŸ†” Nháº­p Chat ID cá»§a báº¡n: " TELEGRAM_CHAT_ID
    if [ -z "$TELEGRAM_CHAT_ID" ]; then
        echo "âš ï¸  Chat ID khÃ´ng Ä‘Æ°á»£c Ä‘á»ƒ trá»‘ng. Táº¯t tÃ­nh nÄƒng Telegram."
        ENABLE_TELEGRAM_BACKUP=false
        return
    fi
    
    echo "âœ… Cáº¥u hÃ¬nh Telegram hoÃ n táº¥t!"
    ENABLE_TELEGRAM_BACKUP=true
}

# HÃ m cáº¥u hÃ¬nh FastAPI
setup_fastapi_config() {
    echo ""
    echo "âš¡ === Cáº¤U HÃŒNH FASTAPI API ==="
    echo "ðŸ“„ API nÃ y cho phÃ©p láº¥y ná»™i dung bÃ i viáº¿t tá»« URL báº¥t ká»³"
    echo "ðŸ” Sá»­ dá»¥ng Bearer Token Ä‘á»ƒ báº£o máº­t"
    echo ""
    
    read -p "ðŸ”‘ Nháº­p máº­t kháº©u Bearer Token: " FASTAPI_PASSWORD
    if [ -z "$FASTAPI_PASSWORD" ]; then
        echo "âš ï¸  Máº­t kháº©u khÃ´ng Ä‘Æ°á»£c Ä‘á»ƒ trá»‘ng. Táº¯t tÃ­nh nÄƒng FastAPI."
        ENABLE_FASTAPI=false
        return
    fi
    
    read -p "ðŸŒ Nháº­p cá»•ng cho API (máº·c Ä‘á»‹nh 8000): " FASTAPI_PORT_INPUT
    if [ -n "$FASTAPI_PORT_INPUT" ]; then
        FASTAPI_PORT="$FASTAPI_PORT_INPUT"
    fi
    
    echo "âœ… Cáº¥u hÃ¬nh FastAPI hoÃ n táº¥t!"
    echo "ðŸ“¡ API sáº½ cháº¡y trÃªn cá»•ng: $FASTAPI_PORT"
    ENABLE_FASTAPI=true
}

# Xá»­ lÃ½ tham sá»‘ dÃ²ng lá»‡nh
N8N_DIR="/home/n8n"
SKIP_DOCKER=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -d|--dir)
            N8N_DIR="$2"
            shift 2
            ;;
        -s|--skip-docker)
            SKIP_DOCKER=true
            shift
            ;;
        --enable-telegram)
            setup_telegram_config
            shift
            ;;
        --enable-fastapi)
            setup_fastapi_config
            shift
            ;;
        *)
            echo "âŒ TÃ¹y chá»n khÃ´ng há»£p lá»‡: $1"
            show_help
            ;;
    esac
done

# Há»i ngÆ°á»i dÃ¹ng vá» tÃ­nh nÄƒng bá»• sung
echo ""
echo "ðŸ”§ === TÃ™Y CHá»ŒN TÃNH NÄ‚NG Bá»” SUNG ==="
echo ""

# Há»i vá» Telegram backup
if [ "$ENABLE_TELEGRAM_BACKUP" = false ]; then
    read -p "ðŸ“± Báº¡n cÃ³ muá»‘n kÃ­ch hoáº¡t gá»­i backup tá»± Ä‘á»™ng qua Telegram? (y/n): " telegram_choice
    if [[ $telegram_choice =~ ^[Yy]$ ]]; then
        setup_telegram_config
    fi
fi

# Há»i vá» FastAPI
if [ "$ENABLE_FASTAPI" = false ]; then
    read -p "âš¡ Báº¡n cÃ³ muá»‘n cÃ i Ä‘áº·t API FastAPI Ä‘á»ƒ láº¥y ná»™i dung bÃ i viáº¿t? (y/n): " fastapi_choice
    if [[ $fastapi_choice =~ ^[Yy]$ ]]; then
        setup_fastapi_config
    fi
fi

# HÃ m kiá»ƒm tra domain
check_domain() {
    local domain=$1
    local server_ip=$(curl -s https://api.ipify.org)
    local domain_ip=$(dig +short $domain)

    if [ "$domain_ip" = "$server_ip" ]; then
        return 0  # Domain Ä‘Ã£ trá» Ä‘Ãºng
    else
        return 1  # Domain chÆ°a trá» Ä‘Ãºng
    fi
}

# HÃ m kiá»ƒm tra cÃ¡c lá»‡nh cáº§n thiáº¿t
check_commands() {
    if ! command -v dig &> /dev/null; then
        echo "ðŸ“¦ CÃ i Ä‘áº·t dnsutils (Ä‘á»ƒ sá»­ dá»¥ng lá»‡nh dig)..."
        apt-get update
        apt-get install -y dnsutils
    fi
}

# Thiáº¿t láº­p swap
setup_swap

# HÃ m cÃ i Ä‘áº·t Docker
install_docker() {
    if $SKIP_DOCKER; then
        echo "â­ï¸  Bá» qua cÃ i Ä‘áº·t Docker theo yÃªu cáº§u..."
        return
    fi
    
    echo "ðŸ³ CÃ i Ä‘áº·t Docker vÃ  Docker Compose..."
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    
    # ThÃªm khÃ³a Docker GPG theo cÃ¡ch má»›i
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # ThÃªm repository Docker
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # CÃ i Ä‘áº·t Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # CÃ i Ä‘áº·t Docker Compose
    if ! command -v docker-compose &> /dev/null && ! command -v docker &> /dev/null; then
        echo "ðŸ“¦ CÃ i Ä‘áº·t Docker Compose..."
        apt-get install -y docker-compose
    elif command -v docker &> /dev/null && ! docker compose version &> /dev/null; then
        echo "ðŸ“¦ CÃ i Ä‘áº·t Docker Compose plugin..."
        apt-get install -y docker-compose-plugin
    fi
    
    # Kiá»ƒm tra Docker Ä‘Ã£ cÃ i Ä‘áº·t thÃ nh cÃ´ng chÆ°a
    if ! command -v docker &> /dev/null; then
        echo "âŒ Lá»—i: Docker chÆ°a Ä‘Æ°á»£c cÃ i Ä‘áº·t Ä‘Ãºng cÃ¡ch."
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! (command -v docker &> /dev/null && docker compose version &> /dev/null); then
        echo "âŒ Lá»—i: Docker Compose chÆ°a Ä‘Æ°á»£c cÃ i Ä‘áº·t Ä‘Ãºng cÃ¡ch."
        exit 1
    fi

    # ThÃªm user hiá»‡n táº¡i vÃ o nhÃ³m docker náº¿u khÃ´ng pháº£i root
    if [ "$SUDO_USER" != "" ]; then
        echo "ðŸ‘¤ ThÃªm user $SUDO_USER vÃ o nhÃ³m docker Ä‘á»ƒ cÃ³ thá»ƒ cháº¡y docker mÃ  khÃ´ng cáº§n sudo..."
        usermod -aG docker $SUDO_USER
        echo "âœ… ÄÃ£ thÃªm user $SUDO_USER vÃ o nhÃ³m docker. CÃ¡c thay Ä‘á»•i sáº½ cÃ³ hiá»‡u lá»±c sau khi Ä‘Äƒng nháº­p láº¡i."
    fi

    # Khá»Ÿi Ä‘á»™ng láº¡i dá»‹ch vá»¥ Docker
    systemctl restart docker

    echo "âœ… Docker vÃ  Docker Compose Ä‘Ã£ Ä‘Æ°á»£c cÃ i Ä‘áº·t thÃ nh cÃ´ng."
}

# CÃ i Ä‘áº·t cÃ¡c gÃ³i cáº§n thiáº¿t
echo "ðŸ“¦ Äang cÃ i Ä‘áº·t cÃ¡c cÃ´ng cá»¥ cáº§n thiáº¿t..."
apt-get update
apt-get install -y dnsutils curl cron jq tar gzip python3-full python3-venv pipx net-tools

# CÃ i Ä‘áº·t yt-dlp thÃ´ng qua pipx hoáº·c virtual environment
echo "ðŸ“º CÃ i Ä‘áº·t yt-dlp..."
if command -v pipx &> /dev/null; then
    pipx install yt-dlp
else
    # Táº¡o virtual environment vÃ  cÃ i Ä‘áº·t yt-dlp vÃ o Ä‘Ã³
    python3 -m venv /opt/yt-dlp-venv
    /opt/yt-dlp-venv/bin/pip install yt-dlp
    ln -sf /opt/yt-dlp-venv/bin/yt-dlp /usr/local/bin/yt-dlp
    chmod +x /usr/local/bin/yt-dlp
fi

# Äáº£m báº£o cron service Ä‘ang cháº¡y
systemctl enable cron
systemctl start cron

# Kiá»ƒm tra cÃ¡c lá»‡nh cáº§n thiáº¿t
check_commands

# Nháº­n input domain tá»« ngÆ°á»i dÃ¹ng
read -p "ðŸŒ Nháº­p tÃªn miá»n hoáº·c tÃªn miá»n phá»¥ cá»§a báº¡n: " DOMAIN

# Kiá»ƒm tra domain
echo "ðŸ” Kiá»ƒm tra domain $DOMAIN..."
if check_domain $DOMAIN; then
    echo "âœ… Domain $DOMAIN Ä‘Ã£ Ä‘Æ°á»£c trá» Ä‘Ãºng Ä‘áº¿n server nÃ y. Tiáº¿p tá»¥c cÃ i Ä‘áº·t"
else
    echo "âš ï¸  Domain $DOMAIN chÆ°a Ä‘Æ°á»£c trá» Ä‘áº¿n server nÃ y."
    echo "ðŸ“ Vui lÃ²ng cáº­p nháº­t báº£n ghi DNS Ä‘á»ƒ trá» $DOMAIN Ä‘áº¿n IP $(curl -s https://api.ipify.org)"
    echo "ðŸ”„ Sau khi cáº­p nháº­t DNS, hÃ£y cháº¡y láº¡i script nÃ y"
    exit 1
fi

# CÃ i Ä‘áº·t Docker vÃ  Docker Compose
install_docker

# Táº¡o thÆ° má»¥c cho n8n
echo "ðŸ“ Táº¡o cáº¥u trÃºc thÆ° má»¥c cho n8n táº¡i $N8N_DIR..."
mkdir -p $N8N_DIR
mkdir -p $N8N_DIR/files
mkdir -p $N8N_DIR/files/temp
mkdir -p $N8N_DIR/files/youtube_content_anylystic
mkdir -p $N8N_DIR/files/backup_full

# Tiáº¿p tá»¥c vá»›i pháº§n táº¡o Dockerfile...

# Táº¡o Dockerfile - Cáº¬P NHáº¬T Vá»šI PUPPETEER
echo "ðŸ³ Táº¡o Dockerfile Ä‘á»ƒ cÃ i Ä‘áº·t n8n vá»›i FFmpeg, yt-dlp vÃ  Puppeteer..."
cat << 'EOF' > $N8N_DIR/Dockerfile
FROM n8nio/n8n:latest

USER root

# CÃ i Ä‘áº·t FFmpeg, wget, zip vÃ  cÃ¡c gÃ³i phá»¥ thuá»™c khÃ¡c
RUN apk update && \
    apk add --no-cache ffmpeg wget zip unzip python3 py3-pip jq tar \
    # Puppeteer dependencies
    chromium \
    nss \
    freetype \
    freetype-dev \
    harfbuzz \
    ca-certificates \
    ttf-freefont \
    ttf-liberation \
    font-noto \
    font-noto-cjk \
    font-noto-emoji \
    dbus \
    udev

# CÃ i Ä‘áº·t yt-dlp trá»±c tiáº¿p sá»­ dá»¥ng pip trong container
RUN pip3 install --break-system-packages -U yt-dlp && \
    chmod +x /usr/bin/yt-dlp

# Thiáº¿t láº­p biáº¿n mÃ´i trÆ°á»ng cho Puppeteer
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# CÃ i Ä‘áº·t n8n-nodes-puppeteer
WORKDIR /usr/local/lib/node_modules/n8n
RUN npm install n8n-nodes-puppeteer

# Kiá»ƒm tra cÃ i Ä‘áº·t cÃ¡c cÃ´ng cá»¥
RUN ffmpeg -version && \
    wget --version | head -n 1 && \
    zip --version | head -n 2 && \
    yt-dlp --version && \
    chromium-browser --version

# Táº¡o thÆ° má»¥c youtube_content_anylystic vÃ  backup_full vÃ  set Ä‘Ãºng quyá»n
RUN mkdir -p /files/youtube_content_anylystic && \
    mkdir -p /files/backup_full && \
    chown -R node:node /files

# Trá»Ÿ láº¡i user node
USER node
WORKDIR /home/node
EOF

# Táº¡o file docker-compose.yml vá»›i cáº­p nháº­t má»›i
echo "ðŸ“ Táº¡o file docker-compose.yml..."
cat << EOF > $N8N_DIR/docker-compose.yml
# Cáº¥u hÃ¬nh Docker Compose cho N8N vá»›i FFmpeg, yt-dlp, vÃ  Puppeteer
# TÃ¡c giáº£: $AUTHOR_NAME
# YouTube: $YOUTUBE_CHANNEL
services:
  n8n:
    build:
      context: .
      dockerfile: Dockerfile
    image: n8n-ffmpeg-latest
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=${DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://${DOMAIN}
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
      # Cáº¥u hÃ¬nh binary data mode
      - N8N_DEFAULT_BINARY_DATA_MODE=filesystem
      - N8N_BINARY_DATA_STORAGE=/files
      - N8N_DEFAULT_BINARY_DATA_FILESYSTEM_DIRECTORY=/files
      - N8N_DEFAULT_BINARY_DATA_TEMP_DIRECTORY=/files/temp
      - NODE_FUNCTION_ALLOW_BUILTIN=child_process,path,fs,util,os
      - N8N_EXECUTIONS_DATA_MAX_SIZE=304857600
      # Cáº¥u hÃ¬nh Puppeteer
      - PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
      - PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
    volumes:
      - ${N8N_DIR}:/home/node/.n8n
      - ${N8N_DIR}/files:/files
    user: "1000:1000"
    cap_add:
      - SYS_ADMIN  # ThÃªm quyá»n cho Puppeteer

  caddy:
    image: caddy:2
    restart: always
    ports:
      - "8080:80"  # Sá»­ dá»¥ng cá»•ng 8080 thay vÃ¬ 80 Ä‘á»ƒ trÃ¡nh xung Ä‘á»™t
      - "443:443"
    volumes:
      - ${N8N_DIR}/Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - n8n

volumes:
  caddy_data:
  caddy_config:
EOF

# Táº¡o file Caddyfile
echo "ðŸŒ Táº¡o file Caddyfile..."
cat << EOF > $N8N_DIR/Caddyfile
${DOMAIN} {
    reverse_proxy n8n:5678
}
EOF

# Táº¡o script sao lÆ°u workflow vÃ  credentials Cáº¢I TIáº¾N
echo "ðŸ’¾ Táº¡o script sao lÆ°u workflow vÃ  credentials cáº£i tiáº¿n..."
cat << 'EOF' > $N8N_DIR/backup-workflows.sh
#!/bin/bash

# =============================================================================
# Script Backup N8N Workflows vÃ  Credentials - PhiÃªn báº£n cáº£i tiáº¿n
# TÃ¡c giáº£: Nguyá»…n Ngá»c Thiá»‡n
# YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1
# =============================================================================

# Thiáº¿t láº­p biáº¿n
BACKUP_DIR="$N8N_DIR/files/backup_full"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/n8n_backup_$DATE.tar.gz"
TEMP_DIR="/tmp/n8n_backup_$DATE"

# Äá»c cáº¥u hÃ¬nh Telegram tá»« file config náº¿u cÃ³
TELEGRAM_CONFIG_FILE="$N8N_DIR/telegram_config.conf"
ENABLE_TELEGRAM_BACKUP=false
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

if [ -f "$TELEGRAM_CONFIG_FILE" ]; then
    source "$TELEGRAM_CONFIG_FILE"
fi

# HÃ m ghi log vá»›i timestamp
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$BACKUP_DIR/backup.log"
}

# HÃ m gá»­i thÃ´ng bÃ¡o qua Telegram
send_telegram_notification() {
    local message="$1"
    local document_path="$2"
    
    if [ "$ENABLE_TELEGRAM_BACKUP" = true ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        # Gá»­i thÃ´ng bÃ¡o text
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$message" \
            -d parse_mode="HTML" > /dev/null
        
        # Gá»­i file backup náº¿u cÃ³ vÃ  kÃ­ch thÆ°á»›c < 50MB
        if [ -n "$document_path" ] && [ -f "$document_path" ]; then
            local file_size=$(stat --format="%s" "$document_path")
            local max_size=$((50 * 1024 * 1024))  # 50MB in bytes
            
            if [ "$file_size" -lt "$max_size" ]; then
                curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument" \
                    -F chat_id="$TELEGRAM_CHAT_ID" \
                    -F document=@"$document_path" \
                    -F caption="ðŸ“¦ Backup N8N - $(date '+%d/%m/%Y %H:%M:%S')" > /dev/null
                log "âœ… ÄÃ£ gá»­i file backup qua Telegram"
            else
                local size_mb=$((file_size / 1024 / 1024))
                log "âš ï¸ File backup quÃ¡ lá»›n (${size_mb}MB) Ä‘á»ƒ gá»­i qua Telegram (giá»›i háº¡n 50MB)"
                curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
                    -d chat_id="$TELEGRAM_CHAT_ID" \
                    -d text="âš ï¸ File backup quÃ¡ lá»›n (${size_mb}MB) Ä‘á»ƒ gá»­i qua Telegram" > /dev/null
            fi
        fi
    fi
}

# HÃ m kiá»ƒm tra vÃ  táº¡o thÆ° má»¥c backup
setup_backup_directories() {
    mkdir -p "$TEMP_DIR"
    mkdir -p "$TEMP_DIR/workflows"
    mkdir -p "$TEMP_DIR/credentials"
    mkdir -p "$TEMP_DIR/settings"
    mkdir -p "$BACKUP_DIR"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log "âŒ KhÃ´ng thá»ƒ táº¡o thÆ° má»¥c backup: $BACKUP_DIR"
        exit 1
    fi
}

# Báº¯t Ä‘áº§u quÃ¡ trÃ¬nh backup
log "ðŸš€ Báº¯t Ä‘áº§u sao lÆ°u workflows vÃ  credentials..."
send_telegram_notification "ðŸš€ <b>Báº¯t Ä‘áº§u backup N8N</b>%0Aâ° Thá»i gian: $(date '+%d/%m/%Y %H:%M:%S')"

# Thiáº¿t láº­p thÆ° má»¥c
setup_backup_directories

# TÃ¬m container n8n
N8N_CONTAINER=$(docker ps -q --filter "name=n8n" 2>/dev/null | head -n 1)

if [ -z "$N8N_CONTAINER" ]; then
    log "âŒ KhÃ´ng tÃ¬m tháº¥y container n8n Ä‘ang cháº¡y"
    send_telegram_notification "âŒ <b>Lá»—i Backup N8N</b>%0AðŸ” KhÃ´ng tÃ¬m tháº¥y container n8n Ä‘ang cháº¡y"
    rm -rf "$TEMP_DIR"
    exit 1
fi

log "âœ… TÃ¬m tháº¥y container n8n: $N8N_CONTAINER"

# Xuáº¥t táº¥t cáº£ workflows
log "ðŸ“‹ Äang xuáº¥t danh sÃ¡ch workflows..."
WORKFLOWS_JSON=$(docker exec $N8N_CONTAINER n8n list:workflows --json 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$WORKFLOWS_JSON" ]; then
    # Äáº¿m sá»‘ lÆ°á»£ng workflows
    WORKFLOW_COUNT=$(echo "$WORKFLOWS_JSON" | jq '. | length' 2>/dev/null || echo "0")
    log "ðŸ’¼ TÃ¬m tháº¥y $WORKFLOW_COUNT workflows"
    
    if [ "$WORKFLOW_COUNT" -gt 0 ]; then
        # Xuáº¥t tá»«ng workflow riÃªng láº»
        echo "$WORKFLOWS_JSON" | jq -c '.[]' 2>/dev/null | while read -r workflow; do
            id=$(echo "$workflow" | jq -r '.id' 2>/dev/null)
            name=$(echo "$workflow" | jq -r '.name' 2>/dev/null | tr -dc '[:alnum:][:space:]_-' | tr '[:space:]' '_')
            
            if [ -n "$id" ] && [ "$id" != "null" ]; then
                log "ðŸ“„ Äang xuáº¥t workflow: $name (ID: $id)"
                docker exec $N8N_CONTAINER n8n export:workflow --id="$id" --output="/tmp/workflow_$id.json" 2>/dev/null
                
                if [ $? -eq 0 ]; then
                    docker cp "$N8N_CONTAINER:/tmp/workflow_$id.json" "$TEMP_DIR/workflows/$id-$name.json" 2>/dev/null
                    docker exec $N8N_CONTAINER rm -f "/tmp/workflow_$id.json" 2>/dev/null
                else
                    log "âš ï¸ KhÃ´ng thá»ƒ xuáº¥t workflow: $name (ID: $id)"
                fi
            fi
        done
        
        # Xuáº¥t táº¥t cáº£ workflows vÃ o má»™t file duy nháº¥t
        log "ðŸ“¦ Äang xuáº¥t táº¥t cáº£ workflows vÃ o file tá»•ng há»£p..."
        docker exec $N8N_CONTAINER n8n export:workflow --all --output="/tmp/all_workflows.json" 2>/dev/null
        if [ $? -eq 0 ]; then
            docker cp "$N8N_CONTAINER:/tmp/all_workflows.json" "$TEMP_DIR/workflows/all_workflows.json" 2>/dev/null
            docker exec $N8N_CONTAINER rm -f "/tmp/all_workflows.json" 2>/dev/null
        fi
    else
        log "âš ï¸ KhÃ´ng tÃ¬m tháº¥y workflow nÃ o Ä‘á»ƒ sao lÆ°u"
    fi
else
    log "âš ï¸ KhÃ´ng thá»ƒ láº¥y danh sÃ¡ch workflows hoáº·c khÃ´ng cÃ³ workflows nÃ o"
fi

# Sao lÆ°u credentials (database vÃ  encryption key)
log "ðŸ” Äang sao lÆ°u credentials vÃ  cáº¥u hÃ¬nh..."

# Sao lÆ°u database
if docker exec $N8N_CONTAINER test -f "/home/node/.n8n/database.sqlite"; then
    docker cp "$N8N_CONTAINER:/home/node/.n8n/database.sqlite" "$TEMP_DIR/credentials/" 2>/dev/null
    if [ $? -eq 0 ]; then
        log "âœ… ÄÃ£ sao lÆ°u database.sqlite"
    else
        log "âš ï¸ KhÃ´ng thá»ƒ sao lÆ°u database.sqlite"
    fi
else
    log "âš ï¸ KhÃ´ng tÃ¬m tháº¥y database.sqlite"
fi

# Sao lÆ°u encryption key
if docker exec $N8N_CONTAINER test -f "/home/node/.n8n/config"; then
    docker cp "$N8N_CONTAINER:/home/node/.n8n/config" "$TEMP_DIR/credentials/" 2>/dev/null
    log "âœ… ÄÃ£ sao lÆ°u file config"
fi

# Sao lÆ°u cÃ¡c file cáº¥u hÃ¬nh khÃ¡c
for config_file in "encryptionKey" "settings.json" "config.json"; do
    if docker exec $N8N_CONTAINER test -f "/home/node/.n8n/$config_file"; then
        docker cp "$N8N_CONTAINER:/home/node/.n8n/$config_file" "$TEMP_DIR/credentials/" 2>/dev/null
        if [ $? -eq 0 ]; then
            log "âœ… ÄÃ£ sao lÆ°u $config_file"
        fi
    fi
done

# Táº¡o file thÃ´ng tin backup
cat << INFO > "$TEMP_DIR/backup_info.txt"
N8N Backup Information
======================
Backup Date: $(date)
N8N Container: $N8N_CONTAINER
Backup Version: 2.0
Created By: Nguyá»…n Ngá»c Thiá»‡n
YouTube Channel: https://www.youtube.com/@kalvinthiensocial

Backup Contents:
- Workflows: $(find "$TEMP_DIR/workflows" -name "*.json" | wc -l) files
- Database: $([ -f "$TEMP_DIR/credentials/database.sqlite" ] && echo "âœ… Included" || echo "âŒ Missing")
- Encryption Key: $([ -f "$TEMP_DIR/credentials/encryptionKey" ] && echo "âœ… Included" || echo "âŒ Missing")
- Config Files: $(find "$TEMP_DIR/credentials" -name "*.json" | wc -l) files

Restore Instructions:
1. Stop N8N container
2. Extract this backup
3. Copy database.sqlite and encryptionKey to .n8n directory
4. Import workflows using n8n import:workflow command
5. Restart N8N container

For support: 08.8888.4749
INFO

# Táº¡o file tar.gz nÃ©n
log "ðŸ“¦ Äang táº¡o file backup nÃ©n: $BACKUP_FILE"
tar -czf "$BACKUP_FILE" -C "$(dirname "$TEMP_DIR")" "$(basename "$TEMP_DIR")" 2>/dev/null

if [ $? -eq 0 ] && [ -f "$BACKUP_FILE" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log "âœ… ÄÃ£ táº¡o file backup: $BACKUP_FILE ($BACKUP_SIZE)"
    
    # Gá»­i thÃ´ng bÃ¡o thÃ nh cÃ´ng qua Telegram
    send_telegram_notification "âœ… <b>Backup N8N hoÃ n táº¥t!</b>%0AðŸ“¦ File: $(basename "$BACKUP_FILE")%0AðŸ“Š KÃ­ch thÆ°á»›c: $BACKUP_SIZE%0Aâ° Thá»i gian: $(date '+%d/%m/%Y %H:%M:%S')" "$BACKUP_FILE"
else
    log "âŒ KhÃ´ng thá»ƒ táº¡o file backup"
    send_telegram_notification "âŒ <b>Lá»—i táº¡o file backup N8N</b>%0Aâ° Thá»i gian: $(date '+%d/%m/%Y %H:%M:%S')"
fi

# Dá»n dáº¹p thÆ° má»¥c táº¡m thá»i
log "ðŸ§¹ Dá»n dáº¹p thÆ° má»¥c táº¡m thá»i..."
rm -rf "$TEMP_DIR"

# Giá»¯ láº¡i tá»‘i Ä‘a 30 báº£n sao lÆ°u gáº§n nháº¥t
log "ðŸ—‚ï¸ Giá»¯ láº¡i 30 báº£n sao lÆ°u gáº§n nháº¥t..."
OLD_BACKUPS=$(find "$BACKUP_DIR" -name "n8n_backup_*.tar.gz" -type f | sort -r | tail -n +31)
if [ -n "$OLD_BACKUPS" ]; then
    echo "$OLD_BACKUPS" | xargs rm -f
    DELETED_COUNT=$(echo "$OLD_BACKUPS" | wc -l)
    log "ðŸ—‘ï¸ ÄÃ£ xÃ³a $DELETED_COUNT báº£n backup cÅ©"
fi

# Thá»‘ng kÃª tá»•ng quan
TOTAL_BACKUPS=$(find "$BACKUP_DIR" -name "n8n_backup_*.tar.gz" -type f | wc -l)
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

log "ðŸ“Š === THá»NG KÃŠ BACKUP ==="
log "ðŸ“ Tá»•ng sá»‘ backup: $TOTAL_BACKUPS"
log "ðŸ’¾ Tá»•ng dung lÆ°á»£ng: $TOTAL_SIZE"
log "âœ… Sao lÆ°u hoÃ n táº¥t: $BACKUP_FILE"

echo ""
echo "ðŸŽ‰ Backup hoÃ n táº¥t thÃ nh cÃ´ng!"
echo "ðŸ“ File backup: $BACKUP_FILE"
echo "ðŸ“Š KÃ­ch thÆ°á»›c: $BACKUP_SIZE"
echo ""
echo "ðŸŽ¥ HÆ°á»›ng dáº«n khÃ´i phá»¥c: https://www.youtube.com/@kalvinthiensocial"
echo "ðŸ“ž Há»— trá»£: 08.8888.4749"
EOF

# Äáº·t quyá»n thá»±c thi cho script sao lÆ°u
chmod +x $N8N_DIR/backup-workflows.sh

# Táº¡o file cáº¥u hÃ¬nh Telegram náº¿u Ä‘Æ°á»£c kÃ­ch hoáº¡t
if [ "$ENABLE_TELEGRAM_BACKUP" = true ]; then
    echo "ðŸ“± Táº¡o file cáº¥u hÃ¬nh Telegram..."
    cat << EOF > $N8N_DIR/telegram_config.conf
# Cáº¥u hÃ¬nh Telegram Bot cho N8N Backup
# TÃ¡c giáº£: $AUTHOR_NAME
ENABLE_TELEGRAM_BACKUP=true
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"
EOF
    chmod 600 $N8N_DIR/telegram_config.conf
    echo "âœ… ÄÃ£ táº¡o file cáº¥u hÃ¬nh Telegram"
fi

# Táº¡o FastAPI application náº¿u Ä‘Æ°á»£c kÃ­ch hoáº¡t
if [ "$ENABLE_FASTAPI" = true ]; then
    echo "âš¡ CÃ i Ä‘áº·t FastAPI vÃ  cÃ¡c dependencies..."
    
    # Cáº­p nháº­t docker-compose.yml Ä‘á»ƒ bao gá»“m FastAPI service
    cat << EOF > $N8N_DIR/docker-compose.yml
# Cáº¥u hÃ¬nh Docker Compose cho N8N vá»›i FFmpeg, yt-dlp, Puppeteer vÃ  FastAPI
# TÃ¡c giáº£: $AUTHOR_NAME
# YouTube: $YOUTUBE_CHANNEL
services:
  n8n:
    build:
      context: .
      dockerfile: Dockerfile
    image: n8n-ffmpeg-latest
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=${DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://${DOMAIN}
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
      # Cáº¥u hÃ¬nh binary data mode
      - N8N_DEFAULT_BINARY_DATA_MODE=filesystem
      - N8N_BINARY_DATA_STORAGE=/files
      - N8N_DEFAULT_BINARY_DATA_FILESYSTEM_DIRECTORY=/files
      - N8N_DEFAULT_BINARY_DATA_TEMP_DIRECTORY=/files/temp
      - NODE_FUNCTION_ALLOW_BUILTIN=child_process,path,fs,util,os
      - N8N_EXECUTIONS_DATA_MAX_SIZE=304857600
      # Cáº¥u hÃ¬nh Puppeteer
      - PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
      - PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
    volumes:
      - ${N8N_DIR}:/home/node/.n8n
      - ${N8N_DIR}/files:/files
    user: "1000:1000"
    cap_add:
      - SYS_ADMIN  # ThÃªm quyá»n cho Puppeteer

  fastapi:
    build:
      context: .
      dockerfile: Dockerfile.fastapi
    image: fastapi-newspaper
    restart: always
    ports:
      - "${FASTAPI_PORT}:8000"
    environment:
      - FASTAPI_PASSWORD=${FASTAPI_PASSWORD}
      - FASTAPI_HOST=0.0.0.0
      - FASTAPI_PORT=8000
    volumes:
      - ${N8N_DIR}/fastapi_logs:/app/logs
    depends_on:
      - n8n

  caddy:
    image: caddy:2
    restart: always
    ports:
      - "8080:80"  # Sá»­ dá»¥ng cá»•ng 8080 thay vÃ¬ 80 Ä‘á»ƒ trÃ¡nh xung Ä‘á»™t
      - "443:443"
    volumes:
      - ${N8N_DIR}/Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - n8n
      - fastapi

volumes:
  caddy_data:
  caddy_config:
EOF

    # Cáº­p nháº­t Caddyfile Ä‘á»ƒ bao gá»“m FastAPI
    cat << EOF > $N8N_DIR/Caddyfile
${DOMAIN} {
    reverse_proxy n8n:5678
}

api.${DOMAIN} {
    reverse_proxy fastapi:8000
}
EOF

    # Táº¡o Dockerfile cho FastAPI
    echo "ðŸ³ Táº¡o Dockerfile.fastapi..."
    cat << 'EOF' > $N8N_DIR/Dockerfile.fastapi
FROM python:3.11-slim

WORKDIR /app

# CÃ i Ä‘áº·t cÃ¡c packages cáº§n thiáº¿t cho newspaper4k
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    libxml2-dev \
    libxslt-dev \
    libjpeg-dev \
    zlib1g-dev \
    libpng-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements vÃ  cÃ i Ä‘áº·t dependencies
COPY fastapi_requirements.txt .
RUN pip install --no-cache-dir -r fastapi_requirements.txt

# Copy á»©ng dá»¥ng
COPY fastapi_app.py .
COPY templates/ templates/

# Táº¡o thÆ° má»¥c logs
RUN mkdir -p logs

# Expose port
EXPOSE 8000

# Cháº¡y á»©ng dá»¥ng
CMD ["python", "fastapi_app.py"]
EOF

    # Táº¡o requirements.txt cho FastAPI
    echo "ðŸ“„ Táº¡o fastapi_requirements.txt..."
    cat << EOF > $N8N_DIR/fastapi_requirements.txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
newspaper4k==0.9.3.1
requests==2.31.0
python-multipart==0.0.6
jinja2==3.1.2
fake-useragent==1.4.0
beautifulsoup4==4.12.2
lxml==4.9.3
python-dateutil==2.8.2
pydantic==2.5.0
aiofiles==23.2.1
EOF

    # Táº¡o á»©ng dá»¥ng FastAPI
    echo "âš¡ Táº¡o á»©ng dá»¥ng FastAPI..."
    cat << 'EOF' > $N8N_DIR/fastapi_app.py
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
FastAPI Article Extractor
TÃ¡c giáº£: Nguyá»…n Ngá»c Thiá»‡n
YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1
Facebook: https://www.facebook.com/Ban.Thien.Handsome/
Zalo/SDT: 08.8888.4749

API Ä‘á»ƒ láº¥y ná»™i dung bÃ i viáº¿t tá»« URL sá»­ dá»¥ng newspaper4k
"""

import os
import uvicorn
import logging
from datetime import datetime
from typing import Optional, Dict, Any, List
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Depends, Request, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, HttpUrl, Field

import newspaper
from newspaper import Article
from fake_useragent import UserAgent
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# Cáº¥u hÃ¬nh logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/fastapi.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Cáº¥u hÃ¬nh
FASTAPI_PASSWORD = os.getenv("FASTAPI_PASSWORD", "default_password")
FASTAPI_HOST = os.getenv("FASTAPI_HOST", "0.0.0.0")
FASTAPI_PORT = int(os.getenv("FASTAPI_PORT", 8000))

# Khá»Ÿi táº¡o user agent ngáº«u nhiÃªn
ua = UserAgent()

# Security
security = HTTPBearer()

# Templates
templates = Jinja2Templates(directory="templates")

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """XÃ¡c thá»±c Bearer token"""
    if credentials.credentials != FASTAPI_PASSWORD:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token khÃ´ng há»£p lá»‡",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return credentials.credentials

# Models
class ArticleRequest(BaseModel):
    url: HttpUrl = Field(..., description="URL cá»§a bÃ i viáº¿t cáº§n láº¥y ná»™i dung")
    language: Optional[str] = Field("vi", description="NgÃ´n ngá»¯ cá»§a bÃ i viáº¿t (vi, en, etc.)")
    
class ArticleResponse(BaseModel):
    success: bool = Field(..., description="Tráº¡ng thÃ¡i thÃ nh cÃ´ng")
    url: str = Field(..., description="URL gá»‘c")
    title: Optional[str] = Field(None, description="TiÃªu Ä‘á» bÃ i viáº¿t")
    text: Optional[str] = Field(None, description="Ná»™i dung chÃ­nh cá»§a bÃ i viáº¿t")
    summary: Optional[str] = Field(None, description="TÃ³m táº¯t tá»± Ä‘á»™ng")
    authors: List[str] = Field(default_factory=list, description="Danh sÃ¡ch tÃ¡c giáº£")
    publish_date: Optional[str] = Field(None, description="NgÃ y xuáº¥t báº£n")
    top_image: Optional[str] = Field(None, description="áº¢nh Ä‘áº¡i diá»‡n")
    keywords: List[str] = Field(default_factory=list, description="Tá»« khÃ³a")
    meta_description: Optional[str] = Field(None, description="MÃ´ táº£ meta")
    meta_keywords: Optional[str] = Field(None, description="Tá»« khÃ³a meta")
    canonical_link: Optional[str] = Field(None, description="Link canonical")
    extracted_at: str = Field(..., description="Thá»i gian trÃ­ch xuáº¥t")
    processing_time: float = Field(..., description="Thá»i gian xá»­ lÃ½ (giÃ¢y)")

class ErrorResponse(BaseModel):
    success: bool = False
    error: str = Field(..., description="ThÃ´ng bÃ¡o lá»—i")
    error_code: str = Field(..., description="MÃ£ lá»—i")
    url: Optional[str] = Field(None, description="URL gÃ¢y lá»—i")

def create_session():
    """Táº¡o session vá»›i retry vÃ  user agent"""
    session = requests.Session()
    
    # Cáº¥u hÃ¬nh retry
    retry_strategy = Retry(
        total=3,
        backoff_factor=1,
        status_forcelist=[429, 500, 502, 503, 504],
    )
    
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    
    # User agent ngáº«u nhiÃªn
    headers = {
        'User-Agent': ua.random,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'vi-VN,vi;q=0.9,en;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
    }
    session.headers.update(headers)
    
    return session

def extract_article_content(url: str, language: str = "vi") -> Dict[str, Any]:
    """TrÃ­ch xuáº¥t ná»™i dung bÃ i viáº¿t"""
    start_time = datetime.now()
    
    try:
        # Táº¡o session tÃ¹y chá»‰nh
        session = create_session()
        
        # Táº¡o Article object
        article = Article(url, language=language)
        article.set_requests_session(session)
        
        # Download vÃ  parse
        article.download()
        article.parse()
        
        # NLP processing (tÃ³m táº¯t vÃ  keywords)
        try:
            article.nlp()
        except Exception as nlp_error:
            logger.warning(f"NLP processing failed: {nlp_error}")
        
        # TÃ­nh thá»i gian xá»­ lÃ½
        processing_time = (datetime.now() - start_time).total_seconds()
        
        # Chuáº©n bá»‹ response
        result = {
            "success": True,
            "url": url,
            "title": article.title or "",
            "text": article.text or "",
            "summary": article.summary or "",
            "authors": list(article.authors) if article.authors else [],
            "publish_date": article.publish_date.isoformat() if article.publish_date else None,
            "top_image": article.top_image or "",
            "keywords": list(article.keywords) if hasattr(article, 'keywords') and article.keywords else [],
            "meta_description": article.meta_description or "",
            "meta_keywords": article.meta_keywords or "",
            "canonical_link": article.canonical_link or "",
            "extracted_at": datetime.now().isoformat(),
            "processing_time": round(processing_time, 2)
        }
        
        logger.info(f"Successfully extracted article: {url} in {processing_time:.2f}s")
        return result
        
    except Exception as e:
        processing_time = (datetime.now() - start_time).total_seconds()
        error_msg = f"Lá»—i khi trÃ­ch xuáº¥t bÃ i viáº¿t: {str(e)}"
        logger.error(f"Error extracting {url}: {error_msg}")
        
        return {
            "success": False,
            "error": error_msg,
            "error_code": "EXTRACTION_ERROR",
            "url": url,
            "processing_time": round(processing_time, 2)
        }

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle management"""
    logger.info("ðŸš€ FastAPI Article Extractor Ä‘ang khá»Ÿi Ä‘á»™ng...")
    logger.info(f"ðŸ‘¤ TÃ¡c giáº£: Nguyá»…n Ngá»c Thiá»‡n")
    logger.info(f"ðŸ“º YouTube: https://www.youtube.com/@kalvinthiensocial")
    logger.info(f"ðŸ“± LiÃªn há»‡: 08.8888.4749")
    yield
    logger.info("ðŸ›‘ FastAPI Article Extractor Ä‘ang táº¯t...")

# Khá»Ÿi táº¡o FastAPI app
app = FastAPI(
    title="N8N Article Extractor API",
    description="""
    ðŸš€ **API TrÃ­ch Xuáº¥t Ná»™i Dung BÃ i Viáº¿t**
    
    API nÃ y cho phÃ©p trÃ­ch xuáº¥t ná»™i dung tá»« báº¥t ká»³ URL bÃ i viáº¿t nÃ o sá»­ dá»¥ng thÆ° viá»‡n newspaper4k.
    
    **TÃ¡c giáº£:** Nguyá»…n Ngá»c Thiá»‡n  
    **YouTube:** [Kalvin Thien Social](https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1)  
    **Facebook:** [Ban Thien Handsome](https://www.facebook.com/Ban.Thien.Handsome/)  
    **LiÃªn há»‡:** 08.8888.4749
    
    ## TÃ­nh nÄƒng:
    - âœ… TrÃ­ch xuáº¥t tiÃªu Ä‘á», ná»™i dung, tÃ¡c giáº£
    - âœ… TÃ³m táº¯t tá»± Ä‘á»™ng báº±ng AI
    - âœ… TrÃ­ch xuáº¥t tá»« khÃ³a
    - âœ… Há»— trá»£ nhiá»u ngÃ´n ngá»¯
    - âœ… Random User-Agent Ä‘á»ƒ trÃ¡nh block
    - âœ… Retry mechanism
    - âœ… Bearer Token authentication
    
    ## CÃ¡ch sá»­ dá»¥ng vá»›i N8N:
    1. Sá»­ dá»¥ng HTTP Request node
    2. URL: `https://api.yourdomain.com/extract`
    3. Method: POST
    4. Headers: `Authorization: Bearer YOUR_PASSWORD`
    5. Body: `{"url": "https://example.com/article"}`
    """,
    version="2.0.0",
    contact={
        "name": "Nguyá»…n Ngá»c Thiá»‡n",
        "url": "https://www.youtube.com/@kalvinthiensocial",
        "email": "contact@example.com"
    },
    lifespan=lifespan
)

@app.get("/", response_class=HTMLResponse, include_in_schema=False)
async def root(request: Request):
    """Trang chá»§ vá»›i hÆ°á»›ng dáº«n sá»­ dá»¥ng"""
    return templates.TemplateResponse("index.html", {
        "request": request,
        "title": "N8N Article Extractor API",
        "author": "Nguyá»…n Ngá»c Thiá»‡n",
        "youtube": "https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1",
        "facebook": "https://www.facebook.com/Ban.Thien.Handsome/",
        "contact": "08.8888.4749"
    })

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "version": "2.0.0",
        "author": "Nguyá»…n Ngá»c Thiá»‡n"
    }

@app.post("/extract", response_model=ArticleResponse)
async def extract_article(
    request: ArticleRequest,
    token: str = Depends(verify_token)
):
    """
    TrÃ­ch xuáº¥t ná»™i dung bÃ i viáº¿t tá»« URL
    
    **YÃªu cáº§u Bearer Token authentication**
    """
    url = str(request.url)
    language = request.language or "vi"
    
    logger.info(f"Extracting article: {url} (language: {language})")
    
    result = extract_article_content(url, language)
    
    if result["success"]:
        return ArticleResponse(**result)
    else:
        raise HTTPException(
            status_code=400,
            detail=ErrorResponse(**result).dict()
        )

@app.post("/extract/batch", dependencies=[Depends(verify_token)])
async def extract_articles_batch(
    urls: List[HttpUrl],
    language: Optional[str] = "vi"
):
    """
    TrÃ­ch xuáº¥t nhiá»u bÃ i viáº¿t cÃ¹ng lÃºc (tá»‘i Ä‘a 10 URLs)
    
    **YÃªu cáº§u Bearer Token authentication**
    """
    if len(urls) > 10:
        raise HTTPException(
            status_code=400,
            detail="Tá»‘i Ä‘a 10 URLs cho má»—i batch request"
        )
    
    logger.info(f"Batch extracting {len(urls)} articles")
    
    results = []
    for url in urls:
        result = extract_article_content(str(url), language)
        results.append(result)
    
    return {
        "success": True,
        "total": len(urls),
        "processed": len(results),
        "results": results,
        "processed_at": datetime.now().isoformat()
    }

@app.get("/stats", dependencies=[Depends(verify_token)])
async def get_stats():
    """Thá»‘ng kÃª sá»­ dá»¥ng API"""
    return {
        "api_version": "2.0.0",
        "author": "Nguyá»…n Ngá»c Thiá»‡n",
        "contact": "08.8888.4749",
        "youtube_channel": "https://www.youtube.com/@kalvinthiensocial",
        "facebook": "https://www.facebook.com/Ban.Thien.Handsome/",
        "uptime": datetime.now().isoformat(),
        "supported_features": [
            "Article content extraction",
            "Automatic summarization",
            "Keyword extraction",
            "Multi-language support",
            "Batch processing",
            "Random User-Agent",
            "Retry mechanism"
        ]
    }

if __name__ == "__main__":
    logger.info(f"ðŸš€ Khá»Ÿi Ä‘á»™ng FastAPI server trÃªn {FASTAPI_HOST}:{FASTAPI_PORT}")
    uvicorn.run(
        "fastapi_app:app",
        host=FASTAPI_HOST,
        port=FASTAPI_PORT,
        reload=False,
        access_log=True
    )
EOF

    # Táº¡o thÆ° má»¥c templates
    mkdir -p $N8N_DIR/templates
    
    # Táº¡o template HTML
    echo "ðŸŽ¨ Táº¡o template HTML..."
    cat << 'EOF' > $N8N_DIR/templates/index.html
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ title }}</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            font-weight: 700;
        }
        
        .header p {
            font-size: 1.2em;
            opacity: 0.9;
        }
        
        .content {
            padding: 50px;
        }
        
        .author-info {
            background: #f8f9fa;
            border-radius: 15px;
            padding: 30px;
            margin-bottom: 40px;
            text-align: center;
        }
        
        .author-info h2 {
            color: #667eea;
            margin-bottom: 20px;
        }
        
        .social-links {
            display: flex;
            justify-content: center;
            gap: 20px;
            flex-wrap: wrap;
            margin-top: 20px;
        }
        
        .social-link {
            display: inline-flex;
            align-items: center;
            gap: 10px;
            background: #667eea;
            color: white;
            padding: 12px 24px;
            border-radius: 25px;
            text-decoration: none;
            transition: all 0.3s ease;
            font-weight: 500;
        }
        
        .social-link:hover {
            background: #764ba2;
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(0,0,0,0.15);
        }
        
        .api-docs {
            background: #fff;
            border: 2px solid #e9ecef;
            border-radius: 15px;
            padding: 30px;
            margin: 30px 0;
        }
        
        .api-docs h3 {
            color: #667eea;
            margin-bottom: 20px;
            font-size: 1.5em;
        }
        
        .endpoint {
            background: #f8f9fa;
            border-left: 4px solid #667eea;
            padding: 20px;
            margin: 20px 0;
            border-radius: 8px;
        }
        
        .endpoint-method {
            background: #28a745;
            color: white;
            padding: 4px 12px;
            border-radius: 4px;
            font-size: 0.8em;
            font-weight: bold;
            margin-right: 10px;
        }
        
        .endpoint-method.post {
            background: #007bff;
        }
        
        pre {
            background: #2d3748;
            color: #e2e8f0;
            padding: 20px;
            border-radius: 8px;
            overflow-x: auto;
            margin: 15px 0;
            font-size: 0.9em;
        }
        
        .features {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 30px;
            margin: 40px 0;
        }
        
        .feature {
            background: white;
            border: 2px solid #e9ecef;
            border-radius: 15px;
            padding: 30px;
            text-align: center;
            transition: all 0.3s ease;
        }
        
        .feature:hover {
            border-color: #667eea;
            transform: translateY(-5px);
            box-shadow: 0 15px 35px rgba(0,0,0,0.1);
        }
        
        .feature-icon {
            font-size: 3em;
            margin-bottom: 20px;
        }
        
        .footer {
            background: #2d3748;
            color: white;
            text-align: center;
            padding: 30px;
        }
        
        @media (max-width: 768px) {
            .header h1 {
                font-size: 2em;
            }
            
            .content {
                padding: 30px 20px;
            }
            
            .social-links {
                flex-direction: column;
                align-items: center;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>ðŸš€ {{ title }}</h1>
            <p>API TrÃ­ch Xuáº¥t Ná»™i Dung BÃ i Viáº¿t Tá»± Äá»™ng</p>
        </div>
        
        <div class="content">
            <div class="author-info">
                <h2>ðŸ‘¨â€ðŸ’» ThÃ´ng Tin TÃ¡c Giáº£</h2>
                <p><strong>{{ author }}</strong></p>
                <p>ðŸ“ž LiÃªn há»‡: {{ contact }}</p>
                
                <div class="social-links">
                    <a href="{{ youtube }}" class="social-link" target="_blank">
                        ðŸ“º ÄÄƒng KÃ½ KÃªnh YouTube
                    </a>
                    <a href="{{ facebook }}" class="social-link" target="_blank">
                        ðŸ“˜ Facebook
                    </a>
                    <a href="tel:{{ contact }}" class="social-link">
                        ðŸ“± Zalo/Phone
                    </a>
                </div>
            </div>
            
            <div class="features">
                <div class="feature">
                    <div class="feature-icon">ðŸŽ¯</div>
                    <h3>TrÃ­ch Xuáº¥t ThÃ´ng Minh</h3>
                    <p>Tá»± Ä‘á»™ng trÃ­ch xuáº¥t tiÃªu Ä‘á», ná»™i dung, tÃ¡c giáº£ vÃ  thÃ´ng tin meta tá»« báº¥t ká»³ bÃ i viáº¿t nÃ o</p>
                </div>
                
                <div class="feature">
                    <div class="feature-icon">ðŸ¤–</div>
                    <h3>TÃ³m Táº¯t AI</h3>
                    <p>Tá»± Ä‘á»™ng táº¡o tÃ³m táº¯t vÃ  trÃ­ch xuáº¥t tá»« khÃ³a quan trá»ng tá»« ná»™i dung bÃ i viáº¿t</p>
                </div>
                
                <div class="feature">
                    <div class="feature-icon">ðŸŒ</div>
                    <h3>Äa NgÃ´n Ngá»¯</h3>
                    <p>Há»— trá»£ trÃ­ch xuáº¥t tá»« bÃ i viáº¿t báº±ng nhiá»u ngÃ´n ngá»¯ khÃ¡c nhau</p>
                </div>
                
                <div class="feature">
                    <div class="feature-icon">ðŸ”’</div>
                    <h3>Báº£o Máº­t</h3>
                    <p>Sá»­ dá»¥ng Bearer Token authentication Ä‘á»ƒ báº£o vá»‡ API khá»i truy cáº­p trÃ¡i phÃ©p</p>
                </div>
            </div>
            
            <div class="api-docs">
                <h3>ðŸ“– HÆ°á»›ng Dáº«n Sá»­ Dá»¥ng API</h3>
                
                <div class="endpoint">
                    <span class="endpoint-method post">POST</span>
                    <strong>/extract</strong> - TrÃ­ch xuáº¥t ná»™i dung tá»« má»™t URL
                    
                    <pre>{
  "url": "https://vnexpress.net/sample-article",
  "language": "vi"
}</pre>
                </div>
                
                <div class="endpoint">
                    <span class="endpoint-method post">POST</span>
                    <strong>/extract/batch</strong> - TrÃ­ch xuáº¥t nhiá»u URL cÃ¹ng lÃºc
                    
                    <pre>[
  "https://vnexpress.net/article-1",
  "https://vnexpress.net/article-2"
]</pre>
                </div>
                
                <div class="endpoint">
                    <span class="endpoint-method">GET</span>
                    <strong>/health</strong> - Kiá»ƒm tra tráº¡ng thÃ¡i API
                </div>
                
                <h4>ðŸ”‘ Authentication Header:</h4>
                <pre>Authorization: Bearer YOUR_PASSWORD</pre>
                
                <h4>ðŸ“Š Sá»­ dá»¥ng vá»›i N8N:</h4>
                <ol>
                    <li>ThÃªm HTTP Request node</li>
                    <li>URL: <code>https://api.yourdomain.com/extract</code></li>
                    <li>Method: POST</li>
                    <li>Headers: <code>Authorization: Bearer YOUR_PASSWORD</code></li>
                    <li>Body: JSON vá»›i URL cáº§n trÃ­ch xuáº¥t</li>
                </ol>
            </div>
            
            <div class="api-docs">
                <h3>ðŸ”— Links Quan Trá»ng</h3>
                <ul style="list-style: none; padding: 0;">
                    <li style="margin: 10px 0;">ðŸ“š <a href="/docs" target="_blank">API Documentation (Swagger)</a></li>
                    <li style="margin: 10px 0;">ðŸ”§ <a href="/redoc" target="_blank">API Documentation (ReDoc)</a></li>
                    <li style="margin: 10px 0;">â¤ï¸ <a href="/health" target="_blank">Health Check</a></li>
                </ul>
            </div>
        </div>
        
        <div class="footer">
            <p>&copy; 2024 {{ author }}. Made with â¤ï¸ for N8N Community</p>
            <p>ðŸŽ¥ Subscribe: {{ youtube }}</p>
        </div>
    </div>
</body>
</html>
EOF

    # Táº¡o thÆ° má»¥c logs cho FastAPI
    mkdir -p $N8N_DIR/fastapi_logs
    
    echo "âœ… ÄÃ£ táº¡o á»©ng dá»¥ng FastAPI hoÃ n chá»‰nh"
fi

# Äáº·t quyá»n cho thÆ° má»¥c n8n
echo "ðŸ” Äáº·t quyá»n cho thÆ° má»¥c n8n..."
chown -R 1000:1000 $N8N_DIR
chmod -R 755 $N8N_DIR

# Khá»Ÿi Ä‘á»™ng cÃ¡c container
echo "ðŸš€ Khá»Ÿi Ä‘á»™ng cÃ¡c container..."
echo "â³ LÆ°u Ã½: QuÃ¡ trÃ¬nh build image cÃ³ thá»ƒ máº¥t vÃ i phÃºt, vui lÃ²ng Ä‘á»£i..."
cd $N8N_DIR

# Kiá»ƒm tra cá»•ng 80 cÃ³ Ä‘ang Ä‘Æ°á»£c sá»­ dá»¥ng khÃ´ng
if netstat -tuln | grep -q ":80\s"; then
    echo "âš ï¸  Cáº¢NH BÃO: Cá»•ng 80 Ä‘ang Ä‘Æ°á»£c sá»­ dá»¥ng bá»Ÿi má»™t á»©ng dá»¥ng khÃ¡c. Caddy sáº½ sá»­ dá»¥ng cá»•ng 8080."
    # ÄÃ£ cáº¥u hÃ¬nh 8080 trong docker-compose.yml
else
    # Náº¿u cá»•ng 80 trá»‘ng, cáº­p nháº­t docker-compose.yml Ä‘á»ƒ sá»­ dá»¥ng cá»•ng 80
    sed -i 's/"8080:80"/"80:80"/g' $N8N_DIR/docker-compose.yml
    echo "âœ… Cá»•ng 80 Ä‘ang trá»‘ng. Caddy sáº½ sá»­ dá»¥ng cá»•ng 80 máº·c Ä‘á»‹nh."
fi

# Kiá»ƒm tra quyá»n truy cáº­p Docker
echo "ðŸ” Kiá»ƒm tra quyá»n truy cáº­p Docker..."
if ! docker ps &>/dev/null; then
    echo "ðŸ”‘ Khá»Ÿi Ä‘á»™ng container vá»›i sudo vÃ¬ quyá»n truy cáº­p Docker..."
    # Sá»­ dá»¥ng docker-compose hoáº·c docker compose tÃ¹y theo phiÃªn báº£n
    if command -v docker-compose &> /dev/null; then
        sudo docker-compose up -d
    elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
        sudo docker compose up -d
    else
        echo "âŒ Lá»—i: KhÃ´ng tÃ¬m tháº¥y lá»‡nh docker-compose hoáº·c docker compose."
        exit 1
    fi
else
    # Sá»­ dá»¥ng docker-compose hoáº·c docker compose tÃ¹y theo phiÃªn báº£n
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
        docker compose up -d
    else
        echo "âŒ Lá»—i: KhÃ´ng tÃ¬m tháº¥y lá»‡nh docker-compose hoáº·c docker compose."
        exit 1
    fi
fi

# Äá»£i má»™t lÃºc Ä‘á»ƒ cÃ¡c container cÃ³ thá»ƒ khá»Ÿi Ä‘á»™ng
echo "â³ Äá»£i cÃ¡c container khá»Ÿi Ä‘á»™ng..."
sleep 15

# XÃ¡c Ä‘á»‹nh lá»‡nh docker phÃ¹ há»£p vá»›i quyá»n truy cáº­p
if ! docker ps &>/dev/null; then
    DOCKER_CMD="sudo docker"
    DOCKER_COMPOSE_CMD="sudo docker-compose"
    if ! command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="sudo docker compose"
    fi
else
    DOCKER_CMD="docker"
    DOCKER_COMPOSE_CMD="docker-compose"
    if ! command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
    fi
fi

# Kiá»ƒm tra cÃ¡c container Ä‘Ã£ cháº¡y chÆ°a
echo "ðŸ” Kiá»ƒm tra cÃ¡c container Ä‘Ã£ cháº¡y chÆ°a..."

if $DOCKER_CMD ps | grep -q "n8n-ffmpeg-latest" || $DOCKER_CMD ps | grep -q "n8n"; then
    echo "âœ… Container n8n Ä‘Ã£ cháº¡y thÃ nh cÃ´ng."
else
    echo "â³ Container n8n Ä‘ang Ä‘Æ°á»£c khá»Ÿi Ä‘á»™ng, cÃ³ thá»ƒ máº¥t thÃªm thá»i gian..."
    echo "ðŸ“‹ Báº¡n cÃ³ thá»ƒ kiá»ƒm tra logs báº±ng lá»‡nh:"
    echo "   $DOCKER_COMPOSE_CMD logs -f n8n"
fi

if $DOCKER_CMD ps | grep -q "caddy:2"; then
    echo "âœ… Container caddy Ä‘Ã£ cháº¡y thÃ nh cÃ´ng."
else
    echo "â³ Container caddy Ä‘ang Ä‘Æ°á»£c khá»Ÿi Ä‘á»™ng, cÃ³ thá»ƒ máº¥t thÃªm thá»i gian..."
    echo "ðŸ“‹ Báº¡n cÃ³ thá»ƒ kiá»ƒm tra logs báº±ng lá»‡nh:"
    echo "   $DOCKER_COMPOSE_CMD logs -f caddy"
fi

if [ "$ENABLE_FASTAPI" = true ]; then
    if $DOCKER_CMD ps | grep -q "fastapi-newspaper"; then
        echo "âœ… Container FastAPI Ä‘Ã£ cháº¡y thÃ nh cÃ´ng."
    else
        echo "â³ Container FastAPI Ä‘ang Ä‘Æ°á»£c khá»Ÿi Ä‘á»™ng, cÃ³ thá»ƒ máº¥t thÃªm thá»i gian..."
        echo "ðŸ“‹ Báº¡n cÃ³ thá»ƒ kiá»ƒm tra logs báº±ng lá»‡nh:"
        echo "   $DOCKER_COMPOSE_CMD logs -f fastapi"
    fi
fi

# Hiá»ƒn thá»‹ thÃ´ng tin vá» cá»•ng Ä‘Æ°á»£c sá»­ dá»¥ng
CADDY_PORT=$(grep -o '"[0-9]\+:80"' $N8N_DIR/docker-compose.yml | cut -d':' -f1 | tr -d '"')
echo ""
echo "ðŸŒ === THÃ”NG TIN TRUY Cáº¬P ==="
echo "ðŸ”§ Cáº¥u hÃ¬nh cá»•ng HTTP: $CADDY_PORT"
if [ "$CADDY_PORT" = "8080" ]; then
    echo "ðŸŒ N8N: http://${DOMAIN}:8080 hoáº·c https://${DOMAIN}"
else
    echo "ðŸŒ N8N: http://${DOMAIN} hoáº·c https://${DOMAIN}"
fi

if [ "$ENABLE_FASTAPI" = true ]; then
    echo "âš¡ FastAPI: https://api.${DOMAIN} hoáº·c http://${DOMAIN}:${FASTAPI_PORT}"
    echo "ðŸ“š API Docs: https://api.${DOMAIN}/docs"
    echo "ðŸ”‘ Bearer Token: $FASTAPI_PASSWORD"
fi

# Kiá»ƒm tra FFmpeg, yt-dlp vÃ  Puppeteer trong container n8n
echo ""
echo "ðŸ” Kiá»ƒm tra cÃ¡c cÃ´ng cá»¥ trong container n8n..."

N8N_CONTAINER=$($DOCKER_CMD ps -q --filter "name=n8n" 2>/dev/null | head -n 1)
if [ -n "$N8N_CONTAINER" ]; then
    echo "ðŸ“¦ Container ID: $N8N_CONTAINER"
    
    if $DOCKER_CMD exec $N8N_CONTAINER ffmpeg -version &> /dev/null; then
        echo "âœ… FFmpeg Ä‘Ã£ Ä‘Æ°á»£c cÃ i Ä‘áº·t thÃ nh cÃ´ng trong container n8n."
        FFMPEG_VERSION=$($DOCKER_CMD exec $N8N_CONTAINER ffmpeg -version | head -n 1)
        echo "   ðŸ“Œ $FFMPEG_VERSION"
    else
        echo "âš ï¸  LÆ°u Ã½: FFmpeg cÃ³ thá»ƒ chÆ°a Ä‘Æ°á»£c cÃ i Ä‘áº·t Ä‘Ãºng cÃ¡ch trong container."
    fi

    if $DOCKER_CMD exec $N8N_CONTAINER yt-dlp --version &> /dev/null; then
        echo "âœ… yt-dlp Ä‘Ã£ Ä‘Æ°á»£c cÃ i Ä‘áº·t thÃ nh cÃ´ng trong container n8n."
        YTDLP_VERSION=$($DOCKER_CMD exec $N8N_CONTAINER yt-dlp --version)
        echo "   ðŸ“Œ yt-dlp version: $YTDLP_VERSION"
    else
        echo "âš ï¸  LÆ°u Ã½: yt-dlp cÃ³ thá»ƒ chÆ°a Ä‘Æ°á»£c cÃ i Ä‘áº·t Ä‘Ãºng cÃ¡ch trong container."
    fi
    
    if $DOCKER_CMD exec $N8N_CONTAINER chromium-browser --version &> /dev/null; then
        echo "âœ… Chromium Ä‘Ã£ Ä‘Æ°á»£c cÃ i Ä‘áº·t thÃ nh cÃ´ng trong container n8n."
        CHROMIUM_VERSION=$($DOCKER_CMD exec $N8N_CONTAINER chromium-browser --version)
        echo "   ðŸ“Œ $CHROMIUM_VERSION"
    else
        echo "âš ï¸  LÆ°u Ã½: Chromium cÃ³ thá»ƒ chÆ°a Ä‘Æ°á»£c cÃ i Ä‘áº·t Ä‘Ãºng cÃ¡ch trong container."
    fi
else
    echo "âš ï¸  LÆ°u Ã½: KhÃ´ng thá»ƒ kiá»ƒm tra cÃ´ng cá»¥ ngay lÃºc nÃ y. Container n8n chÆ°a sáºµn sÃ ng."
fi

# Táº¡o script cáº­p nháº­t tá»± Ä‘á»™ng Cáº¢I TIáº¾N
echo ""
echo "ðŸ”„ Táº¡o script cáº­p nháº­t tá»± Ä‘á»™ng..."
cat << 'EOF' > $N8N_DIR/update-n8n.sh
#!/bin/bash

# =============================================================================
# Script Cáº­p Nháº­t N8N Tá»± Äá»™ng - PhiÃªn báº£n cáº£i tiáº¿n
# TÃ¡c giáº£: Nguyá»…n Ngá»c Thiá»‡n
# YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1
# =============================================================================

# ÄÆ°á»ng dáº«n Ä‘áº¿n thÆ° má»¥c n8n
N8N_DIR="$N8N_DIR"

# HÃ m ghi log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$N8N_DIR/update.log"
}

log "ðŸš€ Báº¯t Ä‘áº§u kiá»ƒm tra cáº­p nháº­t..."

# Kiá»ƒm tra Docker command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    log "âŒ KhÃ´ng tÃ¬m tháº¥y lá»‡nh docker-compose hoáº·c docker compose."
    exit 1
fi

# Cáº­p nháº­t yt-dlp trÃªn host
log "ðŸ“º Cáº­p nháº­t yt-dlp trÃªn host system..."
if command -v pipx &> /dev/null; then
    pipx upgrade yt-dlp
elif [ -d "/opt/yt-dlp-venv" ]; then
    /opt/yt-dlp-venv/bin/pip install -U yt-dlp
else
    log "âš ï¸ KhÃ´ng tÃ¬m tháº¥y cÃ i Ä‘áº·t yt-dlp Ä‘Ã£ biáº¿t"
fi

# Láº¥y phiÃªn báº£n hiá»‡n táº¡i
CURRENT_IMAGE_ID=$(docker images -q n8n-ffmpeg-latest)
if [ -z "$CURRENT_IMAGE_ID" ]; then
    log "âš ï¸ KhÃ´ng tÃ¬m tháº¥y image n8n-ffmpeg-latest"
    exit 1
fi

# Kiá»ƒm tra vÃ  xÃ³a image gá»‘c n8nio/n8n cÅ© náº¿u cáº§n
OLD_BASE_IMAGE_ID=$(docker images -q n8nio/n8n)

# Pull image gá»‘c má»›i nháº¥t
log "â¬‡ï¸ KÃ©o image n8nio/n8n má»›i nháº¥t"
docker pull n8nio/n8n

# Láº¥y image ID má»›i
NEW_BASE_IMAGE_ID=$(docker images -q n8nio/n8n)

# Kiá»ƒm tra xem image gá»‘c Ä‘Ã£ thay Ä‘á»•i chÆ°a
if [ "$NEW_BASE_IMAGE_ID" != "$OLD_BASE_IMAGE_ID" ]; then
    log "ðŸ†• PhÃ¡t hiá»‡n image má»›i (${NEW_BASE_IMAGE_ID}), tiáº¿n hÃ nh cáº­p nháº­t..."
    
    # Sao lÆ°u dá»¯ liá»‡u n8n trÆ°á»›c khi cáº­p nháº­t
    BACKUP_DATE=$(date '+%Y%m%d_%H%M%S')
    BACKUP_FILE="$N8N_DIR/backup_before_update_${BACKUP_DATE}.zip"
    log "ðŸ’¾ Táº¡o báº£n sao lÆ°u trÆ°á»›c cáº­p nháº­t táº¡i $BACKUP_FILE"
    
    cd "$N8N_DIR"
    zip -r "$BACKUP_FILE" . -x "update-n8n.sh" -x "backup_*" -x "files/temp/*" -x "Dockerfile*" -x "docker-compose.yml" &>/dev/null
    
    # Build láº¡i image n8n-ffmpeg
    log "ðŸ”¨ Äang build láº¡i image n8n-ffmpeg-latest..."
    $DOCKER_COMPOSE build --no-cache
    
    # Khá»Ÿi Ä‘á»™ng láº¡i container
    log "ðŸ”„ Khá»Ÿi Ä‘á»™ng láº¡i container..."
    $DOCKER_COMPOSE down
    $DOCKER_COMPOSE up -d
    
    log "âœ… Cáº­p nháº­t hoÃ n táº¥t, phiÃªn báº£n má»›i: ${NEW_BASE_IMAGE_ID}"
    
    # Gá»­i thÃ´ng bÃ¡o Telegram náº¿u cÃ³
    if [ -f "$N8N_DIR/telegram_config.conf" ]; then
        source "$N8N_DIR/telegram_config.conf"
        if [ "$ENABLE_TELEGRAM_BACKUP" = true ]; then
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
                -d chat_id="$TELEGRAM_CHAT_ID" \
                -d text="âœ… <b>N8N Ä‘Ã£ Ä‘Æ°á»£c cáº­p nháº­t!</b>%0AðŸ†• Image ID: ${NEW_BASE_IMAGE_ID}%0Aâ° Thá»i gian: $(date '+%d/%m/%Y %H:%M:%S')" \
                -d parse_mode="HTML" > /dev/null
        fi
    fi
else
    log "â„¹ï¸ KhÃ´ng cÃ³ cáº­p nháº­t má»›i cho n8n"
    
    # Cáº­p nháº­t yt-dlp trong container
    log "ðŸ“º Cáº­p nháº­t yt-dlp trong container n8n..."
    N8N_CONTAINER=$(docker ps -q --filter "name=n8n" 2>/dev/null)
    if [ -n "$N8N_CONTAINER" ]; then
        docker exec -u root $N8N_CONTAINER pip3 install --break-system-packages -U yt-dlp
        log "âœ… yt-dlp Ä‘Ã£ Ä‘Æ°á»£c cáº­p nháº­t thÃ nh cÃ´ng trong container"
    else
        log "âš ï¸ KhÃ´ng tÃ¬m tháº¥y container n8n Ä‘ang cháº¡y"
    fi
fi

log "ðŸŽ‰ HoÃ n thÃ nh kiá»ƒm tra cáº­p nháº­t"
EOF

# Äáº·t quyá»n thá»±c thi cho script cáº­p nháº­t
chmod +x $N8N_DIR/update-n8n.sh

# Táº¡o cron job Ä‘á»ƒ cháº¡y má»—i 12 giá» vÃ  sao lÆ°u hÃ ng ngÃ y
echo "â° Thiáº¿t láº­p cron job cáº­p nháº­t tá»± Ä‘á»™ng má»—i 12 giá» vÃ  sao lÆ°u hÃ ng ngÃ y..."
UPDATE_CRON="0 */12 * * * $N8N_DIR/update-n8n.sh"
BACKUP_CRON="0 2 * * * $N8N_DIR/backup-workflows.sh"

# XÃ³a cÃ¡c cron job cÅ© vÃ  thÃªm má»›i
(crontab -l 2>/dev/null | grep -v "update-n8n.sh\|backup-workflows.sh"; echo "$UPDATE_CRON"; echo "$BACKUP_CRON") | crontab -

echo "âœ… ÄÃ£ thiáº¿t láº­p cron jobs thÃ nh cÃ´ng"

# Táº¡o script kiá»ƒm tra tráº¡ng thÃ¡i
echo "ðŸ“Š Táº¡o script kiá»ƒm tra tráº¡ng thÃ¡i..."
cat << 'EOF' > $N8N_DIR/check-status.sh
#!/bin/bash

# =============================================================================
# Script Kiá»ƒm Tra Tráº¡ng ThÃ¡i N8N
# TÃ¡c giáº£: Nguyá»…n Ngá»c Thiá»‡n
# =============================================================================

echo "ðŸ” === KIá»‚M TRA TRáº NG THÃI N8N ==="
echo "â° Thá»i gian: $(date)"
echo ""

# Kiá»ƒm tra Docker
if command -v docker &> /dev/null; then
    echo "âœ… Docker Ä‘Ã£ Ä‘Æ°á»£c cÃ i Ä‘áº·t"
    docker --version
else
    echo "âŒ Docker chÆ°a Ä‘Æ°á»£c cÃ i Ä‘áº·t"
fi

echo ""

# Kiá»ƒm tra cÃ¡c container
echo "ðŸ“¦ === TRáº NG THÃI CONTAINERS ==="
if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(n8n|caddy|fastapi)"; then
    echo ""
else
    echo "âš ï¸ KhÃ´ng tÃ¬m tháº¥y container nÃ o Ä‘ang cháº¡y"
fi

echo ""

# Kiá»ƒm tra disk space
echo "ðŸ’¾ === DUNG LÆ¯á»¢NG ÄÄ¨A ==="
df -h | grep -E "(^/dev|Filesystem)"

echo ""

# Kiá»ƒm tra backup
echo "ðŸ“¦ === BACKUP Gáº¦N NHáº¤T ==="
if [ -d "$N8N_DIR/files/backup_full" ]; then
    LATEST_BACKUP=$(find "$N8N_DIR/files/backup_full" -name "n8n_backup_*.tar.gz" -type f | sort -r | head -n 1)
    if [ -n "$LATEST_BACKUP" ]; then
        BACKUP_DATE=$(stat -c %y "$LATEST_BACKUP" | cut -d'.' -f1)
        BACKUP_SIZE=$(du -h "$LATEST_BACKUP" | cut -f1)
        echo "ðŸ“ File: $(basename "$LATEST_BACKUP")"
        echo "ðŸ“… NgÃ y: $BACKUP_DATE"
        echo "ðŸ“Š KÃ­ch thÆ°á»›c: $BACKUP_SIZE"
    else
        echo "âš ï¸ KhÃ´ng tÃ¬m tháº¥y file backup nÃ o"
    fi
else
    echo "âŒ ThÆ° má»¥c backup khÃ´ng tá»“n táº¡i"
fi

echo ""
echo "ðŸŽ¥ Há»— trá»£: https://www.youtube.com/@kalvinthiensocial"
echo "ðŸ“ž LiÃªn há»‡: 08.8888.4749"
EOF

chmod +x $N8N_DIR/check-status.sh

echo ""
echo "======================================================================"
echo "ðŸŽ‰    CÃ€I Äáº¶T N8N HOÃ€N Táº¤T THÃ€NH CÃ”NG!    ðŸŽ‰"
echo "======================================================================"
echo ""
echo "ðŸ‘¨â€ðŸ’» TÃ¡c giáº£: $AUTHOR_NAME"
echo "ðŸŽ¥ KÃªnh YouTube: $YOUTUBE_CHANNEL"
echo "ðŸ“˜ Facebook: $FACEBOOK_LINK"
echo "ðŸ“± LiÃªn há»‡: $CONTACT_INFO"
echo ""
echo "ðŸŒŸ === Cáº¢M Æ N Báº N ÄÃƒ Sá»¬ Dá»¤NG SCRIPT! ==="
echo "ðŸ”¥ HÃ£y ÄÄ‚NG KÃ kÃªnh YouTube Ä‘á»ƒ á»§ng há»™ tÃ¡c giáº£!"
echo "ðŸ’ Chia sáº» script nÃ y cho báº¡n bÃ¨ náº¿u tháº¥y há»¯u Ã­ch!"
echo ""

# Hiá»ƒn thá»‹ thÃ´ng tin vá» swap
if [ "$(swapon --show | wc -l)" -gt 0 ]; then
    SWAP_SIZE=$(free -h | grep Swap | awk '{print $2}')
    echo "ðŸ”„ === THÃ”NG TIN SWAP ==="
    echo "ðŸ“Š KÃ­ch thÆ°á»›c: ${SWAP_SIZE}"
    echo "âš™ï¸ Swappiness: $(cat /proc/sys/vm/swappiness) (má»©c Æ°u tiÃªn sá»­ dá»¥ng RAM)"
    echo "ðŸ—‚ï¸ Vfs_cache_pressure: $(cat /proc/sys/vm/vfs_cache_pressure) (tá»‘c Ä‘á»™ giáº£i phÃ³ng cache)"
    echo ""
fi

echo "ðŸ“ === THÃ”NG TIN Há»† THá»NG ==="
echo "ðŸ—ƒï¸ ThÆ° má»¥c cÃ i Ä‘áº·t: $N8N_DIR"
echo "ðŸŒ Truy cáº­p N8N: https://${DOMAIN}"

if [ "$ENABLE_FASTAPI" = true ]; then
    echo "âš¡ === THÃ”NG TIN FASTAPI ==="
    echo "ðŸŒ API URL: https://api.${DOMAIN}"
    echo "ðŸ“š API Docs: https://api.${DOMAIN}/docs"
    echo "ðŸ”‘ Bearer Token: $FASTAPI_PASSWORD"
fi

if [ "$ENABLE_TELEGRAM_BACKUP" = true ]; then
    echo "ðŸ“± === THÃ”NG TIN TELEGRAM ==="
    echo "ðŸ¤– Bot Token: ${TELEGRAM_BOT_TOKEN:0:10}..."
    echo "ðŸ†” Chat ID: $TELEGRAM_CHAT_ID"
    echo "ðŸ“¦ Tá»± Ä‘á»™ng gá»­i backup hÃ ng ngÃ y"
    echo ""
fi

echo "ðŸ”„ === TÃNH NÄ‚NG Tá»° Äá»˜NG ==="
echo "âœ… Cáº­p nháº­t há»‡ thá»‘ng má»—i 12 giá»"
echo "âœ… Sao lÆ°u workflow hÃ ng ngÃ y lÃºc 2 giá» sÃ¡ng"
echo "âœ… Giá»¯ láº¡i 30 báº£n backup gáº§n nháº¥t"
echo "âœ… Log chi tiáº¿t táº¡i $N8N_DIR/update.log vÃ  $N8N_DIR/files/backup_full/backup.log"
echo ""

echo "ðŸ“º === THÃ”NG TIN VIDEO YOUTUBE ==="
echo "ðŸŽ¬ Playlist N8N: https://www.youtube.com/@kalvinthiensocial/playlists"
echo "ðŸ“– HÆ°á»›ng dáº«n sá»­ dá»¥ng: Xem video trÃªn kÃªnh"
echo "ðŸ› ï¸ Há»— trá»£ ká»¹ thuáº­t: BÃ¬nh luáº­n dÆ°á»›i video"
echo ""

echo "ðŸŽ¯ === THÃ”NG TIN BACKUP ==="
echo "ðŸ“ ThÆ° má»¥c backup: $N8N_DIR/files/backup_full/"
echo "ðŸ“‚ ThÆ° má»¥c video YouTube: $N8N_DIR/files/youtube_content_anylystic/"
echo "ðŸ“‹ Script backup: $N8N_DIR/backup-workflows.sh"
echo "ðŸ”„ Script cáº­p nháº­t: $N8N_DIR/update-n8n.sh"
echo "ðŸ“Š Script kiá»ƒm tra: $N8N_DIR/check-status.sh"
echo ""

echo "ðŸŽª === THÃ”NG TIN PUPPETEER ==="
echo "ðŸ¤– Chromium Browser Ä‘Ã£ Ä‘Æ°á»£c cÃ i Ä‘áº·t trong container"
echo "ðŸ§© n8n-nodes-puppeteer package Ä‘Ã£ Ä‘Æ°á»£c cÃ i Ä‘áº·t sáºµn"
echo "ðŸ” TÃ¬m kiáº¿m 'Puppeteer' trong bá»™ nÃºt cá»§a n8n Ä‘á»ƒ sá»­ dá»¥ng"
echo ""

echo "âš ï¸  === LÆ¯U Ã QUAN TRá»ŒNG ==="
echo "â³ SSL cÃ³ thá»ƒ máº¥t vÃ i phÃºt Ä‘á»ƒ Ä‘Æ°á»£c cáº¥u hÃ¬nh hoÃ n táº¥t"
echo "ðŸ“‹ Kiá»ƒm tra tráº¡ng thÃ¡i: $N8N_DIR/check-status.sh"
echo "ðŸ”§ Xem logs container: cd $N8N_DIR && docker-compose logs -f"
echo "ðŸ†˜ Há»— trá»£: LiÃªn há»‡ $CONTACT_INFO hoáº·c comment YouTube"
echo ""

# Hiá»ƒn thá»‹ thÃ´ng tin lá»—i náº¿u cÃ³
FAILED_FEATURES=""

if [ "$ENABLE_TELEGRAM_BACKUP" = true ] && [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    FAILED_FEATURES="${FAILED_FEATURES}- âŒ Telegram backup (thiáº¿u Bot Token)\n"
fi

if [ "$ENABLE_FASTAPI" = true ] && [ -z "$FASTAPI_PASSWORD" ]; then
    FAILED_FEATURES="${FAILED_FEATURES}- âŒ FastAPI (thiáº¿u password)\n"
fi

if [ -n "$FAILED_FEATURES" ]; then
    echo "âš ï¸  === TÃNH NÄ‚NG CHÆ¯A Cáº¤U HÃŒNH ==="
    echo -e "$FAILED_FEATURES"
    echo "ðŸ’¡ Báº¡n cÃ³ thá»ƒ cáº¥u hÃ¬nh láº¡i báº±ng cÃ¡ch cháº¡y script vá»›i tham sá»‘ tÆ°Æ¡ng á»©ng"
    echo ""
fi

echo "ðŸŽŠ === CHÃšC Báº N Sá»¬ Dá»¤NG VUI Váºº! ==="
echo "Script Ä‘Æ°á»£c phÃ¡t triá»ƒn bá»Ÿi $AUTHOR_NAME vá»›i â¤ï¸"
echo "PhiÃªn báº£n: $SCRIPT_VERSION"
echo "======================================================================"

# Gá»­i thÃ´ng bÃ¡o hoÃ n thÃ nh qua Telegram náº¿u cÃ³
if [ "$ENABLE_TELEGRAM_BACKUP" = true ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="ðŸŽ‰ <b>CÃ i Ä‘áº·t N8N hoÃ n táº¥t!</b>%0AðŸŒ Domain: ${DOMAIN}%0Aâ° Thá»i gian: $(date '+%d/%m/%Y %H:%M:%S')%0AðŸŽ¥ HÆ°á»›ng dáº«n: ${YOUTUBE_CHANNEL}" \
        -d parse_mode="HTML" > /dev/null
fi 
