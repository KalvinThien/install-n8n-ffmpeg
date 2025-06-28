#!/bin/bash

# Hiển thị banner
echo "======================================================================"
echo "     🚀 Script Cài Đặt N8N với FFmpeg, yt-dlp, Puppeteer và News API"
echo "                (Phiên bản cải tiến với Backup Telegram)             "
echo "======================================================================"
echo "👨‍💻 Tác giả: Nguyễn Ngọc Thiện"
echo "📺 YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1"
echo "📱 Zalo: 08.8888.4749"
echo "======================================================================"

# Thiết lập DEBIAN_FRONTEND để tránh interactive prompts
export DEBIAN_FRONTEND=noninteractive

# Kiểm tra xem script có được chạy với quyền root không
if [[ $EUID -ne 0 ]]; then
   echo "❌ Script này cần được chạy với quyền root" 
   exit 1
fi

# Hàm thiết lập swap tự động
setup_swap() {
    echo "🔄 Kiểm tra và thiết lập swap tự động..."
    
    if [ "$(swapon --show | wc -l)" -gt 0 ]; then
        SWAP_SIZE=$(free -h | grep Swap | awk '{print $2}')
        echo "✅ Swap đã được bật với kích thước ${SWAP_SIZE}. Bỏ qua thiết lập."
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
    
    echo "🔄 Đang thiết lập swap với kích thước ${SWAP_GB}GB (${SWAP_SIZE}MB)..."
    
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
    
    echo "✅ Đã thiết lập swap với kích thước ${SWAP_GB}GB thành công."
}

# Hàm hiển thị trợ giúp
show_help() {
    echo "Cách sử dụng: $0 [tùy chọn]"
    echo "Tùy chọn:"
    echo "  -h, --help      Hiển thị trợ giúp này"
    echo "  -d, --dir DIR   Chỉ định thư mục cài đặt n8n (mặc định: /home/n8n)"
    echo "  -s, --skip-docker Bỏ qua cài đặt Docker (nếu đã có)"
    echo "  --clean         Xóa tất cả cài đặt cũ trước khi cài mới"
    exit 0
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
            echo "❌ Tùy chọn không hợp lệ: $1"
            show_help
            ;;
    esac
done

# Hàm dọn dẹp cài đặt cũ
cleanup_old_installation() {
    echo "🧹 Đang dọn dẹp cài đặt cũ..."
    
    # Dừng và xóa containers
    echo "  🔄 Dừng và xóa containers cũ..."
    docker stop $(docker ps -aq --filter "name=n8n") 2>/dev/null || true
    docker stop $(docker ps -aq --filter "name=caddy") 2>/dev/null || true
    docker stop $(docker ps -aq --filter "name=fastapi") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "name=n8n") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "name=caddy") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "name=fastapi") 2>/dev/null || true
    
    # Xóa images cũ
    echo "  🗑️ Xóa Docker images cũ..."
    docker rmi $(docker images -q "n8n-custom-ffmpeg") 2>/dev/null || true
    docker rmi $(docker images -q "*n8n*") 2>/dev/null || true
    docker rmi $(docker images -q "*fastapi*") 2>/dev/null || true
    
    # Xóa volumes
    echo "  📦 Xóa Docker volumes cũ..."
    docker volume rm $(docker volume ls -q | grep -E "(n8n|caddy)") 2>/dev/null || true
    
    # Xóa networks
    echo "  🌐 Xóa Docker networks cũ..."
    docker network rm $(docker network ls -q --filter "name=n8n") 2>/dev/null || true
    
    # Xóa thư mục cài đặt cũ
    if [ -d "$N8N_DIR" ]; then
        echo "  📁 Xóa thư mục cài đặt cũ: $N8N_DIR"
        rm -rf "$N8N_DIR"
    fi
    
    # Xóa cron jobs cũ
    echo "  ⏰ Xóa cron jobs cũ..."
    crontab -l 2>/dev/null | grep -v "update-n8n.sh" | grep -v "backup-workflows.sh" | crontab - 2>/dev/null || true
    
    # Docker system prune
    echo "  🧹 Dọn dẹp Docker system..."
    docker system prune -af --volumes
    
    echo "  ✅ Đã dọn dẹp Docker system"
    echo "🎉 Hoàn tất dọn dẹp cài đặt cũ!"
}

# Hỏi người dùng có muốn dọn dẹp không (nếu không dùng --clean flag)
if [ "$CLEAN_INSTALL" = false ]; then
    read -p "🧹 Bạn có muốn xóa tất cả cài đặt N8N cũ không? (y/n): " CLEAN_CHOICE
    if [[ "$CLEAN_CHOICE" =~ ^[Yy]$ ]]; then
        cleanup_old_installation
    fi
else
    cleanup_old_installation
fi

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
            echo "🔄 Lệnh '$cmd' không tìm thấy. Đang cài đặt..."
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
                 echo "❌ Lỗi: Không thể cài đặt lệnh '$cmd'. Vui lòng cài đặt thủ công và chạy lại script."
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
        echo "✅ Docker đã được cài đặt và bỏ qua theo yêu cầu..."
        return
    fi
    
    if command -v docker &> /dev/null; then
        echo "✅ Docker đã được cài đặt."
    else
        echo "🔄 Cài đặt Docker..."
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
        echo "✅ Docker Compose (hoặc plugin) đã được cài đặt."
    else 
        echo "🔄 Cài đặt Docker Compose plugin..."
        apt-get install -y docker-compose-plugin
        if ! (docker compose version &> /dev/null); then 
            echo "🔄 Không cài được plugin, thử cài docker-compose bản cũ..." 
            apt-get install -y docker-compose 
        fi
    fi
    
    if ! command -v docker &> /dev/null; then
        echo "❌ Lỗi: Docker chưa được cài đặt đúng cách."
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! (command -v docker &> /dev/null && docker compose version &> /dev/null); then
        echo "❌ Lỗi: Docker Compose chưa được cài đặt đúng cách."
        exit 1
    fi

    if [ "$SUDO_USER" != "" ]; then
        echo "🔄 Thêm user $SUDO_USER vào nhóm docker..."
        usermod -aG docker $SUDO_USER
        echo "✅ Đã thêm. Thay đổi có hiệu lực sau khi đăng nhập lại hoặc chạy 'newgrp docker'."
    fi
    systemctl enable docker
    systemctl restart docker
    echo "✅ Docker và Docker Compose đã được cài đặt/kiểm tra thành công."
}

# Cài đặt các gói cần thiết
echo "🔄 Đang kiểm tra và cài đặt các công cụ cần thiết..."
apt-get update > /dev/null 2>&1
apt-get install -y dnsutils curl cron jq tar gzip python3-full python3-venv pipx net-tools bc

# Cài đặt yt-dlp
echo "🔄 Cài đặt yt-dlp..."
if command -v pipx &> /dev/null; then
    pipx install yt-dlp --force
    pipx ensurepath
else
    python3 -m venv /opt/yt-dlp-venv
    /opt/yt-dlp-venv/bin/pip install -U pip yt-dlp
    ln -sf /opt/yt-dlp-venv/bin/yt-dlp /usr/local/bin/yt-dlp
    chmod +x /usr/local/bin/yt-dlp
fi
export PATH="$PATH:/usr/local/bin:/opt/yt-dlp-venv/bin:$HOME/.local/bin"

# Đảm bảo cron service đang chạy
systemctl enable cron
systemctl start cron

# Kiểm tra các lệnh (bao gồm Docker)
check_commands

# Nhận input domain từ người dùng
read -p "🌐 Nhập tên miền chính của bạn (ví dụ: google.com ): " DOMAIN
while ! check_domain $DOMAIN; do
    echo "❌ Domain $DOMAIN chưa được trỏ đúng đến IP server này ($(curl -s https://api.ipify.org))."
    echo "📝 Vui lòng cập nhật bản ghi DNS để trỏ $DOMAIN đến IP $(curl -s https://api.ipify.org)." 
    read -p "🔄 Nhấn Enter sau khi cập nhật DNS, hoặc nhập domain khác: " NEW_DOMAIN
    if [ -n "$NEW_DOMAIN" ]; then
        DOMAIN="$NEW_DOMAIN"
    fi
done
echo "✅ Domain $DOMAIN đã được trỏ đúng. Tiếp tục cài đặt."

# Hỏi cài đặt FastAPI
INSTALL_FASTAPI=false
read -p "📰 Bạn có muốn cài đặt FastAPI để cào nội dung bài viết không? (y/n): " FASTAPI_CHOICE
if [[ "$FASTAPI_CHOICE" =~ ^[Yy]$ ]]; then
    INSTALL_FASTAPI=true
    API_DOMAIN="api.$DOMAIN"
    echo "🔄 Sẽ tạo API tại: $API_DOMAIN"
    
    # Kiểm tra API domain
    echo "🔍 Kiểm tra domain API: $API_DOMAIN"
    while ! check_domain $API_DOMAIN; do
        echo "❌ Domain API $API_DOMAIN chưa được trỏ đúng đến IP server này ($(curl -s https://api.ipify.org))."
        echo "📝 Vui lòng cập nhật bản ghi DNS để trỏ $API_DOMAIN đến IP $(curl -s https://api.ipify.org)."
        read -p "🔄 Nhấn Enter sau khi cập nhật DNS API domain: "
    done
    echo "✅ Domain API $API_DOMAIN đã được trỏ đúng."
    
    # Nhập Bearer Token
    while true; do
        read -p "🔐 Nhập Bearer Token của bạn (ít nhất 20 ký tự, chỉ chữ và số): " BEARER_TOKEN
        if [[ ${#BEARER_TOKEN} -ge 20 && "$BEARER_TOKEN" =~ ^[a-zA-Z0-9]+$ ]]; then
            echo "✅ Bearer Token hợp lệ!"
            break
        else
            echo "❌ Bearer Token phải có ít nhất 20 ký tự và chỉ chứa chữ cái và số!"
        fi
    done
fi

# Tạo thư mục cho n8n
echo "🔄 Tạo cấu trúc thư mục cho n8n tại $N8N_DIR..."
mkdir -p $N8N_DIR
mkdir -p $N8N_DIR/files
mkdir -p $N8N_DIR/files/temp
mkdir -p $N8N_DIR/files/youtube_content_anylystic
mkdir -p $N8N_DIR/files/backup_full

# Tạo Dockerfile
echo "🔄 Tạo Dockerfile..."
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
RUN npm install n8n-nodes-puppeteer || echo "Cảnh báo: Không thể cài đặt n8n-nodes-puppeteer, tiếp tục mà không có nó"
RUN mkdir -p /files/youtube_content_anylystic /files/backup_full /files/temp && \
    chown -R node:node /files
USER node
WORKDIR /home/node
EOF

# Cài đặt News Content API nếu được chọn
if [ "$INSTALL_FASTAPI" = true ]; then
    echo "🔄 Cài đặt News Content API..."
    mkdir -p $N8N_DIR/news_api
    
    # Tạo requirements.txt với phiên bản mới nhất
    cat << 'EOF' > $N8N_DIR/news_api/requirements.txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
newspaper4k==0.9.3.1
python-multipart==0.0.6
jinja2==3.1.2
aiofiles==23.2.1
requests==2.31.0
lxml==4.9.3
beautifulsoup4==4.12.2
feedparser==6.0.10
python-dateutil==2.8.2
EOF

    # Tạo main.py cho FastAPI
    cat << 'EOF' > $N8N_DIR/news_api/main.py
from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, HttpUrl
from typing import List, Optional, Dict, Any
import newspaper
from newspaper import Article, Source
import feedparser
import requests
from datetime import datetime
import os
import logging
import asyncio
from concurrent.futures import ThreadPoolExecutor
import json

# Cấu hình logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Khởi tạo FastAPI app
app = FastAPI(
    title="News Content API",
    description="API để cào nội dung bài viết và RSS feeds với Newspaper4k",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Security
security = HTTPBearer()
BEARER_TOKEN = os.getenv("NEWS_API_TOKEN", "default_token_change_me")

# Templates
templates = Jinja2Templates(directory="/app/templates")

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if credentials.credentials != BEARER_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid authentication token")
    return credentials.credentials

# Models
class ArticleRequest(BaseModel):
    url: HttpUrl
    language: str = "en"
    extract_images: bool = True
    summarize: bool = False

class SourceRequest(BaseModel):
    url: HttpUrl
    max_articles: int = 10
    language: str = "en"

class FeedRequest(BaseModel):
    url: HttpUrl
    max_articles: int = 10

class ArticleResponse(BaseModel):
    title: str
    content: str
    summary: str
    authors: List[str]
    publish_date: Optional[str]
    images: List[str]
    url: str
    word_count: int
    read_time_minutes: int

class SourceResponse(BaseModel):
    articles: List[ArticleResponse]
    total_found: int

class FeedResponse(BaseModel):
    articles: List[Dict[str, Any]]
    total_found: int

# Executor cho async operations
executor = ThreadPoolExecutor(max_workers=4)

def extract_article_sync(url: str, language: str = "en") -> Dict[str, Any]:
    """Đồng bộ extract article"""
    try:
        article = Article(str(url), language=language)
        article.download()
        article.parse()
        article.nlp()
        
        # Tính thời gian đọc (giả sử 200 từ/phút)
        word_count = len(article.text.split()) if article.text else 0
        read_time = max(1, word_count // 200)
        
        return {
            "title": article.title or "",
            "content": article.text or "",
            "summary": article.summary or "",
            "authors": article.authors or [],
            "publish_date": article.publish_date.isoformat() if article.publish_date else None,
            "images": list(article.images) if article.images else [],
            "url": str(url),
            "word_count": word_count,
            "read_time_minutes": read_time
        }
    except Exception as e:
        logger.error(f"Error extracting article {url}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Failed to extract article: {str(e)}")

async def extract_article_async(url: str, language: str = "en") -> Dict[str, Any]:
    """Async wrapper cho extract article"""
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(executor, extract_article_sync, url, language)

@app.get("/", response_class=HTMLResponse)
async def homepage(request: Request):
    """Homepage với hướng dẫn sử dụng API"""
    domain = request.headers.get("host", "api.yourdomain.com")
    
    html_content = f"""
    <!DOCTYPE html>
    <html lang="vi">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>News Content API - Nguyễn Ngọc Thiện</title>
        <style>
            * {{ margin: 0; padding: 0; box-sizing: border-box; }}
            body {{ 
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                color: #333;
            }}
            .container {{ 
                max-width: 1200px; 
                margin: 0 auto; 
                padding: 20px;
            }}
            .header {{
                background: rgba(255,255,255,0.95);
                border-radius: 15px;
                padding: 30px;
                margin-bottom: 30px;
                box-shadow: 0 10px 30px rgba(0,0,0,0.1);
                text-align: center;
            }}
            .header h1 {{
                color: #2c3e50;
                margin-bottom: 10px;
                font-size: 2.5em;
            }}
            .header p {{
                color: #7f8c8d;
                font-size: 1.1em;
            }}
            .author-info {{
                background: rgba(255,255,255,0.95);
                border-radius: 15px;
                padding: 25px;
                margin-bottom: 30px;
                box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            }}
            .author-info h2 {{
                color: #e74c3c;
                margin-bottom: 15px;
                text-align: center;
            }}
            .author-links {{
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
                gap: 15px;
                margin-top: 15px;
            }}
            .author-link {{
                display: block;
                padding: 12px 20px;
                background: linear-gradient(45deg, #3498db, #2980b9);
                color: white;
                text-decoration: none;
                border-radius: 8px;
                text-align: center;
                transition: transform 0.3s ease;
            }}
            .author-link:hover {{
                transform: translateY(-2px);
                box-shadow: 0 5px 15px rgba(0,0,0,0.2);
            }}
            .youtube-link {{
                background: linear-gradient(45deg, #ff0000, #cc0000) !important;
                font-weight: bold;
                font-size: 1.1em;
            }}
            .api-section {{
                background: rgba(255,255,255,0.95);
                border-radius: 15px;
                padding: 30px;
                margin-bottom: 30px;
                box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            }}
            .api-section h2 {{
                color: #2c3e50;
                margin-bottom: 20px;
                border-bottom: 3px solid #3498db;
                padding-bottom: 10px;
            }}
            .token-info {{
                background: #f8f9fa;
                border: 2px solid #28a745;
                border-radius: 10px;
                padding: 20px;
                margin: 20px 0;
            }}
            .token-info h3 {{
                color: #28a745;
                margin-bottom: 10px;
            }}
            .token-value {{
                font-family: 'Courier New', monospace;
                background: #e9ecef;
                padding: 10px;
                border-radius: 5px;
                font-size: 1.1em;
                word-break: break-all;
                border: 1px solid #ced4da;
            }}
            .endpoint {{
                background: #f8f9fa;
                border-radius: 10px;
                padding: 20px;
                margin: 20px 0;
                border-left: 5px solid #3498db;
            }}
            .endpoint h3 {{
                color: #2c3e50;
                margin-bottom: 15px;
            }}
            .curl-command {{
                background: #2c3e50;
                color: #ecf0f1;
                padding: 15px;
                border-radius: 8px;
                font-family: 'Courier New', monospace;
                font-size: 0.9em;
                overflow-x: auto;
                white-space: pre-wrap;
                word-break: break-all;
                position: relative;
                margin: 10px 0;
            }}
            .copy-btn {{
                position: absolute;
                top: 10px;
                right: 10px;
                background: #3498db;
                color: white;
                border: none;
                padding: 5px 10px;
                border-radius: 5px;
                cursor: pointer;
                font-size: 0.8em;
            }}
            .copy-btn:hover {{
                background: #2980b9;
            }}
            .links {{
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                gap: 15px;
                margin-top: 20px;
            }}
            .link {{
                display: block;
                padding: 15px;
                background: linear-gradient(45deg, #27ae60, #2ecc71);
                color: white;
                text-decoration: none;
                border-radius: 10px;
                text-align: center;
                transition: transform 0.3s ease;
            }}
            .link:hover {{
                transform: translateY(-2px);
                box-shadow: 0 5px 15px rgba(0,0,0,0.2);
            }}
            @media (max-width: 768px) {{
                .container {{ padding: 10px; }}
                .header h1 {{ font-size: 2em; }}
                .curl-command {{ font-size: 0.8em; }}
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🚀 News Content API</h1>
                <p>API cào nội dung bài viết với Newspaper4k và FastAPI</p>
            </div>

            <div class="author-info">
                <h2>👨‍💻 Tác giả: Nguyễn Ngọc Thiện</h2>
                <div class="author-links">
                    <a href="https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1" class="author-link youtube-link" target="_blank">
                        📺 ĐĂNG KÝ YOUTUBE CHANNEL
                    </a>
                    <a href="https://www.facebook.com/Ban.Thien.Handsome/" class="author-link" target="_blank">
                        📘 Facebook
                    </a>
                    <a href="tel:0888884749" class="author-link">
                        📱 Zalo: 08.8888.4749
                    </a>
                    <a href="https://www.youtube.com/@kalvinthiensocial/playlists" class="author-link" target="_blank">
                        🎬 N8N Playlist
                    </a>
                </div>
            </div>

            <div class="token-info">
                <h3>🔑 Bearer Token của bạn:</h3>
                <div class="token-value">{BEARER_TOKEN}</div>
                <p><strong>Lưu ý:</strong> Sử dụng token này trong header Authorization: Bearer YOUR_TOKEN</p>
            </div>

            <div class="api-section">
                <h2>📚 API Endpoints</h2>
                
                <div class="endpoint">
                    <h3>1. 🩺 Kiểm tra trạng thái API</h3>
                    <div class="curl-command">curl -X GET "https://{domain}/health" \\
     -H "Authorization: Bearer {BEARER_TOKEN}"<button class="copy-btn" onclick="copyToClipboard(this)">Copy</button></div>
                </div>

                <div class="endpoint">
                    <h3>2. 📰 Lấy nội dung bài viết</h3>
                    <div class="curl-command">curl -X POST "https://{domain}/extract-article" \\
     -H "Content-Type: application/json" \\
     -H "Authorization: Bearer {BEARER_TOKEN}" \\
     -d '{{
       "url": "https://dantri.com.vn/the-gioi.htm",
       "language": "vi",
       "extract_images": true,
       "summarize": true
     }}'<button class="copy-btn" onclick="copyToClipboard(this)">Copy</button></div>
                </div>

                <div class="endpoint">
                    <h3>3. 🌐 Cào nhiều bài viết từ website</h3>
                    <div class="curl-command">curl -X POST "https://{domain}/extract-source" \\
     -H "Content-Type: application/json" \\
     -H "Authorization: Bearer {BEARER_TOKEN}" \\
     -d '{{
       "url": "https://dantri.com.vn",
       "max_articles": 10,
       "language": "vi"
     }}'<button class="copy-btn" onclick="copyToClipboard(this)">Copy</button></div>
                </div>

                <div class="endpoint">
                    <h3>4. 📡 Parse RSS Feed</h3>
                    <div class="curl-command">curl -X POST "https://{domain}/parse-feed" \\
     -H "Content-Type: application/json" \\
     -H "Authorization: Bearer {BEARER_TOKEN}" \\
     -d '{{
       "url": "https://dantri.com.vn/rss.xml",
       "max_articles": 10
     }}'<button class="copy-btn" onclick="copyToClipboard(this)">Copy</button></div>
                </div>
            </div>

            <div class="api-section">
                <h2>🔗 Liên kết hữu ích</h2>
                <div class="links">
                    <a href="/docs" class="link">📖 Swagger UI</a>
                    <a href="/redoc" class="link">📚 ReDoc</a>
                    <a href="/health" class="link">🩺 Health Check</a>
                </div>
            </div>
        </div>

        <script>
            function copyToClipboard(button) {{
                const codeBlock = button.parentElement;
                const text = codeBlock.textContent.replace('Copy', '').trim();
                
                navigator.clipboard.writeText(text).then(function() {{
                    button.textContent = 'Copied!';
                    button.style.background = '#27ae60';
                    setTimeout(function() {{
                        button.textContent = 'Copy';
                        button.style.background = '#3498db';
                    }}, 2000);
                }}).catch(function(err) {{
                    console.error('Could not copy text: ', err);
                    button.textContent = 'Error';
                    setTimeout(function() {{
                        button.textContent = 'Copy';
                    }}, 2000);
                }});
            }}
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

@app.get("/health")
async def health_check(token: str = Depends(verify_token)):
    """Kiểm tra trạng thái API"""
    return {
        "status": "healthy",
        "message": "News Content API đang hoạt động",
        "version": "2.0.0",
        "timestamp": datetime.now().isoformat()
    }

@app.post("/extract-article", response_model=ArticleResponse)
async def extract_article(request: ArticleRequest, token: str = Depends(verify_token)):
    """Lấy nội dung bài viết từ URL"""
    try:
        result = await extract_article_async(str(request.url), request.language)
        return ArticleResponse(**result)
    except Exception as e:
        logger.error(f"Error in extract_article: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.post("/extract-source", response_model=SourceResponse)
async def extract_source(request: SourceRequest, token: str = Depends(verify_token)):
    """Cào nhiều bài viết từ một website"""
    try:
        def extract_source_sync():
            source = Source(str(request.url), language=request.language)
            source.build()
            
            articles = []
            for i, article_url in enumerate(source.article_urls()[:request.max_articles]):
                try:
                    article_data = extract_article_sync(article_url, request.language)
                    articles.append(ArticleResponse(**article_data))
                except Exception as e:
                    logger.warning(f"Failed to extract article {article_url}: {str(e)}")
                    continue
            
            return articles
        
        loop = asyncio.get_event_loop()
        articles = await loop.run_in_executor(executor, extract_source_sync)
        
        return SourceResponse(articles=articles, total_found=len(articles))
    except Exception as e:
        logger.error(f"Error in extract_source: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.post("/parse-feed", response_model=FeedResponse)
async def parse_feed(request: FeedRequest, token: str = Depends(verify_token)):
    """Parse RSS feed và lấy thông tin bài viết"""
    try:
        def parse_feed_sync():
            feed = feedparser.parse(str(request.url))
            articles = []
            
            for entry in feed.entries[:request.max_articles]:
                article_data = {
                    "title": getattr(entry, 'title', ''),
                    "link": getattr(entry, 'link', ''),
                    "description": getattr(entry, 'description', ''),
                    "published": getattr(entry, 'published', ''),
                    "author": getattr(entry, 'author', ''),
                    "tags": [tag.term for tag in getattr(entry, 'tags', [])],
                    "summary": getattr(entry, 'summary', '')
                }
                articles.append(article_data)
            
            return articles
        
        loop = asyncio.get_event_loop()
        articles = await loop.run_in_executor(executor, parse_feed_sync)
        
        return FeedResponse(articles=articles, total_found=len(articles))
    except Exception as e:
        logger.error(f"Error in parse_feed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

    # Tạo Dockerfile cho FastAPI
    cat << 'EOF' > $N8N_DIR/news_api/Dockerfile
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
    libffi-dev \
    libssl-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements và cài đặt Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py .

# Tạo thư mục templates (nếu cần)
RUN mkdir -p /app/templates

# Expose port
EXPOSE 8000

# Command để chạy ứng dụng
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
EOF

    echo "✅ Đã tạo News API thành công!"
fi

# Tạo file docker-compose.yml
echo "🔄 Tạo file docker-compose.yml..."
if [ "$INSTALL_FASTAPI" = true ]; then
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
      - NEWS_API_TOKEN=${BEARER_TOKEN}
    depends_on:
      - n8n

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

    echo "🔑 Bearer Token cho News API: $BEARER_TOKEN"
    echo "📝 Lưu token này để sử dụng API!"
    
    # Lưu Bearer Token vào file
    echo "$BEARER_TOKEN" > $N8N_DIR/news_api_token.txt
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

# Tạo file Caddyfile với SSL configuration cải tiến
echo "🔄 Tạo file Caddyfile..."
if [ "$INSTALL_FASTAPI" = true ]; then
    cat << EOF > $N8N_DIR/Caddyfile
# N8N Main Domain
${DOMAIN} {
    reverse_proxy n8n:5678
    
    # SSL Configuration
    tls {
        protocols tls1.2 tls1.3
    }
    
    # Security Headers
    header {
        # Enable HSTS
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        # Prevent XSS attacks
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        # Remove server info
        -Server
    }
    
    # Enable compression
    encode gzip
    
    # Logging
    log {
        output file /var/log/caddy/${DOMAIN}.log
        format json
    }
}

# FastAPI News API Domain
${API_DOMAIN} {
    reverse_proxy fastapi:8000
    
    # SSL Configuration
    tls {
        protocols tls1.2 tls1.3
    }
    
    # Security Headers
    header {
        # Enable HSTS
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        # Prevent XSS attacks
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        # CORS headers for API
        Access-Control-Allow-Origin "*"
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        Access-Control-Allow-Headers "Content-Type, Authorization"
        # Remove server info
        -Server
    }
    
    # Enable compression
    encode gzip
    
    # Logging
    log {
        output file /var/log/caddy/${API_DOMAIN}.log
        format json
    }
}
EOF
else
    cat << EOF > $N8N_DIR/Caddyfile
# N8N Main Domain
${DOMAIN} {
    reverse_proxy n8n:5678
    
    # SSL Configuration
    tls {
        protocols tls1.2 tls1.3
    }
    
    # Security Headers
    header {
        # Enable HSTS
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        # Prevent XSS attacks
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        # Remove server info
        -Server
    }
    
    # Enable compression
    encode gzip
    
    # Logging
    log {
        output file /var/log/caddy/${DOMAIN}.log
        format json
    }
}
EOF
fi

# Cấu hình gửi backup qua Telegram
TELEGRAM_CONF_FILE="$N8N_DIR/telegram_config.txt"
read -p "📱 Bạn có muốn cấu hình gửi file backup hàng ngày qua Telegram không? (y/n): " CONFIGURE_TELEGRAM
if [[ "$CONFIGURE_TELEGRAM" =~ ^[Yy]$ ]]; then
    echo "📝 Để gửi backup qua Telegram, bạn cần một Bot Token và Chat ID."
    echo "🤖 Hướng dẫn lấy Bot Token: Nói chuyện với BotFather trên Telegram (tìm @BotFather), gõ /newbot, làm theo hướng dẫn."
    echo "🆔 Hướng dẫn lấy Chat ID: Nói chuyện với bot @userinfobot trên Telegram, nó sẽ hiển thị User ID của bạn."
    echo "👥 Nếu muốn gửi vào group, thêm bot của bạn vào group, sau đó gửi lệnh /my_id @TenBotCuaBan trong group đó."
    echo "📋 Chat ID của group sẽ bắt đầu bằng dấu trừ (-)."
    read -p "🔑 Nhập Telegram Bot Token của bạn: " TELEGRAM_BOT_TOKEN
    read -p "🆔 Nhập Telegram Chat ID của bạn (hoặc group ID): " TELEGRAM_CHAT_ID
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        echo "TELEGRAM_BOT_TOKEN=\"$TELEGRAM_BOT_TOKEN\"" > "$TELEGRAM_CONF_FILE"
        echo "TELEGRAM_CHAT_ID=\"$TELEGRAM_CHAT_ID\"" >> "$TELEGRAM_CONF_FILE"
        chmod 600 "$TELEGRAM_CONF_FILE"
        echo "✅ Đã lưu cấu hình Telegram vào $TELEGRAM_CONF_FILE"
    else
        echo "❌ Bot Token hoặc Chat ID không được cung cấp. Bỏ qua cấu hình Telegram."
    fi
elif [[ "$CONFIGURE_TELEGRAM" =~ ^[Nn]$ ]]; then
    echo "✅ Đã bỏ qua cấu hình gửi backup qua Telegram."
    if [ -f "$TELEGRAM_CONF_FILE" ]; then
        rm -f "$TELEGRAM_CONF_FILE"
    fi
else
    echo "❌ Lựa chọn không hợp lệ. Mặc định bỏ qua cấu hình Telegram."
fi

# Hỏi về auto-update
AUTO_UPDATE=false
read -p "🔄 Bạn có muốn bật tính năng tự động cập nhật N8N không? (y/n): " UPDATE_CHOICE
if [[ "$UPDATE_CHOICE" =~ ^[Yy]$ ]]; then
    AUTO_UPDATE=true
    echo "✅ Đã bật tính năng tự động cập nhật."
else
    echo "✅ Đã tắt tính năng tự động cập nhật."
fi

# Tạo script sao lưu workflow và credentials
echo "🔄 Tạo script sao lưu workflow và credentials tại $N8N_DIR/backup-workflows.sh..."
cat << 'EOF' > $N8N_DIR/backup-workflows.sh
#!/bin/bash

# Định nghĩa các biến và hàm
N8N_DIR_VALUE="__N8N_DIR__"
BACKUP_BASE_DIR="${N8N_DIR_VALUE}/files/backup_full"
LOG_FILE="${N8N_DIR_VALUE}/files/backup_full/backup.log"
TELEGRAM_CONF_FILE="${N8N_DIR_VALUE}/telegram_config.txt"
DATE="$(date +"%Y%m%d_%H%M%S")"
BACKUP_FILE_NAME="n8n_backup_${DATE}.tar.gz"
BACKUP_FILE_PATH="${BACKUP_BASE_DIR}/${BACKUP_FILE_NAME}"
TEMP_DIR_HOST="/tmp/n8n_backup_host_${DATE}"
TEMP_DIR_CONTAINER_BASE="/tmp/n8n_workflow_exports"
DOMAIN="__DOMAIN__"

TELEGRAM_FILE_SIZE_LIMIT=20971520 # 20MB

# Hàm logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

# Hàm gửi tin nhắn Telegram
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

# Hàm gửi file qua Telegram
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
                log "File backup quá lớn (${readable_size} MB) để gửi qua Telegram. Sẽ chỉ gửi thông báo."
                send_telegram_message "🔄 Hoàn tất sao lưu N8N. File backup '${BACKUP_FILE_NAME}' (${readable_size}MB) quá lớn để gửi. Nó được lưu tại: ${file_path} trên server."
            fi
        fi
    fi
}

# Tạo thư mục backup
mkdir -p "${BACKUP_BASE_DIR}"
log "🔄 Bắt đầu sao lưu workflows và credentials..."
send_telegram_message "🔄 Bắt đầu quá trình sao lưu N8N hàng ngày cho domain: $DOMAIN..."

# Tìm container N8N
N8N_CONTAINER_NAME_PATTERN="n8n"
N8N_CONTAINER_ID="$(docker ps -q --filter "name=${N8N_CONTAINER_NAME_PATTERN}" --format '{{.ID}}' | head -n 1)"

if [ -z "${N8N_CONTAINER_ID}" ]; then
    log "❌ Lỗi: Không tìm thấy container n8n đang chạy."
    send_telegram_message "❌ Lỗi sao lưu N8N ($DOMAIN): Không tìm thấy container n8n đang chạy."
    exit 1
fi
log "✅ Tìm thấy container N8N ID: ${N8N_CONTAINER_ID}"

# Tạo thư mục tạm
mkdir -p "${TEMP_DIR_HOST}/workflows"
mkdir -p "${TEMP_DIR_HOST}/credentials"

# Tạo thư mục export trong container
TEMP_DIR_CONTAINER_UNIQUE="${TEMP_DIR_CONTAINER_BASE}/export_${DATE}"
docker exec "${N8N_CONTAINER_ID}" mkdir -p "${TEMP_DIR_CONTAINER_UNIQUE}"

# Export workflows
log "🔄 Xuất workflows vào ${TEMP_DIR_CONTAINER_UNIQUE} trong container..." 
WORKFLOWS_JSON="$(docker exec "${N8N_CONTAINER_ID}" n8n list:workflow --json 2>/dev/null || echo "[]")"

if [ -z "${WORKFLOWS_JSON}" ] || [ "${WORKFLOWS_JSON}" == "[]" ]; then
    log "⚠️ Cảnh báo: Không tìm thấy workflow nào để sao lưu."
else
    echo "${WORKFLOWS_JSON}" | jq -c '.[]' 2>/dev/null | while IFS= read -r workflow; do
        id="$(echo "${workflow}" | jq -r '.id' 2>/dev/null || echo "")"
        name="$(echo "${workflow}" | jq -r '.name' 2>/dev/null | tr -dc '[:alnum:][:space:]_-' | tr '[:space:]' '_')"
        safe_name="$(echo "${name}" | sed 's/[^a-zA-Z0-9_-]/_/g' | cut -c1-100)"
        
        if [ -n "${id}" ] && [ "${id}" != "null" ]; then
            output_file_container="${TEMP_DIR_CONTAINER_UNIQUE}/${id}-${safe_name}.json"
            log "📄 Đang xuất workflow: '${name}' (ID: ${id})"
            if docker exec "${N8N_CONTAINER_ID}" n8n export:workflow --id="${id}" --output="${output_file_container}" 2>/dev/null; then
                log "✅ Đã xuất workflow ID ${id} thành công."
            else
                log "❌ Lỗi khi xuất workflow ID ${id}."
            fi
        fi
    done

    # Copy workflows từ container ra host
    log "📋 Sao chép workflows từ container ra host..."
    if docker cp "${N8N_CONTAINER_ID}:${TEMP_DIR_CONTAINER_UNIQUE}/." "${TEMP_DIR_HOST}/workflows/" 2>/dev/null; then
        log "✅ Sao chép workflows từ container ra host thành công."
    else
        log "❌ Lỗi khi sao chép workflows từ container ra host."
    fi
fi

# Backup database và encryption key
DB_PATH_HOST="${N8N_DIR_VALUE}/database.sqlite"
KEY_PATH_HOST="${N8N_DIR_VALUE}/encryptionKey"

log "💾 Sao lưu database và encryption key từ host..."
if [ -f "${DB_PATH_HOST}" ]; then
    cp "${DB_PATH_HOST}" "${TEMP_DIR_HOST}/credentials/database.sqlite"
    log "✅ Đã sao lưu database.sqlite"
else
    log "❌ Lỗi: Không tìm thấy file database.sqlite tại ${DB_PATH_HOST}"
fi

if [ -f "${KEY_PATH_HOST}" ]; then
    cp "${KEY_PATH_HOST}" "${TEMP_DIR_HOST}/credentials/encryptionKey"
    log "✅ Đã sao lưu encryptionKey"
else
    log "❌ Lỗi: Không tìm thấy file encryptionKey tại ${KEY_PATH_HOST}"
fi

# Tạo metadata
cat << METADATA_EOF > "${TEMP_DIR_HOST}/backup_metadata.json"
{
    "backup_date": "${DATE}",
    "domain": "${DOMAIN}",
    "n8n_container_id": "${N8N_CONTAINER_ID}",
    "backup_version": "2.0",
    "created_by": "Nguyễn Ngọc Thiện - N8N Auto Backup Script"
}
METADATA_EOF

# Tạo file nén
log "📦 Tạo file nén tar.gz: ${BACKUP_FILE_PATH}"
if tar -czf "${BACKUP_FILE_PATH}" -C "${TEMP_DIR_HOST}" . 2>/dev/null; then
    BACKUP_SIZE=$(du -h "${BACKUP_FILE_PATH}" | cut -f1)
    log "✅ Tạo file backup ${BACKUP_FILE_PATH} thành công. Kích thước: ${BACKUP_SIZE}"
    send_telegram_document "${BACKUP_FILE_PATH}" "✅ Sao lưu N8N ($DOMAIN) hàng ngày hoàn tất: ${BACKUP_FILE_NAME} (${BACKUP_SIZE})"
else
    log "❌ Lỗi: Không thể tạo file backup ${BACKUP_FILE_PATH}."
    send_telegram_message "❌ Lỗi sao lưu N8N ($DOMAIN): Không thể tạo file backup. Kiểm tra log tại ${LOG_FILE}"
fi

# Dọn dẹp
log "🧹 Dọn dẹp thư mục tạm..."
rm -rf "${TEMP_DIR_HOST}"
docker exec "${N8N_CONTAINER_ID}" rm -rf "${TEMP_DIR_CONTAINER_UNIQUE}" 2>/dev/null || true

# Giữ lại 30 bản backup gần nhất
log "🗂️ Giữ lại 30 bản sao lưu gần nhất trong ${BACKUP_BASE_DIR}..."
find "${BACKUP_BASE_DIR}" -maxdepth 1 -name 'n8n_backup_*.tar.gz' -type f -printf '%T@ %p\n' 2>/dev/null | \
sort -nr | tail -n +31 | cut -d' ' -f2- | xargs -r rm -f

# Kết thúc
log "🎉 Sao lưu hoàn tất: ${BACKUP_FILE_PATH}"
if [ -f "${BACKUP_FILE_PATH}" ]; then
    send_telegram_message "🎉 Hoàn tất sao lưu N8N ($DOMAIN). File: ${BACKUP_FILE_NAME}. Log: ${LOG_FILE}"
else
    send_telegram_message "❌ Sao lưu N8N ($DOMAIN) thất bại. Kiểm tra log tại ${LOG_FILE}"
fi

exit 0
EOF

# Thay thế biến trong script
sed -i "s|__N8N_DIR__|$N8N_DIR|g" $N8N_DIR/backup-workflows.sh
sed -i "s|__DOMAIN__|$DOMAIN|g" $N8N_DIR/backup-workflows.sh
chmod +x $N8N_DIR/backup-workflows.sh

# Tạo script backup thủ công để test
echo "🔄 Tạo script backup thủ công tại $N8N_DIR/backup-manual.sh..."
cat << EOF > $N8N_DIR/backup-manual.sh
#!/bin/bash
echo "🧪 Chạy backup thủ công để kiểm tra..."
echo "📁 Thư mục backup: $N8N_DIR/files/backup_full/"
echo "📋 Log file: $N8N_DIR/files/backup_full/backup.log"
echo "🔄 Bắt đầu backup..."
$N8N_DIR/backup-workflows.sh
echo "✅ Hoàn tất! Kiểm tra log để xem kết quả."
EOF
chmod +x $N8N_DIR/backup-manual.sh

# Tạo script chẩn đoán
echo "🔄 Tạo script chẩn đoán tại $N8N_DIR/troubleshoot.sh..."
cat << EOF > $N8N_DIR/troubleshoot.sh
#!/bin/bash
echo "🔍 SCRIPT CHẨN ĐOÁN N8N - Nguyễn Ngọc Thiện"
echo "======================================================================"
echo "📅 Thời gian: \$(date)"
echo "🌐 Domain: $DOMAIN"
if [ "$INSTALL_FASTAPI" = true ]; then
echo "📰 API Domain: $API_DOMAIN"
fi
echo "======================================================================"

echo "🐳 DOCKER STATUS:"
docker --version
docker-compose --version 2>/dev/null || docker compose version
echo ""

echo "📦 CONTAINERS:"
cd $N8N_DIR && docker-compose ps
echo ""

echo "🔍 CONTAINER LOGS (Last 10 lines):"
echo "--- N8N Logs ---"
cd $N8N_DIR && docker-compose logs --tail=10 n8n
if [ "$INSTALL_FASTAPI" = true ]; then
echo "--- FastAPI Logs ---"
cd $N8N_DIR && docker-compose logs --tail=10 fastapi
fi
echo "--- Caddy Logs ---"
cd $N8N_DIR && docker-compose logs --tail=10 caddy
echo ""

echo "🌐 NETWORK CONNECTIVITY:"
echo "Domain $DOMAIN resolves to: \$(dig +short $DOMAIN A)"
if [ "$INSTALL_FASTAPI" = true ]; then
echo "API Domain $API_DOMAIN resolves to: \$(dig +short $API_DOMAIN A)"
fi
echo "Server IP: \$(curl -s https://api.ipify.org)"
echo ""

echo "🔒 SSL CHECK:"
echo "Checking SSL for $DOMAIN..."
curl -I https://$DOMAIN 2>&1 | head -5
if [ "$INSTALL_FASTAPI" = true ]; then
echo "Checking SSL for $API_DOMAIN..."
curl -I https://$API_DOMAIN 2>&1 | head -5
fi
echo ""

echo "💾 DISK USAGE:"
df -h $N8N_DIR
echo ""

echo "📋 BACKUP STATUS:"
ls -la $N8N_DIR/files/backup_full/ | tail -5
echo ""

echo "⏰ CRON JOBS:"
crontab -l | grep -E "(backup|update)"
echo ""

echo "🔧 SYSTEM RESOURCES:"
free -h
echo ""
echo "🎉 Chẩn đoán hoàn tất!"
EOF
chmod +x $N8N_DIR/troubleshoot.sh

# Đặt quyền cho thư mục n8n
echo "🔄 Đặt quyền cho thư mục n8n tại $N8N_DIR..."
sudo chown -R 1000:1000 $N8N_DIR 
sudo chmod -R u+rwX,g+rX,o+rX $N8N_DIR
sudo chown -R 1000:1000 $N8N_DIR/files
sudo chmod -R u+rwX,g+rX,o+rX $N8N_DIR/files

# Khởi động các container
echo "🚀 Khởi động các container... Quá trình build image có thể mất vài phút..."
cd $N8N_DIR

# Xác định lệnh docker-compose
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    echo "❌ Lỗi: Không tìm thấy lệnh docker-compose hoặc docker compose plugin."
    exit 1
fi

echo "🔄 Đang build Docker images... (có thể mất vài phút)"
if ! $DOCKER_COMPOSE_CMD build; then
    echo "⚠️ Cảnh báo: Build Docker images thất bại."
    echo "🔄 Đang thử build lại với cấu hình đơn giản hơn..."
    
    # Tạo Dockerfile đơn giản hơn nếu build ban đầu thất bại
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
    
    # Cập nhật docker-compose.yml để sử dụng Dockerfile đơn giản
    sed -i 's/dockerfile: Dockerfile/dockerfile: Dockerfile.simple/' $N8N_DIR/docker-compose.yml
    
    if ! $DOCKER_COMPOSE_CMD build; then
        echo "❌ Lỗi: Không thể build Docker image thậm chí với cấu hình đơn giản."
        echo "🔍 Kiểm tra kết nối mạng và thử lại."
        exit 1
    fi
    echo "✅ Build thành công với cấu hình đơn giản (không có Puppeteer nodes)."
fi

echo "🚀 Đang khởi động các container..."
if ! $DOCKER_COMPOSE_CMD up -d; then
    echo "❌ Lỗi: Khởi động container thất bại."
    echo "🔍 Kiểm tra logs: $DOCKER_COMPOSE_CMD logs"
    exit 1
fi

echo "⏳ Đợi các container khởi động và SSL được cấp (60 giây)..."
sleep 60

# Kiểm tra các container đã chạy chưa
echo "🔍 Kiểm tra trạng thái các container..."
if $DOCKER_COMPOSE_CMD ps | grep -q "n8n"; then
    echo "✅ Container n8n đã chạy thành công."
else
    echo "⚠️ Cảnh báo: Container n8n có thể chưa chạy. Kiểm tra logs: $DOCKER_COMPOSE_CMD logs n8n"
fi
if $DOCKER_COMPOSE_CMD ps | grep -q "caddy"; then
    echo "✅ Container caddy đã chạy thành công."
else
    echo "⚠️ Cảnh báo: Container caddy có thể chưa chạy. Kiểm tra logs: $DOCKER_COMPOSE_CMD logs caddy"
fi
if [ "$INSTALL_FASTAPI" = true ] && $DOCKER_COMPOSE_CMD ps | grep -q "fastapi"; then
    echo "✅ Container fastapi đã chạy thành công."
elif [ "$INSTALL_FASTAPI" = true ]; then
    echo "⚠️ Cảnh báo: Container fastapi có thể chưa chạy. Kiểm tra logs: $DOCKER_COMPOSE_CMD logs fastapi"
fi

# Kiểm tra SSL certificate
echo "🔒 Kiểm tra SSL certificate..."
if curl -s -I https://$DOMAIN | grep -q "HTTP/2 200\|HTTP/1.1 200"; then
    echo "✅ SSL cho $DOMAIN đã hoạt động!"
else
    echo "⚠️ Cảnh báo: SSL cho $DOMAIN có thể chưa sẵn sàng. Đợi thêm vài phút."
fi

if [ "$INSTALL_FASTAPI" = true ]; then
    if curl -s -I https://$API_DOMAIN | grep -q "HTTP/2 200\|HTTP/1.1 200"; then
        echo "✅ SSL cho $API_DOMAIN đã hoạt động!"
    else
        echo "⚠️ Cảnh báo: SSL cho $API_DOMAIN có thể chưa sẵn sàng. Đợi thêm vài phút."
    fi
fi

# Tạo script cập nhật tự động (chỉ khi được bật)
if [ "$AUTO_UPDATE" = true ]; then
    echo "🔄 Tạo script cập nhật tự động tại $N8N_DIR/update-n8n.sh..."
    cat << EOF > $N8N_DIR/update-n8n.sh
#!/bin/bash
N8N_DIR_VALUE="$N8N_DIR"
LOG_FILE="$N8N_DIR_VALUE/update.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }
log "🔄 Bắt đầu kiểm tra cập nhật..."
cd "$N8N_DIR_VALUE"
if command -v docker-compose &> /dev/null; then DOCKER_COMPOSE="docker-compose"; elif command -v docker &> /dev/null && docker compose version &> /dev/null; then DOCKER_COMPOSE="docker compose"; else log "❌ Lỗi: Docker Compose không tìm thấy."; exit 1; fi
log "🔄 Cập nhật yt-dlp trên host..."
if command -v pipx &> /dev/null; then pipx upgrade yt-dlp; elif [ -d "/opt/yt-dlp-venv" ]; then /opt/yt-dlp-venv/bin/pip install -U yt-dlp; fi
log "🔄 Kéo image n8nio/n8n mới nhất..."
docker pull n8nio/n8n:latest
CURRENT_CUSTOM_IMAGE_ID="$(docker images -q n8n-custom-ffmpeg)"
log "🔄 Build lại image custom n8n..."
if ! \$DOCKER_COMPOSE build n8n; then log "❌ Lỗi build image custom."; exit 1; fi
NEW_CUSTOM_IMAGE_ID="$(docker images -q n8n-custom-ffmpeg)"
if [ "\$CURRENT_CUSTOM_IMAGE_ID" != "\$NEW_CUSTOM_IMAGE_ID" ]; then
    log "🔄 Phát hiện image mới, tiến hành cập nhật n8n..."
    log "💾 Chạy backup trước khi cập nhật..."
    if [ -x "$N8N_DIR_VALUE/backup-workflows.sh" ]; then
        "$N8N_DIR_VALUE/backup-workflows.sh"
    else
        log "⚠️ Không tìm thấy script backup-workflows.sh hoặc không có quyền thực thi."
    fi
    log "🔄 Dừng và khởi động lại containers..."
    \$DOCKER_COMPOSE down
    \$DOCKER_COMPOSE up -d
    log "✅ Cập nhật n8n hoàn tất."
else
    log "ℹ️ Không có cập nhật mới cho image n8n custom."
fi
log "🔄 Cập nhật yt-dlp trong container n8n..."
N8N_CONTAINER_FOR_UPDATE="\$(docker ps -q --filter name=n8n)"
if [ -n "\$N8N_CONTAINER_FOR_UPDATE" ]; then
    docker exec -u root \$N8N_CONTAINER_FOR_UPDATE pip3 install --break-system-packages -U yt-dlp
    log "✅ yt-dlp trong container đã được cập nhật."
else
    log "⚠️ Không tìm thấy container n8n đang chạy để cập nhật yt-dlp."
fi
log "✅ Kiểm tra cập nhật hoàn tất."
EOF
    chmod +x $N8N_DIR/update-n8n.sh
fi

# Thiết lập cron job
CRON_USER=$(whoami)
BACKUP_CRON="0 2 * * * $N8N_DIR/backup-workflows.sh"

if [ "$AUTO_UPDATE" = true ]; then
    UPDATE_CRON="0 */12 * * * $N8N_DIR/update-n8n.sh"
    (crontab -u $CRON_USER -l 2>/dev/null | grep -v "update-n8n.sh" | grep -v "backup-workflows.sh"; echo "$UPDATE_CRON"; echo "$BACKUP_CRON") | crontab -u $CRON_USER -
    echo "✅ Đã thiết lập cron job cập nhật tự động mỗi 12 giờ và sao lưu hàng ngày lúc 2:00 AM."
else
    (crontab -u $CRON_USER -l 2>/dev/null | grep -v "update-n8n.sh" | grep -v "backup-workflows.sh"; echo "$BACKUP_CRON") | crontab -u $CRON_USER -
    echo "✅ Đã thiết lập cron job sao lưu hàng ngày lúc 2:00 AM."
fi

echo "======================================================================"
echo "🎉 N8N ĐÃ ĐƯỢC CÀI ĐẶT THÀNH CÔNG!"
echo "======================================================================"
echo "🌐 Truy cập N8N: https://${DOMAIN}"
if [ "$INSTALL_FASTAPI" = true ]; then
echo "📰 Truy cập News API: https://${API_DOMAIN}"
echo "📚 API Documentation: https://${API_DOMAIN}/docs"
echo "🔑 Bearer Token: $BEARER_TOKEN"
fi

echo ""
echo "📁 Thư mục cài đặt: $N8N_DIR"
echo "🔧 Script chẩn đoán: $N8N_DIR/troubleshoot.sh"
echo "🧪 Test backup: $N8N_DIR/backup-manual.sh"

if [ "$(swapon --show | wc -l)" -gt 0 ]; then
    SWAP_INFO=$(free -h | grep Swap | awk '{print $2}')
    echo "💾 Swap: $SWAP_INFO"
fi

if [ "$AUTO_UPDATE" = true ]; then
    echo "🔄 Auto-update: Enabled (mỗi 12h)"
else
    echo "🔄 Auto-update: Disabled"
fi

if [ -f "$TELEGRAM_CONF_FILE" ]; then
    echo "📱 Telegram backup: Enabled"
else
    echo "📱 Telegram backup: Disabled"
fi

echo "💾 Backup tự động: Hàng ngày lúc 2:00 AM"
echo "📂 Backup location: $N8N_DIR/files/backup_full/"

echo ""
echo "🚀 Tác giả: Nguyễn Ngọc Thiện"
echo "📺 YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1"
echo "📱 Zalo: 08.8888.4749"
echo "======================================================================"
