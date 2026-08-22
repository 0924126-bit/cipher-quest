import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';

/// Secret password-change page.
///
/// Reachable ONLY by typing the URL directly: `/#/passkey`.
/// No link to this page exists anywhere in the app (dashboard included),
/// per operator request. Requires the current password; on success all
/// sessions (including this one) are revoked and everyone must re-enter
/// the new password.
class PasskeyPage extends StatefulWidget {
  const PasskeyPage({super.key});

  @override
  State<PasskeyPage> createState() => _PasskeyPageState();
}

class _PasskeyPageState extends State<PasskeyPage> {
  static const _bgTop = Color(0xFF2B3844);
  static const _bgBottom = Color(0xFF141B21);
  static const _ink = Color(0xFFCFD8E0);
  static const _inkDim = Color(0xFF7A8794);

  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final oldPw = _oldCtrl.text;
    final newPw = _newCtrl.text;
    final confirm = _confirmCtrl.text;
    setState(() => _error = null);
    if (oldPw.isEmpty || newPw.isEmpty) {
      setState(() => _error = 'すべての欄を入力してください');
      return;
    }
    if (newPw.length < 4) {
      setState(() => _error = '新しいパスワードは4文字以上にしてください');
      return;
    }
    if (newPw != confirm) {
      setState(() => _error = '新しいパスワード(確認)が一致しません');
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthService.instance.changePassword(oldPw, newPw);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _inkDim.withValues(alpha: 0.6)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        prefixIcon: Icon(icon, color: _inkDim, size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _inkDim.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _ink, width: 1.2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _inkDim.withValues(alpha: 0.2)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.4,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: _done ? _doneView() : _formView(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_reset_rounded, color: _ink, size: 52),
        const SizedBox(height: 14),
        Text(
          '合言葉の変更',
          style: GoogleFonts.shipporiMincho(
            color: _ink,
            fontSize: 21,
            letterSpacing: 6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '変更するとすべての端末で再ログインが必要になります',
          textAlign: TextAlign.center,
          style: GoogleFonts.shipporiMincho(
            color: _inkDim,
            fontSize: 11.5,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _oldCtrl,
          obscureText: true,
          enabled: !_busy,
          style: const TextStyle(color: _ink, letterSpacing: 2),
          decoration: _dec('現在のパスワード', Icons.key_rounded),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _newCtrl,
          obscureText: true,
          enabled: !_busy,
          style: const TextStyle(color: _ink, letterSpacing: 2),
          decoration: _dec('新しいパスワード(4文字以上)', Icons.fiber_new_rounded),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _confirmCtrl,
          obscureText: true,
          enabled: !_busy,
          onSubmitted: (_) => _submit(),
          style: const TextStyle(color: _ink, letterSpacing: 2),
          decoration: _dec('新しいパスワード(確認)', Icons.check_circle_outline),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: Color(0xFFE08A80), fontSize: 12.5),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _busy ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _ink,
              foregroundColor: _bgBottom,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Text(
                    '変更する',
                    style: GoogleFonts.shipporiMincho(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _doneView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_rounded,
            color: Color(0xFF8FC9A0), size: 60),
        const SizedBox(height: 16),
        Text(
          '変更しました',
          style: GoogleFonts.shipporiMincho(
            color: _ink,
            fontSize: 20,
            letterSpacing: 6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '全端末のセッションを無効化しました。\n新しいパスワードで入り直してください。',
          textAlign: TextAlign.center,
          style: GoogleFonts.shipporiMincho(
            color: _inkDim,
            fontSize: 12.5,
            letterSpacing: 1.5,
            height: 1.8,
          ),
        ),
        const SizedBox(height: 26),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              // token was revoked; RootGate will show the lock screen
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/', (_) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _ink,
              foregroundColor: _bgBottom,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'ログイン画面へ',
              style: GoogleFonts.shipporiMincho(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
