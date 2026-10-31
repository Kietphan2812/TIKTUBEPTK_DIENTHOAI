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

### 3.10. Lưu số điện thoại vĩnh viễn theo tài khoản (UserPreferences)
- **Cơ chế lưu trữ vĩnh viễn:**
  - Tạo `UserPreferences` lưu trữ vĩnh viễn số điện thoại theo khóa riêng biệt `tiktube_permanent_phone_<userKey>` trên thiết bị. Khóa này KHÔNG bị xóa khi người dùng đăng xuất.
  - Khi người dùng đăng nhập lại (`AuthController.login()`), hệ thống tự động tìm và gắn lại số điện thoại đã lưu vào hồ sơ người dùng.
  - Khi mở trang Tài khoản (`AccountScreen`), nếu số điện thoại chưa kịp tải từ máy chủ, hệ thống tự động phục hồi từ `UserPreferences.getUserPhone` và điền lại vào ô nhập ngay lập tức.
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

---

### 3.5. Quy chuẩn về cài đặt iOS (.ipa)
- Định dạng `.apk` chỉ cài được trên Android.
- Định dạng `.ipa` của iOS KHÔNG thể tạo bằng cách đổi tên tệp hay chỉnh sửa file thủ công; bắt buộc phải build trên macOS có Xcode và có chứng chỉ/tài khoản Apple Developer (hoặc dịch vụ CI/CD macOS như GitHub Actions / Codemagic).

---

## 4. GHI NHỚ MÔI TRƯỜNG MÁY CHỦ & CLIENT
- **Hệ điều hành máy người dùng:** Windows.
- **Lệnh PowerShell:** Dùng dấu `;` để nối chuỗi lệnh thay vì `&&`.
- **Thư viện FilePicker:** Phiên bản hiện tại `file_picker: ^13.1.0` sử dụng phương thức `FilePicker.pickFile(...)`, không dùng `.platform.pickFiles(...)`.
- **Mã màu AppTheme:**
  - `context.palette` cung cấp `PtPalette` (`p.bg`, `p.surface`, `p.border`, `p.chip`, `p.textPrimary`, `p.brandRed`, v.v.).
  - Kiểm tra giao diện tối dùng `Theme.of(context).brightness == Brightness.dark`.
