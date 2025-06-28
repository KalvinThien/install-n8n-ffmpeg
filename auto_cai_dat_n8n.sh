#!/bin/bash

# =============================================================================
# 🚀 SCRIPT CÀI ĐẶT N8N TỰ ĐỘNG VỚI FFMPEG, YT-DLP, PUPPETEER VÀ NEWS API
# =============================================================================
# Tác giả: Nguyễn Ngọc Thiện
# YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1
# Zalo: 08.8888.4749
# Cập nhật: 28/12/2024
# Version: 3.0 - Newspaper4k + Random User Agent + SSL Rate Limit Handler
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Emojis
SUCCESS="✅"
ERROR="❌"
WARNING="⚠️"
INFO="ℹ️"
ROCKET="🚀"
GEAR="⚙️"
LOCK="🔒"
GLOBE="🌐"
DATABASE="💾"
BACKUP="📦"
TELEGRAM="📱"
NEWS="📰"
CLOCK="⏰"

# Default values
INSTALL_DIR="/home/n8n"
DOMAIN=""
API_DOMAIN=""
BEARER_TOKEN=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
ENABLE_TELEGRAM_BACKUP="n"
ENABLE_AUTO_UPDATE="y"
SKIP_DOCKER_INSTALL="n"
CLEAN_INSTALL="n"

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_success() {
    print_color $GREEN "$SUCCESS $1"
}

print_error() {
    print_color $RED "$ERROR $1"
}

print_warning() {
    print_color $YELLOW "$WARNING $1"
}

print_info() {
    print_color $BLUE "$INFO $1"
}

print_header() {
    echo ""
    print_color $PURPLE "========================================================================"
    print_color $WHITE "$1"
    print_color $PURPLE "========================================================================"
    echo ""
}

# Function to show help
show_help() {
    cat << EOF
🚀 SCRIPT CÀI ĐẶT N8N TỰ ĐỘNG VỚI FFMPEG, YT-DLP, PUPPETEER VÀ NEWS API

CÁCH SỬ DỤNG:
    $0 [OPTIONS]

TÙY CHỌN:
    -d, --directory DIR     Thư mục cài đặt (mặc định: /home/n8n)
    -s, --skip-docker      Bỏ qua cài đặt Docker (nếu đã có)
    -c, --clean            Xóa cài đặt cũ trước khi cài mới
    -h, --help             Hiển thị trợ giúp này

VÍ DỤ:
    # Cài đặt cơ bản
    sudo $0

    # Cài đặt với thư mục tùy chỉnh
    sudo $0 -d /opt/n8n

    # Cài đặt sạch (xóa cài đặt cũ)
    sudo $0 --clean

    # Bỏ qua cài đặt Docker
    sudo $0 --skip-docker

TÍNH NĂNG:
    ✅ N8N với FFmpeg, yt-dlp, Puppeteer
    ✅ News Content API với Newspaper4k + Random User Agent
    ✅ SSL tự động với Caddy (xử lý rate limit)
    ✅ Telegram Backup tự động
    ✅ Auto-update và backup hàng ngày
    ✅ Swap memory tự động
    ✅ Troubleshooting tools

LIÊN HỆ:
    📺 YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1
    📱 Zalo: 08.8888.4749
    📧 Email: admin@n8nkalvinbot.io.vn

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--directory)
            INSTALL_DIR="$2"
            shift 2
            ;;
        -s|--skip-docker)
            SKIP_DOCKER_INSTALL="y"
            shift
            ;;
        -c|--clean)
            CLEAN_INSTALL="y"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Tùy chọn không hợp lệ: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "Script này cần chạy với quyền root. Sử dụng: sudo $0"
    exit 1
fi

# Function to detect Docker Compose command
detect_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        echo "docker compose"
    else
        echo ""
    fi
}

# Function to check SSL rate limit
check_ssl_rate_limit() {
    local domain=$1
    local log_output
    
    # Wait a bit for logs to appear
    sleep 10
    
    log_output=$(docker logs n8n-caddy-1 2>&1 | grep -i "rate.*limit\|too many certificates" | tail -5)
    
    if [[ -n "$log_output" ]]; then
        return 0  # Rate limit detected
    else
        return 1  # No rate limit
    fi
}

# Function to handle SSL rate limit
handle_ssl_rate_limit() {
    print_header "$ERROR SSL RATE LIMIT DETECTED!"
    
    print_error "Let's Encrypt đã từ chối cấp SSL certificate do vượt quá giới hạn!"
    echo ""
    print_warning "NGUYÊN NHÂN:"
    echo "  • Đã cấp quá 5 certificates cho domain này trong 7 ngày qua"
    echo "  • Let's Encrypt có giới hạn miễn phí nghiêm ngặt"
    echo "  • Domain: $DOMAIN và $API_DOMAIN"
    echo ""
    
    print_info "GIẢI PHÁP KHUYẾN NGHỊ:"
    echo ""
    print_color $CYAN "🔄 GIẢI PHÁP 1: CÀI LẠI UBUNTU (KHUYẾN NGHỊ)"
    echo "  1. Backup dữ liệu quan trọng"
    echo "  2. Cài lại Ubuntu Server hoàn toàn"
    echo "  3. Sử dụng subdomain khác (vd: n8n2.yourdomain.com)"
    echo "  4. Chạy lại script này"
    echo ""
    
    print_color $CYAN "🔄 GIẢI PHÁP 2: ĐỢI ĐẾN NGÀY RESET"
    echo "  • Đợi đến sau ngày: $(date -d '+7 days' '+%d/%m/%Y')"
    echo "  • Let's Encrypt sẽ reset giới hạn sau 7 ngày"
    echo ""
    
    print_color $CYAN "🔄 GIẢI PHÁP 3: SỬ DỤNG STAGING SSL (TẠM THỜI)"
    echo "  • Website sẽ hoạt động nhưng có cảnh báo 'Not Secure'"
    echo "  • Chức năng N8N và API hoạt động bình thường"
    echo "  • Có thể chuyển về production SSL sau 7 ngày"
    echo ""
    
    read -p "Bạn có muốn tiếp tục với Staging SSL? (y/N): " use_staging
    
    if [[ $use_staging =~ ^[Yy]$ ]]; then
        print_info "Đang chuyển sang Staging SSL..."
        setup_staging_ssl
        return 0
    else
        print_warning "Cài đặt bị dừng. Vui lòng thực hiện một trong các giải pháp trên."
        print_info "Để cài lại với staging SSL, chạy lệnh:"
        echo "  sudo $0 --staging-ssl"
        exit 1
    fi
}

# Function to setup staging SSL
setup_staging_ssl() {
    print_info "Đang thiết lập Staging SSL..."
    
    # Stop containers
    cd $INSTALL_DIR
    local DOCKER_COMPOSE=$(detect_docker_compose)
    $DOCKER_COMPOSE down
    
    # Remove SSL volumes
    docker volume rm n8n_caddy_data n8n_caddy_config 2>/dev/null || true
    
    # Create Caddyfile with staging environment
    cat > $INSTALL_DIR/Caddyfile << EOF
{
    email admin@$DOMAIN
    acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
    debug
}

$DOMAIN {
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

$API_DOMAIN {
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

    # Start containers
    $DOCKER_COMPOSE up -d
    
    print_success "Staging SSL đã được thiết lập!"
    print_warning "Website sẽ hiển thị cảnh báo 'Not Secure' - đây là bình thường với staging certificate"
    
    # Create script to convert to production SSL later
    cat > $INSTALL_DIR/convert-to-production-ssl.sh << 'EOF'
#!/bin/bash
echo "🔄 Chuyển đổi từ Staging SSL sang Production SSL..."

cd /home/n8n
DOCKER_COMPOSE=$(command -v docker-compose &> /dev/null && echo "docker-compose" || echo "docker compose")

# Stop containers
$DOCKER_COMPOSE down

# Remove staging SSL data
docker volume rm n8n_caddy_data n8n_caddy_config 2>/dev/null || true

# Update Caddyfile to production
sed -i 's|acme_ca https://acme-staging-v02.api.letsencrypt.org/directory|acme_ca https://acme-v02.api.letsencrypt.org/directory|g' Caddyfile
sed -i '/debug/d' Caddyfile

# Start containers
$DOCKER_COMPOSE up -d

echo "✅ Đã chuyển sang Production SSL!"
echo "🌐 Kiểm tra: https://$(grep -m1 '^[^{]*{' Caddyfile | sed 's/ {//')"
EOF

    chmod +x $INSTALL_DIR/convert-to-production-ssl.sh
    
    print_info "Để chuyển về Production SSL sau 7 ngày, chạy:"
    echo "  $INSTALL_DIR/convert-to-production-ssl.sh"
}

# Function to get user input
get_user_input() {
    print_header "$GEAR THIẾT LẬP CẤU HÌNH"
    
    # Domain input
    while [[ -z "$DOMAIN" ]]; do
        read -p "🌐 Nhập domain chính cho N8N (vd: n8n.yourdomain.com): " DOMAIN
        if [[ -z "$DOMAIN" ]]; then
            print_error "Domain không được để trống!"
        fi
    done
    
    # API Domain
    API_DOMAIN="api.$DOMAIN"
    print_info "📰 API Domain sẽ là: $API_DOMAIN"
    
    # Clean install option
    if [[ "$CLEAN_INSTALL" == "n" ]] && [[ -d "$INSTALL_DIR" ]]; then
        echo ""
        print_warning "Phát hiện cài đặt N8N cũ tại: $INSTALL_DIR"
        read -p "Bạn có muốn xóa cài đặt cũ? (y/N): " clean_old
        if [[ $clean_old =~ ^[Yy]$ ]]; then
            CLEAN_INSTALL="y"
        fi
    fi
    
    # News API setup
    echo ""
    print_info "📰 THIẾT LẬP NEWS CONTENT API"
    read -p "Bạn có muốn cài đặt News Content API? (Y/n): " install_news_api
    if [[ ! $install_news_api =~ ^[Nn]$ ]]; then
        while [[ ${#BEARER_TOKEN} -lt 20 ]]; do
            read -p "🔑 Đặt Bearer Token cho API (ít nhất 20 ký tự): " BEARER_TOKEN
            if [[ ${#BEARER_TOKEN} -lt 20 ]]; then
                print_error "Bearer Token phải có ít nhất 20 ký tự!"
            elif [[ ! $BEARER_TOKEN =~ ^[a-zA-Z0-9]+$ ]]; then
                print_error "Bearer Token chỉ được chứa chữ cái và số!"
                BEARER_TOKEN=""
            fi
        done
        INSTALL_NEWS_API="y"
    else
        INSTALL_NEWS_API="n"
    fi
    
    # Telegram backup setup
    if [[ "$INSTALL_NEWS_API" == "y" ]]; then
        echo ""
        print_info "📱 THIẾT LẬP TELEGRAM BACKUP"
        read -p "Bạn có muốn thiết lập backup qua Telegram? (y/N): " setup_telegram
        if [[ $setup_telegram =~ ^[Yy]$ ]]; then
            read -p "🤖 Nhập Telegram Bot Token: " TELEGRAM_BOT_TOKEN
            read -p "🆔 Nhập Telegram Chat ID: " TELEGRAM_CHAT_ID
            if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
                ENABLE_TELEGRAM_BACKUP="y"
            else
                print_warning "Thiếu thông tin Telegram, bỏ qua backup qua Telegram"
            fi
        fi
    fi
    
    # Auto-update setup
    echo ""
    read -p "🔄 Bạn có muốn bật tự động cập nhật? (Y/n): " auto_update
    if [[ $auto_update =~ ^[Nn]$ ]]; then
        ENABLE_AUTO_UPDATE="n"
    fi
}

# Function to check DNS
check_dns() {
    print_header "$GLOBE KIỂM TRA DNS"
    
    print_info "Đang kiểm tra DNS cho $DOMAIN..."
    local domain_ip=$(dig +short $DOMAIN A | tail -n1)
    local server_ip=$(curl -s https://api.ipify.org)
    
    print_info "IP của domain $DOMAIN: $domain_ip"
    print_info "IP của server: $server_ip"
    
    if [[ "$domain_ip" != "$server_ip" ]]; then
        print_warning "Domain chưa trỏ đúng về server này!"
        print_info "Vui lòng cấu hình DNS:"
        echo "  • Tạo A record: $DOMAIN -> $server_ip"
        echo "  • Tạo A record: $API_DOMAIN -> $server_ip"
        echo ""
        read -p "Bạn có muốn tiếp tục? (y/N): " continue_anyway
        if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
            print_error "Vui lòng cấu hình DNS trước khi tiếp tục"
            exit 1
        fi
    else
        print_success "DNS đã được cấu hình đúng!"
    fi
}

# Function to setup swap
setup_swap() {
    print_header "$DATABASE THIẾT LẬP SWAP MEMORY"
    
    # Check if swap already exists
    if swapon --show | grep -q "/swapfile"; then
        local current_swap=$(free -h | awk '/^Swap:/ {print $2}')
        print_info "Swap hiện tại: $current_swap"
        return 0
    fi
    
    # Calculate swap size based on RAM
    local ram_gb=$(free -g | awk '/^Mem:/ {print $2}')
    local swap_size
    
    if [[ $ram_gb -le 2 ]]; then
        swap_size="4G"
    elif [[ $ram_gb -le 4 ]]; then
        swap_size="4G"
    elif [[ $ram_gb -le 8 ]]; then
        swap_size="4G"
    else
        swap_size="8G"
    fi
    
    print_info "Đang tạo swap file $swap_size..."
    
    # Create swap file
    fallocate -l $swap_size /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    
    # Make swap permanent
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
    fi
    
    # Optimize swap settings
    echo "vm.swappiness=10" >> /etc/sysctl.conf
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
    
    print_success "Swap $swap_size đã được tạo thành công!"
}

# Function to install Docker
install_docker() {
    if [[ "$SKIP_DOCKER_INSTALL" == "y" ]]; then
        print_info "Bỏ qua cài đặt Docker theo yêu cầu"
        return 0
    fi
    
    print_header "$GEAR CÀI ĐẶT DOCKER"
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        print_info "Docker đã được cài đặt"
        
        # Check if Docker Compose is available
        if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
            print_info "Đang cài đặt Docker Compose..."
            apt update
            apt install -y docker-compose
        fi
        
        return 0
    fi
    
    print_info "Đang cài đặt Docker..."
    
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
    
    print_success "Docker đã được cài đặt thành công!"
}

# Function to clean old installation
clean_old_installation() {
    if [[ "$CLEAN_INSTALL" == "y" && -d "$INSTALL_DIR" ]]; then
        print_header "$WARNING XÓA CÀI ĐẶT CŨ"
        
        print_info "Đang dừng containers cũ..."
        cd $INSTALL_DIR 2>/dev/null || true
        local DOCKER_COMPOSE=$(detect_docker_compose)
        if [[ -n "$DOCKER_COMPOSE" ]]; then
            $DOCKER_COMPOSE down 2>/dev/null || true
        fi
        
        print_info "Đang xóa thư mục cài đặt cũ..."
        rm -rf $INSTALL_DIR
        
        print_info "Đang xóa Docker volumes cũ..."
        docker volume rm n8n_caddy_data n8n_caddy_config 2>/dev/null || true
        
        print_success "Đã xóa cài đặt cũ thành công!"
    fi
}

# Function to create directory structure
create_directory_structure() {
    print_header "$GEAR TẠO CẤU TRÚC THỦ MỤC"
    
    # Create main directory
    mkdir -p $INSTALL_DIR
    cd $INSTALL_DIR
    
    # Create subdirectories
    mkdir -p files/backup_full
    mkdir -p files/temp
    mkdir -p files/youtube_content_anylystic
    mkdir -p logs
    
    if [[ "$INSTALL_NEWS_API" == "y" ]]; then
        mkdir -p news_api
    fi
    
    print_success "Cấu trúc thư mục đã được tạo!"
}

# Function to create News API
create_news_api() {
    if [[ "$INSTALL_NEWS_API" != "y" ]]; then
        return 0
    fi
    
    print_header "$NEWS TẠO NEWS CONTENT API"
    
    # Create News API Dockerfile
    cat > $INSTALL_DIR/news_api/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Start application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
EOF

    # Create requirements.txt
    cat > $INSTALL_DIR/news_api/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
newspaper4k==0.9.3
pydantic==2.5.0
python-multipart==0.0.6
user-agents==2.2.0
requests==2.31.0
lxml==4.9.3
Pillow==10.1.0
python-dateutil==2.8.2
feedparser==6.0.10
beautifulsoup4==4.12.2
nltk==3.8.1
EOF

    # Create main.py with improved newspaper4k usage and random user agents
    cat > $INSTALL_DIR/news_api/main.py << 'EOF'
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, HttpUrl, Field
from typing import List, Optional, Dict, Any
import newspaper
from newspaper import Article, Source
import requests
from user_agents import parse
import random
import logging
import os
import re
from datetime import datetime
import feedparser
from urllib.parse import urljoin, urlparse
import time

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="News Content API",
    description="Advanced News Content Extraction API with Newspaper4k",
    version="3.0.0",
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
NEWS_API_TOKEN = os.getenv("NEWS_API_TOKEN", "your-secret-token")

# Random User Agents Pool
USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:121.0) Gecko/20100101 Firefox/121.0",
    "Mozilla/5.0 (X11; Linux x86_64; rv:121.0) Gecko/20100101 Firefox/121.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Edge/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0"
]

def get_random_user_agent():
    """Get a random user agent from the pool"""
    return random.choice(USER_AGENTS)

def get_random_headers():
    """Get random headers for requests"""
    user_agent = get_random_user_agent()
    ua = parse(user_agent)
    
    headers = {
        'User-Agent': user_agent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,vi;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'DNT': '1',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
    }
    
    # Add browser-specific headers
    if 'Chrome' in user_agent:
        headers['sec-ch-ua'] = '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"'
        headers['sec-ch-ua-mobile'] = '?0'
        headers['sec-ch-ua-platform'] = '"Windows"' if 'Windows' in user_agent else '"macOS"' if 'Mac' in user_agent else '"Linux"'
        headers['Sec-Fetch-Dest'] = 'document'
        headers['Sec-Fetch-Mode'] = 'navigate'
        headers['Sec-Fetch-Site'] = 'none'
        headers['Sec-Fetch-User'] = '?1'
    
    return headers

async def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Verify Bearer token"""
    if credentials.credentials != NEWS_API_TOKEN:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return credentials.credentials

# Pydantic models
class ArticleRequest(BaseModel):
    url: HttpUrl
    language: str = Field(default="auto", description="Language code (auto, en, vi, zh, etc.)")
    extract_images: bool = Field(default=True, description="Extract images from article")
    summarize: bool = Field(default=False, description="Generate article summary")
    extract_keywords: bool = Field(default=False, description="Extract keywords using NLP")

class SourceRequest(BaseModel):
    url: HttpUrl
    max_articles: int = Field(default=10, ge=1, le=50, description="Maximum number of articles to extract")
    language: str = Field(default="auto", description="Language code")
    category_filter: Optional[str] = Field(default=None, description="Filter by category")

class FeedRequest(BaseModel):
    url: HttpUrl
    max_articles: int = Field(default=10, ge=1, le=50, description="Maximum number of articles to parse")

class ArticleResponse(BaseModel):
    title: Optional[str]
    content: Optional[str]
    summary: Optional[str]
    authors: List[str]
    publish_date: Optional[str]
    images: List[str]
    top_image: Optional[str]
    videos: List[str]
    keywords: List[str]
    language: Optional[str]
    word_count: int
    read_time_minutes: int
    url: str
    source_domain: str

class SourceResponse(BaseModel):
    source_url: str
    articles: List[ArticleResponse]
    total_articles: int
    categories: List[str]

class FeedResponse(BaseModel):
    feed_url: str
    feed_title: Optional[str]
    feed_description: Optional[str]
    articles: List[Dict[str, Any]]
    total_articles: int

@app.get("/", response_class=HTMLResponse)
async def homepage():
    """API Homepage with documentation"""
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>News Content API</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
            .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 10px; padding: 30px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
            h2 { color: #34495e; margin-top: 30px; }
            .endpoint { background: #ecf0f1; padding: 15px; border-radius: 5px; margin: 10px 0; border-left: 4px solid #3498db; }
            .method { background: #27ae60; color: white; padding: 3px 8px; border-radius: 3px; font-size: 12px; font-weight: bold; }
            .method.post { background: #e74c3c; }
            code { background: #f8f9fa; padding: 2px 6px; border-radius: 3px; font-family: 'Monaco', 'Consolas', monospace; }
            .warning { background: #fff3cd; border: 1px solid #ffeaa7; color: #856404; padding: 15px; border-radius: 5px; margin: 20px 0; }
            .info { background: #d1ecf1; border: 1px solid #bee5eb; color: #0c5460; padding: 15px; border-radius: 5px; margin: 20px 0; }
            .token-section { background: #f8f9fa; border: 1px solid #dee2e6; padding: 20px; border-radius: 5px; margin: 20px 0; }
            .btn { background: #3498db; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 5px; }
            .btn:hover { background: #2980b9; }
            pre { background: #2c3e50; color: #ecf0f1; padding: 15px; border-radius: 5px; overflow-x: auto; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>📰 News Content API v3.0</h1>
            <p>Advanced news content extraction API powered by <strong>Newspaper4k</strong> with random user agents and anti-detection features.</p>
            
            <div class="warning">
                <strong>🔐 Authentication Required:</strong> All API endpoints require a Bearer token in the Authorization header.
                <br><strong>Note:</strong> The actual token is configured during installation and not displayed here for security reasons.
            </div>
            
            <div class="token-section">
                <h3>🔑 How to Change Bearer Token</h3>
                <p>To change your Bearer token, use one of these methods:</p>
                
                <h4>Method 1: One-liner command</h4>
                <pre>cd /home/n8n && sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN="NEW_TOKEN"/' docker-compose.yml && docker-compose restart fastapi</pre>
                
                <h4>Method 2: Edit file directly</h4>
                <pre>nano /home/n8n/docker-compose.yml
# Find and edit the NEWS_API_TOKEN line
docker-compose restart fastapi</pre>
                
                <h4>Method 3: Using environment variable</h4>
                <pre>export NEWS_API_TOKEN="your-new-token"
docker-compose restart fastapi</pre>
            </div>
            
            <h2>📋 API Endpoints</h2>
            
            <div class="endpoint">
                <span class="method">GET</span> <strong>/health</strong>
                <p>Check API health status</p>
            </div>
            
            <div class="endpoint">
                <span class="method post">POST</span> <strong>/extract-article</strong>
                <p>Extract content from a single article URL</p>
                <pre>{
  "url": "https://example.com/article",
  "language": "auto",
  "extract_images": true,
  "summarize": false,
  "extract_keywords": false
}</pre>
            </div>
            
            <div class="endpoint">
                <span class="method post">POST</span> <strong>/extract-source</strong>
                <p>Extract multiple articles from a news website</p>
                <pre>{
  "url": "https://example.com",
  "max_articles": 10,
  "language": "auto"
}</pre>
            </div>
            
            <div class="endpoint">
                <span class="method post">POST</span> <strong>/parse-feed</strong>
                <p>Parse RSS/Atom feeds</p>
                <pre>{
  "url": "https://example.com/rss.xml",
  "max_articles": 10
}</pre>
            </div>
            
            <h2>🔧 Example Usage</h2>
            <pre>curl -X POST "https://api.yourdomain.com/extract-article" \\
     -H "Content-Type: application/json" \\
     -H "Authorization: Bearer YOUR_TOKEN" \\
     -d '{
       "url": "https://example.com/article",
       "language": "vi",
       "extract_images": true,
       "summarize": true
     }'</pre>
            
            <div class="info">
                <strong>💡 Features:</strong>
                <ul>
                    <li>🔄 Random User Agents for anti-detection</li>
                    <li>🌍 Multi-language support (80+ languages)</li>
                    <li>📸 Image and video extraction</li>
                    <li>🔍 Keyword extraction with NLP</li>
                    <li>📝 Automatic summarization</li>
                    <li>📡 RSS/Atom feed parsing</li>
                    <li>🚀 High-performance async processing</li>
                </ul>
            </div>
            
            <h2>📚 Documentation</h2>
            <a href="/docs" class="btn">📖 Swagger UI</a>
            <a href="/redoc" class="btn">📋 ReDoc</a>
            
            <hr style="margin: 30px 0;">
            <p style="text-align: center; color: #7f8c8d;">
                <strong>News Content API v3.0</strong> | 
                Powered by <a href="https://newspaper.readthedocs.io/" target="_blank">Newspaper4k</a> | 
                Built with ❤️ by <a href="https://www.youtube.com/@kalvinthiensocial" target="_blank">Kalvin Thien</a>
            </p>
        </div>
    </body>
    </html>
    """

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "version": "3.0.0",
        "features": {
            "newspaper4k": True,
            "random_user_agents": True,
            "multi_language": True,
            "image_extraction": True,
            "nlp_processing": True,
            "rss_parsing": True
        }
    }

@app.post("/extract-article", response_model=ArticleResponse)
async def extract_article(request: ArticleRequest, token: str = Depends(verify_token)):
    """Extract content from a single article URL"""
    try:
        # Create article with random user agent
        headers = get_random_headers()
        
        # Configure newspaper
        config = newspaper.Config()
        config.browser_user_agent = headers['User-Agent']
        config.request_timeout = 30
        config.number_threads = 1
        config.thread_timeout_seconds = 30
        
        # Set language if specified
        if request.language != "auto":
            config.language = request.language
        
        # Create and download article
        article = Article(str(request.url), config=config)
        
        # Set custom headers for the request
        article.download()
        article.parse()
        
        # Extract keywords and summary if requested
        keywords = []
        summary = None
        
        if request.extract_keywords or request.summarize:
            try:
                article.nlp()
                if request.extract_keywords:
                    keywords = article.keywords
                if request.summarize:
                    summary = article.summary
            except Exception as e:
                logger.warning(f"NLP processing failed: {e}")
        
        # Calculate reading time (average 200 words per minute)
        word_count = len(article.text.split()) if article.text else 0
        read_time = max(1, round(word_count / 200))
        
        # Extract domain
        domain = urlparse(str(request.url)).netloc
        
        # Format publish date
        publish_date = None
        if article.publish_date:
            publish_date = article.publish_date.isoformat()
        
        return ArticleResponse(
            title=article.title,
            content=article.text,
            summary=summary,
            authors=article.authors,
            publish_date=publish_date,
            images=list(article.images) if request.extract_images else [],
            top_image=article.top_image,
            videos=article.movies,
            keywords=keywords,
            language=article.meta_lang or request.language,
            word_count=word_count,
            read_time_minutes=read_time,
            url=str(request.url),
            source_domain=domain
        )
        
    except Exception as e:
        logger.error(f"Error extracting article {request.url}: {e}")
        raise HTTPException(
            status_code=400,
            detail=f"Failed to extract article: {str(e)}"
        )

@app.post("/extract-source", response_model=SourceResponse)
async def extract_source(request: SourceRequest, token: str = Depends(verify_token)):
    """Extract multiple articles from a news website"""
    try:
        # Configure newspaper with random user agent
        headers = get_random_headers()
        
        config = newspaper.Config()
        config.browser_user_agent = headers['User-Agent']
        config.request_timeout = 30
        config.number_threads = 3
        config.thread_timeout_seconds = 30
        
        if request.language != "auto":
            config.language = request.language
        
        # Build source
        source = newspaper.build(str(request.url), config=config)
        
        # Get categories
        categories = []
        try:
            categories = source.category_urls()
        except:
            pass
        
        # Limit articles
        articles_to_process = source.articles[:request.max_articles]
        
        # Download and parse articles
        extracted_articles = []
        for article in articles_to_process:
            try:
                article.download()
                article.parse()
                
                # Calculate reading time
                word_count = len(article.text.split()) if article.text else 0
                read_time = max(1, round(word_count / 200))
                
                # Extract domain
                domain = urlparse(article.url).netloc
                
                # Format publish date
                publish_date = None
                if article.publish_date:
                    publish_date = article.publish_date.isoformat()
                
                extracted_articles.append(ArticleResponse(
                    title=article.title,
                    content=article.text,
                    summary=None,
                    authors=article.authors,
                    publish_date=publish_date,
                    images=list(article.images),
                    top_image=article.top_image,
                    videos=article.movies,
                    keywords=[],
                    language=article.meta_lang or request.language,
                    word_count=word_count,
                    read_time_minutes=read_time,
                    url=article.url,
                    source_domain=domain
                ))
                
                # Add delay to avoid being blocked
                time.sleep(0.5)
                
            except Exception as e:
                logger.warning(f"Failed to extract article {article.url}: {e}")
                continue
        
        return SourceResponse(
            source_url=str(request.url),
            articles=extracted_articles,
            total_articles=len(extracted_articles),
            categories=categories
        )
        
    except Exception as e:
        logger.error(f"Error extracting source {request.url}: {e}")
        raise HTTPException(
            status_code=400,
            detail=f"Failed to extract source: {str(e)}"
        )

@app.post("/parse-feed", response_model=FeedResponse)
async def parse_feed(request: FeedRequest, token: str = Depends(verify_token)):
    """Parse RSS/Atom feeds"""
    try:
        # Get random headers
        headers = get_random_headers()
        
        # Parse feed with custom headers
        response = requests.get(str(request.url), headers=headers, timeout=30)
        response.raise_for_status()
        
        feed = feedparser.parse(response.content)
        
        if feed.bozo:
            raise HTTPException(
                status_code=400,
                detail="Invalid feed format"
            )
        
        # Extract feed info
        feed_title = getattr(feed.feed, 'title', None)
        feed_description = getattr(feed.feed, 'description', None)
        
        # Process entries
        articles = []
        entries_to_process = feed.entries[:request.max_articles]
        
        for entry in entries_to_process:
            article_data = {
                "title": getattr(entry, 'title', None),
                "link": getattr(entry, 'link', None),
                "description": getattr(entry, 'description', None),
                "summary": getattr(entry, 'summary', None),
                "published": getattr(entry, 'published', None),
                "author": getattr(entry, 'author', None),
                "tags": [tag.term for tag in getattr(entry, 'tags', [])],
                "guid": getattr(entry, 'guid', None)
            }
            articles.append(article_data)
        
        return FeedResponse(
            feed_url=str(request.url),
            feed_title=feed_title,
            feed_description=feed_description,
            articles=articles,
            total_articles=len(articles)
        )
        
    except requests.RequestException as e:
        logger.error(f"Error fetching feed {request.url}: {e}")
        raise HTTPException(
            status_code=400,
            detail=f"Failed to fetch feed: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Error parsing feed {request.url}: {e}")
        raise HTTPException(
            status_code=400,
            detail=f"Failed to parse feed: {str(e)}"
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

    print_success "News Content API đã được tạo với Newspaper4k và Random User Agent!"
}

# Function to create N8N Dockerfile
create_n8n_dockerfile() {
    print_header "$GEAR TẠO N8N DOCKERFILE"
    
    cat > $INSTALL_DIR/Dockerfile << 'EOF'
FROM n8nio/n8n:latest

USER root

# Install system dependencies
RUN apk add --no-cache \
    ffmpeg \
    python3 \
    py3-pip \
    chromium \
    chromium-chromedriver \
    curl \
    wget \
    git \
    bash \
    && rm -rf /var/cache/apk/*

# Install yt-dlp
RUN pip3 install --break-system-packages yt-dlp

# Install Puppeteer dependencies
RUN npm install -g puppeteer

# Set Chrome path for Puppeteer
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV CHROME_BIN=/usr/bin/chromium-browser
ENV CHROME_PATH=/usr/bin/chromium-browser

# Create directories
RUN mkdir -p /home/node/.n8n/nodes
RUN mkdir -p /data/youtube_content_anylystic

# Set permissions
RUN chown -R node:node /home/node/.n8n
RUN chown -R node:node /data

USER node

# Install additional N8N nodes
RUN npm install -g n8n-nodes-puppeteer

WORKDIR /data

CMD ["n8n"]
EOF

    print_success "N8N Dockerfile đã được tạo!"
}

# Function to create docker-compose.yml
create_docker_compose() {
    print_header "$GEAR TẠO DOCKER COMPOSE"
    
    # Create base docker-compose
    cat > $INSTALL_DIR/docker-compose.yml << EOF
version: '3.8'

services:
  n8n:
    build: .
    image: n8n-custom-ffmpeg:latest
    container_name: n8n-n8n-1
    restart: unless-stopped
    ports:
      - "127.0.0.1:5678:5678"
    environment:
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://$DOMAIN
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
      - N8N_METRICS=true
      - N8N_LOG_LEVEL=info
      - N8N_PERSONALIZATION_ENABLED=false
      - N8N_VERSION_NOTIFICATIONS_ENABLED=false
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_DEFAULT_BINARY_DATA_MODE=filesystem
      - N8N_BINARY_DATA_TTL=24
      - N8N_EXECUTIONS_DATA_SAVE_ON_ERROR=all
      - N8N_EXECUTIONS_DATA_SAVE_ON_SUCCESS=all
      - N8N_EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS=true
      - N8N_EXECUTIONS_DATA_PRUNE=true
      - N8N_EXECUTIONS_DATA_MAX_AGE=168
    volumes:
      - ./files:/data
      - ./database.sqlite:/data/database.sqlite
      - ./encryptionKey:/data/encryptionKey
    networks:
      - default
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

EOF

    # Add News API service if enabled
    if [[ "$INSTALL_NEWS_API" == "y" ]]; then
        cat >> $INSTALL_DIR/docker-compose.yml << EOF
  fastapi:
    build: ./news_api
    image: news-api:latest
    container_name: n8n-fastapi-1
    restart: unless-stopped
    ports:
      - "127.0.0.1:8000:8000"
    environment:
      - NEWS_API_TOKEN=$BEARER_TOKEN
    volumes:
      - ./logs:/app/logs
    networks:
      - default
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

EOF
    fi

    # Add Caddy service
    cat >> $INSTALL_DIR/docker-compose.yml << EOF
  caddy:
    image: caddy:latest
    container_name: n8n-caddy-1
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
      - ./logs:/var/log/caddy
    networks:
      - default
    depends_on:
      - n8n
EOF

    # Add depends_on for fastapi if enabled
    if [[ "$INSTALL_NEWS_API" == "y" ]]; then
        cat >> $INSTALL_DIR/docker-compose.yml << EOF
      - fastapi
EOF
    fi

    # Add volumes and networks
    cat >> $INSTALL_DIR/docker-compose.yml << EOF

volumes:
  caddy_data:
  caddy_config:

networks:
  default:
    name: n8n_default
EOF

    print_success "Docker Compose đã được tạo!"
}

# Function to create Caddyfile
create_caddyfile() {
    print_header "$LOCK TẠO CADDYFILE"
    
    cat > $INSTALL_DIR/Caddyfile << EOF
{
    email admin@$DOMAIN
    acme_ca https://acme-v02.api.letsencrypt.org/directory
}

$DOMAIN {
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

    # Add API domain if News API is enabled
    if [[ "$INSTALL_NEWS_API" == "y" ]]; then
        cat >> $INSTALL_DIR/Caddyfile << EOF

$API_DOMAIN {
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

    print_success "Caddyfile đã được tạo!"
}

# Function to create backup scripts
create_backup_scripts() {
    print_header "$BACKUP TẠO BACKUP SCRIPTS"
    
    # Create backup script
    cat > $INSTALL_DIR/backup-workflows.sh << 'EOF'
#!/bin/bash

# N8N Backup Script with Telegram Integration
# Tác giả: Nguyễn Ngọc Thiện

BACKUP_DIR="/home/n8n/files/backup_full"
LOG_FILE="$BACKUP_DIR/backup.log"
TELEGRAM_CONFIG="/home/n8n/telegram_config.txt"
DOCKER_COMPOSE_CMD=""

# Detect Docker Compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    echo "ERROR: Docker Compose not found!" | tee -a "$LOG_FILE"
    exit 1
fi

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to send Telegram message
send_telegram_message() {
    local message="$1"
    local file_path="$2"
    
    if [[ ! -f "$TELEGRAM_CONFIG" ]]; then
        return 0
    fi
    
    source "$TELEGRAM_CONFIG"
    
    if [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
        return 0
    fi
    
    # Send text message
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$message" \
        -d parse_mode="HTML" > /dev/null
    
    # Send file if provided and size < 20MB
    if [[ -n "$file_path" && -f "$file_path" ]]; then
        local file_size=$(stat -c%s "$file_path")
        local max_size=$((20 * 1024 * 1024))  # 20MB
        
        if [[ $file_size -lt $max_size ]]; then
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument" \
                -F chat_id="$TELEGRAM_CHAT_ID" \
                -F document=@"$file_path" \
                -F caption="📦 N8N Backup File" > /dev/null
        else
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
                -d chat_id="$TELEGRAM_CHAT_ID" \
                -d text="📦 Backup completed but file too large for Telegram ($(($file_size / 1024 / 1024))MB > 20MB)" > /dev/null
        fi
    fi
}

# Start backup
log_message "🚀 Starting N8N backup process..."

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Generate backup filename
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/n8n_backup_$TIMESTAMP.tar.gz"
TEMP_DIR="/tmp/n8n_backup_$TIMESTAMP"

# Create temporary directory
mkdir -p "$TEMP_DIR"

# Change to N8N directory
cd /home/n8n

# Export workflows from N8N
log_message "📋 Exporting workflows..."
mkdir -p "$TEMP_DIR/workflows"

# Get workflows via N8N API (if running)
if curl -s http://localhost:5678/healthz > /dev/null 2>&1; then
    curl -s http://localhost:5678/rest/workflows | jq '.' > "$TEMP_DIR/workflows/workflows.json" 2>/dev/null || log_message "⚠️ Could not export workflows via API"
else
    log_message "⚠️ N8N not running, skipping API export"
fi

# Copy database and encryption key
log_message "💾 Copying database and encryption key..."
mkdir -p "$TEMP_DIR/credentials"

if [[ -f "database.sqlite" ]]; then
    cp database.sqlite "$TEMP_DIR/credentials/"
    log_message "✅ Database copied"
else
    log_message "⚠️ Database file not found"
fi

if [[ -f "encryptionKey" ]]; then
    cp encryptionKey "$TEMP_DIR/credentials/"
    log_message "✅ Encryption key copied"
else
    log_message "⚠️ Encryption key not found"
fi

# Copy config files
log_message "⚙️ Copying configuration files..."
mkdir -p "$TEMP_DIR/config"

for config_file in docker-compose.yml Caddyfile; do
    if [[ -f "$config_file" ]]; then
        cp "$config_file" "$TEMP_DIR/config/"
        log_message "✅ $config_file copied"
    fi
done

# Create backup metadata
log_message "📊 Creating backup metadata..."
cat > "$TEMP_DIR/backup_metadata.json" << EOF
{
    "backup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "backup_version": "3.0",
    "n8n_version": "$(docker exec n8n-n8n-1 n8n --version 2>/dev/null || echo 'unknown')",
    "server_hostname": "$(hostname)",
    "backup_size_bytes": 0,
    "files_included": {
        "workflows": true,
        "database": $([ -f "database.sqlite" ] && echo "true" || echo "false"),
        "encryption_key": $([ -f "encryptionKey" ] && echo "true" || echo "false"),
        "config_files": true
    }
}
EOF

# Create compressed backup
log_message "📦 Creating compressed backup..."
cd /tmp
tar -czf "$BACKUP_FILE" "n8n_backup_$TIMESTAMP/"

# Update metadata with actual size
if [[ -f "$BACKUP_FILE" ]]; then
    BACKUP_SIZE=$(stat -c%s "$BACKUP_FILE")
    sed -i "s/\"backup_size_bytes\": 0/\"backup_size_bytes\": $BACKUP_SIZE/" "$TEMP_DIR/backup_metadata.json"
    
    # Recreate backup with updated metadata
    tar -czf "$BACKUP_FILE" "n8n_backup_$TIMESTAMP/"
    
    log_message "✅ Backup created: $BACKUP_FILE ($(($BACKUP_SIZE / 1024 / 1024))MB)"
else
    log_message "❌ Failed to create backup file"
    send_telegram_message "❌ <b>N8N Backup Failed</b>%0A%0ABackup file creation failed on $(hostname)"
    exit 1
fi

# Cleanup temp directory
rm -rf "$TEMP_DIR"

# Cleanup old backups (keep last 30)
log_message "🧹 Cleaning up old backups..."
cd "$BACKUP_DIR"
ls -t n8n_backup_*.tar.gz | tail -n +31 | xargs -r rm -f
REMAINING_BACKUPS=$(ls -1 n8n_backup_*.tar.gz 2>/dev/null | wc -l)
log_message "📂 Keeping $REMAINING_BACKUPS backup files"

# Send Telegram notification
BACKUP_SIZE_MB=$(($BACKUP_SIZE / 1024 / 1024))
TELEGRAM_MESSAGE="✅ <b>N8N Backup Completed</b>%0A%0A📅 Date: $(date '+%d/%m/%Y %H:%M')%0A💾 Size: ${BACKUP_SIZE_MB}MB%0A📂 Total backups: $REMAINING_BACKUPS%0A🖥️ Server: $(hostname)"

send_telegram_message "$TELEGRAM_MESSAGE" "$BACKUP_FILE"

log_message "🎉 Backup process completed successfully!"
EOF

    chmod +x $INSTALL_DIR/backup-workflows.sh

    # Create manual backup test script
    cat > $INSTALL_DIR/backup-manual.sh << 'EOF'
#!/bin/bash

echo "🧪 MANUAL BACKUP TEST"
echo "===================="

# Run backup script
/home/n8n/backup-workflows.sh

echo ""
echo "📋 BACKUP RESULTS:"
echo "=================="

# Show latest backup
LATEST_BACKUP=$(ls -t /home/n8n/files/backup_full/n8n_backup_*.tar.gz 2>/dev/null | head -1)

if [[ -n "$LATEST_BACKUP" ]]; then
    echo "✅ Latest backup: $(basename "$LATEST_BACKUP")"
    echo "📊 Size: $(du -h "$LATEST_BACKUP" | cut -f1)"
    echo "📅 Date: $(stat -c %y "$LATEST_BACKUP" | cut -d. -f1)"
    
    echo ""
    echo "📦 Backup contents:"
    tar -tzf "$LATEST_BACKUP" | head -20
    
    if [[ $(tar -tzf "$LATEST_BACKUP" | wc -l) -gt 20 ]]; then
        echo "... and $(($(tar -tzf "$LATEST_BACKUP" | wc -l) - 20)) more files"
    fi
else
    echo "❌ No backup files found!"
fi

echo ""
echo "📂 All backups:"
ls -lah /home/n8n/files/backup_full/n8n_backup_*.tar.gz 2>/dev/null || echo "No backup files found"
EOF

    chmod +x $INSTALL_DIR/backup-manual.sh

    print_success "Backup scripts đã được tạo!"
}

# Function to create update script
create_update_script() {
    if [[ "$ENABLE_AUTO_UPDATE" != "y" ]]; then
        return 0
    fi
    
    print_header "$CLOCK TẠO UPDATE SCRIPT"
    
    cat > $INSTALL_DIR/update-n8n.sh << 'EOF'
#!/bin/bash

# N8N Auto Update Script
# Tác giả: Nguyễn Ngọc Thiện

LOG_FILE="/home/n8n/logs/update.log"
TELEGRAM_CONFIG="/home/n8n/telegram_config.txt"

# Detect Docker Compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    echo "ERROR: Docker Compose not found!" | tee -a "$LOG_FILE"
    exit 1
fi

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to send Telegram notification
send_telegram_notification() {
    local message="$1"
    
    if [[ ! -f "$TELEGRAM_CONFIG" ]]; then
        return 0
    fi
    
    source "$TELEGRAM_CONFIG"
    
    if [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
        return 0
    fi
    
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$message" \
        -d parse_mode="HTML" > /dev/null
}

# Start update process
log_message "🔄 Starting N8N update process..."

cd /home/n8n

# Backup before update
log_message "💾 Creating backup before update..."
/home/n8n/backup-workflows.sh

# Pull latest images
log_message "📥 Pulling latest Docker images..."
$DOCKER_COMPOSE_CMD pull

# Update yt-dlp in running container
log_message "📺 Updating yt-dlp..."
docker exec n8n-n8n-1 pip3 install --break-system-packages -U yt-dlp 2>/dev/null || log_message "⚠️ Could not update yt-dlp"

# Restart containers with new images
log_message "🔄 Restarting containers..."
$DOCKER_COMPOSE_CMD up -d

# Wait for services to be ready
log_message "⏳ Waiting for services to start..."
sleep 30

# Check if N8N is running
if curl -s http://localhost:5678/healthz > /dev/null 2>&1; then
    log_message "✅ N8N is running after update"
    send_telegram_notification "✅ <b>N8N Update Completed</b>%0A%0A📅 Date: $(date '+%d/%m/%Y %H:%M')%0A🖥️ Server: $(hostname)%0A🔄 Status: All services running"
else
    log_message "❌ N8N is not responding after update"
    send_telegram_notification "❌ <b>N8N Update Failed</b>%0A%0A📅 Date: $(date '+%d/%m/%Y %H:%M')%0A🖥️ Server: $(hostname)%0A🔄 Status: N8N not responding"
fi

log_message "🎉 Update process completed!"
EOF

    chmod +x $INSTALL_DIR/update-n8n.sh

    print_success "Update script đã được tạo!"
}

# Function to create troubleshooting script
create_troubleshooting_script() {
    print_header "$GEAR TẠO TROUBLESHOOTING SCRIPT"
    
    cat > $INSTALL_DIR/troubleshoot.sh << 'EOF'
#!/bin/bash

echo "🔍 N8N SYSTEM DIAGNOSTICS"
echo "========================="

DOMAIN_FILE="/home/n8n/.domain"
API_DOMAIN_FILE="/home/n8n/.api_domain"

# Get domains
if [[ -f "$DOMAIN_FILE" ]]; then
    DOMAIN=$(cat "$DOMAIN_FILE")
    API_DOMAIN=$(cat "$API_DOMAIN_FILE" 2>/dev/null || echo "api.$DOMAIN")
else
    echo "⚠️ Domain configuration not found"
    DOMAIN="unknown"
    API_DOMAIN="unknown"
fi

# Detect Docker Compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    echo "❌ Docker Compose not found!"
    exit 1
fi

echo "📍 1. System Information:"
echo "Domain: $DOMAIN"
echo "API Domain: $API_DOMAIN"
echo "Server IP: $(curl -s https://api.ipify.org 2>/dev/null || echo 'Unable to get IP')"
echo "Docker Compose: $DOCKER_COMPOSE"
echo ""

echo "📍 2. DNS Resolution:"
if [[ "$DOMAIN" != "unknown" ]]; then
    echo "Domain IP: $(dig +short $DOMAIN A 2>/dev/null || echo 'DNS lookup failed')"
    echo "API Domain IP: $(dig +short $API_DOMAIN A 2>/dev/null || echo 'DNS lookup failed')"
else
    echo "⚠️ Cannot check DNS - domain unknown"
fi
echo ""

echo "📍 3. Container Status:"
cd /home/n8n 2>/dev/null || echo "⚠️ N8N directory not found"
$DOCKER_COMPOSE ps 2>/dev/null || echo "⚠️ Could not get container status"
echo ""

echo "📍 4. Port Status:"
netstat -tulpn 2>/dev/null | grep -E ":80|:443|:5678|:8000" || echo "⚠️ Could not check ports"
echo ""

echo "📍 5. SSL Certificate Status:"
if [[ "$DOMAIN" != "unknown" ]]; then
    echo "Testing $DOMAIN..."
    echo | openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>/dev/null | openssl x509 -noout -dates -subject -issuer 2>/dev/null || echo "❌ SSL certificate not available"
    
    if [[ "$API_DOMAIN" != "unknown" ]]; then
        echo ""
        echo "Testing $API_DOMAIN..."
        echo | openssl s_client -connect $API_DOMAIN:443 -servername $API_DOMAIN 2>/dev/null | openssl x509 -noout -dates -subject -issuer 2>/dev/null || echo "❌ SSL certificate not available"
    fi
else
    echo "⚠️ Cannot check SSL - domain unknown"
fi
echo ""

echo "📍 6. Service Health Checks:"
if curl -s http://localhost:5678/healthz > /dev/null 2>&1; then
    echo "✅ N8N is responding"
else
    echo "❌ N8N is not responding"
fi

if curl -s http://localhost:8000/health > /dev/null 2>&1; then
    echo "✅ News API is responding"
else
    echo "⚠️ News API is not responding (may not be installed)"
fi
echo ""

echo "📍 7. Recent Logs (last 10 lines):"
echo "--- N8N Logs ---"
$DOCKER_COMPOSE logs --tail=10 n8n 2>/dev/null || echo "⚠️ Could not get N8N logs"
echo ""
echo "--- Caddy Logs ---"
$DOCKER_COMPOSE logs --tail=10 caddy 2>/dev/null || echo "⚠️ Could not get Caddy logs"
echo ""

echo "📍 8. Disk Usage:"
df -h / 2>/dev/null || echo "⚠️ Could not check disk usage"
echo ""

echo "📍 9. Memory Usage:"
free -h 2>/dev/null || echo "⚠️ Could not check memory usage"
echo ""

echo "📍 10. Docker System Info:"
docker system df 2>/dev/null || echo "⚠️ Could not get Docker system info"
echo ""

echo "🔧 QUICK FIX COMMANDS:"
echo "====================="
echo "1. Restart all services:"
echo "   cd /home/n8n && $DOCKER_COMPOSE restart"
echo ""
echo "2. Rebuild and restart:"
echo "   cd /home/n8n && $DOCKER_COMPOSE down && $DOCKER_COMPOSE up -d --build"
echo ""
echo "3. Check logs in real-time:"
echo "   cd /home/n8n && $DOCKER_COMPOSE logs -f"
echo ""
echo "4. Manual backup:"
echo "   /home/n8n/backup-manual.sh"
echo ""
echo "5. Update system:"
echo "   /home/n8n/update-n8n.sh"
echo ""
EOF

    chmod +x $INSTALL_DIR/troubleshoot.sh

    print_success "Troubleshooting script đã được tạo!"
}

# Function to save configuration
save_configuration() {
    print_header "$DATABASE LƯU CẤU HÌNH"
    
    # Save domain info
    echo "$DOMAIN" > $INSTALL_DIR/.domain
    echo "$API_DOMAIN" > $INSTALL_DIR/.api_domain
    
    # Save Bearer token securely
    if [[ "$INSTALL_NEWS_API" == "y" ]]; then
        echo "$BEARER_TOKEN" > $INSTALL_DIR/news_api_token.txt
        chmod 600 $INSTALL_DIR/news_api_token.txt
    fi
    
    # Save Telegram config if enabled
    if [[ "$ENABLE_TELEGRAM_BACKUP" == "y" ]]; then
        cat > $INSTALL_DIR/telegram_config.txt << EOF
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"
EOF
        chmod 600 $INSTALL_DIR/telegram_config.txt
    fi
    
    print_success "Cấu hình đã được lưu!"
}

# Function to setup cron jobs
setup_cron_jobs() {
    if [[ "$ENABLE_AUTO_UPDATE" != "y" && "$INSTALL_NEWS_API" != "y" ]]; then
        return 0
    fi
    
    print_header "$CLOCK THIẾT LẬP CRON JOBS"
    
    # Create cron jobs
    local cron_content=""
    
    # Daily backup at 2:00 AM
    if [[ "$INSTALL_NEWS_API" == "y" ]]; then
        cron_content+="0 2 * * * /home/n8n/backup-workflows.sh >/dev/null 2>&1"$'\n'
    fi
    
    # Auto-update every 12 hours
    if [[ "$ENABLE_AUTO_UPDATE" == "y" ]]; then
        cron_content+="0 */12 * * * /home/n8n/update-n8n.sh >/dev/null 2>&1"$'\n'
    fi
    
    # Install cron jobs
    if [[ -n "$cron_content" ]]; then
        echo "$cron_content" | crontab -
        print_success "Cron jobs đã được thiết lập!"
        
        # Show cron jobs
        print_info "Cron jobs hiện tại:"
        crontab -l | grep -E "(backup-workflows|update-n8n)" || echo "Không có cron jobs nào"
    fi
}

# Function to build and start containers
build_and_start() {
    print_header "$ROCKET XÂY DỰNG VÀ KHỞI ĐỘNG"
    
    cd $INSTALL_DIR
    local DOCKER_COMPOSE=$(detect_docker_compose)
    
    print_info "Đang build Docker images..."
    $DOCKER_COMPOSE build --no-cache
    
    print_info "Đang khởi động containers..."
    $DOCKER_COMPOSE up -d
    
    print_info "Đợi containers khởi động (60 giây)..."
    sleep 60
    
    # Check container status
    print_info "Kiểm tra trạng thái containers..."
    local n8n_status=$($DOCKER_COMPOSE ps n8n | grep -c "Up")
    local caddy_status=$($DOCKER_COMPOSE ps caddy | grep -c "Up")
    
    if [[ $n8n_status -eq 1 ]]; then
        print_success "Container n8n đã chạy thành công."
    else
        print_error "Container n8n không chạy được!"
    fi
    
    if [[ $caddy_status -eq 1 ]]; then
        print_success "Container caddy đã chạy thành công."
    else
        print_error "Container caddy không chạy được!"
    fi
    
    if [[ "$INSTALL_NEWS_API" == "y" ]]; then
        local fastapi_status=$($DOCKER_COMPOSE ps fastapi | grep -c "Up")
        if [[ $fastapi_status -eq 1 ]]; then
            print_success "Container fastapi đã chạy thành công."
        else
            print_error "Container fastapi không chạy được!"
        fi
    fi
}

# Function to check SSL and handle rate limit
check_ssl_and_handle_rate_limit() {
    print_header "$LOCK KIỂM TRA SSL CERTIFICATE"
    
    # Wait for SSL certificate generation
    print_info "Đang chờ SSL certificate được cấp..."
    sleep 30
    
    # Check for rate limit
    if check_ssl_rate_limit "$DOMAIN"; then
        handle_ssl_rate_limit
        return $?
    fi
    
    # Test SSL certificates
    print_info "Kiểm tra SSL certificate cho $DOMAIN..."
    if echo | openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>/dev/null | openssl x509 -noout -dates 2>/dev/null; then
        print_success "SSL certificate cho $DOMAIN đã được cấp thành công!"
    else
        print_warning "SSL cho $DOMAIN có thể chưa sẵn sàng. Đợi thêm vài phút."
    fi
    
    if [[ "$INSTALL_NEWS_API" == "y" ]]; then
        print_info "Kiểm tra SSL certificate cho $API_DOMAIN..."
        if echo | openssl s_client -connect $API_DOMAIN:443 -servername $API_DOMAIN 2>/dev/null | openssl x509 -noout -dates 2>/dev/null; then
            print_success "SSL certificate cho $API_DOMAIN đã được cấp thành công!"
        else
            print_warning "SSL cho $API_DOMAIN có thể chưa sẵn sàng. Đợi thêm vài phút."
        fi
    fi
}

# Function to show final summary
show_final_summary() {
    local swap_info=$(free -h | awk '/^Swap:/ {print $2}')
    
    print_header "$SUCCESS N8N ĐÃ ĐƯỢC CÀI ĐẶT THÀNH CÔNG!"
    
    echo ""
    print_color $GREEN "🌐 Truy cập N8N: https://$DOMAIN"
    
    if [[ "$INSTALL_NEWS_API" == "y" ]]; then
        print_color $GREEN "📰 Truy cập News API: https://$API_DOMAIN"
        print_color $GREEN "📚 API Documentation: https://$API_DOMAIN/docs"
        print_color $YELLOW "🔑 Bearer Token: *** (đã ẩn vì bảo mật)"
        echo ""
        print_info "Để xem Bearer Token:"
        echo "  cat $INSTALL_DIR/news_api_token.txt"
        echo ""
        print_info "Để đổi Bearer Token:"
        echo "  cd $INSTALL_DIR && sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN=\"NEW_TOKEN\"/' docker-compose.yml && docker-compose restart fastapi"
    fi
    
    echo ""
    print_color $CYAN "📁 Thư mục cài đặt: $INSTALL_DIR"
    print_color $CYAN "🔧 Script chẩn đoán: $INSTALL_DIR/troubleshoot.sh"
    print_color $CYAN "🧪 Test backup: $INSTALL_DIR/backup-manual.sh"
    
    echo ""
    print_color $PURPLE "💾 Swap: $swap_info"
    print_color $PURPLE "🔄 Auto-update: $([ "$ENABLE_AUTO_UPDATE" == "y" ] && echo "Enabled (mỗi 12h)" || echo "Disabled")"
    print_color $PURPLE "📱 Telegram backup: $([ "$ENABLE_TELEGRAM_BACKUP" == "y" ] && echo "Enabled" || echo "Disabled")"
    
    if [[ "$INSTALL_NEWS_API" == "y" ]]; then
        print_color $PURPLE "💾 Backup tự động: Hàng ngày lúc 2:00 AM"
        print_color $PURPLE "📂 Backup location: $INSTALL_DIR/files/backup_full/"
    fi
    
    echo ""
    print_color $WHITE "🚀 Tác giả: Nguyễn Ngọc Thiện"
    print_color $WHITE "📺 YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1"
    print_color $WHITE "📱 Zalo: 08.8888.4749"
    
    print_color $PURPLE "========================================================================"
    echo ""
    
    # Show additional info if staging SSL was used
    if [[ -f "$INSTALL_DIR/convert-to-production-ssl.sh" ]]; then
        print_warning "STAGING SSL ĐƯỢC SỬ DỤNG:"
        echo "• Website sẽ hiển thị cảnh báo 'Not Secure'"
        echo "• Chức năng hoạt động bình thường"
        echo "• Để chuyển về Production SSL sau 7 ngày:"
        echo "  $INSTALL_DIR/convert-to-production-ssl.sh"
        echo ""
    fi
}

# Main execution
main() {
    print_header "$ROCKET SCRIPT CÀI ĐẶT N8N TỰ ĐỘNG v3.0"
    
    print_info "Tác giả: Nguyễn Ngọc Thiện"
    print_info "YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1"
    print_info "Cập nhật: 28/12/2024"
    echo ""
    
    # Step 1: Get user input
    get_user_input
    
    # Step 2: Check DNS
    check_dns
    
    # Step 3: Setup swap
    setup_swap
    
    # Step 4: Install Docker
    install_docker
    
    # Step 5: Clean old installation
    clean_old_installation
    
    # Step 6: Create directory structure
    create_directory_structure
    
    # Step 7: Create News API (if enabled)
    create_news_api
    
    # Step 8: Create N8N Dockerfile
    create_n8n_dockerfile
    
    # Step 9: Create Docker Compose
    create_docker_compose
    
    # Step 10: Create Caddyfile
    create_caddyfile
    
    # Step 11: Create backup scripts
    create_backup_scripts
    
    # Step 12: Create update script
    create_update_script
    
    # Step 13: Create troubleshooting script
    create_troubleshooting_script
    
    # Step 14: Save configuration
    save_configuration
    
    # Step 15: Setup cron jobs
    setup_cron_jobs
    
    # Step 16: Build and start containers
    build_and_start
    
    # Step 17: Check SSL and handle rate limit
    check_ssl_and_handle_rate_limit
    
    # Step 18: Show final summary
    show_final_summary
}

# Run main function
main "$@"
