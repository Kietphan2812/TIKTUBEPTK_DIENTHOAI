-- ============================================================
-- Dữ liệu mẫu TIKTUBE
-- Chạy sau schema.sql. Có thể chạy lại nhiều lần (idempotent).
-- ============================================================

insert into categories (name) values
  ('Giải trí'),
  ('Âm nhạc & sáng tạo'),
  ('Gaming'),
  ('Giáo dục & kiến thức'),
  ('Làm đẹp & thời trang'),
  ('Ẩm thực'),
  ('Du lịch & trải nghiệm'),
  ('Lifestyle (đời sống)'),
  ('Thể thao & sức khỏe'),
  ('Review & kiểm tiền'),
  ('DIY & sáng tạo')
on conflict (name) do nothing;

insert into channels (id, name, handle, subscriber_count, colors) values
  ('11111111-1111-4111-8111-111111111111', 'PTK', '@ptk', 7,
    array['#7A5CC4', '#4B3F8F']),
  ('11111111-1111-4111-8111-111111111112', 'Nhat', '@nhat', 12000,
    array['#3E5C3A', '#6E8C5A']),
  ('11111111-1111-4111-8111-111111111113', 'Foodie PTK', '@foodieptk', 32400,
    array['#FFB74D', '#E2703A']),
  ('11111111-1111-4111-8111-111111111114', 'kiepthan4', '@kiepthan4', 4,
    array['#2A2F45', '#42506E'])
on conflict (id) do nothing;

-- Tài khoản demo: đăng nhập bằng kiepthan4 / TikTube@123
-- (hoặc email kiepthan4444@gmail.com). Mật khẩu được băm bằng bcrypt.
insert into users (user_key, name, email, age, password_hash) values
  ('kiepthan4', 'kiepthan4', 'kiepthan4444@gmail.com', 18,
   crypt('TikTube@123', gen_salt('bf', 10)))
on conflict (user_key) do update
  set password_hash = excluded.password_hash;

insert into videos (id, channel_id, category_id, title, description, duration_seconds, view_count, like_count, is_live, thumbnail_colors, published_at)
select '22222222-2222-4222-8222-222222222201', c.id, cat.id,
       'Nhạc Mỹ Nhân', 'Nhạc remix của PTK.', 296, 28, 1, true,
       array['#1B3B4A', '#2F6E7C'], '2026-09-09 10:00:00+07'
from channels c, categories cat
where c.handle = '@ptk' and cat.name = 'Âm nhạc & sáng tạo'
on conflict (id) do nothing;

insert into videos (id, channel_id, category_id, title, description, duration_seconds, view_count, like_count, is_live, thumbnail_colors, published_at)
select '22222222-2222-4222-8222-222222222202', c.id, cat.id,
       'Ai Là Người Thương Em', 'Bản nhạc buồn nhẹ nhàng.', 342, 128400, 540, false,
       array['#6E5B52', '#B9A79B'], '2026-09-08 20:00:00+07'
from channels c, categories cat
where c.handle = '@ptk' and cat.name = 'Âm nhạc & sáng tạo'
on conflict (id) do nothing;

insert into videos (id, channel_id, category_id, title, description, duration_seconds, view_count, like_count, is_live, thumbnail_colors, published_at)
select '22222222-2222-4222-8222-222222222203', c.id, cat.id,
       'Em Sẽ Là Cô Dâu', 'MV mới nhất của PTK.', 293, 2751000, 3200, false,
       array['#7A5CC4', '#4B3F8F'], '2026-09-07 19:00:00+07'
from channels c, categories cat
where c.handle = '@ptk' and cat.name = 'Âm nhạc & sáng tạo'
on conflict (id) do nothing;

insert into videos (id, channel_id, category_id, title, description, duration_seconds, view_count, like_count, is_live, thumbnail_colors, published_at)
select '22222222-2222-4222-8222-222222222204', c.id, cat.id,
       'Nhạc Cũ Ngỡ Là Anh', 'Nhạc cũ remix.', 302, 9800, 120, false,
       array['#2A2F45', '#42506E'], '2026-09-09 08:00:00+07'
from channels c, categories cat
where c.handle = '@kiepthan4' and cat.name = 'Lifestyle (đời sống)'
on conflict (id) do nothing;

insert into videos (id, channel_id, category_id, title, description, duration_seconds, view_count, like_count, is_live, thumbnail_colors, published_at)
select '22222222-2222-4222-8222-222222222205', c.id, cat.id,
       'Nhạc Ai Là Người Thương Em', 'Remix version.', 342, 17400, 310, false,
       array['#1B3B4A', '#2F6E7C'], '2026-09-09 11:00:00+07'
from channels c, categories cat
where c.handle = '@ptk' and cat.name = 'Âm nhạc & sáng tạo'
on conflict (id) do nothing;

insert into videos (id, channel_id, category_id, title, description, duration_seconds, view_count, like_count, is_live, thumbnail_colors, published_at)
select '22222222-2222-4222-8222-222222222206', c.id, cat.id,
       'Em sẽ là cô dâu', 'Live acoustic.', 293, 52300, 880, false,
       array['#7A5CC4', '#4B3F8F'], '2026-09-09 12:00:00+07'
from channels c, categories cat
where c.handle = '@ptk' and cat.name = 'Âm nhạc & sáng tạo'
on conflict (id) do nothing;

insert into videos (id, channel_id, category_id, title, description, duration_seconds, view_count, like_count, is_live, thumbnail_colors, published_at)
select '22222222-2222-4222-8222-222222222207', c.id, cat.id,
       'Nhạc Mỹ Nhân', 'Bản gốc.', 296, 28, 1, false,
       array['#12312E', '#1F5F57'], '2026-09-09 09:00:00+07'
from channels c, categories cat
where c.handle = '@ptk' and cat.name = 'Âm nhạc & sáng tạo'
on conflict (id) do nothing;

insert into videos (id, channel_id, category_id, title, description, duration_seconds, view_count, like_count, is_live, thumbnail_colors, published_at)
select '22222222-2222-4222-8222-222222222208', c.id, cat.id,
       'Alista bỏ sữa và những người bạn', 'Vlog ngắn.', 72, 12400, 210, false,
       array['#3E5C3A', '#6E8C5A'], '2026-09-09 07:00:00+07'
from channels c, categories cat
where c.handle = '@nhat' and cat.name = 'Giải trí'
on conflict (id) do nothing;

insert into videos (id, channel_id, category_id, title, description, duration_seconds, view_count, like_count, is_live, thumbnail_colors, published_at)
select '22222222-2222-4222-8222-222222222209', c.id, cat.id,
       'Review 5 quán ăn đêm Sài Gòn dưới 50k', 'Ăn đêm Sài Gòn.', 728, 341000, 2100, false,
       array['#FFB74D', '#E2703A'], '2026-09-08 21:00:00+07'
from channels c, categories cat
where c.handle = '@foodieptk' and cat.name = 'Ẩm thực'
on conflict (id) do nothing;

insert into videos (id, channel_id, category_id, title, description, duration_seconds, view_count, like_count, is_live, thumbnail_colors, published_at)
select '22222222-2222-4222-8222-222222222210', c.id, cat.id,
       'Leo núi Tà Xùa săn mây 2 ngày 1 đêm', 'Chuyến đi Tà Xùa.', 1111, 89000, 1300, false,
       array['#4E6E8E', '#9EC5D9'], '2026-09-06 06:00:00+07'
from channels c, categories cat
where c.handle = '@nhat' and cat.name = 'Du lịch & trải nghiệm'
on conflict (id) do nothing;

insert into videos (id, channel_id, category_id, title, description, duration_seconds, view_count, like_count, is_live, thumbnail_colors, published_at)
select '22222222-2222-4222-8222-222222222211', c.id, cat.id,
       'Hướng dẫn Flutter: dựng UI trong 15 phút', 'Flutter cơ bản.', 904, 56200, 990, false,
       array['#2A4B7C', '#4C8DFF'], '2026-09-05 15:00:00+07'
from channels c, categories cat
where c.handle = '@nhat' and cat.name = 'Giáo dục & kiến thức'
on conflict (id) do nothing;

insert into videos (id, channel_id, category_id, title, description, duration_seconds, view_count, like_count, is_live, thumbnail_colors, published_at)
select '22222222-2222-4222-8222-222222222212', c.id, cat.id,
       'Đấu rank leo top 1 server — highlight cực cháy', 'Highlight gaming.', 1337, 1203000, 5400, false,
       array['#3B1F5E', '#8B2FC9'], '2026-09-04 22:00:00+07'
from channels c, categories cat
where c.handle = '@nhat' and cat.name = 'Gaming'
on conflict (id) do nothing;

insert into videos (id, channel_id, category_id, title, description, duration_seconds, view_count, like_count, is_live, thumbnail_colors, published_at)
select '22222222-2222-4222-8222-222222222213', c.id, cat.id,
       'Skincare buổi tối cho da dầu mụn', 'Routine skincare.', 502, 45000, 780, false,
       array['#E7A8B8', '#B5627C'], '2026-09-03 20:30:00+07'
from channels c, categories cat
where c.handle = '@foodieptk' and cat.name = 'Làm đẹp & thời trang'
on conflict (id) do nothing;

insert into videos (id, channel_id, category_id, title, description, duration_seconds, view_count, like_count, is_live, thumbnail_colors, published_at)
select '22222222-2222-4222-8222-222222222214', c.id, cat.id,
       'Bài tập 10 phút mỗi sáng cho người ngồi nhiều', 'Workout tại nhà.', 636, 210500, 2400, false,
       array['#1F6F63', '#57C6A5'], '2026-09-02 06:00:00+07'
from channels c, categories cat
where c.handle = '@nhat' and cat.name = 'Thể thao & sức khỏe'
on conflict (id) do nothing;

insert into videos (id, channel_id, category_id, title, description, duration_seconds, view_count, like_count, is_live, thumbnail_colors, published_at)
select '22222222-2222-4222-8222-222222222215', c.id, cat.id,
       'Tự làm kệ gỗ treo tường chỉ với 150k', 'DIY nhà xinh.', 469, 77200, 1150, false,
       array['#8A5A2B', '#D9A45B'], '2026-09-01 18:00:00+07'
from channels c, categories cat
where c.handle = '@foodieptk' and cat.name = 'DIY & sáng tạo'
on conflict (id) do nothing;

insert into comments (video_id, author_name, content, created_at, user_key)
select '22222222-2222-4222-8222-222222222201', 'kiepthan4', '222', '2026-09-11 09:00:00+07', 'kiepthan4'
where not exists (
  select 1 from comments
  where video_id = '22222222-2222-4222-8222-222222222201'
    and author_name = 'kiepthan4' and content = '222'
);

insert into comments (video_id, author_name, content, created_at, user_key)
select '22222222-2222-4222-8222-222222222201', 'kiepthan4', 'XCLOL', '2026-09-11 09:01:00+07', 'kiepthan4'
where not exists (
  select 1 from comments
  where video_id = '22222222-2222-4222-8222-222222222201'
    and author_name = 'kiepthan4' and content = 'XCLOL'
);

insert into comments (video_id, author_name, content, created_at, user_key)
select '22222222-2222-4222-8222-222222222201', 'kiepthan4', 'hehe', '2026-09-09 19:00:00+07', 'kiepthan4'
where not exists (
  select 1 from comments
  where video_id = '22222222-2222-4222-8222-222222222201'
    and author_name = 'kiepthan4' and content = 'hehe'
);

insert into comments (video_id, author_name, content, created_at)
select '22222222-2222-4222-8222-222222222201', 'Bắp Bơ', 'Bắp ngô', '2026-09-09 18:00:00+07'
where not exists (
  select 1 from comments
  where video_id = '22222222-2222-4222-8222-222222222201'
    and author_name = 'Bắp Bơ'
);

insert into comments (video_id, author_name, content, created_at)
select '22222222-2222-4222-8222-222222222201', 'Mèo Con', 'Nghe hoài không chán luôn', '2026-09-08 21:00:00+07'
where not exists (
  select 1 from comments
  where video_id = '22222222-2222-4222-8222-222222222201'
    and author_name = 'Mèo Con'
);

insert into subscriptions (user_key, channel_id) values
  ('kiepthan4', '11111111-1111-4111-8111-111111111111'),
  ('kiepthan4', '11111111-1111-4111-8111-111111111112'),
  ('kiepthan4', '11111111-1111-4111-8111-111111111113')
on conflict (user_key, channel_id) do nothing;

-- 5 video đã có sẵn trên Cloudinary của tài khoản: gắn vào dữ liệu mẫu
-- để trình phát và thumbnail thật hoạt động ngay.
update videos set
  video_url = 'https://res.cloudinary.com/fvqm3bbv/video/upload/v1789087426/tiktube_videos/dqmbzulah1sj4q6rwrgc.mp4',
  thumbnail_url = 'https://res.cloudinary.com/fvqm3bbv/video/upload/so_0,w_640,h_360,c_fill/tiktube_videos/dqmbzulah1sj4q6rwrgc.jpg',
  public_id = 'tiktube_videos/dqmbzulah1sj4q6rwrgc'
where id = '22222222-2222-4222-8222-222222222201';

update videos set
  video_url = 'https://res.cloudinary.com/fvqm3bbv/video/upload/v1788965682/tiktube_videos/ul7rbg1mq6etye7l2hpu.mp4',
  thumbnail_url = 'https://res.cloudinary.com/fvqm3bbv/video/upload/so_0,w_640,h_360,c_fill/tiktube_videos/ul7rbg1mq6etye7l2hpu.jpg',
  public_id = 'tiktube_videos/ul7rbg1mq6etye7l2hpu'
where id = '22222222-2222-4222-8222-222222222202';

update videos set
  video_url = 'https://res.cloudinary.com/fvqm3bbv/video/upload/v1788945082/tiktube_videos/tjqnsd85bf6fyyj0to9g.mp4',
  thumbnail_url = 'https://res.cloudinary.com/fvqm3bbv/video/upload/so_0,w_640,h_360,c_fill/tiktube_videos/tjqnsd85bf6fyyj0to9g.jpg',
  public_id = 'tiktube_videos/tjqnsd85bf6fyyj0to9g'
where id = '22222222-2222-4222-8222-222222222203';

update videos set
  video_url = 'https://res.cloudinary.com/fvqm3bbv/video/upload/v1788941808/tiktube_videos/cw755olqhepgi3ilqvbh.mp4',
  thumbnail_url = 'https://res.cloudinary.com/fvqm3bbv/video/upload/so_0,w_640,h_360,c_fill/tiktube_videos/cw755olqhepgi3ilqvbh.jpg',
  public_id = 'tiktube_videos/cw755olqhepgi3ilqvbh'
where id = '22222222-2222-4222-8222-222222222204';

update videos set
  video_url = 'https://res.cloudinary.com/fvqm3bbv/video/upload/v1788932598/tiktube_videos/kaku3brbua4dxoxdebad.mp4',
  thumbnail_url = 'https://res.cloudinary.com/fvqm3bbv/video/upload/so_0,w_640,h_360,c_fill/tiktube_videos/kaku3brbua4dxoxdebad.jpg',
  public_id = 'tiktube_videos/kaku3brbua4dxoxdebad'
where id = '22222222-2222-4222-8222-222222222205';

-- Lịch sử xem 7 ngày gần nhất cho biểu đồ thống kê (idempotent theo ngày).
insert into watch_history (user_key, video_id, watched_at)
select 'kiepthan4', v.id, now() - (gs || ' days')::interval
from (
  values
    ('22222222-2222-4222-8222-222222222201'::uuid),
    ('22222222-2222-4222-8222-222222222202'::uuid),
    ('22222222-2222-4222-8222-222222222203'::uuid)
) as t(video_id)
join videos v on v.id = t.video_id
cross join generate_series(0, 6) as gs
where not exists (
  select 1 from watch_history wh
  where wh.user_key = 'kiepthan4'
    and wh.video_id = v.id
    and wh.watched_at::date = (now() - (gs || ' days')::interval)::date
);

-- Thêm lượt xem cho một số ngày để biểu đồ 7 ngày có dao động thực tế.
insert into watch_history (user_key, video_id, watched_at)
select 'kiepthan4', v.id, now() - (gs || ' days')::interval
from (
  values
    ('22222222-2222-4222-8222-222222222204'::uuid, 0),
    ('22222222-2222-4222-8222-222222222205'::uuid, 0),
    ('22222222-2222-4222-8222-222222222204'::uuid, 1),
    ('22222222-2222-4222-8222-222222222205'::uuid, 1),
    ('22222222-2222-4222-8222-222222222204'::uuid, 3),
    ('22222222-2222-4222-8222-222222222205'::uuid, 3),
    ('22222222-2222-4222-8222-222222222204'::uuid, 5),
    ('22222222-2222-4222-8222-222222222205'::uuid, 5),
    ('22222222-2222-4222-8222-222222222204'::uuid, 6)
) as t(video_id, gs)
join videos v on v.id = t.video_id
where not exists (
  select 1 from watch_history wh
  where wh.user_key = 'kiepthan4'
    and wh.video_id = v.id
    and wh.watched_at::date = (now() - (gs || ' days')::interval)::date
);

-- Gắn tag thật cho các video mẫu (không ghi đè tag người dùng đã sửa).
update videos v
set tags = t.tags
from (
  values
    ('22222222-2222-4222-8222-222222222201'::uuid, array['nhac', 'remix', 'my-nhan']::text[]),
    ('22222222-2222-4222-8222-222222222202'::uuid, array['nhac', 'buon', 'remix']::text[]),
    ('22222222-2222-4222-8222-222222222203'::uuid, array['nhac', 'mv', 'co-dau']::text[]),
    ('22222222-2222-4222-8222-222222222204'::uuid, array['nhac', 'remix', 'nhac-cu']::text[]),
    ('22222222-2222-4222-8222-222222222205'::uuid, array['nhac', 'remix', 'hay']::text[]),
    ('22222222-2222-4222-8222-222222222206'::uuid, array['nhac', 'live', 'acoustic']::text[]),
    ('22222222-2222-4222-8222-222222222207'::uuid, array['nhac', 'my-nhan', 'ban-goc']::text[]),
    ('22222222-2222-4222-8222-222222222208'::uuid, array['vlog', 'alista', 'thu-cung']::text[]),
    ('22222222-2222-4222-8222-222222222209'::uuid, array['review', 'am-thuc', 'sai-gon']::text[]),
    ('22222222-2222-4222-8222-222222222210'::uuid, array['du-lich', 'ta-xua', 'san-may']::text[]),
    ('22222222-2222-4222-8222-222222222211'::uuid, array['flutter', 'lap-trinh', 'huong-dan']::text[]),
    ('22222222-2222-4222-8222-222222222212'::uuid, array['gaming', 'highlight', 'rank']::text[]),
    ('22222222-2222-4222-8222-222222222213'::uuid, array['skincare', 'lam-dep', 'routine']::text[]),
    ('22222222-2222-4222-8222-222222222214'::uuid, array['workout', 'the-thao', 'suc-khoe']::text[]),
    ('22222222-2222-4222-8222-222222222215'::uuid, array['diy', 'nha-xinh', 'ke-go']::text[])
) as t(id, tags)
where v.id = t.id
  and (v.tags is null or cardinality(v.tags) = 0);
