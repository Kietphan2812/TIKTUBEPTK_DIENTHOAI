-- ============================================================
-- TIKTUBE schema (Postgres / Neon)
-- Chạy: dán toàn bộ file này vào Neon SQL Editor
-- ============================================================

create extension if not exists pgcrypto;

create table if not exists categories (
  id serial primary key,
  name text not null unique
);

create table if not exists channels (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  handle text not null unique,
  subscriber_count integer not null default 0,
  colors text[] not null default array['#2E6F7E', '#12312E'],
  created_at timestamptz not null default now()
);

create table if not exists users (
  user_key text primary key,
  name text not null,
  email text not null,
  age integer,
  avatar_url text,
  created_at timestamptz not null default now()
);

-- Xác thực: mật khẩu bcrypt (pgcrypto) + phiên đăng nhập bằng token.
alter table users add column if not exists password_hash text;
create unique index if not exists users_email_lower_idx on users (lower(email));

create table if not exists sessions (
  token_hash text primary key,
  user_key text not null references users(user_key) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);

create index if not exists sessions_user_idx on sessions (user_key);
create index if not exists sessions_expires_idx on sessions (expires_at);

create table if not exists videos (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references channels(id) on delete cascade,
  category_id integer references categories(id) on delete set null,
  title text not null,
  description text not null default '',
  duration_seconds integer not null default 0,
  view_count bigint not null default 0,
  like_count integer not null default 0,
  is_live boolean not null default false,
  thumbnail_colors text[] not null default array['#1B3B4A', '#2F6E7C'],
  published_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

-- Bổ sung cho video tải lên Cloudinary (chạy lại nhiều lần vẫn an toàn).
alter table videos add column if not exists video_url text;
alter table videos add column if not exists thumbnail_url text;
alter table videos add column if not exists public_id text;
alter table videos add column if not exists uploaded_by text not null default 'kiepthan4';
alter table videos add column if not exists tags text[] not null default '{}';
alter table videos add column if not exists age_rating text not null default 'kids';

create index if not exists videos_published_idx on videos (published_at desc);
create index if not exists videos_category_idx on videos (category_id);
create index if not exists videos_uploaded_by_idx on videos (uploaded_by, published_at desc);

create table if not exists comments (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references videos(id) on delete cascade,
  author_name text not null,
  content text not null,
  created_at timestamptz not null default now()
);

-- Gắn bình luận với tài khoản thật để kiểm tra quyền xoá.
alter table comments add column if not exists user_key text;

create index if not exists comments_video_idx on comments (video_id, created_at desc);
create index if not exists comments_user_idx on comments (user_key);

-- Bình luận cũ của tài khoản demo (trước khi có cột user_key).
update comments
set user_key = 'kiepthan4'
where user_key is null and author_name = 'kiepthan4';

create table if not exists likes (
  video_id uuid not null references videos(id) on delete cascade,
  user_key text not null,
  created_at timestamptz not null default now(),
  primary key (video_id, user_key)
);

create table if not exists subscriptions (
  user_key text not null,
  channel_id uuid not null references channels(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_key, channel_id)
);

create table if not exists watch_history (
  id uuid primary key default gen_random_uuid(),
  user_key text not null default 'kiepthan4',
  video_id uuid not null references videos(id) on delete cascade,
  watched_at timestamptz not null default now()
);

create index if not exists watch_history_user_idx on watch_history (user_key, watched_at desc);
