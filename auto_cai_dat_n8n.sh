#!/bin/bash

# Hiển thị banner
echo "======================================================================"
echo "     🚀 Script Cài Đặt N8N với FFmpeg, yt-dlp, Puppeteer và News API"
echo "                    (Phiên bản cải tiến 2025)                       "
echo "======================================================================"
echo "👨‍💻 Tác giả: Nguyễn Ngọc Thiện"
echo "📺 YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1"
echo "📱 Zalo: 08.8888.4749"
echo "======================================================================"

# Kiểm tra xem script có được chạy với quyền root không
if [[ $EUID -ne 0 ]]; then
   echo "❌ Script này cần được chạy với quyền root" 
   exit 1
fi

# Thiết lập biến môi trường để tránh interactive prompts
export DEBIAN_FRONTEND=noninteractive

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

# Hàm dọn dẹp cài đặt cũ
cleanup_old_installations() {
    echo "🧹 Bắt đầu dọn dẹp cài đặt cũ..."
    
    # Dừng và xóa containers liên quan
    echo "  🔄 Dừng và xóa containers cũ..."
    docker stop $(docker ps -aq --filter "name=n8n") 2>/dev/null || true
    docker stop $(docker ps -aq --filter "name=caddy") 2>/dev/null || true
    docker stop $(docker ps -aq --filter "name=fastapi") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "name=n8n") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "name=caddy") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "name=fastapi") 2>/dev/null || true
    
    # Xóa docker-compose projects
    echo "  🔄 Xóa docker-compose projects cũ..."
    find /home -name "docker-compose.yml" -path "*/n8n/*" -exec dirname {} \; 2>/dev/null | while read dir; do
        if [ -d "$dir" ]; then
            echo "    Dọn dẹp: $dir"
            cd "$dir" && docker-compose down 2>/dev/null || true
        fi
    done
    
    # Xóa images liên quan
    echo "  🔄 Xóa Docker images cũ..."
    docker rmi $(docker images | grep -E "(n8n|caddy)" | awk '{print $3}') 2>/dev/null || true
    docker rmi n8n-custom-ffmpeg:latest 2>/dev/null || true
    
    # Xóa volumes
    echo "  🔄 Xóa Docker volumes cũ..."
    docker volume rm $(docker volume ls | grep -E "(n8n|caddy)" | awk '{print $2}') 2>/dev/null || true
    
    # Xóa thư mục cài đặt
    echo "  🔄 Xóa thư mục cài đặt cũ..."
    find /home -maxdepth 2 -name "*n8n*" -type d 2>/dev/null | while read dir; do
        if [ -d "$dir" ]; then
            echo "    Xóa thư mục: $dir"
            rm -rf "$dir"
        fi
    done
    
    find /opt -maxdepth 2 -name "*n8n*" -type d 2>/dev/null | while read dir; do
        if [ -d "$dir" ]; then
            echo "    Xóa thư mục: $dir"
            rm -rf "$dir"
        fi
    done
    
    # Xóa cron jobs cũ
    echo "  🔄 Xóa cron jobs cũ..."
    (crontab -l 2>/dev/null | grep -v "n8n" | grep -v "backup-workflows" | grep -v "update-n8n") | crontab - 2>/dev/null || true
    
    # Docker system prune
    echo "  🔄 Dọn dẹp Docker system..."
    docker system prune -af --volumes
    
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
            echo "❌ Tùy chọn không hợp lệ: $1"
            show_help
            ;;
    esac
done

# Hỏi người dùng có muốn dọn dẹp cài đặt cũ không
if [ "$CLEAN_INSTALL" = false ]; then
    read -p "🧹 Bạn có muốn xóa tất cả cài đặt N8N/Docker cũ trước khi cài mới không? (y/n): " CLEAN_CHOICE
    if [[ "$CLEAN_CHOICE" =~ ^[Yy]$ ]]; then
        CLEAN_INSTALL=true
    fi
fi

if [ "$CLEAN_INSTALL" = true ]; then
    cleanup_old_installations
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
    for cmd in dig curl cron jq tar gzip bc; do
        if ! command -v $cmd &> /dev/null; then
            echo "🔄 Lệnh '$cmd' không tìm thấy. Đang cài đặt..."
            apt-get update -qq > /dev/null
            if [ "$cmd" == "cron" ]; then
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
        apt-get update -qq
        apt-get install -y apt-transport-https ca-certificates curl software-properties-common
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update -qq
        apt-get install -y docker-ce docker-ce-cli containerd.io
    fi

    # Cài đặt Docker Compose
    if command -v docker-compose &> /dev/null || (command -v docker &> /dev/null && docker compose version &> /dev/null); then
        echo "✅ Docker Compose đã được cài đặt."
    else 
        echo "🔄 Cài đặt Docker Compose plugin..."
        apt-get install -y docker-compose-plugin
        if ! (docker compose version &> /dev/null); then 
            echo "🔄 Thử cài docker-compose bản cũ..." 
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
    fi
    systemctl enable docker
    systemctl restart docker
    echo "✅ Docker và Docker Compose đã được cài đặt thành công."
}

# Cài đặt các gói cần thiết
echo "🔄 Đang kiểm tra và cài đặt các công cụ cần thiết..."
apt-get update -qq > /dev/null
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
install_docker

# Nhận input domain từ người dùng
read -p "🌐 Nhập tên miền chính của bạn (ví dụ: n8nkalvinbot.io.vn): " DOMAIN
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
read -p "📰 Bạn có muốn cài đặt FastAPI để cào nội dung bài viết không? (y/n): " INSTALL_FASTAPI
if [[ "$INSTALL_FASTAPI" =~ ^[Yy]$ ]]; then
    API_DOMAIN="api.$DOMAIN"
    echo "🌐 Sẽ tạo API tại: $API_DOMAIN"
    
    echo "🔄 Kiểm tra domain API: $API_DOMAIN"
    while ! check_domain $API_DOMAIN; do
        echo "❌ Domain API $API_DOMAIN chưa được trỏ đúng đến IP server này ($(curl -s https://api.ipify.org))."
        echo "📝 Vui lòng cập nhật bản ghi DNS để trỏ $API_DOMAIN đến IP $(curl -s https://api.ipify.org)."
        read -p "🔄 Nhấn Enter sau khi cập nhật DNS, hoặc nhập domain API khác: " NEW_API_DOMAIN
        if [ -n "$NEW_API_DOMAIN" ]; then
            API_DOMAIN="$NEW_API_DOMAIN"
        fi
    done
    echo "✅ Domain API $API_DOMAIN đã được trỏ đúng."
    
    # Yêu cầu người dùng nhập Bearer Token
    while true; do
        read -p "🔐 Nhập Bearer Token của bạn (ít nhất 20 ký tự, chỉ chữ và số): " BEARER_TOKEN
        if [ ${#BEARER_TOKEN} -ge 20 ] && [[ "$BEARER_TOKEN" =~ ^[a-zA-Z0-9]+$ ]]; then
            echo "✅ Bearer Token hợp lệ!"
            break
        else
            echo "❌ Token không hợp lệ! Cần ít nhất 20 ký tự và chỉ chứa chữ cái, số."
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
RUN npm install n8n-nodes-puppeteer || echo "Cảnh báo: Không thể cài đặt n8n-nodes-puppeteer"
RUN mkdir -p /files/youtube_content_anylystic /files/backup_full /files/temp && \
    chown -R node:node /files
USER node
WORKDIR /home/node
EOF

# Cài đặt FastAPI nếu được chọn
if [[ "$INSTALL_FASTAPI" =~ ^[Yy]$ ]]; then
    echo "🔄 Cài đặt News Content API..."
    mkdir -p $N8N_DIR/news_api
    
    # Tạo requirements.txt
    cat << 'EOF' > $N8N_DIR/news_api/requirements.txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
newspaper4k==0.9.3.1
python-multipart==0.0.6
requests==2.31.0
beautifulsoup4==4.12.2
lxml==4.9.3
Pillow==10.1.0
python-dateutil==2.8.2
feedparser==6.0.10
EOF

    # Tạo main.py
    cat << EOF > $N8N_DIR/news_api/main.py
import os
import logging
from datetime import datetime
from typing import List, Optional, Dict, Any
import feedparser
import requests
from bs4 import BeautifulSoup
from fastapi import FastAPI, HTTPException, Depends, Security, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, HttpUrl
from newspaper import Article, Source
import uvicorn

# Cấu hình logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Bearer Token từ environment variable
BEARER_TOKEN = os.getenv("NEWS_API_TOKEN", "default_token_change_me")

app = FastAPI(
    title="News Content API",
    description="API để cào nội dung bài viết và RSS feeds",
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
    if credentials.credentials != BEARER_TOKEN:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return credentials.credentials

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

class SourceResponse(BaseModel):
    articles: List[ArticleResponse]
    total_found: int

class FeedResponse(BaseModel):
    articles: List[Dict[str, Any]]
    total_found: int
    feed_title: str
    feed_description: str

@app.get("/", response_class=HTMLResponse)
async def homepage():
    domain = os.getenv("API_DOMAIN", "api.yourdomain.com")
    token = BEARER_TOKEN
    
    html_content = f'''
    <!DOCTYPE html>
    <html lang="vi">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>News Content API - Cào Nội Dung Bài Viết</title>
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
                text-align: center;
                color: white;
                margin-bottom: 40px;
            }}
            .header h1 {{
                font-size: 2.5rem;
                margin-bottom: 10px;
                text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
            }}
            .header p {{
                font-size: 1.2rem;
                opacity: 0.9;
            }}
            .card {{
                background: white;
                border-radius: 15px;
                padding: 30px;
                margin-bottom: 30px;
                box-shadow: 0 10px 30px rgba(0,0,0,0.1);
                transition: transform 0.3s ease;
            }}
            .card:hover {{
                transform: translateY(-5px);
            }}
            .card h2 {{
                color: #667eea;
                margin-bottom: 20px;
                font-size: 1.8rem;
            }}
            .token-display {{
                background: #f8f9fa;
                border: 2px solid #667eea;
                border-radius: 10px;
                padding: 15px;
                margin: 20px 0;
                font-family: 'Courier New', monospace;
                font-size: 1.1rem;
                word-break: break-all;
            }}
            .curl-example {{
                background: #2d3748;
                color: #e2e8f0;
                border-radius: 10px;
                padding: 20px;
                margin: 15px 0;
                font-family: 'Courier New', monospace;
                font-size: 0.9rem;
                overflow-x: auto;
                position: relative;
            }}
            .copy-btn {{
                position: absolute;
                top: 10px;
                right: 10px;
                background: #667eea;
                color: white;
                border: none;
                border-radius: 5px;
                padding: 5px 10px;
                cursor: pointer;
                font-size: 0.8rem;
            }}
            .copy-btn:hover {{
                background: #5a67d8;
            }}
            .endpoint {{
                background: #f7fafc;
                border-left: 4px solid #667eea;
                padding: 15px;
                margin: 15px 0;
                border-radius: 0 10px 10px 0;
            }}
            .method {{
                display: inline-block;
                padding: 4px 8px;
                border-radius: 4px;
                font-weight: bold;
                font-size: 0.8rem;
                margin-right: 10px;
            }}
            .get {{ background: #48bb78; color: white; }}
            .post {{ background: #ed8936; color: white; }}
            .footer {{
                text-align: center;
                color: white;
                margin-top: 40px;
                opacity: 0.8;
            }}
            .grid {{
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                gap: 20px;
                margin-top: 20px;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🚀 News Content API</h1>
                <p>API mạnh mẽ để cào nội dung bài viết và RSS feeds</p>
            </div>

            <div class="card">
                <h2>🔑 Bearer Token</h2>
                <p>Sử dụng token này để xác thực các API calls:</p>
                <div class="token-display">
                    <strong>Bearer Token:</strong> {token}
                </div>
                <p><strong>Lưu ý:</strong> Giữ token này bảo mật và không chia sẻ công khai!</p>
            </div>

            <div class="card">
                <h2>📖 API Endpoints</h2>
                
                <div class="endpoint">
                    <span class="method get">GET</span>
                    <strong>/health</strong> - Kiểm tra trạng thái API
                </div>
                
                <div class="endpoint">
                    <span class="method post">POST</span>
                    <strong>/extract-article</strong> - Lấy nội dung bài viết từ URL
                </div>
                
                <div class="endpoint">
                    <span class="method post">POST</span>
                    <strong>/extract-source</strong> - Cào nhiều bài viết từ website
                </div>
                
                <div class="endpoint">
                    <span class="method post">POST</span>
                    <strong>/parse-feed</strong> - Phân tích RSS feeds
                </div>
            </div>

            <div class="card">
                <h2>💻 Ví Dụ cURL</h2>
                
                <h3>1. Kiểm tra trạng thái API:</h3>
                <div class="curl-example">
                    <button class="copy-btn" onclick="copyToClipboard('health-curl')">Copy</button>
                    <div id="health-curl">curl -X GET "https://{domain}/health" \\
     -H "Authorization: Bearer {token}"</div>
                </div>

                <h3>2. Lấy nội dung bài viết:</h3>
                <div class="curl-example">
                    <button class="copy-btn" onclick="copyToClipboard('article-curl')">Copy</button>
                    <div id="article-curl">curl -X POST "https://{domain}/extract-article" \\
     -H "Content-Type: application/json" \\
     -H "Authorization: Bearer {token}" \\
     -d '{{
       "url": "https://dantri.com.vn/the-gioi.htm",
       "language": "vi",
       "extract_images": true,
       "summarize": true
     }}'</div>
                </div>

                <h3>3. Cào nhiều bài viết từ website:</h3>
                <div class="curl-example">
                    <button class="copy-btn" onclick="copyToClipboard('source-curl')">Copy</button>
                    <div id="source-curl">curl -X POST "https://{domain}/extract-source" \\
     -H "Content-Type: application/json" \\
     -H "Authorization: Bearer {token}" \\
     -d '{{
       "url": "https://dantri.com.vn",
       "max_articles": 10,
       "language": "vi"
     }}'</div>
                </div>

                <h3>4. Phân tích RSS Feed:</h3>
                <div class="curl-example">
                    <button class="copy-btn" onclick="copyToClipboard('feed-curl')">Copy</button>
                    <div id="feed-curl">curl -X POST "https://{domain}/parse-feed" \\
     -H "Content-Type: application/json" \\
     -H "Authorization: Bearer {token}" \\
     -d '{{
       "url": "https://dantri.com.vn/rss.xml",
       "max_articles": 10
     }}'</div>
                </div>
            </div>

            <div class="grid">
                <div class="card">
                    <h2>📚 Documentation</h2>
                    <p>Xem tài liệu API chi tiết:</p>
                    <ul style="margin-top: 10px;">
                        <li><a href="/docs" target="_blank">Swagger UI</a></li>
                        <li><a href="/redoc" target="_blank">ReDoc</a></li>
                    </ul>
                </div>

                <div class="card">
                    <h2>🔧 Đổi Bearer Token</h2>
                    <p>Để đổi Bearer Token:</p>
                    <div class="curl-example">
                        <div>cd /home/n8n && \\
sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN="NEW_TOKEN"/' docker-compose.yml && \\
docker-compose restart fastapi</div>
                    </div>
                </div>
            </div>

            <div class="footer">
                <p>🚀 Made with ❤️ by Nguyễn Ngọc Thiện</p>
                <p>📺 <a href="https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1" style="color: #ffd700;">Subscribe YouTube Channel</a></p>
            </div>
        </div>

        <script>
            function copyToClipboard(elementId) {{
                const element = document.getElementById(elementId);
                const text = element.textContent;
                navigator.clipboard.writeText(text).then(function() {{
                    const btn = element.parentElement.querySelector('.copy-btn');
                    const originalText = btn.textContent;
                    btn.textContent = 'Copied!';
                    btn.style.background = '#48bb78';
                    setTimeout(() => {{
                        btn.textContent = originalText;
                        btn.style.background = '#667eea';
                    }}, 2000);
                }});
            }}
        </script>
    </body>
    </html>
    '''
    return html_content

@app.get("/health")
async def health_check(token: str = Depends(verify_token)):
    return {{
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "version": "2.0.0",
        "message": "News Content API đang hoạt động bình thường"
    }}

@app.post("/extract-article", response_model=ArticleResponse)
async def extract_article(request: ArticleRequest, token: str = Depends(verify_token)):
    try:
        article = Article(str(request.url), language=request.language)
        article.download()
        article.parse()
        
        if request.summarize:
            article.nlp()
        
        # Tính thời gian đọc (giả sử 200 từ/phút)
        word_count = len(article.text.split())
        read_time = max(1, round(word_count / 200))
        
        return ArticleResponse(
            title=article.title or "Không có tiêu đề",
            content=article.text or "Không thể lấy nội dung",
            summary=article.summary if request.summarize else None,
            authors=article.authors or [],
            publish_date=article.publish_date.isoformat() if article.publish_date else None,
            images=list(article.images) if request.extract_images else [],
            url=str(request.url),
            word_count=word_count,
            read_time_minutes=read_time
        )
    except Exception as e:
        logger.error(f"Lỗi khi xử lý bài viết {{request.url}}: {{str(e)}}")
        raise HTTPException(status_code=400, detail=f"Không thể xử lý bài viết: {{str(e)}}")

@app.post("/extract-source", response_model=SourceResponse)
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
                
                articles.append(ArticleResponse(
                    title=article.title or "Không có tiêu đề",
                    content=article.text or "Không thể lấy nội dung",
                    authors=article.authors or [],
                    publish_date=article.publish_date.isoformat() if article.publish_date else None,
                    images=list(article.images),
                    url=article_url,
                    word_count=word_count,
                    read_time_minutes=read_time
                ))
            except Exception as e:
                logger.warning(f"Bỏ qua bài viết {{article_url}}: {{str(e)}}")
                continue
        
        return SourceResponse(
            articles=articles,
            total_found=len(articles)
        )
    except Exception as e:
        logger.error(f"Lỗi khi xử lý nguồn {{request.url}}: {{str(e)}}")
        raise HTTPException(status_code=400, detail=f"Không thể xử lý nguồn: {{str(e)}}")

@app.post("/parse-feed", response_model=FeedResponse)
async def parse_feed(request: FeedRequest, token: str = Depends(verify_token)):
    try:
        feed = feedparser.parse(str(request.url))
        
        articles = []
        for entry in feed.entries[:request.max_articles]:
            article_data = {{
                "title": entry.get("title", "Không có tiêu đề"),
                "link": entry.get("link", ""),
                "description": entry.get("description", ""),
                "published": entry.get("published", ""),
                "author": entry.get("author", ""),
                "tags": [tag.term for tag in entry.get("tags", [])],
                "summary": entry.get("summary", "")
            }}
            articles.append(article_data)
        
        return FeedResponse(
            articles=articles,
            total_found=len(articles),
            feed_title=feed.feed.get("title", "Không có tiêu đề"),
            feed_description=feed.feed.get("description", "Không có mô tả")
        )
    except Exception as e:
        logger.error(f"Lỗi khi phân tích feed {{request.url}}: {{str(e)}}")
        raise HTTPException(status_code=400, detail=f"Không thể phân tích feed: {{str(e)}}")

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
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements và cài đặt Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose port
EXPOSE 8000

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

    echo "✅ Đã tạo News API thành công!"
fi

# Tạo file docker-compose.yml
echo "🔄 Tạo file docker-compose.yml..."
if [[ "$INSTALL_FASTAPI" =~ ^[Yy]$ ]]; then
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
      - API_DOMAIN=${API_DOMAIN}
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

    echo "🔑 Bearer Token cho News API: $BEARER_TOKEN"
    echo "📝 Lưu token này để sử dụng API!"
    
    # Lưu token vào file
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

# Tạo file Caddyfile với SSL cải tiến
echo "🔄 Tạo file Caddyfile..."
if [[ "$INSTALL_FASTAPI" =~ ^[Yy]$ ]]; then
    cat << EOF > $N8N_DIR/Caddyfile
${DOMAIN} {
    reverse_proxy n8n:5678
    tls {
        protocols tls1.2 tls1.3
    }
    header {
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
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
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
    header {
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
read -p "📱 Bạn có muốn cấu hình gửi file backup hàng ngày qua Telegram không? (y/n): " CONFIGURE_TELEGRAM
if [[ "$CONFIGURE_TELEGRAM" =~ ^[Yy]$ ]]; then
    echo "📱 Để gửi backup qua Telegram, bạn cần Bot Token và Chat ID."
    echo "🤖 Hướng dẫn lấy Bot Token: Tìm @BotFather trên Telegram, gõ /newbot"
    echo "🆔 Hướng dẫn lấy Chat ID: Tìm @userinfobot trên Telegram, gõ /start"
    read -p "🔑 Nhập Telegram Bot Token: " TELEGRAM_BOT_TOKEN
    read -p "🆔 Nhập Telegram Chat ID: " TELEGRAM_CHAT_ID
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        echo "TELEGRAM_BOT_TOKEN=\"$TELEGRAM_BOT_TOKEN\"" > "$TELEGRAM_CONF_FILE"
        echo "TELEGRAM_CHAT_ID=\"$TELEGRAM_CHAT_ID\"" >> "$TELEGRAM_CONF_FILE"
        chmod 600 "$TELEGRAM_CONF_FILE"
        echo "✅ Đã lưu cấu hình Telegram vào $TELEGRAM_CONF_FILE"
    else
        echo "❌ Bot Token hoặc Chat ID không được cung cấp. Bỏ qua cấu hình Telegram."
    fi
else
    echo "⏭️ Đã bỏ qua cấu hình gửi backup qua Telegram."
    if [ -f "$TELEGRAM_CONF_FILE" ]; then
        rm -f "$TELEGRAM_CONF_FILE"
    fi
fi

# Hỏi về tự động cập nhật
read -p "🔄 Bạn có muốn bật tính năng tự động cập nhật N8N không? (y/n): " AUTO_UPDATE
if [[ "$AUTO_UPDATE" =~ ^[Nn]$ ]]; then
    AUTO_UPDATE_ENABLED=false
else
    AUTO_UPDATE_ENABLED=true
fi

# Tạo script sao lưu workflow và credentials với fix lỗi
echo "🔄 Tạo script sao lưu workflow và credentials tại $N8N_DIR/backup-workflows.sh..."
cat << EOF > $N8N_DIR/backup-workflows.sh
#!/bin/bash

# Định nghĩa các biến
N8N_DIR_VALUE="$N8N_DIR"
BACKUP_BASE_DIR="\${N8N_DIR_VALUE}/files/backup_full"
LOG_FILE="\${N8N_DIR_VALUE}/files/backup_full/backup.log"
TELEGRAM_CONF_FILE="\${N8N_DIR_VALUE}/telegram_config.txt"
DATE="\$(date +"%Y%m%d_%H%M%S")"
BACKUP_FILE_NAME="n8n_backup_\${DATE}.tar.gz"
BACKUP_FILE_PATH="\${BACKUP_BASE_DIR}/\${BACKUP_FILE_NAME}"
TEMP_DIR_HOST="/tmp/n8n_backup_host_\${DATE}"
TEMP_DIR_CONTAINER_BASE="/tmp/n8n_workflow_exports"
TELEGRAM_FILE_SIZE_LIMIT=20971520 # 20MB

# Hàm logging
log() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" | tee -a "\${LOG_FILE}"
}

# Hàm gửi tin nhắn Telegram
send_telegram_message() {
    local message="\$1"
    if [ -f "\${TELEGRAM_CONF_FILE}" ]; then
        source "\${TELEGRAM_CONF_FILE}"
        if [ -n "\${TELEGRAM_BOT_TOKEN}" ] && [ -n "\${TELEGRAM_CHAT_ID}" ]; then
            (curl -s -X POST "https://api.telegram.org/bot\${TELEGRAM_BOT_TOKEN}/sendMessage" \\
                -d chat_id="\${TELEGRAM_CHAT_ID}" \\
                -d text="\${message}" \\
                -d parse_mode="Markdown" > /dev/null 2>&1) &
        fi
    fi
}

# Hàm gửi file qua Telegram
send_telegram_document() {
    local file_path="\$1"
    local caption="\$2"
    if [ -f "\${TELEGRAM_CONF_FILE}" ]; then
        source "\${TELEGRAM_CONF_FILE}"
        if [ -n "\${TELEGRAM_BOT_TOKEN}" ] && [ -n "\${TELEGRAM_CHAT_ID}" ]; then
            local file_size="\$(du -b "\${file_path}" | cut -f1)"
            if [ "\${file_size}" -le "\${TELEGRAM_FILE_SIZE_LIMIT}" ]; then
                log "Đang gửi file backup qua Telegram: \${file_path}"
                (curl -s -X POST "https://api.telegram.org/bot\${TELEGRAM_BOT_TOKEN}/sendDocument" \\
                    -F chat_id="\${TELEGRAM_CHAT_ID}" \\
                    -F document=@"\${file_path}" \\
                    -F caption="\${caption}" > /dev/null 2>&1) &
            else
                local readable_size="\$(echo "scale=2; \${file_size} / 1024 / 1024" | bc)"
                log "File backup quá lớn (\${readable_size} MB) để gửi qua Telegram."
                send_telegram_message "Hoàn tất sao lưu N8N. File backup '\${BACKUP_FILE_NAME}' (\${readable_size}MB) quá lớn để gửi. Nó được lưu tại: \${file_path} trên server."
            fi
        fi
    fi
}

# Tạo thư mục backup nếu chưa có
mkdir -p "\${BACKUP_BASE_DIR}"

log "Bắt đầu sao lưu workflows và credentials..."
send_telegram_message "🔄 Bắt đầu quá trình sao lưu N8N hàng ngày cho domain: $DOMAIN..."

# Tìm container N8N
N8N_CONTAINER_ID="\$(docker ps -q --filter "name=n8n" --format '{{.ID}}' | head -n 1)"

if [ -z "\${N8N_CONTAINER_ID}" ]; then
    log "Lỗi: Không tìm thấy container n8n đang chạy."
    send_telegram_message "❌ Lỗi sao lưu N8N ($DOMAIN): Không tìm thấy container n8n đang chạy."
    exit 1
fi

log "Tìm thấy container N8N ID: \${N8N_CONTAINER_ID}"

# Tạo thư mục tạm
mkdir -p "\${TEMP_DIR_HOST}/workflows"
mkdir -p "\${TEMP_DIR_HOST}/credentials"

# Tạo thư mục export trong container
TEMP_DIR_CONTAINER_UNIQUE="\${TEMP_DIR_CONTAINER_BASE}/export_\${DATE}"
docker exec "\${N8N_CONTAINER_ID}" mkdir -p "\${TEMP_DIR_CONTAINER_UNIQUE}"

log "Xuất workflows vào \${TEMP_DIR_CONTAINER_UNIQUE} trong container..."
WORKFLOWS_JSON="\$(docker exec "\${N8N_CONTAINER_ID}" n8n list:workflow --json 2>/dev/null || echo "[]")"

if [ -z "\${WORKFLOWS_JSON}" ] || [ "\${WORKFLOWS_JSON}" == "[]" ]; then
    log "Cảnh báo: Không tìm thấy workflow nào để sao lưu."
else
    echo "\${WORKFLOWS_JSON}" | jq -c '.[]' 2>/dev/null | while IFS= read -r workflow; do
        id="\$(echo "\${workflow}" | jq -r '.id' 2>/dev/null || echo "")"
        name="\$(echo "\${workflow}" | jq -r '.name' 2>/dev/null | tr -dc '[:alnum:][:space:]_-' | tr '[:space:]' '_')"
        safe_name="\$(echo "\${name}" | sed 's/[^a-zA-Z0-9_-]/_/g' | cut -c1-100)"
        
        if [ -n "\${id}" ] && [ "\${id}" != "null" ]; then
            output_file_container="\${TEMP_DIR_CONTAINER_UNIQUE}/\${id}-\${safe_name}.json"
            log "Đang xuất workflow: '\${name}' (ID: \${id})"
            if docker exec "\${N8N_CONTAINER_ID}" n8n export:workflow --id="\${id}" --output="\${output_file_container}" 2>/dev/null; then
                log "Đã xuất workflow ID \${id} thành công."
            else
                log "Lỗi khi xuất workflow ID \${id}."
            fi
        fi
    done

    log "Sao chép workflows từ container ra host"
    if docker cp "\${N8N_CONTAINER_ID}:\${TEMP_DIR_CONTAINER_UNIQUE}/." "\${TEMP_DIR_HOST}/workflows/" 2>/dev/null; then
        log "Sao chép workflows thành công."
    else
        log "Lỗi khi sao chép workflows."
    fi
fi

# Backup database và encryption key
DB_PATH_HOST="\${N8N_DIR_VALUE}/database.sqlite"
KEY_PATH_HOST="\${N8N_DIR_VALUE}/encryptionKey"

log "Sao lưu database và encryption key..."
if [ -f "\${DB_PATH_HOST}" ]; then
    cp "\${DB_PATH_HOST}" "\${TEMP_DIR_HOST}/credentials/database.sqlite"
    log "Đã sao lưu database.sqlite"
else
    log "Cảnh báo: Không tìm thấy file database.sqlite tại \${DB_PATH_HOST}"
fi

if [ -f "\${KEY_PATH_HOST}" ]; then
    cp "\${KEY_PATH_HOST}" "\${TEMP_DIR_HOST}/credentials/encryptionKey"
    log "Đã sao lưu encryptionKey"
else
    log "Cảnh báo: Không tìm thấy file encryptionKey tại \${KEY_PATH_HOST}"
fi

# Tạo metadata
cat << METADATA_EOF > "\${TEMP_DIR_HOST}/backup_metadata.json"
{
    "backup_date": "\$(date -Iseconds)",
    "domain": "$DOMAIN",
    "n8n_version": "\$(docker exec "\${N8N_CONTAINER_ID}" n8n --version 2>/dev/null || echo "unknown")",
    "backup_type": "full",
    "created_by": "auto_backup_script"
}
METADATA_EOF

log "Tạo file nén tar.gz: \${BACKUP_FILE_PATH}"
if tar -czf "\${BACKUP_FILE_PATH}" -C "\${TEMP_DIR_HOST}" . 2>/dev/null; then
    log "Tạo file backup \${BACKUP_FILE_PATH} thành công."
    send_telegram_document "\${BACKUP_FILE_PATH}" "✅ Sao lưu N8N ($DOMAIN) hàng ngày hoàn tất: \${BACKUP_FILE_NAME}"
else
    log "Lỗi: Không thể tạo file backup \${BACKUP_FILE_PATH}."
    send_telegram_message "❌ Lỗi sao lưu N8N ($DOMAIN): Không thể tạo file backup. Kiểm tra log tại \${LOG_FILE}"
fi

# Dọn dẹp
log "Dọn dẹp thư mục tạm..."
rm -rf "\${TEMP_DIR_HOST}"
docker exec "\${N8N_CONTAINER_ID}" rm -rf "\${TEMP_DIR_CONTAINER_UNIQUE}" 2>/dev/null || true

# Giữ lại 30 bản backup gần nhất
log "Giữ lại 30 bản sao lưu gần nhất..."
find "\${BACKUP_BASE_DIR}" -maxdepth 1 -name 'n8n_backup_*.tar.gz' -type f -printf '%T@ %p\\n' 2>/dev/null | \\
sort -nr | tail -n +31 | cut -d' ' -f2- | xargs -r rm -f

log "Sao lưu hoàn tất: \${BACKUP_FILE_PATH}"
if [ -f "\${BACKUP_FILE_PATH}" ]; then
    send_telegram_message "✅ Hoàn tất sao lưu N8N ($DOMAIN). File: \${BACKUP_FILE_NAME}"
else
    send_telegram_message "❌ Sao lưu N8N ($DOMAIN) thất bại. Kiểm tra log tại \${LOG_FILE}"
fi

exit 0
EOF

# Tạo script backup thủ công để test
echo "🔄 Tạo script backup thủ công tại $N8N_DIR/backup-manual.sh..."
cat << EOF > $N8N_DIR/backup-manual.sh
#!/bin/bash
echo "🧪 Chạy backup thủ công để kiểm tra..."
echo "📁 Thư mục backup: $N8N_DIR/files/backup_full/"
echo "📋 Log file: $N8N_DIR/files/backup_full/backup.log"
echo ""
$N8N_DIR/backup-workflows.sh
echo ""
echo "✅ Hoàn tất backup thủ công!"
echo "📂 Kiểm tra file backup tại: $N8N_DIR/files/backup_full/"
ls -la $N8N_DIR/files/backup_full/*.tar.gz 2>/dev/null || echo "Chưa có file backup nào."
EOF

# Tạo script chẩn đoán
echo "🔄 Tạo script chẩn đoán tại $N8N_DIR/troubleshoot.sh..."
cat << EOF > $N8N_DIR/troubleshoot.sh
#!/bin/bash
echo "🔍 SCRIPT CHẨN ĐOÁN N8N"
echo "======================================================================"
echo "📅 Thời gian: \$(date)"
echo "🌐 Domain: $DOMAIN"
if [[ "$INSTALL_FASTAPI" =~ ^[Yy]$ ]]; then
echo "📰 API Domain: $API_DOMAIN"
fi
echo "📁 Thư mục N8N: $N8N_DIR"
echo ""

echo "🐳 DOCKER STATUS:"
echo "Docker version: \$(docker --version)"
echo "Docker Compose: \$(docker-compose --version 2>/dev/null || docker compose version 2>/dev/null)"
echo ""

echo "📦 CONTAINERS:"
cd $N8N_DIR
docker-compose ps
echo ""

echo "🔗 NETWORK CONNECTIVITY:"
echo "Server IP: \$(curl -s https://api.ipify.org)"
echo "Domain $DOMAIN resolves to: \$(dig +short $DOMAIN A)"
if [[ "$INSTALL_FASTAPI" =~ ^[Yy]$ ]]; then
echo "API Domain $API_DOMAIN resolves to: \$(dig +short $API_DOMAIN A)"
fi
echo ""

echo "🔒 SSL CERTIFICATES:"
echo "Checking $DOMAIN SSL..."
curl -I https://$DOMAIN 2>/dev/null | head -n 1 || echo "❌ SSL check failed for $DOMAIN"
if [[ "$INSTALL_FASTAPI" =~ ^[Yy]$ ]]; then
echo "Checking $API_DOMAIN SSL..."
curl -I https://$API_DOMAIN 2>/dev/null | head -n 1 || echo "❌ SSL check failed for $API_DOMAIN"
fi
echo ""

echo "💾 DISK USAGE:"
df -h $N8N_DIR
echo ""

echo "📋 RECENT LOGS (last 20 lines):"
echo "--- N8N Logs ---"
docker-compose logs --tail=20 n8n 2>/dev/null || echo "No N8N logs available"
echo ""
echo "--- Caddy Logs ---"
docker-compose logs --tail=20 caddy 2>/dev/null || echo "No Caddy logs available"
if [[ "$INSTALL_FASTAPI" =~ ^[Yy]$ ]]; then
echo ""
echo "--- FastAPI Logs ---"
docker-compose logs --tail=20 fastapi 2>/dev/null || echo "No FastAPI logs available"
fi
echo ""

echo "🔄 BACKUP STATUS:"
if [ -f "$N8N_DIR/files/backup_full/backup.log" ]; then
    echo "Last backup log entries:"
    tail -n 10 "$N8N_DIR/files/backup_full/backup.log"
else
    echo "No backup log found"
fi
echo ""

echo "📊 SYSTEM RESOURCES:"
echo "Memory usage:"
free -h
echo ""
echo "CPU usage:"
top -bn1 | grep "Cpu(s)" || echo "CPU info not available"
echo ""

echo "✅ Chẩn đoán hoàn tất!"
echo "======================================================================"
EOF

# Đặt quyền thực thi cho các script
chmod +x $N8N_DIR/backup-workflows.sh
chmod +x $N8N_DIR/backup-manual.sh
chmod +x $N8N_DIR/troubleshoot.sh

# Đặt quyền cho thư mục n8n
echo "🔄 Đặt quyền cho thư mục n8n tại $N8N_DIR..."
chown -R 1000:1000 $N8N_DIR 
chmod -R u+rwX,g+rX,o+rX $N8N_DIR
chown -R 1000:1000 $N8N_DIR/files
chmod -R u+rwX,g+rX,o+rX $N8N_DIR/files

# Khởi động các container
echo "🔄 Khởi động các container... Quá trình build image có thể mất vài phút..."
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
    
    # Tạo Dockerfile đơn giản hơn
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
    echo "✅ Build thành công với cấu hình đơn giản."
fi

echo "🚀 Đang khởi động các container..."
if ! $DOCKER_COMPOSE_CMD up -d; then
    echo "❌ Lỗi: Khởi động container thất bại."
    echo "🔍 Kiểm tra logs: $DOCKER_COMPOSE_CMD logs"
    exit 1
fi

echo "⏳ Đợi các container khởi động và SSL được cấp (60 giây)..."
sleep 60

# Kiểm tra trạng thái containers
echo "🔍 Kiểm tra trạng thái các container..."
if $DOCKER_COMPOSE_CMD ps | grep -q "n8n"; then
    echo "✅ Container n8n đã chạy thành công."
else
    echo "⚠️ Cảnh báo: Container n8n có thể chưa chạy. Kiểm tra: $DOCKER_COMPOSE_CMD logs n8n"
fi

if $DOCKER_COMPOSE_CMD ps | grep -q "caddy"; then
    echo "✅ Container caddy đã chạy thành công."
else
    echo "⚠️ Cảnh báo: Container caddy có thể chưa chạy. Kiểm tra: $DOCKER_COMPOSE_CMD logs caddy"
fi

if [[ "$INSTALL_FASTAPI" =~ ^[Yy]$ ]] && $DOCKER_COMPOSE_CMD ps | grep -q "fastapi"; then
    echo "✅ Container fastapi đã chạy thành công."
elif [[ "$INSTALL_FASTAPI" =~ ^[Yy]$ ]]; then
    echo "⚠️ Cảnh báo: Container fastapi có thể chưa chạy. Kiểm tra: $DOCKER_COMPOSE_CMD logs fastapi"
fi

# Kiểm tra SSL
echo "🔒 Kiểm tra SSL certificate..."
if curl -I https://$DOMAIN 2>/dev/null | grep -q "200 OK"; then
    echo "✅ SSL cho $DOMAIN hoạt động bình thường."
else
    echo "⚠️ Cảnh báo: SSL cho $DOMAIN có thể chưa sẵn sàng. Đợi thêm vài phút."
fi

if [[ "$INSTALL_FASTAPI" =~ ^[Yy]$ ]]; then
    if curl -I https://$API_DOMAIN 2>/dev/null | grep -q "200 OK"; then
        echo "✅ SSL cho $API_DOMAIN hoạt động bình thường."
    else
        echo "⚠️ Cảnh báo: SSL cho $API_DOMAIN có thể chưa sẵn sàng. Đợi thêm vài phút."
    fi
fi

# Tạo script cập nhật tự động
if [ "$AUTO_UPDATE_ENABLED" = true ]; then
    echo "🔄 Tạo script cập nhật tự động tại $N8N_DIR/update-n8n.sh..."
    cat << EOF > $N8N_DIR/update-n8n.sh
#!/bin/bash
N8N_DIR_VALUE="$N8N_DIR"
LOG_FILE="\$N8N_DIR_VALUE/update.log"

log() { 
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" >> "\$LOG_FILE"
}

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
    pipx upgrade yt-dlp
elif [ -d "/opt/yt-dlp-venv" ]; then 
    /opt/yt-dlp-venv/bin/pip install -U yt-dlp
fi

log "Kéo image n8nio/n8n mới nhất..."
docker pull n8nio/n8n:latest

CURRENT_CUSTOM_IMAGE_ID="\$(docker images -q n8n-custom-ffmpeg:latest)"
log "Build lại image custom n8n..."
if ! \$DOCKER_COMPOSE build n8n; then 
    log "Lỗi build image custom."
    exit 1
fi

NEW_CUSTOM_IMAGE_ID="\$(docker images -q n8n-custom-ffmpeg:latest)"
if [ "\$CURRENT_CUSTOM_IMAGE_ID" != "\$NEW_CUSTOM_IMAGE_ID" ]; then
    log "Phát hiện image mới, tiến hành cập nhật n8n..."
    log "Chạy backup trước khi cập nhật..."
    if [ -x "\$N8N_DIR_VALUE/backup-workflows.sh" ]; then
        "\$N8N_DIR_VALUE/backup-workflows.sh"
    fi
    log "Dừng và khởi động lại containers..."
    \$DOCKER_COMPOSE down
    \$DOCKER_COMPOSE up -d
    log "Cập nhật n8n hoàn tất."
else
    log "Không có cập nhật mới cho image n8n custom."
fi

log "Cập nhật yt-dlp trong container n8n..."
N8N_CONTAINER_FOR_UPDATE="\$(docker ps -q --filter name=n8n)"
if [ -n "\$N8N_CONTAINER_FOR_UPDATE" ]; then
    docker exec -u root \$N8N_CONTAINER_FOR_UPDATE pip3 install --break-system-packages -U yt-dlp
    log "yt-dlp trong container đã được cập nhật."
else
    log "Không tìm thấy container n8n đang chạy."
fi

log "Kiểm tra cập nhật hoàn tất."
EOF
    chmod +x $N8N_DIR/update-n8n.sh
fi

# Thiết lập cron jobs
CRON_USER=$(whoami)
if [ "$AUTO_UPDATE_ENABLED" = true ]; then
    UPDATE_CRON="0 */12 * * * $N8N_DIR/update-n8n.sh"
    BACKUP_CRON="0 2 * * * $N8N_DIR/backup-workflows.sh"
    (crontab -u $CRON_USER -l 2>/dev/null | grep -v "update-n8n.sh" | grep -v "backup-workflows.sh"; echo "$UPDATE_CRON"; echo "$BACKUP_CRON") | crontab -u $CRON_USER -
    echo "✅ Đã thiết lập cron job cập nhật tự động mỗi 12 giờ và sao lưu hàng ngày lúc 2:00 AM."
else
    BACKUP_CRON="0 2 * * * $N8N_DIR/backup-workflows.sh"
    (crontab -u $CRON_USER -l 2>/dev/null | grep -v "update-n8n.sh" | grep -v "backup-workflows.sh"; echo "$BACKUP_CRON") | crontab -u $CRON_USER -
    echo "✅ Đã thiết lập cron job sao lưu hàng ngày lúc 2:00 AM."
fi

echo "======================================================================"
echo "🎉 N8N ĐÃ ĐƯỢC CÀI ĐẶT THÀNH CÔNG!"
echo "======================================================================"
echo "🌐 Truy cập N8N: https://${DOMAIN}"
if [[ "$INSTALL_FASTAPI" =~ ^[Yy]$ ]]; then
echo "📰 Truy cập News API: https://${API_DOMAIN}"
echo "📚 API Documentation: https://${API_DOMAIN}/docs"
echo "🔑 Bearer Token: $BEARER_TOKEN"
fi
echo ""
echo "📁 Thư mục cài đặt: $N8N_DIR"
echo "🔧 Script chẩn đoán: $N8N_DIR/troubleshoot.sh"
echo "🧪 Test backup: $N8N_DIR/backup-manual.sh"
echo ""
if [ "$(swapon --show | wc -l)" -gt 0 ]; then
    SWAP_INFO=$(free -h | grep Swap | awk '{print $2}')
    echo "💾 Swap: $SWAP_INFO"
fi
echo "🔄 Auto-update: $([ "$AUTO_UPDATE_ENABLED" = true ] && echo "Enabled (mỗi 12h)" || echo "Disabled")"
echo "📱 Telegram backup: $([ -f "$TELEGRAM_CONF_FILE" ] && echo "Enabled" || echo "Disabled")"
echo "💾 Backup tự động: Hàng ngày lúc 2:00 AM"
echo "📂 Backup location: $N8N_DIR/files/backup_full/"
echo ""
echo "🚀 Tác giả: Nguyễn Ngọc Thiện"
echo "📺 YouTube: https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1"
echo "📱 Zalo: 08.8888.4749"
echo "======================================================================"
