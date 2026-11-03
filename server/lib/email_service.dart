import 'dart:async';
import 'dart:convert';
import 'dart:io';

class EmailService {
  EmailService({
    required this.smtpEmail,
    required this.smtpPassword,
    this.gmailWebhookUrl = '',
  });

  final String smtpEmail;
  final String smtpPassword;
  final String gmailWebhookUrl;

  /// Gửi mã xác thực OTP khôi phục mật khẩu qua Gmail Webhook (HTTPS 443) hoặc Gmail SMTP SSL (Cổng 465)
  Future<void> sendPasswordResetOtp({
    required String toEmail,
    required String otp,
    String? userName,
  }) async {
    final name = (userName != null && userName.isNotEmpty) ? userName : 'Bạn';
    final subject = '[TIKTUBE] Mã xác nhận đặt lại mật khẩu: $otp';

    final bodyText = '''
Xin chào $name,

Bạn vừa yêu cầu đặt lại mật khẩu cho tài khoản TIKTUBE liên kết với email này.
Mã xác nhận OTP của bạn là: $otp

Mã xác nhận có hiệu lực trong vòng 5 phút. Vui lòng không chia sẻ mã này cho bất kỳ ai để bảo vệ an toàn cho tài khoản của bạn.

Nếu bạn không thực hiện yêu cầu này, vui lòng bỏ qua email.

Trân trọng,
Đội ngũ hỗ trợ TIKTUBE PTK
''';

    final bodyHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f7f6fb; margin: 0; padding: 20px; color: #222; }
    .card { max-width: 520px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 16px rgba(0,0,0,0.06); border: 1px solid #eae7f3; }
    .header { background: linear-gradient(135deg, #e8112d 0%, #ff416c 100%); padding: 26px 20px; text-align: center; color: #ffffff; }
    .header h1 { margin: 0; font-size: 24px; font-weight: 800; letter-spacing: 0.5px; }
    .header p { margin: 6px 0 0; font-size: 13px; opacity: 0.9; }
    .content { padding: 30px 24px; text-align: center; }
    .greeting { font-size: 15px; font-weight: 600; margin-bottom: 12px; color: #171426; text-align: left; }
    .desc { font-size: 13.5px; color: #555263; line-height: 1.5; margin-bottom: 24px; text-align: left; }
    .otp-box { background: #fdf2f4; border: 2px dashed #f5a8b5; border-radius: 14px; padding: 18px 24px; display: inline-block; margin: 0 auto 24px; }
    .otp-code { font-size: 32px; font-weight: 800; color: #e8112d; letter-spacing: 8px; font-family: 'Courier New', Courier, monospace; }
    .expiry { font-size: 12.5px; color: #8c899c; margin-top: 6px; }
    .warning { font-size: 12px; color: #ff6b6b; background: #fff5f5; padding: 10px 14px; border-radius: 8px; margin-bottom: 24px; text-align: left; }
    .footer { background: #faf9fd; padding: 16px 24px; text-align: center; font-size: 11.5px; color: #9c99ab; border-top: 1px solid #f0edf8; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1>TIKTUBE</h1>
      <p>Nền tảng chia sẻ Video & Kết nối Bạn bè PTK</p>
    </div>
    <div class="content">
      <div class="greeting">Xin chào $name,</div>
      <div class="desc">
        Hệ thống nhận được yêu cầu đặt lại mật khẩu cho tài khoản TIKTUBE của bạn. Sử dụng mã xác thực OTP bên dưới để hoàn tất:
      </div>
      <div class="otp-box">
        <div class="otp-code">$otp</div>
        <div class="expiry">Hiệu lực trong 5 phút</div>
      </div>
      <div class="warning">
        🔒 <b>Lưu ý bảo mật:</b> Tuyệt đối không cung cấp mã OTP này cho bất kỳ ai khác, kể cả quản trị viên hệ thống.
      </div>
      <div class="desc" style="font-size: 12px; color: #888;">
        Nếu bạn không gửi yêu cầu này, có thể ai đó đã nhập nhầm email của bạn. Mật khẩu hiện tại của bạn vẫn an toàn.
      </div>
    </div>
    <div class="footer">
      Email tự động được gửi từ hệ thống TIKTUBE · Không phản hồi email này
    </div>
  </div>
</body>
</html>
''';

    final cleanWebhook = gmailWebhookUrl.trim();
    if (cleanWebhook.isNotEmpty) {
      try {
        await _sendViaWebhook(
          webhookUrl: cleanWebhook,
          toEmail: toEmail,
          subject: subject,
          bodyText: bodyText,
          bodyHtml: bodyHtml,
        );
        return;
      } catch (e) {
        stderr.writeln('Gửi OTP qua Webhook thất bại, chuyển sang gửi qua SMTP: $e');
      }
    }

    await _sendViaSmtp(
      toEmail: toEmail,
      subject: subject,
      bodyText: bodyText,
      bodyHtml: bodyHtml,
    );
  }

  Future<void> _sendViaWebhook({
    required String webhookUrl,
    required String toEmail,
    required String subject,
    required String bodyText,
    required String bodyHtml,
  }) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(webhookUrl);
      final request = await client.postUrl(uri).timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      final payload = jsonEncode({
        'to': toEmail,
        'subject': subject,
        'text': bodyText,
        'html': bodyHtml,
      });
      request.write(payload);
      final response = await request.close().timeout(const Duration(seconds: 25));

      // Google Apps Script redirect với mã 302/303 khi thành công
      if (response.statusCode >= 200 && response.statusCode < 400) {
        return;
      }
      final responseBody = await utf8.decoder.bind(response).join();
      throw Exception('Webhook trả về mã ${response.statusCode}: $responseBody');
    } finally {
      client.close();
    }
  }

  Future<void> _sendViaSmtp({
    required String toEmail,
    required String subject,
    required String bodyText,
    required String bodyHtml,
  }) async {
    final cleanPass = smtpPassword.replaceAll(' ', '');
    final cleanSender = smtpEmail.trim();

    final socket = await SecureSocket.connect(
      'smtp.gmail.com',
      465,
      timeout: const Duration(seconds: 15),
    );

    final lines = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    final iterator = StreamIterator<String>(lines);

    Future<String> readResponse() async {
      final buffer = StringBuffer();
      while (await iterator.moveNext().timeout(const Duration(seconds: 15))) {
        final line = iterator.current;
        buffer.writeln(line);
        // RFC 5321: Dòng cuối cùng của response luôn có dạng "XYZ ..." (dấu cách sau mã 3 chữ số)
        if (line.length >= 4 && line[3] == ' ') {
          final code = int.tryParse(line.substring(0, 3));
          if (code != null && code >= 400) {
            throw Exception('SMTP Server Error ($code): $line');
          }
          return buffer.toString().trim();
        }
      }
      throw TimeoutException('Mất kết nối với máy chủ SMTP Gmail.');
    }

    void sendLine(String line) {
      socket.write('$line\r\n');
    }

    try {
      // 1. Chờ lời chào từ server
      await readResponse();

      // 2. Gửi EHLO
      sendLine('EHLO localhost');
      await readResponse();

      // 3. Đăng nhập AUTH LOGIN
      sendLine('AUTH LOGIN');
      await readResponse();

      sendLine(base64Encode(utf8.encode(cleanSender)));
      await readResponse();

      sendLine(base64Encode(utf8.encode(cleanPass)));
      await readResponse();

      // 4. Định tuyến người gửi và người nhận
      sendLine('MAIL FROM:<$cleanSender>');
      await readResponse();

      sendLine('RCPT TO:<$toEmail>');
      await readResponse();

      // 5. Soạn nội dung DATA
      sendLine('DATA');
      await readResponse();

      final boundary = '----=_Part_${DateTime.now().millisecondsSinceEpoch}';
      final rawSubject = '=?UTF-8?B?${base64Encode(utf8.encode(subject))}?=';

      sendLine('From: TIKTUBE Support <$cleanSender>');
      sendLine('To: <$toEmail>');
      sendLine('Subject: $rawSubject');
      sendLine('MIME-Version: 1.0');
      sendLine('Content-Type: multipart/alternative; boundary="$boundary"');
      sendLine('');
      sendLine('--$boundary');
      sendLine('Content-Type: text/plain; charset=UTF-8');
      sendLine('Content-Transfer-Encoding: base64');
      sendLine('');
      sendLine(base64Encode(utf8.encode(bodyText)));
      sendLine('');
      sendLine('--$boundary');
      sendLine('Content-Type: text/html; charset=UTF-8');
      sendLine('Content-Transfer-Encoding: base64');
      sendLine('');
      sendLine(base64Encode(utf8.encode(bodyHtml)));
      sendLine('');
      sendLine('--$boundary--');
      sendLine('.');
      await readResponse();

      // 6. Kết thúc phiên
      sendLine('QUIT');
    } finally {
      await socket.close();
    }
  }
}
