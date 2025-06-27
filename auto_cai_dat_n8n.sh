#!/bin/bash

# Hiển thị banner
echo "======================================================================"
echo "     Script cài đặt N8N với FFmpeg, yt-dlp, Puppeteer và SSL tự động  "
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
    local server_ip=$(curl -s https://api.ipify.org)
    local domain_ip=$(dig +short $domain)

    if [ "$domain_ip" = "$server_ip" ]; then
        return 0  # Domain đã trỏ đúng
    else
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

# Phát hiện môi trường trước khi cài đặt
detect_environment

# Hàm phát hiện môi trường
detect_environment() {
    IS_WSL=false
    IS_VPS=true
    
    # Kiểm tra WSL
    if [ -f /proc/version ] && grep -qi microsoft /proc/version; then
        IS_WSL=true
        IS_VPS=false
        echo "🔍 Phát hiện môi trường: WSL (Windows Subsystem for Linux)"
    elif [ -f /proc/version ] && grep -qi wsl /proc/version; then
        IS_WSL=true
        IS_VPS=false
        echo "🔍 Phát hiện môi trường: WSL2 (Windows Subsystem for Linux)"
    else
        echo "🔍 Phát hiện môi trường: VPS/Server Linux"
    fi
}

# Hàm khởi động Docker daemon cho WSL
start_docker_wsl() {
    echo "🐳 Khởi động Docker daemon cho môi trường WSL..."
    
    # Kiểm tra xem Docker daemon có đang chạy không
    if ! pgrep dockerd > /dev/null; then
        echo "Khởi động Docker daemon..."
        
        # Khởi động Docker daemon trong background
        sudo dockerd > /var/log/docker.log 2>&1 &
        
        # Đợi Docker daemon khởi động
        echo "Đợi Docker daemon khởi động..."
        for i in {1..30}; do
            if docker version &> /dev/null; then
                echo "✅ Docker daemon đã khởi động thành công!"
                return 0
            fi
            echo "Đợi Docker daemon... ($i/30)"
            sleep 2
        done
        
        echo "❌ Docker daemon không thể khởi động sau 60 giây"
        echo "Thử khởi động thủ công bằng lệnh: sudo dockerd"
        return 1
    else
        echo "✅ Docker daemon đã đang chạy!"
        return 0
    fi
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

    # Xử lý khởi động Docker theo môi trường
    if $IS_WSL; then
        echo "⚠️  Môi trường WSL: Docker daemon sẽ được khởi động thủ công"
        start_docker_wsl
    else
        # Khởi động Docker service cho VPS/Server
        systemctl enable docker
        systemctl restart docker
        
        # Kiểm tra Docker service
        if systemctl is-active --quiet docker; then
            echo "✅ Docker service đã khởi động thành công!"
        else
            echo "❌ Lỗi khởi động Docker service"
            systemctl status docker
            exit 1
        fi
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
    echo "🔑 Lưu token này để sử dụng: $NEWS_API_TOKEN"
else
    SETUP_NEWS_API="n"
fi

# Kiểm tra domain
echo "Kiểm tra domain $DOMAIN..."
if check_domain $DOMAIN; then
    echo "Domain $DOMAIN đã được trỏ đúng đến server này. Tiếp tục cài đặt"
else
    echo "Domain $DOMAIN chưa được trỏ đến server này."
    echo "Vui lòng cập nhật bản ghi DNS để trỏ $DOMAIN đến IP $(curl -s https://api.ipify.org)"
    echo "Sau khi cập nhật DNS, hãy chạy lại script này"
    exit 1
fi

# Cài đặt Docker và Docker Compose
install_docker

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
    # Docker-compose với FastAPI
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
      context: ./fastapi
      dockerfile: Dockerfile
    image: n8n-fastapi:latest
    restart: always
    ports:
      - "8000:8000"
    environment:
      - API_TOKEN=${NEWS_API_TOKEN}
      - PYTHONUNBUFFERED=1
    volumes:
      - ${N8N_DIR}/fastapi:/app
    depends_on:
      - n8n

  caddy:
    image: caddy:2
    restart: always
    ports:
      - "80:80"
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
    # Docker-compose không có FastAPI
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
      - "80:80"
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
    # Caddyfile với API subdomain
    cat << EOF > $N8N_DIR/Caddyfile
${DOMAIN} {
    reverse_proxy n8n:5678
}

api.${DOMAIN} {
    reverse_proxy fastapi:8000
}
EOF
else
    # Caddyfile chỉ có domain chính
    cat << EOF > $N8N_DIR/Caddyfile
${DOMAIN} {
    reverse_proxy n8n:5678
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
if [ -f "\$N8N_DIR/telegram_backup.conf" ]; then
    source "\$N8N_DIR/telegram_backup.conf"
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

# Tạo script backup thủ công
echo "Tạo script backup thủ công..."
cat << 'EOF' > $N8N_DIR/manual-backup.sh
#!/bin/bash

# Script backup thủ công với đầy đủ thông tin
echo "🔄 BẮT ĐẦU BACKUP THỦ CÔNG"
echo "========================="

N8N_DIR="$(dirname "$0")"
cd "$N8N_DIR"

# Chạy script backup chính
echo "Chạy script backup chính..."
./backup-workflows.sh

# Hiển thị thông tin backup
echo ""
echo "📊 THÔNG TIN BACKUP:"
echo "==================="

BACKUP_DIR="$N8N_DIR/files/backup_full"
if [ -d "$BACKUP_DIR" ]; then
    echo "📁 Thư mục backup: $BACKUP_DIR"
    echo "📈 Số lượng backup:"
    ls -1 "$BACKUP_DIR"/n8n_backup_*.tar* 2>/dev/null | wc -l || echo "0"
    
    echo ""
    echo "📋 Danh sách backup gần nhất:"
    ls -lht "$BACKUP_DIR"/n8n_backup_*.tar* 2>/dev/null | head -5 || echo "Chưa có backup nào"
    
    echo ""
    echo "💾 Tổng dung lượng backup:"
    du -sh "$BACKUP_DIR" 2>/dev/null || echo "N/A"
    
    # Kiểm tra backup log
    if [ -f "$BACKUP_DIR/backup.log" ]; then
        echo ""
        echo "📜 Log backup mới nhất (5 dòng cuối):"
        tail -5 "$BACKUP_DIR/backup.log"
    fi
else
    echo "❌ Thư mục backup không tồn tại: $BACKUP_DIR"
fi

echo ""
echo "✅ HOÀN TẤT BACKUP THỦ CÔNG"
EOF

chmod +x $N8N_DIR/manual-backup.sh

# Lưu cấu hình Telegram nếu có
if [ "$SETUP_TELEGRAM" = "y" ] && [ -f "/tmp/telegram_config.txt" ]; then
    echo "Lưu cấu hình Telegram..."
    mv /tmp/telegram_config.txt $N8N_DIR/telegram_backup.conf
    chmod 600 $N8N_DIR/telegram_backup.conf
fi

# Tạo News API nếu người dùng chọn
if [ "$SETUP_NEWS_API" = "y" ]; then
    echo "Đang tạo News Content API với FastAPI và Newspaper4k..."
    
    # Tạo thư mục cho FastAPI
    mkdir -p $N8N_DIR/fastapi
    
    # Tạo Dockerfile cho FastAPI
    cat << 'EOF' > $N8N_DIR/fastapi/Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Cài đặt các gói hệ thống cần thiết
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

    # Tạo requirements.txt
    cat << 'EOF' > $N8N_DIR/fastapi/requirements.txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
newspaper4k==0.9.2
fake-useragent==1.4.0
feedparser==6.0.10
python-multipart==0.0.6
requests==2.31.0
beautifulsoup4==4.12.2
lxml==4.9.3
pydantic==2.5.0
EOF
    
    # Tạo file main.py cho FastAPI
    cat << 'EOF' > $N8N_DIR/fastapi/main.py
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import logging
from datetime import datetime
from typing import Optional
from fake_useragent import UserAgent
import feedparser
import requests

from fastapi import FastAPI, HTTPException, Depends, Security, Query
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import HTMLResponse
import newspaper
from newspaper import Article

# Cấu hình logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Cấu hình
API_TOKEN = os.getenv("API_TOKEN", "your-secret-token-here")

# FastAPI app
app = FastAPI(
    title="📰 News Content API by Kalvin Thien",
    description="API lấy nội dung tin tức sử dụng Newspaper4k - Phát triển bởi Nguyễn Ngọc Thiện",
    version="2.0.0",
    docs_url=None,  # Tắt docs mặc định
    redoc_url=None
)

# Security
security = HTTPBearer()

# Authentication với logging chi tiết
async def verify_token(credentials: HTTPAuthorizationCredentials = Security(security)):
    logger.info(f"Received token: {credentials.credentials[:10]}...")
    logger.info(f"Expected token: {API_TOKEN[:10]}...")
    
    if credentials.credentials != API_TOKEN:
        logger.error("Token authentication failed")
        raise HTTPException(status_code=401, detail="Invalid API token")
    
    logger.info("Token authentication successful")
    return credentials.credentials

# User agent
ua = UserAgent()

# Routes
@app.get("/", response_class=HTMLResponse)
async def home():
    return f"""
    <!DOCTYPE html>
    <html lang="vi">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>📰 News Content API - Kalvin Thien Social</title>
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
        <style>
            :root {{
                --primary: #2563eb;
                --primary-dark: #1d4ed8;
                --secondary: #64748b;
                --accent: #f59e0b;
                --background: #ffffff;
                --surface: #f8fafc;
                --text-primary: #0f172a;
                --text-secondary: #475569;
                --border: #e2e8f0;
                --success: #10b981;
                --warning: #f59e0b;
                --error: #ef4444;
            }}
            
            * {{
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }}
            
            body {{
                font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                color: var(--text-primary);
                line-height: 1.6;
                padding-top: 80px; /* Space for fixed navbar */
            }}
            
            /* Navigation Menu */
            .author-nav {{
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                background: rgba(255, 255, 255, 0.95);
                backdrop-filter: blur(10px);
                box-shadow: 0 2px 20px rgba(0, 0, 0, 0.1);
                z-index: 1000;
                transition: transform 0.3s ease;
                padding: 12px 0;
            }}
            
            .author-nav.hidden {{
                transform: translateY(-100%);
            }}
            
            .nav-container {{
                max-width: 1200px;
                margin: 0 auto;
                padding: 0 20px;
                display: flex;
                justify-content: space-between;
                align-items: center;
                flex-wrap: wrap;
                gap: 15px;
            }}
            
            .nav-brand {{
                display: flex;
                align-items: center;
                gap: 10px;
                font-weight: 600;
                color: var(--primary);
                text-decoration: none;
                font-size: 1.1rem;
            }}
            
            .nav-links {{
                display: flex;
                gap: 15px;
                align-items: center;
                flex-wrap: wrap;
            }}
            
            .nav-link {{
                display: flex;
                align-items: center;
                gap: 6px;
                padding: 8px 12px;
                border-radius: 8px;
                text-decoration: none;
                color: var(--text-primary);
                transition: all 0.3s ease;
                font-size: 0.9rem;
                border: 1px solid transparent;
                white-space: nowrap;
            }}
            
            .nav-link:hover {{
                background: var(--primary);
                color: white;
                transform: translateY(-2px);
                box-shadow: 0 4px 12px rgba(37, 99, 235, 0.3);
            }}
            
            .nav-link.phone {{
                background: var(--success);
                color: white;
                font-weight: 500;
            }}
            
            .nav-link.phone:hover {{
                background: #059669;
            }}
            
            /* Responsive Navigation */
            @media (max-width: 768px) {{
                body {{
                    padding-top: 120px; /* More space for mobile nav */
                }}
                
                .nav-container {{
                    flex-direction: column;
                    gap: 10px;
                    padding: 8px 15px;
                }}
                
                .nav-links {{
                    justify-content: center;
                    gap: 8px;
                }}
                
                .nav-link {{
                    font-size: 0.8rem;
                    padding: 6px 10px;
                }}
                
                .nav-brand {{
                    font-size: 1rem;
                }}
            }}
            
            @media (max-width: 480px) {{
                body {{
                    padding-top: 140px;
                }}
                
                .nav-links {{
                    display: grid;
                    grid-template-columns: repeat(2, 1fr);
                    width: 100%;
                    gap: 8px;
                }}
                
                .nav-link {{
                    justify-content: center;
                    text-align: center;
                    font-size: 0.75rem;
                }}
            }}
            
            .container {{
                max-width: 1200px;
                margin: 0 auto;
                padding: 20px;
            }}
            
            .header {{
                background: var(--background);
                border-radius: 20px;
                padding: 40px;
                text-align: center;
                box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
                margin-bottom: 30px;
                backdrop-filter: blur(10px);
            }}
            
            .header h1 {{
                font-size: 3rem;
                font-weight: 700;
                background: linear-gradient(135deg, var(--primary), var(--accent));
                -webkit-background-clip: text;
                -webkit-text-fill-color: transparent;
                margin-bottom: 15px;
            }}
            
            .header p {{
                font-size: 1.2rem;
                color: var(--text-secondary);
                margin-bottom: 20px;
            }}
            
            .author-info {{
                background: var(--surface);
                border-radius: 15px;
                padding: 20px;
                margin-bottom: 20px;
                border: 1px solid var(--border);
            }}
            
            .author-info h3 {{
                color: var(--primary);
                margin-bottom: 15px;
                font-size: 1.3rem;
            }}
            
            .social-links {{
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
                gap: 15px;
                margin-top: 15px;
            }}
            
            .social-link {{
                display: flex;
                align-items: center;
                padding: 12px 16px;
                background: var(--background);
                border-radius: 10px;
                text-decoration: none;
                color: var(--text-primary);
                border: 1px solid var(--border);
                transition: all 0.3s ease;
            }}
            
            .social-link:hover {{
                transform: translateY(-2px);
                box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.1);
                border-color: var(--primary);
            }}
            
            .social-link .icon {{
                margin-right: 10px;
                font-size: 1.2rem;
            }}
            
            .api-section {{
                background: var(--background);
                border-radius: 20px;
                padding: 30px;
                margin-bottom: 30px;
                box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.1);
            }}
            
            .api-section h2 {{
                color: var(--primary);
                margin-bottom: 20px;
                font-size: 1.8rem;
                display: flex;
                align-items: center;
                gap: 10px;
            }}
            
            .auth-box {{
                background: linear-gradient(135deg, #fef3c7, #fde68a);
                border-radius: 15px;
                padding: 25px;
                border-left: 4px solid var(--warning);
                margin-bottom: 25px;
            }}
            
            .auth-box h3 {{
                color: #92400e;
                margin-bottom: 15px;
            }}
            
            .code-block {{
                background: #1e293b;
                color: #e2e8f0;
                padding: 20px;
                border-radius: 10px;
                font-family: 'Fira Code', monospace;
                font-size: 0.9rem;
                overflow-x: auto;
                margin: 15px 0;
                border: 1px solid #374151;
            }}
            
            .endpoints-grid {{
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                gap: 20px;
                margin-top: 25px;
            }}
            
            .endpoint-card {{
                background: var(--surface);
                border-radius: 15px;
                padding: 25px;
                border: 1px solid var(--border);
                transition: all 0.3s ease;
            }}
            
            .endpoint-card:hover {{
                transform: translateY(-5px);
                box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
                border-color: var(--primary);
            }}
            
            .endpoint-card h4 {{
                color: var(--primary);
                margin-bottom: 10px;
                font-size: 1.2rem;
            }}
            
            .method-badge {{
                display: inline-block;
                padding: 4px 12px;
                border-radius: 20px;
                font-size: 0.8rem;
                font-weight: 600;
                margin-bottom: 10px;
            }}
            
            .method-get {{
                background: #dcfce7;
                color: #166534;
            }}
            
            .method-post {{
                background: #dbeafe;
                color: #1e40af;
            }}
            
            .example-section {{
                background: var(--background);
                border-radius: 20px;
                padding: 30px;
                margin-bottom: 30px;
                box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.1);
            }}
            
            .curl-example {{
                background: #0f172a;
                color: #e2e8f0;
                padding: 25px;
                border-radius: 15px;
                font-family: 'Fira Code', monospace;
                font-size: 0.9rem;
                overflow-x: auto;
                margin: 20px 0;
                border: 1px solid #1e293b;
            }}
            
            .curl-example .comment {{
                color: #64748b;
            }}
            
            .curl-example .string {{
                color: #10b981;
            }}
            
            .curl-example .flag {{
                color: #f59e0b;
            }}
            
            .footer {{
                text-align: center;
                padding: 40px 20px;
                color: var(--background);
                font-size: 0.9rem;
            }}
            
            .footer a {{
                color: var(--background);
                text-decoration: none;
                font-weight: 500;
            }}
            
            .footer a:hover {{
                text-decoration: underline;
            }}
            
            .status-badge {{
                display: inline-flex;
                align-items: center;
                gap: 8px;
                padding: 8px 16px;
                background: #dcfce7;
                color: #166534;
                border-radius: 20px;
                font-size: 0.9rem;
                font-weight: 500;
                margin-top: 10px;
            }}
            
            .token-display {{
                background: #fef3c7;
                border: 2px dashed #f59e0b;
                border-radius: 10px;
                padding: 15px;
                margin: 15px 0;
                text-align: center;
                font-family: 'Fira Code', monospace;
                font-weight: 600;
                color: #92400e;
            }}
            
            @media (max-width: 768px) {{
                .header h1 {{
                    font-size: 2rem;
                }}
                
                .container {{
                    padding: 15px;
                }}
                
                .social-links {{
                    grid-template-columns: 1fr;
                }}
            }}
        </style>
    </head>
    <body>
        <!-- Navigation Menu -->
        <nav class="author-nav" id="authorNav">
            <div class="nav-container">
                <a href="#" class="nav-brand">
                    <span>👨‍💻</span>
                    <span>Nguyễn Ngọc Thiện</span>
                </a>
                <div class="nav-links">
                    <a href="https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1" class="nav-link" target="_blank">
                        <span>📺</span>
                        <span>YouTube</span>
                    </a>
                    <a href="https://www.facebook.com/Ban.Thien.Handsome/" class="nav-link" target="_blank">
                        <span>📘</span>
                        <span>Facebook</span>
                    </a>
                    <a href="tel:0888884749" class="nav-link phone">
                        <span>📱</span>
                        <span>08.8888.4749</span>
                    </a>
                    <a href="https://www.youtube.com/@kalvinthiensocial/playlists" class="nav-link" target="_blank">
                        <span>🎬</span>
                        <span>N8N Tutorials</span>
                    </a>
                </div>
            </div>
        </nav>
        
        <div class="container">
            <div class="header">
                <h1>📰 News Content API</h1>
                <p>API lấy nội dung tin tức chuyên nghiệp với Newspaper4k</p>
                <div class="status-badge">
                    <span>🟢</span>
                    <span>API đang hoạt động - Version 2.0.0</span>
                </div>
            </div>
            
            <div class="author-info">
                <h3>👨‍💻 Thông Tin Tác Giả</h3>
                <p><strong>Nguyễn Ngọc Thiện</strong> - Chuyên gia N8N & Automation</p>
                
                <div class="social-links">
                    <a href="https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1" class="social-link" target="_blank">
                        <span class="icon">📺</span>
                        <div>
                            <strong>YouTube: Kalvin Thien Social</strong><br>
                            <small>HẢY ĐĂNG KÝ ĐỂ ỦNG HỘ!</small>
                        </div>
                    </a>
                    <a href="https://www.facebook.com/Ban.Thien.Handsome/" class="social-link" target="_blank">
                        <span class="icon">📘</span>
                        <div>
                            <strong>Facebook</strong><br>
                            <small>Ban Thien Handsome</small>
                        </div>
                    </a>
                    <a href="tel:0888884749" class="social-link">
                        <span class="icon">📱</span>
                        <div>
                            <strong>Zalo/Phone</strong><br>
                            <small>08.8888.4749</small>
                        </div>
                    </a>
                    <a href="https://www.youtube.com/@kalvinthiensocial/playlists" class="social-link" target="_blank">
                        <span class="icon">🎬</span>
                        <div>
                            <strong>N8N Tutorials</strong><br>
                            <small>Playlist chuyên sâu</small>
                        </div>
                    </a>
                </div>
            </div>
            
            <div class="api-section">
                <h2>🔐 Xác Thực API</h2>
                <div class="auth-box">
                    <h3>⚠️ Quan trọng: Bearer Token</h3>
                    <p>Tất cả các API endpoints yêu cầu Bearer Token trong header Authorization:</p>
                    <div class="code-block">Authorization: Bearer YOUR_TOKEN</div>
                    <div class="token-display">
                        <strong>⚠️ Token được ẩn vì lý do bảo mật</strong>
                        <p style="font-size: 0.9em; margin-top: 8px; color: #666;">
                            Để xem hoặc đổi token, chạy lệnh: <code>./change-api-token.sh</code>
                        </p>
                    </div>
                </div>
            </div>
            
            <div class="api-section">
                <h2>🚀 API Endpoints</h2>
                <div class="endpoints-grid">
                    <div class="endpoint-card">
                        <span class="method-badge method-get">GET</span>
                        <h4>/health</h4>
                        <p>Kiểm tra trạng thái hoạt động của API</p>
                    </div>
                    
                    <div class="endpoint-card">
                        <span class="method-badge method-get">GET</span>
                        <h4>/article</h4>
                        <p>Lấy nội dung chi tiết của một bài viết từ URL</p>
                    </div>
                    
                    <div class="endpoint-card">
                        <span class="method-badge method-get">GET</span>
                        <h4>/feed</h4>
                        <p>Crawl nhiều bài viết từ RSS feed</p>
                    </div>
                    
                    <div class="endpoint-card">
                        <span class="method-badge method-get">GET</span>
                        <h4>/docs</h4>
                        <p>Tài liệu API tương tác (Swagger UI)</p>
                    </div>
                </div>
            </div>
            
            <div class="example-section">
                <h2>💡 Ví Dụ Sử Dụng</h2>
                
                <h3>1. Kiểm tra trạng thái API:</h3>
                <div class="curl-example">
<span class="comment"># Kiểm tra API có hoạt động không</span>
curl <span class="flag">-H</span> <span class="string">"Authorization: Bearer YOUR_TOKEN"</span> \\
  <span class="string">"https://api.${DOMAIN}/health"</span>
                </div>
                
                <h3>2. Lấy nội dung bài viết:</h3>
                <div class="curl-example">
<span class="comment"># Lấy nội dung từ URL bài báo</span>
curl <span class="flag">-H</span> <span class="string">"Authorization: Bearer YOUR_TOKEN"</span> \\
  <span class="string">"https://api.${DOMAIN}/article?url=https://vnexpress.net/example-article"</span>
                </div>
                
                <h3>3. Crawl RSS feed:</h3>
                <div class="curl-example">
<span class="comment"># Lấy 10 bài viết mới nhất từ RSS feed</span>
curl <span class="flag">-H</span> <span class="string">"Authorization: Bearer YOUR_TOKEN"</span> \\
  <span class="string">"https://api.${DOMAIN}/feed?url=https://vnexpress.net/rss&limit=10"</span>
                </div>
                
                <h3>4. Sử dụng trong N8N:</h3>
                <div class="curl-example">
<span class="comment"># Cấu hình HTTP Request node trong N8N:</span>
<span class="comment"># Method: GET</span>
<span class="comment"># URL: https://api.${DOMAIN}/article</span>
<span class="comment"># Headers: Authorization = Bearer YOUR_TOKEN</span>
<span class="comment"># Query Parameters: url = {{$json.article_url}}</span>
                </div>
            </div>
            
            <div class="api-section">
                <h2>📚 Tài Liệu & Hỗ Trợ</h2>
                <div class="endpoints-grid">
                    <div class="endpoint-card">
                        <h4>📖 API Documentation</h4>
                        <p>Tài liệu chi tiết với Swagger UI</p>
                        <a href="/docs" style="color: var(--primary); text-decoration: none; font-weight: 500;">→ Xem docs</a>
                    </div>
                    
                    <div class="endpoint-card">
                        <h4>🎥 Video Tutorials</h4>
                        <p>Hướng dẫn sử dụng API trong N8N</p>
                        <a href="https://www.youtube.com/@kalvinthiensocial/playlists" target="_blank" style="color: var(--primary); text-decoration: none; font-weight: 500;">→ Xem playlist</a>
                    </div>
                    
                    <div class="endpoint-card">
                        <h4>💬 Hỗ Trợ</h4>
                        <p>Liên hệ trực tiếp qua Zalo</p>
                        <a href="tel:0888884749" style="color: var(--primary); text-decoration: none; font-weight: 500;">→ 08.8888.4749</a>
                    </div>
                    
                    <div class="endpoint-card">
                        <h4>⚙️ Đổi Token</h4>
                        <p>Hướng dẫn thay đổi Bearer Token</p>
                        <a href="#change-token" style="color: var(--primary); text-decoration: none; font-weight: 500;">→ Xem hướng dẫn</a>
                    </div>
                </div>
            </div>
            
            <div class="api-section" id="change-token">
                <h2>🔑 Hướng Dẫn Đổi Bearer Token</h2>
                <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; border-left: 4px solid var(--primary);">
                    <h3>📋 Các bước thực hiện:</h3>
                    <ol style="line-height: 1.8;">
                        <li><strong>SSH vào server</strong> và di chuyển đến thư mục N8N:</li>
                        <div class="code-block" style="margin: 10px 0;">cd /home/n8n</div>
                        
                        <li><strong>Chạy script đổi token:</strong></li>
                        <div class="code-block" style="margin: 10px 0;">sudo ./change-api-token.sh</div>
                        
                        <li><strong>Chọn một trong hai cách:</strong>
                            <ul style="margin-top: 8px;">
                                <li>Nhập token tùy chỉnh của bạn</li>
                                <li>Để trống để tạo token tự động</li>
                            </ul>
                        </li>
                        
                        <li><strong>Script sẽ tự động:</strong>
                            <ul style="margin-top: 8px;">
                                <li>Cập nhật file cấu hình</li>
                                <li>Restart FastAPI container</li>
                                <li>Hiển thị token mới</li>
                            </ul>
                        </li>
                        
                        <li><strong>Cập nhật token mới</strong> trong tất cả N8N workflows của bạn</li>
                    </ol>
                    
                    <h3 style="margin-top: 20px;">🔍 Kiểm tra token hiện tại:</h3>
                    <div class="code-block" style="margin: 10px 0;">cat /home/n8n/fastapi/.env</div>
                    
                    <h3 style="margin-top: 20px;">✅ Test API với token mới:</h3>
                    <div class="code-block" style="margin: 10px 0;">curl -H "Authorization: Bearer YOUR_NEW_TOKEN" "https://api.${DOMAIN}/health"</div>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p>© 2025 <a href="https://www.youtube.com/@kalvinthiensocial">Kalvin Thien Social</a> - Phát triển bởi Nguyễn Ngọc Thiện</p>
            <p>🚀 Hãy đăng ký kênh YouTube để ủng hộ tác giả!</p>
        </div>
        
        <!-- JavaScript for Navigation -->
        <script>
            let lastScrollTop = 0;
            const nav = document.getElementById('authorNav');
            
            window.addEventListener('scroll', function() {{
                let scrollTop = window.pageYOffset || document.documentElement.scrollTop;
                
                if (scrollTop > lastScrollTop && scrollTop > 100) {{
                    // Scrolling down & past header
                    nav.classList.add('hidden');
                }} else {{
                    // Scrolling up or at top
                    nav.classList.remove('hidden');
                }}
                
                lastScrollTop = scrollTop <= 0 ? 0 : scrollTop; // For Mobile or negative scrolling
            }});
            
            // Smooth scroll for anchor links
            document.querySelectorAll('a[href^="#"]').forEach(anchor => {{
                anchor.addEventListener('click', function (e) {{
                    e.preventDefault();
                    const target = document.querySelector(this.getAttribute('href'));
                    if (target) {{
                        target.scrollIntoView({{
                            behavior: 'smooth',
                            block: 'start'
                        }});
                    }}
                }});
            }});
        </script>
    </body>
    </html>
    """

@app.get("/docs", response_class=HTMLResponse)
async def api_docs():
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>API Documentation</title>
        <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@3.25.0/swagger-ui.css" />
    </head>
    <body>
        <div id="swagger-ui"></div>
        <script src="https://unpkg.com/swagger-ui-dist@3.25.0/swagger-ui-bundle.js"></script>
        <script>
            SwaggerUIBundle({
                url: '/openapi.json',
                dom_id: '#swagger-ui',
                presets: [
                    SwaggerUIBundle.presets.apis,
                    SwaggerUIBundle.presets.standalone
                ]
            });
        </script>
    </body>
    </html>
    """

@app.get("/health")
async def health_check(credentials: HTTPAuthorizationCredentials = Depends(verify_token)):
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "version": "2.0.0",
        "api_token_status": "valid",
        "features": ["article_extraction", "rss_parsing", "content_crawling"]
    }

@app.get("/article")
async def get_article(
    url: str = Query(..., description="URL của bài viết cần lấy nội dung"),
    credentials: HTTPAuthorizationCredentials = Depends(verify_token)
):
    """Lấy nội dung chi tiết của một bài viết từ URL"""
    
    try:
        # Tạo article object
        article = newspaper.Article(url)
        
        # Cấu hình user agent
        config = newspaper.Config()
        config.browser_user_agent = ua.random
        config.request_timeout = 30
        
        article.config = config
        
        # Download và parse
        article.download()
        article.parse()
        
        # Trích xuất thông tin
        result = {
            "success": True,
            "url": url,
            "title": article.title,
            "text": article.text,
            "summary": article.summary if hasattr(article, 'summary') else "",
            "authors": article.authors,
            "publish_date": article.publish_date.isoformat() if article.publish_date else None,
            "top_image": article.top_image,
            "meta_keywords": article.meta_keywords,
            "meta_description": article.meta_description,
            "word_count": len(article.text.split()) if article.text else 0,
            "language": article.meta_lang if hasattr(article, 'meta_lang') else "unknown"
        }
        
        return result
        
    except Exception as e:
        logger.error(f"Error processing article {url}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Lỗi khi xử lý bài viết: {str(e)}")

@app.get("/feed")
async def parse_feed(
    url: str = Query(..., description="URL của RSS feed"),
    limit: int = Query(10, description="Số lượng bài viết tối đa", ge=1, le=50),
    credentials: HTTPAuthorizationCredentials = Depends(verify_token)
):
    """Phân tích RSS feed và lấy danh sách bài viết"""
    
    try:
        feed = feedparser.parse(url)
        
        if not feed.entries:
            raise HTTPException(status_code=404, detail="Không tìm thấy bài viết trong feed")
        
        articles = []
        processed = 0
        
        for entry in feed.entries[:limit]:
            if processed >= limit:
                break
                
            try:
                article_data = {
                    "title": entry.get("title", ""),
                    "url": entry.get("link", ""),
                    "description": entry.get("description", ""),
                    "published": entry.get("published", ""),
                    "author": entry.get("author", ""),
                    "tags": [tag.term for tag in entry.get("tags", [])]
                }
                articles.append(article_data)
                processed += 1
                
            except Exception as e:
                logger.warning(f"Error processing entry: {str(e)}")
                continue
        
        return {
            "success": True,
            "feed_url": url,
            "feed_title": feed.feed.get("title", ""),
            "feed_description": feed.feed.get("description", ""),
            "articles": articles,
            "total_articles": len(articles),
            "requested_limit": limit
        }
        
    except Exception as e:
        logger.error(f"Error processing feed {url}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Lỗi khi xử lý RSS feed: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    print(f"🚀 Khởi động News Content API tại http://0.0.0.0:8000")
    print(f"📚 Tài liệu API: http://0.0.0.0:8000/docs")
    print(f"🔑 Bearer Token: {API_TOKEN}")
    
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        workers=1
    )
EOF

    # Lưu token vào file cấu hình
    echo "API_TOKEN=\"$NEWS_API_TOKEN\"" > $N8N_DIR/fastapi/.env
    
    # Tạo script đổi token
    cat << EOF > $N8N_DIR/change-api-token.sh
#!/bin/bash

# Script đổi Bearer Token cho News API
echo "🔑 SCRIPT ĐỔI BEARER TOKEN CHO NEWS API"
echo "======================================"

N8N_DIR="\$(dirname "\$0")"
cd "\$N8N_DIR"

# Lấy domain từ docker-compose.yml
DOMAIN=\$(grep "N8N_HOST=" docker-compose.yml | cut -d'=' -f2 | tr -d '{}'  2>/dev/null || echo "yourdomain.com")

# Hiển thị token hiện tại
if [ -f "fastapi/.env" ]; then
    CURRENT_TOKEN=\$(grep "API_TOKEN=" fastapi/.env | cut -d'"' -f2)
    echo "🔍 Token hiện tại: \$CURRENT_TOKEN"
else
    echo "⚠️  Không tìm thấy file cấu hình token"
fi

echo ""
read -p "Nhập Bearer Token mới (để trống = tạo tự động): " NEW_TOKEN

if [ -z "\$NEW_TOKEN" ]; then
    NEW_TOKEN=\$(openssl rand -hex 16)
    echo "🎲 Token tự động được tạo: \$NEW_TOKEN"
fi

# Cập nhật token
echo "API_TOKEN=\"\$NEW_TOKEN\"" > fastapi/.env

# Cập nhật docker-compose.yml
if [ -f "docker-compose.yml" ]; then
    sed -i "s/API_TOKEN=.*/API_TOKEN=\$NEW_TOKEN/" docker-compose.yml
    echo "✅ Đã cập nhật docker-compose.yml"
fi

# Restart FastAPI container
echo "🔄 Đang restart FastAPI container..."
if command -v docker-compose &> /dev/null; then
    docker-compose restart fastapi
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    docker compose restart fastapi
else
    echo "❌ Không tìm thấy docker-compose command"
    exit 1
fi

echo ""
echo "✅ HOÀN TẤT ĐỔI TOKEN!"
echo "🔑 Token mới: \$NEW_TOKEN"
echo "🌐 Hãy cập nhật token này trong N8N workflows của bạn"
echo "📚 Kiểm tra API: https://api.\$DOMAIN/health"
echo ""
echo "📋 VÍ DỤ SỬ DỤNG CURL:"
echo "curl -H \"Authorization: Bearer \$NEW_TOKEN\" \\"
echo "  \"https://api.\$DOMAIN/article?url=https://example.com/news\""
EOF

    chmod +x $N8N_DIR/change-api-token.sh
    
    echo "✅ News API đã được cấu hình thành công"
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

# Tạo cron job để chạy mỗi 12 giờ
echo "Thiết lập cron job cập nhật tự động mỗi 12 giờ và sao lưu hàng ngày..."
UPDATE_CRON="0 */12 * * * $N8N_DIR/update-n8n.sh"
BACKUP_CRON="0 2 * * * $N8N_DIR/backup-workflows.sh"
(crontab -l 2>/dev/null | grep -v "update-n8n.sh\|backup-workflows.sh"; echo "$UPDATE_CRON"; echo "$BACKUP_CRON") | crontab -

# Danh sách các thành phần thất bại
FAILED_COMPONENTS=()

# Kiểm tra trạng thái News API
if [ "$SETUP_NEWS_API" = "y" ]; then
    if systemctl is-active --quiet news-api; then
        NEWS_API_STATUS="✅ Đang chạy"
    else
        NEWS_API_STATUS="❌ Lỗi khởi động"
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
if $IS_WSL; then
    echo "  - Môi trường: WSL (Windows Subsystem for Linux)"
    echo "  - Docker daemon: Khởi động thủ công"
else
    echo "  - Môi trường: VPS/Server Linux"
    echo "  - Docker service: Systemd quản lý"
fi
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
    echo "📰 NEWS CONTENT API (CẢI TIẾN MỚI):"
    echo "  - URL API: https://api.${DOMAIN}"
    echo "  - Docs UI: https://api.${DOMAIN}/docs (với Navigation Menu responsive)"
    echo "  - Bearer Token: $NEWS_API_TOKEN (được ẩn trong docs vì bảo mật)"
    echo "  - Chức năng: Lấy nội dung tin tức với Newspaper4k"
    echo ""
    echo "  📋 CÁCH SỬ DỤNG NEWS API TRONG N8N:"
    echo "  1. Tạo HTTP Request node trong workflow"
    echo "  2. Method: GET"
    echo "  3. URL: https://api.${DOMAIN}/article"
    echo "  4. Headers: Authorization: Bearer $NEWS_API_TOKEN"
    echo "  5. Query Parameters: url = {{$json.article_url}}"
    echo ""
    echo "  🔧 ĐỔI BEARER TOKEN (HƯỚNG DẪN ĐẦY ĐỦ):"
    echo "  - Chạy lệnh: $N8N_DIR/change-api-token.sh"
    echo "  - Script tự động lấy domain từ cấu hình"
    echo "  - Hiển thị ví dụ curl với domain và token mới"
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
echo "  - 📋 Xem logs N8N: cd $N8N_DIR && docker-compose logs -f n8n"
echo "  - 🔄 Restart N8N: cd $N8N_DIR && docker-compose restart"
echo "  - 💾 Backup thủ công: $N8N_DIR/manual-backup.sh"
echo "  - 🔄 Cập nhật thủ công: $N8N_DIR/update-n8n.sh"
echo "  - 🏗️  Rebuild containers: cd $N8N_DIR && docker-compose down && docker-compose up -d --build"

if [ "$SETUP_NEWS_API" = "y" ]; then
    echo "  - 🔄 Restart News API: cd $N8N_DIR && docker-compose restart fastapi"
    echo "  - 📋 Xem logs News API: cd $N8N_DIR && docker-compose logs -f fastapi"
    echo "  - 🔑 Đổi API Token: $N8N_DIR/change-api-token.sh"
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
    echo "  - Giữ bí mật Bearer Token của News API: $NEWS_API_TOKEN"
fi

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
echo "  - Phiên bản: v2.1 (27/06/2025)"
echo "  - Tính năng mới: News API + Telegram Backup + Navigation UI"
echo ""
echo "======================================================================"
echo "🎯 CÀI ĐẶT HOÀN TẤT! CHÚC BẠN SỬ DỤNG N8N HIỆU QUẢ!"
echo "======================================================================"
