#!/bin/bash

# Script cài đặt N8N tự động với ZeroSSL
# Tác giả: Nguyễn Ngọc Thiện
# Cập nhật: 30/06/2025

set -e

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Biến toàn cục
SCRIPT_DIR="/home/n8n"
DOMAIN=""
API_DOMAIN=""
NEWS_TOKEN=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
GOOGLE_DRIVE_ENABLED=false
GOOGLE_CREDENTIALS_FILE=""
GOOGLE_FOLDER_ID=""
AUTO_UPDATE=false
USE_DOMAIN=true
SSL_PROVIDER="letsencrypt"
ZEROSSL_EMAIL=""

# Hàm log với timestamp
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Hàm hiển thị header
show_header() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🚀 SCRIPT CÀI ĐẶT N8N TỰ ĐỘNG 2025 🚀                    ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ ✨ N8N + FFmpeg + yt-dlp + Puppeteer + News API + Telegram Backup        ║
║ 🔒 SSL Certificate tự động với Caddy (Let's Encrypt + ZeroSSL)           ║
║ 📰 News Content API với FastAPI + Newspaper4k                            ║
║ 📱 Telegram + Google Drive Backup tự động                                ║
║ 🔄 Auto-Update với tùy chọn                                              ║
║ 🌐 Hỗ trợ cài đặt không cần domain (localhost)                          ║
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

# Hàm kiểm tra và cài đặt Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        log "${YELLOW}🐳 Cài đặt Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        usermod -aG docker $USER
        systemctl enable docker
        systemctl start docker
        rm get-docker.sh
        log "${GREEN}[SUCCESS] Docker đã được cài đặt"
    else
        log "${GREEN}[INFO] Docker đã được cài đặt"
    fi

    if ! command -v docker-compose &> /dev/null; then
        log "${YELLOW}🐳 Cài đặt Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        log "${GREEN}[SUCCESS] Docker Compose đã được cài đặt"
    else
        log "${GREEN}[INFO] Sử dụng docker-compose"
    fi
}

# Hàm thiết lập swap
setup_swap() {
    log "${YELLOW}🔄 Thiết lập swap memory..."
    if [ ! -f /swapfile ]; then
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        log "${GREEN}[SUCCESS] Đã tạo swap 2GB"
    else
        log "${GREEN}[INFO] Swap file đã tồn tại"
    fi
}

# Hàm cấu hình domain
configure_domain() {
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                           🌐 CẤU HÌNH DOMAIN                                ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    echo -e "${YELLOW}🌐 Bạn có muốn sử dụng domain tùy chỉnh? (Y/n):${NC}"
    read -r use_domain_input
    if [[ $use_domain_input =~ ^[Nn]$ ]]; then
        USE_DOMAIN=false
        DOMAIN="localhost"
        API_DOMAIN="localhost"
        log "${GREEN}[INFO] Sử dụng localhost (không SSL)"
        return
    fi

    while true; do
        echo -e "${YELLOW}🌐 Nhập domain chính cho N8N (ví dụ: n8n.example.com):${NC}"
        read -r DOMAIN
        if [[ -n "$DOMAIN" && "$DOMAIN" != *" "* ]]; then
            break
        fi
        echo -e "${RED}[ERROR] Domain không hợp lệ. Vui lòng nhập lại.${NC}"
    done

    API_DOMAIN="api.$DOMAIN"
    log "${GREEN}[INFO] Domain N8N: $DOMAIN"
    log "${GREEN}[INFO] Domain API: $API_DOMAIN"
}

# Hàm kiểm tra DNS
check_dns() {
    if [ "$USE_DOMAIN" = false ]; then
        return 0
    fi

    log "${YELLOW}🔍 Kiểm tra DNS cho domain $DOMAIN..."
    
    SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || curl -s icanhazip.com)
    log "${GREEN}[INFO] IP máy chủ: $SERVER_IP"
    
    DOMAIN_IP=$(dig +short $DOMAIN | tail -n1)
    API_DOMAIN_IP=$(dig +short $API_DOMAIN | tail -n1)
    
    log "${GREEN}[INFO] IP của $DOMAIN: $DOMAIN_IP"
    log "${GREEN}[INFO] IP của $API_DOMAIN: $API_DOMAIN_IP"
    
    if [ "$DOMAIN_IP" != "$SERVER_IP" ] || [ "$API_DOMAIN_IP" != "$SERVER_IP" ]; then
        echo -e "${RED}"
        cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                        ⚠️  DNS CHƯA ĐƯỢC CẤU HÌNH                           ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
        echo -e "${NC}"
        echo -e "${YELLOW}Vui lòng cấu hình DNS records:${NC}"
        echo -e "  • $DOMAIN → $SERVER_IP"
        echo -e "  • $API_DOMAIN → $SERVER_IP"
        echo ""
        echo -e "${YELLOW}Bạn có muốn tiếp tục? (y/N):${NC}"
        read -r continue_dns
        if [[ ! $continue_dns =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log "${GREEN}[SUCCESS] DNS đã được cấu hình đúng"
    fi
}

# Hàm cleanup cài đặt cũ
cleanup_old_installation() {
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                           🗑️  CLEANUP OPTION                               ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    if [ -d "$SCRIPT_DIR" ]; then
        echo -e "${YELLOW}[WARNING] Phát hiện cài đặt N8N cũ tại: $SCRIPT_DIR${NC}"
        echo -e "${YELLOW}🗑️  Bạn có muốn xóa cài đặt cũ và cài mới? (y/N):${NC}"
        read -r cleanup_choice
        if [[ $cleanup_choice =~ ^[Yy]$ ]]; then
            log "${YELLOW}🗑️ Xóa cài đặt cũ..."
            cd /
            docker-compose -f $SCRIPT_DIR/docker-compose.yml down 2>/dev/null || true
            docker system prune -f 2>/dev/null || true
            rm -rf $SCRIPT_DIR
            log "${GREEN}[SUCCESS] Đã xóa cài đặt cũ"
        fi
    fi
}

# Hàm cấu hình News API
configure_news_api() {
    echo -e "${CYAN}"
    cat << "EOF"
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
    echo -e "${YELLOW}📰 Bạn có muốn cài đặt News Content API? (Y/n):${NC}"
    read -r news_api_choice
    
    if [[ ! $news_api_choice =~ ^[Nn]$ ]]; then
        echo ""
        echo -e "${BLUE}🔐 Thiết lập Bearer Token cho News API:${NC}"
        echo -e "  • Token có thể chứa chữ cái, số và ký tự đặc biệt"
        echo -e "  • Độ dài tùy ý (khuyến nghị từ 32 ký tự)"
        echo -e "  • Sẽ được sử dụng để xác thực API calls"
        echo ""
        
        while true; do
            echo -e "${YELLOW}🔑 Nhập Bearer Token:${NC}"
            read -r NEWS_TOKEN
            if [[ -n "$NEWS_TOKEN" ]]; then
                break
            fi
            echo -e "${RED}[ERROR] Token không được để trống${NC}"
        done
        
        log "${GREEN}[SUCCESS] Đã thiết lập Bearer Token cho News API"
    fi
}

# Hàm cấu hình Telegram Backup
configure_telegram_backup() {
    echo -e "${CYAN}"
    cat << "EOF"
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
    echo -e "${YELLOW}📱 Bạn có muốn thiết lập Telegram Backup? (Y/n):${NC}"
    read -r telegram_choice
    
    if [[ ! $telegram_choice =~ ^[Nn]$ ]]; then
        echo ""
        echo -e "${BLUE}🤖 Hướng dẫn tạo Telegram Bot:${NC}"
        echo -e "  1. Mở Telegram, tìm @BotFather"
        echo -e "  2. Gửi /newbot và làm theo hướng dẫn"
        echo -e "  3. Lưu Bot Token"
        echo -e "  4. Tìm @userinfobot để lấy Chat ID"
        echo ""
        
        while true; do
            echo -e "${YELLOW}🔑 Nhập Telegram Bot Token:${NC}"
            read -r TELEGRAM_BOT_TOKEN
            if [[ -n "$TELEGRAM_BOT_TOKEN" ]]; then
                break
            fi
            echo -e "${RED}[ERROR] Bot Token không được để trống${NC}"
        done
        
        while true; do
            echo -e "${YELLOW}🆔 Nhập Telegram Chat ID:${NC}"
            read -r TELEGRAM_CHAT_ID
            if [[ -n "$TELEGRAM_CHAT_ID" ]]; then
                break
            fi
            echo -e "${RED}[ERROR] Chat ID không được để trống${NC}"
        done
        
        log "${GREEN}[SUCCESS] Đã thiết lập Telegram Backup"
    fi
}

# Hàm cấu hình Google Drive Backup
configure_google_drive_backup() {
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                        ☁️  GOOGLE DRIVE BACKUP                             ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    echo "Google Drive Backup cho phép:"
    echo -e "  ☁️  Tự động backup workflows & credentials lên Google Drive"
    echo -e "  📁 Tạo thư mục riêng cho từng server"
    echo -e "  🔄 Backup hàng ngày, giữ 30 bản gần nhất"
    echo -e "  📊 Thông báo trạng thái backup qua Telegram"
    echo ""
    echo -e "${YELLOW}☁️  Bạn có muốn thiết lập Google Drive Backup? (Y/n):${NC}"
    read -r gdrive_choice
    
    if [[ ! $gdrive_choice =~ ^[Nn]$ ]]; then
        GOOGLE_DRIVE_ENABLED=true
        echo ""
        echo -e "${BLUE}🔐 Hướng dẫn thiết lập Google Drive API:${NC}"
        echo -e "  1. Truy cập: https://console.developers.google.com/"
        echo -e "  2. Tạo project mới hoặc chọn project có sẵn"
        echo -e "  3. Enable Google Drive API"
        echo -e "  4. Tạo Service Account:"
        echo -e "     • APIs & Services → Credentials → Create Credentials → Service Account"
        echo -e "     • Đặt tên và mô tả cho Service Account"
        echo -e "     • Tạo Key (JSON format) và download"
        echo -e "  5. Chia sẻ thư mục Google Drive với email Service Account"
        echo ""
        
        echo -e "${YELLOW}📁 Nhập Google Drive Folder ID (từ URL thư mục):${NC}"
        echo -e "${BLUE}   Ví dụ: https://drive.google.com/drive/folders/1ABC...XYZ${NC}"
        echo -e "${BLUE}   → Folder ID là: 1ABC...XYZ${NC}"
        read -r GOOGLE_FOLDER_ID
        
        echo ""
        echo -e "${YELLOW}📄 Dán nội dung file JSON credentials (Ctrl+D để kết thúc):${NC}"
        GOOGLE_CREDENTIALS_CONTENT=$(cat)
        
        log "${GREEN}[SUCCESS] Đã thiết lập Google Drive Backup"
    fi
}

# Hàm cấu hình Auto-Update
configure_auto_update() {
    echo -e "${CYAN}"
    cat << "EOF"
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
    echo -e "${YELLOW}🔄 Bạn có muốn bật Auto-Update? (Y/n):${NC}"
    read -r auto_update_choice
    if [[ ! $auto_update_choice =~ ^[Nn]$ ]]; then
        AUTO_UPDATE=true
        log "${GREEN}[SUCCESS] Đã bật Auto-Update"
    fi
}

# Hàm cấu hình SSL Provider
configure_ssl_provider() {
    if [ "$USE_DOMAIN" = false ]; then
        return 0
    fi

    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                        🔒 SSL CERTIFICATE PROVIDER                         ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    echo "Chọn nhà cung cấp SSL:"
    echo -e "  ${GREEN}1.${NC} Let's Encrypt (Mặc định - 90 ngày, 5 cert/tuần/domain)"
    echo -e "  ${GREEN}2.${NC} ZeroSSL (90 ngày, không giới hạn domain)"
    echo -e "  ${GREEN}3.${NC} Tự động chuyển đổi (Let's Encrypt → ZeroSSL nếu rate limit)"
    echo ""
    echo -e "${YELLOW}🔒 Chọn SSL Provider (1/2/3) [3]:${NC}"
    read -r ssl_choice

    case $ssl_choice in
        1)
            SSL_PROVIDER="letsencrypt"
            log "${GREEN}[INFO] Sử dụng Let's Encrypt"
            ;;
        2)
            SSL_PROVIDER="zerossl"
            echo -e "${YELLOW}📧 Nhập email cho ZeroSSL:${NC}"
            read -r ZEROSSL_EMAIL
            log "${GREEN}[INFO] Sử dụng ZeroSSL"
            ;;
        *)
            SSL_PROVIDER="auto"
            echo -e "${YELLOW}📧 Nhập email cho SSL certificates:${NC}"
            read -r ZEROSSL_EMAIL
            log "${GREEN}[INFO] Sử dụng chế độ tự động chuyển đổi"
            ;;
    esac
}

# Hàm tạo cấu trúc thư mục
create_directory_structure() {
    log "${YELLOW}📁 Tạo cấu trúc thư mục..."
    
    mkdir -p $SCRIPT_DIR/{data,logs,backups,scripts,news-api,google-credentials}
    mkdir -p $SCRIPT_DIR/data/{database,workflows,credentials}
    
    log "${GREEN}[SUCCESS] Đã tạo cấu trúc thư mục"
}

# Hàm tạo Dockerfile cho N8N
create_n8n_dockerfile() {
    log "${YELLOW}🐳 Tạo Dockerfile cho N8N..."
    
    cat > $SCRIPT_DIR/Dockerfile << 'EOF'
FROM n8nio/n8n:latest

USER root

# Cài đặt các dependencies cần thiết
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
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Tạo script update yt-dlp
RUN echo '#!/bin/bash' > /usr/local/bin/update-ytdlp.sh && \
    echo 'pip3 install --upgrade yt-dlp' >> /usr/local/bin/update-ytdlp.sh && \
    chmod +x /usr/local/bin/update-ytdlp.sh

USER node

# Cài đặt các node packages bổ sung
RUN cd /usr/local/lib/node_modules/n8n && \
    npm install puppeteer-core@latest

EXPOSE 5678

CMD ["n8n", "start"]
EOF

    log "${GREEN}[SUCCESS] Đã tạo Dockerfile cho N8N"
}

# Hàm tạo News Content API
create_news_api() {
    if [[ -z "$NEWS_TOKEN" ]]; then
        return 0
    fi

    log "${YELLOW}📰 Tạo News Content API..."
    
    # Tạo requirements.txt
    cat > $SCRIPT_DIR/news-api/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
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
    cat > $SCRIPT_DIR/news-api/main.py << EOF
from fastapi import FastAPI, HTTPException, Depends, status
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
BEARER_TOKEN = "$NEWS_TOKEN"

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if credentials.credentials != BEARER_TOKEN:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return credentials.credentials

# Models
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
    link: str
    entries: List[dict]

class URLRequest(BaseModel):
    url: str
    language: str = "vi"

@app.get("/")
async def root():
    return {
        "message": "News Content API v2.0.0",
        "endpoints": {
            "article": "/article - Cào nội dung bài viết",
            "rss": "/rss - Parse RSS feed",
            "health": "/health - Kiểm tra trạng thái"
        }
    }

@app.get("/health")
async def health_check():
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

@app.post("/article", response_model=ArticleResponse)
async def get_article(request: URLRequest, token: str = Depends(verify_token)):
    try:
        logger.info(f"Processing article: {request.url}")
        
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
            title=article.title or "Không có tiêu đề",
            content=article.text or "Không có nội dung",
            summary=article.summary or "Không có tóm tắt",
            authors=article.authors or [],
            publish_date=publish_date,
            top_image=article.top_image or None,
            url=request.url,
            keywords=article.keywords or []
        )
        
    except Exception as e:
        logger.error(f"Error processing article {request.url}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Lỗi xử lý bài viết: {str(e)}")

@app.post("/rss", response_model=RSSResponse)
async def parse_rss(request: URLRequest, token: str = Depends(verify_token)):
    try:
        logger.info(f"Processing RSS: {request.url}")
        
        # Parse RSS feed
        feed = feedparser.parse(request.url)
        
        if feed.bozo:
            raise HTTPException(status_code=400, detail="RSS feed không hợp lệ")
        
        # Format entries
        entries = []
        for entry in feed.entries[:20]:  # Giới hạn 20 entries
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
            title=feed.feed.get('title', 'Không có tiêu đề'),
            description=feed.feed.get('description', 'Không có mô tả'),
            link=feed.feed.get('link', request.url),
            entries=entries
        )
        
    except Exception as e:
        logger.error(f"Error processing RSS {request.url}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Lỗi xử lý RSS: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

    # Tạo Dockerfile cho News API
    cat > $SCRIPT_DIR/news-api/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Cài đặt system dependencies
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

# Copy requirements và cài đặt Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY main.py .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

    log "${GREEN}[SUCCESS] Đã tạo News Content API"
}

# Hàm tạo docker-compose.yml
create_docker_compose() {
    log "${YELLOW}🐳 Tạo docker-compose.yml..."
    
    # Tạo phần services cơ bản
    cat > $SCRIPT_DIR/docker-compose.yml << EOF
version: '3.8'

services:
  n8n:
    build: .
    container_name: n8n-container
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=\${N8N_PASSWORD:-admin123456}
      - N8N_HOST=\${N8N_HOST:-localhost}
      - N8N_PORT=5678
      - N8N_PROTOCOL=\${N8N_PROTOCOL:-http}
      - WEBHOOK_URL=\${WEBHOOK_URL:-http://localhost:5678}
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
      - TZ=Asia/Ho_Chi_Minh
    volumes:
      - ./data:/home/node/.n8n
      - ./logs:/var/log/n8n
    networks:
      - n8n_network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3

EOF

    # Thêm News API nếu được cấu hình
    if [[ -n "$NEWS_TOKEN" ]]; then
        cat >> $SCRIPT_DIR/docker-compose.yml << EOF
  news-api:
    build: ./news-api
    container_name: news-api-container
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      - TZ=Asia/Ho_Chi_Minh
    networks:
      - n8n_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

EOF
    fi

    # Thêm Caddy nếu sử dụng domain
    if [ "$USE_DOMAIN" = true ]; then
        cat >> $SCRIPT_DIR/docker-compose.yml << EOF
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
    depends_on:
      - n8n
EOF
        if [[ -n "$NEWS_TOKEN" ]]; then
            cat >> $SCRIPT_DIR/docker-compose.yml << EOF
      - news-api
EOF
        fi
        cat >> $SCRIPT_DIR/docker-compose.yml << EOF

volumes:
  caddy_data:
  caddy_config:

EOF
    fi

    # Thêm networks
    cat >> $SCRIPT_DIR/docker-compose.yml << EOF
networks:
  n8n_network:
    driver: bridge
EOF

    log "${GREEN}[SUCCESS] Đã tạo docker-compose.yml"
}

# Hàm tạo Caddyfile
create_caddyfile() {
    if [ "$USE_DOMAIN" = false ]; then
        return 0
    fi

    log "${YELLOW}🌐 Tạo Caddyfile..."
    
    # Xác định ACME CA dựa trên SSL provider
    local acme_ca=""
    case $SSL_PROVIDER in
        "letsencrypt")
            acme_ca="https://acme-v02.api.letsencrypt.org/directory"
            ;;
        "zerossl")
            acme_ca="https://acme.zerossl.com/v2/DV90"
            ;;
        "auto")
            acme_ca="https://acme-v02.api.letsencrypt.org/directory"
            ;;
    esac

    cat > $SCRIPT_DIR/Caddyfile << EOF
{
    email ${ZEROSSL_EMAIL:-admin@${DOMAIN}}
    acme_ca $acme_ca
}

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
    
    # Logging
    log {
        output file /var/log/caddy/access.log
        format json
    }
}

EOF

    # Thêm API domain nếu có News API
    if [[ -n "$NEWS_TOKEN" ]]; then
        cat >> $SCRIPT_DIR/Caddyfile << EOF
$API_DOMAIN {
    reverse_proxy news-api:8000
    
    # Security headers
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
    
    # CORS headers
    header {
        Access-Control-Allow-Origin "*"
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        Access-Control-Allow-Headers "Content-Type, Authorization"
    }
    
    # Logging
    log {
        output file /var/log/caddy/api-access.log
        format json
    }
}
EOF
    fi

    log "${GREEN}[SUCCESS] Đã tạo Caddyfile"
}

# Hàm tạo backup system
create_backup_system() {
    log "${YELLOW}💾 Tạo hệ thống backup..."
    
    # Tạo script backup chính
    cat > $SCRIPT_DIR/scripts/backup.sh << 'EOF'
#!/bin/bash

# Script backup N8N
# Tự động backup workflows, credentials và cấu hình

SCRIPT_DIR="/home/n8n"
BACKUP_DIR="$SCRIPT_DIR/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="n8n_backup_$DATE"
BACKUP_FILE="$BACKUP_DIR/$BACKUP_NAME.zip"

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $SCRIPT_DIR/logs/backup.log
}

# Tạo thư mục backup
mkdir -p $BACKUP_DIR

log "${YELLOW}🔄 Bắt đầu backup N8N..."

# Backup dữ liệu N8N
cd $SCRIPT_DIR
zip -r $BACKUP_FILE \
    data/database/ \
    data/workflows/ \
    data/credentials/ \
    docker-compose.yml \
    Caddyfile \
    .env 2>/dev/null || true

if [ -f "$BACKUP_FILE" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log "${GREEN}[SUCCESS] ✅ Backup thành công: $BACKUP_NAME.zip ($BACKUP_SIZE)"
    
    # Xóa backup cũ (giữ 30 bản gần nhất)
    cd $BACKUP_DIR
    ls -t *.zip 2>/dev/null | tail -n +31 | xargs rm -f 2>/dev/null || true
    
    # Gửi qua Telegram nếu được cấu hình
    if [ -f "$SCRIPT_DIR/.env" ]; then
        source $SCRIPT_DIR/.env
        if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
            BACKUP_SIZE_BYTES=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_FILE" 2>/dev/null || echo "0")
            if [ "$BACKUP_SIZE_BYTES" -lt 20971520 ]; then  # < 20MB
                curl -s -X POST \
                    "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument" \
                    -F chat_id="$TELEGRAM_CHAT_ID" \
                    -F document=@"$BACKUP_FILE" \
                    -F caption="🔄 N8N Backup: $BACKUP_NAME ($BACKUP_SIZE)" >/dev/null
                log "${GREEN}[SUCCESS] 📱 Đã gửi backup qua Telegram"
            else
                curl -s -X POST \
                    "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
                    -d chat_id="$TELEGRAM_CHAT_ID" \
                    -d text="🔄 N8N Backup: $BACKUP_NAME ($BACKUP_SIZE) - File quá lớn để gửi qua Telegram" >/dev/null
                log "${YELLOW}[WARNING] 📱 File backup quá lớn cho Telegram"
            fi
        fi
    fi
    
    # Upload lên Google Drive nếu được cấu hình
    if [ -f "$SCRIPT_DIR/scripts/gdrive_upload.py" ]; then
        python3 $SCRIPT_DIR/scripts/gdrive_upload.py "$BACKUP_FILE" 2>/dev/null && \
        log "${GREEN}[SUCCESS] ☁️ Đã upload backup lên Google Drive" || \
        log "${YELLOW}[WARNING] ☁️ Lỗi upload Google Drive"
    fi
    
else
    log "${RED}[ERROR] ❌ Backup thất bại"
    exit 1
fi

log "${GREEN}🎉 Hoàn thành backup N8N"
EOF

    chmod +x $SCRIPT_DIR/scripts/backup.sh

    # Tạo script Google Drive upload nếu được cấu hình
    if [ "$GOOGLE_DRIVE_ENABLED" = true ]; then
        create_google_drive_scripts
    fi

    log "${GREEN}[SUCCESS] Đã tạo hệ thống backup"
}

# Hàm tạo Google Drive scripts
create_google_drive_scripts() {
    log "${YELLOW}☁️ Tạo Google Drive integration..."
    
    # Lưu credentials
    echo "$GOOGLE_CREDENTIALS_CONTENT" > $SCRIPT_DIR/google-credentials/credentials.json
    
    # Tạo requirements cho Google Drive
    cat > $SCRIPT_DIR/google-credentials/requirements.txt << 'EOF'
google-api-python-client==2.108.0
google-auth==2.23.4
google-auth-oauthlib==1.1.0
google-auth-httplib2==0.1.1
EOF

    # Cài đặt dependencies
    pip3 install -r $SCRIPT_DIR/google-credentials/requirements.txt >/dev/null 2>&1 || true

    # Tạo script upload
    cat > $SCRIPT_DIR/scripts/gdrive_upload.py << EOF
#!/usr/bin/env python3

import os
import sys
from datetime import datetime
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from google.oauth2 import service_account

# Cấu hình
CREDENTIALS_FILE = '/home/n8n/google-credentials/credentials.json'
FOLDER_ID = '$GOOGLE_FOLDER_ID'
SCOPES = ['https://www.googleapis.com/auth/drive.file']

def upload_to_drive(file_path):
    try:
        # Xác thực
        credentials = service_account.Credentials.from_service_account_file(
            CREDENTIALS_FILE, scopes=SCOPES)
        service = build('drive', 'v3', credentials=credentials)
        
        # Tên file
        file_name = os.path.basename(file_path)
        
        # Metadata
        file_metadata = {
            'name': file_name,
            'parents': [FOLDER_ID] if FOLDER_ID else []
        }
        
        # Upload
        media = MediaFileUpload(file_path, resumable=True)
        file = service.files().create(
            body=file_metadata,
            media_body=media,
            fields='id'
        ).execute()
        
        print(f"Upload thành công: {file_name} (ID: {file.get('id')})")
        
        # Xóa file backup cũ trên Drive (giữ 30 bản)
        cleanup_old_backups(service)
        
        return True
        
    except Exception as e:
        print(f"Lỗi upload Google Drive: {str(e)}")
        return False

def cleanup_old_backups(service):
    try:
        # Tìm tất cả file backup
        query = f"parents in '{FOLDER_ID}' and name contains 'n8n_backup_'"
        results = service.files().list(
            q=query,
            orderBy='createdTime desc',
            fields='files(id, name, createdTime)'
        ).execute()
        
        files = results.get('files', [])
        
        # Xóa file cũ (giữ 30 bản gần nhất)
        if len(files) > 30:
            for file in files[30:]:
                service.files().delete(fileId=file['id']).execute()
                print(f"Đã xóa backup cũ: {file['name']}")
                
    except Exception as e:
        print(f"Lỗi cleanup Google Drive: {str(e)}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 gdrive_upload.py <file_path>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    if not os.path.exists(file_path):
        print(f"File không tồn tại: {file_path}")
        sys.exit(1)
    
    success = upload_to_drive(file_path)
    sys.exit(0 if success else 1)
EOF

    chmod +x $SCRIPT_DIR/scripts/gdrive_upload.py
    
    log "${GREEN}[SUCCESS] Đã tạo Google Drive integration"
}

# Hàm tạo restore system
create_restore_system() {
    log "${YELLOW}🔄 Tạo hệ thống restore..."
    
    cat > $SCRIPT_DIR/scripts/restore.sh << 'EOF'
#!/bin/bash

# Script restore N8N từ backup

SCRIPT_DIR="/home/n8n"
BACKUP_DIR="$SCRIPT_DIR/backups"

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

show_restore_menu() {
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                        🔄 N8N RESTORE SYSTEM                               ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo "Chọn nguồn restore:"
    echo -e "  ${GREEN}1.${NC} Restore từ file backup local"
    echo -e "  ${GREEN}2.${NC} Restore từ Google Drive"
    echo -e "  ${GREEN}3.${NC} Liệt kê backup có sẵn"
    echo -e "  ${GREEN}4.${NC} Thoát"
    echo ""
}

list_local_backups() {
    echo -e "${YELLOW}📋 Danh sách backup local:${NC}"
    if [ -d "$BACKUP_DIR" ] && [ "$(ls -A $BACKUP_DIR/*.zip 2>/dev/null)" ]; then
        ls -la $BACKUP_DIR/*.zip | awk '{print NR". "$9" ("$5" bytes) - "$6" "$7" "$8}'
    else
        echo "Không có backup nào"
    fi
    echo ""
}

restore_from_local() {
    list_local_backups
    echo -e "${YELLOW}Nhập đường dẫn file backup (hoặc số thứ tự):${NC}"
    read -r backup_input
    
    # Kiểm tra nếu là số thứ tự
    if [[ "$backup_input" =~ ^[0-9]+$ ]]; then
        backup_file=$(ls $BACKUP_DIR/*.zip 2>/dev/null | sed -n "${backup_input}p")
    else
        backup_file="$backup_input"
    fi
    
    if [ ! -f "$backup_file" ]; then
        log "${RED}[ERROR] File backup không tồn tại: $backup_file"
        return 1
    fi
    
    restore_backup "$backup_file"
}

restore_from_gdrive() {
    if [ ! -f "$SCRIPT_DIR/scripts/gdrive_download.py" ]; then
        log "${RED}[ERROR] Google Drive không được cấu hình"
        return 1
    fi
    
    echo -e "${YELLOW}📋 Danh sách backup trên Google Drive:${NC}"
    python3 $SCRIPT_DIR/scripts/gdrive_download.py --list
    
    echo -e "${YELLOW}Nhập tên file backup để download:${NC}"
    read -r backup_name
    
    temp_file="/tmp/$backup_name"
    if python3 $SCRIPT_DIR/scripts/gdrive_download.py "$backup_name" "$temp_file"; then
        restore_backup "$temp_file"
        rm -f "$temp_file"
    else
        log "${RED}[ERROR] Không thể download backup từ Google Drive"
        return 1
    fi
}

restore_backup() {
    local backup_file="$1"
    
    log "${YELLOW}🔄 Bắt đầu restore từ: $(basename $backup_file)"
    
    # Xác nhận
    echo -e "${RED}⚠️  CẢNH BÁO: Restore sẽ ghi đè tất cả dữ liệu hiện tại!${NC}"
    echo -e "${YELLOW}Bạn có chắc chắn muốn tiếp tục? (yes/no):${NC}"
    read -r confirm
    if [ "$confirm" != "yes" ]; then
        log "${YELLOW}[INFO] Hủy restore"
        return 0
    fi
    
    # Dừng containers
    log "${YELLOW}🛑 Dừng N8N containers..."
    cd $SCRIPT_DIR
    docker-compose down
    
    # Backup dữ liệu hiện tại
    log "${YELLOW}💾 Backup dữ liệu hiện tại..."
    backup_current_date=$(date +%Y%m%d_%H%M%S)
    mkdir -p $BACKUP_DIR/pre-restore
    zip -r "$BACKUP_DIR/pre-restore/pre_restore_$backup_current_date.zip" \
        data/ docker-compose.yml Caddyfile .env 2>/dev/null || true
    
    # Giải nén backup
    log "${YELLOW}📦 Giải nén backup..."
    temp_restore_dir="/tmp/n8n_restore_$$"
    mkdir -p $temp_restore_dir
    unzip -q "$backup_file" -d $temp_restore_dir
    
    # Restore dữ liệu
    log "${YELLOW}🔄 Restore dữ liệu..."
    
    # Restore database và workflows
    if [ -d "$temp_restore_dir/data" ]; then
        rm -rf $SCRIPT_DIR/data/*
        cp -r $temp_restore_dir/data/* $SCRIPT_DIR/data/
    fi
    
    # Restore cấu hình
    [ -f "$temp_restore_dir/docker-compose.yml" ] && cp "$temp_restore_dir/docker-compose.yml" $SCRIPT_DIR/
    [ -f "$temp_restore_dir/Caddyfile" ] && cp "$temp_restore_dir/Caddyfile" $SCRIPT_DIR/
    [ -f "$temp_restore_dir/.env" ] && cp "$temp_restore_dir/.env" $SCRIPT_DIR/
    
    # Cleanup
    rm -rf $temp_restore_dir
    
    # Khởi động lại
    log "${YELLOW}🚀 Khởi động lại N8N..."
    docker-compose up -d
    
    # Đợi khởi động
    sleep 30
    
    # Kiểm tra trạng thái
    if docker-compose ps | grep -q "Up"; then
        log "${GREEN}[SUCCESS] ✅ Restore thành công!"
        log "${GREEN}[INFO] 🌐 N8N: http://localhost:5678"
        if [ "$USE_DOMAIN" = true ]; then
            log "${GREEN}[INFO] 🌐 Domain: https://$DOMAIN"
        fi
    else
        log "${RED}[ERROR] ❌ Có lỗi khi khởi động sau restore"
        log "${YELLOW}[INFO] Restore lại từ backup pre-restore nếu cần"
    fi
}

# Main menu
while true; do
    show_restore_menu
    echo -e "${YELLOW}Chọn tùy chọn (1-4):${NC}"
    read -r choice
    
    case $choice in
        1)
            restore_from_local
            ;;
        2)
            restore_from_gdrive
            ;;
        3)
            list_local_backups
            if [ -f "$SCRIPT_DIR/scripts/gdrive_download.py" ]; then
                echo -e "${YELLOW}📋 Backup trên Google Drive:${NC}"
                python3 $SCRIPT_DIR/scripts/gdrive_download.py --list
            fi
            echo ""
            ;;
        4)
            log "${GREEN}👋 Thoát restore system"
            exit 0
            ;;
        *)
            echo -e "${RED}Lựa chọn không hợp lệ${NC}"
            ;;
    esac
    
    echo -e "${YELLOW}Nhấn Enter để tiếp tục...${NC}"
    read
done
EOF

    chmod +x $SCRIPT_DIR/scripts/restore.sh

    # Tạo Google Drive download script nếu cần
    if [ "$GOOGLE_DRIVE_ENABLED" = true ]; then
        cat > $SCRIPT_DIR/scripts/gdrive_download.py << EOF
#!/usr/bin/env python3

import os
import sys
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload
from google.oauth2 import service_account
import io

# Cấu hình
CREDENTIALS_FILE = '/home/n8n/google-credentials/credentials.json'
FOLDER_ID = '$GOOGLE_FOLDER_ID'
SCOPES = ['https://www.googleapis.com/auth/drive.readonly']

def list_backups():
    try:
        credentials = service_account.Credentials.from_service_account_file(
            CREDENTIALS_FILE, scopes=SCOPES)
        service = build('drive', 'v3', credentials=credentials)
        
        query = f"parents in '{FOLDER_ID}' and name contains 'n8n_backup_'"
        results = service.files().list(
            q=query,
            orderBy='createdTime desc',
            fields='files(id, name, size, createdTime)'
        ).execute()
        
        files = results.get('files', [])
        
        if not files:
            print("Không có backup nào trên Google Drive")
            return
        
        print("Danh sách backup trên Google Drive:")
        for i, file in enumerate(files, 1):
            size_mb = int(file.get('size', 0)) / (1024*1024)
            print(f"{i}. {file['name']} ({size_mb:.1f}MB) - {file['createdTime']}")
            
    except Exception as e:
        print(f"Lỗi liệt kê backup: {str(e)}")

def download_backup(file_name, output_path):
    try:
        credentials = service_account.Credentials.from_service_account_file(
            CREDENTIALS_FILE, scopes=SCOPES)
        service = build('drive', 'v3', credentials=credentials)
        
        # Tìm file
        query = f"parents in '{FOLDER_ID}' and name = '{file_name}'"
        results = service.files().list(q=query).execute()
        files = results.get('files', [])
        
        if not files:
            print(f"Không tìm thấy file: {file_name}")
            return False
        
        file_id = files[0]['id']
        
        # Download
        request = service.files().get_media(fileId=file_id)
        fh = io.BytesIO()
        downloader = MediaIoBaseDownload(fh, request)
        
        done = False
        while done is False:
            status, done = downloader.next_chunk()
            print(f"Download {int(status.progress() * 100)}%")
        
        # Lưu file
        with open(output_path, 'wb') as f:
            f.write(fh.getvalue())
        
        print(f"Download thành công: {output_path}")
        return True
        
    except Exception as e:
        print(f"Lỗi download: {str(e)}")
        return False

if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--list":
        list_backups()
    elif len(sys.argv) == 3:
        file_name = sys.argv[1]
        output_path = sys.argv[2]
        success = download_backup(file_name, output_path)
        sys.exit(0 if success else 1)
    else:
        print("Usage:")
        print("  python3 gdrive_download.py --list")
        print("  python3 gdrive_download.py <file_name> <output_path>")
        sys.exit(1)
EOF

        chmod +x $SCRIPT_DIR/scripts/gdrive_download.py
    fi

    log "${GREEN}[SUCCESS] Đã tạo hệ thống restore"
}

# Hàm tạo auto-update script
create_auto_update_script() {
    if [ "$AUTO_UPDATE" = false ]; then
        return 0
    fi

    log "${YELLOW}🔄 Tạo script auto-update..."
    
    cat > $SCRIPT_DIR/scripts/auto_update.sh << 'EOF'
#!/bin/bash

# Script auto-update N8N và dependencies

SCRIPT_DIR="/home/n8n"
LOG_FILE="$SCRIPT_DIR/logs/auto_update.log"

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# Tạo thư mục logs
mkdir -p $SCRIPT_DIR/logs

log "${YELLOW}🔄 Bắt đầu auto-update N8N..."

cd $SCRIPT_DIR

# Backup trước khi update
log "${YELLOW}💾 Tạo backup trước update..."
$SCRIPT_DIR/scripts/backup.sh

# Pull latest images
log "${YELLOW}📦 Pull latest Docker images..."
docker-compose pull

# Rebuild và restart
log "${YELLOW}🔄 Rebuild và restart containers..."
docker-compose up -d --build

# Update yt-dlp trong container
log "${YELLOW}📺 Update yt-dlp..."
docker-compose exec -T n8n /usr/local/bin/update-ytdlp.sh || true

# Kiểm tra trạng thái
sleep 30
if docker-compose ps | grep -q "Up"; then
    log "${GREEN}[SUCCESS] ✅ Auto-update thành công"
    
    # Gửi thông báo qua Telegram
    if [ -f "$SCRIPT_DIR/.env" ]; then
        source $SCRIPT_DIR/.env
        if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
            curl -s -X POST \
                "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
                -d chat_id="$TELEGRAM_CHAT_ID" \
                -d text="✅ N8N Auto-Update thành công - $(date '+%Y-%m-%d %H:%M:%S')" >/dev/null
        fi
    fi
else
    log "${RED}[ERROR] ❌ Auto-update thất bại"
    
    # Gửi cảnh báo qua Telegram
    if [ -f "$SCRIPT_DIR/.env" ]; then
        source $SCRIPT_DIR/.env
        if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
            curl -s -X POST \
                "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
                -d chat_id="$TELEGRAM_CHAT_ID" \
                -d text="❌ N8N Auto-Update thất bại - $(date '+%Y-%m-%d %H:%M:%S')" >/dev/null
        fi
    fi
fi

log "${GREEN}🎉 Hoàn thành auto-update"
EOF

    chmod +x $SCRIPT_DIR/scripts/auto_update.sh
    
    log "${GREEN}[SUCCESS] Đã tạo script auto-update"
}

# Hàm tạo SSL renewal script với ZeroSSL fallback
create_ssl_renewal_script() {
    if [ "$USE_DOMAIN" = false ]; then
        return 0
    fi

    log "${YELLOW}🔒 Tạo script SSL renewal..."
    
    cat > $SCRIPT_DIR/scripts/ssl_renewal.sh << EOF
#!/bin/bash

# Script tự động gia hạn SSL với ZeroSSL fallback

SCRIPT_DIR="/home/n8n"
LOG_FILE="\$SCRIPT_DIR/logs/ssl_renewal.log"

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" | tee -a \$LOG_FILE
}

# Tạo thư mục logs
mkdir -p \$SCRIPT_DIR/logs

log "\${YELLOW}🔒 Kiểm tra SSL certificate..."

cd \$SCRIPT_DIR

# Kiểm tra SSL certificate hiện tại
check_ssl_expiry() {
    local domain="\$1"
    local expiry_date=\$(echo | openssl s_client -servername \$domain -connect \$domain:443 2>/dev/null | openssl x509 -noout -dates | grep notAfter | cut -d= -f2)
    
    if [ -n "\$expiry_date" ]; then
        local expiry_timestamp=\$(date -d "\$expiry_date" +%s)
        local current_timestamp=\$(date +%s)
        local days_until_expiry=\$(( (expiry_timestamp - current_timestamp) / 86400 ))
        
        echo \$days_until_expiry
    else
        echo "0"
    fi
}

# Kiểm tra rate limit từ logs
check_rate_limit() {
    local recent_logs=\$(docker-compose logs caddy --tail=50 2>/dev/null | grep -i "rate.*limit\\|too many certificates" | tail -1)
    
    if [ -n "\$recent_logs" ]; then
        # Trích xuất thời gian retry từ log
        local retry_time=\$(echo "\$recent_logs" | grep -oP 'retry after \K[0-9-]+ [0-9:]+' | head -1)
        if [ -n "\$retry_time" ]; then
            local retry_timestamp=\$(date -d "\$retry_time UTC" +%s 2>/dev/null || echo "0")
            local current_timestamp=\$(date +%s)
            
            if [ \$retry_timestamp -gt \$current_timestamp ]; then
                local hours_until_retry=\$(( (retry_timestamp - current_timestamp) / 3600 ))
                echo "rate_limit:\$hours_until_retry"
                return 0
            fi
        fi
    fi
    
    echo "ok"
}

# Chuyển sang ZeroSSL
switch_to_zerossl() {
    log "\${YELLOW}🔄 Chuyển sang ZeroSSL..."
    
    # Backup Caddyfile hiện tại
    cp Caddyfile Caddyfile.backup.\$(date +%Y%m%d_%H%M%S)
    
    # Cập nhật Caddyfile với ZeroSSL
    sed -i 's|acme_ca.*|acme_ca https://acme.zerossl.com/v2/DV90|' Caddyfile
    
    # Xóa SSL data cũ
    docker-compose down
    docker volume rm n8n_caddy_data n8n_caddy_config 2>/dev/null || true
    
    # Khởi động lại với ZeroSSL
    docker-compose up -d
    
    log "\${GREEN}[SUCCESS] Đã chuyển sang ZeroSSL"
}

# Chuyển về Let's Encrypt
switch_to_letsencrypt() {
    log "\${YELLOW}🔄 Chuyển về Let's Encrypt..."
    
    # Backup Caddyfile hiện tại
    cp Caddyfile Caddyfile.backup.\$(date +%Y%m%d_%H%M%S)
    
    # Cập nhật Caddyfile với Let's Encrypt
    sed -i 's|acme_ca.*|acme_ca https://acme-v02.api.letsencrypt.org/directory|' Caddyfile
    
    # Xóa SSL data cũ
    docker-compose down
    docker volume rm n8n_caddy_data n8n_caddy_config 2>/dev/null || true
    
    # Khởi động lại với Let's Encrypt
    docker-compose up -d
    
    log "\${GREEN}[SUCCESS] Đã chuyển về Let's Encrypt"
}

# Main logic
main() {
    local domain="$DOMAIN"
    local days_until_expiry=\$(check_ssl_expiry \$domain)
    local rate_limit_status=\$(check_rate_limit)
    
    log "\${GREEN}[INFO] Domain: \$domain"
    log "\${GREEN}[INFO] SSL expires in: \$days_until_expiry days"
    log "\${GREEN}[INFO] Rate limit status: \$rate_limit_status"
    
    # Nếu SSL sắp hết hạn (< 30 ngày)
    if [ \$days_until_expiry -lt 30 ]; then
        log "\${YELLOW}⚠️  SSL certificate sắp hết hạn (\$days_until_expiry ngày)"
        
        # Kiểm tra rate limit
        if [[ \$rate_limit_status == rate_limit:* ]]; then
            local hours_until_retry=\${rate_limit_status#rate_limit:}
            log "\${YELLOW}⚠️  Let's Encrypt rate limit - còn \$hours_until_retry giờ"
            
            # Chuyển sang ZeroSSL nếu còn rate limit
            if [ \$hours_until_retry -gt 0 ]; then
                switch_to_zerossl
            else
                log "\${GREEN}[INFO] Rate limit đã hết, thử lại Let's Encrypt"
                switch_to_letsencrypt
            fi
        else
            log "\${GREEN}[INFO] Không có rate limit, gia hạn SSL"
            # Force renewal
            docker-compose restart caddy
        fi
    else
        log "\${GREEN}[INFO] SSL certificate còn hạn (\$days_until_expiry ngày)"
    fi
    
    # Gửi thông báo qua Telegram
    if [ -f "\$SCRIPT_DIR/.env" ]; then
        source \$SCRIPT_DIR/.env
        if [ -n "\$TELEGRAM_BOT_TOKEN" ] && [ -n "\$TELEGRAM_CHAT_ID" ]; then
            curl -s -X POST \\
                "https://api.telegram.org/bot\$TELEGRAM_BOT_TOKEN/sendMessage" \\
                -d chat_id="\$TELEGRAM_CHAT_ID" \\
                -d text="🔒 SSL Check: \$domain - Còn \$days_until_expiry ngày - \$(date '+%Y-%m-%d %H:%M:%S')" >/dev/null
        fi
    fi
}

main
log "\${GREEN}🎉 Hoàn thành kiểm tra SSL"
EOF

    chmod +x $SCRIPT_DIR/scripts/ssl_renewal.sh
    
    log "${GREEN}[SUCCESS] Đã tạo script SSL renewal"
}

# Hàm tạo diagnostic script
create_diagnostic_script() {
    log "${YELLOW}🔧 Tạo script chẩn đoán..."
    
    cat > $SCRIPT_DIR/scripts/diagnose.sh << 'EOF'
#!/bin/bash

# Script chẩn đoán N8N

SCRIPT_DIR="/home/n8n"

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                        🔧 N8N DIAGNOSTIC TOOL                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}🔍 Kiểm tra trạng thái hệ thống...${NC}"
echo ""

# Kiểm tra Docker
echo -e "${BLUE}🐳 Docker Status:${NC}"
if command -v docker &> /dev/null; then
    echo -e "  ✅ Docker: $(docker --version)"
    echo -e "  ✅ Docker Compose: $(docker-compose --version)"
else
    echo -e "  ❌ Docker chưa được cài đặt"
fi
echo ""

# Kiểm tra containers
echo -e "${BLUE}📦 Container Status:${NC}"
cd $SCRIPT_DIR 2>/dev/null || { echo "❌ Thư mục N8N không tồn tại"; exit 1; }

if [ -f "docker-compose.yml" ]; then
    docker-compose ps
else
    echo "❌ docker-compose.yml không tồn tại"
fi
echo ""

# Kiểm tra ports
echo -e "${BLUE}🌐 Port Status:${NC}"
netstat -tlnp | grep -E ':5678|:8000|:80|:443' || echo "Không có port nào đang lắng nghe"
echo ""

# Kiểm tra SSL
echo -e "${BLUE}🔒 SSL Status:${NC}"
if [ -f ".env" ]; then
    source .env
    if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "localhost" ]; then
        echo "Kiểm tra SSL cho domain: $DOMAIN"
        echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "❌ Không thể kiểm tra SSL"
    else
        echo "ℹ️  Sử dụng localhost (không SSL)"
    fi
else
    echo "❌ File .env không tồn tại"
fi
echo ""

# Kiểm tra logs
echo -e "${BLUE}📋 Recent Logs:${NC}"
echo -e "${YELLOW}N8N Logs (10 dòng cuối):${NC}"
docker-compose logs n8n --tail=10 2>/dev/null || echo "❌ Không thể lấy logs N8N"
echo ""

if docker-compose ps | grep -q "caddy"; then
    echo -e "${YELLOW}Caddy Logs (10 dòng cuối):${NC}"
    docker-compose logs caddy --tail=10 2>/dev/null || echo "❌ Không thể lấy logs Caddy"
    echo ""
fi

# Kiểm tra disk space
echo -e "${BLUE}💾 Disk Usage:${NC}"
df -h | grep -E "/$|/home"
echo ""

# Kiểm tra memory
echo -e "${BLUE}🧠 Memory Usage:${NC}"
free -h
echo ""

# Kiểm tra backup
echo -e "${BLUE}💾 Backup Status:${NC}"
if [ -d "backups" ]; then
    backup_count=$(ls backups/*.zip 2>/dev/null | wc -l)
    echo "📁 Số lượng backup: $backup_count"
    if [ $backup_count -gt 0 ]; then
        echo "📅 Backup mới nhất:"
        ls -la backups/*.zip | tail -1
    fi
else
    echo "❌ Thư mục backup không tồn tại"
fi
echo ""

# Kiểm tra cron jobs
echo -e "${BLUE}⏰ Cron Jobs:${NC}"
crontab -l 2>/dev/null | grep -E "backup|update|ssl" || echo "Không có cron job nào"
echo ""

echo -e "${GREEN}🎉 Hoàn thành chẩn đoán hệ thống${NC}"
echo ""
echo -e "${YELLOW}📋 Các lệnh hữu ích:${NC}"
echo -e "  • Xem logs: ${CYAN}docker-compose logs -f${NC}"
echo -e "  • Restart: ${CYAN}docker-compose restart${NC}"
echo -e "  • Backup: ${CYAN}$SCRIPT_DIR/scripts/backup.sh${NC}"
echo -e "  • Restore: ${CYAN}$SCRIPT_DIR/scripts/restore.sh${NC}"
echo -e "  • Update: ${CYAN}$SCRIPT_DIR/scripts/auto_update.sh${NC}"
EOF

    chmod +x $SCRIPT_DIR/scripts/diagnose.sh
    
    log "${GREEN}[SUCCESS] Đã tạo script chẩn đoán"
}

# Hàm thiết lập cron jobs
setup_cron_jobs() {
    log "${YELLOW}⏰ Thiết lập cron jobs..."
    
    # Tạo cron jobs
    cron_jobs=""
    
    # Backup hàng ngày lúc 2:00 AM
    cron_jobs+="0 2 * * * $SCRIPT_DIR/scripts/backup.sh\n"
    
    # Auto-update nếu được bật
    if [ "$AUTO_UPDATE" = true ]; then
        cron_jobs+="0 */12 * * * $SCRIPT_DIR/scripts/auto_update.sh\n"
    fi
    
    # SSL renewal check hàng ngày
    if [ "$USE_DOMAIN" = true ]; then
        cron_jobs+="0 3 * * * $SCRIPT_DIR/scripts/ssl_renewal.sh\n"
    fi
    
    # Cài đặt cron jobs
    echo -e "$cron_jobs" | crontab -
    
    log "${GREEN}[SUCCESS] Đã thiết lập cron jobs"
}

# Hàm tạo file .env
create_env_file() {
    log "${YELLOW}🔧 Tạo file .env..."
    
    cat > $SCRIPT_DIR/.env << EOF
# N8N Configuration
N8N_PASSWORD=admin123456
N8N_HOST=${DOMAIN}
N8N_PROTOCOL=${USE_DOMAIN:+https}${USE_DOMAIN:-http}
WEBHOOK_URL=${USE_DOMAIN:+https://$DOMAIN}${USE_DOMAIN:-http://localhost:5678}

# Domain Configuration
DOMAIN=${DOMAIN}
API_DOMAIN=${API_DOMAIN}
USE_DOMAIN=${USE_DOMAIN}

# SSL Configuration
SSL_PROVIDER=${SSL_PROVIDER}
ZEROSSL_EMAIL=${ZEROSSL_EMAIL}

# News API Configuration
NEWS_TOKEN=${NEWS_TOKEN}

# Telegram Configuration
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}

# Google Drive Configuration
GOOGLE_DRIVE_ENABLED=${GOOGLE_DRIVE_ENABLED}
GOOGLE_FOLDER_ID=${GOOGLE_FOLDER_ID}

# System Configuration
AUTO_UPDATE=${AUTO_UPDATE}
SCRIPT_VERSION=2.0.0
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')
EOF

    log "${GREEN}[SUCCESS] Đã tạo file .env"
}

# Hàm build và deploy containers
build_and_deploy() {
    log "${YELLOW}🏗️ Build và deploy containers..."
    
    cd $SCRIPT_DIR
    
    # Dừng containers cũ
    log "${YELLOW}🛑 Dừng containers cũ..."
    docker-compose down 2>/dev/null || true
    
    # Build Docker images
    log "${YELLOW}📦 Build Docker images..."
    docker-compose build --no-cache
    
    # Khởi động services
    log "${YELLOW}🚀 Khởi động services..."
    docker-compose up -d
    
    # Đợi services khởi động
    log "${YELLOW}⏳ Đợi services khởi động..."
    sleep 30
    
    # Kiểm tra trạng thái containers
    log "${YELLOW}🔍 Kiểm tra trạng thái containers..."
    if docker-compose ps | grep -q "Up"; then
        log "${GREEN}[SUCCESS] ✅ Containers đã khởi động thành công"
    else
        log "${RED}[ERROR] ❌ Có lỗi khi khởi động containers"
        docker-compose logs
        exit 1
    fi
}

# Hàm kiểm tra SSL với phân tích thông minh
check_ssl_status() {
    if [ "$USE_DOMAIN" = false ]; then
        return 0
    fi

    log "${YELLOW}🔒 Kiểm tra SSL certificate..."
    
    # Đợi Caddy khởi động và thử cấp SSL
    sleep 60
    
    # Lấy logs Caddy gần đây
    local caddy_logs=$(docker-compose logs caddy --tail=100 2>/dev/null)
    
    # Kiểm tra xem có SSL thành công không
    if echo "$caddy_logs" | grep -q "certificate obtained successfully"; then
        log "${GREEN}[SUCCESS] ✅ SSL certificate đã được cấp thành công"
        return 0
    fi
    
    # Kiểm tra rate limit
    local rate_limit_info=$(echo "$caddy_logs" | grep -i "rate.*limit\|too many certificates" | tail -1)
    
    if [ -n "$rate_limit_info" ]; then
        # Trích xuất thời gian retry
        local retry_time=$(echo "$rate_limit_info" | grep -oP 'retry after \K[0-9-]+ [0-9:]+' | head -1)
        
        if [ -n "$retry_time" ]; then
            # Chuyển đổi sang giờ VN
            local retry_timestamp=$(date -d "$retry_time UTC" +%s 2>/dev/null || echo "0")
            local current_timestamp=$(date +%s)
            local vn_retry_time=$(date -d "@$retry_timestamp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Không xác định")
            
            show_ssl_rate_limit_error "$vn_retry_time" "$caddy_logs"
        else
            show_ssl_rate_limit_error "Không xác định" "$caddy_logs"
        fi
    else
        # Kiểm tra các lỗi SSL khác
        if echo "$caddy_logs" | grep -q -i "error\|failed"; then
            log "${RED}[ERROR] 🚨 Có lỗi khi cấp SSL certificate"
            echo "$caddy_logs" | grep -i "error\|failed" | tail -5
        else
            log "${YELLOW}[WARNING] ⚠️ SSL certificate chưa được cấp, có thể đang trong quá trình xử lý"
        fi
    fi
}

# Hàm hiển thị lỗi SSL rate limit
show_ssl_rate_limit_error() {
    local retry_time="$1"
    local logs="$2"
    
    echo -e "${RED}[ERROR] 🚨 PHÁT HIỆN SSL RATE LIMIT!${NC}"
    echo ""
    echo -e "${CYAN}"
    cat << "EOF"
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
    
    echo -e "${BLUE}💡 GIẢI PHÁP:${NC}"
    echo -e "  ${GREEN}1. CÀI LẠI UBUNTU (KHUYẾN NGHỊ):${NC}"
    echo -e "     • Cài lại Ubuntu Server hoàn toàn"
    echo -e "     • Sử dụng subdomain khác (vd: n8n2.domain.com)"
    echo -e "     • Chạy lại script này"
    echo ""
    echo -e "  ${GREEN}2. SỬ DỤNG ZEROSSL (TỰ ĐỘNG):${NC}"
    echo -e "     • Script sẽ tự động chuyển sang ZeroSSL"
    echo -e "     • SSL certificate vẫn hợp lệ và bảo mật"
    echo -e "     • Tự động gia hạn sau 90 ngày"
    echo ""
    echo -e "  ${GREEN}3. ĐỢI ĐẾN KHI RATE LIMIT RESET:${NC}"
    echo -e "     • Đợi đến sau $retry_time (Giờ VN)"
    echo -e "     • Chạy lại script để cấp SSL mới"
    echo ""
    
    echo -e "${YELLOW}📋 LỊCH SỬ SSL ATTEMPTS GẦN ĐÂY:${NC}"
    echo "$logs" | grep -E "certificate obtained|rate.*limit|too many certificates|error" | tail -5 | sed 's/^/• /'
    echo ""
    
    echo -e "${YELLOW}🤔 Bạn muốn tiếp tục với ZeroSSL? (Y/n):${NC}"
    read -r ssl_choice
    
    if [[ ! $ssl_choice =~ ^[Nn]$ ]]; then
        log "${YELLOW}🔄 Chuyển sang ZeroSSL..."
        switch_to_zerossl_now
    else
        echo ""
        echo -e "${BLUE}📋 HƯỚNG DẪN CÀI LẠI UBUNTU:${NC}"
        echo -e "  1. Backup dữ liệu quan trọng"
        echo -e "  2. Cài lại Ubuntu Server từ đầu"
        echo -e "  3. Sử dụng subdomain khác hoặc domain khác"
        echo -e "  4. Chạy lại script: ${CYAN}curl -sSL https://raw.githubusercontent.com/KalvinThien/install-n8n-ffmpeg/main/auto_cai_dat_n8n.sh | bash${NC}"
        echo ""
        exit 1
    fi
}

# Hàm chuyển sang ZeroSSL ngay lập tức
switch_to_zerossl_now() {
    log "${YELLOW}🔄 Đang chuyển sang ZeroSSL..."
    
    cd $SCRIPT_DIR
    
    # Backup Caddyfile
    cp Caddyfile Caddyfile.backup.$(date +%Y%m%d_%H%M%S)
    
    # Cập nhật Caddyfile với ZeroSSL
    sed -i 's|acme_ca.*|acme_ca https://acme.zerossl.com/v2/DV90|' Caddyfile
    
    # Cập nhật .env
    sed -i 's|SSL_PROVIDER=.*|SSL_PROVIDER=zerossl|' .env
    
    # Xóa SSL data cũ và restart
    docker-compose down
    docker volume rm n8n_caddy_data n8n_caddy_config 2>/dev/null || true
    docker-compose up -d
    
    log "${GREEN}[SUCCESS] ✅ Đã chuyển sang ZeroSSL"
    
    # Đợi và kiểm tra SSL mới
    log "${YELLOW}⏳ Đợi ZeroSSL cấp certificate..."
    sleep 90
    
    local zerossl_logs=$(docker-compose logs caddy --tail=50 2>/dev/null)
    if echo "$zerossl_logs" | grep -q "certificate obtained successfully"; then
        log "${GREEN}[SUCCESS] 🎉 ZeroSSL certificate đã được cấp thành công!"
    else
        log "${YELLOW}[WARNING] ⚠️ ZeroSSL đang trong quá trình cấp certificate"
        log "${YELLOW}[INFO] Vui lòng đợi thêm vài phút và kiểm tra lại"
    fi
}

# Hàm hiển thị thông tin hoàn thành
show_completion_info() {
    echo ""
    echo -e "${GREEN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🎉 CÀI ĐẶT N8N HOÀN TẤT THÀNH CÔNG! 🎉                   ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo -e "${CYAN}📋 THÔNG TIN TRUY CẬP:${NC}"
    if [ "$USE_DOMAIN" = true ]; then
        echo -e "  🌐 N8N Interface: ${GREEN}https://$DOMAIN${NC}"
        if [[ -n "$NEWS_TOKEN" ]]; then
            echo -e "  📰 News API: ${GREEN}https://$API_DOMAIN${NC}"
        fi
    else
        echo -e "  🌐 N8N Interface: ${GREEN}http://localhost:5678${NC}"
        if [[ -n "$NEWS_TOKEN" ]]; then
            echo -e "  📰 News API: ${GREEN}http://localhost:8000${NC}"
        fi
    fi
    echo -e "  👤 Username: ${YELLOW}admin${NC}"
    echo -e "  🔑 Password: ${YELLOW}admin123456${NC}"
    echo ""
    
    if [[ -n "$NEWS_TOKEN" ]]; then
        echo -e "${CYAN}🔐 NEWS API AUTHENTICATION:${NC}"
        echo -e "  🔑 Bearer Token: ${YELLOW}$NEWS_TOKEN${NC}"
        echo -e "  📖 API Docs: ${GREEN}https://$API_DOMAIN/docs${NC} (nếu dùng domain)"
        echo ""
    fi
    
    echo -e "${CYAN}🛠️ QUẢN LÝ HỆ THỐNG:${NC}"
    echo -e "  📁 Thư mục cài đặt: ${YELLOW}$SCRIPT_DIR${NC}"
    echo -e "  🔧 Chẩn đoán: ${YELLOW}$SCRIPT_DIR/scripts/diagnose.sh${NC}"
    echo -e "  💾 Backup: ${YELLOW}$SCRIPT_DIR/scripts/backup.sh${NC}"
    echo -e "  🔄 Restore: ${YELLOW}$SCRIPT_DIR/scripts/restore.sh${NC}"
    if [ "$AUTO_UPDATE" = true ]; then
        echo -e "  🔄 Auto-Update: ${GREEN}Đã bật${NC} (mỗi 12 giờ)"
    fi
    echo ""
    
    echo -e "${CYAN}📱 BACKUP CONFIGURATION:${NC}"
    echo -e "  💾 Backup tự động: ${GREEN}Hàng ngày lúc 2:00 AM${NC}"
    if [[ -n "$TELEGRAM_BOT_TOKEN" ]]; then
        echo -e "  📱 Telegram Backup: ${GREEN}Đã cấu hình${NC}"
    fi
    if [ "$GOOGLE_DRIVE_ENABLED" = true ]; then
        echo -e "  ☁️  Google Drive Backup: ${GREEN}Đã cấu hình${NC}"
    fi
    echo ""
    
    if [ "$USE_DOMAIN" = true ]; then
        echo -e "${CYAN}🔒 SSL CERTIFICATE:${NC}"
        case $SSL_PROVIDER in
            "letsencrypt")
                echo -e "  🔐 Provider: ${GREEN}Let's Encrypt${NC}"
                ;;
            "zerossl")
                echo -e "  🔐 Provider: ${GREEN}ZeroSSL${NC}"
                ;;
            "auto")
                echo -e "  🔐 Provider: ${GREEN}Auto (Let's Encrypt → ZeroSSL)${NC}"
                ;;
        esac
        echo -e "  🔄 Auto-renewal: ${GREEN}Đã cấu hình${NC}"
        echo ""
    fi
    
    echo -e "${YELLOW}⚠️  LƯU Ý QUAN TRỌNG:${NC}"
    echo -e "  • Đổi mật khẩu mặc định sau khi đăng nhập"
    echo -e "  • Backup định kỳ được lưu tại: $SCRIPT_DIR/backups"
    echo -e "  • Logs hệ thống tại: $SCRIPT_DIR/logs"
    echo -e "  • Sử dụng script chẩn đoán để kiểm tra trạng thái"
    echo ""
    
    echo -e "${GREEN}🎬 ĐĂNG KÝ KÊNH YOUTUBE ĐỂ ỦNG HỘ:${NC}"
    echo -e "  📺 ${CYAN}https://www.youtube.com/@kalvinthiensocial${NC}"
    echo -e "  📱 Zalo: ${CYAN}08.8888.4749${NC}"
    echo ""
    
    echo -e "${GREEN}🚀 Chúc bạn sử dụng N8N hiệu quả! 🚀${NC}"
}

# Main function
main() {
    show_header
    
    # Kiểm tra quyền root
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[ERROR] Script cần chạy với quyền root${NC}"
        echo "Sử dụng: sudo bash $0"
        exit 1
    fi
    
    # Thiết lập swap
    setup_swap
    
    # Cấu hình domain
    configure_domain
    
    # Kiểm tra DNS
    check_dns
    
    # Cleanup cài đặt cũ
    cleanup_old_installation
    
    # Cài đặt Docker
    install_docker
    
    # Cấu hình các services
    configure_news_api
    configure_telegram_backup
    configure_google_drive_backup
    configure_auto_update
    configure_ssl_provider
    
    # Tạo cấu trúc
    create_directory_structure
    create_n8n_dockerfile
    create_news_api
    create_docker_compose
    create_caddyfile
    create_env_file
    
    # Tạo các scripts
    create_backup_system
    create_restore_system
    create_auto_update_script
    create_ssl_renewal_script
    create_diagnostic_script
    
    # Thiết lập cron jobs
    setup_cron_jobs
    
    # Build và deploy
    build_and_deploy
    
    # Kiểm tra SSL
    check_ssl_status
    
    # Hiển thị thông tin hoàn thành
    show_completion_info
}

# Chạy script
main "$@"
