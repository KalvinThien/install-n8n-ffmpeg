#!/bin/bash

# =============================================================================
# 🚀 SCRIPT CÀI ĐẶT N8N TỰ ĐỘNG 2025 - PHIÊN BẢN HOÀN CHỈNH
# =============================================================================
# Tác giả: Nguyễn Ngọc Thiện
# YouTube: https://www.youtube.com/@kalvinthiensocial
# Zalo: 08.8888.4749
# Cập nhật: 30/06/2025
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
GDRIVE_CLIENT_ID=""
GDRIVE_CLIENT_SECRET=""
ENABLE_NEWS_API=false
ENABLE_TELEGRAM=false
ENABLE_GDRIVE=false
ENABLE_AUTO_UPDATE=false
CLEAN_INSTALL=false
SKIP_DOCKER=false
LOCAL_MODE=false
RESTORE_MODE=false
RESTORE_FILE=""

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                    🚀 SCRIPT CÀI ĐẶT N8N TỰ ĐỘNG 2025 🚀                    ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE} ✨ N8N + FFmpeg + yt-dlp + Puppeteer + News API + Telegram + GDrive       ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 🔒 SSL Certificate tự động với Caddy                                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 📰 News Content API với FastAPI + Newspaper4k                            ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 📱 Telegram Backup tự động hàng ngày                                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} ☁️ Google Drive Backup với OAuth2                                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 📦 Complete Restore System                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 🔄 Auto-Update với tùy chọn                                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 🏠 Local Mode (không cần domain)                                         ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${YELLOW} 👨‍💻 Tác giả: Nguyễn Ngọc Thiện                                           ${CYAN}║${NC}"
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
    echo "  -h, --help              Hiển thị trợ giúp này"
    echo "  -d, --dir DIR           Thư mục cài đặt (mặc định: /home/n8n)"
    echo "  -c, --clean             Xóa cài đặt cũ trước khi cài mới"
    echo "  -s, --skip-docker       Bỏ qua cài đặt Docker (nếu đã có)"
    echo "  -l, --local             Cài đặt Local Mode (không cần domain)"
    echo "  -r, --restore FILE      Restore từ file backup"
    echo ""
    echo "Ví dụ:"
    echo "  $0                      # Cài đặt bình thường"
    echo "  $0 --clean             # Xóa cài đặt cũ và cài mới"
    echo "  $0 --local             # Cài đặt Local Mode"
    echo "  $0 --restore backup.tar.gz  # Restore từ file"
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
            -r|--restore)
                RESTORE_MODE=true
                RESTORE_FILE="$2"
                shift 2
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
# USER INPUT FUNCTIONS
# =============================================================================

get_installation_mode() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        return 0
    fi
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        🏠 CHỌN CHẾ ĐỘ CÀI ĐẶT                              ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Chọn chế độ cài đặt:${NC}"
    echo -e "  ${GREEN}1. Domain Mode${NC} - Cài đặt với domain và SSL certificate"
    echo -e "  ${GREEN}2. Local Mode${NC} - Cài đặt local (localhost) không cần domain"
    echo ""
    
    while true; do
        read -p "🏠 Chọn chế độ cài đặt (1/2): " mode_choice
        case $mode_choice in
            1)
                LOCAL_MODE=false
                break
                ;;
            2)
                LOCAL_MODE=true
                info "Đã chọn Local Mode - không cần domain"
                break
                ;;
            *)
                error "Vui lòng chọn 1 hoặc 2"
                ;;
        esac
    done
}

get_restore_option() {
    if [[ "$RESTORE_MODE" == "true" ]]; then
        return 0
    fi
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        📦 RESTORE OPTION                                   ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    read -p "📦 Bạn có muốn restore từ backup cũ? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        RESTORE_MODE=true
        
        echo ""
        echo -e "${WHITE}Chọn nguồn restore:${NC}"
        echo -e "  ${GREEN}1. File local${NC} - Restore từ file .tar.gz"
        echo -e "  ${GREEN}2. Google Drive${NC} - Restore từ Google Drive"
        echo ""
        
        while true; do
            read -p "📦 Chọn nguồn restore (1/2): " restore_choice
            case $restore_choice in
                1)
                    while true; do
                        read -p "📁 Nhập đường dẫn file backup (.tar.gz): " RESTORE_FILE
                        if [[ -f "$RESTORE_FILE" && "$RESTORE_FILE" == *.tar.gz ]]; then
                            break
                        else
                            error "File không tồn tại hoặc không phải .tar.gz"
                        fi
                    done
                    break
                    ;;
                2)
                    RESTORE_FILE="gdrive"
                    break
                    ;;
                *)
                    error "Vui lòng chọn 1 hoặc 2"
                    ;;
            esac
        done
    fi
}

get_domain_input() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        DOMAIN="localhost"
        API_DOMAIN="localhost"
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
    echo -e "  • Token phải có ít nhất 8 ký tự"
    echo -e "  • Có thể chứa chữ cái, số và ký tự đặc biệt"
    echo -e "  • Sẽ được sử dụng để xác thực API calls"
    echo ""
    
    while true; do
        read -p "🔑 Nhập Bearer Token (ít nhất 8 ký tự): " BEARER_TOKEN
        if [[ ${#BEARER_TOKEN} -ge 8 ]]; then
            break
        else
            error "Token phải có ít nhất 8 ký tự."
        fi
    done
    
    success "Đã thiết lập Bearer Token cho News API"
}

get_telegram_config() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        📱 TELEGRAM BACKUP                                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Telegram Backup cho phép:${NC}"
    echo -e "  🔄 Tự động backup workflows & credentials mỗi ngày"
    echo -e "  📱 Gửi file backup qua Telegram Bot (nếu <20MB)"
    echo -e "  📊 Thông báo realtime về trạng thái backup"
    echo -e "  🗂️ Giữ 30 bản backup gần nhất tự động"
    echo ""
    
    read -p "📱 Bạn có muốn thiết lập Telegram Backup? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_TELEGRAM=false
        return 0
    fi
    
    ENABLE_TELEGRAM=true
    
    echo ""
    echo -e "${YELLOW}🤖 Hướng dẫn tạo Telegram Bot:${NC}"
    echo -e "  1. Mở Telegram, tìm @BotFather"
    echo -e "  2. Gửi lệnh: /newbot"
    echo -e "  3. Đặt tên và username cho bot"
    echo -e "  4. Copy Bot Token nhận được"
    echo ""
    
    while true; do
        read -p "🤖 Nhập Telegram Bot Token: " TELEGRAM_BOT_TOKEN
        if [[ -n "$TELEGRAM_BOT_TOKEN" && "$TELEGRAM_BOT_TOKEN" =~ ^[0-9]+:[a-zA-Z0-9_-]+$ ]]; then
            break
        else
            error "Bot Token không hợp lệ. Format: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
        fi
    done
    
    echo ""
    echo -e "${YELLOW}🆔 Hướng dẫn lấy Chat ID:${NC}"
    echo -e "  • Cho cá nhân: Tìm @userinfobot, gửi /start"
    echo -e "  • Cho nhóm: Thêm bot vào nhóm, Chat ID bắt đầu bằng dấu trừ (-)"
    echo ""
    
    while true; do
        read -p "🆔 Nhập Telegram Chat ID: " TELEGRAM_CHAT_ID
        if [[ -n "$TELEGRAM_CHAT_ID" && "$TELEGRAM_CHAT_ID" =~ ^-?[0-9]+$ ]]; then
            break
        else
            error "Chat ID không hợp lệ. Phải là số (có thể có dấu trừ ở đầu)"
        fi
    done
    
    success "Đã thiết lập Telegram Backup"
}

get_gdrive_config() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        ☁️  GOOGLE DRIVE BACKUP                             ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Google Drive Backup cho phép:${NC}"
    echo -e "  ☁️ Tự động upload backup lên Google Drive mỗi ngày"
    echo -e "  🔒 Xác thực OAuth2 an toàn"
    echo -e "  📁 Tự động tạo thư mục N8N_Backups"
    echo -e "  🗂️ Giữ 30 bản backup gần nhất"
    echo -e "  📦 Restore interactive từ Google Drive"
    echo ""
    
    read -p "☁️ Bạn có muốn thiết lập Google Drive Backup? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_GDRIVE=false
        return 0
    fi
    
    ENABLE_GDRIVE=true
    
    echo ""
    echo -e "${YELLOW}🔧 Hướng dẫn thiết lập Google Drive API:${NC}"
    echo ""
    echo -e "${WHITE}Bước 1: Google Cloud Console${NC}"
    echo -e "  1. Truy cập: ${BLUE}https://console.cloud.google.com/${NC}"
    echo -e "  2. Tạo project mới hoặc chọn project có sẵn"
    echo -e "  3. Enable Google Drive API:"
    echo -e "     • APIs & Services → Library"
    echo -e "     • Tìm 'Google Drive API' → Enable"
    echo ""
    echo -e "${WHITE}Bước 2: Tạo OAuth2 Credentials${NC}"
    echo -e "  1. APIs & Services → Credentials"
    echo -e "  2. Create Credentials → OAuth client ID"
    echo -e "  3. Application type: Desktop application"
    echo -e "  4. Name: N8N Backup (hoặc tên bất kỳ)"
    echo -e "  5. Download JSON file hoặc copy Client ID & Secret"
    echo ""
    
    echo -e "${YELLOW}📋 Nhập thông tin OAuth2:${NC}"
    echo ""
    
    while true; do
        read -p "🔑 Client ID: " GDRIVE_CLIENT_ID
        if [[ -n "$GDRIVE_CLIENT_ID" ]]; then
            break
        else
            error "Client ID không được để trống"
        fi
    done
    
    while true; do
        read -p "🔐 Client Secret: " GDRIVE_CLIENT_SECRET
        if [[ -n "$GDRIVE_CLIENT_SECRET" ]]; then
            break
        else
            error "Client Secret không được để trống"
        fi
    done
    
    success "Đã thiết lập Google Drive OAuth2"
}

get_auto_update_config() {
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
            apt update
            apt install -y docker-compose
            export DOCKER_COMPOSE="docker-compose"
        fi
        
        return 0
    fi
    
    log "📦 Cài đặt Docker..."
    
    # Update system
    apt update
    apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add current user to docker group
    usermod -aG docker $SUDO_USER 2>/dev/null || true
    
    export DOCKER_COMPOSE="docker-compose"
    success "Đã cài đặt Docker thành công"
}

# =============================================================================
# GOOGLE DRIVE SETUP
# =============================================================================

setup_gdrive() {
    if [[ "$ENABLE_GDRIVE" != "true" ]]; then
        return 0
    fi
    
    log "☁️ Thiết lập Google Drive..."
    
    # Install rclone
    if ! command -v rclone &> /dev/null; then
        log "Cài đặt rclone..."
        curl https://rclone.org/install.sh | bash
    fi
    
    # Create rclone config
    log "Cấu hình rclone cho Google Drive..."
    
    mkdir -p ~/.config/rclone
    
    cat > ~/.config/rclone/rclone.conf << EOF
[gdrive]
type = drive
client_id = $GDRIVE_CLIENT_ID
client_secret = $GDRIVE_CLIENT_SECRET
scope = drive
EOF
    
    # Authorize rclone
    echo ""
    echo -e "${YELLOW}🔐 Xác thực Google Drive:${NC}"
    echo -e "  1. Chạy lệnh sau để xác thực:"
    echo -e "     ${WHITE}rclone authorize \"drive\"${NC}"
    echo -e "  2. Trình duyệt sẽ mở, đăng nhập Google"
    echo -e "  3. Copy token nhận được và paste vào đây"
    echo ""
    
    read -p "📋 Paste token từ rclone authorize: " gdrive_token
    
    # Update config with token
    cat >> ~/.config/rclone/rclone.conf << EOF
token = $gdrive_token
EOF
    
    # Test connection
    log "🧪 Test kết nối Google Drive..."
    if rclone lsd gdrive: &>/dev/null; then
        success "✅ Kết nối Google Drive thành công"
        
        # Create backup folder
        rclone mkdir gdrive:N8N_Backups 2>/dev/null || true
        success "📁 Đã tạo thư mục N8N_Backups"
    else
        error "❌ Không thể kết nối Google Drive"
        ENABLE_GDRIVE=false
    fi
}

# =============================================================================
# RESTORE FUNCTIONS
# =============================================================================

restore_from_backup() {
    if [[ "$RESTORE_MODE" != "true" ]]; then
        return 0
    fi
    
    log "📦 Bắt đầu restore từ backup..."
    
    local restore_file=""
    local temp_dir="/tmp/n8n_restore_$(date +%s)"
    
    if [[ "$RESTORE_FILE" == "gdrive" ]]; then
        # Restore from Google Drive
        log "☁️ Restore từ Google Drive..."
        
        # List available backups
        echo ""
        echo -e "${YELLOW}📋 Danh sách backup trên Google Drive:${NC}"
        rclone ls gdrive:N8N_Backups/ | grep "\.tar\.gz$" | sort -r | head -10
        echo ""
        
        read -p "📁 Nhập tên file backup (ví dụ: n8n_backup_20250630_120000.tar.gz): " backup_name
        
        # Download from Google Drive
        restore_file="/tmp/$backup_name"
        log "⬇️ Download backup từ Google Drive..."
        rclone copy "gdrive:N8N_Backups/$backup_name" /tmp/
        
        if [[ ! -f "$restore_file" ]]; then
            error "Không thể download file backup từ Google Drive"
            return 1
        fi
    else
        # Restore from local file
        restore_file="$RESTORE_FILE"
    fi
    
    # Extract backup
    log "📂 Giải nén backup..."
    mkdir -p "$temp_dir"
    tar -xzf "$restore_file" -C "$temp_dir" --strip-components=1
    
    # Backup current data
    if [[ -d "$INSTALL_DIR/files" ]]; then
        log "💾 Backup dữ liệu hiện tại..."
        mv "$INSTALL_DIR/files" "$INSTALL_DIR/files_backup_$(date +%s)"
    fi
    
    # Restore workflows and credentials
    log "🔄 Restore workflows và credentials..."
    
    if [[ -d "$temp_dir/credentials" ]]; then
        mkdir -p "$INSTALL_DIR/files"
        cp -r "$temp_dir/credentials/"* "$INSTALL_DIR/files/" 2>/dev/null || true
    fi
    
    if [[ -d "$temp_dir/workflows" ]]; then
        mkdir -p "$INSTALL_DIR/files/workflows"
        cp -r "$temp_dir/workflows/"* "$INSTALL_DIR/files/workflows/" 2>/dev/null || true
    fi
    
    # Set proper permissions
    chown -R 1000:1000 "$INSTALL_DIR/files" 2>/dev/null || true
    
    # Cleanup
    rm -rf "$temp_dir"
    if [[ "$RESTORE_FILE" == "gdrive" ]]; then
        rm -f "$restore_file"
    fi
    
    success "✅ Restore hoàn thành"
}

# =============================================================================
# PROJECT SETUP
# =============================================================================

create_project_structure() {
    log "📁 Tạo cấu trúc thư mục..."
    
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Create directories
    mkdir -p files/backup_full
    mkdir -p files/temp
    mkdir -p files/youtube_content_anylystic
    mkdir -p logs
    
    if [[ "$ENABLE_NEWS_API" == "true" ]]; then
        mkdir -p news_api
    fi
    
    # Set proper permissions for N8N
    chown -R 1000:1000 "$INSTALL_DIR/files" 2>/dev/null || true
    
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

# Create directories
RUN mkdir -p /home/node/.n8n/nodes
RUN mkdir -p /data/youtube_content_anylystic

# Set permissions
RUN chown -R node:node /home/node/.n8n
RUN chown -R node:node /data

USER node

# Install additional N8N nodes
RUN npm install n8n-nodes-puppeteer

WORKDIR /data
EOF
    
    success "Đã tạo Dockerfile cho N8N"
}

create_news_api() {
    if [[ "$ENABLE_NEWS_API" != "true" ]]; then
        return 0
    fi
    
    log "📰 Tạo News Content API..."
    
    # Create requirements.txt
    cat > "$INSTALL_DIR/news_api/requirements.txt" << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
newspaper4k==0.9.3
user-agents==2.2.0
pydantic==2.5.0
python-multipart==0.0.6
requests==2.31.0
lxml==4.9.3
Pillow==10.1.0
nltk==3.8.1
beautifulsoup4==4.12.2
feedparser==6.0.10
python-dateutil==2.8.2
EOF
    
    # Create main.py
    cat > "$INSTALL_DIR/news_api/main.py" << 'EOF'
import os
import random
import logging
from datetime import datetime
from typing import List, Optional, Dict, Any
import feedparser
import requests
from fastapi import FastAPI, HTTPException, Depends, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, HttpUrl, Field
import newspaper
from newspaper import Article, Source
from user_agents import parse
import nltk

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
    title="News Content API",
    description="Advanced News Content Extraction API with Newspaper4k",
    version="2.0.0",
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

# Random User Agents
USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:121.0) Gecko/20100101 Firefox/121.0",
    "Mozilla/5.0 (X11; Linux x86_64; rv:121.0) Gecko/20100101 Firefox/121.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Edge/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15"
]

def get_random_user_agent() -> str:
    """Get a random user agent string"""
    return random.choice(USER_AGENTS)

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
    language: str = Field(default="en", description="Language code (en, vi, zh, etc.)")
    extract_images: bool = Field(default=True, description="Extract images from article")
    summarize: bool = Field(default=False, description="Generate article summary")

class SourceRequest(BaseModel):
    url: HttpUrl
    max_articles: int = Field(default=10, ge=1, le=50, description="Maximum articles to extract")
    language: str = Field(default="en", description="Language code")

class FeedRequest(BaseModel):
    url: HttpUrl
    max_articles: int = Field(default=10, ge=1, le=50, description="Maximum articles to parse")

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

# Helper functions
def create_newspaper_config(language: str = "en") -> newspaper.Config:
    """Create newspaper configuration with random user agent"""
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
    return config

def extract_article_content(url: str, language: str = "en", extract_images: bool = True, summarize: bool = False) -> ArticleResponse:
    """Extract content from a single article"""
    try:
        config = create_newspaper_config(language)
        article = Article(url, config=config)
        
        # Download and parse
        article.download()
        article.parse()
        
        # Extract keywords and summary if requested
        keywords = []
        summary = None
        
        if article.text:
            try:
                article.nlp()
                keywords = article.keywords[:10]  # Limit to 10 keywords
                if summarize:
                    summary = article.summary
            except Exception as e:
                logger.warning(f"NLP processing failed for {url}: {e}")
        
        # Calculate read time (average 200 words per minute)
        word_count = len(article.text.split()) if article.text else 0
        read_time = max(1, round(word_count / 200))
        
        # Extract images
        images = []
        if extract_images:
            images = list(article.images)[:10]  # Limit to 10 images
        
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
            url=url
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
    <html>
    <head>
        <title>News Content API</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }}
            .container {{ max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
            h1 {{ color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }}
            h2 {{ color: #34495e; margin-top: 30px; }}
            .endpoint {{ background: #ecf0f1; padding: 15px; border-radius: 5px; margin: 10px 0; }}
            .method {{ background: #3498db; color: white; padding: 3px 8px; border-radius: 3px; font-size: 12px; }}
            .auth-info {{ background: #e74c3c; color: white; padding: 15px; border-radius: 5px; margin: 20px 0; }}
            .token-change {{ background: #f39c12; color: white; padding: 15px; border-radius: 5px; margin: 20px 0; }}
            code {{ background: #2c3e50; color: #ecf0f1; padding: 2px 5px; border-radius: 3px; }}
            pre {{ background: #2c3e50; color: #ecf0f1; padding: 15px; border-radius: 5px; overflow-x: auto; }}
            .feature {{ background: #27ae60; color: white; padding: 10px; border-radius: 5px; margin: 5px 0; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 News Content API v2.0</h1>
            <p>Advanced News Content Extraction API với <strong>Newspaper4k</strong> và <strong>Random User Agents</strong></p>
            
            <div class="auth-info">
                <h3>🔐 Authentication Required</h3>
                <p>Tất cả API calls yêu cầu Bearer Token trong header:</p>
                <code>Authorization: Bearer YOUR_TOKEN_HERE</code>
                <p><strong>Lưu ý:</strong> Token đã được đặt trong quá trình cài đặt và không hiển thị ở đây vì lý do bảo mật.</p>
            </div>

            <div class="token-change">
                <h3>🔧 Đổi Bearer Token</h3>
                <p><strong>Cách 1:</strong> One-liner command</p>
                <pre>cd /home/n8n && sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN="NEW_TOKEN"/' docker-compose.yml && docker-compose restart fastapi</pre>
                
                <p><strong>Cách 2:</strong> Edit file trực tiếp</p>
                <pre>nano /home/n8n/docker-compose.yml
# Tìm dòng NEWS_API_TOKEN và thay đổi
docker-compose restart fastapi</pre>
            </div>
            
            <h2>✨ Tính Năng</h2>
            <div class="feature">📰 Cào nội dung bài viết từ bất kỳ website nào</div>
            <div class="feature">📡 Parse RSS feeds để lấy tin tức mới nhất</div>
            <div class="feature">🔍 Tìm kiếm và phân tích nội dung tự động</div>
            <div class="feature">🌍 Hỗ trợ 80+ ngôn ngữ (Việt, Anh, Trung, Nhật...)</div>
            <div class="feature">🎭 Random User Agents để tránh bị block</div>
            <div class="feature">🤖 Tích hợp trực tiếp vào N8N workflows</div>
            
            <h2>📖 API Endpoints</h2>
            
            <div class="endpoint">
                <span class="method">GET</span> <strong>/health</strong>
                <p>Kiểm tra trạng thái API</p>
            </div>
            
            <div class="endpoint">
                <span class="method">POST</span> <strong>/extract-article</strong>
                <p>Lấy nội dung bài viết từ URL</p>
                <pre>{{"url": "https://example.com/article", "language": "vi", "extract_images": true, "summarize": true}}</pre>
            </div>
            
            <div class="endpoint">
                <span class="method">POST</span> <strong>/extract-source</strong>
                <p>Cào nhiều bài viết từ website</p>
                <pre>{{"url": "https://dantri.com.vn", "max_articles": 10, "language": "vi"}}</pre>
            </div>
            
            <div class="endpoint">
                <span class="method">POST</span> <strong>/parse-feed</strong>
                <p>Phân tích RSS feeds</p>
                <pre>{{"url": "https://dantri.com.vn/rss.xml", "max_articles": 10}}</pre>
            </div>
            
            <h2>🔗 Documentation</h2>
            <p>
                <a href="/docs" target="_blank">📚 Swagger UI</a> | 
                <a href="/redoc" target="_blank">📖 ReDoc</a>
            </p>
            
            <h2>💻 Ví Dụ cURL</h2>
            <pre>curl -X POST "https://api.yourdomain.com/extract-article" \\
     -H "Content-Type: application/json" \\
     -H "Authorization: Bearer YOUR_TOKEN" \\
     -d '{{"url": "https://dantri.com.vn/the-gioi.htm", "language": "vi"}}'</pre>
            
            <hr style="margin: 30px 0;">
            <p style="text-align: center; color: #7f8c8d;">
                🚀 Powered by <strong>Newspaper4k</strong> | 
                👨‍💻 Created by <strong>Nguyễn Ngọc Thiện</strong> | 
                📺 <a href="https://www.youtube.com/@kalvinthiensocial">YouTube Channel</a>
            </p>
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
        "version": "2.0.0",
        "features": [
            "Article extraction",
            "Source crawling", 
            "RSS feed parsing",
            "Multi-language support",
            "Random User Agents",
            "Image extraction",
            "Keyword extraction",
            "Content summarization"
        ]
    }

@app.post("/extract-article", response_model=ArticleResponse)
async def extract_article(
    request: ArticleRequest,
    token: str = Depends(verify_token)
):
    """Extract content from a single article URL"""
    logger.info(f"Extracting article: {request.url}")
    return extract_article_content(
        str(request.url),
        request.language,
        request.extract_images,
        request.summarize
    )

@app.post("/extract-source", response_model=SourceResponse)
async def extract_source(
    request: SourceRequest,
    token: str = Depends(verify_token)
):
    """Extract multiple articles from a news source"""
    try:
        logger.info(f"Extracting source: {request.url}")
        
        config = create_newspaper_config(request.language)
        source = Source(str(request.url), config=config)
        source.build()
        
        # Limit articles
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
            categories=source.category_urls()[:10]  # Limit categories
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
        logger.info(f"Parsing feed: {request.url}")
        
        # Set random user agent for requests
        headers = {'User-Agent': get_random_user_agent()}
        
        # Parse feed
        feed = feedparser.parse(str(request.url), request_headers=headers)
        
        if feed.bozo:
            logger.warning(f"Feed parsing warning for {request.url}: {feed.bozo_exception}")
        
        # Extract articles
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
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF
    
    # Create Dockerfile for News API
    cat > "$INSTALL_DIR/news_api/Dockerfile" << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
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

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose port
EXPOSE 8000

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
EOF
    
    success "Đã tạo News Content API"
}

create_docker_compose() {
    log "🐳 Tạo docker-compose.yml..."
    
    # Determine ports based on mode
    local n8n_ports="127.0.0.1:5678:5678"
    local api_ports="127.0.0.1:8000:8000"
    
    if [[ "$LOCAL_MODE" == "true" ]]; then
        n8n_ports="5678:5678"
        api_ports="8000:8000"
    fi
    
    cat > "$INSTALL_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  n8n:
    build: .
    container_name: n8n-container
    restart: unless-stopped
    ports:
      - "${n8n_ports}"
    environment:
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - NODE_ENV=production
      - WEBHOOK_URL=$([[ "$LOCAL_MODE" == "true" ]] && echo "http://localhost:5678/" || echo "https://${DOMAIN}/")
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

    if [[ "$LOCAL_MODE" != "true" ]]; then
        cat >> "$INSTALL_DIR/docker-compose.yml" << EOF

  caddy:
    image: caddy:latest
    container_name: caddy-proxy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - n8n_network
    depends_on:
      - n8n
EOF
    fi

    if [[ "$ENABLE_NEWS_API" == "true" ]]; then
        cat >> "$INSTALL_DIR/docker-compose.yml" << EOF
$([[ "$LOCAL_MODE" != "true" ]] && echo "      - fastapi")

  fastapi:
    build: ./news_api
    container_name: news-api-container
    restart: unless-stopped
    ports:
      - "${api_ports}"
    environment:
      - NEWS_API_TOKEN=${BEARER_TOKEN}
      - PYTHONUNBUFFERED=1
    networks:
      - n8n_network
EOF
    fi

    cat >> "$INSTALL_DIR/docker-compose.yml" << 'EOF'

volumes:
EOF

    if [[ "$LOCAL_MODE" != "true" ]]; then
        cat >> "$INSTALL_DIR/docker-compose.yml" << 'EOF'
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
    cat > "$INSTALL_DIR/backup-workflows.sh" << 'EOF'
#!/bin/bash

# =============================================================================
# N8N BACKUP SCRIPT - Tự động backup workflows và credentials
# =============================================================================

set -e

BACKUP_DIR="/home/n8n/files/backup_full"
LOG_FILE="$BACKUP_DIR/backup.log"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="n8n_backup_$TIMESTAMP"
TEMP_DIR="/tmp/$BACKUP_NAME"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}" | tee -a "$LOG_FILE"
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
mkdir -p "$BACKUP_DIR"
mkdir -p "$TEMP_DIR"

log "🔄 Bắt đầu backup N8N..."

# Export workflows from N8N
log "📋 Export workflows..."
cd /home/n8n

# Create workflows directory
mkdir -p "$TEMP_DIR/workflows"

# Try to export workflows via N8N CLI (if available)
if docker exec n8n-container which n8n &> /dev/null; then
    docker exec n8n-container n8n export:workflow --all --output=/tmp/workflows.json 2>/dev/null || true
    docker cp n8n-container:/tmp/workflows.json "$TEMP_DIR/workflows/" 2>/dev/null || true
fi

# Backup database and encryption key
log "💾 Backup database và encryption key..."
mkdir -p "$TEMP_DIR/credentials"

# Copy database
if [[ -f "/home/n8n/files/database.sqlite" ]]; then
    cp "/home/n8n/files/database.sqlite" "$TEMP_DIR/credentials/"
elif [[ -f "/home/n8n/database.sqlite" ]]; then
    cp "/home/n8n/database.sqlite" "$TEMP_DIR/credentials/"
fi

# Copy encryption key
if [[ -f "/home/n8n/files/encryptionKey" ]]; then
    cp "/home/n8n/files/encryptionKey" "$TEMP_DIR/credentials/"
elif [[ -f "/home/n8n/encryptionKey" ]]; then
    cp "/home/n8n/encryptionKey" "$TEMP_DIR/credentials/"
fi

# Copy all files from .n8n directory
cp -r /home/n8n/files/* "$TEMP_DIR/credentials/" 2>/dev/null || true

# Backup config files
log "🔧 Backup config files..."
mkdir -p "$TEMP_DIR/config"
cp docker-compose.yml "$TEMP_DIR/config/" 2>/dev/null || true
cp Caddyfile "$TEMP_DIR/config/" 2>/dev/null || true

# Create metadata
log "📊 Tạo metadata..."
cat > "$TEMP_DIR/backup_metadata.json" << EOL
{
    "backup_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "backup_name": "$BACKUP_NAME",
    "n8n_version": "$(docker exec n8n-container n8n --version 2>/dev/null || echo 'unknown')",
    "backup_type": "full",
    "files": {
        "workflows": "$(find $TEMP_DIR/workflows -name "*.json" | wc -l) files",
        "database": "$(ls -la $TEMP_DIR/credentials/database.sqlite 2>/dev/null | awk '{print $5}' || echo '0') bytes",
        "config": "$(find $TEMP_DIR/config -name "*" | wc -l) files"
    }
}
EOL

# Create compressed backup
log "📦 Tạo file backup nén..."
cd /tmp
tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" "$BACKUP_NAME/"

# Get backup size
BACKUP_SIZE=$(ls -lh "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | awk '{print $5}')
log "✅ Backup hoàn thành: $BACKUP_NAME.tar.gz ($BACKUP_SIZE)"

# Cleanup temp directory
rm -rf "$TEMP_DIR"

# Keep only last 30 backups
log "🧹 Cleanup old backups..."
cd "$BACKUP_DIR"
ls -t n8n_backup_*.tar.gz | tail -n +31 | xargs -r rm -f

# Upload to Google Drive if configured
if command -v rclone &> /dev/null && rclone lsd gdrive: &>/dev/null; then
    log "☁️ Upload to Google Drive..."
    rclone copy "$BACKUP_DIR/$BACKUP_NAME.tar.gz" gdrive:N8N_Backups/
    
    # Cleanup old backups on Google Drive
    log "🧹 Cleanup old Google Drive backups..."
    rclone ls gdrive:N8N_Backups/ | grep "n8n_backup_.*\.tar\.gz" | sort -k2 -r | tail -n +31 | awk '{print $2}' | while read file; do
        rclone delete "gdrive:N8N_Backups/$file"
    done
fi

# Send to Telegram if configured
if [[ -f "/home/n8n/telegram_config.txt" ]]; then
    source "/home/n8n/telegram_config.txt"
    
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        log "📱 Gửi thông báo Telegram..."
        
        MESSAGE="🔄 *N8N Backup Completed*
        
📅 Date: $(date +'%Y-%m-%d %H:%M:%S')
📦 File: \`$BACKUP_NAME.tar.gz\`
💾 Size: $BACKUP_SIZE
📊 Status: ✅ Success

🗂️ Backup location: \`$BACKUP_DIR\`
☁️ Google Drive: $(command -v rclone &> /dev/null && echo "✅ Uploaded" || echo "❌ Not configured")"

        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$MESSAGE" \
            -d parse_mode="Markdown" > /dev/null || true
        
        # Send file if smaller than 20MB
        BACKUP_SIZE_BYTES=$(stat -c%s "$BACKUP_DIR/$BACKUP_NAME.tar.gz")
        if [[ $BACKUP_SIZE_BYTES -lt 20971520 ]]; then
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument" \
                -F chat_id="$TELEGRAM_CHAT_ID" \
                -F document="@$BACKUP_DIR/$BACKUP_NAME.tar.gz" \
                -F caption="📦 N8N Backup: $BACKUP_NAME.tar.gz" > /dev/null || true
        fi
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
    
    # Google Drive restore script
    if [[ "$ENABLE_GDRIVE" == "true" ]]; then
        cat > "$INSTALL_DIR/gdrive-restore.sh" << 'EOF'
#!/bin/bash

# =============================================================================
# GOOGLE DRIVE RESTORE SCRIPT
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
echo -e "${CYAN}║${WHITE}                    📦 GOOGLE DRIVE RESTORE TOOL                             ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check rclone
if ! command -v rclone &> /dev/null; then
    echo -e "${RED}❌ rclone không được cài đặt!${NC}"
    exit 1
fi

# Check Google Drive connection
if ! rclone lsd gdrive: &>/dev/null; then
    echo -e "${RED}❌ Không thể kết nối Google Drive!${NC}"
    echo -e "${YELLOW}Chạy lại script cài đặt để cấu hình Google Drive${NC}"
    exit 1
fi

echo -e "${BLUE}📋 Danh sách backup trên Google Drive:${NC}"
echo ""

# List backups
backups=$(rclone ls gdrive:N8N_Backups/ | grep "n8n_backup_.*\.tar\.gz" | sort -k2 -r)

if [[ -z "$backups" ]]; then
    echo -e "${RED}❌ Không tìm thấy backup nào trên Google Drive${NC}"
    exit 1
fi

# Display backups with numbers
echo "$backups" | head -20 | nl -w2 -s'. '
echo ""

# Get user choice
while true; do
    read -p "📦 Chọn số thứ tự backup để restore (1-20): " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le 20 ]]; then
        break
    else
        echo -e "${RED}Vui lòng nhập số từ 1-20${NC}"
    fi
done

# Get selected backup
selected_backup=$(echo "$backups" | head -20 | sed -n "${choice}p" | awk '{print $2}')

if [[ -z "$selected_backup" ]]; then
    echo -e "${RED}❌ Không thể lấy thông tin backup${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}📦 Đã chọn: $selected_backup${NC}"
echo ""

# Confirm restore
read -p "⚠️ Bạn có chắc chắn muốn restore? Dữ liệu hiện tại sẽ được backup trước (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Đã hủy restore"
    exit 0
fi

echo ""
echo -e "${GREEN}🔄 Bắt đầu restore process...${NC}"

# Backup current data
if [[ -d "/home/n8n/files" ]]; then
    echo "💾 Backup dữ liệu hiện tại..."
    mv "/home/n8n/files" "/home/n8n/files_backup_$(date +%s)"
fi

# Download backup
echo "⬇️ Download backup từ Google Drive..."
temp_file="/tmp/$selected_backup"
rclone copy "gdrive:N8N_Backups/$selected_backup" /tmp/

if [[ ! -f "$temp_file" ]]; then
    echo -e "${RED}❌ Không thể download backup${NC}"
    exit 1
fi

# Extract backup
echo "📂 Giải nén backup..."
temp_dir="/tmp/n8n_restore_$(date +%s)"
mkdir -p "$temp_dir"
tar -xzf "$temp_file" -C "$temp_dir" --strip-components=1

# Restore data
echo "🔄 Restore workflows và credentials..."
mkdir -p "/home/n8n/files"

if [[ -d "$temp_dir/credentials" ]]; then
    cp -r "$temp_dir/credentials/"* "/home/n8n/files/" 2>/dev/null || true
fi

if [[ -d "$temp_dir/workflows" ]]; then
    mkdir -p "/home/n8n/files/workflows"
    cp -r "$temp_dir/workflows/"* "/home/n8n/files/workflows/" 2>/dev/null || true
fi

# Set permissions
chown -R 1000:1000 "/home/n8n/files" 2>/dev/null || true

# Cleanup
rm -rf "$temp_dir" "$temp_file"

echo ""
echo -e "${GREEN}✅ Restore hoàn thành!${NC}"
echo -e "${YELLOW}🔄 Khởi động lại N8N container để áp dụng thay đổi:${NC}"
echo -e "${WHITE}cd /home/n8n && docker-compose restart n8n${NC}"
echo ""
EOF

        chmod +x "$INSTALL_DIR/gdrive-restore.sh"
    fi
    
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
elif docker ps | grep -q "news-api-container"; then
    log "✅ News API container đang chạy"
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
# TELEGRAM CONFIGURATION
# =============================================================================

setup_telegram_config() {
    if [[ "$ENABLE_TELEGRAM" != "true" ]]; then
        return 0
    fi
    
    log "📱 Thiết lập cấu hình Telegram..."
    
    cat > "$INSTALL_DIR/telegram_config.txt" << EOF
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"
EOF
    
    chmod 600 "$INSTALL_DIR/telegram_config.txt"
    
    # Test Telegram connection
    log "🧪 Test kết nối Telegram..."
    
    local mode_text="Domain Mode"
    if [[ "$LOCAL_MODE" == "true" ]]; then
        mode_text="Local Mode"
    fi
    
    TEST_MESSAGE="🚀 *N8N Installation Completed*

📅 Date: $(date +'%Y-%m-%d %H:%M:%S')
🏠 Mode: $mode_text
🌐 Domain: $DOMAIN
📰 API Domain: $API_DOMAIN
💾 Backup: Enabled
☁️ Google Drive: $([[ "$ENABLE_GDRIVE" == "true" ]] && echo "Enabled" || echo "Disabled")
🔄 Auto-update: $([[ "$ENABLE_AUTO_UPDATE" == "true" ]] && echo "Enabled" || echo "Disabled")

✅ System is ready!"

    if curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$TEST_MESSAGE" \
        -d parse_mode="Markdown" > /dev/null; then
        success "✅ Telegram test thành công"
    else
        warning "⚠️ Telegram test thất bại - kiểm tra lại Bot Token và Chat ID"
    fi
}

# =============================================================================
# CRON JOBS
# =============================================================================

setup_cron_jobs() {
    log "⏰ Thiết lập cron jobs..."
    
    # Remove existing cron jobs for n8n
    crontab -l 2>/dev/null | grep -v "/home/n8n" | crontab - 2>/dev/null || true
    
    # Add backup job (daily at 2:00 AM)
    (crontab -l 2>/dev/null; echo "0 2 * * * /home/n8n/backup-workflows.sh") | crontab -
    
    # Add auto-update job if enabled
    if [[ "$ENABLE_AUTO_UPDATE" == "true" ]]; then
        (crontab -l 2>/dev/null; echo "0 */12 * * * /home/n8n/update-n8n.sh") | crontab -
    fi
    
    success "Đã thiết lập cron jobs"
}

# =============================================================================
# SSL RATE LIMIT DETECTION
# =============================================================================

parse_ssl_retry_time() {
    local log_line="$1"
    
    # Extract retry time from log line
    local retry_time=$(echo "$log_line" | grep -oP 'retry after \K[0-9-]+ [0-9:]+' | head -1)
    
    if [[ -n "$retry_time" ]]; then
        # Convert UTC to Vietnam time
        local utc_time="$retry_time UTC"
        local vn_time=$(TZ='Asia/Ho_Chi_Minh' date -d "$utc_time" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")
        
        if [[ -n "$vn_time" ]]; then
            echo "$vn_time"
        else
            echo "Không xác định được"
        fi
    else
        echo "Không xác định được"
    fi
}

check_ssl_rate_limit() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        return 0
    fi
    
    log "🔒 Kiểm tra SSL certificate..."
    
    # Wait for containers to start
    sleep 30
    
    # Get Caddy logs
    local caddy_logs=$($DOCKER_COMPOSE logs caddy 2>/dev/null || echo "")
    
    # Check for different SSL states
    local rate_limit_detected=false
    local ssl_success=false
    local ssl_error=false
    local retry_time=""
    
    if echo "$caddy_logs" | grep -q "certificate obtained successfully"; then
        ssl_success=true
    fi
    
    if echo "$caddy_logs" | grep -q "rateLimited\|too many certificates"; then
        rate_limit_detected=true
        # Get the latest retry time
        retry_time=$(echo "$caddy_logs" | grep "retry after" | tail -1 | parse_ssl_retry_time)
    fi
    
    if echo "$caddy_logs" | grep -q "error.*certificate\|failed.*certificate" && [[ "$ssl_success" != "true" ]]; then
        ssl_error=true
    fi
    
    if [[ "$rate_limit_detected" == "true" ]]; then
        error "🚨 PHÁT HIỆN SSL RATE LIMIT!"
        echo ""
        echo -e "${RED}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║${WHITE}                        ⚠️  SSL RATE LIMIT DETECTED                          ${RED}║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}🔍 NGUYÊN NHÂN:${NC}"
        echo -e "  • Let's Encrypt giới hạn 5 certificates/domain/tuần"
        echo -e "  • Domain này đã đạt giới hạn miễn phí"
        echo -e "  • Cần đợi đến tuần sau để cấp SSL mới"
        echo ""
        echo -e "${YELLOW}💡 GIẢI PHÁP:${NC}"
        echo -e "  ${GREEN}1. CÀI LẠI UBUNTU (KHUYẾN NGHỊ):${NC}"
        echo -e "     • Cài lại Ubuntu Server hoàn toàn"
        echo -e "     • Sử dụng subdomain khác (vd: n8n2.domain.com)"
        echo -e "     • Chạy lại script này"
        echo ""
        echo -e "  ${GREEN}2. SỬ DỤNG STAGING SSL (TẠM THỜI):${NC}"
        echo -e "     • Website sẽ hiển thị 'Not Secure' nhưng vẫn hoạt động"
        echo -e "     • Chức năng N8N và API hoạt động đầy đủ"
        echo -e "     • Có thể chuyển về production SSL sau khi rate limit reset"
        echo ""
        echo -e "  ${GREEN}3. ĐỢI ĐẾN KHI RATE LIMIT RESET:${NC}"
        if [[ -n "$retry_time" && "$retry_time" != "Không xác định được" ]]; then
            echo -e "     • Đợi đến sau ${WHITE}$retry_time (Giờ VN)${NC}"
        else
            echo -e "     • Đợi 7 ngày kể từ lần thử SSL cuối cùng"
        fi
        echo -e "     • Chạy lại script để cấp SSL mới"
        echo ""
        
        echo -e "${YELLOW}📋 LỊCH SỬ SSL ATTEMPTS GẦN ĐÂY:${NC}"
        echo "$caddy_logs" | grep -E "(error|rateLimited|certificate)" | tail -5 | while read line; do
            echo "• $line"
        done
        echo ""
        
        # Multiple choice menu
        echo -e "${CYAN}🤔 Bạn muốn làm gì tiếp theo?${NC}"
        echo -e "  ${WHITE}1.${NC} Tiếp tục với Staging SSL (tạm thời)"
        echo -e "  ${WHITE}2.${NC} Dừng cài đặt và cài lại Ubuntu"
        echo -e "  ${WHITE}3.${NC} Dừng cài đặt và đợi rate limit reset"
        echo ""
        
        while true; do
            read -p "Chọn tùy chọn (1/2/3): " ssl_choice
            case $ssl_choice in
                1)
                    setup_staging_ssl
                    break
                    ;;
                2)
                    echo ""
                    echo -e "${CYAN}📋 HƯỚNG DẪN CÀI LẠI UBUNTU:${NC}"
                    echo -e "  1. Backup dữ liệu quan trọng"
                    echo -e "  2. Cài lại Ubuntu Server từ đầu"
                    echo -e "  3. Sử dụng subdomain khác hoặc domain khác"
                    echo -e "  4. Chạy lại script: curl -sSL https://raw.githubusercontent.com/KalvinThien/install-n8n-ffmpeg/main/auto_cai_dat_n8n.sh | bash"
                    echo ""
                    exit 1
                    ;;
                3)
                    echo ""
                    echo -e "${YELLOW}⏰ Thời gian đợi rate limit reset:${NC}"
                    if [[ -n "$retry_time" && "$retry_time" != "Không xác định được" ]]; then
                        echo -e "  • Đợi đến sau: ${WHITE}$retry_time (Giờ VN)${NC}"
                    else
                        echo -e "  • Đợi ít nhất 7 ngày từ lần thử cuối"
                    fi
                    echo -e "  • Sau đó chạy lại script để cấp SSL production"
                    echo ""
                    exit 1
                    ;;
                *)
                    error "Vui lòng chọn 1, 2 hoặc 3"
                    ;;
            esac
        done
        
    elif [[ "$ssl_success" == "true" ]]; then
        success "✅ SSL certificate đã được cấp thành công"
        
        # Test SSL after a short wait
        sleep 60
        if curl -I "https://$DOMAIN" &>/dev/null; then
            success "✅ SSL certificate hoạt động bình thường"
        else
            warning "⚠️ SSL có thể chưa sẵn sàng - đợi thêm vài phút"
        fi
        
    elif [[ "$ssl_error" == "true" ]]; then
        warning "⚠️ Có lỗi SSL nhưng không phải rate limit"
        echo ""
        echo -e "${YELLOW}📋 SSL Error Logs:${NC}"
        echo "$caddy_logs" | grep -E "error.*certificate" | tail -3
        echo ""
        
        read -p "🤔 Bạn có muốn tiếp tục với Staging SSL? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            setup_staging_ssl
        fi
        
    else
        info "🔄 SSL đang được xử lý..."
        sleep 60
        
        # Check again after waiting
        if curl -I "https://$DOMAIN" &>/dev/null; then
            success "✅ SSL certificate hoạt động bình thường"
        else
            warning "⚠️ SSL có thể chưa sẵn sàng - kiểm tra lại sau vài phút"
        fi
    fi
}

setup_staging_ssl() {
    warning "🔧 Thiết lập Staging SSL..."
    
    # Stop containers
    $DOCKER_COMPOSE down
    
    # Remove SSL volumes
    docker volume rm n8n_caddy_data n8n_caddy_config 2>/dev/null || true
    
    # Update Caddyfile for staging
    cat > "$INSTALL_DIR/Caddyfile" << EOF
{
    email admin@${DOMAIN}
    acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
    debug
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
    
    log {
        output file /var/log/caddy/api.log
        format json
    }
}
EOF
    fi
    
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
    
    # Stop old containers first
    log "🛑 Dừng containers cũ..."
    $DOCKER_COMPOSE down --remove-orphans 2>/dev/null || true
    
    # Build images
    log "📦 Build Docker images..."
    $DOCKER_COMPOSE build --no-cache
    
    # Start services
    log "🚀 Khởi động services..."
    $DOCKER_COMPOSE up -d
    
    # Wait for services
    log "⏳ Đợi services khởi động..."
    sleep 30
    
    # Check container status
    log "🔍 Kiểm tra trạng thái containers..."
    if $DOCKER_COMPOSE ps | grep -q "Up"; then
        success "✅ Containers đã khởi động thành công"
    else
        error "❌ Có lỗi khi khởi động containers"
        $DOCKER_COMPOSE logs
        exit 1
    fi
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

echo -e "${BLUE}📍 2. Container Status:${NC}"
$DOCKER_COMPOSE ps
echo ""

echo -e "${BLUE}📍 3. Docker Images:${NC}"
docker images | grep -E "(n8n|caddy|news-api)"
echo ""

echo -e "${BLUE}📍 4. Network Status:${NC}"
echo "• Port 80: $(netstat -tulpn | grep :80 | wc -l) connections"
echo "• Port 443: $(netstat -tulpn | grep :443 | wc -l) connections"
echo "• Port 5678: $(netstat -tulpn | grep :5678 | wc -l) connections"
echo "• Port 8000: $(netstat -tulpn | grep :8000 | wc -l) connections"
echo "• Docker Networks:"
docker network ls | grep n8n
echo ""

echo -e "${BLUE}📍 5. SSL Certificate Status:${NC}"
if [[ -f "Caddyfile" ]]; then
    DOMAIN=$(grep -E "^[a-zA-Z0-9.-]+\s*{" Caddyfile | head -1 | awk '{print $1}')
    if [[ -n "$DOMAIN" && "$DOMAIN" != "localhost" ]]; then
        echo "• Domain: $DOMAIN"
        echo "• DNS Resolution: $(dig +short $DOMAIN A | tail -1)"
        echo "• SSL Test:"
        timeout 10 curl -I https://$DOMAIN 2>/dev/null | head -3 || echo "  SSL not ready"
    else
        echo "• Local Mode - No SSL needed"
    fi
else
    echo "• No Caddyfile found"
fi
echo ""

echo -e "${BLUE}📍 6. Recent Logs (last 10 lines):${NC}"
echo -e "${YELLOW}N8N Logs:${NC}"
$DOCKER_COMPOSE logs --tail=10 n8n 2>/dev/null || echo "No N8N logs"
echo ""

if docker ps | grep -q "caddy-proxy"; then
    echo -e "${YELLOW}Caddy Logs:${NC}"
    $DOCKER_COMPOSE logs --tail=10 caddy 2>/dev/null || echo "No Caddy logs"
    echo ""
fi

if docker ps | grep -q "news-api"; then
    echo -e "${YELLOW}News API Logs:${NC}"
    $DOCKER_COMPOSE logs --tail=10 fastapi 2>/dev/null || echo "No News API logs"
    echo ""
fi

echo -e "${BLUE}📍 7. Backup Status:${NC}"
if [[ -d "/home/n8n/files/backup_full" ]]; then
    BACKUP_COUNT=$(ls -1 /home/n8n/files/backup_full/n8n_backup_*.tar.gz 2>/dev/null | wc -l)
    echo "• Local backups: $BACKUP_COUNT"
    if [[ $BACKUP_COUNT -gt 0 ]]; then
        echo "• Latest backup: $(ls -t /home/n8n/files/backup_full/n8n_backup_*.tar.gz | head -1 | xargs basename)"
        echo "• Latest backup size: $(ls -lh /home/n8n/files/backup_full/n8n_backup_*.tar.gz | head -1 | awk '{print $5}')"
    fi
else
    echo "• No backup directory found"
fi

# Check Google Drive
if command -v rclone &> /dev/null && rclone lsd gdrive: &>/dev/null; then
    GDRIVE_COUNT=$(rclone ls gdrive:N8N_Backups/ | grep "n8n_backup_.*\.tar\.gz" | wc -l)
    echo "• Google Drive backups: $GDRIVE_COUNT"
else
    echo "• Google Drive: Not configured"
fi
echo ""

echo -e "${BLUE}📍 8. Cron Jobs:${NC}"
crontab -l 2>/dev/null | grep -E "(n8n|backup)" || echo "• No N8N cron jobs found"
echo ""

echo -e "${GREEN}🔧 QUICK FIX COMMANDS:${NC}"
echo -e "${YELLOW}• Restart all services:${NC} cd /home/n8n && $DOCKER_COMPOSE restart"
echo -e "${YELLOW}• View live logs:${NC} cd /home/n8n && $DOCKER_COMPOSE logs -f"
echo -e "${YELLOW}• Rebuild containers:${NC} cd /home/n8n && $DOCKER_COMPOSE down && $DOCKER_COMPOSE up -d --build"
echo -e "${YELLOW}• Manual backup:${NC} /home/n8n/backup-manual.sh"
if [[ -n "$DOMAIN" && "$DOMAIN" != "localhost" ]]; then
    echo -e "${YELLOW}• Check SSL:${NC} curl -I https://$DOMAIN"
fi
if [[ -f "/home/n8n/gdrive-restore.sh" ]]; then
    echo -e "${YELLOW}• Google Drive restore:${NC} /home/n8n/gdrive-restore.sh"
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
    echo -e "${GREEN}║${WHITE}                    🎉 N8N ĐÃ ĐƯỢC CÀI ĐẶT THÀNH CÔNG!                      ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}🌐 TRUY CẬP DỊCH VỤ:${NC}"
    if [[ "$LOCAL_MODE" == "true" ]]; then
        echo -e "  • N8N: ${WHITE}http://localhost:5678${NC}"
        if [[ "$ENABLE_NEWS_API" == "true" ]]; then
            echo -e "  • News API: ${WHITE}http://localhost:8000${NC}"
            echo -e "  • API Docs: ${WHITE}http://localhost:8000/docs${NC}"
        fi
    else
        echo -e "  • N8N: ${WHITE}https://${DOMAIN}${NC}"
        if [[ "$ENABLE_NEWS_API" == "true" ]]; then
            echo -e "  • News API: ${WHITE}https://${API_DOMAIN}${NC}"
            echo -e "  • API Docs: ${WHITE}https://${API_DOMAIN}/docs${NC}"
        fi
    fi
    
    if [[ "$ENABLE_NEWS_API" == "true" ]]; then
        echo -e "  • Bearer Token: ${YELLOW}Đã được đặt (không hiển thị vì bảo mật)${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}📁 THÔNG TIN HỆ THỐNG:${NC}"
    echo -e "  • Chế độ: ${WHITE}$([[ "$LOCAL_MODE" == "true" ]] && echo "Local Mode" || echo "Domain Mode")${NC}"
    echo -e "  • Thư mục cài đặt: ${WHITE}${INSTALL_DIR}${NC}"
    echo -e "  • Script chẩn đoán: ${WHITE}${INSTALL_DIR}/troubleshoot.sh${NC}"
    echo -e "  • Test backup: ${WHITE}${INSTALL_DIR}/backup-manual.sh${NC}"
    if [[ "$ENABLE_GDRIVE" == "true" ]]; then
        echo -e "  • Google Drive restore: ${WHITE}${INSTALL_DIR}/gdrive-restore.sh${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}💾 CẤU HÌNH BACKUP:${NC}"
    local swap_info=$(swapon --show | grep -v NAME | awk '{print $3}' | head -1)
    echo -e "  • Swap: ${WHITE}${swap_info:-"Không có"}${NC}"
    echo -e "  • Auto-update: ${WHITE}$([[ "$ENABLE_AUTO_UPDATE" == "true" ]] && echo "Enabled (mỗi 12h)" || echo "Disabled")${NC}"
    echo -e "  • Telegram backup: ${WHITE}$([[ "$ENABLE_TELEGRAM" == "true" ]] && echo "Enabled" || echo "Disabled")${NC}"
    echo -e "  • Google Drive backup: ${WHITE}$([[ "$ENABLE_GDRIVE" == "true" ]] && echo "Enabled" || echo "Disabled")${NC}"
    echo -e "  • Backup tự động: ${WHITE}Hàng ngày lúc 2:00 AM${NC}"
    echo -e "  • Backup location: ${WHITE}${INSTALL_DIR}/files/backup_full/${NC}"
    echo ""
    
    if [[ "$ENABLE_NEWS_API" == "true" ]]; then
        echo -e "${CYAN}🔧 ĐỔI BEARER TOKEN:${NC}"
        echo -e "  ${WHITE}cd /home/n8n && sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN=\"NEW_TOKEN\"/' docker-compose.yml && $DOCKER_COMPOSE restart fastapi${NC}"
        echo ""
    fi
    
    if [[ "$RESTORE_MODE" == "true" ]]; then
        echo -e "${CYAN}📦 RESTORE COMPLETED:${NC}"
        echo -e "  • Dữ liệu đã được restore từ backup"
        echo -e "  • Workflows và credentials đã được khôi phục"
        echo -e "  • Khởi động lại container để áp dụng thay đổi"
        echo ""
    fi
    
    echo -e "${CYAN}🚀 TÁC GIẢ:${NC}"
    echo -e "  • Tên: ${WHITE}Nguyễn Ngọc Thiện${NC}"
    echo -e "  • YouTube: ${WHITE}https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1${NC}"
    echo -e "  • Zalo: ${WHITE}08.8888.4749${NC}"
    echo -e "  • Cập nhật: ${WHITE}30/06/2025${NC}"
    echo ""
    
    echo -e "${YELLOW}🎬 ĐĂNG KÝ KÊNH YOUTUBE ĐỂ ỦNG HỘ MÌNH NHÉ! 🔔${NC}"
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
    get_installation_mode
    get_restore_option
    get_domain_input
    get_cleanup_option
    get_news_api_config
    get_telegram_config
    get_gdrive_config
    get_auto_update_config
    
    # Verify DNS
    verify_dns
    
    # Cleanup old installation
    cleanup_old_installation
    
    # Install Docker
    install_docker
    
    # Setup Google Drive
    setup_gdrive
    
    # Create project structure
    create_project_structure
    
    # Restore from backup if requested
    restore_from_backup
    
    # Create configuration files
    create_dockerfile
    create_news_api
    create_docker_compose
    create_caddyfile
    
    # Create scripts
    create_backup_scripts
    create_update_script
    create_troubleshooting_script
    
    # Setup Telegram
    setup_telegram_config
    
    # Setup cron jobs
    setup_cron_jobs
    
    # Build and deploy
    build_and_deploy
    
    # Check SSL and rate limits
    check_ssl_rate_limit
    
    # Show final summary
    show_final_summary
}

# Run main function
main "$@"
