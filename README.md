# 🚀 N8N Advanced Installation Script

<div align="center">

![N8N Logo](https://n8n.io/favicon.ico) 

[![Bash Script](https://img.shields.io/badge/bash-script-brightgreen.svg)](https://www.gnu.org/software/bash/)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![N8N](https://img.shields.io/badge/N8N-Workflow%20Automation-orange.svg)](https://n8n.io/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**Cài đặt N8N chuyên nghiệp với FFmpeg, yt-dlp, Puppeteer, SSL tự động và Backup Telegram nâng cao**

</div>

## ✨ Tổng quan

Script cài đặt nâng cao này giúp bạn triển khai N8N - nền tảng tự động hóa workflow mạnh mẽ - với đầy đủ các công cụ tiện ích như FFmpeg, yt-dlp, và Puppeteer. Script đã được tối ưu để vận hành mượt mà trên các phiên bản Ubuntu mới nhất, tự động cấu hình SSL với Caddy, và nay được tăng cường với **hệ thống backup tin cậy hơn cùng tùy chọn gửi thông báo và file backup qua Telegram**.


![Terminal Preview](https://raw.githubusercontent.com/n8n-io/n8n/master/assets/n8n-screenshot.png)

## 🔥 Tính năng

- 🛠️ **Cài đặt tự động** N8N với Docker và Docker Compose.
- 🚀 **Ưu tiên cài đặt nhanh**: Cung cấp lệnh cài đặt nhanh chóng và tiện lợi.
- 🔒 **SSL tự động** với Caddy (không cần cấu hình thủ công!).
- 🎬 **FFmpeg tích hợp** cho xử lý media.
- 📹 **yt-dlp** cho tải video từ YouTube và nhiều nền tảng khác.
- 🌐 **Puppeteer** cho tự động hóa trình duyệt web.
- 💾 **Backup tự động hàng ngày (đã cải tiến)**: Sao lưu toàn bộ workflow và credentials (database, encryption key) một cách đáng tin cậy.
- 📲 **Thông báo và gửi backup qua Telegram (MỚI)**: Tùy chọn cấu hình để nhận thông báo và file backup (nếu <20MB) trực tiếp qua Telegram, kèm hướng dẫn cấu hình chi tiết.
- 🔄 **Cập nhật tự động** N8N và các thành phần (bao gồm cả việc chạy backup trước khi cập nhật).
- 📊 **Tự động cấu hình swap** dựa trên RAM của máy chủ.
- 🇻🇳 **Giao diện tiếng Việt hoàn chỉnh**: Tất cả thông báo và hướng dẫn trong quá trình cài đặt đều bằng tiếng Việt.
- ⚠️ **Xử lý lỗi thông minh** và reporting.
- 🔍 **Kiểm tra và xác minh domain** tự động.
- 📦 **Nén file backup**: Các file backup giờ đây được nén dưới dạng `.tar.gz` để tiết kiệm dung lượng.
- 📜 **Log chi tiết**: Ghi log đầy đủ cho quá trình backup và cập nhật.

## 💻 Yêu cầu

- Ubuntu 20.04 LTS hoặc mới hơn.
- Ít nhất 1GB RAM (khuyến nghị 2GB hoặc cao hơn).
- Tên miền trỏ về địa chỉ IP của máy chủ.
- Quyền sudo/root.
- Kết nối internet (cần thiết cho việc tải gói, Docker images và gửi thông báo Telegram).
- Các gói tiện ích: `curl`, `dig`, `cron`, `jq`, `tar`, `gzip`, `bc` (script sẽ cố gắng tự cài đặt nếu thiếu).

## 📋 Hướng dẫn cài đặt

### 🚀 Cài đặt nhanh (Khuyến nghị)

Sao chép và chạy lệnh sau trực tiếp trên terminal của server:

```bash
cd /tmp && curl -sSL https://raw.githubusercontent.com/KalvinThien/install-n8n-ffmpeg/main/auto_cai_dat_n8n.sh | tr -d '\r' > install_n8n.sh && chmod +x install_n8n.sh && sudo bash install_n8n.sh
```
*Lưu ý: Thay thế URL `https://raw.githubusercontent.com/KalvinThien/install-n8n-ffmpeg/main/auto_cai_dat_n8n.sh` bằng URL thực tế của file script `n8n_install_updated.sh` nếu bạn lưu trữ ở nơi khác.*

### Cài đặt thủ công

Nếu bạn muốn tải script về máy trước:

```bash
# Tải script (ví dụ, đặt tên là n8n_install_updated.sh)
# wget -O n8n_install_updated.sh <URL_TO_YOUR_UPDATED_SCRIPT>

# Cấp quyền thực thi
chmod +x n8n_install_updated.sh

# Chạy script
sudo ./n8n_install_updated.sh
```

Trong quá trình cài đặt, bạn sẽ được hỏi:
- Tên miền của bạn.
- Có muốn cấu hình gửi backup qua Telegram không. 

### Tùy chọn nâng cao khi chạy script

```bash
# Chỉ định thư mục cài đặt khác (ví dụ: /opt/n8n)
sudo ./n8n_install_updated.sh -d /opt/n8n

# Bỏ qua cài đặt Docker (nếu Docker và Docker Compose đã được cài đặt từ trước)
sudo ./n8n_install_updated.sh -s

# Xem trợ giúp
sudo ./n8n_install_updated.sh -h
```

### Hướng dẫn cấu hình gửi Backup qua Telegram

Nếu bạn chọn **Có (y)** khi được hỏi về việc cấu hình gửi backup qua Telegram, script sẽ yêu cầu bạn cung cấp hai thông tin:

1.  **Telegram Bot Token**:
    *   Đây là một chuỗi ký tự duy nhất dùng để xác thực bot của bạn.
    *   **Cách lấy**: 
        1.  Mở Telegram, tìm kiếm `BotFather` (bot chính thức của Telegram để tạo và quản lý bot).
        2.  Bắt đầu chat với BotFather bằng cách gõ lệnh `/start`.
        3.  Gõ lệnh `/newbot` để tạo một bot mới.
        4.  Làm theo hướng dẫn của BotFather: đặt tên cho bot (ví dụ: `N8N Backup Bot`), sau đó đặt username cho bot (phải kết thúc bằng `bot`, ví dụ: `MyN8NBackup_bot`).
        5.  Sau khi tạo thành công, BotFather sẽ cung cấp cho bạn một **HTTP API token**. Đây chính là `TELEGRAM_BOT_TOKEN` bạn cần. Hãy sao chép và lưu lại cẩn thận.

2.  **Telegram Chat ID**:
    *   Đây là ID của cuộc trò chuyện (cá nhân hoặc nhóm) mà bot sẽ gửi thông báo và file backup đến.
    *   **Cách lấy Chat ID cá nhân của bạn**:
        1.  Mở Telegram, tìm kiếm bot `@userinfobot`.
        2.  Bắt đầu chat với `@userinfobot` bằng cách gõ lệnh `/start`.
        3.  Bot sẽ trả về thông tin người dùng của bạn, bao gồm cả `Id`. Đây chính là `TELEGRAM_CHAT_ID` của bạn.
    *   **Cách lấy Chat ID của một Group**:
        1.  Thêm bot bạn vừa tạo ở bước 1 vào group Telegram mà bạn muốn nhận backup.
        2.  Gửi một tin nhắn bất kỳ vào group đó.
        3.  Cách đơn giản nhất để lấy Group ID là sử dụng một bot khác như `@RawDataBot` hoặc `@get_id_bot`. Thêm một trong các bot này vào group, nó sẽ hiển thị thông tin JSON của tin nhắn, trong đó có `chat` -> `id`. Group ID thường là một số âm (ví dụ: `-1001234567890`).
        4.  Hoặc, bạn có thể gửi lệnh `/my_id @TenBotCuaBan` (thay `@TenBotCuaBan` bằng username của bot bạn đã tạo) vào group. Một số bot (như `@userinfobot` nếu được thêm vào group) có thể phản hồi với ID của group.

Sau khi nhập hai thông tin này, script sẽ lưu chúng vào file `$N8N_DIR/telegram_backup.conf` và sử dụng để gửi backup tự động.

## 🔧 Cấu trúc thư mục (ví dụ với thư mục cài đặt mặc định `/home/n8n`)

```
/home/n8n/
├── Dockerfile                # Dockerfile tùy chỉnh với FFmpeg, yt-dlp và Puppeteer
├── docker-compose.yml        # Cấu hình Docker Compose
├── Caddyfile                 # Cấu hình Caddy Server (SSL)
├── update-n8n.sh             # Script cập nhật tự động N8N
├── backup-workflows.sh       # Script sao lưu tự động workflows và credentials
├── telegram_backup.conf      # (TÙY CHỌN) File cấu hình Telegram Bot Token và Chat ID
├── database.sqlite           # File database của N8N
├── encryptionKey             # Khóa mã hóa cho credentials của N8N
└── files/
    ├── temp/                 # Thư mục tạm thời cho N8N
    ├── youtube_content_anylystic/ # Nơi lưu video YouTube
    └── backup_full/          # Nơi lưu trữ các file backup .tar.gz hàng ngày
        └── backup.log        # Log chi tiết của quá trình backup
```

## 📌 Sau khi cài đặt

- Truy cập N8N qua `https://your-domain.com`.
- **Sao lưu tự động**: Được cấu hình chạy hàng ngày vào lúc 2 giờ sáng.
    - File backup (ví dụ: `n8n_backup_YYYYMMDD_HHMMSS.tar.gz`) được lưu tại `$N8N_DIR/files/backup_full/`.
    - Log chi tiết của quá trình backup được lưu tại `$N8N_DIR/files/backup_full/backup.log`.
    - Nếu bạn đã cấu hình Telegram, thông báo về trạng thái backup và file backup (nếu kích thước < 20MB) sẽ được gửi đến Chat ID đã cung cấp.
- **Kiểm tra cập nhật tự động**: Diễn ra mỗi 12 giờ.
    - Log cập nhật được lưu tại `$N8N_DIR/update.log`.
    - Script sẽ tự động chạy backup trước khi thực hiện cập nhật N8N.

## ⚙️ Cấu hình Swap tự động 

Script tự động phân tích RAM trên máy chủ và thiết lập swap tối ưu:

| RAM     | Kích thước swap |
|---------|-----------------|
| ≤ 2GB   | 2x RAM          |
| 2GB-8GB | 1x RAM          |
| > 8GB   | 4GB cố định     |

Các tham số `vm.swappiness` (đặt thành 10) và `vm.vfs_cache_pressure` (đặt thành 50) được điều chỉnh.

## 🚨 Xử lý sự cố

- **Docker không khởi động**: Kiểm tra logs bằng lệnh `cd /path/to/your/n8n_dir && docker compose logs n8n`.
- **SSL không hoạt động**: Kiểm tra Caddy logs bằng `cd /path/to/your/n8n_dir && docker compose logs caddy`.
- **Không tải được video YouTube**: Cập nhật yt-dlp trên host. Sau đó, script cập nhật tự động cũng sẽ cập nhật yt-dlp trong container.
- **Backup không gửi qua Telegram**: 
    - Kiểm tra file cấu hình `$N8N_DIR/telegram_backup.conf`.
    - Đảm bảo server có kết nối internet.
    - Kiểm tra log backup tại `$N8N_DIR/files/backup_full/backup.log`.
- **Vấn đề khác**: Xem thêm trong các file log hoặc liên hệ hỗ trợ.

## 📜 Miễn trừ trách nhiệm

- Script này được cung cấp "NGUYÊN TRẠNG" mà không có bất kỳ bảo đảm nào, dù rõ ràng hay ngụ ý.
- Người dùng hoàn toàn chịu trách nhiệm về việc sử dụng script này và mọi hậu quả có thể phát sinh.
- Luôn đảm bảo bạn đã sao lưu dữ liệu quan trọng trước khi chạy bất kỳ script nào có quyền truy cập hệ thống cao.
- Tác giả không chịu trách nhiệm cho bất kỳ mất mát dữ liệu, gián đoạn dịch vụ hoặc thiệt hại nào khác do việc sử dụng script này gây ra.
- Vui lòng tự kiểm tra và hiểu rõ script trước khi thực thi trên môi trường production.

## 👨‍💻 Thông tin và hỗ trợ

### Liên hệ

- **Zalo/Phone**: 0888884749
- **GitHub**: [Github/KalvinThien](https://github.com/KalvinThien)

### Donate

Nếu bạn thấy dự án này hữu ích, hãy xem xét hỗ trợ để phát triển thêm tính năng mới:

- **TP Bank**: 0888884749
- **Chủ tài khoản**: Nguyễn Ngọc Thiện

<div align="center">
  <img src="https://github.com/KalvinThien/install-n8n-ffmpeg/blob/main/qrcode.png?raw=true" alt="QR Code Donate" width="400" />
</div>

## 📝 Changelog

### v1.4.1 (15/05/2025) - Bản cập nhật hiện tại
- ✅ **Cải tiến Hướng dẫn & Hoàn thiện Script**:
    - **Ưu tiên lệnh cài đặt nhanh** trong README.
    - **Bổ sung hướng dẫn chi tiết** cách lấy Telegram Bot Token và Chat ID.
    - **Thêm mục Miễn trừ trách nhiệm** vào README.
    - Sửa các lỗi nhỏ về định dạng Markdown/HTML trong README.
    - Cập nhật ngày phát hành cho phiên bản này.
- ✅ **Cải tiến Backup Lớn & Tích hợp Telegram (từ v1.4.0)**:
    - Sửa lỗi logic và đường dẫn trong script backup (`backup-workflows.sh`) để đảm bảo sao lưu chính xác workflows, database (`database.sqlite`), và encryption key.
    - File backup được nén dưới dạng `.tar.gz`.
    - Tùy chọn cấu hình gửi thông báo trạng thái backup và file backup (nếu < 20MB) hàng ngày qua Telegram.
    - Hướng dẫn chi tiết bằng tiếng Việt trong quá trình cài đặt để cấu hình Telegram.
    - Cải thiện log chi tiết cho quá trình backup.
    - Dọn dẹp các bản backup cũ an toàn hơn.
- 🇻🇳 **Việt hóa hoàn toàn (từ v1.4.0)**: Tất cả các thông báo, câu hỏi trong script cài đặt đều bằng tiếng Việt.
- 🛠️ **Cải tiến Script Cài đặt (từ v1.4.0)**:
    - Kiểm tra và cài đặt các gói phụ thuộc mạnh mẽ hơn.
    - Cải thiện logic kiểm tra và cài đặt Docker & Docker Compose.
    - Tối ưu hóa quyền truy cập thư mục cho N8N và script backup.
    - Script cập nhật (`update-n8n.sh`) giờ đây sẽ tự động chạy backup trước khi cập nhật N8N.

### v1.3.0 (26/03/2025)
- ✅ Thêm tính năng tự động cấu hình swap
- 🔄 Cập nhật cách cài đặt yt-dlp để tương thích với Python mới
- 🔒 Cập nhật phương pháp thêm khóa GPG cho Docker
- 🐛 Sửa lỗi trong Dockerfile cho Alpine Linux

### v1.2.0 (15/02/2025)
- ✅ Thêm tích hợp Puppeteer
- 🔄 Cải thiện hệ thống sao lưu và khôi phục (phiên bản trước khi có sửa lỗi lớn và Telegram)
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
    <sub>Script gốc được phát triển bởi Nguyễn Ngọc Thiện</sub><br />
    <sub>© 2025 Nguyễn Ngọc Thiện - Mọi quyền được bảo lưu</sub>
  </p>
  
  [![Made with Love](https://img.shields.io/badge/Made%20with-❤️-red.svg)](https://github.com/your-username)
</div>

