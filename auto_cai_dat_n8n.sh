#!/bin/bash

# Hiển thị banner
echo "======================================================================"
echo "     Script cài đặt N8N với FFmpeg, yt-dlp, Puppeteer và SSL tự động  "
echo "                (Phiên bản cải tiến với Backup Telegram)             "
echo "======================================================================"

# Kiểm tra xem script có được chạy với quyền root không
if [[ $EUID -ne 0 ]]; then
   echo "Script này cần được chạy với quyền root" 
   exit 1
fi

# Hàm thiết lập swap tự động
setup_swap() {
    echo "Kiểm tra và thiết lập swap tự động..."
    
    if [ "$(swapon --show | wc -l)" -gt 0 ]; then
        SWAP_SIZE=$(free -h | grep Swap | awk '{print $2}')
        echo "Swap đã được bật với kích thước ${SWAP_SIZE}. Bỏ qua thiết lập."
        return
    fi
    
    RAM_MB=$(free -m | grep Mem | awk '{print $2}')
    
    if [ "$RAM_MB" -le 2048 ]; then
        SWAP_SIZE=$((RAM_MB * 2))
    elif [ "$RAM_MB" -gt 2048 ] && [ "$RAM_MB" -le 8192 ]; then
        SWAP_SIZE=$RAM_MB
    else
        SWAP_SIZE=4096
    fi
    
    SWAP_GB=$(( (SWAP_SIZE + 1023) / 1024 ))
    
    echo "Đang thiết lập swap với kích thước ${SWAP_GB}GB (${SWAP_SIZE}MB)..."
    
    dd if=/dev/zero of=/swapfile bs=1M count=$SWAP_SIZE status=progress
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    
    sysctl vm.swappiness=10
    sysctl vm.vfs_cache_pressure=50
    
    if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
        echo "vm.swappiness=10" >> /etc/sysctl.conf
    fi
    
    if ! grep -q "vm.vfs_cache_pressure" /etc/sysctl.conf; then
        echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
    fi
    
    echo "Đã thiết lập swap với kích thước ${SWAP_GB}GB thành công."
    echo "Swappiness đã được đặt thành 10."
    echo "Vfs_cache_pressure đã được đặt thành 50."
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
    local server_ip=$(curl -s https://api.ipify.org || echo "Không thể lấy IP server")
    if [ "$server_ip" == "Không thể lấy IP server" ]; then return 1; fi
    local domain_ip=$(dig +short $domain A)

    if [ "$domain_ip" = "$server_ip" ]; then
        return 0
    else
        return 1
    fi
}

# Hàm kiểm tra các lệnh cần thiết
check_commands() {
    for cmd in dig curl cron jq tar gzip bc docker; do
        if ! command -v $cmd &> /dev/null; then
            echo "Lệnh '$cmd' không tìm thấy. Đang cố gắng cài đặt..."
            apt-get update > /dev/null
            if [ "$cmd" == "docker" ]; then
                install_docker # Gọi hàm cài đặt docker riêng
            elif [ "$cmd" == "cron" ]; then
                apt-get install -y cron
            elif [ "$cmd" == "bc" ]; then
                apt-get install -y bc
            else
                apt-get install -y dnsutils curl jq tar gzip # bc thường có sẵn
            fi
            if ! command -v $cmd &> /dev/null; then
                 echo "Lỗi: Không thể cài đặt lệnh '$cmd'. Vui lòng cài đặt thủ công và chạy lại script."
                 exit 1
            fi
        fi
    done
}

# Thiết lập swap
setup_swap

# Hàm cài đặt Docker
install_docker() {
    if $SKIP_DOCKER && command -v docker &> /dev/null; then
        echo "Docker đã được cài đặt và bỏ qua theo yêu cầu..."
        return
    fi
    
    if command -v docker &> /dev/null; then
        echo "Docker đã được cài đặt."
    else
        echo "Cài đặt Docker..."
        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl software-properties-common
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io
    fi

    # Cài đặt Docker Compose
    if command -v docker-compose &> /dev/null || (command -v docker &> /dev/null && docker compose version &> /dev/null); then
        echo "Docker Compose (hoặc plugin) đã được cài đặt."
    else 
        echo "Cài đặt Docker Compose plugin..."
        apt-get install -y docker-compose-plugin
        if ! (docker compose version &> /dev/null); then 
            echo "Không cài được plugin, thử cài docker-compose bản cũ..." 
            apt-get install -y docker-compose 
        fi
    fi
    
    if ! command -v docker &> /dev/null; then
        echo "Lỗi: Docker chưa được cài đặt đúng cách."
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! (command -v docker &> /dev/null && docker compose version &> /dev/null); then
        echo "Lỗi: Docker Compose chưa được cài đặt đúng cách."
        exit 1
    fi

    if [ "$SUDO_USER" != "" ]; then
        echo "Thêm user $SUDO_USER vào nhóm docker..."
        usermod -aG docker $SUDO_USER
        echo "Đã thêm. Thay đổi có hiệu lực sau khi đăng nhập lại hoặc chạy 'newgrp docker'."
    fi
    systemctl enable docker
    systemctl restart docker
    echo "Docker và Docker Compose đã được cài đặt/kiểm tra thành công."
}

# Cài đặt các gói cần thiết (trừ Docker đã xử lý ở check_commands)
echo "Đang kiểm tra và cài đặt các công cụ cần thiết..."
apt-get update > /dev/null
apt-get install -y dnsutils curl cron jq tar gzip python3-full python3-venv pipx net-tools bc

# Cài đặt yt-dlp
echo "Cài đặt yt-dlp..."
if command -v pipx &> /dev/null; then
    pipx install yt-dlp
    pipx ensurepath
else
    python3 -m venv /opt/yt-dlp-venv
    /opt/yt-dlp-venv/bin/pip install -U pip yt-dlp
    ln -sf /opt/yt-dlp-venv/bin/yt-dlp /usr/local/bin/yt-dlp
    chmod +x /usr/local/bin/yt-dlp
fi
export PATH="$PATH:/usr/local/bin:/opt/yt-dlp-venv/bin:$HOME/.local/bin" # Đảm bảo yt-dlp trong PATH

# Đảm bảo cron service đang chạy
systemctl enable cron
systemctl start cron

# Kiểm tra các lệnh (bao gồm Docker)
check_commands

# Nhận input domain từ người dùng
read -p "Nhập tên miền hoặc tên miền phụ của bạn (ví dụ: n8n.example.com): " DOMAIN
while ! check_domain $DOMAIN; do
    echo "Domain $DOMAIN chưa được trỏ đúng đến IP server này ($(curl -s https://api.ipify.org))."
    echo "Vui lòng cập nhật bản ghi DNS để trỏ $DOMAIN đến IP $(curl -s https://api.ipify.org)." 
    read -p "Nhấn Enter sau khi cập nhật DNS, hoặc nhập domain khác: " NEW_DOMAIN
    if [ -n "$NEW_DOMAIN" ]; then
        DOMAIN="$NEW_DOMAIN"
    fi
done
echo "Domain $DOMAIN đã được trỏ đúng. Tiếp tục cài đặt."

# Tạo thư mục cho n8n
echo "Tạo cấu trúc thư mục cho n8n tại $N8N_DIR..."
mkdir -p $N8N_DIR
mkdir -p $N8N_DIR/files
mkdir -p $N8N_DIR/files/temp
mkdir -p $N8N_DIR/files/youtube_content_anylystic
mkdir -p $N8N_DIR/files/backup_full

# Tạo Dockerfile
echo "Tạo Dockerfile..."
cat << 'EOF' > $N8N_DIR/Dockerfile
FROM n8nio/n8n:latest
USER root
RUN apk update && \
    apk add --no-cache ffmpeg wget zip unzip python3 py3-pip jq tar gzip \
    chromium nss freetype freetype-dev harfbuzz ca-certificates ttf-freefont \
    font-noto font-noto-cjk font-noto-emoji dbus udev
RUN pip3 install --break-system-packages -U yt-dlp && \
    chmod +x /usr/bin/yt-dlp
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
WORKDIR /usr/local/lib/node_modules/n8n
RUN npm install n8n-nodes-puppeteer
RUN mkdir -p /files/youtube_content_anylystic /files/backup_full /files/temp && \
    chown -R node:node /files
USER node
WORKDIR /home/node
EOF

# Tạo file docker-compose.yml
echo "Tạo file docker-compose.yml..."
cat << EOF > $N8N_DIR/docker-compose.yml
services:
  n8n:
    build:
      context: .
      dockerfile: Dockerfile
    image: n8n-custom-ffmpeg:latest
    restart: always
    ports:
      - "127.0.0.1:5678:5678"
    environment:
      - N8N_HOST=${DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://${DOMAIN}
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
      - N8N_DEFAULT_BINARY_DATA_MODE=filesystem
      - N8N_BINARY_DATA_STORAGE=/files
      - N8N_DEFAULT_BINARY_DATA_FILESYSTEM_DIRECTORY=/files
      - N8N_DEFAULT_BINARY_DATA_TEMP_DIRECTORY=/files/temp
      - NODE_FUNCTION_ALLOW_BUILTIN=child_process,path,fs,util,os
      - N8N_EXECUTIONS_DATA_MAX_SIZE=304857600 # 300MB
      - PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
      - PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
    volumes:
      - ${N8N_DIR}:/home/node/.n8n  # Mount toàn bộ thư mục N8N_DIR vào /home/node/.n8n
      - ${N8N_DIR}/files:/files      # Mount thư mục files vào /files trong container
    user: "node"
    cap_add:
      - SYS_ADMIN

  caddy:
    image: caddy:latest
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
    tls internal # Hoặc email của bạn: tls your-email@example.com
}
EOF

# Cấu hình gửi backup qua Telegram
TELEGRAM_CONF_FILE="$N8N_DIR/telegram_backup.conf"
read -p "Bạn có muốn cấu hình gửi file backup hàng ngày qua Telegram không? (y/n): " CONFIGURE_TELEGRAM
if [[ "$CONFIGURE_TELEGRAM" =~ ^[Yy]$ ]]; then
    echo "Để gửi backup qua Telegram, bạn cần một Bot Token và Chat ID."
    echo "Hướng dẫn lấy Bot Token: Nói chuyện với BotFather trên Telegram (tìm @BotFather), gõ /newbot, làm theo hướng dẫn."
    echo "Hướng dẫn lấy Chat ID: Nói chuyện với bot @userinfobot trên Telegram, nó sẽ hiển thị User ID của bạn."
    echo "Nếu muốn gửi vào group, thêm bot của bạn vào group, sau đó gửi lệnh /my_id @TenBotCuaBan trong group đó (thay @TenBotCuaBan bằng username bot của bạn)." 
    echo "Chat ID của group sẽ bắt đầu bằng dấu trừ (-)."
    read -p "Nhập Telegram Bot Token của bạn: " TELEGRAM_BOT_TOKEN
    read -p "Nhập Telegram Chat ID của bạn (hoặc group ID): " TELEGRAM_CHAT_ID
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        echo "TELEGRAM_BOT_TOKEN=\"$TELEGRAM_BOT_TOKEN\"" > "$TELEGRAM_CONF_FILE"
        echo "TELEGRAM_CHAT_ID=\"$TELEGRAM_CHAT_ID\"" >> "$TELEGRAM_CONF_FILE"
        chmod 600 "$TELEGRAM_CONF_FILE"
        echo "Đã lưu cấu hình Telegram vào $TELEGRAM_CONF_FILE"
    else
        echo "Bot Token hoặc Chat ID không được cung cấp. Bỏ qua cấu hình Telegram."
    fi
elif [[ "$CONFIGURE_TELEGRAM" =~ ^[Nn]$ ]]; then
    echo "Đã bỏ qua cấu hình gửi backup qua Telegram."
    if [ -f "$TELEGRAM_CONF_FILE" ]; then # Xóa file conf cũ nếu người dùng chọn không
        rm -f "$TELEGRAM_CONF_FILE"
    fi
else
    echo "Lựa chọn không hợp lệ. Mặc định bỏ qua cấu hình Telegram."
fi

# Tạo script sao lưu workflow và credentials
echo "Tạo script sao lưu workflow và credentials tại $N8N_DIR/backup-workflows.sh..."
cat << EOF > $N8N_DIR/backup-workflows.sh
#!/bin/bash

N8N_DIR_VALUE="$N8N_DIR"
BACKUP_BASE_DIR="\\\${N8N_DIR_VALUE}/files/backup_full"
LOG_FILE="\\\
ogens_DIR_VALUE}/files/backup_full/backup.log"
TELEGRAM_CONF_FILE="\\\
ogens_DIR_VALUE}/telegram_backup.conf"
DATE=\\"$(date +"%Y%m%d_%H%M%S")\"
BACKUP_FILE_NAME="n8n_backup_\\\
ogens_DATE.tar.gz"
BACKUP_FILE_PATH="\\\
ogens_BACKUP_BASE_DIR/\\\
ogens_BACKUP_FILE_NAME"
TEMP_DIR_HOST="/tmp/n8n_backup_host_\\\
ogens_DATE"
TEMP_DIR_CONTAINER_BASE="/tmp/n8n_workflow_exports"

TELEGRAM_FILE_SIZE_LIMIT=20971520 # 20MB

log() {
    echo "[\\\$(date '+%Y-%m-%d %H:%M:%S')] \\\
ogens1" | tee -a "\\\
ogens_LOG_FILE"
}

send_telegram_message() {
    local message="\\\
ogens1"
    if [ -f "\\\
ogens_TELEGRAM_CONF_FILE" ]; then
        source "\\\
ogens_TELEGRAM_CONF_FILE"
        if [ -n "\\\
ogens_TELEGRAM_BOT_TOKEN" ] && [ -n "\\\
ogens_TELEGRAM_CHAT_ID" ]; then
            (curl -s -X POST "https://api.telegram.org/bot\\\
ogens_TELEGRAM_BOT_TOKEN/sendMessage" \
                -d chat_id="\\\
ogens_TELEGRAM_CHAT_ID" \
                -d text="\\\
ogensmessage" \
                -d parse_mode="Markdown" > /dev/null 2>&1) &
        fi
    fi
}

send_telegram_document() {
    local file_path="\\\
ogens1"
    local caption="\\\
ogens2"
    if [ -f "\\\
ogens_TELEGRAM_CONF_FILE" ]; then
        source "\\\
ogens_TELEGRAM_CONF_FILE"
        if [ -n "\\\
ogens_TELEGRAM_BOT_TOKEN" ] && [ -n "\\\
ogens_TELEGRAM_CHAT_ID" ]; then
            local file_size=\\\"$(du -b "\\\
ogensfile_path" | cut -f1)\\\"
            if [ "\\\
ogensfile_size" -le "\\\
ogens_TELEGRAM_FILE_SIZE_LIMIT" ]; then
                log "Đang gửi file backup qua Telegram: \\\
ogens{file_path}"
                (curl -s -X POST "https://api.telegram.org/bot\\\
ogens_TELEGRAM_BOT_TOKEN/sendDocument" \
                    -F chat_id="\\\
ogens_TELEGRAM_CHAT_ID" \
                    -F document=@"\\\
ogensfile_path" \
                    -F caption="\\\
ogenscaption" > /dev/null 2>&1) &
            else
                local readable_size=\\\"$(echo "scale=2; \\\
ogensfile_size / 1024 / 1024" | bc)\\\"
                log "File backup quá lớn (\\\
ogens{readable_size} MB) để gửi qua Telegram. Sẽ chỉ gửi thông báo."
                send_telegram_message "Hoàn tất sao lưu N8N. File backup '\\\
ogens_BACKUP_FILE_NAME' (\\\
ogens{readable_size}MB) quá lớn để gửi. Nó được lưu tại: \\\
ogens{file_path} trên server."
            fi
        fi
    fi
}

mkdir -p "\\\
ogens_BACKUP_BASE_DIR"
log "Bắt đầu sao lưu workflows và credentials..."
send_telegram_message "Bắt đầu quá trình sao lưu N8N hàng ngày cho domain: $DOMAIN..."

N8N_CONTAINER_NAME_PATTERN="n8n"
N8N_CONTAINER_ID=\\\"$(docker ps -q --filter "name=\\
ogens_N8N_CONTAINER_NAME_PATTERN" --format '{{.ID}}' | head -n 1)\\\"

if [ -z "\\\
ogens_N8N_CONTAINER_ID" ]; then
    log "Lỗi: Không tìm thấy container n8n đang chạy."
    send_telegram_message "Lỗi sao lưu N8N ($DOMAIN): Không tìm thấy container n8n đang chạy."
    exit 1
fi
log "Tìm thấy container N8N ID: \\\
ogens_N8N_CONTAINER_ID"

mkdir -p "\\\
ogens_TEMP_DIR_HOST/workflows"
mkdir -p "\\\
ogens_TEMP_DIR_HOST/credentials"

# Tạo thư mục export tạm thời bên trong container (đảm bảo nó là duy nhất cho lần chạy này)
TEMP_DIR_CONTAINER_UNIQUE="\\\
ogens_TEMP_DIR_CONTAINER_BASE/export_\\\
ogens_DATE"
docker exec "\\\
ogens_N8N_CONTAINER_ID" mkdir -p "\\\
ogens_TEMP_DIR_CONTAINER_UNIQUE"

log "Xuất workflows vào \\\
ogens_TEMP_DIR_CONTAINER_UNIQUE trong container..." 
WORKFLOWS_JSON=\\\"$(docker exec "\\\
ogens_N8N_CONTAINER_ID" n8n list:workflow --json)\\\"

if [ -z "\\\
ogens_WORKFLOWS_JSON" ] || [ "\\\
ogens_WORKFLOWS_JSON" == "[]" ]; then
    log "Cảnh báo: Không tìm thấy workflow nào để sao lưu."
else
    echo "\\\
ogens_WORKFLOWS_JSON" | jq -c '.[]' | while IFS= read -r workflow; do
        id=\\\"$(echo "\\\
ogensworkflow" | jq -r '.id')\\\"
        name=\\\"$(echo "\\\
ogensworkflow" | jq -r '.name' | tr -dc '[:alnum:][:space:]_-' | tr '[:space:]' '_')\\\"
        safe_name=\\\"$(echo "\\\
ogensname" | sed 's/[^a-zA-Z0-9_-]/_/g' | cut -c1-100)\\\"
        output_file_container="\\\
ogens_TEMP_DIR_CONTAINER_UNIQUE/\\\
ogensid-\\
ogenssafe_name.json"
        log "Đang xuất workflow: '\\\
ogensname' (ID: \\\
ogensid) vào container: \\\
ogensoutput_file_container"
        if docker exec "\\\
ogens_N8N_CONTAINER_ID" n8n export:workflow --id="\\\
ogensid" --output="\\\
ogensoutput_file_container"; then
            log "Đã xuất workflow ID \\\
ogensid thành công."
        else
            log "Lỗi khi xuất workflow ID \\\
ogensid."
        fi
    done

    log "Sao chép workflows từ container \\\
ogens_N8N_CONTAINER_ID:\\\
ogens_TEMP_DIR_CONTAINER_UNIQUE vào host \\\
ogens_TEMP_DIR_HOST/workflows"
    if docker cp "\\\
ogens_N8N_CONTAINER_ID:\\\
ogens_TEMP_DIR_CONTAINER_UNIQUE/." "\\\
ogens_TEMP_DIR_HOST/workflows/"; then
        log "Sao chép workflows từ container ra host thành công."
    else
        log "Lỗi khi sao chép workflows từ container ra host."
    fi
fi

DB_PATH_HOST="\\\
ogens_N8N_DIR_VALUE/database.sqlite"
KEY_PATH_HOST="\\\
ogens_N8N_DIR_VALUE/encryptionKey"

log "Sao lưu database và encryption key từ host..."
if [ -f "\\\
ogens_DB_PATH_HOST" ]; then
    cp "\\\
ogens_DB_PATH_HOST" "\\\
ogens_TEMP_DIR_HOST/credentials/database.sqlite"
    log "Đã sao lưu database.sqlite"
else
    log "Lỗi: Không tìm thấy file database.sqlite tại \\\
ogens_DB_PATH_HOST"
fi

if [ -f "\\\
ogens_KEY_PATH_HOST" ]; then
    cp "\\\
ogens_KEY_PATH_HOST" "\\\
ogens_TEMP_DIR_HOST/credentials/encryptionKey"
    log "Đã sao lưu encryptionKey"
else
    log "Lỗi: Không tìm thấy file encryptionKey tại \\\
ogens_KEY_PATH_HOST"
fi

log "Tạo file nén tar.gz: \\\
ogens_BACKUP_FILE_PATH"
if tar -czf "\\\
ogens_BACKUP_FILE_PATH" -C "\\\
ogens_TEMP_DIR_HOST" . ; then
    log "Tạo file backup \\\
ogens_BACKUP_FILE_PATH thành công."
    send_telegram_document "\\\
ogens_BACKUP_FILE_PATH" "Sao lưu N8N ($DOMAIN) hàng ngày hoàn tất: \\\
ogens_BACKUP_FILE_NAME"
else
    log "Lỗi: Không thể tạo file backup \\\
ogens_BACKUP_FILE_PATH."
    send_telegram_message "Lỗi sao lưu N8N ($DOMAIN): Không thể tạo file backup. Kiểm tra log tại \\\
ogens_LOG_FILE"
fi

log "Dọn dẹp thư mục tạm..."
rm -rf "\\\
ogens_TEMP_DIR_HOST"
docker exec "\\\
ogens_N8N_CONTAINER_ID" rm -rf "\\\
ogens_TEMP_DIR_CONTAINER_UNIQUE"

log "Giữ lại 30 bản sao lưu gần nhất trong \\\
ogens_BACKUP_BASE_DIR..."
find "\\\
ogens_BACKUP_BASE_DIR" -maxdepth 1 -name 'n8n_backup_*.tar.gz' -type f -printf '%T@ %p\\n' | \
sort -nr | tail -n +31 | cut -d' ' -f2- | xargs -r rm -f

log "Sao lưu hoàn tất: \\\
ogens_BACKUP_FILE_PATH"
if [ -f "\\\
ogens_BACKUP_FILE_PATH" ]; then
    send_telegram_message "Hoàn tất sao lưu N8N ($DOMAIN). File: \\\
ogens_BACKUP_FILE_NAME. Log: \\\
ogens_LOG_FILE"
else
    send_telegram_message "Sao lưu N8N ($DOMAIN) thất bại. Kiểm tra log tại \\\
ogens_LOG_FILE"
fi

exit 0
EOF

# Đặt quyền thực thi cho script sao lưu
chmod +x $N8N_DIR/backup-workflows.sh

# Đặt quyền cho thư mục n8n (đảm bảo user node (1000) có thể ghi vào .n8n và files)
# User `node` trong container n8nio/n8n thường có UID 1000.
# Nếu thư mục $N8N_DIR được tạo bởi root, cần chown cho user sẽ chạy n8n (thường là 1000)
# Hoặc, nếu docker-compose chạy n8n với user: "node", docker sẽ tự xử lý quyền trong volume.
# Tuy nhiên, để script backup (chạy bởi root qua cron) có thể đọc $N8N_DIR/database.sqlite, quyền phải phù hợp.
# $N8N_DIR nên thuộc root, nhưng $N8N_DIR/database.sqlite và $N8N_DIR/encryptionKey phải đọc được bởi root.
# Và container n8n (user node) phải ghi được vào $N8N_DIR (là /home/node/.n8n trong container).
# Cách đơn giản nhất là chown $N8N_DIR cho user 1000 (node) nếu nó được mount vào /home/node/.n8n
echo "Đặt quyền cho thư mục n8n tại $N8N_DIR..."
# Đảm bảo thư mục gốc $N8N_DIR tồn tại và có quyền phù hợp cho Docker mount
sudo chown -R 1000:1000 $N8N_DIR 
sudo chmod -R u+rwX,g+rX,o+rX $N8N_DIR
# Thư mục files cũng cần quyền tương tự nếu n8n ghi vào đó
sudo chown -R 1000:1000 $N8N_DIR/files
sudo chmod -R u+rwX,g+rX,o+rX $N8N_DIR/files

# Khởi động các container
echo "Khởi động các container... Quá trình build image có thể mất vài phút..."
cd $N8N_DIR

# Xác định lệnh docker-compose
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    echo "Lỗi: Không tìm thấy lệnh docker-compose hoặc docker compose plugin."
    exit 1
fi

# Build và khởi động
if ! $DOCKER_COMPOSE_CMD build; then
    echo "Lỗi: Build Docker image thất bại."
    exit 1
fi
if ! $DOCKER_COMPOSE_CMD up -d; then
    echo "Lỗi: Khởi động container thất bại."
    exit 1
fi

echo "Đợi các container khởi động (30 giây)..."
sleep 30

# Kiểm tra các container đã chạy chưa
echo "Kiểm tra trạng thái các container..."
if $DOCKER_COMPOSE_CMD ps | grep -q "n8n"; then # Kiểm tra tên service trong docker-compose
    echo "Container n8n đã chạy thành công."
else
    echo "Cảnh báo: Container n8n có thể chưa chạy. Kiểm tra logs: $DOCKER_COMPOSE_CMD logs n8n"
fi
if $DOCKER_COMPOSE_CMD ps | grep -q "caddy"; then
    echo "Container caddy đã chạy thành công."
else
    echo "Cảnh báo: Container caddy có thể chưa chạy. Kiểm tra logs: $DOCKER_COMPOSE_CMD logs caddy"
fi

# Tạo script cập nhật tự động (giữ nguyên từ script gốc)
echo "Tạo script cập nhật tự động tại $N8N_DIR/update-n8n.sh..."
cat << EOF > $N8N_DIR/update-n8n.sh
#!/bin/bash
N8N_DIR_VALUE="$N8N_DIR"
LOG_FILE="\\\
ogens_N8N_DIR_VALUE/update.log"
log() { echo "[\\\$(date '+%Y-%m-%d %H:%M:%S')] \\\
ogens1" >> "\\\
ogens_LOG_FILE"; }
log "Bắt đầu kiểm tra cập nhật..."
cd "\\\
ogens_N8N_DIR_VALUE"
if command -v docker-compose &> /dev/null; then DOCKER_COMPOSE="docker-compose"; elif command -v docker &> /dev/null && docker compose version &> /dev/null; then DOCKER_COMPOSE="docker compose"; else log "Lỗi: Docker Compose không tìm thấy."; exit 1; fi
log "Cập nhật yt-dlp trên host..."
if command -v pipx &> /dev/null; then pipx upgrade yt-dlp; elif [ -d "/opt/yt-dlp-venv" ]; then /opt/yt-dlp-venv/bin/pip install -U yt-dlp; fi
log "Kéo image n8nio/n8n mới nhất..."
docker pull n8nio/n8n:latest
CURRENT_CUSTOM_IMAGE_ID=\\\"$(\\$DOCKER_COMPOSE images -q n8n)\\\"
log "Build lại image custom n8n..."
if ! \\$DOCKER_COMPOSE build n8n; then log "Lỗi build image custom."; exit 1; fi
NEW_CUSTOM_IMAGE_ID=\\\"$(\\$DOCKER_COMPOSE images -q n8n)\\\"
if [ "\\\
ogens_CURRENT_CUSTOM_IMAGE_ID" != "\\\
ogens_NEW_CUSTOM_IMAGE_ID" ]; then
    log "Phát hiện image mới, tiến hành cập nhật n8n..."
    # Chạy backup trước khi cập nhật
    log "Chạy backup trước khi cập nhật..."
    if [ -x "\\\
ogens_N8N_DIR_VALUE/backup-workflows.sh" ]; then
        "\\\
ogens_N8N_DIR_VALUE/backup-workflows.sh"
    else
        log "Không tìm thấy script backup-workflows.sh hoặc không có quyền thực thi."
    fi
    log "Dừng và khởi động lại container n8n..."
    \\$DOCKER_COMPOSE down
    \\$DOCKER_COMPOSE up -d n8n caddy # Đảm bảo caddy cũng được khởi động lại nếu cần
    log "Cập nhật n8n hoàn tất."
else
    log "Không có cập nhật mới cho image n8n custom."
fi
log "Cập nhật yt-dlp trong container n8n..."
N8N_CONTAINER_FOR_UPDATE=\\\"$(\\$DOCKER_COMPOSE ps -q n8n)\\\"
if [ -n "\\\
ogens_N8N_CONTAINER_FOR_UPDATE" ]; then
    docker exec -u root "\\\
ogens_N8N_CONTAINER_FOR_UPDATE" pip3 install --break-system-packages -U yt-dlp
    log "yt-dlp trong container đã được cập nhật."
else
    log "Không tìm thấy container n8n đang chạy để cập nhật yt-dlp."
fi
log "Kiểm tra cập nhật hoàn tất."
EOF
chmod +x $N8N_DIR/update-n8n.sh

# Thiết lập cron job
CRON_USER=$(whoami) # Chạy cron với user hiện tại (root)
UPDATE_CRON="0 */12 * * * $N8N_DIR/update-n8n.sh"
BACKUP_CRON="0 2 * * * $N8N_DIR/backup-workflows.sh"
(crontab -u $CRON_USER -l 2>/dev/null | grep -v "update-n8n.sh" | grep -v "backup-workflows.sh"; echo "$UPDATE_CRON"; echo "$BACKUP_CRON") | crontab -u $CRON_USER -
echo "Đã thiết lập cron job cập nhật tự động mỗi 12 giờ và sao lưu hàng ngày lúc 2 giờ sáng."

echo "======================================================================"
echo "N8n đã được cài đặt và cấu hình với FFmpeg, yt-dlp, Puppeteer và SSL."
echo "Truy cập https://${DOMAIN} để sử dụng."

if [ "$(swapon --show | wc -l)" -gt 0 ]; then
    SWAP_INFO=$(free -h | grep Swap | awk '{print $2}')
    echo "► Swap đã được thiết lập: $SWAP_INFO"
fi
echo "Các file cấu hình và dữ liệu được lưu trong $N8N_DIR"
echo "► Tính năng tự động cập nhật: Kiểm tra mỗi 12 giờ. Log: $N8N_DIR/update.log"
echo "► Tính năng sao lưu workflow và credentials:"
echo "  - Sao lưu tự động hàng ngày vào lúc 2 giờ sáng."
necho "  - File sao lưu: $N8N_DIR/files/backup_full/n8n_backup_YYYYMMDD_HHMMSS.tar.gz"
echo "  - Giữ lại 30 bản sao lưu gần nhất."
echo "  - Log sao lưu: $N8N_DIR/files/backup_full/backup.log"
if [ -f "$TELEGRAM_CONF_FILE" ]; then
    echo "  - Thông báo và file backup (nếu <20MB) sẽ được gửi qua Telegram."
    echo "  - Cấu hình Telegram: $TELEGRAM_CONF_FILE"
fi
echo "► Thư mục tải video YouTube: $N8N_DIR/files/youtube_content_anylystic/"
echo "► Puppeteer đã được cài đặt trong container."
echo "======================================================================"
