import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/role_config.dart';
import '../services/alarm_service.dart';
import '../services/api_service.dart';
import '../services/fullscreen_service.dart';

/// 呪術師用ページ。
///
/// 呪いのボタンを1回押すとクールダウン(運営ダッシュボードで調整可能、
/// 既定30秒)に入り、その間は押せない。押すと運営ダッシュボードと
/// ハンター端末に音付きで通知が飛ぶ。
/// ボタンの見た目はアップロード画像に差し替え可能。未設定時は
/// 呪いの刻印風の怖いデフォルトデザイン。
class CursedPage extends StatefulWidget {
  const CursedPage({super.key});

  @override
  State<CursedPage> createState() => _CursedPageState();
}

class _CursedPageState extends State<CursedPage>
    with SingleTickerProviderStateMixin {
  CursedConfig _config = const CursedConfig();
  bool _loading = true;

  int _cooldownLeft = 0;
  Timer? _cooldown;
  Timer? _configPoll;
  bool _justFired = false;

  late final AnimationController _breath;

  bool get _ready => _cooldownLeft <= 0;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _loadConfig();
    _configPoll = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadConfig();
    });
  }

  Future<void> _loadConfig() async {
    try {
      final roles = await ApiService.instance.getRoles();
      if (!mounted) return;
      final newImage = roles.cursed.buttonImage;
      // ボタン画像を先読みして表示遅延をなくす
      if (newImage.isNotEmpty && newImage != _config.buttonImage) {
        precacheImage(NetworkImage(newImage), context);
      }
      setState(() {
        _config = roles.cursed;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fireCurse() async {
    // ユーザージェスチャのタイミングで全画面化
    FullscreenService.instance.enter();
    if (!_ready) return;
    setState(() {
      _cooldownLeft = _config.cooldownSec;
      _justFired = true;
    });
    AlarmService.instance.playCursePress();
    AlarmService.instance.vibrate();
    try {
      final cd = await ApiService.instance.pressCurse();
      if (mounted && cd != _config.cooldownSec) {
        setState(() => _cooldownLeft = math.min(_cooldownLeft, cd));
      }
    } catch (_) {
      // 通信失敗してもローカルのクールダウンは維持(連打防止)
    }
    _cooldown?.cancel();
    _cooldown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _cooldownLeft -= 1;
        if (_cooldownLeft <= 0) {
          _cooldownLeft = 0;
          _justFired = false;
          _cooldown?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _cooldown?.cancel();
    _configPoll?.cancel();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0710),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.4,
            colors: [Color(0xFF1C1230), Color(0xFF0A0710)],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: Color(0xFF9B59D0)))
              : Column(
                  children: [
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          tooltip: '全画面表示',
                          onPressed: () =>
                              FullscreenService.instance.toggle(),
                          icon: const Icon(Icons.fullscreen,
                              color: Color(0xFF6E5E85), size: 22),
                        ),
                      ),
                    ),
                    _roleBadge(),
                    const SizedBox(height: 16),
                    Text(
                      _config.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.shipporiMincho(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFCDB4E8),
                        letterSpacing: 4,
                        shadows: const [
                          Shadow(
                            color: Color(0xFF7C3AED),
                            blurRadius: 26,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _config.subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.shipporiMincho(
                        fontSize: 14,
                        color: const Color(0xFF6E5E85),
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    _curseButton(),
                    const Spacer(),
                    _statusLine(),
                    const SizedBox(height: 28),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _roleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF5B3A8C)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'CURSED',
        style: GoogleFonts.shipporiMincho(
          fontSize: 12,
          letterSpacing: 8,
          color: const Color(0xFF9B59D0),
        ),
      ),
    );
  }

  Widget _curseButton() {
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, _) {
        final glow = _ready ? 0.25 + _breath.value * 0.35 : 0.06;
        return GestureDetector(
          onTap: _fireCurse,
          child: Opacity(
            opacity: _ready ? 1.0 : 0.55,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _ready
                      ? const Color(0xFF9B59D0)
                      : const Color(0xFF3A2B52),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: glow),
                    blurRadius: 70,
                    spreadRadius: _ready ? 10 + _breath.value * 8 : 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: _config.buttonImage.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            _config.buttonImage,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            frameBuilder: (context, child, frame,
                                wasSyncLoaded) {
                              if (wasSyncLoaded || frame != null) {
                                return child;
                              }
                              // 読み込み中は既定の刻印を見せて空白を防ぐ
                              return _defaultFace();
                            },
                            errorBuilder: (_, __, ___) => _defaultFace(),
                          ),
                          if (!_ready) _cooldownVeil(),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          _defaultFace(),
                          if (!_ready) _cooldownVeil(),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 画像未設定時の「呪いの刻印」風デフォルトデザイン。
  Widget _defaultFace() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0xFF2C1745), Color(0xFF120A20)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '呪',
            style: GoogleFonts.shipporiMincho(
              fontSize: 96,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFB388E0),
              shadows: const [
                Shadow(color: Color(0xFF7C3AED), blurRadius: 30),
                Shadow(color: Color(0xFFE23A2E), blurRadius: 60),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _ready ? '触れれば呪いが放たれる' : '力を溜めている…',
            style: GoogleFonts.shipporiMincho(
              fontSize: 12,
              color: const Color(0xFF8E7BA8),
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cooldownVeil() {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_cooldownLeft',
              style: GoogleFonts.shipporiMincho(
                fontSize: 64,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFCDB4E8),
              ),
            ),
            Text(
              '秒後に再び使える',
              style: GoogleFonts.shipporiMincho(
                fontSize: 12,
                color: const Color(0xFF8E7BA8),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusLine() {
    final text = _justFired && !_ready
        ? '呪いを放った——ハンターに伝わった'
        : _ready
            ? '呪いは ${_config.cooldownSec} 秒に1度だけ放てる'
            : '呪力回復中…';
    return Text(
      text,
      style: GoogleFonts.shipporiMincho(
        fontSize: 13,
        color: _justFired && !_ready
            ? const Color(0xFFB388E0)
            : const Color(0xFF6E5E85),
        letterSpacing: 2,
      ),
    );
  }
}
