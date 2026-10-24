import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_controller.dart';
import '../data/tiktube_api.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const Color _ink = Color(0xFF171426);
  static const Color _muted = Color(0xFF6B6879);
  static const Color _violet = Color(0xFF6C5CE7);
  static const Color _violetDark = Color(0xFF4A3BC7);
  static const Color _red = Color(0xFFE8112D);
  static const Color _pink = Color(0xFFF25C8A);
  static const Color _card = Color(0xFFFCFBFE);
  static const Color _field = Color(0xFFF5F4FA);
  static const Color _border = Color(0xFFE4E1EF);

  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _registerFormKey = GlobalKey<FormState>();

  final TextEditingController _login = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  final TextEditingController _age = TextEditingController();

  bool _register = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _login.dispose();
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _age.dispose();
    super.dispose();
  }

  void _setMode(bool register) {
    if (_submitting || _register == register) return;
    setState(() {
      _register = register;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final FormState? form = _register
        ? _registerFormKey.currentState
        : _loginFormKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_register) {
        final String ageText = _age.text.trim();
        await widget.controller.register(
          name: _name.text.trim(),
          username: _username.text.trim().toLowerCase(),
          email: _email.text.trim().toLowerCase(),
          password: _password.text,
          age: ageText.isEmpty ? null : int.tryParse(ageText),
        );
      } else {
        await widget.controller.login(
          login: _login.text.trim(),
          password: _password.text,
        );
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error =
            'Không thể kết nối tới máy chủ TIKTUBE. Kiểm tra API đang chạy rồi thử lại.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _friendlyError(ApiException error) {
    if (error.statusCode == 401) {
      return 'Tên đăng nhập hoặc mật khẩu không đúng.';
    }
    if (error.message.contains('Không kết nối được API')) {
      return 'Không kết nối được máy chủ TIKTUBE. Hãy chắc chắn API Dart đang chạy ở cổng 8787.';
    }
    return error.message;
  }

  String? _required(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  String? _emailValidator(String? value) {
    final String email = value?.trim() ?? '';
    if (email.isEmpty) return 'Vui lòng nhập email.';
    final RegExp pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!pattern.hasMatch(email)) return 'Email không hợp lệ.';
    return null;
  }

  String? _usernameValidator(String? value) {
    final String username = value?.trim().toLowerCase() ?? '';
    if (username.isEmpty) return 'Vui lòng nhập tên đăng nhập.';
    if (!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(username)) {
      return '3–30 ký tự: chữ, số, dấu gạch dưới.';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final String password = value ?? '';
    if (password.isEmpty) return 'Vui lòng nhập mật khẩu.';
    if (password.length < 8) return 'Mật khẩu cần ít nhất 8 ký tự.';
    return null;
  }

  String? _confirmValidator(String? value) {
    if (value == null || value.isEmpty) return 'Nhập lại mật khẩu.';
    if (value != _password.text) return 'Mật khẩu nhập lại chưa khớp.';
    return null;
  }

  String? _ageValidator(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final int? age = int.tryParse(text);
    if (age == null || age < 1 || age > 120) {
      return 'Tuổi phải từ 1 đến 120.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090B1A),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _AuthBackground()),
          Positioned(
            top: -140,
            right: -120,
            child: _Glow(color: _violet, size: 430),
          ),
          Positioned(
            bottom: -170,
            left: -130,
            child: _Glow(color: _pink, size: 420),
          ),
          Positioned(
            top: 120,
            left: -180,
            child: _Glow(color: const Color(0xFF2A6CF6), size: 380),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool wide = constraints.maxWidth >= 1020;
                final double verticalPad = wide ? 40 : 22;
                final double availableHeight =
                    constraints.maxHeight - verticalPad * 2;
                final double minHeight =
                    availableHeight > 0 ? availableHeight : 0;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 52 : 18,
                    vertical: verticalPad,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 1220,
                        minHeight: minHeight,
                      ),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 52),
                                    child: _brandPanel(context),
                                  ),
                                ),
                                SizedBox(
                                  width: 470,
                                  child: _authCard(context),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                _mobileHeader(context),
                                const SizedBox(height: 18),
                                _cardWidth(child: _authCard(context)),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardWidth({required Widget child}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 470),
      child: SizedBox(width: double.infinity, child: child),
    );
  }

  Widget _mobileHeader(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _AuthLogo(scale: 0.92),
        const SizedBox(height: 14),
        Text(
          'Nơi đam mê\nthành thước phim.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: MediaQuery.sizeOf(context).width < 420 ? 26 : 31,
            height: 1.03,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Đăng nhập để tiếp tục hành trình sáng tạo cùng TIKTUBE.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xB8FFFFFF),
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _brandPanel(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _AuthLogo(scale: 1.22),
          const SizedBox(height: 46),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                const TextSpan(text: 'Nơi đam mê\n'),
                TextSpan(
                  text: 'thành thước phim.',
                  style: TextStyle(
                    color: const Color(0xFFFF7A9C),
                    shadows: <Shadow>[
                      Shadow(
                        color: _pink.withValues(alpha: 0.35),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 53,
              height: 1.02,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.9,
            ),
          ),
          const SizedBox(height: 22),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: const Text(
              'Tải video, xây dựng kênh và theo dõi khán giả của bạn trên một nền tảng được kết nối dữ liệu thật.',
              style: TextStyle(
                color: Color(0xC7FFFFFF),
                fontSize: 15.5,
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 34),
          const _FeatureRow(
            icon: Icons.cloud_upload_outlined,
            title: 'Tải video an toàn',
            subtitle: 'Lưu trữ trực tiếp trên Cloudinary',
            accent: Color(0xFF7CE0C3),
          ),
          SizedBox(height: 18),
          const _FeatureRow(
            icon: Icons.insights_rounded,
            title: 'Thống kê thời gian thực',
            subtitle: 'Lượt xem, cảm xúc và bình luận từ Neon',
            accent: Color(0xFF9E8CFF),
          ),
          const SizedBox(height: 18),
          const _FeatureRow(
            icon: Icons.shield_outlined,
            title: 'Tài khoản được bảo vệ',
            subtitle: 'Đăng nhập bằng tài khoản web hiện có, phiên an toàn',
            accent: Color(0xFFFFA2B8),
          ),
          const SizedBox(height: 34),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: const <Widget>[
              _TechBadge(label: 'NEON POSTGRES', color: Color(0xFF62D6B0)),
              _TechBadge(label: 'CLOUDINARY', color: Color(0xFF8FA8FF)),
              _TechBadge(label: 'DART API', color: Color(0xFFFF9DB4)),
            ],
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _LiveDot(),
                SizedBox(width: 9),
                Text(
                  'Hệ thống đang kết nối dữ liệu thật',
                  style: TextStyle(
                    color: Color(0xD9FFFFFF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _authCard(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 1020;
    return Container(
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width < 420 ? 22 : 30,
        compact ? 22 : 26,
        MediaQuery.sizeOf(context).width < 420 ? 22 : 30,
        24,
      ),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF070511).withValues(alpha: 0.42),
            blurRadius: 60,
            offset: const Offset(0, 26),
          ),
          BoxShadow(
            color: _violet.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _MiniLogo(),
            SizedBox(height: compact ? 20 : 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                _register ? 'Tạo tài khoản mới' : 'Chào mừng trở lại',
                key: ValueKey<bool>(_register),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 28,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.9,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _register
                  ? 'Chỉ mất một phút để bắt đầu xây dựng kênh của bạn.'
                  : 'Đăng nhập để xem video, bình luận và quản lý kênh.',
              style: const TextStyle(
                color: _muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            _modeSwitch(),
            const SizedBox(height: 18),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _errorBanner(_error!),
                    ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _register ? _registerForm() : _loginForm(),
            ),
            const SizedBox(height: 20),
            _GradientButton(
              key: const ValueKey<String>('auth-submit'),
              label: _register ? 'Tạo tài khoản' : 'Đăng nhập',
              loadingLabel:
                  _register ? 'Đang tạo tài khoản...' : 'Đang đăng nhập...',
              loading: _submitting,
              onTap: _submit,
            ),
            const SizedBox(height: 18),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.verified_user_outlined, size: 13, color: _muted),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Tài khoản dùng chung với web · Phiên đăng nhập 30 ngày',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 10.5,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EEF8),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE8E5F3)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _ModeButton(
              label: 'Đăng nhập',
              selected: !_register,
              onTap: () => _setMode(false),
            ),
          ),
          Expanded(
            child: _ModeButton(
              label: 'Đăng ký',
              selected: _register,
              onTap: () => _setMode(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F3),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFF7C9D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline_rounded, size: 17, color: _red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF9F1D2F),
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loginForm() {
    return Form(
      key: _loginFormKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _AuthField(
            controller: _login,
            label: 'Email hoặc tên đăng nhập',
            hint: 'email@example.com hoặc tên đăng nhập',
            icon: Icons.alternate_email_rounded,
            autofillHints: const <String>[AutofillHints.username],
            textInputAction: TextInputAction.next,
            validator: (String? value) => _required(
              value,
              'Vui lòng nhập email hoặc tên đăng nhập.',
            ),
          ),
          const SizedBox(height: 12),
          _AuthField(
            controller: _password,
            label: 'Mật khẩu',
            hint: 'Nhập mật khẩu của bạn',
            icon: Icons.lock_outline_rounded,
            obscureText: !_showPassword,
            autofillHints: const <String>[AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: _submit,
            suffix: _VisibilityButton(
              visible: _showPassword,
              onTap: () => setState(() => _showPassword = !_showPassword),
            ),
            validator: (String? value) => _required(
              value,
              'Vui lòng nhập mật khẩu.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _registerForm() {
    return Form(
      key: _registerFormKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget nameField = _AuthField(
                controller: _name,
                label: 'Tên hiển thị',
                hint: 'Nguyễn Văn A',
                icon: Icons.person_outline_rounded,
                autofillHints: const <String>[AutofillHints.name],
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                validator: (String? value) => _required(
                  value,
                  'Nhập tên hiển thị.',
                ),
              );
              final Widget usernameField = _AuthField(
                controller: _username,
                label: 'Tên đăng nhập',
                hint: 'nguyenvana',
                icon: Icons.tag_rounded,
                autofillHints: const <String>[AutofillHints.newUsername],
                textInputAction: TextInputAction.next,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                  LengthLimitingTextInputFormatter(30),
                ],
                validator: _usernameValidator,
              );
              if (constraints.maxWidth >= 380) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: nameField),
                    const SizedBox(width: 10),
                    Expanded(child: usernameField),
                  ],
                );
              }
              return Column(
                children: <Widget>[
                  nameField,
                  const SizedBox(height: 12),
                  usernameField,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _AuthField(
            controller: _email,
            label: 'Email',
            hint: 'email@example.com',
            icon: Icons.mail_outline_rounded,
            autofillHints: const <String>[AutofillHints.email],
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _emailValidator,
          ),
          const SizedBox(height: 12),
          _AuthField(
            controller: _password,
            label: 'Mật khẩu',
            hint: 'Ít nhất 8 ký tự',
            icon: Icons.lock_outline_rounded,
            obscureText: !_showPassword,
            autofillHints: const <String>[AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            suffix: _VisibilityButton(
              visible: _showPassword,
              onTap: () => setState(() => _showPassword = !_showPassword),
            ),
            validator: _passwordValidator,
          ),
          const SizedBox(height: 12),
          _AuthField(
            controller: _confirmPassword,
            label: 'Nhập lại mật khẩu',
            hint: 'Nhập lại mật khẩu ở trên',
            icon: Icons.lock_reset_rounded,
            obscureText: !_showConfirmPassword,
            textInputAction: TextInputAction.next,
            suffix: _VisibilityButton(
              visible: _showConfirmPassword,
              onTap: () =>
                  setState(() => _showConfirmPassword = !_showConfirmPassword),
            ),
            validator: _confirmValidator,
          ),
          const SizedBox(height: 12),
          _AuthField(
            controller: _age,
            label: 'Tuổi (không bắt buộc)',
            hint: '18',
            icon: Icons.cake_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: _submit,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            validator: _ageValidator,
          ),
        ],
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: <double>[0, 0.5, 1],
          colors: <Color>[
            Color(0xFF080A18),
            Color(0xFF14112E),
            Color(0xFF26123F),
          ],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color.withValues(alpha: 0.38),
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0),
            ],
            stops: const <double>[0, 0.42, 1],
          ),
        ),
      ),
    );
  }
}

class _AuthLogo extends StatelessWidget {
  const _AuthLogo({this.scale = 1});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 46 * scale,
          height: 33 * scale,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFFFF3850), Color(0xFFC90C27)],
            ),
            borderRadius: BorderRadius.circular(7 * scale),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFE8112D).withValues(alpha: 0.35),
                blurRadius: 18 * scale,
                offset: Offset(0, 6 * scale),
              ),
            ],
          ),
          child: Text(
            'PTK',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14 * scale,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4 * scale,
              height: 1,
            ),
          ),
        ),
        SizedBox(width: 10 * scale),
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              const TextSpan(
                text: 'TIK',
                style: TextStyle(color: Color(0xFFFF5A70)),
              ),
              TextSpan(
                text: 'TUBE',
                style: TextStyle(
                  color: Colors.white,
                  shadows: <Shadow>[
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
          style: TextStyle(
            fontSize: 27 * scale,
            fontWeight: FontWeight.w900,
            letterSpacing: -1 * scale,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _MiniLogo extends StatelessWidget {
  const _MiniLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 34,
          height: 25,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFFFF3850), Color(0xFFC90C27)],
            ),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            'PTK',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text.rich(
          const TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: 'TIK',
                style: TextStyle(color: Color(0xFFE8112D)),
              ),
              TextSpan(
                text: 'TUBE',
                style: TextStyle(color: Color(0xFF171426)),
              ),
            ],
          ),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, size: 20, color: accent),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xA8FFFFFF),
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TechBadge extends StatelessWidget {
  const _TechBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xB8FFFFFF),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF54D6A0),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Color(0x6654D6A0), blurRadius: 8, spreadRadius: 2),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              boxShadow: selected
                  ? <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFF1A1335).withValues(alpha: 0.09),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? _AuthScreenState._ink
                    : _AuthScreenState._muted,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
    this.suffix,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: _AuthScreenState._border),
    );

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      enableSuggestions: !obscureText,
      autocorrect: false,
      cursorColor: _AuthScreenState._violet,
      style: const TextStyle(
        color: _AuthScreenState._ink,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      validator: validator,
      onFieldSubmitted: (_) => onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          color: _AuthScreenState._muted,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: _AuthScreenState._violetDark,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(
          color: _AuthScreenState._muted.withValues(alpha: 0.68),
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(
          icon,
          size: 18,
          color: _AuthScreenState._muted,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 44),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 44),
        filled: true,
        fillColor: _AuthScreenState._field,
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(0, 17, 14, 15),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(
            color: _AuthScreenState._violet,
            width: 1.5,
          ),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(
            color: _AuthScreenState._red,
            width: 1.1,
          ),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(
            color: _AuthScreenState._red,
            width: 1.4,
          ),
        ),
        errorStyle: const TextStyle(
          color: _AuthScreenState._red,
          fontSize: 10.5,
          height: 1.25,
          fontWeight: FontWeight.w500,
        ),
        errorMaxLines: 2,
      ),
    );
  }
}

class _VisibilityButton extends StatelessWidget {
  const _VisibilityButton({required this.visible, required this.onTap});

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: visible ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
      splashRadius: 20,
      icon: Icon(
        visible
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        size: 18,
        color: _AuthScreenState._muted,
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    super.key,
    required this.label,
    required this.loadingLabel,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final String loadingLabel;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = !loading;

    return Semantics(
      button: true,
      label: loading ? loadingLabel : label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[Color(0xFFE8112D), Color(0xFFF25C8A)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: enabled
                  ? <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFFE8112D).withValues(alpha: 0.28),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: loading
                    ? Row(
                        key: const ValueKey<String>('loading'),
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            loadingLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        key: const ValueKey<String>('label'),
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 17,
                            color: Colors.white,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
