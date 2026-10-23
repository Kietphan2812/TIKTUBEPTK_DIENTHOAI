import 'package:flutter/material.dart';

import '../auth/auth_scope.dart';
import '../data/api_client.dart';
import '../data/tiktube_api.dart';
import '../models/profile.dart';
import '../theme/app_theme.dart';
import '../widgets/section_top_bar.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, this.api});

  final TikTubeApi? api;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final TikTubeApi _api;
  final TextEditingController _username = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _age = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _prefilled = false;
  String? _error;
  String _displayName = 'kiepthan4';
  String _userKey = '';

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiClient();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final Profile? cached = AuthScope.maybeOf(context)?.profile;
    if (cached == null) return;
    _username.text = cached.name;
    _email.text = cached.email;
    _age.text = cached.age?.toString() ?? '';
    _displayName = cached.name.isEmpty ? cached.userKey : cached.name;
    _userKey = cached.userKey;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Profile profile = await _api.fetchProfile();
      if (!mounted) return;
      setState(() {
        _username.text = profile.name;
        _email.text = profile.email;
        _age.text = profile.age?.toString() ?? '';
        _displayName = profile.name.isEmpty ? profile.userKey : profile.name;
        _userKey = profile.userKey;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _age.dispose();
    super.dispose();
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _save({
    String message = 'Đã lưu thông tin tài khoản vào Neon.',
  }) async {
    if (_saving) return;
    final String name = _username.text.trim();
    final String email = _email.text.trim();
    final int? age = int.tryParse(_age.text.trim());

    if (name.isEmpty) {
      _notify('Tên đăng nhập không được để trống.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _notify('Email không hợp lệ.');
      return;
    }
    if (age != null && (age < 1 || age > 120)) {
      _notify('Tuổi phải nằm trong khoảng 1–120.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final Profile profile = await _api.updateProfile(
        name: name,
        email: email,
        age: age,
      );
      if (!mounted) return;
      setState(() {
        _displayName = profile.name.isEmpty ? profile.userKey : profile.name;
        _userKey = profile.userKey;
        _saving = false;
      });
      AuthScope.maybeOf(context)?.updateProfileCache(profile);
      _notify(message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _notify('Không lưu được tài khoản: $error');
    }
  }

  void _goHome() {
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  }

  Future<void> _logout() async {
    final auth = AuthScope.maybeOf(context);
    if (auth == null) {
      _goHome();
      return;
    }
    _goHome();
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bool compact = MediaQuery.sizeOf(context).width < 700;

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: <Widget>[
          SectionTopBar(
            title: 'Tài khoản',
            onBack: () => Navigator.of(context).maybePop(),
            onHome: _goHome,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: RefreshIndicator(
                color: p.brandRed,
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    compact ? 14 : 24,
                    compact ? 14 : 24,
                    compact ? 14 : 24,
                    32,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _ProfileHeader(
                            displayName: _displayName,
                            userKey: _userKey,
                            loading: _loading,
                            compact: compact,
                          ),
                          if (_error != null) ...<Widget>[
                            const SizedBox(height: 12),
                            _ErrorBanner(error: _error!, onRetry: _load),
                          ],
                          const SizedBox(height: 16),
                          _ProfileFormCard(
                            compact: compact,
                            username: _username,
                            email: _email,
                            age: _age,
                            saving: _saving,
                            onSave: _save,
                          ),
                          const SizedBox(height: 16),
                          _SessionCard(
                            displayName: _displayName,
                            onLogout: _logout,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.userKey,
    required this.loading,
    required this.compact,
  });

  final String displayName;
  final String userKey;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 22),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: compact ? 58 : 66,
            height: compact ? 58 : 66,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: p.ctaGradient),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Xin chào!',
                  style: TextStyle(
                    fontSize: compact ? 20 : 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: p.textPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${userKey.isEmpty ? '...' : userKey}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: p.textSecondary),
                ),
              ],
            ),
          ),
          if (loading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: p.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileFormCard extends StatelessWidget {
  const _ProfileFormCard({
    required this.compact,
    required this.username,
    required this.email,
    required this.age,
    required this.saving,
    required this.onSave,
  });

  final bool compact;
  final TextEditingController username;
  final TextEditingController email;
  final TextEditingController age;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 22),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Thông tin cá nhân',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Tài khoản dùng chung với phiên bản web TIKTUBE.',
            style: TextStyle(fontSize: 11.5, color: p.textSecondary),
          ),
          const SizedBox(height: 18),
          _ProfileField(
            controller: username,
            label: 'Tên hiển thị',
            hint: 'Nhập tên hiển thị',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          _ProfileField(
            controller: email,
            label: 'Email',
            hint: 'email@example.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          _ProfileField(
            controller: age,
            label: 'Tuổi (không bắt buộc)',
            hint: 'Ví dụ: 18',
            icon: Icons.cake_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: onSave,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: saving ? null : onSave,
              style: FilledButton.styleFrom(
                backgroundColor: p.brandRed,
                foregroundColor: Colors.white,
                disabledBackgroundColor: p.brandRed.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Lưu thông tin',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: p.border),
    );

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: (_) => onSubmitted?.call(),
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: p.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(fontSize: 12.5, color: p.textSecondary),
        floatingLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: p.brandRed,
        ),
        hintStyle: TextStyle(
          fontSize: 12.5,
          color: p.textSecondary.withValues(alpha: 0.7),
        ),
        prefixIcon: Icon(icon, size: 19, color: p.textSecondary),
        filled: true,
        fillColor: p.surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: p.brandRed, width: 1.4),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.displayName, required this.onLogout});

  final String displayName;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.verified_user_outlined,
                size: 18,
                color: p.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Phiên đăng nhập',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E9E62).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Đang hoạt động',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E9E62),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Đăng nhập với tài khoản $displayName · phiên lưu 30 ngày.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: p.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Đăng xuất'),
              style: OutlinedButton.styleFrom(
                foregroundColor: p.brandRed,
                side: BorderSide(color: p.brandRed.withValues(alpha: 0.45)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: p.brandRed.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.brandRed.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.cloud_off_rounded, size: 17, color: p.brandRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Không tải được hồ sơ từ Neon. Đang dùng dữ liệu đã lưu.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: p.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: p.brandRed,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Thử lại',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
