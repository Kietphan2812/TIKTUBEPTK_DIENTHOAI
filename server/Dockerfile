# Dockerfile chạy TIKTUBE API trên Render.
#
# Render cấu hình:
#   Runtime:         Docker
#   Root Directory:  (để trống)
#   Dockerfile Path: server/Dockerfile
#   Docker Context:  server
#   Health Check:    /health
#
# Các biến DATABASE_URL và CLOUDINARY_* được khai báo trong Render Dashboard,
# không đưa file .env lên repository.

FROM dart:stable AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN dart pub get

COPY . .
RUN dart compile exe bin/server.dart -o /app/bin/server

FROM dart:stable

WORKDIR /app

COPY --from=build /app/bin/server /app/bin/server

ENV PORT=8787
EXPOSE 8787

CMD ["/app/bin/server"]
