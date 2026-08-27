import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/role_config.dart';
import '../services/api_service.dart';
import '../services/key_sound_map.dart';
import '../services/sound_service.dart';
import 'widgets/timer_candles.dart';

/// 廃校ホラータイマー。
///
/// - 残り時間: 数字ではなく「儀式の蝋燭」13本が燃え尽きていく表示
/// - 背景: ダッシュボードから差し替え可能な廃校画像（初期は内蔵の廃校廊下）
/// - BGM: ループ再生（初期は合成ホラードローン、ダッシュボードでmp3差替可）
/// - キー音: キーごとにダッシュボードで割り当てた音を再生（未割当は既定音）
/// - 演出: 明滅する蛍光灯、残り時間わずかで血の色に
class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage>
    with TickerProviderStateMixin {
  TimerConfig _cfg = const TimerConfig();

  int _remaining = 300; // sec
  bool _running = false;
  bool _finished = false;
  Timer? _tick;

  // 蛍光灯の明滅
  final math.Random _rand = math.Random();
  double _flickerLevel = 1.0;
  Timer? _flickerTimer;

  // 蝋燭の炎の揺らぎ
  late final AnimationController _flame;

  final FocusNode _focus = FocusNode();
  bool _bgmStarted = false;

  @override
  void initState() {
    super.initState();
    _flame = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _scheduleFlicker();
    _load();
    // ページ表示中は音源マップを取得（デフォルトはビルド内蔵）
    _loadSounds();
  }

  Future<void> _load() async {
    try {
      final roles = await ApiService.instance.getRoles();
      if (!mounted) return;
      setState(() {
        _cfg = roles.timer;
        if (!_running && !_finished) _remaining = _cfg.durationSec;
      });
    } catch (_) {
      // 未認証などでも初期設定で動く
    }
  }

  Future<void> _loadSounds() async {
    try {
      final data = await ApiService.instance.getSoundsData();
      SoundService.instance.updateSources({
        'timer_bgm':
            data.roleMap['timer_bgm'] ?? '/audio/timer_bgm.mp3',
        'timer_key':
            data.roleMap['timer_key'] ?? '/audio/timer_key.mp3',
      });
      SoundService.instance.updateKeySounds(data.keyMap);
    } catch (_) {
      // 未認証時はビルド内蔵のデフォルト音を使う
      SoundService.instance.updateSources(const {
        'timer_bgm': '/audio/timer_bgm.mp3',
        'timer_key': '/audio/timer_key.mp3',
      });
    }
  }

  void _scheduleFlicker() {
    _flickerTimer?.cancel();
    _flickerTimer = Timer(
      Duration(milliseconds: 600 + _rand.nextInt(3200)),
      () {
        if (!mounted) return;
        // ランダムに 1〜4 回チカチカ
        final times = 1 + _rand.nextInt(3);
        var count = 0;
        Timer.periodic(const Duration(milliseconds: 70), (t) {
          if (!mounted) {
            t.cancel();
            return;
          }
          setState(() {
            _flickerLevel = count % 2 == 0
                ? 0.35 + _rand.nextDouble() * 0.3
                : 1.0;
          });
          count++;
          if (count >= times * 2) {
            t.cancel();
            setState(() => _flickerLevel = 1.0);
          }
        });
        _scheduleFlicker();
      },
    );
  }

  void _ensureBgm() {
    if (_bgmStarted) return;
    _bgmStarted = true;
    SoundService.instance.startTimerBgm();
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    _ensureBgm(); // 最初のキーで自動再生制限を解除しつつBGM開始

    // キー別の割当音（未割当は既定の timer_key 音）
    SoundService.instance
        .playTimerKey(KeySoundMap.normalize(event.logicalKey));

    // スペース/Enter で開始・停止をトグル、R でリセット
    if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      _toggle();
    } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
      _reset();
    }
  }

  void _toggle() {
    if (_finished) {
      _reset();
      return;
    }
    setState(() => _running = !_running);
    _tick?.cancel();
    if (_running) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _remaining--;
          if (_remaining <= 0) {
            _remaining = 0;
            _running = false;
            _finished = true;
            _tick?.cancel();
          }
        });
      });
    }
  }

  void _reset() {
    _tick?.cancel();
    setState(() {
      _remaining = _cfg.durationSec;
      _running = false;
      _finished = false;
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _flickerTimer?.cancel();
    _flame.dispose();
    _focus.dispose();
    SoundService.instance.stopTimerBgm();
    super.dispose();
  }

  String get _bgUrl =>
      _cfg.bgImage.isNotEmpty ? _cfg.bgImage : '/images/timer_bg.jpg';

  @override
  Widget build(BuildContext context) {
    final danger = _remaining <= 30 && !_finished;

    return KeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: GestureDetector(
        // タップでもキー音+BGM解錠（スマホ用）
        onTap: () {
          _ensureBgm();
          SoundService.instance.playTimerKey(); // タップは既定音
          _focus.requestFocus();
        },
        onDoubleTap: _toggle,
        onLongPress: _reset,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ---- 廃校背景 ----
              AnimatedOpacity(
                opacity: _flickerLevel,
                duration: const Duration(milliseconds: 60),
                child: Image.network(
                  _bgUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: const Color(0xFF0A0D0C)),
                ),
              ),
              // ---- 暗幕（文字を読ませる） ----
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Colors.black.withValues(alpha: danger ? 0.42 : 0.5),
                      Colors.black.withValues(alpha: 0.86),
                    ],
                  ),
                ),
              ),
              // ---- 残り僅かで滲む血の色 ----
              if (danger)
                IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.4,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF5A0000).withValues(
                              alpha: 0.25 +
                                  0.2 * (1 - _remaining / 30).clamp(0, 1)),
                        ],
                      ),
                    ),
                  ),
                ),
              // ---- 本体 ----
              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 28),
                    // タイトル
                    Text(
                      _cfg.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        letterSpacing: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF9FB0A6)
                            .withValues(alpha: _flickerLevel),
                        shadows: const [
                          Shadow(
                              color: Color(0xAA000000),
                              blurRadius: 18,
                              offset: Offset(0, 4)),
                          Shadow(color: Color(0x5538FF66), blurRadius: 30),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _cfg.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        letterSpacing: 4,
                        color: const Color(0xFF6E7D74)
                            .withValues(alpha: 0.9 * _flickerLevel),
                      ),
                    ),
                    const Spacer(),
                    // ---- 残り時間: 儀式の蝋燭 ----
                    if (_finished) _deadDisplay() else _candles(danger),
                    const Spacer(),
                    // 操作ヒント
                    Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: Text(
                        'SPACE / ダブルタップ : ${_running ? "停止" : "開始"}　　'
                        'R / 長押し : リセット',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 2,
                          color: const Color(0xFF4E5B54)
                              .withValues(alpha: 0.8 * _flickerLevel),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ---- ビネット ----
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.65),
                      ],
                      stops: const [0, 0.2, 0.8, 1],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 数字を使わない残り時間表示。
  /// 13本の儀式の蝋燭が左から順に燃え尽き、消えた蝋燭からは
  /// 煙が立ちのぼる。残り僅かで炎が血の色に変わる。
  Widget _candles(bool danger) {
    final progress =
        _cfg.durationSec <= 0 ? 0.0 : _remaining / _cfg.durationSec;
    return Column(
      children: [
        AnimatedBuilder(
          animation: _flame,
          builder: (context, _) => TimerCandles(
            progress: progress,
            flicker: _flickerLevel,
            flame: _flame.value,
            danger: danger,
            finished: _finished,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _running
              ? (danger ? '― 灯が、残りわずか ―' : '― 灯が消えてゆく ―')
              : '― 灯は静止している ―',
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 6,
            color: (danger
                    ? const Color(0xFF8A3A3A)
                    : const Color(0xFF5E6E64))
                .withValues(alpha: 0.9 * _flickerLevel),
          ),
        ),
      ],
    );
  }

  Widget _deadDisplay() {
    return Column(
      children: [
        Text(
          '刻限',
          style: TextStyle(
            fontSize: 96,
            fontWeight: FontWeight.w800,
            letterSpacing: 20,
            color: const Color(0xFF8B0000).withValues(alpha: _flickerLevel),
            shadows: const [
              Shadow(color: Color(0xFF5A0000), blurRadius: 60),
              Shadow(color: Color(0xCC000000), blurRadius: 10),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'もう、逃げられない',
          style: TextStyle(
            fontSize: 16,
            letterSpacing: 10,
            color: Color(0xFF7A2430),
            shadows: [Shadow(color: Color(0xFF3D0813), blurRadius: 14)],
          ),
        ),
      ],
    );
  }
}
