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

# Hàm cài đặt Docker
install_docker() {
    if $SKIP_DOCKER; then
        echo "Bỏ qua cài đặt Docker theo yêu cầu..."
        return
    fi
    
    echo "Cài đặt Docker và Docker Compose..."
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    
    # Thêm khóa Docker GPG
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    
    # Thêm repository Docker
    add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    
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

    echo "Docker và Docker Compose đã được cài đặt thành công."
}

# Cài đặt các gói cần thiết
echo "Đang cài đặt các công cụ cần thiết..."
apt-get update
apt-get install -y dnsutils curl cron python3-pip jq tar gzip

# Cài đặt yt-dlp trên host system
echo "Cài đặt yt-dlp..."
pip3 install -U yt-dlp

# Đảm bảo cron service đang chạy
systemctl enable cron
systemctl start cron

# Kiểm tra các lệnh cần thiết
check_commands

# Nhận input domain từ người dùng
read -p "Nhập tên miền hoặc tên miền phụ của bạn: " DOMAIN

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

# Tạo và sử dụng virtual environment để cài đặt yt-dlp
RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install -U yt-dlp

# Tạo symbolic link đến yt-dlp trong virtual environment
RUN ln -sf /opt/venv/bin/yt-dlp /usr/local/bin/yt-dlp && \
    chmod +x /usr/local/bin/yt-dlp

# Thiết lập PATH để bao gồm virtual environment
ENV PATH="/opt/venv/bin:$PATH"

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

# Tạo file docker-compose.yml
echo "Tạo file docker-compose.yml..."
cat << EOF > $N8N_DIR/docker-compose.yml
version: "3"
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

# Tạo file Caddyfile
echo "Tạo file Caddyfile..."
cat << EOF > $N8N_DIR/Caddyfile
${DOMAIN} {
    reverse_proxy n8n:5678
}
EOF

# Tạo script sao lưu workflow và credentials
echo "Tạo script sao lưu workflow và credentials..."
cat << EOF > $N8N_DIR/backup-workflows.sh
#!/bin/bash

# Thiết lập biến
BACKUP_DIR="/files/backup_full"
DATE=\$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="\$BACKUP_DIR/n8n_backup_\$DATE.tar"
TEMP_DIR="/tmp/n8n_backup_\$DATE"
N8N_CONTAINER=\$(docker ps -q --filter "name=n8n" 2>/dev/null)

# Hàm ghi log
log() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" >> \$BACKUP_DIR/backup.log
}

log "Bắt đầu sao lưu workflows và credentials..."

# Tạo thư mục tạm thời
mkdir -p \$TEMP_DIR
mkdir -p \$TEMP_DIR/workflows
mkdir -p \$TEMP_DIR/credentials
mkdir -p \$BACKUP_DIR

# Kiểm tra container n8n có đang chạy không
if [ -z "\$N8N_CONTAINER" ]; then
    log "Lỗi: Không tìm thấy container n8n đang chạy"
    rm -rf \$TEMP_DIR
    exit 1
fi

# Xuất danh sách workflow IDs
log "Xuất danh sách workflow IDs..."
docker exec \$N8N_CONTAINER n8n export:workflow --all --quiet

# Xuất từng workflow ra file JSON riêng
log "Xuất workflows ra file JSON..."
WORKFLOWS=\$(docker exec \$N8N_CONTAINER n8n list:workflows --json)
if [ -z "\$WORKFLOWS" ]; then
    log "Cảnh báo: Không tìm thấy workflow nào"
else
    echo "\$WORKFLOWS" | jq -c '.[]' | while read -r workflow; do
        id=\$(echo "\$workflow" | jq -r '.id')
        name=\$(echo "\$workflow" | jq -r '.name' | tr -dc '[:alnum:][:space:]' | tr '[:space:]' '_')
        log "Đang xuất workflow: \$name (ID: \$id)"
        docker exec \$N8N_CONTAINER n8n export:workflow --id="\$id" --output="\$TEMP_DIR/workflows/\$id-\$name.json"
    done
fi

# Sao lưu thư mục .n8n
log "Sao lưu thư mục .n8n chứa credentials..."
cp -r /home/node/.n8n/database.sqlite \$TEMP_DIR/credentials/
cp -r /home/node/.n8n/encryptionKey \$TEMP_DIR/credentials/

# Tạo file tar
log "Tạo file tar: \$BACKUP_FILE"
tar -cf \$BACKUP_FILE -C \$(dirname \$TEMP_DIR) \$(basename \$TEMP_DIR)

# Xóa thư mục tạm thời
log "Dọn dẹp thư mục tạm thời..."
rm -rf \$TEMP_DIR

# Giữ lại tối đa 30 bản sao lưu gần nhất
log "Giữ lại 30 bản sao lưu gần nhất..."
ls -t \$BACKUP_DIR/n8n_backup_*.tar | tail -n +31 | xargs -r rm

log "Sao lưu hoàn tất: \$BACKUP_FILE"
EOF

# Đặt quyền thực thi cho script sao lưu
chmod +x $N8N_DIR/backup-workflows.sh

# Đặt quyền cho thư mục n8n
echo "Đặt quyền cho thư mục n8n..."
chown -R 1000:1000 $N8N_DIR
chmod -R 755 $N8N_DIR

# Khởi động các container
echo "Khởi động các container..."
echo "Lưu ý: Quá trình build image có thể mất vài phút, vui lòng đợi..."
cd $N8N_DIR

# Sử dụng docker-compose hoặc docker compose tùy theo phiên bản
if command -v docker-compose &> /dev/null; then
    docker-compose up -d
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    docker compose up -d
else
    echo "Lỗi: Không tìm thấy lệnh docker-compose hoặc docker compose."
    exit 1
fi

# Đợi một lúc để các container có thể khởi động
echo "Đợi các container khởi động..."
sleep 15

# Kiểm tra các container đã chạy chưa
echo "Kiểm tra các container đã chạy chưa..."
if docker ps | grep -q "n8n-ffmpeg-latest" || docker ps | grep -q "n8n"; then
    echo "Container n8n đã chạy thành công."
else
    echo "Container n8n đang được khởi động, có thể mất thêm thời gian..."
    echo "Bạn có thể kiểm tra logs bằng lệnh:"
    if command -v docker-compose &> /dev/null; then
        echo "  docker-compose logs -f"
    else
        echo "  docker compose logs -f"
    fi
fi

if docker ps | grep -q "caddy:2"; then
    echo "Container caddy đã chạy thành công."
else
    echo "Container caddy đang được khởi động, có thể mất thêm thời gian..."
    echo "Bạn có thể kiểm tra logs bằng lệnh:"
    if command -v docker-compose &> /dev/null; then
        echo "  docker-compose logs -f"
    else
        echo "  docker compose logs -f"
    fi
fi

# Kiểm tra FFmpeg, yt-dlp và Puppeteer trong container n8n
echo "Kiểm tra FFmpeg, yt-dlp và Puppeteer trong container n8n..."
N8N_CONTAINER=$(docker ps -q --filter "name=n8n" 2>/dev/null)
if [ -n "$N8N_CONTAINER" ]; then
    if docker exec $N8N_CONTAINER ffmpeg -version &> /dev/null; then
        echo "FFmpeg đã được cài đặt thành công trong container n8n."
        echo "Phiên bản FFmpeg:"
        docker exec $N8N_CONTAINER ffmpeg -version | head -n 1
    else
        echo "Lưu ý: FFmpeg có thể chưa được cài đặt đúng cách trong container."
    fi

    if docker exec $N8N_CONTAINER yt-dlp --version &> /dev/null; then
        echo "yt-dlp đã được cài đặt thành công trong container n8n."
        echo "Phiên bản yt-dlp:"
        docker exec $N8N_CONTAINER yt-dlp --version
    else
        echo "Lưu ý: yt-dlp có thể chưa được cài đặt đúng cách trong container."
    fi
    
    if docker exec $N8N_CONTAINER chromium-browser --version &> /dev/null; then
        echo "Chromium đã được cài đặt thành công trong container n8n."
        echo "Phiên bản Chromium:"
        docker exec $N8N_CONTAINER chromium-browser --version
    else
        echo "Lưu ý: Chromium có thể chưa được cài đặt đúng cách trong container."
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
pip3 install -U yt-dlp

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
    
    # Cập nhật yt-dlp trong container sử dụng virtual environment
    log "Cập nhật yt-dlp trong container n8n..."
    N8N_CONTAINER=\$(docker ps -q --filter "name=n8n" 2>/dev/null)
    if [ -n "\$N8N_CONTAINER" ]; then
        docker exec -u root \$N8N_CONTAINER /opt/venv/bin/pip install -U yt-dlp
        log "yt-dlp đã được cập nhật thành công trong container"
    else
        log "Không tìm thấy container n8n đang chạy"
    fi
fi
EOF

# Đặt quyền thực thi cho script cập nhật
chmod +x $N8N_DIR/update-n8n.sh

# Tạo cron job để chạy mỗi 12 giờ
echo "Thiết lập cron job cập nhật tự động mỗi 12 giờ và sao lưu hàng ngày..."
UPDATE_CRON="0 */12 * * * $N8N_DIR/update-n8n.sh"
BACKUP_CRON="0 2 * * * $N8N_DIR/backup-workflows.sh"
(crontab -l 2>/dev/null | grep -v "update-n8n.sh\|backup-workflows.sh"; echo "$UPDATE_CRON"; echo "$BACKUP_CRON") | crontab -

echo "======================================================================"
echo "N8n đã được cài đặt và cấu hình với FFmpeg, yt-dlp, Puppeteer và SSL sử dụng Caddy."
echo "Truy cập https://${DOMAIN} để sử dụng."
echo "Các file cấu hình và dữ liệu được lưu trong $N8N_DIR"
echo ""
echo "► Tính năng tự động cập nhật đã được thiết lập:"
echo "  - Kiểm tra cập nhật mỗi 12 giờ"
echo "  - Log cập nhật được lưu tại $N8N_DIR/update.log"
echo "  - Tự động sao lưu trước khi cập nhật"
echo "  - Tự động cập nhật yt-dlp trên cả host và container"
echo ""
echo "► Tính năng sao lưu workflow và credentials:"
echo "  - Sao lưu tự động hàng ngày vào lúc 2 giờ sáng"
echo "  - File sao lưu được lưu tại $N8N_DIR/files/backup_full với tên theo thời gian"
echo "  - Giữ lại 30 bản sao lưu gần nhất"
echo "  - Log sao lưu được lưu tại $N8N_DIR/files/backup_full/backup.log"
echo ""
echo "► Thông tin về thư mục tải video:"
echo "  - Thư mục lưu video YouTube: $N8N_DIR/files/youtube_content_anylystic/"
echo ""
echo "► Thông tin về Puppeteer:"
echo "  - Chromium Browser đã được cài đặt trong container cho Puppeteer"
echo "  - n8n-nodes-puppeteer package đã được cài đặt sẵn"
echo "  - Để sử dụng nút Puppeteer trong n8n, tìm kiếm 'Puppeteer' trong bộ nút"
echo ""
echo "Lưu ý: Có thể mất vài phút để SSL được cấu hình hoàn tất."
echo "Script được chỉnh sửa từ script gốc của Nguyễn Ngọc Thiện, https://www.youtube.com/@EtoolsAICONTENT"
echo "======================================================================"
