#!/bin/bash

# Hiển thị banner
echo "======================================================================"
echo "   Script cài đặt N8N với FFmpeg, yt-dlp, Puppeteer, thêm tính năng api cào bài viết và SSL tự động"
echo "======================================================================"

# Kiểm tra xem script có được chạy với quyền root không
if [[ $EUID -ne 0 ]]; then
   echo "Script này cần được chạy với quyền root" 
   exit 1
fi

# Hàm thiết lập swap tự động
setup_swap() {
    echo "Kiểm tra và thiết lập swap tự động..."
    
    # Kiểm tra nếu swap đã được bật
    if [ "$(swapon --show | wc -l)" -gt 0 ]; then
        SWAP_SIZE=$(free -h | grep Swap | awk '{print $2}')
        echo "Swap đã được bật với kích thước ${SWAP_SIZE}. Bỏ qua thiết lập."
        return
    fi
    
    # Lấy thông tin RAM (đơn vị MB)
    RAM_MB=$(free -m | grep Mem | awk '{print $2}')
    
    # Tính toán kích thước swap dựa trên RAM
    if [ "$RAM_MB" -le 2048 ]; then
        # Với RAM <= 2GB, swap = 2x RAM
        SWAP_SIZE=$((RAM_MB * 2))
    elif [ "$RAM_MB" -gt 2048 ] && [ "$RAM_MB" -le 8192 ]; then
        # Với 2GB < RAM <= 8GB, swap = RAM
        SWAP_SIZE=$RAM_MB
    else
        # Với RAM > 8GB, swap = 4GB
        SWAP_SIZE=4096
    fi
    
    # Chuyển đổi sang GB cho dễ nhìn (làm tròn lên)
    SWAP_GB=$(( (SWAP_SIZE + 1023) / 1024 ))
    
    echo "Đang thiết lập swap với kích thước ${SWAP_GB}GB (${SWAP_SIZE}MB)..."
    
    # Tạo swap file với đơn vị MB
    dd if=/dev/zero of=/swapfile bs=1M count=$SWAP_SIZE status=progress
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    
    # Thêm vào fstab để swap được kích hoạt sau khi khởi động lại
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    
    # Cấu hình swappiness và cache pressure
    sysctl vm.swappiness=10
    sysctl vm.vfs_cache_pressure=50
    
    # Lưu cấu hình vào sysctl.conf nếu chưa có
    if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
        echo "vm.swappiness=10" >> /etc/sysctl.conf
    fi
    
    if ! grep -q "vm.vfs_cache_pressure" /etc/sysctl.conf; then
        echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
    fi
    
    echo "Đã thiết lập swap với kích thước ${SWAP_GB}GB thành công."
    echo "Swappiness đã được đặt thành 10 (mặc định: 60)"
    echo "Vfs_cache_pressure đã được đặt thành 50 (mặc định: 100)"
}

# Hàm hiển thị trợ giúp
show_help() {
    echo "Cách sử dụng: $0 [tùy chọn]"
    echo "Tùy chọn:"
    echo "  -h, --help      Hiển thị trợ giúp này"
    echo "  -d, --dir DIR   Chỉ định thư mục cài đặt n8n (mặc định: /home/n8n)"
    echo "  -s, --skip-docker Bỏ qua cài đặt Docker (nếu đã có)"
    exit 0
}

# Xử lý tham số dòng lệnh
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
        *)
            echo "Tùy chọn không hợp lệ: $1"
            show_help
            ;;
    esac
done

# Hàm kiểm tra domain
check_domain() {
    local domain=$1
    local server_ip=$(curl -s https://api.ipify.org 2>/dev/null || curl -s https://ipv4.icanhazip.com 2>/dev/null || echo "")
    local domain_ip=$(dig +short $domain 2>/dev/null || nslookup $domain 2>/dev/null | grep -A1 "Name:" | tail -1 | awk '{print $2}' || echo "")

    echo "🔍 Kiểm tra DNS pointing:"
    echo "  - Server IP: $server_ip"
    echo "  - Domain IP: $domain_ip"
    
    # Kiểm tra nếu không lấy được IP
    if [ -z "$server_ip" ] || [ -z "$domain_ip" ]; then
        echo "⚠️  Không thể xác định IP. Tiếp tục cài đặt..."
        return 0
    fi

    if [ "$domain_ip" = "$server_ip" ]; then
        echo "✅ Domain đã trỏ đúng"
        return 0  # Domain đã trỏ đúng
    else
        echo "❌ Domain chưa trỏ đúng"
        return 1  # Domain chưa trỏ đúng
    fi
}

# Hàm kiểm tra các lệnh cần thiết
check_commands() {
    if ! command -v dig &> /dev/null; then
        echo "Cài đặt dnsutils (để sử dụng lệnh dig)..."
        apt-get update
        apt-get install -y dnsutils
    fi
}

# Thiết lập swap
setup_swap

# Hàm kiểm tra và khởi động Docker daemon
start_docker_daemon() {
    echo "🔧 Kiểm tra và khởi động Docker daemon..."
    
    # Kiểm tra xem có phải WSL không
    if grep -qi microsoft /proc/version 2>/dev/null || grep -qi wsl /proc/version 2>/dev/null; then
        echo "⚠️  Phát hiện môi trường WSL - sẽ khởi động Docker daemon thủ công"
        
        # Khởi động Docker daemon cho WSL
        if ! pgrep dockerd > /dev/null; then
            echo "Khởi động Docker daemon..."
            dockerd > /dev/null 2>&1 &
            sleep 10
            
            # Đợi daemon sẵn sàng
            for i in {1..30}; do
                if docker info > /dev/null 2>&1; then
                    echo "✅ Docker daemon đã khởi động thành công"
                    break
                fi
                sleep 2
                echo "Đợi Docker daemon khởi động... ($i/30)"
            done
            
            if ! docker info > /dev/null 2>&1; then
                echo "❌ Không thể khởi động Docker daemon trong WSL"
                echo "💡 Thử khởi động Docker Desktop trên Windows hoặc chạy lệnh sau:"
                echo "   sudo dockerd &"
                return 1
            fi
        else
            echo "✅ Docker daemon đã đang chạy"
        fi
    else
        # Môi trường VPS/Server thông thường
        if systemctl is-active --quiet docker; then
            echo "✅ Docker service đã đang chạy"
        else
            echo "Khởi động Docker service..."
            systemctl start docker
            systemctl enable docker
        fi
    fi
    
    return 0
}

# Hàm cài đặt Docker
install_docker() {
    if $SKIP_DOCKER; then
        echo "Bỏ qua cài đặt Docker theo yêu cầu..."
        return
    fi
    
    echo "Cài đặt Docker và Docker Compose..."
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    
    # Thêm khóa Docker GPG theo cách mới
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Thêm repository Docker
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Cài đặt Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Cài đặt Docker Compose
    if ! command -v docker-compose &> /dev/null && ! command -v docker &> /dev/null; then
        echo "Cài đặt Docker Compose..."
        apt-get install -y docker-compose
    elif command -v docker &> /dev/null && ! docker compose version &> /dev/null; then
        echo "Cài đặt Docker Compose plugin..."
        apt-get install -y docker-compose-plugin
    fi
    
    # Kiểm tra Docker đã cài đặt thành công chưa
    if ! command -v docker &> /dev/null; then
        echo "Lỗi: Docker chưa được cài đặt đúng cách."
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! (command -v docker &> /dev/null && docker compose version &> /dev/null); then
        echo "Lỗi: Docker Compose chưa được cài đặt đúng cách."
        exit 1
    fi

    # Thêm user hiện tại vào nhóm docker nếu không phải root
    if [ "$SUDO_USER" != "" ]; then
        echo "Thêm user $SUDO_USER vào nhóm docker để có thể chạy docker mà không cần sudo..."
        usermod -aG docker $SUDO_USER
        echo "Đã thêm user $SUDO_USER vào nhóm docker. Các thay đổi sẽ có hiệu lực sau khi đăng nhập lại."
    fi

    # Khởi động Docker daemon
    if ! start_docker_daemon; then
        echo "❌ Lỗi khởi động Docker daemon"
        exit 1
    fi

    echo "Docker và Docker Compose đã được cài đặt thành công."
}

# Cài đặt các gói cần thiết
echo "Đang cài đặt các công cụ cần thiết..."
apt-get update
apt-get install -y dnsutils curl cron jq tar gzip python3-full python3-venv pipx net-tools

# Cài đặt yt-dlp thông qua pipx hoặc virtual environment
echo "Cài đặt yt-dlp..."
if command -v pipx &> /dev/null; then
    pipx install yt-dlp
else
    # Tạo virtual environment và cài đặt yt-dlp vào đó
    python3 -m venv /opt/yt-dlp-venv
    /opt/yt-dlp-venv/bin/pip install yt-dlp
    ln -sf /opt/yt-dlp-venv/bin/yt-dlp /usr/local/bin/yt-dlp
    chmod +x /usr/local/bin/yt-dlp
fi

# Đảm bảo cron service đang chạy
systemctl enable cron
systemctl start cron

# Kiểm tra các lệnh cần thiết
check_commands

# Nhận input domain từ người dùng
read -p "Nhập tên miền hoặc tên miền phụ của bạn: " DOMAIN

# Cấu hình Telegram backup (tùy chọn)
echo ""
echo "🔔 Cấu hình gửi backup qua Telegram (tùy chọn)"
read -p "Bạn có muốn cấu hình gửi backup tự động qua Telegram không? (y/n): " SETUP_TELEGRAM
if [ "$SETUP_TELEGRAM" = "y" ] || [ "$SETUP_TELEGRAM" = "Y" ]; then
    echo "Để cấu hình Telegram, bạn cần:"
    echo "1. Tạo bot Telegram bằng cách nhắn tin cho @BotFather"
    echo "2. Lấy Bot Token từ BotFather"
    echo "3. Lấy Chat ID bằng cách nhắn tin cho bot và truy cập: https://api.telegram.org/bot<TOKEN>/getUpdates"
    echo ""
    read -p "Nhập Bot Token: " TELEGRAM_BOT_TOKEN
    read -p "Nhập Chat ID: " TELEGRAM_CHAT_ID
    
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        echo "TELEGRAM_BOT_TOKEN=\"$TELEGRAM_BOT_TOKEN\"" > /tmp/telegram_config.txt
        echo "TELEGRAM_CHAT_ID=\"$TELEGRAM_CHAT_ID\"" >> /tmp/telegram_config.txt
        echo "✅ Cấu hình Telegram đã được lưu tạm thời"
    else
        echo "⚠️ Thông tin Telegram không đầy đủ, bỏ qua cấu hình này"
        SETUP_TELEGRAM="n"
    fi
else
    SETUP_TELEGRAM="n"
fi

# Cấu hình FastAPI News Content API (tùy chọn)
echo ""
echo "📰 Cấu hình API lấy nội dung tin tức (FastAPI + Newspaper4k)"
read -p "Bạn có muốn tạo API riêng để lấy nội dung bài viết không? (y/n): " SETUP_NEWS_API
if [ "$SETUP_NEWS_API" = "y" ] || [ "$SETUP_NEWS_API" = "Y" ]; then
    read -p "Nhập mật khẩu Bearer Token cho API (để bảo mật): " NEWS_API_TOKEN
    if [ -z "$NEWS_API_TOKEN" ]; then
        NEWS_API_TOKEN=$(openssl rand -hex 16)
        echo "⚠️ Bạn chưa nhập token, sử dụng token tự động: $NEWS_API_TOKEN"
    fi
    echo "✅ Sẽ tạo News API với Bearer Token đã cấu hình"
else
    SETUP_NEWS_API="n"
fi

# Kiểm tra domain
echo "Kiểm tra domain $DOMAIN..."
if check_domain $DOMAIN; then
    echo "✅ Tiếp tục cài đặt với domain $DOMAIN"
else
    echo ""
    echo "⚠️  CẢNH BÁO: Domain chưa được trỏ đúng"
    echo "📝 Hướng dẫn cấu hình DNS:"
    echo "  1. Truy cập panel quản lý domain của bạn"
    echo "  2. Tạo/sửa bản ghi A record:"
    echo "     - Name: @ (hoặc để trống)"
    echo "     - Type: A"
    echo "     - Value: $(curl -s https://api.ipify.org 2>/dev/null || echo "SERVER_IP")"
    echo "  3. Tạo bản ghi A record cho subdomain API:"
    echo "     - Name: api"
    echo "     - Type: A"
    echo "     - Value: $(curl -s https://api.ipify.org 2>/dev/null || echo "SERVER_IP")"
    echo ""
    read -p "Bạn có muốn tiếp tục cài đặt không? (y/n): " CONTINUE_INSTALL
    if [ "$CONTINUE_INSTALL" != "y" ] && [ "$CONTINUE_INSTALL" != "Y" ]; then
        echo "Thoát cài đặt. Vui lòng cấu hình DNS và chạy lại script."
        exit 1
    fi
    echo "⚠️  Tiếp tục cài đặt - SSL có thể thất bại nếu DNS chưa đúng"
fi

# Cài đặt Docker và Docker Compose
install_docker

# Đảm bảo Docker daemon đang chạy
if ! start_docker_daemon; then
    echo "❌ Không thể khởi động Docker daemon. Thoát script."
    exit 1
fi

# Function cleanup containers và images cũ
cleanup_old_installation() {
    echo "🧹 Dọn dẹp các container và image cũ..."
    
    # Chuyển đến thư mục N8N nếu có
    if [ -d "$N8N_DIR" ]; then
        cd "$N8N_DIR"
        
        # Dừng và xóa containers bằng docker-compose nếu có
        if [ -f "docker-compose.yml" ]; then
            echo "Dừng containers với docker-compose..."
            if command -v docker-compose &> /dev/null; then
                docker-compose down --remove-orphans --volumes 2>/dev/null || true
            elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
                docker compose down --remove-orphans --volumes 2>/dev/null || true
            fi
        fi
    fi
    
    # Dừng tất cả containers liên quan
    echo "Dừng các container cũ..."
    docker stop $(docker ps -a -q --filter "name=n8n") 2>/dev/null || true
    docker stop $(docker ps -a -q --filter "name=caddy") 2>/dev/null || true
    docker stop $(docker ps -a -q --filter "name=fastapi") 2>/dev/null || true
    
    # Xóa containers cũ
    echo "Xóa các container cũ..."
    docker rm $(docker ps -a -q --filter "name=n8n") 2>/dev/null || true
    docker rm $(docker ps -a -q --filter "name=caddy") 2>/dev/null || true
    docker rm $(docker ps -a -q --filter "name=fastapi") 2>/dev/null || true
    
    # Xóa images cũ nếu có
    echo "Xóa các image cũ..."
    docker rmi n8n-ffmpeg-latest 2>/dev/null || true
    docker rmi $(docker images -q --filter "dangling=true") 2>/dev/null || true
    
    # Xóa networks orphan
    echo "Dọn dẹp networks..."
    docker network prune -f 2>/dev/null || true
    
    # Dọn dẹp volumes không sử dụng (cẩn thận với volumes)
    echo "Dọn dẹp volumes không sử dụng..."
    docker volume ls -q --filter "dangling=true" | xargs -r docker volume rm 2>/dev/null || true
    
    echo "✅ Hoàn tất dọn dẹp!"
}

# Kiểm tra xem có cần dọn dẹp không
echo "🔍 Kiểm tra các container N8N hiện có..."
EXISTING_CONTAINERS=$(docker ps -a --filter "name=n8n" --format "{{.Names}}" 2>/dev/null || true)
if [ -n "$EXISTING_CONTAINERS" ]; then
    echo "⚠️  Phát hiện container N8N cũ: $EXISTING_CONTAINERS"
    read -p "Bạn có muốn dọn dẹp và cài đặt lại từ đầu? (y/n): " CLEANUP_CHOICE
    if [ "$CLEANUP_CHOICE" = "y" ] || [ "$CLEANUP_CHOICE" = "Y" ]; then
        cleanup_old_installation
    fi
fi

# Tạo thư mục cho n8n
echo "Tạo cấu trúc thư mục cho n8n tại $N8N_DIR..."
mkdir -p $N8N_DIR
mkdir -p $N8N_DIR/files
mkdir -p $N8N_DIR/files/temp
mkdir -p $N8N_DIR/files/youtube_content_anylystic
mkdir -p $N8N_DIR/files/backup_full

# Tạo Dockerfile - CẬP NHẬT VỚI PUPPETEER
echo "Tạo Dockerfile để cài đặt n8n với FFmpeg, yt-dlp và Puppeteer..."
cat << 'EOF' > $N8N_DIR/Dockerfile
FROM n8nio/n8n:latest

USER root

# Cài đặt FFmpeg, wget, zip và các gói phụ thuộc cơ bản
RUN apk update && \
    apk add --no-cache ffmpeg wget zip unzip python3 py3-pip jq tar

# Cài đặt yt-dlp trực tiếp sử dụng pip trong container
RUN pip3 install --break-system-packages -U yt-dlp && \
    chmod +x /usr/bin/yt-dlp

# Cài đặt Puppeteer dependencies (với error handling)
RUN apk add --no-cache \
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
    udev \
    || echo "Warning: Some Puppeteer dependencies failed to install"

# Thiết lập biến môi trường cho Puppeteer (nếu có)
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Cài đặt n8n-nodes-puppeteer (với error handling)
WORKDIR /usr/local/lib/node_modules/n8n
RUN npm install n8n-nodes-puppeteer || echo "Warning: n8n-nodes-puppeteer installation failed, skipping..."

# Kiểm tra cài đặt các công cụ (với error handling cho Puppeteer)
RUN ffmpeg -version && \
    wget --version | head -n 1 && \
    zip --version | head -n 2 && \
    yt-dlp --version

# Kiểm tra Chromium (tùy chọn)
RUN chromium-browser --version || echo "Warning: Chromium not available, Puppeteer features will be disabled"

# Tạo thư mục youtube_content_anylystic và backup_full và set đúng quyền
RUN mkdir -p /files/youtube_content_anylystic && \
    mkdir -p /files/backup_full && \
    chown -R node:node /files

# Tạo file cảnh báo về trạng thái Puppeteer
RUN if command -v chromium-browser >/dev/null 2>&1; then \
        echo "Puppeteer: AVAILABLE" > /files/puppeteer_status.txt; \
    else \
        echo "Puppeteer: NOT_AVAILABLE" > /files/puppeteer_status.txt; \
    fi

# Trở lại user node
USER node
WORKDIR /home/node
EOF

# Tạo file docker-compose.yml
echo "Tạo file docker-compose.yml..."
if [ "$SETUP_NEWS_API" = "y" ]; then
    # Tạo docker-compose với News API
    cat << EOF > $N8N_DIR/docker-compose.yml
# Cấu hình Docker Compose cho N8N với FFmpeg, yt-dlp, Puppeteer và News API
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
      # Cấu hình binary data mode
      - N8N_DEFAULT_BINARY_DATA_MODE=filesystem
      - N8N_BINARY_DATA_STORAGE=/files
      - N8N_DEFAULT_BINARY_DATA_FILESYSTEM_DIRECTORY=/files
      - N8N_DEFAULT_BINARY_DATA_TEMP_DIRECTORY=/files/temp
      - NODE_FUNCTION_ALLOW_BUILTIN=child_process,path,fs,util,os
      - N8N_EXECUTIONS_DATA_MAX_SIZE=304857600
      # Cấu hình Puppeteer
      - PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
      - PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
    volumes:
      - ${N8N_DIR}:/home/node/.n8n
      - ${N8N_DIR}/files:/files
    user: "1000:1000"
    cap_add:
      - SYS_ADMIN  # Thêm quyền cho Puppeteer

  fastapi:
    build:
      context: ./news_api
      dockerfile: Dockerfile
    image: news-api-latest
    restart: always
    ports:
      - "8000:8000"
    environment:
      - NEWS_API_TOKEN=${NEWS_API_TOKEN}
      - NEWS_API_HOST=0.0.0.0
      - NEWS_API_PORT=8000
    volumes:
      - ${N8N_DIR}/news_api:/app
    depends_on:
      - n8n

  caddy:
    image: caddy:2
    restart: always
    ports:
      - "8080:80"  # Sử dụng cổng 8080 thay vì 80 để tránh xung đột
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
else
    # Tạo docker-compose chỉ có N8N
    cat << EOF > $N8N_DIR/docker-compose.yml
# Cấu hình Docker Compose cho N8N với FFmpeg, yt-dlp, và Puppeteer
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
      # Cấu hình binary data mode
      - N8N_DEFAULT_BINARY_DATA_MODE=filesystem
      - N8N_BINARY_DATA_STORAGE=/files
      - N8N_DEFAULT_BINARY_DATA_FILESYSTEM_DIRECTORY=/files
      - N8N_DEFAULT_BINARY_DATA_TEMP_DIRECTORY=/files/temp
      - NODE_FUNCTION_ALLOW_BUILTIN=child_process,path,fs,util,os
      - N8N_EXECUTIONS_DATA_MAX_SIZE=304857600
      # Cấu hình Puppeteer
      - PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
      - PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
    volumes:
      - ${N8N_DIR}:/home/node/.n8n
      - ${N8N_DIR}/files:/files
    user: "1000:1000"
    cap_add:
      - SYS_ADMIN  # Thêm quyền cho Puppeteer

  caddy:
    image: caddy:2
    restart: always
    ports:
      - "8080:80"  # Sử dụng cổng 8080 thay vì 80 để tránh xung đột
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
fi

# Tạo file Caddyfile
echo "Tạo file Caddyfile..."
if [ "$SETUP_NEWS_API" = "y" ]; then
    # Caddyfile với cả domain chính và API subdomain
    cat << EOF > $N8N_DIR/Caddyfile
# Main N8N domain
${DOMAIN} {
    reverse_proxy n8n:5678
    
    # SSL configuration
    tls {
        protocols tls1.2 tls1.3
    }
    
    # Headers for security
    header {
        # Enable HSTS
        Strict-Transport-Security max-age=31536000;
        # Prevent MIME type sniffing
        X-Content-Type-Options nosniff
        # Prevent clickjacking
        X-Frame-Options DENY
        # XSS protection
        X-XSS-Protection "1; mode=block"
        # Remove server header
        -Server
    }
    
    # Error handling
    handle_errors {
        @ssl_error expression {http.error.status_code} == 526
        respond @ssl_error "SSL Error: Certificate issue detected. Please check DNS configuration." 503
    }
}

# News API subdomain
api.${DOMAIN} {
    reverse_proxy fastapi:8000
    
    # SSL configuration
    tls {
        protocols tls1.2 tls1.3
    }
    
    # Headers for API
    header {
        # CORS headers
        Access-Control-Allow-Origin *
        Access-Control-Allow-Methods "GET, POST, OPTIONS"
        Access-Control-Allow-Headers "Authorization, Content-Type"
        # Security headers
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        -Server
    }
    
    # Handle preflight requests
    @options method OPTIONS
    respond @options 200
    
    # Error handling
    handle_errors {
        @ssl_error expression {http.error.status_code} == 526
        respond @ssl_error "SSL Error: Certificate issue detected. Please check DNS configuration." 503
    }
}

# HTTP to HTTPS redirect (fallback)
http://${DOMAIN} {
    redir https://${DOMAIN}{uri} permanent
}

http://api.${DOMAIN} {
    redir https://api.${DOMAIN}{uri} permanent
}
EOF
else
    # Caddyfile chỉ có domain chính
    cat << EOF > $N8N_DIR/Caddyfile
# Main N8N domain
${DOMAIN} {
    reverse_proxy n8n:5678
    
    # SSL configuration
    tls {
        protocols tls1.2 tls1.3
    }
    
    # Headers for security
    header {
        # Enable HSTS
        Strict-Transport-Security max-age=31536000;
        # Prevent MIME type sniffing
        X-Content-Type-Options nosniff
        # Prevent clickjacking
        X-Frame-Options DENY
        # XSS protection
        X-XSS-Protection "1; mode=block"
        # Remove server header
        -Server
    }
    
    # Error handling
    handle_errors {
        @ssl_error expression {http.error.status_code} == 526
        respond @ssl_error "SSL Error: Certificate issue detected. Please check DNS configuration." 503
    }
}

# HTTP to HTTPS redirect
http://${DOMAIN} {
    redir https://${DOMAIN}{uri} permanent
}
EOF
fi

# Tạo script sao lưu workflow và credentials
echo "Tạo script sao lưu workflow và credentials..."
cat << EOF > $N8N_DIR/backup-workflows.sh
#!/bin/bash

# Thiết lập biến
N8N_DIR="$N8N_DIR"
BACKUP_DIR="\$N8N_DIR/files/backup_full"
DATE=\$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="\$BACKUP_DIR/n8n_backup_\$DATE.tar"
TEMP_DIR="/tmp/n8n_backup_\$DATE"

# Hàm ghi log
log() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" | tee -a \$BACKUP_DIR/backup.log
}

# Tạo thư mục backup nếu chưa có
mkdir -p \$BACKUP_DIR

log "Bắt đầu sao lưu workflows và credentials..."

# Kiểm tra lệnh docker và quyền truy cập
if ! command -v docker &> /dev/null; then
    log "Lỗi: Docker chưa được cài đặt"
    exit 1
fi

# Xác định lệnh docker phù hợp
if ! docker ps &>/dev/null; then
    DOCKER_CMD="sudo docker"
else
    DOCKER_CMD="docker"
fi

# Tìm container n8n
N8N_CONTAINER=\$(\$DOCKER_CMD ps -q --filter "name=n8n" 2>/dev/null)
if [ -z "\$N8N_CONTAINER" ]; then
    log "Lỗi: Không tìm thấy container n8n đang chạy"
    exit 1
fi

# Tạo thư mục tạm thời
mkdir -p \$TEMP_DIR
mkdir -p \$TEMP_DIR/workflows
mkdir -p \$TEMP_DIR/credentials
mkdir -p \$TEMP_DIR/database

# Xuất workflows (với error handling)
log "Đang xuất workflows..."
WORKFLOWS=\$(\$DOCKER_CMD exec \$N8N_CONTAINER n8n list:workflows --json 2>/dev/null || echo "[]")
if [ "\$WORKFLOWS" = "[]" ] || [ -z "\$WORKFLOWS" ]; then
    log "Cảnh báo: Không tìm thấy workflow nào để sao lưu"
    echo "[]" > \$TEMP_DIR/workflows/empty_workflows.json
else
    # Xuất tất cả workflows thành 1 file
    echo "\$WORKFLOWS" > \$TEMP_DIR/workflows/all_workflows.json
    log "Đã xuất \$(echo "\$WORKFLOWS" | jq length) workflows"
    
    # Xuất từng workflow riêng lẻ (nếu có thể)
    echo "\$WORKFLOWS" | jq -c '.[]' 2>/dev/null | while read -r workflow; do
        id=\$(echo "\$workflow" | jq -r '.id' 2>/dev/null)
        name=\$(echo "\$workflow" | jq -r '.name' 2>/dev/null | tr -dc '[:alnum:][:space:]' | tr '[:space:]' '_')
        if [ -n "\$id" ] && [ "\$id" != "null" ]; then
            \$DOCKER_CMD exec \$N8N_CONTAINER n8n export:workflow --id="\$id" --output="/tmp/workflow_\$id.json" 2>/dev/null || true
            \$DOCKER_CMD cp \$N8N_CONTAINER:/tmp/workflow_\$id.json \$TEMP_DIR/workflows/\$id-\$name.json 2>/dev/null || true
        fi
    done
fi

# Sao lưu database và credentials từ container
log "Đang sao lưu database và credentials..."
\$DOCKER_CMD exec \$N8N_CONTAINER cp /home/node/.n8n/database.sqlite /tmp/database_backup.sqlite 2>/dev/null || true
\$DOCKER_CMD cp \$N8N_CONTAINER:/tmp/database_backup.sqlite \$TEMP_DIR/database/ 2>/dev/null || true

\$DOCKER_CMD exec \$N8N_CONTAINER cp /home/node/.n8n/config /tmp/config_backup -r 2>/dev/null || true
\$DOCKER_CMD cp \$N8N_CONTAINER:/tmp/config_backup \$TEMP_DIR/credentials/ 2>/dev/null || true

# Sao lưu toàn bộ thư mục .n8n từ host (volume mount)
if [ -d "\$N8N_DIR" ]; then
    log "Đang sao lưu thư mục cấu hình n8n từ host..."
    cp -r "\$N8N_DIR"/*.sqlite \$TEMP_DIR/database/ 2>/dev/null || true
    cp -r "\$N8N_DIR"/config \$TEMP_DIR/credentials/ 2>/dev/null || true
    cp -r "\$N8N_DIR"/nodes \$TEMP_DIR/credentials/ 2>/dev/null || true
fi

# Tạo file thông tin backup
cat > \$TEMP_DIR/backup_info.txt << BACKUP_INFO
Backup Date: \$(date)
N8N Directory: \$N8N_DIR
Container ID: \$N8N_CONTAINER
Workflows Count: \$(echo "\$WORKFLOWS" | jq length 2>/dev/null || echo "0")
BACKUP_INFO

# Tạo file tar nén
log "Đang tạo file nén backup..."
tar -czf \$BACKUP_FILE -C \$(dirname \$TEMP_DIR) \$(basename \$TEMP_DIR)

# Xóa thư mục tạm thời
rm -rf \$TEMP_DIR

# Kiểm tra kích thước file backup
if [ -f "\$BACKUP_FILE" ]; then
    BACKUP_SIZE=\$(du -h "\$BACKUP_FILE" | cut -f1)
    log "Sao lưu hoàn tất: \$BACKUP_FILE (Kích thước: \$BACKUP_SIZE)"
else
    log "Lỗi: Không thể tạo file backup"
    exit 1
fi

# Giữ lại tối đa 30 bản sao lưu gần nhất
log "Dọn dẹp các bản sao lưu cũ..."
find \$BACKUP_DIR -name "n8n_backup_*.tar" -type f -mtime +30 -delete 2>/dev/null || true
BACKUP_COUNT=\$(ls -1 \$BACKUP_DIR/n8n_backup_*.tar 2>/dev/null | wc -l)
log "Hiện có \$BACKUP_COUNT bản sao lưu trong thư mục"

# Gửi backup qua Telegram (nếu được cấu hình)
if [ -f "\$N8N_DIR/telegram_config.txt" ]; then
    source "\$N8N_DIR/telegram_config.txt"
    if [ -n "\$TELEGRAM_BOT_TOKEN" ] && [ -n "\$TELEGRAM_CHAT_ID" ]; then
        log "Đang gửi backup qua Telegram..."
        curl -s -X POST "https://api.telegram.org/bot\$TELEGRAM_BOT_TOKEN/sendDocument" \
            -F chat_id="\$TELEGRAM_CHAT_ID" \
            -F document=@"\$BACKUP_FILE" \
            -F caption="🔄 Backup N8N tự động - \$(date '+%d/%m/%Y %H:%M:%S')%0AKích thước: \$BACKUP_SIZE" \
            > /dev/null 2>&1 && log "Đã gửi backup qua Telegram thành công" || log "Lỗi gửi backup qua Telegram"
    fi
fi

log "Hoàn tất quá trình sao lưu"
EOF

# Đặt quyền thực thi cho script sao lưu
chmod +x $N8N_DIR/backup-workflows.sh

# Tạo script backup thủ công để test
echo "Tạo script backup thủ công để test..."
cat << EOF > $N8N_DIR/backup-manual.sh
#!/bin/bash

echo "🔄 BACKUP N8N THỦ CÔNG"
echo "======================"

# Gọi script backup chính
if [ -f "$N8N_DIR/backup-workflows.sh" ]; then
    echo "Đang chạy backup..."
    $N8N_DIR/backup-workflows.sh
    
    echo ""
    echo "📁 Kiểm tra kết quả backup:"
    echo "Thư mục backup: $N8N_DIR/files/backup_full/"
    
    if [ -d "$N8N_DIR/files/backup_full" ]; then
        echo "Các file backup hiện có:"
        ls -la $N8N_DIR/files/backup_full/
        
        # Hiển thị file backup mới nhất
        LATEST_BACKUP=\$(ls -t $N8N_DIR/files/backup_full/n8n_backup_*.tar 2>/dev/null | head -1)
        if [ -n "\$LATEST_BACKUP" ]; then
            echo ""
            echo "📦 File backup mới nhất: \$LATEST_BACKUP"
            echo "📊 Kích thước: \$(du -h "\$LATEST_BACKUP" | cut -f1)"
            echo "📅 Thời gian: \$(stat -c %y "\$LATEST_BACKUP")"
            
            # Kiểm tra nội dung backup
            echo ""
            echo "🔍 Nội dung backup:"
            tar -tzf "\$LATEST_BACKUP" | head -20
            if [ \$(tar -tzf "\$LATEST_BACKUP" | wc -l) -gt 20 ]; then
                echo "... và \$((\$(tar -tzf "\$LATEST_BACKUP" | wc -l) - 20)) file khác"
            fi
        else
            echo "❌ Không tìm thấy file backup nào"
        fi
    else
        echo "❌ Thư mục backup không tồn tại"
    fi
else
    echo "❌ Script backup không tìm thấy: $N8N_DIR/backup-workflows.sh"
fi

echo ""
echo "✅ Hoàn tất kiểm tra backup thủ công"
EOF

chmod +x $N8N_DIR/backup-manual.sh

# Lưu cấu hình Telegram nếu có
if [ "$SETUP_TELEGRAM" = "y" ] && [ -f "/tmp/telegram_config.txt" ]; then
    echo "Lưu cấu hình Telegram..."
    mv /tmp/telegram_config.txt $N8N_DIR/telegram_config.txt
    chmod 600 $N8N_DIR/telegram_config.txt
fi

# Tạo News API nếu người dùng chọn
if [ "$SETUP_NEWS_API" = "y" ]; then
    echo "Đang tạo News Content API với FastAPI và Newspaper4k..."
    
    # Tạo thư mục cho News API
    mkdir -p $N8N_DIR/news_api
    
    # Tạo môi trường ảo Python
    echo "Tạo môi trường ảo Python cho News API..."
    python3 -m venv $N8N_DIR/news_api/venv
    
    # Cài đặt các thư viện cần thiết
    echo "Cài đặt các thư viện Python cần thiết..."
    $N8N_DIR/news_api/venv/bin/pip install --upgrade pip
    $N8N_DIR/news_api/venv/bin/pip install fastapi uvicorn newspaper4k fake-useragent python-multipart pydantic requests beautifulsoup4 feedparser
    
    # Tạo Dockerfile cho News API
    cat << 'EOF' > $N8N_DIR/news_api/Dockerfile
FROM python:3.12-slim

WORKDIR /app

# Cài đặt các gói cần thiết
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements và cài đặt
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy code
COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

    # Tạo requirements.txt
    cat << 'EOF' > $N8N_DIR/news_api/requirements.txt
fastapi==0.104.1
uvicorn==0.24.0
newspaper4k>=0.9.0
fake-useragent>=1.4.0
python-multipart>=0.0.6
pydantic>=2.5.0
requests>=2.32.0
beautifulsoup4>=4.12.0
feedparser>=6.0.0
aiofiles>=23.2.0
httpx>=0.25.0
EOF

    # Tạo file main.py cho FastAPI
    cat << EOF > $N8N_DIR/news_api/main.py
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import asyncio
import hashlib
from datetime import datetime, timedelta
from typing import List, Optional, Dict, Union
from urllib.parse import urlparse
from fake_useragent import UserAgent
import feedparser
import requests
from bs4 import BeautifulSoup

from fastapi import FastAPI, HTTPException, Depends, Security, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel, HttpUrl, Field
import newspaper
from newspaper import Article, Source

# Cấu hình
API_TOKEN = os.getenv("NEWS_API_TOKEN", "$NEWS_API_TOKEN")
API_HOST = os.getenv("NEWS_API_HOST", "0.0.0.0")
API_PORT = int(os.getenv("NEWS_API_PORT", "8000"))
DOMAIN = "${DOMAIN}"

# FastAPI app
app = FastAPI(
    title="📰 News Content API",
    description="API lấy nội dung tin tức sử dụng Newspaper4k",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Security
security = HTTPBearer()
ua = UserAgent()

# Models
class ArticleRequest(BaseModel):
    url: HttpUrl = Field(..., description="URL của bài viết cần lấy nội dung")
    language: Optional[str] = Field("vi", description="Ngôn ngữ của bài viết (vi, en, etc.)")
    extract_images: Optional[bool] = Field(True, description="Có lấy hình ảnh không")
    summarize: Optional[bool] = Field(True, description="Có tóm tắt nội dung không")

class SourceRequest(BaseModel):
    url: HttpUrl = Field(..., description="URL của trang tin tức")
    max_articles: Optional[int] = Field(10, description="Số lượng bài viết tối đa")
    category_filter: Optional[List[str]] = Field(None, description="Lọc theo danh mục")

class FeedRequest(BaseModel):
    url: HttpUrl = Field(..., description="URL của RSS feed")
    max_articles: Optional[int] = Field(20, description="Số lượng bài viết tối đa")

class MonitorRequest(BaseModel):
    sources: List[HttpUrl] = Field(..., description="Danh sách URL nguồn tin")
    keywords: Optional[List[str]] = Field(None, description="Từ khóa cần theo dõi")
    check_interval: Optional[int] = Field(3600, description="Khoảng thời gian kiểm tra (giây)")

# Authentication
async def verify_token(credentials: HTTPAuthorizationCredentials = Security(security)):
    if credentials.credentials != API_TOKEN:
        raise HTTPException(status_code=401, detail="Token không hợp lệ")
    return credentials

# Helper functions
def get_random_headers():
    return {
        'User-Agent': ua.random,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'vi-VN,vi;q=0.9,en;q=0.8',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
    }

def safe_extract_content(article_url: str, language: str = "vi") -> Dict:
    try:
        # Cấu hình newspaper
        config = newspaper.Config()
        config.browser_user_agent = ua.random
        config.request_timeout = 10
        config.language = language
        config.memoize_articles = False
        
        # Tạo bài viết
        article = Article(article_url, config=config)
        article.download()
        article.parse()
        
        # NLP processing nếu có nội dung
        if article.text:
            try:
                article.nlp()
            except:
                pass
        
        return {
            "success": True,
            "url": article_url,
            "title": article.title or "Không có tiêu đề",
            "text": article.text or "Không thể lấy nội dung",
            "summary": article.summary or "Không có tóm tắt",
            "authors": article.authors or [],
            "publish_date": article.publish_date.isoformat() if article.publish_date else None,
            "top_image": article.top_image or None,
            "images": list(article.images) if article.images else [],
            "keywords": article.keywords or [],
            "language": article.meta_lang or language,
            "source_url": article.source_url or None,
            "meta_description": article.meta_description or None,
            "meta_keywords": article.meta_keywords or [],
            "tags": article.tags or []
        }
    except Exception as e:
        return {
            "success": False,
            "url": article_url,
            "error": str(e),
            "title": None,
            "text": None
        }

async def extract_from_source(source_url: str, max_articles: int = 10) -> Dict:
    try:
        # Xây dựng nguồn tin
        source = Source(source_url)
        source.build()
        
        articles_data = []
        processed = 0
        
        for article in source.articles[:max_articles]:
            if processed >= max_articles:
                break
                
            article_data = safe_extract_content(article.url)
            if article_data["success"]:
                articles_data.append(article_data)
                processed += 1
        
        return {
            "success": True,
            "source_url": source_url,
            "total_found": len(source.articles),
            "processed": processed,
            "articles": articles_data,
            "categories": source.category_urls() if hasattr(source, 'category_urls') else []
        }
    except Exception as e:
        return {
            "success": False,
            "source_url": source_url,
            "error": str(e),
            "articles": []
        }

def parse_rss_feed(feed_url: str, max_articles: int = 20) -> Dict:
    try:
        feed = feedparser.parse(feed_url)
        articles = []
        
        for entry in feed.entries[:max_articles]:
            article_data = {
                "title": entry.get("title", ""),
                "url": entry.get("link", ""),
                "description": entry.get("description", ""),
                "published": entry.get("published", ""),
                "author": entry.get("author", ""),
                "tags": [tag.term for tag in entry.get("tags", [])]
            }
            articles.append(article_data)
        
        return {
            "success": True,
            "feed_url": feed_url,
            "feed_title": feed.feed.get("title", ""),
            "feed_description": feed.feed.get("description", ""),
            "articles": articles,
            "total_articles": len(articles)
        }
    except Exception as e:
        return {
            "success": False,
            "feed_url": feed_url,
            "error": str(e),
            "articles": []
        }

# Routes
@app.get("/", response_class=HTMLResponse)
async def home():
    return f"""
    <!DOCTYPE html>
    <html lang="vi">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>📰 News Content API - {DOMAIN}</title>
        <style>
            * {{
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }}
            
            body {{
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                line-height: 1.6;
                color: #333;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
            }}
            
            .author-info {{
                position: fixed;
                top: 20px;
                right: 20px;
                background: rgba(255, 255, 255, 0.95);
                backdrop-filter: blur(10px);
                padding: 15px;
                border-radius: 15px;
                box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
                z-index: 1000;
                transition: all 0.3s ease;
                max-width: 280px;
                border: 1px solid rgba(255, 255, 255, 0.2);
            }}
            
            .author-info.scrolled {{
                top: 10px;
                transform: scale(0.9);
            }}
            
            .author-info h4 {{
                color: #667eea;
                margin-bottom: 10px;
                font-size: 14px;
                text-align: center;
            }}
            
            .author-info a {{
                color: #667eea;
                text-decoration: none;
                font-size: 12px;
                display: block;
                margin: 5px 0;
                transition: color 0.3s ease;
            }}
            
            .author-info a:hover {{
                color: #764ba2;
            }}
            
            .container {{
                max-width: 1200px;
                margin: 0 auto;
                padding: 20px;
                min-height: 100vh;
                display: flex;
                flex-direction: column;
            }}
            
            .header {{
                text-align: center;
                color: white;
                margin-bottom: 40px;
                padding: 40px 0;
            }}
            
            .header h1 {{
                font-size: 3rem;
                margin-bottom: 10px;
                text-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);
            }}
            
            .header p {{
                font-size: 1.2rem;
                opacity: 0.9;
            }}
            
            .main-content {{
                background: rgba(255, 255, 255, 0.95);
                backdrop-filter: blur(10px);
                border-radius: 20px;
                padding: 40px;
                box-shadow: 0 20px 60px rgba(0, 0, 0, 0.1);
                margin-bottom: 20px;
                border: 1px solid rgba(255, 255, 255, 0.2);
            }}
            
            .api-info {{
                background: linear-gradient(135deg, #667eea, #764ba2);
                color: white;
                padding: 25px;
                border-radius: 15px;
                margin: 25px 0;
                box-shadow: 0 10px 30px rgba(102, 126, 234, 0.3);
            }}
            
            .api-info h3 {{
                margin-bottom: 15px;
                font-size: 1.3rem;
            }}
            
            .api-info code {{
                background: rgba(255, 255, 255, 0.2);
                padding: 8px 12px;
                border-radius: 8px;
                font-family: 'Consolas', 'Monaco', monospace;
                display: inline-block;
                margin-top: 10px;
            }}
            
            .endpoints-grid {{
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                gap: 20px;
                margin: 30px 0;
            }}
            
            .endpoint {{
                background: white;
                padding: 25px;
                border-radius: 15px;
                box-shadow: 0 5px 20px rgba(0, 0, 0, 0.1);
                border-left: 5px solid #667eea;
                transition: transform 0.3s ease, box-shadow 0.3s ease;
            }}
            
            .endpoint:hover {{
                transform: translateY(-5px);
                box-shadow: 0 10px 30px rgba(0, 0, 0, 0.15);
            }}
            
            .endpoint h4 {{
                color: #667eea;
                margin-bottom: 10px;
                font-size: 1.1rem;
            }}
            
            .endpoint p {{
                color: #666;
                line-height: 1.5;
            }}
            
            .curl-examples {{
                background: #f8f9fa;
                padding: 25px;
                border-radius: 15px;
                margin: 30px 0;
                border: 1px solid #e9ecef;
            }}
            
            .curl-examples h3 {{
                color: #667eea;
                margin-bottom: 20px;
            }}
            
            .curl-command {{
                background: #2d3748;
                color: #68d391;
                padding: 15px;
                border-radius: 10px;
                font-family: 'Consolas', 'Monaco', monospace;
                font-size: 14px;
                overflow-x: auto;
                margin: 15px 0;
                border: 1px solid #4a5568;
            }}
            
            .change-token {{
                background: #fff3cd;
                border: 1px solid #ffeaa7;
                border-radius: 10px;
                padding: 20px;
                margin: 20px 0;
            }}
            
            .change-token h4 {{
                color: #856404;
                margin-bottom: 10px;
            }}
            
            .change-token code {{
                background: #fff;
                padding: 8px 12px;
                border-radius: 5px;
                border: 1px solid #dee2e6;
                display: block;
                margin: 10px 0;
            }}
            
            .cta-section {{
                text-align: center;
                margin-top: 40px;
                padding: 30px;
                background: linear-gradient(135deg, #667eea, #764ba2);
                border-radius: 15px;
                color: white;
            }}
            
            .cta-section a {{
                display: inline-block;
                background: white;
                color: #667eea;
                padding: 15px 30px;
                border-radius: 25px;
                text-decoration: none;
                font-weight: bold;
                margin: 10px;
                transition: transform 0.3s ease, box-shadow 0.3s ease;
            }}
            
            .cta-section a:hover {{
                transform: translateY(-2px);
                box-shadow: 0 5px 15px rgba(0, 0, 0, 0.2);
            }}
            
            @media (max-width: 768px) {{
                .author-info {{
                    position: relative;
                    top: 0;
                    right: 0;
                    margin-bottom: 20px;
                    max-width: 100%;
                }}
                
                .header h1 {{
                    font-size: 2rem;
                }}
                
                .main-content {{
                    padding: 20px;
                }}
                
                .endpoints-grid {{
                    grid-template-columns: 1fr;
                }}
            }}
        </style>
    </head>
    <body>
        <div class="author-info" id="authorInfo">
            <h4>👨‍💻 Thông Tin Tác Giả</h4>
            <a href="https://www.youtube.com/@kalvinthiensocial" target="_blank">📺 YouTube: Kalvin Thien Social</a>
            <a href="https://www.facebook.com/Ban.Thien.Handsome/" target="_blank">📘 Facebook: Ban Thien Handsome</a>
            <a href="tel:0888884749">📱 Zalo/Phone: 08.8888.4749</a>
            <p style="font-size: 11px; color: #666; margin-top: 10px;">🚀 Ngày cập nhật: 27/06/2025</p>
        </div>

        <div class="container">
            <div class="header">
                <h1>📰 News Content API</h1>
                <p>API lấy nội dung tin tức sử dụng Newspaper4k cho domain: <strong>{DOMAIN}</strong></p>
            </div>
            
            <div class="main-content">
                <div class="api-info">
                    <h3>🔐 Xác Thực API</h3>
                    <p>Tất cả API endpoints yêu cầu Bearer Token trong header:</p>
                    <code>Authorization: Bearer YOUR_TOKEN_HERE</code>
                    <p style="margin-top: 15px; font-size: 14px; opacity: 0.9;">
                        ⚠️ Token được cấu hình riêng cho mỗi installation để bảo mật
                    </p>
                </div>

                <div class="endpoints-grid">
                    <div class="endpoint">
                        <h4>GET /health</h4>
                        <p>Kiểm tra trạng thái API và thông tin phiên bản</p>
                    </div>
                    
                    <div class="endpoint">
                        <h4>POST /extract-article</h4>
                        <p>Lấy nội dung chi tiết của một bài viết từ URL</p>
                    </div>
                    
                    <div class="endpoint">
                        <h4>POST /extract-source</h4>
                        <p>Lấy nhiều bài viết từ một trang tin tức</p>
                    </div>
                    
                    <div class="endpoint">
                        <h4>POST /parse-feed</h4>
                        <p>Phân tích RSS feed và lấy danh sách bài viết</p>
                    </div>
                    
                    <div class="endpoint">
                        <h4>GET /stats</h4>
                        <p>Thống kê sử dụng API (cần authentication)</p>
                    </div>
                </div>

                <div class="curl-examples">
                    <h3>💻 Ví Dụ Lệnh cURL</h3>
                    
                    <h4>1. Kiểm tra trạng thái API:</h4>
                    <div class="curl-command">
curl -X GET "https://api.{DOMAIN}/health" \\
     -H "Authorization: Bearer YOUR_TOKEN_HERE"
                    </div>

                    <h4>2. Lấy nội dung bài viết:</h4>
                    <div class="curl-command">
curl -X POST "https://api.{DOMAIN}/extract-article" \\
     -H "Content-Type: application/json" \\
     -H "Authorization: Bearer YOUR_TOKEN_HERE" \\
     -d '{{
       "url": "https://example.com/news-article",
       "language": "vi",
       "extract_images": true,
       "summarize": true
     }}'
                    </div>

                    <h4>3. Phân tích RSS feed:</h4>
                    <div class="curl-command">
curl -X POST "https://api.{DOMAIN}/parse-feed" \\
     -H "Content-Type: application/json" \\
     -H "Authorization: Bearer YOUR_TOKEN_HERE" \\
     -d '{{
       "url": "https://example.com/rss.xml",
       "max_articles": 10
     }}'
                    </div>
                </div>

                <div class="change-token" id="change-token">
                    <h4>🔧 Hướng Dẫn Đổi Bearer Token</h4>
                    <p>Để thay đổi Bearer Token cho API, sử dụng các lệnh sau:</p>
                    
                    <p><strong>1. Đổi token và restart service:</strong></p>
                    <code>sudo sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN="TOKEN_MOI"/' /etc/systemd/system/news-api.service && sudo systemctl daemon-reload && sudo systemctl restart news-api</code>
                    
                    <p><strong>2. Đổi token trong Docker environment:</strong></p>
                    <code>cd {os.path.dirname(os.path.abspath(__file__))} && sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN=TOKEN_MOI/' docker-compose.yml && docker-compose restart fastapi</code>
                    
                    <p><strong>3. Kiểm tra token hiện tại:</strong></p>
                    <code>curl -X GET "https://api.{DOMAIN}/health" -H "Authorization: Bearer TOKEN_CU" | jq</code>
                </div>

                <div class="cta-section">
                    <h3>🚀 Bắt Đầu Sử Dụng</h3>
                    <p>Truy cập tài liệu API chi tiết hoặc test ngay các endpoint</p>
                    <a href="/docs">📚 Swagger UI Documentation</a>
                    <a href="/redoc">📖 ReDoc Documentation</a>
                </div>
            </div>
        </div>

        <script>
            // Sticky author info với scroll effect
            window.addEventListener('scroll', function() {{
                const authorInfo = document.getElementById('authorInfo');
                if (window.scrollY > 100) {{
                    authorInfo.classList.add('scrolled');
                }} else {{
                    authorInfo.classList.remove('scrolled');
                }}
            }});

            // Auto copy curl commands khi click
            document.querySelectorAll('.curl-command').forEach(function(element) {{
                element.addEventListener('click', function() {{
                    navigator.clipboard.writeText(this.textContent.trim()).then(function() {{
                        // Hiệu ứng copied
                        element.style.background = '#22543d';
                        setTimeout(function() {{
                            element.style.background = '#2d3748';
                        }}, 1000);
                    }});
                }});
                
                // Thêm tooltip
                element.title = 'Click để copy lệnh';
                element.style.cursor = 'pointer';
            }});
        </script>
    </body>
    </html>
    """

@app.get("/health")
async def health_check(credentials: HTTPAuthorizationCredentials = Security(security)):
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "version": "1.0.0",
        "features": ["article_extraction", "source_crawling", "rss_parsing", "content_monitoring"]
    }

@app.post("/extract-article")
async def extract_article(
    request: ArticleRequest,
    credentials: HTTPAuthorizationCredentials = Depends(verify_token)
):
    """Lấy nội dung chi tiết của một bài viết"""
    
    article_data = safe_extract_content(
        str(request.url),
        request.language
    )
    
    if not article_data["success"]:
        raise HTTPException(status_code=400, detail=f"Không thể lấy nội dung: {article_data.get('error')}")
    
    # Lọc dữ liệu theo yêu cầu
    if not request.extract_images:
        article_data.pop("images", None)
        article_data.pop("top_image", None)
    
    if not request.summarize:
        article_data.pop("summary", None)
        article_data.pop("keywords", None)
    
    return article_data

@app.post("/extract-source")
async def extract_source(
    request: SourceRequest,
    credentials: HTTPAuthorizationCredentials = Depends(verify_token)
):
    """Lấy nhiều bài viết từ một trang tin tức"""
    
    source_data = await extract_from_source(
        str(request.url),
        request.max_articles
    )
    
    if not source_data["success"]:
        raise HTTPException(status_code=400, detail=f"Không thể lấy dữ liệu từ nguồn: {source_data.get('error')}")
    
    return source_data

@app.post("/parse-feed")
async def parse_feed(
    request: FeedRequest,
    credentials: HTTPAuthorizationCredentials = Depends(verify_token)
):
    """Phân tích RSS feed"""
    
    feed_data = parse_rss_feed(str(request.url), request.max_articles)
    
    if not feed_data["success"]:
        raise HTTPException(status_code=400, detail=f"Không thể phân tích feed: {feed_data.get('error')}")
    
    return feed_data

@app.get("/stats")
async def get_stats(credentials: HTTPAuthorizationCredentials = Depends(verify_token)):
    """Thống kê sử dụng API"""
    return {
        "total_requests": "N/A",
        "successful_extractions": "N/A", 
        "failed_extractions": "N/A",
        "uptime": "N/A",
        "note": "Tính năng thống kê sẽ được bổ sung trong phiên bản sau"
    }

if __name__ == "__main__":
    import uvicorn
    print(f"🚀 Khởi động News Content API tại http://{API_HOST}:{API_PORT}")
    print(f"📚 Tài liệu API: http://{API_HOST}:{API_PORT}/docs")
    print(f"🌐 Domain: {DOMAIN}")
    print(f"🔒 Authentication: Bearer Token Required")
    
    uvicorn.run(
        "main:app",
        host=API_HOST,
        port=API_PORT,
        reload=False,
        workers=1
    )
EOF

    # Tạo script khởi động News API
    cat << EOF > $N8N_DIR/news_api/start_news_api.sh
#!/bin/bash

# Cấu hình môi trường
export NEWS_API_TOKEN="$NEWS_API_TOKEN"
export NEWS_API_HOST="0.0.0.0"
export NEWS_API_PORT="8001"

# Khởi động News API
cd "$N8N_DIR/news_api"
source venv/bin/activate
python main.py
EOF

    # Đặt quyền cho các file
    chmod +x $N8N_DIR/news_api/start_news_api.sh
    chmod +x $N8N_DIR/news_api/main.py
    
    echo "✅ News API đã được tạo và sẽ được khởi động cùng với Docker Compose"
fi

# Đặt quyền cho thư mục n8n
echo "Đặt quyền cho thư mục n8n..."
chown -R 1000:1000 $N8N_DIR
chmod -R 755 $N8N_DIR

# Khởi động các container
echo "Khởi động các container..."
echo "Lưu ý: Quá trình build image có thể mất vài phút, vui lòng đợi..."
cd $N8N_DIR

# Kiểm tra cổng 80 có đang được sử dụng không
if netstat -tuln | grep -q ":80\s"; then
    echo "CẢNH BÁO: Cổng 80 đang được sử dụng bởi một ứng dụng khác. Caddy sẽ sử dụng cổng 8080."
    # Đã cấu hình 8080 trong docker-compose.yml
else
    # Nếu cổng 80 trống, cập nhật docker-compose.yml để sử dụng cổng 80
    sed -i 's/"8080:80"/"80:80"/g' $N8N_DIR/docker-compose.yml
    echo "Cổng 80 đang trống. Caddy sẽ sử dụng cổng 80 mặc định."
fi

# Kiểm tra quyền truy cập Docker
echo "Kiểm tra quyền truy cập Docker..."
if ! docker ps &>/dev/null; then
    echo "Khởi động container với sudo vì quyền truy cập Docker..."
    DOCKER_COMPOSE_CMD="sudo docker-compose"
    if ! command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="sudo docker compose"
    fi
else
    DOCKER_COMPOSE_CMD="docker-compose"
    if ! command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
    fi
fi

# Build và khởi động containers với error handling
echo "🔨 Bắt đầu build Docker image..."
BUILD_OUTPUT=$($DOCKER_COMPOSE_CMD build 2>&1)
BUILD_EXIT_CODE=$?

if [ $BUILD_EXIT_CODE -ne 0 ]; then
    echo "❌ Lỗi build Docker image:"
    echo "$BUILD_OUTPUT"
    echo ""
    echo "Có thể thử các cách khắc phục sau:"
    echo "1. Chạy lại script này"
    echo "2. Kiểm tra kết nối internet"
    echo "3. Giải phóng dung lượng disk"
    exit 1
else
    echo "✅ Build Docker image thành công!"
fi

echo "🚀 Khởi động containers..."
START_OUTPUT=$($DOCKER_COMPOSE_CMD up -d --remove-orphans 2>&1)
START_EXIT_CODE=$?

if [ $START_EXIT_CODE -ne 0 ]; then
    echo "❌ Lỗi khởi động containers:"
    echo "$START_OUTPUT"
    exit 1
else
    echo "✅ Containers đã được khởi động!"
fi

# Đợi lâu hơn để các container có thể khởi động hoàn toàn
echo "⏳ Đợi containers khởi động hoàn toàn (30 giây)..."
sleep 30

# Tạo file hosts entry cho testing local
echo "📝 Tạo thông tin hosts entry cho testing..."
SERVER_IP=$(curl -s https://api.ipify.org 2>/dev/null || curl -s https://ipv4.icanhazip.com 2>/dev/null || echo "127.0.0.1")
cat << EOF > $N8N_DIR/hosts_entry.txt
# Thêm vào file /etc/hosts để test local (nếu DNS chưa propagate)
$SERVER_IP $DOMAIN
$SERVER_IP api.$DOMAIN

# Trên Windows: C:\Windows\System32\drivers\etc\hosts
# Trên Linux/Mac: /etc/hosts
EOF

# Kiểm tra các container đã chạy chưa
echo "🔍 Kiểm tra trạng thái containers..."

# Xác định lệnh docker phù hợp với quyền truy cập
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

# Kiểm tra container N8N
N8N_RUNNING=$($DOCKER_CMD ps --filter "name=n8n" --format "{{.Names}}" 2>/dev/null)
if [ -n "$N8N_RUNNING" ]; then
    N8N_STATUS=$($DOCKER_CMD ps --filter "name=n8n" --format "{{.Status}}" 2>/dev/null)
    echo "✅ Container N8N: $N8N_RUNNING - $N8N_STATUS"
else
    echo "❌ Container N8N: Không chạy hoặc lỗi khởi động"
    echo "📋 Kiểm tra logs N8N:"
    echo "   $DOCKER_COMPOSE_CMD logs n8n"
    echo ""
fi

# Kiểm tra container Caddy
CADDY_RUNNING=$($DOCKER_CMD ps --filter "name=caddy" --format "{{.Names}}" 2>/dev/null)
if [ -n "$CADDY_RUNNING" ]; then
    CADDY_STATUS=$($DOCKER_CMD ps --filter "name=caddy" --format "{{.Status}}" 2>/dev/null)
    echo "✅ Container Caddy: $CADDY_RUNNING - $CADDY_STATUS"
else
    echo "❌ Container Caddy: Không chạy hoặc lỗi khởi động"
    echo "📋 Kiểm tra logs Caddy:"
    echo "   $DOCKER_COMPOSE_CMD logs caddy"
    echo ""
fi

# Nếu có container không chạy, hiển thị thông tin troubleshooting
if [ -z "$N8N_RUNNING" ] || [ -z "$CADDY_RUNNING" ]; then
    echo "⚠️  Một hoặc nhiều container không chạy. Các bước khắc phục:"
    echo "1. Kiểm tra logs: $DOCKER_COMPOSE_CMD logs"
    echo "2. Restart containers: $DOCKER_COMPOSE_CMD restart"
    echo "3. Rebuild từ đầu: $DOCKER_COMPOSE_CMD down && $DOCKER_COMPOSE_CMD up -d --build"
    echo ""
fi

# Hiển thị thông tin về cổng được sử dụng
CADDY_PORT=$(grep -o '"[0-9]\+:80"' $N8N_DIR/docker-compose.yml | cut -d':' -f1 | tr -d '"')
echo ""
echo "Cấu hình cổng HTTP: $CADDY_PORT"
if [ "$CADDY_PORT" = "8080" ]; then
    echo "Sử dụng cổng 8080 cho HTTP thay vì cổng 80 mặc định (tránh xung đột)."
    echo "Bạn có thể truy cập bằng URL: http://${DOMAIN}:8080 hoặc https://${DOMAIN}"
else
    echo "Sử dụng cổng 80 mặc định cho HTTP."
    echo "Bạn có thể truy cập bằng URL: http://${DOMAIN} hoặc https://${DOMAIN}"
fi

# Kiểm tra FFmpeg, yt-dlp và Puppeteer trong container n8n
echo "Kiểm tra FFmpeg, yt-dlp và Puppeteer trong container n8n..."

# Xác định lệnh docker phù hợp với quyền truy cập
if ! docker ps &>/dev/null; then
    DOCKER_CMD="sudo docker"
else
    DOCKER_CMD="docker"
fi

N8N_CONTAINER=$($DOCKER_CMD ps -q --filter "name=n8n" 2>/dev/null)
if [ -n "$N8N_CONTAINER" ]; then
    if $DOCKER_CMD exec $N8N_CONTAINER ffmpeg -version &> /dev/null; then
        echo "FFmpeg đã được cài đặt thành công trong container n8n."
        echo "Phiên bản FFmpeg:"
        $DOCKER_CMD exec $N8N_CONTAINER ffmpeg -version | head -n 1
    else
        echo "Lưu ý: FFmpeg có thể chưa được cài đặt đúng cách trong container."
    fi

    if $DOCKER_CMD exec $N8N_CONTAINER yt-dlp --version &> /dev/null; then
        echo "yt-dlp đã được cài đặt thành công trong container n8n."
        echo "Phiên bản yt-dlp:"
        $DOCKER_CMD exec $N8N_CONTAINER yt-dlp --version
    else
        echo "Lưu ý: yt-dlp có thể chưa được cài đặt đúng cách trong container."
    fi
    
    # Kiểm tra trạng thái Puppeteer từ file status
    PUPPETEER_STATUS=$($DOCKER_CMD exec $N8N_CONTAINER cat /files/puppeteer_status.txt 2>/dev/null || echo "Puppeteer: UNKNOWN")
    
    if [[ "$PUPPETEER_STATUS" == *"AVAILABLE"* ]]; then
        echo "✅ Puppeteer/Chromium đã được cài đặt thành công trong container n8n."
        echo "Phiên bản Chromium:"
        $DOCKER_CMD exec $N8N_CONTAINER chromium-browser --version 2>/dev/null || echo "Lỗi lấy thông tin phiên bản"
    else
        echo "⚠️  Lưu ý: Puppeteer/Chromium cài đặt không thành công hoặc không khả dụng."
        echo "   Các tính năng tự động hóa trình duyệt sẽ không hoạt động."
        echo "   Hệ thống vẫn hoạt động bình thường với các tính năng khác."
    fi
else
    echo "Lưu ý: Không thể kiểm tra công cụ ngay lúc này. Container n8n chưa sẵn sàng."
fi

# Tạo script kiểm tra cập nhật tự động
echo "Tạo script cập nhật tự động..."
cat << EOF > $N8N_DIR/update-n8n.sh
#!/bin/bash

# Đường dẫn đến thư mục n8n
N8N_DIR="$N8N_DIR"

# Hàm ghi log
log() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" >> \$N8N_DIR/update.log
}

log "Bắt đầu kiểm tra cập nhật..."

# Kiểm tra Docker command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    log "Không tìm thấy lệnh docker-compose hoặc docker compose."
    exit 1
fi

# Cập nhật yt-dlp trên host
log "Cập nhật yt-dlp trên host system..."
if command -v pipx &> /dev/null; then
    pipx upgrade yt-dlp
elif [ -d "/opt/yt-dlp-venv" ]; then
    /opt/yt-dlp-venv/bin/pip install -U yt-dlp
else
    log "Không tìm thấy cài đặt yt-dlp đã biết"
fi

# Lấy phiên bản hiện tại
CURRENT_IMAGE_ID=\$(docker images -q n8n-ffmpeg-latest)
if [ -z "\$CURRENT_IMAGE_ID" ]; then
    log "Không tìm thấy image n8n-ffmpeg-latest"
    exit 1
fi

# Kiểm tra và xóa image gốc n8nio/n8n cũ nếu cần
OLD_BASE_IMAGE_ID=\$(docker images -q n8nio/n8n)

# Pull image gốc mới nhất
log "Kéo image n8nio/n8n mới nhất"
docker pull n8nio/n8n

# Lấy image ID mới
NEW_BASE_IMAGE_ID=\$(docker images -q n8nio/n8n)

# Kiểm tra xem image gốc đã thay đổi chưa
if [ "\$NEW_BASE_IMAGE_ID" != "\$OLD_BASE_IMAGE_ID" ]; then
    log "Phát hiện image mới (\${NEW_BASE_IMAGE_ID}), tiến hành cập nhật..."
    
    # Sao lưu dữ liệu n8n
    BACKUP_DATE=\$(date '+%Y%m%d_%H%M%S')
    BACKUP_FILE="\$N8N_DIR/backup_\${BACKUP_DATE}.zip"
    log "Tạo bản sao lưu tại \$BACKUP_FILE"
    zip -r \$BACKUP_FILE \$N8N_DIR -x \$N8N_DIR/update-n8n.sh -x \$N8N_DIR/backup_* -x \$N8N_DIR/files/temp/* -x \$N8N_DIR/Dockerfile -x \$N8N_DIR/docker-compose.yml
    
    # Build lại image n8n-ffmpeg
    cd \$N8N_DIR
    log "Đang build lại image n8n-ffmpeg-latest..."
    \$DOCKER_COMPOSE build
    
    # Khởi động lại container
    log "Khởi động lại container..."
    \$DOCKER_COMPOSE down
    \$DOCKER_COMPOSE up -d
    
    log "Cập nhật hoàn tất, phiên bản mới: \${NEW_BASE_IMAGE_ID}"
else
    log "Không có cập nhật mới cho n8n"
    
    # Cập nhật yt-dlp trong container
    log "Cập nhật yt-dlp trong container n8n..."
    N8N_CONTAINER=\$(docker ps -q --filter "name=n8n" 2>/dev/null)
    if [ -n "\$N8N_CONTAINER" ]; then
        docker exec -u root \$N8N_CONTAINER pip3 install --break-system-packages -U yt-dlp
        log "yt-dlp đã được cập nhật thành công trong container"
    else
        log "Không tìm thấy container n8n đang chạy"
    fi
fi
EOF

# Đặt quyền thực thi cho script cập nhật
chmod +x $N8N_DIR/update-n8n.sh

# Tạo script khắc phục sự cố
echo "Tạo script khắc phục sự cố..."
cat << 'EOF' > $N8N_DIR/troubleshoot.sh
#!/bin/bash

# Script khắc phục sự cố N8N
echo "🔧 SCRIPT KHẮC PHỤC SỰ CỐ N8N"
echo "================================"

N8N_DIR="$(dirname "$0")"
cd "$N8N_DIR"

# Xác định docker command
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

echo "1. Kiểm tra trạng thái containers..."
echo "=================================="
$DOCKER_CMD ps --filter "name=n8n" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "2. Kiểm tra logs containers..."
echo "============================="
echo ">> N8N Logs (10 dòng cuối):"
$DOCKER_COMPOSE_CMD logs --tail=10 n8n 2>/dev/null || echo "Không thể lấy logs N8N"
echo ""
echo ">> Caddy Logs (10 dòng cuối):"
$DOCKER_COMPOSE_CMD logs --tail=10 caddy 2>/dev/null || echo "Không thể lấy logs Caddy"
echo ""

echo "3. Kiểm tra network connectivity..."
echo "==================================="
echo ">> Kiểm tra cổng 5678 (N8N internal):"
$DOCKER_CMD exec $(docker ps -q --filter "name=n8n" | head -1) netstat -tuln | grep :5678 2>/dev/null || echo "N8N port không listening"
echo ""

echo "4. Kiểm tra disk space..."
echo "========================"
df -h | head -1
df -h | grep -E '(/$|/var|/home)'
echo ""

echo "5. Các lệnh khắc phục thường dùng:"
echo "================================="
echo "• Restart containers:"
echo "  $DOCKER_COMPOSE_CMD restart"
echo ""
echo "• Rebuild containers:"
echo "  $DOCKER_COMPOSE_CMD down && $DOCKER_COMPOSE_CMD up -d --build"
echo ""
echo "• Xem logs realtime:"
echo "  $DOCKER_COMPOSE_CMD logs -f"
echo ""
echo "• Kiểm tra resources:"
echo "  $DOCKER_CMD stats --no-stream"
echo ""

read -p "Bạn có muốn restart containers ngay bây giờ? (y/n): " RESTART_CHOICE
if [ "$RESTART_CHOICE" = "y" ] || [ "$RESTART_CHOICE" = "Y" ]; then
    echo "🔄 Đang restart containers..."
    $DOCKER_COMPOSE_CMD restart
    echo "✅ Hoàn tất restart. Đợi 30 giây để containers khởi động..."
    sleep 30
    echo "Trạng thái sau khi restart:"
    $DOCKER_CMD ps --filter "name=n8n"
fi
EOF

chmod +x $N8N_DIR/troubleshoot.sh

# Tạo script debug SSL
echo "Tạo script debug SSL..."
cat << 'EOF' > $N8N_DIR/debug-ssl.sh
#!/bin/bash

# Script debug SSL issues
echo "🔍 SSL DEBUG SCRIPT"
echo "=================="

N8N_DIR="$(dirname "$0")"
cd "$N8N_DIR"

# Xác định docker command
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

# Lấy domain từ Caddyfile
DOMAIN=$(grep -o '^[^{]*' Caddyfile | head -1 | sed 's/^# Main N8N domain//' | xargs)
if [ -z "$DOMAIN" ]; then
    DOMAIN=$(grep -E '^[a-zA-Z0-9.-]+\s*{' Caddyfile | head -1 | awk '{print $1}')
fi

echo "🌐 Domain được cấu hình: $DOMAIN"
echo ""

echo "1. Kiểm tra DNS Resolution..."
echo "============================="
echo ">> Domain chính:"
dig +short $DOMAIN || nslookup $DOMAIN
echo ""
echo ">> API subdomain:"
dig +short api.$DOMAIN || nslookup api.$DOMAIN
echo ""

echo "2. Kiểm tra Container Status..."
echo "=============================="
$DOCKER_CMD ps --filter "name=caddy" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "3. Kiểm tra Caddy Logs..."
echo "========================"
echo ">> Caddy logs (20 dòng cuối):"
$DOCKER_COMPOSE_CMD logs --tail=20 caddy
echo ""

echo "4. Test HTTP/HTTPS Connectivity..."
echo "================================="
echo ">> Test HTTP (should redirect):"
curl -I -k http://$DOMAIN 2>/dev/null || echo "HTTP connection failed"
echo ""
echo ">> Test HTTPS:"
curl -I -k https://$DOMAIN 2>/dev/null || echo "HTTPS connection failed"
echo ""

if [ -n "$(docker ps -q --filter 'name=fastapi')" ]; then
    echo ">> Test API HTTP:"
    curl -I -k http://api.$DOMAIN 2>/dev/null || echo "API HTTP connection failed"
    echo ""
    echo ">> Test API HTTPS:"
    curl -I -k https://api.$DOMAIN 2>/dev/null || echo "API HTTPS connection failed"
    echo ""
fi

echo "5. Kiểm tra SSL Certificate..."
echo "============================="
echo ">> SSL Certificate info cho $DOMAIN:"
echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -dates -subject -issuer 2>/dev/null || echo "Không thể lấy thông tin SSL certificate"
echo ""

echo "6. Kiểm tra Firewall và Ports..."
echo "================================"
echo ">> Listening ports:"
netstat -tuln | grep -E ':(80|443|5678|8000)\s'
echo ""

echo "7. Caddyfile Configuration..."
echo "============================"
echo ">> Current Caddyfile:"
cat Caddyfile
echo ""

echo "8. Khuyến nghị khắc phục..."
echo "=========================="
echo "Nếu gặp lỗi SSL:"
echo "1. Kiểm tra DNS đã trỏ đúng chưa (có thể mất 5-60 phút)"
echo "2. Restart Caddy: $DOCKER_COMPOSE_CMD restart caddy"
echo "3. Xem logs chi tiết: $DOCKER_COMPOSE_CMD logs -f caddy"
echo "4. Kiểm tra firewall: ufw status"
echo "5. Test local: curl -H 'Host: $DOMAIN' http://localhost"
echo ""

echo "🔧 Lệnh khắc phục nhanh:"
echo "========================"
echo "# Restart tất cả containers:"
echo "$DOCKER_COMPOSE_CMD restart"
echo ""
echo "# Force rebuild SSL:"
echo "$DOCKER_COMPOSE_CMD down && $DOCKER_COMPOSE_CMD up -d"
echo ""
echo "# Xóa SSL cache (nếu cần):"
echo "$DOCKER_CMD volume ls | grep caddy && $DOCKER_CMD volume rm \$(docker volume ls -q | grep caddy)"
echo ""

read -p "Bạn có muốn restart Caddy ngay bây giờ? (y/n): " RESTART_CHOICE
if [ "$RESTART_CHOICE" = "y" ] || [ "$RESTART_CHOICE" = "Y" ]; then
    echo "🔄 Đang restart Caddy..."
    $DOCKER_COMPOSE_CMD restart caddy
    echo "✅ Hoàn tất restart. Đợi 30 giây để SSL certificate được tạo..."
    sleep 30
    echo "Test lại HTTPS:"
    curl -I -k https://$DOMAIN || echo "Vẫn gặp lỗi SSL"
fi
EOF

chmod +x $N8N_DIR/debug-ssl.sh

# Tạo script test SSL nhanh
echo "Tạo script test SSL nhanh..."
cat << 'EOF' > $N8N_DIR/test-ssl-quick.sh
#!/bin/bash

# Script test SSL nhanh cho N8N
echo "🔍 QUICK SSL TEST"
echo "================="

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Lấy domain từ tham số hoặc hỏi người dùng
if [ -z "$1" ]; then
    read -p "Nhập domain của bạn: " DOMAIN
else
    DOMAIN=$1
fi

echo "🌐 Testing domain: $DOMAIN"
echo ""

# Test 1: DNS Resolution
echo "1. 🔍 DNS Resolution..."
DNS_IP=$(dig +short $DOMAIN 2>/dev/null || nslookup $DOMAIN 2>/dev/null | grep -A1 "Name:" | tail -1 | awk '{print $2}' || echo "")
if [ -n "$DNS_IP" ]; then
    echo -e "   ✅ DNS OK: $DOMAIN → $DNS_IP"
else
    echo -e "   ${RED}❌ DNS FAILED${NC}"
fi

# Test 2: HTTP Connection
echo "2. 🌐 HTTP Connection..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$DOMAIN --connect-timeout 10 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" = "301" ] || [ "$HTTP_STATUS" = "302" ] || [ "$HTTP_STATUS" = "200" ]; then
    echo -e "   ✅ HTTP OK: Status $HTTP_STATUS"
else
    echo -e "   ${RED}❌ HTTP FAILED: Status $HTTP_STATUS${NC}"
fi

# Test 3: HTTPS Connection
echo "3. 🔒 HTTPS Connection..."
HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN --connect-timeout 10 -k 2>/dev/null || echo "000")
if [ "$HTTPS_STATUS" = "200" ]; then
    echo -e "   ✅ HTTPS OK: Status $HTTPS_STATUS"
else
    echo -e "   ${RED}❌ HTTPS FAILED: Status $HTTPS_STATUS${NC}"
fi

# Test 4: SSL Certificate
echo "4. 📜 SSL Certificate..."
SSL_INFO=$(echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "")
if [ -n "$SSL_INFO" ]; then
    echo -e "   ✅ SSL Certificate OK"
    echo "   $SSL_INFO"
else
    echo -e "   ${RED}❌ SSL Certificate FAILED${NC}"
fi

# Test 5: API Subdomain (nếu có)
echo "5. 🔌 API Subdomain..."
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://api.$DOMAIN/health --connect-timeout 10 -k 2>/dev/null || echo "000")
if [ "$API_STATUS" = "200" ] || [ "$API_STATUS" = "401" ]; then
    echo -e "   ✅ API OK: Status $API_STATUS"
elif [ "$API_STATUS" = "000" ]; then
    echo -e "   ${YELLOW}⚠️  API không được cấu hình${NC}"
else
    echo -e "   ${RED}❌ API FAILED: Status $API_STATUS${NC}"
fi

echo ""
echo "📋 SUMMARY:"
echo "==========="

# Tổng kết
if [ -n "$DNS_IP" ] && ([ "$HTTPS_STATUS" = "200" ] || [ "$HTTP_STATUS" = "301" ] || [ "$HTTP_STATUS" = "302" ]); then
    echo -e "✅ ${GREEN}Domain $DOMAIN hoạt động tốt!${NC}"
    echo "   🌐 Truy cập: https://$DOMAIN"
    if [ "$API_STATUS" = "200" ] || [ "$API_STATUS" = "401" ]; then
        echo "   🔌 API: https://api.$DOMAIN"
    fi
else
    echo -e "❌ ${RED}Domain $DOMAIN gặp vấn đề:${NC}"
    
    if [ -z "$DNS_IP" ]; then
        echo "   • DNS chưa trỏ đúng - Kiểm tra bản ghi A record"
    fi
    
    if [ "$HTTPS_STATUS" != "200" ] && [ "$HTTP_STATUS" != "301" ] && [ "$HTTP_STATUS" != "302" ]; then
        echo "   • Web server không phản hồi - Kiểm tra Docker containers"
    fi
    
    if [ -z "$SSL_INFO" ]; then
        echo "   • SSL certificate chưa có - Đợi Let's Encrypt tạo certificate"
    fi
    
    echo ""
    echo "🔧 Khắc phục:"
    echo "   1. Chạy debug chi tiết: ./debug-ssl.sh"
    echo "   2. Kiểm tra containers: docker-compose ps"
    echo "   3. Xem logs: docker-compose logs caddy"
    echo "   4. Restart: docker-compose restart"
fi

echo ""
echo "⏱️  DNS propagation có thể mất 5-60 phút"
echo "🔄 Chạy lại: ./test-ssl-quick.sh $DOMAIN"
EOF

chmod +x $N8N_DIR/test-ssl-quick.sh

# Tạo cron job để chạy mỗi 12 giờ
echo "Thiết lập cron job cập nhật tự động mỗi 12 giờ và sao lưu hàng ngày..."
UPDATE_CRON="0 */12 * * * $N8N_DIR/update-n8n.sh"
BACKUP_CRON="0 2 * * * $N8N_DIR/backup-workflows.sh"
(crontab -l 2>/dev/null | grep -v "update-n8n.sh\|backup-workflows.sh"; echo "$UPDATE_CRON"; echo "$BACKUP_CRON") | crontab -

# Danh sách các thành phần thất bại
FAILED_COMPONENTS=()

# Kiểm tra trạng thái News API
if [ "$SETUP_NEWS_API" = "y" ]; then
    # Kiểm tra container FastAPI
    if ! docker ps &>/dev/null; then
        DOCKER_CMD="sudo docker"
    else
        DOCKER_CMD="docker"
    fi
    
    FASTAPI_CONTAINER=$($DOCKER_CMD ps -q --filter "name=fastapi" 2>/dev/null)
    if [ -n "$FASTAPI_CONTAINER" ]; then
        NEWS_API_STATUS="✅ Đang chạy (Container)"
    else
        NEWS_API_STATUS="❌ Container chưa khởi động"
        FAILED_COMPONENTS+=("News API")
    fi
fi

# Kiểm tra trạng thái Puppeteer
PUPPETEER_INSTALL_STATUS="❌ Lỗi cài đặt"
if ! docker ps &>/dev/null; then
    DOCKER_CMD="sudo docker"
else
    DOCKER_CMD="docker"
fi

N8N_CONTAINER_CHECK=$($DOCKER_CMD ps -q --filter "name=n8n" 2>/dev/null)
if [ -n "$N8N_CONTAINER_CHECK" ]; then
    PUPPETEER_STATUS_CHECK=$($DOCKER_CMD exec $N8N_CONTAINER_CHECK cat /files/puppeteer_status.txt 2>/dev/null || echo "Puppeteer: UNKNOWN")
    if [[ "$PUPPETEER_STATUS_CHECK" == *"AVAILABLE"* ]]; then
        PUPPETEER_INSTALL_STATUS="✅ Khả dụng"
    else
        PUPPETEER_INSTALL_STATUS="⚠️ Không khả dụng"
        FAILED_COMPONENTS+=("Puppeteer/Chromium")
    fi
fi

echo "======================================================================"
echo "🎉 N8N ĐÃ ĐƯỢC CÀI ĐẶT VÀ CẤU HÌNH THÀNH CÔNG!"
echo "======================================================================"
echo ""
echo "🌐 TRUY CẬP N8N:"
echo "  - URL chính: https://${DOMAIN}"
if [ "$CADDY_PORT" = "8080" ]; then
    echo "  - URL phụ: http://${DOMAIN}:8080"
fi
echo ""

# Hiển thị thông tin về swap
if [ "$(swapon --show | wc -l)" -gt 0 ]; then
    SWAP_SIZE=$(free -h | grep Swap | awk '{print $2}')
    echo "💾 THÔNG TIN SWAP:"
    echo "  - Kích thước: ${SWAP_SIZE}"
    echo "  - Swappiness: $(cat /proc/sys/vm/swappiness) (Mức càng thấp càng ưu tiên dùng RAM)"
    echo "  - Vfs_cache_pressure: $(cat /proc/sys/vm/vfs_cache_pressure) (Mức càng thấp càng giữ cache lâu hơn)"
    echo ""
fi

echo "📁 THÔNG TIN HỆ THỐNG:"
echo "  - Thư mục cài đặt: $N8N_DIR"
echo "  - Container runtime: Docker"
echo "  - Reverse proxy: Caddy (tự động SSL)"
echo ""

echo "🔄 TÍNH NĂNG TỰ ĐỘNG CẬP NHẬT:"
echo "  - Kiểm tra cập nhật: Mỗi 12 giờ"
echo "  - Log cập nhật: $N8N_DIR/update.log"
echo "  - Tự động sao lưu trước khi cập nhật"
echo "  - Tự động cập nhật yt-dlp và các công cụ"
echo ""

echo "💾 TÍNH NĂNG SAO LƯU TỰ ĐỘNG:"
echo "  - Lịch sao lưu: Hàng ngày lúc 2:00 AM"
echo "  - Thư mục backup: $N8N_DIR/files/backup_full/"
echo "  - Loại dữ liệu: Workflows, Credentials, Database"
echo "  - Giữ lại: 30 bản sao lưu gần nhất"
echo "  - Log backup: $N8N_DIR/files/backup_full/backup.log"

if [ "$SETUP_TELEGRAM" = "y" ]; then
    echo "  - 📱 Telegram: Tự động gửi backup qua Telegram"
fi
echo ""

if [ "$SETUP_TELEGRAM" = "y" ]; then
    echo "📱 CẤU HÌNH TELEGRAM BACKUP:"
    echo "  - Trạng thái: ✅ Đã kích hoạt"
    echo "  - File cấu hình: $N8N_DIR/telegram_config.txt"
    echo "  - Chức năng: Tự động gửi file backup qua Telegram"
    echo ""
fi

if [ "$SETUP_NEWS_API" = "y" ]; then
    echo "📰 NEWS CONTENT API:"
    echo "  - URL API: https://api.${DOMAIN}"
    echo "  - Docs/Testing: https://api.${DOMAIN}/docs"
    echo "  - Bearer Token: [Đã cấu hình - không hiển thị để bảo mật]"
    echo "  - Trạng thái: $NEWS_API_STATUS"
    echo "  - Chức năng: Lấy nội dung tin tức với Newspaper4k"
    echo ""
    echo "  📋 CÁCH SỬ DỤNG NEWS API TRONG N8N:"
    echo "  1. Tạo HTTP Request node trong workflow"
    echo "  2. Method: POST"
    echo "  3. URL: https://api.${DOMAIN}/extract-article"
    echo "  4. Headers: Authorization: Bearer [YOUR_TOKEN]"
    echo "  5. Body: {\"url\": \"https://example.com/news-article\"}"
    echo ""
    echo "  🔧 LỆNH TEST API (thay YOUR_TOKEN bằng token thực):"
    echo "  curl -X POST \"https://api.${DOMAIN}/extract-article\" \\"
    echo "       -H \"Content-Type: application/json\" \\"
    echo "       -H \"Authorization: Bearer YOUR_TOKEN\" \\"
    echo "       -d '{\"url\": \"https://dantri.com.vn/the-gioi.htm\"}'"
    echo ""
fi

echo "📺 THÔNG TIN CÔNG CỤ TÍCH HỢP:"
echo "  - FFmpeg: ✅ Xử lý video/audio"
echo "  - yt-dlp: ✅ Tải video YouTube"
echo "  - Puppeteer: $PUPPETEER_INSTALL_STATUS"
echo "  - Chromium: $PUPPETEER_INSTALL_STATUS"
echo "  - Thư mục video: $N8N_DIR/files/youtube_content_anylystic/"
echo ""

echo "🛠️ LỆNH QUẢN LÝ HỆ THỐNG:"
echo "  - 🔧 Khắc phục sự cố: $N8N_DIR/troubleshoot.sh"
echo "  - 🔒 Debug SSL: $N8N_DIR/debug-ssl.sh"
echo "  - ⚡ Test SSL nhanh: $N8N_DIR/test-ssl-quick.sh $DOMAIN"
echo "  - 📋 Xem logs N8N: cd $N8N_DIR && docker-compose logs -f n8n"
echo "  - 🔄 Restart N8N: cd $N8N_DIR && docker-compose restart"
echo "  - 💾 Backup thủ công: $N8N_DIR/backup-workflows.sh"
echo "  - 🧪 Test backup: $N8N_DIR/backup-manual.sh"
echo "  - 🔄 Cập nhật thủ công: $N8N_DIR/update-n8n.sh"
echo "  - 🏗️  Rebuild containers: cd $N8N_DIR && docker-compose down && docker-compose up -d --build"

if [ "$SETUP_NEWS_API" = "y" ]; then
    echo "  - 🔄 Restart News API: cd $N8N_DIR && docker-compose restart fastapi"
    echo "  - 📋 Xem logs News API: cd $N8N_DIR && docker-compose logs -f fastapi"
    echo "  - 🔑 Đổi Bearer Token: sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN=NEW_TOKEN/' $N8N_DIR/docker-compose.yml"
fi
echo ""

# Hiển thị cảnh báo nếu có thành phần thất bại
if [ ${#FAILED_COMPONENTS[@]} -gt 0 ]; then
    echo "⚠️  CÁC THÀNH PHẦN CÀI ĐẶT KHÔNG THÀNH CÔNG:"
    for component in "${FAILED_COMPONENTS[@]}"; do
        echo "  - ❌ $component"
    done
    echo ""
    echo "📞 Bạn có thể chạy lại script hoặc cài đặt thủ công các thành phần này."
    echo ""
fi

echo "📚 TÀI LIỆU THAM KHẢO:"
echo "  - N8N Documentation: https://docs.n8n.io/"
echo "  - N8N Community: https://community.n8n.io/"
if [ "$SETUP_NEWS_API" = "y" ]; then
    echo "  - Newspaper4k: https://newspaper4k.readthedocs.io/"
fi
echo ""

echo "🔒 LƯU Ý BẢO MẬT VÀ HỆ THỐNG:"
echo "  - Đổi mật khẩu đăng nhập N8N sau khi truy cập lần đầu"
echo "  - Backup định kỳ các workflow quan trọng"
echo "  - Giám sát logs hệ thống thường xuyên"
if [ "$SETUP_NEWS_API" = "y" ]; then
    echo "  - Giữ bí mật Bearer Token của News API"
fi
echo ""
echo "🚨 KHẮC PHỤC LỖI SSL (ERR_SSL_PROTOCOL_ERROR):"
echo "  1. ⚡ Test nhanh: $N8N_DIR/test-ssl-quick.sh ${DOMAIN}"
echo "  2. 🔒 Debug chi tiết: $N8N_DIR/debug-ssl.sh"
echo "  3. 🌐 Kiểm tra DNS: dig ${DOMAIN} && dig api.${DOMAIN}"
echo "  4. ⏰ Đợi DNS propagation (5-60 phút)"
echo "  5. 🔄 Restart Caddy: cd $N8N_DIR && docker-compose restart caddy"
echo "  6. 📋 Xem logs: cd $N8N_DIR && docker-compose logs caddy"
echo "  7. 🏠 Test local: curl -H 'Host: ${DOMAIN}' http://localhost"
echo "  8. 📝 Hosts entry (tạm thời): cat $N8N_DIR/hosts_entry.txt"

# Thông báo đặc biệt về Puppeteer nếu không khả dụng
if [[ "$PUPPETEER_INSTALL_STATUS" == *"Không khả dụng"* ]] || [[ "$PUPPETEER_INSTALL_STATUS" == *"Lỗi cài đặt"* ]]; then
    echo ""
    echo "⚠️  THÔNG BÁO VỀ PUPPETEER:"
    echo "  - Puppeteer/Chromium không cài đặt thành công"
    echo "  - Các workflow sử dụng tự động hóa trình duyệt sẽ không hoạt động"
    echo "  - Tất cả tính năng khác của N8N vẫn hoạt động bình thường"
    echo "  - Bạn có thể thử cài đặt lại bằng cách chạy script một lần nữa"
fi
echo ""

echo "⏱️  LƯU Ý KHỞI ĐỘNG:"
echo "  - N8N có thể cần 2-3 phút để khởi động hoàn toàn"
echo "  - SSL certificate tự động có thể mất 5-10 phút để cấu hình"
echo "  - Nếu không truy cập được, hãy kiểm tra logs và DNS"
echo ""

echo "👨‍💻 THÔNG TIN TÁC GIẢ:"
echo "  - Tác giả: Nguyễn Ngọc Thiện"
echo "  - YouTube: Kalvin Thien Social"
echo "  - Facebook: Ban Thien Handsome"
echo "  - Zalo/Phone: 08.8888.4749"
echo "  - Ngày cập nhật: 27/06/2025"
echo "  - Phiên bản: N8N + FFmpeg + News API + Telegram Backup"
echo ""
echo "======================================================================"
echo "🎯 CÀI ĐẶT HOÀN TẤT! CHÚC BẠN SỬ DỤNG N8N HIỆU QUẢ!"
echo "======================================================================"
