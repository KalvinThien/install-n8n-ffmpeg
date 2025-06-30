#!/bin/bash

# =============================================================================
# 🚀 SCRIPT CÀI ĐẶT N8N TỰ ĐỘNG 2025 - PHIÊN BẢN HOÀN CHỈNH V4.1
# =============================================================================
# Tác giả: Nguyễn Ngọc Thiện
# YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1
# Playlist N8N: https://www.youtube.com/@kalvinthiensocial/playlists
# Facebook: @https://www.facebook.com/Ban.Thien.Handsome/
# Zalo: 08.8888.4749
# Cập nhật: 30/06/2025
#
# ✨ TÍNH NĂNG MỚI V4.1 
#   - 🔧 Sửa lỗi ChromeDriver với Chrome for Testing API mới
#   - 🛡️ Khắc phục lỗi anti-bot protection (Sucuri/Cloudflare) cho News API
#   - 🤖 Tích hợp Selenium WebDriver với stealth mode
#   - 🔄 Cải thiện User Agent rotation và session handling 
#   - 🎭 Thêm browser fingerprint randomization
#   - 📱 Hỗ trợ mobile user agents cho trang tin tức Việt Nam
#   - ⚡ Tối ưu performance với connection pooling
#   - 🚧 Fallback method cho ChromeDriver installation

# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Global variables
INSTALL_DIR="/home/n8n"
DOMAIN=""
API_DOMAIN=""
BEARER_TOKEN=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
RCLONE_REMOTE_NAME="gdrive_n8n"
GDRIVE_BACKUP_FOLDER="n8n_backups"
ENABLE_NEWS_API=false
ENABLE_TELEGRAM=false
ENABLE_GDRIVE_BACKUP=false
ENABLE_AUTO_UPDATE=false
CLEAN_INSTALL=false
SKIP_DOCKER=false
LOCAL_MODE=false
RESTORE_MODE=false
RESTORE_SOURCE=""
RESTORE_FILE_PATH=""

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}              🚀 SCRIPT CÀI ĐẶT N8N TỰ ĐỘNG 2025 - V4.1 HOÀN CHỈNH 🚀         ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE} ✨ N8N + FFmpeg + yt-dlp + Puppeteer + News API + Telegram/G-Drive Backup ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} ☁️ Backup & Restore qua Google Drive (rclone)                             ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 🔄 Tùy chọn Restore dữ liệu ngay khi cài đặt                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 🐞 Sửa lỗi phân tích SSL Rate Limit, hiển thị giờ VN (GMT+7)              ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 🔑 Gỡ bỏ giới hạn Bearer Token (độ dài, ký tự đặc biệt)                   ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${YELLOW} 👨‍💻 Tác giả: Nguyễn Ngọc Thiện (Original) & v0 (Upgraded)                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW} 📺 YouTube: https://www.youtube.com/@kalvinthiensocial                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW} 📱 Zalo: 08.8888.4749                                                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW} 🎬 Đăng ký kênh để ủng hộ mình nhé! 🔔                                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW} 📅 Cập nhật: 30/06/2025                                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

show_help() {
    echo "Sử dụng: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help          Hiển thị trợ giúp này"
    echo "  -d, --dir DIR       Thư mục cài đặt (mặc định: /home/n8n)"
    echo "  -c, --clean         Xóa cài đặt cũ trước khi cài mới"
    echo "  -s, --skip-docker   Bỏ qua cài đặt Docker (nếu đã có)"
    echo "  -l, --local         Cài đặt Local Mode (không cần domain)"
    echo ""
    echo "Ví dụ:"
    echo "  $0                  # Cài đặt bình thường với domain"
    echo "  $0 --local         # Cài đặt Local Mode"
    echo "  $0 --clean         # Xóa cài đặt cũ và cài mới"
    echo "  $0 -d /opt/n8n     # Cài đặt vào thư mục /opt/n8n"
    echo ""
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            -c|--clean)
                CLEAN_INSTALL=true
                shift
                ;;
            -s|--skip-docker)
                SKIP_DOCKER=true
                shift
                ;;
            -l|--local)
                LOCAL_MODE=true
                shift
                ;;
            *)
                error "Tham số không hợp lệ: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# =============================================================================
# SYSTEM CHECKS
# =============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Script này cần chạy với quyền root. Sử dụng: sudo $0"
        exit 1
    fi
}

check_os() {
    if [[ ! -f /etc/os-release ]]; then
        error "Không thể xác định hệ điều hành"
        exit 1
    fi
    
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        warning "Script được thiết kế cho Ubuntu. Hệ điều hành hiện tại: $ID"
        read -p "Bạn có muốn tiếp tục? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

detect_environment() {
    if grep -q Microsoft /proc/version 2>/dev/null; then
        info "Phát hiện môi trường WSL"
        export WSL_ENV=true
    else
        export WSL_ENV=false
    fi
}

check_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        export DOCKER_COMPOSE="docker-compose"
        info "Sử dụng docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        export DOCKER_COMPOSE="docker compose"
        info "Sử dụng docker compose"
    else
        export DOCKER_COMPOSE=""
    fi
}

# =============================================================================
# SWAP MANAGEMENT
# =============================================================================

setup_swap() {
    log "🔄 Thiết lập swap memory..."
    
    # Get total RAM in GB
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local swap_size
    
    # Calculate swap size based on RAM
    if [[ $ram_gb -le 2 ]]; then
        swap_size="2G"
    elif [[ $ram_gb -le 4 ]]; then
        swap_size="4G"
    else
        swap_size="4G"
    fi
    
    # Check if swap already exists
    if swapon --show | grep -q "/swapfile"; then
        info "Swap file đã tồn tại"
        return 0
    fi
    
    # Create swap file
    log "Tạo swap file ${swap_size}..."
    fallocate -l $swap_size /swapfile || dd if=/dev/zero of=/swapfile bs=1024 count=$((${swap_size%G} * 1024 * 1024))
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    
    # Make swap permanent
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
    fi
    
    success "Đã thiết lập swap ${swap_size}"
}

# =============================================================================
# RCLONE & RESTORE FUNCTIONS
# =============================================================================

install_rclone() {
    if command -v rclone &> /dev/null; then
        info "rclone đã được cài đặt."
        return 0
    fi
    log "📦 Cài đặt rclone..."
    apt-get update && apt-get install -y unzip
    curl https://rclone.org/install.sh | sudo bash
    success "Đã cài đặt rclone thành công."
}

setup_rclone_config() {
    if rclone listremotes | grep -q "^${RCLONE_REMOTE_NAME}:"; then
        info "Cấu hình rclone remote '${RCLONE_REMOTE_NAME}' đã tồn tại."
        return 0
    fi

    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${WHITE}             ⚙️ HƯỚNG DẪN CẤU HÌNH RCLONE VỚI GOOGLE DRIVE ⚙️             ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo "Bạn cần thực hiện vài bước để kết nối script với tài khoản Google Drive của bạn."
    echo "Script sẽ mở trình cấu hình của rclone. Vui lòng làm theo các bước sau:"
    echo ""
    echo -e "1. Chạy lệnh sau: ${CYAN}rclone config${NC}"
    echo "2. Nhấn ${WHITE}n${NC} (New remote)"
    echo -e "3. Đặt tên remote: ${WHITE}${RCLONE_REMOTE_NAME}${NC} (QUAN TRỌNG: phải nhập chính xác tên này)"
    echo "4. Chọn loại storage, tìm và nhập số tương ứng với ${WHITE}drive${NC} (Google Drive)"
    echo "5. Để trống ${WHITE}client_id${NC} và ${WHITE}client_secret${NC} (nhấn Enter)"
    echo "6. Chọn scope, nhập ${WHITE}1${NC} (Full access)"
    echo "7. Để trống ${WHITE}root_folder_id${NC} và ${WHITE}service_account_file${NC} (nhấn Enter)"
    echo "8. Trả lời ${WHITE}n${NC} cho 'Edit advanced config?'"
    echo "9. Trả lời ${WHITE}n${NC} cho 'Use auto config?' (QUAN TRỌNG: nếu bạn đang SSH)"
    echo "10. rclone sẽ hiện 1 link. ${RED}Copy link này và mở trên trình duyệt máy tính của bạn.${NC}"
    echo "11. Đăng nhập tài khoản Google và cho phép rclone truy cập."
    echo "12. Google sẽ trả về 1 mã xác thực. ${RED}Copy mã này và paste lại vào terminal.${NC}"
    echo "13. Trả lời ${WHITE}n${NC} cho 'Configure this as a team drive?'"
    echo "14. Xác nhận bằng cách nhấn ${WHITE}y${NC} (Yes this is OK)"
    echo "15. Nhấn ${WHITE}q${NC} (Quit config) để thoát."
    echo ""
    read -p "Nhấn Enter khi bạn đã sẵn sàng để bắt đầu cấu hình rclone..."

    rclone config

    if ! rclone listremotes | grep -q "^${RCLONE_REMOTE_NAME}:"; then
        error "Cấu hình rclone remote '${RCLONE_REMOTE_NAME}' không thành công. Vui lòng thử lại."
        exit 1
    fi
    success "Đã cấu hình rclone remote '${RCLONE_REMOTE_NAME}' thành công!"
}

get_restore_option() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        🔄 TÙY CHỌN RESTORE DỮ LIỆU                          ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    read -p "🔄 Bạn có muốn khôi phục dữ liệu từ một bản backup có sẵn không? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        RESTORE_MODE=false
        return 0
    fi

    RESTORE_MODE=true
    echo "Chọn nguồn khôi phục:"
    echo -e "  ${GREEN}1. Từ file backup local (.tar.gz)${NC}"
    echo -e "  ${GREEN}2. Từ Google Drive (yêu cầu cấu hình rclone)${NC}"
    read -p "Lựa chọn của bạn [1]: " source_choice

    if [[ "$source_choice" == "2" ]]; then
        RESTORE_SOURCE="gdrive"
        install_rclone
        setup_rclone_config
        
        read -p "📝 Nhập tên thư mục trên Google Drive chứa backup [n8n_backups]: " GDRIVE_FOLDER_INPUT
        if [[ -n "$GDRIVE_FOLDER_INPUT" ]]; then GDRIVE_BACKUP_FOLDER="$GDRIVE_FOLDER_INPUT"; fi

        log "🔍 Lấy danh sách backup từ Google Drive..."
        mapfile -t backups < <(rclone lsf "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER" --include "*.tar.gz" | sort -r)
        if [ ${#backups[@]} -eq 0 ]; then
            error "Không tìm thấy file backup nào trên Google Drive trong thư mục '$GDRIVE_BACKUP_FOLDER'."
            exit 1
        fi

        echo "Chọn file backup để khôi phục:"
        for i in "${!backups[@]}"; do
            echo "  $((i+1)). ${backups[$i]}"
        done
        read -p "Nhập số thứ tự file backup: " file_idx
        
        selected_backup="${backups[$((file_idx-1))]}"
        if [[ -z "$selected_backup" ]]; then
            error "Lựa chọn không hợp lệ."
            exit 1
        fi

        log "📥 Tải file backup '$selected_backup'..."
        mkdir -p /tmp/n8n_restore
        rclone copyto "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER/$selected_backup" "/tmp/n8n_restore/$selected_backup" --progress
        RESTORE_FILE_PATH="/tmp/n8n_restore/$selected_backup"
        success "Đã tải file backup thành công."

    else
        RESTORE_SOURCE="local"
        while true; do
            read -p "📁 Nhập đường dẫn đầy đủ đến file backup (.tar.gz): " RESTORE_FILE_PATH
            if [[ -f "$RESTORE_FILE_PATH" ]]; then
                break
            else
                error "File không tồn tại. Vui lòng kiểm tra lại đường dẫn."
            fi
        done
    fi
}

perform_restore() {
    if [[ "$RESTORE_MODE" != "true" ]]; then return 0; fi
    
    log "🔄 Bắt đầu quá trình khôi phục từ file: $RESTORE_FILE_PATH"
    
    # Ensure target directory exists
    mkdir -p "$INSTALL_DIR/files"
    
    # Clean target directory
    log "🧹 Dọn dẹp thư mục dữ liệu cũ..."
    rm -rf "$INSTALL_DIR/files/*"
    
    # Extract backup
    log "📦 Giải nén file backup..."
    local temp_extract_dir="/tmp/n8n_restore_extract_$$"
    mkdir -p "$temp_extract_dir"
    
    if tar -xzf "$RESTORE_FILE_PATH" -C "$temp_extract_dir"; then
        local backup_content_dir=$(find "$temp_extract_dir" -mindepth 1 -maxdepth 1 -type d)
        if [[ -d "$backup_content_dir" ]]; then
            log "Tìm thấy nội dung backup trong: $backup_content_dir"
            # Restore credentials (database, encryption key)
            if [[ -d "$backup_content_dir/credentials" ]]; then
                log "Khôi phục database và key..."
                cp -a "$backup_content_dir/credentials/." "$INSTALL_DIR/files/"
            fi
            # Restore config files (docker-compose.yml, Caddyfile)
            if [[ -d "$backup_content_dir/config" ]]; then
                log "Khôi phục file cấu hình..."
                cp -a "$backup_content_dir/config/." "$INSTALL_DIR/"
            fi
            # Restore other data if needed (e.g., user files)
            # This part can be expanded if the backup contains more data.
        else
            error "Cấu trúc file backup không hợp lệ. Không tìm thấy thư mục nội dung."
            rm -rf "$temp_extract_dir"
            exit 1
        fi
        
        rm -rf "$temp_extract_dir"
        if [[ "$RESTORE_SOURCE" == "gdrive" ]]; then
            rm -rf "/tmp/n8n_restore"
        fi
        
        success "✅ Khôi phục dữ liệu thành công!"
    else
        error "Giải nén file backup thất bại."
        rm -rf "$temp_extract_dir"
        exit 1
    fi
}

# =============================================================================
# USER INPUT FUNCTIONS
# =============================================================================

get_installation_mode() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        return 0
    fi
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        🏠 CHỌN CHẾ ĐỘ CÀI ĐẶT                              ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Chọn chế độ cài đặt:${NC}"
    echo -e "  ${GREEN}1. Production Mode (có domain + SSL)${NC}"
    echo -e "     • Cần domain đã trỏ về server"
    echo -e "     • Tự động cấp SSL certificate"
    echo -e "     • Phù hợp cho production"
    echo ""
    echo -e "  ${GREEN}2. Local Mode (không cần domain)${NC}"
    echo -e "     • Chạy trên localhost"
    echo -e "     • Không cần SSL certificate"
    echo -e "     • Phù hợp cho development/testing"
    echo ""
    
    read -p "🏠 Bạn muốn cài đặt Local Mode? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        LOCAL_MODE=true
        info "Đã chọn Local Mode"
    else
        LOCAL_MODE=false
        info "Đã chọn Production Mode"
    fi
}

get_domain_input() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        DOMAIN="localhost"
        API_DOMAIN="localhost"
        info "Local Mode: Sử dụng localhost"
        return 0
    fi
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                           🌐 CẤU HÌNH DOMAIN                                ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    while true; do
        read -p "🌐 Nhập domain chính cho N8N (ví dụ: n8n.example.com): " DOMAIN
        if [[ -n "$DOMAIN" && "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]]; then
            break
        else
            error "Domain không hợp lệ. Vui lòng nhập lại."
        fi
    done
    
    API_DOMAIN="api.${DOMAIN}"
    info "Domain N8N: ${DOMAIN}"
    info "Domain API: ${API_DOMAIN}"
}

get_cleanup_option() {
    if [[ "$CLEAN_INSTALL" == "true" ]]; then
        return 0
    fi
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                           🗑️  CLEANUP OPTION                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ -d "$INSTALL_DIR" ]]; then
        warning "Phát hiện cài đặt N8N cũ tại: $INSTALL_DIR"
        read -p "🗑️  Bạn có muốn xóa cài đặt cũ và cài mới? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            CLEAN_INSTALL=true
        fi
    fi
}

get_news_api_config() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        📰 NEWS CONTENT API                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}News Content API cho phép:${NC}"
    echo -e "  📰 Cào nội dung bài viết từ bất kỳ website nào"
    echo -e "  📡 Parse RSS feeds để lấy tin tức mới nhất"
    echo -e "  🔍 Tìm kiếm và phân tích nội dung tự động"
    echo -e "  🤖 Tích hợp trực tiếp vào N8N workflows"
    echo ""
    
    read -p "📰 Bạn có muốn cài đặt News Content API? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_NEWS_API=false
        return 0
    fi
    
    ENABLE_NEWS_API=true
    
    echo ""
    echo -e "${YELLOW}🔐 Thiết lập Bearer Token cho News API:${NC}"
    echo -e "  • ${GREEN}ĐÃ GỠ BỎ GIỚI HẠN!${NC} Bạn có thể đặt bất kỳ mật khẩu nào."
    echo -e "  • Hỗ trợ chữ, số, ký tự đặc biệt, độ dài tùy ý."
    echo -e "  • Sẽ được sử dụng để xác thực API calls"
    echo ""
    
    read -p "🔑 Nhập Bearer Token của bạn (để trống sẽ tự tạo token siêu mạnh): " BEARER_TOKEN
    if [[ -z "$BEARER_TOKEN" ]]; then
        BEARER_TOKEN=$(openssl rand -base64 48)
        info "Đã tự động tạo Bearer Token an toàn."
    fi
    
    success "Đã thiết lập Bearer Token cho News API"
}

get_backup_config() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        info "Local Mode: Bỏ qua cấu hình backup tự động"
        return 0
    fi

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                      💾 CẤU HÌNH BACKUP TỰ ĐỘNG                          ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Tùy chọn backup:${NC}"
    echo -e "  🔄 Tự động backup workflows & credentials mỗi ngày"
    echo -e "  📱 Gửi thông báo & file backup qua Telegram"
    echo -e "  ☁️ Tải file backup lên Google Drive an toàn"
    echo -e "  🗂️ Tự động dọn dẹp các bản backup cũ"
    echo ""

    # Telegram Backup
    read -p "📱 Bạn có muốn thiết lập backup qua Telegram không? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_TELEGRAM=true
        echo ""
        echo -e "${YELLOW}🤖 Hướng dẫn tạo Telegram Bot:${NC}"
        echo -e "  1. Mở Telegram, tìm @BotFather và gửi lệnh /newbot"
        echo -e "  2. Copy Bot Token nhận được"
        echo ""
        while true; do
            read -p "🤖 Nhập Telegram Bot Token: " TELEGRAM_BOT_TOKEN
            if [[ -n "$TELEGRAM_BOT_TOKEN" ]]; then break; fi
        done
        
        echo ""
        echo -e "${YELLOW}🆔 Hướng dẫn lấy Chat ID:${NC}"
        echo -e "  • Tìm @userinfobot, gửi /start để lấy ID cá nhân"
        echo ""
        while true; do
            read -p "🆔 Nhập Telegram Chat ID: " TELEGRAM_CHAT_ID
            if [[ -n "$TELEGRAM_CHAT_ID" ]]; then break; fi
        done
        success "Đã cấu hình Telegram Backup."
    fi

    # Google Drive Backup
    read -p "☁️ Bạn có muốn thiết lập backup qua Google Drive không? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_GDRIVE_BACKUP=true
        install_rclone
        setup_rclone_config
        read -p "📝 Nhập tên thư mục trên Google Drive để lưu backup [n8n_backups]: " GDRIVE_FOLDER_INPUT
        if [[ -n "$GDRIVE_FOLDER_INPUT" ]]; then GDRIVE_BACKUP_FOLDER="$GDRIVE_FOLDER_INPUT"; fi
        success "Đã cấu hình Google Drive Backup."
    fi
}

get_auto_update_config() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        info "Local Mode: Bỏ qua Auto-Update"
        ENABLE_AUTO_UPDATE=false
        return 0
    fi
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        🔄 AUTO-UPDATE                                      ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Auto-Update sẽ:${NC}"
    echo -e "  🔄 Tự động cập nhật N8N mỗi 12 giờ"
    echo -e "  📦 Cập nhật yt-dlp, FFmpeg và các dependencies"
    echo -e "  📋 Ghi log chi tiết quá trình update"
    echo -e "  🔒 Backup trước khi update"
    echo ""
    
    read -p "🔄 Bạn có muốn bật Auto-Update? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_AUTO_UPDATE=false
    else
        ENABLE_AUTO_UPDATE=true
        success "Đã bật Auto-Update"
    fi
}

# =============================================================================
# DNS VERIFICATION
# =============================================================================

verify_dns() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        info "Local Mode: Bỏ qua kiểm tra DNS"
        return 0
    fi
    
    log "🔍 Kiểm tra DNS cho domain ${DOMAIN}..."
    
    # Get server IP
    local server_ip=$(curl -s https://api.ipify.org || curl -s http://ipv4.icanhazip.com || echo "unknown")
    info "IP máy chủ: ${server_ip}"
    
    # Check domain DNS
    local domain_ip=$(dig +short "$DOMAIN" A | tail -n1)
    local api_domain_ip=$(dig +short "$API_DOMAIN" A | tail -n1)
    
    info "IP của ${DOMAIN}: ${domain_ip:-"không tìm thấy"}"
    info "IP của ${API_DOMAIN}: ${api_domain_ip:-"không tìm thấy"}"
    
    if [[ "$domain_ip" != "$server_ip" ]] || [[ "$api_domain_ip" != "$server_ip" ]]; then
        warning "DNS chưa trỏ đúng về máy chủ!"
        echo ""
        echo -e "${YELLOW}Hướng dẫn cấu hình DNS:${NC}"
        echo -e "  1. Đăng nhập vào trang quản lý domain"
        echo -e "  2. Tạo 2 bản ghi A record:"
        echo -e "     • ${DOMAIN} → ${server_ip}"
        echo -e "     • ${API_DOMAIN} → ${server_ip}"
        echo -e "  3. Đợi 5-60 phút để DNS propagation"
        echo ""
        
        read -p "🤔 Bạn có muốn tiếp tục cài đặt? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        success "DNS đã được cấu hình đúng"
    fi
}

# =============================================================================
# CLEANUP FUNCTIONS
# =============================================================================

cleanup_old_installation() {
    if [[ "$CLEAN_INSTALL" != "true" ]]; then
        return 0
    fi
    
    log "🗑️ Xóa cài đặt cũ..."
    
    # Stop and remove containers
    if [[ -d "$INSTALL_DIR" ]]; then
        cd "$INSTALL_DIR"
        if [[ -n "$DOCKER_COMPOSE" ]]; then
            $DOCKER_COMPOSE down --volumes --remove-orphans 2>/dev/null || true
        fi
    fi
    
    # Remove Docker images
    docker rmi n8n-custom-ffmpeg:latest news-api:latest 2>/dev/null || true
    
    # Remove installation directory
    rm -rf "$INSTALL_DIR"
    
    # Remove cron jobs
    crontab -l 2>/dev/null | grep -v "/home/n8n" | crontab - 2>/dev/null || true
    
    success "Đã xóa cài đặt cũ"
}

# =============================================================================
# DOCKER INSTALLATION
# =============================================================================

install_docker() {
    if [[ "$SKIP_DOCKER" == "true" ]]; then
        info "Bỏ qua cài đặt Docker"
        return 0
    fi
    
    if command -v docker &> /dev/null; then
        info "Docker đã được cài đặt"
        
        # Check if Docker is running
        if ! docker info &> /dev/null; then
            log "Khởi động Docker daemon..."
            systemctl start docker
            systemctl enable docker
        fi
        
        # Install docker-compose if not available
        if [[ -z "$DOCKER_COMPOSE" ]]; then
            log "Cài đặt docker-compose..."
            apt-get update
            apt-get install -y docker-compose-plugin
            export DOCKER_COMPOSE="docker compose"
        fi
        
        return 0
    fi
    
    log "📦 Cài đặt Docker..."
    
    # Update system
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    # Add Docker GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add current user to docker group
    usermod -aG docker $SUDO_USER 2>/dev/null || true
    
    export DOCKER_COMPOSE="docker compose"
    success "Đã cài đặt Docker thành công"
}

# =============================================================================
# PROJECT SETUP
# =============================================================================

create_project_structure() {
    log "📁 Tạo cấu trúc thư mục..."
    
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Create directories with proper permissions
    mkdir -p files/backup_full
    mkdir -p files/temp
    mkdir -p files/youtube_content_anylystic
    mkdir -p logs
    
    if [[ "$ENABLE_NEWS_API" == "true" ]]; then
        mkdir -p news_api
    fi
    
    success "Đã tạo cấu trúc thư mục"
}

create_dockerfile() {
    log "🐳 Tạo Dockerfile cho N8N..."
    
    cat > "$INSTALL_DIR/Dockerfile" << 'EOF'
FROM n8nio/n8n:latest

USER root

# Install system dependencies
RUN apk add --no-cache \
    ffmpeg \
    python3 \
    python3-dev \
    py3-pip \
    chromium \
    chromium-chromedriver \
    curl \
    wget \
    git \
    build-base \
    linux-headers

# Install yt-dlp
RUN pip3 install --break-system-packages yt-dlp

# Install Puppeteer dependencies
RUN npm install -g puppeteer

# Set Chrome path for Puppeteer
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

# Create directories with proper permissions
RUN mkdir -p /home/node/.n8n/nodes
RUN mkdir -p /data/youtube_content_anylystic

# Set ownership to node user (UID 1000)
RUN chown -R 1000:1000 /home/node/.n8n
RUN chown -R 1000:1000 /data

USER node

# Install additional N8N nodes
RUN npm install n8n-nodes-puppeteer

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5678/healthz || exit 1

WORKDIR /data
EOF
    
    success "Đã tạo Dockerfile cho N8N"
}

create_news_api() {
    if [[ "$ENABLE_NEWS_API" != "true" ]]; then
        return 0
    fi
    
    log "📰 Tạo News Content API v4.1 (Anti-Bot Protection)..."
    
    # Create requirements.txt với selenium và các thư viện stealth
    cat > "$INSTALL_DIR/news_api/requirements.txt" << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
newspaper4k==0.9.3
selenium==4.15.0
selenium-stealth==1.0.6
undetected-chromedriver==3.5.4
requests==2.31.0
requests-html==0.10.0
user-agents==2.2.0
fake-useragent==1.4.0
pydantic==2.5.0
python-multipart==0.0.6
lxml==4.9.3
Pillow==10.1.0
nltk==3.8.1
beautifulsoup4==4.12.2
feedparser==6.0.10
python-dateutil==2.8.2
cloudscraper==1.2.71
curl-cffi==0.5.10
httpx[http2]==0.25.2
playwright==1.40.0
asyncio==3.4.3
aiohttp==3.9.1
retrying==1.3.4
random-user-agent==1.0.1
EOF
    
    # Create main.py với anti-bot protection
    cat > "$INSTALL_DIR/news_api/main.py" << 'EOF'
import os
import random
import logging
import asyncio
import time
from datetime import datetime
from typing import List, Optional, Dict, Any
import feedparser
import requests
import httpx
import cloudscraper
from requests_html import HTMLSession
from fastapi import FastAPI, HTTPException, Depends, Security, BackgroundTasks
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, HttpUrl, Field
import newspaper
from newspaper import Article, Source
from fake_useragent import UserAgent
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium_stealth import stealth
import undetected_chromedriver as uc
import nltk
from retrying import retry
from curl_cffi import requests as cffi_requests

# Download required NLTK data
try:
    nltk.download('punkt', quiet=True)
    nltk.download('stopwords', quiet=True)
except:
    pass

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# FastAPI app
app = FastAPI(
    title="News Content API v4.1 - Anti-Bot Protection",
    description="Advanced News Content Extraction API với khả năng bypass Sucuri/Cloudflare protection",
    version="4.1.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security
security = HTTPBearer()
NEWS_API_TOKEN = os.getenv("NEWS_API_TOKEN", "default_token")

# User Agent Generators
ua = UserAgent()

# Danh sách User Agents tối ưu cho trang tin tức Việt Nam
VIETNAM_USER_AGENTS = [
    # Chrome trên Windows (phổ biến nhất tại VN)
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36",
    
    # Mobile User Agents (rất hiệu quả cho VN news sites)
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1",
    "Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
    "Mozilla/5.0 (Linux; Android 12; SM-G973F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36",
    
    # Firefox Desktop
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:120.0) Gecko/20100101 Firefox/120.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:119.0) Gecko/20100101 Firefox/119.0",
    
    # Edge Browser  
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0",
    
    # MacOS Safari
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15",
]

def get_random_user_agent() -> str:
    """Lấy user agent ngẫu nhiên tối ưu cho trang tin tức VN"""
    return random.choice(VIETNAM_USER_AGENTS)

def get_random_headers() -> Dict[str, str]:
    """Tạo headers ngẫu nhiên chống detection"""
    user_agent = get_random_user_agent()
    
    headers = {
        'User-Agent': user_agent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
        'Accept-Language': random.choice([
            'vi-VN,vi;q=0.9,en;q=0.8,en-US;q=0.7',
            'vi,en-US;q=0.9,en;q=0.8',
            'en-US,en;q=0.9,vi;q=0.8'
        ]),
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'none',
        'Sec-Fetch-User': '?1',
        'Cache-Control': 'max-age=0',
    }
    
    # Thêm các headers ngẫu nhiên cho Chrome
    if 'Chrome' in user_agent:
        headers.update({
            'sec-ch-ua': '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
            'sec-ch-ua-mobile': '?1' if 'Mobile' in user_agent else '?0',
            'sec-ch-ua-platform': '"Android"' if 'Android' in user_agent else '"Windows"'
        })
    
    return headers

class AdvancedScraper:
    """Advanced scraper với multiple bypass methods"""
    
    def __init__(self):
        self.session = requests.Session()
        self.cloudscraper = cloudscraper.create_scraper(
            browser={
                'browser': 'chrome',
                'platform': 'windows',
                'mobile': False
            }
        )
        self.html_session = HTMLSession()
        
    @retry(stop_max_attempt_number=3, wait_fixed=2000)
    def get_content_with_requests(self, url: str) -> Optional[str]:
        """Phương pháp 1: Sử dụng requests với headers tối ưu"""
        try:
            headers = get_random_headers()
            
            # Thêm delay ngẫu nhiên
            time.sleep(random.uniform(1, 3))
            
            response = self.session.get(
                url, 
                headers=headers, 
                timeout=30,
                allow_redirects=True,
                verify=False
            )
            
            if response.status_code == 200:
                return response.text
            
        except Exception as e:
            logger.warning(f"Requests method failed for {url}: {e}")
        
        return None
    
    @retry(stop_max_attempt_number=3, wait_fixed=2000)
    def get_content_with_cloudscraper(self, url: str) -> Optional[str]:
        """Phương pháp 2: Sử dụng CloudScraper"""
        try:
            headers = get_random_headers()
            time.sleep(random.uniform(1, 3))
            
            response = self.cloudscraper.get(url, headers=headers, timeout=30)
            
            if response.status_code == 200:
                return response.text
                
        except Exception as e:
            logger.warning(f"CloudScraper method failed for {url}: {e}")
        
        return None
    
    @retry(stop_max_attempt_number=2, wait_fixed=3000)  
    def get_content_with_requests_html(self, url: str) -> Optional[str]:
        """Phương pháp 3: Sử dụng requests-html (JavaScript support)"""
        try:
            headers = get_random_headers()
            time.sleep(random.uniform(2, 4))
            
            r = self.html_session.get(url, headers=headers, timeout=30)
            
            # Render JavaScript nếu cần
            if 'cloudflare' in r.text.lower() or 'sucuri' in r.text.lower():
                r.html.render(timeout=20, wait=3)
            
            if r.status_code == 200:
                return r.html.html
                
        except Exception as e:
            logger.warning(f"Requests-HTML method failed for {url}: {e}")
        
        return None
    
    @retry(stop_max_attempt_number=2, wait_fixed=5000)
    def get_content_with_curl_cffi(self, url: str) -> Optional[str]:
        """Phương pháp 4: Sử dụng curl-cffi (impersonate Chrome)"""
        try:
            headers = get_random_headers()
            time.sleep(random.uniform(2, 5))
            
            response = cffi_requests.get(
                url,
                headers=headers,
                timeout=30,
                impersonate="chrome120"  # Giả mạo Chrome 120
            )
            
            if response.status_code == 200:
                return response.text
                
        except Exception as e:
            logger.warning(f"curl-cffi method failed for {url}: {e}")
        
        return None
    
    @retry(stop_max_attempt_number=1, wait_fixed=10000)
    def get_content_with_selenium(self, url: str) -> Optional[str]:
        """Phương pháp 5: Sử dụng Selenium (last resort)"""
        driver = None
        try:
            # Cấu hình Chrome options
            chrome_options = Options()
            chrome_options.add_argument('--headless')
            chrome_options.add_argument('--no-sandbox')
            chrome_options.add_argument('--disable-dev-shm-usage')
            chrome_options.add_argument('--disable-gpu')
            chrome_options.add_argument('--window-size=1920,1080')
            chrome_options.add_argument(f'--user-agent={get_random_user_agent()}')
            chrome_options.add_argument('--disable-blink-features=AutomationControlled')
            chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
            chrome_options.add_experimental_option('useAutomationExtension', False)
            
            # Sử dụng undetected-chromedriver
            driver = uc.Chrome(options=chrome_options)
            
            # Apply stealth
            stealth(driver,
                languages=["vi-VN", "vi", "en-US", "en"],
                vendor="Google Inc.",
                platform="Win32",
                webgl_vendor="Intel Inc.",
                renderer="Intel Iris OpenGL Engine",
                fix_hairline=True,
            )
            
            logger.info(f"🤖 Sử dụng Selenium để bypass protection cho: {url}")
            
            driver.get(url)
            
            # Đợi trang load và xử lý các challenge
            WebDriverWait(driver, 20).until(
                lambda d: d.execute_script("return document.readyState") == "complete"
            )
            
            # Kiểm tra và xử lý Cloudflare/Sucuri challenge
            if "cloudflare" in driver.page_source.lower() or "sucuri" in driver.page_source.lower():
                logger.info("🛡️ Phát hiện anti-bot protection, đang chờ bypass...")
                time.sleep(10)  # Đợi challenge được giải quyết
                
                # Kiểm tra lại
                WebDriverWait(driver, 30).until(
                    lambda d: "cloudflare" not in d.page_source.lower() and "sucuri" not in d.page_source.lower()
                )
            
            return driver.page_source
            
        except Exception as e:
            logger.error(f"Selenium method failed for {url}: {e}")
        finally:
            if driver:
                driver.quit()
        
        return None
    
    def get_content(self, url: str) -> str:
        """Thử tất cả phương pháp để lấy nội dung"""
        
        # Phương pháp 1: Requests đơn giản (nhanh nhất)
        content = self.get_content_with_requests(url)
        if content and len(content) > 1000:  # Kiểm tra content có đủ dài
            logger.info(f"✅ Thành công với requests: {url}")
            return content
        
        # Phương pháp 2: CloudScraper  
        content = self.get_content_with_cloudscraper(url)
        if content and len(content) > 1000:
            logger.info(f"✅ Thành công với CloudScraper: {url}")
            return content
        
        # Phương pháp 3: curl-cffi
        content = self.get_content_with_curl_cffi(url)
        if content and len(content) > 1000:
            logger.info(f"✅ Thành công với curl-cffi: {url}")
            return content
        
        # Phương pháp 4: requests-html (có JavaScript)
        content = self.get_content_with_requests_html(url)
        if content and len(content) > 1000:
            logger.info(f"✅ Thành công với requests-html: {url}")
            return content
        
        # Phương pháp 5: Selenium (chậm nhưng hiệu quả nhất)
        content = self.get_content_with_selenium(url)
        if content and len(content) > 1000:
            logger.info(f"✅ Thành công với Selenium: {url}")
            return content
        
        # Nếu tất cả đều fail
        raise HTTPException(
            status_code=400, 
            detail=f"Không thể bypass anti-bot protection cho {url}. Content quá ngắn hoặc bị block."
        )

# Global scraper instance
scraper = AdvancedScraper()

def verify_token(credentials: HTTPAuthorizationCredentials = Security(security)):
    """Verify Bearer token"""
    if credentials.credentials != NEWS_API_TOKEN:
        raise HTTPException(
            status_code=401,
            detail="Invalid authentication token"
        )
    return credentials.credentials

# Pydantic models
class ArticleRequest(BaseModel):
    url: HttpUrl
    language: str = Field(default="vi", description="Language code (vi, en, zh, etc.)")
    extract_images: bool = Field(default=True, description="Extract images from article")
    summarize: bool = Field(default=False, description="Generate article summary")
    bypass_method: str = Field(default="auto", description="auto, requests, cloudscraper, selenium")

class SourceRequest(BaseModel):
    url: HttpUrl
    max_articles: int = Field(default=10, ge=1, le=30, description="Maximum articles to extract")
    language: str = Field(default="vi", description="Language code")

class FeedRequest(BaseModel):
    url: HttpUrl
    max_articles: int = Field(default=10, ge=1, le=30, description="Maximum articles to parse")

class ArticleResponse(BaseModel):
    title: str
    content: str
    summary: Optional[str] = None
    authors: List[str]
    publish_date: Optional[datetime] = None
    images: List[str]
    top_image: Optional[str] = None
    keywords: List[str]
    language: str
    word_count: int
    read_time_minutes: int
    url: str
    bypass_method_used: str = Field(description="Method successfully used to bypass protection")

class SourceResponse(BaseModel):
    source_url: str
    articles: List[ArticleResponse]
    total_articles: int
    categories: List[str]

class FeedResponse(BaseModel):
    feed_url: str
    feed_title: str
    articles: List[Dict[str, Any]]
    total_articles: int

def create_newspaper_config(language: str = "vi") -> newspaper.Config:
    """Create newspaper configuration with advanced settings"""
    config = newspaper.Config()
    config.language = language
    config.browser_user_agent = get_random_user_agent()
    config.request_timeout = 30
    config.number_threads = 1
    config.thread_timeout_seconds = 30
    config.ignored_content_types_defaults = {
        'application/pdf', 'application/x-pdf', 'application/x-bzpdf',
        'application/x-gzpdf', 'application/msword', 'doc', 'text/plain'
    }
    config.keep_article_html = True
    return config

def extract_article_content(url: str, language: str = "vi", extract_images: bool = True, summarize: bool = False, bypass_method: str = "auto") -> ArticleResponse:
    """Extract content from a single article with anti-bot protection"""
    try:
        # Lấy raw HTML với advanced scraper
        raw_html = scraper.get_content(url)
        
        # Sử dụng newspaper để parse content
        config = create_newspaper_config(language)
        article = Article(url, config=config)
        
        # Download và parse với raw HTML
        article.set_html(raw_html)
        article.parse()
        
        # Extract keywords và summary nếu yêu cầu
        keywords = []
        summary = None
        
        if article.text:
            try:
                article.nlp()
                keywords = article.keywords[:10]
                if summarize:
                    summary = article.summary
            except Exception as e:
                logger.warning(f"NLP processing failed for {url}: {e}")
        
        # Tính toán read time
        word_count = len(article.text.split()) if article.text else 0
        read_time = max(1, round(word_count / 200))
        
        # Extract images
        images = []
        if extract_images:
            images = list(article.images)[:10]
        
        return ArticleResponse(
            title=article.title or "No title",
            content=article.text or "No content",
            summary=summary,
            authors=article.authors,
            publish_date=article.publish_date,
            images=images,
            top_image=article.top_image,
            keywords=keywords,
            language=language,
            word_count=word_count,
            read_time_minutes=read_time,
            url=url,
            bypass_method_used="advanced_multi_method"
        )
        
    except Exception as e:
        logger.error(f"Error extracting article {url}: {e}")
        raise HTTPException(status_code=400, detail=f"Failed to extract article: {str(e)}")

# API Routes
@app.get("/", response_class=HTMLResponse)
async def root():
    """API Homepage with documentation"""
    html_content = f"""
    <!DOCTYPE html>
    <html lang="vi">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>News Content API v4.1 - Anti-Bot Protection - by Nguyễn Ngọc Thiện</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: #333; line-height: 1.6; }
            .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
            .header { text-align: center; background: rgba(255, 255, 255, 0.1); backdrop-filter: blur(10px); border-radius: 20px; padding: 40px 20px; margin-bottom: 30px; box-shadow: 0 8px 32px rgba(31, 38, 135, 0.37); border: 1px solid rgba(255, 255, 255, 0.18); }
            .header h1 { color: #fff; font-size: 2.5em; margin-bottom: 10px; text-shadow: 2px 2px 4px rgba(0,0,0,0.3); }
            .header p { color: #f0f0f0; font-size: 1.2em; }
            .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-bottom: 30px; }
            .card { background: rgba(255, 255, 255, 0.95); border-radius: 15px; padding: 25px; box-shadow: 0 8px 25px rgba(0,0,0,0.1); transition: transform 0.3s ease, box-shadow 0.3s ease; }
            .card:hover { transform: translateY(-5px); box-shadow: 0 15px 35px rgba(0,0,0,0.2); }
            .card h3 { color: #2c3e50; margin-bottom: 15px; display: flex; align-items: center; gap: 10px; }
            .card .emoji { font-size: 1.5em; }
            .author-info { background: linear-gradient(45deg, #667eea, #764ba2); color: white; border-radius: 15px; padding: 25px; text-align: center; margin-top: 30px; }
            .author-info h3 { margin-bottom: 15px; }
            .social-links { display: flex; justify-content: center; gap: 15px; flex-wrap: wrap; margin-top: 15px; }
            .social-links a { background: rgba(255,255,255,0.2); color: white; padding: 10px 20px; border-radius: 25px; text-decoration: none; transition: all 0.3s ease; }
            .social-links a:hover { background: rgba(255,255,255,0.3); transform: scale(1.05); }
            .update-log { background: #e8f5e8; border-left: 5px solid #28a745; padding: 20px; border-radius: 10px; margin-top: 20px; }
            .update-log h4 { color: #155724; margin-bottom: 10px; }
            .update-log ul { margin-left: 20px; }
            .update-log li { color: #155724; margin-bottom: 5px; }
            @media (max-width: 768px) { .header h1 { font-size: 2em; } .grid { grid-template-columns: 1fr; } .social-links { flex-direction: column; align-items: center; } }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🚀 News Content API v4.1 - Anti-Bot Protection</h1>
                <p>Advanced News Content Extraction API với khả năng bypass Sucuri/Cloudflare protection</p>
            </div>
            
            <div class="grid">
                <div class="card">
                    <h3><span class="emoji">🛡️</span>Bypass Protection</h3>
                    <ul>
                        <li>✅ Sucuri CloudProxy bypass</li>
                        <li>✅ Cloudflare protection</li>
                        <li>✅ JavaScript challenge solver</li>
                        <li>✅ Browser impersonation</li>
                        <li>✅ Mobile user agents VN</li>
                    </ul>
                </div>
                
                <div class="card">
                    <h3><span class="emoji">🔧</span>V4.1 Updates</h3>
                    <ul>
                        <li>🔧 Fixed ChromeDriver API</li>
                        <li>🚧 Chrome for Testing API</li>
                        <li>🛡️ Fallback installation</li>
                        <li>⚡ Improved stability</li>
                        <li>🐞 Bug fixes</li>
                    </ul>
                </div>
                
                <div class="card">
                    <h3><span class="emoji">🚀</span>5 Bypass Methods</h3>
                    <ol>
                        <li><strong>Requests</strong> - Smart headers</li>
                        <li><strong>CloudScraper</strong> - JS challenges</li>
                        <li><strong>curl-cffi</strong> - Chrome impersonation</li>
                        <li><strong>requests-html</strong> - JS rendering</li>
                        <li><strong>Selenium</strong> - Full browser</li>
                    </ol>
                </div>
                
                <div class="card">
                    <h3><span class="emoji">📰</span>VN News Sites</h3>
                    <ul>
                        <li>✅ VnExpress.net</li>
                        <li>✅ Dantri.com.vn</li>
                        <li>✅ Tuoitre.vn</li>
                        <li>✅ Thanhnien.vn</li>
                        <li>✅ Và nhiều site khác</li>
                    </ul>
                </div>
                
                <div class="card">
                    <h3><span class="emoji">🔐</span>API Authentication</h3>
                    <p>Tất cả endpoints yêu cầu Bearer Token:</p>
                    <code style="background: #2c3e50; color: #ecf0f1; padding: 8px; border-radius: 5px; display: block; margin-top: 10px;">
                        Authorization: Bearer YOUR_TOKEN
                    </code>
                </div>
                
                <div class="card">
                    <h3><span class="emoji">📚</span>API Endpoints</h3>
                    <ul>
                        <li><strong>GET /health</strong> - Kiểm tra API</li>
                        <li><strong>POST /extract-article</strong> - Cào bài viết</li>
                        <li><strong>POST /extract-source</strong> - Cào nhiều bài</li>
                        <li><strong>POST /extract-feed</strong> - Cào RSS feed</li>
                    </ul>
                    <p style="margin-top: 15px;">
                        <a href="/docs" target="_blank" style="color: #667eea; text-decoration: none;">📚 Swagger UI</a> | 
                        <a href="/redoc" target="_blank" style="color: #667eea; text-decoration: none;">📖 ReDoc</a>
                    </p>
                </div>
            </div>
            
            <div class="author-info">
                <h3>👨‍💻 Tác Giả - Nguyễn Ngọc Thiện</h3>
                <p>🚀 Chuyên gia N8N Automation & Web Scraping</p>
                <div class="social-links">
                    <a href="https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1" target="_blank">📺 YouTube</a>
                    <a href="https://www.youtube.com/@kalvinthiensocial/playlists" target="_blank">🎬 N8N Playlist</a>
                    <a href="https://www.facebook.com/Ban.Thien.Handsome/" target="_blank">📘 Facebook</a>
                    <a href="tel:0888884749">📱 Zalo: 08.8888.4749</a>
                </div>
                <p style="margin-top: 15px; font-size: 0.9em; opacity: 0.9;">
                    🎯 Hãy đăng ký kênh YouTube để ủng hộ và nhận thông báo video mới nhất về N8N! 🔔
                </p>
                
                <div class="update-log">
                    <h4>📅 Update Log V4.1 - 30/06/2025</h4>
                    <ul>
                        <li>🔧 Fixed ChromeDriver installation error với Chrome for Testing API</li>
                        <li>🚧 Added fallback method sử dụng apt chromium-chromedriver</li>
                        <li>⚡ Improved Docker build stability</li>
                        <li>🐞 Bug fixes for anti-bot protection</li>
                        <li>📊 Enhanced error logging and debugging</li>
                    </ul>
                </div>
            </div>
        </div>
    </body>
    </html>
      """
      return html_content

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now(),
        "version": "4.1.0",
        "features": [
            "Anti-bot protection bypass",
            "Sucuri CloudProxy bypass", 
            "Cloudflare bypass",
            "Selenium stealth mode",
            "Multi-method content extraction",
            "Vietnam news sites optimized",
            "Mobile user agents",
            "Smart retry logic"
        ],
        "bypass_methods": [
            "requests + smart headers",
            "cloudscraper",
            "curl-cffi browser impersonation", 
            "requests-html JavaScript",
            "selenium undetected"
        ]
    }

@app.post("/extract-article", response_model=ArticleResponse)
async def extract_article(
    request: ArticleRequest,
    token: str = Depends(verify_token)
):
    """Extract content from a single article URL with anti-bot protection"""
    logger.info(f"🔍 Extracting article with anti-bot bypass: {request.url}")
    return extract_article_content(
        str(request.url),
        request.language,
        request.extract_images,
        request.summarize,
        request.bypass_method
    )

@app.post("/extract-source", response_model=SourceResponse)
async def extract_source(
    request: SourceRequest,
    token: str = Depends(verify_token)
):
    """Extract multiple articles from a news source with protection bypass"""
    try:
        logger.info(f"🔍 Extracting source with bypass: {request.url}")
        
        # Sử dụng advanced scraper để lấy HTML của trang chính
        source_html = scraper.get_content(str(request.url))
        
        config = create_newspaper_config(request.language)
        source = Source(str(request.url), config=config)
        
        # Build source với HTML đã lấy được
        source.set_html(source_html)
        source.build()
        
        articles_to_process = source.articles[:request.max_articles]
        
        extracted_articles = []
        for article in articles_to_process:
            try:
                article_response = extract_article_content(
                    article.url,
                    request.language,
                    extract_images=True,
                    summarize=False
                )
                extracted_articles.append(article_response)
            except Exception as e:
                logger.warning(f"Failed to extract article {article.url}: {e}")
                continue
        
        return SourceResponse(
            source_url=str(request.url),
            articles=extracted_articles,
            total_articles=len(extracted_articles),
            categories=source.category_urls()[:10]
        )
        
    except Exception as e:
        logger.error(f"Error extracting source {request.url}: {e}")
        raise HTTPException(status_code=400, detail=f"Failed to extract source: {str(e)}")

@app.post("/parse-feed", response_model=FeedResponse)
async def parse_feed(
    request: FeedRequest,
    token: str = Depends(verify_token)
):
    """Parse RSS/Atom feed and extract articles"""
    try:
        logger.info(f"🔍 Parsing feed: {request.url}")
        
        # Set random user agent cho requests
        headers = get_random_headers()
        
        # Parse feed
        feed = feedparser.parse(str(request.url), request_headers=headers)
        
        if feed.bozo:
            logger.warning(f"Feed parsing warning for {request.url}: {feed.bozo_exception}")
        
        articles = []
        entries_to_process = feed.entries[:request.max_articles]
        
        for entry in entries_to_process:
            article_data = {
                "title": getattr(entry, 'title', 'No title'),
                "link": getattr(entry, 'link', ''),
                "description": getattr(entry, 'description', ''),
                "published": getattr(entry, 'published', ''),
                "author": getattr(entry, 'author', ''),
                "tags": [tag.term for tag in getattr(entry, 'tags', [])],
                "summary": getattr(entry, 'summary', '')
            }
            articles.append(article_data)
        
        return FeedResponse(
            feed_url=str(request.url),
            feed_title=getattr(feed.feed, 'title', 'Unknown Feed'),
            articles=articles,
            total_articles=len(articles)
        )
        
    except Exception as e:
        logger.error(f"Error parsing feed {request.url}: {e}")
        raise HTTPException(status_code=400, detail=f"Failed to parse feed: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, workers=1)
EOF
    
    # Create Dockerfile cho News API với Selenium
    cat > "$INSTALL_DIR/news_api/Dockerfile" << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies cho Selenium và Chrome
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    libxml2-dev \
    libxslt-dev \
    libjpeg-dev \
    zlib1g-dev \
    libpng-dev \
    curl \
    wget \
    gnupg \
    unzip \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

# Install Google Chrome
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# Install ChromeDriver với Chrome for Testing API mới + fallback method
RUN CHROME_VERSION=$(google-chrome --version | grep -oP '\d+\.\d+\.\d+' | head -1) \
    && CHROME_MAJOR_VERSION=$(echo $CHROME_VERSION | cut -d. -f1) \
    && echo "Chrome version: $CHROME_VERSION, Major: $CHROME_MAJOR_VERSION" \
    && LATEST_RELEASE=$(curl -s "https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE_$CHROME_MAJOR_VERSION" || echo "") \
    && if [ -n "$LATEST_RELEASE" ] && [ "$LATEST_RELEASE" != "" ]; then \
        echo "Latest ChromeDriver release for Chrome $CHROME_MAJOR_VERSION: $LATEST_RELEASE" \
        && wget -O /tmp/chromedriver.zip "https://storage.googleapis.com/chrome-for-testing-public/$LATEST_RELEASE/linux64/chromedriver-linux64.zip" \
        && unzip /tmp/chromedriver.zip -d /tmp/ \
        && mv /tmp/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver \
        && rm -rf /tmp/chromedriver.zip /tmp/chromedriver-linux64 \
        && chmod +x /usr/local/bin/chromedriver \
        && echo "✅ ChromeDriver installed via Chrome for Testing API"; \
    else \
        echo "⚠️ Chrome for Testing API failed, using apt chromium-chromedriver as fallback" \
        && apt-get update \
        && apt-get install -y chromium-chromedriver \
        && ln -sf /usr/bin/chromedriver /usr/local/bin/chromedriver \
        && rm -rf /var/lib/apt/lists/*; \
    fi \
    && chromedriver --version

# Copy requirements và install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install Playwright browsers
RUN playwright install chromium
RUN playwright install-deps

# Copy application code
COPY . .

# Set environment variables
ENV DISPLAY=:99
ENV CHROME_BIN=/usr/bin/google-chrome
ENV CHROMEDRIVER_PATH=/usr/local/bin/chromedriver

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose port
EXPOSE 8000

# Start Xvfb và run application
CMD ["sh", "-c", "Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 & uvicorn main:app --host 0.0.0.0 --port 8000 --workers 1"]
EOF
    
    success "Đã tạo News Content API v4.0 với Anti-Bot Protection"
}

create_docker_compose() {
    log "🐳 Tạo docker-compose.yml..."
    
    if [[ "$LOCAL_MODE" == "true" ]]; then
        # Local Mode - No Caddy, direct port exposure
        cat > "$INSTALL_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  n8n:
    build: .
    container_name: n8n-container
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - NODE_ENV=production
      - WEBHOOK_URL=http://localhost:5678/
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
      - N8N_METRICS=true
      - N8N_LOG_LEVEL=info
      - N8N_LOG_OUTPUT=console
      - N8N_USER_FOLDER=/home/node
      - N8N_ENCRYPTION_KEY=\${N8N_ENCRYPTION_KEY:-$(openssl rand -hex 32)}
      - DB_TYPE=sqlite
      - DB_SQLITE_DATABASE=/home/node/.n8n/database.sqlite
      - N8N_BASIC_AUTH_ACTIVE=false
      - N8N_DISABLE_PRODUCTION_MAIN_PROCESS=false
      - EXECUTIONS_TIMEOUT=3600
      - EXECUTIONS_TIMEOUT_MAX=7200
      - N8N_EXECUTIONS_DATA_MAX_SIZE=500MB
      - N8N_BINARY_DATA_TTL=1440
      - N8N_BINARY_DATA_MODE=filesystem
    volumes:
      - ./files:/home/node/.n8n
      - ./files/youtube_content_anylystic:/data/youtube_content_anylystic
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - n8n_network
EOF

        if [[ "$ENABLE_NEWS_API" == "true" ]]; then
            cat >> "$INSTALL_DIR/docker-compose.yml" << EOF

  fastapi:
    build: ./news_api
    container_name: news-api-container
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      - NEWS_API_TOKEN=${BEARER_TOKEN}
      - PYTHONUNBUFFERED=1
    networks:
      - n8n_network
EOF
        fi

    else
        # Production Mode - With Caddy reverse proxy
        cat > "$INSTALL_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  n8n:
    build: .
    container_name: n8n-container
    restart: unless-stopped
    ports:
      - "127.0.0.1:5678:5678"
    environment:
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - NODE_ENV=production
      - WEBHOOK_URL=https://${DOMAIN}/
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
      - N8N_METRICS=true
      - N8N_LOG_LEVEL=info
      - N8N_LOG_OUTPUT=console
      - N8N_USER_FOLDER=/home/node
      - N8N_ENCRYPTION_KEY=\${N8N_ENCRYPTION_KEY:-$(openssl rand -hex 32)}
      - DB_TYPE=sqlite
      - DB_SQLITE_DATABASE=/home/node/.n8n/database.sqlite
      - N8N_BASIC_AUTH_ACTIVE=false
      - N8N_DISABLE_PRODUCTION_MAIN_PROCESS=false
      - EXECUTIONS_TIMEOUT=3600
      - EXECUTIONS_TIMEOUT_MAX=7200
      - N8N_EXECUTIONS_DATA_MAX_SIZE=500MB
      - N8N_BINARY_DATA_TTL=1440
      - N8N_BINARY_DATA_MODE=filesystem
    volumes:
      - ./files:/home/node/.n8n
      - ./files/youtube_content_anylystic:/data/youtube_content_anylystic
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - n8n_network

  caddy:
    image: caddy:latest
    container_name: caddy-proxy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - n8n_network
    depends_on:
      - n8n
EOF

        if [[ "$ENABLE_NEWS_API" == "true" ]]; then
            cat >> "$INSTALL_DIR/docker-compose.yml" << EOF
      - fastapi

  fastapi:
    build: ./news_api
    container_name: news-api-container
    restart: unless-stopped
    ports:
      - "127.0.0.1:8000:8000"
    environment:
      - NEWS_API_TOKEN=${BEARER_TOKEN}
      - PYTHONUNBUFFERED=1
    networks:
      - n8n_network
EOF
        fi

        cat >> "$INSTALL_DIR/docker-compose.yml" << 'EOF'

volumes:
  caddy_data:
  caddy_config:
EOF
    fi

    cat >> "$INSTALL_DIR/docker-compose.yml" << 'EOF'

networks:
  n8n_network:
    driver: bridge
EOF
    
    success "Đã tạo docker-compose.yml"
}

create_caddyfile() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        info "Local Mode: Bỏ qua tạo Caddyfile"
        return 0
    fi
    
    log "🌐 Tạo Caddyfile..."
    
    cat > "$INSTALL_DIR/Caddyfile" << EOF
{
    email admin@${DOMAIN}
    acme_ca https://acme-v02.api.letsencrypt.org/directory
}

${DOMAIN} {
    reverse_proxy n8n:5678
    
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
    }
    
    encode gzip
    
    # Error pages
    handle_errors {
        @502 expression {http.error.status_code} == 502
        handle @502 {
            respond "N8N service is starting up. Please wait a moment and refresh." 502
        }
    }
    
    log {
        output file /var/log/caddy/n8n.log
        format json
    }
}
EOF

    if [[ "$ENABLE_NEWS_API" == "true" ]]; then
        cat >> "$INSTALL_DIR/Caddyfile" << EOF

${API_DOMAIN} {
    reverse_proxy fastapi:8000
    
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Access-Control-Allow-Origin "*"
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        Access-Control-Allow-Headers "Content-Type, Authorization"
    }
    
    encode gzip
    
    # Error pages
    handle_errors {
        @502 expression {http.error.status_code} == 502
        handle @502 {
            respond "News API service is starting up. Please wait a moment and refresh." 502
        }
    }
    
    log {
        output file /var/log/caddy/api.log
        format json
    }
}
EOF
    fi
    
    success "Đã tạo Caddyfile"
}

# =============================================================================
# BACKUP SYSTEM
# =============================================================================

create_backup_scripts() {
    log "💾 Tạo hệ thống backup..."
    
    # Main backup script
    cat > "$INSTALL_DIR/backup-workflows.sh" << EOF
#!/bin/bash

# =============================================================================
# N8N BACKUP SCRIPT - Tự động backup workflows và credentials
# =============================================================================

set -e

BACKUP_DIR="/home/n8n/files/backup_full"
LOG_FILE="/home/n8n/logs/backup.log"
TIMESTAMP=\$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="n8n_backup_\$TIMESTAMP"
TEMP_DIR="/tmp/\$BACKUP_NAME"

# Colors
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
NC='\\033[0m'

log() {
    echo -e "\${GREEN}[\$(date +'%Y-%m-%d %H:%M:%S')] \$1\${NC}" | tee -a "\$LOG_FILE"
}

error() {
    echo -e "\${RED}[ERROR] \$1\${NC}" | tee -a "\$LOG_FILE"
}

# Check Docker Compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    error "Docker Compose không tìm thấy!"
    exit 1
fi

# Create backup directory
mkdir -p "\$BACKUP_DIR"
mkdir -p "\$TEMP_DIR"

log "🔄 Bắt đầu backup N8N..."

# Backup database and encryption key
log "💾 Backup database và key..."
mkdir -p "\$TEMP_DIR/credentials"
cp "/home/n8n/files/database.sqlite" "\$TEMP_DIR/credentials/"
cp "/home/n8n/files/encryptionKey" "\$TEMP_DIR/credentials/" 2>/dev/null || true

# Backup config files
log "🔧 Backup config files..."
mkdir -p "\$TEMP_DIR/config"
cp /home/n8n/docker-compose.yml "\$TEMP_DIR/config/" 2>/dev/null || true
cp /home/n8n/Caddyfile "\$TEMP_DIR/config/" 2>/dev/null || true

# Create metadata
log "📊 Tạo metadata..."
cat > "\$TEMP_DIR/backup_metadata.json" << EOL
{
    "backup_date": "\$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "backup_name": "\$BACKUP_NAME",
    "n8n_version": "\$(docker exec n8n-container n8n --version 2>/dev/null || echo 'unknown')",
    "backup_type": "full"
}
EOL

# Create compressed backup
log "📦 Tạo file backup nén..."
cd /tmp
tar -czf "\$BACKUP_DIR/\$BACKUP_NAME.tar.gz" "\$BACKUP_NAME/"

# Get backup size
BACKUP_SIZE=\$(ls -lh "\$BACKUP_DIR/\$BACKUP_NAME.tar.gz" | awk '{print \$5}')
log "✅ Backup hoàn thành: \$BACKUP_NAME.tar.gz (\$BACKUP_SIZE)"

# Cleanup temp directory
rm -rf "\$TEMP_DIR"

# Keep only last 30 local backups
log "🧹 Cleanup old local backups..."
cd "\$BACKUP_DIR"
ls -t n8n_backup_*.tar.gz | tail -n +31 | xargs -r rm -f

# Send to Telegram if configured
if [[ -f "/home/n8n/telegram_config.txt" ]]; then
    source "/home/n8n/telegram_config.txt"
    
    if [[ -n "\$TELEGRAM_BOT_TOKEN" && -n "\$TELEGRAM_CHAT_ID" ]]; then
        log "📱 Gửi thông báo Telegram..."
        MESSAGE="🔄 *N8N Backup Completed*
📅 Date: \$(date +'%Y-%m-%d %H:%M:%S')
📦 File: \`\$BACKUP_NAME.tar.gz\`
💾 Size: \$BACKUP_SIZE
📊 Status: ✅ Success"
        curl -s -X POST "https://api.telegram.org/bot\$TELEGRAM_BOT_TOKEN/sendMessage" -d chat_id="\$TELEGRAM_CHAT_ID" -d text="\$MESSAGE" -d parse_mode="Markdown" > /dev/null || true
    fi
fi

# Upload to Google Drive if configured
if [[ -f "/home/n8n/gdrive_config.txt" ]]; then
    source "/home/n8n/gdrive_config.txt"
    if [[ -n "\$RCLONE_REMOTE_NAME" && -n "\$GDRIVE_BACKUP_FOLDER" ]]; then
        log "☁️ Uploading to Google Drive..."
        rclone copy "\$BACKUP_DIR/\$BACKUP_NAME.tar.gz" "\$RCLONE_REMOTE_NAME:\$GDRIVE_BACKUP_FOLDER" --progress
        log "🧹 Cleanup old Google Drive backups (older than 30 days)..."
        rclone delete --min-age 30d "\$RCLONE_REMOTE_NAME:\$GDRIVE_BACKUP_FOLDER"
    fi
fi

log "🎉 Backup process completed successfully!"
EOF

    chmod +x "$INSTALL_DIR/backup-workflows.sh"
    
    # Manual backup test script
    cat > "$INSTALL_DIR/backup-manual.sh" << 'EOF'
#!/bin/bash

echo "🧪 MANUAL BACKUP TEST"
echo "===================="
echo ""

cd /home/n8n

echo "📋 Thông tin hệ thống:"
echo "• Thời gian: $(date)"
echo "• Disk usage: $(df -h /home/n8n | tail -1 | awk '{print $5}')"
echo "• Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"
echo ""

echo "🔄 Chạy backup test..."
./backup-workflows.sh

echo ""
echo "📊 Kết quả backup:"
ls -lah /home/n8n/files/backup_full/n8n_backup_*.tar.gz | tail -5

echo ""
echo "✅ Manual backup test completed!"
EOF

    chmod +x "$INSTALL_DIR/backup-manual.sh"
    
    success "Đã tạo hệ thống backup"
}

create_update_script() {
    if [[ "$ENABLE_AUTO_UPDATE" != "true" ]]; then
        return 0
    fi
    
    log "🔄 Tạo script auto-update..."
    
    cat > "$INSTALL_DIR/update-n8n.sh" << 'EOF'
#!/bin/bash

# =============================================================================
# N8N AUTO-UPDATE SCRIPT
# =============================================================================

set -e

LOG_FILE="/home/n8n/logs/update.log"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$TIMESTAMP] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$TIMESTAMP] [ERROR] $1${NC}" | tee -a "$LOG_FILE"
}

# Check Docker Compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    error "Docker Compose không tìm thấy!"
    exit 1
fi

cd /home/n8n

log "🔄 Bắt đầu auto-update N8N..."

# Backup before update
log "💾 Backup trước khi update..."
./backup-workflows.sh

# Pull latest images
log "📦 Pull latest Docker images..."
$DOCKER_COMPOSE pull

# Update yt-dlp in running container
log "📺 Update yt-dlp..."
docker exec n8n-container pip3 install --break-system-packages -U yt-dlp || true

# Restart services
log "🔄 Restart services..."
$DOCKER_COMPOSE up -d

# Wait for services to be ready
log "⏳ Đợi services khởi động..."
sleep 30

# Check if services are running
if docker ps | grep -q "n8n-container"; then
    log "✅ N8N container đang chạy"
else
    error "❌ N8N container không chạy"
fi

if docker ps | grep -q "caddy-proxy"; then
    log "✅ Caddy container đang chạy"
else
    log "ℹ️ Caddy container không chạy (có thể đang ở Local Mode)"
fi

# Send Telegram notification if configured
if [[ -f "/home/n8n/telegram_config.txt" ]]; then
    source "/home/n8n/telegram_config.txt"
    
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        MESSAGE="🔄 *N8N Auto-Update Completed*
        
📅 Date: $TIMESTAMP
🚀 Status: ✅ Success
📦 Components updated:
• N8N Docker image
• yt-dlp
• System dependencies

🌐 Services: All running normally"

        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$MESSAGE" \
            -d parse_mode="Markdown" > /dev/null || true
    fi
fi

log "🎉 Auto-update completed successfully!"
EOF

    chmod +x "$INSTALL_DIR/update-n8n.sh"
    
    success "Đã tạo script auto-update"
}

# =============================================================================
# TELEGRAM & GDRIVE CONFIGURATION
# =============================================================================

setup_backup_configs() {
    if [[ "$ENABLE_TELEGRAM" == "true" ]]; then
        log "📱 Lưu cấu hình Telegram..."
        cat > "$INSTALL_DIR/telegram_config.txt" << EOF
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"
EOF
        chmod 600 "$INSTALL_DIR/telegram_config.txt"
    fi

    if [[ "$ENABLE_GDRIVE_BACKUP" == "true" ]]; then
        log "☁️ Lưu cấu hình Google Drive..."
        cat > "$INSTALL_DIR/gdrive_config.txt" << EOF
RCLONE_REMOTE_NAME="$RCLONE_REMOTE_NAME"
GDRIVE_BACKUP_FOLDER="$GDRIVE_BACKUP_FOLDER"
EOF
        chmod 600 "$INSTALL_DIR/gdrive_config.txt"
    fi
}

# =============================================================================
# CRON JOBS
# =============================================================================

setup_cron_jobs() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        info "Local Mode: Bỏ qua thiết lập cron jobs"
        return 0
    fi
    
    log "⏰ Thiết lập cron jobs..."
    
    # Remove existing cron jobs for n8n
    crontab -l 2>/dev/null | grep -v "/home/n8n" | crontab - 2>/dev/null || true
    
    # Add backup job (daily at 2:00 AM)
    (crontab -l 2>/dev/null; echo "0 2 * * * /home/n8n/backup-workflows.sh >> /home/n8n/logs/cron.log 2>&1") | crontab -
    
    # Add auto-update job if enabled
    if [[ "$ENABLE_AUTO_UPDATE" == "true" ]]; then
        (crontab -l 2>/dev/null; echo "0 */12 * * * /home/n8n/update-n8n.sh >> /home/n8n/logs/cron.log 2>&1") | crontab -
    fi
    
    success "Đã thiết lập cron jobs"
}

# =============================================================================
# SSL RATE LIMIT DETECTION (IMPROVED)
# =============================================================================

check_ssl_rate_limit() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        info "Local Mode: Bỏ qua kiểm tra SSL"
        return 0
    fi
    
    log "🔒 Kiểm tra SSL certificate (logic đã cải tiến)..."
    
    # Wait for Caddy to attempt SSL issuance
    log "⏳ Đợi Caddy xử lý SSL (tối đa 90 giây)..."
    sleep 90
    
    local caddy_logs=$($DOCKER_COMPOSE logs caddy 2>&1)

    # First, check for a clear success message to avoid false positives
    if echo "$caddy_logs" | grep -q "certificate obtained successfully" | grep -q "$DOMAIN"; then
        success "✅ SSL certificate đã được cấp thành công cho $DOMAIN"
        return 0
    fi

    # If no success message, then check for the specific rate limit error
    if echo "$caddy_logs" | grep -q "urn:ietf:params:acme:error:rateLimited"; then
        error "🚨 PHÁT HIỆN SSL RATE LIMIT!"
        echo ""
        echo -e "${RED}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║${WHITE}                        ⚠️  SSL RATE LIMIT DETECTED                          ${RED}║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # Install python3-pip and pytz if not present, for timezone conversion
        if ! dpkg -s python3-pip >/dev/null 2>&1; then apt-get install -y python3-pip; fi
        if ! python3 -c "import pytz" >/dev/null 2>&1; then pip3 install pytz; fi

        local reset_time_vn=$(python3 -c "
import re, datetime, pytz
log_data = '''$caddy_logs'''
match = re.search(r'Retry-After: (\w{3}, \d{2} \w{3} \d{4} \d{2}:\d{2}:\d{2} GMT)', log_data)
if match:
    try:
        gmt_time_str = match.group(1)
        gmt_time = datetime.datetime.strptime(gmt_time_str, '%a, %d %b %Y %H:%M:%S GMT')
        gmt_tz = pytz.timezone('GMT')
        gmt_time_aware = gmt_tz.localize(gmt_time)
        vn_tz = pytz.timezone('Asia/Ho_Chi_Minh')
        vn_time = gmt_time_aware.astimezone(vn_tz)
        print(vn_time.strftime('%H:%M:%S ngày %d-%m-%Y (Giờ Việt Nam)'))
    except Exception:
        print('Không thể tính toán, vui lòng đợi 7 ngày.')
else:
    print('Không xác định được, vui lòng đợi 7 ngày.')
")
        
        echo -e "${YELLOW}🔍 NGUYÊN NHÂN:${NC}"
        echo -e "  • Let's Encrypt giới hạn 5 certificates/domain/tuần"
        echo -e "  • Domain này đã đạt giới hạn miễn phí"
        echo ""
        echo -e "${YELLOW}📅 THÔNG TIN RATE LIMIT:${NC}"
        echo -e "  • Rate limit sẽ được reset vào khoảng: ${WHITE}$reset_time_vn${NC}"
        echo ""
        
        echo -e "${YELLOW}💡 GIẢI PHÁP:${NC}"
        echo -e "  ${GREEN}1. SỬ DỤNG STAGING SSL (TẠM THỜI):${NC}"
        echo -e "     • Website sẽ hiển thị 'Not Secure' nhưng vẫn hoạt động"
        echo -e "     • Có thể chuyển về production SSL sau khi rate limit reset"
        echo ""
        echo -e "  ${GREEN}2. ĐỢI ĐẾN KHI RATE LIMIT RESET:${NC}"
        echo -e "     • Đợi đến sau thời gian ở trên và chạy lại script"
        echo ""
        
        echo -e "${YELLOW}📋 LỊCH SỬ SSL ATTEMPTS GẦN ĐÂY:${NC}"
        echo "$caddy_logs" | grep -i "certificate\|ssl\|acme\|rate" | tail -10 | while read line; do
            echo -e "  ${WHITE}• $line${NC}"
        done
        echo ""
        
        read -p "🤔 Bạn muốn tiếp tục với Staging SSL? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            setup_staging_ssl
        else
            exit 1
        fi
    else
        warning "⚠️ SSL có thể chưa sẵn sàng hoặc đã xảy ra lỗi khác."
        echo -e "${YELLOW}Vui lòng kiểm tra log của Caddy để biết chi tiết:${NC}"
        $DOCKER_COMPOSE logs caddy
    fi
}

setup_staging_ssl() {
    warning "🔧 Thiết lập Staging SSL..."
    
    # Stop containers
    $DOCKER_COMPOSE down
    
    # Remove SSL volumes to force re-issuance
    docker volume rm ${INSTALL_DIR##*/}_caddy_data ${INSTALL_DIR##*/}_caddy_config 2>/dev/null || true
    
    # Update Caddyfile for staging
    sed -i '/acme_ca/c\    acme_ca https://acme-staging-v02.api.letsencrypt.org/directory' "$INSTALL_DIR/Caddyfile"
    
    # Restart containers
    $DOCKER_COMPOSE up -d
    
    success "✅ Đã thiết lập Staging SSL"
    warning "⚠️ Website sẽ hiển thị 'Not Secure' - đây là bình thường với staging certificate"
}

# =============================================================================
# DEPLOYMENT
# =============================================================================

build_and_deploy() {
    log "🏗️ Build và deploy containers..."
    cd "$INSTALL_DIR"
    
    log "🛑 Dừng containers cũ (nếu có)..."
    $DOCKER_COMPOSE down --remove-orphans 2>/dev/null || true
    
    log "🔐 Thiết lập quyền cho thư mục dữ liệu..."
    chown -R 1000:1000 "$INSTALL_DIR/files/"
    
    log "📦 Build Docker images..."
    $DOCKER_COMPOSE build --no-cache
    
    log "🚀 Khởi động services..."
    $DOCKER_COMPOSE up -d
    
    log "⏳ Đợi services khởi động và healthy (tối đa 3 phút)..."

    local services_to_check=("n8n-container")
    if [[ "$LOCAL_MODE" != "true" ]]; then
        services_to_check+=("caddy-proxy")
    fi
    if [[ "$ENABLE_NEWS_API" == "true" ]]; then
        services_to_check+=("news-api-container")
    fi

    local all_healthy=false
    local max_retries=12 # 12 retries * 15 seconds = 180 seconds = 3 minutes
    local retry_count=0

    # Temporarily disable exit on error for the check loop
    set +e

    while [[ $retry_count -lt $max_retries ]]; do
        all_healthy=true
        for service in "${services_to_check[@]}"; do
            # 1. Check if container is running
            container_id=$(docker ps -q --filter "name=^${service}$")
            if [[ -z "$container_id" ]]; then
                warning "Service '${service}' chưa chạy. Đang đợi... ($((retry_count+1))/${max_retries})"
                all_healthy=false
                break # Break inner loop, try again after sleep
            fi

            # 2. Check health status (if health check exists)
            health_status=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-health-check{{end}}' "$service")
            exit_code=$?

            if [[ $exit_code -ne 0 ]]; then
                warning "Không thể kiểm tra trạng thái của '${service}'. Có thể nó đang khởi động lại. Đang đợi... ($((retry_count+1))/${max_retries})"
                all_healthy=false
                break
            fi

            if [[ "$health_status" == "healthy" ]]; then
                info "✅ Service '${service}' đã healthy."
                continue # Check next service
            elif [[ "$health_status" == "unhealthy" ]]; then
                error "❌ Service '${service}' đã unhealthy. Kiểm tra logs."
                $DOCKER_COMPOSE logs "$service" --tail=50
                # Re-enable exit on error before exiting
                set -e
                exit 1
            else
                # Status is 'starting' or 'no-health-check'
                if [[ "$health_status" == "no-health-check" ]]; then
                     # For services without healthcheck, just being 'running' is enough
                     container_status=$(docker inspect --format='{{.State.Status}}' "$service")
                     if [[ "$container_status" == "running" ]]; then
                        info "✅ Service '${service}' đang chạy (không có health check)."
                        continue
                     else
                        warning "⏳ Service '${service}' đang ở trạng thái '${container_status}'. Đang đợi... ($((retry_count+1))/${max_retries})"
                        all_healthy=false
                        break
                     fi
                else
                    warning "⏳ Service '${service}' đang ở trạng thái '${health_status}'. Đang đợi... ($((retry_count+1))/${max_retries})"
                    all_healthy=false
                    break # Break inner loop, try again after sleep
                fi
            fi
        done

        if [[ "$all_healthy" == "true" ]]; then
            break # Exit while loop
        fi

        sleep 15
        ((retry_count++))
    done

    # Re-enable exit on error
    set -e

    if [[ "$all_healthy" != "true" ]]; then
        error "❌ Một hoặc nhiều services không thể khởi động thành công sau 3 phút."
        echo ""
        echo -e "${YELLOW}📋 Trạng thái containers cuối cùng:${NC}"
        $DOCKER_COMPOSE ps
        echo ""
        echo -e "${YELLOW}📋 Logs của các container:${NC}"
        $DOCKER_COMPOSE logs --tail=100
        echo ""
        echo -e "${YELLOW}🔧 Vui lòng chạy script chẩn đoán để tìm lỗi: bash ${INSTALL_DIR}/troubleshoot.sh${NC}"
        exit 1
    fi

    success "🎉 Tất cả services đã khởi động thành công!"
}

# =============================================================================
# TROUBLESHOOTING SCRIPT
# =============================================================================

create_troubleshooting_script() {
    log "🔧 Tạo script chẩn đoán..."
    
    cat > "$INSTALL_DIR/troubleshoot.sh" << 'EOF'
#!/bin/bash

# =============================================================================
# N8N TROUBLESHOOTING SCRIPT
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}                    🔧 N8N TROUBLESHOOTING SCRIPT                            ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check Docker Compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    echo -e "${RED}❌ Docker Compose không tìm thấy!${NC}"
    exit 1
fi

cd /home/n8n

echo -e "${BLUE}📍 1. System Information:${NC}"
echo "• OS: $(lsb_release -d | cut -f2)"
echo "• Kernel: $(uname -r)"
echo "• Docker: $(docker --version)"
echo "• Docker Compose: $($DOCKER_COMPOSE --version)"
echo "• Disk Usage: $(df -h /home/n8n | tail -1 | awk '{print $5}')"
echo "• Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"
echo "• Uptime: $(uptime -p)"
echo ""

echo -e "${BLUE}📍 2. Installation Mode:${NC}"
if [[ -f "Caddyfile" ]]; then
    echo "• Mode: Production Mode (with SSL)"
    DOMAIN=$(grep -E "^[a-zA-Z0-9.-]+\s*{" Caddyfile | head -1 | awk '{print $1}')
    echo "• Domain: $DOMAIN"
else
    echo "• Mode: Local Mode"
    echo "• Access: http://localhost:5678"
fi
echo ""

echo -e "${BLUE}📍 3. Container Status:${NC}"
$DOCKER_COMPOSE ps
echo ""

echo -e "${BLUE}📍 4. Docker Images:${NC}"
docker images | grep -E "(n8n|caddy|news-api)"
echo ""

echo -e "${BLUE}📍 5. Network Status:${NC}"
echo "• Port 80: $(netstat -tulpn 2>/dev/null | grep :80 | wc -l) connections"
echo "• Port 443: $(netstat -tulpn 2>/dev/null | grep :443 | wc -l) connections"
echo "• Port 5678: $(netstat -tulpn 2>/dev/null | grep :5678 | wc -l) connections"
echo "• Port 8000: $(netstat -tulpn 2>/dev/null | grep :8000 | wc -l) connections"
echo "• Docker Networks:"
docker network ls | grep n8n
echo ""

if [[ -n "$DOMAIN" && "$DOMAIN" != "localhost" ]]; then
    echo -e "${BLUE}📍 6. SSL Certificate Status:${NC}"
    echo "• Domain: $DOMAIN"
    echo "• DNS Resolution: $(dig +short $DOMAIN A | tail -1)"
    echo "• SSL Test:"
    timeout 10 curl -I https://$DOMAIN 2>/dev/null | head -3 || echo "  SSL not ready"
    echo ""
fi

echo -e "${BLUE}📍 7. File Permissions:${NC}"
echo "• N8N data directory: $(ls -ld /home/n8n/files | awk '{print $1" "$3":"$4}')"
echo "• Database file: $(ls -l /home/n8n/files/database.sqlite 2>/dev/null | awk '{print $1" "$3":"$4}' || echo 'Not found')"
echo ""

echo -e "${BLUE}📍 8. Recent Logs (last 20 lines):${NC}"
echo -e "${YELLOW}N8N Logs:${NC}"
$DOCKER_COMPOSE logs --tail=20 n8n 2>/dev/null || echo "No N8N logs"
echo ""

if docker ps | grep -q "caddy-proxy"; then
    echo -e "${YELLOW}Caddy Logs:${NC}"
    $DOCKER_COMPOSE logs --tail=20 caddy 2>/dev/null || echo "No Caddy logs"
    echo ""
fi

if docker ps | grep -q "news-api"; then
    echo -e "${YELLOW}News API Logs:${NC}"
    $DOCKER_COMPOSE logs --tail=20 fastapi 2>/dev/null || echo "No News API logs"
    echo ""
fi

echo -e "${BLUE}📍 9. Backup Status:${NC}"
if [[ -d "/home/n8n/files/backup_full" ]]; then
    BACKUP_COUNT=$(ls -1 /home/n8n/files/backup_full/n8n_backup_*.tar.gz 2>/dev/null | wc -l)
    echo "• Backup files: $BACKUP_COUNT"
    if [[ $BACKUP_COUNT -gt 0 ]]; then
        echo "• Latest backup: $(ls -t /home/n8n/files/backup_full/n8n_backup_*.tar.gz | head -1 | xargs basename)"
        echo "• Latest backup size: $(ls -lh /home/n8n/files/backup_full/n8n_backup_*.tar.gz | head -1 | awk '{print $5}')"
    fi
else
    echo "• No backup directory found"
fi
echo ""

echo -e "${BLUE}📍 10. Cron Jobs:${NC}"
crontab -l 2>/dev/null | grep -E "(n8n|backup)" || echo "• No N8N cron jobs found"
echo ""

echo -e "${GREEN}🔧 QUICK FIX COMMANDS:${NC}"
echo -e "${YELLOW}• Fix permissions:${NC} chown -R 1000:1000 /home/n8n/files/"
echo -e "${YELLOW}• Restart all services:${NC} cd /home/n8n && $DOCKER_COMPOSE restart"
echo -e "${YELLOW}• View live logs:${NC} cd /home/n8n && $DOCKER_COMPOSE logs -f"
echo -e "${YELLOW}• Rebuild containers:${NC} cd /home/n8n && $DOCKER_COMPOSE down && $DOCKER_COMPOSE up -d --build"
echo -e "${YELLOW}• Manual backup:${NC} /home/n8n/backup-manual.sh"

if [[ -n "$DOMAIN" && "$DOMAIN" != "localhost" ]]; then
    echo -e "${YELLOW}• Check SSL:${NC} curl -I https://$DOMAIN"
fi

echo ""
echo -e "${CYAN}✅ Troubleshooting completed!${NC}"
EOF

    chmod +x "$INSTALL_DIR/troubleshoot.sh"
    
    success "Đã tạo script chẩn đoán"
}

# =============================================================================
# FINAL SUMMARY
# =============================================================================

show_final_summary() {
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${WHITE}                🎉 N8N ĐÃ ĐƯỢC CÀI ĐẶT THÀNH CÔNG! (V4.0)                    ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}🌐 TRUY CẬP DỊCH VỤ:${NC}"
    if [[ "$LOCAL_MODE" == "true" ]]; then
        echo -e "  • N8N: ${WHITE}http://localhost:5678${NC}"
        if [[ "$ENABLE_NEWS_API" == "true" ]]; then
            echo -e "  • News API v4.0: ${WHITE}http://localhost:8000${NC}"
            echo -e "  • API Docs: ${WHITE}http://localhost:8000/docs${NC}"
        fi
    else
        echo -e "  • N8N: ${WHITE}https://${DOMAIN}${NC}"
        if [[ "$ENABLE_NEWS_API" == "true" ]]; then
            echo -e "  • News API v4.0: ${WHITE}https://${API_DOMAIN}${NC}"
            echo -e "  • API Docs: ${WHITE}https://${API_DOMAIN}/docs${NC}"
        fi
    fi
    
    if [[ "$ENABLE_NEWS_API" == "true" ]]; then
        echo -e "  • Bearer Token: ${YELLOW}Đã được đặt (không hiển thị vì bảo mật)${NC}"
        echo ""
        echo -e "${PURPLE}🆕 TÍNH NĂNG MỚI NEWS API V4.0:${NC}"
        echo -e "  ✅ ${WHITE}Khắc phục lỗi 307 Sucuri CloudProxy${NC}"
        echo -e "  ✅ ${WHITE}Bypass VnExpress, Dân Trí, Tuổi Trẻ${NC}"  
        echo -e "  ✅ ${WHITE}5 phương pháp bypass tự động${NC}"
        echo -e "  ✅ ${WHITE}Selenium stealth mode${NC}"
        echo -e "  ✅ ${WHITE}Mobile User Agents tối ưu VN${NC}"
        echo ""
        echo -e "${YELLOW}🧪 TEST API NGAY:${NC}"
        echo -e "  ${WHITE}curl -X POST \"$([[ "$LOCAL_MODE" == "true" ]] && echo "http://localhost:8000" || echo "https://${API_DOMAIN}")/extract-article\" \\${NC}"
        echo -e "  ${WHITE}  -H \"Content-Type: application/json\" \\${NC}"
        echo -e "  ${WHITE}  -H \"Authorization: Bearer YOUR_TOKEN\" \\${NC}"
        echo -e "  ${WHITE}  -d '{\"url\": \"https://vnexpress.net/trung-tam-trien-lam-lon-nhat-dong-nam-a-san-sang-hoat-dong-4907516.html\", \"language\": \"vi\"}'${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}📁 THÔNG TIN HỆ THỐNG:${NC}"
    echo -e "  • Phiên bản: ${WHITE}N8N v4.0 với Anti-Bot Protection${NC}"
    echo -e "  • Chế độ: ${WHITE}$([[ "$LOCAL_MODE" == "true" ]] && echo "Local Mode" || echo "Production Mode")${NC}"
    echo -e "  • Thư mục cài đặt: ${WHITE}${INSTALL_DIR}${NC}"
    echo -e "  • Script chẩn đoán: ${WHITE}${INSTALL_DIR}/troubleshoot.sh${NC}"
    echo -e "  • Test backup: ${WHITE}${INSTALL_DIR}/backup-manual.sh${NC}"
    echo ""
    
    echo -e "${CYAN}💾 CẤU HÌNH BACKUP:${NC}"
    echo -e "  • Telegram backup: ${WHITE}$([[ "$ENABLE_TELEGRAM" == "true" ]] && echo "Đã bật" || echo "Đã tắt")${NC}"
    echo -e "  • Google Drive backup: ${WHITE}$([[ "$ENABLE_GDRIVE_BACKUP" == "true" ]] && echo "Đã bật" || echo "Đã tắt")${NC}"
    if [[ "$LOCAL_MODE" != "true" ]]; then
        echo -e "  • Backup tự động: ${WHITE}Hàng ngày lúc 2:00 AM${NC}"
    fi
    echo -e "  • Backup location: ${WHITE}${INSTALL_DIR}/files/backup_full/${NC}"
    echo ""
    
    if [[ "$ENABLE_NEWS_API" == "true" ]]; then
        echo -e "${CYAN}🔧 ĐỔI BEARER TOKEN:${NC}"
        echo -e "  ${WHITE}cd /home/n8n && sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN=\"NEW_TOKEN\"/' docker-compose.yml && $DOCKER_COMPOSE restart fastapi${NC}"
        echo ""
        
        echo -e "${CYAN}🛡️ TROUBLESHOOTING ANTI-BOT:${NC}"
        echo -e "  • Xem logs: ${WHITE}docker logs news-api-container${NC}"
        echo -e "  • Restart News API: ${WHITE}$DOCKER_COMPOSE restart fastapi${NC}"
        echo -e "  • Test bypass: ${WHITE}curl $([[ "$LOCAL_MODE" == "true" ]] && echo "http://localhost:8000" || echo "https://${API_DOMAIN}")/health${NC}"
        echo ""
    fi
    
    echo -e "${CYAN}🚀 TÁC GIẢ:${NC}"
    echo -e "  • Tên: ${WHITE}Nguyễn Ngọc Thiện${NC}"
    echo -e "  • YouTube: ${WHITE}https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1${NC}"
    echo -e "  • Playlist N8N: ${WHITE}https://www.youtube.com/@kalvinthiensocial/playlists${NC}"
    echo -e "  • Facebook: ${WHITE}https://www.facebook.com/Ban.Thien.Handsome/${NC}"
    echo -e "  • Zalo: ${WHITE}08.8888.4749${NC}"
    echo -e "  • Cập nhật: ${WHITE}30/06/2025${NC}"
    echo ""
    
    echo -e "${YELLOW}🎬 HÃY ĐĂNG KÝ KÊNH YOUTUBE ĐỂ ỦNG HỘ MÌNH NHÉ! 🔔${NC}"
    echo -e "${YELLOW}📺 Xem playlist N8N đầy đủ tại: https://www.youtube.com/@kalvinthiensocial/playlists${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Show banner
    show_banner
    
    # System checks
    check_root
    check_os
    detect_environment
    check_docker_compose
    
    # Setup swap
    setup_swap
    
    # Get user input
    get_restore_option
    get_installation_mode
    get_domain_input
    get_cleanup_option
    get_news_api_config
    get_backup_config
    get_auto_update_config
    
    # Verify DNS (skip for local mode)
    verify_dns
    
    # Cleanup old installation
    cleanup_old_installation
    
    # Install Docker
    install_docker
    
    # Create project structure
    create_project_structure
    
    # Perform restore if requested
    perform_restore
    
    # Create configuration files
    create_dockerfile
    create_news_api
    create_docker_compose
    create_caddyfile
    
    # Create scripts
    create_backup_scripts
    create_update_script
    create_troubleshooting_script
    
    # Setup Backup Configs
    setup_backup_configs
    
    # Setup cron jobs (skip for local mode)
    setup_cron_jobs
    
    # Build and deploy
    build_and_deploy
    
    # Check SSL and rate limits (skip for local mode)
    check_ssl_rate_limit
    
    # Show final summary
    show_final_summary
}

# Run main function
main "$@"
