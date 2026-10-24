# Quy trình bắt buộc sau khi hoàn thành công việc (Release & Backup Workflow)

Mỗi khi hoàn thành xong bất kỳ tính năng, chỉnh sửa giao diện hay sửa lỗi nào theo yêu cầu của người dùng, trợ lý Antigravity PHẢI thực hiện 2 bước bắt buộc sau:

1. **Lưu lên GitHub**:
   - Kiểm tra mã nguồn với `flutter test` và `flutter analyze`.
   - Nâng số phiên bản kế tiếp trong `pubspec.yaml` (ví dụ: `1.0.10+11` -> `1.0.11+12`) và cập nhật `README.md`.
   - Chạy `git add .`, tạo commit mô tả rõ thay đổi, và chạy `git push origin main`.

2. **Xuất bản APK Android ra ổ D để cài điện thoại**:
   - Chạy lệnh build bản release trỏ API Render:
     `flutter build apk --release --dart-define=API_BASE_URL=https://tiktube-api.onrender.com`
   - Sao chép file APK vừa build ra ổ `D:\TIKTUBE_v<version>.apk` (ví dụ: `D:\TIKTUBE_v1.0.10+11.apk`) để người dùng sao chép và cài đặt trên điện thoại.
