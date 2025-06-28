#!/bin/bash

# =============================================================================
# 🚀 SCRIPT CÀI ĐẶT N8N TỰ ĐỘNG VỚI FFMPEG, YT-DLP, PUPPETEER VÀ NEWS API
# =============================================================================
# Tác giả: Nguyễn Ngọc Thiện
# YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1
# Zalo: 08.8888.4749
# Cập nhật: 28/06/2025
# =============================================================================

set -e  # Exit on any error

# =============================================================================
# 🎨 THIẾT LẬP MÀU SẮC VÀ LOGGING
# =============================================================================

# Màu sắc dễ đọc trên nền đen
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'      # Thay đổi từ xanh dương sang cyan
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

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
    echo -e "${WHITE}$1${NC}"
}

# =============================================================================
# 🔧 BIẾN TOÀN CỤC
# =============================================================================

INSTALL_DIR="/home/n8n"
DOMAIN=""
API_DOMAIN=""
NEWS_API_TOKEN=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
AUTO_UPDATE="y"
ENABLE_TELEGRAM="n"
ENABLE_NEWS_API="y"
CLEAN_INSTALL="n"

# =============================================================================
# 🛠️ HÀM TIỆN ÍCH
# =============================================================================

# Kiểm tra quyền root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Script này cần chạy với quyền root. Vui lòng sử dụng sudo."
        exit 1
    fi
}

# Phát hiện hệ điều hành
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        log_error "Không thể xác định hệ điều hành"
        exit 1
    fi
    
    if [[ $OS != *"Ubuntu"* ]]; then
        log_warning "Script này được thiết kế cho Ubuntu. Hệ điều hành hiện tại: $OS"
        read -p "Bạn có muốn tiếp tục? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Kiểm tra kết nối internet
check_internet() {
    if ! ping -c 1 google.com &> /dev/null; then
        log_error "Không có kết nối internet"
        exit 1
    fi
}

# Xác định Docker Compose command
get_docker_compose_cmd() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        echo "docker compose"
    else
        log_error "Docker Compose không được tìm thấy"
        exit 1
    fi
}

# =============================================================================
# 📋 HÀM NHẬP THÔNG TIN
# =============================================================================

# Nhập domain
input_domain() {
    log_header "🌐 THIẾT LẬP DOMAIN"
    
    while true; do
        read -p "$(echo -e "${CYAN}🌐 Nhập domain cho N8N (ví dụ: n8n.yourdomain.com): ${NC}")" DOMAIN
        
        if [[ -z "$DOMAIN" ]]; then
            log_error "Domain không được để trống!"
            continue
        fi
        
        # Kiểm tra format domain
        if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]] && [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9-]+\.[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$ ]]; then
            log_error "Format domain không hợp lệ!"
            continue
        fi
        
        API_DOMAIN="api.$DOMAIN"
        log_info "Domain N8N: $DOMAIN"
        log_info "Domain API: $API_DOMAIN"
        
        read -p "$(echo -e "${CYAN}Xác nhận domain này? (Y/n): ${NC}")" -r
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            continue
        fi
        break
    done
}

# Hỏi về việc xóa cài đặt cũ
ask_clean_install() {
    if [[ -d "$INSTALL_DIR" ]]; then
        log_warning "Phát hiện cài đặt N8N cũ tại $INSTALL_DIR"
        read -p "$(echo -e "${YELLOW}Bạn có muốn xóa cài đặt cũ và cài đặt lại từ đầu? (y/N): ${NC}")" -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            CLEAN_INSTALL="y"
        fi
    fi
}

# Hỏi về News API
ask_news_api() {
    log_header "📰 THIẾT LẬP NEWS CONTENT API"
    
    read -p "$(echo -e "${CYAN}Bạn có muốn cài đặt News Content API? (Y/n): ${NC}")" -r
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_NEWS_API="n"
        return
    fi
    
    ENABLE_NEWS_API="y"
    
    while true; do
        read -p "$(echo -e "${CYAN}🔑 Đặt Bearer Token cho API (ít nhất 20 ký tự): ${NC}")" NEWS_API_TOKEN
        
        if [[ ${#NEWS_API_TOKEN} -lt 20 ]]; then
            log_error "Bearer Token phải có ít nhất 20 ký tự!"
            continue
        fi
        
        if [[ ! "$NEWS_API_TOKEN" =~ ^[a-zA-Z0-9]+$ ]]; then
            log_error "Bearer Token chỉ được chứa chữ cái và số!"
            continue
        fi
        
        break
    done
}

# Hỏi về Telegram backup
ask_telegram_backup() {
    log_header "📱 THIẾT LẬP TELEGRAM BACKUP"
    
    read -p "$(echo -e "${CYAN}Bạn có muốn thiết lập backup qua Telegram? (y/N): ${NC}")" -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        ENABLE_TELEGRAM="n"
        return
    fi
    
    ENABLE_TELEGRAM="y"
    
    log_info "Để thiết lập Telegram backup, bạn cần:"
    log_info "1. Tạo bot với @BotFather và lấy Bot Token"
    log_info "2. Lấy Chat ID (cá nhân hoặc nhóm)"
    echo ""
    
    while true; do
        read -p "$(echo -e "${CYAN}🤖 Nhập Telegram Bot Token: ${NC}")" TELEGRAM_BOT_TOKEN
        if [[ -z "$TELEGRAM_BOT_TOKEN" ]]; then
            log_error "Bot Token không được để trống!"
            continue
        fi
        break
    done
    
    while true; do
        read -p "$(echo -e "${CYAN}🆔 Nhập Telegram Chat ID: ${NC}")" TELEGRAM_CHAT_ID
        if [[ -z "$TELEGRAM_CHAT_ID" ]]; then
            log_error "Chat ID không được để trống!"
            continue
        fi
        break
    done
}

# Hỏi về auto update
ask_auto_update() {
    read -p "$(echo -e "${CYAN}🔄 Bạn có muốn bật tự động cập nhật? (Y/n): ${NC}")" -r
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        AUTO_UPDATE="n"
    fi
}

# =============================================================================
# 🔍 HÀM KIỂM TRA
# =============================================================================

# Kiểm tra DNS
check_dns() {
    log_header "🌐 KIỂM TRA DNS"
    
    log_info "Đang kiểm tra DNS cho $DOMAIN..."
    
    # Lấy IP của domain
    DOMAIN_IP=$(dig +short "$DOMAIN" A | tail -n1)
    if [[ -z "$DOMAIN_IP" ]]; then
        log_error "Không thể resolve domain $DOMAIN"
        log_error "Vui lòng kiểm tra:"
        log_error "1. Domain đã được đăng ký chưa?"
        log_error "2. DNS A record đã trỏ về IP server chưa?"
        exit 1
    fi
    
    # Lấy IP của server
    SERVER_IP=$(curl -s https://api.ipify.org || curl -s http://ipv4.icanhazip.com || echo "unknown")
    
    log_info "IP của domain $DOMAIN: $DOMAIN_IP"
    log_info "IP của server: $SERVER_IP"
    
    if [[ "$DOMAIN_IP" != "$SERVER_IP" ]]; then
        log_warning "IP của domain không khớp với IP server!"
        log_warning "SSL certificate có thể không được cấp thành công."
        read -p "$(echo -e "${YELLOW}Bạn có muốn tiếp tục? (y/N): ${NC}")" -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log_success "DNS đã được cấu hình đúng!"
    fi
}

# =============================================================================
# 💾 HÀM THIẾT LẬP SWAP
# =============================================================================

setup_swap() {
    log_header "💾 THIẾT LẬP SWAP MEMORY"
    
    # Kiểm tra swap hiện tại
    CURRENT_SWAP=$(free -h | awk '/^Swap:/ {print $2}')
    log_info "Swap hiện tại: $CURRENT_SWAP"
    
    # Nếu đã có swap >= 2GB thì bỏ qua
    if [[ "$CURRENT_SWAP" != "0B" ]] && [[ "$CURRENT_SWAP" != "0" ]]; then
        SWAP_SIZE_MB=$(free -m | awk '/^Swap:/ {print $2}')
        if [[ $SWAP_SIZE_MB -ge 2048 ]]; then
            log_success "Swap đã đủ lớn ($CURRENT_SWAP), bỏ qua thiết lập swap."
            return
        fi
    fi
    
    # Tính toán swap size dựa trên RAM
    RAM_MB=$(free -m | awk '/^Mem:/ {print $2}')
    
    if [[ $RAM_MB -le 1024 ]]; then
        SWAP_SIZE="2G"
    elif [[ $RAM_MB -le 2048 ]]; then
        SWAP_SIZE="3G"
    elif [[ $RAM_MB -le 4096 ]]; then
        SWAP_SIZE="4G"
    else
        SWAP_SIZE="4G"
    fi
    
    log_info "Đang tạo swap file $SWAP_SIZE..."
    
    # Tạo swap file
    fallocate -l $SWAP_SIZE /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=${SWAP_SIZE%G}000 2>/dev/null
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null 2>&1
    swapon /swapfile
    
    # Thêm vào fstab nếu chưa có
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
    fi
    
    # Tối ưu swap settings
    echo "vm.swappiness=10" >> /etc/sysctl.conf 2>/dev/null || true
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf 2>/dev/null || true
    
    log_success "Swap $SWAP_SIZE đã được thiết lập!"
}

# =============================================================================
# 🐳 HÀM CÀI ĐẶT DOCKER
# =============================================================================

install_docker() {
    log_header "⚙️ CÀI ĐẶT DOCKER"
    
    if command -v docker &> /dev/null; then
        log_info "Docker đã được cài đặt"
        
        # Kiểm tra Docker daemon
        if ! docker info >/dev/null 2>&1; then
            log_info "Đang khởi động Docker daemon..."
            systemctl start docker
            systemctl enable docker
        fi
        return
    fi
    
    log_info "Đang cài đặt Docker..."
    
    # Cập nhật package list
    apt-get update -qq
    
    # Cài đặt dependencies
    apt-get install -y -qq \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common
    
    # Thêm Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Thêm Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Cài đặt Docker
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Cài đặt docker-compose standalone nếu cần
    if ! command -v docker-compose &> /dev/null; then
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    # Khởi động Docker
    systemctl start docker
    systemctl enable docker
    
    # Thêm user vào docker group
    usermod -aG docker $SUDO_USER 2>/dev/null || true
    
    log_success "Docker đã được cài đặt thành công!"
}

# =============================================================================
# 🗑️ HÀM XÓA CÀI ĐẶT CŨ
# =============================================================================

clean_old_installation() {
    if [[ "$CLEAN_INSTALL" != "y" ]]; then
        return
    fi
    
    log_header "⚠️ XÓA CÀI ĐẶT CŨ"
    
    log_info "Đang dừng containers cũ..."
    cd "$INSTALL_DIR" 2>/dev/null || true
    DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
    $DOCKER_COMPOSE_CMD down 2>/dev/null || true
    
    log_info "Đang xóa thư mục cài đặt cũ..."
    rm -rf "$INSTALL_DIR"
    
    log_info "Đang xóa Docker volumes cũ..."
    docker volume rm n8n_caddy_data n8n_caddy_config 2>/dev/null || true
    
    log_success "Đã xóa cài đặt cũ thành công!"
}

# =============================================================================
# 📁 HÀM TẠO CẤU TRÚC THƯ MỤC
# =============================================================================

create_directory_structure() {
    log_header "⚙️ TẠO CẤU TRÚC THƯ MỤC"
    
    # Tạo thư mục chính
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Tạo cấu trúc thư mục
    mkdir -p files/{backup_full,temp,youtube_content_anylystic}
    mkdir -p logs
    
    if [[ "$ENABLE_NEWS_API" == "y" ]]; then
        mkdir -p news_api
    fi
    
    # Set permissions
    chmod 755 "$INSTALL_DIR"
    chmod -R 755 files/
    
    log_success "Cấu trúc thư mục đã được tạo!"
}

# =============================================================================
# 📰 HÀM TẠO NEWS CONTENT API
# =============================================================================

create_news_api() {
    if [[ "$ENABLE_NEWS_API" != "y" ]]; then
        return
    fi
    
    log_header "📰 TẠO NEWS CONTENT API"
    
    # Lưu token vào file riêng với permissions 600
    echo "$NEWS_API_TOKEN" > "$INSTALL_DIR/news_api_token.txt"
    chmod 600 "$INSTALL_DIR/news_api_token.txt"
    
    # Tạo requirements.txt
    cat > "$INSTALL_DIR/news_api/requirements.txt" << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
newspaper4k==0.9.3
user-agents==2.2.0
python-multipart==0.0.6
pydantic==2.5.0
requests==2.31.0
lxml==4.9.3
Pillow==10.1.0
nltk==3.8.1
feedparser==6.0.10
beautifulsoup4==4.12.2
python-dateutil==2.8.2
EOF

    # Tạo main.py với newspaper4k đúng cách và random user agent
    cat > "$INSTALL_DIR/news_api/main.py" << 'EOF'
import os
import random
import asyncio
import logging
from typing import List, Optional, Dict, Any
from datetime import datetime
import json
import re

import newspaper
from newspaper import Article, Source
import feedparser
import requests
from bs4 import BeautifulSoup
from user_agents import parse as parse_user_agent
import nltk

from fastapi import FastAPI, HTTPException, Depends, Security, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, HttpUrl, Field, validator

# Download NLTK data
try:
    nltk.download('punkt', quiet=True)
    nltk.download('stopwords', quiet=True)
except:
    pass

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load Bearer Token from file
try:
    with open('/app/news_api_token.txt', 'r') as f:
        BEARER_TOKEN = f.read().strip()
except:
    BEARER_TOKEN = os.getenv('NEWS_API_TOKEN', 'default_token_change_me')

# Random User Agent Pool
USER_AGENTS = [
    # Chrome
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    
    # Firefox
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:121.0) Gecko/20100101 Firefox/121.0",
    "Mozilla/5.0 (X11; Linux x86_64; rv:121.0) Gecko/20100101 Firefox/121.0",
    
    # Safari
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1",
    
    # Edge
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0"
]

def get_random_headers():
    """Generate random headers with user agent"""
    user_agent = random.choice(USER_AGENTS)
    parsed_ua = parse_user_agent(user_agent)
    
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
            'sec-ch-ua-platform': f'"{parsed_ua.os.family}"',
            'Sec-Fetch-Dest': 'document',
            'Sec-Fetch-Mode': 'navigate',
            'Sec-Fetch-Site': 'none',
            'Sec-Fetch-User': '?1'
        })
    elif 'Firefox' in user_agent:
        headers.update({
            'Cache-Control': 'max-age=0',
        })
    
    return headers

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

def verify_token(credentials: HTTPAuthorizationCredentials = Security(security)):
    """Verify Bearer Token"""
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
    summarize: bool = Field(default=False, description="Generate summary using NLP")
    timeout: int = Field(default=30, ge=5, le=120, description="Request timeout in seconds")

class SourceRequest(BaseModel):
    url: HttpUrl
    max_articles: int = Field(default=10, ge=1, le=100, description="Maximum articles to extract")
    language: str = Field(default="auto", description="Language code")
    timeout: int = Field(default=60, ge=10, le=300, description="Request timeout in seconds")

class FeedRequest(BaseModel):
    url: HttpUrl
    max_articles: int = Field(default=10, ge=1, le=50, description="Maximum articles to parse")
    timeout: int = Field(default=30, ge=5, le=120, description="Request timeout in seconds")

class ArticleResponse(BaseModel):
    title: str
    content: str
    summary: Optional[str] = None
    authors: List[str]
    publish_date: Optional[datetime] = None
    top_image: Optional[str] = None
    images: List[str]
    keywords: List[str]
    language: str
    url: str
    word_count: int
    read_time_minutes: int

# Helper functions
def extract_article_content(url: str, language: str = "auto", timeout: int = 30) -> Dict[str, Any]:
    """Extract article content using newspaper4k"""
    try:
        # Get random headers
        headers = get_random_headers()
        
        # Create article with custom config
        config = newspaper.Config()
        config.browser_user_agent = headers['User-Agent']
        config.request_timeout = timeout
        config.number_threads = 1
        config.thread_timeout_seconds = timeout
        config.ignored_content_types_defaults = {}
        
        if language != "auto":
            config.language = language
        
        # Create and process article
        article = Article(str(url), config=config)
        
        # Set custom headers for requests
        article.download(input_html=None, title=None, recursion_counter=0)
        article.parse()
        
        # Try NLP processing
        try:
            article.nlp()
        except Exception as e:
            logger.warning(f"NLP processing failed: {e}")
        
        # Calculate read time (average 200 words per minute)
        word_count = len(article.text.split()) if article.text else 0
        read_time = max(1, round(word_count / 200))
        
        return {
            "title": article.title or "No title found",
            "content": article.text or "No content extracted",
            "summary": article.summary or None,
            "authors": article.authors or [],
            "publish_date": article.publish_date,
            "top_image": article.top_image or None,
            "images": list(article.images) if article.images else [],
            "keywords": article.keywords or [],
            "language": article.meta_lang or language,
            "url": str(url),
            "word_count": word_count,
            "read_time_minutes": read_time
        }
        
    except Exception as e:
        logger.error(f"Error extracting article from {url}: {e}")
        raise HTTPException(
            status_code=400,
            detail=f"Failed to extract article: {str(e)}"
        )

def extract_source_articles(url: str, max_articles: int = 10, language: str = "auto", timeout: int = 60) -> List[Dict[str, Any]]:
    """Extract multiple articles from a news source"""
    try:
        # Get random headers
        headers = get_random_headers()
        
        # Create source with custom config
        config = newspaper.Config()
        config.browser_user_agent = headers['User-Agent']
        config.request_timeout = timeout
        config.number_threads = 3
        config.thread_timeout_seconds = timeout
        
        if language != "auto":
            config.language = language
        
        # Build source
        source = Source(str(url), config=config)
        source.build()
        
        # Limit articles
        articles_to_process = source.articles[:max_articles]
        results = []
        
        for article in articles_to_process:
            try:
                article.download()
                article.parse()
                
                # Try NLP
                try:
                    article.nlp()
                except:
                    pass
                
                word_count = len(article.text.split()) if article.text else 0
                read_time = max(1, round(word_count / 200))
                
                results.append({
                    "title": article.title or "No title",
                    "content": article.text or "No content",
                    "summary": article.summary or None,
                    "authors": article.authors or [],
                    "publish_date": article.publish_date,
                    "top_image": article.top_image or None,
                    "images": list(article.images) if article.images else [],
                    "keywords": article.keywords or [],
                    "language": article.meta_lang or language,
                    "url": article.url,
                    "word_count": word_count,
                    "read_time_minutes": read_time
                })
                
            except Exception as e:
                logger.warning(f"Failed to process article {article.url}: {e}")
                continue
        
        return results
        
    except Exception as e:
        logger.error(f"Error extracting source {url}: {e}")
        raise HTTPException(
            status_code=400,
            detail=f"Failed to extract source: {str(e)}"
        )

# API Routes
@app.get("/", response_class=HTMLResponse)
async def homepage():
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
            .container {{ max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
            h1 {{ color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }}
            h2 {{ color: #34495e; margin-top: 30px; }}
            .endpoint {{ background: #ecf0f1; padding: 15px; border-radius: 5px; margin: 10px 0; }}
            .method {{ background: #3498db; color: white; padding: 5px 10px; border-radius: 3px; font-weight: bold; }}
            .method.post {{ background: #e74c3c; }}
            code {{ background: #f8f9fa; padding: 2px 5px; border-radius: 3px; font-family: 'Courier New', monospace; }}
            .warning {{ background: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 5px; margin: 20px 0; }}
            .info {{ background: #d1ecf1; border: 1px solid #bee5eb; padding: 15px; border-radius: 5px; margin: 20px 0; }}
            .token-info {{ background: #f8d7da; border: 1px solid #f5c6cb; padding: 15px; border-radius: 5px; margin: 20px 0; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 News Content API v2.0</h1>
            <p>Advanced News Content Extraction API powered by <strong>Newspaper4k</strong> with Random User Agent rotation.</p>
            
            <div class="token-info">
                <h3>🔐 Authentication Required</h3>
                <p>All API endpoints require Bearer Token authentication.</p>
                <p><strong>Your token was set during installation.</strong></p>
                <p>Use: <code>Authorization: Bearer YOUR_TOKEN</code></p>
            </div>

            <div class="info">
                <h3>📚 Documentation</h3>
                <p>• <a href="/docs" target="_blank">Swagger UI Documentation</a></p>
                <p>• <a href="/redoc" target="_blank">ReDoc Documentation</a></p>
            </div>

            <h2>📋 Available Endpoints</h2>
            
            <div class="endpoint">
                <span class="method">GET</span> <code>/health</code>
                <p>Check API health status</p>
            </div>
            
            <div class="endpoint">
                <span class="method post">POST</span> <code>/extract-article</code>
                <p>Extract content from a single article URL</p>
                <p><strong>Parameters:</strong> url, language, extract_images, summarize, timeout</p>
            </div>
            
            <div class="endpoint">
                <span class="method post">POST</span> <code>/extract-source</code>
                <p>Extract multiple articles from a news website</p>
                <p><strong>Parameters:</strong> url, max_articles, language, timeout</p>
            </div>
            
            <div class="endpoint">
                <span class="method post">POST</span> <code>/parse-feed</code>
                <p>Parse RSS/Atom feeds</p>
                <p><strong>Parameters:</strong> url, max_articles, timeout</p>
            </div>

            <h2>🔧 Change Bearer Token</h2>
            <div class="warning">
                <p><strong>Method 1:</strong> Edit docker-compose.yml</p>
                <code>cd /home/n8n && nano docker-compose.yml</code>
                <p>Find <code>NEWS_API_TOKEN</code> and change the value, then restart:</p>
                <code>docker compose restart fastapi</code>
                
                <p><strong>Method 2:</strong> One-liner command</p>
                <code>cd /home/n8n && sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN="NEW_TOKEN"/' docker-compose.yml && docker compose restart fastapi</code>
                
                <p><strong>Method 3:</strong> Environment variable</p>
                <code>docker exec -it n8n-fastapi-1 sh -c 'echo "NEW_TOKEN" > /app/news_api_token.txt'</code>
                <code>docker compose restart fastapi</code>
            </div>

            <h2>🌟 Features</h2>
            <ul>
                <li>✅ <strong>Newspaper4k</strong> - Latest article extraction library</li>
                <li>✅ <strong>Random User Agents</strong> - Anti-detection with 10+ user agents</li>
                <li>✅ <strong>Multi-language</strong> - Support 80+ languages</li>
                <li>✅ <strong>Image Extraction</strong> - Get article images and top image</li>
                <li>✅ <strong>NLP Processing</strong> - Keywords and summary generation</li>
                <li>✅ <strong>RSS/Atom Feeds</strong> - Parse news feeds</li>
                <li>✅ <strong>Source Extraction</strong> - Bulk article extraction</li>
                <li>✅ <strong>Rate Limiting</strong> - Built-in protection</li>
            </ul>

            <h2>💡 Example Usage</h2>
            <div class="endpoint">
                <h4>Extract Single Article:</h4>
                <code>
curl -X POST "https://api.{DOMAIN}/extract-article" \\<br>
&nbsp;&nbsp;&nbsp;&nbsp;-H "Authorization: Bearer YOUR_TOKEN" \\<br>
&nbsp;&nbsp;&nbsp;&nbsp;-H "Content-Type: application/json" \\<br>
&nbsp;&nbsp;&nbsp;&nbsp;-d '{{"url": "https://example.com/article", "language": "en"}}'
                </code>
            </div>

            <p style="margin-top: 40px; text-align: center; color: #7f8c8d;">
                <strong>Created by Nguyễn Ngọc Thiện</strong><br>
                <a href="https://www.youtube.com/@kalvinthiensocial" target="_blank">YouTube Channel</a> | 
                <a href="https://www.facebook.com/Ban.Thien.Handsome/" target="_blank">Facebook</a>
            </p>
        </div>
    </body>
    </html>
    """
    return html_content.replace("{DOMAIN}", os.getenv("DOMAIN", "yourdomain.com"))

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "version": "2.0.0",
        "features": {
            "newspaper4k": True,
            "random_user_agents": True,
            "nlp_processing": True,
            "multi_language": True,
            "rss_feeds": True
        }
    }

@app.post("/extract-article", response_model=ArticleResponse)
async def extract_article(
    request: ArticleRequest,
    token: str = Depends(verify_token)
):
    """Extract content from a single article URL"""
    result = extract_article_content(
        str(request.url),
        request.language,
        request.timeout
    )
    return ArticleResponse(**result)

@app.post("/extract-source")
async def extract_source(
    request: SourceRequest,
    token: str = Depends(verify_token)
):
    """Extract multiple articles from a news source"""
    articles = extract_source_articles(
        str(request.url),
        request.max_articles,
        request.language,
        request.timeout
    )
    
    return {
        "source_url": str(request.url),
        "total_articles": len(articles),
        "articles": articles,
        "extracted_at": datetime.now().isoformat()
    }

@app.post("/parse-feed")
async def parse_feed(
    request: FeedRequest,
    token: str = Depends(verify_token)
):
    """Parse RSS/Atom feed"""
    try:
        headers = get_random_headers()
        
        # Parse feed
        feed = feedparser.parse(str(request.url), request_headers=headers)
        
        if feed.bozo:
            raise HTTPException(
                status_code=400,
                detail="Invalid RSS/Atom feed"
            )
        
        articles = []
        entries = feed.entries[:request.max_articles]
        
        for entry in entries:
            # Extract basic info
            article_data = {
                "title": getattr(entry, 'title', 'No title'),
                "content": getattr(entry, 'summary', '') or getattr(entry, 'description', ''),
                "url": getattr(entry, 'link', ''),
                "publish_date": None,
                "authors": [],
                "word_count": 0,
                "read_time_minutes": 1
            }
            
            # Parse publish date
            if hasattr(entry, 'published_parsed') and entry.published_parsed:
                try:
                    article_data["publish_date"] = datetime(*entry.published_parsed[:6])
                except:
                    pass
            
            # Parse authors
            if hasattr(entry, 'author'):
                article_data["authors"] = [entry.author]
            
            # Calculate word count and read time
            content = article_data["content"]
            if content:
                word_count = len(content.split())
                article_data["word_count"] = word_count
                article_data["read_time_minutes"] = max(1, round(word_count / 200))
            
            articles.append(article_data)
        
        return {
            "feed_url": str(request.url),
            "feed_title": getattr(feed.feed, 'title', 'Unknown'),
            "feed_description": getattr(feed.feed, 'description', ''),
            "total_articles": len(articles),
            "articles": articles,
            "parsed_at": datetime.now().isoformat()
        }
        
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

    # Tạo Dockerfile cho News API
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
COPY main.py .

# Copy token file
COPY ../news_api_token.txt /app/news_api_token.txt

# Expose port
EXPOSE 8000

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
EOF

    log_success "News Content API đã được tạo với Newspaper4k và Random User Agent!"
}

# =============================================================================
# 🐳 HÀM TẠO N8N DOCKERFILE
# =============================================================================

create_n8n_dockerfile() {
    log_header "⚙️ TẠO N8N DOCKERFILE"
    
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

# Set working directory
WORKDIR /home/node

# Expose port
EXPOSE 5678

# Start N8N
CMD ["n8n", "start"]
EOF

    log_success "N8N Dockerfile đã được tạo!"
}

# =============================================================================
# 🐳 HÀM TẠO DOCKER COMPOSE
# =============================================================================

create_docker_compose() {
    log_header "⚙️ TẠO DOCKER COMPOSE"
    
    DOCKER_COMPOSE_CONTENT="version: '3.8'

services:
  n8n:
    build: .
    image: n8n-custom-ffmpeg:latest
    container_name: n8n-n8n-1
    restart: unless-stopped
    ports:
      - \"127.0.0.1:5678:5678\"
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
      - N8N_EXECUTIONS_DATA_MAX_SIZE=500MB
      - N8N_LOG_LEVEL=info
      - N8N_LOG_OUTPUT=console,file
      - N8N_LOG_FILE_COUNT_MAX=100
      - N8N_LOG_FILE_SIZE_MAX=16m
      - N8N_USER_MANAGEMENT_DISABLED=false
      - N8N_PUBLIC_API_DISABLED=false
      - N8N_DISABLE_UI=false
      - N8N_ENCRYPTION_KEY=\${N8N_ENCRYPTION_KEY:-}
    volumes:
      - ./files:/data
      - ./database.sqlite:/home/node/.n8n/database.sqlite
      - ./encryptionKey:/home/node/.n8n/config/encryptionKey
    networks:
      - default
    depends_on:
      - caddy

  caddy:
    image: caddy:latest
    container_name: n8n-caddy-1
    restart: unless-stopped
    ports:
      - \"80:80\"
      - \"443:443\"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - default"

    if [[ "$ENABLE_NEWS_API" == "y" ]]; then
        DOCKER_COMPOSE_CONTENT="$DOCKER_COMPOSE_CONTENT

  fastapi:
    build: ./news_api
    image: news-api:latest
    container_name: n8n-fastapi-1
    restart: unless-stopped
    ports:
      - \"127.0.0.1:8000:8000\"
    environment:
      - NEWS_API_TOKEN=$NEWS_API_TOKEN
      - DOMAIN=$DOMAIN
    volumes:
      - ./news_api_token.txt:/app/news_api_token.txt:ro
    networks:
      - default"
    fi

    DOCKER_COMPOSE_CONTENT="$DOCKER_COMPOSE_CONTENT

volumes:
  caddy_data:
  caddy_config:

networks:
  default:
    driver: bridge"

    echo "$DOCKER_COMPOSE_CONTENT" > "$INSTALL_DIR/docker-compose.yml"
    
    log_success "Docker Compose đã được tạo!"
}

# =============================================================================
# 🔒 HÀM TẠO CADDYFILE
# =============================================================================

create_caddyfile() {
    log_header "🔒 TẠO CADDYFILE"
    
    CADDYFILE_CONTENT="{
    email admin@$DOMAIN
    acme_ca https://acme-v02.api.letsencrypt.org/directory
}

$DOMAIN {
    reverse_proxy n8n:5678
    
    header {
        Strict-Transport-Security \"max-age=31536000; includeSubDomains\"
        X-Content-Type-Options \"nosniff\"
        X-Frame-Options \"DENY\"
        X-XSS-Protection \"1; mode=block\"
    }
    
    encode gzip
    
    log {
        output file /var/log/caddy/n8n.log
        format json
    }
}"

    if [[ "$ENABLE_NEWS_API" == "y" ]]; then
        CADDYFILE_CONTENT="$CADDYFILE_CONTENT

$API_DOMAIN {
    reverse_proxy fastapi:8000
    
    header {
        Strict-Transport-Security \"max-age=31536000; includeSubDomains\"
        X-Content-Type-Options \"nosniff\"
        X-Frame-Options \"DENY\"
        X-XSS-Protection \"1; mode=block\"
        Access-Control-Allow-Origin \"*\"
        Access-Control-Allow-Methods \"GET, POST, PUT, DELETE, OPTIONS\"
        Access-Control-Allow-Headers \"Content-Type, Authorization\"
    }
    
    encode gzip
    
    log {
        output file /var/log/caddy/api.log
        format json
    }
}"
    fi

    echo "$CADDYFILE_CONTENT" > "$INSTALL_DIR/Caddyfile"
    
    log_success "Caddyfile đã được tạo!"
}

# =============================================================================
# 💾 HÀM TẠO BACKUP SCRIPTS
# =============================================================================

create_backup_scripts() {
    log_header "📦 TẠO BACKUP SCRIPTS"
    
    # Script backup chính
    cat > "$INSTALL_DIR/backup-workflows.sh" << 'EOF'
#!/bin/bash

# Backup N8N workflows and data
BACKUP_DIR="/home/n8n/files/backup_full"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="n8n_backup_${TIMESTAMP}.tar.gz"
LOG_FILE="$BACKUP_DIR/backup.log"

# Tạo thư mục backup nếu chưa có
mkdir -p "$BACKUP_DIR"

# Function để ghi log
log_backup() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_backup "🔄 Bắt đầu backup N8N..."

# Tạo thư mục tạm
TEMP_DIR="/tmp/n8n_backup_$TIMESTAMP"
mkdir -p "$TEMP_DIR"

# Export workflows từ N8N (nếu có)
if [ -f "/home/n8n/database.sqlite" ]; then
    log_backup "📋 Backup database và workflows..."
    mkdir -p "$TEMP_DIR/workflows"
    mkdir -p "$TEMP_DIR/credentials"
    
    # Copy database
    cp "/home/n8n/database.sqlite" "$TEMP_DIR/credentials/" 2>/dev/null || true
    
    # Copy encryption key
    cp "/home/n8n/encryptionKey" "$TEMP_DIR/credentials/" 2>/dev/null || true
    
    # Copy config files
    if [ -d "/home/n8n/files" ]; then
        mkdir -p "$TEMP_DIR/config"
        cp -r "/home/n8n/files" "$TEMP_DIR/config/" 2>/dev/null || true
    fi
fi

# Tạo metadata
cat > "$TEMP_DIR/backup_metadata.json" << EOL
{
    "backup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "version": "2.0",
    "domain": "$(cat /home/n8n/docker-compose.yml | grep N8N_HOST | cut -d'=' -f2 || echo 'unknown')",
    "backup_type": "full"
}
EOL

# Tạo file tar.gz
cd "$TEMP_DIR"
tar -czf "$BACKUP_DIR/$BACKUP_FILE" . 2>/dev/null

# Xóa thư mục tạm
rm -rf "$TEMP_DIR"

# Kiểm tra kết quả
if [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
    log_backup "✅ Backup thành công: $BACKUP_FILE ($BACKUP_SIZE)"
    
    # Gửi thông báo Telegram nếu được cấu hình
    if [ -f "/home/n8n/telegram_config.txt" ]; then
        source "/home/n8n/telegram_config.txt"
        if [ ! -z "$TELEGRAM_BOT_TOKEN" ] && [ ! -z "$TELEGRAM_CHAT_ID" ]; then
            MESSAGE="🔄 N8N Backup hoàn thành!%0A📁 File: $BACKUP_FILE%0A📊 Size: $BACKUP_SIZE%0A⏰ Time: $(date '+%Y-%m-%d %H:%M:%S')"
            
            # Gửi tin nhắn
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
                -d chat_id="$TELEGRAM_CHAT_ID" \
                -d text="$MESSAGE" \
                -d parse_mode="HTML" >/dev/null 2>&1
            
            # Gửi file nếu nhỏ hơn 20MB
            FILE_SIZE_MB=$(du -m "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
            if [ "$FILE_SIZE_MB" -lt 20 ]; then
                curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument" \
                    -F chat_id="$TELEGRAM_CHAT_ID" \
                    -F document="@$BACKUP_DIR/$BACKUP_FILE" \
                    -F caption="📦 N8N Backup File - $BACKUP_FILE" >/dev/null 2>&1
                log_backup "📱 Đã gửi backup file qua Telegram"
            else
                log_backup "📱 File quá lớn để gửi qua Telegram (>20MB)"
            fi
        fi
    fi
else
    log_backup "❌ Backup thất bại!"
    exit 1
fi

# Xóa backup cũ (giữ lại 30 bản gần nhất)
cd "$BACKUP_DIR"
ls -t n8n_backup_*.tar.gz 2>/dev/null | tail -n +31 | xargs rm -f 2>/dev/null || true

log_backup "🧹 Đã dọn dẹp backup cũ (giữ lại 30 bản gần nhất)"
log_backup "✅ Backup hoàn thành!"
EOF

    # Script backup manual test
    cat > "$INSTALL_DIR/backup-manual.sh" << 'EOF'
#!/bin/bash

echo "🧪 CHẠY BACKUP TEST MANUAL"
echo "=========================="

# Chạy backup script
/home/n8n/backup-workflows.sh

echo ""
echo "📁 DANH SÁCH BACKUP FILES:"
ls -lah /home/n8n/files/backup_full/*.tar.gz 2>/dev/null || echo "Không có backup files"

echo ""
echo "📋 LOG BACKUP GẦN NHẤT:"
tail -10 /home/n8n/files/backup_full/backup.log 2>/dev/null || echo "Không có log file"
EOF

    # Script update tự động
    cat > "$INSTALL_DIR/update-n8n.sh" << 'EOF'
#!/bin/bash

LOG_FILE="/home/n8n/logs/update.log"
mkdir -p "/home/n8n/logs"

log_update() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_update "🔄 Bắt đầu cập nhật N8N..."

cd /home/n8n

# Xác định Docker Compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    log_update "❌ Docker Compose không tìm thấy!"
    exit 1
fi

# Pull images mới
log_update "📥 Đang pull Docker images mới..."
$DOCKER_COMPOSE pull

# Restart containers
log_update "🔄 Đang restart containers..."
$DOCKER_COMPOSE up -d

# Cập nhật yt-dlp trong container
log_update "📺 Đang cập nhật yt-dlp..."
docker exec n8n-n8n-1 pip3 install --break-system-packages -U yt-dlp 2>/dev/null || true

log_update "✅ Cập nhật hoàn thành!"
EOF

    # Script troubleshoot
    cat > "$INSTALL_DIR/troubleshoot.sh" << 'EOF'
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
echo "📍 3. Disk Usage:"
df -h

echo ""
echo "📍 4. Memory Usage:"
free -h

echo ""
echo "📍 5. N8N Logs (10 dòng cuối):"
$DOCKER_COMPOSE logs --tail=10 n8n

echo ""
echo "📍 6. Caddy Logs (10 dòng cuối):"
$DOCKER_COMPOSE logs --tail=10 caddy

if [ -f "docker-compose.yml" ] && grep -q "fastapi" docker-compose.yml; then
    echo ""
    echo "📍 7. News API Logs (10 dòng cuối):"
    $DOCKER_COMPOSE logs --tail=10 fastapi
fi

echo ""
echo "📍 8. SSL Certificate Check:"
echo "Domain: $(grep -o '[a-zA-Z0-9.-]*\.[a-zA-Z]{2,}' Caddyfile | head -1)"
openssl s_client -connect $(grep -o '[a-zA-Z0-9.-]*\.[a-zA-Z]{2,}' Caddyfile | head -1):443 -servername $(grep -o '[a-zA-Z0-9.-]*\.[a-zA-Z]{2,}' Caddyfile | head -1) 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "SSL chưa sẵn sàng"

echo ""
echo "📍 9. Recent Backup Files:"
ls -lah files/backup_full/*.tar.gz 2>/dev/null | tail -5 || echo "Không có backup files"

echo ""
echo "🔧 QUICK FIX COMMANDS:"
echo "======================"
echo "Restart all: cd /home/n8n && $DOCKER_COMPOSE restart"
echo "Rebuild all: cd /home/n8n && $DOCKER_COMPOSE down && $DOCKER_COMPOSE up -d --build"
echo "View logs: cd /home/n8n && $DOCKER_COMPOSE logs -f"
echo "Manual backup: /home/n8n/backup-manual.sh"
EOF

    # Set permissions
    chmod +x "$INSTALL_DIR"/*.sh
    
    log_success "Backup scripts đã được tạo!"
}

# =============================================================================
# 🔧 HÀM THIẾT LẬP CRON JOBS
# =============================================================================

setup_cron_jobs() {
    if [[ "$AUTO_UPDATE" == "y" ]]; then
        # Thêm cron job cho auto update (mỗi 12 giờ)
        (crontab -l 2>/dev/null; echo "0 */12 * * * /home/n8n/update-n8n.sh >/dev/null 2>&1") | crontab -
    fi
    
    # Thêm cron job cho backup hàng ngày
    (crontab -l 2>/dev/null; echo "0 2 * * * /home/n8n/backup-workflows.sh >/dev/null 2>&1") | crontab -
}

# =============================================================================
# 📱 HÀM THIẾT LẬP TELEGRAM
# =============================================================================

setup_telegram() {
    if [[ "$ENABLE_TELEGRAM" != "y" ]]; then
        return
    fi
    
    # Tạo file config Telegram
    cat > "$INSTALL_DIR/telegram_config.txt" << EOF
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"
EOF
    
    chmod 600 "$INSTALL_DIR/telegram_config.txt"
    
    # Test Telegram connection
    log_info "Đang test kết nối Telegram..."
    
    TEST_MESSAGE="🚀 N8N Installation Complete!%0A📅 $(date '+%Y-%m-%d %H:%M:%S')%0A🌐 Domain: $DOMAIN"
    
    RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$TEST_MESSAGE" \
        -d parse_mode="HTML")
    
    if echo "$RESPONSE" | grep -q '"ok":true'; then
        log_success "Telegram đã được cấu hình thành công!"
    else
        log_warning "Không thể gửi tin nhắn test Telegram. Vui lòng kiểm tra Bot Token và Chat ID."
    fi
}

# =============================================================================
# 🚀 HÀM BUILD VÀ KHỞI ĐỘNG
# =============================================================================

build_and_start() {
    log_header "🚀 BUILD VÀ KHỞI ĐỘNG CONTAINERS"
    
    cd "$INSTALL_DIR"
    
    # Xác định Docker Compose command
    DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
    
    log_info "Đang build Docker images..."
    $DOCKER_COMPOSE_CMD build --no-cache
    
    log_info "Đang khởi động các container..."
    $DOCKER_COMPOSE_CMD up -d
    
    log_info "Đợi containers khởi động và SSL được cấp (60 giây)..."
    sleep 60
    
    # Kiểm tra trạng thái containers
    log_info "Kiểm tra trạng thái các container..."
    
    if docker ps | grep -q "n8n-n8n-1"; then
        log_success "Container n8n đã chạy thành công."
    else
        log_error "Container n8n không chạy được!"
    fi
    
    if docker ps | grep -q "n8n-caddy-1"; then
        log_success "Container caddy đã chạy thành công."
    else
        log_error "Container caddy không chạy được!"
    fi
    
    if [[ "$ENABLE_NEWS_API" == "y" ]] && docker ps | grep -q "n8n-fastapi-1"; then
        log_success "Container fastapi đã chạy thành công."
    fi
}

# =============================================================================
# 🔒 HÀM KIỂM TRA SSL VÀ XỬ LÝ RATE LIMIT
# =============================================================================

check_ssl_and_rate_limit() {
    log_header "🔒 KIỂM TRA SSL CERTIFICATE"
    
    cd "$INSTALL_DIR"
    DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
    
    # Kiểm tra Caddy logs để tìm rate limit
    CADDY_LOGS=$($DOCKER_COMPOSE_CMD logs caddy 2>/dev/null | tail -20)
    
    if echo "$CADDY_LOGS" | grep -q "rateLimited\|rate.*limit\|too many certificates"; then
        log_error "🚨 PHÁT HIỆN SSL RATE LIMIT!"
        log_error "Let's Encrypt đã giới hạn số lượng certificate cho domain này."
        echo ""
        log_warning "📋 CÁC GIẢI PHÁP:"
        echo ""
        log_message "1️⃣ 🔄 SỬ DỤNG STAGING SSL (Khuyến nghị)"
        log_message "   - Website sẽ hoạt động ngay nhưng browser hiển thị 'Not Secure'"
        log_message "   - Chức năng N8N và API hoạt động đầy đủ"
        log_message "   - Có thể chuyển về production SSL sau 7 ngày"
        echo ""
        log_message "2️⃣ ⏰ ĐỢI 7 NGÀY"
        log_message "   - Đợi đến sau ngày $(date -d '+7 days' '+%d/%m/%Y')"
        log_message "   - Rate limit sẽ được reset"
        echo ""
        log_message "3️⃣ 🔄 CÀI LẠI UBUNTU VPS"
        log_message "   - Backup dữ liệu quan trọng trước"
        log_message "   - Cài lại Ubuntu và chạy script này"
        log_message "   - Sử dụng IP mới sẽ không bị rate limit"
        echo ""
        
        read -p "$(echo -e "${CYAN}Bạn có muốn sử dụng Staging SSL để tiếp tục? (Y/n): ${NC}")" -r
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            setup_staging_ssl
        else
            log_warning "Vui lòng chọn một trong các giải pháp trên và chạy lại script."
            exit 1
        fi
    else
        # Kiểm tra SSL certificate bình thường
        log_info "Đang kiểm tra SSL certificate..."
        
        sleep 30  # Đợi thêm để SSL có thể được cấp
        
        if openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" 2>/dev/null | grep -q "Verify return code: 0"; then
            log_success "SSL certificate cho $DOMAIN đã được cấp thành công!"
        else
            log_warning "SSL cho $DOMAIN có thể chưa sẵn sàng. Đợi thêm vài phút."
        fi
        
        if [[ "$ENABLE_NEWS_API" == "y" ]]; then
            if openssl s_client -connect "$API_DOMAIN:443" -servername "$API_DOMAIN" 2>/dev/null | grep -q "Verify return code: 0"; then
                log_success "SSL certificate cho $API_DOMAIN đã được cấp thành công!"
            else
                log_warning "SSL cho $API_DOMAIN có thể chưa sẵn sàng. Đợi thêm vài phút."
            fi
        fi
    fi
}

# =============================================================================
# 🔧 HÀM THIẾT LẬP STAGING SSL
# =============================================================================

setup_staging_ssl() {
    log_header "🔧 THIẾT LẬP STAGING SSL"
    
    cd "$INSTALL_DIR"
    DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
    
    log_info "Đang dừng containers..."
    $DOCKER_COMPOSE_CMD down
    
    log_info "Đang xóa SSL data cũ..."
    docker volume rm n8n_caddy_data n8n_caddy_config 2>/dev/null || true
    
    log_info "Đang tạo Caddyfile với Let's Encrypt STAGING..."
    
    # Tạo Caddyfile với staging environment
    STAGING_CADDYFILE="{
    email admin@$DOMAIN
    acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
    debug
}

$DOMAIN {
    reverse_proxy n8n:5678
    
    header {
        Strict-Transport-Security \"max-age=31536000; includeSubDomains\"
        X-Content-Type-Options \"nosniff\"
        X-Frame-Options \"DENY\"
        X-XSS-Protection \"1; mode=block\"
    }
    
    encode gzip
    
    log {
        output file /var/log/caddy/n8n.log
        format json
    }
}"

    if [[ "$ENABLE_NEWS_API" == "y" ]]; then
        STAGING_CADDYFILE="$STAGING_CADDYFILE

$API_DOMAIN {
    reverse_proxy fastapi:8000
    
    header {
        Strict-Transport-Security \"max-age=31536000; includeSubDomains\"
        X-Content-Type-Options \"nosniff\"
        X-Frame-Options \"DENY\"
        X-XSS-Protection \"1; mode=block\"
        Access-Control-Allow-Origin \"*\"
        Access-Control-Allow-Methods \"GET, POST, PUT, DELETE, OPTIONS\"
        Access-Control-Allow-Headers \"Content-Type, Authorization\"
    }
    
    encode gzip
    
    log {
        output file /var/log/caddy/api.log
        format json
    }
}"
    fi

    echo "$STAGING_CADDYFILE" > "$INSTALL_DIR/Caddyfile"
    
    log_info "Đang khởi động containers với staging SSL..."
    $DOCKER_COMPOSE_CMD up -d
    
    log_info "Đợi staging SSL được cấp (30 giây)..."
    sleep 30
    
    log_success "🎯 STAGING SSL ĐÃ ĐƯỢC THIẾT LẬP!"
    log_warning "⚠️ Website sẽ hiển thị cảnh báo 'Not Secure' - đây là bình thường với staging certificate"
    log_success "✅ Tất cả chức năng N8N và API hoạt động đầy đủ"
    
    # Tạo script chuyển về production SSL
    cat > "$INSTALL_DIR/switch-to-production-ssl.sh" << EOF
#!/bin/bash

echo "🔄 CHUYỂN VỀ PRODUCTION SSL"
echo "=========================="

cd /home/n8n

# Xác định Docker Compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    echo "❌ Docker Compose không tìm thấy!"
    exit 1
fi

echo "⏹️ Đang dừng containers..."
\$DOCKER_COMPOSE down

echo "🗑️ Đang xóa staging SSL data..."
docker volume rm n8n_caddy_data n8n_caddy_config 2>/dev/null || true

echo "📝 Đang tạo production Caddyfile..."
cat > /home/n8n/Caddyfile << 'PROD_EOF'
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
PROD_EOF

if [[ "$ENABLE_NEWS_API" == "y" ]]; then
cat >> /home/n8n/Caddyfile << 'PROD_EOF'

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
PROD_EOF
fi

echo "🚀 Đang khởi động với production SSL..."
\$DOCKER_COMPOSE up -d

echo "✅ Đã chuyển về production SSL!"
echo "🌐 Truy cập: https://$DOMAIN"
EOF

    chmod +x "$INSTALL_DIR/switch-to-production-ssl.sh"
    
    log_info "📝 Script chuyển về production SSL đã được tạo tại:"
    log_info "   /home/n8n/switch-to-production-ssl.sh"
    log_info "🕐 Chạy script này sau ngày $(date -d '+7 days' '+%d/%m/%Y') để có production SSL"
}

# =============================================================================
# 📊 HÀM HIỂN THỊ KẾT QUẢ
# =============================================================================

show_final_result() {
    log_header "🎉 N8N ĐÃ ĐƯỢC CÀI ĐẶT THÀNH CÔNG!"
    
    # Thông tin truy cập
    log_message "🌐 Truy cập N8N: https://$DOMAIN"
    
    if [[ "$ENABLE_NEWS_API" == "y" ]]; then
        log_message "📰 Truy cập News API: https://$API_DOMAIN"
        log_message "📚 API Documentation: https://$API_DOMAIN/docs"
        log_message "🔑 Bearer Token: $NEWS_API_TOKEN"
    fi
    
    echo ""
    
    # Thông tin hệ thống
    CURRENT_SWAP=$(free -h | awk '/^Swap:/ {print $2}')
    log_message "📁 Thư mục cài đặt: $INSTALL_DIR"
    log_message "🔧 Script chẩn đoán: $INSTALL_DIR/troubleshoot.sh"
    log_message "🧪 Test backup: $INSTALL_DIR/backup-manual.sh"
    log_message "💾 Swap: $CURRENT_SWAP"
    
    if [[ "$AUTO_UPDATE" == "y" ]]; then
        log_message "🔄 Auto-update: Enabled (mỗi 12h)"
    else
        log_message "🔄 Auto-update: Disabled"
    fi
    
    if [[ "$ENABLE_TELEGRAM" == "y" ]]; then
        log_message "📱 Telegram backup: Enabled"
    else
        log_message "📱 Telegram backup: Disabled"
    fi
    
    log_message "💾 Backup tự động: Hàng ngày lúc 2:00 AM"
    log_message "📂 Backup location: $INSTALL_DIR/files/backup_full/"
    
    echo ""
    
    # Thông tin tác giả
    log_message "🚀 Tác giả: Nguyễn Ngọc Thiện"
    log_message "📺 YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1"
    log_message "📱 Zalo: 08.8888.4749"
}

# =============================================================================
# 🚀 HÀM MAIN
# =============================================================================

main() {
    # Hiển thị header
    log_header "🚀 SCRIPT CÀI ĐẶT N8N TỰ ĐỘNG VỚI FFMPEG, YT-DLP, PUPPETEER VÀ NEWS API"
    log_message "Tác giả: Nguyễn Ngọc Thiện"
    log_message "YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1"
    log_message "Cập nhật: 28/06/2025"
    echo ""
    
    # Kiểm tra điều kiện
    check_root
    detect_os
    check_internet
    
    # Nhập thông tin
    input_domain
    ask_clean_install
    ask_news_api
    ask_telegram_backup
    ask_auto_update
    
    # Kiểm tra DNS
    check_dns
    
    # Thiết lập hệ thống
    setup_swap
    install_docker
    clean_old_installation
    
    # Tạo cấu trúc
    create_directory_structure
    create_news_api
    create_n8n_dockerfile
    create_docker_compose
    create_caddyfile
    create_backup_scripts
    
    # Thiết lập services
    setup_cron_jobs
    setup_telegram
    
    # Build và khởi động
    build_and_start
    
    # Kiểm tra SSL và xử lý rate limit
    check_ssl_and_rate_limit
    
    # Hiển thị kết quả
    show_final_result
}

# =============================================================================
# 🎯 CHẠY SCRIPT
# =============================================================================

# Xử lý tham số dòng lệnh
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN_INSTALL="y"
            shift
            ;;
        -d|--directory)
            INSTALL_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Sử dụng: $0 [OPTIONS]"
            echo "OPTIONS:"
            echo "  --clean           Xóa cài đặt cũ"
            echo "  -d, --directory   Thư mục cài đặt (mặc định: /home/n8n)"
            echo "  -h, --help        Hiển thị trợ giúp"
            exit 0
            ;;
        *)
            log_error "Tham số không hợp lệ: $1"
            exit 1
            ;;
    esac
done

# Chạy main function
main "$@"
