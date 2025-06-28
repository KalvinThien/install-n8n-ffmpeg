# 🚀 Script Cài Đặt N8N Tự Động với FFmpeg, yt-dlp, Puppeteer và News API

![N8N](https://img.shields.io/badge/N8N-Automation-blue) ![Docker](https://img.shields.io/badge/Docker-Containerized-blue) ![SSL](https://img.shields.io/badge/SSL-Auto-green) ![API](https://img.shields.io/badge/News%20API-FastAPI-red)

Script tự động cài đặt N8N với đầy đủ tính năng mở rộng và tự động hóa backup, bao gồm:
- **N8N Workflow Automation** với FFmpeg, yt-dlp, Puppeteer
- **News Content API** (FastAPI + Newspaper4k)
- **Telegram Backup** tự động
- **SSL Certificate** tự động với Caddy
- **Swap Memory** tự động
- **Backup** hàng ngày

## 👨‍💻 Thông Tin Tác Giả

**Nguyễn Ngọc Thiện**
- 📺 **YouTube**: [Kalvin Thien Social](https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1) - **HẢY ĐĂNG KÝ ĐỂ ỦNG HỘ!**
- 📘 **Facebook**: [Ban Thien Handsome](https://www.facebook.com/Ban.Thien.Handsome/)
- 📱 **Zalo/Phone**: 08.8888.4749
- 🎬 **N8N Playlist**: [N8N Tutorials](https://www.youtube.com/@kalvinthiensocial/playlists)
- 🚀 **Ngày cập nhật**: 27/06/2025

## ✨ Tính Năng Chính

### 🔧 N8N Core Features
- **N8N** với tất cả tính năng automation
- **FFmpeg** - Xử lý video/audio
- **yt-dlp** - Download video YouTube
- **Puppeteer + Chromium** - Browser automation
- **SSL tự động** với Caddy reverse proxy
- **Volume mapping** cho file persistence

### 📰 News Content API (Tùy chọn)
- **FastAPI** với Newspaper4k
- **Bearer Token Authentication**
- **Subdomain API**: `api.yourdomain.com`
- **Responsive UI** với thiết kế 2025
- **Interactive Documentation**

**API Endpoints:**
- `GET /health` - Kiểm tra trạng thái
- `POST /extract-article` - Lấy nội dung bài viết
- `POST /extract-source` - Crawl nhiều bài viết
- `POST /parse-feed` - Phân tích RSS feeds

### 📱 Telegram Backup (Tùy chọn)
- **Tự động gửi backup** qua Telegram Bot
- **Backup hàng ngày** lúc 2:00 AM
- **Giữ 30 bản backup** gần nhất
- **Thông báo realtime** qua Telegram

### 💾 Smart Backup System
- **Backup workflows & credentials**
- **Database backup** (SQLite)
- **Error handling** toàn diện
- **Compression** (.tar.gz)
- **Manual backup** script để test

## 🖥️ Hỗ Trợ Môi Trường

✅ **Ubuntu VPS/Server** (Recommend)  
✅ **Ubuntu on Windows WSL**  
✅ **Ubuntu Docker Environment**  
✅ **Tự động detect** và xử lý môi trường

## 📋 Yêu Cầu Hệ Thống

- **OS**: Ubuntu 20.04+ (VPS hoặc WSL)
- **RAM**: Tối thiểu 2GB (khuyến nghị 4GB+)
- **Disk**: 20GB+ free space
- **Network**: Domain đã trỏ về server
- **Permission**: Root access

## 🚀 Cài Đặt Nhanh

### 1️⃣ Một Lệnh Cài Đặt

```bash
cd /tmp && curl -sSL https://raw.githubusercontent.com/KalvinThien/install-n8n-ffmpeg/main/auto_cai_dat_n8n.sh | tr -d '\r' > install_n8n.sh && chmod +x install_n8n.sh && sudo bash install_n8n.sh
```

### 2️⃣ Hoặc Tải Xuống & Chạy

```bash
wget https://raw.githubusercontent.com/KalvinThien/install-n8n-ffmpeg/main/auto_cai_dat_n8n.sh
chmod +x auto_cai_dat_n8n.sh
sudo ./auto_cai_dat_n8n.sh
```

### 3️⃣ Options Nâng Cao

```bash
# Chỉ định thư mục cài đặt
sudo ./auto_cai_dat_n8n.sh -d /custom/path

# Bỏ qua cài đặt Docker (nếu đã có)
sudo ./auto_cai_dat_n8n.sh -s

# Xem trợ giúp
./auto_cai_dat_n8n.sh -h
```

## 🔧 Quá Trình Cài Đặt

Script sẽ hướng dẫn bạn qua các bước:

1. **Setup Swap** tự động
2. **Nhập domain** của bạn
3. **Cấu hình Telegram** (tùy chọn)
4. **Cấu hình News API** (tùy chọn)
5. **Kiểm tra DNS** pointing
6. **Cài đặt Docker** & dependencies
7. **Build & start** containers
8. **Setup SSL** certificate

## 📰 News Content API

### 🔑 Authentication

Tất cả API calls yêu cầu Bearer Token:

```bash
Authorization: Bearer YOUR_TOKEN_HERE
```

### 📖 API Documentation

Sau khi cài đặt, truy cập:
- **Homepage**: `https://api.yourdomain.com/`
- **Swagger UI**: `https://api.yourdomain.com/docs`
- **ReDoc**: `https://api.yourdomain.com/redoc`

### 💻 Ví Dụ cURL

**1. Kiểm tra API:**
```bash
curl -X GET "https://api.yourdomain.com/health" \
     -H "Authorization: Bearer YOUR_TOKEN"
```

**2. Lấy nội dung bài viết:**
```bash
curl -X POST "https://api.yourdomain.com/extract-article" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -d '{
       "url": "https://dantri.com.vn/the-gioi.htm",
       "language": "vi",
       "extract_images": true,
       "summarize": true
     }'
```

**3. Parse RSS Feed:**
```bash
curl -X POST "https://api.yourdomain.com/parse-feed" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -d '{
       "url": "https://dantri.com.vn/rss.xml",
       "max_articles": 10
     }'
```

### 🔧 Đổi Bearer Token {#change-token}

**Method 1: Docker Environment**
```bash
cd /home/n8n
sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN=NEW_TOKEN_HERE/' docker-compose.yml
docker-compose restart fastapi
```

**Method 2: Direct Edit**
```bash
nano /home/n8n/docker-compose.yml
# Tìm dòng NEWS_API_TOKEN và thay đổi
docker-compose restart fastapi
```

**Method 3: One-liner**
```bash
cd /home/n8n && sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN="YOUR_NEW_TOKEN"/' docker-compose.yml && docker-compose restart fastapi
```

## 💾 Backup & Restore

### 🔄 Backup Tự Động

Script tự động backup mỗi ngày lúc 2:00 AM:
- **Workflows** và **Credentials**
- **Database** (SQLite)
- **Configuration files**
- **Compression** với gzip

### 🧪 Test Backup

```bash
# Chạy backup thủ công và kiểm tra
/home/n8n/backup-manual.sh

# Chạy backup thông thường
/home/n8n/backup-workflows.sh
```

### 📁 Vị Trí Backup

```
/home/n8n/files/backup_full/
├── n8n_backup_20250627_140000.tar.gz
├── n8n_backup_20250626_140000.tar.gz
└── backup.log
```

### 📱 Telegram Backup

Nếu đã cấu hình, backup sẽ tự động gửi qua Telegram:
- **File backup** (.tar.gz)
- **Thông tin** kích thước & timestamp
- **Notifications** khi backup thành công/thất bại

## 🛠️ Quản Lý Hệ Thống

### 🔧 Lệnh Cơ Bản

```bash
# Xem trạng thái containers
cd /home/n8n && docker-compose ps

# Xem logs realtime
cd /home/n8n && docker-compose logs -f

# Restart toàn bộ
cd /home/n8n && docker-compose restart

# Rebuild containers
cd /home/n8n && docker-compose down && docker-compose up -d --build
```

### 🔍 Troubleshooting

```bash
# Script chẩn đoán tự động
/home/n8n/troubleshoot.sh

# Kiểm tra Docker status
docker ps --filter "name=n8n"

# Kiểm tra logs cụ thể
cd /home/n8n && docker-compose logs n8n
cd /home/n8n && docker-compose logs caddy
cd /home/n8n && docker-compose logs fastapi  # Nếu có News API
```

### 🔄 Updates

```bash
# Update tự động (mỗi 12h)
/home/n8n/update-n8n.sh

# Update yt-dlp manual
docker exec -it n8n_container pip3 install --break-system-packages -U yt-dlp
```

## 📂 Cấu Trúc Thư Mục

```
/home/n8n/
├── docker-compose.yml          # Main config
├── Dockerfile                  # N8N custom image
├── Caddyfile                   # Reverse proxy config
├── backup-workflows.sh         # Auto backup script
├── backup-manual.sh            # Manual backup test
├── update-n8n.sh              # Auto update script
├── troubleshoot.sh             # Diagnostic script
├── telegram_config.txt         # Telegram settings (if enabled)
├── files/                      # N8N data
│   ├── backup_full/           # Backup storage
│   ├── temp/                  # Temporary files
│   └── youtube_content_anylystic/  # Video downloads
└── news_api/                   # News API (if enabled)
    ├── Dockerfile
    ├── requirements.txt
    ├── main.py
    └── start_news_api.sh
```

## ⚡ Performance Tips

### 🚀 Optimization

1. **Memory**: Script tự động setup swap phù hợp
2. **CPU**: Sử dụng single worker cho stability
3. **Disk**: Auto cleanup old backups (30 days)
4. **Network**: Caddy auto-compression enabled

### 📊 Monitoring

```bash
# Resource usage
docker stats --no-stream

# Disk usage
df -h

# Memory usage
free -h

# Swap usage
swapon --show
```

## 🐛 Troubleshooting

### ❌ Lỗi Thường Gặp

**1. Docker daemon not running (WSL)**
```bash
# Khởi động Docker daemon thủ công
sudo dockerd &

# Hoặc restart script
sudo ./auto_cai_dat_n8n.sh
```

**2. Domain chưa trỏ đúng**
```bash
# Kiểm tra DNS
dig yourdomain.com
nslookup yourdomain.com

# Đợi DNS propagation (5-60 phút)
```

**3. Container không start**
```bash
# Xem logs chi tiết
cd /home/n8n && docker-compose logs

# Cleanup và rebuild
docker system prune -f
cd /home/n8n && docker-compose down
docker-compose up -d --build
```

**4. News API authentication failed**
```bash
# Kiểm tra token trong docker-compose.yml
grep NEWS_API_TOKEN /home/n8n/docker-compose.yml

# Test API
curl -X GET "https://api.yourdomain.com/health" \
     -H "Authorization: Bearer YOUR_TOKEN"
```

**5. SSL Certificate issues**
```bash
# Xem Caddy logs
cd /home/n8n && docker-compose logs caddy

# Force SSL renewal
docker-compose restart caddy
```

### 🔧 Recovery Commands

```bash
# Clean reinstall
sudo rm -rf /home/n8n
sudo ./auto_cai_dat_n8n.sh

# Restore from backup
cd /home/n8n/files/backup_full
tar -xzf n8n_backup_YYYYMMDD_HHMMSS.tar.gz
# Copy files back to appropriate locations

# Reset Docker
sudo systemctl stop docker
sudo systemctl start docker
cd /home/n8n && docker-compose up -d
```

## 🌟 Features Roadmap

- [ ] **Multi-domain** support
- [ ] **Database** external storage options
- [ ] **Kubernetes** deployment
- [ ] **Monitoring** dashboard
- [ ] **Auto-scaling** based on load
- [ ] **Plugin** marketplace integration

## 🤝 Contributing

1. Fork repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## 📄 License

MIT License - Xem file [LICENSE](LICENSE)

## 💬 Support

- **Issues**: [GitHub Issues](https://github.com/KalvinThien/install-n8n-ffmpeg/issues)
- **YouTube**: [Kalvin Thien Social](https://www.youtube.com/@kalvinthiensocial)
- **Facebook**: [Ban Thien Handsome](https://www.facebook.com/Ban.Thien.Handsome/)
- **Zalo**: 08.8888.4749

## ⭐ Star History

Nếu script này hữu ích, hãy cho một ⭐ star để ủng hộ!

[![Star History Chart](https://api.star-history.com/svg?repos=KalvinThien/install-n8n-ffmpeg&type=Date)](https://star-history.com/#KalvinThien/install-n8n-ffmpeg&Date)

---

**🚀 Made with ❤️ by Nguyễn Ngọc Thiện - 27/06/2025**

