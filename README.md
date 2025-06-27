# 🚀 N8N Advanced Installation Script

<div align="center">

![N8N Logo](https://n8n.io/favicon.ico) 

[![Bash Script](https://img.shields.io/badge/bash-script-brightgreen.svg)](https://www.gnu.org/software/bash/)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![N8N](https://img.shields.io/badge/N8N-Workflow%20Automation-orange.svg)](https://n8n.io/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**Cài đặt N8N chuyên nghiệp với FFmpeg, yt-dlp, Puppeteer, SSL tự động, Backup Telegram và News Content API**

</div>

## ✨ Tổng quan

Script cài đặt nâng cao này giúp bạn triển khai N8N - nền tảng tự động hóa workflow mạnh mẽ - với đầy đủ các công cụ tiện ích như FFmpeg, yt-dlp, và Puppeteer. Script đã được tối ưu để vận hành mượt mà trên các phiên bản Ubuntu mới nhất, tự động cấu hình SSL với Caddy, và nay được tăng cường với **hệ thống backup tin cậy hơn cùng tùy chọn gửi thông báo và file backup qua Telegram**, **API lấy nội dung tin tức với newspaper4k** và **xử lý lỗi Puppeteer thông minh**.


![Terminal Preview](https://raw.githubusercontent.com/n8n-io/n8n/master/assets/n8n-screenshot.png)

## 🔥 Tính năng Mới & Nâng Cao

### 🎯 **Tính năng cốt lõi N8N**
- 🛠️ **Cài đặt tự động** N8N với Docker và Docker Compose
- 🚀 **Ưu tiên cài đặt nhanh**: Cung cấp lệnh cài đặt nhanh chóng và tiện lợi
- 🔒 **SSL tự động** với Caddy (không cần cấu hình thủ công!)
- 🎬 **FFmpeg tích hợp** cho xử lý media
- 📹 **yt-dlp** cho tải video từ YouTube và nhiều nền tảng khác
- 🌐 **Puppeteer với xử lý lỗi thông minh** cho tự động hóa trình duyệt web

### 💾 **Hệ thống Backup nâng cao**
- 💾 **Backup tự động hàng ngày (đã cải tiến)**: Sao lưu toàn bộ workflow và credentials
- 📲 **Thông báo và gửi backup qua Telegram**: Tùy chọn cấu hình để nhận thông báo và file backup
- 📦 **Nén file backup**: Các file backup được nén dưới dạng `.tar.gz` để tiết kiệm dung lượng
- 📜 **Log chi tiết**: Ghi log đầy đủ cho quá trình backup và cập nhật
- 🔄 **Cleanup tự động**: Dọn dẹp containers cũ và xử lý xung đột

### 📰 **News Content API (MỚI)**
- 🗞️ **API lấy nội dung tin tức** với newspaper4k và fake-useragent
- 📡 **RSS Feed Parser**: Phân tích và crawl nhiều bài viết từ RSS feeds
- 🔐 **Bảo mật Bearer Token**: API được bảo vệ với authentication
- 🚀 **FastAPI Performance**: API chạy với FastAPI, tốc độ cao
- 📚 **Tài liệu API tích hợp**: HTML docs thay vì Swagger mặc định
- 🌐 **Subdomain riêng**: API chạy trên subdomain riêng (api.domain.com)

### 🛡️ **Tính năng bảo vệ & tối ưu**
- 🔄 **Cập nhật tự động** N8N và các thành phần
- 📊 **Tự động cấu hình swap** dựa trên RAM của máy chủ
- ⚠️ **Xử lý lỗi thông minh** và reporting
- 🔍 **Kiểm tra và xác minh domain** tự động
- 🇻🇳 **Giao diện tiếng Việt hoàn chỉnh**

## 💻 Yêu cầu

- Ubuntu 20.04 LTS hoặc mới hơn
- Ít nhất 1GB RAM (khuyến nghị 2GB hoặc cao hơn)
- Tên miền trỏ về địa chỉ IP của máy chủ
- **Subdomain cho API**: `api.yourdomain.com` (tùy chọn, cho News API)
- Quyền sudo/root
- Kết nối internet (cần thiết cho việc tải gói, Docker images và gửi thông báo Telegram)
- Các gói tiện ích: `curl`, `dig`, `cron`, `jq`, `tar`, `gzip`, `bc` (script sẽ cố gắng tự cài đặt nếu thiếu)

## 📋 Hướng dẫn cài đặt

### 🚀 Cài đặt nhanh (Khuyến nghị)

Sao chép và chạy lệnh sau trực tiếp trên terminal của server:

```bash
cd /tmp && curl -sSL https://raw.githubusercontent.com/KalvinThien/install-n8n-ffmpeg/main/auto_cai_dat_n8n.sh | tr -d '\r' > install_n8n.sh && chmod +x install_n8n.sh && sudo bash install_n8n.sh
```

### Cài đặt thủ công

```bash
# Tải script
wget -O auto_cai_dat_n8n.sh https://raw.githubusercontent.com/KalvinThien/install-n8n-ffmpeg/main/auto_cai_dat_n8n.sh

# Cấp quyền thực thi
chmod +x auto_cai_dat_n8n.sh

# Chạy script
sudo ./auto_cai_dat_n8n.sh
```

Trong quá trình cài đặt, bạn sẽ được hỏi:
- Tên miền của bạn
- Có muốn cấu hình News Content API không
- Có muốn cấu hình gửi backup qua Telegram không

### 🔧 Khắc phục lỗi API Subdomain

Nếu API subdomain bị lỗi `ERR_QUIC_PROTOCOL_ERROR`, hãy chạy script troubleshoot:

```bash
# Chạy từ thư mục N8N
cd /home/n8n  # hoặc thư mục cài đặt của bạn
sudo ./troubleshoot.sh api
```

Hoặc kiểm tra thủ công:

```bash
# Kiểm tra DNS
dig api.yourdomain.com

# Kiểm tra containers
docker compose ps

# Khởi động lại Caddy
docker compose restart caddy

# Kiểm tra logs
docker compose logs caddy
docker compose logs fastapi
```

### 📰 Sử dụng News Content API

Sau khi cài đặt, API sẽ có sẵn tại `https://api.yourdomain.com` với các endpoint:

```bash
# Lấy nội dung bài viết
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "https://api.yourdomain.com/article?url=https://example.com/news"

# Crawl nhiều bài viết từ RSS
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "https://api.yourdomain.com/feed?url=https://example.com/rss&limit=10"

# Xem tài liệu API
https://api.yourdomain.com/docs
```

### Hướng dẫn cấu hình gửi Backup qua Telegram

Nếu bạn chọn **Có (y)** khi được hỏi về việc cấu hình gửi backup qua Telegram:

1. **Telegram Bot Token**:
   - Mở Telegram, tìm kiếm `BotFather`
   - Gõ `/start` và `/newbot`
   - Đặt tên bot (ví dụ: `N8N Backup Bot`)
   - Đặt username (phải kết thúc bằng `bot`, ví dụ: `MyN8NBackup_bot`)
   - Sao chép **HTTP API token** được cung cấp

2. **Telegram Chat ID**:
   - Tìm kiếm bot `@userinfobot` và gõ `/start`
   - Bot sẽ trả về `Id` - đây chính là Chat ID của bạn

## 🔧 Cấu trúc thư mục (ví dụ với thư mục cài đặt mặc định `/home/n8n`)

```
/home/n8n/
├── Dockerfile                # Dockerfile tùy chỉnh với FFmpeg, yt-dlp và Puppeteer
├── docker-compose.yml        # Cấu hình Docker Compose với News API
├── Caddyfile                 # Cấu hình Caddy Server (SSL + API subdomain)
├── fastapi/                  # News Content API
│   ├── main.py              # FastAPI application
│   ├── requirements.txt     # Python dependencies
│   └── docs.html           # API documentation
├── update-n8n.sh            # Script cập nhật tự động N8N
├── backup-workflows.sh      # Script sao lưu tự động workflows và credentials
├── troubleshoot.sh          # Script chẩn đoán và khắc phục sự cố
├── telegram_backup.conf     # (TÙY CHỌN) File cấu hình Telegram Bot Token và Chat ID
├── database.sqlite          # File database của N8N
├── encryptionKey            # Khóa mã hóa cho credentials của N8N
└── files/
    ├── temp/                # Thư mục tạm thời cho N8N
    ├── youtube_content_anylystic/ # Nơi lưu video YouTube
    ├── backup_full/         # Nơi lưu trữ các file backup .tar.gz hàng ngày
    │   └── backup.log       # Log chi tiết của quá trình backup
    └── puppeteer_status.txt # Trạng thái cài đặt Puppeteer
```

## 📌 Sau khi cài đặt

### 🌐 Truy cập dịch vụ
- **N8N**: `https://yourdomain.com`
- **News API**: `https://api.yourdomain.com` (Bearer Token required)
- **API Docs**: `https://api.yourdomain.com/docs`

### ⚙️ Hoạt động tự động
- **Sao lưu tự động**: Chạy hàng ngày vào lúc 2 giờ sáng
- **Kiểm tra cập nhật**: Diễn ra mỗi 12 giờ
- **Cleanup containers**: Tự động dọn dẹp containers cũ
- **Telegram notifications**: Thông báo trạng thái backup (nếu được cấu hình)

## ⚙️ Cấu hình Swap tự động 

Script tự động phân tích RAM trên máy chủ và thiết lập swap tối ưu:

| RAM     | Kích thước swap |
|---------|-----------------|
| ≤ 2GB   | 2x RAM          |
| 2GB-8GB | 1x RAM          |
| > 8GB   | 4GB cố định     |

## 🚨 Xử lý sự cố

### 🔧 Lệnh chẩn đoán nhanh
```bash
# Chạy troubleshoot tự động
sudo ./troubleshoot.sh

# Kiểm tra specific service
sudo ./troubleshoot.sh api      # Kiểm tra News API
sudo ./troubleshoot.sh backup   # Kiểm tra Backup
sudo ./troubleshoot.sh puppeteer # Kiểm tra Puppeteer
```

### 🐛 Các vấn đề thường gặp
- **Docker không khởi động**: `docker compose logs n8n`
- **SSL không hoạt động**: `docker compose logs caddy`
- **API subdomain lỗi 502**: Kiểm tra DNS và khởi động lại Caddy
- **Backup không gửi qua Telegram**: Kiểm tra `telegram_backup.conf` và kết nối internet
- **Puppeteer không hoạt động**: Xem `files/puppeteer_status.txt`

## 🔧 Quản Lý Bearer Token

### Đổi Bearer Token cho News API {#change-token}

Nếu bạn muốn thay đổi Bearer Token cho News API (vì lý do bảo mật hoặc token bị lộ):

```bash
# Chạy script đổi token tự động
cd /home/n8n  # hoặc thư mục cài đặt của bạn
./change-api-token.sh
```

**Script sẽ thực hiện:**
- Hiển thị token hiện tại
- Cho phép nhập token mới hoặc tạo tự động
- Cập nhật file cấu hình
- Restart FastAPI container
- Hiển thị token mới

**Sau khi đổi token:**
1. Cập nhật token mới trong tất cả N8N workflows
2. Kiểm tra API hoạt động: `https://api.yourdomain.com/health`
3. Test với workflow mẫu

### Kiểm tra Token hiện tại

```bash
# Xem token hiện tại
cd /home/n8n
cat fastapi/.env
```

### Hướng dẫn đổi token thủ công

Nếu script tự động không hoạt động, bạn có thể đổi token thủ công:

```bash
# 1. Tạo token mới
NEW_TOKEN=$(openssl rand -hex 16)
echo "Token mới: $NEW_TOKEN"

# 2. Cập nhật file .env
echo "API_TOKEN=\"$NEW_TOKEN\"" > /home/n8n/fastapi/.env

# 3. Cập nhật docker-compose.yml
sed -i "s/API_TOKEN=.*/API_TOKEN=$NEW_TOKEN/" /home/n8n/docker-compose.yml

# 4. Restart FastAPI container
cd /home/n8n
docker-compose restart fastapi

# 5. Kiểm tra API
curl -H "Authorization: Bearer $NEW_TOKEN" \
  "https://api.yourdomain.com/health"
```

### Lưu ý bảo mật

- **Không bao giờ chia sẻ Bearer Token** với người khác
- **Thay đổi token định kỳ** (mỗi 3-6 tháng)
- **Sử dụng token mạnh** (ít nhất 16 ký tự)
- **Không commit token** vào git repository
- **Backup token** ở nơi an toàn

## 👨‍💻 Thông Tin Tác Giả

**Nguyễn Ngọc Thiện**
- 📺 **YouTube**: [Kalvin Thien Social](https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1) - **HẢY ĐĂNG KÝ ĐỂ ỦNG HỘ!**
- 📘 **Facebook**: [Ban Thien Handsome](https://www.facebook.com/Ban.Thien.Handsome/)
- 📱 **Zalo/Phone**: 08.8888.4749
- 🎬 **N8N Playlist**: [N8N Tutorials](https://www.youtube.com/@kalvinthiensocial/playlists)
- 💻 **GitHub**: [KalvinThien](https://github.com/KalvinThien)

### 💝 Donate

Nếu bạn thấy dự án này hữu ích, hãy xem xét hỗ trợ để phát triển thêm tính năng mới:

- **TP Bank**: 08.8888.4749
- **Chủ tài khoản**: Nguyễn Ngọc Thiện

<div align="center">
  <img src="https://github.com/KalvinThien/install-n8n-ffmpeg/blob/main/qrcode.png?raw=true" alt="QR Code Donate" width="400" />
</div>

## 📜 Miễn trừ trách nhiệm

- Script này được cung cấp "NGUYÊN TRẠNG" mà không có bất kỳ bảo đảm nào, dù rõ ràng hay ngụ ý
- Người dùng hoàn toàn chịu trách nhiệm về việc sử dụng script này và mọi hậu quả có thể phát sinh
- Luôn đảm bảo bạn đã sao lưu dữ liệu quan trọng trước khi chạy bất kỳ script nào có quyền truy cập hệ thống cao
- Tác giả không chịu trách nhiệm cho bất kỳ mất mát dữ liệu, gián đoạn dịch vụ hoặc thiệt hại nào khác do việc sử dụng script này gây ra
- Vui lòng tự kiểm tra và hiểu rõ script trước khi thực thi trên môi trường production

## 📝 Changelog

### v2.0.0 (27/06/2025) - Bản cập nhật hiện tại
- 🆕 **News Content API Integration**:
  - Tích hợp FastAPI + newspaper4k + fake-useragent để tạo API lấy nội dung tin tức
  - API chạy trên subdomain riêng (api.domain.com)
  - Bảo mật với Bearer Token authentication
  - Hỗ trợ crawl nội dung bài viết và RSS feeds
  - Tài liệu API HTML tùy chỉnh
- 🛡️ **Enhanced Error Handling & Troubleshooting**:
  - Xử lý lỗi Puppeteer thông minh, không gián đoạn cài đặt
  - Script troubleshoot tự động chẩn đoán và khắc phục sự cố
  - Cleanup function tự động dọn dẹp containers cũ/xung đột
  - File trạng thái Puppeteer để tracking
- 🔧 **Infrastructure Improvements**:
  - Cập nhật Caddyfile để hỗ trợ API subdomain
  - Enhanced Docker Compose với service dependencies
  - Improved container monitoring và health checks
  - Better error logging và status reporting

### v1.4.1 (15/05/2025)
- ✅ **Cải tiến Backup Lớn & Tích hợp Telegram**:
  - Sửa lỗi logic backup workflows, database và encryption key
  - File backup được nén dưới dạng `.tar.gz`
  - Tùy chọn gửi backup qua Telegram với hướng dẫn chi tiết
  - Log chi tiết và cleanup backup cũ an toàn
- 🇻🇳 **Việt hóa hoàn toàn**: Tất cả thông báo bằng tiếng Việt
- 🛠️ **Cải tiến Script Cài đặt**: Kiểm tra dependencies mạnh mẽ hơn

### v1.3.0 (26/03/2025)
- ✅ Thêm tính năng tự động cấu hình swap
- 🔄 Cập nhật cách cài đặt yt-dlp để tương thích với Python mới
- 🔒 Cập nhật phương pháp thêm khóa GPG cho Docker

### v1.2.0 (15/02/2025)
- ✅ Thêm tích hợp Puppeteer
- 🔄 Cải thiện hệ thống sao lưu và khôi phục
- 🔧 Cập nhật cấu hình Docker Compose

### v1.1.0 (10/01/2025)
- ✅ Thêm hỗ trợ FFmpeg và yt-dlp
- 🔄 Tự động cập nhật N8N
- 🔒 Tích hợp Caddy cho SSL tự động

### v1.0.0 (05/12/2024)
- 🚀 Phát hành lần đầu
- ✅ Cài đặt N8N cơ bản với Docker
- 🔧 Cấu hình cơ bản và hướng dẫn

---

<div align="center">
  <p>
    <sub>🚀 **Hãy đăng ký kênh YouTube để ủng hộ tác giả!** 🚀</sub><br />
    <sub>📺 <a href="https://www.youtube.com/@kalvinthiensocial?sub_confirmation=1">Kalvin Thien Social</a></sub><br />
    <sub>© 2025 Nguyễn Ngọc Thiện - Mọi quyền được bảo lưu</sub>
  </p>
</div>

