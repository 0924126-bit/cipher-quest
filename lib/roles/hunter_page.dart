import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/role_config.dart';
import '../services/alarm_service.dart';
import '../services/api_service.dart';
import '../services/fullscreen_service.dart';
import '../services/socket_service.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';

/// ハンター用のスマホ通知端末ページ。
///
/// /ws/hunter に常時接続し、呪術師が呪いのボタンを押すと
/// 音とバイブ付きで即座に通知が表示される。
class HunterPage extends StatefulWidget {
  const HunterPage({super.key});

  @override
  State<HunterPage> createState() => _HunterPageState();
}

class _HunterPageState extends State<HunterPage>
    with SingleTickerProviderStateMixin {
  HunterConfig _config = const HunterConfig();
  final List<CurseEvent> _events = [];
  bool _connected = false;
  bool _soundArmed = false;
  int _flashUntilMs = 0;

  SocketService? _socket;
  StreamSubscription? _msgSub;
  StreamSubscription? _statusSub;
  Timer? _flashTimer;
  Timer? _repeatTimer; // 呼び出し音を3秒間隔で繰り返す
  int _repeatLeft = 0;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _loadCurseSound();
    _connect();
  }

  /// ダッシュボードで割り当てた呪い発動音（mp3）があれば取得。
  /// 未割当なら内蔵の合成スティングのまま。
  Future<void> _loadCurseSound() async {
    try {
      final data = await ApiService.instance.getSoundsData();
      SoundService.instance.updateSources({'curse': data.roleMap['curse']});
    } catch (_) {}
  }

  void _playCurse() {
    if (!SoundService.instance.playCurseCustom()) {
      AlarmService.instance.playCurseSting();
    }
  }

  void _connect() {
    final s = SocketService('/ws/hunter', autoReconnect: true);
    _socket = s;
    _msgSub = s.messages.listen(_onMessage);
    _statusSub = s.connectionStatus.listen((ok) {
      if (mounted) setState(() => _connected = ok);
    });
    s.connect();
  }

  void _onMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'init':
        final roles = msg['roles'];
        if (roles is Map<String, dynamic>) {
          final cfg = RoleConfig.fromJson(roles);
          setState(() => _config = cfg.hunter);
        }
        final recent = msg['recent_curses'];
        if (recent is List) {
          setState(() {
            _events
              ..clear()
              ..addAll(recent.whereType<Map<String, dynamic>>()
                  .map(CurseEvent.fromJson));
          });
        }
        break;
      case 'roles':
        final roles = msg['roles'];
        if (roles is Map<String, dynamic>) {
          final cfg = RoleConfig.fromJson(roles);
          setState(() => _config = cfg.hunter);
        }
        break;
      case 'curse':
        final ev = msg['event'];
        if (ev is Map<String, dynamic>) {
          final curse = CurseEvent.fromJson(ev);
          setState(() {
            _events.add(curse);
            if (_events.length > 30) _events.removeAt(0);
            _flashUntilMs =
                DateTime.now().millisecondsSinceEpoch + 4000;
          });
          _startAlertRepeat();
          _flashTimer?.cancel();
          _flashTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) setState(() {});
          });
        }
        break;
    }
  }

  bool get _flashing =>
      DateTime.now().millisecondsSinceEpoch < _flashUntilMs;

  /// 呪い発動のアラート：即時鳴らしたあと、3秒間隔でさらに3回
  /// （合計4回・約10秒）繰り返す。ポケット内でも気づけるように。
  void _startAlertRepeat() {
    if (_soundArmed) _playCurse();
    AlarmService.instance.vibrate();
    _repeatTimer?.cancel();
    _repeatLeft = 3;
    _repeatTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || _repeatLeft <= 0) {
        timer.cancel();
        return;
      }
      _repeatLeft--;
      if (_soundArmed) _playCurse();
      AlarmService.instance.vibrate();
      if (_repeatLeft <= 0) timer.cancel();
    });
  }

  /// ブラウザの自動再生制限を解除するため、最初に1タップさせる。
  /// 同じジェスチャで全画面化も行う。
  void _armSound() {
    FullscreenService.instance.enter();
    _playCurse();
    setState(() => _soundArmed = true);
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _statusSub?.cancel();
    _socket?.dispose();
    _flashTimer?.cancel();
    _repeatTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.3,
            colors: _flashing
                ? [const Color(0xFF3A0E2E), const Color(0xFF14060F)]
                : [const Color(0xFF1A161E), AppColors.bgDeep],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 4),
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
              _header(),
              const SizedBox(height: 12),
              if (!_soundArmed) _armBanner(),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: _connected
                  ? AppColors.amberDim
                  : AppColors.blood,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'HUNTER',
            style: GoogleFonts.shipporiMincho(
              fontSize: 12,
              letterSpacing: 8,
              color: _connected ? AppColors.amber : AppColors.blood,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _config.title,
          textAlign: TextAlign.center,
          style: GoogleFonts.shipporiMincho(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.bone,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _connected ? '接続中 — 呪いの気配を監視している' : '再接続しています…',
          style: GoogleFonts.shipporiMincho(
            fontSize: 12,
            color: _connected ? AppColors.boneDim : AppColors.blood,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _armBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GestureDetector(
        onTap: _armSound,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.12),
            border: Border.all(color: AppColors.amberDim),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.volume_up, color: AppColors.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'タップして通知音を有効にする\n(ブラウザの仕様で最初に1回タップが必要です)',
                  style: GoogleFonts.shipporiMincho(
                    fontSize: 12,
                    color: AppColors.bone,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.nightlight_round,
                size: 48,
                color: AppColors.boneDim.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(
              'まだ呪いは放たれていない…',
              style: GoogleFonts.shipporiMincho(
                fontSize: 14,
                color: AppColors.boneDim,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      );
    }
    final latest = _events.last;
    final rest = _events.reversed.skip(1).take(10).toList();
    return Column(
      children: [
        const SizedBox(height: 8),
        _latestCard(latest),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: rest.length,
            itemBuilder: (context, i) => _historyTile(rest[i]),
          ),
        ),
      ],
    );
  }

  Widget _latestCard(CurseEvent ev) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final active = _flashing;
        final glow = active ? 0.3 + _pulse.value * 0.4 : 0.1;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF20121E),
            border: Border.all(
              color: active
                  ? const Color(0xFFB84AA0)
                  : const Color(0xFF4A2B45),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color:
                    const Color(0xFFB84AA0).withValues(alpha: glow),
                blurRadius: 40,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 40,
                color: active
                    ? const Color(0xFFE879C9)
                    : const Color(0xFF9B59D0),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ev.message,
                      style: GoogleFonts.shipporiMincho(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFECD9F5),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timeText(ev.atMs),
                      style: GoogleFonts.shipporiMincho(
                        fontSize: 12,
                        color: const Color(0xFF8E7BA8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _historyTile(CurseEvent ev) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFF34283E), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.history,
              size: 18, color: AppColors.boneDim),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ev.message,
              style: GoogleFonts.shipporiMincho(
                fontSize: 13,
                color: AppColors.bone,
              ),
            ),
          ),
          Text(
            _timeText(ev.atMs),
            style: GoogleFonts.shipporiMincho(
              fontSize: 11,
              color: AppColors.boneDim,
            ),
          ),
        ],
      ),
    );
  }

  String _timeText(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}
