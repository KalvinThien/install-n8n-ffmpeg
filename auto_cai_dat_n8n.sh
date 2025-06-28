#!/bin/bash

# =============================================================================
# 🚀 SCRIPT CÀI ĐẶT N8N TỰ ĐỘNG VỚI FFMPEG, YT-DLP, PUPPETEER VÀ NEWS API
# =============================================================================
# 
# Tác giả: Nguyễn Ngọc Thiện
# YouTube: https://www.youtube.com/@kalvinthiensocial
# Facebook: https://www.facebook.com/Ban.Thien.Handsome/
# Zalo/Phone: 08.8888.4749
# Cập nhật: 28/06/2025
#
# Tính năng:
# - N8N với FFmpeg, yt-dlp, Puppeteer
# - News Content API (FastAPI + Newspaper4k)
# - SSL tự động với Caddy
# - Telegram Backup System
# - Smart Backup & Auto-Update
# - Rate Limit Detection & Handling
# =============================================================================

set -e

# =============================================================================
# 🎨 THIẾT LẬP MÀU SẮC VÀ LOGGING
# =============================================================================

# Màu sắc dễ đọc trên terminal đen
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'    # Thay đổi từ xanh dương sang cyan
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${CYAN}ℹ️ $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_header() {
    echo ""
    echo -e "${WHITE}========================================================================${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${WHITE}========================================================================${NC}"
    echo ""
}

log_message() {
    echo -e "${PURPLE}📝 $1${NC}"
}

# =============================================================================
# 🔧 BIẾN TOÀN CỤC
# =============================================================================

INSTALL_DIR="/home/n8n"
DOMAIN=""
NEWS_API_ENABLED=false
NEWS_API_TOKEN=""
TELEGRAM_ENABLED=false
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
AUTO_UPDATE_ENABLED=false
CLEANUP_OLD=false

# =============================================================================
# 🛠️ CÁC HÀM TIỆN ÍCH
# =============================================================================

# Kiểm tra quyền root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Script này cần chạy với quyền root (sudo)"
        exit 1
    fi
}

# Hiển thị banner
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🚀 N8N AUTOMATION INSTALLER 2025 🚀                      ║
║                                                                              ║
║  📺 YouTube: https://www.youtube.com/@kalvinthiensocial                     ║
║  📘 Facebook: https://www.facebook.com/Ban.Thien.Handsome/                 ║
║  📱 Zalo: 08.8888.4749                                                      ║
║                                                                              ║
║  ✨ Tính năng:                                                              ║
║  🤖 N8N + FFmpeg + yt-dlp + Puppeteer                                      ║
║  📰 News Content API (FastAPI + Newspaper4k)                               ║
║  🔒 SSL tự động với Caddy                                                   ║
║  📱 Telegram Backup System                                                  ║
║  💾 Smart Backup & Auto-Update                                             ║
║  🚨 SSL Rate Limit Detection                                               ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Xử lý tham số dòng lệnh
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                CLEANUP_OLD=true
                shift
                ;;
            -d|--directory)
                INSTALL_DIR="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Tham số không hợp lệ: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Hiển thị trợ giúp
show_help() {
    echo "Cách sử dụng: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --clean              Xóa cài đặt cũ trước khi cài mới"
    echo "  -d, --directory DIR  Thư mục cài đặt (mặc định: /home/n8n)"
    echo "  -h, --help           Hiển thị trợ giúp này"
    echo ""
    echo "Ví dụ:"
    echo "  $0 --clean"
    echo "  $0 -d /custom/path"
}

# Kiểm tra hệ điều hành
check_os() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Không thể xác định hệ điều hành"
        exit 1
    fi
    
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        log_warning "Script được thiết kế cho Ubuntu. Hệ điều hành hiện tại: $ID"
        read -p "Bạn có muốn tiếp tục? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Kiểm tra kết nối internet
check_internet() {
    log_info "Kiểm tra kết nối internet..."
    if ! ping -c 1 google.com &> /dev/null; then
        log_error "Không có kết nối internet"
        exit 1
    fi
    log_success "Kết nối internet OK"
}

# =============================================================================
# 📝 THU THẬP THÔNG TIN TỪ NGƯỜI DÙNG
# =============================================================================

collect_user_input() {
    log_header "📝 THU THẬP THÔNG TIN CÀI ĐẶT"
    
    # Domain chính
    while [[ -z "$DOMAIN" ]]; do
        read -p "🌐 Nhập domain chính cho N8N (ví dụ: n8n.example.com): " DOMAIN
        if [[ -z "$DOMAIN" ]]; then
            log_error "Domain không được để trống!"
        fi
    done
    
    # Cleanup option
    if [[ "$CLEANUP_OLD" == false ]]; then
        read -p "🗑️ Xóa cài đặt cũ (nếu có)? (Y/n): " -r
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            CLEANUP_OLD=false
        else
            CLEANUP_OLD=true
        fi
    fi
    
    # News API
    read -p "📰 Bạn có muốn cài đặt News Content API? (Y/n): " -r
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        NEWS_API_ENABLED=true
        
        while [[ ${#NEWS_API_TOKEN} -lt 20 ]]; do
            read -p "🔑 Đặt Bearer Token cho API (ít nhất 20 ký tự): " NEWS_API_TOKEN
            if [[ ${#NEWS_API_TOKEN} -lt 20 ]]; then
                log_error "Token phải có ít nhất 20 ký tự!"
            fi
        done
    fi
    
    # Telegram backup
    log_info "📱 THIẾT LẬP TELEGRAM BACKUP"
    read -p "Bạn có muốn thiết lập backup qua Telegram? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        TELEGRAM_ENABLED=true
        
        while [[ -z "$TELEGRAM_BOT_TOKEN" ]]; do
            read -p "🤖 Nhập Telegram Bot Token: " TELEGRAM_BOT_TOKEN
        done
        
        while [[ -z "$TELEGRAM_CHAT_ID" ]]; do
            read -p "💬 Nhập Telegram Chat ID: " TELEGRAM_CHAT_ID
        done
    fi
    
    # Auto update
    read -p "🔄 Bạn có muốn bật tự động cập nhật? (Y/n): " -r
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        AUTO_UPDATE_ENABLED=true
    fi
}

# =============================================================================
# 🌐 KIỂM TRA DNS
# =============================================================================

check_dns() {
    log_header "🌐 KIỂM TRA DNS"
    
    log_info "Đang kiểm tra DNS cho $DOMAIN..."
    
    # Lấy IP của domain
    DOMAIN_IP=$(dig +short "$DOMAIN" A | tail -n1)
    if [[ -z "$DOMAIN_IP" ]]; then
        log_error "Không thể resolve domain $DOMAIN"
        log_error "Vui lòng kiểm tra DNS settings"
        exit 1
    fi
    
    # Lấy IP của server
    SERVER_IP=$(curl -s https://api.ipify.org)
    if [[ -z "$SERVER_IP" ]]; then
        log_error "Không thể lấy IP của server"
        exit 1
    fi
    
    log_info "IP của domain $DOMAIN: $DOMAIN_IP"
    log_info "IP của server: $SERVER_IP"
    
    if [[ "$DOMAIN_IP" == "$SERVER_IP" ]]; then
        log_success "DNS đã được cấu hình đúng!"
    else
        log_error "DNS chưa được cấu hình đúng!"
        log_error "Domain $DOMAIN trỏ về $DOMAIN_IP nhưng server có IP $SERVER_IP"
        read -p "Bạn có muốn tiếp tục? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# =============================================================================
# 💾 THIẾT LẬP SWAP MEMORY
# =============================================================================

setup_swap() {
    log_header "💾 THIẾT LẬP SWAP MEMORY"
    
    # Kiểm tra swap hiện tại
    CURRENT_SWAP=$(free -h | awk '/^Swap:/ {print $2}')
    log_info "Swap hiện tại: $CURRENT_SWAP"
    
    # Nếu đã có swap >= 2GB thì bỏ qua
    if [[ "$CURRENT_SWAP" != "0B" ]]; then
        SWAP_SIZE_MB=$(free -m | awk '/^Swap:/ {print $2}')
        if [[ $SWAP_SIZE_MB -ge 2048 ]]; then
            log_success "Swap đã đủ lớn ($CURRENT_SWAP)"
            return
        fi
    fi
    
    # Tính toán swap size dựa trên RAM
    RAM_MB=$(free -m | awk '/^Mem:/ {print $2}')
    if [[ $RAM_MB -lt 2048 ]]; then
        SWAP_SIZE="2G"
    elif [[ $RAM_MB -lt 4096 ]]; then
        SWAP_SIZE="4G"
    else
        SWAP_SIZE="4G"
    fi
    
    log_info "Đang tạo swap file $SWAP_SIZE..."
    
    # Tạo swap file
    fallocate -l $SWAP_SIZE /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    
    # Thêm vào fstab để persistent
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
    fi
    
    log_success "Swap $SWAP_SIZE đã được thiết lập!"
}

# =============================================================================
# 🐳 CÀI ĐẶT DOCKER
# =============================================================================

install_docker() {
    log_header "⚙️ CÀI ĐẶT DOCKER"
    
    # Kiểm tra Docker đã cài chưa
    if command -v docker &> /dev/null; then
        log_info "Docker đã được cài đặt"
        
        # Kiểm tra Docker daemon
        if ! docker info &> /dev/null; then
            log_info "Đang khởi động Docker daemon..."
            systemctl start docker
            systemctl enable docker
        fi
        
        # Kiểm tra Docker Compose
        if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
            log_info "Đang cài đặt Docker Compose..."
            apt update
            apt install -y docker-compose
        fi
        
        return
    fi
    
    log_info "Đang cài đặt Docker..."
    
    # Cập nhật package list
    apt update
    
    # Cài đặt dependencies
    apt install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Thêm Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Thêm Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Cài đặt Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose
    
    # Khởi động Docker
    systemctl start docker
    systemctl enable docker
    
    # Thêm user vào docker group
    usermod -aG docker $SUDO_USER 2>/dev/null || true
    
    log_success "Docker đã được cài đặt thành công!"
}

# =============================================================================
# 🗑️ XÓA CÀI ĐẶT CŨ
# =============================================================================

cleanup_old_installation() {
    if [[ "$CLEANUP_OLD" == true ]]; then
        log_header "⚠️ XÓA CÀI ĐẶT CŨ"
        
        log_info "Đang dừng containers cũ..."
        cd "$INSTALL_DIR" 2>/dev/null || true
        
        # Xác định Docker Compose command
        if command -v docker-compose &> /dev/null; then
            DOCKER_COMPOSE="docker-compose"
        elif docker compose version &> /dev/null; then
            DOCKER_COMPOSE="docker compose"
        else
            DOCKER_COMPOSE="docker-compose"
        fi
        
        $DOCKER_COMPOSE down 2>/dev/null || true
        
        log_info "Đang xóa thư mục cài đặt cũ..."
        rm -rf "$INSTALL_DIR"
        
        log_info "Đang xóa Docker volumes cũ..."
        docker volume rm n8n_caddy_data n8n_caddy_config 2>/dev/null || true
        
        log_success "Đã xóa cài đặt cũ thành công!"
    fi
}

# =============================================================================
# 📁 TẠO CẤU TRÚC THƯ MỤC
# =============================================================================

create_directory_structure() {
    log_header "⚙️ TẠO CẤU TRÚC THƯ MỤC"
    
    # Tạo thư mục chính
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Tạo cấu trúc thư mục
    mkdir -p files/{backup_full,temp,youtube_content_anylystic}
    mkdir -p logs
    
    if [[ "$NEWS_API_ENABLED" == true ]]; then
        mkdir -p news_api
    fi
    
    # Tạo file token cho News API
    if [[ "$NEWS_API_ENABLED" == true ]]; then
        echo "$NEWS_API_TOKEN" > news_api_token.txt
        chmod 600 news_api_token.txt
    fi
    
    # Tạo file config Telegram
    if [[ "$TELEGRAM_ENABLED" == true ]]; then
        cat > telegram_config.txt << EOF
TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID
EOF
        chmod 600 telegram_config.txt
    fi
    
    log_success "Cấu trúc thư mục đã được tạo!"
}

# =============================================================================
# 📰 TẠO NEWS CONTENT API
# =============================================================================

create_news_api() {
    if [[ "$NEWS_API_ENABLED" == false ]]; then
        return
    fi
    
    log_header "📰 TẠO NEWS CONTENT API"
    
    cd "$INSTALL_DIR/news_api"
    
    # Tạo requirements.txt
    cat > requirements.txt << 'EOF'
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
    
    # Tạo main.py với Newspaper4k và Random User Agent
    cat > main.py << 'EOF'
import os
import random
import logging
from datetime import datetime
from typing import List, Optional, Dict, Any
import asyncio
from concurrent.futures import ThreadPoolExecutor

from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, HttpUrl, Field
import uvicorn
from user_agents import parse
import requests

# Import newspaper4k với cách sử dụng đúng
from newspaper import Article, Config
import newspaper
import feedparser
import nltk

# Download NLTK data
try:
    nltk.download('punkt', quiet=True)
    nltk.download('stopwords', quiet=True)
except:
    pass

# Logging setup
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Random User Agents Pool
USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:120.0) Gecko/20100101 Firefox/120.0",
    "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:121.0) Gecko/20100101 Firefox/121.0"
]

def get_random_headers():
    """Generate random headers with user agent"""
    user_agent = random.choice(USER_AGENTS)
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
        headers.update({
            'sec-ch-ua': '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"Windows"' if 'Windows' in user_agent else '"macOS"' if 'Mac' in user_agent else '"Linux"',
            'Sec-Fetch-Dest': 'document',
            'Sec-Fetch-Mode': 'navigate',
            'Sec-Fetch-Site': 'none',
            'Sec-Fetch-User': '?1',
        })
    
    return headers

# Load Bearer Token
try:
    with open('/app/news_api_token.txt', 'r') as f:
        BEARER_TOKEN = f.read().strip()
except FileNotFoundError:
    BEARER_TOKEN = os.getenv('NEWS_API_TOKEN', 'default-token-change-me')

# FastAPI app
app = FastAPI(
    title="News Content API",
    description="Advanced News Content Extraction API với Newspaper4k và Random User Agent",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security
security = HTTPBearer()

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if credentials.credentials != BEARER_TOKEN:
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
    summarize: bool = Field(default=False, description="Generate article summary using NLP")

class SourceRequest(BaseModel):
    url: HttpUrl
    max_articles: int = Field(default=10, ge=1, le=50, description="Maximum articles to extract")
    language: str = Field(default="auto", description="Language code")

class FeedRequest(BaseModel):
    url: HttpUrl
    max_articles: int = Field(default=10, ge=1, le=50, description="Maximum articles from feed")

class ArticleResponse(BaseModel):
    title: Optional[str]
    content: Optional[str]
    summary: Optional[str]
    authors: List[str]
    publish_date: Optional[str]
    top_image: Optional[str]
    images: List[str]
    url: str
    language: Optional[str]
    word_count: int
    read_time_minutes: int
    keywords: List[str]
    meta_description: Optional[str]
    meta_keywords: Optional[str]

class SourceResponse(BaseModel):
    source_url: str
    articles: List[ArticleResponse]
    total_found: int
    extracted: int

class HealthResponse(BaseModel):
    status: str
    timestamp: str
    version: str
    features: List[str]

# Helper functions
def create_newspaper_config(language: str = "auto") -> Config:
    """Create newspaper config with random user agent"""
    config = Config()
    config.browser_user_agent = random.choice(USER_AGENTS)
    config.request_timeout = 30
    config.number_threads = 1
    config.thread_timeout_seconds = 30
    config.ignored_content_types_defaults = {}
    
    # Set language if not auto
    if language != "auto":
        config.language = language
    
    return config

def extract_article_content(url: str, language: str = "auto") -> Dict[str, Any]:
    """Extract content from a single article URL"""
    try:
        # Create config with random user agent
        config = create_newspaper_config(language)
        
        # Create article object
        article = Article(url, config=config)
        
        # Download article
        article.download()
        
        # Parse article
        article.parse()
        
        # NLP processing (optional)
        try:
            article.nlp()
        except Exception as e:
            logger.warning(f"NLP processing failed for {url}: {e}")
        
        # Calculate read time (average 200 words per minute)
        word_count = len(article.text.split()) if article.text else 0
        read_time = max(1, round(word_count / 200))
        
        # Format publish date
        publish_date = None
        if article.publish_date:
            publish_date = article.publish_date.isoformat()
        
        return {
            "title": article.title or "",
            "content": article.text or "",
            "summary": article.summary or "",
            "authors": article.authors or [],
            "publish_date": publish_date,
            "top_image": article.top_image or "",
            "images": list(article.images) or [],
            "url": url,
            "language": getattr(article, 'meta_lang', language),
            "word_count": word_count,
            "read_time_minutes": read_time,
            "keywords": article.keywords or [],
            "meta_description": getattr(article, 'meta_description', ''),
            "meta_keywords": getattr(article, 'meta_keywords', '')
        }
        
    except Exception as e:
        logger.error(f"Error extracting article {url}: {e}")
        return {
            "title": None,
            "content": None,
            "summary": None,
            "authors": [],
            "publish_date": None,
            "top_image": None,
            "images": [],
            "url": url,
            "language": language,
            "word_count": 0,
            "read_time_minutes": 0,
            "keywords": [],
            "meta_description": None,
            "meta_keywords": None,
            "error": str(e)
        }

# API Routes
@app.get("/", response_class=HTMLResponse)
async def root():
    """API Homepage với thông tin sử dụng"""
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>News Content API</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
            .header { background: #2563eb; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
            .endpoint { background: #f8fafc; padding: 15px; border-radius: 8px; margin: 10px 0; border-left: 4px solid #2563eb; }
            .method { background: #10b981; color: white; padding: 4px 8px; border-radius: 4px; font-size: 12px; }
            .method.post { background: #f59e0b; }
            code { background: #e5e7eb; padding: 2px 4px; border-radius: 4px; }
            .auth-note { background: #fef3c7; padding: 10px; border-radius: 4px; margin: 10px 0; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🚀 News Content API</h1>
            <p>Advanced News Content Extraction với Newspaper4k và Random User Agent</p>
        </div>
        
        <div class="auth-note">
            <strong>🔐 Authentication:</strong> Tất cả API calls yêu cầu Bearer Token đã được đặt trong lúc cài đặt.
            <br><code>Authorization: Bearer YOUR_TOKEN</code>
        </div>
        
        <h2>📖 API Endpoints</h2>
        
        <div class="endpoint">
            <span class="method">GET</span> <strong>/health</strong>
            <p>Kiểm tra trạng thái API</p>
        </div>
        
        <div class="endpoint">
            <span class="method post">POST</span> <strong>/extract-article</strong>
            <p>Lấy nội dung bài viết từ URL</p>
            <code>{"url": "https://example.com/article", "language": "vi", "extract_images": true}</code>
        </div>
        
        <div class="endpoint">
            <span class="method post">POST</span> <strong>/extract-source</strong>
            <p>Crawl nhiều bài viết từ website</p>
            <code>{"url": "https://example.com", "max_articles": 10, "language": "vi"}</code>
        </div>
        
        <div class="endpoint">
            <span class="method post">POST</span> <strong>/parse-feed</strong>
            <p>Phân tích RSS feeds</p>
            <code>{"url": "https://example.com/rss.xml", "max_articles": 10}</code>
        </div>
        
        <h2>📚 Documentation</h2>
        <p>
            <a href="/docs" target="_blank">📖 Swagger UI</a> | 
            <a href="/redoc" target="_blank">📋 ReDoc</a>
        </p>
        
        <h2>🔧 Đổi Bearer Token</h2>
        <p>Để đổi Bearer Token, sử dụng một trong các cách sau:</p>
        <ol>
            <li><code>cd /home/n8n && sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN="NEW_TOKEN"/' docker-compose.yml && docker compose restart fastapi</code></li>
            <li>Edit file <code>/home/n8n/docker-compose.yml</code> và restart service</li>
            <li>Edit file <code>/home/n8n/news_api_token.txt</code> và restart container</li>
        </ol>
    </body>
    </html>
    """
    return html_content

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy",
        timestamp=datetime.now().isoformat(),
        version="2.0.0",
        features=[
            "Article Extraction",
            "Source Crawling", 
            "RSS Feed Parsing",
            "Random User Agent",
            "Multi-language Support",
            "NLP Processing",
            "Image Extraction"
        ]
    )

@app.post("/extract-article", response_model=ArticleResponse)
async def extract_article(
    request: ArticleRequest,
    token: str = Depends(verify_token)
):
    """Extract content from a single article URL"""
    try:
        # Extract article in thread pool to avoid blocking
        loop = asyncio.get_event_loop()
        with ThreadPoolExecutor(max_workers=1) as executor:
            result = await loop.run_in_executor(
                executor, 
                extract_article_content, 
                str(request.url), 
                request.language
            )
        
        if "error" in result:
            raise HTTPException(status_code=400, detail=f"Failed to extract article: {result['error']}")
        
        return ArticleResponse(**result)
        
    except Exception as e:
        logger.error(f"Error in extract_article: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/extract-source", response_model=SourceResponse)
async def extract_source(
    request: SourceRequest,
    token: str = Depends(verify_token)
):
    """Extract multiple articles from a news source"""
    try:
        # Build source using newspaper
        config = create_newspaper_config(request.language)
        source = newspaper.build(str(request.url), config=config)
        
        # Get article URLs (limit to max_articles)
        article_urls = [article.url for article in source.articles[:request.max_articles]]
        
        # Extract articles in parallel
        loop = asyncio.get_event_loop()
        with ThreadPoolExecutor(max_workers=3) as executor:
            tasks = [
                loop.run_in_executor(executor, extract_article_content, url, request.language)
                for url in article_urls
            ]
            results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Filter successful extractions
        articles = []
        for result in results:
            if isinstance(result, dict) and "error" not in result:
                articles.append(ArticleResponse(**result))
        
        return SourceResponse(
            source_url=str(request.url),
            articles=articles,
            total_found=len(source.articles),
            extracted=len(articles)
        )
        
    except Exception as e:
        logger.error(f"Error in extract_source: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/parse-feed", response_model=SourceResponse)
async def parse_feed(
    request: FeedRequest,
    token: str = Depends(verify_token)
):
    """Parse RSS/Atom feed and extract articles"""
    try:
        # Parse feed
        headers = get_random_headers()
        response = requests.get(str(request.url), headers=headers, timeout=30)
        response.raise_for_status()
        
        feed = feedparser.parse(response.content)
        
        if not feed.entries:
            raise HTTPException(status_code=400, detail="No entries found in feed")
        
        # Get article URLs from feed entries
        article_urls = []
        for entry in feed.entries[:request.max_articles]:
            if hasattr(entry, 'link'):
                article_urls.append(entry.link)
        
        # Extract articles in parallel
        loop = asyncio.get_event_loop()
        with ThreadPoolExecutor(max_workers=3) as executor:
            tasks = [
                loop.run_in_executor(executor, extract_article_content, url, "auto")
                for url in article_urls
            ]
            results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Filter successful extractions
        articles = []
        for result in results:
            if isinstance(result, dict) and "error" not in result:
                articles.append(ArticleResponse(**result))
        
        return SourceResponse(
            source_url=str(request.url),
            articles=articles,
            total_found=len(feed.entries),
            extracted=len(articles)
        )
        
    except Exception as e:
        logger.error(f"Error in parse_feed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        workers=1
    )
EOF
    
    # Tạo Dockerfile cho News API
    cat > Dockerfile << 'EOF'
FROM python:3.11-slim

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

WORKDIR /app

# Copy requirements and install Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py .

# Copy token file from parent directory
COPY ../news_api_token.txt /app/news_api_token.txt

# Expose port
EXPOSE 8000

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
EOF
    
    log_success "News Content API đã được tạo với Newspaper4k và Random User Agent!"
}

# =============================================================================
# 🐳 TẠO N8N DOCKERFILE
# =============================================================================

create_n8n_dockerfile() {
    log_header "⚙️ TẠO N8N DOCKERFILE"
    
    cd "$INSTALL_DIR"
    
    cat > Dockerfile << 'EOF'
FROM n8nio/n8n:latest

# Switch to root to install packages
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
    bash \
    && rm -rf /var/cache/apk/*

# Install Python packages
RUN pip3 install --break-system-packages \
    yt-dlp \
    requests \
    beautifulsoup4 \
    selenium \
    pandas \
    numpy

# Set environment variables for Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV CHROME_BIN=/usr/bin/chromium-browser
ENV CHROME_PATH=/usr/bin/chromium-browser

# Switch back to node user
USER node

# Set working directory
WORKDIR /home/node

# Expose port
EXPOSE 5678
EOF
    
    log_success "N8N Dockerfile đã được tạo!"
}

# =============================================================================
# 🐳 TẠO DOCKER COMPOSE
# =============================================================================

create_docker_compose() {
    log_header "⚙️ TẠO DOCKER COMPOSE"
    
    cd "$INSTALL_DIR"
    
    # Tạo docker-compose.yml
    cat > docker-compose.yml << EOF
services:
  n8n:
    build: .
    image: n8n-custom-ffmpeg:latest
    container_name: n8n-n8n-1
    restart: unless-stopped
    ports:
      - "127.0.0.1:5678:5678"
    environment:
      - N8N_HOST=\${N8N_HOST:-localhost}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://$DOMAIN/
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
      - N8N_METRICS=true
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_VERSION_NOTIFICATIONS_ENABLED=false
      - N8N_TEMPLATES_ENABLED=true
      - N8N_ONBOARDING_FLOW_DISABLED=false
      - N8N_DIAGNOSTICS_CONFIG_ENABLED=false
      - EXECUTIONS_TIMEOUT=3600
      - EXECUTIONS_TIMEOUT_MAX=7200
      - N8N_EXECUTION_TIMEOUT=3600
      - N8N_EXECUTION_TIMEOUT_MAX=7200
      - N8N_MAX_EXECUTION_TIMEOUT=7200
      - N8N_EXECUTIONS_DATA_MAX_SIZE=500MB
      - DB_TYPE=sqlite
      - DB_SQLITE_DATABASE=/home/node/.n8n/database.sqlite
      - N8N_ENCRYPTION_KEY=\${N8N_ENCRYPTION_KEY:-$(openssl rand -base64 32)}
    volumes:
      - ./files:/home/node/files
      - ./database.sqlite:/home/node/.n8n/database.sqlite
      - ./encryptionKey:/home/node/.n8n/config
    networks:
      - default

EOF

    # Thêm News API service nếu được bật
    if [[ "$NEWS_API_ENABLED" == true ]]; then
        cat >> docker-compose.yml << EOF
  fastapi:
    build: ./news_api
    image: news-api:latest
    container_name: n8n-fastapi-1
    restart: unless-stopped
    ports:
      - "127.0.0.1:8000:8000"
    environment:
      - NEWS_API_TOKEN=$NEWS_API_TOKEN
    volumes:
      - ./news_api:/app
      - ./news_api_token.txt:/app/news_api_token.txt:ro
    networks:
      - default

EOF
    fi

    # Thêm Caddy service
    cat >> docker-compose.yml << EOF
  caddy:
    image: caddy:latest
    container_name: n8n-caddy-1
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
      - default

volumes:
  caddy_data:
  caddy_config:

networks:
  default:
    name: n8n_default
EOF
    
    log_success "Docker Compose đã được tạo!"
}

# =============================================================================
# 🔒 TẠO CADDYFILE
# =============================================================================

create_caddyfile() {
    log_header "🔒 TẠO CADDYFILE"
    
    cd "$INSTALL_DIR"
    
    # Tạo Caddyfile với SSL tự động
    cat > Caddyfile << EOF
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

    # Thêm API domain nếu News API được bật
    if [[ "$NEWS_API_ENABLED" == true ]]; then
        API_DOMAIN="api.$DOMAIN"
        cat >> Caddyfile << EOF

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
    
    log_success "Caddyfile đã được tạo!"
}

# =============================================================================
# 📦 TẠO BACKUP SCRIPTS
# =============================================================================

create_backup_scripts() {
    log_header "📦 TẠO BACKUP SCRIPTS"
    
    cd "$INSTALL_DIR"
    
    # Script backup workflows
    cat > backup-workflows.sh << 'EOF'
#!/bin/bash

# Backup N8N workflows và credentials
BACKUP_DIR="/home/n8n/files/backup_full"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="n8n_backup_${TIMESTAMP}.tar.gz"
LOG_FILE="$BACKUP_DIR/backup.log"

# Tạo thư mục backup nếu chưa có
mkdir -p "$BACKUP_DIR"

# Function để ghi log
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_message "🔄 Bắt đầu backup N8N..."

# Tạo thư mục tạm
TEMP_DIR="/tmp/n8n_backup_$TIMESTAMP"
mkdir -p "$TEMP_DIR"

# Export workflows từ N8N (nếu có API)
log_message "📋 Export workflows..."
mkdir -p "$TEMP_DIR/workflows"

# Backup database và config files
log_message "💾 Backup database và config..."
mkdir -p "$TEMP_DIR/credentials"

# Copy database
if [ -f "/home/n8n/database.sqlite" ]; then
    cp "/home/n8n/database.sqlite" "$TEMP_DIR/credentials/"
    log_message "✅ Database copied"
fi

# Copy encryption key
if [ -f "/home/n8n/encryptionKey" ]; then
    cp "/home/n8n/encryptionKey" "$TEMP_DIR/credentials/"
    log_message "✅ Encryption key copied"
fi

# Copy config files
if [ -d "/home/n8n/files" ]; then
    cp -r "/home/n8n/files" "$TEMP_DIR/" 2>/dev/null || true
    log_message "✅ Files directory copied"
fi

# Tạo metadata
cat > "$TEMP_DIR/backup_metadata.json" << EOL
{
    "backup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "version": "2.0.0",
    "hostname": "$(hostname)",
    "backup_type": "full"
}
EOL

# Tạo file tar.gz
log_message "📦 Tạo archive..."
cd /tmp
tar -czf "$BACKUP_DIR/$BACKUP_FILE" "n8n_backup_$TIMESTAMP/"

# Xóa thư mục tạm
rm -rf "$TEMP_DIR"

# Kiểm tra kích thước file
BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
log_message "✅ Backup hoàn thành: $BACKUP_FILE ($BACKUP_SIZE)"

# Gửi qua Telegram nếu được cấu hình
if [ -f "/home/n8n/telegram_config.txt" ]; then
    source "/home/n8n/telegram_config.txt"
    
    if [ ! -z "$TELEGRAM_BOT_TOKEN" ] && [ ! -z "$TELEGRAM_CHAT_ID" ]; then
        # Kiểm tra kích thước file (Telegram limit 20MB)
        BACKUP_SIZE_BYTES=$(stat -f%z "$BACKUP_DIR/$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_DIR/$BACKUP_FILE")
        
        MESSAGE="🔄 N8N Backup hoàn thành!%0A📅 $(date)%0A📦 File: $BACKUP_FILE%0A💾 Size: $BACKUP_SIZE"
        
        if [ $BACKUP_SIZE_BYTES -lt 20971520 ]; then
            # Gửi file nếu < 20MB
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument" \
                -F chat_id="$TELEGRAM_CHAT_ID" \
                -F document="@$BACKUP_DIR/$BACKUP_FILE" \
                -F caption="$MESSAGE" > /dev/null
            log_message "📱 Backup file sent to Telegram"
        else
            # Chỉ gửi thông báo nếu file quá lớn
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
                -d chat_id="$TELEGRAM_CHAT_ID" \
                -d text="$MESSAGE%0A⚠️ File quá lớn để gửi qua Telegram (>20MB)" > /dev/null
            log_message "📱 Backup notification sent to Telegram (file too large)"
        fi
    fi
fi

# Xóa backup cũ (giữ lại 30 bản gần nhất)
log_message "🧹 Dọn dẹp backup cũ..."
cd "$BACKUP_DIR"
ls -t n8n_backup_*.tar.gz | tail -n +31 | xargs -r rm
log_message "✅ Backup process completed"
EOF

    chmod +x backup-workflows.sh

    # Script backup manual (để test)
    cat > backup-manual.sh << 'EOF'
#!/bin/bash

echo "🧪 MANUAL BACKUP TEST"
echo "===================="

# Chạy backup script
/home/n8n/backup-workflows.sh

echo ""
echo "📋 BACKUP FILES:"
ls -la /home/n8n/files/backup_full/n8n_backup_*.tar.gz | tail -5

echo ""
echo "📊 BACKUP LOG (10 dòng cuối):"
tail -10 /home/n8n/files/backup_full/backup.log
EOF

    chmod +x backup-manual.sh

    # Thiết lập cron job cho backup tự động
    if [[ "$TELEGRAM_ENABLED" == true ]] || [[ "$AUTO_UPDATE_ENABLED" == true ]]; then
        # Tạo cron job backup hàng ngày lúc 2:00 AM
        (crontab -l 2>/dev/null; echo "0 2 * * * /home/n8n/backup-workflows.sh") | crontab -
        log_message "⏰ Đã thiết lập backup tự động hàng ngày lúc 2:00 AM"
    fi

    log_success "Backup scripts đã được tạo!"
}

# =============================================================================
# 🔄 TẠO UPDATE SCRIPT
# =============================================================================

create_update_script() {
    if [[ "$AUTO_UPDATE_ENABLED" == false ]]; then
        return
    fi
    
    cd "$INSTALL_DIR"
    
    cat > update-n8n.sh << 'EOF'
#!/bin/bash

# Auto update N8N và components
LOG_FILE="/home/n8n/logs/update.log"
mkdir -p "$(dirname "$LOG_FILE")"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_message "🔄 Bắt đầu auto update..."

cd /home/n8n

# Xác định Docker Compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    log_message "❌ Docker Compose không tìm thấy!"
    exit 1
fi

# Backup trước khi update
log_message "💾 Tạo backup trước update..."
/home/n8n/backup-workflows.sh

# Pull latest images
log_message "📥 Pull latest Docker images..."
$DOCKER_COMPOSE pull

# Restart containers với images mới
log_message "🔄 Restart containers..."
$DOCKER_COMPOSE up -d

# Update yt-dlp trong container
log_message "📺 Update yt-dlp..."
docker exec n8n-n8n-1 pip3 install --break-system-packages -U yt-dlp

log_message "✅ Auto update hoàn thành!"
EOF

    chmod +x update-n8n.sh
    
    # Thêm cron job update (mỗi 12 tiếng)
    (crontab -l 2>/dev/null; echo "0 */12 * * * /home/n8n/update-n8n.sh") | crontab -
    
    log_success "Auto-update script đã được tạo!"
}

# =============================================================================
# 🔍 TẠO TROUBLESHOOT SCRIPT
# =============================================================================

create_troubleshoot_script() {
    cd "$INSTALL_DIR"
    
    cat > troubleshoot.sh << 'EOF'
#!/bin/bash

echo "🔍 N8N SYSTEM DIAGNOSTICS"
echo "========================="

# Xác định Docker Compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    echo "❌ Docker Compose không tìm thấy!"
    exit 1
fi

echo "📍 1. Container Status:"
cd /home/n8n && $DOCKER_COMPOSE ps

echo ""
echo "📍 2. Docker System Info:"
docker system df

echo ""
echo "📍 3. Memory Usage:"
free -h

echo ""
echo "📍 4. Disk Usage:"
df -h /home/n8n

echo ""
echo "📍 5. Recent Logs (N8N):"
$DOCKER_COMPOSE logs --tail=10 n8n

echo ""
echo "📍 6. Recent Logs (Caddy):"
$DOCKER_COMPOSE logs --tail=10 caddy

if docker ps | grep -q fastapi; then
    echo ""
    echo "📍 7. Recent Logs (FastAPI):"
    $DOCKER_COMPOSE logs --tail=10 fastapi
fi

echo ""
echo "📍 8. Network Connectivity:"
curl -I https://google.com 2>/dev/null | head -1 || echo "❌ No internet connection"

echo ""
echo "📍 9. SSL Certificate Check:"
if command -v openssl &> /dev/null; then
    echo | openssl s_client -connect $(hostname):443 -servername $(hostname) 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "❌ SSL certificate issue"
else
    echo "⚠️ OpenSSL not available"
fi

echo ""
echo "📍 10. Port Status:"
netstat -tulpn | grep -E ":80|:443|:5678|:8000" || ss -tulpn | grep -E ":80|:443|:5678|:8000"
EOF

    chmod +x troubleshoot.sh
    
    log_success "Troubleshoot script đã được tạo!"
}

# =============================================================================
# 🚀 BUILD VÀ KHỞI ĐỘNG CONTAINERS
# =============================================================================

build_and_start() {
    log_header "🚀 BUILD VÀ KHỞI ĐỘNG CONTAINERS"
    
    cd "$INSTALL_DIR"
    
    # Xác định Docker Compose command
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE="docker-compose"
    elif docker compose version &> /dev/null; then
        DOCKER_COMPOSE="docker compose"
    else
        log_error "Docker Compose không tìm thấy!"
        exit 1
    fi
    
    log_info "Đang build Docker images..."
    $DOCKER_COMPOSE build
    
    log_info "Đang khởi động containers..."
    $DOCKER_COMPOSE up -d
    
    # Đợi containers khởi động
    log_info "Đợi containers khởi động (30 giây)..."
    sleep 30
    
    # Kiểm tra trạng thái
    log_info "Kiểm tra trạng thái containers:"
    $DOCKER_COMPOSE ps
    
    log_success "Containers đã được khởi động!"
}

# =============================================================================
# 🔒 KIỂM TRA SSL VÀ XỬ LÝ RATE LIMIT
# =============================================================================

check_ssl_and_rate_limit() {
    log_header "🔒 KIỂM TRA SSL CERTIFICATE"
    
    cd "$INSTALL_DIR"
    
    # Xác định Docker Compose command
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE="docker-compose"
    elif docker compose version &> /dev/null; then
        DOCKER_COMPOSE="docker compose"
    else
        DOCKER_COMPOSE="docker compose"
    fi
    
    log_info "Đang kiểm tra Caddy logs để phát hiện rate limit..."
    
    # Đợi 60 giây để Caddy thử lấy SSL
    sleep 60
    
    # Kiểm tra logs để tìm rate limit
    RATE_LIMIT_DETECTED=false
    if $DOCKER_COMPOSE logs caddy 2>/dev/null | grep -q "rateLimited\|rate.*limit\|too many certificates"; then
        RATE_LIMIT_DETECTED=true
    fi
    
    if [[ "$RATE_LIMIT_DETECTED" == true ]]; then
        log_error "🚨 PHÁT HIỆN SSL RATE LIMIT!"
        log_error "Let's Encrypt đã đạt giới hạn 5 certificates/tuần cho domain này"
        echo ""
        log_warning "📋 CÁC GIẢI PHÁP:"
        echo ""
        echo "1. 🎯 SỬ DỤNG STAGING SSL (KHUYẾN NGHỊ):"
        echo "   - Website sẽ hoạt động ngay lập tức"
        echo "   - Browser sẽ cảnh báo 'Not Secure' (bình thường)"
        echo "   - Tất cả chức năng N8N và API hoạt động đầy đủ"
        echo ""
        echo "2. ⏰ ĐỢI 7 NGÀY:"
        echo "   - Đợi đến sau ngày $(date -d '+7 days' '+%d/%m/%Y')"
        echo "   - Rate limit sẽ được reset"
        echo ""
        echo "3. 🔄 CÀI LẠI UBUNTU VPS:"
        echo "   - Backup dữ liệu quan trọng"
        echo "   - Cài lại Ubuntu và chạy script này"
        echo ""
        
        read -p "Bạn muốn chọn giải pháp nào? (1=Staging SSL, 2=Đợi 7 ngày, 3=Hướng dẫn cài lại): " -r CHOICE
        
        case $CHOICE in
            1)
                log_info "🔄 Chuyển sang Staging SSL..."
                
                # Dừng containers
                $DOCKER_COMPOSE down
                
                # Xóa SSL data cũ
                docker volume rm n8n_caddy_data n8n_caddy_config 2>/dev/null || true
                
                # Tạo Caddyfile với staging
                cat > Caddyfile << EOF
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
EOF

                if [[ "$NEWS_API_ENABLED" == true ]]; then
                    API_DOMAIN="api.$DOMAIN"
                    cat >> Caddyfile << EOF

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
                
                # Khởi động lại
                $DOCKER_COMPOSE up -d
                
                log_success "✅ Đã chuyển sang Staging SSL!"
                log_warning "⚠️ Browser sẽ cảnh báo 'Not Secure' - đây là bình thường với staging certificate"
                echo ""
                log_info "🌐 TRUY CẬP NGAY:"
                log_info "N8N: https://$DOMAIN (click 'Advanced' -> 'Proceed to site')"
                if [[ "$NEWS_API_ENABLED" == true ]]; then
                    log_info "API: https://api.$DOMAIN/docs"
                fi
                ;;
            2)
                log_info "⏰ Hệ thống sẽ tự động thử lại sau 7 ngày"
                log_info "Bạn có thể sử dụng HTTP trong thời gian chờ: http://$DOMAIN"
                ;;
            3)
                echo ""
                log_warning "📋 HƯỚNG DẪN CÀI LẠI UBUNTU VPS:"
                echo ""
                echo "1. 💾 Backup dữ liệu quan trọng:"
                echo "   - Download file backup từ /home/n8n/files/backup_full/"
                echo "   - Lưu các file config quan trọng"
                echo ""
                echo "2. 🔄 Cài lại Ubuntu:"
                echo "   - Truy cập control panel VPS"
                echo "   - Chọn 'Reinstall OS' hoặc 'Rebuild'"
                echo "   - Chọn Ubuntu 20.04+ LTS"
                echo ""
                echo "3. 🚀 Chạy lại script:"
                echo "   cd /tmp && curl -sSL https://raw.githubusercontent.com/KalvinThien/install-n8n-ffmpeg/main/auto_cai_dat_n8n.sh | tr -d '\r' > install_n8n.sh && chmod +x install_n8n.sh && sudo bash install_n8n.sh"
                echo ""
                echo "4. 📥 Restore backup:"
                echo "   - Upload file backup"
                echo "   - Extract và copy files về vị trí cũ"
                ;;
        esac
    else
        # Kiểm tra SSL certificate
        log_info "Đang kiểm tra SSL certificate..."
        sleep 30
        
        if curl -I "https://$DOMAIN" &>/dev/null; then
            log_success "✅ SSL Certificate đã được cấp thành công!"
        else
            log_warning "⚠️ SSL Certificate chưa sẵn sàng, có thể cần thêm thời gian"
            log_info "Bạn có thể kiểm tra logs: cd /home/n8n && docker compose logs -f caddy"
        fi
    fi
}

# =============================================================================
# 🎯 HIỂN THỊ THÔNG TIN HOÀN THÀNH
# =============================================================================

show_completion_info() {
    log_header "🎉 CÀI ĐẶT HOÀN THÀNH!"
    
    echo -e "${GREEN}✅ N8N Automation Platform đã được cài đặt thành công!${NC}"
    echo ""
    
    log_info "🌐 TRUY CẬP HỆ THỐNG:"
    log_info "N8N Dashboard: https://$DOMAIN"
    
    if [[ "$NEWS_API_ENABLED" == true ]]; then
        log_info "News API: https://api.$DOMAIN"
        log_info "API Documentation: https://api.$DOMAIN/docs"
    fi
    
    echo ""
    log_info "📁 CẤU TRÚC THƯ MỤC:"
    log_info "Thư mục chính: $INSTALL_DIR"
    log_info "Backup: $INSTALL_DIR/files/backup_full/"
    log_info "Logs: $INSTALL_DIR/logs/"
    
    echo ""
    log_info "🔧 LỆNH QUẢN LÝ:"
    log_info "Xem trạng thái: cd $INSTALL_DIR && docker compose ps"
    log_info "Xem logs: cd $INSTALL_DIR && docker compose logs -f"
    log_info "Restart: cd $INSTALL_DIR && docker compose restart"
    log_info "Chẩn đoán: $INSTALL_DIR/troubleshoot.sh"
    
    if [[ "$NEWS_API_ENABLED" == true ]]; then
        echo ""
        log_info "🔑 ĐỔI BEARER TOKEN:"
        log_info "Method 1: cd $INSTALL_DIR && sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN=\"NEW_TOKEN\"/' docker-compose.yml && docker compose restart fastapi"
        log_info "Method 2: Edit file $INSTALL_DIR/news_api_token.txt và restart container"
    fi
    
    if [[ "$TELEGRAM_ENABLED" == true ]]; then
        echo ""
        log_info "📱 TELEGRAM BACKUP:"
        log_info "Test backup: $INSTALL_DIR/backup-manual.sh"
        log_info "Auto backup: Mỗi ngày 2:00 AM"
    fi
    
    if [[ "$AUTO_UPDATE_ENABLED" == true ]]; then
        echo ""
        log_info "🔄 AUTO UPDATE:"
        log_info "Tự động: Mỗi 12 tiếng"
        log_info "Manual: $INSTALL_DIR/update-n8n.sh"
    fi
    
    echo ""
    log_success "🚀 Hệ thống đã sẵn sàng sử dụng!"
    echo ""
    log_info "📺 Đừng quên SUBSCRIBE YouTube: https://www.youtube.com/@kalvinthiensocial"
    log_info "📘 Facebook: https://www.facebook.com/Ban.Thien.Handsome/"
    log_info "📱 Zalo: 08.8888.4749"
}

# =============================================================================
# 🚀 HÀM MAIN
# =============================================================================

main() {
    # Kiểm tra quyền root
    check_root
    
    # Hiển thị banner
    show_banner
    
    # Parse arguments
    parse_arguments "$@"
    
    # Kiểm tra hệ điều hành
    check_os
    
    # Kiểm tra internet
    check_internet
    
    # Thu thập thông tin từ người dùng
    collect_user_input
    
    # Kiểm tra DNS
    check_dns
    
    # Thiết lập swap
    setup_swap
    
    # Cài đặt Docker
    install_docker
    
    # Xóa cài đặt cũ
    cleanup_old_installation
    
    # Tạo cấu trúc thư mục
    create_directory_structure
    
    # Tạo News API
    create_news_api
    
    # Tạo N8N Dockerfile
    create_n8n_dockerfile
    
    # Tạo Docker Compose
    create_docker_compose
    
    # Tạo Caddyfile
    create_caddyfile
    
    # Tạo backup scripts
    create_backup_scripts
    
    # Tạo update script
    create_update_script
    
    # Tạo troubleshoot script
    create_troubleshoot_script
    
    # Build và khởi động containers
    build_and_start
    
    # Kiểm tra SSL và xử lý rate limit
    check_ssl_and_rate_limit
    
    # Hiển thị thông tin hoàn thành
    show_completion_info
}

# Chạy script
main "$@"
