# HƯỚNG DẪN & TOÀN BỘ LỊCH SỬ DỰ ÁN TIKTUBE

Tài liệu quy tắc workspace lưu trữ toàn bộ lịch sử các quyết định kỹ thuật và quy trình của dự án TIKTUBE.

## 1. Quy trình bắt buộc sau mỗi lần hoàn thành nhiệm vụ
1. `flutter analyze` đạt 0 lỗi, `flutter test` đạt 100% pass.
2. Tăng số phiên bản trong `pubspec.yaml` và `README.md`.
3. `git add .`, commit và `git push origin main`.
4. Build APK release: `flutter build apk --release --dart-define=API_BASE_URL=https://tiktube-api.onrender.com`
5. Copy file APK ra ổ `D:\TIKTUBE_v<version>.apk`.

## 2. Các quyết định kỹ thuật cốt lõi
- **Khung video cố định 16:9:** Khung player trên `WatchScreen` luôn khoá ở 16:9, video bất kỳ kích thước (dọc 9:16, vuông 1:1, 4:3) đều căn giữa trong nền đen, tuyệt đối không co giãn làm nhảy layout.
- **Thanh kênh & nút YouTube (Ảnh 2):**
  - Kênh: Avatar + Tên kênh + Số sub + Nút `[ Đăng ký ]` / `[ Đã đăng ký ]` dạng viên thuốc đặt sát cạnh thông tin kênh.
  - Cụm nút hành động viên thuốc (Pill capsules cuộn ngang): `[ 👍 $likeCount | 👎 ]`, `[ ➦ Chia sẻ ]`, `[ ✦ Đặt câu hỏi ]`, `[ ⤓ Tải xuống ]`, `[ ⋯ ]`.
- **Hệ thống bình luận phân cấp & phản hồi (Ảnh 3):**
  - Nút like `👍`, dislike `👎`, và text button `Phản hồi`.
  - Bấm `Phản hồi` hiện banner `Đang phản hồi @author` và focus vào ô nhập.
  - Định dạng lưu trữ 2 chiều: `[reply:PARENT_ID] nội_dung`.
  - Hiển thị chuỗi phản hồi con: gập mở `▼ n phản hồi` / `▲ Thu gọn`, thụt lề 38px, avatar 24px.
  - Nền bình luận trong suốt khi xem video dọc, hỗ trợ ảnh/icon và đổi avatar trong trang tài khoản.
- **Thống kê:** Biểu đồ miền (Area chart) theo ngày, tháng, cả tháng; thống kê riêng biệt cho từng tài khoản cá nhân.
- **iOS:** Cần môi trường macOS/Xcode để build `.ipa`, không thể đổi đuôi file apk.
- **PowerShell:** Nối lệnh bằng `;`, không dùng `&&`.
