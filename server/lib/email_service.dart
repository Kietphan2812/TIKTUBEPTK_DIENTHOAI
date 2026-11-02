import 'dart:async';
import 'dart:convert';
import 'dart:io';

class EmailService {
  EmailService({
    required this.smtpEmail,
    required this.smtpPassword,
  });

  final String smtpEmail;
  final String smtpPassword;

  /// Gửi mã xác thực OTP khôi phục mật khẩu qua Gmail SMTP SSL (Cổng 465)
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

    await _sendViaSmtp(
      toEmail: toEmail,
      subject: subject,
      bodyText: bodyText,
      bodyHtml: bodyHtml,
    );
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

    final buffer = StringBuffer();
    final stream = socket.cast<List<int>>().transform(utf8.decoder);

    Completer<String>? nextExpected;
    final sub = stream.listen((data) {
      buffer.write(data);
      if (nextExpected != null && !nextExpected!.isCompleted) {
        nextExpected!.complete(data);
      }
    });

    Future<void> expect(String code) async {
      final deadline = DateTime.now().add(const Duration(seconds: 12));
      while (true) {
        if (buffer.toString().contains(code)) return;
        if (DateTime.now().isAfter(deadline)) {
          throw TimeoutException('Quá thời gian phản hồi từ máy chủ SMTP ($code)');
        }
        nextExpected = Completer<String>();
        await nextExpected!.future.timeout(const Duration(seconds: 12));
      }
    }

    void sendLine(String line) {
      socket.write('$line\r\n');
    }

    try {
      await expect('220');
      buffer.clear();

      sendLine('EHLO localhost');
      await expect('250 ');
      buffer.clear();

      sendLine('AUTH LOGIN');
      await expect('334 ');
      buffer.clear();

      sendLine(base64Encode(utf8.encode(cleanSender)));
      await expect('334 ');
      buffer.clear();

      sendLine(base64Encode(utf8.encode(cleanPass)));
      await expect('235');
      buffer.clear();

      sendLine('MAIL FROM:<$cleanSender>');
      await expect('250');
      buffer.clear();

      sendLine('RCPT TO:<$toEmail>');
      await expect('250');
      buffer.clear();

      sendLine('DATA');
      await expect('354');
      buffer.clear();

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
      await expect('250');
      buffer.clear();

      sendLine('QUIT');
    } finally {
      await sub.cancel();
      await socket.close();
    }
  }
}
