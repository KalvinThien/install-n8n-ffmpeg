#!/bin/bash

# Hiển thị banner
echo "======================================================================"
echo "🚀 Script Cài Đặt N8N Cải Tiến với News API và Telegram Backup 🚀"
echo "                    Tác giả: Nguyễn Ngọc Thiện                      "
echo "📺 YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1"
echo "📱 Zalo: 08.8888.4749 | 📘 Facebook: Ban.Thien.Handsome"
echo "======================================================================"

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   echo "❌ Script này cần được chạy với quyền root (sudo)" 
   exit 1
fi

# Thiết lập biến môi trường để tránh interactive prompts
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

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
    
    echo "📝 Đang thiết lập swap với kích thước ${SWAP_GB}GB (${SWAP_SIZE}MB)..."
    
    dd if=/dev/zero of=/swapfile bs=1M count=$SWAP_SIZE status=progress 2>/dev/null
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null 2>&1
    swapon /swapfile
    
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    
    sysctl vm.swappiness=10 >/dev/null 2>&1
    sysctl vm.vfs_cache_pressure=50 >/dev/null 2>&1
    
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
    echo "  --clean         Xóa tất cả cài đặt N8N cũ và tạo mới"
    exit 0
}

# Hàm clean install
clean_install() {
    echo "🗑️ Đang xóa tất cả cài đặt N8N cũ..."
    
    # Dừng và xóa containers
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
    elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
    fi
    
    if [ -n "$DOCKER_COMPOSE_CMD" ] && [ -f "/home/n8n/docker-compose.yml" ]; then
        cd /home/n8n
        $DOCKER_COMPOSE_CMD down -v 2>/dev/null || true
    fi
    
    # Xóa containers và images liên quan
    docker stop $(docker ps -aq --filter "name=n8n") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "name=n8n") 2>/dev/null || true
    docker rmi $(docker images -q "*n8n*") 2>/dev/null || true
    docker rmi $(docker images -q "*fastapi*") 2>/dev/null || true
    
    # Xóa volumes
    docker volume rm $(docker volume ls -q | grep n8n) 2>/dev/null || true
    
    # Xóa thư mục cài đặt
    rm -rf /home/n8n
    
    # Xóa cron jobs
    crontab -l 2>/dev/null | grep -v "n8n" | crontab - 2>/dev/null || true
    
    echo "✅ Đã xóa sạch tất cả cài đặt N8N cũ."
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

# Thực hiện clean install nếu được yêu cầu
if [ "$CLEAN_INSTALL" = true ]; then
    read -p "⚠️ Bạn có chắc chắn muốn xóa TẤT CẢ cài đặt N8N cũ không? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        clean_install
    else
        echo "❌ Hủy bỏ clean install."
        exit 0
    fi
fi

# Hàm kiểm tra domain
check_domain() {
    local domain=$1
    local server_ip=$(curl -s https://api.ipify.org 2>/dev/null || echo "")
    if [ -z "$server_ip" ]; then 
        echo "❌ Không thể lấy IP server"
        return 1
    fi
    
    local domain_ip=$(dig +short $domain A 2>/dev/null | head -n1)
    
    if [ "$domain_ip" = "$server_ip" ]; then
        return 0
    else
        return 1
    fi
}

# Hàm cài đặt Docker
install_docker() {
    if $SKIP_DOCKER && command -v docker &> /dev/null; then
        echo "✅ Docker đã được cài đặt và bỏ qua theo yêu cầu..."
        return
    fi
    
    if command -v docker &> /dev/null; then
        echo "✅ Docker đã được cài đặt."
    else
        echo "📦 Cài đặt Docker..."
        apt-get update >/dev/null 2>&1
        apt-get install -y apt-transport-https ca-certificates curl software-properties-common >/dev/null 2>&1
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update >/dev/null 2>&1
        apt-get install -y docker-ce docker-ce-cli containerd.io >/dev/null 2>&1
    fi

    # Cài đặt Docker Compose
    if command -v docker-compose &> /dev/null || (command -v docker &> /dev/null && docker compose version &> /dev/null 2>&1); then
        echo "✅ Docker Compose đã được cài đặt."
    else 
        echo "📦 Cài đặt Docker Compose plugin..."
        apt-get install -y docker-compose-plugin >/dev/null 2>&1
        if ! (docker compose version &> /dev/null 2>&1); then 
            echo "📦 Cài docker-compose standalone..." 
            apt-get install -y docker-compose >/dev/null 2>&1
        fi
    fi
    
    if ! command -v docker &> /dev/null; then
        echo "❌ Lỗi: Docker chưa được cài đặt đúng cách."
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! (command -v docker &> /dev/null && docker compose version &> /dev/null 2>&1); then
        echo "❌ Lỗi: Docker Compose chưa được cài đặt đúng cách."
        exit 1
    fi

    if [ "$SUDO_USER" != "" ]; then
        usermod -aG docker $SUDO_USER >/dev/null 2>&1
    fi
    systemctl enable docker >/dev/null 2>&1
    systemctl restart docker >/dev/null 2>&1
    echo "✅ Docker và Docker Compose đã được cài đặt thành công."
}

# Thiết lập swap
setup_swap

# Cài đặt các gói cần thiết
echo "📦 Đang cài đặt các công cụ cần thiết..."
apt-get update >/dev/null 2>&1
apt-get install -y dnsutils curl cron jq tar gzip python3-full python3-venv pipx net-tools bc >/dev/null 2>&1

# Cài đặt yt-dlp
echo "📦 Cài đặt yt-dlp..."
if command -v pipx &> /dev/null; then
    pipx install yt-dlp --force >/dev/null 2>&1
    pipx ensurepath >/dev/null 2>&1
else
    python3 -m venv /opt/yt-dlp-venv >/dev/null 2>&1
    /opt/yt-dlp-venv/bin/pip install -U pip yt-dlp >/dev/null 2>&1
    ln -sf /opt/yt-dlp-venv/bin/yt-dlp /usr/local/bin/yt-dlp
    chmod +x /usr/local/bin/yt-dlp
fi
export PATH="$PATH:/usr/local/bin:/opt/yt-dlp-venv/bin:$HOME/.local/bin"

# Đảm bảo cron service đang chạy
systemctl enable cron >/dev/null 2>&1
systemctl start cron >/dev/null 2>&1

# Cài đặt Docker
install_docker

# Nhận input domain từ người dùng
echo ""
echo "🌐 THIẾT LẬP DOMAIN"
echo "==================="
read -p "Nhập tên miền chính của bạn (ví dụ: n8nkalvinbot.io.vn): " DOMAIN
while ! check_domain $DOMAIN; do
    echo "❌ Domain $DOMAIN chưa được trỏ đúng đến IP server này ($(curl -s https://api.ipify.org))."
    echo "📝 Vui lòng cập nhật bản ghi DNS để trỏ $DOMAIN đến IP $(curl -s https://api.ipify.org)." 
    read -p "Nhấn Enter sau khi cập nhật DNS, hoặc nhập domain khác: " NEW_DOMAIN
    if [ -n "$NEW_DOMAIN" ]; then
        DOMAIN="$NEW_DOMAIN"
    fi
done
echo "✅ Domain $DOMAIN đã được trỏ đúng. Tiếp tục cài đặt."

# Hỏi về News API
echo ""
echo "📰 THIẾT LẬP NEWS CONTENT API"
echo "=============================="
read -p "Bạn có muốn cài đặt FastAPI để cào nội dung bài viết không? (y/n): " INSTALL_NEWS_API
INSTALL_NEWS_API=${INSTALL_NEWS_API,,} # Convert to lowercase

NEWS_API_TOKEN=""
API_DOMAIN=""

if [[ "$INSTALL_NEWS_API" =~ ^[y]$ ]]; then
    API_DOMAIN="api.$DOMAIN"
    echo "🔗 Sẽ tạo API tại: $API_DOMAIN"
    
    echo "🔍 Kiểm tra domain API: $API_DOMAIN"
    while ! check_domain $API_DOMAIN; do
        echo "❌ Domain API $API_DOMAIN chưa được trỏ đúng đến IP server này."
        echo "📝 Vui lòng tạo bản ghi DNS cho $API_DOMAIN trỏ đến IP $(curl -s https://api.ipify.org)."
        read -p "Nhấn Enter sau khi cập nhật DNS cho API domain: "
    done
    echo "✅ Domain API $API_DOMAIN đã được trỏ đúng."
    
    # Cho người dùng tự đặt Bearer Token
    echo ""
    echo "🔑 THIẾT LẬP BEARER TOKEN BẢO MẬT"
    echo "================================="
    echo "📝 Để bảo mật API, bạn cần đặt một Bearer Token riêng."
    echo "💡 Token nên dài ít nhất 20 ký tự, bao gồm chữ và số."
    echo "⚠️ Lưu ý: Token này sẽ được sử dụng để xác thực tất cả API calls."
    echo ""
    
    while true; do
        read -p "🔐 Nhập Bearer Token của bạn (ít nhất 20 ký tự): " NEWS_API_TOKEN
        if [ ${#NEWS_API_TOKEN} -lt 20 ]; then
            echo "❌ Token quá ngắn! Vui lòng nhập ít nhất 20 ký tự."
        elif [[ ! "$NEWS_API_TOKEN" =~ ^[a-zA-Z0-9]+$ ]]; then
            echo "❌ Token chỉ được chứa chữ cái và số!"
        else
            echo "✅ Bearer Token hợp lệ!"
            break
        fi
    done
fi

# Tạo thư mục cho n8n
echo ""
echo "📁 Tạo cấu trúc thư mục cho n8n tại $N8N_DIR..."
mkdir -p $N8N_DIR
mkdir -p $N8N_DIR/files
mkdir -p $N8N_DIR/files/temp
mkdir -p $N8N_DIR/files/youtube_content_anylystic
mkdir -p $N8N_DIR/files/backup_full

# Tạo Dockerfile cho N8N
echo "🐳 Tạo Dockerfile..."
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

# Cài đặt News Content API nếu được chọn
if [[ "$INSTALL_NEWS_API" =~ ^[y]$ ]]; then
    echo "📰 Cài đặt News Content API..."
    
    mkdir -p $N8N_DIR/news_api
    
    # Tạo requirements.txt với version cố định
    cat << 'EOF' > $N8N_DIR/news_api/requirements.txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
newspaper4k==0.9.3.1
python-multipart==0.0.6
jinja2==3.1.2
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
requests==2.31.0
beautifulsoup4==4.12.2
lxml==4.9.3
feedparser==6.0.10
python-dateutil==2.8.2
EOF

    # Tạo main.py cho FastAPI
    cat << 'EOF' > $N8N_DIR/news_api/main.py
import os
import logging
from datetime import datetime
from typing import List, Optional, Dict, Any
import requests
import feedparser
from urllib.parse import urljoin, urlparse
import re

from fastapi import FastAPI, HTTPException, Depends, Request, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, HttpUrl, Field
import newspaper
from newspaper import Article, Source
import uvicorn

# Thiết lập logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Khởi tạo FastAPI app
app = FastAPI(
    title="News Content API by Kalvin Thien",
    description="API để cào nội dung bài viết và RSS feeds - Tác giả: Nguyễn Ngọc Thiện",
    version="2.0.0",
    contact={
        "name": "Nguyễn Ngọc Thiện",
        "url": "https://www.youtube.com/@kalvinthiensocial",
        "email": "contact@kalvinthien.com"
    }
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
NEWS_API_TOKEN = os.getenv("NEWS_API_TOKEN", "default_token_change_me")

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
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
    language: str = Field(default="vi", description="Ngôn ngữ bài viết (vi, en, zh, ja, etc.)")
    extract_images: bool = Field(default=True, description="Có lấy hình ảnh không")
    summarize: bool = Field(default=False, description="Có tóm tắt không")

class SourceRequest(BaseModel):
    url: HttpUrl
    max_articles: int = Field(default=10, ge=1, le=50, description="Số lượng bài viết tối đa")
    language: str = Field(default="vi", description="Ngôn ngữ")

class FeedRequest(BaseModel):
    url: HttpUrl
    max_articles: int = Field(default=10, ge=1, le=100, description="Số lượng bài viết tối đa")

class ArticleResponse(BaseModel):
    title: str
    content: str
    summary: Optional[str] = None
    authors: List[str]
    publish_date: Optional[str] = None
    url: str
    images: List[str] = []
    word_count: int
    read_time_minutes: int
    language: str
    extracted_at: str

class SourceResponse(BaseModel):
    source_url: str
    articles: List[ArticleResponse]
    total_found: int
    extracted_at: str

class FeedResponse(BaseModel):
    feed_url: str
    feed_title: str
    feed_description: str
    articles: List[Dict[str, Any]]
    total_articles: int
    extracted_at: str

# Utility functions
def clean_text(text: str) -> str:
    if not text:
        return ""
    # Loại bỏ ký tự đặc biệt và khoảng trắng thừa
    text = re.sub(r'\s+', ' ', text)
    text = text.strip()
    return text

def estimate_read_time(word_count: int) -> int:
    # Ước tính 200 từ/phút
    return max(1, round(word_count / 200))

def extract_article_content(url: str, language: str = "vi") -> Dict[str, Any]:
    try:
        article = Article(url, language=language)
        article.download()
        article.parse()
        
        # Tính toán thời gian đọc
        word_count = len(article.text.split()) if article.text else 0
        read_time = estimate_read_time(word_count)
        
        # Format publish date
        publish_date = None
        if article.publish_date:
            publish_date = article.publish_date.isoformat()
        
        return {
            "title": clean_text(article.title),
            "content": clean_text(article.text),
            "authors": article.authors or [],
            "publish_date": publish_date,
            "url": url,
            "images": list(article.images) if article.images else [],
            "word_count": word_count,
            "read_time_minutes": read_time,
            "language": language,
            "extracted_at": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Error extracting article {url}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Không thể cào nội dung: {str(e)}")

# Routes
@app.get("/", response_class=HTMLResponse)
async def homepage():
    html_content = """
    <!DOCTYPE html>
    <html lang="vi">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>News Content API - Kalvin Thien</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { 
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                color: white;
            }
            .container {
                background: rgba(255, 255, 255, 0.1);
                backdrop-filter: blur(10px);
                border-radius: 20px;
                padding: 40px;
                max-width: 800px;
                text-align: center;
                box-shadow: 0 8px 32px rgba(31, 38, 135, 0.37);
                border: 1px solid rgba(255, 255, 255, 0.18);
            }
            h1 { font-size: 2.5em; margin-bottom: 20px; }
            .subtitle { font-size: 1.2em; margin-bottom: 30px; opacity: 0.9; }
            .features { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 30px 0; }
            .feature {
                background: rgba(255, 255, 255, 0.1);
                padding: 20px;
                border-radius: 10px;
                border: 1px solid rgba(255, 255, 255, 0.2);
            }
            .links { margin-top: 30px; }
            .btn {
                display: inline-block;
                padding: 12px 24px;
                margin: 10px;
                background: rgba(255, 255, 255, 0.2);
                color: white;
                text-decoration: none;
                border-radius: 25px;
                border: 1px solid rgba(255, 255, 255, 0.3);
                transition: all 0.3s ease;
            }
            .btn:hover {
                background: rgba(255, 255, 255, 0.3);
                transform: translateY(-2px);
            }
            .author {
                margin-top: 30px;
                padding-top: 20px;
                border-top: 1px solid rgba(255, 255, 255, 0.3);
                font-size: 0.9em;
                opacity: 0.8;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 News Content API</h1>
            <p class="subtitle">API cào nội dung bài viết và RSS feeds chuyên nghiệp</p>
            
            <div class="features">
                <div class="feature">
                    <h3>📰 Cào Bài Viết</h3>
                    <p>Trích xuất nội dung từ bất kỳ URL nào</p>
                </div>
                <div class="feature">
                    <h3>🔍 Tìm Kiếm</h3>
                    <p>Crawl nhiều bài viết từ website</p>
                </div>
                <div class="feature">
                    <h3>📡 RSS Feeds</h3>
                    <p>Phân tích và parse RSS feeds</p>
                </div>
                <div class="feature">
                    <h3>🔐 Bảo Mật</h3>
                    <p>Bearer Token authentication</p>
                </div>
            </div>
            
            <div class="links">
                <a href="/docs" class="btn">📚 API Documentation</a>
                <a href="/redoc" class="btn">📖 ReDoc</a>
                <a href="/health" class="btn">🩺 Health Check</a>
            </div>
            
            <div class="author">
                <p><strong>Tác giả:</strong> Nguyễn Ngọc Thiện</p>
                <p>📺 <a href="https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1" style="color: #FFD700;">YouTube Channel</a> | 📱 Zalo: 08.8888.4749</p>
            </div>
        </div>
    </body>
    </html>
    """
    return html_content

@app.get("/health")
async def health_check(token: str = Depends(verify_token)):
    return {
        "status": "healthy",
        "service": "News Content API",
        "version": "2.0.0",
        "author": "Nguyễn Ngọc Thiện",
        "timestamp": datetime.now().isoformat(),
        "endpoints": {
            "extract_article": "/extract-article",
            "extract_source": "/extract-source", 
            "parse_feed": "/parse-feed"
        }
    }

@app.post("/extract-article", response_model=ArticleResponse)
async def extract_article(request: ArticleRequest, token: str = Depends(verify_token)):
    """Trích xuất nội dung từ một bài viết cụ thể"""
    try:
        result = extract_article_content(str(request.url), request.language)
        
        # Thêm summary nếu được yêu cầu
        if request.summarize and result["content"]:
            # Simple summarization - lấy 3 câu đầu
            sentences = result["content"].split('. ')
            summary = '. '.join(sentences[:3]) + '.' if len(sentences) > 3 else result["content"]
            result["summary"] = summary
        
        return ArticleResponse(**result)
    except Exception as e:
        logger.error(f"Error in extract_article: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Lỗi xử lý: {str(e)}")

@app.post("/extract-source", response_model=SourceResponse)
async def extract_source(request: SourceRequest, token: str = Depends(verify_token)):
    """Crawl nhiều bài viết từ một website"""
    try:
        source = Source(str(request.url), language=request.language)
        source.build()
        
        articles = []
        processed = 0
        
        for article_url in source.article_urls():
            if processed >= request.max_articles:
                break
                
            try:
                article_data = extract_article_content(article_url, request.language)
                articles.append(ArticleResponse(**article_data))
                processed += 1
            except Exception as e:
                logger.warning(f"Skipping article {article_url}: {str(e)}")
                continue
        
        return SourceResponse(
            source_url=str(request.url),
            articles=articles,
            total_found=len(articles),
            extracted_at=datetime.now().isoformat()
        )
    except Exception as e:
        logger.error(f"Error in extract_source: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Lỗi crawl source: {str(e)}")

@app.post("/parse-feed", response_model=FeedResponse)
async def parse_feed(request: FeedRequest, token: str = Depends(verify_token)):
    """Parse RSS feed và lấy danh sách bài viết"""
    try:
        feed = feedparser.parse(str(request.url))
        
        if feed.bozo:
            raise HTTPException(status_code=400, detail="RSS feed không hợp lệ")
        
        articles = []
        for entry in feed.entries[:request.max_articles]:
            article_data = {
                "title": clean_text(entry.get('title', '')),
                "link": entry.get('link', ''),
                "description": clean_text(entry.get('description', '')),
                "published": entry.get('published', ''),
                "author": entry.get('author', ''),
                "tags": [tag.term for tag in entry.get('tags', [])],
                "summary": clean_text(entry.get('summary', ''))
            }
            articles.append(article_data)
        
        return FeedResponse(
            feed_url=str(request.url),
            feed_title=clean_text(feed.feed.get('title', '')),
            feed_description=clean_text(feed.feed.get('description', '')),
            articles=articles,
            total_articles=len(articles),
            extracted_at=datetime.now().isoformat()
        )
    except Exception as e:
        logger.error(f"Error in parse_feed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Lỗi parse RSS: {str(e)}")

if __name__ == "__main__":
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
    libwebp-dev \
    libtiff-dev \
    libopenjp2-7-dev \
    zlib1g-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements và cài đặt Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py .

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
EOF

    echo "✅ Đã tạo News API thành công!"
fi

# Tạo file docker-compose.yml
echo "🐳 Tạo file docker-compose.yml..."
if [[ "$INSTALL_NEWS_API" =~ ^[y]$ ]]; then
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
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

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

    # Tạo Caddyfile với cả 2 domains
    cat << EOF > $N8N_DIR/Caddyfile
${DOMAIN} {
    reverse_proxy n8n:5678
    encode gzip
}

${API_DOMAIN} {
    reverse_proxy fastapi:8000
    encode gzip
}
EOF

    echo "🔑 Bearer Token cho News API: $NEWS_API_TOKEN"
    echo "📝 Lưu token này để sử dụng API!"
    
    # Lưu token vào file để dễ quản lý
    echo "$NEWS_API_TOKEN" > $N8N_DIR/news_api_token.txt
    chmod 600 $N8N_DIR/news_api_token.txt

else
    # Docker compose chỉ có N8N
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

    # Tạo Caddyfile chỉ có N8N
    cat << EOF > $N8N_DIR/Caddyfile
${DOMAIN} {
    reverse_proxy n8n:5678
    encode gzip
}
EOF
fi

# Cấu hình gửi backup qua Telegram
echo ""
echo "📱 THIẾT LẬP TELEGRAM BACKUP"
echo "============================"
TELEGRAM_CONF_FILE="$N8N_DIR/telegram_config.txt"
read -p "Bạn có muốn cấu hình gửi file backup hàng ngày qua Telegram không? (y/n): " CONFIGURE_TELEGRAM
CONFIGURE_TELEGRAM=${CONFIGURE_TELEGRAM,,}

if [[ "$CONFIGURE_TELEGRAM" =~ ^[y]$ ]]; then
    echo ""
    echo "📋 HƯỚNG DẪN LẤY TELEGRAM BOT TOKEN VÀ CHAT ID:"
    echo "=============================================="
    echo "🤖 Lấy Bot Token:"
    echo "   1. Mở Telegram, tìm @BotFather"
    echo "   2. Gửi lệnh: /newbot"
    echo "   3. Làm theo hướng dẫn đặt tên bot"
    echo "   4. Copy Bot Token nhận được"
    echo ""
    echo "🆔 Lấy Chat ID:"
    echo "   - Cho cá nhân: Tìm @userinfobot, gửi /start"
    echo "   - Cho nhóm: Thêm bot vào nhóm, gửi tin nhắn, sau đó truy cập:"
    echo "     https://api.telegram.org/bot<BOT_TOKEN>/getUpdates"
    echo "     (Chat ID nhóm bắt đầu bằng dấu trừ -)"
    echo ""
    
    read -p "🔑 Nhập Telegram Bot Token của bạn: " TELEGRAM_BOT_TOKEN
    read -p "🆔 Nhập Telegram Chat ID của bạn (hoặc group ID): " TELEGRAM_CHAT_ID
    
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        echo "TELEGRAM_BOT_TOKEN=\"$TELEGRAM_BOT_TOKEN\"" > "$TELEGRAM_CONF_FILE"
        echo "TELEGRAM_CHAT_ID=\"$TELEGRAM_CHAT_ID\"" >> "$TELEGRAM_CONF_FILE"
        chmod 600 "$TELEGRAM_CONF_FILE"
        echo "✅ Đã lưu cấu hình Telegram vào $TELEGRAM_CONF_FILE"
        
        # Test gửi tin nhắn
        echo "🧪 Đang test gửi tin nhắn Telegram..."
        TEST_MESSAGE="🎉 Chúc mừng! Telegram backup đã được cấu hình thành công cho N8N domain: $DOMAIN

📝 Thông tin:
- Domain: $DOMAIN
- Backup time: Hàng ngày lúc 2:00 AM
- Tác giả: Nguyễn Ngọc Thiện
- YouTube: https://www.youtube.com/@kalvinthiensocial

✅ Hệ thống sẽ tự động gửi backup qua Telegram từ bây giờ!"

        if curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d chat_id="${TELEGRAM_CHAT_ID}" \
            -d text="${TEST_MESSAGE}" \
            -d parse_mode="Markdown" > /dev/null 2>&1; then
            echo "✅ Test Telegram thành công! Kiểm tra tin nhắn trong Telegram."
        else
            echo "⚠️ Test Telegram thất bại. Kiểm tra lại Bot Token và Chat ID."
        fi
    else
        echo "❌ Bot Token hoặc Chat ID không được cung cấp. Bỏ qua cấu hình Telegram."
    fi
elif [[ "$CONFIGURE_TELEGRAM" =~ ^[n]$ ]]; then
    echo "✅ Đã bỏ qua cấu hình gửi backup qua Telegram."
    if [ -f "$TELEGRAM_CONF_FILE" ]; then
        rm -f "$TELEGRAM_CONF_FILE"
    fi
else
    echo "❌ Lựa chọn không hợp lệ. Mặc định bỏ qua cấu hình Telegram."
fi

# Tạo script sao lưu workflow và credentials
echo ""
echo "💾 Tạo script sao lưu workflow và credentials..."
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
                log "File backup quá lớn (${readable_size} MB) để gửi qua Telegram. Sẽ chỉ gửi thông báo."
                send_telegram_message "🔄 Hoàn tất sao lưu N8N

📊 **Thống kê:**
- Domain: $DOMAIN
- File: \`${BACKUP_FILE_NAME}\`
- Kích thước: ${readable_size}MB (quá lớn để gửi)
- Vị trí: \`${file_path}\`

⚠️ File quá lớn để gửi qua Telegram. Vui lòng truy cập server để tải xuống."
            fi
        fi
    fi
}

mkdir -p "${BACKUP_BASE_DIR}"
log "🔄 Bắt đầu sao lưu workflows và credentials..."
send_telegram_message "🔄 Bắt đầu quá trình sao lưu N8N hàng ngày cho domain: \`$DOMAIN\`..."

# Tìm container N8N
N8N_CONTAINER_ID="$(docker ps -q --filter "name=n8n" --format '{{.ID}}' | head -n 1)"

if [ -z "${N8N_CONTAINER_ID}" ]; then
    log "❌ Lỗi: Không tìm thấy container n8n đang chạy."
    send_telegram_message "❌ **Lỗi sao lưu N8N** (\`$DOMAIN\`): Không tìm thấy container n8n đang chạy."
    exit 1
fi
log "✅ Tìm thấy container N8N ID: ${N8N_CONTAINER_ID}"

mkdir -p "${TEMP_DIR_HOST}/workflows"
mkdir -p "${TEMP_DIR_HOST}/credentials"

# Tạo thư mục export tạm thời bên trong container
TEMP_DIR_CONTAINER_UNIQUE="${TEMP_DIR_CONTAINER_BASE}/export_${DATE}"
docker exec "${N8N_CONTAINER_ID}" mkdir -p "${TEMP_DIR_CONTAINER_UNIQUE}"

log "📤 Xuất workflows vào ${TEMP_DIR_CONTAINER_UNIQUE} trong container..." 
WORKFLOWS_JSON="$(docker exec "${N8N_CONTAINER_ID}" n8n export:workflow --output="${TEMP_DIR_CONTAINER_UNIQUE}" --all 2>/dev/null || echo "")"

if [ $? -eq 0 ]; then
    log "✅ Xuất workflows thành công."
    
    # Sao chép workflows từ container ra host
    log "📋 Sao chép workflows từ container ra host..."
    if docker cp "${N8N_CONTAINER_ID}:${TEMP_DIR_CONTAINER_UNIQUE}/." "${TEMP_DIR_HOST}/workflows/" 2>/dev/null; then
        log "✅ Sao chép workflows thành công."
        WORKFLOW_COUNT=$(find "${TEMP_DIR_HOST}/workflows" -name "*.json" | wc -l)
        log "📊 Đã sao lưu ${WORKFLOW_COUNT} workflows."
    else
        log "⚠️ Lỗi khi sao chép workflows từ container ra host."
    fi
else
    log "⚠️ Cảnh báo: Không tìm thấy workflow nào để sao lưu hoặc lỗi khi xuất."
    WORKFLOW_COUNT=0
fi

# Sao lưu database và encryption key
DB_PATH_HOST="${N8N_DIR_VALUE}/database.sqlite"
KEY_PATH_HOST="${N8N_DIR_VALUE}/encryptionKey"

log "💾 Sao lưu database và encryption key từ host..."
if [ -f "${DB_PATH_HOST}" ]; then
    cp "${DB_PATH_HOST}" "${TEMP_DIR_HOST}/credentials/database.sqlite"
    log "✅ Đã sao lưu database.sqlite"
else
    log "⚠️ Cảnh báo: Không tìm thấy file database.sqlite tại ${DB_PATH_HOST}"
fi

if [ -f "${KEY_PATH_HOST}" ]; then
    cp "${KEY_PATH_HOST}" "${TEMP_DIR_HOST}/credentials/encryptionKey"
    log "✅ Đã sao lưu encryptionKey"
else
    log "⚠️ Cảnh báo: Không tìm thấy file encryptionKey tại ${KEY_PATH_HOST}"
fi

# Tạo metadata
cat << METADATA_EOF > "${TEMP_DIR_HOST}/backup_metadata.json"
{
    "backup_date": "$(date -Iseconds)",
    "domain": "$DOMAIN",
    "workflow_count": ${WORKFLOW_COUNT:-0},
    "n8n_container_id": "${N8N_CONTAINER_ID}",
    "backup_version": "2.0",
    "author": "Nguyễn Ngọc Thiện"
}
METADATA_EOF

log "📦 Tạo file nén tar.gz: ${BACKUP_FILE_PATH}"
if tar -czf "${BACKUP_FILE_PATH}" -C "${TEMP_DIR_HOST}" . 2>/dev/null; then
    BACKUP_SIZE=$(du -h "${BACKUP_FILE_PATH}" | cut -f1)
    log "✅ Tạo file backup ${BACKUP_FILE_PATH} thành công. Kích thước: ${BACKUP_SIZE}"
    
    # Gửi qua Telegram với thông tin chi tiết
    BACKUP_CAPTION="🎉 **Sao lưu N8N hoàn tất**

📊 **Thống kê:**
- Domain: \`$DOMAIN\`
- Workflows: ${WORKFLOW_COUNT:-0}
- Kích thước: ${BACKUP_SIZE}
- File: \`${BACKUP_FILE_NAME}\`
- Thời gian: $(date '+%d/%m/%Y %H:%M:%S')

👨‍💻 **Tác giả:** Nguyễn Ngọc Thiện
📺 **YouTube:** https://www.youtube.com/@kalvinthiensocial"

    send_telegram_document "${BACKUP_FILE_PATH}" "${BACKUP_CAPTION}"
else
    log "❌ Lỗi: Không thể tạo file backup ${BACKUP_FILE_PATH}."
    send_telegram_message "❌ **Lỗi sao lưu N8N** (\`$DOMAIN\`): Không thể tạo file backup. Kiểm tra log tại \`${LOG_FILE}\`"
fi

log "🧹 Dọn dẹp thư mục tạm..."
rm -rf "${TEMP_DIR_HOST}"
docker exec "${N8N_CONTAINER_ID}" rm -rf "${TEMP_DIR_CONTAINER_UNIQUE}" 2>/dev/null || true

log "🗂️ Giữ lại 30 bản sao lưu gần nhất trong ${BACKUP_BASE_DIR}..."
find "${BACKUP_BASE_DIR}" -maxdepth 1 -name 'n8n_backup_*.tar.gz' -type f -printf '%T@ %p\n' 2>/dev/null | \
sort -nr | tail -n +31 | cut -d' ' -f2- | xargs -r rm -f

log "✅ Sao lưu hoàn tất: ${BACKUP_FILE_PATH}"

exit 0
EOF

# Thay thế biến trong script
sed -i "s|\$N8N_DIR|$N8N_DIR|g" $N8N_DIR/backup-workflows.sh
sed -i "s|\$DOMAIN|$DOMAIN|g" $N8N_DIR/backup-workflows.sh
chmod +x $N8N_DIR/backup-workflows.sh

# Tạo script backup thủ công để test
cat << 'EOF' > $N8N_DIR/backup-manual.sh
#!/bin/bash
echo "🧪 Chạy backup thủ công để kiểm tra..."
echo "📝 Script này giúp bạn test backup trước khi thiết lập tự động."
echo ""

# Chạy script backup chính
if [ -x "/home/n8n/backup-workflows.sh" ]; then
    echo "▶️ Đang chạy backup..."
    /home/n8n/backup-workflows.sh
    echo ""
    echo "✅ Backup test hoàn tất!"
    echo "📁 Kiểm tra file backup tại: /home/n8n/files/backup_full/"
    echo "📋 Xem log tại: /home/n8n/files/backup_full/backup.log"
else
    echo "❌ Không tìm thấy script backup-workflows.sh"
    exit 1
fi
EOF
chmod +x $N8N_DIR/backup-manual.sh

# Tạo script chẩn đoán hệ thống
cat << 'EOF' > $N8N_DIR/troubleshoot.sh
#!/bin/bash
echo "🔍 SCRIPT CHẨN ĐOÁN HỆ THỐNG N8N"
echo "================================="
echo "Tác giả: Nguyễn Ngọc Thiện"
echo "YouTube: https://www.youtube.com/@kalvinthiensocial"
echo ""

# Kiểm tra Docker
echo "🐳 KIỂM TRA DOCKER:"
echo "-------------------"
if command -v docker &> /dev/null; then
    echo "✅ Docker đã cài đặt: $(docker --version)"
    if systemctl is-active --quiet docker; then
        echo "✅ Docker service đang chạy"
    else
        echo "❌ Docker service không chạy"
        echo "🔧 Sửa: sudo systemctl start docker"
    fi
else
    echo "❌ Docker chưa được cài đặt"
fi

# Kiểm tra Docker Compose
if command -v docker-compose &> /dev/null; then
    echo "✅ Docker Compose: $(docker-compose --version)"
elif docker compose version &> /dev/null 2>&1; then
    echo "✅ Docker Compose Plugin: $(docker compose version)"
else
    echo "❌ Docker Compose chưa được cài đặt"
fi

echo ""

# Kiểm tra containers
echo "📦 KIỂM TRA CONTAINERS:"
echo "----------------------"
cd /home/n8n 2>/dev/null || { echo "❌ Thư mục /home/n8n không tồn tại"; exit 1; }

if [ -f "docker-compose.yml" ]; then
    echo "✅ File docker-compose.yml tồn tại"
    
    # Xác định lệnh docker-compose
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
    fi
    
    echo "📊 Trạng thái containers:"
    $DOCKER_COMPOSE_CMD ps
    
    echo ""
    echo "🔍 Containers đang chạy:"
    docker ps --filter "name=n8n"
else
    echo "❌ File docker-compose.yml không tồn tại"
fi

echo ""

# Kiểm tra ports
echo "🌐 KIỂM TRA PORTS:"
echo "------------------"
if netstat -tlnp 2>/dev/null | grep -q ":80 "; then
    echo "✅ Port 80 đang được sử dụng"
else
    echo "❌ Port 80 không được sử dụng"
fi

if netstat -tlnp 2>/dev/null | grep -q ":443 "; then
    echo "✅ Port 443 đang được sử dụng"
else
    echo "❌ Port 443 không được sử dụng"
fi

if netstat -tlnp 2>/dev/null | grep -q ":5678 "; then
    echo "✅ Port 5678 (N8N) đang được sử dụng"
else
    echo "❌ Port 5678 (N8N) không được sử dụng"
fi

echo ""

# Kiểm tra disk space
echo "💾 KIỂM TRA DISK SPACE:"
echo "----------------------"
df -h /home/n8n 2>/dev/null || df -h /

echo ""

# Kiểm tra memory
echo "🧠 KIỂM TRA MEMORY:"
echo "-------------------"
free -h

echo ""

# Kiểm tra logs gần đây
echo "📋 LOGS GẦN ĐÂY:"
echo "----------------"
if [ -f "/home/n8n/files/backup_full/backup.log" ]; then
    echo "📄 Backup logs (5 dòng cuối):"
    tail -n 5 /home/n8n/files/backup_full/backup.log
else
    echo "⚠️ Chưa có backup logs"
fi

echo ""

# Kiểm tra cron jobs
echo "⏰ KIỂM TRA CRON JOBS:"
echo "---------------------"
if crontab -l 2>/dev/null | grep -q "n8n"; then
    echo "✅ Cron jobs đã được thiết lập:"
    crontab -l 2>/dev/null | grep "n8n"
else
    echo "❌ Chưa có cron jobs cho N8N"
fi

echo ""

# Đề xuất sửa lỗi
echo "🔧 ĐỀ XUẤT SỬA LỖI:"
echo "-------------------"
echo "1. Nếu containers không chạy:"
echo "   cd /home/n8n && docker-compose up -d"
echo ""
echo "2. Nếu cần rebuild:"
echo "   cd /home/n8n && docker-compose down && docker-compose up -d --build"
echo ""
echo "3. Nếu cần xem logs chi tiết:"
echo "   cd /home/n8n && docker-compose logs -f"
echo ""
echo "4. Nếu cần restart Docker:"
echo "   sudo systemctl restart docker"
echo ""
echo "5. Test backup thủ công:"
echo "   /home/n8n/backup-manual.sh"

echo ""
echo "✅ Chẩn đoán hoàn tất!"
echo "📞 Hỗ trợ: Zalo 08.8888.4749 | YouTube: @kalvinthiensocial"
EOF
chmod +x $N8N_DIR/troubleshoot.sh

# Đặt quyền cho thư mục n8n
echo "🔐 Đặt quyền cho thư mục n8n tại $N8N_DIR..."
chown -R 1000:1000 $N8N_DIR 
chmod -R u+rwX,g+rX,o+rX $N8N_DIR
chown -R 1000:1000 $N8N_DIR/files
chmod -R u+rwX,g+rX,o+rX $N8N_DIR/files

# Khởi động các container
echo ""
echo "🚀 KHỞI ĐỘNG CÁC CONTAINER"
echo "=========================="
cd $N8N_DIR

# Xác định lệnh docker-compose
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif command -v docker &> /dev/null && docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    echo "❌ Lỗi: Không tìm thấy lệnh docker-compose hoặc docker compose plugin."
    exit 1
fi

echo "🐳 Đang build Docker images... (có thể mất vài phút)"
if ! $DOCKER_COMPOSE_CMD build; then
    echo "⚠️ Cảnh báo: Build Docker images thất bại."
    echo "🔄 Đang thử build lại với cấu hình đơn giản hơn..."
    
    # Sử dụng Dockerfile.simple cho N8N
    sed -i 's/dockerfile: Dockerfile/dockerfile: Dockerfile.simple/' $N8N_DIR/docker-compose.yml
    
    if ! $DOCKER_COMPOSE_CMD build; then
        echo "❌ Lỗi: Không thể build Docker images thậm chí với cấu hình đơn giản."
        echo "🔍 Kiểm tra kết nối mạng và thử lại."
        echo "📋 Chạy script chẩn đoán: $N8N_DIR/troubleshoot.sh"
        exit 1
    fi
    echo "✅ Build thành công với cấu hình đơn giản."
fi

echo "▶️ Đang khởi động các container..."
if ! $DOCKER_COMPOSE_CMD up -d; then
    echo "❌ Lỗi: Khởi động container thất bại."
    echo "📋 Kiểm tra logs: $DOCKER_COMPOSE_CMD logs"
    echo "🔍 Chạy script chẩn đoán: $N8N_DIR/troubleshoot.sh"
    exit 1
fi

echo "⏳ Đợi các container khởi động (30 giây)..."
sleep 30

# Kiểm tra containers
echo "🔍 Kiểm tra trạng thái containers..."
if $DOCKER_COMPOSE_CMD ps | grep -q "n8n"; then
    echo "✅ Container N8N đã chạy thành công."
else
    echo "⚠️ Cảnh báo: Container N8N có thể chưa chạy. Kiểm tra logs: $DOCKER_COMPOSE_CMD logs n8n"
fi

if $DOCKER_COMPOSE_CMD ps | grep -q "caddy"; then
    echo "✅ Container Caddy đã chạy thành công."
else
    echo "⚠️ Cảnh báo: Container Caddy có thể chưa chạy. Kiểm tra logs: $DOCKER_COMPOSE_CMD logs caddy"
fi

if [[ "$INSTALL_NEWS_API" =~ ^[y]$ ]] && $DOCKER_COMPOSE_CMD ps | grep -q "fastapi"; then
    echo "✅ Container FastAPI đã chạy thành công."
elif [[ "$INSTALL_NEWS_API" =~ ^[y]$ ]]; then
    echo "⚠️ Cảnh báo: Container FastAPI có thể chưa chạy. Kiểm tra logs: $DOCKER_COMPOSE_CMD logs fastapi"
fi

# Tạo script cập nhật tự động
echo ""
echo "🔄 Tạo script cập nhật tự động..."
cat << EOF > $N8N_DIR/update-n8n.sh
#!/bin/bash
N8N_DIR_VALUE="$N8N_DIR"
LOG_FILE="\$N8N_DIR_VALUE/update.log"

log() { 
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" | tee -a "\$LOG_FILE"
}

log "🔄 Bắt đầu kiểm tra cập nhật..."
cd "\$N8N_DIR_VALUE"

# Xác định lệnh docker-compose
if command -v docker-compose &> /dev/null; then 
    DOCKER_COMPOSE="docker-compose"
elif command -v docker &> /dev/null && docker compose version &> /dev/null 2>&1; then 
    DOCKER_COMPOSE="docker compose"
else 
    log "❌ Lỗi: Docker Compose không tìm thấy."
    exit 1
fi

log "📦 Cập nhật yt-dlp trên host..."
if command -v pipx &> /dev/null; then 
    pipx upgrade yt-dlp >/dev/null 2>&1
elif [ -d "/opt/yt-dlp-venv" ]; then 
    /opt/yt-dlp-venv/bin/pip install -U yt-dlp >/dev/null 2>&1
fi

log "🐳 Kéo image n8nio/n8n mới nhất..."
docker pull n8nio/n8n:latest >/dev/null 2>&1

CURRENT_CUSTOM_IMAGE_ID="\$(docker images -q n8n-custom-ffmpeg:latest 2>/dev/null)"

log "🔨 Build lại image custom n8n..."
if ! \$DOCKER_COMPOSE build n8n >/dev/null 2>&1; then 
    log "❌ Lỗi build image custom."
    exit 1
fi

NEW_CUSTOM_IMAGE_ID="\$(docker images -q n8n-custom-ffmpeg:latest 2>/dev/null)"

if [ "\$CURRENT_CUSTOM_IMAGE_ID" != "\$NEW_CUSTOM_IMAGE_ID" ]; then
    log "🆕 Phát hiện image mới, tiến hành cập nhật n8n..."
    
    # Chạy backup trước khi cập nhật
    log "💾 Chạy backup trước khi cập nhật..."
    if [ -x "\$N8N_DIR_VALUE/backup-workflows.sh" ]; then
        "\$N8N_DIR_VALUE/backup-workflows.sh" >/dev/null 2>&1
    else
        log "⚠️ Không tìm thấy script backup-workflows.sh."
    fi
    
    log "🔄 Dừng và khởi động lại containers..."
    \$DOCKER_COMPOSE down >/dev/null 2>&1
    \$DOCKER_COMPOSE up -d >/dev/null 2>&1
    log "✅ Cập nhật n8n hoàn tất."
else
    log "ℹ️ Không có cập nhật mới cho image n8n custom."
fi

log "📦 Cập nhật yt-dlp trong container n8n..."
N8N_CONTAINER_FOR_UPDATE="\$(docker ps -q --filter name=n8n | head -n1)"
if [ -n "\$N8N_CONTAINER_FOR_UPDATE" ]; then
    docker exec -u root \$N8N_CONTAINER_FOR_UPDATE pip3 install --break-system-packages -U yt-dlp >/dev/null 2>&1
    log "✅ yt-dlp trong container đã được cập nhật."
else
    log "⚠️ Không tìm thấy container n8n đang chạy để cập nhật yt-dlp."
fi

log "✅ Kiểm tra cập nhật hoàn tất."
EOF
chmod +x $N8N_DIR/update-n8n.sh

# Hỏi về auto-update
echo ""
echo "🔄 THIẾT LẬP TỰ ĐỘNG CẬP NHẬT"
echo "============================="
read -p "Bạn có muốn bật tự động cập nhật N8N mỗi 12 giờ không? (y/n): " ENABLE_AUTO_UPDATE
ENABLE_AUTO_UPDATE=${ENABLE_AUTO_UPDATE,,}

# Thiết lập cron jobs
CRON_USER=$(whoami)
BACKUP_CRON="0 2 * * * $N8N_DIR/backup-workflows.sh"

# Xóa cron jobs cũ trước
(crontab -u $CRON_USER -l 2>/dev/null | grep -v "update-n8n.sh" | grep -v "backup-workflows.sh") | crontab -u $CRON_USER - 2>/dev/null

# Thêm backup cron
echo "$BACKUP_CRON" | crontab -u $CRON_USER - 2>/dev/null

if [[ "$ENABLE_AUTO_UPDATE" =~ ^[y]$ ]]; then
    UPDATE_CRON="0 */12 * * * $N8N_DIR/update-n8n.sh"
    (crontab -u $CRON_USER -l 2>/dev/null; echo "$UPDATE_CRON") | crontab -u $CRON_USER - 2>/dev/null
    echo "✅ Đã thiết lập tự động cập nhật mỗi 12 giờ và backup hàng ngày."
else
    echo "✅ Đã thiết lập backup hàng ngày (không bật auto-update)."
fi

# Hiển thị thông tin hoàn tất
echo ""
echo "======================================================================"
echo "🎉 CÀI ĐẶT HOÀN TẤT!"
echo "======================================================================"
echo "✅ N8N đã được cài đặt và cấu hình với FFmpeg, yt-dlp, Puppeteer và SSL."
echo ""
echo "🌐 **TRUY CẬP:**"
echo "   N8N: https://${DOMAIN}"
if [[ "$INSTALL_NEWS_API" =~ ^[y]$ ]]; then
    echo "   News API: https://${API_DOMAIN}"
    echo "   API Docs: https://${API_DOMAIN}/docs"
fi
echo ""

if [ "$(swapon --show | wc -l)" -gt 0 ]; then
    SWAP_INFO=$(free -h | grep Swap | awk '{print $2}')
    echo "💾 **SWAP:** $SWAP_INFO đã được thiết lập"
fi

echo "📁 **FILES:** Dữ liệu được lưu trong $N8N_DIR"
echo ""
echo "🔄 **TỰ ĐỘNG CẬP NHẬT:**"
if [[ "$ENABLE_AUTO_UPDATE" =~ ^[y]$ ]]; then
    echo "   ✅ Kiểm tra mỗi 12 giờ. Log: $N8N_DIR/update.log"
else
    echo "   ❌ Đã tắt (có thể bật sau bằng cách chỉnh sửa crontab)"
fi

echo ""
echo "💾 **BACKUP SYSTEM:**"
echo "   📅 Tự động hàng ngày lúc 2:00 AM"
echo "   📁 Vị trí: $N8N_DIR/files/backup_full/"
echo "   📋 Log: $N8N_DIR/files/backup_full/backup.log"
echo "   🗂️ Giữ lại 30 bản backup gần nhất"
if [ -f "$TELEGRAM_CONF_FILE" ]; then
    echo "   📱 Gửi qua Telegram (nếu <20MB)"
fi

if [[ "$INSTALL_NEWS_API" =~ ^[y]$ ]]; then
    echo ""
    echo "📰 **NEWS CONTENT API:**"
    echo "   🔑 Bearer Token: $NEWS_API_TOKEN"
    echo "   📝 Token đã lưu tại: $N8N_DIR/news_api_token.txt"
    echo "   🔧 Đổi token: sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN=NEW_TOKEN/' $N8N_DIR/docker-compose.yml"
    echo ""
    echo "   📖 **API Endpoints:**"
    echo "   • GET  /health - Kiểm tra trạng thái"
    echo "   • POST /extract-article - Cào nội dung bài viết"
    echo "   • POST /extract-source - Crawl nhiều bài viết"
    echo "   • POST /parse-feed - Phân tích RSS feeds"
    echo ""
    echo "   💻 **Ví dụ sử dụng:**"
    echo "   curl -X GET \"https://${API_DOMAIN}/health\" \\"
    echo "        -H \"Authorization: Bearer $NEWS_API_TOKEN\""
fi

echo ""
echo "🛠️ **QUẢN LÝ HỆ THỐNG:**"
echo "   📊 Trạng thái: cd $N8N_DIR && docker-compose ps"
echo "   📋 Logs: cd $N8N_DIR && docker-compose logs -f"
echo "   🔄 Restart: cd $N8N_DIR && docker-compose restart"
echo "   🧪 Test backup: $N8N_DIR/backup-manual.sh"
echo "   🔍 Chẩn đoán: $N8N_DIR/troubleshoot.sh"
echo ""
echo "📺 **YOUTUBE:** https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1"
echo "📱 **ZALO:** 08.8888.4749"
echo "📘 **FACEBOOK:** Ban.Thien.Handsome"
echo ""
echo "🎬 **Thư mục video YouTube:** $N8N_DIR/files/youtube_content_anylystic/"
echo "🤖 **Puppeteer:** Đã được cài đặt trong container"
echo ""
echo "======================================================================"
echo "🚀 Made with ❤️ by Nguyễn Ngọc Thiện - $(date '+%d/%m/%Y')"
echo "======================================================================"
