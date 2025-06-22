#!/bin/bash

# =============================================================================
# Script cài đặt N8N tự động với FFmpeg, yt-dlp, Puppeteer, SSL và các tính năng mới
# Tác giả: Nguyễn Ngọc Thiện
# YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1
# Facebook: https://www.facebook.com/Ban.Thien.Handsome/
# Zalo/SDT: 08.8888.4749
# =============================================================================

echo "======================================================================"
echo "     🚀 Script Cài Đặt N8N Tự Động Phiên Bản Cải Tiến 🚀  "
echo "     ✨ Với FFmpeg, yt-dlp, Puppeteer, SSL và FastAPI ✨"
echo "======================================================================"
echo ""
echo "📺 Kênh YouTube hướng dẫn: https://www.youtube.com/@kalvinthiensocial"
echo "🔥 Hãy ĐĂNG KÝ kênh để ủng hộ và nhận thông báo video mới!"
echo "📱 Liên hệ: 08.8888.4749 (Zalo/Phone)"
echo "📧 Facebook: https://www.facebook.com/Ban.Thien.Handsome/"
echo ""
echo "======================================================================"

# Kiểm tra xem script có được chạy với quyền root không
if [[ $EUID -ne 0 ]]; then
   echo "❌ Script này cần được chạy với quyền root" 
   exit 1
fi

# Biến cấu hình toàn cục
SCRIPT_VERSION="2.0"
AUTHOR_NAME="Nguyễn Ngọc Thiện"
YOUTUBE_CHANNEL="https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1"
FACEBOOK_LINK="https://www.facebook.com/Ban.Thien.Handsome/"
CONTACT_INFO="08.8888.4749"

# Biến cấu hình Telegram
ENABLE_TELEGRAM_BACKUP=false
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# Biến cấu hình FastAPI
ENABLE_FASTAPI=false
FASTAPI_PASSWORD=""
FASTAPI_PORT="8000"

# Hàm thiết lập swap tự động
setup_swap() {
    echo "🔄 Kiểm tra và thiết lập swap tự động..."
    
    # Kiểm tra nếu swap đã được bật
    if [ "$(swapon --show | wc -l)" -gt 0 ]; then
        SWAP_SIZE=$(free -h | grep Swap | awk '{print $2}')
        echo "✅ Swap đã được bật với kích thước ${SWAP_SIZE}. Bỏ qua thiết lập."
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
    
    echo "⚙️  Đang thiết lập swap với kích thước ${SWAP_GB}GB (${SWAP_SIZE}MB)..."
    
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
    
    echo "✅ Đã thiết lập swap với kích thước ${SWAP_GB}GB thành công."
    echo "🔧 Swappiness đã được đặt thành 10 (mặc định: 60)"
    echo "🔧 Vfs_cache_pressure đã được đặt thành 50 (mặc định: 100)"
}

# Hàm hiển thị trợ giúp
show_help() {
    echo "📋 Cách sử dụng: $0 [tùy chọn]"
    echo "📖 Tùy chọn:"
    echo "  -h, --help      Hiển thị trợ giúp này"
    echo "  -d, --dir DIR   Chỉ định thư mục cài đặt n8n (mặc định: /home/n8n)"
    echo "  -s, --skip-docker Bỏ qua cài đặt Docker (nếu đã có)"
    echo "  --enable-telegram  Kích hoạt gửi backup qua Telegram"
    echo "  --enable-fastapi   Kích hoạt API FastAPI để lấy nội dung bài viết"
    echo ""
    echo "🎥 Kênh YouTube: $YOUTUBE_CHANNEL"
    echo "📞 Liên hệ: $CONTACT_INFO"
    exit 0
}

# Hàm cấu hình Telegram
setup_telegram_config() {
    echo ""
    echo "🤖 === CẤU HÌNH TELEGRAM BOT ==="
    echo "📝 Để nhận backup tự động qua Telegram, bạn cần:"
    echo "   1. Tạo bot mới với @BotFather trên Telegram"
    echo "   2. Lấy Bot Token"
    echo "   3. Lấy Chat ID (ID cuộc trò chuyện)"
    echo ""
    
    read -p "🔑 Nhập Bot Token của bạn: " TELEGRAM_BOT_TOKEN
    if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
        echo "⚠️  Bot Token không được để trống. Tắt tính năng Telegram."
        ENABLE_TELEGRAM_BACKUP=false
        return
    fi
    
    read -p "🆔 Nhập Chat ID của bạn: " TELEGRAM_CHAT_ID
    if [ -z "$TELEGRAM_CHAT_ID" ]; then
        echo "⚠️  Chat ID không được để trống. Tắt tính năng Telegram."
        ENABLE_TELEGRAM_BACKUP=false
        return
    fi
    
    echo "✅ Cấu hình Telegram hoàn tất!"
    ENABLE_TELEGRAM_BACKUP=true
}

# Hàm cấu hình FastAPI
setup_fastapi_config() {
    echo ""
    echo "⚡ === CẤU HÌNH FASTAPI API ==="
    echo "📄 API này cho phép lấy nội dung bài viết từ URL bất kỳ"
    echo "🔐 Sử dụng Bearer Token để bảo mật"
    echo ""
    
    read -p "🔑 Nhập mật khẩu Bearer Token: " FASTAPI_PASSWORD
    if [ -z "$FASTAPI_PASSWORD" ]; then
        echo "⚠️  Mật khẩu không được để trống. Tắt tính năng FastAPI."
        ENABLE_FASTAPI=false
        return
    fi
    
    read -p "🌐 Nhập cổng cho API (mặc định 8000): " FASTAPI_PORT_INPUT
    if [ -n "$FASTAPI_PORT_INPUT" ]; then
        FASTAPI_PORT="$FASTAPI_PORT_INPUT"
    fi
    
    echo "✅ Cấu hình FastAPI hoàn tất!"
    echo "📡 API sẽ chạy trên cổng: $FASTAPI_PORT"
    ENABLE_FASTAPI=true
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
        --enable-telegram)
            setup_telegram_config
            shift
            ;;
        --enable-fastapi)
            setup_fastapi_config
            shift
            ;;
        *)
            echo "❌ Tùy chọn không hợp lệ: $1"
            show_help
            ;;
    esac
done

# Hỏi người dùng về tính năng bổ sung
echo ""
echo "🔧 === TÙY CHỌN TÍNH NĂNG BỔ SUNG ==="
echo ""

# Hỏi về Telegram backup
if [ "$ENABLE_TELEGRAM_BACKUP" = false ]; then
    read -p "📱 Bạn có muốn kích hoạt gửi backup tự động qua Telegram? (y/n): " telegram_choice
    if [[ $telegram_choice =~ ^[Yy]$ ]]; then
        setup_telegram_config
    fi
fi

# Hỏi về FastAPI
if [ "$ENABLE_FASTAPI" = false ]; then
    read -p "⚡ Bạn có muốn cài đặt API FastAPI để lấy nội dung bài viết? (y/n): " fastapi_choice
    if [[ $fastapi_choice =~ ^[Yy]$ ]]; then
        setup_fastapi_config
    fi
fi

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
        echo "📦 Cài đặt dnsutils (để sử dụng lệnh dig)..."
        apt-get update
        apt-get install -y dnsutils
    fi
}

# Thiết lập swap
setup_swap

# Hàm cài đặt Docker
install_docker() {
    if $SKIP_DOCKER; then
        echo "⏭️  Bỏ qua cài đặt Docker theo yêu cầu..."
        return
    fi
    
    echo "🐳 Cài đặt Docker và Docker Compose..."
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
        echo "📦 Cài đặt Docker Compose..."
        apt-get install -y docker-compose
    elif command -v docker &> /dev/null && ! docker compose version &> /dev/null; then
        echo "📦 Cài đặt Docker Compose plugin..."
        apt-get install -y docker-compose-plugin
    fi
    
    # Kiểm tra Docker đã cài đặt thành công chưa
    if ! command -v docker &> /dev/null; then
        echo "❌ Lỗi: Docker chưa được cài đặt đúng cách."
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! (command -v docker &> /dev/null && docker compose version &> /dev/null); then
        echo "❌ Lỗi: Docker Compose chưa được cài đặt đúng cách."
        exit 1
    fi

    # Thêm user hiện tại vào nhóm docker nếu không phải root
    if [ "$SUDO_USER" != "" ]; then
        echo "👤 Thêm user $SUDO_USER vào nhóm docker để có thể chạy docker mà không cần sudo..."
        usermod -aG docker $SUDO_USER
        echo "✅ Đã thêm user $SUDO_USER vào nhóm docker. Các thay đổi sẽ có hiệu lực sau khi đăng nhập lại."
    fi

    # Khởi động lại dịch vụ Docker
    systemctl restart docker

    echo "✅ Docker và Docker Compose đã được cài đặt thành công."
}

# Cài đặt các gói cần thiết
echo "📦 Đang cài đặt các công cụ cần thiết..."
apt-get update
apt-get install -y dnsutils curl cron jq tar gzip python3-full python3-venv pipx net-tools

# Cài đặt yt-dlp thông qua pipx hoặc virtual environment
echo "📺 Cài đặt yt-dlp..."
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
read -p "🌐 Nhập tên miền hoặc tên miền phụ của bạn: " DOMAIN

# Kiểm tra domain
echo "🔍 Kiểm tra domain $DOMAIN..."
if check_domain $DOMAIN; then
    echo "✅ Domain $DOMAIN đã được trỏ đúng đến server này. Tiếp tục cài đặt"
else
    echo "⚠️  Domain $DOMAIN chưa được trỏ đến server này."
    echo "📝 Vui lòng cập nhật bản ghi DNS để trỏ $DOMAIN đến IP $(curl -s https://api.ipify.org)"
    echo "🔄 Sau khi cập nhật DNS, hãy chạy lại script này"
    exit 1
fi

# Cài đặt Docker và Docker Compose
install_docker

# Tạo thư mục cho n8n
echo "📁 Tạo cấu trúc thư mục cho n8n tại $N8N_DIR..."
mkdir -p $N8N_DIR
mkdir -p $N8N_DIR/files
mkdir -p $N8N_DIR/files/temp
mkdir -p $N8N_DIR/files/youtube_content_anylystic
mkdir -p $N8N_DIR/files/backup_full

# Tiếp tục với phần tạo Dockerfile...

# Tạo Dockerfile - CẬP NHẬT VỚI PUPPETEER
echo "🐳 Tạo Dockerfile để cài đặt n8n với FFmpeg, yt-dlp và Puppeteer..."
cat << 'EOF' > $N8N_DIR/Dockerfile
FROM n8nio/n8n:latest

USER root

# Cài đặt FFmpeg, wget, zip và các gói phụ thuộc khác
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

# Cài đặt yt-dlp trực tiếp sử dụng pip trong container
RUN pip3 install --break-system-packages -U yt-dlp && \
    chmod +x /usr/bin/yt-dlp

# Thiết lập biến môi trường cho Puppeteer
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Cài đặt n8n-nodes-puppeteer
WORKDIR /usr/local/lib/node_modules/n8n
RUN npm install n8n-nodes-puppeteer

# Kiểm tra cài đặt các công cụ
RUN ffmpeg -version && \
    wget --version | head -n 1 && \
    zip --version | head -n 2 && \
    yt-dlp --version && \
    chromium-browser --version

# Tạo thư mục youtube_content_anylystic và backup_full và set đúng quyền
RUN mkdir -p /files/youtube_content_anylystic && \
    mkdir -p /files/backup_full && \
    chown -R node:node /files

# Trở lại user node
USER node
WORKDIR /home/node
EOF

# Tạo file docker-compose.yml với cập nhật mới
echo "📝 Tạo file docker-compose.yml..."
cat << EOF > $N8N_DIR/docker-compose.yml
# Cấu hình Docker Compose cho N8N với FFmpeg, yt-dlp, và Puppeteer
# Tác giả: $AUTHOR_NAME
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

# Tạo file Caddyfile
echo "🌐 Tạo file Caddyfile..."
cat << EOF > $N8N_DIR/Caddyfile
${DOMAIN} {
    reverse_proxy n8n:5678
}
EOF

# Tạo script sao lưu workflow và credentials CẢI TIẾN
echo "💾 Tạo script sao lưu workflow và credentials cải tiến..."
cat << 'EOF' > $N8N_DIR/backup-workflows.sh
#!/bin/bash

# =============================================================================
# Script Backup N8N Workflows và Credentials - Phiên bản cải tiến
# Tác giả: Nguyễn Ngọc Thiện
# YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1
# =============================================================================

# Thiết lập biến
BACKUP_DIR="$N8N_DIR/files/backup_full"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/n8n_backup_$DATE.tar.gz"
TEMP_DIR="/tmp/n8n_backup_$DATE"

# Đọc cấu hình Telegram từ file config nếu có
TELEGRAM_CONFIG_FILE="$N8N_DIR/telegram_config.conf"
ENABLE_TELEGRAM_BACKUP=false
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

if [ -f "$TELEGRAM_CONFIG_FILE" ]; then
    source "$TELEGRAM_CONFIG_FILE"
fi

# Hàm ghi log với timestamp
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$BACKUP_DIR/backup.log"
}

# Hàm gửi thông báo qua Telegram
send_telegram_notification() {
    local message="$1"
    local document_path="$2"
    
    if [ "$ENABLE_TELEGRAM_BACKUP" = true ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        # Gửi thông báo text
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$message" \
            -d parse_mode="HTML" > /dev/null
        
        # Gửi file backup nếu có và kích thước < 50MB
        if [ -n "$document_path" ] && [ -f "$document_path" ]; then
            local file_size=$(stat --format="%s" "$document_path")
            local max_size=$((50 * 1024 * 1024))  # 50MB in bytes
            
            if [ "$file_size" -lt "$max_size" ]; then
                curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument" \
                    -F chat_id="$TELEGRAM_CHAT_ID" \
                    -F document=@"$document_path" \
                    -F caption="📦 Backup N8N - $(date '+%d/%m/%Y %H:%M:%S')" > /dev/null
                log "✅ Đã gửi file backup qua Telegram"
            else
                local size_mb=$((file_size / 1024 / 1024))
                log "⚠️ File backup quá lớn (${size_mb}MB) để gửi qua Telegram (giới hạn 50MB)"
                curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
                    -d chat_id="$TELEGRAM_CHAT_ID" \
                    -d text="⚠️ File backup quá lớn (${size_mb}MB) để gửi qua Telegram" > /dev/null
            fi
        fi
    fi
}

# Hàm kiểm tra và tạo thư mục backup
setup_backup_directories() {
    mkdir -p "$TEMP_DIR"
    mkdir -p "$TEMP_DIR/workflows"
    mkdir -p "$TEMP_DIR/credentials"
    mkdir -p "$TEMP_DIR/settings"
    mkdir -p "$BACKUP_DIR"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log "❌ Không thể tạo thư mục backup: $BACKUP_DIR"
        exit 1
    fi
}

# Bắt đầu quá trình backup
log "🚀 Bắt đầu sao lưu workflows và credentials..."
send_telegram_notification "🚀 <b>Bắt đầu backup N8N</b>%0A⏰ Thời gian: $(date '+%d/%m/%Y %H:%M:%S')"

# Thiết lập thư mục
setup_backup_directories

# Tìm container n8n
N8N_CONTAINER=$(docker ps -q --filter "name=n8n" 2>/dev/null | head -n 1)

if [ -z "$N8N_CONTAINER" ]; then
    log "❌ Không tìm thấy container n8n đang chạy"
    send_telegram_notification "❌ <b>Lỗi Backup N8N</b>%0A🔍 Không tìm thấy container n8n đang chạy"
    rm -rf "$TEMP_DIR"
    exit 1
fi

log "✅ Tìm thấy container n8n: $N8N_CONTAINER"

# Xuất tất cả workflows
log "📋 Đang xuất danh sách workflows..."
WORKFLOWS_JSON=$(docker exec $N8N_CONTAINER n8n list:workflows --json 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$WORKFLOWS_JSON" ]; then
    # Đếm số lượng workflows
    WORKFLOW_COUNT=$(echo "$WORKFLOWS_JSON" | jq '. | length' 2>/dev/null || echo "0")
    log "💼 Tìm thấy $WORKFLOW_COUNT workflows"
    
    if [ "$WORKFLOW_COUNT" -gt 0 ]; then
        # Xuất từng workflow riêng lẻ
        echo "$WORKFLOWS_JSON" | jq -c '.[]' 2>/dev/null | while read -r workflow; do
            id=$(echo "$workflow" | jq -r '.id' 2>/dev/null)
            name=$(echo "$workflow" | jq -r '.name' 2>/dev/null | tr -dc '[:alnum:][:space:]_-' | tr '[:space:]' '_')
            
            if [ -n "$id" ] && [ "$id" != "null" ]; then
                log "📄 Đang xuất workflow: $name (ID: $id)"
                docker exec $N8N_CONTAINER n8n export:workflow --id="$id" --output="/tmp/workflow_$id.json" 2>/dev/null
                
                if [ $? -eq 0 ]; then
                    docker cp "$N8N_CONTAINER:/tmp/workflow_$id.json" "$TEMP_DIR/workflows/$id-$name.json" 2>/dev/null
                    docker exec $N8N_CONTAINER rm -f "/tmp/workflow_$id.json" 2>/dev/null
                else
                    log "⚠️ Không thể xuất workflow: $name (ID: $id)"
                fi
            fi
        done
        
        # Xuất tất cả workflows vào một file duy nhất
        log "📦 Đang xuất tất cả workflows vào file tổng hợp..."
        docker exec $N8N_CONTAINER n8n export:workflow --all --output="/tmp/all_workflows.json" 2>/dev/null
        if [ $? -eq 0 ]; then
            docker cp "$N8N_CONTAINER:/tmp/all_workflows.json" "$TEMP_DIR/workflows/all_workflows.json" 2>/dev/null
            docker exec $N8N_CONTAINER rm -f "/tmp/all_workflows.json" 2>/dev/null
        fi
    else
        log "⚠️ Không tìm thấy workflow nào để sao lưu"
    fi
else
    log "⚠️ Không thể lấy danh sách workflows hoặc không có workflows nào"
fi

# Sao lưu credentials (database và encryption key)
log "🔐 Đang sao lưu credentials và cấu hình..."

# Sao lưu database
if docker exec $N8N_CONTAINER test -f "/home/node/.n8n/database.sqlite"; then
    docker cp "$N8N_CONTAINER:/home/node/.n8n/database.sqlite" "$TEMP_DIR/credentials/" 2>/dev/null
    if [ $? -eq 0 ]; then
        log "✅ Đã sao lưu database.sqlite"
    else
        log "⚠️ Không thể sao lưu database.sqlite"
    fi
else
    log "⚠️ Không tìm thấy database.sqlite"
fi

# Sao lưu encryption key
if docker exec $N8N_CONTAINER test -f "/home/node/.n8n/config"; then
    docker cp "$N8N_CONTAINER:/home/node/.n8n/config" "$TEMP_DIR/credentials/" 2>/dev/null
    log "✅ Đã sao lưu file config"
fi

# Sao lưu các file cấu hình khác
for config_file in "encryptionKey" "settings.json" "config.json"; do
    if docker exec $N8N_CONTAINER test -f "/home/node/.n8n/$config_file"; then
        docker cp "$N8N_CONTAINER:/home/node/.n8n/$config_file" "$TEMP_DIR/credentials/" 2>/dev/null
        if [ $? -eq 0 ]; then
            log "✅ Đã sao lưu $config_file"
        fi
    fi
done

# Tạo file thông tin backup
cat << INFO > "$TEMP_DIR/backup_info.txt"
N8N Backup Information
======================
Backup Date: $(date)
N8N Container: $N8N_CONTAINER
Backup Version: 2.0
Created By: Nguyễn Ngọc Thiện
YouTube Channel: https://www.youtube.com/@kalvinthiensocial

Backup Contents:
- Workflows: $(find "$TEMP_DIR/workflows" -name "*.json" | wc -l) files
- Database: $([ -f "$TEMP_DIR/credentials/database.sqlite" ] && echo "✅ Included" || echo "❌ Missing")
- Encryption Key: $([ -f "$TEMP_DIR/credentials/encryptionKey" ] && echo "✅ Included" || echo "❌ Missing")
- Config Files: $(find "$TEMP_DIR/credentials" -name "*.json" | wc -l) files

Restore Instructions:
1. Stop N8N container
2. Extract this backup
3. Copy database.sqlite and encryptionKey to .n8n directory
4. Import workflows using n8n import:workflow command
5. Restart N8N container

For support: 08.8888.4749
INFO

# Tạo file tar.gz nén
log "📦 Đang tạo file backup nén: $BACKUP_FILE"
tar -czf "$BACKUP_FILE" -C "$(dirname "$TEMP_DIR")" "$(basename "$TEMP_DIR")" 2>/dev/null

if [ $? -eq 0 ] && [ -f "$BACKUP_FILE" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log "✅ Đã tạo file backup: $BACKUP_FILE ($BACKUP_SIZE)"
    
    # Gửi thông báo thành công qua Telegram
    send_telegram_notification "✅ <b>Backup N8N hoàn tất!</b>%0A📦 File: $(basename "$BACKUP_FILE")%0A📊 Kích thước: $BACKUP_SIZE%0A⏰ Thời gian: $(date '+%d/%m/%Y %H:%M:%S')" "$BACKUP_FILE"
else
    log "❌ Không thể tạo file backup"
    send_telegram_notification "❌ <b>Lỗi tạo file backup N8N</b>%0A⏰ Thời gian: $(date '+%d/%m/%Y %H:%M:%S')"
fi

# Dọn dẹp thư mục tạm thời
log "🧹 Dọn dẹp thư mục tạm thời..."
rm -rf "$TEMP_DIR"

# Giữ lại tối đa 30 bản sao lưu gần nhất
log "🗂️ Giữ lại 30 bản sao lưu gần nhất..."
OLD_BACKUPS=$(find "$BACKUP_DIR" -name "n8n_backup_*.tar.gz" -type f | sort -r | tail -n +31)
if [ -n "$OLD_BACKUPS" ]; then
    echo "$OLD_BACKUPS" | xargs rm -f
    DELETED_COUNT=$(echo "$OLD_BACKUPS" | wc -l)
    log "🗑️ Đã xóa $DELETED_COUNT bản backup cũ"
fi

# Thống kê tổng quan
TOTAL_BACKUPS=$(find "$BACKUP_DIR" -name "n8n_backup_*.tar.gz" -type f | wc -l)
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

log "📊 === THỐNG KÊ BACKUP ==="
log "📁 Tổng số backup: $TOTAL_BACKUPS"
log "💾 Tổng dung lượng: $TOTAL_SIZE"
log "✅ Sao lưu hoàn tất: $BACKUP_FILE"

echo ""
echo "🎉 Backup hoàn tất thành công!"
echo "📁 File backup: $BACKUP_FILE"
echo "📊 Kích thước: $BACKUP_SIZE"
echo ""
echo "🎥 Hướng dẫn khôi phục: https://www.youtube.com/@kalvinthiensocial"
echo "📞 Hỗ trợ: 08.8888.4749"
EOF

# Đặt quyền thực thi cho script sao lưu
chmod +x $N8N_DIR/backup-workflows.sh

# Tạo file cấu hình Telegram nếu được kích hoạt
if [ "$ENABLE_TELEGRAM_BACKUP" = true ]; then
    echo "📱 Tạo file cấu hình Telegram..."
    cat << EOF > $N8N_DIR/telegram_config.conf
# Cấu hình Telegram Bot cho N8N Backup
# Tác giả: $AUTHOR_NAME
ENABLE_TELEGRAM_BACKUP=true
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"
EOF
    chmod 600 $N8N_DIR/telegram_config.conf
    echo "✅ Đã tạo file cấu hình Telegram"
fi

# Tạo FastAPI application nếu được kích hoạt
if [ "$ENABLE_FASTAPI" = true ]; then
    echo "⚡ Cài đặt FastAPI và các dependencies..."
    
    # Cập nhật docker-compose.yml để bao gồm FastAPI service
    cat << EOF > $N8N_DIR/docker-compose.yml
# Cấu hình Docker Compose cho N8N với FFmpeg, yt-dlp, Puppeteer và FastAPI
# Tác giả: $AUTHOR_NAME
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

    # Cập nhật Caddyfile để bao gồm FastAPI
    cat << EOF > $N8N_DIR/Caddyfile
${DOMAIN} {
    reverse_proxy n8n:5678
}

api.${DOMAIN} {
    reverse_proxy fastapi:8000
}
EOF

    # Tạo Dockerfile cho FastAPI
    echo "🐳 Tạo Dockerfile.fastapi..."
    cat << 'EOF' > $N8N_DIR/Dockerfile.fastapi
FROM python:3.11-slim

WORKDIR /app

# Cài đặt các packages cần thiết cho newspaper4k
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

# Copy requirements và cài đặt dependencies
COPY fastapi_requirements.txt .
RUN pip install --no-cache-dir -r fastapi_requirements.txt

# Copy ứng dụng
COPY fastapi_app.py .
COPY templates/ templates/

# Tạo thư mục logs
RUN mkdir -p logs

# Expose port
EXPOSE 8000

# Chạy ứng dụng
CMD ["python", "fastapi_app.py"]
EOF

    # Tạo requirements.txt cho FastAPI
    echo "📄 Tạo fastapi_requirements.txt..."
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

    # Tạo ứng dụng FastAPI
    echo "⚡ Tạo ứng dụng FastAPI..."
    cat << 'EOF' > $N8N_DIR/fastapi_app.py
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
FastAPI Article Extractor
Tác giả: Nguyễn Ngọc Thiện
YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1
Facebook: https://www.facebook.com/Ban.Thien.Handsome/
Zalo/SDT: 08.8888.4749

API để lấy nội dung bài viết từ URL sử dụng newspaper4k
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

# Cấu hình logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/fastapi.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Cấu hình
FASTAPI_PASSWORD = os.getenv("FASTAPI_PASSWORD", "default_password")
FASTAPI_HOST = os.getenv("FASTAPI_HOST", "0.0.0.0")
FASTAPI_PORT = int(os.getenv("FASTAPI_PORT", 8000))

# Khởi tạo user agent ngẫu nhiên
ua = UserAgent()

# Security
security = HTTPBearer()

# Templates
templates = Jinja2Templates(directory="templates")

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Xác thực Bearer token"""
    if credentials.credentials != FASTAPI_PASSWORD:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token không hợp lệ",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return credentials.credentials

# Models
class ArticleRequest(BaseModel):
    url: HttpUrl = Field(..., description="URL của bài viết cần lấy nội dung")
    language: Optional[str] = Field("vi", description="Ngôn ngữ của bài viết (vi, en, etc.)")
    
class ArticleResponse(BaseModel):
    success: bool = Field(..., description="Trạng thái thành công")
    url: str = Field(..., description="URL gốc")
    title: Optional[str] = Field(None, description="Tiêu đề bài viết")
    text: Optional[str] = Field(None, description="Nội dung chính của bài viết")
    summary: Optional[str] = Field(None, description="Tóm tắt tự động")
    authors: List[str] = Field(default_factory=list, description="Danh sách tác giả")
    publish_date: Optional[str] = Field(None, description="Ngày xuất bản")
    top_image: Optional[str] = Field(None, description="Ảnh đại diện")
    keywords: List[str] = Field(default_factory=list, description="Từ khóa")
    meta_description: Optional[str] = Field(None, description="Mô tả meta")
    meta_keywords: Optional[str] = Field(None, description="Từ khóa meta")
    canonical_link: Optional[str] = Field(None, description="Link canonical")
    extracted_at: str = Field(..., description="Thời gian trích xuất")
    processing_time: float = Field(..., description="Thời gian xử lý (giây)")

class ErrorResponse(BaseModel):
    success: bool = False
    error: str = Field(..., description="Thông báo lỗi")
    error_code: str = Field(..., description="Mã lỗi")
    url: Optional[str] = Field(None, description="URL gây lỗi")

def create_session():
    """Tạo session với retry và user agent"""
    session = requests.Session()
    
    # Cấu hình retry
    retry_strategy = Retry(
        total=3,
        backoff_factor=1,
        status_forcelist=[429, 500, 502, 503, 504],
    )
    
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    
    # User agent ngẫu nhiên
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
    """Trích xuất nội dung bài viết"""
    start_time = datetime.now()
    
    try:
        # Tạo session tùy chỉnh
        session = create_session()
        
        # Tạo Article object
        article = Article(url, language=language)
        article.set_requests_session(session)
        
        # Download và parse
        article.download()
        article.parse()
        
        # NLP processing (tóm tắt và keywords)
        try:
            article.nlp()
        except Exception as nlp_error:
            logger.warning(f"NLP processing failed: {nlp_error}")
        
        # Tính thời gian xử lý
        processing_time = (datetime.now() - start_time).total_seconds()
        
        # Chuẩn bị response
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
        error_msg = f"Lỗi khi trích xuất bài viết: {str(e)}"
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
    logger.info("🚀 FastAPI Article Extractor đang khởi động...")
    logger.info(f"👤 Tác giả: Nguyễn Ngọc Thiện")
    logger.info(f"📺 YouTube: https://www.youtube.com/@kalvinthiensocial")
    logger.info(f"📱 Liên hệ: 08.8888.4749")
    yield
    logger.info("🛑 FastAPI Article Extractor đang tắt...")

# Khởi tạo FastAPI app
app = FastAPI(
    title="N8N Article Extractor API",
    description="""
    🚀 **API Trích Xuất Nội Dung Bài Viết**
    
    API này cho phép trích xuất nội dung từ bất kỳ URL bài viết nào sử dụng thư viện newspaper4k.
    
    **Tác giả:** Nguyễn Ngọc Thiện  
    **YouTube:** [Kalvin Thien Social](https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1)  
    **Facebook:** [Ban Thien Handsome](https://www.facebook.com/Ban.Thien.Handsome/)  
    **Liên hệ:** 08.8888.4749
    
    ## Tính năng:
    - ✅ Trích xuất tiêu đề, nội dung, tác giả
    - ✅ Tóm tắt tự động bằng AI
    - ✅ Trích xuất từ khóa
    - ✅ Hỗ trợ nhiều ngôn ngữ
    - ✅ Random User-Agent để tránh block
    - ✅ Retry mechanism
    - ✅ Bearer Token authentication
    
    ## Cách sử dụng với N8N:
    1. Sử dụng HTTP Request node
    2. URL: `https://api.yourdomain.com/extract`
    3. Method: POST
    4. Headers: `Authorization: Bearer YOUR_PASSWORD`
    5. Body: `{"url": "https://example.com/article"}`
    """,
    version="2.0.0",
    contact={
        "name": "Nguyễn Ngọc Thiện",
        "url": "https://www.youtube.com/@kalvinthiensocial",
        "email": "contact@example.com"
    },
    lifespan=lifespan
)

@app.get("/", response_class=HTMLResponse, include_in_schema=False)
async def root(request: Request):
    """Trang chủ với hướng dẫn sử dụng"""
    return templates.TemplateResponse("index.html", {
        "request": request,
        "title": "N8N Article Extractor API",
        "author": "Nguyễn Ngọc Thiện",
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
        "author": "Nguyễn Ngọc Thiện"
    }

@app.post("/extract", response_model=ArticleResponse)
async def extract_article(
    request: ArticleRequest,
    token: str = Depends(verify_token)
):
    """
    Trích xuất nội dung bài viết từ URL
    
    **Yêu cầu Bearer Token authentication**
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
    Trích xuất nhiều bài viết cùng lúc (tối đa 10 URLs)
    
    **Yêu cầu Bearer Token authentication**
    """
    if len(urls) > 10:
        raise HTTPException(
            status_code=400,
            detail="Tối đa 10 URLs cho mỗi batch request"
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
    """Thống kê sử dụng API"""
    return {
        "api_version": "2.0.0",
        "author": "Nguyễn Ngọc Thiện",
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
    logger.info(f"🚀 Khởi động FastAPI server trên {FASTAPI_HOST}:{FASTAPI_PORT}")
    uvicorn.run(
        "fastapi_app:app",
        host=FASTAPI_HOST,
        port=FASTAPI_PORT,
        reload=False,
        access_log=True
    )
EOF

    # Tạo thư mục templates
    mkdir -p $N8N_DIR/templates
    
    # Tạo template HTML
    echo "🎨 Tạo template HTML..."
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
            <h1>🚀 {{ title }}</h1>
            <p>API Trích Xuất Nội Dung Bài Viết Tự Động</p>
        </div>
        
        <div class="content">
            <div class="author-info">
                <h2>👨‍💻 Thông Tin Tác Giả</h2>
                <p><strong>{{ author }}</strong></p>
                <p>📞 Liên hệ: {{ contact }}</p>
                
                <div class="social-links">
                    <a href="{{ youtube }}" class="social-link" target="_blank">
                        📺 Đăng Ký Kênh YouTube
                    </a>
                    <a href="{{ facebook }}" class="social-link" target="_blank">
                        📘 Facebook
                    </a>
                    <a href="tel:{{ contact }}" class="social-link">
                        📱 Zalo/Phone
                    </a>
                </div>
            </div>
            
            <div class="features">
                <div class="feature">
                    <div class="feature-icon">🎯</div>
                    <h3>Trích Xuất Thông Minh</h3>
                    <p>Tự động trích xuất tiêu đề, nội dung, tác giả và thông tin meta từ bất kỳ bài viết nào</p>
                </div>
                
                <div class="feature">
                    <div class="feature-icon">🤖</div>
                    <h3>Tóm Tắt AI</h3>
                    <p>Tự động tạo tóm tắt và trích xuất từ khóa quan trọng từ nội dung bài viết</p>
                </div>
                
                <div class="feature">
                    <div class="feature-icon">🌐</div>
                    <h3>Đa Ngôn Ngữ</h3>
                    <p>Hỗ trợ trích xuất từ bài viết bằng nhiều ngôn ngữ khác nhau</p>
                </div>
                
                <div class="feature">
                    <div class="feature-icon">🔒</div>
                    <h3>Bảo Mật</h3>
                    <p>Sử dụng Bearer Token authentication để bảo vệ API khỏi truy cập trái phép</p>
                </div>
            </div>
            
            <div class="api-docs">
                <h3>📖 Hướng Dẫn Sử Dụng API</h3>
                
                <div class="endpoint">
                    <span class="endpoint-method post">POST</span>
                    <strong>/extract</strong> - Trích xuất nội dung từ một URL
                    
                    <pre>{
  "url": "https://vnexpress.net/sample-article",
  "language": "vi"
}</pre>
                </div>
                
                <div class="endpoint">
                    <span class="endpoint-method post">POST</span>
                    <strong>/extract/batch</strong> - Trích xuất nhiều URL cùng lúc
                    
                    <pre>[
  "https://vnexpress.net/article-1",
  "https://vnexpress.net/article-2"
]</pre>
                </div>
                
                <div class="endpoint">
                    <span class="endpoint-method">GET</span>
                    <strong>/health</strong> - Kiểm tra trạng thái API
                </div>
                
                <h4>🔑 Authentication Header:</h4>
                <pre>Authorization: Bearer YOUR_PASSWORD</pre>
                
                <h4>📊 Sử dụng với N8N:</h4>
                <ol>
                    <li>Thêm HTTP Request node</li>
                    <li>URL: <code>https://api.yourdomain.com/extract</code></li>
                    <li>Method: POST</li>
                    <li>Headers: <code>Authorization: Bearer YOUR_PASSWORD</code></li>
                    <li>Body: JSON với URL cần trích xuất</li>
                </ol>
            </div>
            
            <div class="api-docs">
                <h3>🔗 Links Quan Trọng</h3>
                <ul style="list-style: none; padding: 0;">
                    <li style="margin: 10px 0;">📚 <a href="/docs" target="_blank">API Documentation (Swagger)</a></li>
                    <li style="margin: 10px 0;">🔧 <a href="/redoc" target="_blank">API Documentation (ReDoc)</a></li>
                    <li style="margin: 10px 0;">❤️ <a href="/health" target="_blank">Health Check</a></li>
                </ul>
            </div>
        </div>
        
        <div class="footer">
            <p>&copy; 2024 {{ author }}. Made with ❤️ for N8N Community</p>
            <p>🎥 Subscribe: {{ youtube }}</p>
        </div>
    </div>
</body>
</html>
EOF

    # Tạo thư mục logs cho FastAPI
    mkdir -p $N8N_DIR/fastapi_logs
    
    echo "✅ Đã tạo ứng dụng FastAPI hoàn chỉnh"
fi

# Đặt quyền cho thư mục n8n
echo "🔐 Đặt quyền cho thư mục n8n..."
chown -R 1000:1000 $N8N_DIR
chmod -R 755 $N8N_DIR

# Khởi động các container
echo "🚀 Khởi động các container..."
echo "⏳ Lưu ý: Quá trình build image có thể mất vài phút, vui lòng đợi..."
cd $N8N_DIR

# Kiểm tra cổng 80 có đang được sử dụng không
if netstat -tuln | grep -q ":80\s"; then
    echo "⚠️  CẢNH BÁO: Cổng 80 đang được sử dụng bởi một ứng dụng khác. Caddy sẽ sử dụng cổng 8080."
    # Đã cấu hình 8080 trong docker-compose.yml
else
    # Nếu cổng 80 trống, cập nhật docker-compose.yml để sử dụng cổng 80
    sed -i 's/"8080:80"/"80:80"/g' $N8N_DIR/docker-compose.yml
    echo "✅ Cổng 80 đang trống. Caddy sẽ sử dụng cổng 80 mặc định."
fi

# Kiểm tra quyền truy cập Docker
echo "🔍 Kiểm tra quyền truy cập Docker..."
if ! docker ps &>/dev/null; then
    echo "🔑 Khởi động container với sudo vì quyền truy cập Docker..."
    # Sử dụng docker-compose hoặc docker compose tùy theo phiên bản
    if command -v docker-compose &> /dev/null; then
        sudo docker-compose up -d
    elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
        sudo docker compose up -d
    else
        echo "❌ Lỗi: Không tìm thấy lệnh docker-compose hoặc docker compose."
        exit 1
    fi
else
    # Sử dụng docker-compose hoặc docker compose tùy theo phiên bản
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
        docker compose up -d
    else
        echo "❌ Lỗi: Không tìm thấy lệnh docker-compose hoặc docker compose."
        exit 1
    fi
fi

# Đợi một lúc để các container có thể khởi động
echo "⏳ Đợi các container khởi động..."
sleep 15

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

# Kiểm tra các container đã chạy chưa
echo "🔍 Kiểm tra các container đã chạy chưa..."

if $DOCKER_CMD ps | grep -q "n8n-ffmpeg-latest" || $DOCKER_CMD ps | grep -q "n8n"; then
    echo "✅ Container n8n đã chạy thành công."
else
    echo "⏳ Container n8n đang được khởi động, có thể mất thêm thời gian..."
    echo "📋 Bạn có thể kiểm tra logs bằng lệnh:"
    echo "   $DOCKER_COMPOSE_CMD logs -f n8n"
fi

if $DOCKER_CMD ps | grep -q "caddy:2"; then
    echo "✅ Container caddy đã chạy thành công."
else
    echo "⏳ Container caddy đang được khởi động, có thể mất thêm thời gian..."
    echo "📋 Bạn có thể kiểm tra logs bằng lệnh:"
    echo "   $DOCKER_COMPOSE_CMD logs -f caddy"
fi

if [ "$ENABLE_FASTAPI" = true ]; then
    if $DOCKER_CMD ps | grep -q "fastapi-newspaper"; then
        echo "✅ Container FastAPI đã chạy thành công."
    else
        echo "⏳ Container FastAPI đang được khởi động, có thể mất thêm thời gian..."
        echo "📋 Bạn có thể kiểm tra logs bằng lệnh:"
        echo "   $DOCKER_COMPOSE_CMD logs -f fastapi"
    fi
fi

# Hiển thị thông tin về cổng được sử dụng
CADDY_PORT=$(grep -o '"[0-9]\+:80"' $N8N_DIR/docker-compose.yml | cut -d':' -f1 | tr -d '"')
echo ""
echo "🌐 === THÔNG TIN TRUY CẬP ==="
echo "🔧 Cấu hình cổng HTTP: $CADDY_PORT"
if [ "$CADDY_PORT" = "8080" ]; then
    echo "🌍 N8N: http://${DOMAIN}:8080 hoặc https://${DOMAIN}"
else
    echo "🌍 N8N: http://${DOMAIN} hoặc https://${DOMAIN}"
fi

if [ "$ENABLE_FASTAPI" = true ]; then
    echo "⚡ FastAPI: https://api.${DOMAIN} hoặc http://${DOMAIN}:${FASTAPI_PORT}"
    echo "📚 API Docs: https://api.${DOMAIN}/docs"
    echo "🔑 Bearer Token: $FASTAPI_PASSWORD"
fi

# Kiểm tra FFmpeg, yt-dlp và Puppeteer trong container n8n
echo ""
echo "🔍 Kiểm tra các công cụ trong container n8n..."

N8N_CONTAINER=$($DOCKER_CMD ps -q --filter "name=n8n" 2>/dev/null | head -n 1)
if [ -n "$N8N_CONTAINER" ]; then
    echo "📦 Container ID: $N8N_CONTAINER"
    
    if $DOCKER_CMD exec $N8N_CONTAINER ffmpeg -version &> /dev/null; then
        echo "✅ FFmpeg đã được cài đặt thành công trong container n8n."
        FFMPEG_VERSION=$($DOCKER_CMD exec $N8N_CONTAINER ffmpeg -version | head -n 1)
        echo "   📌 $FFMPEG_VERSION"
    else
        echo "⚠️  Lưu ý: FFmpeg có thể chưa được cài đặt đúng cách trong container."
    fi

    if $DOCKER_CMD exec $N8N_CONTAINER yt-dlp --version &> /dev/null; then
        echo "✅ yt-dlp đã được cài đặt thành công trong container n8n."
        YTDLP_VERSION=$($DOCKER_CMD exec $N8N_CONTAINER yt-dlp --version)
        echo "   📌 yt-dlp version: $YTDLP_VERSION"
    else
        echo "⚠️  Lưu ý: yt-dlp có thể chưa được cài đặt đúng cách trong container."
    fi
    
    if $DOCKER_CMD exec $N8N_CONTAINER chromium-browser --version &> /dev/null; then
        echo "✅ Chromium đã được cài đặt thành công trong container n8n."
        CHROMIUM_VERSION=$($DOCKER_CMD exec $N8N_CONTAINER chromium-browser --version)
        echo "   📌 $CHROMIUM_VERSION"
    else
        echo "⚠️  Lưu ý: Chromium có thể chưa được cài đặt đúng cách trong container."
    fi
else
    echo "⚠️  Lưu ý: Không thể kiểm tra công cụ ngay lúc này. Container n8n chưa sẵn sàng."
fi

# Tạo script cập nhật tự động CẢI TIẾN
echo ""
echo "🔄 Tạo script cập nhật tự động..."
cat << 'EOF' > $N8N_DIR/update-n8n.sh
#!/bin/bash

# =============================================================================
# Script Cập Nhật N8N Tự Động - Phiên bản cải tiến
# Tác giả: Nguyễn Ngọc Thiện
# YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1
# =============================================================================

# Đường dẫn đến thư mục n8n
N8N_DIR="$N8N_DIR"

# Hàm ghi log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$N8N_DIR/update.log"
}

log "🚀 Bắt đầu kiểm tra cập nhật..."

# Kiểm tra Docker command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    log "❌ Không tìm thấy lệnh docker-compose hoặc docker compose."
    exit 1
fi

# Cập nhật yt-dlp trên host
log "📺 Cập nhật yt-dlp trên host system..."
if command -v pipx &> /dev/null; then
    pipx upgrade yt-dlp
elif [ -d "/opt/yt-dlp-venv" ]; then
    /opt/yt-dlp-venv/bin/pip install -U yt-dlp
else
    log "⚠️ Không tìm thấy cài đặt yt-dlp đã biết"
fi

# Lấy phiên bản hiện tại
CURRENT_IMAGE_ID=$(docker images -q n8n-ffmpeg-latest)
if [ -z "$CURRENT_IMAGE_ID" ]; then
    log "⚠️ Không tìm thấy image n8n-ffmpeg-latest"
    exit 1
fi

# Kiểm tra và xóa image gốc n8nio/n8n cũ nếu cần
OLD_BASE_IMAGE_ID=$(docker images -q n8nio/n8n)

# Pull image gốc mới nhất
log "⬇️ Kéo image n8nio/n8n mới nhất"
docker pull n8nio/n8n

# Lấy image ID mới
NEW_BASE_IMAGE_ID=$(docker images -q n8nio/n8n)

# Kiểm tra xem image gốc đã thay đổi chưa
if [ "$NEW_BASE_IMAGE_ID" != "$OLD_BASE_IMAGE_ID" ]; then
    log "🆕 Phát hiện image mới (${NEW_BASE_IMAGE_ID}), tiến hành cập nhật..."
    
    # Sao lưu dữ liệu n8n trước khi cập nhật
    BACKUP_DATE=$(date '+%Y%m%d_%H%M%S')
    BACKUP_FILE="$N8N_DIR/backup_before_update_${BACKUP_DATE}.zip"
    log "💾 Tạo bản sao lưu trước cập nhật tại $BACKUP_FILE"
    
    cd "$N8N_DIR"
    zip -r "$BACKUP_FILE" . -x "update-n8n.sh" -x "backup_*" -x "files/temp/*" -x "Dockerfile*" -x "docker-compose.yml" &>/dev/null
    
    # Build lại image n8n-ffmpeg
    log "🔨 Đang build lại image n8n-ffmpeg-latest..."
    $DOCKER_COMPOSE build --no-cache
    
    # Khởi động lại container
    log "🔄 Khởi động lại container..."
    $DOCKER_COMPOSE down
    $DOCKER_COMPOSE up -d
    
    log "✅ Cập nhật hoàn tất, phiên bản mới: ${NEW_BASE_IMAGE_ID}"
    
    # Gửi thông báo Telegram nếu có
    if [ -f "$N8N_DIR/telegram_config.conf" ]; then
        source "$N8N_DIR/telegram_config.conf"
        if [ "$ENABLE_TELEGRAM_BACKUP" = true ]; then
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
                -d chat_id="$TELEGRAM_CHAT_ID" \
                -d text="✅ <b>N8N đã được cập nhật!</b>%0A🆕 Image ID: ${NEW_BASE_IMAGE_ID}%0A⏰ Thời gian: $(date '+%d/%m/%Y %H:%M:%S')" \
                -d parse_mode="HTML" > /dev/null
        fi
    fi
else
    log "ℹ️ Không có cập nhật mới cho n8n"
    
    # Cập nhật yt-dlp trong container
    log "📺 Cập nhật yt-dlp trong container n8n..."
    N8N_CONTAINER=$(docker ps -q --filter "name=n8n" 2>/dev/null)
    if [ -n "$N8N_CONTAINER" ]; then
        docker exec -u root $N8N_CONTAINER pip3 install --break-system-packages -U yt-dlp
        log "✅ yt-dlp đã được cập nhật thành công trong container"
    else
        log "⚠️ Không tìm thấy container n8n đang chạy"
    fi
fi

log "🎉 Hoàn thành kiểm tra cập nhật"
EOF

# Đặt quyền thực thi cho script cập nhật
chmod +x $N8N_DIR/update-n8n.sh

# Tạo cron job để chạy mỗi 12 giờ và sao lưu hàng ngày
echo "⏰ Thiết lập cron job cập nhật tự động mỗi 12 giờ và sao lưu hàng ngày..."
UPDATE_CRON="0 */12 * * * $N8N_DIR/update-n8n.sh"
BACKUP_CRON="0 2 * * * $N8N_DIR/backup-workflows.sh"

# Xóa các cron job cũ và thêm mới
(crontab -l 2>/dev/null | grep -v "update-n8n.sh\|backup-workflows.sh"; echo "$UPDATE_CRON"; echo "$BACKUP_CRON") | crontab -

echo "✅ Đã thiết lập cron jobs thành công"

# Tạo script kiểm tra trạng thái
echo "📊 Tạo script kiểm tra trạng thái..."
cat << 'EOF' > $N8N_DIR/check-status.sh
#!/bin/bash

# =============================================================================
# Script Kiểm Tra Trạng Thái N8N
# Tác giả: Nguyễn Ngọc Thiện
# =============================================================================

echo "🔍 === KIỂM TRA TRẠNG THÁI N8N ==="
echo "⏰ Thời gian: $(date)"
echo ""

# Kiểm tra Docker
if command -v docker &> /dev/null; then
    echo "✅ Docker đã được cài đặt"
    docker --version
else
    echo "❌ Docker chưa được cài đặt"
fi

echo ""

# Kiểm tra các container
echo "📦 === TRẠNG THÁI CONTAINERS ==="
if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(n8n|caddy|fastapi)"; then
    echo ""
else
    echo "⚠️ Không tìm thấy container nào đang chạy"
fi

echo ""

# Kiểm tra disk space
echo "💾 === DUNG LƯỢNG ĐĨA ==="
df -h | grep -E "(^/dev|Filesystem)"

echo ""

# Kiểm tra backup
echo "📦 === BACKUP GẦN NHẤT ==="
if [ -d "$N8N_DIR/files/backup_full" ]; then
    LATEST_BACKUP=$(find "$N8N_DIR/files/backup_full" -name "n8n_backup_*.tar.gz" -type f | sort -r | head -n 1)
    if [ -n "$LATEST_BACKUP" ]; then
        BACKUP_DATE=$(stat -c %y "$LATEST_BACKUP" | cut -d'.' -f1)
        BACKUP_SIZE=$(du -h "$LATEST_BACKUP" | cut -f1)
        echo "📁 File: $(basename "$LATEST_BACKUP")"
        echo "📅 Ngày: $BACKUP_DATE"
        echo "📊 Kích thước: $BACKUP_SIZE"
    else
        echo "⚠️ Không tìm thấy file backup nào"
    fi
else
    echo "❌ Thư mục backup không tồn tại"
fi

echo ""
echo "🎥 Hỗ trợ: https://www.youtube.com/@kalvinthiensocial"
echo "📞 Liên hệ: 08.8888.4749"
EOF

chmod +x $N8N_DIR/check-status.sh

echo ""
echo "======================================================================"
echo "🎉    CÀI ĐẶT N8N HOÀN TẤT THÀNH CÔNG!    🎉"
echo "======================================================================"
echo ""
echo "👨‍💻 Tác giả: $AUTHOR_NAME"
echo "🎥 Kênh YouTube: $YOUTUBE_CHANNEL"
echo "📘 Facebook: $FACEBOOK_LINK"
echo "📱 Liên hệ: $CONTACT_INFO"
echo ""
echo "🌟 === CẢM ƠN BẠN ĐÃ SỬ DỤNG SCRIPT! ==="
echo "🔥 Hãy ĐĂNG KÝ kênh YouTube để ủng hộ tác giả!"
echo "💝 Chia sẻ script này cho bạn bè nếu thấy hữu ích!"
echo ""

# Hiển thị thông tin về swap
if [ "$(swapon --show | wc -l)" -gt 0 ]; then
    SWAP_SIZE=$(free -h | grep Swap | awk '{print $2}')
    echo "🔄 === THÔNG TIN SWAP ==="
    echo "📊 Kích thước: ${SWAP_SIZE}"
    echo "⚙️ Swappiness: $(cat /proc/sys/vm/swappiness) (mức ưu tiên sử dụng RAM)"
    echo "🗂️ Vfs_cache_pressure: $(cat /proc/sys/vm/vfs_cache_pressure) (tốc độ giải phóng cache)"
    echo ""
fi

echo "📁 === THÔNG TIN HỆ THỐNG ==="
echo "🗃️ Thư mục cài đặt: $N8N_DIR"
echo "🌐 Truy cập N8N: https://${DOMAIN}"

if [ "$ENABLE_FASTAPI" = true ]; then
    echo "⚡ === THÔNG TIN FASTAPI ==="
    echo "🌐 API URL: https://api.${DOMAIN}"
    echo "📚 API Docs: https://api.${DOMAIN}/docs"
    echo "🔑 Bearer Token: $FASTAPI_PASSWORD"
fi

if [ "$ENABLE_TELEGRAM_BACKUP" = true ]; then
    echo "📱 === THÔNG TIN TELEGRAM ==="
    echo "🤖 Bot Token: ${TELEGRAM_BOT_TOKEN:0:10}..."
    echo "🆔 Chat ID: $TELEGRAM_CHAT_ID"
    echo "📦 Tự động gửi backup hàng ngày"
    echo ""
fi

echo "🔄 === TÍNH NĂNG TỰ ĐỘNG ==="
echo "✅ Cập nhật hệ thống mỗi 12 giờ"
echo "✅ Sao lưu workflow hàng ngày lúc 2 giờ sáng"
echo "✅ Giữ lại 30 bản backup gần nhất"
echo "✅ Log chi tiết tại $N8N_DIR/update.log và $N8N_DIR/files/backup_full/backup.log"
echo ""

echo "📺 === THÔNG TIN VIDEO YOUTUBE ==="
echo "🎬 Playlist N8N: https://www.youtube.com/@kalvinthiensocial/playlists"
echo "📖 Hướng dẫn sử dụng: Xem video trên kênh"
echo "🛠️ Hỗ trợ kỹ thuật: Bình luận dưới video"
echo ""

echo "🎯 === THÔNG TIN BACKUP ==="
echo "📁 Thư mục backup: $N8N_DIR/files/backup_full/"
echo "📂 Thư mục video YouTube: $N8N_DIR/files/youtube_content_anylystic/"
echo "📋 Script backup: $N8N_DIR/backup-workflows.sh"
echo "🔄 Script cập nhật: $N8N_DIR/update-n8n.sh"
echo "📊 Script kiểm tra: $N8N_DIR/check-status.sh"
echo ""

echo "🎪 === THÔNG TIN PUPPETEER ==="
echo "🤖 Chromium Browser đã được cài đặt trong container"
echo "🧩 n8n-nodes-puppeteer package đã được cài đặt sẵn"
echo "🔍 Tìm kiếm 'Puppeteer' trong bộ nút của n8n để sử dụng"
echo ""

echo "⚠️  === LƯU Ý QUAN TRỌNG ==="
echo "⏳ SSL có thể mất vài phút để được cấu hình hoàn tất"
echo "📋 Kiểm tra trạng thái: $N8N_DIR/check-status.sh"
echo "🔧 Xem logs container: cd $N8N_DIR && docker-compose logs -f"
echo "🆘 Hỗ trợ: Liên hệ $CONTACT_INFO hoặc comment YouTube"
echo ""

# Hiển thị thông tin lỗi nếu có
FAILED_FEATURES=""

if [ "$ENABLE_TELEGRAM_BACKUP" = true ] && [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    FAILED_FEATURES="${FAILED_FEATURES}- ❌ Telegram backup (thiếu Bot Token)\n"
fi

if [ "$ENABLE_FASTAPI" = true ] && [ -z "$FASTAPI_PASSWORD" ]; then
    FAILED_FEATURES="${FAILED_FEATURES}- ❌ FastAPI (thiếu password)\n"
fi

if [ -n "$FAILED_FEATURES" ]; then
    echo "⚠️  === TÍNH NĂNG CHƯA CẤU HÌNH ==="
    echo -e "$FAILED_FEATURES"
    echo "💡 Bạn có thể cấu hình lại bằng cách chạy script với tham số tương ứng"
    echo ""
fi

echo "🎊 === CHÚC BẠN SỬ DỤNG VUI VẺ! ==="
echo "Script được phát triển bởi $AUTHOR_NAME với ❤️"
echo "Phiên bản: $SCRIPT_VERSION"
echo "======================================================================"

# Gửi thông báo hoàn thành qua Telegram nếu có
if [ "$ENABLE_TELEGRAM_BACKUP" = true ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="🎉 <b>Cài đặt N8N hoàn tất!</b>%0A🌐 Domain: ${DOMAIN}%0A⏰ Thời gian: $(date '+%d/%m/%Y %H:%M:%S')%0A🎥 Hướng dẫn: ${YOUTUBE_CHANNEL}" \
        -d parse_mode="HTML" > /dev/null
fi 
