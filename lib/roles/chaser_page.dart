import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/role_config.dart';
import '../services/alarm_service.dart';
import '../services/api_service.dart';
import '../services/fullscreen_service.dart';
import '../theme/app_theme.dart';

/// チェイサー用ページ。
///
/// 大きな警報ボタンを押すと防犯ブザーのようなサイレンが
/// N秒間(運営ダッシュボードで調整可能)鳴り響く。
/// 画面には「あなたはチェイサーです」(タイトルも変更可能)。
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
  Timer? _configPoll;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _loadConfig();
    // 運営がダッシュボードで設定を変えたら数秒で反映される
    _configPoll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_alarming) _loadConfig();
    });
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

  void _startAlarm() {
    // ユーザージェスチャのタイミングで全画面化(初回タップ時)
    FullscreenService.instance.enter();
    if (_alarming) {
      _stopAlarm();
      return;
    }
    AlarmService.instance.startSiren();
    AlarmService.instance.vibrate();
    setState(() {
      _alarming = true;
      _remaining = _config.alarmSec;
    });
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining -= 1);
      if (_remaining <= 0) _stopAlarm();
    });
  }

  void _stopAlarm() {
    _countdown?.cancel();
    AlarmService.instance.stopSiren();
    if (mounted) {
      setState(() {
        _alarming = false;
        _remaining = 0;
      });
    }
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _configPoll?.cancel();
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
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final glow = _alarming ? 0.35 + _pulse.value * 0.45 : 0.15;
        final color =
            _alarming ? const Color(0xFFE23A2E) : const Color(0xFF8E2B24);
        return GestureDetector(
          onTap: _startAlarm,
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
                  _alarming
                      ? Icons.notifications_active
                      : Icons.notifications_none,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
                const SizedBox(height: 10),
                Text(
                  _alarming ? '停止する' : '警報を鳴らす',
                  style: GoogleFonts.shipporiMincho(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.92),
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
    return Text(
      _alarming
          ? '‼ 警報発動中 ‼'
          : '警報は ${_config.alarmSec} 秒間鳴り続けます',
      style: GoogleFonts.shipporiMincho(
        fontSize: 13,
        color: _alarming ? const Color(0xFFFF5545) : AppColors.boneDim,
        letterSpacing: 2,
      ),
    );
  }
}
