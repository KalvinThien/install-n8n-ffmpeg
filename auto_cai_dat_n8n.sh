#!/bin/bash

# Script cài đặt N8N tự động với ZeroSSL và Google Drive Backup
# Tác giả: Nguyễn Ngọc Thiện
# YouTube: https://www.youtube.com/@kalvinthiensocial
# Cập nhật: 30/06/2025

set -e

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Biến toàn cục
SCRIPT_DIR="/tmp"
N8N_DIR="/home/n8n"
DOMAIN=""
API_DOMAIN=""
USE_DOMAIN="true"
NEWS_API_ENABLED="false"
TELEGRAM_BACKUP_ENABLED="false"
GDRIVE_BACKUP_ENABLED="false"
AUTO_UPDATE_ENABLED="false"
BEARER_TOKEN=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
GDRIVE_SERVICE_ACCOUNT=""
SSL_PROVIDER="letsencrypt"

# Logging
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_info() {
    log "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    log "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

# Header
show_header() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🚀 SCRIPT CÀI ĐẶT N8N TỰ ĐỘNG 2025 🚀                    ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ ✨ N8N + FFmpeg + yt-dlp + Puppeteer + News API + Telegram Backup        ║
║ 🔒 SSL Certificate tự động với Let's Encrypt & ZeroSSL                   ║
║ 📰 News Content API với FastAPI + Newspaper4k                            ║
║ 📱 Telegram Backup tự động hàng ngày                                     ║
║ ☁️  Google Drive Backup với Service Account                              ║
║ 🔄 Auto-Update với tùy chọn                                              ║
║ 🏠 Localhost mode cho máy ảo                                             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ 👨‍💻 Tác giả: Nguyễn Ngọc Thiện                                           ║
║ 📺 YouTube: https://www.youtube.com/@kalvinthiensocial                  ║
║ 📱 Zalo: 08.8888.4749                                                   ║
║ 🎬 Đăng ký kênh để ủng hộ mình nhé! 🔔                                  ║
║ 📅 Cập nhật: 30/06/2025                                                 ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Kiểm tra quyền root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Script này cần chạy với quyền root!"
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
        log_error "Không thể phát hiện hệ điều hành"
        exit 1
    fi
    
    log_info "Hệ điều hành: $OS $VER"
}

# Thiết lập swap
setup_swap() {
    log_info "🔄 Thiết lập swap memory..."
    
    if [[ -f /swapfile ]]; then
        log_info "Swap file đã tồn tại"
        return
    fi
    
    # Tạo swap 2GB
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    
    # Thêm vào fstab
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    
    log_success "Đã thiết lập swap 2GB"
}

# Cấu hình domain
configure_domain() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                           🌐 CẤU HÌNH DOMAIN                                ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo -e "${YELLOW}🏠 Bạn có muốn cài đặt với domain (SSL) hay localhost? (D/l):${NC}"
    echo -e "   ${GREEN}D${NC} - Sử dụng domain với SSL certificate"
    echo -e "   ${GREEN}l${NC} - Localhost mode (không cần domain/SSL)"
    echo ""
    read -p "Lựa chọn (D/l): " domain_choice
    
    case $domain_choice in
        [Ll]*)
            USE_DOMAIN="false"
            log_info "Chế độ localhost được chọn"
            ;;
        *)
            USE_DOMAIN="true"
            echo ""
            echo -e "${CYAN}🌐 Nhập domain chính cho N8N (ví dụ: n8n.example.com):${NC}"
            read -p "Domain: " DOMAIN
            
            if [[ -z "$DOMAIN" ]]; then
                log_error "Domain không được để trống!"
                exit 1
            fi
            
            API_DOMAIN="api.$DOMAIN"
            log_info "Domain N8N: $DOMAIN"
            log_info "Domain API: $API_DOMAIN"
            ;;
    esac
}

# Kiểm tra DNS
check_dns() {
    if [[ "$USE_DOMAIN" == "false" ]]; then
        return 0
    fi
    
    log_info "🔍 Kiểm tra DNS cho domain $DOMAIN..."
    
    SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || curl -s icanhazip.com)
    DOMAIN_IP=$(dig +short $DOMAIN | tail -n1)
    API_DOMAIN_IP=$(dig +short $API_DOMAIN | tail -n1)
    
    log_info "IP máy chủ: $SERVER_IP"
    log_info "IP của $DOMAIN: $DOMAIN_IP"
    log_info "IP của $API_DOMAIN: $API_DOMAIN_IP"
    
    if [[ "$SERVER_IP" != "$DOMAIN_IP" ]] || [[ "$SERVER_IP" != "$API_DOMAIN_IP" ]]; then
        log_warning "DNS chưa được cấu hình đúng!"
        echo -e "${YELLOW}Vui lòng cấu hình DNS records:${NC}"
        echo -e "  A    $DOMAIN        $SERVER_IP"
        echo -e "  A    $API_DOMAIN    $SERVER_IP"
        echo ""
        read -p "Nhấn Enter để tiếp tục sau khi đã cấu hình DNS..."
    else
        log_success "DNS đã được cấu hình đúng"
    fi
}

# Cleanup cài đặt cũ
cleanup_old_installation() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                           🗑️  CLEANUP OPTION                               ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    if [[ -d "$N8N_DIR" ]]; then
        log_warning "Phát hiện cài đặt N8N cũ tại: $N8N_DIR"
        echo -e "${YELLOW}🗑️  Bạn có muốn xóa cài đặt cũ và cài mới? (y/N):${NC}"
        read -p "Lựa chọn: " cleanup_choice
        
        if [[ $cleanup_choice =~ ^[Yy]$ ]]; then
            log_info "🗑️ Xóa cài đặt cũ..."
            
            # Dừng containers
            cd $N8N_DIR 2>/dev/null && docker-compose down -v 2>/dev/null || true
            
            # Xóa thư mục
            rm -rf $N8N_DIR
            
            # Xóa cron jobs
            crontab -l 2>/dev/null | grep -v "/home/n8n" | crontab - 2>/dev/null || true
            
            log_success "Đã xóa cài đặt cũ"
        fi
    fi
}

# Cài đặt Docker
install_docker() {
    if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
        log_info "Docker đã được cài đặt"
        return
    fi
    
    log_info "🐳 Cài đặt Docker..."
    
    # Cập nhật package list
    apt-get update -y
    
    # Cài đặt dependencies
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common \
        jq \
        zip \
        unzip \
        wget \
        git \
        htop \
        nano \
        dnsutils
    
    # Thêm Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Thêm Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Cài đặt Docker
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Cài đặt docker-compose standalone
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Khởi động Docker
    systemctl enable docker
    systemctl start docker
    
    log_success "Đã cài đặt Docker"
}

# Tạo cấu trúc thư mục
create_directory_structure() {
    log_info "📁 Tạo cấu trúc thư mục..."
    
    mkdir -p $N8N_DIR/{data,scripts,backups,logs,ssl}
    mkdir -p $N8N_DIR/news-api
    mkdir -p $N8N_DIR/backups/{local,gdrive}
    
    log_success "Đã tạo cấu trúc thư mục"
}

# Cấu hình News API
configure_news_api() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                        📰 NEWS CONTENT API                                 ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo "News Content API cho phép:"
    echo -e "  📰 Cào nội dung bài viết từ bất kỳ website nào"
    echo -e "  📡 Parse RSS feeds để lấy tin tức mới nhất"
    echo -e "  🔍 Tìm kiếm và phân tích nội dung tự động"
    echo -e "  🤖 Tích hợp trực tiếp vào N8N workflows"
    echo ""
    
    read -p "📰 Bạn có muốn cài đặt News Content API? (Y/n): " news_choice
    
    if [[ ! $news_choice =~ ^[Nn]$ ]]; then
        NEWS_API_ENABLED="true"
        
        echo ""
        echo -e "${CYAN}🔐 Thiết lập Bearer Token cho News API:${NC}"
        echo -e "  • Token có thể chứa chữ cái, số và ký tự đặc biệt"
        echo -e "  • Độ dài tùy ý (khuyến nghị từ 32 ký tự trở lên)"
        echo -e "  • Sẽ được sử dụng để xác thực API calls"
        echo ""
        
        while true; do
            read -s -p "🔑 Nhập Bearer Token: " BEARER_TOKEN
            echo ""
            
            if [[ ${#BEARER_TOKEN} -lt 8 ]]; then
                log_error "Token phải có ít nhất 8 ký tự!"
                continue
            fi
            
            break
        done
        
        log_success "Đã thiết lập Bearer Token cho News API"
    fi
}

# Cấu hình Telegram Backup
configure_telegram_backup() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                        📱 TELEGRAM BACKUP                                  ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo "Telegram Backup cho phép:"
    echo -e "  🔄 Tự động backup workflows & credentials mỗi ngày"
    echo -e "  📱 Gửi file backup qua Telegram Bot (nếu <20MB)"
    echo -e "  📊 Thông báo realtime về trạng thái backup"
    echo -e "  🗂️ Giữ 30 bản backup gần nhất tự động"
    echo ""
    
    read -p "📱 Bạn có muốn thiết lập Telegram Backup? (Y/n): " telegram_choice
    
    if [[ ! $telegram_choice =~ ^[Nn]$ ]]; then
        TELEGRAM_BACKUP_ENABLED="true"
        
        echo ""
        echo -e "${CYAN}🤖 Thiết lập Telegram Bot:${NC}"
        echo -e "  1. Tạo bot mới: https://t.me/BotFather"
        echo -e "  2. Gửi /newbot và làm theo hướng dẫn"
        echo -e "  3. Lấy Bot Token từ BotFather"
        echo ""
        
        read -p "🔑 Nhập Telegram Bot Token: " TELEGRAM_BOT_TOKEN
        
        echo ""
        echo -e "${CYAN}💬 Lấy Chat ID:${NC}"
        echo -e "  1. Gửi tin nhắn cho bot vừa tạo"
        echo -e "  2. Truy cập: https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getUpdates"
        echo -e "  3. Tìm 'chat':{'id': YOUR_CHAT_ID}"
        echo ""
        
        read -p "🆔 Nhập Chat ID: " TELEGRAM_CHAT_ID
        
        log_success "Đã thiết lập Telegram Backup"
    fi
}

# Cấu hình Google Drive Backup
configure_gdrive_backup() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                        ☁️  GOOGLE DRIVE BACKUP                             ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo "Google Drive Backup cho phép:"
    echo -e "  ☁️  Tự động upload backup lên Google Drive"
    echo -e "  🔐 Sử dụng Service Account để xác thực"
    echo -e "  📁 Tự động tạo thư mục theo ngày/tháng"
    echo -e "  🗂️ Cleanup backup cũ tự động (giữ 30 bản)"
    echo ""
    
    read -p "☁️  Bạn có muốn thiết lập Google Drive Backup? (Y/n): " gdrive_choice
    
    if [[ ! $gdrive_choice =~ ^[Nn]$ ]]; then
        GDRIVE_BACKUP_ENABLED="true"
        
        echo ""
        echo -e "${CYAN}🔧 Hướng dẫn tạo Service Account:${NC}"
        echo -e "  1. Truy cập: https://console.cloud.google.com/"
        echo -e "  2. Tạo project mới hoặc chọn project có sẵn"
        echo -e "  3. Bật Google Drive API"
        echo -e "  4. Tạo Service Account:"
        echo -e "     - IAM & Admin → Service Accounts → Create"
        echo -e "     - Tạo key JSON và download"
        echo -e "  5. Chia sẻ thư mục Drive với email Service Account"
        echo ""
        
        echo -e "${YELLOW}📋 Paste nội dung file JSON Service Account:${NC}"
        echo -e "${YELLOW}(Nhấn Ctrl+D khi hoàn thành)${NC}"
        echo ""
        
        GDRIVE_SERVICE_ACCOUNT=$(cat)
        
        if [[ -z "$GDRIVE_SERVICE_ACCOUNT" ]]; then
            log_warning "Không có Service Account, bỏ qua Google Drive Backup"
            GDRIVE_BACKUP_ENABLED="false"
        else
            log_success "Đã thiết lập Google Drive Backup"
        fi
    fi
}

# Cấu hình Auto Update
configure_auto_update() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                        🔄 AUTO-UPDATE                                      ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo "Auto-Update sẽ:"
    echo -e "  🔄 Tự động cập nhật N8N mỗi 12 giờ"
    echo -e "  📦 Cập nhật yt-dlp, FFmpeg và các dependencies"
    echo -e "  📋 Ghi log chi tiết quá trình update"
    echo -e "  🔒 Backup trước khi update"
    echo ""
    
    read -p "🔄 Bạn có muốn bật Auto-Update? (Y/n): " update_choice
    
    if [[ ! $update_choice =~ ^[Nn]$ ]]; then
        AUTO_UPDATE_ENABLED="true"
        log_success "Đã bật Auto-Update"
    fi
}

# Tạo Dockerfile cho N8N
create_n8n_dockerfile() {
    log_info "🐳 Tạo Dockerfile cho N8N..."
    
    cat > $N8N_DIR/Dockerfile << 'EOF'
FROM n8nio/n8n:latest

USER root

# Cài đặt dependencies
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

# Cài đặt yt-dlp
RUN pip3 install --no-cache-dir yt-dlp

# Cài đặt Puppeteer dependencies
RUN npm install -g puppeteer

# Thiết lập Chrome path cho Puppeteer
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Tạo thư mục cho custom nodes
RUN mkdir -p /home/node/.n8n/custom

USER node

# Cài đặt custom nodes phổ biến
RUN cd /home/node/.n8n && npm install \
    n8n-nodes-puppeteer \
    n8n-nodes-youtube \
    n8n-nodes-rss-feed-trigger

WORKDIR /home/node
EOF
    
    log_success "Đã tạo Dockerfile cho N8N"
}

# Tạo News Content API
create_news_api() {
    if [[ "$NEWS_API_ENABLED" != "true" ]]; then
        return
    fi
    
    log_info "📰 Tạo News Content API..."
    
    # Tạo requirements.txt
    cat > $N8N_DIR/news-api/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
newspaper4k==0.9.2
feedparser==6.0.10
requests==2.31.0
beautifulsoup4==4.12.2
python-multipart==0.0.6
pydantic==2.5.0
lxml==4.9.3
Pillow==10.1.0
python-dateutil==2.8.2
EOF
    
    # Tạo main.py
    cat > $N8N_DIR/news-api/main.py << EOF
from fastapi import FastAPI, HTTPException, Depends, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
import newspaper
import feedparser
import requests
from bs4 import BeautifulSoup
from pydantic import BaseModel
from typing import List, Optional
import logging
from datetime import datetime
import re

# Cấu hình logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="News Content API",
    description="API để cào nội dung tin tức và parse RSS feeds",
    version="2.0.0"
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
BEARER_TOKEN = "$BEARER_TOKEN"

def verify_token(credentials: HTTPAuthorizationCredentials = Security(security)):
    if credentials.credentials != BEARER_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid token")
    return credentials.credentials

# Models
class ArticleRequest(BaseModel):
    url: str
    language: str = "vi"

class RSSRequest(BaseModel):
    url: str
    limit: int = 10

class ArticleResponse(BaseModel):
    title: str
    content: str
    summary: str
    authors: List[str]
    publish_date: Optional[str]
    top_image: Optional[str]
    url: str
    keywords: List[str]

class RSSResponse(BaseModel):
    title: str
    description: str
    entries: List[dict]

@app.get("/")
async def root():
    return {
        "message": "News Content API v2.0.0",
        "endpoints": {
            "article": "/article - Cào nội dung bài viết",
            "rss": "/rss - Parse RSS feed",
            "search": "/search - Tìm kiếm tin tức"
        }
    }

@app.post("/article", response_model=ArticleResponse)
async def get_article(request: ArticleRequest, token: str = Depends(verify_token)):
    try:
        # Tạo Article object
        article = newspaper.Article(request.url, language=request.language)
        
        # Download và parse
        article.download()
        article.parse()
        article.nlp()
        
        # Format publish date
        publish_date = None
        if article.publish_date:
            publish_date = article.publish_date.isoformat()
        
        return ArticleResponse(
            title=article.title or "",
            content=article.text or "",
            summary=article.summary or "",
            authors=article.authors or [],
            publish_date=publish_date,
            top_image=article.top_image or "",
            url=request.url,
            keywords=article.keywords or []
        )
        
    except Exception as e:
        logger.error(f"Error processing article {request.url}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Không thể xử lý bài viết: {str(e)}")

@app.post("/rss", response_model=RSSResponse)
async def parse_rss(request: RSSRequest, token: str = Depends(verify_token)):
    try:
        # Parse RSS feed
        feed = feedparser.parse(request.url)
        
        if feed.bozo:
            raise HTTPException(status_code=400, detail="RSS feed không hợp lệ")
        
        # Lấy entries theo limit
        entries = []
        for entry in feed.entries[:request.limit]:
            entry_data = {
                "title": getattr(entry, 'title', ''),
                "link": getattr(entry, 'link', ''),
                "description": getattr(entry, 'description', ''),
                "published": getattr(entry, 'published', ''),
                "author": getattr(entry, 'author', ''),
                "tags": [tag.term for tag in getattr(entry, 'tags', [])]
            }
            entries.append(entry_data)
        
        return RSSResponse(
            title=getattr(feed.feed, 'title', ''),
            description=getattr(feed.feed, 'description', ''),
            entries=entries
        )
        
    except Exception as e:
        logger.error(f"Error parsing RSS {request.url}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Không thể parse RSS: {str(e)}")

@app.get("/search")
async def search_news(q: str, source: str = "google", limit: int = 10, token: str = Depends(verify_token)):
    try:
        results = []
        
        if source == "google":
            # Google News search
            search_url = f"https://news.google.com/rss/search?q={q}&hl=vi&gl=VN&ceid=VN:vi"
            feed = feedparser.parse(search_url)
            
            for entry in feed.entries[:limit]:
                results.append({
                    "title": getattr(entry, 'title', ''),
                    "link": getattr(entry, 'link', ''),
                    "published": getattr(entry, 'published', ''),
                    "source": getattr(entry, 'source', {}).get('title', ''),
                    "description": getattr(entry, 'summary', '')
                })
        
        return {"query": q, "results": results}
        
    except Exception as e:
        logger.error(f"Error searching news: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Lỗi tìm kiếm: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
EOF
    
    # Tạo Dockerfile cho News API
    cat > $N8N_DIR/news-api/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Cài đặt system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    libxml2-dev \
    libxslt-dev \
    libjpeg-dev \
    libpng-dev \
    libwebp-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements và cài đặt Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY . .

# Expose port
EXPOSE 8001

# Run application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001", "--reload"]
EOF
    
    log_success "Đã tạo News Content API"
}

# Tạo docker-compose.yml
create_docker_compose() {
    log_info "🐳 Tạo docker-compose.yml..."
    
    if [[ "$USE_DOMAIN" == "true" ]]; then
        # Với domain và SSL
        cat > $N8N_DIR/docker-compose.yml << EOF
version: '3.8'

services:
  n8n:
    build: .
    container_name: n8n-container
    restart: unless-stopped
    environment:
      - N8N_HOST=$DOMAIN
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://$DOMAIN/
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
      - N8N_METRICS=true
      - N8N_LOG_LEVEL=info
      - N8N_PERSONALIZATION_ENABLED=false
      - N8N_VERSION_NOTIFICATIONS_ENABLED=false
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_DEFAULT_BINARY_DATA_MODE=filesystem
      - N8N_BINARY_DATA_TTL=24
      - N8N_BINARY_DATA_STORAGE_PATH=/home/node/.n8n/binaryData
    volumes:
      - ./data:/home/node/.n8n
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - n8n_network
    depends_on:
      - caddy

EOF

        # Thêm News API nếu được bật
        if [[ "$NEWS_API_ENABLED" == "true" ]]; then
            cat >> $N8N_DIR/docker-compose.yml << EOF
  news-api:
    build: ./news-api
    container_name: news-api-container
    restart: unless-stopped
    environment:
      - TZ=Asia/Ho_Chi_Minh
    networks:
      - n8n_network

EOF
        fi

        # Thêm Caddy
        cat >> $N8N_DIR/docker-compose.yml << EOF
  caddy:
    image: caddy:2-alpine
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

volumes:
  caddy_data:
  caddy_config:

networks:
  n8n_network:
    driver: bridge
EOF
    else
        # Localhost mode
        cat > $N8N_DIR/docker-compose.yml << EOF
version: '3.8'

services:
  n8n:
    build: .
    container_name: n8n-container
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=localhost
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=http://localhost:5678/
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
      - N8N_METRICS=true
      - N8N_LOG_LEVEL=info
      - N8N_PERSONALIZATION_ENABLED=false
      - N8N_VERSION_NOTIFICATIONS_ENABLED=false
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_DEFAULT_BINARY_DATA_MODE=filesystem
      - N8N_BINARY_DATA_TTL=24
      - N8N_BINARY_DATA_STORAGE_PATH=/home/node/.n8n/binaryData
    volumes:
      - ./data:/home/node/.n8n
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - n8n_network

EOF

        # Thêm News API nếu được bật
        if [[ "$NEWS_API_ENABLED" == "true" ]]; then
            cat >> $N8N_DIR/docker-compose.yml << EOF
  news-api:
    build: ./news-api
    container_name: news-api-container
    restart: unless-stopped
    ports:
      - "8001:8001"
    environment:
      - TZ=Asia/Ho_Chi_Minh
    networks:
      - n8n_network

EOF
        fi

        cat >> $N8N_DIR/docker-compose.yml << EOF
networks:
  n8n_network:
    driver: bridge
EOF
    fi
    
    log_success "Đã tạo docker-compose.yml"
}

# Tạo Caddyfile
create_caddyfile() {
    if [[ "$USE_DOMAIN" != "true" ]]; then
        return
    fi
    
    log_info "🌐 Tạo Caddyfile..."
    
    cat > $N8N_DIR/Caddyfile << EOF
# N8N Main Domain
$DOMAIN {
    reverse_proxy n8n:5678
    
    # Security headers
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
    
    # Gzip compression
    encode gzip
    
    # Logging
    log {
        output file /var/log/caddy/n8n.log
        format json
    }
}

EOF

    # Thêm API domain nếu News API được bật
    if [[ "$NEWS_API_ENABLED" == "true" ]]; then
        cat >> $N8N_DIR/Caddyfile << EOF
# News API Domain
$API_DOMAIN {
    reverse_proxy news-api:8001
    
    # Security headers
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        Access-Control-Allow-Origin "*"
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        Access-Control-Allow-Headers "Content-Type, Authorization"
    }
    
    # Gzip compression
    encode gzip
    
    # Logging
    log {
        output file /var/log/caddy/api.log
        format json
    }
}
EOF
    fi
    
    log_success "Đã tạo Caddyfile"
}

# Tạo backup system
create_backup_system() {
    log_info "💾 Tạo hệ thống backup..."
    
    # Tạo script backup chính
    cat > $N8N_DIR/scripts/backup.sh << 'EOF'
#!/bin/bash

# N8N Backup Script với Google Drive support
# Tác giả: Nguyễn Ngọc Thiện

set -e

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Biến
N8N_DIR="/home/n8n"
BACKUP_DIR="$N8N_DIR/backups"
LOCAL_BACKUP_DIR="$BACKUP_DIR/local"
GDRIVE_BACKUP_DIR="$BACKUP_DIR/gdrive"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="n8n_backup_$TIMESTAMP"

# Logging
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_info() {
    log "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

# Tạo backup local
create_local_backup() {
    log_info "🔄 Tạo backup local..."
    
    mkdir -p $LOCAL_BACKUP_DIR
    
    # Tạo thư mục backup tạm
    TEMP_BACKUP_DIR="/tmp/$BACKUP_NAME"
    mkdir -p $TEMP_BACKUP_DIR
    
    # Backup N8N data
    if [[ -d "$N8N_DIR/data" ]]; then
        cp -r $N8N_DIR/data $TEMP_BACKUP_DIR/
        log_info "✅ Đã backup N8N data"
    fi
    
    # Backup docker-compose và configs
    cp $N8N_DIR/docker-compose.yml $TEMP_BACKUP_DIR/ 2>/dev/null || true
    cp $N8N_DIR/Dockerfile $TEMP_BACKUP_DIR/ 2>/dev/null || true
    cp $N8N_DIR/Caddyfile $TEMP_BACKUP_DIR/ 2>/dev/null || true
    
    # Backup scripts
    if [[ -d "$N8N_DIR/scripts" ]]; then
        cp -r $N8N_DIR/scripts $TEMP_BACKUP_DIR/
    fi
    
    # Backup news-api nếu có
    if [[ -d "$N8N_DIR/news-api" ]]; then
        cp -r $N8N_DIR/news-api $TEMP_BACKUP_DIR/
    fi
    
    # Tạo file zip
    cd /tmp
    zip -r "$LOCAL_BACKUP_DIR/$BACKUP_NAME.zip" $BACKUP_NAME/
    
    # Cleanup temp
    rm -rf $TEMP_BACKUP_DIR
    
    log_success "✅ Đã tạo backup: $LOCAL_BACKUP_DIR/$BACKUP_NAME.zip"
    
    # Cleanup old backups (giữ 30 bản)
    cd $LOCAL_BACKUP_DIR
    ls -t *.zip 2>/dev/null | tail -n +31 | xargs rm -f 2>/dev/null || true
    
    echo "$LOCAL_BACKUP_DIR/$BACKUP_NAME.zip"
}

# Upload to Google Drive
upload_to_gdrive() {
    local backup_file="$1"
    
    if [[ ! -f "$N8N_DIR/gdrive_service_account.json" ]]; then
        log_info "⏭️ Bỏ qua Google Drive backup (không có service account)"
        return
    fi
    
    log_info "☁️ Upload backup lên Google Drive..."
    
    # Cài đặt Google Drive API client nếu chưa có
    if ! command -v python3 &> /dev/null; then
        log_error "Python3 không được cài đặt"
        return
    fi
    
    # Tạo script upload
    cat > /tmp/gdrive_upload.py << 'PYTHON_EOF'
import json
import os
import sys
from datetime import datetime
import requests
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

def get_access_token(service_account_file):
    """Lấy access token từ service account"""
    credentials = service_account.Credentials.from_service_account_file(
        service_account_file,
        scopes=['https://www.googleapis.com/auth/drive']
    )
    credentials.refresh(requests.Request())
    return credentials.token

def upload_file(service_account_file, file_path, folder_name="N8N_Backups"):
    """Upload file lên Google Drive"""
    try:
        # Khởi tạo service
        credentials = service_account.Credentials.from_service_account_file(
            service_account_file,
            scopes=['https://www.googleapis.com/auth/drive']
        )
        service = build('drive', 'v3', credentials=credentials)
        
        # Tìm hoặc tạo thư mục backup
        folder_id = None
        results = service.files().list(
            q=f"name='{folder_name}' and mimeType='application/vnd.google-apps.folder'",
            fields="files(id, name)"
        ).execute()
        
        if results['files']:
            folder_id = results['files'][0]['id']
        else:
            # Tạo thư mục mới
            folder_metadata = {
                'name': folder_name,
                'mimeType': 'application/vnd.google-apps.folder'
            }
            folder = service.files().create(body=folder_metadata, fields='id').execute()
            folder_id = folder.get('id')
        
        # Upload file
        file_name = os.path.basename(file_path)
        file_metadata = {
            'name': file_name,
            'parents': [folder_id]
        }
        
        media = MediaFileUpload(file_path, resumable=True)
        file = service.files().create(
            body=file_metadata,
            media_body=media,
            fields='id'
        ).execute()
        
        print(f"SUCCESS: File uploaded with ID: {file.get('id')}")
        return True
        
    except Exception as e:
        print(f"ERROR: {str(e)}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 gdrive_upload.py <service_account_file> <backup_file>")
        sys.exit(1)
    
    service_account_file = sys.argv[1]
    backup_file = sys.argv[2]
    
    if upload_file(service_account_file, backup_file):
        sys.exit(0)
    else:
        sys.exit(1)
PYTHON_EOF
    
    # Cài đặt Google API client
    pip3 install --quiet google-api-python-client google-auth google-auth-oauthlib google-auth-httplib2 2>/dev/null || {
        log_error "Không thể cài đặt Google API client"
        return
    }
    
    # Upload file
    if python3 /tmp/gdrive_upload.py "$N8N_DIR/gdrive_service_account.json" "$backup_file"; then
        log_success "✅ Đã upload backup lên Google Drive"
    else
        log_error "❌ Lỗi upload lên Google Drive"
    fi
    
    # Cleanup
    rm -f /tmp/gdrive_upload.py
}

# Gửi thông báo Telegram
send_telegram_notification() {
    local message="$1"
    local backup_file="$2"
    
    if [[ ! -f "$N8N_DIR/telegram_config.json" ]]; then
        return
    fi
    
    # Đọc config
    local bot_token=$(jq -r '.bot_token' $N8N_DIR/telegram_config.json)
    local chat_id=$(jq -r '.chat_id' $N8N_DIR/telegram_config.json)
    
    if [[ "$bot_token" == "null" || "$chat_id" == "null" ]]; then
        return
    fi
    
    # Gửi tin nhắn
    curl -s -X POST "https://api.telegram.org/bot$bot_token/sendMessage" \
        -d "chat_id=$chat_id" \
        -d "text=$message" \
        -d "parse_mode=HTML" > /dev/null
    
    # Gửi file nếu < 20MB
    if [[ -f "$backup_file" ]]; then
        local file_size=$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file" 2>/dev/null || echo "0")
        if [[ $file_size -lt 20971520 ]]; then  # 20MB
            curl -s -X POST "https://api.telegram.org/bot$bot_token/sendDocument" \
                -F "chat_id=$chat_id" \
                -F "document=@$backup_file" \
                -F "caption=📦 N8N Backup - $(date)" > /dev/null
        fi
    fi
}

# Main backup function
main() {
    log_info "🚀 Bắt đầu backup N8N..."
    
    # Tạo backup local
    backup_file=$(create_local_backup)
    
    # Upload to Google Drive
    upload_to_gdrive "$backup_file"
    
    # Gửi thông báo
    local message="✅ <b>N8N Backup Completed</b>
📅 Time: $(date)
📦 File: $(basename $backup_file)
💾 Size: $(du -h $backup_file | cut -f1)
🖥️ Server: $(hostname)"
    
    send_telegram_notification "$message" "$backup_file"
    
    log_success "🎉 Backup hoàn thành!"
}

# Chạy backup
main "$@"
EOF
    
    chmod +x $N8N_DIR/scripts/backup.sh
    
    # Tạo script restore
    cat > $N8N_DIR/scripts/restore.sh << 'EOF'
#!/bin/bash

# N8N Restore Script
# Tác giả: Nguyễn Ngọc Thiện

set -e

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Biến
N8N_DIR="/home/n8n"
BACKUP_DIR="$N8N_DIR/backups"
LOCAL_BACKUP_DIR="$BACKUP_DIR/local"

# Logging
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_info() {
    log "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

log_warning() {
    log "${YELLOW}[WARNING]${NC} $1"
}

# Menu restore
show_restore_menu() {
    echo -e "${CYAN}"
    cat << 'MENU_EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                           🔄 N8N RESTORE MENU                               ║
╚══════════════════════════════════════════════════════════════════════════════╝
MENU_EOF
    echo -e "${NC}"
    
    echo -e "${YELLOW}Chọn nguồn restore:${NC}"
    echo -e "  ${GREEN}1${NC} - Restore từ backup local"
    echo -e "  ${GREEN}2${NC} - Restore từ file zip"
    echo -e "  ${GREEN}3${NC} - Restore từ Google Drive"
    echo -e "  ${GREEN}0${NC} - Thoát"
    echo ""
    
    read -p "Lựa chọn (0-3): " choice
    
    case $choice in
        1) restore_from_local ;;
        2) restore_from_file ;;
        3) restore_from_gdrive ;;
        0) exit 0 ;;
        *) 
            log_error "Lựa chọn không hợp lệ!"
            show_restore_menu
            ;;
    esac
}

# Restore từ backup local
restore_from_local() {
    log_info "📋 Danh sách backup local:"
    
    if [[ ! -d "$LOCAL_BACKUP_DIR" ]] || [[ -z "$(ls -A $LOCAL_BACKUP_DIR 2>/dev/null)" ]]; then
        log_error "Không tìm thấy backup local nào!"
        return
    fi
    
    # Liệt kê backup
    local backups=($(ls -t $LOCAL_BACKUP_DIR/*.zip 2>/dev/null))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        log_error "Không tìm thấy file backup!"
        return
    fi
    
    echo ""
    for i in "${!backups[@]}"; do
        local backup_file="${backups[$i]}"
        local backup_name=$(basename "$backup_file" .zip)
        local backup_date=$(echo "$backup_name" | grep -o '[0-9]\{8\}_[0-9]\{6\}' | sed 's/_/ /')
        local file_size=$(du -h "$backup_file" | cut -f1)
        
        echo -e "  ${GREEN}$((i+1))${NC} - $backup_date (${file_size})"
    done
    
    echo ""
    read -p "Chọn backup để restore (1-${#backups[@]}): " backup_choice
    
    if [[ $backup_choice -ge 1 && $backup_choice -le ${#backups[@]} ]]; then
        local selected_backup="${backups[$((backup_choice-1))]}"
        perform_restore "$selected_backup"
    else
        log_error "Lựa chọn không hợp lệ!"
    fi
}

# Restore từ file zip
restore_from_file() {
    echo ""
    read -p "📁 Nhập đường dẫn đến file backup (.zip): " backup_file
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "File không tồn tại: $backup_file"
        return
    fi
    
    if [[ "${backup_file##*.}" != "zip" ]]; then
        log_error "File phải có định dạng .zip"
        return
    fi
    
    perform_restore "$backup_file"
}

# Restore từ Google Drive
restore_from_gdrive() {
    log_info "☁️ Restore từ Google Drive..."
    
    if [[ ! -f "$N8N_DIR/gdrive_service_account.json" ]]; then
        log_error "Không tìm thấy Google Drive service account!"
        return
    fi
    
    # Tạo script list files
    cat > /tmp/gdrive_list.py << 'PYTHON_EOF'
import json
import sys
from google.oauth2 import service_account
from googleapiclient.discovery import build

def list_backup_files(service_account_file, folder_name="N8N_Backups"):
    """List backup files từ Google Drive"""
    try:
        credentials = service_account.Credentials.from_service_account_file(
            service_account_file,
            scopes=['https://www.googleapis.com/auth/drive']
        )
        service = build('drive', 'v3', credentials=credentials)
        
        # Tìm thư mục backup
        results = service.files().list(
            q=f"name='{folder_name}' and mimeType='application/vnd.google-apps.folder'",
            fields="files(id, name)"
        ).execute()
        
        if not results['files']:
            print("ERROR: Không tìm thấy thư mục backup")
            return
        
        folder_id = results['files'][0]['id']
        
        # List files trong thư mục
        results = service.files().list(
            q=f"parents in '{folder_id}' and name contains '.zip'",
            orderBy="createdTime desc",
            fields="files(id, name, size, createdTime)"
        ).execute()
        
        files = results.get('files', [])
        
        if not files:
            print("ERROR: Không tìm thấy file backup")
            return
        
        for i, file in enumerate(files):
            size_mb = round(int(file['size']) / 1024 / 1024, 2)
            print(f"{i+1}|{file['id']}|{file['name']}|{size_mb}MB|{file['createdTime']}")
            
    except Exception as e:
        print(f"ERROR: {str(e)}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 gdrive_list.py <service_account_file>")
        sys.exit(1)
    
    list_backup_files(sys.argv[1])
PYTHON_EOF
    
    # List files
    local gdrive_files=$(python3 /tmp/gdrive_list.py "$N8N_DIR/gdrive_service_account.json" 2>/dev/null)
    
    if [[ -z "$gdrive_files" ]] || [[ "$gdrive_files" == ERROR* ]]; then
        log_error "Không thể lấy danh sách backup từ Google Drive"
        rm -f /tmp/gdrive_list.py
        return
    fi
    
    echo ""
    echo -e "${YELLOW}📋 Danh sách backup trên Google Drive:${NC}"
    echo ""
    
    local file_ids=()
    local file_names=()
    
    while IFS='|' read -r num file_id file_name file_size created_time; do
        echo -e "  ${GREEN}$num${NC} - $file_name ($file_size)"
        file_ids+=("$file_id")
        file_names+=("$file_name")
    done <<< "$gdrive_files"
    
    echo ""
    read -p "Chọn backup để restore (1-${#file_ids[@]}): " gdrive_choice
    
    if [[ $gdrive_choice -ge 1 && $gdrive_choice -le ${#file_ids[@]} ]]; then
        local selected_id="${file_ids[$((gdrive_choice-1))]}"
        local selected_name="${file_names[$((gdrive_choice-1))]}"
        
        # Download file
        log_info "📥 Downloading $selected_name..."
        
        cat > /tmp/gdrive_download.py << 'PYTHON_EOF'
import sys
from google.oauth2 import service_account
from googleapiclient.discovery import build
import io
from googleapiclient.http import MediaIoBaseDownload

def download_file(service_account_file, file_id, output_path):
    """Download file từ Google Drive"""
    try:
        credentials = service_account.Credentials.from_service_account_file(
            service_account_file,
            scopes=['https://www.googleapis.com/auth/drive']
        )
        service = build('drive', 'v3', credentials=credentials)
        
        request = service.files().get_media(fileId=file_id)
        fh = io.BytesIO()
        downloader = MediaIoBaseDownload(fh, request)
        
        done = False
        while done is False:
            status, done = downloader.next_chunk()
        
        with open(output_path, 'wb') as f:
            f.write(fh.getvalue())
        
        print("SUCCESS")
        
    except Exception as e:
        print(f"ERROR: {str(e)}")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python3 gdrive_download.py <service_account_file> <file_id> <output_path>")
        sys.exit(1)
    
    download_file(sys.argv[1], sys.argv[2], sys.argv[3])
PYTHON_EOF
        
        local temp_file="/tmp/$selected_name"
        local download_result=$(python3 /tmp/gdrive_download.py "$N8N_DIR/gdrive_service_account.json" "$selected_id" "$temp_file")
        
        if [[ "$download_result" == "SUCCESS" ]]; then
            log_success "✅ Đã download backup từ Google Drive"
            perform_restore "$temp_file"
            rm -f "$temp_file"
        else
            log_error "❌ Lỗi download backup từ Google Drive"
        fi
    else
        log_error "Lựa chọn không hợp lệ!"
    fi
    
    # Cleanup
    rm -f /tmp/gdrive_list.py /tmp/gdrive_download.py
}

# Thực hiện restore
perform_restore() {
    local backup_file="$1"
    
    log_warning "⚠️ CẢNH BÁO: Restore sẽ ghi đè toàn bộ dữ liệu N8N hiện tại!"
    echo ""
    read -p "Bạn có chắc chắn muốn tiếp tục? (y/N): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "Đã hủy restore"
        return
    fi
    
    log_info "🔄 Bắt đầu restore từ: $(basename $backup_file)"
    
    # Dừng N8N containers
    log_info "🛑 Dừng N8N containers..."
    cd $N8N_DIR
    docker-compose down 2>/dev/null || true
    
    # Backup dữ liệu hiện tại
    log_info "💾 Backup dữ liệu hiện tại..."
    local current_backup="$N8N_DIR/backups/pre_restore_$(date +%Y%m%d_%H%M%S).zip"
    mkdir -p $(dirname $current_backup)
    
    if [[ -d "$N8N_DIR/data" ]]; then
        cd $N8N_DIR
        zip -r "$current_backup" data/ 2>/dev/null || true
        log_info "✅ Đã backup dữ liệu hiện tại: $current_backup"
    fi
    
    # Extract backup
    log_info "📦 Giải nén backup..."
    local temp_extract="/tmp/n8n_restore_$(date +%s)"
    mkdir -p $temp_extract
    
    cd $temp_extract
    unzip -q "$backup_file"
    
    # Tìm thư mục chứa data
    local backup_data_dir=""
    if [[ -d "data" ]]; then
        backup_data_dir="data"
    else
        # Tìm trong subdirectories
        backup_data_dir=$(find . -name "data" -type d | head -n1)
    fi
    
    if [[ -z "$backup_data_dir" ]]; then
        log_error "Không tìm thấy thư mục data trong backup!"
        rm -rf $temp_extract
        return
    fi
    
    # Restore data
    log_info "🔄 Restore dữ liệu N8N..."
    rm -rf $N8N_DIR/data
    cp -r "$backup_data_dir" $N8N_DIR/
    
    # Restore configs nếu có
    for config_file in docker-compose.yml Dockerfile Caddyfile; do
        if [[ -f "$config_file" ]]; then
            cp "$config_file" $N8N_DIR/
            log_info "✅ Restored $config_file"
        fi
    done
    
    # Restore scripts nếu có
    if [[ -d "scripts" ]]; then
        cp -r scripts/* $N8N_DIR/scripts/ 2>/dev/null || true
        chmod +x $N8N_DIR/scripts/*.sh 2>/dev/null || true
        log_info "✅ Restored scripts"
    fi
    
    # Restore news-api nếu có
    if [[ -d "news-api" ]]; then
        rm -rf $N8N_DIR/news-api
        cp -r news-api $N8N_DIR/
        log_info "✅ Restored news-api"
    fi
    
    # Set permissions
    chown -R 1000:1000 $N8N_DIR/data 2>/dev/null || true
    
    # Cleanup
    rm -rf $temp_extract
    
    # Khởi động lại containers
    log_info "🚀 Khởi động lại N8N..."
    cd $N8N_DIR
    docker-compose up -d
    
    log_success "🎉 Restore hoàn thành!"
    log_info "📋 Backup dữ liệu cũ: $current_backup"
    
    if [[ "$USE_DOMAIN" == "true" ]]; then
        log_info "🌐 N8N URL: https://$DOMAIN"
    else
        log_info "🌐 N8N URL: http://localhost:5678"
    fi
}

# Main
if [[ $# -eq 0 ]]; then
    show_restore_menu
else
    perform_restore "$1"
fi
EOF
    
    chmod +x $N8N_DIR/scripts/restore.sh
    
    # Tạo config files cho Telegram và Google Drive
    if [[ "$TELEGRAM_BACKUP_ENABLED" == "true" ]]; then
        cat > $N8N_DIR/telegram_config.json << EOF
{
    "bot_token": "$TELEGRAM_BOT_TOKEN",
    "chat_id": "$TELEGRAM_CHAT_ID"
}
EOF
    fi
    
    if [[ "$GDRIVE_BACKUP_ENABLED" == "true" && -n "$GDRIVE_SERVICE_ACCOUNT" ]]; then
        echo "$GDRIVE_SERVICE_ACCOUNT" > $N8N_DIR/gdrive_service_account.json
    fi
    
    log_success "Đã tạo hệ thống backup"
}

# Tạo SSL renewal script
create_ssl_renewal_script() {
    if [[ "$USE_DOMAIN" != "true" ]]; then
        return
    fi
    
    log_info "🔒 Tạo SSL renewal script..."
    
    cat > $N8N_DIR/scripts/ssl_renewal.sh << 'EOF'
#!/bin/bash

# SSL Certificate Renewal Script với ZeroSSL fallback
# Tác giả: Nguyễn Ngọc Thiện

set -e

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Biến
N8N_DIR="/home/n8n"
LOG_FILE="$N8N_DIR/logs/ssl_renewal.log"

# Logging
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "$message"
    echo "$message" >> $LOG_FILE
}

log_info() {
    log "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

# Kiểm tra SSL certificate
check_ssl_status() {
    local domain="$1"
    
    # Kiểm tra certificate expiry
    local cert_info=$(echo | openssl s_client -servername $domain -connect $domain:443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "")
    
    if [[ -z "$cert_info" ]]; then
        echo "NO_CERT"
        return
    fi
    
    local not_after=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
    local expiry_timestamp=$(date -d "$not_after" +%s 2>/dev/null || echo "0")
    local current_timestamp=$(date +%s)
    local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
    
    if [[ $days_until_expiry -lt 30 ]]; then
        echo "EXPIRING_SOON"
    elif [[ $days_until_expiry -lt 0 ]]; then
        echo "EXPIRED"
    else
        echo "VALID"
    fi
}

# Kiểm tra Caddy logs cho rate limit
check_rate_limit() {
    local caddy_logs=$(docker logs caddy-proxy 2>&1 | tail -50)
    
    if echo "$caddy_logs" | grep -q "rateLimited\|too many certificates"; then
        # Extract retry after time
        local retry_after=$(echo "$caddy_logs" | grep -o "retry after [0-9-]* [0-9:]* UTC" | tail -1 | sed 's/retry after //' | sed 's/ UTC//')
        
        if [[ -n "$retry_after" ]]; then
            local retry_timestamp=$(date -d "$retry_after UTC" +%s 2>/dev/null || echo "0")
            local current_timestamp=$(date +%s)
            
            if [[ $retry_timestamp -gt $current_timestamp ]]; then
                echo "RATE_LIMITED"
                return
            fi
        fi
    fi
    
    echo "OK"
}

# Chuyển sang ZeroSSL
switch_to_zerossl() {
    log_info "🔄 Chuyển sang ZeroSSL..."
    
    # Backup Caddyfile hiện tại
    cp $N8N_DIR/Caddyfile $N8N_DIR/Caddyfile.backup
    
    # Tạo Caddyfile với ZeroSSL
    cat > $N8N_DIR/Caddyfile << 'CADDY_EOF'
{
    acme_ca https://acme.zerossl.com/v2/DV90
}

# N8N Main Domain
DOMAIN_PLACEHOLDER {
    reverse_proxy n8n:5678
    
    # Security headers
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
    
    # Gzip compression
    encode gzip
    
    # Logging
    log {
        output file /var/log/caddy/n8n.log
        format json
    }
}

API_DOMAIN_PLACEHOLDER {
    reverse_proxy news-api:8001
    
    # Security headers
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        Access-Control-Allow-Origin "*"
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        Access-Control-Allow-Headers "Content-Type, Authorization"
    }
    
    # Gzip compression
    encode gzip
    
    # Logging
    log {
        output file /var/log/caddy/api.log
        format json
    }
}
CADDY_EOF
    
    # Replace placeholders (sẽ được thay thế bởi script chính)
    # sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" $N8N_DIR/Caddyfile
    # sed -i "s/API_DOMAIN_PLACEHOLDER/$API_DOMAIN/g" $N8N_DIR/Caddyfile
    
    # Restart Caddy
    cd $N8N_DIR
    docker-compose restart caddy
    
    log_success "✅ Đã chuyển sang ZeroSSL"
}

# Chuyển về Let's Encrypt
switch_to_letsencrypt() {
    log_info "🔄 Chuyển về Let's Encrypt..."
    
    if [[ -f "$N8N_DIR/Caddyfile.backup" ]]; then
        cp $N8N_DIR/Caddyfile.backup $N8N_DIR/Caddyfile
        cd $N8N_DIR
        docker-compose restart caddy
        log_success "✅ Đã chuyển về Let's Encrypt"
    fi
}

# Gửi thông báo Telegram
send_telegram_notification() {
    local message="$1"
    
    if [[ ! -f "$N8N_DIR/telegram_config.json" ]]; then
        return
    fi
    
    local bot_token=$(jq -r '.bot_token' $N8N_DIR/telegram_config.json 2>/dev/null || echo "")
    local chat_id=$(jq -r '.chat_id' $N8N_DIR/telegram_config.json 2>/dev/null || echo "")
    
    if [[ -n "$bot_token" && -n "$chat_id" && "$bot_token" != "null" && "$chat_id" != "null" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$bot_token/sendMessage" \
            -d "chat_id=$chat_id" \
            -d "text=$message" \
            -d "parse_mode=HTML" > /dev/null
    fi
}

# Main renewal function
main() {
    log_info "🔒 Kiểm tra SSL certificates..."
    
    # Đọc domain từ docker-compose.yml hoặc Caddyfile
    local domain=$(grep "N8N_HOST=" $N8N_DIR/docker-compose.yml | cut -d= -f2 | head -1)
    
    if [[ -z "$domain" || "$domain" == "localhost" ]]; then
        log_info "⏭️ Localhost mode, bỏ qua SSL check"
        exit 0
    fi
    
    # Kiểm tra trạng thái SSL
    local ssl_status=$(check_ssl_status "$domain")
    local rate_limit_status=$(check_rate_limit)
    
    log_info "SSL Status: $ssl_status"
    log_info "Rate Limit Status: $rate_limit_status"
    
    case "$ssl_status" in
        "NO_CERT"|"EXPIRED"|"EXPIRING_SOON")
            if [[ "$rate_limit_status" == "RATE_LIMITED" ]]; then
                log_info "🔄 Let's Encrypt rate limited, chuyển sang ZeroSSL"
                switch_to_zerossl
                
                # Thông báo
                local message="⚠️ <b>SSL Certificate Issue</b>
🌐 Domain: $domain
🔒 Status: $ssl_status
🚫 Let's Encrypt: Rate Limited
🔄 Action: Switched to ZeroSSL
📅 Time: $(date)"
                
                send_telegram_notification "$message"
            else
                log_info "🔄 Renewing SSL certificate..."
                cd $N8N_DIR
                docker-compose restart caddy
                
                # Đợi và kiểm tra lại
                sleep 30
                local new_status=$(check_ssl_status "$domain")
                
                if [[ "$new_status" == "VALID" ]]; then
                    log_success "✅ SSL certificate renewed successfully"
                    
                    local message="✅ <b>SSL Certificate Renewed</b>
🌐 Domain: $domain
🔒 Status: Valid
📅 Time: $(date)"
                    
                    send_telegram_notification "$message"
                else
                    log_error "❌ SSL renewal failed"
                    
                    local message="❌ <b>SSL Renewal Failed</b>
🌐 Domain: $domain
🔒 Status: $new_status
📅 Time: $(date)"
                    
                    send_telegram_notification "$message"
                fi
            fi
            ;;
        "VALID")
            log_success "✅ SSL certificate is valid"
            ;;
    esac
}

# Tạo log directory
mkdir -p $(dirname $LOG_FILE)

# Chạy main function
main "$@"
EOF
    
    chmod +x $N8N_DIR/scripts/ssl_renewal.sh
    
    log_success "Đã tạo SSL renewal script"
}

# Tạo auto-update script
create_auto_update_script() {
    if [[ "$AUTO_UPDATE_ENABLED" != "true" ]]; then
        return
    fi
    
    log_info "🔄 Tạo script auto-update..."
    
    cat > $N8N_DIR/scripts/auto_update.sh << 'EOF'
#!/bin/bash

# N8N Auto-Update Script
# Tác giả: Nguyễn Ngọc Thiện

set -e

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Biến
N8N_DIR="/home/n8n"
LOG_FILE="$N8N_DIR/logs/auto_update.log"

# Logging
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "$message"
    echo "$message" >> $LOG_FILE
}

log_info() {
    log "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

# Gửi thông báo Telegram
send_telegram_notification() {
    local message="$1"
    
    if [[ ! -f "$N8N_DIR/telegram_config.json" ]]; then
        return
    fi
    
    local bot_token=$(jq -r '.bot_token' $N8N_DIR/telegram_config.json 2>/dev/null || echo "")
    local chat_id=$(jq -r '.chat_id' $N8N_DIR/telegram_config.json 2>/dev/null || echo "")
    
    if [[ -n "$bot_token" && -n "$chat_id" && "$bot_token" != "null" && "$chat_id" != "null" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$bot_token/sendMessage" \
            -d "chat_id=$chat_id" \
            -d "text=$message" \
            -d "parse_mode=HTML" > /dev/null
    fi
}

# Backup trước khi update
create_pre_update_backup() {
    log_info "💾 Tạo backup trước khi update..."
    
    if [[ -f "$N8N_DIR/scripts/backup.sh" ]]; then
        $N8N_DIR/scripts/backup.sh
        log_success "✅ Đã tạo backup"
    else
        log_error "❌ Không tìm thấy script backup"
    fi
}

# Update Docker images
update_docker_images() {
    log_info "🐳 Cập nhật Docker images..."
    
    cd $N8N_DIR
    
    # Pull latest images
    docker-compose pull
    
    # Rebuild custom images
    docker-compose build --no-cache
    
    log_success "✅ Đã cập nhật Docker images"
}

# Update system packages
update_system_packages() {
    log_info "📦 Cập nhật system packages..."
    
    apt-get update -y
    apt-get upgrade -y
    apt-get autoremove -y
    apt-get autoclean
    
    log_success "✅ Đã cập nhật system packages"
}

# Restart services
restart_services() {
    log_info "🔄 Khởi động lại services..."
    
    cd $N8N_DIR
    docker-compose down
    docker-compose up -d
    
    # Đợi services khởi động
    sleep 30
    
    log_success "✅ Đã khởi động lại services"
}

# Kiểm tra health
check_health() {
    log_info "🏥 Kiểm tra health..."
    
    local n8n_health="❌"
    local api_health="❌"
    
    # Kiểm tra N8N
    if curl -s -f http://localhost:5678/healthz > /dev/null 2>&1; then
        n8n_health="✅"
    fi
    
    # Kiểm tra News API nếu có
    if docker ps | grep -q news-api-container; then
        if curl -s -f http://localhost:8001/ > /dev/null 2>&1; then
            api_health="✅"
        fi
    else
        api_health="⏭️"
    fi
    
    log_info "N8N Health: $n8n_health"
    log_info "API Health: $api_health"
    
    if [[ "$n8n_health" == "✅" ]]; then
        return 0
    else
        return 1
    fi
}

# Main update function
main() {
    log_info "🚀 Bắt đầu auto-update..."
    
    # Tạo log directory
    mkdir -p $(dirname $LOG_FILE)
    
    # Backup trước khi update
    create_pre_update_backup
    
    # Update system packages
    update_system_packages
    
    # Update Docker images
    update_docker_images
    
    # Restart services
    restart_services
    
    # Kiểm tra health
    if check_health; then
        log_success "🎉 Auto-update hoàn thành thành công!"
        
        local message="✅ <b>N8N Auto-Update Completed</b>
🔄 Status: Success
📅 Time: $(date)
🖥️ Server: $(hostname)
🐳 Docker images updated
📦 System packages updated"
        
        send_telegram_notification "$message"
    else
        log_error "❌ Auto-update thất bại!"
        
        local message="❌ <b>N8N Auto-Update Failed</b>
🔄 Status: Failed
📅 Time: $(date)
🖥️ Server: $(hostname)
⚠️ Services may be down"
        
        send_telegram_notification "$message"
        
        exit 1
    fi
}

# Chạy main function
main "$@"
EOF
    
    chmod +x $N8N_DIR/scripts/auto_update.sh
    
    log_success "Đã tạo script auto-update"
}

# Tạo script chẩn đoán
create_diagnostic_script() {
    log_info "🔧 Tạo script chẩn đoán..."
    
    cat > $N8N_DIR/scripts/diagnose.sh << 'EOF'
#!/bin/bash

# N8N Diagnostic Script
# Tác giả: Nguyễn Ngọc Thiện

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Header
echo -e "${CYAN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                        🔧 N8N DIAGNOSTIC TOOL                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# System Info
echo -e "${WHITE}📊 SYSTEM INFORMATION${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}OS:${NC} $(lsb_release -d | cut -f2)"
echo -e "${BLUE}Kernel:${NC} $(uname -r)"
echo -e "${BLUE}Uptime:${NC} $(uptime -p)"
echo -e "${BLUE}Load Average:${NC} $(uptime | awk -F'load average:' '{print $2}')"
echo -e "${BLUE}Memory:${NC} $(free -h | grep Mem | awk '{print $3"/"$2" ("$3/$2*100"%)"}')"
echo -e "${BLUE}Disk:${NC} $(df -h / | tail -1 | awk '{print $3"/"$2" ("$5")"}')"
echo ""

# Docker Info
echo -e "${WHITE}🐳 DOCKER INFORMATION${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✅ Docker installed${NC}"
    echo -e "${BLUE}Version:${NC} $(docker --version)"
    echo -e "${BLUE}Status:${NC} $(systemctl is-active docker)"
    
    if command -v docker-compose &> /dev/null; then
        echo -e "${GREEN}✅ Docker Compose installed${NC}"
        echo -e "${BLUE}Version:${NC} $(docker-compose --version)"
    else
        echo -e "${RED}❌ Docker Compose not installed${NC}"
    fi
else
    echo -e "${RED}❌ Docker not installed${NC}"
fi
echo ""

# N8N Containers
echo -e "${WHITE}📦 N8N CONTAINERS${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ -d "/home/n8n" ]]; then
    cd /home/n8n
    
    if [[ -f "docker-compose.yml" ]]; then
        echo -e "${GREEN}✅ Docker Compose file found${NC}"
        
        # Container status
        containers=$(docker-compose ps --services 2>/dev/null || echo "")
        if [[ -n "$containers" ]]; then
            while read -r container; do
                if [[ -n "$container" ]]; then
                    status=$(docker-compose ps $container 2>/dev/null | tail -n +3 | awk '{print $4}' || echo "Down")
                    if [[ "$status" == "Up" ]]; then
                        echo -e "${GREEN}✅ $container: Running${NC}"
                    else
                        echo -e "${RED}❌ $container: $status${NC}"
                    fi
                fi
            done <<< "$containers"
        else
            echo -e "${YELLOW}⚠️ No containers found${NC}"
        fi
    else
        echo -e "${RED}❌ Docker Compose file not found${NC}"
    fi
else
    echo -e "${RED}❌ N8N directory not found${NC}"
fi
echo ""

# Network Connectivity
echo -e "${WHITE}🌐 NETWORK CONNECTIVITY${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check internet
if ping -c 1 8.8.8.8 &> /dev/null; then
    echo -e "${GREEN}✅ Internet connectivity${NC}"
else
    echo -e "${RED}❌ No internet connectivity${NC}"
fi

# Check DNS
if nslookup google.com &> /dev/null; then
    echo -e "${GREEN}✅ DNS resolution${NC}"
else
    echo -e "${RED}❌ DNS resolution failed${NC}"
fi

# Check ports
ports=("80" "443" "5678" "8001")
for port in "${ports[@]}"; do
    if netstat -tuln | grep -q ":$port "; then
        echo -e "${GREEN}✅ Port $port is open${NC}"
    else
        echo -e "${YELLOW}⚠️ Port $port is not open${NC}"
    fi
done
echo ""

# SSL Certificate
echo -e "${WHITE}🔒 SSL CERTIFICATE${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Đọc domain từ docker-compose.yml
if [[ -f "/home/n8n/docker-compose.yml" ]]; then
    domain=$(grep "N8N_HOST=" /home/n8n/docker-compose.yml | cut -d= -f2 | head -1)
    
    if [[ -n "$domain" && "$domain" != "localhost" ]]; then
        echo -e "${BLUE}Domain:${NC} $domain"
        
        # Check SSL
        cert_info=$(echo | openssl s_client -servername $domain -connect $domain:443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "")
        
        if [[ -n "$cert_info" ]]; then
            not_after=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
            expiry_timestamp=$(date -d "$not_after" +%s 2>/dev/null || echo "0")
            current_timestamp=$(date +%s)
            days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
            
            if [[ $days_until_expiry -gt 30 ]]; then
                echo -e "${GREEN}✅ SSL Certificate valid (expires in $days_until_expiry days)${NC}"
            elif [[ $days_until_expiry -gt 0 ]]; then
                echo -e "${YELLOW}⚠️ SSL Certificate expires soon ($days_until_expiry days)${NC}"
            else
                echo -e "${RED}❌ SSL Certificate expired${NC}"
            fi
            
            echo -e "${BLUE}Expires:${NC} $not_after"
        else
            echo -e "${RED}❌ No SSL Certificate found${NC}"
        fi
    else
        echo -e "${BLUE}Mode:${NC} Localhost (no SSL needed)"
    fi
else
    echo -e "${RED}❌ Cannot determine domain${NC}"
fi
echo ""

# Service Health
echo -e "${WHITE}🏥 SERVICE HEALTH${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# N8N Health
if curl -s -f http://localhost:5678/healthz > /dev/null 2>&1; then
    echo -e "${GREEN}✅ N8N is healthy${NC}"
else
    echo -e "${RED}❌ N8N is not responding${NC}"
fi

# News API Health
if docker ps | grep -q news-api-container; then
    if curl -s -f http://localhost:8001/ > /dev/null 2>&1; then
        echo -e "${GREEN}✅ News API is healthy${NC}"
    else
        echo -e "${RED}❌ News API is not responding${NC}"
    fi
else
    echo -e "${BLUE}ℹ️ News API not installed${NC}"
fi

# Caddy Health
if docker ps | grep -q caddy-proxy; then
    if curl -s -f http://localhost:80 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Caddy is healthy${NC}"
    else
        echo -e "${RED}❌ Caddy is not responding${NC}"
    fi
else
    echo -e "${BLUE}ℹ️ Caddy not installed (localhost mode)${NC}"
fi
echo ""

# Disk Usage
echo -e "${WHITE}💾 DISK USAGE${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ -d "/home/n8n" ]]; then
    echo -e "${BLUE}N8N Directory:${NC} $(du -sh /home/n8n 2>/dev/null || echo "Unknown")"
    
    if [[ -d "/home/n8n/data" ]]; then
        echo -e "${BLUE}N8N Data:${NC} $(du -sh /home/n8n/data 2>/dev/null || echo "Unknown")"
    fi
    
    if [[ -d "/home/n8n/backups" ]]; then
        echo -e "${BLUE}Backups:${NC} $(du -sh /home/n8n/backups 2>/dev/null || echo "Unknown")"
        
        local_backups=$(ls /home/n8n/backups/local/*.zip 2>/dev/null | wc -l || echo "0")
        echo -e "${BLUE}Local Backups:${NC} $local_backups files"
    fi
fi

# Docker volumes
echo -e "${BLUE}Docker Volumes:${NC}"
docker volume ls | grep n8n || echo "No N8N volumes found"
echo ""

# Recent Logs
echo -e "${WHITE}📋 RECENT LOGS${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if docker ps | grep -q n8n-container; then
    echo -e "${BLUE}N8N Container Logs (last 5 lines):${NC}"
    docker logs n8n-container --tail 5 2>/dev/null || echo "Cannot access logs"
    echo ""
fi

if docker ps | grep -q caddy-proxy; then
    echo -e "${BLUE}Caddy Logs (last 5 lines):${NC}"
    docker logs caddy-proxy --tail 5 2>/dev/null || echo "Cannot access logs"
    echo ""
fi

# Cron Jobs
echo -e "${WHITE}⏰ CRON JOBS${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cron_jobs=$(crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" || echo "")
if [[ -n "$cron_jobs" ]]; then
    echo "$cron_jobs"
else
    echo "No cron jobs found"
fi
echo ""

# Recommendations
echo -e "${WHITE}💡 RECOMMENDATIONS${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if backup is configured
if [[ ! -f "/home/n8n/scripts/backup.sh" ]]; then
    echo -e "${YELLOW}⚠️ Backup script not found - consider setting up backups${NC}"
fi

# Check if auto-update is configured
if [[ ! -f "/home/n8n/scripts/auto_update.sh" ]]; then
    echo -e "${YELLOW}⚠️ Auto-update script not found - consider enabling auto-updates${NC}"
fi

# Check disk space
disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [[ $disk_usage -gt 80 ]]; then
    echo -e "${RED}❌ Disk usage is high ($disk_usage%) - consider cleaning up${NC}"
elif [[ $disk_usage -gt 70 ]]; then
    echo -e "${YELLOW}⚠️ Disk usage is moderate ($disk_usage%) - monitor closely${NC}"
fi

# Check memory usage
mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
if [[ $mem_usage -gt 90 ]]; then
    echo -e "${RED}❌ Memory usage is high ($mem_usage%) - consider adding more RAM${NC}"
elif [[ $mem_usage -gt 80 ]]; then
    echo -e "${YELLOW}⚠️ Memory usage is moderate ($mem_usage%) - monitor closely${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Diagnostic completed!${NC}"
echo -e "${BLUE}For support, contact: https://www.youtube.com/@kalvinthiensocial${NC}"
EOF
    
    chmod +x $N8N_DIR/scripts/diagnose.sh
    
    log_success "Đã tạo script chẩn đoán"
}

# Thiết lập cron jobs
setup_cron_jobs() {
    log_info "⏰ Thiết lập cron jobs..."
    
    # Backup cron jobs hiện tại
    crontab -l 2>/dev/null > /tmp/current_crontab || touch /tmp/current_crontab
    
    # Xóa các cron jobs N8N cũ
    grep -v "/home/n8n" /tmp/current_crontab > /tmp/new_crontab || touch /tmp/new_crontab
    
    # Thêm backup job (hàng ngày lúc 2:00 AM)
    echo "0 2 * * * /home/n8n/scripts/backup.sh >> /home/n8n/logs/backup.log 2>&1" >> /tmp/new_crontab
    
    # Thêm SSL renewal job (hàng ngày lúc 3:00 AM)
    if [[ "$USE_DOMAIN" == "true" ]]; then
        echo "0 3 * * * /home/n8n/scripts/ssl_renewal.sh >> /home/n8n/logs/ssl_renewal.log 2>&1" >> /tmp/new_crontab
    fi
    
    # Thêm auto-update job (mỗi 12 giờ)
    if [[ "$AUTO_UPDATE_ENABLED" == "true" ]]; then
        echo "0 */12 * * * /home/n8n/scripts/auto_update.sh >> /home/n8n/logs/auto_update.log 2>&1" >> /tmp/new_crontab
    fi
    
    # Cài đặt cron jobs mới
    crontab /tmp/new_crontab
    
    # Cleanup
    rm -f /tmp/current_crontab /tmp/new_crontab
    
    log_success "Đã thiết lập cron jobs"
}

# Build và deploy containers
build_and_deploy() {
    log_info "🏗️ Build và deploy containers..."
    
    cd $N8N_DIR
    
    # Dừng containers cũ
    log_info "🛑 Dừng containers cũ..."
    docker-compose down -v 2>/dev/null || true
    
    # Build Docker images
    log_info "📦 Build Docker images..."
    docker-compose build --no-cache
    
    # Khởi động containers
    log_info "🚀 Khởi động containers..."
    docker-compose up -d
    
    # Đợi containers khởi động
    log_info "⏳ Đợi services khởi động..."
    sleep 30
    
    # Kiểm tra trạng thái containers
    log_info "🔍 Kiểm tra trạng thái containers..."
    if docker-compose ps | grep -q "Up"; then
        log_success "✅ Containers đã khởi động thành công"
    else
        log_error "❌ Một số containers không khởi động được"
        docker-compose ps
        exit 1
    fi
}

# Kiểm tra SSL certificate
check_ssl_certificate() {
    if [[ "$USE_DOMAIN" != "true" ]]; then
        return
    fi
    
    log_info "🔒 Kiểm tra SSL certificate..."
    
    # Đợi SSL certificate được cấp
    local max_attempts=10
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_info "Thử lần $attempt/$max_attempts..."
        
        # Kiểm tra Caddy logs
        local caddy_logs=$(docker logs caddy-proxy 2>&1 | tail -20)
        
        # Kiểm tra rate limit
        if echo "$caddy_logs" | grep -q "rateLimited\|too many certificates"; then
            log_error "🚨 PHÁT HIỆN SSL RATE LIMIT!"
            
            echo -e "${CYAN}"
            cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                        ⚠️  SSL RATE LIMIT DETECTED                          ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
            echo -e "${NC}"
            
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
            echo -e "  ${GREEN}2. SỬ DỤNG ZEROSSL (TỰ ĐỘNG):${NC}"
            echo -e "     • Script sẽ tự động chuyển sang ZeroSSL"
            echo -e "     • SSL certificate vẫn được cấp miễn phí"
            echo -e "     • Tự động gia hạn sau 90 ngày"
            echo ""
            echo -e "  ${GREEN}3. ĐỢI ĐẾN KHI RATE LIMIT RESET:${NC}"
            
            # Tính toán thời gian reset
            local retry_after=$(echo "$caddy_logs" | grep -o "retry after [0-9-]* [0-9:]* UTC" | tail -1 | sed 's/retry after //' | sed 's/ UTC//')
            
            if [[ -n "$retry_after" ]]; then
                local retry_timestamp=$(date -d "$retry_after UTC" +%s 2>/dev/null || echo "0")
                local vn_time=$(TZ='Asia/Ho_Chi_Minh' date -d "@$retry_timestamp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Unknown")
                echo -e "     • Đợi đến sau $vn_time (Giờ VN)"
            else
                echo -e "     • Đợi 7 ngày kể từ lần thử SSL cuối cùng"
            fi
            echo -e "     • Chạy lại script để cấp SSL mới"
            echo ""
            
            echo -e "${YELLOW}📋 LỊCH SỬ SSL ATTEMPTS GẦN ĐÂY:${NC}"
            echo "$caddy_logs" | grep -E "(rateLimited|too many certificates|obtain|error)" | tail -5 | while read line; do
                echo "• $line"
            done
            echo ""
            
            read -p "🤔 Bạn muốn chuyển sang ZeroSSL tự động? (Y/n): " zerossl_choice
            
            if [[ ! $zerossl_choice =~ ^[Nn]$ ]]; then
                log_info "🔄 Chuyển sang ZeroSSL..."
                
                # Update Caddyfile với ZeroSSL
                sed -i '1i{\n    acme_ca https://acme.zerossl.com/v2/DV90\n}' $N8N_DIR/Caddyfile
                
                # Restart Caddy
                docker-compose restart caddy
                
                log_success "✅ Đã chuyển sang ZeroSSL"
                
                # Đợi SSL được cấp
                sleep 60
                continue
            else
                echo ""
                echo -e "${YELLOW}📋 HƯỚNG DẪN CÀI LẠI UBUNTU:${NC}"
                echo -e "  1. Backup dữ liệu quan trọng"
                echo -e "  2. Cài lại Ubuntu Server từ đầu"
                echo -e "  3. Sử dụng subdomain khác hoặc domain khác"
                echo -e "  4. Chạy lại script: curl -sSL https://raw.githubusercontent.com/KalvinThien/install-n8n-ffmpeg/main/auto_cai_dat_n8n.sh | bash"
                echo ""
                exit 1
            fi
        fi
        
        # Kiểm tra SSL thành công
        if echo "$caddy_logs" | grep -q "certificate obtained successfully"; then
            log_success "✅ SSL certificate đã được cấp thành công"
            return
        fi
        
        # Kiểm tra bằng cách test HTTPS
        if curl -s -k https://$DOMAIN > /dev/null 2>&1; then
            log_success "✅ HTTPS đang hoạt động"
            return
        fi
        
        sleep 30
        ((attempt++))
    done
    
    log_warning "⚠️ Không thể xác nhận SSL certificate, nhưng có thể vẫn đang được cấp"
}

# Hiển thị thông tin hoàn thành
show_completion_info() {
    echo -e "${GREEN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                        🎉 CÀI ĐẶT HOÀN THÀNH!                               ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo -e "${WHITE}📋 THÔNG TIN TRUY CẬP:${NC}"
    
    if [[ "$USE_DOMAIN" == "true" ]]; then
        echo -e "  🌐 N8N URL: ${GREEN}https://$DOMAIN${NC}"
        if [[ "$NEWS_API_ENABLED" == "true" ]]; then
            echo -e "  📰 News API: ${GREEN}https://$API_DOMAIN${NC}"
            echo -e "  🔑 Bearer Token: ${YELLOW}$BEARER_TOKEN${NC}"
        fi
    else
        echo -e "  🌐 N8N URL: ${GREEN}http://localhost:5678${NC}"
        if [[ "$NEWS_API_ENABLED" == "true" ]]; then
            echo -e "  📰 News API: ${GREEN}http://localhost:8001${NC}"
            echo -e "  🔑 Bearer Token: ${YELLOW}$BEARER_TOKEN${NC}"
        fi
    fi
    
    echo ""
    echo -e "${WHITE}🔧 LỆNH QUẢN LÝ:${NC}"
    echo -e "  📊 Chẩn đoán hệ thống: ${CYAN}/home/n8n/scripts/diagnose.sh${NC}"
    echo -e "  💾 Backup thủ công: ${CYAN}/home/n8n/scripts/backup.sh${NC}"
    echo -e "  🔄 Restore: ${CYAN}/home/n8n/scripts/restore.sh${NC}"
    
    if [[ "$USE_DOMAIN" == "true" ]]; then
        echo -e "  🔒 Kiểm tra SSL: ${CYAN}/home/n8n/scripts/ssl_renewal.sh${NC}"
    fi
    
    if [[ "$AUTO_UPDATE_ENABLED" == "true" ]]; then
        echo -e "  🔄 Update thủ công: ${CYAN}/home/n8n/scripts/auto_update.sh${NC}"
    fi
    
    echo ""
    echo -e "${WHITE}📁 THÔNG TIN THÊM:${NC}"
    echo -e "  📂 Thư mục N8N: ${CYAN}/home/n8n${NC}"
    echo -e "  📋 Logs: ${CYAN}/home/n8n/logs/${NC}"
    echo -e "  💾 Backups: ${CYAN}/home/n8n/backups/${NC}"
    
    if [[ "$TELEGRAM_BACKUP_ENABLED" == "true" ]]; then
        echo -e "  📱 Telegram backup: ${GREEN}Enabled${NC}"
    fi
    
    if [[ "$GDRIVE_BACKUP_ENABLED" == "true" ]]; then
        echo -e "  ☁️  Google Drive backup: ${GREEN}Enabled${NC}"
    fi
    
    if [[ "$AUTO_UPDATE_ENABLED" == "true" ]]; then
        echo -e "  🔄 Auto-update: ${GREEN}Enabled (mỗi 12 giờ)${NC}"
    fi
    
    echo ""
    echo -e "${WHITE}🎬 HỖ TRỢ:${NC}"
    echo -e "  📺 YouTube: ${CYAN}https://www.youtube.com/@kalvinthiensocial${NC}"
    echo -e "  📱 Zalo: ${CYAN}08.8888.4749${NC}"
    echo -e "  🔔 Đăng ký kênh để ủng hộ mình nhé!"
    
    echo ""
    log_success "🚀 N8N đã sẵn sàng sử dụng!"
}

# Main function
main() {
    show_header
    check_root
    detect_os
    setup_swap
    configure_domain
    check_dns
    cleanup_old_installation
    install_docker
    create_directory_structure
    configure_news_api
    configure_telegram_backup
    configure_gdrive_backup
    configure_auto_update
    create_n8n_dockerfile
    create_news_api
    create_docker_compose
    create_caddyfile
    create_backup_system
    create_ssl_renewal_script
    create_auto_update_script
    create_diagnostic_script
    setup_cron_jobs
    build_and_deploy
    check_ssl_certificate
    show_completion_info
}

# Chạy script
main "$@"
