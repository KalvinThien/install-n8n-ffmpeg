# 🚀 N8N Advanced Installation Script

<div align="center">

![N8N Logo](https://n8n.io/favicon.ico) 

[![Bash Script](https://img.shields.io/badge/bash-script-brightgreen.svg)](https://www.gnu.org/software/bash/)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![N8N](https://img.shields.io/badge/N8N-Workflow%20Automation-orange.svg)](https://n8n.io/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**Cài đặt N8N chuyên nghiệp với FFmpeg, yt-dlp, Puppeteer và SSL tự động**

</div>

## ✨ Tổng quan

Script cài đặt nâng cao này giúp bạn triển khai N8N - nền tảng tự động hóa workflow mạnh mẽ - với đầy đủ các công cụ tiện ích như FFmpeg, yt-dlp, và Puppeteer. Script đã được tối ưu để vận hành mượt mà trên các phiên bản Ubuntu mới nhất và tự động cấu hình SSL với Caddy để đảm bảo kết nối an toàn.

![Terminal Preview](https://raw.githubusercontent.com/n8n-io/n8n/master/assets/n8n-screenshot.png)

## 🔥 Tính năng

- 🛠️ **Cài đặt tự động** N8N với Docker và Docker Compose
- 🔒 **SSL tự động** với Caddy (không cần cấu hình thủ công!)
- 🎬 **FFmpeg tích hợp** cho xử lý media
- 📹 **yt-dlp** cho tải video từ YouTube và nhiều nền tảng khác
- 🌐 **Puppeteer** cho tự động hóa trình duyệt web
- 💾 **Backup tự động** workflow và credentials
- 🔄 **Cập nhật tự động** N8N và các thành phần
- 📊 **Tự động cấu hình swap** dựa trên RAM của máy chủ
- ⚠️ **Xử lý lỗi thông minh** và reporting
- 🔍 **Kiểm tra và xác minh domain** tự động

## 💻 Yêu cầu

- Ubuntu 20.04 LTS hoặc mới hơn
- Ít nhất 1GB RAM (khuyến nghị 2GB hoặc cao hơn)
- Tên miền trỏ về địa chỉ IP của máy chủ
- Quyền sudo/root
- Kết nối internet

## 📋 Hướng dẫn cài đặt

### Cài đặt cơ bản

```bash
# Tải script
wget -O n8n-install.sh https://raw.githubusercontent.com/KalvinThien/install-n8n-ffmpeg/main/auto_cai_dat_n8n.sh

# Cấp quyền thực thi
chmod +x n8n-install.sh

# Chạy script
sudo ./n8n-install.sh
```
# Cài Tự Động
```bash
cd /tmp && curl -sSL https://raw.githubusercontent.com/KalvinThien/install-n8n-ffmpeg/main/auto_cai_dat_n8n.sh | tr -d '\r' > install_n8n.sh && chmod +x install_n8n.sh && sudo bash install_n8n.sh
```
### Tùy chọn nâng cao

```bash
# Chỉ định thư mục cài đặt khác
sudo ./n8n-install.sh -d /opt/n8n

# Bỏ qua cài đặt Docker (nếu đã cài)
sudo ./n8n-install.sh -s

# Xem trợ giúp
sudo ./n8n-install.sh -h
```

## 🔧 Cấu trúc thư mục

```
/home/n8n/
├── Dockerfile                # Dockerfile tùy chỉnh với FFmpeg, yt-dlp và Puppeteer
├── docker-compose.yml        # Cấu hình Docker Compose
├── Caddyfile                 # Cấu hình Caddy Server (SSL)
├── update-n8n.sh             # Script cập nhật tự động
├── backup-workflows.sh       # Script sao lưu tự động
└── files/
    ├── temp/                 # Thư mục tạm thời
    ├── youtube_content_anylystic/ # Nơi lưu video YouTube  
    └── backup_full/          # Sao lưu workflows
```

## 📌 Sau khi cài đặt

- Truy cập N8N qua `https://your-domain.com`
- Sao lưu tự động được cấu hình chạy hàng ngày lúc 2h sáng
- Kiểm tra cập nhật diễn ra mỗi 12 giờ 
- Xem logs tại `/home/n8n/update.log` và `/home/n8n/files/backup_full/backup.log`

## ⚙️ Cấu hình Swap tự động 

Script tự động phân tích RAM trên máy chủ và thiết lập swap tối ưu:

| RAM | Kích thước swap |
|-----|-----------------|
| ≤ 2GB | 2x RAM |
| 2GB-8GB | 1x RAM |
| > 8GB | 4GB cố định |

Các tham số swappiness và cache pressure được điều chỉnh để hiệu suất tốt nhất.

## 🚨 Xử lý sự cố

- **Docker không khởi động**: Kiểm tra logs bằng lệnh `docker logs n8n`
- **SSL không hoạt động**: Kiểm tra Caddy logs bằng `docker logs caddy`
- **Không tải được video YouTube**: Cập nhật yt-dlp bằng lệnh thủ công `sudo /opt/yt-dlp-venv/bin/pip install -U yt-dlp`
- **Vấn đề khác**: Xem thêm trong logs hoặc liên hệ hỗ trợ

## 👨‍💻 Thông tin và hỗ trợ

### Liên hệ

- **Zalo/Phone**: 0888884749
- **GitHub**: [Github/kalvinThien](https://github.com/KalvinThien)

### Donate

Nếu bạn thấy dự án này hữu ích, hãy xem xét hỗ trợ để phát triển thêm tính năng mới:

- **TP Bank**: 0888884749
- **Chủ tài khoản**: Nguyễn Ngọc Thiện

<div align="center">
  <img src="https://github.com/KalvinThien/install-n8n-ffmpeg/blob/main/qrcode.png?raw=true" alt="QR Code Donate" width="400">
</div>

## 📝 Changelog

### v1.3.0 (26/03/2025)
- ✅ Thêm tính năng tự động cấu hình swap
- 🔄 Cập nhật cách cài đặt yt-dlp để tương thích với Python mới
- 🔒 Cập nhật phương pháp thêm khóa GPG cho Docker
- 🐛 Sửa lỗi trong Dockerfile cho Alpine Linux

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
    <sub>Script gốc được phát triển bởi Nguyễn Ngọc Thiện</sub><br>
    <sub>© 2025 Nguyễn Ngọc Thiện - Mọi quyền được bảo lưu</sub>
  </p>
  
  [![Made with Love](https://img.shields.io/badge/Made%20with-❤️-red.svg)](https://github.com/your-username)
</div>
