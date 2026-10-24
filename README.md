# TIKTUBE — Flutter + Neon Postgres + Cloudinary

Bản dựng lại giao diện **TIKTUBE** (trang xem & chia sẻ video của PTK) bằng Flutter,
kèm REST API viết bằng Dart, dùng chung database Neon với web app và lưu video trên
Cloudinary.

Phiên bản Android đang phát hành: **1.0.11+12** (APK cài trực tiếp, trỏ API
`https://tiktube-api.onrender.com`).

## Kiến trúc

```
Flutter (web/desktop/mobile)
      │  HTTP + JSON (CORS) + Bearer token
      ▼
Dart server (shelf) — server/
      │  postgres driver (SSL)
      ▼
Neon Postgres — TIKTUBETPK / production / neondb
      │  schema web: nguoi_dung, video, binh_luan, luot_thich, ...
      └── Cloudinary Upload API (ký phía server)

Flutter ── gửi file ──► Dart server ── ký upload ──► Cloudinary
                                   └── ghi metadata vào bảng video
```

- App **không kết nối trực tiếp** vào database hay Cloudinary. Mật khẩu DB và
  `CLOUDINARY_API_SECRET` chỉ nằm ở `server/.env`, không nhúng vào Flutter.
- **Không dùng dữ liệu mẫu trong UI.** Tất cả màn hình đọc từ API; khi API lỗi sẽ
  hiện trạng thái lỗi kèm nút **Thử lại**, không tự rơi về dữ liệu hard-code.
- App **không tạo schema video/người dùng song song**. Video đăng từ web và từ app
  cùng nằm trong bảng `video`; bình luận, lượt thích, đăng ký kênh, lịch sử xem
  cũng dùng đúng các bảng web đang dùng.
- Phần riêng của app gồm bảng `app_sessions` (phiên đăng nhập), bảng
  `app_saved_videos` (video đã lưu) và cột nullable `nguoi_dung.ten_hien_thi`
  (tên hiển thị trong app). Cột này không làm thay đổi `ten_dang_nhap` mà web
  dùng để đăng nhập.
- **Đăng nhập thật:** tài khoản web hiện lưu SHA-256 dạng 64 ký tự hex. App xác
  thực đúng định dạng này và tài khoản mới do app tạo cũng lưu SHA-256 hex để
  đăng nhập được trên cả web lẫn app. Phiên là token ngẫu nhiên 256-bit; server
  chỉ lưu SHA-256 của token trong `app_sessions`.
- Flutter giữ token trong `localStorage` (web) và gửi qua header `Authorization`.
- Nhãn cạnh feed **Dành cho bạn / Video mới** hiển thị **“Neon SQL”** khi tải được
  dữ liệu, hoặc **“Chưa kết nối”** khi API không phản hồi.
- Trang chủ mặc định mở **Dành cho bạn**; chuyển sang **Mới nhất** để xem đúng thứ
  tự thời gian. Feed mới được tải lại mỗi **10 giây**; gợi ý cá nhân hóa được tính
  lại mỗi **30 giây**, sau khi xem video hoặc khi quay lại tab.
- Màn hình **Xem video** là feed dọc toàn màn hình, tự phát video đang hiển thị và
  tạm dừng video khi vuốt sang trang khác. Ba tab **Đã follow / Bạn bè / Dành cho
  bạn** lấy dữ liệu thật từ Neon; thích, lưu và theo dõi kênh được ghi ngay vào
  database. Video đã xem được lưu thời lượng để cải thiện gợi ý.
- **Bạn bè** gồm video mới từ những kênh người dùng đã thích, bình luận hoặc xem
  trong **90 ngày** gần nhất. Nếu chưa đủ tín hiệu, app lần lượt dùng feed kênh đã
  đăng ký rồi đến video xu hướng, không dùng danh sách bạn bè giả.
- Trong màn hình xem nhanh, chuông thông báo tự làm mới mỗi **8 giây**; thông báo
  mới hiện banner ngay trên video. **Đăng video** mở lựa chọn **Đăng video nhanh**
  (tự điền tiêu đề từ tên tệp, hashtag gợi ý theo danh mục) hoặc **Đăng video
  TIKTUBE** (biểu mẫu đầy đủ với xem trước).

## Dữ liệu thật đang dùng

| Màn hình / chức năng | Nguồn dữ liệu |
|---|---|
| Đăng nhập / Đăng ký | `nguoi_dung` + `app_sessions` — tạo phiên thật |
| Trang chủ | `video` + `nguoi_dung` + `danh_muc` — video đã duyệt |
| Dành cho bạn | `lich_su_xem` (kèm thời lượng xem), `luot_thich`, `binh_luan`, `video`, `danh_muc`, `the_tag`, `dang_ky_kenh` — xếp hạng bằng SQL |
| Video xu hướng | `video`, `luot_thich`, `binh_luan`, `lich_su_xem`, `dang_ky_kenh` — xếp hạng bằng SQL |
| Video từ kênh đã đăng ký | `video` + `dang_ky_kenh` — chỉ video đã duyệt của kênh đang theo dõi |
| Xem nhanh — Đã follow | `video` + `dang_ky_kenh` — video mới từ kênh đã đăng ký |
| Xem nhanh — Bạn bè | `luot_thich`, `binh_luan`, `lich_su_xem` (90 ngày) → kênh đã tương tác + `video` |
| Xem nhanh — Dành cho bạn | `GET /api/feed/for-you` + tín hiệu xu hướng `GET /api/videos/trending` khi cần |
| Lưu video | `app_saved_videos` — lưu/bỏ lưu thật theo tài khoản, khôi phục trạng thái khi tải lại |
| Xem video | `video`, `binh_luan`, `luot_thich`, `lich_su_xem`, `dang_ky_kenh`; lưu thêm thời lượng đã xem/phần trăm hoàn thành |
| Đăng video | `POST /api/videos/upload` — file đi qua server, lưu Cloudinary, ghi `video` + `lich_su_dang_video` + `kiem_duyet_video` |
| Gợi ý thẻ tag | `the_tag` + `danh_muc` — `GET /api/tags?category=...`, đổi danh mục sẽ tải lại đúng tag của danh mục đó |
| Đăng ký kênh | `dang_ky_kenh` (kênh chính là `nguoi_dung`) |
| Lịch sử | `lich_su_xem`; tab **Video đã đăng** đọc `video` của chính người dùng |
| Thống kê | tổng hợp từ `video`, `luot_thich`, `binh_luan`, `lich_su_xem`; app cũng cập nhật `thong_ke` khi có xem/thích/bình luận |
| Tài khoản | `nguoi_dung` — hồ sơ thật; đăng xuất xoá phiên |

Video web đã duyệt hiện có (ví dụ `Nhạc Mỹ Nhân`, `Ai Là Người Thương Em`, ...)
được app đọc trực tiếp từ `video`; tiêu đề, mô tả, hashtag, thumbnail, lượt xem,
lượt thích và bình luận đều là dữ liệu SQL thật.

Video bị web từ chối vẫn hiện trong tab **Video đã đăng** của chủ video, kèm nhãn
**Bị từ chối**; video chờ duyệt có nhãn **Chờ duyệt**. Trang chủ chỉ hiện video
đã duyệt.

Trong màn hình **Đăng video**, ngay sau khi chọn file, video tự phát trong khung
xem trước (lặp lại, có thanh tiến trình và nút tắt/bật âm thanh; trên web tự phát
ở chế độ tắt tiếng để đúng chính sách autoplay của trình duyệt). Danh sách thẻ
tag bên dưới lấy từ `the_tag` theo `danh_muc` đang chọn, không dùng danh sách cố
định; đổi danh mục sẽ xoá tag đã chọn và tải lại gợi ý của danh mục mới.

### Cách tính điểm xu hướng

Điểm được tính hoàn toàn trong SQL trên Neon, không dùng dữ liệu mẫu:

```
score = 100 × (
    2·ln(1 + tổng lượt xem)
  + 5·ln(1 + lượt thích)
  + 7·ln(1 + bình luận)
  + 9·ln(1 + người xem duy nhất trong kỳ)
  + 0.8·ln(1 + người đăng ký kênh)
) / (tuổi_video_ngày + 2)^0.65
```

- Kỳ xem có thể là **24 giờ**, **7 ngày** hoặc **30 ngày**; số người xem được
  đếm duy nhất từ `lich_su_xem.thoi_gian_xem`.
- Hàm `ln` giúp video mới, ít lượt vẫn có cơ hội cạnh tranh; mẫu số làm giảm dần
  điểm của video cũ.
- API `GET /api/videos/trending` xếp hạng lại theo điểm, sau đó mới đến ngày
  đăng. App tự làm mới mỗi 10 giây và có màn hình **Xu hướng** riêng để đổi kỳ
  xem, lọc danh mục, xem điểm và số người xem gần đây.

### Cách tính feed “Dành cho bạn”

`GET /api/feed/for-you` tính trực tiếp trên Neon, không lưu snapshot gợi ý giả:

- Cửa sổ hành vi mặc định **30 ngày**, suy giảm theo thời gian với bán thời gian
  **14 ngày**.
- Mỗi lần xem có trọng số `1 + 2 × tỷ_lệ_hoàn_thành`; tỷ lệ lấy từ
  `lich_su_xem.thoi_luong_xem / lich_su_xem.thoi_luong_video` (video cũ chưa có
  thời lượng được tính mức trung bình).
- Lượt thích có trọng số **4**, bình luận có trọng số **5**.
- Điểm sở thích cộng dồn theo **danh mục** và **hashtag**; hashtag lấy từ
  `video.mo_ta` (dạng `#tag`) và `the_tag.ten_tag` nếu video có `tag`.
- Video thuộc kênh người dùng đã đăng ký được **xếp trước** nếu còn trong
  **45 ngày** gần đây; sau đó mới xếp theo điểm sở thích, tín hiệu xu hướng toàn
  app (lượt xem, like, bình luận, người xem gần đây, người đăng ký kênh) và độ
  mới.
- Video vừa xem trong 2 ngày bị trừ nhẹ điểm để gợi ý đa dạng hơn. Thứ tự trong
  ngày có tie-breaker theo `video_id + ngày`, nên không đổi liên tục giữa các lần
  tải.
- Người chưa đăng nhập hoặc chưa đủ lịch sử nhận tín hiệu xu hướng + kênh đã
  đăng ký; response ghi rõ `personalized`, `reason`, `windowDays`, `forDate`.
- Mỗi item có `recommendationScore` và `recommendationReason`
  (`subscription`, `category_tag`, `category`, `tag`, `trending`) để kiểm tra.
- **Video liên quan** trong màn hình xem được ưu tiên theo cùng danh mục, hashtag
  chung, cùng kênh, rồi mới đến lượt xem.

### Ghi thời lượng xem

Khi phát video, `VideoSurface` báo vị trí hiện tại. Màn hình xem lưu mốc xa nhất
mỗi 10 giây, khi app bị đưa xuống nền và khi đóng màn hình qua:

```http
POST /api/videos/<id>/watch-progress
Authorization: Bearer <token>
Content-Type: application/json

{"watchedSeconds": 42, "durationSeconds": 120}
```

Server cập nhật dòng `lich_su_xem` gần nhất (không tăng lượt xem lần hai) vào hai
cột mới `thoi_luong_xem` và `thoi_luong_video`. Hai cột được thêm tự động bằng
`ensureAppSchema` khi API khởi động hoặc bằng `setup_target_db.dart`.

## Chạy dự án

### 1. Cấu hình server

```bash
cd server
cp .env.example .env
```

Điền vào `server/.env`:

```dotenv
DATABASE_URL=postgresql://user:password@ep-xxx.region.aws.neon.tech/neondb?sslmode=require
PORT=8787
CLOUDINARY_CLOUD_NAME=...
CLOUDINARY_API_KEY=...
CLOUDINARY_API_SECRET=...
```

> Có thể dán nguyên chuỗi Neon từ Console (kể cả `channel_binding`) — server tự bỏ
> tham số này. Host direct hoặc pooled đều chạy được.

### 2. Chuẩn bị database đích

Database `TIKTUBETPK` / branch `production` / database `neondb` **đã có schema và
dữ liệu web**. Không chạy `bin/init_db.dart` (script cũ đã bị vô hiệu hoá để tránh
tạo schema song song).

Chạy một lần:

```bash
cd server
dart pub get
dart run bin/setup_target_db.dart
```

Script này chỉ:

- tạo bảng `app_sessions` nếu chưa có;
- thêm cột nullable `nguoi_dung.ten_hien_thi` nếu chưa có;
- thêm `lich_su_xem.thoi_luong_xem` và `lich_su_xem.thoi_luong_video` (mặc định 0);
- thêm index cho lịch sử xem / lượt thích / bình luận theo người dùng và thời gian;
- tạo tài khoản demo `kiepthan4` nếu chưa tồn tại.

Không xoá, không ghi đè người dùng, video, bình luận, lượt thích hay dữ liệu admin
hiện có. Có thể chạy lại nhiều lần.

### 3. Chạy API

```bash
cd server
dart run bin/server.dart
```

- API: http://localhost:8787
- Health check: http://localhost:8787/health (trả về `cloudinary: true` khi đã cấu hình)
- CORS cho phép Flutter web gọi trực tiếp.
- Lần truy vấn Neon đầu tiên sau khi idle có thể mất vài giây. App có trạng thái
  loading và timeout 25 giây; upload có timeout 5 phút.

### 4. Chạy Flutter

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8787
```

Hoặc build bản web tĩnh:

```bash
flutter build web --release
cd build/web
python -m http.server 8080
```

Mở http://127.0.0.1:8080 (hoặc bản đang chạy ở http://127.0.0.1:62845).

### 5. Tài khoản demo

```text
Tên đăng nhập: kiepthan4
Email:         kiepthan4@local.test
Mật khẩu:      TikTube@123
```

Tài khoản này do `setup_target_db.dart` tạo trong `nguoi_dung` nên web cũng có thể
đăng nhập được. Người dùng web cũ (ví dụ `PTK`, `kietphan4`, ...) đăng nhập bằng
đúng tên đăng nhập/email và mật khẩu web hiện tại. Đăng ký tài khoản mới sẽ tạo
người dùng thật trong Neon và tự động đăng nhập.

## Đồng bộ web → app

- Web và app dùng chung bảng `video`; không cần job đồng bộ riêng.
- Web upload → ghi `video` → app gọi `GET /api/videos` và thấy video sau tối đa
  khoảng 10 giây (polling), hoặc bấm nút tải lại.
- App upload → ghi `video` với `trang_thai = 'da_duyet'`, đồng thời ghi
  `lich_su_dang_video` và `kiem_duyet_video` để web thấy trong lịch sử/kiểm duyệt.
- Xoá video trong app sẽ xoá bản ghi `video` (các bảng con cascade) và xoá file
  Cloudinary tương ứng.

## API chính

| Method | Endpoint | Mô tả |
|---|---|---|
| POST | `/api/auth/register` | `{name, username, email, password, age?}` → token + profile |
| POST | `/api/auth/login` | `{login, password}` → token + profile |
| POST | `/api/auth/logout` | Xoá phiên hiện tại (gửi kèm Bearer token) |
| GET | `/health` | Trạng thái API + Cloudinary |
| GET | `/api/categories` | Danh mục |
| GET | `/api/tags?category=...&limit=...` | Thẻ tag đã liên kết với danh mục trong `the_tag` |
| GET | `/api/videos?limit=...` | Danh sách video đã duyệt |
| GET | `/api/videos/trending?days=7&limit=12&category=...` | Bảng xếp hạng xu hướng từ SQL (kèm `trendScore`, `recentViews`) |
| GET | `/api/feed/for-you?days=30&limit=24&category=...` | Feed cá nhân hóa: hành vi + danh mục/hashtag + kênh đã đăng ký + xu hướng; Bearer tùy chọn |
| GET | `/api/videos/<id>` | Chi tiết video |
| POST | `/api/videos/upload` | Body là bytes video (tối đa 100 MB) + query `title`, `description`, `category`, `tags`, `age`, `filename`; server ký upload Cloudinary |
| PATCH | `/api/videos/<id>` | Sửa metadata video |
| DELETE | `/api/videos/<id>` | Xoá video + file Cloudinary |
| GET | `/api/videos/<id>/comments` | Bình luận |
| POST | `/api/videos/<id>/comments` | Gửi bình luận |
| DELETE | `/api/videos/<id>/comments/<commentId>` | Xoá bình luận |
| POST | `/api/videos/<id>/like` | Like/unlike |
| POST | `/api/videos/<id>/save` | `{saved}` — lưu/bỏ lưu video |
| POST | `/api/videos/<id>/view` | Ghi lượt xem + lịch sử |
| POST | `/api/videos/<id>/watch-progress` | `{watchedSeconds, durationSeconds}` — cập nhật thời lượng đã xem, không tăng lượt xem |
| GET | `/api/channels` | Kênh |
| GET | `/api/subscriptions` | Kênh đã đăng ký |
| GET | `/api/feed/subscriptions?limit=30` | Video mới nhất từ các kênh đã đăng ký (cần Bearer token) |
| GET | `/api/feed/friends?limit=30` | Video mới từ kênh đã thích/bình luận/xem trong 90 ngày (cần Bearer token) |
| GET | `/api/saved?limit=50` | Video người dùng đã lưu, mới nhất trước (cần Bearer token) |
| POST/DELETE | `/api/channels/<id>/subscribe` | Đăng ký/huỷ đăng ký |
| GET | `/api/history` | Lịch sử xem |
| DELETE | `/api/history` | Xoá toàn bộ lịch sử |
| DELETE | `/api/history/<videoId>` | Xoá một mục lịch sử |
| GET | `/api/uploads` | Video đã đăng (kèm trạng thái duyệt) |
| GET | `/api/stats` | Thống kê người sáng tạo |
| GET | `/api/notifications` | Thông báo của tài khoản (dùng chung bảng `thong_bao` với web) |
| POST | `/api/notifications/read` | Đánh dấu tất cả thông báo đã đọc |
| POST | `/api/notifications/<id>/read` | Đánh dấu một thông báo đã đọc |
| GET | `/api/me` | Hồ sơ |
| PATCH | `/api/me` | Cập nhật tên/email/tuổi |

Các endpoint đọc công khai như `/api/videos`, `/api/categories`, `/api/tags`,
`/api/videos/trending`, `/api/feed/for-you`, `/api/videos/<id>` vẫn xem được khi
chưa đăng nhập. Riêng `/api/feed/for-you`, nếu gửi kèm Bearer token thì feed được
cá nhân hóa; không có token sẽ trả tín hiệu xu hướng. Endpoint
`/api/feed/subscriptions`, `/api/feed/friends`, `/api/saved`, các endpoint ghi
(upload, bình luận, like, save, view, watch-progress, đăng ký kênh) và dữ liệu
riêng (lịch sử, uploads, stats, thông báo, `/api/me`) yêu cầu header:

```http
Authorization: Bearer <token>
```

Token có hạn 30 ngày. Đăng xuất sẽ xoá token ở server và trong `localStorage`.

## Cấu trúc chính

```
lib/
  auth/            AuthController, AuthScope, lưu phiên localStorage
  data/            ApiClient, TikTubeApi, model parsing
  models/          Video, RecommendedFeed, Channel, Comment, Profile, AuthSession, ...
  screens/         auth, home, quick_watch, quick_upload, upload_choice, trending, watch, upload, notifications, subscriptions, history, stats, account
  widgets/         data_state (loading/error), quick_watch_page, quick_comments_sheet, video_surface (player), ...
server/
  bin/server.dart          HTTP server
  bin/setup_target_db.dart chuẩn bị app_sessions + app_saved_videos + tài khoản demo (idempotent)
  bin/init_db.dart         đã vô hiệu hoá — không dùng cho DB web
  lib/api.dart             routes + nhận bytes video qua query params
  lib/db.dart              map truy vấn sang schema web tiếng Việt
  lib/cloudinary.dart      ký upload/destroy
  Dockerfile               build API để deploy Render
render.yaml                cấu hình Render Blueprint (rootDir: server)
db/
  schema.sql       schema cũ của app (legacy, không dùng cho TIKTUBETPK)
  seed.sql         seed cũ của app (legacy, không dùng cho TIKTUBETPK)
test/
  api_client_test.dart  parse REST, lỗi, đăng nhập + Bearer token, feed bạn bè/lưu video
  widget_test.dart      điều hướng, lỗi API, thống kê, bình luận, xem nhanh, đăng nhanh, auth
```

## Kiểm tra

```bash
flutter analyze
flutter test
flutter build web --release --dart-define=API_BASE_URL=https://tiktube-api.onrender.com
cd server && dart analyze
```

Bộ test hiện bao phủ: parse API, xu hướng + feed đăng ký + feed Dành cho bạn +
feed Bạn bè + lưu video, thời lượng xem, thẻ tag theo danh mục, đăng nhập + Bearer
token, trang chủ, trạng thái lỗi API, thống kê, tìm kiếm, responsive, điều hướng,
xem video/bình luận, xem nhanh (thích/lưu), lựa chọn đăng video, đăng nhanh, thông
báo, upload tiến trình, khôi phục phiên sau khi mở lại app và luồng đăng nhập/đăng
ký/đăng xuất.

## Deploy API lên Render

Repo đã có sẵn `server/Dockerfile` và `render.yaml`.

1. Trên Render, chọn **New → Web Service** (hoặc **Blueprint** nếu dùng
   `render.yaml`).
2. Kết nối repository GitHub.
3. Cấu hình:
   - **Root Directory:** để trống
   - **Runtime:** `Docker`
   - **Dockerfile Path:** `server/Dockerfile`
   - **Docker Context:** `server`
   - **Health Check Path:** `/health`
4. Thêm các biến môi trường trong **Environment**:
   - `DATABASE_URL`
   - `CLOUDINARY_CLOUD_NAME`
   - `CLOUDINARY_API_KEY`
   - `CLOUDINARY_API_SECRET`
5. Sau khi deploy, Render cấp URL dạng
   `https://tiktube-api.onrender.com`. Kiểm tra:

   ```text
   https://tiktube-api.onrender.com/health
   ```

6. Build app trỏ vào URL đó:

   ```bash
   flutter build apk --release --dart-define=API_BASE_URL=https://tiktube-api.onrender.com
   ```

Không commit `server/.env`; các secret chỉ khai báo trong Render Dashboard.

## Lưu ý bảo mật

- `server/.env` chứa secret Neon và Cloudinary — không commit/chia sẻ.
- **Nên rotate mật khẩu Neon và `CLOUDINARY_API_SECRET` sau buổi demo**, vì secret
  đã được dùng trong quá trình kiểm thử.
- Upload đi qua server; Flutter không bao giờ thấy API secret.
- Web hiện lưu mật khẩu bằng **SHA-256 không salt** (64 ký tự hex). App buộc phải
  giữ đúng định dạng này để tài khoản tạo từ app vẫn đăng nhập được trên web.
  Đây không phải chuẩn lưu mật khẩu hiện đại; nếu có thể sửa cả web, nên chuyển
  sang Argon2id/bcrypt có salt và migrate dần.
- Token phiên được lưu dạng SHA-256 trong `app_sessions.token_hash`. Trên web,
  token được giữ trong `localStorage`; trên Android/iOS/desktop, token được lưu
  bằng `SharedPreferences` để app nhớ đăng nhập sau khi thoát. Production nên
  dùng cookie `HttpOnly` hoặc secure storage.
- Không dùng tài khoản demo cho dữ liệu thật.
