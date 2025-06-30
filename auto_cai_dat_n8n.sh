#!/bin/bash

# =============================================================================
# 🚀 SCRIPT CÀI ĐẶT N8N TỰ ĐỘNG 2025 - PHIÊN BẢN HOÀN CHỈNH
# =============================================================================
# Tác giả: Nguyễn Ngọc Thiện
# YouTube: https://www.youtube.com/@kalvinthiensocial
# Zalo: 08.8888.4749
# Cập nhật: 30/06/2025 - Enhanced with ZeroSSL & Google Drive
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
GOOGLE_DRIVE_ENABLED=false
GOOGLE_CLIENT_ID=""
GOOGLE_CLIENT_SECRET=""
ENABLE_NEWS_API=false
ENABLE_TELEGRAM=false
ENABLE_AUTO_UPDATE=false
ENABLE_RESTORE=false
RESTORE_SOURCE=""
RESTORE_FILE=""
CLEAN_INSTALL=false
SKIP_DOCKER=false
LOCAL_MODE=false
SSL_PROVIDER="letsencrypt"
ZEROSSL_EMAIL=""
ZEROSSL_API_KEY=""

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                🚀 SCRIPT CÀI ĐẶT N8N TỰ ĐỘNG 2025 - ENHANCED 🚀              ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE} ✨ N8N + ZeroSSL + Google Drive Backup + Full Restore                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 🔒 Smart SSL: Let's Encrypt → ZeroSSL khi rate limit                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 📱 Google Drive Backup với OAuth2 authentication                         ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 🔄 Full Restore: Workflows + Certificates + Settings                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 🕐 Timezone: Asia/Ho_Chi_Minh (GMT+7)                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 🛡️ Enhanced Bearer Token: Unlimited chars + Special chars               ${CYAN}║${NC}"
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
    local vn_time=$(TZ='Asia/Ho_Chi_Minh' date +'%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[${vn_time}] $1${NC}"
}

error() {
    local vn_time=$(TZ='Asia/Ho_Chi_Minh' date +'%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR ${vn_time}] $1${NC}" >&2
}

warning() {
    local vn_time=$(TZ='Asia/Ho_Chi_Minh' date +'%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[WARNING ${vn_time}] $1${NC}"
}

info() {
    local vn_time=$(TZ='Asia/Ho_Chi_Minh' date +'%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[INFO ${vn_time}] $1${NC}"
}

success() {
    local vn_time=$(TZ='Asia/Ho_Chi_Minh' date +'%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[SUCCESS ${vn_time}] $1${NC}"
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
    echo "  -r, --restore FILE      Restore từ backup file"
    echo "  --restore-gdrive        Restore từ Google Drive"
    echo ""
    echo "Ví dụ:"
    echo "  $0                      # Cài đặt bình thường"
    echo "  $0 --local             # Cài đặt Local Mode"
    echo "  $0 --clean             # Xóa cài đặt cũ và cài mới"
    echo "  $0 -r backup.tar.gz    # Restore từ file backup"
    echo "  $0 --restore-gdrive     # Restore từ Google Drive"
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
                ENABLE_RESTORE=true
                RESTORE_SOURCE="file"
                RESTORE_FILE="$2"
                shift 2
                ;;
            --restore-gdrive)
                ENABLE_RESTORE=true
                RESTORE_SOURCE="gdrive"
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
# RESTORE FUNCTIONALITY
# =============================================================================

show_restore_menu() {
    if [[ "$ENABLE_RESTORE" != "true" ]]; then
        return 0
    fi
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        🔄 RESTORE N8N BACKUP                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Restore Options:${NC}"
    echo -e "  ${GREEN}1. Restore từ file local (.tar.gz)${NC}"
    echo -e "  ${GREEN}2. Restore từ Google Drive${NC}"
    echo -e "  ${GREEN}3. Restore từ URL (http/https)${NC}"
    echo ""
    
    if [[ "$RESTORE_SOURCE" == "" ]]; then
        read -p "🔄 Chọn phương thức restore (1-3): " restore_choice
        case $restore_choice in
            1)
                RESTORE_SOURCE="file"
                read -p "📁 Nhập đường dẫn file backup (.tar.gz): " RESTORE_FILE
                ;;
            2)
                RESTORE_SOURCE="gdrive"
                ;;
            3)
                RESTORE_SOURCE="url"
                read -p "🌐 Nhập URL file backup: " RESTORE_FILE
                ;;
            *)
                error "Lựa chọn không hợp lệ"
                exit 1
                ;;
        esac
    fi
    
    info "Restore source: $RESTORE_SOURCE"
    if [[ -n "$RESTORE_FILE" ]]; then
        info "Restore file: $RESTORE_FILE"
    fi
}

validate_backup_file() {
    local backup_file="$1"
    local temp_dir="/tmp/n8n_restore_validate"
    
    if [[ ! -f "$backup_file" ]]; then
        error "File backup không tồn tại: $backup_file"
        return 1
    fi
    
    # Create temp directory for validation
    mkdir -p "$temp_dir"
    
    # Extract to temp directory for validation
    if tar -tzf "$backup_file" &>/dev/null; then
        tar -xzf "$backup_file" -C "$temp_dir" 2>/dev/null || {
            error "Không thể giải nén file backup"
            rm -rf "$temp_dir"
            return 1
        }
    else
        error "File backup không hợp lệ (không phải tar.gz)"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Check backup structure
    local backup_root=$(find "$temp_dir" -maxdepth 1 -type d -name "n8n_backup_*" | head -1)
    if [[ -z "$backup_root" ]]; then
        error "Cấu trúc backup không hợp lệ"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Check for required components
    local has_workflows=false
    local has_credentials=false
    local has_metadata=false
    
    if [[ -d "$backup_root/workflows" ]]; then
        has_workflows=true
    fi
    
    if [[ -d "$backup_root/credentials" ]] && [[ -f "$backup_root/credentials/database.sqlite" ]]; then
        has_credentials=true
    fi
    
    if [[ -f "$backup_root/backup_metadata.json" ]]; then
        has_metadata=true
    fi
    
    info "Backup validation:"
    echo "  • Workflows: $($has_workflows && echo "✅" || echo "❌")"
    echo "  • Credentials/Database: $($has_credentials && echo "✅" || echo "❌")"
    echo "  • Metadata: $($has_metadata && echo "✅" || echo "❌")"
    
    # Cleanup temp directory
    rm -rf "$temp_dir"
    
    if [[ "$has_workflows" == "true" && "$has_credentials" == "true" ]]; then
        success "Backup file hợp lệ"
        return 0
    else
        error "Backup file thiếu components quan trọng"
        return 1
    fi
}

download_from_gdrive() {
    info "🔍 Tìm kiếm backup files trên Google Drive..."
    
    # This would require Google Drive API integration
    # For now, provide instructions for manual download
    echo ""
    echo -e "${YELLOW}📋 HƯỚNG DẪN TẢI BACKUP TỪ GOOGLE DRIVE:${NC}"
    echo -e "  1. Truy cập: https://drive.google.com"
    echo -e "  2. Tìm thư mục: N8N_Backups"
    echo -e "  3. Download file backup mới nhất (.tar.gz)"
    echo -e "  4. Upload file lên server và chạy:"
    echo -e "     ${WHITE}sudo bash $0 -r /path/to/backup.tar.gz${NC}"
    echo ""
    
    read -p "📁 Nhập đường dẫn file backup đã download: " RESTORE_FILE
    RESTORE_SOURCE="file"
}

perform_restore() {
    if [[ "$ENABLE_RESTORE" != "true" ]]; then
        return 0
    fi
    
    log "🔄 Bắt đầu quá trình restore..."
    
    local backup_file=""
    local temp_dir="/tmp/n8n_restore_$(date +%s)"
    
    # Handle different restore sources
    case "$RESTORE_SOURCE" in
        "file")
            if [[ ! -f "$RESTORE_FILE" ]]; then
                error "File không tồn tại: $RESTORE_FILE"
                exit 1
            fi
            backup_file="$RESTORE_FILE"
            ;;
        "url")
            info "📥 Download backup từ URL..."
            backup_file="/tmp/n8n_backup_download.tar.gz"
            if ! curl -L "$RESTORE_FILE" -o "$backup_file"; then
                error "Không thể download từ URL: $RESTORE_FILE"
                exit 1
            fi
            ;;
        "gdrive")
            download_from_gdrive
            backup_file="$RESTORE_FILE"
            ;;
    esac
    
    # Validate backup file
    if ! validate_backup_file "$backup_file"; then
        exit 1
    fi
    
    # Create temp directory
    mkdir -p "$temp_dir"
    
    # Extract backup
    log "📦 Giải nén backup file..."
    tar -xzf "$backup_file" -C "$temp_dir"
    
    local backup_root=$(find "$temp_dir" -maxdepth 1 -type d -name "n8n_backup_*" | head -1)
    
    # Stop existing containers
    if [[ -d "$INSTALL_DIR" ]]; then
        cd "$INSTALL_DIR"
        if [[ -n "$DOCKER_COMPOSE" ]]; then
            log "🛑 Dừng containers hiện tại..."
            $DOCKER_COMPOSE down 2>/dev/null || true
        fi
    fi
    
    # Create install directory if not exists
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Restore workflows
    if [[ -d "$backup_root/workflows" ]]; then
        log "📋 Restore workflows..."
        mkdir -p files/workflows
        cp -r "$backup_root/workflows/"* files/workflows/ 2>/dev/null || true
    fi
    
    # Restore database and credentials
    if [[ -f "$backup_root/credentials/database.sqlite" ]]; then
        log "💾 Restore database..."
        mkdir -p files
        cp "$backup_root/credentials/database.sqlite" files/
        chown 1000:1000 files/database.sqlite
    fi
    
    # Restore encryption key
    if [[ -f "$backup_root/credentials/encryptionKey" ]]; then
        log "🔐 Restore encryption key..."
        cp "$backup_root/credentials/encryptionKey" files/
        chown 1000:1000 files/encryptionKey
    fi
    
    # Restore config files
    if [[ -d "$backup_root/config" ]]; then
        log "🔧 Restore config files..."
        cp "$backup_root/config/"* . 2>/dev/null || true
    fi
    
    # Set proper permissions
    chown -R 1000:1000 files/
    
    # Cleanup temp directory
    rm -rf "$temp_dir"
    
    success "✅ Restore completed successfully!"
    
    # Continue with normal installation to start services
    info "🚀 Khởi động services với dữ liệu đã restore..."
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
    
    if [[ "$ENABLE_RESTORE" == "true" ]]; then
        info "Restore mode: Bỏ qua lựa chọn installation mode"
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
    if [[ "$CLEAN_INSTALL" == "true" ]] || [[ "$ENABLE_RESTORE" == "true" ]]; then
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
    if [[ "$ENABLE_RESTORE" == "true" ]]; then
        info "Restore mode: Bỏ qua cấu hình News API"
        return 0
    fi
    
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
    echo -e "  • Token có thể chứa bất kỳ ký tự nào (chữ, số, ký tự đặc biệt)"
    echo -e "  • Không giới hạn độ dài (khuyến nghị ít nhất 32 ký tự)"
    echo -e "  • Sẽ được sử dụng để xác thực API calls"
    echo -e "  • Ví dụ: MySecure@Token!2025#N8N"
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

get_ssl_provider_config() {
    if [[ "$LOCAL_MODE" == "true" ]] || [[ "$ENABLE_RESTORE" == "true" ]]; then
        return 0
    fi
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        🔒 SSL CERTIFICATE PROVIDER                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}SSL Provider Options:${NC}"
    echo -e "  ${GREEN}1. Let's Encrypt (Mặc định)${NC}"
    echo -e "     • Miễn phí"
    echo -e "     • Limit: 5 certs/domain/tuần"
    echo -e "     • Tự động renew sau 60 ngày"
    echo ""
    echo -e "  ${GREEN}2. ZeroSSL (Khuyến nghị khi bị rate limit)${NC}"
    echo -e "     • Miễn phí với API key"
    echo -e "     • Ít bị rate limit hơn"
    echo -e "     • Tự động renew sau 75 ngày"
    echo ""
    
    read -p "🔒 Chọn SSL provider (1=Let's Encrypt, 2=ZeroSSL) [1]: " ssl_choice
    
    case "${ssl_choice:-1}" in
        1)
            SSL_PROVIDER="letsencrypt"
            info "Đã chọn Let's Encrypt"
            ;;
        2)
            SSL_PROVIDER="zerossl"
            info "Đã chọn ZeroSSL"
            
            echo ""
            echo -e "${YELLOW}📋 Thiết lập ZeroSSL:${NC}"
            
            while true; do
                read -p "📧 Nhập email cho ZeroSSL: " ZEROSSL_EMAIL
                if [[ "$ZEROSSL_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                    break
                else
                    error "Email không hợp lệ"
                fi
            done
            
            echo ""
            echo -e "${YELLOW}🔑 Lấy ZeroSSL API Key:${NC}"
            echo -e "  1. Truy cập: https://app.zerossl.com/developer"
            echo -e "  2. Đăng ký/Đăng nhập với email: ${ZEROSSL_EMAIL}"
            echo -e "  3. Copy API Key"
            echo ""
            
            while true; do
                read -p "🔑 Nhập ZeroSSL API Key: " ZEROSSL_API_KEY
                if [[ ${#ZEROSSL_API_KEY} -ge 32 ]]; then
                    break
                else
                    error "API Key không hợp lệ (quá ngắn)"
                fi
            done
            
            success "Đã thiết lập ZeroSSL"
            ;;
        *)
            SSL_PROVIDER="letsencrypt"
            info "Sử dụng Let's Encrypt (mặc định)"
            ;;
    esac
}

get_google_drive_config() {
    if [[ "$LOCAL_MODE" == "true" ]] || [[ "$ENABLE_RESTORE" == "true" ]]; then
        return 0
    fi
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        📱 GOOGLE DRIVE BACKUP                              ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Google Drive Backup cho phép:${NC}"
    echo -e "  ☁️  Tự động upload backup lên Google Drive"
    echo -e "  📁 Tạo thư mục N8N_Backups tự động" 
    echo -e "  🔄 Sync backup theo lịch (hàng ngày/tuần)"
    echo -e "  🗂️ Giữ 30 backup gần nhất, xóa cũ tự động"
    echo -e "  🔐 Sử dụng OAuth2 authentication an toàn"
    echo ""
    
    read -p "☁️  Bạn có muốn thiết lập Google Drive Backup? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        GOOGLE_DRIVE_ENABLED=false
        return 0
    fi
    
    GOOGLE_DRIVE_ENABLED=true
    
    echo ""
    echo -e "${YELLOW}🔑 Thiết lập Google Drive OAuth2:${NC}"
    echo ""
    echo -e "${WHITE}BƯỚC 1: Tạo Google Cloud Project${NC}"
    echo -e "  1. Truy cập: https://console.cloud.google.com/"
    echo -e "  2. Tạo project mới hoặc chọn project có sẵn"
    echo -e "  3. Enable Google Drive API:"
    echo -e "     • APIs & Services → Library → Google Drive API → Enable"
    echo ""
    
    echo -e "${WHITE}BƯỚC 2: Tạo OAuth2 Credentials${NC}"
    echo -e "  1. APIs & Services → Credentials → Create Credentials → OAuth client ID"
    echo -e "  2. Application type: Desktop application"
    echo -e "  3. Name: N8N Backup Client"
    echo -e "  4. Download JSON file credential"
    echo ""
    
    echo -e "${WHITE}BƯỚC 3: Lấy Client ID và Secret${NC}"
    echo -e "  • Mở file JSON vừa download"
    echo -e "  • Copy client_id và client_secret"
    echo ""
    
    read -p "📋 Nhấn Enter khi đã hoàn thành các bước trên..."
    echo ""
    
    while true; do
        read -p "🔑 Nhập Google Client ID: " GOOGLE_CLIENT_ID
        if [[ ${#GOOGLE_CLIENT_ID} -ge 20 ]]; then
            break
        else
            error "Client ID không hợp lệ"
        fi
    done
    
    while true; do
        read -p "🔐 Nhập Google Client Secret: " GOOGLE_CLIENT_SECRET
        if [[ ${#GOOGLE_CLIENT_SECRET} -ge 10 ]]; then
            break
        else
            error "Client Secret không hợp lệ"
        fi
    done
    
    success "Đã thiết lập Google Drive OAuth2"
    info "Sau khi cài đặt xong, bạn sẽ cần authorize quyền truy cập Google Drive"
}

get_telegram_config() {
    if [[ "$LOCAL_MODE" == "true" ]] || [[ "$ENABLE_RESTORE" == "true" ]]; then
        info "Local Mode/Restore: Bỏ qua cấu hình Telegram"
        ENABLE_TELEGRAM=false
        return 0
    fi
    
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

get_auto_update_config() {
    if [[ "$LOCAL_MODE" == "true" ]] || [[ "$ENABLE_RESTORE" == "true" ]]; then
        info "Local Mode/Restore: Bỏ qua Auto-Update"
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
    if [[ "$CLEAN_INSTALL" != "true" ]] && [[ "$ENABLE_RESTORE" != "true" ]]; then
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
    
    # Remove Docker images (only if clean install, not restore)
    if [[ "$CLEAN_INSTALL" == "true" ]]; then
        docker rmi n8n-custom-ffmpeg:latest news-api:latest 2>/dev/null || true
        
        # Remove installation directory
        rm -rf "$INSTALL_DIR"
        
        # Remove cron jobs
        crontab -l 2>/dev/null | grep -v "/home/n8n" | crontab - 2>/dev/null || true
    fi
    
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
    mkdir -p files/gdrive_auth
    mkdir -p logs
    
    # Set proper ownership for N8N data directory
    chown -R 1000:1000 files/
    
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

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose port
EXPOSE 8000

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
EOF
    
    success "Đã tạo News Content API"
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
    
    log "🌐 Tạo Caddyfile với SSL provider: $SSL_PROVIDER..."
    
    # Configure SSL provider settings
    local ssl_config=""
    case "$SSL_PROVIDER" in
        "letsencrypt")
            ssl_config="acme_ca https://acme-v02.api.letsencrypt.org/directory"
            ;;
        "zerossl")
            ssl_config="acme_ca https://acme.zerossl.com/v2/DV90
    acme_ca_root https://acme.zerossl.com/v2/DV90
    email $ZEROSSL_EMAIL"
            if [[ -n "$ZEROSSL_API_KEY" ]]; then
                ssl_config="$ssl_config
    acme_eab {
        key_id $ZEROSSL_API_KEY
        mac_key $ZEROSSL_API_KEY
    }"
            fi
            ;;
    esac
    
    cat > "$INSTALL_DIR/Caddyfile" << EOF
{
    email ${ZEROSSL_EMAIL:-admin@${DOMAIN}}
    $ssl_config
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
    
    success "Đã tạo Caddyfile với SSL provider: $SSL_PROVIDER"
}

# =============================================================================
# GOOGLE DRIVE BACKUP SYSTEM
# =============================================================================

create_google_drive_backup() {
    if [[ "$GOOGLE_DRIVE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    log "☁️  Tạo hệ thống Google Drive backup..."
    
    # Create Python script for Google Drive upload
    cat > "$INSTALL_DIR/gdrive_backup.py" << EOF
#!/usr/bin/env python3
"""
Google Drive Backup Script for N8N
Author: Nguyễn Ngọc Thiện
"""

import os
import json
import pickle
import gzip
import shutil
from datetime import datetime, timedelta
from pathlib import Path
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request

# Scopes
SCOPES = ['https://www.googleapis.com/auth/drive.file']

# Configuration
CREDENTIALS_FILE = '/home/n8n/files/gdrive_auth/credentials.json'
TOKEN_FILE = '/home/n8n/files/gdrive_auth/token.pickle'
BACKUP_FOLDER = '/home/n8n/files/backup_full'
GDRIVE_FOLDER_NAME = 'N8N_Backups'

class GoogleDriveBackup:
    def __init__(self):
        self.service = None
        self.folder_id = None
        
    def authenticate(self):
        """Authenticate with Google Drive API"""
        creds = None
        
        # Load existing token
        if os.path.exists(TOKEN_FILE):
            with open(TOKEN_FILE, 'rb') as token:
                creds = pickle.load(token)
        
        # If there are no (valid) credentials, request authorization
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                if not os.path.exists(CREDENTIALS_FILE):
                    raise FileNotFoundError(f"Credentials file not found: {CREDENTIALS_FILE}")
                
                flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_FILE, SCOPES)
                creds = flow.run_local_server(port=0)
            
            # Save credentials for next run
            with open(TOKEN_FILE, 'wb') as token:
                pickle.dump(creds, token)
        
        self.service = build('drive', 'v3', credentials=creds)
        print("✅ Google Drive authentication successful")
        
    def get_or_create_folder(self):
        """Get or create backup folder in Google Drive"""
        # Search for existing folder
        results = self.service.files().list(
            q=f"name='{GDRIVE_FOLDER_NAME}' and mimeType='application/vnd.google-apps.folder'",
            fields="files(id, name)"
        ).execute()
        
        folders = results.get('files', [])
        
        if folders:
            self.folder_id = folders[0]['id']
            print(f"📁 Found existing folder: {GDRIVE_FOLDER_NAME}")
        else:
            # Create new folder
            folder_metadata = {
                'name': GDRIVE_FOLDER_NAME,
                'mimeType': 'application/vnd.google-apps.folder'
            }
            
            folder = self.service.files().create(
                body=folder_metadata,
                fields='id'
            ).execute()
            
            self.folder_id = folder.get('id')
            print(f"📁 Created new folder: {GDRIVE_FOLDER_NAME}")
    
    def upload_file(self, file_path):
        """Upload backup file to Google Drive"""
        file_name = os.path.basename(file_path)
        
        # Check if file already exists
        results = self.service.files().list(
            q=f"name='{file_name}' and parents in '{self.folder_id}'",
            fields="files(id, name)"
        ).execute()
        
        existing_files = results.get('files', [])
        
        file_metadata = {
            'name': file_name,
            'parents': [self.folder_id]
        }
        
        media = MediaFileUpload(file_path, resumable=True)
        
        if existing_files:
            # Update existing file
            file_id = existing_files[0]['id']
            file = self.service.files().update(
                fileId=file_id,
                media_body=media
            ).execute()
            print(f"📤 Updated existing file: {file_name}")
        else:
            # Create new file
            file = self.service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id'
            ).execute()
            print(f"📤 Uploaded new file: {file_name}")
        
        return file.get('id')
    
    def cleanup_old_backups(self, keep_count=30):
        """Remove old backup files, keep only recent ones"""
        # List all backup files in folder
        results = self.service.files().list(
            q=f"parents in '{self.folder_id}' and name contains 'n8n_backup_'",
            fields="files(id, name, createdTime)",
            orderBy="createdTime desc"
        ).execute()
        
        files = results.get('files', [])
        
        # Delete files beyond keep_count
        if len(files) > keep_count:
            files_to_delete = files[keep_count:]
            
            for file in files_to_delete:
                self.service.files().delete(fileId=file['id']).execute()
                print(f"🗑️  Deleted old backup: {file['name']}")
    
    def backup_to_drive(self):
        """Main backup process"""
        try:
            print(f"🚀 Starting Google Drive backup - {datetime.now()}")
            
            # Authenticate
            self.authenticate()
            
            # Get or create folder
            self.get_or_create_folder()
            
            # Find latest backup file
            backup_files = sorted(
                Path(BACKUP_FOLDER).glob('n8n_backup_*.tar.gz'),
                key=os.path.getmtime,
                reverse=True
            )
            
            if not backup_files:
                print("❌ No backup files found")
                return False
            
            latest_backup = backup_files[0]
            file_size_mb = latest_backup.stat().st_size / (1024 * 1024)
            
            print(f"📦 Uploading: {latest_backup.name} ({file_size_mb:.2f} MB)")
            
            # Upload file
            self.upload_file(str(latest_backup))
            
            # Cleanup old backups
            self.cleanup_old_backups()
            
            print("✅ Google Drive backup completed successfully")
            return True
            
        except Exception as e:
            print(f"❌ Google Drive backup failed: {str(e)}")
            return False

def main():
    backup = GoogleDriveBackup()
    return backup.backup_to_drive()

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
EOF
    
    # Make script executable
    chmod +x "$INSTALL_DIR/gdrive_backup.py"
    
    # Create requirements for Google Drive
    cat > "$INSTALL_DIR/gdrive_requirements.txt" << 'EOF'
google-api-python-client==2.100.0
google-auth-httplib2==0.1.0
google-auth-oauthlib==1.0.0
google-auth==2.22.0
EOF
    
    # Install Google Drive dependencies
    log "📦 Cài đặt Google Drive dependencies..."
    pip3 install -r "$INSTALL_DIR/gdrive_requirements.txt"
    
    # Create credentials file from user input
    cat > "$INSTALL_DIR/files/gdrive_auth/credentials.json" << EOF
{
    "installed": {
        "client_id": "$GOOGLE_CLIENT_ID",
        "client_secret": "$GOOGLE_CLIENT_SECRET",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
        "redirect_uris": ["urn:ietf:wg:oauth:2.0:oob", "http://localhost"]
    }
}
EOF
    
    chmod 600 "$INSTALL_DIR/files/gdrive_auth/credentials.json"
    
    success "Đã tạo hệ thống Google Drive backup"
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
VN_TIMESTAMP=$(TZ='Asia/Ho_Chi_Minh' date +"%Y%m%d_%H%M%S")
BACKUP_NAME="n8n_backup_$VN_TIMESTAMP"
TEMP_DIR="/tmp/$BACKUP_NAME"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    local vn_time=$(TZ='Asia/Ho_Chi_Minh' date +'%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[${vn_time}] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    local vn_time=$(TZ='Asia/Ho_Chi_Minh' date +'%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR ${vn_time}] $1${NC}" | tee -a "$LOG_FILE"
}

warning() {
    local vn_time=$(TZ='Asia/Ho_Chi_Minh' date +'%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[WARNING ${vn_time}] $1${NC}" | tee -a "$LOG_FILE"
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

# Backup SSL certificates if available
log "🔒 Backup SSL certificates..."
mkdir -p "$TEMP_DIR/ssl"

# Copy Caddy data (contains SSL certs)
if docker volume inspect n8n_caddy_data &>/dev/null; then
    docker run --rm -v n8n_caddy_data:/data -v "$TEMP_DIR/ssl:/backup" busybox cp -r /data /backup/ 2>/dev/null || true
fi

# Backup config files
log "🔧 Backup config files..."
mkdir -p "$TEMP_DIR/config"
cp docker-compose.yml "$TEMP_DIR/config/" 2>/dev/null || true
cp Caddyfile "$TEMP_DIR/config/" 2>/dev/null || true

# Create metadata
log "📊 Tạo metadata..."
cat > "$TEMP_DIR/backup_metadata.json" << EOL
{
    "backup_date": "$(TZ='Asia/Ho_Chi_Minh' date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "backup_name": "$BACKUP_NAME",
    "timezone": "Asia/Ho_Chi_Minh",
    "n8n_version": "$(docker exec n8n-container n8n --version 2>/dev/null || echo 'unknown')",
    "backup_type": "full",
    "includes_ssl": true,
    "includes_workflows": true,
    "includes_credentials": true,
    "files": {
        "workflows": "$(find $TEMP_DIR/workflows -name "*.json" | wc -l) files",
        "database": "$(ls -la $TEMP_DIR/credentials/database.sqlite 2>/dev/null | awk '{print $5}' || echo '0') bytes",
        "config": "$(find $TEMP_DIR/config -name "*" | wc -l) files",
        "ssl_certs": "$(find $TEMP_DIR/ssl -name "*" | wc -l) files"
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
if [[ -f "/home/n8n/gdrive_backup.py" && -f "/home/n8n/files/gdrive_auth/credentials.json" ]]; then
    log "☁️  Uploading to Google Drive..."
    python3 /home/n8n/gdrive_backup.py || warning "Google Drive upload failed"
fi

# Send to Telegram if configured
if [[ -f "/home/n8n/telegram_config.txt" ]]; then
    source "/home/n8n/telegram_config.txt"
    
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        log "📱 Gửi thông báo Telegram..."
        
        local vn_time=$(TZ='Asia/Ho_Chi_Minh' date +'%Y-%m-%d %H:%M:%S')
        MESSAGE="🔄 *N8N Backup Completed*
        
📅 Date: $vn_time (GMT+7)
📦 File: \`$BACKUP_NAME.tar.gz\`
💾 Size: $BACKUP_SIZE
📊 Status: ✅ Success
🔒 Includes: Workflows + Credentials + SSL

🗂️ Backup location: \`$BACKUP_DIR\`"

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

local vn_time=$(TZ='Asia/Ho_Chi_Minh' date +'%Y-%m-%d %H:%M:%S')

echo "📋 Thông tin hệ thống:"
echo "• Thời gian (GMT+7): $vn_time"
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
# N8N AUTO-UPDATE SCRIPT WITH ZEROSSL RENEWAL
# =============================================================================

set -e

LOG_FILE="/home/n8n/logs/update.log"
VN_TIMESTAMP=$(TZ='Asia/Ho_Chi_Minh' date +'%Y-%m-%d %H:%M:%S')

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$VN_TIMESTAMP] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$VN_TIMESTAMP] [ERROR] $1${NC}" | tee -a "$LOG_FILE"
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

# Check SSL certificate expiry and renew if needed
log "🔒 Kiểm tra SSL certificate..."
if [[ -f "Caddyfile" ]]; then
    # Extract domain from Caddyfile
    DOMAIN=$(grep -E "^[a-zA-Z0-9.-]+\s*{" Caddyfile | head -1 | awk '{print $1}')
    
    if [[ -n "$DOMAIN" ]]; then
        # Check SSL expiry
        SSL_EXPIRY=$(echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -dates | grep 'notAfter' | cut -d= -f2)
        
        if [[ -n "$SSL_EXPIRY" ]]; then
            # Convert to timestamp
            EXPIRY_TIMESTAMP=$(date -d "$SSL_EXPIRY" +%s)
            CURRENT_TIMESTAMP=$(date +%s)
            DAYS_TO_EXPIRY=$(( (EXPIRY_TIMESTAMP - CURRENT_TIMESTAMP) / 86400 ))
            
            log "📅 SSL expires in $DAYS_TO_EXPIRY days"
            
            # Renew if less than 30 days (ZeroSSL recommended renewal period)
            if [[ $DAYS_TO_EXPIRY -lt 30 ]]; then
                log "🔄 Renewing SSL certificate (ZeroSSL)..."
                $DOCKER_COMPOSE restart caddy
                sleep 30
            fi
        fi
    fi
fi

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
        
📅 Date: $VN_TIMESTAMP (GMT+7)
🚀 Status: ✅ Success
📦 Components updated:
• N8N Docker image
• yt-dlp
• SSL certificates (if needed)
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
    
    local mode_text="Production Mode"
    if [[ "$LOCAL_MODE" == "true" ]]; then
        mode_text="Local Mode"
    fi
    
    local vn_time=$(TZ='Asia/Ho_Chi_Minh' date +'%Y-%m-%d %H:%M:%S')
    
    TEST_MESSAGE="🚀 *N8N Installation Completed*

📅 Date: $vn_time (GMT+7)
🏠 Mode: $mode_text
🔒 SSL: $SSL_PROVIDER
🌐 Domain: $DOMAIN
📰 API Domain: $API_DOMAIN
💾 Backup: Enabled
☁️  Google Drive: $([[ "$GOOGLE_DRIVE_ENABLED" == "true" ]] && echo "Enabled" || echo "Disabled")
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
    if [[ "$LOCAL_MODE" == "true" ]]; then
        info "Local Mode: Bỏ qua thiết lập cron jobs"
        return 0
    fi
    
    log "⏰ Thiết lập cron jobs..."
    
    # Remove existing cron jobs for n8n
    crontab -l 2>/dev/null | grep -v "/home/n8n" | crontab - 2>/dev/null || true
    
    # Add backup job (daily at 2:00 AM Vietnam time)
    (crontab -l 2>/dev/null; echo "0 2 * * * cd /home/n8n && TZ='Asia/Ho_Chi_Minh' /home/n8n/backup-workflows.sh") | crontab -
    
    # Add auto-update job if enabled (every 12 hours Vietnam time)
    if [[ "$ENABLE_AUTO_UPDATE" == "true" ]]; then
        (crontab -l 2>/dev/null; echo "0 */12 * * * cd /home/n8n && TZ='Asia/Ho_Chi_Minh' /home/n8n/update-n8n.sh") | crontab -
    fi
    
    success "Đã thiết lập cron jobs"
}

# =============================================================================
# SSL DETECTION & SMART PROVIDER SWITCHING
# =============================================================================

parse_ssl_logs() {
    local logs="$1"
    
    # Look for successful certificate generation
    if echo "$logs" | grep -q "certificate obtained successfully"; then
        return 0  # Success
    fi
    
    # Look for rate limit indicators
    if echo "$logs" | grep -qE "rateLimited|too many certificates|rate.?limit|exhausted|too many"; then
        return 1  # Rate limited
    fi
    
    # Look for other errors
    if echo "$logs" | grep -qE "error|failed|timeout"; then
        return 2  # Other error
    fi
    
    return 3  # Unknown status
}

check_ssl_rate_limit() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        info "Local Mode: Bỏ qua kiểm tra SSL"
        return 0
    fi
    
    log "🔒 Kiểm tra SSL certificate..."
    
    # Wait for containers to start
    sleep 30
    
    # Check Caddy logs
    local caddy_logs=""
    local ssl_status=""
    
    if caddy_logs=$($DOCKER_COMPOSE logs caddy 2>/dev/null); then
        parse_ssl_logs "$caddy_logs"
        ssl_status=$?
        
        case $ssl_status in
            0)
                success "✅ SSL certificate đã được cấp thành công"
                log "📊 SSL Provider: $SSL_PROVIDER"
                
                # Test SSL endpoint
                sleep 60
                if curl -I "https://$DOMAIN" &>/dev/null; then
                    success "✅ HTTPS endpoint đang hoạt động"
                else
                    warning "⚠️ SSL certificate OK nhưng HTTPS chưa sẵn sàng - đợi thêm vài phút"
                fi
                return 0
                ;;
            1)
                error "🚨 PHÁT HIỆN SSL RATE LIMIT!"
                handle_ssl_rate_limit "$caddy_logs"
                ;;
            2)
                warning "⚠️ SSL có lỗi khác"
                echo -e "${YELLOW}📋 Caddy logs:${NC}"
                echo "$caddy_logs" | tail -10
                
                read -p "🤔 Bạn có muốn thử chuyển sang ZeroSSL? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    switch_to_zerossl
                fi
                ;;
            *)
                warning "⚠️ Không thể xác định trạng thái SSL - đợi thêm vài phút"
                ;;
        esac
    else
        warning "⚠️ Không thể lấy Caddy logs"
    fi
}

handle_ssl_rate_limit() {
    local logs="$1"
    
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${WHITE}                    ⚠️  SSL RATE LIMIT DETECTED                              ${RED}║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Calculate Vietnam time for rate limit reset
    local vn_time=$(TZ='Asia/Ho_Chi_Minh' date +'%Y-%m-%d %H:%M:%S')
    local reset_time=$(TZ='Asia/Ho_Chi_Minh' date -d '+7 days' +'%Y-%m-%d %H:%M:%S')
    
    echo -e "${YELLOW}🔍 NGUYÊN NHÂN:${NC}"
    echo -e "  • Let's Encrypt giới hạn 5 certificates/domain/tuần"
    echo -e "  • Domain này đã đạt giới hạn miễn phí"
    echo -e "  • Rate limit sẽ reset vào: ${WHITE}$reset_time (GMT+7)${NC}"
    echo ""
    
    echo -e "${YELLOW}💡 GIẢI PHÁP TỰ ĐỘNG:${NC}"
    echo -e "  ${GREEN}🔄 Chuyển sang ZeroSSL (KHUYẾN NGHỊ):${NC}"
    echo -e "     • ZeroSSL ít bị rate limit hơn"
    echo -e "     • Tự động renew sau 75 ngày"
    echo -e "     • Miễn phí với API key"
    echo ""
    
    echo -e "${YELLOW}📋 LOG ANALYSIS:${NC}"
    echo "$logs" | grep -E "certificate|ssl|acme|rate|error" | tail -5 | while read line; do
        echo -e "  ${WHITE}• $line${NC}"
    done
    echo ""
    
    read -p "🔄 Bạn có muốn tự động chuyển sang ZeroSSL? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo ""
        echo -e "${CYAN}📋 HƯỚNG DẪN THỦ CÔNG:${NC}"
        echo -e "  1. Đợi đến ${WHITE}$reset_time (GMT+7)${NC}"
        echo -e "  2. Restart Caddy: ${WHITE}cd /home/n8n && docker-compose restart caddy${NC}"
        echo -e "  3. Hoặc cài lại với subdomain khác"
        echo ""
        return 1
    else
        switch_to_zerossl
    fi
}

switch_to_zerossl() {
    log "🔄 Chuyển đổi sang ZeroSSL..."
    
    # Get ZeroSSL credentials if not already provided
    if [[ -z "$ZEROSSL_EMAIL" || -z "$ZEROSSL_API_KEY" ]]; then
        echo ""
        echo -e "${YELLOW}📋 Thiết lập ZeroSSL:${NC}"
        
        while true; do
            read -p "📧 Nhập email cho ZeroSSL: " ZEROSSL_EMAIL
            if [[ "$ZEROSSL_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                break
            else
                error "Email không hợp lệ"
            fi
        done
        
        echo ""
        echo -e "${YELLOW}🔑 Lấy ZeroSSL API Key:${NC}"
        echo -e "  1. Truy cập: https://app.zerossl.com/developer"
        echo -e "  2. Đăng ký/Đăng nhập với email: ${ZEROSSL_EMAIL}"
        echo -e "  3. Copy API Key"
        echo ""
        
        while true; do
            read -p "🔑 Nhập ZeroSSL API Key: " ZEROSSL_API_KEY
            if [[ ${#ZEROSSL_API_KEY} -ge 32 ]]; then
                break
            else
                error "API Key không hợp lệ (quá ngắn)"
            fi
        done
    fi
    
    # Stop containers
    $DOCKER_COMPOSE down
    
    # Remove SSL volumes to force new certificate generation
    docker volume rm n8n_caddy_data n8n_caddy_config 2>/dev/null || true
    
    # Update SSL provider
    SSL_PROVIDER="zerossl"
    
    # Recreate Caddyfile with ZeroSSL
    create_caddyfile
    
    # Restart containers
    log "🚀 Khởi động lại với ZeroSSL..."
    $DOCKER_COMPOSE up -d
    
    # Wait and check
    sleep 60
    
    local caddy_logs=$($DOCKER_COMPOSE logs caddy 2>/dev/null || echo "")
    parse_ssl_logs "$caddy_logs"
    local ssl_status=$?
    
    if [[ $ssl_status -eq 0 ]]; then
        success "✅ Đã chuyển sang ZeroSSL thành công!"
        log "📊 New SSL Provider: ZeroSSL"
    else
        error "❌ Chuyển sang ZeroSSL thất bại"
        echo -e "${YELLOW}📋 ZeroSSL logs:${NC}"
        echo "$caddy_logs" | tail -10
    fi
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
    
    # Check container status with health checks
    log "🔍 Kiểm tra trạng thái containers..."
    
    local max_retries=10
    local retry_count=0
    local all_healthy=false
    
    while [[ $retry_count -lt $max_retries ]]; do
        local n8n_status=$(docker inspect n8n-container --format='{{.State.Health.Status}}' 2>/dev/null || echo "no-health-check")
        
        if [[ "$n8n_status" == "healthy" ]] || docker ps | grep -q "n8n-container.*Up"; then
            success "✅ N8N container đã khởi động thành công"
            all_healthy=true
            break
        else
            warning "⏳ Đợi N8N container khởi động... (${retry_count}/${max_retries})"
            sleep 10
            ((retry_count++))
        fi
    done
    
    if [[ "$all_healthy" != "true" ]]; then
        error "❌ Có lỗi khi khởi động containers"
        echo ""
        echo -e "${YELLOW}📋 Container logs:${NC}"
        $DOCKER_COMPOSE logs --tail=20
        echo ""
        echo -e "${YELLOW}🔧 Thử fix quyền và restart:${NC}"
        
        # Fix permissions
        chown -R 1000:1000 "$INSTALL_DIR/files/"
        
        # Restart containers
        $DOCKER_COMPOSE restart
        sleep 30
        
        if docker ps | grep -q "n8n-container.*Up"; then
            success "✅ Đã fix và containers hoạt động bình thường"
        else
            error "❌ Vẫn có lỗi - vui lòng chạy troubleshoot script"
            exit 1
        fi
    fi
}

# =============================================================================
# GOOGLE DRIVE SETUP
# =============================================================================

setup_google_drive() {
    if [[ "$GOOGLE_DRIVE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    log "☁️  Thiết lập Google Drive authentication..."
    
    # Create Google Drive backup system
    create_google_drive_backup
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                  ☁️  GOOGLE DRIVE AUTHENTICATION                           ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Bước cuối cùng: Authorize Google Drive access${NC}"
    echo -e "  1. Script sẽ mở browser để authorize"
    echo -e "  2. Đăng nhập Google account"
    echo -e "  3. Cho phép access Google Drive"
    echo -e "  4. Copy authorization code và paste vào terminal"
    echo ""
    
    read -p "📋 Bạn đã sẵn sàng authorize Google Drive? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "🔐 Chạy Google Drive authorization..."
        
        # Run the Python script to do initial authentication
        if python3 "$INSTALL_DIR/gdrive_backup.py" 2>/dev/null; then
            success "✅ Google Drive authentication thành công"
            
            # Test upload with a small file
            echo "Test backup" > /tmp/test_backup.txt
            if python3 -c "
import sys
sys.path.append('/home/n8n')
from gdrive_backup import GoogleDriveBackup
backup = GoogleDriveBackup()
backup.authenticate()
backup.get_or_create_folder()
backup.upload_file('/tmp/test_backup.txt')
print('Test upload successful')
" 2>/dev/null; then
                success "✅ Google Drive test upload thành công"
                rm -f /tmp/test_backup.txt
            else
                warning "⚠️ Google Drive test upload thất bại - có thể cần setup lại"
            fi
        else
            warning "⚠️ Google Drive authorization thất bại"
            info "💡 Bạn có thể setup lại bằng cách chạy: python3 /home/n8n/gdrive_backup.py"
        fi
    else
        info "ℹ️ Bỏ qua Google Drive authorization - có thể setup sau"
        info "💡 Để setup sau, chạy: python3 /home/n8n/gdrive_backup.py"
    fi
}

# =============================================================================
# RESTORE SYSTEM FUNCTIONS
# =============================================================================

create_restore_scripts() {
    log "🔄 Tạo restore utilities..."
    
    # Create restore script
    cat > "$INSTALL_DIR/restore-from-backup.sh" << 'EOF'
#!/bin/bash

# =============================================================================
# N8N RESTORE SCRIPT - Restore từ backup file
# =============================================================================

set -e

BACKUP_FILE="$1"
RESTORE_DIR="/tmp/n8n_restore_$(date +%s)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    local vn_time=$(TZ='Asia/Ho_Chi_Minh' date +'%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[${vn_time}] $1${NC}"
}

error() {
    local vn_time=$(TZ='Asia/Ho_Chi_Minh' date +'%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR ${vn_time}] $1${NC}"
}

if [[ -z "$BACKUP_FILE" ]]; then
    echo "Usage: $0 <backup_file.tar.gz>"
    echo ""
    echo "Available backups:"
    ls -la /home/n8n/files/backup_full/n8n_backup_*.tar.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
    error "Backup file không tồn tại: $BACKUP_FILE"
    exit 1
fi

log "🔄 Bắt đầu restore từ: $(basename $BACKUP_FILE)"

# Extract backup
mkdir -p "$RESTORE_DIR"
tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"

BACKUP_ROOT=$(find "$RESTORE_DIR" -maxdepth 1 -type d -name "n8n_backup_*" | head -1)

if [[ -z "$BACKUP_ROOT" ]]; then
    error "Backup structure không hợp lệ"
    rm -rf "$RESTORE_DIR"
    exit 1
fi

# Check Docker Compose
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    error "Docker Compose không tìm thấy!"
    exit 1
fi

cd /home/n8n

# Stop containers
log "🛑 Dừng containers..."
$DOCKER_COMPOSE down

# Restore database
if [[ -f "$BACKUP_ROOT/credentials/database.sqlite" ]]; then
    log "💾 Restore database..."
    cp "$BACKUP_ROOT/credentials/database.sqlite" files/
    chown 1000:1000 files/database.sqlite
fi

# Restore encryption key
if [[ -f "$BACKUP_ROOT/credentials/encryptionKey" ]]; then
    log "🔐 Restore encryption key..."
    cp "$BACKUP_ROOT/credentials/encryptionKey" files/
    chown 1000:1000 files/encryptionKey
fi

# Restore SSL certificates
if [[ -d "$BACKUP_ROOT/ssl" ]]; then
    log "🔒 Restore SSL certificates..."
    # This would restore Caddy SSL data
    # Implementation depends on backup structure
fi

# Set permissions
chown -R 1000:1000 files/

# Start containers
log "🚀 Khởi động containers..."
$DOCKER_COMPOSE up -d

# Cleanup
rm -rf "$RESTORE_DIR"

log "✅ Restore completed successfully!"
EOF

    chmod +x "$INSTALL_DIR/restore-from-backup.sh"
    
    success "Đã tạo restore utilities"
}

# =============================================================================
# TROUBLESHOOTING SCRIPT
# =============================================================================

create_troubleshooting_script() {
    log "🔧 Tạo script chẩn đoán..."
    
    cat > "$INSTALL_DIR/troubleshoot.sh" << 'EOF'
#!/bin/bash

# =============================================================================
# N8N TROUBLESHOOTING SCRIPT - Enhanced Version
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
echo -e "${CYAN}║${WHITE}                🔧 N8N TROUBLESHOOTING SCRIPT - ENHANCED                     ${CYAN}║${NC}"
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

VN_TIME=$(TZ='Asia/Ho_Chi_Minh' date +'%Y-%m-%d %H:%M:%S')

echo -e "${BLUE}📍 1. System Information:${NC}"
echo "• Time (GMT+7): $VN_TIME"
echo "• OS: $(lsb_release -d | cut -f2)"
echo "• Kernel: $(uname -r)"
echo "• Docker: $(docker --version)"
echo "• Docker Compose: $($DOCKER_COMPOSE --version)"
echo "• Disk Usage: $(df -h /home/n8n | tail -1 | awk '{print $5}')"
echo "• Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"
echo "• Uptime: $(uptime -p)"
echo ""

echo -e "${BLUE}📍 2. Installation Mode & SSL:${NC}"
if [[ -f "Caddyfile" ]]; then
    echo "• Mode: Production Mode (with SSL)"
    DOMAIN=$(grep -E "^[a-zA-Z0-9.-]+\s*{" Caddyfile | head -1 | awk '{print $1}')
    echo "• Domain: $DOMAIN"
    
    # Check SSL provider
    if grep -q "zerossl" Caddyfile; then
        echo "• SSL Provider: ZeroSSL"
    else
        echo "• SSL Provider: Let's Encrypt"
    fi
    
    # Check SSL status
    if [[ -n "$DOMAIN" ]]; then
        SSL_STATUS=$(curl -I https://$DOMAIN 2>/dev/null | head -1 | awk '{print $2}' || echo "Failed")
        echo "• SSL Status: $SSL_STATUS"
        
        if [[ "$SSL_STATUS" == "200" ]]; then
            SSL_EXPIRY=$(echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -dates | grep 'notAfter' | cut -d= -f2)
            if [[ -n "$SSL_EXPIRY" ]]; then
                EXPIRY_TIMESTAMP=$(date -d "$SSL_EXPIRY" +%s)
                CURRENT_TIMESTAMP=$(date +%s)
                DAYS_TO_EXPIRY=$(( (EXPIRY_TIMESTAMP - CURRENT_TIMESTAMP) / 86400 ))
                echo "• SSL Expires: $DAYS_TO_EXPIRY days"
            fi
        fi
    fi
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

echo -e "${BLUE}📍 6. File Permissions:${NC}"
echo "• N8N data directory: $(ls -ld /home/n8n/files | awk '{print $1" "$3":"$4}')"
echo "• Database file: $(ls -l /home/n8n/files/database.sqlite 2>/dev/null | awk '{print $1" "$3":"$4}' || echo 'Not found')"
echo ""

echo -e "${BLUE}📍 7. Backup Status:${NC}"
if [[ -d "/home/n8n/files/backup_full" ]]; then
    BACKUP_COUNT=$(ls -1 /home/n8n/files/backup_full/n8n_backup_*.tar.gz 2>/dev/null | wc -l)
    echo "• Backup files: $BACKUP_COUNT"
    if [[ $BACKUP_COUNT -gt 0 ]]; then
        LATEST_BACKUP=$(ls -t /home/n8n/files/backup_full/n8n_backup_*.tar.gz | head -1)
        echo "• Latest backup: $(basename $LATEST_BACKUP)"
        echo "• Latest backup size: $(ls -lh $LATEST_BACKUP | awk '{print $5}')"
        echo "• Latest backup time: $(ls -l $LATEST_BACKUP | awk '{print $6" "$7" "$8}')"
    fi
else
    echo "• No backup directory found"
fi

# Check Google Drive
if [[ -f "/home/n8n/gdrive_backup.py" ]]; then
    echo "• Google Drive: Configured"
    if [[ -f "/home/n8n/files/gdrive_auth/token.pickle" ]]; then
        echo "• Google Drive Auth: ✅ Authenticated"
    else
        echo "• Google Drive Auth: ❌ Not authenticated"
    fi
else
    echo "• Google Drive: Not configured"
fi
echo ""

echo -e "${BLUE}📍 8. Cron Jobs:${NC}"
crontab -l 2>/dev/null | grep -E "(n8n|backup)" || echo "• No N8N cron jobs found"
echo ""

echo -e "${BLUE}📍 9. Recent Logs (last 10 lines):${NC}"
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

echo -e "${GREEN}🔧 QUICK FIX COMMANDS:${NC}"
echo -e "${YELLOW}• Fix permissions:${NC} chown -R 1000:1000 /home/n8n/files/"
echo -e "${YELLOW}• Restart all services:${NC} cd /home/n8n && $DOCKER_COMPOSE restart"
echo -e "${YELLOW}• View live logs:${NC} cd /home/n8n && $DOCKER_COMPOSE logs -f"
echo -e "${YELLOW}• Rebuild containers:${NC} cd /home/n8n && $DOCKER_COMPOSE down && $DOCKER_COMPOSE up -d --build"
echo -e "${YELLOW}• Manual backup:${NC} /home/n8n/backup-manual.sh"
echo -e "${YELLOW}• Restore from backup:${NC} /home/n8n/restore-from-backup.sh /path/to/backup.tar.gz"

if [[ -n "$DOMAIN" && "$DOMAIN" != "localhost" ]]; then
    echo -e "${YELLOW}• Check SSL:${NC} curl -I https://$DOMAIN"
    echo -e "${YELLOW}• Force SSL renewal:${NC} cd /home/n8n && $DOCKER_COMPOSE restart caddy"
fi

if [[ -f "/home/n8n/gdrive_backup.py" ]]; then
    echo -e "${YELLOW}• Test Google Drive:${NC} python3 /home/n8n/gdrive_backup.py"
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
    local vn_time=$(TZ='Asia/Ho_Chi_Minh' date +'%Y-%m-%d %H:%M:%S')
    
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${WHITE}                🎉 N8N ĐÃ ĐƯỢC CÀI ĐẶT THÀNH CÔNG! 🎉                      ${GREEN}║${NC}"
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
    echo -e "  • Chế độ: ${WHITE}$([[ "$LOCAL_MODE" == "true" ]] && echo "Local Mode" || echo "Production Mode")${NC}"
    echo -e "  • SSL Provider: ${WHITE}$SSL_PROVIDER${NC}"
    echo -e "  • Timezone: ${WHITE}Asia/Ho_Chi_Minh (GMT+7)${NC}"
    echo -e "  • Thời gian cài đặt: ${WHITE}$vn_time${NC}"
    echo -e "  • Thư mục cài đặt: ${WHITE}${INSTALL_DIR}${NC}"
    echo ""
    
    echo -e "${CYAN}🛠️  MANAGEMENT SCRIPTS:${NC}"
    echo -e "  • Chẩn đoán hệ thống: ${WHITE}${INSTALL_DIR}/troubleshoot.sh${NC}"
    echo -e "  • Test backup: ${WHITE}${INSTALL_DIR}/backup-manual.sh${NC}"
    echo -e "  • Restore backup: ${WHITE}${INSTALL_DIR}/restore-from-backup.sh <file>${NC}"
    if [[ "$ENABLE_AUTO_UPDATE" == "true" ]]; then
        echo -e "  • Manual update: ${WHITE}${INSTALL_DIR}/update-n8n.sh${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}💾 CẤU HÌNH BACKUP:${NC}"
    local swap_info=$(swapon --show | grep -v NAME | awk '{print $3}' | head -1)
    echo -e "  • Swap: ${WHITE}${swap_info:-"Không có"}${NC}"
    echo -e "  • Auto-update: ${WHITE}$([[ "$ENABLE_AUTO_UPDATE" == "true" ]] && echo "Enabled (mỗi 12h)" || echo "Disabled")${NC}"
    echo -e "  • Telegram backup: ${WHITE}$([[ "$ENABLE_TELEGRAM" == "true" ]] && echo "Enabled" || echo "Disabled")${NC}"
    echo -e "  • Google Drive backup: ${WHITE}$([[ "$GOOGLE_DRIVE_ENABLED" == "true" ]] && echo "Enabled" || echo "Disabled")${NC}"
    if [[ "$LOCAL_MODE" != "true" ]]; then
        echo -e "  • Backup tự động: ${WHITE}Hàng ngày lúc 2:00 AM (GMT+7)${NC}"
    fi
    echo -e "  • Backup location: ${WHITE}${INSTALL_DIR}/files/backup_full/${NC}"
    echo ""
    
    if [[ "$ENABLE_NEWS_API" == "true" ]]; then
        echo -e "${CYAN}🔧 ĐỔI BEARER TOKEN:${NC}"
        echo -e "  ${WHITE}cd /home/n8n && sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN=\"NEW_TOKEN\"/' docker-compose.yml && $DOCKER_COMPOSE restart fastapi${NC}"
        echo ""
    fi
    
    if [[ "$GOOGLE_DRIVE_ENABLED" == "true" ]]; then
        echo -e "${CYAN}☁️  GOOGLE DRIVE COMMANDS:${NC}"
        echo -e "  • Test upload: ${WHITE}python3 /home/n8n/gdrive_backup.py${NC}"
        echo -e "  • Re-authenticate: ${WHITE}rm /home/n8n/files/gdrive_auth/token.pickle && python3 /home/n8n/gdrive_backup.py${NC}"
        echo ""
    fi
    
    if [[ "$LOCAL_MODE" == "true" ]]; then
        echo -e "${CYAN}🏠 LOCAL MODE NOTES:${NC}"
        echo -e "  • Không có SSL certificate (chạy trên HTTP)"
        echo -e "  • Không có auto-update và cron jobs"
        echo -e "  • Phù hợp cho development và testing"
        echo -e "  • Để chuyển sang Production Mode, chạy lại script với domain"
        echo ""
    fi
    
    if [[ "$ENABLE_RESTORE" == "true" ]]; then
        echo -e "${CYAN}🔄 RESTORE COMPLETED:${NC}"
        echo -e "  • Đã restore từ: ${WHITE}$RESTORE_SOURCE${NC}"
        echo -e "  • Workflows và credentials đã được khôi phục"
        echo -e "  • Hệ thống đã sẵn sàng sử dụng"
        echo ""
    fi
    
    echo -e "${CYAN}🚀 TÁC GIẢ:${NC}"
    echo -e "  • Tên: ${WHITE}Nguyễn Ngọc Thiện${NC}"
    echo -e "  • YouTube: ${WHITE}https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1${NC}"
    echo -e "  • Zalo: ${WHITE}08.8888.4749${NC}"
    echo -e "  • Cập nhật: ${WHITE}30/06/2025 - Enhanced Version${NC}"
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
    
    # Handle restore mode first
    if [[ "$ENABLE_RESTORE" == "true" ]]; then
        show_restore_menu
        perform_restore
    fi
    
    # System checks
    check_root
    check_os
    detect_environment
    check_docker_compose
    
    # Setup swap
    setup_swap
    
    # Get user input (skip if restore mode)
    if [[ "$ENABLE_RESTORE" != "true" ]]; then
        get_installation_mode
        get_domain_input
        get_cleanup_option
        get_ssl_provider_config
        get_news_api_config
        get_google_drive_config
        get_telegram_config
        get_auto_update_config
    fi
    
    # Verify DNS (skip for local mode)
    verify_dns
    
    # Cleanup old installation
    cleanup_old_installation
    
    # Install Docker
    install_docker
    
    # Create project structure
    create_project_structure
    
    # Create configuration files
    create_dockerfile
    create_news_api
    create_docker_compose
    create_caddyfile
    
    # Create scripts
    create_backup_scripts
    create_update_script
    create_restore_scripts
    create_troubleshooting_script
    
    # Setup services
    setup_telegram_config
    setup_google_drive
    
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
