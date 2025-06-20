#!/bin/bash

# Hiển thị banner
echo "======================================================================"
echo "     Script cài đặt N8N với FFmpeg, yt-dlp, Puppeteer, FastAPI và SSL tự động  "
echo "======================================================================"

# Kiểm tra xem script có được chạy với quyền root không
if [[ $EUID -ne 0 ]]; then
   echo "Script này cần được chạy với quyền root" 
   exit 1
fi

# Biến để lưu trạng thái cài đặt
INSTALL_ISSUES=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
FASTAPI_PASSWORD=""
SETUP_TELEGRAM=false
SETUP_FASTAPI=false
API_DOMAIN=""

# Hàm thiết lập swap tự động
setup_swap() {
    echo "Kiểm tra và thiết lập swap tự động..."
    
    # Kiểm tra nếu swap đã được bật
    if [ "$(swapon --show | wc -l)" -gt 0 ]; then
        SWAP_SIZE=$(free -h | grep Swap | awk '{print $2}')
        echo "Swap đã được bật với kích thước ${SWAP_SIZE}. Bỏ qua thiết lập."
        return
    fi
    
    # Lấy thông tin RAM (đơn vị MB)
    RAM_MB=$(free -m | grep Mem | awk '{print $2}')
    
    # Tính toán kích thước swap dựa trên RAM
    if [ "$RAM_MB" -le 2048 ]; then
        # Với RAM <= 2GB, swap = 2x RAM
        SWAP_SIZE=$((RAM_MB * 2))
    elif [ "$RAM_MB" -gt 2048 ] && [ "$RAM_MB" -le 8192 ]; then
        # Với 2GB < RAM <= 8GB, swap = RAM
        SWAP_SIZE=$RAM_MB
    else
        # Với RAM > 8GB, swap = 4GB
        SWAP_SIZE=4096
    fi
    
    # Chuyển đổi sang GB cho dễ nhìn (làm tròn lên)
    SWAP_GB=$(( (SWAP_SIZE + 1023) / 1024 ))
    
    echo "Đang thiết lập swap với kích thước ${SWAP_GB}GB (${SWAP_SIZE}MB)..."
    
    # Tạo swap file với đơn vị MB
    dd if=/dev/zero of=/swapfile bs=1M count=$SWAP_SIZE status=progress
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    
    # Thêm vào fstab để swap được kích hoạt sau khi khởi động lại
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    
    # Cấu hình swappiness và cache pressure
    sysctl vm.swappiness=10
    sysctl vm.vfs_cache_pressure=50
    
    # Lưu cấu hình vào sysctl.conf nếu chưa có
    if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
        echo "vm.swappiness=10" >> /etc/sysctl.conf
    fi
    
    if ! grep -q "vm.vfs_cache_pressure" /etc/sysctl.conf; then
        echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
    fi
    
    echo "Đã thiết lập swap với kích thước ${SWAP_GB}GB thành công."
    echo "Swappiness đã được đặt thành 10 (mặc định: 60)"
    echo "Vfs_cache_pressure đã được đặt thành 50 (mặc định: 100)"
}

# Hàm hiển thị trợ giúp
show_help() {
    echo "Cách sử dụng: $0 [tùy chọn]"
    echo "Tùy chọn:"
    echo "  -h, --help      Hiển thị trợ giúp này"
    echo "  -d, --dir DIR   Chỉ định thư mục cài đặt n8n (mặc định: /home/n8n)"
    echo "  -s, --skip-docker Bỏ qua cài đặt Docker (nếu đã có)"
    exit 0
}

# Xử lý tham số dòng lệnh
N8N_DIR="/home/n8n"
SKIP_DOCKER=false

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
        *)
            echo "Tùy chọn không hợp lệ: $1"
            show_help
            ;;
    esac
done

# Hàm kiểm tra domain
check_domain() {
    local domain=$1
    local server_ip=$(curl -s https://api.ipify.org)
    local domain_ip=$(dig +short $domain)

    if [ "$domain_ip" = "$server_ip" ]; then
        return 0  # Domain đã trỏ đúng
    else
        return 1  # Domain chưa trỏ đúng
    fi
}

# Hàm kiểm tra các lệnh cần thiết
check_commands() {
    if ! command -v dig &> /dev/null; then
        echo "Cài đặt dnsutils (để sử dụng lệnh dig)..."
        apt-get update
        apt-get install -y dnsutils
    fi
}

# Hàm thiết lập Telegram backup
setup_telegram_backup() {
    echo ""
    echo "======================================================================"
    echo "  CẤU HÌNH GỬI BACKUP TỰ ĐỘNG QUA TELEGRAM"
    echo "======================================================================"
    echo ""
    read -p "Bạn có muốn thiết lập gửi backup tự động qua Telegram không? (y/n): " setup_tg
    
    if [[ $setup_tg =~ ^[Yy]$ ]]; then
        SETUP_TELEGRAM=true
        echo ""
        echo "Để thiết lập Telegram backup, bạn cần:"
        echo "1. Tạo bot Telegram bằng cách nhắn tin cho @BotFather"
        echo "2. Lấy Bot Token từ @BotFather"
        echo "3. Lấy Chat ID của bạn bằng cách nhắn tin cho bot @userinfobot"
        echo ""
        read -p "Nhập Bot Token: " TELEGRAM_BOT_TOKEN
        read -p "Nhập Chat ID: " TELEGRAM_CHAT_ID
        
        # Kiểm tra token và chat ID
        echo "Đang kiểm tra kết nối Telegram..."
        test_response=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d chat_id="${TELEGRAM_CHAT_ID}" \
            -d text="🎉 Thiết lập backup N8N qua Telegram thành công!")
        
        if echo "$test_response" | grep -q '"ok":true'; then
            echo "✅ Kết nối Telegram thành công!"
        else
            echo "❌ Lỗi kết nối Telegram. Vui lòng kiểm tra lại Token và Chat ID."
            SETUP_TELEGRAM=false
            INSTALL_ISSUES="$INSTALL_ISSUES\n- Thiết lập Telegram backup thất bại"
        fi
    else
        echo "Bỏ qua thiết lập Telegram backup."
    fi
}

# Hàm thiết lập FastAPI cho crawl bài viết
setup_fastapi_crawler() {
    echo ""
    echo "======================================================================"
    echo "  CẤU HÌNH API CRAWL BÀI VIẾT VỚI FASTAPI"
    echo "======================================================================"
    echo ""
    read -p "Bạn có muốn thiết lập API riêng để lấy nội dung bài viết không? (y/n): " setup_api
    
    if [[ $setup_api =~ ^[Yy]$ ]]; then
        SETUP_FASTAPI=true
        echo ""
        echo "API này sẽ cho phép bạn crawl nội dung từ các trang web báo."
        
        # Hỏi về subdomain cho API
        read -p "Nhập subdomain cho API (ví dụ: api.yourdomain.com): " API_DOMAIN
        
        # Kiểm tra API domain
        echo "Kiểm tra API domain $API_DOMAIN..."
        if check_domain $API_DOMAIN; then
            echo "✅ API Domain $API_DOMAIN đã được trỏ đúng đến server này."
        else
            echo "⚠️ API Domain $API_DOMAIN chưa được trỏ đến server này."
            echo "📍 Vui lòng tạo bản ghi DNS: $API_DOMAIN → $(curl -s https://api.ipify.org)"
            echo "💡 Bạn có thể tiếp tục cài đặt và cấu hình DNS sau."
        fi
        
        read -p "Nhập mật khẩu Bearer token cho API: " FASTAPI_PASSWORD
        echo "✅ API sẽ được triển khai tại: https://${API_DOMAIN}"
        echo "📖 Documentation: https://${API_DOMAIN}/docs"
    else
        echo "Bỏ qua thiết lập FastAPI crawler."
    fi
}

# Thiết lập swap
setup_swap

# Cài đặt các gói cần thiết
echo "Đang cài đặt các công cụ cần thiết..."
apt-get update
apt-get install -y dnsutils curl cron jq tar gzip python3-full python3-venv python3-pip pipx net-tools

# Cài đặt yt-dlp thông qua pipx hoặc virtual environment
echo "Cài đặt yt-dlp..."
if command -v pipx &> /dev/null; then
    pipx install yt-dlp
else
    # Tạo virtual environment và cài đặt yt-dlp vào đó
    python3 -m venv /opt/yt-dlp-venv
    /opt/yt-dlp-venv/bin/pip install yt-dlp
    ln -sf /opt/yt-dlp-venv/bin/yt-dlp /usr/local/bin/yt-dlp
    chmod +x /usr/local/bin/yt-dlp
fi

# Kiểm tra các lệnh cần thiết
check_commands

# Nhận input domain và thiết lập cấu hình - UPDATED
echo ""
echo "======================================================================"
echo "  CẤU HÌNH DOMAIN"
echo "======================================================================"
echo ""
read -p "Nhập tên miền chính cho N8N (ví dụ: n8n.yourdomain.com): " DOMAIN

# Kiểm tra domain chính
echo "Kiểm tra domain $DOMAIN..."
if check_domain $DOMAIN; then
    echo "✅ Domain $DOMAIN đã được trỏ đúng đến server này."
else
    echo "❌ Domain $DOMAIN chưa được trỏ đến server này."
    echo "📍 IP server hiện tại: $(curl -s https://api.ipify.org)"
    echo "📍 IP domain đang trỏ: $(dig +short $DOMAIN | head -1)"
    echo ""
    echo "Vui lòng cập nhật bản ghi DNS để trỏ $DOMAIN đến IP $(curl -s https://api.ipify.org)"
    read -p "Bạn có muốn tiếp tục cài đặt không? (y/n): " continue_install
    if [[ ! $continue_install =~ ^[Yy]$ ]]; then
        echo "Thoát cài đặt. Vui lòng cấu hình DNS và chạy lại script."
        exit 1
    fi
fi

# Thiết lập Telegram backup
setup_telegram_backup

# Thiết lập FastAPI crawler với subdomain
setup_fastapi_crawler

# Cài đặt FastAPI và dependencies nếu được yêu cầu
if [ "$SETUP_FASTAPI" = true ]; then
    echo "Cài đặt FastAPI và các thư viện cần thiết..."
    
    # Tạo virtual environment cho FastAPI
    python3 -m venv /opt/fastapi-venv
    
    # Cài đặt các thư viện
    /opt/fastapi-venv/bin/pip install fastapi uvicorn newspaper4k requests python-multipart fake-useragent || {
        echo "❌ Lỗi cài đặt FastAPI dependencies"
        INSTALL_ISSUES="$INSTALL_ISSUES\n- FastAPI dependencies cài đặt thất bại"
        SETUP_FASTAPI=false
    }
fi

# Đảm bảo cron service đang chạy
systemctl enable cron
systemctl start cron

# Kiểm tra domain
echo "Kiểm tra domain $DOMAIN..."
if check_domain $DOMAIN; then
    echo "Domain $DOMAIN đã được trỏ đúng đến server này. Tiếp tục cài đặt"
else
    echo "Domain $DOMAIN chưa được trỏ đến server này."
    echo "Vui lòng cập nhật bản ghi DNS để trỏ $DOMAIN đến IP $(curl -s https://api.ipify.org)"
    echo "Sau khi cập nhật DNS, hãy chạy lại script này"
    exit 1
fi

# Hàm cài đặt Docker
install_docker() {
    if $SKIP_DOCKER; then
        echo "Bỏ qua cài đặt Docker theo yêu cầu..."
        return
    fi
    
    echo "Cài đặt Docker và Docker Compose..."
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    
    # Thêm khóa Docker GPG theo cách mới
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Thêm repository Docker
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Cài đặt Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Cài đặt Docker Compose
    if ! command -v docker-compose &> /dev/null && ! command -v docker &> /dev/null; then
        echo "Cài đặt Docker Compose..."
        apt-get install -y docker-compose
    elif command -v docker &> /dev/null && ! docker compose version &> /dev/null; then
        echo "Cài đặt Docker Compose plugin..."
        apt-get install -y docker-compose-plugin
    fi
    
    # Kiểm tra Docker đã cài đặt thành công chưa
    if ! command -v docker &> /dev/null; then
        echo "Lỗi: Docker chưa được cài đặt đúng cách."
        INSTALL_ISSUES="$INSTALL_ISSUES\n- Docker cài đặt thất bại"
        return 1
    fi

    if ! command -v docker-compose &> /dev/null && ! (command -v docker &> /dev/null && docker compose version &> /dev/null); then
        echo "Lỗi: Docker Compose chưa được cài đặt đúng cách."
        INSTALL_ISSUES="$INSTALL_ISSUES\n- Docker Compose cài đặt thất bại"
        return 1
    fi

    # Thêm user hiện tại vào nhóm docker nếu không phải root
    if [ "$SUDO_USER" != "" ]; then
        echo "Thêm user $SUDO_USER vào nhóm docker để có thể chạy docker mà không cần sudo..."
        usermod -aG docker $SUDO_USER
        echo "Đã thêm user $SUDO_USER vào nhóm docker. Các thay đổi sẽ có hiệu lực sau khi đăng nhập lại."
    fi

    # Khởi động lại dịch vụ Docker
    systemctl restart docker

    echo "Docker và Docker Compose đã được cài đặt thành công."
}

# Cài đặt Docker và Docker Compose
install_docker

# Tạo thư mục cho n8n
echo "Tạo cấu trúc thư mục cho n8n tại $N8N_DIR..."
mkdir -p $N8N_DIR
mkdir -p $N8N_DIR/files
mkdir -p $N8N_DIR/files/temp
mkdir -p $N8N_DIR/files/youtube_content_anylystic
mkdir -p $N8N_DIR/files/backup_full

# Tạo thư mục cho FastAPI nếu cần
if [ "$SETUP_FASTAPI" = true ]; then
    mkdir -p $N8N_DIR/fastapi
fi

# Tạo FastAPI app cho crawling nếu được yêu cầu
if [ "$SETUP_FASTAPI" = true ]; then
    echo "Tạo FastAPI app cho crawling bài viết..."
    
    cat << 'EOF' > $N8N_DIR/fastapi/main.py
import asyncio
import json
import logging
from datetime import datetime
from typing import Dict, List, Optional
from urllib.parse import urlparse
import hashlib
import time
import os

import newspaper
from fake_useragent import UserAgent
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, HttpUrl
import requests
import uvicorn

# Cấu hình logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Khởi tạo FastAPI app
app = FastAPI(
    title="N8N Article Crawler API",
    description="API để crawl nội dung bài viết từ các trang web báo",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Cấu hình bảo mật
BEARER_TOKEN = os.getenv("FASTAPI_PASSWORD", "changeme")
security = HTTPBearer()

# User agent để tránh bị chặn
ua = UserAgent()

# Models
class ArticleRequest(BaseModel):
    url: HttpUrl
    language: Optional[str] = "vi"

class ArticleResponse(BaseModel):
    url: str
    title: str
    authors: List[str]
    publish_date: Optional[str]
    text: str
    summary: str
    keywords: List[str]
    top_image: Optional[str]
    meta_description: Optional[str]
    extracted_at: str
    success: bool
    error: Optional[str] = None

class UrlMonitorRequest(BaseModel):
    source_url: HttpUrl
    check_interval: int = 3600  # Giây
    max_articles: int = 10

# Cache đơn giản để lưu kết quả
article_cache = {}
monitored_sources = {}

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Xác thực Bearer token"""
    if credentials.credentials != BEARER_TOKEN:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token không hợp lệ",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return credentials.credentials

def get_article_hash(url: str) -> str:
    """Tạo hash cho URL để cache"""
    return hashlib.md5(url.encode()).hexdigest()

def extract_article_content(url: str, language: str = "vi") -> ArticleResponse:
    """Trích xuất nội dung bài viết từ URL"""
    try:
        # Tạo cấu hình cho newspaper
        config = newspaper.Config()
        config.browser_user_agent = ua.random
        config.request_timeout = 10
        config.number_threads = 1
        
        # Tải và phân tích bài viết
        article = newspaper.Article(url, config=config, language=language)
        article.download()
        article.parse()
        
        # Thực hiện NLP để lấy keywords và summary
        try:
            article.nlp()
        except Exception as e:
            logger.warning(f"NLP thất bại cho {url}: {e}")
        
        # Tạo response
        response = ArticleResponse(
            url=url,
            title=article.title or "Không có tiêu đề",
            authors=article.authors or [],
            publish_date=article.publish_date.isoformat() if article.publish_date else None,
            text=article.text or "Không thể trích xuất nội dung",
            summary=article.summary or "Không có tóm tắt",
            keywords=article.keywords or [],
            top_image=article.top_image or None,
            meta_description=article.meta_description or None,
            extracted_at=datetime.now().isoformat(),
            success=True
        )
        
        return response
        
    except Exception as e:
        logger.error(f"Lỗi trích xuất {url}: {e}")
        return ArticleResponse(
            url=url,
            title="",
            authors=[],
            publish_date=None,
            text="",
            summary="",
            keywords=[],
            top_image=None,
            meta_description=None,
            extracted_at=datetime.now().isoformat(),
            success=False,
            error=str(e)
        )

@app.get("/", response_class=HTMLResponse)
async def read_root():
    """Trang chủ API"""
    api_domain = os.getenv("API_DOMAIN", "api.localhost")
    main_domain = os.getenv("DOMAIN", "localhost")
    html_content = f'''
    <!DOCTYPE html>
    <html lang="vi">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>N8N Article Crawler API</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }}
            .container {{ max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
            h1 {{ color: #333; text-align: center; }}
            .endpoint {{ background: #f8f9fa; padding: 20px; margin: 20px 0; border-radius: 5px; border-left: 4px solid #007bff; }}
            .method {{ display: inline-block; padding: 4px 8px; border-radius: 3px; color: white; font-weight: bold; }}
            .post {{ background: #28a745; }}
            .get {{ background: #007bff; }}
            code {{ background: #e9ecef; padding: 2px 4px; border-radius: 3px; }}
            .auth-note {{ background: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 5px; margin: 20px 0; }}
            .example {{ background: #f8f9fa; padding: 15px; margin: 10px 0; border-radius: 5px; border: 1px solid #dee2e6; }}
            .success {{ color: #28a745; }}
            .warning {{ color: #ffc107; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 N8N Article Crawler API</h1>
            <p>API để crawl nội dung bài viết từ các trang web báo với khả năng theo dõi tự động.</p>
            
            <div class="auth-note">
                <strong>⚠️ Lưu ý:</strong> Tất cả API đều yêu cầu Bearer token trong header Authorization.
            </div>
            
            <div class="endpoint">
                <span class="method post">POST</span> <strong>/extract</strong><br>
                Trích xuất nội dung từ một URL bài viết cụ thể.<br>
                <div class="example">
                    <strong>Ví dụ request:</strong><br>
                    <code>POST https://{api_domain}/extract</code><br>
                    <code>Authorization: Bearer YOUR_TOKEN</code><br>
                    <code>{{"url": "https://example.com/article", "language": "vi"}}</code>
                </div>
            </div>
            
            <div class="endpoint">
                <span class="method post">POST</span> <strong>/monitor</strong><br>
                Thiết lập theo dõi tự động cho một nguồn tin (trang web).
            </div>
            
            <div class="endpoint">
                <span class="method get">GET</span> <strong>/sources</strong><br>
                Liệt kê tất cả nguồn tin đang được theo dõi.
            </div>
            
            <div class="endpoint">
                <span class="method get">GET</span> <strong>/health</strong><br>
                Kiểm tra sức khỏe API.
            </div>
            
            <div class="endpoint">
                <span class="method get">GET</span> <strong>/docs</strong><br>
                Tài liệu API chi tiết với giao diện Swagger.
            </div>
            
            <h3>📋 Cách sử dụng với N8N:</h3>
            <p>1. Tạo HTTP Request node trong N8N</p>
            <p>2. Đặt URL: <code>https://{api_domain}/extract</code></p>
            <p>3. Method: POST</p>
            <p>4. Headers: <code>Authorization: Bearer YOUR_TOKEN</code></p>
            <p>5. Body: <code>{{"url": "https://example.com/article"}}</code></p>
            
            <h3>🔗 Liên kết hữu ích:</h3>
            <p>🌐 <a href="https://{main_domain}">N8N Dashboard</a></p>
            <p>📖 <a href="/docs">API Documentation</a></p>
            <p>❤️ <a href="/health">API Health Check</a></p>
            
            <h3>🔄 Response Format:</h3>
            <div class="example">
                <code>{{<br>
                &nbsp;&nbsp;"url": "https://example.com/article",<br>
                &nbsp;&nbsp;"title": "Tiêu đề bài viết",<br>
                &nbsp;&nbsp;"authors": ["Tác giả"],<br>
                &nbsp;&nbsp;"text": "Nội dung đầy đủ...",<br>
                &nbsp;&nbsp;"summary": "Tóm tắt bài viết...",<br>
                &nbsp;&nbsp;"keywords": ["từ khóa"],<br>
                &nbsp;&nbsp;"success": true<br>
                }}</code>
            </div>
        </div>
    </body>
    </html>
    '''
    return html_content

@app.post("/extract", response_model=ArticleResponse)
async def extract_article(
    request: ArticleRequest,
    token: str = Depends(verify_token)
) -> ArticleResponse:
    """Trích xuất nội dung từ URL bài viết"""
    
    url = str(request.url)
    article_hash = get_article_hash(url)
    
    # Kiểm tra cache (cache trong 1 giờ)
    if article_hash in article_cache:
        cached_data = article_cache[article_hash]
        if time.time() - cached_data['timestamp'] < 3600:
            logger.info(f"Trả về kết quả từ cache cho {url}")
            return cached_data['data']
    
    logger.info(f"Đang trích xuất nội dung từ: {url}")
    result = extract_article_content(url, request.language)
    
    # Lưu vào cache
    article_cache[article_hash] = {
        'data': result,
        'timestamp': time.time()
    }
    
    return result

@app.post("/monitor")
async def setup_monitoring(
    request: UrlMonitorRequest,
    token: str = Depends(verify_token)
) -> Dict:
    """Thiết lập theo dõi tự động cho nguồn tin"""
    
    source_url = str(request.source_url)
    
    try:
        # Tạo source object từ newspaper
        source = newspaper.build(source_url, language='vi')
        
        # Lưu thông tin theo dõi
        monitored_sources[source_url] = {
            'source': source,
            'check_interval': request.check_interval,
            'max_articles': request.max_articles,
            'last_check': None,
            'articles_found': 0,
            'created_at': datetime.now().isoformat()
        }
        
        return {
            "success": True,
            "message": f"Đã thiết lập theo dõi cho {source_url}",
            "articles_count": len(source.articles),
            "check_interval": request.check_interval
        }
        
    except Exception as e:
        logger.error(f"Lỗi thiết lập theo dõi {source_url}: {e}")
        raise HTTPException(
            status_code=400,
            detail=f"Không thể thiết lập theo dõi: {str(e)}"
        )

@app.get("/sources")
async def get_monitored_sources(token: str = Depends(verify_token)) -> Dict:
    """Lấy danh sách nguồn tin đang theo dõi"""
    return {
        "total_sources": len(monitored_sources),
        "sources": {url: {
            "check_interval": data["check_interval"],
            "max_articles": data["max_articles"],
            "last_check": data["last_check"],
            "articles_found": data["articles_found"],
            "created_at": data["created_at"]
        } for url, data in monitored_sources.items()}
    }

@app.get("/health")
async def health_check():
    """Kiểm tra sức khỏe API"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "cache_size": len(article_cache),
        "monitored_sources": len(monitored_sources)
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)
EOF

    # Tạo script chạy FastAPI
    cat << EOF > $N8N_DIR/fastapi/run.sh
#!/bin/bash
export FASTAPI_PASSWORD="$FASTAPI_PASSWORD"
export DOMAIN="$DOMAIN"
export API_DOMAIN="$API_DOMAIN"
cd /app/fastapi
/opt/fastapi-venv/bin/uvicorn main:app --host 0.0.0.0 --port 8001 --reload
EOF
    chmod +x $N8N_DIR/fastapi/run.sh
fi

# Tạo Dockerfile tùy chỉnh cho n8n với FFmpeg, yt-dlp và Puppeteer
echo "Tạo Dockerfile tùy chỉnh cho n8n..."
cat << EOF > $N8N_DIR/Dockerfile
FROM n8nio/n8n:latest

USER root

# Cập nhật packages và cài đặt các công cụ cần thiết
RUN apk update && apk add --no-cache \\
    ffmpeg \\
    python3 \\
    py3-pip \\
    chromium \\
    chromium-chromedriver \\
    ttf-freefont \\
    font-noto-emoji \\
    wqy-zenhei \\
    curl \\
    wget \\
    git \\
    bash \\
    jq \\
    tar \\
    gzip

# Cài đặt yt-dlp
RUN pip3 install --no-cache-dir yt-dlp

# Cài đặt các thư viện Python bổ sung
RUN pip3 install --no-cache-dir requests beautifulsoup4 lxml

# Thiết lập biến môi trường cho Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV CHROME_BIN=/usr/bin/chromium-browser
ENV CHROME_PATH=/usr/bin/chromium-browser

# Cài đặt Puppeteer và dependencies
RUN npm install -g puppeteer@latest
RUN npm install -g playwright
RUN npx playwright install chromium

# Tạo thư mục và set quyền
RUN mkdir -p /home/node/files && chown -R node:node /home/node/files
RUN mkdir -p /home/node/.cache && chown -R node:node /home/node/.cache

# Chuyển về user node
USER node

# Thiết lập thư mục làm việc
WORKDIR /home/node

# Expose port
EXPOSE 5678

# Lệnh khởi động
CMD ["n8n", "start"]
EOF

# Tạo docker-compose.yml
echo "Tạo docker-compose.yml..."
if [ "$SETUP_FASTAPI" = true ]; then
cat << EOF > $N8N_DIR/docker-compose.yml
version: '3.8'

services:
  n8n:
    build: .
    image: n8n-ffmpeg-latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=changeme
      - N8N_HOST=\${DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://\${DOMAIN}/
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
    volumes:
      - ./files:/files
      - n8n_data:/home/node/.n8n
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - n8n-network

  fastapi:
    image: python:3.11-slim
    container_name: fastapi-crawler
    restart: unless-stopped
    ports:
      - "8001:8001"
    environment:
      - FASTAPI_PASSWORD=\${FASTAPI_PASSWORD}
      - DOMAIN=\${DOMAIN}
      - API_DOMAIN=\${API_DOMAIN}
    volumes:
      - ./fastapi:/app/fastapi
      - /opt/fastapi-venv:/opt/fastapi-venv
    working_dir: /app
    command: bash -c "apt-get update && apt-get install -y curl && /app/fastapi/run.sh"
    networks:
      - n8n-network

  caddy:
    image: caddy:2
    container_name: caddy
    restart: unless-stopped
    ports:
      - "8080:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - n8n-network

volumes:
  n8n_data:
  caddy_data:
  caddy_config:

networks:
  n8n-network:
    driver: bridge
EOF
else
    cat << EOF > $N8N_DIR/docker-compose.yml
version: '3.8'

services:
  n8n:
    build: .
    image: n8n-ffmpeg-latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=changeme
      - N8N_HOST=\${DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://\${DOMAIN}/
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
    volumes:
      - ./files:/files
      - n8n_data:/home/node/.n8n
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - n8n-network

  caddy:
    image: caddy:2
    container_name: caddy
    restart: unless-stopped
    ports:
      - "8080:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - n8n-network

volumes:
  n8n_data:
  caddy_data:
  caddy_config:

networks:
  n8n-network:
    driver: bridge
EOF
fi

# Tạo .env file
echo "Tạo file .env..."
cat << EOF > $N8N_DIR/.env
DOMAIN=$DOMAIN
API_DOMAIN=$API_DOMAIN
FASTAPI_PASSWORD=$FASTAPI_PASSWORD
EOF

# Tạo Caddyfile
echo "Tạo Caddyfile cho SSL tự động..."
if [ "$SETUP_FASTAPI" = true ]; then
cat << EOF > $N8N_DIR/Caddyfile
# N8N Main Domain
$DOMAIN {
    reverse_proxy n8n:5678
    
    # Cấu hình headers bảo mật
    header {
        # Bảo mật
        Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        
        # Loại bỏ thông tin server
        -Server
    }
    
    # Cấu hình gzip
    encode gzip
    
    # Log
    log {
        output file /var/log/caddy/n8n-access.log
        format console
    }
}

# FastAPI Subdomain
$API_DOMAIN {
    reverse_proxy fastapi:8001
    
    # Cấu hình headers bảo mật
    header {
        # Bảo mật
        Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        
        # CORS cho API
        Access-Control-Allow-Origin "*"
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        Access-Control-Allow-Headers "Content-Type, Authorization"
        
        # Loại bỏ thông tin server
        -Server
    }
    
    # Cấu hình gzip
    encode gzip
    
    # Log
    log {
        output file /var/log/caddy/api-access.log
        format console
    }
}
EOF
else
    cat << EOF > $N8N_DIR/Caddyfile
$DOMAIN {
    reverse_proxy n8n:5678
    
    # Cấu hình headers bảo mật
    header {
        # Bảo mật
        Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        
        # Loại bỏ thông tin server
        -Server
    }
    
    # Cấu hình gzip
    encode gzip
    
    # Log
    log {
        output file /var/log/caddy/access.log
        format console
    }
}
EOF
fi

# Tạo script backup được cải tiến với hỗ trợ Telegram
echo "Tạo script backup workflows và credentials..."
cat << EOF > $N8N_DIR/backup-workflows.sh
#!/bin/bash

# Cấu hình
BACKUP_DIR="$N8N_DIR/files/backup_full"
TIMESTAMP=\$(date '+%Y%m%d_%H%M%S')
BACKUP_FILE="\$BACKUP_DIR/n8n_backup_\$TIMESTAMP.tar.gz"
TEMP_DIR="/tmp/n8n_backup_\$TIMESTAMP"

# Telegram cấu hình
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"
SEND_TO_TELEGRAM=$SETUP_TELEGRAM

# Hàm ghi log
log() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" | tee -a "\$BACKUP_DIR/backup.log"
}

# Hàm gửi tin nhắn Telegram
send_telegram_message() {
    local message="\$1"
    if [ "\$SEND_TO_TELEGRAM" = true ] && [ -n "\$TELEGRAM_BOT_TOKEN" ] && [ -n "\$TELEGRAM_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot\$TELEGRAM_BOT_TOKEN/sendMessage" \\
            -d chat_id="\$TELEGRAM_CHAT_ID" \\
            -d text="\$message" \\
            -d parse_mode="HTML" > /dev/null
    fi
}

# Hàm gửi file qua Telegram
send_telegram_file() {
    local file_path="\$1"
    local caption="\$2"
    if [ "\$SEND_TO_TELEGRAM" = true ] && [ -n "\$TELEGRAM_BOT_TOKEN" ] && [ -n "\$TELEGRAM_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot\$TELEGRAM_BOT_TOKEN/sendDocument" \\
            -F chat_id="\$TELEGRAM_CHAT_ID" \\
            -F document=@"\$file_path" \\
            -F caption="\$caption" > /dev/null
    fi
}

log "🔄 Bắt đầu quá trình backup N8N..."
send_telegram_message "🔄 <b>Bắt đầu backup N8N</b>%0A📅 Thời gian: \$(date '+%d/%m/%Y %H:%M:%S')"

# Tạo thư mục backup nếu không tồn tại
mkdir -p "\$BACKUP_DIR"
mkdir -p "\$TEMP_DIR/workflows"
mkdir -p "\$TEMP_DIR/credentials"

# Tìm container N8N
log "Tìm container N8N..."
N8N_CONTAINER=\$(docker ps -q --filter "name=n8n" 2>/dev/null)

if [ -z "\$N8N_CONTAINER" ]; then
    log "❌ Lỗi: Không tìm thấy container n8n đang chạy"
    send_telegram_message "❌ <b>Lỗi Backup</b>%0AKhông tìm thấy container N8N đang chạy"
    rm -rf "\$TEMP_DIR"
    exit 1
fi

log "✅ Tìm thấy container N8N: \$N8N_CONTAINER"

# Xuất workflows
log "📝 Đang xuất workflows..."
WORKFLOWS=\$(docker exec \$N8N_CONTAINER n8n list:workflows --json 2>/dev/null)
if [ -z "\$WORKFLOWS" ] || [ "\$WORKFLOWS" = "[]" ]; then
    log "⚠️ Cảnh báo: Không tìm thấy workflow nào hoặc chưa có workflow"
    echo "[]" > "\$TEMP_DIR/workflows/empty.json"
else
    # Xuất từng workflow
    WORKFLOW_COUNT=0
    echo "\$WORKFLOWS" | jq -c '.[]' | while read -r workflow; do
        id=\$(echo "\$workflow" | jq -r '.id')
        name=\$(echo "\$workflow" | jq -r '.name' | tr -dc '[:alnum:][:space:]_-' | tr '[:space:]' '_')
        log "  → Xuất workflow: \$name (ID: \$id)"
        
        # Xuất workflow với xử lý lỗi
        if docker exec \$N8N_CONTAINER n8n export:workflow --id="\$id" --output="/tmp/workflow_\$id.json" 2>/dev/null; then
            docker cp "\$N8N_CONTAINER:/tmp/workflow_\$id.json" "\$TEMP_DIR/workflows/\$id-\$name.json"
            docker exec \$N8N_CONTAINER rm -f "/tmp/workflow_\$id.json"
            WORKFLOW_COUNT=\$((WORKFLOW_COUNT + 1))
        else
            log "    ⚠️ Lỗi xuất workflow \$name"
        fi
    done
    
    # Lưu số lượng workflow đã backup
    echo "\$WORKFLOW_COUNT" > "\$TEMP_DIR/workflow_count.txt"
fi

# Sao lưu credentials và database
log "🔐 Đang sao lưu credentials và database..."
if docker exec \$N8N_CONTAINER test -f "/home/node/.n8n/database.sqlite"; then
    docker cp "\$N8N_CONTAINER:/home/node/.n8n/database.sqlite" "\$TEMP_DIR/credentials/"
    log "  ✅ Đã sao lưu database.sqlite"
else
    log "  ⚠️ Không tìm thấy database.sqlite"
fi

if docker exec \$N8N_CONTAINER test -f "/home/node/.n8n/config"; then
    docker cp "\$N8N_CONTAINER:/home/node/.n8n/config" "\$TEMP_DIR/credentials/"
    log "  ✅ Đã sao lưu config"
fi

# Tạo thông tin backup
cat << EOL > "\$TEMP_DIR/backup_info.txt"
Backup N8N được tạo vào: \$(date '+%Y-%m-%d %H:%M:%S')
Domain: $DOMAIN
Container ID: \$N8N_CONTAINER
Số workflow: \$(cat "\$TEMP_DIR/workflow_count.txt" 2>/dev/null || echo "0")
EOL

# Tạo file tar.gz
log "📦 Đang tạo file backup..."
cd "\$(dirname "\$TEMP_DIR")"
tar -czf "\$BACKUP_FILE" "\$(basename "\$TEMP_DIR")"

# Kiểm tra backup thành công
if [ -f "\$BACKUP_FILE" ]; then
    BACKUP_SIZE=\$(du -h "\$BACKUP_FILE" | cut -f1)
    log "✅ Backup thành công: \$BACKUP_FILE (Kích thước: \$BACKUP_SIZE)"
    
    # Gửi thông báo và file backup qua Telegram
    send_telegram_message "✅ <b>Backup N8N thành công!</b>%0A📁 File: n8n_backup_\$TIMESTAMP.tar.gz%0A📊 Kích thước: \$BACKUP_SIZE%0A🕐 Thời gian: \$(date '+%d/%m/%Y %H:%M:%S')"
    
    # Gửi file backup qua Telegram (nếu file < 50MB)
    FILE_SIZE_MB=\$(stat -f%z "\$BACKUP_FILE" 2>/dev/null || stat -c%s "\$BACKUP_FILE" 2>/dev/null)
    FILE_SIZE_MB=\$((FILE_SIZE_MB / 1024 / 1024))
    
    if [ \$FILE_SIZE_MB -lt 50 ]; then
        log "📤 Đang gửi file backup qua Telegram..."
        send_telegram_file "\$BACKUP_FILE" "📦 N8N Backup - \$(date '+%d/%m/%Y %H:%M:%S')"
        log "✅ Đã gửi file backup qua Telegram"
    else
        log "⚠️ File backup quá lớn (\${FILE_SIZE_MB}MB) để gửi qua Telegram"
        send_telegram_message "⚠️ File backup quá lớn (\${FILE_SIZE_MB}MB) để gửi qua Telegram"
    fi
else
    log "❌ Lỗi: Không thể tạo file backup"
    send_telegram_message "❌ <b>Lỗi Backup</b>%0AKhông thể tạo file backup"
    rm -rf "\$TEMP_DIR"
    exit 1
fi

# Dọn dẹp thư mục tạm
log "🧹 Dọn dẹp thư mục tạm..."
rm -rf "\$TEMP_DIR"

# Giữ lại tối đa 30 bản backup gần nhất
log "🗂️ Dọn dẹp backup cũ..."
BACKUP_COUNT=\$(ls -1 "\$BACKUP_DIR"/n8n_backup_*.tar.gz 2>/dev/null | wc -l)
if [ \$BACKUP_COUNT -gt 30 ]; then
    REMOVED_COUNT=\$((\$BACKUP_COUNT - 30))
    ls -t "\$BACKUP_DIR"/n8n_backup_*.tar.gz | tail -n +31 | xargs -r rm
    log "🗑️ Đã xóa \$REMOVED_COUNT backup cũ, giữ lại 30 backup gần nhất"
fi

log "🎉 Hoàn tất quá trình backup!"
EOF

# Đặt quyền thực thi cho script backup
chmod +x $N8N_DIR/backup-workflows.sh

# Tạo cron job cho backup hàng ngày
echo "Thiết lập backup tự động hàng ngày..."
CRON_JOB="0 2 * * * $N8N_DIR/backup-workflows.sh"

# Kiểm tra xem cron job đã tồn tại chưa
if ! crontab -l 2>/dev/null | grep -q "$N8N_DIR/backup-workflows.sh"; then
    # Thêm cron job
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "✅ Đã thiết lập backup tự động lúc 2:00 sáng hàng ngày"
else
    echo "ℹ️ Cron job backup đã tồn tại"
fi

# Đặt quyền cho thư mục n8n
echo "Đặt quyền cho thư mục n8n..."
chown -R 1000:1000 $N8N_DIR
chmod -R 755 $N8N_DIR

# Khởi động các container
echo "Khởi động các container..."
echo "Lưu ý: Quá trình build image có thể mất vài phút, vui lòng đợi..."
cd $N8N_DIR

# Kiểm tra cổng 80 có đang được sử dụng không
if netstat -tuln | grep -q ":80\s"; then
    echo "CẢNH BÁO: Cổng 80 đang được sử dụng bởi một ứng dụng khác. Caddy sẽ sử dụng cổng 8080."
    # Đã cấu hình 8080 trong docker-compose.yml
else
    # Nếu cổng 80 trống, cập nhật docker-compose.yml để sử dụng cổng 80
    sed -i 's/"8080:80"/"80:80"/g' $N8N_DIR/docker-compose.yml
    echo "Cổng 80 đang trống. Caddy sẽ sử dụng cổng 80 mặc định."
fi

# Kiểm tra quyền truy cập Docker
echo "Kiểm tra quyền truy cập Docker..."
if ! docker ps &>/dev/null; then
    echo "Khởi động container với sudo vì quyền truy cập Docker..."
    # Sử dụng docker-compose hoặc docker compose tùy theo phiên bản
    if command -v docker-compose &> /dev/null; then
        sudo docker-compose up -d
    elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
        sudo docker compose up -d
    else
        echo "Lỗi: Không tìm thấy lệnh docker-compose hoặc docker compose."
        exit 1
    fi
else
    # Sử dụng docker-compose hoặc docker compose tùy theo phiên bản
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
        docker compose up -d
    else
        echo "Lỗi: Không tìm thấy lệnh docker-compose hoặc docker compose."
        exit 1
    fi
fi

# Đợi một lúc để các container có thể khởi động
echo "Đợi các container khởi động..."
sleep 15

# Tạo script cập nhật tự động
echo "Tạo script cập nhật tự động..."
cat << EOF > $N8N_DIR/update-n8n.sh
#!/bin/bash

# Đường dẫn đến thư mục n8n
N8N_DIR="$N8N_DIR"

# Hàm ghi log
log() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" >> \$N8N_DIR/update.log
}

log "Bắt đầu kiểm tra cập nhật..."

# Kiểm tra Docker command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    log "Không tìm thấy lệnh docker-compose hoặc docker compose."
    exit 1
fi

# Cập nhật yt-dlp trên host
log "Cập nhật yt-dlp trên host system..."
if command -v pipx &> /dev/null; then
    pipx upgrade yt-dlp
elif [ -d "/opt/yt-dlp-venv" ]; then
    /opt/yt-dlp-venv/bin/pip install -U yt-dlp
else
    log "Không tìm thấy cài đặt yt-dlp đã biết"
fi

# Lấy phiên bản hiện tại
CURRENT_IMAGE_ID=\$(docker images -q n8n-ffmpeg-latest)
if [ -z "\$CURRENT_IMAGE_ID" ]; then
    log "Không tìm thấy image n8n-ffmpeg-latest"
    exit 1
fi

# Kiểm tra và xóa image gốc n8nio/n8n cũ nếu cần
OLD_BASE_IMAGE_ID=\$(docker images -q n8nio/n8n)

# Pull image gốc mới nhất
log "Kéo image n8nio/n8n mới nhất"
docker pull n8nio/n8n

# Lấy image ID mới
NEW_BASE_IMAGE_ID=\$(docker images -q n8nio/n8n)

# Kiểm tra xem image gốc đã thay đổi chưa
if [ "\$NEW_BASE_IMAGE_ID" != "\$OLD_BASE_IMAGE_ID" ]; then
    log "Phát hiện image mới (\${NEW_BASE_IMAGE_ID}), tiến hành cập nhật..."
    
    # Sao lưu dữ liệu n8n trước khi cập nhật
    \$N8N_DIR/backup-workflows.sh
    
    # Build lại image n8n-ffmpeg
    cd \$N8N_DIR
    log "Đang build lại image n8n-ffmpeg-latest..."
    \$DOCKER_COMPOSE build
    
    # Khởi động lại container
    log "Khởi động lại container..."
    \$DOCKER_COMPOSE down
    \$DOCKER_COMPOSE up -d
    
    log "Cập nhật hoàn tất!"
else
    log "Image n8nio/n8n đã là phiên bản mới nhất"
fi
EOF

chmod +x $N8N_DIR/update-n8n.sh

# Tạo script kiểm tra SSL
echo "Tạo script kiểm tra SSL..."
cat << EOF > $N8N_DIR/check-ssl.sh
#!/bin/bash

echo "======================================================================"
echo "                    KIỂM TRA SSL VÀ DOMAIN"
echo "======================================================================"

# Kiểm tra DNS
echo "🔍 Kiểm tra DNS cho domain chính..."
MAIN_IP=\$(dig +short $DOMAIN | head -1)
SERVER_IP=\$(curl -s https://api.ipify.org)

echo "📍 IP Server: \$SERVER_IP"
echo "📍 IP Domain $DOMAIN: \$MAIN_IP"

if [ "\$MAIN_IP" = "\$SERVER_IP" ]; then
    echo "✅ Domain $DOMAIN đã trỏ đúng"
else
    echo "❌ Domain $DOMAIN chưa trỏ đúng"
fi

# Kiểm tra API domain nếu có
if [ "$SETUP_FASTAPI" = true ]; then
    echo ""
    echo "🔍 Kiểm tra DNS cho API domain..."
    API_IP=\$(dig +short $API_DOMAIN | head -1)
    echo "📍 IP API Domain $API_DOMAIN: \$API_IP"
    
    if [ "\$API_IP" = "\$SERVER_IP" ]; then
        echo "✅ API Domain $API_DOMAIN đã trỏ đúng"
    else
        echo "❌ API Domain $API_DOMAIN chưa trỏ đúng"
    fi
fi

echo ""
echo "🐳 Kiểm tra containers..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "📋 Kiểm tra logs containers..."
echo "--- Caddy Logs (10 dòng cuối) ---"
docker logs caddy --tail 10

if [ "$SETUP_FASTAPI" = true ]; then
    echo ""
    echo "--- FastAPI Logs (10 dòng cuối) ---"
    docker logs fastapi-crawler --tail 10
fi

echo ""
echo "--- N8N Logs (10 dòng cuối) ---"
docker logs n8n --tail 10

echo ""
echo "🌐 Kiểm tra kết nối..."
echo "Test HTTP $DOMAIN:"
curl -I -s --connect-timeout 5 http://$DOMAIN || echo "❌ HTTP không kết nối được"

echo ""
echo "Test HTTPS $DOMAIN:"
curl -I -s --connect-timeout 5 https://$DOMAIN || echo "❌ HTTPS không kết nối được"

if [ "$SETUP_FASTAPI" = true ]; then
    echo ""
    echo "Test API $API_DOMAIN:"
    curl -I -s --connect-timeout 5 https://$API_DOMAIN || echo "❌ API không kết nối được"
fi

echo ""
echo "🔧 Hướng dẫn debug:"
echo "1. Nếu DNS chưa đúng: Cập nhật bản ghi A record"
echo "2. Nếu container không chạy: docker-compose restart"
echo "3. Nếu SSL lỗi: Đợi 2-5 phút để Let's Encrypt cấp cert"
echo "4. Xem logs chi tiết: docker-compose logs -f caddy"
echo "======================================================================"
EOF

chmod +x $N8N_DIR/check-ssl.sh

# Tạo cron job cho cập nhật tự động (hàng tuần)
CRON_UPDATE="0 3 * * 0 $N8N_DIR/update-n8n.sh"
if ! crontab -l 2>/dev/null | grep -q "$N8N_DIR/update-n8n.sh"; then
    (crontab -l 2>/dev/null; echo "$CRON_UPDATE") | crontab -
    echo "✅ Đã thiết lập cập nhật tự động vào Chủ nhật hàng tuần lúc 3:00 sáng"
fi

# Tạo lần backup đầu tiên để kiểm tra
echo "Tạo backup đầu tiên để kiểm tra..."
$N8N_DIR/backup-workflows.sh

# Chạy script kiểm tra SSL sau khi khởi động
echo ""
echo "🔍 Chạy kiểm tra SSL và domain..."
sleep 5
$N8N_DIR/check-ssl.sh

# Hiển thị thông tin hoàn thành
echo ""
echo "======================================================================"
echo "                    CÀI ĐẶT HOÀN TẤT!"
echo "======================================================================"
echo ""
echo "🎉 N8N đã được cài đặt thành công với các tính năng:"
echo ""
echo "✅ N8N với FFmpeg, yt-dlp, Puppeteer"
echo "✅ SSL tự động với Let's Encrypt"
echo "✅ Backup tự động hàng ngày lúc 2:00 sáng"
echo "✅ Cập nhật tự động hàng tuần vào Chủ nhật"

if [ "$SETUP_TELEGRAM" = true ]; then
    echo "✅ Backup qua Telegram đã được thiết lập"
fi

if [ "$SETUP_FASTAPI" = true ]; then
    echo "✅ FastAPI Article Crawler đã được thiết lập"
    echo "   → API domain: https://$API_DOMAIN"
    echo "   → API docs: https://$API_DOMAIN/docs"
    echo "   → API endpoint: https://$API_DOMAIN/extract"
fi

echo ""
echo "🌐 Truy cập N8N tại: https://$DOMAIN"
echo "🔐 Tài khoản mặc định: admin / changeme"
echo "📁 Thư mục cài đặt: $N8N_DIR"
echo "💾 Thư mục backup: $N8N_DIR/files/backup_full"
echo ""
echo "📋 Lệnh hữu ích:"
echo "   - Xem logs: docker-compose logs -f"
echo "   - Khởi động lại: docker-compose restart"
echo "   - Dừng dịch vụ: docker-compose down"
echo "   - Backup thủ công: $N8N_DIR/backup-workflows.sh"
echo "   - Cập nhật thủ công: $N8N_DIR/update-n8n.sh"
echo ""

# Hiển thị các vấn đề cài đặt nếu có
if [ -n "$INSTALL_ISSUES" ]; then
    echo "⚠️ Các vấn đề đã ghi nhận:"
    echo -e "$INSTALL_ISSUES"
echo ""
fi

echo "🔧 Hướng dẫn sử dụng chi tiết:"
echo "   - Tài liệu N8N: https://docs.n8n.io"
echo "   - Hỗ trợ: https://community.n8n.io"

if [ "$SETUP_FASTAPI" = true ]; then
echo ""
    echo "📖 Hướng dẫn sử dụng FastAPI Crawler với N8N:"
    echo "   1. Tạo HTTP Request node"
    echo "   2. URL: https://$API_DOMAIN/extract"
    echo "   3. Method: POST"
    echo "   4. Headers: Authorization: Bearer $FASTAPI_PASSWORD"
    echo "   5. Body: {\"url\": \"https://example.com/article\"}"
    echo ""
    echo "🔗 Kiểm tra API:"
    echo "   - Health check: curl https://$API_DOMAIN/health"
    echo "   - API docs: https://$API_DOMAIN/docs"
fi

echo ""
echo "Cảm ơn bạn đã sử dụng script cài đặt N8N tự động! 🚀"
echo "======================================================================"
