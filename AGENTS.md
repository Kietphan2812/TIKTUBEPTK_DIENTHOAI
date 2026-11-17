# TIKTUBE — HƯỚNG DẪN & TOÀN BỘ LỊCH SỬ DỰ ÁN CHO ANTIGRAVITY (AGENTS.MD)

Tài liệu này ghi nhớ toàn bộ kiến trúc, lịch sử các yêu cầu của người dùng, quyết định thiết kế và quy trình làm việc bắt buộc. Mọi phiên làm việc tiếp theo PHẢI tuân thủ các quy tắc này mà không cần hỏi lại người dùng.

---

## 1. THÔNG TIN HỆ THỐNG & KIẾN TRÚC
- **Tên dự án:** TIKTUBE (Ứng dụng video đa nền tảng Flutter cho PTK).
- **Công nghệ chính:** Flutter (Android, iOS, Web, Desktop).
- **Backend API:** Dart REST API (shelf) lưu tại `server/`, đã triển khai trên Render tại:
  `https://tiktube-api.onrender.com`
- **Database:** Neon Serverless PostgreSQL (`neondb`), kết nối trực tiếp với backend.
- **Lưu trữ media:** Cloudinary (lưu video và ảnh thumbnail/avatar).
- **Nguyên tắc dữ liệu:** KHÔNG dùng dữ liệu mẫu (mock) trong UI khi API hoạt động. Khi mất mạng hay lỗi API, hiển thị giao diện báo lỗi kèm nút "Thử lại".
- **Kho mã nguồn GitHub:** `https://github.com/Kietphan2812/TIKTUBEPTK_DIENTHOAI.git` (nhánh chính: `main`).

---

## 2. QUY TRÌNH BẮT BUỘC SAU MỖI LẦN LÀM XONG (MANDATORY WORKFLOW)
Sau khi hoàn thành bất kỳ tính năng, chỉnh sửa giao diện hay sửa lỗi nào, Antigravity **BẮT BUỘC PHẢI TỰ ĐỘNG THỰC HIỆN ĐẦY ĐỦ CÁC BƯỚC SAU** trước khi trả lời xong cho người dùng:

1. **Kiểm tra chất lượng code:**
   - Chạy `flutter analyze` đảm bảo **0 lỗi, 0 cảnh báo**.
   - Chạy `flutter test` đảm bảo **100% tests pass**.
2. **Nâng số phiên bản (Version Bumping):**
   - Tăng số phiên bản trong [pubspec.yaml](file:///d:/flutter_app_ptk/pubspec.yaml) (ví dụ: `1.0.12+13` -> `1.0.13+14`).
   - Cập nhật số phiên bản tương ứng trong [README.md](file:///d:/flutter_app_ptk/README.md).
3. **Lưu trữ lên GitHub:**
   - Chạy `git add .`
   - Tạo commit với mô tả chi tiết: `git commit -m "feat/fix: ..."`
   - Đẩy lên nhánh main: `git push origin main`
4. **Biên dịch bản cài đặt APK Android:**
   - Chạy lệnh build release gắn API URL:
     `flutter build apk --release --dart-define=API_BASE_URL=https://tiktube-api.onrender.com`
   - Sao chép file APK vừa tạo ra thư mục gốc ổ D:
     `Copy-Item "build/app/outputs/flutter-apk/app-release.apk" "D:\TIKTUBE_v<version>.apk"`
     *(Ví dụ: `D:\TIKTUBE_v1.0.12+13.apk`)*

---

## 3. LỊCH SỬ CÁC QUYẾT ĐỊNH THIẾT KẾ ĐÃ CHỐT

### 3.1. Khung phát video cố định (WatchScreen & VideoSurface)
- **Tỷ lệ khung hình:** Khoá cố định tuyệt đối ở tỷ lệ **16:9** (`AspectRatio(aspectRatio: 16 / 9)`).
- **Hành vi video:** Video tải lên dù ở bất kỳ kích cỡ nào (video dọc TikTok `9:16`, video vuông `1:1`, `4:3` hay `16:9`) đều được căn giữa vừa vặn bên trong khung cố định với dải nền đen rạp chiếu phim (`ColoredBox(color: Colors.black)`).
- **Mục đích:** Giữ khung player cố định, tuyệt đối không làm nhảy hoặc xô lệch layout thông tin kênh và bình luận bên dưới.

### 3.2. Thanh thông tin kênh & Cụm nút hành động kiểu YouTube (Ảnh 2)
- **Hàng kênh:**
  - Avatar tròn kênh + Tên kênh in đậm + Số lượng người đăng ký.
  - Nút viên thuốc `[ Đăng ký ]` / `[ Đã đăng ký ]` bo tròn (Stadium) nằm sát bên cạnh thông tin kênh.
- **Thanh nút hành động dạng viên thuốc (Pill Capsule) cuộn ngang:**
  - `[ 👍 $likeCount | 👎 ]`: Cụm Thích & Không thích gộp chung 1 viên thuốc, có vạch ngăn cách ở giữa.
  - `[ ➦ Chia sẻ ]`: Sao chép liên kết video.
  - `[ ✦ Đặt câu hỏi ]`: Trợ lý AI hỏi đáp.
  - `[ ⤓ Tải xuống ]`: Tải video về máy.
  - `[ ⋯ ]`: Menu tùy chọn (Báo cáo vi phạm, chất lượng 1080p, tốc độ phát lại 1.0x).

### 3.3. Bình luận phân cấp & Phản hồi trực tiếp (Ảnh 3)
- **Dưới mỗi bình luận:** Nút thích `👍`, nút không thích `👎`, và nút text **`Phản hồi`**.
- **Chế độ phản hồi:** Khi bấm `Phản hồi`, hiển thị banner `Đang phản hồi @author` kèm nút [✕] huỷ, con trỏ tự động nhảy vào ô nhập bình luận.
- **Cơ chế lưu trữ:** Bình luận con gửi lên backend với format `[reply:PARENT_ID] nội_dung`. Cơ chế này tương thích 100% hai chiều với bảng `binh_luan` trong Neon Postgres mà không cần thay đổi schema database.
- **Hiển thị chuỗi phản hồi con:**
  - Nút gập mở: `▼ n phản hồi` / `▲ Thu gọn`.
  - Khi mở: các bình luận con thụt lề 38px, avatar nhỏ 24px, có nút thích/phản hồi riêng.
- **Tính năng mở rộng:** Hỗ trợ xem bình luận trong suốt trên nền video dọc, gửi ảnh/icon trong bình luận, và đổi avatar trong trang tài khoản.

### 3.4. Thống kê kênh & video (Analytics)
- **Biểu đồ miền (Area / Line Chart):** Biểu đồ dạng miền mượt mà, có dải màu gradient phía dưới đường biểu diễn thay vì dạng cột thô.
- **Lọc thời gian:** Hỗ trợ xem chi tiết theo ngày, 7 ngày, toàn tháng (30 ngày).
- **Phân vùng dữ liệu:** Thống kê hiển thị riêng biệt theo từng tài khoản đăng nhập (lượt xem, lượt like, bình luận, người đăng ký của chính tài khoản đó), không cộng dồn chung toàn bộ hệ thống.

### 3.6. Nhắn tin, Kết bạn & Gọi thoại / Video (Đồng bộ Neon PostgreSQL & nhantinptk.onrender.com)
- **Kiến trúc & Cơ sở dữ liệu:**
  - Kết nối trực tiếp máy chủ thời gian thực `https://nhantinptk.onrender.com` qua `socket_io_client`.
  - Cơ sở dữ liệu Neon PostgreSQL (`sql_nhantin` - `ep-withered-meadow-b5o6uv6v.c-7.us-east-2.aws.neon.tech/neondb`): lưu trữ vĩnh viễn danh sách người dùng (`users`), tin nhắn (`messages`), lời mời kết bạn (`friend_requests`).
  - Lưu trữ đám mây hình ảnh: Cloudinary tài khoản `qfgja134` (API Secret `WR2xJMwT27mWJjfIjwoAqMbuF8M`), gửi ảnh trực tiếp qua endpoint `/api/upload`.
  - Đồng bộ 2 chiều thời gian thực với web app `https://nhantinptk.onrender.com`.
- **Giao diện & Tính năng:**
  - Huy hiệu trạng thái thời gian thực: `🟢 Neon SQL Online` / `🟠 Đang kết nối SQL...`.
  - Đăng ký tài khoản: Tích hợp ô nhập **Số điện thoại** (9-11 số), tự động đồng bộ SĐT vào Neon PostgreSQL để tìm kiếm bạn bè và kết nối nhắn tin.
  - **Cloud của tôi (Lưu trữ đám mây cá nhân):** Tính năng lưu trữ riêng tư độc lập (icon Cloud xanh ☁️), hỗ trợ lưu trữ văn bản, ghi chú, và ảnh cá nhân vĩnh viễn trên Cloudinary `qfgja134` và Neon Postgres. Đã loại bỏ các tài khoản bot mẫu cũ.
  - Loại bỏ hoàn toàn hộp thoại và nút "Đổi nick" tạm thời, tài khoản đăng nhập gắn liền với phiên người dùng TIKTUBE.
  - Gửi hình ảnh qua Cloudinary hiển thị mượt mà trong bong bóng chat.
  - Tín hiệu cuộc gọi thoại & video (`call:initiate`, `call:incoming`, `call:answer`, `call:hangup`) kết nối qua lại giữa điện thoại và máy tính/web.
- **Kết bạn & Tìm kiếm:** Hộp thoại tìm bạn theo Số điện thoại hoặc Tên đăng nhập (username), hiển thị thông tin thẻ người dùng, gửi/chấp nhận lời mời kết bạn.
- **Trò chuyện trực tiếp (Chat):** Danh bạ bạn bè, cửa sổ chat thời gian thực, bong bóng tin nhắn gửi/nhận, lưu trữ bền vững với SharedPreferences, mô phỏng phản hồi tự động thông minh.
- **Gọi thoại (Audio Call 📞) & Gọi Video (Video Call 📹):**
  - Giao diện cuộc gọi hiện đại với hiệu ứng sóng âm avatar lan toả (Avatar Pulse Ring).
  - Đồng hồ đếm thời lượng cuộc gọi.
  - Bộ nút điều khiển: bật/tắt mic, camera, chuyển loa ngoài và nút gác máy đỏ 🔴.
  - Hộp thoại nhận cuộc gọi đến với 2 nút Trả lời 🟢 và Từ chối 🔴.
- **Điểm truy cập:** Nút Nhắn tin trên TopBar (Desktop/Tablet), thanh điều hướng đáy _MobileBottomNav (Mobile), và cụm nút hành động trên WatchScreen.

### 3.7. Sửa lỗi tin nhắn kép, Xóa bạn bè & Badge thông báo tin nhắn chưa đọc
- **Khử trùng lặp tin nhắn (Message Deduplication):**
  - Khi gửi tin nhắn, client chèn tin nhắn lạc quan (optimistic) hiển thị ngay lập tức. Khi Socket.io nhận sự kiện `message:new` từ server Neon, hệ thống tìm tin nhắn tương ứng theo nội dung text, ảnh và timestamp gần nhất để cập nhật ID máy chủ thay vì chèn mới lặp lại (ngăn chặn tình trạng 1 tin nhắn hiển thị 2 lần).
  - Khử trùng lặp cả trong lịch sử tải `chat:history` và khi khôi phục từ `SharedPreferences`.
  - Bổ sung cờ chặn gửi kép `_isSending` tránh bấm nút gửi nhiều lần liên tiếp.
- **Tính năng Xóa bạn bè (Unfriend):**
  - Hỗ trợ xóa bạn bè ở cả 2 vị trí: menu 3 chấm trên thanh tiêu đề cuộc trò chuyện (Mobile & Desktop) và nút icon thùng rác / người xóa trên danh sách tab "Bạn bè".
  - Hộp thoại xác nhận an toàn trước khi xóa: "Xác nhận xóa bạn bè khỏi Neon SQL".
  - Khi xác nhận, gửi sự kiện `friend:remove` qua Socket.io và gọi API `POST /api/friends/remove`, đồng thời lưu `_deletedFriendIds` vào bộ nhớ máy để bạn bè đã xóa không tự ý xuất hiện lại khi đồng bộ.
  - Lắng nghe sự kiện `friend:removed` thời gian thực từ đối phương để cập nhật danh bạ ngay lập tức.
- **Huy hiệu thông báo tin nhắn chưa đọc (Unread Message Badge):**
  - Thanh điều hướng đáy điện thoại (`_MobileBottomNav`): hiển thị badge số màu đỏ bo tròn trực tiếp trên icon `Nhắn tin`.
  - Thanh TopBar trên Desktop/Tablet: hiển thị badge số tin nhắn chưa đọc trên icon chat.
  - Tự động cập nhật thời gian thực khi có người gửi tin nhắn đến và tự động reset về 0 khi người dùng bấm vào xem cuộc trò chuyện.
  - `ChatService.instance.init()` được gọi ngay từ `HomeScreen` để kết nối Socket.io và cập nhật badge ngay từ khi mở app.

### 3.8. Đồng bộ tài khoản Chat theo phiên TIKTUBE & Phân lập bạn bè theo từng tài khoản
- **Đồng bộ tự động theo phiên đăng nhập (Profile Binding):**
  - Tài khoản chat `_currentUser` trong `ChatService` tự động đồng bộ 100% với tài khoản TIKTUBE đang đăng nhập (`AuthController.profile` / `KIETPHAN2812`).
  - Loại bỏ hoàn toàn fallback cứng cũ (`phantaanskieetj` / `0338351410`).
  - Nếu tài khoản TIKTUBE chưa từng có trên Neon SQL, hệ thống tự động đăng ký tạo người dùng mới trên Neon ngay lập tức.
- **Phân lập danh bạ bạn bè & tin nhắn (Account-scoped Isolation):**
  - Mỗi tài khoản chỉ hiển thị danh bạ bạn bè của CHÍNH tài khoản đó được lưu trên Neon PostgreSQL (`myFriendIds` của chính `_currentUser.id`) và Cloud của tôi. Tài khoản mới có 0 bạn bè sẽ hiển thị danh sách trống kèm Cloud cá nhân, tuyệt đối không bị dính 3 bạn bè cố định của tài khoản khác.
  - Khi người dùng đăng xuất hoặc chuyển sang tài khoản khác, hệ thống tự động xóa bộ nhớ phiên cũ, nạp bộ nhớ đệm riêng biệt theo khóa `tiktube_friends_v3_<userKey>`, `tiktube_messages_v3_<userKey>` và tải danh bạ bạn bè thật của tài khoản mới từ Neon.
  - Tích hợp lắng nghe tự động tại `AuthController` (`restore`, `_apply`, `logout`, `updateProfileCache`), `HomeScreen` và `ChatScreen` (`didChangeDependencies`).

### 3.9. Đồng bộ Số điện thoại cá nhân từ trang Tài khoản sang Trang Chat & Neon SQL
- **Lưu trữ & Truyền dữ liệu hai chiều:**
  - `AccountScreen._save()` đọc trường `_phone.text.trim()`, kiểm tra định dạng hợp lệ (9-11 chữ số), và truyền vào `_api.updateProfile(phone: phone)`.
  - `TikTubeApi` và `ApiClient` nhận tham số `String? phone`, đính kèm vào payload `PATCH /api/me` và trả về `profile.copyWith(phone: phone)`.
  - `AccountScreen` gọi đồng thời `updateProfileCache(profile)` và `ChatService.instance.updateCurrentUserPhone(phone)`.
- **Đồng bộ tức thì lên Neon SQL & Giao diện Chat:**
  - `ChatService` ngay lập tức gán SĐT mới vào `_currentUser.phone`, lưu xuống SharedPreferences `_prefCurrentUserKey()`, và gọi API `POST /api/users/profile` của `nhantinptk.onrender.com` để cập nhật bảng `users` trên Neon PostgreSQL.
  - Thanh trạng thái `_buildNeonStatusBanner` trên `ChatScreen` ưu tiên hiển thị SĐT thực đã lưu, loại bỏ triệt để chuỗi hash ngẫu nhiên cũ (`0320001688`).
  - Khi khởi động lại app (`AuthController.restore()`), hệ thống bảo toàn trường `phone` của phiên hiện tại thay vì bị ghi đè bởi giá trị rỗng từ máy chủ video.

### 3.10. Lưu số điện thoại vĩnh viễn theo tài khoản (Neon PostgreSQL nguoi_dung & UserPreferences)
- **Cơ chế lưu trữ vĩnh viễn:**
  - **Lưu trực tiếp vào database Neon PostgreSQL:** Đã thêm cột `so_dien_thoai VARCHAR(20)` vào bảng `nguoi_dung` của database Neon `neondb`. Tất cả các API `GET /api/me`, `PATCH /api/me`, `POST /api/auth/register`, `POST /api/auth/login` đều đọc và ghi nhận trường `phone` trực tiếp từ database.
  - SĐT tài khoản `kietphan2812` đã được cập nhật vĩnh viễn là `0338351410` trong cơ sở dữ liệu Neon.
  - Tạo `UserPreferences` lưu trữ vĩnh viễn số điện thoại theo khóa riêng biệt `tiktube_permanent_phone_<userKey>` trên thiết bị. Khóa này KHÔNG bị xóa khi người dùng đăng xuất.
  - Khi người dùng đăng nhập lại (`AuthController.login()`), hệ thống tự động nạp SĐT từ database hoặc bộ nhớ thiết bị vào hồ sơ người dùng.
  - Khi mở trang Tài khoản (`AccountScreen`), số điện thoại tự động tải về từ máy chủ và điền vào ô nhập ngay lập tức.
  - Trong `ChatService`, khi tải danh sách người dùng từ Neon SQL, nếu tài khoản đã có SĐT trên Neon, hệ thống tự động sao lưu ngược lại vào `UserPreferences` để bảo toàn dữ liệu vĩnh viễn xuyên suốt mọi phiên đăng nhập/đăng xuất.

---

### 3.11. Tái thiết kế Giao diện Nhắn tin di động hiện đại (Modern Mobile Chat App Redesign)
- **Header & Trạng thái di động tích hợp:**
  - Loại bỏ hoàn toàn thanh trạng thái gồ ghề kiểu web debug (`_buildNeonStatusBanner`).
  - Tích hợp avatar cá nhân có chấm xanh Neon SQL thời gian thực, tiêu đề "Tin nhắn & Bạn bè", phụ đề số điện thoại/username, cụm nút Tìm kiếm, Lời mời kết bạn có badge số đỏ, và nút Thêm bạn.
- **Thanh Khoảnh khắc & Bạn bè đang Online (Stories / Active Bar):**
  - Bổ sung thanh cuộn ngang bạn bè đang hoạt động với viền sáng gradient và chấm xanh hoạt động trực tiếp dưới thanh tìm kiếm.
  - Vị trí đầu tiên dành riêng cho "Cloud của tôi" với biểu tượng đám mây phát sáng. Bấm vào bất kỳ người bạn nào sẽ mở ngay cuộc trò chuyện.
- **Bộ lọc danh sách dạng viên thuốc (Filter Chips):**
  - Hỗ trợ chuyển đổi nhanh: `Tất cả`, `Chưa đọc` (kèm badge đỏ), `Danh bạ (n)`, và `Cloud của tôi`.
- **Thẻ cuộc trò chuyện & Tab Danh bạ di động cao cấp:**
  - Hiển thị thời gian tin nhắn góc phải, preview tin nhắn/ảnh/cuộc gọi kèm tiền tố `Bạn:`, badge tin nhắn chưa đọc đỏ nổi bật.
  - Nhấn giữ cuộc trò chuyện để mở Bottom Sheet tiện ích: xem thông tin cá nhân, gọi thoại, gọi video, xóa bạn bè.
  - Tab Danh bạ tổ chức chuyên nghiệp: các tiện ích nhanh "Thêm bạn mới", "Lời mời kết bạn", "Cloud của tôi", và danh sách bạn bè kèm nút gọi/nhắn tin trực tiếp.
- **Tiện ích trò chuyện mở rộng:**
  - Thanh chọn emoji cảm xúc nhanh (`👍`, `❤️`, `😂`, `🔥`, `🎉`, v.v.).
  - Xem ảnh phóng to toàn màn hình (`InteractiveViewer`) khi nhấn vào ảnh đã gửi/nhận.
  - Nút soạn tin/thêm bạn nhanh dạng FAB (Floating Action Button) phong cách ứng dụng di động chuẩn.

### 3.12. Khôi phục mật khẩu qua Gmail OTP (Gmail App Password)
- **Cơ chế gửi Email tự động:**
  - Sử dụng giao thức Gmail SMTP SSL cổng 465 trực tiếp từ máy chủ Dart (`EmailService`), không phụ thuộc thư viện bên ngoài.
  - Cấu hình qua biến môi trường `SMTP_EMAIL` và `SMTP_PASSWORD` (Mật khẩu ứng dụng 16 ký tự `ptmi bnyz mvhk meig` tạo từ tài khoản `kietphan4444@gmail.com`).
  - Giao diện email HTML chuyên nghiệp với logo TIKTUBE, mã OTP 6 số in đậm viền đứt nét, cảnh báo bảo mật và thời gian hết hạn 5 phút.
  - **Lưu ý mạng Render Cloud:** Render gói miễn phí (Free Tier) chặn tường lửa outbound tất cả các cổng SMTP truyền thống (25, 465, 587) gây ra `SocketException (errno = 110)`. Do đó hệ thống hỗ trợ `GMAIL_WEBHOOK_URL` (Google Apps Script Web App chạy trên HTTPS cổng 443 không bao giờ bị chặn) với fallback về SMTP cổng 465 khi chạy local.
- **Backend API Endpoints:**
  - `POST /api/auth/forgot-password`: Kiểm tra email trong bảng `nguoi_dung` Neon PostgreSQL, sinh mã OTP 6 số ngẫu nhiên, lưu bộ nhớ đệm và gửi email.
  - `POST /api/auth/verify-otp`: Xác thực mã OTP trước khi cho phép đặt mật khẩu.
  - `POST /api/auth/reset-password`: Xác thực OTP, cập nhật `mat_khau_hash` (SHA-256) vào Neon PostgreSQL và tự động phát hành phiên đăng nhập mới.
- **Giao diện Client (AuthScreen):**
  - Nút "Quên mật khẩu?" đặt dưới ô nhập Mật khẩu trên form đăng nhập.
  - Hộp thoại khôi phục mật khẩu 3 bước (Stepper 1-2-3):
    1. Nhập Email Gmail đã đăng ký.
    2. Nhập mã OTP 6 số kèm đồng hồ đếm ngược 60 giây gửi lại.
    3. Đặt mật khẩu mới (tối thiểu 8 ký tự) & Tự động đăng nhập vào ứng dụng ngay lập tức.

---

### 3.13. Thông báo Cuộc gọi & Tin nhắn Đẩy (Firebase FCM & Local Notifications)
- **Cấu hình Firebase Cloud Messaging (FCM):**
  - Đã tích hợp `android/app/google-services.json` kết nối dự án Firebase `tiktube-cd8d5` (Package `com.example.flutter_app_ptk`).
  - Thiết lập Google Services Gradle plugin trong `android/settings.gradle.kts` và `android/app/build.gradle.kts`.
  - Cấp đầy đủ quyền Android Manifest: `POST_NOTIFICATIONS`, `VIBRATE`, `WAKE_LOCK`, `USE_FULL_SCREEN_INTENT`, `showWhenLocked`, `turnScreenOn`.
- **Dịch vụ Thông báo (`PushNotificationService`):**
  - Kênh thông báo tin nhắn: `tiktube_messages` (Importance High, Heads-up popup).
  - Kênh thông báo cuộc gọi đến: `tiktube_calls` (Importance Max, Full-screen intent, rung chuông nổi).
  - Xử lý thông báo ngầm qua `@pragma('vm:entry-point') _firebaseMessagingBackgroundHandler`.
  - Kết nối trực tiếp với `ChatService`: khi nhận sự kiện `message:new` tự động thả banner tin nhắn mới kèm tên người gửi, khi nhận sự kiện `call:incoming` tự động phát thông báo cuộc gọi đến kèm tên và SĐT người gọi.

---

### 3.14. Tự động chuyển màn hình cuộc gọi toàn cục & Nút thao tác trên thông báo (Global Call Manager)
- **Quản lý cuộc gọi toàn cục (`CallManager`):**
  - Gắn `GlobalKey<NavigatorState>` (`CallManager.navigatorKey`) vào root `MaterialApp`.
  - Lắng nghe `ChatService.callEvents`: bất kể người dùng đang ở đâu trong ứng dụng (Trang chủ, xem video 16:9, tìm kiếm, v.v.), khi có cuộc gọi đến màn hình lập tức chuyển ngay sang giao diện cuộc gọi (`CallOverlay`).
  - Cờ `CallOverlay.isCallOpen` ngăn chặn việc mở chồng chéo nhiều popup gọi cùng lúc.
- **Tương tác thông báo Heads-Up (Android Action Buttons):**
  - Thêm 2 nút bấm trực tiếp trên banner thông báo: **[ Trả lời 🟢 ]** và **[ Từ chối 🔴 ]**.
  - Khi bấm vào banner thông báo hoặc bấm nút **[ Trả lời ]**: ứng dụng lập tức mở lên và chuyển thẳng vào màn hình cuộc gọi (`CallOverlay`). Nếu bấm Trả lời, tự động kết nối cuộc gọi.
  - Khi bấm **[ Từ chối ]**: tự động phát tín hiệu `call:reject` và huỷ thông báo ngay lập tức mà không cần mở app.
  - Bổ sung quyền Android: `SYSTEM_ALERT_WINDOW`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_PHONE_CALL`, và cấu hình `setShowWhenLocked(true)`, `setTurnScreenOn(true)` trong `MainActivity.kt`.

---

### 3.15. Nhạc chuông cuộc gọi hệ thống, Đưa App lên trước & Thông báo tương tác TIKTUBE
- **Nhạc chuông cuộc gọi thật (Android Native RingtoneManager):**
  - Tích hợp `RingtoneManager.getDefaultUri(TYPE_RINGTONE)` qua MethodChannel `com.example.flutter_app_ptk/app_control` trong `MainActivity.kt`.
  - Khi có cuộc gọi đến (`call:incoming`), máy tự động đổ chuông điện thoại thật và lặp vô tận cho đến khi bấm Trả lời, Từ chối hoặc cuộc gọi kết thúc.
  - Tự động dừng chuông ngay lập tức khi người dùng bấm Trả lời hoặc Từ chối trên thông báo/màn hình.
- **Tự động đưa App lên màn hình trước (Bring App To Front):**
  - `CallManager.bringAppToFront()` kích hoạt `startActivity` với cờ `FLAG_ACTIVITY_NEW_TASK | FLAG_ACTIVITY_REORDER_TO_FRONT | FLAG_ACTIVITY_SINGLE_TOP`.
  - Kết hợp quyền `SYSTEM_ALERT_WINDOW` giúp ứng dụng tự động mở lên màn hình trước khi có cuộc gọi đến.
- **Thông báo đẩy tương tác TIKTUBE (Thích, Bình luận, Đăng ký kênh):**
  - Tạo `NotificationSyncService` tự động đồng bộ danh sách thông báo từ API Neon Postgres.
  - Kênh thông báo `tiktube_interactions` (Tương tác TIKTUBE, Importance High).
  - Khi có người thích video, bình luận video hoặc đăng ký kênh, hệ thống tự động bắn Heads-up Notification nổi kèm rung và âm thanh thông báo.

---

### 3.16. Camera thiết bị thật & Điều khiển cuộc gọi video (Device Camera Preview & Video Call Controls)
- **Kích hoạt Camera trước thiết bị thật (`camera: ^0.12.2`):**
  - Khi vào cuộc gọi video hoặc bấm nghe máy, hệ thống tự động quét danh sách camera (`availableCameras()`), ưu tiên chọn camera trước (`CameraLensDirection.front`) và khởi tạo `CameraController` với độ phân giải Medium kèm luồng âm thanh `enableAudio: true`.
  - Luồng video camera thật hiển thị trực tiếp toàn màn hình (`CameraPreview`) với tỷ lệ vừa vặn không méo hình, giúp người dùng nhìn thấy khuôn mặt và khung cảnh thực tế của mình khi gọi video.
- **Bộ điều khiển cuộc gọi nâng cao:**
  - Nút **[ Bật/Tắt cam ]**: Chuyển đổi giữa chế độ xem camera trực tiếp và chế độ ẩn camera với placeholder thông tin.
  - Nút **[ Đổi cam ]**: Lật camera trước / sau nếu máy có nhiều hơn 1 camera.
  - Nút **[ Bật/Tắt mic ]**: Trạng thái micro hiển thị rõ ràng trên huy hiệu trạng thái (Micro mở / Micro đã tắt).
  - Nút **[ Loa ngoài / Loa trong ]**: Chuyển đổi linh hoạt giữa chế độ loa ngoài và loa trong.
  - Tự động giải phóng phần cứng camera (`_cameraController?.dispose()`) khi gác máy hoặc đóng overlay.

---

### 3.17. Giới hạn độ tuổi 18+ & Khóa bảo vệ nội dung không dành cho trẻ em (Age Gate)
- **Nhận diện video 18+:**
  - Mô hình `Video`: thuộc tính `isKidsOnly` (đồng bộ `danh_cho_tre_em` từ database Neon), `bool get is18Plus => !isKidsOnly;`. Tự động nhận diện nhãn 18+ qua các tag (`#18+`, `18+`, `[18+]`) hoặc trường `age_rating`.
  - Màn hình tải video (`UploadScreen`): Khi người dùng chọn "Không, video không dành cho trẻ em (18+)", hệ thống tự động gắn tag `18+` và thiết lập `kidsOnly: false`.
- **Huy hiệu cảnh báo 18+ trên Thumbnail:**
  - `VideoThumb`: Hiển thị badge màu đỏ `🔞 18+` bo góc bán trong suốt ở góc trên cùng bên trái của tất cả thumbnail trên Trang chủ, Thịnh hành, Tìm kiếm, Đăng ký.
- **Khóa bảo vệ rạp chiếu 16:9 (WatchScreen Age Gate):**
  - Khi video là 18+ và người dùng chưa đăng nhập hoặc có độ tuổi < 18 (hoặc chưa khai báo tuổi), màn hình **hoàn toàn không nạp VideoSurface** (ngăn chặn 100% việc tải luồng video và âm thanh từ Cloudinary).
  - Thay vào đó, hiển thị giao diện rạp phim cảnh báo 18+ với biểu tượng tròn đỏ, thông báo lý do rõ ràng theo từng trường hợp (chưa đăng nhập, dưới 18 tuổi, hoặc cần cập nhật tuổi).
  - Cung cấp nút tiện ích: **[ Đăng nhập ngay ]** (mở `AuthScreen`), **[ Cập nhật tuổi ]** (mở `AccountScreen`), và **[ Quay lại ]**.
- **Khóa bảo vệ lướt video ngắn kiểu TikTok (QuickWatchPage):**
  - Chặn ngay tại tầng khởi tạo: kiểm tra `_is18Blocked`, không gọi `_initialize()` hay `_play()`.
  - Hiển thị lớp phủ Age Gate màu đen toàn màn hình phong cách TikTok kèm huy hiệu `18+`, cảnh báo người xem và hướng dẫn "Vuốt lên để xem video tiếp theo".

---

### 3.5. Quy chuẩn về cài đặt iOS (.ipa)
- Định dạng `.apk` chỉ cài được trên Android.
- Định dạng `.ipa` của iOS KHÔNG thể tạo bằng cách đổi tên tệp hay chỉnh sửa file thủ công; bắt buộc phải build trên macOS có Xcode và có chứng chỉ/tài khoản Apple Developer (hoặc dịch vụ CI/CD macOS như GitHub Actions / Codemagic).

---

### 3.17. Lưu trữ Video dung lượng lớn trên Google Drive 400 GB (Kiến trúc Hybrid Google Drive + Cloudinary)
- **Kiến trúc lưu trữ kết hợp (Hybrid Storage Architecture):**
  - **Google Drive Storage (400 GB+):** Lưu trữ toàn bộ các tệp video tải lên (`videoUrl` phát luồng trực tiếp `https://drive.google.com/uc?export=download&id=...`). Video được tổ chức trong thư mục `TIKTUBE_VIDEOS` (ID: `19KOpd7VOawrH2J_E8zbNkJagHloqFPRI`).
  - **Cloudinary CDN (`fvqm3bbv` / `qfgja134`):** Tiếp tục lưu trữ thumbnail video, ảnh đại diện người dùng, và ảnh trong tin nhắn chat thời gian thực.
  - **Cơ chế dự phòng tự động (Auto Fallback):** Nếu Google Drive gặp sự cố hoặc chưa cấu hình, hệ thống tự động fallback tải lên Cloudinary mà không gián đoạn người dùng.
- **Xác thực OAuth 2.0 (Direct Quota Usage):**
  - Service Account bị Google chặn do quota 0 MB trên My Drive.
  - Hệ thống sử dụng giao thức OAuth 2.0 Offline Access với `RefreshToken` (`GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, `GOOGLE_OAUTH_REFRESH_TOKEN`).
  - `autoRefreshingClient` tự động gia hạn token vĩnh viễn, tiêu thụ trực tiếp vào hạn mức 400 GB của tài khoản `kietphan4444@gmail.com`.
  - Quản lý tệp hai chiều: hỗ trợ xóa video tự động trên Google Drive khi xóa video trong database (`DELETE /api/videos/<id>`).

---

### 3.18. Cơ chế Bắt máy Cuộc gọi thật & Bản chất Âm thanh đàm thoại (Socket.io Signaling vs WebRTC)
- **Sửa lỗi tự động kết nối sau 3 giây (Fix Auto-connected Call Bug):**
  - Trước đây: `CallOverlay` trong `initState` có bộ hẹn giờ cứng `Timer(const Duration(milliseconds: 3000))` tự động kích hoạt `_connected = true` và nhảy đồng hồ `00:01, 00:02...` dù bên người nhận chưa hề bấm nút nghe máy.
  - Khắc phục: Đã xóa bỏ hoàn toàn bộ hẹn giờ 3 giây giả lập. Bên gọi (`isIncoming == false`) hiện giữ trạng thái `"Đang đổ chuông..."` và chỉ chuyển sang `"Connected / Đang đàm thoại"` KHI VÀ CHỈ KHI nhận được sự kiện Socket.io `call:answered` từ phía người nhận.
  - Bổ sung cơ chế Timeout: Nếu sau 45 giây người nhận không bấm máy, hệ thống tự động ngắt cuộc gọi với thông báo "Người nhận không trả lời".
  - Bổ sung sự kiện Từ chối: Khi người nhận bấm nút đỏ Từ chối, bên gọi lập tức hiển thị thông báo "Cuộc gọi bị từ chối" và tự động đóng màn hình gọi.
- **Bản chất Mic, Loa & Truyền giọng nói trực tiếp (Signaling Server vs Media Server):**
  - Hệ thống hiện tại sử dụng **Socket.io Signaling Server** (`nhantinptk.onrender.com`): Quản lý tín hiệu phát cuộc gọi (`initiate`), rung chuông native (`RingtoneManager`), thông báo đẩy cuộc gọi đến (`incoming`), chấp nhận (`answered`), kết thúc (`ended`), từ chối (`rejected`), và mở phần cứng camera trước (`camera: ^0.12.2`) kèm đếm thời lượng.
  - Để truyền giọng nói thật qua lại giữa 2 micro và 2 loa ngoài thiết bị theo thời gian thực (P2P real-time audio), hệ sinh thái cần bổ sung giao thức **WebRTC (Web Real-Time Communication)** với máy chủ STUN/TURN server để bypass NAT/Firewall và mã hóa luồng media track.

---

### 3.19. Tích hợp Truyền âm thanh trực tiếp qua WebRTC P2P (Live Voice Call via Google STUN)
- **Thư viện chuẩn:** `flutter_webrtc: ^1.6.3`.
- **Dịch vụ WebRtcService (`lib/services/webrtc_service.dart`):**
  - Cụm STUN Server Google: `stun:stun.l.google.com:19302`, `stun:stun1.l.google.com:19302`, `stun:stun2.l.google.com:19302`, `stun:stun3.l.google.com:19302`, `stun:stun4.l.google.com:19302`.
  - Phía người gọi (Caller): Mở microphone bằng `navigator.mediaDevices.getUserMedia({'audio': true, 'video': false})`, khởi tạo `createPeerConnection`, thêm local audio track, tạo SDP Offer và gom ứng viên STUN (Vanilla ICE) gửi kèm qua `call:initiate`.
  - Phía người nhận (Receiver): Mở microphone, tạo `createPeerConnection`, thêm local audio track, nạp remote offer, tạo SDP Answer và gom ứng viên STUN gửi về qua `call:answer`.
  - Hai chiều thông tuyến: Khi người gọi nhận được answer, nạp vào `setRemoteDescription`, kết nối P2P được thiết lập thành công. Âm thanh giọng nói từ micro máy A truyền trực tiếp qua loa máy B và ngược lại theo thời gian thực với độ trễ thấp (low-latency Opus audio).
  - Hỗ trợ Trickle ICE dự phòng: Tự động phát hiện và chuyển tiếp ứng viên `call:ice-candidate` qua Socket.io.
  - Điều khiển phần cứng: Nút Mic gọi `WebRtcService.instance.setMicrophoneMute(muted)`, nút Loa gọi `WebRtcService.instance.setSpeakerphoneOn(enabled)` qua `Helper.setSpeakerphoneOn`.
  - Giải phóng tài nguyên: Khi gác máy hoặc đóng overlay, tự động dừng audio tracks, đóng peer connection và giải phóng toàn bộ luồng media.
  - Cấp quyền Android trong `AndroidManifest.xml`: `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`, `ACCESS_NETWORK_STATE`, `BLUETOOTH`, `BLUETOOTH_CONNECT`.

---

### 3.20. Hỗ trợ người dùng iOS qua PWA (Progressive Web App) & GitHub Pages
- **Cấu hình PWA cho iOS (`web/index.html` & `web/manifest.json`):**
  - Thẻ nhận diện đặc quyền Apple: `<meta name="apple-mobile-web-app-capable" content="yes">`, `<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">`, `<meta name="apple-mobile-web-app-title" content="TIKTUBE">`.
  - Icon PWA: Cung cấp `apple-touch-icon` các kích cỡ 192x192 và 512x512.
  - Manifest: Khai báo `display: standalone`, `theme_color: #0F172A`, `background_color: #0F172A`.
  - Tự động ẩn toàn bộ thanh điều hướng của Safari, mở toàn màn hình (Standalone) như App tải từ App Store.
- **Triển khai Web lên GitHub Pages:**
  - Thư mục phát hành web tĩnh: `docs/` chứa toàn bộ bản build web Flutter (`index.html`, `404.html`, `manifest.json`, `main.dart.js`, `assets/`, `canvaskit/`).
  - Hỗ trợ định tuyến Single Page App: Tệp `docs/404.html` đồng bộ với `index.html` ngăn chặn lỗi 404 khi người dùng refresh hoặc truy cập trực tiếp URL.
  - GitHub Actions Workflow: `.github/workflows/deploy_pages.yml` tự động build và deploy lên GitHub Pages mỗi khi có commit mới trên nhánh `main`.
  - Địa chỉ Web PWA dành cho người dùng iOS: `https://kietphan2812.github.io/TIKTUBEPTK_DIENTHOAI/`.

---

### 3.21. Đăng nhập Google thật (Google Identity Services & google_sign_in)
- **Thư viện chuẩn:** `google_sign_in: ^7.2.0`.
- **Cấu hình Google Cloud Console (Dự án `elegant-matrix-514123-i9`):**
  - Trạng thái công bố: **In production** (Sẵn sàng phục vụ mọi người dùng có tài khoản Google mà không bị giới hạn Test Users).
  - Web Client ID: `767308821556-4ofr0c7a66p78md3nrq1svn03i1u7q0a.apps.googleusercontent.com`.
  - Android Keystore & SHA-1: Debug keystore `C:\Users\DELL\.android\debug.keystore`, Package name `com.example.flutter_app_ptk`, SHA-1: `59:26:6F:76:C9:0A:0B:A0:BB:7F:EE:C0:47:88:5C:C0:D8:4B:60:DB`.
  - Tích hợp GIS SDK: `<script src="https://accounts.google.com/gsi/client" async defer></script>` và thẻ `<meta name="google-signin-client_id" ...>` trong `web/index.html`.
- **Dịch vụ `GoogleAuthService` (`lib/utils/google_auth_service.dart`):**
  - Khởi tạo `GoogleSignIn.instance.initialize(clientId: kIsWeb ? googleClientId : null, serverClientId: googleClientId)`. Việc truyền `serverClientId: googleClientId` là bắt buộc trên Android để Google Play Services / Credential Manager hoạt động bình thường, khắc phục lỗi `serverClientId must be provided on Android`.
  - Trên Web: Sử dụng widget Google Sign-In chính thức thông qua `buildGsiButton(...)` (renderButton) và lắng nghe sự kiện `authenticationEvents`.
  - Trên Mobile / Desktop: Xác thực người dùng bằng `GoogleSignIn.instance.authenticate(scopeHint: ['email', 'profile', 'openid'])`.
  - Hiển thị hộp thoại Google Account Chooser chính thức (`accounts.google.com`) liệt kê toàn bộ các tài khoản Google đã lưu trong trình duyệt hoặc thiết bị của người dùng.
  - Loại bỏ hoàn toàn bottom sheet giả lập cũ.
  - Tự động nạp `email`, `name`, `avatarUrl` và đăng nhập/tạo tài khoản trên TIKTUBE qua `AuthController.loginWithGoogle()`.

---

### 3.22. Trích xuất Thumbnail tự động, Toàn trang Sửa video kèm Ảnh bìa & Danh sách Người theo dõi thật
- **Trích xuất ảnh Thumbnail tự động & Khắc phục thời lượng `--:--`:**
  - Bổ sung getter `effectiveThumbnailUrl` trong [Video](file:///d:/flutter_app_ptk/lib/models/video.dart): hỗ trợ nhận diện và trích xuất ảnh bìa chất lượng cao từ cả Google Drive (`https://lh3.googleusercontent.com/d/<DRIVE_ID>`) lẫn Cloudinary frame 2s (`/upload/so_2,w_640,h_360,c_fill/...jpg`).
  - Tự động phát hiện và chuyển đổi các link Cloudinary giả chứa ID Google Drive sang URL thumbnail chính thức của Google Drive.
  - Đã chạy cập nhật trực tiếp 51 video trong bảng `video` của Neon PostgreSQL sang URL thumbnail thật `https://lh3.googleusercontent.com/d/<id>`, giải quyết triệt để tình trạng video không có hình bìa trên cả Web, Mobile và Desktop.
  - Cập nhật [VideoThumb](file:///d:/flutter_app_ptk/lib/widgets/video_thumb.dart) và [QuickWatchPage](file:///d:/flutter_app_ptk/lib/widgets/quick_watch_page.dart) sử dụng `effectiveThumbnailUrl`.
  - Với các video có thời lượng <= 0, ẩn hoàn toàn badge thời lượng thay vì hiển thị `--:--` gây mất thẩm mỹ.
- **Trang Sửa video toàn diện (`UploadScreen(editVideo: video)`):**
  - Loại bỏ hoàn toàn hộp thoại sửa video popup nhỏ hẹp cũ (`_EditVideoDialog`) trong [HistoryScreen](file:///d:/flutter_app_ptk/lib/screens/history_screen.dart).
  - Khi bấm "Sửa video", ứng dụng chuyển thẳng sang toàn bộ màn hình [UploadScreen](file:///d:/flutter_app_ptk/lib/screens/upload_screen.dart) ở chế độ biên tập: nạp sẵn tiêu đề, mô tả, danh mục, thẻ hashtag, chế độ trẻ em và ảnh thumbnail hiện tại.
  - Tích hợp tính năng **Chọn ảnh bìa từ thiết bị**: người dùng có thể bấm "Chọn ảnh bìa" để tải ảnh thumbnail mới từ máy lên Cloudinary (`ChatService.instance.uploadImage`) hoặc xoá ảnh bìa tuỳ thích.
  - Hỗ trợ xem trước video đã đăng ngay trong khung phát preview 16:9.
- **Kích hoạt Tab Người theo dõi / Người đăng ký (Subscribers):**
  - Backend API: Thêm endpoint `GET /api/subscribers` và hàm `listSubscribers()` trong `server/lib/db.dart` & `server/lib/api.dart`. Sửa lỗi mệnh đề sắp xếp bảng `dang_ky_kenh` từ `ngay_tao` sang đúng tên cột `ngay_dang_ky`, truy vấn chuẩn xác danh sách người đăng ký của tài khoản.
  - Client API: Bổ sung `fetchSubscribers()` trong `TikTubeApi` và `ApiClient`.
  - Màn hình Đăng ký ([SubscriptionsScreen](file:///d:/flutter_app_ptk/lib/screens/subscriptions_screen.dart)): Tab 2 ("Người theo dõi") hiển thị danh sách người dùng đang theo dõi kênh của bạn với avatar, tên, username, số video, và nút Đăng ký lại / Huỷ đăng ký hai chiều mượt mà.
  - Cập nhật thư mục `docs/` để đồng bộ bản dựng Web PWA mới nhất lên GitHub Pages.

---

### 3.23. Cắt ảnh bìa từ Video khi Đăng/Sửa, Thời lượng Video Neon SQL & Sửa lỗi 401 Kênh
- **Cắt ảnh từ video làm ảnh bìa (Frame Capture):**
  - Thêm nút `[ 📸 Cắt ảnh ($posLabel) ]` ngay trên khung phát video xem trước trong [UploadScreen](file:///d:/flutter_app_ptk/lib/screens/upload_screen.dart) (cả khi đăng mới và chỉnh sửa video).
  - Người dùng có thể tua/dừng ở bất kỳ giây nào và bấm "Cắt ảnh" để chụp lại khung hình hiện tại làm ảnh bìa thumbnail.
  - Triển khai đa nền tảng:
    - Android Native: Tích hợp qua MethodChannel `com.example.flutter_app_ptk/app_control` với hàm `getVideoFrame(path/url, timeUs)` sử dụng `MediaMetadataRetriever` (resize 1280x720, nén JPEG).
    - Fallback / Web: [video_frame_capture_web.dart](file:///d:/flutter_app_ptk/lib/utils/video_frame_capture_web.dart) dùng HTML5 `<video>` vẽ lên `<canvas>` toDataURL, kết hợp [RenderRepaintBoundary](file:///d:/flutter_app_ptk/lib/utils/video_frame_capture_io.dart).
  - Ảnh cắt ra được lưu tự động lên Cloudinary và lưu vào trường `hinh_thu_nho` trên Neon PostgreSQL khi bấm "Đăng video" / "Lưu thay đổi".
- **Đồng bộ thời lượng (Duration) cho toàn bộ 100% video trên Neon PostgreSQL:**
  - Đã truy vấn API Google Drive `videoMediaMetadata.durationMillis` và cập nhật chính xác thời lượng thực cho toàn bộ 17 video trước đó bị thiếu thời lượng (0 hoặc null) trong bảng `video` của Neon DB (ví dụ: `ông lão đánh cá au` -> 26s (`0:26`), `dancing` -> 7s (`0:07`), v.v.).
  - Khi tải video mới lên, ứng dụng tự động lấy `duration` từ `VideoPlayerController` và lưu trực tiếp `durationSeconds` vào API backend để lưu vào Neon DB, đảm bảo không bao giờ bị thiếu thời lượng.
- **Khắc phục lỗi 401 & Hiển thị toàn bộ video của Kênh ([ChannelScreen](file:///d:/flutter_app_ptk/lib/screens/channel_screen.dart)):**
  - Sửa lỗi 401: Bọc try/catch cho lời loại `_api.fetchSubscriptions()`, cho phép khách vãng lai (chưa đăng nhập) vào xem trang kênh mà không bị văng thông báo lỗi `ApiException(401): Bạn cần đăng nhập để tiếp tục.`.
  - Lọc video chuẩn theo kênh: Bổ sung tham số `channelId` và `channel` vào endpoint `GET /api/videos` tại backend (`server/lib/api.dart` & `server/lib/db.dart`), giải quyết triệt để lỗi kênh chỉ hiển thị 1 video.

---

### 3.24. Nâng cấp Độ nét Ảnh bìa (Full-HD Clarity) & Giao diện Rạp chiếu phim Ambient Cinema
- **Khắc phục triệt để tình trạng ảnh bìa bị mờ, vỡ hạt:**
  - **Lỗi cũ:** Trước đây thẻ [VideoThumb](file:///d:/flutter_app_ptk/lib/widgets/video_thumb.dart) dùng `BoxFit.cover` trong khung `16:9`. Với các video dọc TikTok/Shorts (tỷ lệ 9:16), `BoxFit.cover` phóng to khung hình lên hơn 316% ($3.16\times$) và cắt bỏ 70% nội dung (bị mất phần trên/dưới, chỉ còn một góc nhỏ bị phóng to vỡ hạt). Đồng thời `Video.effectiveThumbnailUrl` trước đây ưu tiên trích xuất ID Google Drive từ `videoUrl` khiến các ảnh bìa HD tải lên Cloudinary hoặc ảnh cắt từ video bị bỏ qua và rơi về thumbnail 360p mặc định của Drive.
  - **Thiết kế Ambient Cinema View chuẩn YouTube:**
    - Lớp nền lan tỏa: Sử dụng ảnh bìa phủ toàn khung kết hợp `BackdropFilter(blur: 16x16)` và lớp tối rạp phim `Colors.black45`, tạo dải màu ambient hiện đại tự nhiên theo tông của video.
    - Lớp ảnh chính: Sử dụng `BoxFit.contain` kết hợp `filterQuality: FilterQuality.high`. Toàn bộ video (dọc TikTok, ngang 16:9 hay vuông 1:1) đều hiển thị trọn vẹn 100% tỷ lệ gốc, hoàn toàn không bị zoom cắt xén 300% nên ảnh giữ nguyên độ nét gốc và sắc nét hơn gấp 3 lần.
  - **Ưu tiên ảnh bìa HD chất lượng cao (`effectiveThumbnailUrl`):**
    - Ưu tiên hàng đầu ảnh thumbnail thực tế (Cloudinary, ảnh chụp từ video). Nâng cấp link Cloudinary video thumbnail sang `w_1280,h_720,c_fill,q_auto:best`.
    - Native Android (`MainActivity.kt`): `getVideoFrame` trích xuất khung hình ở độ phân giải gốc của video qua `MediaMetadataRetriever.OPTION_CLOSEST` và nén JPEG chất lượng 95%, đảm bảo ảnh cắt từ video có độ nét đạt chuẩn 1080p/720p hệt như đang xem video.

---

## 4. GHI NHỚ MÔI TRƯỜNG MÁY CHỦ & CLIENT
- **Hệ điều hành máy người dùng:** Windows.
- **Lệnh PowerShell:** Dùng dấu `;` để nối chuỗi lệnh thay vì `&&`.
- **Thư viện FilePicker:** Phiên bản hiện tại `file_picker: ^13.1.0` sử dụng phương thức `FilePicker.pickFile(...)`, không dùng `.platform.pickFiles(...)`.
- **Mã màu AppTheme:**
  - `context.palette` cung cấp `PtPalette` (`p.bg`, `p.surface`, `p.border`, `p.chip`, `p.textPrimary`, `p.brandRed`, v.v.).
  - Kiểm tra giao diện tối dùng `Theme.of(context).brightness == Brightness.dark`.
