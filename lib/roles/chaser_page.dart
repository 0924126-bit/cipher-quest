import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/role_config.dart';
import '../services/alarm_service.dart';
import '../services/api_service.dart';
import '../services/fullscreen_service.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';

/// チェイサー用ページ。
///
/// 大きな警報ボタンを押すとサイレンがN秒間鳴り響く。
/// 警報は【1回限り】。発動すると途中停止はできず、鳴り終わると
/// 使用済みになる。再度使えるのはダッシュボードで許可したときのみ。
class ChaserPage extends StatefulWidget {
  const ChaserPage({super.key});

  @override
  State<ChaserPage> createState() => _ChaserPageState();
}

class _ChaserPageState extends State<ChaserPage>
    with SingleTickerProviderStateMixin {
  ChaserConfig _config = const ChaserConfig();
  bool _loading = true;

  bool _alarming = false;
  int _remaining = 0;
  Timer? _countdown;
  SocketService? _socket;
  StreamSubscription? _wsSub;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    // 初回だけHTTPで即時表示。以降の設定変更（再許可含む）は
    // /ws/hunter のプッシュで反映。ポーリングは行わない
    // （Cloudflare無料枠のリクエスト数節約）。
    _loadConfig();
    _connectFeed();
  }

  void _connectFeed() {
    final s = SocketService('/ws/hunter', autoReconnect: true);
    _socket = s;
    _wsSub = s.messages.listen((msg) {
      final type = msg['type'];
      if (type != 'init' && type != 'roles') return;
      final roles = msg['roles'];
      if (roles is! Map<String, dynamic>) return;
      // 警報鳴動中はローカル状態を優先（鳴り終わりに取り直す）
      if (_alarming || !mounted) return;
      setState(() {
        _config = RoleConfig.fromJson(roles).chaser;
        _loading = false;
      });
    });
    s.connect();
  }

  Future<void> _loadConfig() async {
    try {
      final roles = await ApiService.instance.getRoles();
      if (!mounted) return;
      setState(() {
        _config = roles.chaser;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startAlarm() async {
    // ユーザージェスチャのタイミングで全画面化(初回タップ時)
    FullscreenService.instance.enter();
    // 鳴っている間は何をしても止まらない(1回限りの警報)
    if (_alarming) return;
    if (!_config.alarmArmed) return; // 使用済み

    // サーバーで消費(他端末との二重発動も防ぐ)
    int alarmSec;
    try {
      final sec = await ApiService.instance.fireChaserAlarm();
      if (sec == null) {
        // すでに使用済みだった
        await _loadConfig();
        return;
      }
      alarmSec = sec;
    } catch (_) {
      return; // 通信失敗時は発動しない(誤消費防止)
    }

    if (!mounted) return;
    AlarmService.instance.startSiren();
    AlarmService.instance.vibrate();
    setState(() {
      _alarming = true;
      _remaining = alarmSec;
      _config = ChaserConfig(
        title: _config.title,
        subtitle: _config.subtitle,
        alarmSec: _config.alarmSec,
        alarmArmed: false,
      );
    });
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining -= 1);
      if (_remaining <= 0) _finishAlarm();
    });
  }

  /// 時間切れでのみ停止する(手動停止は不可)。
  void _finishAlarm() {
    _countdown?.cancel();
    AlarmService.instance.stopSiren();
    if (mounted) {
      setState(() {
        _alarming = false;
        _remaining = 0;
      });
      _loadConfig(); // 最新の armed 状態を取り直す
    }
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _wsSub?.cancel();
    _socket?.dispose();
    AlarmService.instance.stopSiren();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: _alarming
                ? [const Color(0xFF3A0E0C), const Color(0xFF120404)]
                : [const Color(0xFF1D1A15), AppColors.bgDeep],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.amber))
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
                              color: AppColors.boneDim, size: 22),
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
                        color: _alarming
                            ? const Color(0xFFFF5545)
                            : AppColors.bone,
                        letterSpacing: 4,
                        shadows: [
                          Shadow(
                            color: (_alarming
                                    ? const Color(0xFFFF3B2F)
                                    : AppColors.amber)
                                .withValues(alpha: 0.5),
                            blurRadius: 24,
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
                        color: AppColors.boneDim,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    _alarmButton(),
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
        border: Border.all(
          color: _alarming ? const Color(0xFFFF3B2F) : AppColors.amberDim,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'CHASER',
        style: GoogleFonts.shipporiMincho(
          fontSize: 12,
          letterSpacing: 8,
          color: _alarming ? const Color(0xFFFF5545) : AppColors.amber,
        ),
      ),
    );
  }

  Widget _alarmButton() {
    final used = !_config.alarmArmed && !_alarming;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final glow = _alarming ? 0.35 + _pulse.value * 0.45 : 0.15;
        final color = used
            ? const Color(0xFF3A3733)
            : _alarming
                ? const Color(0xFFE23A2E)
                : const Color(0xFF8E2B24);
        return GestureDetector(
          onTap: used ? null : _startAlarm,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color,
                  Color.lerp(color, Colors.black, 0.55)!,
                ],
              ),
              border: Border.all(
                color: _alarming
                    ? const Color(0xFFFF6B5E)
                    : AppColors.amberDim,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: glow),
                  blurRadius: 60,
                  spreadRadius: _alarming ? 14 + _pulse.value * 10 : 4,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  used
                      ? Icons.notifications_off
                      : _alarming
                          ? Icons.notifications_active
                          : Icons.notifications_none,
                  size: 64,
                  color: Colors.white.withValues(alpha: used ? 0.4 : 0.92),
                ),
                const SizedBox(height: 10),
                Text(
                  used
                      ? '使用済み'
                      : _alarming
                          ? '発動中'
                          : '警報を鳴らす',
                  style: GoogleFonts.shipporiMincho(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: used ? 0.45 : 0.92),
                    letterSpacing: 3,
                  ),
                ),
                if (_alarming) ...[
                  const SizedBox(height: 6),
                  Text(
                    '残り ${math.max(0, _remaining)} 秒',
                    style: GoogleFonts.shipporiMincho(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusLine() {
    final used = !_config.alarmArmed && !_alarming;
    return Text(
      _alarming
          ? '‼ 警報発動中（停止はできない）‼'
          : used
              ? '警報は使用済みです。運営の許可を待ってください。'
              : '警報は1回限り。${_config.alarmSec} 秒間鳴り続け、途中では止められません。',
      style: GoogleFonts.shipporiMincho(
        fontSize: 13,
        color: _alarming
            ? const Color(0xFFFF5545)
            : used
                ? const Color(0xFF6E6A62)
                : AppColors.boneDim,
        letterSpacing: 2,
      ),
    );
  }
}
