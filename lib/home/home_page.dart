import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/url_open.dart'
    if (dart.library.js_interop) '../services/url_open_web.dart';

/// トップページ（/）。来場者向けの公開入口。
///
/// デザイン方針: Google的ミニマリズム。白背景・十分な余白・
/// 細いタイポグラフィ・アクセント1色（青）。
///
/// 導線: 「予約する」「整理券を表示」＋（口コミが有効なら）「口コミを見る」。
/// 隠し導線: ロゴを10回連続タップ（2秒以内間隔）すると
/// ダッシュボードのパスワード画面（/dashboard）へ移動する。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _accent = Color(0xFF1A73E8);
  static const _ink = Color(0xFF202124);
  static const _sub = Color(0xFF5F6368);
  static const _line = Color(0xFFDADCE0);

  int _taps = 0;
  Timer? _tapReset;
  bool _reviewsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkReviews();
  }

  @override
  void dispose() {
    _tapReset?.cancel();
    super.dispose();
  }

  /// 口コミが有効ならリンクを出す（無効なら何も表示しない）。
  Future<void> _checkReviews() async {
    try {
      final (enabled, _) = await ApiService.instance.listReviews();
      if (!mounted) return;
      setState(() => _reviewsEnabled = enabled);
    } catch (_) {}
  }

  /// ロゴ10連続タップ → スタッフ用パスワード画面へ（見た目の反応なし）。
  void _logoTap() {
    _tapReset?.cancel();
    _taps++;
    if (_taps >= 10) {
      _taps = 0;
      gotoHashRoute('/dashboard');
      return;
    }
    _tapReset = Timer(const Duration(seconds: 2), () => _taps = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ロゴ（隠しタップ対象）
                  Center(
                    child: GestureDetector(
                      onTap: _logoTap,
                      behavior: HitTestBehavior.opaque,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/identity_e_logo.png',
                          width: 88,
                          height: 88,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Identity E',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w400,
                      color: _ink,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '史上最恐の鬼ごっこ',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: _sub),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26)),
                      ),
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/reserve'),
                      icon: const Icon(Icons.event_available, size: 20),
                      label: const Text('予約する',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _line),
                        foregroundColor: _ink,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26)),
                      ),
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/ticket'),
                      icon: const Icon(Icons.confirmation_number_outlined,
                          size: 20, color: _sub),
                      label: const Text('整理券を表示',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500)),
                    ),
                  ),
                  if (_reviewsEnabled) ...[
                    const SizedBox(height: 28),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/kutikomi'),
                      child: const Text('口コミを見る',
                          style: TextStyle(fontSize: 13, color: _sub)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
