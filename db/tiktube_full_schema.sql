-- ============================================================
-- HỆ THỐNG CƠ SỞ DỮ LIỆU TIKTUBE (NEON SERVERLESS POSTGRESQL)
-- File: db/tiktube_full_schema.sql
-- Hướng dẫn: Dán toàn bộ mã này vào Neon SQL Editor hoặc pgAdmin và nhấn Run.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. BẢNG NGƯỜI DÙNG (nguoi_dung)
CREATE TABLE IF NOT EXISTS nguoi_dung (
  nguoi_dung_id SERIAL PRIMARY KEY,
  ten_dang_nhap VARCHAR(50) NOT NULL UNIQUE,
  ten_hien_thi VARCHAR(60),
  email VARCHAR(100) NOT NULL UNIQUE,
  so_dien_thoai VARCHAR(20),
  mat_khau_hash VARCHAR(255) NOT NULL,
  anh_dai_dien TEXT,
  do_tuoi INT DEFAULT 18,
  vai_tro VARCHAR(20) DEFAULT 'user',
  ngay_tao TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ngay_cap_nhat TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. BẢNG DANH MỤC (danh_muc)
CREATE TABLE IF NOT EXISTS danh_muc (
  danh_muc_id SERIAL PRIMARY KEY,
  ten_danh_muc VARCHAR(100) NOT NULL UNIQUE,
  mo_ta TEXT,
  ngay_tao TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. BẢNG THẺ TAG (the_tag)
CREATE TABLE IF NOT EXISTS the_tag (
  tag_id SERIAL PRIMARY KEY,
  danh_muc_id INT REFERENCES danh_muc(danh_muc_id) ON DELETE CASCADE,
  ten_tag VARCHAR(50) NOT NULL,
  ngay_tao TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. BẢNG VIDEO (video)
CREATE TABLE IF NOT EXISTS video (
  video_id SERIAL PRIMARY KEY,
  nguoi_dung_id INT NOT NULL REFERENCES nguoi_dung(nguoi_dung_id) ON DELETE CASCADE,
  danh_muc_id INT REFERENCES danh_muc(danh_muc_id) ON DELETE SET NULL,
  tag_id INT REFERENCES the_tag(tag_id) ON DELETE SET NULL,
  tieu_de VARCHAR(255) NOT NULL,
  mo_ta TEXT,
  duong_dan_video TEXT NOT NULL,
  duong_dan_anh_bia TEXT,
  thoi_luong DOUBLE PRECISION NOT NULL DEFAULT 0,
  luot_xem BIGINT NOT NULL DEFAULT 0,
  danh_cho_tre_em BOOLEAN NOT NULL DEFAULT FALSE,
  trang_thai VARCHAR(20) NOT NULL DEFAULT 'da_duyet',
  ngay_tao TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ngay_cap_nhat TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. BẢNG BÌNH LUẬN (binh_luan)
CREATE TABLE IF NOT EXISTS binh_luan (
  binh_luan_id SERIAL PRIMARY KEY,
  video_id INT NOT NULL REFERENCES video(video_id) ON DELETE CASCADE,
  nguoi_dung_id INT NOT NULL REFERENCES nguoi_dung(nguoi_dung_id) ON DELETE CASCADE,
  noi_dung TEXT NOT NULL,
  ngay_tao TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ngay_cap_nhat TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. BẢNG LƯỢT THÍCH (luot_thich)
CREATE TABLE IF NOT EXISTS luot_thich (
  luot_thich_id SERIAL PRIMARY KEY,
  video_id INT NOT NULL REFERENCES video(video_id) ON DELETE CASCADE,
  nguoi_dung_id INT NOT NULL REFERENCES nguoi_dung(nguoi_dung_id) ON DELETE CASCADE,
  ngay_tao TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_video_nguoi_dung UNIQUE (video_id, nguoi_dung_id)
);

-- 7. BẢNG ĐĂNG KÝ KÊNH (dang_ky_kenh)
CREATE TABLE IF NOT EXISTS dang_ky_kenh (
  dang_ky_id SERIAL PRIMARY KEY,
  nguoi_dung_id INT NOT NULL REFERENCES nguoi_dung(nguoi_dung_id) ON DELETE CASCADE,
  kenh_id INT NOT NULL REFERENCES nguoi_dung(nguoi_dung_id) ON DELETE CASCADE,
  ngay_dang_ky TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_dang_ky UNIQUE (nguoi_dung_id, kenh_id)
);

-- 8. BẢNG LỊCH SỬ XEM (lich_su_xem)
CREATE TABLE IF NOT EXISTS lich_su_xem (
  lich_su_id SERIAL PRIMARY KEY,
  nguoi_dung_id INT NOT NULL REFERENCES nguoi_dung(nguoi_dung_id) ON DELETE CASCADE,
  video_id INT NOT NULL REFERENCES video(video_id) ON DELETE CASCADE,
  thoi_luong_xem DOUBLE PRECISION NOT NULL DEFAULT 0,
  thoi_luong_video DOUBLE PRECISION NOT NULL DEFAULT 0,
  thoi_gian_xem TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. BẢNG VIDEO ĐÃ LƯU (app_saved_videos)
CREATE TABLE IF NOT EXISTS app_saved_videos (
  nguoi_dung_id INT NOT NULL REFERENCES nguoi_dung(nguoi_dung_id) ON DELETE CASCADE,
  video_id INT NOT NULL REFERENCES video(video_id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (nguoi_dung_id, video_id)
);

-- 10. BẢNG PHIÊN ĐĂNG NHẬP (app_sessions)
CREATE TABLE IF NOT EXISTS app_sessions (
  token_hash TEXT PRIMARY KEY,
  nguoi_dung_id INT NOT NULL REFERENCES nguoi_dung(nguoi_dung_id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 11. BẢNG THÔNG BÁO (thong_bao)
CREATE TABLE IF NOT EXISTS thong_bao (
  thong_bao_id SERIAL PRIMARY KEY,
  nguoi_dung_id INT NOT NULL REFERENCES nguoi_dung(nguoi_dung_id) ON DELETE CASCADE,
  noi_dung TEXT NOT NULL,
  link TEXT,
  da_xem BOOLEAN NOT NULL DEFAULT FALSE,
  ngay_tao TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 12. BẢNG THỐNG KÊ CREATOR (thong_ke)
CREATE TABLE IF NOT EXISTS thong_ke (
  thong_ke_id SERIAL PRIMARY KEY,
  nguoi_dung_id INT NOT NULL REFERENCES nguoi_dung(nguoi_dung_id) ON DELETE CASCADE,
  ngay DATE NOT NULL,
  so_luot_xem INT NOT NULL DEFAULT 0,
  so_luot_thich INT NOT NULL DEFAULT 0,
  so_binh_luan INT NOT NULL DEFAULT 0,
  ngay_cap_nhat TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_thong_ke_ngay UNIQUE (nguoi_dung_id, ngay)
);

-- 13. BẢNG NGƯỜI XEM VÃNG LAI (nguoi_xem)
CREATE TABLE IF NOT EXISTS nguoi_xem (
  nguoi_xem_id SERIAL PRIMARY KEY,
  nguoi_dung_id INT REFERENCES nguoi_dung(nguoi_dung_id) ON DELETE SET NULL,
  ten_nguoi_xem VARCHAR(100),
  dia_chi_ip VARCHAR(50),
  thiet_bi VARCHAR(200),
  ngay_truy_cap TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 14. BẢNG TÀI KHOẢN QUẢN TRỊ (tai_khoan_admin)
CREATE TABLE IF NOT EXISTS tai_khoan_admin (
  id SERIAL PRIMARY KEY,
  username VARCHAR(100) NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL
);

-- 15. BẢNG KIỂM DUYỆT VIDEO (kiem_duyet_video)
CREATE TABLE IF NOT EXISTS kiem_duyet_video (
  id SERIAL PRIMARY KEY,
  video_id INT NOT NULL REFERENCES video(video_id) ON DELETE CASCADE,
  admin_username VARCHAR(100) REFERENCES tai_khoan_admin(username) ON DELETE SET NULL,
  trang_thai_moi VARCHAR(50) NOT NULL,
  ly_do TEXT,
  ngay_duyet TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 16. BẢNG NHẬT KÝ ĐĂNG VIDEO (lich_su_dang_video)
CREATE TABLE IF NOT EXISTS lich_su_dang_video (
  id SERIAL PRIMARY KEY,
  video_id INT NOT NULL REFERENCES video(video_id) ON DELETE CASCADE,
  nguoi_dung_id INT NOT NULL REFERENCES nguoi_dung(nguoi_dung_id) ON DELETE CASCADE,
  tieu_de VARCHAR(255) NOT NULL,
  mo_ta TEXT,
  video_url TEXT,
  luot_xem INT NOT NULL DEFAULT 0,
  thoi_gian_dang TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 17. PHÂN HỆ MẠNG XÃ HỘI & CHAT REALTIME (sql_nhantin)
CREATE TABLE IF NOT EXISTS chat_users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  phone VARCHAR(20) NOT NULL,
  avatar TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS messages (
  id SERIAL PRIMARY KEY,
  sender_id INT NOT NULL,
  receiver_id INT NOT NULL,
  content TEXT,
  image_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS friend_requests (
  id SERIAL PRIMARY KEY,
  sender_id INT NOT NULL,
  receiver_id INT NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS friends (
  user_id INT NOT NULL,
  friend_id INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, friend_id)
);

-- ============================================================
-- CHỈ MỤC TỐI ƯU HIỆU NĂNG TRUY VẤN (INDEXES)
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_nguoi_dung_phone ON nguoi_dung (so_dien_thoai);
CREATE INDEX IF NOT EXISTS idx_video_nguoi_dung ON video (nguoi_dung_id);
CREATE INDEX IF NOT EXISTS idx_video_danh_muc ON video (danh_muc_id);
CREATE INDEX IF NOT EXISTS idx_video_ngay_tao ON video (ngay_tao DESC);
CREATE INDEX IF NOT EXISTS idx_binh_luan_video ON binh_luan (video_id, ngay_tao DESC);
CREATE INDEX IF NOT EXISTS idx_lich_su_xem_user ON lich_su_xem (nguoi_dung_id, thoi_gian_xem DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON app_sessions (expires_at);
CREATE INDEX IF NOT EXISTS idx_thong_bao_user ON thong_bao (nguoi_dung_id, ngay_tao DESC);
CREATE INDEX IF NOT EXISTS idx_messages_pair ON messages (sender_id, receiver_id, created_at DESC);

-- ============================================================
-- ĐỊNH NGHĨA CÁC KHUNG NHÌN ẢO (VIEWS)
-- ============================================================

-- VIEW 1: Video Xu hướng
CREATE OR REPLACE VIEW video_xu_huong AS
SELECT 
  v.video_id,
  v.tieu_de,
  COALESCE(u.ten_hien_thi, u.ten_dang_nhap) AS ten_tac_gia,
  v.luot_xem,
  COUNT(DISTINCT lt.luot_thich_id)::INT AS so_luot_thich,
  COUNT(DISTINCT bl.binh_luan_id)::INT AS so_binh_luan,
  (COUNT(DISTINCT lt.luot_thich_id) + COUNT(DISTINCT bl.binh_luan_id))::INT AS tong_tuong_tac,
  ROUND(
    (
      (v.luot_xem * 1.0 + COUNT(DISTINCT lt.luot_thich_id) * 3.0 + COUNT(DISTINCT bl.binh_luan_id) * 2.0)
      / GREATEST(EXTRACT(EPOCH FROM (NOW() - v.ngay_tao)) / 86400.0, 0.5)
    )::NUMERIC, 2
  )::DOUBLE PRECISION AS diem_xu_huong,
  v.ngay_tao
FROM video v
JOIN nguoi_dung u ON u.nguoi_dung_id = v.nguoi_dung_id
LEFT JOIN luot_thich lt ON lt.video_id = v.video_id
LEFT JOIN binh_luan bl ON bl.video_id = v.video_id
WHERE v.trang_thai IN ('da_duyet', 'approved')
GROUP BY v.video_id, v.tieu_de, u.ten_hien_thi, u.ten_dang_nhap, v.luot_xem, v.ngay_tao;

-- VIEW 2: Tìm kiếm Video
CREATE OR REPLACE VIEW vw_tim_kiem_video AS
SELECT 
  v.video_id,
  v.tieu_de,
  LOWER(v.tieu_de) AS tieu_de_khong_dau,
  SUBSTRING(COALESCE(v.mo_ta, '') FROM 1 FOR 500) AS mo_ta_tom_tat,
  COALESCE(u.ten_hien_thi, u.ten_dang_nhap) AS ten_tac_gia,
  u.anh_dai_dien,
  COALESCE(dm.ten_danh_muc, 'Chung') AS ten_danh_muc,
  v.luot_xem,
  v.ngay_tao
FROM video v
JOIN nguoi_dung u ON u.nguoi_dung_id = v.nguoi_dung_id
LEFT JOIN danh_muc dm ON dm.danh_muc_id = v.danh_muc_id
WHERE v.trang_thai IN ('da_duyet', 'approved');

-- VIEW 3: Video phù hợp độ tuổi
CREATE OR REPLACE VIEW vw_video_phu_hop_do_tuoi AS
SELECT 
  v.video_id AS ma_video,
  v.tieu_de,
  v.mo_ta,
  v.duong_dan_video,
  v.duong_dan_anh_bia AS anh_thumbnail,
  v.luot_xem,
  (SELECT COUNT(*)::INT FROM luot_thich lt WHERE lt.video_id = v.video_id) AS luot_thich,
  CASE WHEN v.danh_cho_tre_em = TRUE THEN 'Dưới 18' ELSE 'Trên 18' END AS do_tuoi_phu_hop,
  v.ngay_tao,
  u.nguoi_dung_id AS ma_nguoi_dung,
  u.ten_dang_nhap,
  u.do_tuoi AS tuoi_nguoi_dung,
  CASE 
    WHEN v.danh_cho_tre_em = TRUE THEN 'Phù hợp'
    WHEN u.do_tuoi >= 18 THEN 'Phù hợp'
    ELSE 'Không phù hợp'
  END AS phu_hop
FROM video v
CROSS JOIN nguoi_dung u
WHERE v.trang_thai IN ('da_duyet', 'approved');

-- ============================================================
-- DỮ LIỆU KHỞI TẠO BAN ĐẦU (SEED DATA)
-- ============================================================
INSERT INTO tai_khoan_admin (username, password)
VALUES ('admin', 'admin123')
ON CONFLICT (username) DO NOTHING;

INSERT INTO danh_muc (ten_danh_muc, mo_ta) VALUES
  ('Âm nhạc', 'Các video bài hát, MV và trình diễn âm nhạc'),
  ('Trò chơi', 'Livestream, đánh giá và gameplay các tựa game hot'),
  ('Giáo dục', 'Bài giảng, hướng dẫn lập trình và kiến thức công nghệ'),
  ('Giải trí', 'Hài kịch, tiểu phẩm và video thư giãn ngắn'),
  ('Đời sống & Vlog', 'Nhật ký đời sống, du lịch và ẩm thực')
ON CONFLICT (ten_danh_muc) DO NOTHING;

