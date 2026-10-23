import 'package:flutter/material.dart';

import '../auth/auth_scope.dart';
import '../data/api_client.dart';
import '../data/tiktube_api.dart';
import '../models/profile.dart';
import '../widgets/app_pill.dart';
import '../widgets/dashed_box.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, this.api});

  final TikTubeApi? api;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  static const Color _purple = Color(0xFF7A6BF0);
  static const Color _ink = Color(0xFF262633);
  static const Color _muted = Color(0xFF5D5D6E);
  static const Color _card = Color(0xFFF2F0FA);
  static const Color _fieldBorder = Color(0xFFDAD8E8);

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

    setState(() => _saving = true);
    try {
      final Profile profile = await _api.updateProfile(
        name: name,
        email: email,
        age: age,
      );
      if (!mounted) return;
      setState(() {
        _displayName = profile.name;
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

  void _updateAge() {
    final value = _age.text.trim();
    final int? age = int.tryParse(value);
    if (age == null || age < 1 || age > 120) {
      _notify('Vui lòng nhập số tuổi hợp lệ (1–120).');
      return;
    }
    _save(message: 'Đã cập nhật tuổi: $age.');
  }

  Future<void> _logout() async {
    final auth = AuthScope.maybeOf(context);
    if (auth == null) {
      _notify('Đã đăng xuất khỏi tài khoản $_displayName.');
      Navigator.of(context).maybePop();
      return;
    }
    final navigator = Navigator.of(context);
    navigator.popUntil((Route<dynamic> route) => route.isFirst);
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF6C7BF0), Color(0xFF8A5CD9)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 384),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(26, 28, 26, 22),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        'Xin chào!',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: _ink,
                        ),
                      ),
                      if (_loading)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Đang tải hồ sơ từ Neon...',
                            style: TextStyle(
                              fontSize: 11,
                              color: _muted.withValues(alpha: 0.8),
                            ),
                          ),
                        )
                      else if (_error != null)
                        TextButton(
                          onPressed: _load,
                          child: const Text(
                            'Không tải được hồ sơ — Thử lại',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 92,
                        height: 92,
                        child: Stack(
                          children: <Widget>[
                            Container(
                              width: 88,
                              height: 88,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[
                                    Color(0xFF5B6B8C),
                                    Color(0xFF32405C),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 26,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _purple,
                                  border: Border.all(color: _card, width: 2),
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _Field(label: 'Tên hiển thị:', controller: _username),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Tên đăng nhập: @${_userKey.isEmpty ? '...' : _userKey}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: _muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Field(label: 'Email:', controller: _email),
                      const SizedBox(height: 16),
                      Center(
                        child: AppPill(
                          label: _saving ? 'Đang lưu...' : 'Lưu thông tin',
                          height: 34,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          background: _purple,
                          foreground: Colors.white,
                          onTap: _saving ? () {} : () => _save(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      DashedBox(
                        color: const Color(0xFFB9B4D8),
                        radius: 8,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                        child: Column(
                          children: <Widget>[
                            Text(
                              'Tuổi của bạn: ${_age.text.isEmpty ? '--' : _age.text}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _muted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                SizedBox(
                                  width: 96,
                                  height: 30,
                                  child: TextField(
                                    controller: _age,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: _ink,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: 'Số tuổi',
                                      hintStyle: const TextStyle(
                                        fontSize: 11,
                                        color: _muted,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 7,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(5),
                                        borderSide: const BorderSide(
                                          color: _fieldBorder,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(5),
                                        borderSide: const BorderSide(
                                          color: _fieldBorder,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(5),
                                        borderSide: const BorderSide(
                                          color: _purple,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                AppPill(
                                  label: 'Cập nhật',
                                  height: 30,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  background: _purple,
                                  foreground: Colors.white,
                                  onTap: _saving ? () {} : _updateAge,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: FilledButton(
                          onPressed: _logout,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFF0475A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text(
                            'Đăng xuất',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: TextButton.styleFrom(
                          foregroundColor: _purple,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Vào xem video ngay →'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: _AccountScreenState._muted,
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 34,
          child: TextField(
            controller: controller,
            style: const TextStyle(
              fontSize: 12,
              color: _AccountScreenState._ink,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(
                  color: _AccountScreenState._fieldBorder,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(
                  color: _AccountScreenState._fieldBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(
                  color: _AccountScreenState._purple,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
