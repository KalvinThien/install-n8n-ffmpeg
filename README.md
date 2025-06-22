# 🚀 Script Cài Đặt N8N Tự Động - Phiên Bản Cải Tiến 2.0

## 👨‍💻 Thông Tin Tác Giả

**Nguyễn Ngọc Thiện**
- 📺 **YouTube**: [Kalvin Thien Social](https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1) - **HẢY ĐĂNG KÝ ĐỂ ỦNG HỘ!**
- 📘 **Facebook**: [Ban Thien Handsome](https://www.facebook.com/Ban.Thien.Handsome/)
- 📱 **Zalo/Phone**: 08.8888.4749
- 🎬 **N8N Playlist**: [N8N Tutorials](https://www.youtube.com/@kalvinthiensocial/playlists)

---

## ⭐ Tính Năng Mới Trong Phiên Bản 2.0

### 🔥 Cải Tiến Chính
- ✅ **Sửa lỗi backup tự động** - Backup workflow và credentials hoạt động 100%
- ✅ **Telegram Bot Integration** - Tự động gửi backup qua Telegram hàng ngày
- ✅ **FastAPI Article Extractor** - API lấy nội dung bài viết từ URL bất kỳ
- ✅ **Improved UI/UX** - Giao diện đẹp với emoji và màu sắc
- ✅ **Better Error Handling** - Xử lý lỗi thông minh, không dừng cài đặt
- ✅ **Detailed Logging** - Log chi tiết mọi hoạt động

### 🛠️ Tính Năng Kỹ Thuật
- 🐳 **Docker Compose v2** support
- 🔄 **Smart Backup System** với nén .tar.gz
- 📱 **Telegram Notifications** cho backup và update
- ⚡ **FastAPI + Newspaper4k** cho việc trích xuất nội dung
- 🎯 **Random User-Agent** chống block website
- 🔐 **Bearer Token Authentication** bảo mật API
- 📊 **Status Monitoring Scripts** kiểm tra trạng thái hệ thống

---

## 🚀 Cài Đặt Nhanh

### Yêu Cầu Hệ Thống
- Ubuntu 20.04+ hoặc Debian 11+
- RAM: Tối thiểu 2GB (khuyến nghị 4GB+)
- Disk: Tối thiểu 20GB
- Domain đã trỏ về IP server

### Lệnh Cài Đặt Một Dòng
```bash
curl -fsSL https://raw.githubusercontent.com/username/repo/main/n8n_install_auto_improved.sh | sudo bash
```

### Hoặc Tải Về và Chạy
```bash
wget https://raw.githubusercontent.com/username/repo/main/n8n_install_auto_improved.sh
chmod +x n8n_install_auto_improved.sh
sudo ./n8n_install_auto_improved.sh
```

---

## 🎛️ Tùy Chọn Cài Đặt

### Tham Số Dòng Lệnh
```bash
# Hiển thị trợ giúp
sudo ./n8n_install_auto_improved.sh --help

# Chỉ định thư mục cài đặt
sudo ./n8n_install_auto_improved.sh --dir /opt/n8n

# Bỏ qua cài đặt Docker (nếu đã có)
sudo ./n8n_install_auto_improved.sh --skip-docker

# Kích hoạt Telegram backup
sudo ./n8n_install_auto_improved.sh --enable-telegram

# Kích hoạt FastAPI
sudo ./n8n_install_auto_improved.sh --enable-fastapi

# Kết hợp nhiều tùy chọn
sudo ./n8n_install_auto_improved.sh --dir /opt/n8n --enable-telegram --enable-fastapi
```

---

## 📱 Cấu Hình Telegram Bot (Tùy Chọn)

### Bước 1: Tạo Bot
1. Mở Telegram, tìm `@BotFather`
2. Gửi `/newbot`
3. Đặt tên cho bot của bạn
4. Lưu `Bot Token`

### Bước 2: Lấy Chat ID
1. Gửi tin nhắn cho bot vừa tạo
2. Truy cập: `https://api.telegram.org/bot<BOT_TOKEN>/getUpdates`
3. Tìm `chat.id` trong response

### Bước 3: Cấu Hình
Khi chạy script, chọn `y` cho tùy chọn Telegram và nhập:
- Bot Token
- Chat ID

### Tính Năng Telegram
- 📦 Tự động gửi backup hàng ngày
- 🔄 Thông báo khi có update N8N
- ⚠️ Cảnh báo khi có lỗi backup
- 📊 File backup nhỏ hơn 50MB sẽ được gửi trực tiếp

---

## ⚡ FastAPI Article Extractor

### Tính Năng
- 🎯 Trích xuất tiêu đề, nội dung, tác giả từ bất kỳ URL nào
- 🤖 Tóm tắt tự động bằng AI
- 🔤 Trích xuất từ khóa quan trọng
- 🌐 Hỗ trợ đa ngôn ngữ (Việt, Anh, ...)
- 🎭 Random User-Agent chống block
- 🔒 Bearer Token authentication
- 📚 Swagger UI documentation

### API Endpoints
```
GET  /                    # Trang chủ với hướng dẫn
POST /extract             # Trích xuất 1 URL
POST /extract/batch       # Trích xuất nhiều URL (max 10)
GET  /health              # Health check
GET  /stats               # Thống kê API
GET  /docs                # Swagger documentation
GET  /redoc               # ReDoc documentation
```

### Sử Dụng Với N8N
1. Thêm **HTTP Request** node
2. **URL**: `https://api.yourdomain.com/extract`
3. **Method**: `POST`
4. **Headers**: 
   ```
   Authorization: Bearer YOUR_PASSWORD
   Content-Type: application/json
   ```
5. **Body**:
   ```json
   {
     "url": "https://vnexpress.net/sample-article",
     "language": "vi"
   }
   ```

### Response Example
```json
{
  "success": true,
  "url": "https://vnexpress.net/sample-article",
  "title": "Tiêu đề bài viết",
  "text": "Nội dung đầy đủ của bài viết...",
  "summary": "Tóm tắt tự động...",
  "authors": ["Tác giả 1", "Tác giả 2"],
  "publish_date": "2024-01-15T10:30:00",
  "keywords": ["từ khóa 1", "từ khóa 2"],
  "processing_time": 2.34
}
```

---

## 💾 Hệ Thống Backup Cải Tiến

### Tính Năng Backup
- ✅ **Tự động hàng ngày** lúc 2:00 sáng
- ✅ **Backup toàn bộ workflows** (từng file riêng + file tổng hợp)
- ✅ **Backup credentials** (database.sqlite, encryptionKey, config)
- ✅ **Nén .tar.gz** tiết kiệm dung lượng
- ✅ **Giữ 30 backup gần nhất** tự động xóa cũ
- ✅ **Log chi tiết** mọi hoạt động
- ✅ **Gửi qua Telegram** (nếu được kích hoạt)

### Thư Mục Backup
```
/home/n8n/files/backup_full/
├── n8n_backup_20240115_020000.tar.gz
├── n8n_backup_20240114_020000.tar.gz
├── ...
└── backup.log
```

### Chạy Backup Thủ Công
```bash
cd /home/n8n
./backup-workflows.sh
```

### Kiểm Tra Log Backup
```bash
tail -f /home/n8n/files/backup_full/backup.log
```

---

## 🔄 Hệ Thống Cập Nhật Tự Động

### Tính Năng Update
- 🔄 **Kiểm tra mỗi 12 giờ** image N8N mới
- 📦 **Tự động backup** trước khi update  
- 🚀 **Build và restart** container khi có update
- 📱 **Thông báo Telegram** khi có update
- 📺 **Cập nhật yt-dlp** định kỳ

### Chạy Update Thủ Công
```bash
cd /home/n8n
./update-n8n.sh
```

### Kiểm Tra Log Update
```bash
tail -f /home/n8n/update.log
```

---

## 📊 Monitoring & Maintenance

### Script Kiểm Tra Trạng Thái
```bash
cd /home/n8n
./check-status.sh
```

### Xem Logs Container
```bash
cd /home/n8n

# Xem log N8N
docker-compose logs -f n8n

# Xem log Caddy
docker-compose logs -f caddy

# Xem log FastAPI (nếu có)
docker-compose logs -f fastapi

# Xem tất cả logs
docker-compose logs -f
```

### Restart Services
```bash
cd /home/n8n

# Restart toàn bộ
docker-compose restart

# Restart riêng lẻ
docker-compose restart n8n
docker-compose restart caddy
docker-compose restart fastapi
```

---

## 🏗️ Cấu Trúc Thư Mục

```
/home/n8n/
├── 📄 docker-compose.yml          # Cấu hình Docker services
├── 📄 Dockerfile                  # N8N với FFmpeg, yt-dlp, Puppeteer
├── 📄 Dockerfile.fastapi          # FastAPI container
├── 📄 Caddyfile                   # Reverse proxy + SSL
├── 📄 fastapi_app.py              # Ứng dụng FastAPI
├── 📄 fastapi_requirements.txt    # Dependencies FastAPI
├── 📄 telegram_config.conf        # Cấu hình Telegram
├── 📄 backup-workflows.sh         # Script backup cải tiến
├── 📄 update-n8n.sh               # Script update tự động
├── 📄 check-status.sh             # Script kiểm tra trạng thái
├── 📄 backup.log                  # Log backup
├── 📄 update.log                  # Log update
├── 📁 files/                      # Data files
│   ├── 📁 backup_full/            # Thư mục backup chính
│   ├── 📁 youtube_content_anylystic/ # Video downloads
│   └── 📁 temp/                   # Temporary files
├── 📁 fastapi_logs/               # FastAPI logs
└── 📁 templates/                  # HTML templates
    └── index.html                 # FastAPI homepage
```

---

## 🌐 Truy Cập Services

### URLs Mặc Định
- **N8N**: `https://yourdomain.com`
- **FastAPI**: `https://api.yourdomain.com`
- **API Docs**: `https://api.yourdomain.com/docs`

### Ports (Backup Access)
- **N8N**: `http://yourdomain.com:5678`
- **FastAPI**: `http://yourdomain.com:8000`
- **Caddy Admin**: `http://yourdomain.com:2019`

---

## 🛠️ Troubleshooting

### Lỗi Thường Gặp

#### 1. Container không khởi động
```bash
# Kiểm tra logs
cd /home/n8n
docker-compose logs

# Build lại image
docker-compose build --no-cache
docker-compose up -d
```

#### 2. SSL không hoạt động
```bash
# Kiểm tra Caddy logs
docker-compose logs caddy

# Restart Caddy
docker-compose restart caddy
```

#### 3. Backup không gửi được qua Telegram
```bash
# Kiểm tra config
cat /home/n8n/telegram_config.conf

# Test thủ công
curl -X POST "https://api.telegram.org/bot<BOT_TOKEN>/sendMessage" \
  -d chat_id="<CHAT_ID>" \
  -d text="Test message"
```

#### 4. FastAPI không hoạt động
```bash
# Kiểm tra logs
docker-compose logs fastapi

# Restart service
docker-compose restart fastapi
```

### Commands Hữu Ích

```bash
# Kiểm tra disk space
df -h

# Kiểm tra RAM
free -h

# Kiểm tra processes
ps aux | grep docker

# Cleanup Docker
docker system prune -a

# Reset toàn bộ (XÓA DỮ LIỆU!)
cd /home/n8n
docker-compose down -v
docker system prune -a -f
```

---

## 🔐 Bảo Mật

### Recommendations
- 🔒 Đổi mật khẩu mặc định của N8N
- 🔑 Sử dụng mật khẩu mạnh cho FastAPI Bearer Token
- 🛡️ Cấu hình firewall chỉ mở port cần thiết
- 📱 Bảo mật Bot Token Telegram
- 🔄 Cập nhật định kỳ

### Firewall Setup
```bash
# Chỉ mở port cần thiết
ufw allow 22    # SSH
ufw allow 80    # HTTP
ufw allow 443   # HTTPS
ufw enable
```

---

## 🆘 Hỗ Trợ

### Liên Hệ Tác Giả
- 📞 **Zalo/Phone**: 08.8888.4749
- 📘 **Facebook**: [Ban Thien Handsome](https://www.facebook.com/Ban.Thien.Handsome/)
- 🎥 **YouTube**: [Kalvin Thien Social](https://www.youtube.com/@kalvinthiensocial)

### Cách Nhận Hỗ Trợ
1. 🎥 Xem video hướng dẫn trên YouTube
2. 💬 Comment dưới video
3. 📱 Nhắn tin Zalo: 08.8888.4749
4. 📘 Inbox Facebook

### Đóng Góp & Báo Lỗi
- 🐛 Báo lỗi qua GitHub Issues
- 💡 Đề xuất tính năng mới
- 🤝 Contribute code qua Pull Request

---

## 📜 Changelog

### Version 2.0.0 (2024-01-15)
- ✅ Sửa lỗi backup script không hoạt động
- ✅ Thêm Telegram Bot integration
- ✅ Thêm FastAPI Article Extractor
- ✅ Cải thiện UI/UX với emoji và màu sắc
- ✅ Better error handling
- ✅ Improved logging system
- ✅ Docker Compose v2 support
- ✅ Smart backup với nén .tar.gz
- ✅ Status monitoring scripts

### Version 1.x
- ✅ N8N với FFmpeg, yt-dlp, Puppeteer
- ✅ SSL tự động với Caddy
- ✅ Docker containerization
- ✅ Basic backup system

---

## 📄 License

Dự án này được phát hành dưới giấy phép MIT. Xem file [LICENSE](LICENSE) để biết thêm chi tiết.

---

## 🙏 Cảm Ơn

- 💝 Cảm ơn cộng đồng N8N Việt Nam
- 🌟 Cảm ơn các subscribers kênh YouTube
- ❤️ Cảm ơn những người đã test và feedback

---

## 🔥 Kêu Gọi Hành Động

### 🎥 ĐĂNG KÝ KÊNH YOUTUBE
👆 **[CLICK ĐỂ ĐĂNG KÝ](https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1)** 👆

### 💝 Chia Sẻ Script
Nếu script này hữu ích, hãy chia sẻ cho bạn bè!

### 📱 Theo Dõi Updates
- 🔔 Bật thông báo YouTube để không bỏ lỡ video mới
- 📘 Follow Facebook để cập nhật script mới

---

**Made with ❤️ by Nguyễn Ngọc Thiện**
*Script phát triển cho cộng đồng N8N Việt Nam* 
