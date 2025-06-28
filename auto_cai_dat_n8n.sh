#!/bin/bash

# Hiển thị banner
echo "======================================================================"
echo "     Script cài đặt N8N với FFmpeg, yt-dlp, Puppeteer, News API     "
echo "           và SSL tự động (Phiên bản cải tiến 2025)                 "
echo "                   Tác giả: Nguyễn Ngọc Thiện                       "
echo "======================================================================"

# Kiểm tra xem script có được chạy với quyền root không
if [[ $EUID -ne 0 ]]; then
   echo "Script này cần được chạy với quyền root" 
   exit 1
fi

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
    echo "  -c, --clean     Xóa tất cả cài đặt N8N/Docker cũ và cài mới"
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
        -c|--clean)
            CLEAN_INSTALL=true
            shift
            ;;
        *)
            echo "Tùy chọn không hợp lệ: $1"
            show_help
            ;;
    esac
done

# Hàm cleanup cài đặt cũ
cleanup_old_installation() {
    echo "======================================================================"
    echo "  CẢNH BÁO: Bạn sắp xóa toàn bộ cài đặt N8N và Docker hiện tại!"
    echo "  Điều này sẽ xóa:"
    echo "  - Tất cả containers Docker"
    echo "  - Tất cả images Docker"
    echo "  - Thư mục $N8N_DIR"
    echo "  - Tất cả dữ liệu workflows, credentials và backup"
    echo "======================================================================"
    read -p "Bạn có chắc chắn muốn xóa tất cả và cài đặt mới? (YES để xác nhận): " CONFIRM_CLEAN
    
    if [ "$CONFIRM_CLEAN" = "YES" ]; then
        echo "Đang dừng tất cả containers..."
        docker stop $(docker ps -aq) 2>/dev/null || true
        
        echo "Đang xóa tất cả containers..."
        docker rm $(docker ps -aq) 2>/dev/null || true
        
        echo "Đang xóa tất cả images..."
        docker rmi $(docker images -q) 2>/dev/null || true
        
        echo "Đang xóa tất cả volumes..."
        docker volume prune -f 2>/dev/null || true
        
        echo "Đang xóa tất cả networks..."
        docker network prune -f 2>/dev/null || true
        
        echo "Đang xóa system cache..."
        docker system prune -af 2>/dev/null || true
        
        if [ -d "$N8N_DIR" ]; then
            echo "Đang xóa thư mục $N8N_DIR..."
            rm -rf "$N8N_DIR"
        fi
        
        # Xóa cron jobs cũ
        crontab -l 2>/dev/null | grep -v "update-n8n.sh" | grep -v "backup-workflows.sh" | crontab - 2>/dev/null || true
        
        echo "✅ Đã xóa sạch tất cả cài đặt cũ. Tiếp tục cài đặt mới..."
    else
        echo "❌ Hủy bỏ quá trình cleanup. Tiếp tục với cài đặt thông thường..."
    fi
}

# Nếu có flag clean, thực hiện cleanup
if [ "$CLEAN_INSTALL" = true ]; then
    cleanup_old_installation
fi

# Hàm kiểm tra domain
check_domain() {
    local domain=$1
    local server_ip=$(curl -s https://api.ipify.org || curl -s http://ipv4.icanhazip.com || echo "Không thể lấy IP server")
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
    for cmd in dig curl cron jq tar gzip bc python3; do
        if ! command -v $cmd &> /dev/null; then
            echo "Lệnh '$cmd' không tìm thấy. Đang cài đặt..."
            apt-get update > /dev/null 2>&1
            if [ "$cmd" == "cron" ]; then
                apt-get install -y cron
            elif [ "$cmd" == "bc" ]; then
                apt-get install -y bc
            elif [ "$cmd" == "python3" ]; then
                apt-get install -y python3 python3-pip python3-venv
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
        echo "Docker Compose (hoặc plugin) đã được cài đặt."
    else 
        echo "Cài đặt Docker Compose plugin..."
        apt-get install -y docker-compose-plugin
        if ! (docker compose version &> /dev/null); then 
            echo "Không cài được plugin, thử cài docker-compose bản cũ..." 
            apt-get install -y docker-compose 
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
        usermod -aG docker $SUDO_USER
        echo "Đã thêm. Thay đổi có hiệu lực sau khi đăng nhập lại hoặc chạy 'newgrp docker'."
    fi
    systemctl enable docker
    systemctl restart docker
    echo "Docker và Docker Compose đã được cài đặt/kiểm tra thành công."
}

# Cài đặt các gói cần thiết
echo "Đang kiểm tra và cài đặt các công cụ cần thiết..."
apt-get update > /dev/null
apt-get install -y dnsutils curl cron jq tar gzip python3-full python3-venv python3-pip pipx net-tools bc

# Cài đặt yt-dlp
echo "Cài đặt yt-dlp..."
if command -v pipx &> /dev/null; then
    pipx install yt-dlp
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
install_docker

# Nhận input domain từ người dùng
read -p "Nhập tên miền chính của bạn (ví dụ: n8nkalvinbot.io.vn): " DOMAIN
while ! check_domain $DOMAIN; do
    echo "Domain $DOMAIN chưa được trỏ đúng đến IP server này ($(curl -s https://api.ipify.org))."
    echo "Vui lòng cập nhật bản ghi DNS để trỏ $DOMAIN đến IP $(curl -s https://api.ipify.org)." 
    read -p "Nhấn Enter sau khi cập nhật DNS, hoặc nhập domain khác: " NEW_DOMAIN
    if [ -n "$NEW_DOMAIN" ]; then
        DOMAIN="$NEW_DOMAIN"
    fi
done
echo "✅ Domain $DOMAIN đã được trỏ đúng. Tiếp tục cài đặt."

# Hỏi về News API
API_DOMAIN=""
INSTALL_NEWS_API=false
read -p "Bạn có muốn cài đặt FastAPI để cào nội dung bài viết không? (y/n): " INSTALL_API_CHOICE
if [[ "$INSTALL_API_CHOICE" =~ ^[Yy]$ ]]; then
    API_DOMAIN="api.$DOMAIN"
    echo "Sẽ tạo API tại: $API_DOMAIN"
    
    # Kiểm tra API domain
    echo "Kiểm tra domain API: $API_DOMAIN"
    if check_domain $API_DOMAIN; then
        echo "✅ Domain API $API_DOMAIN đã được trỏ đúng."
        INSTALL_NEWS_API=true
    else
        echo "⚠️  Domain API $API_DOMAIN chưa được trỏ đúng."
        read -p "Bạn có muốn tiếp tục cài đặt API (có thể cấu hình DNS sau)? (y/n): " CONTINUE_API
        if [[ "$CONTINUE_API" =~ ^[Yy]$ ]]; then
            INSTALL_NEWS_API=true
            echo "Sẽ cài đặt API. Hãy nhớ trỏ $API_DOMAIN đến server này."
        else
            echo "Bỏ qua cài đặt News API."
        fi
    fi
fi

# Tạo thư mục cho n8n
echo "Tạo cấu trúc thư mục cho n8n tại $N8N_DIR..."
mkdir -p $N8N_DIR
mkdir -p $N8N_DIR/files
mkdir -p $N8N_DIR/files/temp
mkdir -p $N8N_DIR/files/youtube_content_anylystic
mkdir -p $N8N_DIR/files/backup_full

# Tạo Dockerfile cho N8N
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
RUN npm install n8n-nodes-puppeteer || echo "Cảnh báo: Không thể cài đặt n8n-nodes-puppeteer, tiếp tục mà không có nó"
RUN mkdir -p /files/youtube_content_anylystic /files/backup_full /files/temp && \
    chown -R node:node /files
USER node
WORKDIR /home/node
EOF

# Cài đặt News API nếu được chọn
if [ "$INSTALL_NEWS_API" = true ]; then
    echo "Cài đặt News Content API..."
    mkdir -p $N8N_DIR/news_api
    
    # Tạo requirements.txt cho News API
    cat << 'EOF' > $N8N_DIR/news_api/requirements.txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
newspaper4k==0.9.2.9
python-multipart==0.0.6
Jinja2==3.1.2
aiofiles==23.2.1
requests==2.31.0
feedparser==6.0.10
beautifulsoup4==4.12.2
lxml==4.9.3
html5lib==1.1
python-dateutil==2.8.2
validators==0.22.0
pydantic==2.5.0
EOF

    # Tạo Dockerfile cho News API
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
    libpng-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user
RUN useradd -m -u 1000 apiuser && chown -R apiuser:apiuser /app
USER apiuser

# Expose port
EXPOSE 8000

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
EOF

    # Tạo News API main.py
    cat << 'EOF' > $N8N_DIR/news_api/main.py
from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, HttpUrl, Field, validator
from typing import Optional, List, Dict, Any
import newspaper
from newspaper import Article, Config
import feedparser
import requests
from datetime import datetime, timezone
import logging
import os
import asyncio
import aiofiles
from urllib.parse import urljoin, urlparse
import validators
from bs4 import BeautifulSoup
import json
import re

# Logging setup
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# App initialization
app = FastAPI(
    title="News Content API by Kalvin Thien",
    description="API để cào nội dung bài viết và RSS feeds - Phát triển bởi Nguyễn Ngọc Thiện",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Security
security = HTTPBearer()
API_TOKEN = os.getenv("NEWS_API_TOKEN", "default_secure_token_2025")

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if credentials.credentials != API_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid authentication token")
    return credentials.credentials

# Pydantic models
class ArticleRequest(BaseModel):
    url: HttpUrl
    language: str = Field(default="vi", description="Ngôn ngữ bài viết (vi, en, etc.)")
    extract_images: bool = Field(default=True, description="Có trích xuất hình ảnh không")
    summarize: bool = Field(default=False, description="Có tóm tắt bài viết không")

    @validator('language')
    def validate_language(cls, v):
        supported_languages = ['vi', 'en', 'zh', 'ja', 'ko', 'th', 'id', 'ms']
        if v not in supported_languages:
            raise ValueError(f'Ngôn ngữ không được hỗ trợ. Hỗ trợ: {supported_languages}')
        return v

class SourceRequest(BaseModel):
    url: HttpUrl
    max_articles: int = Field(default=10, ge=1, le=50, description="Số lượng bài viết tối đa")
    language: str = Field(default="vi")

class FeedRequest(BaseModel):
    url: HttpUrl
    max_articles: int = Field(default=10, ge=1, le=100)

class ArticleResponse(BaseModel):
    title: Optional[str]
    content: Optional[str]
    summary: Optional[str]
    authors: List[str]
    publish_date: Optional[str]
    url: str
    images: List[str]
    tags: List[str]
    language: str
    word_count: int
    read_time_minutes: int
    extracted_at: str

class HealthResponse(BaseModel):
    status: str
    message: str
    version: str
    timestamp: str
    author: str = "Nguyễn Ngọc Thiện"
    youtube: str = "https://www.youtube.com/@kalvinthiensocial"

# Utility functions
def calculate_read_time(word_count: int) -> int:
    """Tính thời gian đọc (giả sử 200 từ/phút)"""
    return max(1, word_count // 200)

def clean_text(text: str) -> str:
    """Làm sạch văn bản"""
    if not text:
        return ""
    # Loại bỏ ký tự thừa và chuẩn hóa khoảng trắng
    text = re.sub(r'\s+', ' ', text)
    text = re.sub(r'\n+', '\n', text)
    return text.strip()

def summarize_text(text: str, max_sentences: int = 3) -> str:
    """Tóm tắt văn bản đơn giản"""
    if not text:
        return ""
    
    sentences = text.split('.')
    # Lọc câu có độ dài hợp lý
    good_sentences = [s.strip() for s in sentences if len(s.strip()) > 20 and len(s.strip()) < 200]
    
    if len(good_sentences) <= max_sentences:
        return '. '.join(good_sentences) + '.'
    else:
        return '. '.join(good_sentences[:max_sentences]) + '.'

async def extract_article_content(url: str, language: str = "vi", extract_images: bool = True) -> ArticleResponse:
    """Trích xuất nội dung bài viết"""
    try:
        config = Config()
        config.browser_user_agent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        config.request_timeout = 10
        config.fetch_images = extract_images
        config.language = language
        
        article = Article(url, config=config)
        article.download()
        article.parse()
        
        if extract_images:
            article.nlp()
        
        # Tính word count
        word_count = len(article.text.split()) if article.text else 0
        
        # Tạo response
        response = ArticleResponse(
            title=clean_text(article.title) if article.title else "Không có tiêu đề",
            content=clean_text(article.text) if article.text else "Không thể trích xuất nội dung",
            summary=clean_text(article.summary) if article.summary else None,
            authors=article.authors or [],
            publish_date=article.publish_date.isoformat() if article.publish_date else None,
            url=str(url),
            images=article.images if extract_images else [],
            tags=list(article.tags) if article.tags else [],
            language=language,
            word_count=word_count,
            read_time_minutes=calculate_read_time(word_count),
            extracted_at=datetime.now(timezone.utc).isoformat()
        )
        
        return response
        
    except Exception as e:
        logger.error(f"Lỗi khi trích xuất bài viết {url}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Không thể trích xuất bài viết: {str(e)}")

# Routes
@app.get("/", response_class=HTMLResponse)
async def home():
    """Trang chủ với giao diện thân thiện"""
    html_content = """
    <!DOCTYPE html>
    <html lang="vi">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>News Content API - Nguyễn Ngọc Thiện</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { 
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                color: #333;
            }
            .container { 
                background: rgba(255,255,255,0.95);
                padding: 2rem;
                border-radius: 20px;
                box-shadow: 0 15px 35px rgba(0,0,0,0.1);
                text-align: center;
                max-width: 600px;
                width: 90%;
                backdrop-filter: blur(10px);
            }
            h1 { 
                color: #4f46e5;
                margin-bottom: 1rem;
                font-size: 2.5rem;
                font-weight: 700;
            }
            .subtitle {
                color: #6b7280;
                margin-bottom: 2rem;
                font-size: 1.1rem;
            }
            .author {
                background: linear-gradient(45deg, #f59e0b, #ef4444);
                -webkit-background-clip: text;
                background-clip: text;
                -webkit-text-fill-color: transparent;
                font-weight: 600;
                margin-bottom: 2rem;
                font-size: 1.2rem;
            }
            .links {
                display: flex;
                gap: 1rem;
                justify-content: center;
                flex-wrap: wrap;
                margin: 2rem 0;
            }
            .btn {
                padding: 12px 24px;
                border-radius: 50px;
                text-decoration: none;
                font-weight: 600;
                transition: all 0.3s ease;
                display: inline-flex;
                align-items: center;
                gap: 8px;
            }
            .btn-primary {
                background: linear-gradient(45deg, #4f46e5, #7c3aed);
                color: white;
            }
            .btn-secondary {
                background: linear-gradient(45deg, #059669, #0d9488);
                color: white;
            }
            .btn-accent {
                background: linear-gradient(45deg, #dc2626, #ea580c);
                color: white;
            }
            .btn:hover {
                transform: translateY(-2px);
                box-shadow: 0 8px 25px rgba(0,0,0,0.15);
            }
            .features {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
                gap: 1rem;
                margin: 2rem 0;
            }
            .feature {
                background: rgba(255,255,255,0.7);
                padding: 1.5rem;
                border-radius: 15px;
                border: 1px solid rgba(255,255,255,0.3);
            }
            .feature h3 {
                color: #4f46e5;
                margin-bottom: 0.5rem;
            }
            .endpoints {
                text-align: left;
                background: rgba(248,250,252,0.8);
                padding: 1.5rem;
                border-radius: 15px;
                margin: 1rem 0;
                border: 1px solid rgba(226,232,240,0.5);
            }
            .endpoint {
                font-family: 'Courier New', monospace;
                background: rgba(255,255,255,0.9);
                padding: 0.5rem;
                border-radius: 8px;
                margin: 0.5rem 0;
                border-left: 4px solid #4f46e5;
            }
            @media (max-width: 768px) {
                .container { margin: 1rem; padding: 1.5rem; }
                h1 { font-size: 2rem; }
                .links { flex-direction: column; align-items: center; }
                .btn { width: 200px; justify-content: center; }
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 News Content API</h1>
            <p class="subtitle">API mạnh mẽ để cào nội dung bài viết và RSS feeds</p>
            <p class="author">Phát triển bởi Nguyễn Ngọc Thiện</p>
            
            <div class="features">
                <div class="feature">
                    <h3>📰 Trích xuất bài viết</h3>
                    <p>Lấy nội dung, tiêu đề, hình ảnh từ URL</p>
                </div>
                <div class="feature">
                    <h3>📡 RSS Feeds</h3>
                    <p>Phân tích và lấy dữ liệu từ RSS feeds</p>
                </div>
                <div class="feature">
                    <h3>🔐 Bảo mật</h3>
                    <p>Bearer Token authentication</p>
                </div>
                <div class="feature">
                    <h3>🌐 Đa ngôn ngữ</h3>
                    <p>Hỗ trợ tiếng Việt và nhiều ngôn ngữ khác</p>
                </div>
            </div>

            <div class="endpoints">
                <h3>📋 API Endpoints:</h3>
                <div class="endpoint">GET /health - Kiểm tra trạng thái API</div>
                <div class="endpoint">POST /extract-article - Trích xuất nội dung bài viết</div>
                <div class="endpoint">POST /extract-source - Cào nhiều bài viết từ trang web</div>
                <div class="endpoint">POST /parse-feed - Phân tích RSS feeds</div>
            </div>
            
            <div class="links">
                <a href="/docs" class="btn btn-primary">📚 API Documentation</a>
                <a href="/redoc" class="btn btn-secondary">📖 ReDoc</a>
                <a href="https://www.youtube.com/@kalvinthiensocial" class="btn btn-accent" target="_blank">🎥 YouTube Channel</a>
            </div>
            
            <p style="margin-top: 2rem; color: #6b7280; font-size: 0.9rem;">
                💡 Sử dụng Bearer Token trong header Authorization để truy cập API<br>
                📞 Liên hệ: 08.8888.4749 | Facebook: Ban.Thien.Handsome
            </p>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Kiểm tra trạng thái API"""
    return HealthResponse(
        status="healthy",
        message="News Content API đang hoạt động bình thường",
        version="2.0.0",
        timestamp=datetime.now(timezone.utc).isoformat()
    )

@app.post("/extract-article", response_model=ArticleResponse)
async def extract_article(request: ArticleRequest, token: str = Depends(verify_token)):
    """Trích xuất nội dung từ một bài viết"""
    return await extract_article_content(
        str(request.url), 
        request.language, 
        request.extract_images
    )

@app.post("/extract-source")
async def extract_from_source(request: SourceRequest, token: str = Depends(verify_token)):
    """Cào nhiều bài viết từ một trang web"""
    try:
        source = newspaper.build(str(request.url), language=request.language)
        articles = []
        
        for i, article in enumerate(source.articles[:request.max_articles]):
            try:
                article_response = await extract_article_content(
                    article.url, 
                    request.language, 
                    extract_images=False  # Để tăng tốc độ
                )
                articles.append(article_response.dict())
            except Exception as e:
                logger.warning(f"Không thể trích xuất bài viết {article.url}: {str(e)}")
                continue
        
        return {
            "source_url": str(request.url),
            "total_found": len(source.articles),
            "extracted_count": len(articles),
            "articles": articles,
            "extracted_at": datetime.now(timezone.utc).isoformat()
        }
        
    except Exception as e:
        logger.error(f"Lỗi khi cào từ source {request.url}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Không thể cào từ source: {str(e)}")

@app.post("/parse-feed")
async def parse_rss_feed(request: FeedRequest, token: str = Depends(verify_token)):
    """Phân tích RSS feed và trích xuất bài viết"""
    try:
        feed = feedparser.parse(str(request.url))
        
        if feed.bozo:
            logger.warning(f"RSS feed có thể không hợp lệ: {request.url}")
        
        articles = []
        for entry in feed.entries[:request.max_articles]:
            try:
                # Lấy URL bài viết
                article_url = entry.link if hasattr(entry, 'link') else None
                if not article_url:
                    continue
                
                # Trích xuất nội dung chi tiết
                article_response = await extract_article_content(article_url, extract_images=False)
                
                # Bổ sung thông tin từ RSS
                article_dict = article_response.dict()
                article_dict.update({
                    "rss_title": getattr(entry, 'title', ''),
                    "rss_summary": getattr(entry, 'summary', ''),
                    "rss_published": getattr(entry, 'published', ''),
                    "rss_categories": [tag.term for tag in getattr(entry, 'tags', [])]
                })
                
                articles.append(article_dict)
                
            except Exception as e:
                logger.warning(f"Không thể xử lý entry RSS: {str(e)}")
                continue
        
        return {
            "feed_url": str(request.url),
            "feed_title": getattr(feed.feed, 'title', ''),
            "feed_description": getattr(feed.feed, 'description', ''),
            "total_entries": len(feed.entries),
            "extracted_count": len(articles),
            "articles": articles,
            "parsed_at": datetime.now(timezone.utc).isoformat()
        }
        
    except Exception as e:
        logger.error(f"Lỗi khi parse RSS feed {request.url}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Không thể parse RSS feed: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

    echo "✅ Đã tạo News API thành công!"
fi

# Tạo file docker-compose.yml
echo "Tạo file docker-compose.yml..."
COMPOSE_CONTENT="services:
  n8n:
    build:
      context: .
      dockerfile: Dockerfile
    image: n8n-custom-ffmpeg:latest
    restart: always
    ports:
      - \"127.0.0.1:5678:5678\"
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
    user: \"node\"
    cap_add:
      - SYS_ADMIN"

if [ "$INSTALL_NEWS_API" = true ]; then
    # Tạo Bearer Token ngẫu nhiên
    API_TOKEN=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    echo "🔑 Bearer Token cho News API: $API_TOKEN"
    echo "📝 Lưu token này để sử dụng API!"
    echo "$API_TOKEN" > "$N8N_DIR/news_api_token.txt"
    
    COMPOSE_CONTENT="$COMPOSE_CONTENT

  fastapi:
    build:
      context: ./news_api
      dockerfile: Dockerfile
    image: news-api-custom:latest
    restart: always
    ports:
      - \"127.0.0.1:8000:8000\"
    environment:
      - NEWS_API_TOKEN=$API_TOKEN
    volumes:
      - ${N8N_DIR}/news_api:/app
    depends_on:
      - n8n"
fi

COMPOSE_CONTENT="$COMPOSE_CONTENT

  caddy:
    image: caddy:latest
    restart: always
    ports:
      - \"80:80\"
      - \"443:443\"
    volumes:
      - ${N8N_DIR}/Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - n8n"

if [ "$INSTALL_NEWS_API" = true ]; then
    COMPOSE_CONTENT="$COMPOSE_CONTENT
      - fastapi"
fi

COMPOSE_CONTENT="$COMPOSE_CONTENT

volumes:
  caddy_data:
  caddy_config:"

echo "$COMPOSE_CONTENT" > "$N8N_DIR/docker-compose.yml"

# Tạo file Caddyfile
echo "Tạo file Caddyfile..."
CADDYFILE_CONTENT="${DOMAIN} {
    reverse_proxy n8n:5678
    tls internal
}"

if [ "$INSTALL_NEWS_API" = true ]; then
    CADDYFILE_CONTENT="$CADDYFILE_CONTENT

${API_DOMAIN} {
    reverse_proxy fastapi:8000
    tls internal
}"
fi

echo "$CADDYFILE_CONTENT" > "$N8N_DIR/Caddyfile"

# Cấu hình gửi backup qua Telegram
TELEGRAM_CONF_FILE="$N8N_DIR/telegram_config.txt"
read -p "Bạn có muốn cấu hình gửi file backup hàng ngày qua Telegram không? (y/n): " CONFIGURE_TELEGRAM
if [[ "$CONFIGURE_TELEGRAM" =~ ^[Yy]$ ]]; then
    echo "======================================================================"
    echo "📱 HƯỚNG DẪN LẤY TELEGRAM BOT TOKEN VÀ CHAT ID:"
    echo "1. Bot Token:"
    echo "   - Mở Telegram, tìm @BotFather"
    echo "   - Gửi lệnh: /newbot"
    echo "   - Đặt tên và username cho bot"
    echo "   - Copy Bot Token nhận được"
    echo ""
    echo "2. Chat ID:"
    echo "   - Cá nhân: Tìm @userinfobot, gửi /start để lấy User ID"
    echo "   - Nhóm: Thêm bot vào nhóm, gửi tin nhắn, sau đó truy cập:"
    echo "     https://api.telegram.org/bot<BOT_TOKEN>/getUpdates"
    echo "   - Chat ID nhóm bắt đầu bằng dấu trừ (-)"
    echo "======================================================================"
    read -p "Nhập Telegram Bot Token của bạn: " TELEGRAM_BOT_TOKEN
    read -p "Nhập Telegram Chat ID của bạn (hoặc group ID): " TELEGRAM_CHAT_ID
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        echo "TELEGRAM_BOT_TOKEN=\"$TELEGRAM_BOT_TOKEN\"" > "$TELEGRAM_CONF_FILE"
        echo "TELEGRAM_CHAT_ID=\"$TELEGRAM_CHAT_ID\"" >> "$TELEGRAM_CONF_FILE"
        echo "DOMAIN=\"$DOMAIN\"" >> "$TELEGRAM_CONF_FILE"
        chmod 600 "$TELEGRAM_CONF_FILE"
        echo "✅ Đã lưu cấu hình Telegram vào $TELEGRAM_CONF_FILE"
        
        # Test gửi tin nhắn
        echo "🧪 Đang test gửi tin nhắn Telegram..."
        TEST_MSG="🎉 Chúc mừng! Backup tự động N8N đã được cấu hình thành công cho domain: $DOMAIN"
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d chat_id="${TELEGRAM_CHAT_ID}" \
            -d text="${TEST_MSG}" > /dev/null
        echo "✅ Đã gửi tin nhắn test. Kiểm tra Telegram của bạn!"
    else
        echo "❌ Bot Token hoặc Chat ID không được cung cấp. Bỏ qua cấu hình Telegram."
    fi
elif [[ "$CONFIGURE_TELEGRAM" =~ ^[Nn]$ ]]; then
    echo "Đã bỏ qua cấu hình gửi backup qua Telegram."
    if [ -f "$TELEGRAM_CONF_FILE" ]; then
        rm -f "$TELEGRAM_CONF_FILE"
    fi
else
    echo "Lựa chọn không hợp lệ. Mặc định bỏ qua cấu hình Telegram."
fi

# Tạo script sao lưu workflow và credentials (cải tiến)
echo "Tạo script sao lưu workflow và credentials tại $N8N_DIR/backup-workflows.sh..."
cat << 'EOF' > $N8N_DIR/backup-workflows.sh
#!/bin/bash

N8N_DIR_VALUE="__N8N_DIR__"
BACKUP_BASE_DIR="${N8N_DIR_VALUE}/files/backup_full"
LOG_FILE="${BACKUP_BASE_DIR}/backup.log"
TELEGRAM_CONF_FILE="${N8N_DIR_VALUE}/telegram_config.txt"
DATE="$(date +"%Y%m%d_%H%M%S")"
BACKUP_FILE_NAME="n8n_backup_${DATE}.tar.gz"
BACKUP_FILE_PATH="${BACKUP_BASE_DIR}/${BACKUP_FILE_NAME}"
TEMP_DIR_HOST="/tmp/n8n_backup_host_${DATE}"
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
                send_telegram_message "📦 Backup N8N (*__DOMAIN__*) hoàn tất!\n📁 File: \`${BACKUP_FILE_NAME}\`\n📏 Size: ${readable_size}MB (quá lớn để gửi)\n📍 Vị trí: \`${file_path}\`"
            fi
        fi
    fi
}

mkdir -p "${BACKUP_BASE_DIR}"
log "🚀 Bắt đầu sao lưu workflows và credentials..."
send_telegram_message "🔄 Bắt đầu quá trình backup N8N cho domain: *__DOMAIN__*..."

# Tìm container N8N
N8N_CONTAINER_ID="$(docker ps -q --filter "name=n8n" --format '{{.ID}}' | head -n 1)"

if [ -z "${N8N_CONTAINER_ID}" ]; then
    log "❌ Lỗi: Không tìm thấy container n8n đang chạy."
    send_telegram_message "❌ Lỗi backup N8N (*__DOMAIN__*): Không tìm thấy container đang chạy."
    exit 1
fi
log "✅ Tìm thấy container N8N ID: ${N8N_CONTAINER_ID}"

# Tạo thư mục backup tạm
mkdir -p "${TEMP_DIR_HOST}/workflows"
mkdir -p "${TEMP_DIR_HOST}/credentials" 
mkdir -p "${TEMP_DIR_HOST}/config"

# Export workflows
log "📋 Đang export workflows..."
TEMP_DIR_CONTAINER_UNIQUE="/tmp/n8n_export_${DATE}"
docker exec "${N8N_CONTAINER_ID}" mkdir -p "${TEMP_DIR_CONTAINER_UNIQUE}"

WORKFLOWS_JSON="$(docker exec "${N8N_CONTAINER_ID}" n8n list:workflow --json 2>/dev/null || echo "[]")"

if [ -z "${WORKFLOWS_JSON}" ] || [ "${WORKFLOWS_JSON}" == "[]" ]; then
    log "⚠️  Cảnh báo: Không tìm thấy workflow nào để backup."
    echo "[]" > "${TEMP_DIR_HOST}/workflows/workflows.json"
else
    echo "${WORKFLOWS_JSON}" | jq -c '.[]' 2>/dev/null | while IFS= read -r workflow; do
        id="$(echo "${workflow}" | jq -r '.id' 2>/dev/null || echo "")"
        name="$(echo "${workflow}" | jq -r '.name' 2>/dev/null | tr -dc '[:alnum:][:space:]_-' | tr '[:space:]' '_')"
        safe_name="$(echo "${name}" | sed 's/[^a-zA-Z0-9_-]/_/g' | cut -c1-100)"
        
        if [ -n "${id}" ] && [ "${id}" != "null" ]; then
            output_file_container="${TEMP_DIR_CONTAINER_UNIQUE}/${id}-${safe_name}.json"
            log "📄 Đang export workflow: '${name}' (ID: ${id})"
            if docker exec "${N8N_CONTAINER_ID}" n8n export:workflow --id="${id}" --output="${output_file_container}" 2>/dev/null; then
                log "✅ Đã export workflow ID ${id} thành công."
            else
                log "❌ Lỗi khi export workflow ID ${id}."
            fi
        fi
    done

    # Copy workflows từ container ra host
    if docker cp "${N8N_CONTAINER_ID}:${TEMP_DIR_CONTAINER_UNIQUE}/." "${TEMP_DIR_HOST}/workflows/" 2>/dev/null; then
        log "✅ Copy workflows từ container thành công."
    else
        log "❌ Lỗi khi copy workflows từ container."
    fi
    
    # Save workflows list
    echo "${WORKFLOWS_JSON}" > "${TEMP_DIR_HOST}/workflows/workflows.json"
fi

# Backup database và encryption key
log "🔐 Đang backup database và encryption key..."
DB_PATH_HOST="${N8N_DIR_VALUE}/database.sqlite"
KEY_PATH_HOST="${N8N_DIR_VALUE}/encryptionKey"
CONFIG_PATH_HOST="${N8N_DIR_VALUE}/config"

if [ -f "${DB_PATH_HOST}" ]; then
    cp "${DB_PATH_HOST}" "${TEMP_DIR_HOST}/credentials/database.sqlite"
    log "✅ Đã backup database.sqlite"
else
    log "⚠️  Không tìm thấy database.sqlite tại ${DB_PATH_HOST}"
fi

if [ -f "${KEY_PATH_HOST}" ]; then
    cp "${KEY_PATH_HOST}" "${TEMP_DIR_HOST}/credentials/encryptionKey"
    log "✅ Đã backup encryptionKey"
else
    log "⚠️  Không tìm thấy encryptionKey tại ${KEY_PATH_HOST}"
fi

# Backup config nếu có
if [ -d "${CONFIG_PATH_HOST}" ]; then
    cp -r "${CONFIG_PATH_HOST}"/* "${TEMP_DIR_HOST}/config/" 2>/dev/null
    log "✅ Đã backup config files"
fi

# Tạo metadata file
cat << METADATA > "${TEMP_DIR_HOST}/backup_metadata.json"
{
    "backup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "domain": "__DOMAIN__",
    "n8n_version": "$(docker exec "${N8N_CONTAINER_ID}" n8n --version 2>/dev/null || echo 'unknown')",
    "backup_type": "full",
    "backup_size": "to_be_calculated",
    "created_by": "Nguyễn Ngọc Thiện - Auto Backup Script"
}
METADATA

# Tạo file nén
log "📦 Đang tạo file backup: ${BACKUP_FILE_PATH}"
if tar -czf "${BACKUP_FILE_PATH}" -C "${TEMP_DIR_HOST}" . 2>/dev/null; then
    # Tính size và cập nhật metadata
    BACKUP_SIZE=$(du -h "${BACKUP_FILE_PATH}" | cut -f1)
    log "✅ Tạo file backup thành công. Size: ${BACKUP_SIZE}"
    
    # Gửi qua Telegram
    send_telegram_document "${BACKUP_FILE_PATH}" "📦 Backup N8N (*__DOMAIN__*) ngày $(date '+%d/%m/%Y %H:%M')
📁 Size: ${BACKUP_SIZE}
🎯 Workflows: $(ls -1 "${TEMP_DIR_HOST}/workflows"/*.json 2>/dev/null | wc -l)
⏰ Thời gian: $(date '+%H:%M:%S')"
else
    log "❌ Lỗi: Không thể tạo file backup ${BACKUP_FILE_PATH}."
    send_telegram_message "❌ Lỗi backup N8N (*__DOMAIN__*): Không thể tạo file backup."
fi

# Cleanup
log "🧹 Dọn dẹp thư mục tạm..."
rm -rf "${TEMP_DIR_HOST}"
docker exec "${N8N_CONTAINER_ID}" rm -rf "${TEMP_DIR_CONTAINER_UNIQUE}" 2>/dev/null || true

# Cleanup old backups (giữ 30 bản gần nhất)
log "🗂️  Dọn dẹp backup cũ (giữ 30 bản gần nhất)..."
find "${BACKUP_BASE_DIR}" -maxdepth 1 -name 'n8n_backup_*.tar.gz' -type f -printf '%T@ %p\n' 2>/dev/null | \
sort -nr | tail -n +31 | cut -d' ' -f2- | xargs -r rm -f

BACKUP_COUNT=$(find "${BACKUP_BASE_DIR}" -maxdepth 1 -name 'n8n_backup_*.tar.gz' -type f | wc -l)

log "✅ Backup hoàn tất: ${BACKUP_FILE_PATH}"
if [ -f "${BACKUP_FILE_PATH}" ]; then
    send_telegram_message "✅ Backup N8N (*__DOMAIN__*) hoàn tất!
📁 File: \`${BACKUP_FILE_NAME}\`
📊 Tổng backup: ${BACKUP_COUNT}/30
📋 Log: \`${LOG_FILE}\`"
else
    send_telegram_message "❌ Backup N8N (*__DOMAIN__*) thất bại! Kiểm tra log: \`${LOG_FILE}\`"
fi

exit 0
EOF

# Thay thế biến trong script
sed -i "s|__N8N_DIR__|$N8N_DIR|g" $N8N_DIR/backup-workflows.sh
sed -i "s|__DOMAIN__|$DOMAIN|g" $N8N_DIR/backup-workflows.sh
chmod +x $N8N_DIR/backup-workflows.sh

# Tạo script backup thủ công để test
echo "Tạo script backup thủ công tại $N8N_DIR/backup-manual.sh..."
cat << 'EOF' > $N8N_DIR/backup-manual.sh
#!/bin/bash

echo "🧪 Chạy backup thủ công để test..."
echo "======================================================================"

# Chạy script backup chính
SCRIPT_DIR="$(dirname "$0")"
BACKUP_SCRIPT="$SCRIPT_DIR/backup-workflows.sh"

if [ -f "$BACKUP_SCRIPT" ]; then
    echo "📍 Chạy: $BACKUP_SCRIPT"
    echo "======================================================================"
    bash "$BACKUP_SCRIPT"
    echo "======================================================================"
    echo "✅ Backup thủ công hoàn tất!"
    echo "📁 Kiểm tra thư mục: $SCRIPT_DIR/files/backup_full/"
    echo "📋 Xem log: $SCRIPT_DIR/files/backup_full/backup.log"
else
    echo "❌ Không tìm thấy script backup: $BACKUP_SCRIPT"
    exit 1
fi
EOF
chmod +x $N8N_DIR/backup-manual.sh

# Tạo script troubleshoot
echo "Tạo script chẩn đoán tại $N8N_DIR/troubleshoot.sh..."
cat << 'EOF' > $N8N_DIR/troubleshoot.sh
#!/bin/bash

echo "🔍 CHẨN ĐOÁN HỆ THỐNG N8N"
echo "======================================================================"

# Thông tin cơ bản
echo "📊 THÔNG TIN HỆ THỐNG:"
echo "- Thời gian: $(date)"
echo "- Uptime: $(uptime)"
echo "- Disk usage: $(df -h / | tail -1 | awk '{print $5}')"
echo "- Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"
echo "- Swap: $(free -h | grep Swap | awk '{print $3"/"$2}')"
echo ""

# Docker status
echo "🐳 DOCKER STATUS:"
if command -v docker &> /dev/null; then
    echo "✅ Docker installed: $(docker --version)"
    echo "🔄 Docker service: $(systemctl is-active docker)"
    echo "📦 Containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "💾 Docker disk usage:"
    docker system df
else
    echo "❌ Docker not found!"
fi
echo ""

# N8N specific
N8N_DIR_VALUE="__N8N_DIR__"
echo "🚀 N8N STATUS:"
echo "📁 N8N Directory: $N8N_DIR_VALUE"
if [ -d "$N8N_DIR_VALUE" ]; then
    echo "✅ N8N directory exists"
    echo "📋 Files in N8N directory:"
    ls -la "$N8N_DIR_VALUE"
    echo ""
    
    if [ -f "$N8N_DIR_VALUE/docker-compose.yml" ]; then
        echo "✅ docker-compose.yml exists"
        cd "$N8N_DIR_VALUE"
        
        # Container logs
        echo "📝 Recent container logs:"
        if command -v docker-compose &> /dev/null; then
            docker-compose logs --tail=10 n8n
        elif docker compose version &> /dev/null; then
            docker compose logs --tail=10 n8n
        fi
    else
        echo "❌ docker-compose.yml not found"
    fi
else
    echo "❌ N8N directory not found"
fi
echo ""

# Network checks
echo "🌐 NETWORK CHECKS:"
echo "🔍 External IP: $(curl -s https://api.ipify.org || echo 'Failed to get IP')"
echo "🔍 DNS resolution test:"
nslookup google.com
echo ""

# Backup status
echo "💾 BACKUP STATUS:"
BACKUP_DIR="$N8N_DIR_VALUE/files/backup_full"
if [ -d "$BACKUP_DIR" ]; then
    echo "✅ Backup directory exists"
    echo "📊 Backup files:"
    ls -lah "$BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -5 || echo "No backup files found"
    
    if [ -f "$BACKUP_DIR/backup.log" ]; then
        echo "📋 Recent backup log:"
        tail -10 "$BACKUP_DIR/backup.log"
    fi
else
    echo "❌ Backup directory not found"
fi
echo ""

# Cron status
echo "⏰ CRON STATUS:"
echo "🔄 Cron service: $(systemctl is-active cron)"
echo "📋 Active cron jobs:"
crontab -l | grep -E "(backup|update)" || echo "No N8N related cron jobs found"
echo ""

echo "======================================================================"
echo "✅ Chẩn đoán hoàn tất!"
echo "📞 Nếu cần hỗ trợ, liên hệ: 08.8888.4749"
EOF

sed -i "s|__N8N_DIR__|$N8N_DIR|g" $N8N_DIR/troubleshoot.sh
chmod +x $N8N_DIR/troubleshoot.sh

# Đặt quyền cho thư mục n8n
echo "Đặt quyền cho thư mục n8n tại $N8N_DIR..."
sudo chown -R 1000:1000 $N8N_DIR 
sudo chmod -R u+rwX,g+rX,o+rX $N8N_DIR
sudo chown -R 1000:1000 $N8N_DIR/files
sudo chmod -R u+rwX,g+rX,o+rX $N8N_DIR/files

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
        echo "Lỗi: Không thể build Docker image thậm chí với cấu hình đơn giản."
        echo "Kiểm tra kết nối mạng và thử lại."
        exit 1
    fi
    echo "Build thành công với cấu hình đơn giản (không có Puppeteer nodes)."
fi

echo "Đang khởi động các container..."
if ! $DOCKER_COMPOSE_CMD up -d; then
    echo "Lỗi: Khởi động container thất bại."
    echo "Kiểm tra logs: $DOCKER_COMPOSE_CMD logs"
    exit 1
fi

echo "Đợi các container khởi động (30 giây)..."
sleep 30

# Kiểm tra các container đã chạy chưa
echo "Kiểm tra trạng thái các container..."
if $DOCKER_COMPOSE_CMD ps | grep -q "n8n"; then
    echo "✅ Container n8n đã chạy thành công."
else
    echo "⚠️  Container n8n có thể chưa chạy. Kiểm tra logs: $DOCKER_COMPOSE_CMD logs n8n"
fi

if $DOCKER_COMPOSE_CMD ps | grep -q "caddy"; then
    echo "✅ Container caddy đã chạy thành công."
else
    echo "⚠️  Container caddy có thể chưa chạy. Kiểm tra logs: $DOCKER_COMPOSE_CMD logs caddy"
fi

if [ "$INSTALL_NEWS_API" = true ] && $DOCKER_COMPOSE_CMD ps | grep -q "fastapi"; then
    echo "✅ Container News API đã chạy thành công."
else
    if [ "$INSTALL_NEWS_API" = true ]; then
        echo "⚠️  Container News API có thể chưa chạy. Kiểm tra logs: $DOCKER_COMPOSE_CMD logs fastapi"
    fi
fi

# Tạo script cập nhật tự động (cải tiến)
echo "Tạo script cập nhật tự động tại $N8N_DIR/update-n8n.sh..."
cat << 'EOF' > $N8N_DIR/update-n8n.sh
#!/bin/bash
N8N_DIR_VALUE="__N8N_DIR__"
LOG_FILE="$N8N_DIR_VALUE/update.log"

log() { 
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Hỏi người dùng có muốn cập nhật không (nếu chạy thủ công)
if [ -t 0 ]; then  # Kiểm tra nếu chạy interactively
    read -p "🔄 Bạn có muốn cập nhật N8N và các thành phần không? (y/n): " UPDATE_CHOICE
    if [[ ! "$UPDATE_CHOICE" =~ ^[Yy]$ ]]; then
        log "❌ Người dùng từ chối cập nhật."
        exit 0
    fi
fi

log "🚀 Bắt đầu kiểm tra cập nhật..."
cd "$N8N_DIR_VALUE"

if command -v docker-compose &> /dev/null; then 
    DOCKER_COMPOSE="docker-compose"
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then 
    DOCKER_COMPOSE="docker compose"
else 
    log "❌ Lỗi: Docker Compose không tìm thấy."
    exit 1
fi

# Backup trước khi cập nhật
log "💾 Chạy backup trước khi cập nhật..."
if [ -x "$N8N_DIR_VALUE/backup-workflows.sh" ]; then
    "$N8N_DIR_VALUE/backup-workflows.sh"
    log "✅ Backup hoàn tất."
else
    log "⚠️  Không tìm thấy script backup."
fi

# Cập nhật yt-dlp trên host
log "🎥 Cập nhật yt-dlp trên host..."
if command -v pipx &> /dev/null; then 
    pipx upgrade yt-dlp
elif [ -d "/opt/yt-dlp-venv" ]; then 
    /opt/yt-dlp-venv/bin/pip install -U yt-dlp
fi

# Kéo image mới
log "🐳 Kéo images mới nhất..."
docker pull n8nio/n8n:latest
docker pull caddy:latest

# Kiểm tra có cập nhật không
CURRENT_N8N_IMAGE_ID="$(docker images -q n8n-custom-ffmpeg:latest)"
log "🔧 Build lại images custom..."
if ! $DOCKER_COMPOSE build --no-cache; then 
    log "❌ Lỗi build images custom."
    exit 1
fi
NEW_N8N_IMAGE_ID="$(docker images -q n8n-custom-ffmpeg:latest)"

if [ "$CURRENT_N8N_IMAGE_ID" != "$NEW_N8N_IMAGE_ID" ] || [ -z "$CURRENT_N8N_IMAGE_ID" ]; then
    log "🔄 Phát hiện image mới, tiến hành cập nhật containers..."
    
    log "🛑 Dừng containers..."
    $DOCKER_COMPOSE down
    
    log "🚀 Khởi động lại containers..."
    $DOCKER_COMPOSE up -d
    
    # Đợi containers khởi động
    sleep 30
    
    log "✅ Cập nhật containers hoàn tất."
else
    log "ℹ️  Không có cập nhật mới cho N8N images."
fi

# Cập nhật yt-dlp trong container
log "🎥 Cập nhật yt-dlp trong container n8n..."
N8N_CONTAINER_FOR_UPDATE="$(docker ps -q --filter name=n8n)"
if [ -n "$N8N_CONTAINER_FOR_UPDATE" ]; then
    docker exec -u root $N8N_CONTAINER_FOR_UPDATE pip3 install --break-system-packages -U yt-dlp
    log "✅ yt-dlp trong container đã được cập nhật."
else
    log "⚠️  Không tìm thấy container n8n đang chạy."
fi

# Dọn dẹp Docker
log "🧹 Dọn dẹp Docker images cũ..."
docker image prune -f

log "✅ Kiểm tra cập nhật hoàn tất."
EOF

sed -i "s|__N8N_DIR__|$N8N_DIR|g" $N8N_DIR/update-n8n.sh
chmod +x $N8N_DIR/update-n8n.sh

# Thiết lập cron job với tùy chọn auto-update
read -p "Bạn có muốn bật tự động cập nhật mỗi 12 giờ không? (y/n): " ENABLE_AUTO_UPDATE
if [[ "$ENABLE_AUTO_UPDATE" =~ ^[Yy]$ ]]; then
    CRON_USER=$(whoami)
    UPDATE_CRON="0 */12 * * * $N8N_DIR/update-n8n.sh"
    BACKUP_CRON="0 2 * * * $N8N_DIR/backup-workflows.sh"
    (crontab -u $CRON_USER -l 2>/dev/null | grep -v "update-n8n.sh" | grep -v "backup-workflows.sh"; echo "$UPDATE_CRON"; echo "$BACKUP_CRON") | crontab -u $CRON_USER -
    echo "✅ Đã thiết lập cron job cập nhật tự động mỗi 12 giờ và backup hàng ngày lúc 2:00 AM."
else
    CRON_USER=$(whoami)
    BACKUP_CRON="0 2 * * * $N8N_DIR/backup-workflows.sh"
    (crontab -u $CRON_USER -l 2>/dev/null | grep -v "update-n8n.sh" | grep -v "backup-workflows.sh"; echo "$BACKUP_CRON") | crontab -u $CRON_USER -
    echo "✅ Đã thiết lập chỉ backup hàng ngày lúc 2:00 AM. Cập nhật thủ công khi cần."
fi

echo "======================================================================"
echo "🎉 HOÀN TẤT CÀI ĐẶT N8N VỚI TẤT CẢ TÍNH NĂNG NÂNG CAO!"
echo "======================================================================"
echo ""
echo "🚀 TRUY CẬP ỨNG DỤNG:"
echo "   📱 N8N Main: https://${DOMAIN}"

if [ "$INSTALL_NEWS_API" = true ]; then
    echo "   📰 News API: https://${API_DOMAIN}"
    echo "   📚 API Docs: https://${API_DOMAIN}/docs"
    echo "   🔑 Bearer Token: $(cat $N8N_DIR/news_api_token.txt)"
fi

echo ""
echo "💾 THÔNG TIN HỆ THỐNG:"
if [ "$(swapon --show | wc -l)" -gt 0 ]; then
    SWAP_INFO=$(free -h | grep Swap | awk '{print $2}')
    echo "   💿 Swap Memory: $SWAP_INFO"
fi
echo "   📁 Thư mục cài đặt: $N8N_DIR"
echo "   🎥 Video downloads: $N8N_DIR/files/youtube_content_anylystic/"
echo "   💾 Backup storage: $N8N_DIR/files/backup_full/"

echo ""
echo "🛠️  CÁC LỆNH QUẢN LÝ:"
echo "   🔍 Chẩn đoán hệ thống: $N8N_DIR/troubleshoot.sh"
echo "   💾 Backup thủ công: $N8N_DIR/backup-manual.sh"
echo "   🔄 Cập nhật thủ công: $N8N_DIR/update-n8n.sh"
echo "   📋 Xem logs: cd $N8N_DIR && docker-compose logs -f"

echo ""
echo "📊 TÍNH NĂNG ĐÃ CÀI ĐẶT:"
echo "   ✅ N8N với FFmpeg, yt-dlp, Puppeteer"
echo "   ✅ SSL tự động với Caddy"
echo "   ✅ Backup tự động hàng ngày (2:00 AM)"

if [ -f "$TELEGRAM_CONF_FILE" ]; then
    echo "   ✅ Telegram notifications"
fi

if [ "$INSTALL_NEWS_API" = true ]; then
    echo "   ✅ News Content API (FastAPI + Newspaper4k)"
fi

if [[ "$ENABLE_AUTO_UPDATE" =~ ^[Yy]$ ]]; then
    echo "   ✅ Auto-update mỗi 12 giờ"
else
    echo "   📝 Auto-update: Tắt (cập nhật thủ công)"
fi

echo ""
echo "📖 HƯỚNG DẪN CHI TIẾT:"
echo "   🎬 YouTube: https://www.youtube.com/@kalvinthiensocial"
echo "   📘 Facebook: https://www.facebook.com/Ban.Thien.Handsome/"
echo "   📞 Liên hệ: 08.8888.4749"

if [ "$INSTALL_NEWS_API" = true ]; then
    echo ""
    echo "🔧 SỬ DỤNG NEWS API TRONG N8N:"
    echo "   1. Tạo HTTP Request node trong N8N"
    echo "   2. Method: POST"
    echo "   3. URL: https://${API_DOMAIN}/extract-article"
    echo "   4. Headers: Authorization: Bearer $(cat $N8N_DIR/news_api_token.txt)"
    echo "   5. Body: {\"url\": \"https://dantri.com.vn/example.htm\"}"
fi

echo ""
echo "======================================================================"
echo "🎉 Chúc bạn sử dụng N8N hiệu quả! - Nguyễn Ngọc Thiện"
echo "======================================================================"
