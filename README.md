# 🚀 Script Cài Đặt N8N Tự Động với FFmpeg, yt-dlp, Puppeteer và News API

![N8N](https://img.shields.io/badge/N8N-Automation-blue) ![Docker](https://img.shields.io/badge/Docker-Containerized-blue) ![SSL](https://img.shields.io/badge/SSL-Auto-green) ![API](https://img.shields.io/badge/News%20API-FastAPI-red) ![Telegram](https://img.shields.io/badge/Telegram-Backup-orange)

> 🎥 **HÃY ĐĂNG KÝ KÊNH YOUTUBE ĐỂ ỦNG HỘ MÌNH NHÉ!** 👈  
> **[👉 ĐĂNG KÝ NGAY TẠI ĐÂY](https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1)** để không bỏ lỡ video hướng dẫn mới nhất! 🔔

Script tự động cài đặt **N8N Workflow Automation** với đầy đủ tính năng mở rộng 2025, bao gồm:
- **🤖 N8N** với FFmpeg, yt-dlp, Puppeteer
- **📰 News Content API** (FastAPI + Newspaper4k) 
- **📱 Telegram Backup** tự động hàng ngày
- **🔒 SSL Certificate** tự động với Caddy
- **💾 Smart Backup System** với compression
- **🔄 Auto-Update** với tùy chọn

## 👨‍💻 Thông Tin Tác Giả

**🌟 Nguyễn Ngọc Thiện**
- 📺 **YouTube**: [Kalvin Thien Social](https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1) - **🔔 ĐĂNG KÝ ĐỂ ỦNG HỘ!**
- 📘 **Facebook**: [Ban Thien Handsome](https://www.facebook.com/Ban.Thien.Handsome/)
- 📱 **Zalo/Phone**: 08.8888.4749
- 🎬 **N8N Playlist**: [N8N Tutorials](https://www.youtube.com/@kalvinthiensocial/playlists)
- 🚀 **Cập nhật**: 27/12/2024

> 💡 **Nếu script này hữu ích, đừng quên:**  
> ⭐ **Star** repository này  
> 🎥 **Subscribe** YouTube channel  
> 👍 **Like** và **Share** để giúp mình phát triển kênh nhé! 

## ✨ Tính Năng Nổi Bật 2025

### 🔧 N8N Core Features
- **🤖 N8N** với tất cả tính năng automation
- **🎬 FFmpeg** - Xử lý video/audio chuyên nghiệp
- **📺 yt-dlp** - Download video YouTube/TikTok/Facebook
- **🌐 Puppeteer + Chromium** - Browser automation
- **🔒 SSL tự động** với Caddy reverse proxy
- **📁 Volume mapping** cho file persistence
- **⚡ Swap memory** tự động theo RAM

### 📰 News Content API (Tính năng HOT 2025!)
> **TÍNH NĂNG MỚI 2025!** 🎉

- **🚀 FastAPI** với **Newspaper4k** mới nhất
- **🔐 Bearer Token Authentication** tùy chỉnh bảo mật
- **🌐 Subdomain riêng**: `api.yourdomain.com`
- **📱 Responsive UI** với thiết kế 2025
- **📚 Interactive Documentation** (Swagger + ReDoc)
- **🌍 Đa ngôn ngữ** (Việt, Anh, Trung, Nhật...)

**API Endpoints:**
- `GET /health` - Kiểm tra trạng thái API
- `POST /extract-article` - Lấy nội dung bài viết từ URL
- `POST /extract-source` - Crawl nhiều bài viết từ website
- `POST /parse-feed` - Phân tích RSS feeds

### 📱 Telegram Backup System (Tính năng HOT!)
- **🔄 Tự động backup** workflows & credentials mỗi ngày 2:00 AM
- **📱 Gửi file backup** qua Telegram Bot (nếu <20MB)
- **📊 Thông báo realtime** về trạng thái backup
- **🗂️ Giữ 30 bản backup** gần nhất tự động
- **🧪 Test manual backup** để kiểm tra

### 💾 Smart Backup System
- **📋 Export workflows** từ N8N database
- **🔐 Backup credentials** & encryption keys  
- **📦 Compression** với tar.gz
- **📊 Metadata tracking** (version, size, date)
- **🧹 Auto cleanup** backup cũ
- **📋 Detailed logging** mọi hoạt động

## 🖥️ Hỗ Trợ Môi Trường

✅ **Ubuntu VPS/Server** (Khuyến nghị)  
✅ **Ubuntu on Windows WSL2**  
✅ **Ubuntu Docker Environment**  
✅ **Auto-detect** và xử lý môi trường

## 📋 Yêu Cầu Hệ Thống

- **OS**: Ubuntu 20.04+ (VPS hoặc WSL)
- **RAM**: Tối thiểu 2GB (khuyến nghị 4GB+)
- **Storage**: 20GB+ free space
- **Network**: Domain đã trỏ về server IP
- **Access**: Root/sudo permissions

## 🚀 Cài Đặt Siêu Nhanh

### 1️⃣ Một Lệnh Cài Đặt (Khuyến nghị)

```bash
cd /tmp && curl -sSL https://raw.githubusercontent.com/KalvinThien/install-n8n-ffmpeg/main/auto_cai_dat_n8n.sh | tr -d '\r' > install_n8n.sh && chmod +x install_n8n.sh && sudo bash install_n8n.sh
```

### 2️⃣ Hoặc Download & Chạy

```bash
wget https://raw.githubusercontent.com/KalvinThien/install-n8n-ffmpeg/main/auto_cai_dat_n8n.sh
chmod +x auto_cai_dat_n8n.sh
sudo ./auto_cai_dat_n8n.sh
```

### 3️⃣ Cài Đặt Sạch (Xóa hết cài đặt cũ)

```bash
sudo ./auto_cai_dat_n8n.sh --clean
```

### 4️⃣ Options Nâng Cao

```bash
# Chỉ định thư mục cài đặt
sudo ./auto_cai_dat_n8n.sh -d /custom/path

# Bỏ qua cài đặt Docker (nếu đã có)
sudo ./auto_cai_dat_n8n.sh -s

# Xem trợ giúp đầy đủ
./auto_cai_dat_n8n.sh -h
```

## 🔧 Quá Trình Cài Đặt Tương Tác

Script sẽ hướng dẫn bạn qua từng bước:

1. **🔄 Setup Swap** - Tự động tính toán và setup swap phù hợp
2. **🌐 Nhập Domain** - Domain chính cho N8N 
3. **🗑️ Cleanup Option** - Tùy chọn xóa cài đặt cũ (nếu có)
4. **📰 News API Setup** - Có muốn cài News Content API không?
5. **🔐 Bearer Token** - Đặt mật khẩu Bearer Token bảo mật
6. **📱 Telegram Config** - Có muốn backup qua Telegram không?
7. **🔄 Auto-Update** - Có muốn tự động cập nhật không?
8. **✅ DNS Verification** - Kiểm tra domain đã trỏ đúng chưa
9. **🐳 Docker Installation** - Cài đặt Docker & dependencies
10. **🏗️ Build & Deploy** - Build images và khởi động containers  
11. **🔒 SSL Setup** - Tự động cấp SSL certificate

## 📰 News Content API - TÍNH NĂNG SIÊU HOT 2025! 

### 🎯 Giới Thiệu
News Content API được xây dựng với **FastAPI** và **Newspaper4k** phiên bản mới nhất, giúp bạn:
- **📰 Cào nội dung** bài viết từ bất kỳ website nào
- **📡 Parse RSS feeds** để lấy tin tức mới nhất  
- **🔍 Tìm kiếm** và phân tích nội dung tự động
- **🤖 Tích hợp** trực tiếp vào N8N workflows

### 🔑 Authentication

Tất cả API calls yêu cầu **Bearer Token tùy chỉnh**:

```bash
Authorization: Bearer YOUR_CUSTOM_TOKEN_HERE
```

> **🔐 Bảo mật:** Script sẽ yêu cầu bạn tự đặt Bearer Token (ít nhất 20 ký tự) để đảm bảo bảo mật tối đa!

### 📖 API Documentation

Sau khi cài đặt, truy cập:
- **🏠 Homepage**: `https://api.yourdomain.com/`
- **📚 Swagger UI**: `https://api.yourdomain.com/docs` 
- **📖 ReDoc**: `https://api.yourdomain.com/redoc`

### 💻 Ví Dụ Sử Dụng với cURL

**1. 🩺 Kiểm tra API:**
```bash
curl -X GET "https://api.yourdomain.com/health" \
     -H "Authorization: Bearer YOUR_CUSTOM_TOKEN"
```

**2. 📰 Lấy nội dung bài viết:**
```bash
curl -X POST "https://api.yourdomain.com/extract-article" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_CUSTOM_TOKEN" \
     -d '{
       "url": "https://dantri.com.vn/the-gioi.htm",
       "language": "vi", 
       "extract_images": true,
       "summarize": true
     }'
```

**3. 🌐 Cào nhiều bài viết từ website:**
```bash
curl -X POST "https://api.yourdomain.com/extract-source" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_CUSTOM_TOKEN" \
     -d '{
       "url": "https://dantri.com.vn",
       "max_articles": 10,
       "language": "vi"
     }'
```

**4. 📡 Parse RSS Feed:**
```bash
curl -X POST "https://api.yourdomain.com/parse-feed" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_CUSTOM_TOKEN" \
     -d '{
       "url": "https://dantri.com.vn/rss.xml",
       "max_articles": 10
     }'
```

### 🔧 Đổi Bearer Token {#change-token}

**Method 1: Qua Docker Environment**
```bash
cd /home/n8n
sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN=NEW_TOKEN_HERE/' docker-compose.yml
docker-compose restart fastapi
```

**Method 2: Edit trực tiếp**
```bash
nano /home/n8n/docker-compose.yml
# Tìm dòng NEWS_API_TOKEN và thay đổi
docker-compose restart fastapi
```

**Method 3: One-liner command**
```bash
cd /home/n8n && sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN="YOUR_NEW_TOKEN"/' docker-compose.yml && docker-compose restart fastapi
```

### 🤖 Sử Dụng trong N8N Workflows

**1. Tạo HTTP Request Node:**
- **Method**: POST
- **URL**: `https://api.yourdomain.com/extract-article`
- **Authentication**: Header Auth
  - **Name**: `Authorization`
  - **Value**: `Bearer YOUR_CUSTOM_TOKEN`

**2. Request Body:**
```json
{
  "url": "{{ $json.article_url }}",
  "language": "vi",
  "extract_images": true,
  "summarize": false
}
```

**3. Response sẽ chứa:**
```json
{
  "title": "Tiêu đề bài viết",
  "content": "Nội dung đầy đủ...",
  "summary": "Tóm tắt bài viết",
  "authors": ["Tác giả"],
  "publish_date": "2024-12-27T10:00:00Z",
  "images": ["url1.jpg", "url2.jpg"],
  "word_count": 500,
  "read_time_minutes": 3
}
```

## 📱 Telegram Backup System

### 🔧 Cấu Hình Telegram Bot

**1. 🤖 Tạo Bot:**
- Mở Telegram, tìm **@BotFather**
- Gửi lệnh: `/newbot`
- Đặt tên và username cho bot
- **Copy Bot Token** nhận được

**2. 🆔 Lấy Chat ID:**

**Cho cá nhân:**
- Tìm **@userinfobot** trên Telegram
- Gửi `/start` để lấy **User ID**

**Cho nhóm:**
- Thêm bot vào nhóm 
- Gửi tin nhắn trong nhóm
- Truy cập: `https://api.telegram.org/bot<BOT_TOKEN>/getUpdates`
- **Chat ID nhóm** bắt đầu bằng dấu trừ (-)

### 📱 Test Telegram Integration

```bash
# Test gửi tin nhắn
curl -X POST "https://api.telegram.org/bot<BOT_TOKEN>/sendMessage" \
     -d chat_id="<CHAT_ID>" \
     -d text="Test message from N8N backup system!"
```

### 🔄 Backup Features

- **⏰ Automatic**: Mỗi ngày lúc 2:00 AM
- **📱 Notifications**: Realtime qua Telegram
- **📦 File Transfer**: Auto gửi file backup (nếu <20MB)
- **📊 Statistics**: Số lượng workflows, size, thời gian
- **🗂️ Retention**: Giữ 30 bản backup gần nhất

## 💾 Backup & Restore System

### 🔄 Backup Tự Động

Script tự động backup mỗi ngày lúc **2:00 AM**:
- **📋 Workflows** và **Credentials** từ N8N
- **💾 Database** (SQLite) với tất cả dữ liệu
- **🔐 Encryption keys** và config files
- **📦 Compression** với gzip để tiết kiệm dung lượng

### 🧪 Test Backup Thủ Công

```bash
# Chạy backup test để kiểm tra
/home/n8n/backup-manual.sh

# Chạy backup thông thường  
/home/n8n/backup-workflows.sh

# Xem logs backup
tail -f /home/n8n/files/backup_full/backup.log
```

### 📁 Cấu Trúc Backup

```
/home/n8n/files/backup_full/
├── n8n_backup_20241227_140000.tar.gz   # Backup hôm nay
├── n8n_backup_20241226_140000.tar.gz   # Backup hôm qua  
├── n8n_backup_20241225_140000.tar.gz   # Backup 2 ngày trước
├── ...                                 # Tối đa 30 bản
└── backup.log                          # Log file
```

### 📦 Nội Dung Backup File

Mỗi file backup chứa:
```
backup_metadata.json          # Thông tin backup
workflows/                    # Tất cả workflows exported
├── 1-My_Workflow.json
├── 2-Another_Workflow.json  
└── workflows.json           # Danh sách workflows
credentials/                 # Credentials & database
├── database.sqlite          # N8N database
└── encryptionKey           # Encryption key
config/                     # Config files (nếu có)
```

### 🔧 Restore từ Backup

```bash
# 1. Dừng containers
cd /home/n8n && docker-compose down

# 2. Giải nén backup
cd /home/n8n/files/backup_full
tar -xzf n8n_backup_YYYYMMDD_HHMMSS.tar.gz

# 3. Copy files về vị trí cũ
cp credentials/database.sqlite /home/n8n/
cp credentials/encryptionKey /home/n8n/
# Workflows sẽ tự động import khi khởi động N8N

# 4. Khởi động lại
cd /home/n8n && docker-compose up -d
```

## 🛠️ Quản Lý Hệ Thống

### 🔧 Lệnh Cơ Bản

```bash
# Xem trạng thái containers
cd /home/n8n && docker-compose ps

# Xem logs realtime
cd /home/n8n && docker-compose logs -f

# Restart từng service
cd /home/n8n && docker-compose restart n8n
cd /home/n8n && docker-compose restart caddy
cd /home/n8n && docker-compose restart fastapi  # Nếu có News API

# Rebuild toàn bộ
cd /home/n8n && docker-compose down && docker-compose up -d --build
```

### 🔍 Troubleshooting & Diagnostics

```bash
# Script chẩn đoán tự động (TÍNH NĂNG MỚI!)
/home/n8n/troubleshoot.sh

# Kiểm tra Docker status  
docker ps --filter "name=n8n"

# Xem logs chi tiết
cd /home/n8n && docker-compose logs n8n
cd /home/n8n && docker-compose logs caddy  
cd /home/n8n && docker-compose logs fastapi  # News API

# Kiểm tra disk usage
df -h
docker system df

# Kiểm tra memory
free -h
docker stats --no-stream
```

### 🔄 Updates & Maintenance

```bash
# Update tự động (mỗi 12h nếu đã enable)
/home/n8n/update-n8n.sh

# Update manual components
docker exec -it n8n_container pip3 install --break-system-packages -U yt-dlp

# Clean Docker cache
docker system prune -f
docker image prune -f
```

## 📂 Cấu Trúc Thư Mục Hoàn Chỉnh

```
/home/n8n/
├── 🐳 docker-compose.yml          # Main config với tất cả services
├── 🏗️ Dockerfile                  # N8N custom image
├── 🌐 Caddyfile                   # Reverse proxy + SSL config  
├── 💾 backup-workflows.sh         # Auto backup script
├── 🧪 backup-manual.sh            # Manual backup test script
├── 🔄 update-n8n.sh              # Auto update script
├── 🔍 troubleshoot.sh             # Diagnostic script (MỚI!)
├── 📱 telegram_config.txt         # Telegram settings (nếu có)
├── 🔑 news_api_token.txt         # News API token (nếu có)
├── 📁 files/                      # N8N data directory
│   ├── backup_full/              # 💾 Backup storage (30 bản)
│   ├── temp/                     # 🗂️ Temporary files  
│   └── youtube_content_anylystic/ # 🎬 Video downloads
├── 📰 news_api/                   # News API (nếu có)
│   ├── Dockerfile
│   ├── requirements.txt           # Python dependencies
│   ├── main.py                   # FastAPI application
│   └── start_news_api.sh         # Startup script
├── 💾 database.sqlite             # N8N main database
├── 🔐 encryptionKey               # N8N encryption key
└── 📋 logs/                       # Log files
    ├── update.log                # Update logs
    └── backup.log                # Backup logs
```

## ⚡ Performance & Optimization

### 🚀 System Optimization

1. **💾 Memory**: Script tự động setup swap theo RAM
2. **⚡ CPU**: Single worker cho stability
3. **🗂️ Disk**: Auto cleanup old backups & Docker cache
4. **🌐 Network**: Caddy gzip compression enabled
5. **🔧 Docker**: Optimized images với multi-stage builds

### 📊 Performance Monitoring

```bash
# Resource usage realtime
docker stats

# Disk usage breakdown  
df -h
du -sh /home/n8n/*

# Memory usage detail
free -h && swapon --show

# Network connections
netstat -tulpn | grep :80
netstat -tulpn | grep :443
```

### 🎛️ Performance Tuning

```bash
# Tăng Docker memory limits (nếu cần)
nano /home/n8n/docker-compose.yml
# Thêm: mem_limit: 2g

# Tối ưu N8N settings
# Trong container N8N environment:
# N8N_EXECUTIONS_DATA_MAX_SIZE=500MB
# N8N_EXECUTIONS_TIMEOUT=3600
```

## 🐛 Troubleshooting Guide

### ❌ Lỗi Thường Gặp & Cách Sửa

**1. 🐳 Docker daemon not running (WSL)**
```bash
# Khởi động Docker daemon
sudo dockerd &

# Hoặc restart Docker service
sudo systemctl restart docker

# Kiểm tra status
sudo systemctl status docker
```

**2. 🌐 Domain chưa trỏ đúng**
```bash
# Kiểm tra DNS propagation
dig yourdomain.com A
nslookup yourdomain.com 8.8.8.8

# Kiểm tra IP server
curl -s https://api.ipify.org

# Đợi DNS propagation (5-60 phút)
```

**3. 🐳 Container không start**
```bash
# Xem logs chi tiết
cd /home/n8n && docker-compose logs

# Cleanup và rebuild
docker system prune -f
cd /home/n8n && docker-compose down
docker-compose up -d --build

# Nếu vẫn lỗi, check ports
sudo netstat -tulpn | grep :80
sudo netstat -tulpn | grep :443
```

**4. 📰 News API authentication failed**
```bash
# Kiểm tra token
grep NEWS_API_TOKEN /home/n8n/docker-compose.yml

# Test API health
curl -X GET "https://api.yourdomain.com/health" \
     -H "Authorization: Bearer YOUR_TOKEN"

# Restart News API service
cd /home/n8n && docker-compose restart fastapi
```

**5. 🔒 SSL Certificate issues**
```bash
# Xem Caddy logs
cd /home/n8n && docker-compose logs caddy

# Force SSL renewal
docker-compose restart caddy

# Kiểm tra domain accessibility
curl -I https://yourdomain.com
```

**6. 📱 Telegram backup không hoạt động**
```bash
# Test Telegram Bot
curl -X POST "https://api.telegram.org/bot<BOT_TOKEN>/getMe"

# Test gửi tin nhắn
curl -X POST "https://api.telegram.org/bot<BOT_TOKEN>/sendMessage" \
     -d chat_id="<CHAT_ID>" \
     -d text="Test message"

# Kiểm tra config file
cat /home/n8n/telegram_config.txt
```

**7. 💾 Backup lỗi**
```bash
# Chạy manual backup để debug
/home/n8n/backup-manual.sh

# Xem log chi tiết
tail -f /home/n8n/files/backup_full/backup.log

# Kiểm tra permissions
ls -la /home/n8n/files/backup_full/
```

### 🔧 Recovery Commands

```bash
# 🧹 Clean reinstall (XÓA TẤT CẢ!)
sudo rm -rf /home/n8n
sudo ./auto_cai_dat_n8n.sh --clean

# 🔄 Soft restart services
cd /home/n8n
docker-compose restart

# 💾 Restore từ backup
cd /home/n8n/files/backup_full
tar -xzf n8n_backup_YYYYMMDD_HHMMSS.tar.gz
# Copy files về vị trí cũ

# 🐳 Reset Docker completely  
sudo systemctl stop docker
sudo systemctl start docker
cd /home/n8n && docker-compose up -d
```

### 🩺 Health Check Commands

```bash
# Comprehensive system check
/home/n8n/troubleshoot.sh

# Quick status check
cd /home/n8n && docker-compose ps

# Service-specific checks
curl -I https://yourdomain.com                    # N8N
curl -I https://api.yourdomain.com/health        # News API
systemctl status docker                          # Docker
systemctl status cron                           # Cron jobs
```

## 🌟 Features Roadmap 2025

- [ ] **🌍 Multi-domain** support cho nhiều N8N instances
- [ ] **📊 Monitoring dashboard** với Grafana  
- [ ] **☸️ Kubernetes** deployment option
- [ ] **🔗 External database** support (PostgreSQL)
- [ ] **📈 Auto-scaling** dựa trên load
- [ ] **🛒 Plugin marketplace** integration
- [ ] **🔔 Advanced notifications** (Discord, Slack, Email)
- [ ] **🧠 AI content** analysis integration

## 🤝 Contributing & Support

### 💬 Nhận Hỗ Trợ

- **🐛 Issues**: [GitHub Issues](https://github.com/KalvinThien/install-n8n-ffmpeg/issues)
- **🎥 YouTube**: [Kalvin Thien Social](https://www.youtube.com/@kalvinthiensocial) - **ĐĂNG KÝ ĐỂ ỦNG HỘ!**
- **📘 Facebook**: [Ban Thien Handsome](https://www.facebook.com/Ban.Thien.Handsome/)
- **📱 Zalo**: 08.8888.4749

### 🔧 Contributing

1. **🍴 Fork** repository này
2. **🌿 Tạo feature branch**: `git checkout -b feature/amazing-feature`
3. **💾 Commit changes**: `git commit -m 'Add amazing feature'`
4. **📤 Push to branch**: `git push origin feature/amazing-feature`  
5. **🔄 Create Pull Request**

### 📝 Bug Reports

Khi báo lỗi, hãy include:
- **🖥️ OS version** (Ubuntu 20.04, 22.04, etc.)
- **🐳 Docker version**
- **📋 Error logs** từ `docker-compose logs`
- **🔧 Steps to reproduce**

## 📄 License & Credits

**📜 License**: MIT License - Xem file [LICENSE](LICENSE)

**🙏 Credits**:
- **N8N Team** - Workflow automation platform
- **📰 Newspaper4k** - Python article extraction  
- **🚀 FastAPI** - Modern Python web framework
- **🐳 Docker** - Containerization platform
- **🌐 Caddy** - Web server with automatic HTTPS

## ⭐ Star History & Community

> **🌟 Nếu script này hữu ích, hãy cho 1 STAR để ủng hộ!**  
> **🎥 Và đừng quên SUBSCRIBE YouTube channel nhé!**

[![Star History Chart](https://api.star-history.com/svg?repos=KalvinThien/install-n8n-ffmpeg&type=Date)](https://star-history.com/#KalvinThien/install-n8n-ffmpeg&Date)

### 📊 Statistics

![GitHub stars](https://img.shields.io/github/stars/KalvinThien/install-n8n-ffmpeg?style=social)
![GitHub forks](https://img.shields.io/github/forks/KalvinThien/install-n8n-ffmpeg?style=social)  
![GitHub watchers](https://img.shields.io/github/watchers/KalvinThien/install-n8n-ffmpeg?style=social)
![GitHub downloads](https://img.shields.io/github/downloads/KalvinThien/install-n8n-ffmpeg/total)

## 🎯 Quick Links

| 🔗 Link | 📝 Mô Tả |
|---------|-----------|
| [🎥 YouTube](https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1) | **ĐĂNG KÝ để xem video hướng dẫn!** |
| [📚 N8N Docs](https://docs.n8n.io/) | Tài liệu chính thức N8N |
| [📰 Newspaper4k](https://pypi.org/project/newspaper4k/) | Python library để cào tin tức |
| [🚀 FastAPI](https://fastapi.tiangolo.com/) | Framework cho News API |
| [🐳 Docker](https://docs.docker.com/) | Tài liệu Docker |

---

**🚀 Made with ❤️ by Nguyễn Ngọc Thiện - December 2024**

> 💡 **Đừng quên**: ĐĂNG KÝ [YouTube channel](https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1) để không bỏ lỡ video mới! 🔔
