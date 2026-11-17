import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi_web;

/// Trình hiển thị nút đăng nhập Google Identity Services (GIS) chính thức trên Web.
/// Nút này kích hoạt cửa sổ Chọn tài khoản chính thức (accounts.google.com).
Widget buildGsiButton({required bool isRegister}) {
  return gsi_web.renderButton(
    configuration: gsi_web.GSIButtonConfiguration(
      type: gsi_web.GSIButtonType.standard,
      theme: gsi_web.GSIButtonTheme.outline,
      size: gsi_web.GSIButtonSize.large,
      shape: gsi_web.GSIButtonShape.rectangular,
      text: isRegister
          ? gsi_web.GSIButtonText.signupWith
          : gsi_web.GSIButtonText.signinWith,
      logoAlignment: gsi_web.GSIButtonLogoAlignment.left,
      minimumWidth: 320,
      locale: 'vi',
    ),
  );
}
