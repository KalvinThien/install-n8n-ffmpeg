#!/bin/bash

# Hiển thị banner
echo "======================================================================"
echo "     Script cài đặt N8N với FFmpeg, yt-dlp, Puppeteer và SSL tự động  "
echo "                (Phiên bản cải tiến với News API & Telegram Backup)             "
echo "======================================================================"

# Kiểm tra xem script có được chạy với quyền root không
if [[ $EUID -ne 0 ]]; then
   echo "Script này cần được chạy với quyền root" 
   exit 1
fi

# Suppress interactive prompts
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

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
}

# Hàm hiển thị trợ giúp
show_help() {
    echo "Cách sử dụng: $0 [tùy chọn]"
    echo "Tùy chọn:"
    echo "  -h, --help      Hiển thị trợ giúp này"
    echo "  -d, --dir DIR   Chỉ định thư mục cài đặt n8n (mặc định: /home/n8n)"
    echo "  -s, --skip-docker Bỏ qua cài đặt Docker (nếu đã có)"
    echo "  --clean         Xóa tất cả cài đặt N8N cũ và tạo mới"
    exit 0
}

# Hàm cleanup Docker và N8N cũ
cleanup_old_installation() {
    echo "🧹 Đang tìm kiếm và dọn dẹp cài đặt N8N cũ..."
    
    # Tìm và dừng tất cả containers liên quan đến N8N
    echo "Tìm kiếm containers N8N..."
    N8N_CONTAINERS=$(docker ps -a --filter "name=n8n" --format "{{.Names}}" 2>/dev/null || true)
    CADDY_CONTAINERS=$(docker ps -a --filter "name=caddy" --format "{{.Names}}" 2>/dev/null || true)
    FASTAPI_CONTAINERS=$(docker ps -a --filter "name=fastapi" --format "{{.Names}}" 2>/dev/null || true)
    
    if [ -n "$N8N_CONTAINERS" ] || [ -n "$CADDY_CONTAINERS" ] || [ -n "$FASTAPI_CONTAINERS" ]; then
        echo "Tìm thấy containers cũ:"
        [ -n "$N8N_CONTAINERS" ] && echo "  - N8N: $N8N_CONTAINERS"
        [ -n "$CADDY_CONTAINERS" ] && echo "  - Caddy: $CADDY_CONTAINERS"
        [ -n "$FASTAPI_CONTAINERS" ] && echo "  - FastAPI: $FASTAPI_CONTAINERS"
        
        echo "Đang dừng và xóa containers..."
        for container in $N8N_CONTAINERS $CADDY_CONTAINERS $FASTAPI_CONTAINERS; do
            docker stop "$container" 2>/dev/null || true
            docker rm "$container" 2>/dev/null || true
            echo "  ✅ Đã xóa container: $container"
        done
    fi
    
    # Tìm và xóa docker-compose projects
    echo "Tìm kiếm docker-compose projects..."
    COMPOSE_PROJECTS=$(docker compose ls --format json 2>/dev/null | jq -r '.[].Name' 2>/dev/null | grep -E "(n8n|caddy)" || true)
    
    if [ -n "$COMPOSE_PROJECTS" ]; then
        echo "Tìm thấy docker-compose projects: $COMPOSE_PROJECTS"
        for project in $COMPOSE_PROJECTS; do
            echo "Đang xóa project: $project"
            docker compose -p "$project" down --volumes --remove-orphans 2>/dev/null || true
            echo "  ✅ Đã xóa project: $project"
        done
    fi
    
    # Tìm và xóa images liên quan
    echo "Tìm kiếm Docker images liên quan..."
    N8N_IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "(n8n|caddy)" || true)
    
    if [ -n "$N8N_IMAGES" ]; then
        echo "Tìm thấy images cũ:"
        echo "$N8N_IMAGES"
        echo "Đang xóa images..."
        echo "$N8N_IMAGES" | xargs -r docker rmi -f 2>/dev/null || true
        echo "  ✅ Đã xóa images cũ"
    fi
    
    # Tìm và xóa volumes
    echo "Tìm kiếm Docker volumes..."
    N8N_VOLUMES=$(docker volume ls --format "{{.Name}}" | grep -E "(n8n|caddy)" || true)
    
    if [ -n "$N8N_VOLUMES" ]; then
        echo "Tìm thấy volumes cũ: $N8N_VOLUMES"
        echo "Đang xóa volumes..."
        echo "$N8N_VOLUMES" | xargs -r docker volume rm -f 2>/dev/null || true
        echo "  ✅ Đã xóa volumes cũ"
    fi
    
    # Tìm và xóa thư mục cài đặt cũ
    echo "Tìm kiếm thư mục cài đặt N8N..."
    OLD_N8N_DIRS=$(find /home -maxdepth 2 -name "*n8n*" -type d 2>/dev/null || true)
    OLD_N8N_DIRS="$OLD_N8N_DIRS $(find /opt -maxdepth 2 -name "*n8n*" -type d 2>/dev/null || true)"
    OLD_N8N_DIRS="$OLD_N8N_DIRS $(find /var -maxdepth 2 -name "*n8n*" -type d 2>/dev/null || true)"
    
    if [ -n "$OLD_N8N_DIRS" ]; then
        echo "Tìm thấy thư mục cũ:"
        echo "$OLD_N8N_DIRS"
        echo "Đang xóa thư mục cũ..."
        echo "$OLD_N8N_DIRS" | xargs -r rm -rf 2>/dev/null || true
        echo "  ✅ Đã xóa thư mục cũ"
    fi
    
    # Xóa cron jobs cũ
    echo "Xóa cron jobs N8N cũ..."
    (crontab -l 2>/dev/null | grep -v "n8n\|backup-workflows\|update-n8n" || true) | crontab - 2>/dev/null || true
    echo "  ✅ Đã xóa cron jobs cũ"
    
    # Docker system prune
    echo "Dọn dẹp Docker system..."
    docker system prune -f --volumes 2>/dev/null || true
    echo "  ✅ Đã dọn dẹp Docker system"
    
    echo "🎉 Hoàn tất dọn dẹp cài đặt cũ!"
}

# Xử lý tham số dòng lệnh
N8N_DIR="/home/n8n"
SKIP_DOCKER=false
CLEAN_INSTALL=false

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
        --clean)
            CLEAN_INSTALL=true
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
    local domain_ip=$(dig +short $domain A | head -n1)

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
            echo "Lệnh '$cmd' không tìm thấy. Đang cài đặt..."
            apt-get update > /dev/null 2>&1
            if [ "$cmd" == "docker" ]; then
                install_docker
            elif [ "$cmd" == "cron" ]; then
                apt-get install -y cron
            elif [ "$cmd" == "bc" ]; then
                apt-get install -y bc
            else
                apt-get install -y dnsutils curl jq tar gzip
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
        apt-get update > /dev/null 2>&1
        apt-get install -y apt-transport-https ca-certificates curl software-properties-common > /dev/null 2>&1
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update > /dev/null 2>&1
        apt-get install -y docker-ce docker-ce-cli containerd.io > /dev/null 2>&1
    fi

    # Cài đặt Docker Compose
    if command -v docker-compose &> /dev/null || (command -v docker &> /dev/null && docker compose version &> /dev/null); then
        echo "Docker Compose đã được cài đặt."
    else 
        echo "Cài đặt Docker Compose plugin..."
        apt-get install -y docker-compose-plugin > /dev/null 2>&1
        if ! (docker compose version &> /dev/null); then 
            echo "Cài docker-compose standalone..." 
            apt-get install -y docker-compose > /dev/null 2>&1
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
        usermod -aG docker $SUDO_USER > /dev/null 2>&1
    fi
    systemctl enable docker > /dev/null 2>&1
    systemctl restart docker > /dev/null 2>&1
    echo "Docker và Docker Compose đã được cài đặt thành công."
}

# Kiểm tra cleanup
if $CLEAN_INSTALL; then
    echo "🧹 Chế độ Clean Install được kích hoạt"
    cleanup_old_installation
else
    # Hỏi người dùng có muốn cleanup không
    read -p "🧹 Bạn có muốn xóa tất cả cài đặt N8N cũ trước khi cài mới không? (y/n): " CLEANUP_CHOICE
    if [[ "$CLEANUP_CHOICE" =~ ^[Yy]$ ]]; then
        cleanup_old_installation
    else
        echo "Bỏ qua cleanup. Tiếp tục cài đặt..."
    fi
fi

# Cài đặt các gói cần thiết
echo "Đang kiểm tra và cài đặt các công cụ cần thiết..."
apt-get update > /dev/null 2>&1
apt-get install -y dnsutils curl cron jq tar gzip python3-full python3-venv pipx net-tools bc > /dev/null 2>&1

# Cài đặt yt-dlp
echo "Cài đặt yt-dlp..."
if command -v pipx &> /dev/null; then
    pipx install yt-dlp --force > /dev/null 2>&1
    pipx ensurepath > /dev/null 2>&1
else
    python3 -m venv /opt/yt-dlp-venv
    /opt/yt-dlp-venv/bin/pip install -U pip yt-dlp > /dev/null 2>&1
    ln -sf /opt/yt-dlp-venv/bin/yt-dlp /usr/local/bin/yt-dlp
    chmod +x /usr/local/bin/yt-dlp
fi
export PATH="$PATH:/usr/local/bin:/opt/yt-dlp-venv/bin:$HOME/.local/bin"

# Đảm bảo cron service đang chạy
systemctl enable cron > /dev/null 2>&1
systemctl start cron > /dev/null 2>&1

# Kiểm tra các lệnh
check_commands

# Nhận input domain từ người dùng
read -p "Nhập tên miền chính của bạn (ví dụ: n8nkalvinbot.io.vn): " DOMAIN
while ! check_domain $DOMAIN; do
    echo "❌ Domain $DOMAIN chưa được trỏ đúng đến IP server này ($(curl -s https://api.ipify.org))."
    echo "Vui lòng cập nhật bản ghi DNS để trỏ $DOMAIN đến IP $(curl -s https://api.ipify.org)." 
    read -p "Nhấn Enter sau khi cập nhật DNS, hoặc nhập domain khác: " NEW_DOMAIN
    if [ -n "$NEW_DOMAIN" ]; then
        DOMAIN="$NEW_DOMAIN"
    fi
done
echo "✅ Domain $DOMAIN đã được trỏ đúng. Tiếp tục cài đặt."

# Hỏi về News API
read -p "Bạn có muốn cài đặt FastAPI để cào nội dung bài viết không? (y/n): " INSTALL_NEWS_API
if [[ "$INSTALL_NEWS_API" =~ ^[Yy]$ ]]; then
    API_DOMAIN="api.$DOMAIN"
    echo "Sẽ tạo API tại: $API_DOMAIN"
    
    echo "Kiểm tra domain API: $API_DOMAIN"
    while ! check_domain $API_DOMAIN; do
        echo "❌ Domain API $API_DOMAIN chưa được trỏ đúng đến IP server này ($(curl -s https://api.ipify.org))."
        echo "Vui lòng cập nhật bản ghi DNS để trỏ $API_DOMAIN đến IP $(curl -s https://api.ipify.org)."
        read -p "Nhấn Enter sau khi cập nhật DNS, hoặc nhập domain API khác: " NEW_API_DOMAIN
        if [ -n "$NEW_API_DOMAIN" ]; then
            API_DOMAIN="$NEW_API_DOMAIN"
        fi
    done
    echo "✅ Domain API $API_DOMAIN đã được trỏ đúng."
    
    # Yêu cầu người dùng đặt Bearer Token
    while true; do
        read -p "🔐 Nhập Bearer Token của bạn (ít nhất 20 ký tự, chỉ chữ và số): " NEWS_API_TOKEN
        if [ ${#NEWS_API_TOKEN} -ge 20 ] && [[ "$NEWS_API_TOKEN" =~ ^[a-zA-Z0-9]+$ ]]; then
            break
        else
            echo "❌ Bearer Token phải có ít nhất 20 ký tự và chỉ chứa chữ cái và số!"
        fi
    done
    echo "✅ Bearer Token hợp lệ!"
fi

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
RUN npm install n8n-nodes-puppeteer || echo "Cảnh báo: Không thể cài đặt n8n-nodes-puppeteer"
RUN mkdir -p /files/youtube_content_anylystic /files/backup_full /files/temp && \
    chown -R node:node /files
USER node
WORKDIR /home/node
EOF

# Tạo Dockerfile.simple cho fallback
cat << 'EOF' > $N8N_DIR/Dockerfile.simple
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
RUN mkdir -p /files/youtube_content_anylystic /files/backup_full /files/temp && \
    chown -R node:node /files
USER node
WORKDIR /home/node
EOF

# Cài đặt News API nếu được chọn
if [[ "$INSTALL_NEWS_API" =~ ^[Yy]$ ]]; then
    echo "Cài đặt News Content API..."
    mkdir -p $N8N_DIR/news_api
    
    # Tạo requirements.txt với version đúng
    cat << 'EOF' > $N8N_DIR/news_api/requirements.txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
newspaper4k==0.9.3.1
python-multipart==0.0.6
jinja2==3.1.2
aiofiles==23.2.1
requests==2.31.0
beautifulsoup4==4.12.2
lxml==4.9.3
python-dateutil==2.8.2
feedparser==6.0.10
pydantic==2.4.2
EOF

    # Tạo main.py cho FastAPI
    cat << EOF > $N8N_DIR/news_api/main.py
import os
import asyncio
import logging
from datetime import datetime
from typing import List, Optional, Dict, Any
import feedparser
import requests
from bs4 import BeautifulSoup
from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, HttpUrl
from newspaper import Article, Source
import uvicorn

# Logging setup
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Security
security = HTTPBearer()
NEWS_API_TOKEN = os.getenv("NEWS_API_TOKEN", "default_token")

app = FastAPI(
    title="News Content API",
    description="API để cào nội dung bài viết và RSS feeds",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

templates = Jinja2Templates(directory="/app/templates")

# Models
class ArticleRequest(BaseModel):
    url: HttpUrl
    language: str = "vi"
    extract_images: bool = True
    summarize: bool = False

class SourceRequest(BaseModel):
    url: HttpUrl
    max_articles: int = 10
    language: str = "vi"

class FeedRequest(BaseModel):
    url: HttpUrl
    max_articles: int = 10

class ArticleResponse(BaseModel):
    title: str
    content: str
    summary: Optional[str] = None
    authors: List[str]
    publish_date: Optional[str] = None
    images: List[str]
    url: str
    word_count: int
    read_time_minutes: int

# Auth dependency
async def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if credentials.credentials != NEWS_API_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid authentication token")
    return credentials.credentials

# Routes
@app.get("/", response_class=HTMLResponse)
async def homepage(request: Request):
    domain = request.headers.get("host", "api.yourdomain.com")
    curl_examples = {
        "health": f'''curl -X GET "https://{domain}/health" \\
     -H "Authorization: Bearer {NEWS_API_TOKEN}"''',
        "extract_article": f'''curl -X POST "https://{domain}/extract-article" \\
     -H "Content-Type: application/json" \\
     -H "Authorization: Bearer {NEWS_API_TOKEN}" \\
     -d '{{
       "url": "https://dantri.com.vn/the-gioi.htm",
       "language": "vi",
       "extract_images": true,
       "summarize": true
     }}'""",
        "extract_source": f'''curl -X POST "https://{domain}/extract-source" \\
     -H "Content-Type: application/json" \\
     -H "Authorization: Bearer {NEWS_API_TOKEN}" \\
     -d '{{
       "url": "https://dantri.com.vn",
       "max_articles": 10,
       "language": "vi"
     }}'""",
        "parse_feed": f'''curl -X POST "https://{domain}/parse-feed" \\
     -H "Content-Type: application/json" \\
     -H "Authorization: Bearer {NEWS_API_TOKEN}" \\
     -d '{{
       "url": "https://dantri.com.vn/rss.xml",
       "max_articles": 10
     }}'"""
    }
    
    html_content = f"""
    <!DOCTYPE html>
    <html lang="vi">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>News Content API - Kalvin Thien</title>
        <style>
            * {{ margin: 0; padding: 0; box-sizing: border-box; }}
            body {{ 
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                line-height: 1.6; color: #333; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
            }}
            .container {{ max-width: 1200px; margin: 0 auto; padding: 20px; }}
            .header {{ text-align: center; color: white; margin-bottom: 40px; }}
            .header h1 {{ font-size: 3rem; margin-bottom: 10px; text-shadow: 2px 2px 4px rgba(0,0,0,0.3); }}
            .header p {{ font-size: 1.2rem; opacity: 0.9; }}
            .card {{ 
                background: white; border-radius: 15px; padding: 30px; margin-bottom: 30px;
                box-shadow: 0 10px 30px rgba(0,0,0,0.1); transition: transform 0.3s ease;
            }}
            .card:hover {{ transform: translateY(-5px); }}
            .card h2 {{ color: #667eea; margin-bottom: 20px; font-size: 1.8rem; }}
            .endpoint {{ 
                background: #f8f9fa; border-radius: 10px; padding: 20px; margin-bottom: 20px;
                border-left: 4px solid #667eea;
            }}
            .endpoint h3 {{ color: #333; margin-bottom: 10px; }}
            .endpoint p {{ color: #666; margin-bottom: 15px; }}
            .code-block {{ 
                background: #2d3748; color: #e2e8f0; padding: 20px; border-radius: 8px;
                font-family: 'Courier New', monospace; font-size: 14px; overflow-x: auto;
                white-space: pre-wrap; word-wrap: break-word;
            }}
            .copy-btn {{ 
                background: #667eea; color: white; border: none; padding: 8px 15px;
                border-radius: 5px; cursor: pointer; margin-top: 10px; font-size: 12px;
            }}
            .copy-btn:hover {{ background: #5a67d8; }}
            .author {{ text-align: center; color: white; margin-top: 40px; }}
            .author a {{ color: #ffd700; text-decoration: none; }}
            .author a:hover {{ text-decoration: underline; }}
            .token-info {{ 
                background: #fff3cd; border: 1px solid #ffeaa7; border-radius: 8px;
                padding: 15px; margin-bottom: 20px; color: #856404;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🚀 News Content API</h1>
                <p>API cào nội dung bài viết và RSS feeds - Phiên bản 2025</p>
            </div>

            <div class="card">
                <div class="token-info">
                    <strong>🔐 Bearer Token:</strong> {NEWS_API_TOKEN}<br>
                    <small>Sử dụng token này trong header Authorization: Bearer {NEWS_API_TOKEN}</small>
                </div>
                
                <h2>📖 API Documentation</h2>
                <p>Truy cập các trang tài liệu API:</p>
                <ul style="margin: 15px 0; padding-left: 20px;">
                    <li><a href="/docs" target="_blank">📚 Swagger UI</a> - Giao diện tương tác</li>
                    <li><a href="/redoc" target="_blank">📖 ReDoc</a> - Tài liệu chi tiết</li>
                </ul>
            </div>

            <div class="card">
                <h2>🔧 API Endpoints</h2>
                
                <div class="endpoint">
                    <h3>GET /health</h3>
                    <p>Kiểm tra trạng thái API</p>
                    <div class="code-block">{curl_examples["health"]}</div>
                    <button class="copy-btn" onclick="copyToClipboard('{curl_examples["health"].replace("'", "\\'")}')">📋 Copy</button>
                </div>

                <div class="endpoint">
                    <h3>POST /extract-article</h3>
                    <p>Lấy nội dung bài viết từ URL</p>
                    <div class="code-block">{curl_examples["extract_article"]}</div>
                    <button class="copy-btn" onclick="copyToClipboard('{curl_examples["extract_article"].replace("'", "\\'")}')">📋 Copy</button>
                </div>

                <div class="endpoint">
                    <h3>POST /extract-source</h3>
                    <p>Cào nhiều bài viết từ website</p>
                    <div class="code-block">{curl_examples["extract_source"]}</div>
                    <button class="copy-btn" onclick="copyToClipboard('{curl_examples["extract_source"].replace("'", "\\'")}')">📋 Copy</button>
                </div>

                <div class="endpoint">
                    <h3>POST /parse-feed</h3>
                    <p>Phân tích RSS feeds</p>
                    <div class="code-block">{curl_examples["parse_feed"]}</div>
                    <button class="copy-btn" onclick="copyToClipboard('{curl_examples["parse_feed"].replace("'", "\\'")}')">📋 Copy</button>
                </div>
            </div>

            <div class="author">
                <p>🚀 Made with ❤️ by <strong>Nguyễn Ngọc Thiện</strong></p>
                <p>
                    📺 <a href="https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1" target="_blank">YouTube Channel</a> |
                    📘 <a href="https://www.facebook.com/Ban.Thien.Handsome/" target="_blank">Facebook</a> |
                    📱 Zalo: 08.8888.4749
                </p>
            </div>
        </div>

        <script>
            function copyToClipboard(text) {{
                navigator.clipboard.writeText(text).then(function() {{
                    alert('Đã copy lệnh curl!');
                }}, function(err) {{
                    console.error('Lỗi copy: ', err);
                }});
            }}
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

@app.get("/health")
async def health_check(token: str = Depends(verify_token)):
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "version": "2.0.0",
        "message": "News Content API đang hoạt động bình thường"
    }

@app.post("/extract-article", response_model=ArticleResponse)
async def extract_article(request: ArticleRequest, token: str = Depends(verify_token)):
    try:
        article = Article(str(request.url), language=request.language)
        article.download()
        article.parse()
        
        if request.summarize:
            article.nlp()
        
        # Calculate read time (average 200 words per minute)
        word_count = len(article.text.split())
        read_time = max(1, round(word_count / 200))
        
        return ArticleResponse(
            title=article.title or "Không có tiêu đề",
            content=article.text or "Không thể trích xuất nội dung",
            summary=article.summary if request.summarize else None,
            authors=article.authors or [],
            publish_date=article.publish_date.isoformat() if article.publish_date else None,
            images=list(article.images) if request.extract_images else [],
            url=str(request.url),
            word_count=word_count,
            read_time_minutes=read_time
        )
    except Exception as e:
        logger.error(f"Error extracting article: {e}")
        raise HTTPException(status_code=400, detail=f"Lỗi khi trích xuất bài viết: {str(e)}")

@app.post("/extract-source")
async def extract_source(request: SourceRequest, token: str = Depends(verify_token)):
    try:
        source = Source(str(request.url), language=request.language)
        source.build()
        
        articles = []
        for i, article_url in enumerate(source.article_urls()[:request.max_articles]):
            try:
                article = Article(article_url, language=request.language)
                article.download()
                article.parse()
                
                word_count = len(article.text.split())
                read_time = max(1, round(word_count / 200))
                
                articles.append({
                    "title": article.title or "Không có tiêu đề",
                    "url": article_url,
                    "content": article.text[:500] + "..." if len(article.text) > 500 else article.text,
                    "authors": article.authors or [],
                    "publish_date": article.publish_date.isoformat() if article.publish_date else None,
                    "word_count": word_count,
                    "read_time_minutes": read_time
                })
            except Exception as e:
                logger.warning(f"Error processing article {article_url}: {e}")
                continue
        
        return {
            "source_url": str(request.url),
            "total_articles": len(articles),
            "articles": articles
        }
    except Exception as e:
        logger.error(f"Error extracting source: {e}")
        raise HTTPException(status_code=400, detail=f"Lỗi khi trích xuất nguồn: {str(e)}")

@app.post("/parse-feed")
async def parse_feed(request: FeedRequest, token: str = Depends(verify_token)):
    try:
        feed = feedparser.parse(str(request.url))
        
        if feed.bozo:
            raise HTTPException(status_code=400, detail="RSS feed không hợp lệ")
        
        articles = []
        for entry in feed.entries[:request.max_articles]:
            articles.append({
                "title": entry.get("title", "Không có tiêu đề"),
                "url": entry.get("link", ""),
                "summary": entry.get("summary", ""),
                "published": entry.get("published", ""),
                "author": entry.get("author", ""),
                "tags": [tag.term for tag in entry.get("tags", [])]
            })
        
        return {
            "feed_title": feed.feed.get("title", ""),
            "feed_description": feed.feed.get("description", ""),
            "feed_url": str(request.url),
            "total_articles": len(articles),
            "articles": articles
        }
    except Exception as e:
        logger.error(f"Error parsing feed: {e}")
        raise HTTPException(status_code=400, detail=f"Lỗi khi phân tích RSS feed: {str(e)}")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

    # Tạo Dockerfile cho FastAPI
    cat << 'EOF' > $N8N_DIR/news_api/Dockerfile
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
    libffi-dev \
    libssl-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py .

# Create templates directory
RUN mkdir -p templates

# Expose port
EXPOSE 8000

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

    # Tạo script khởi động
    cat << 'EOF' > $N8N_DIR/news_api/start_news_api.sh
#!/bin/bash
cd /app
exec uvicorn main:app --host 0.0.0.0 --port 8000 --reload
EOF
    chmod +x $N8N_DIR/news_api/start_news_api.sh
    
    echo "✅ Đã tạo News API thành công!"
fi

# Tạo file docker-compose.yml
echo "Tạo file docker-compose.yml..."
if [[ "$INSTALL_NEWS_API" =~ ^[Yy]$ ]]; then
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
      - N8N_EXECUTIONS_DATA_MAX_SIZE=304857600
      - PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
      - PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
    volumes:
      - ${N8N_DIR}:/home/node/.n8n
      - ${N8N_DIR}/files:/files
    user: "node"
    cap_add:
      - SYS_ADMIN

  fastapi:
    build:
      context: ./news_api
      dockerfile: Dockerfile
    image: news-api:latest
    restart: always
    ports:
      - "127.0.0.1:8000:8000"
    environment:
      - NEWS_API_TOKEN=${NEWS_API_TOKEN}
    volumes:
      - ${N8N_DIR}/news_api:/app

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
      - fastapi

volumes:
  caddy_data:
  caddy_config:
EOF

    echo "🔑 Bearer Token cho News API: $NEWS_API_TOKEN"
    echo "📝 Lưu token này để sử dụng API!"
    
    # Lưu token vào file
    echo "$NEWS_API_TOKEN" > $N8N_DIR/news_api_token.txt
    chmod 600 $N8N_DIR/news_api_token.txt
else
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
      - N8N_EXECUTIONS_DATA_MAX_SIZE=304857600
      - PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
      - PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
    volumes:
      - ${N8N_DIR}:/home/node/.n8n
      - ${N8N_DIR}/files:/files
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
fi

# Tạo file Caddyfile với SSL tự động
echo "Tạo file Caddyfile..."
if [[ "$INSTALL_NEWS_API" =~ ^[Yy]$ ]]; then
    cat << EOF > $N8N_DIR/Caddyfile
${DOMAIN} {
    reverse_proxy n8n:5678
    tls {
        protocols tls1.2 tls1.3
    }
    encode gzip
    
    header {
        # Security headers
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}

${API_DOMAIN} {
    reverse_proxy fastapi:8000
    tls {
        protocols tls1.2 tls1.3
    }
    encode gzip
    
    header {
        # Security headers
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        # CORS headers
        Access-Control-Allow-Origin "*"
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        Access-Control-Allow-Headers "Content-Type, Authorization"
    }
}
EOF
else
    cat << EOF > $N8N_DIR/Caddyfile
${DOMAIN} {
    reverse_proxy n8n:5678
    tls {
        protocols tls1.2 tls1.3
    }
    encode gzip
    
    header {
        # Security headers
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}
EOF
fi

# Cấu hình gửi backup qua Telegram
TELEGRAM_CONF_FILE="$N8N_DIR/telegram_config.txt"
read -p "Bạn có muốn cấu hình gửi file backup hàng ngày qua Telegram không? (y/n): " CONFIGURE_TELEGRAM
if [[ "$CONFIGURE_TELEGRAM" =~ ^[Yy]$ ]]; then
    echo "Để gửi backup qua Telegram, bạn cần một Bot Token và Chat ID."
    echo "Hướng dẫn lấy Bot Token: Nói chuyện với BotFather trên Telegram (tìm @BotFather), gõ /newbot, làm theo hướng dẫn."
    echo "Hướng dẫn lấy Chat ID: Nói chuyện với bot @userinfobot trên Telegram, nó sẽ hiển thị User ID của bạn."
    echo "Nếu muốn gửi vào group, thêm bot của bạn vào group, sau đó gửi tin nhắn bất kỳ, rồi truy cập:"
    echo "https://api.telegram.org/bot<BOT_TOKEN>/getUpdates để lấy Chat ID (bắt đầu bằng dấu trừ)."
    
    read -p "Nhập Telegram Bot Token của bạn: " TELEGRAM_BOT_TOKEN
    read -p "Nhập Telegram Chat ID của bạn (hoặc group ID): " TELEGRAM_CHAT_ID
    
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        echo "TELEGRAM_BOT_TOKEN=\"$TELEGRAM_BOT_TOKEN\"" > "$TELEGRAM_CONF_FILE"
        echo "TELEGRAM_CHAT_ID=\"$TELEGRAM_CHAT_ID\"" >> "$TELEGRAM_CONF_FILE"
        chmod 600 "$TELEGRAM_CONF_FILE"
        echo "✅ Đã lưu cấu hình Telegram vào $TELEGRAM_CONF_FILE"
        
        # Test gửi tin nhắn
        echo "🧪 Đang test gửi tin nhắn Telegram..."
        TEST_MESSAGE="🎉 Chào mừng! Hệ thống N8N backup đã được cấu hình thành công cho domain: $DOMAIN

📅 Backup tự động: Mỗi ngày lúc 2:00 AM
📱 Thông báo: Sẽ gửi qua Telegram này
📁 File backup: Sẽ gửi nếu < 20MB

🚀 Tác giả: Nguyễn Ngọc Thiện
📺 YouTube: https://www.youtube.com/@kalvinthiensocial"

        if curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d chat_id="${TELEGRAM_CHAT_ID}" \
            -d text="${TEST_MESSAGE}" \
            -d parse_mode="Markdown" > /dev/null 2>&1; then
            echo "✅ Test Telegram thành công! Kiểm tra tin nhắn trong Telegram."
        else
            echo "❌ Test Telegram thất bại. Kiểm tra lại Bot Token và Chat ID."
        fi
    else
        echo "Bot Token hoặc Chat ID không được cung cấp. Bỏ qua cấu hình Telegram."
    fi
elif [[ "$CONFIGURE_TELEGRAM" =~ ^[Nn]$ ]]; then
    echo "Đã bỏ qua cấu hình gửi backup qua Telegram."
    if [ -f "$TELEGRAM_CONF_FILE" ]; then
        rm -f "$TELEGRAM_CONF_FILE"
    fi
else
    echo "Lựa chọn không hợp lệ. Mặc định bỏ qua cấu hình Telegram."
fi

# Hỏi về auto-update
read -p "Bạn có muốn bật tính năng tự động cập nhật N8N không? (y/n): " ENABLE_AUTO_UPDATE

# Tạo script sao lưu workflow và credentials
echo "Tạo script sao lưu workflow và credentials tại $N8N_DIR/backup-workflows.sh..."
cat << 'EOF' > $N8N_DIR/backup-workflows.sh
#!/bin/bash

N8N_DIR_VALUE="$N8N_DIR"
BACKUP_BASE_DIR="${N8N_DIR_VALUE}/files/backup_full"
LOG_FILE="${N8N_DIR_VALUE}/files/backup_full/backup.log"
TELEGRAM_CONF_FILE="${N8N_DIR_VALUE}/telegram_config.txt"
DATE="$(date +"%Y%m%d_%H%M%S")"
BACKUP_FILE_NAME="n8n_backup_${DATE}.tar.gz"
BACKUP_FILE_PATH="${BACKUP_BASE_DIR}/${BACKUP_FILE_NAME}"
TEMP_DIR_HOST="/tmp/n8n_backup_host_${DATE}"
TEMP_DIR_CONTAINER_BASE="/tmp/n8n_workflow_exports"

TELEGRAM_FILE_SIZE_LIMIT=20971520 # 20MB

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

send_telegram_message() {
    local message="$1"
    if [ -f "${TELEGRAM_CONF_FILE}" ]; then
        source "${TELEGRAM_CONF_FILE}"
        if [ -n "${TELEGRAM_BOT_TOKEN}" ] && [ -n "${TELEGRAM_CHAT_ID}" ]; then
            (curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
                -d chat_id="${TELEGRAM_CHAT_ID}" \
                -d text="${message}" \
                -d parse_mode="Markdown" > /dev/null 2>&1) &
        fi
    fi
}

send_telegram_document() {
    local file_path="$1"
    local caption="$2"
    if [ -f "${TELEGRAM_CONF_FILE}" ]; then
        source "${TELEGRAM_CONF_FILE}"
        if [ -n "${TELEGRAM_BOT_TOKEN}" ] && [ -n "${TELEGRAM_CHAT_ID}" ]; then
            local file_size="$(du -b "${file_path}" | cut -f1)"
            if [ "${file_size}" -le "${TELEGRAM_FILE_SIZE_LIMIT}" ]; then
                log "Đang gửi file backup qua Telegram: ${file_path}"
                (curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
                    -F chat_id="${TELEGRAM_CHAT_ID}" \
                    -F document=@"${file_path}" \
                    -F caption="${caption}" > /dev/null 2>&1) &
            else
                local readable_size="$(echo "scale=2; ${file_size} / 1024 / 1024" | bc)"
                log "File backup quá lớn (${readable_size} MB) để gửi qua Telegram."
                send_telegram_message "📦 Backup N8N hoàn tất!

📁 File: \`${BACKUP_FILE_NAME}\`
📊 Kích thước: ${readable_size}MB (quá lớn để gửi)
📍 Vị trí: \`${file_path}\`
🕐 Thời gian: $(date '+%d/%m/%Y %H:%M:%S')

⚠️ File quá lớn (>20MB) nên không thể gửi qua Telegram."
            fi
        fi
    fi
}

mkdir -p "${BACKUP_BASE_DIR}"
log "Bắt đầu sao lưu workflows và credentials..."
send_telegram_message "🔄 Bắt đầu quá trình sao lưu N8N hàng ngày...

🌐 Domain: \`$DOMAIN\`
📅 Thời gian: $(date '+%d/%m/%Y %H:%M:%S')"

N8N_CONTAINER_NAME_PATTERN="n8n"
N8N_CONTAINER_ID="$(docker ps -q --filter "name=${N8N_CONTAINER_NAME_PATTERN}" --format '{{.ID}}' | head -n 1)"

if [ -z "${N8N_CONTAINER_ID}" ]; then
    log "Lỗi: Không tìm thấy container n8n đang chạy."
    send_telegram_message "❌ Lỗi sao lưu N8N!

🌐 Domain: \`$DOMAIN\`
❗ Lỗi: Không tìm thấy container n8n đang chạy
📋 Log: \`${LOG_FILE}\`"
    exit 1
fi
log "Tìm thấy container N8N ID: ${N8N_CONTAINER_ID}"

mkdir -p "${TEMP_DIR_HOST}/workflows"
mkdir -p "${TEMP_DIR_HOST}/credentials"
mkdir -p "${TEMP_DIR_HOST}/metadata"

# Tạo thư mục export tạm thời bên trong container
TEMP_DIR_CONTAINER_UNIQUE="${TEMP_DIR_CONTAINER_BASE}/export_${DATE}"
docker exec "${N8N_CONTAINER_ID}" mkdir -p "${TEMP_DIR_CONTAINER_UNIQUE}"

log "Xuất workflows vào ${TEMP_DIR_CONTAINER_UNIQUE} trong container..." 
WORKFLOWS_JSON="$(docker exec "${N8N_CONTAINER_ID}" n8n list:workflow --json 2>/dev/null || echo "[]")"

WORKFLOW_COUNT=0
if [ -z "${WORKFLOWS_JSON}" ] || [ "${WORKFLOWS_JSON}" == "[]" ]; then
    log "Cảnh báo: Không tìm thấy workflow nào để sao lưu."
else
    echo "${WORKFLOWS_JSON}" | jq -c '.[]' 2>/dev/null | while IFS= read -r workflow; do
        id="$(echo "${workflow}" | jq -r '.id' 2>/dev/null || echo "")"
        name="$(echo "${workflow}" | jq -r '.name' 2>/dev/null | tr -dc '[:alnum:][:space:]_-' | tr '[:space:]' '_')"
        safe_name="$(echo "${name}" | sed 's/[^a-zA-Z0-9_-]/_/g' | cut -c1-100)"
        
        if [ -n "${id}" ] && [ "${id}" != "null" ]; then
            output_file_container="${TEMP_DIR_CONTAINER_UNIQUE}/${id}-${safe_name}.json"
            log "Đang xuất workflow: '${name}' (ID: ${id})"
            if docker exec "${N8N_CONTAINER_ID}" n8n export:workflow --id="${id}" --output="${output_file_container}" 2>/dev/null; then
                log "✅ Đã xuất workflow ID ${id} thành công."
                WORKFLOW_COUNT=$((WORKFLOW_COUNT + 1))
            else
                log "❌ Lỗi khi xuất workflow ID ${id}."
            fi
        fi
    done

    log "Sao chép workflows từ container vào host..."
    if docker cp "${N8N_CONTAINER_ID}:${TEMP_DIR_CONTAINER_UNIQUE}/." "${TEMP_DIR_HOST}/workflows/" 2>/dev/null; then
        log "✅ Sao chép workflows từ container ra host thành công."
        WORKFLOW_COUNT=$(find "${TEMP_DIR_HOST}/workflows" -name "*.json" | wc -l)
    else
        log "❌ Lỗi khi sao chép workflows từ container ra host."
    fi
fi

# Backup database và encryption key
DB_PATH_HOST="${N8N_DIR_VALUE}/database.sqlite"
KEY_PATH_HOST="${N8N_DIR_VALUE}/encryptionKey"

log "Sao lưu database và encryption key từ host..."
if [ -f "${DB_PATH_HOST}" ]; then
    cp "${DB_PATH_HOST}" "${TEMP_DIR_HOST}/credentials/database.sqlite"
    log "✅ Đã sao lưu database.sqlite"
else
    log "❌ Không tìm thấy file database.sqlite tại ${DB_PATH_HOST}"
fi

if [ -f "${KEY_PATH_HOST}" ]; then
    cp "${KEY_PATH_HOST}" "${TEMP_DIR_HOST}/credentials/encryptionKey"
    log "✅ Đã sao lưu encryptionKey"
else
    log "❌ Không tìm thấy file encryptionKey tại ${KEY_PATH_HOST}"
fi

# Tạo metadata
cat << EOF > "${TEMP_DIR_HOST}/metadata/backup_info.json"
{
    "backup_date": "$(date -Iseconds)",
    "domain": "$DOMAIN",
    "workflow_count": ${WORKFLOW_COUNT},
    "n8n_container_id": "${N8N_CONTAINER_ID}",
    "backup_version": "2.0",
    "created_by": "Nguyễn Ngọc Thiện - N8N Auto Backup Script"
}
EOF

log "Tạo file nén tar.gz: ${BACKUP_FILE_PATH}"
if tar -czf "${BACKUP_FILE_PATH}" -C "${TEMP_DIR_HOST}" . 2>/dev/null; then
    BACKUP_SIZE=$(du -h "${BACKUP_FILE_PATH}" | cut -f1)
    log "✅ Tạo file backup ${BACKUP_FILE_PATH} thành công. Kích thước: ${BACKUP_SIZE}"
    
    # Gửi qua Telegram
    BACKUP_CAPTION="📦 Backup N8N hoàn tất!

🌐 Domain: $DOMAIN
📁 File: ${BACKUP_FILE_NAME}
📊 Kích thước: ${BACKUP_SIZE}
📋 Workflows: ${WORKFLOW_COUNT}
🕐 Thời gian: $(date '+%d/%m/%Y %H:%M:%S')

✅ Backup thành công!"

    send_telegram_document "${BACKUP_FILE_PATH}" "${BACKUP_CAPTION}"
else
    log "❌ Không thể tạo file backup ${BACKUP_FILE_PATH}."
    send_telegram_message "❌ Lỗi sao lưu N8N!

🌐 Domain: \`$DOMAIN\`
❗ Lỗi: Không thể tạo file backup
📋 Log: \`${LOG_FILE}\`
🕐 Thời gian: $(date '+%d/%m/%Y %H:%M:%S')"
fi

# Dọn dẹp
log "Dọn dẹp thư mục tạm..."
rm -rf "${TEMP_DIR_HOST}"
docker exec "${N8N_CONTAINER_ID}" rm -rf "${TEMP_DIR_CONTAINER_UNIQUE}" 2>/dev/null || true

# Giữ lại 30 bản backup gần nhất
log "Giữ lại 30 bản sao lưu gần nhất trong ${BACKUP_BASE_DIR}..."
find "${BACKUP_BASE_DIR}" -maxdepth 1 -name 'n8n_backup_*.tar.gz' -type f -printf '%T@ %p\n' 2>/dev/null | \
sort -nr | tail -n +31 | cut -d' ' -f2- | xargs -r rm -f

REMAINING_BACKUPS=$(find "${BACKUP_BASE_DIR}" -maxdepth 1 -name 'n8n_backup_*.tar.gz' -type f | wc -l)
log "Hoàn tất sao lưu. Còn lại ${REMAINING_BACKUPS} bản backup trong hệ thống."

exit 0
EOF

# Thay thế biến trong script
sed -i "s|\$N8N_DIR|$N8N_DIR|g" $N8N_DIR/backup-workflows.sh
sed -i "s|\$DOMAIN|$DOMAIN|g" $N8N_DIR/backup-workflows.sh
chmod +x $N8N_DIR/backup-workflows.sh

# Tạo script backup thủ công để test
echo "Tạo script backup thủ công tại $N8N_DIR/backup-manual.sh..."
cat << EOF > $N8N_DIR/backup-manual.sh
#!/bin/bash
echo "🧪 Chạy backup thủ công để kiểm tra..."
echo "📁 Thư mục backup: $N8N_DIR/files/backup_full/"
echo "📋 Log file: $N8N_DIR/files/backup_full/backup.log"
echo ""
$N8N_DIR/backup-workflows.sh
echo ""
echo "✅ Hoàn tất backup thủ công!"
echo "📁 Kiểm tra file backup tại: $N8N_DIR/files/backup_full/"
ls -la $N8N_DIR/files/backup_full/*.tar.gz 2>/dev/null || echo "Chưa có file backup nào."
EOF
chmod +x $N8N_DIR/backup-manual.sh

# Tạo script chẩn đoán
echo "Tạo script chẩn đoán tại $N8N_DIR/troubleshoot.sh..."
cat << EOF > $N8N_DIR/troubleshoot.sh
#!/bin/bash
echo "🔍 SCRIPT CHẨN ĐOÁN HỆ THỐNG N8N"
echo "=================================="
echo ""

echo "📊 THÔNG TIN HỆ THỐNG:"
echo "- OS: \$(lsb_release -d | cut -f2)"
echo "- Kernel: \$(uname -r)"
echo "- RAM: \$(free -h | grep Mem | awk '{print \$2}')"
echo "- Disk: \$(df -h / | tail -1 | awk '{print \$4}') free"
echo "- Swap: \$(free -h | grep Swap | awk '{print \$2}')"
echo ""

echo "🐳 DOCKER STATUS:"
docker --version 2>/dev/null || echo "❌ Docker không được cài đặt"
docker-compose --version 2>/dev/null || docker compose version 2>/dev/null || echo "❌ Docker Compose không được cài đặt"
echo "- Docker service: \$(systemctl is-active docker)"
echo ""

echo "📦 CONTAINERS:"
cd $N8N_DIR
if command -v docker-compose &> /dev/null; then
    docker-compose ps
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    docker compose ps
else
    echo "❌ Không tìm thấy docker-compose"
fi
echo ""

echo "🌐 NETWORK & DNS:"
echo "- Server IP: \$(curl -s https://api.ipify.org || echo 'Không lấy được IP')"
echo "- Domain $DOMAIN resolves to: \$(dig +short $DOMAIN A | head -1)"
if [[ "$INSTALL_NEWS_API" =~ ^[Yy]$ ]]; then
    echo "- API Domain $API_DOMAIN resolves to: \$(dig +short $API_DOMAIN A | head -1)"
fi
echo ""

echo "🔒 SSL CERTIFICATES:"
echo "- $DOMAIN SSL: \$(curl -s -I https://$DOMAIN | head -1 || echo 'Không kết nối được')"
if [[ "$INSTALL_NEWS_API" =~ ^[Yy]$ ]]; then
    echo "- $API_DOMAIN SSL: \$(curl -s -I https://$API_DOMAIN | head -1 || echo 'Không kết nối được')"
fi
echo ""

echo "📁 FILES & PERMISSIONS:"
echo "- N8N Directory: $N8N_DIR"
ls -la $N8N_DIR/ | head -10
echo ""

echo "📋 LOGS (Last 10 lines):"
echo "--- Docker Compose Logs ---"
cd $N8N_DIR
if command -v docker-compose &> /dev/null; then
    docker-compose logs --tail=10
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    docker compose logs --tail=10
fi
echo ""

echo "--- Backup Logs ---"
if [ -f "$N8N_DIR/files/backup_full/backup.log" ]; then
    tail -10 $N8N_DIR/files/backup_full/backup.log
else
    echo "Chưa có log backup"
fi
echo ""

echo "🔧 TROUBLESHOOTING SUGGESTIONS:"
echo "1. Nếu containers không chạy: cd $N8N_DIR && docker-compose restart"
echo "2. Nếu SSL lỗi: cd $N8N_DIR && docker-compose restart caddy"
echo "3. Nếu domain không resolve: Kiểm tra DNS settings"
echo "4. Rebuild containers: cd $N8N_DIR && docker-compose down && docker-compose up -d --build"
echo "5. Xem logs chi tiết: cd $N8N_DIR && docker-compose logs [service_name]"
echo ""
echo "✅ Hoàn tất chẩn đoán!"
EOF
chmod +x $N8N_DIR/troubleshoot.sh

# Đặt quyền cho thư mục n8n
echo "Đặt quyền cho thư mục n8n tại $N8N_DIR..."
chown -R 1000:1000 $N8N_DIR 
chmod -R u+rwX,g+rX,o+rX $N8N_DIR
chown -R 1000:1000 $N8N_DIR/files
chmod -R u+rwX,g+rX,o+rX $N8N_DIR/files

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

echo "Đang build Docker images... (có thể mất vài phút)"
if ! $DOCKER_COMPOSE_CMD build; then
    echo "Cảnh báo: Build Docker images thất bại."
    echo "Đang thử build lại với cấu hình đơn giản hơn..."
    
    # Sử dụng Dockerfile.simple cho n8n
    sed -i 's/dockerfile: Dockerfile/dockerfile: Dockerfile.simple/' $N8N_DIR/docker-compose.yml
    
    if ! $DOCKER_COMPOSE_CMD build; then
        echo "Lỗi: Không thể build Docker images thậm chí với cấu hình đơn giản."
        echo "Kiểm tra kết nối mạng và thử lại."
        exit 1
    fi
    echo "✅ Build thành công với cấu hình đơn giản."
fi

echo "Đang khởi động các container..."
if ! $DOCKER_COMPOSE_CMD up -d; then
    echo "Lỗi: Khởi động container thất bại."
    echo "Kiểm tra logs: $DOCKER_COMPOSE_CMD logs"
    exit 1
fi

echo "Đợi các container khởi động và SSL được cấp (60 giây)..."
sleep 60

# Kiểm tra các container đã chạy chưa
echo "Kiểm tra trạng thái các container..."
if $DOCKER_COMPOSE_CMD ps | grep -q "n8n"; then
    echo "✅ Container n8n đã chạy thành công."
else
    echo "⚠️ Container n8n có thể chưa chạy. Kiểm tra logs: $DOCKER_COMPOSE_CMD logs n8n"
fi

if $DOCKER_COMPOSE_CMD ps | grep -q "caddy"; then
    echo "✅ Container caddy đã chạy thành công."
else
    echo "⚠️ Container caddy có thể chưa chạy. Kiểm tra logs: $DOCKER_COMPOSE_CMD logs caddy"
fi

if [[ "$INSTALL_NEWS_API" =~ ^[Yy]$ ]] && $DOCKER_COMPOSE_CMD ps | grep -q "fastapi"; then
    echo "✅ Container FastAPI đã chạy thành công."
elif [[ "$INSTALL_NEWS_API" =~ ^[Yy]$ ]]; then
    echo "⚠️ Container FastAPI có thể chưa chạy. Kiểm tra logs: $DOCKER_COMPOSE_CMD logs fastapi"
fi

# Kiểm tra SSL
echo "🔒 Kiểm tra SSL certificates..."
sleep 10
if curl -s -I https://$DOMAIN | grep -q "200 OK"; then
    echo "✅ SSL cho $DOMAIN hoạt động bình thường."
else
    echo "⚠️ SSL cho $DOMAIN có thể chưa sẵn sàng. Đợi thêm vài phút và thử lại."
fi

if [[ "$INSTALL_NEWS_API" =~ ^[Yy]$ ]]; then
    if curl -s -I https://$API_DOMAIN | grep -q "200 OK"; then
        echo "✅ SSL cho $API_DOMAIN hoạt động bình thường."
    else
        echo "⚠️ SSL cho $API_DOMAIN có thể chưa sẵn sàng. Đợi thêm vài phút và thử lại."
    fi
fi

# Tạo script cập nhật tự động
echo "Tạo script cập nhật tự động tại $N8N_DIR/update-n8n.sh..."
cat << EOF > $N8N_DIR/update-n8n.sh
#!/bin/bash
N8N_DIR_VALUE="$N8N_DIR"
LOG_FILE="\$N8N_DIR_VALUE/update.log"
ENABLE_AUTO_UPDATE="$ENABLE_AUTO_UPDATE"

log() { echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" >> "\$LOG_FILE"; }

# Kiểm tra nếu auto-update bị tắt
if [[ "\$ENABLE_AUTO_UPDATE" =~ ^[Nn]\$ ]]; then
    log "Auto-update bị tắt. Bỏ qua cập nhật."
    exit 0
fi

log "Bắt đầu kiểm tra cập nhật..."
cd "\$N8N_DIR_VALUE"

if command -v docker-compose &> /dev/null; then 
    DOCKER_COMPOSE="docker-compose"
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then 
    DOCKER_COMPOSE="docker compose"
else 
    log "Lỗi: Docker Compose không tìm thấy."
    exit 1
fi

log "Cập nhật yt-dlp trên host..."
if command -v pipx &> /dev/null; then 
    pipx upgrade yt-dlp > /dev/null 2>&1
elif [ -d "/opt/yt-dlp-venv" ]; then 
    /opt/yt-dlp-venv/bin/pip install -U yt-dlp > /dev/null 2>&1
fi

log "Kéo image n8nio/n8n mới nhất..."
docker pull n8nio/n8n:latest > /dev/null 2>&1

CURRENT_CUSTOM_IMAGE_ID="\$(docker images -q n8n-custom-ffmpeg 2>/dev/null)"
log "Build lại image custom n8n..."
if ! \$DOCKER_COMPOSE build n8n > /dev/null 2>&1; then 
    log "Lỗi build image custom."
    exit 1
fi

NEW_CUSTOM_IMAGE_ID="\$(docker images -q n8n-custom-ffmpeg 2>/dev/null)"
if [ "\$CURRENT_CUSTOM_IMAGE_ID" != "\$NEW_CUSTOM_IMAGE_ID" ]; then
    log "Phát hiện image mới, tiến hành cập nhật n8n..."
    
    # Chạy backup trước khi cập nhật
    log "Chạy backup trước khi cập nhật..."
    if [ -x "\$N8N_DIR_VALUE/backup-workflows.sh" ]; then
        "\$N8N_DIR_VALUE/backup-workflows.sh"
    fi
    
    log "Dừng và khởi động lại containers..."
    \$DOCKER_COMPOSE down > /dev/null 2>&1
    \$DOCKER_COMPOSE up -d > /dev/null 2>&1
    log "Cập nhật n8n hoàn tất."
else
    log "Không có cập nhật mới cho image n8n custom."
fi

log "Cập nhật yt-dlp trong container n8n..."
N8N_CONTAINER_FOR_UPDATE="\$(docker ps -q --filter name=n8n)"
if [ -n "\$N8N_CONTAINER_FOR_UPDATE" ]; then
    docker exec -u root \$N8N_CONTAINER_FOR_UPDATE pip3 install --break-system-packages -U yt-dlp > /dev/null 2>&1
    log "yt-dlp trong container đã được cập nhật."
fi

log "Kiểm tra cập nhật hoàn tất."
EOF
chmod +x $N8N_DIR/update-n8n.sh

# Thiết lập cron job
CRON_USER=$(whoami)
BACKUP_CRON="0 2 * * * $N8N_DIR/backup-workflows.sh"

if [[ "$ENABLE_AUTO_UPDATE" =~ ^[Yy]$ ]]; then
    UPDATE_CRON="0 */12 * * * $N8N_DIR/update-n8n.sh"
    (crontab -u $CRON_USER -l 2>/dev/null | grep -v "update-n8n.sh" | grep -v "backup-workflows.sh"; echo "$UPDATE_CRON"; echo "$BACKUP_CRON") | crontab -u $CRON_USER -
    echo "✅ Đã thiết lập cron job cập nhật tự động mỗi 12 giờ và sao lưu hàng ngày."
else
    (crontab -u $CRON_USER -l 2>/dev/null | grep -v "update-n8n.sh" | grep -v "backup-workflows.sh"; echo "$BACKUP_CRON") | crontab -u $CRON_USER -
    echo "✅ Đã thiết lập cron job sao lưu hàng ngày (auto-update bị tắt)."
fi

echo "======================================================================"
echo "🎉 N8N ĐÃ ĐƯỢC CÀI ĐẶT THÀNH CÔNG!"
echo "======================================================================"
echo ""
echo "🌐 Truy cập N8N tại: https://${DOMAIN}"
if [[ "$INSTALL_NEWS_API" =~ ^[Yy]$ ]]; then
    echo "📰 Truy cập News API tại: https://${API_DOMAIN}"
    echo "🔑 Bearer Token: $NEWS_API_TOKEN"
    echo "📚 API Docs: https://${API_DOMAIN}/docs"
fi
echo ""
echo "📊 THÔNG TIN HỆ THỐNG:"
if [ "$(swapon --show | wc -l)" -gt 0 ]; then
    SWAP_INFO=$(free -h | grep Swap | awk '{print $2}')
    echo "💾 Swap: $SWAP_INFO"
fi
echo "📁 Thư mục cài đặt: $N8N_DIR"
echo "🎬 Thư mục video: $N8N_DIR/files/youtube_content_anylystic/"
echo ""
echo "🔄 TÍNH NĂNG TỰ ĐỘNG:"
if [[ "$ENABLE_AUTO_UPDATE" =~ ^[Yy]$ ]]; then
    echo "✅ Auto-update: Mỗi 12 giờ (Log: $N8N_DIR/update.log)"
else
    echo "❌ Auto-update: Đã tắt"
fi
echo "💾 Backup: Hàng ngày lúc 2:00 AM"
echo "📁 File backup: $N8N_DIR/files/backup_full/"
echo "📋 Log backup: $N8N_DIR/files/backup_full/backup.log"
if [ -f "$TELEGRAM_CONF_FILE" ]; then
    echo "📱 Telegram: Đã cấu hình (file <20MB sẽ được gửi)"
fi
echo ""
echo "🛠️ LỆNH HỮU ÍCH:"
echo "🧪 Test backup: $N8N_DIR/backup-manual.sh"
echo "🔍 Chẩn đoán: $N8N_DIR/troubleshoot.sh"
echo "📊 Xem logs: cd $N8N_DIR && docker-compose logs -f"
echo "🔄 Restart: cd $N8N_DIR && docker-compose restart"
echo ""
if [[ "$INSTALL_NEWS_API" =~ ^[Yy]$ ]]; then
    echo "🔧 ĐỔI BEARER TOKEN:"
    echo "cd $N8N_DIR && sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN=\"NEW_TOKEN\"/' docker-compose.yml && docker-compose restart fastapi"
    echo ""
fi
echo "👨‍💻 TÁC GIẢ: Nguyễn Ngọc Thiện"
echo "📺 YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1"
echo "📘 Facebook: https://www.facebook.com/Ban.Thien.Handsome/"
echo "📱 Zalo: 08.8888.4749"
echo "======================================================================"
