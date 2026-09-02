import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/role_config.dart';
import '../services/alarm_service.dart';
import '../services/api_service.dart';
import '../services/key_sound_map.dart';
import '../services/socket_service.dart';
import '../services/sound_service.dart';
import 'widgets/timer_candles.dart';
import 'widgets/timer_faces.dart';

/// 廃校ホラータイマー。
///
/// - 残り時間: ダッシュボードで選べる5デザイン
///   (儀式の蝋燭 / 数字 / 血月蝕 / 血の砂時計 / 心電図)
/// - 背景: ダッシュボードから差し替え可能な廃校画像（初期は内蔵の廃校廊下）
/// - BGM: ループ再生（初期は合成ホラードローン、ダッシュボードでmp3差替可）
/// - キー音: キーごとにダッシュボードで割り当てた音を再生（未割当は既定音）
/// - 呪い: 呪術師がボタンを押すと /ws/hunter 経由で受信し、
///   この画面から自動で3秒間の緊張音（上昇パルス+ドローン+鼓動）を鳴らす
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

  // 呪い発動の受信（/ws/hunter に乗り合い）→ 3秒の緊張音を自動再生
  SocketService? _curseSocket;
  StreamSubscription? _curseSub;

  @override
  void initState() {
    super.initState();
    _flame = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _scheduleFlicker();
    // 初回だけHTTPで即時表示（WS接続前でも設定・音が揃う）。
    _load();
    _loadSounds();
    // 以降の設定変更・全体リセット・キー音割当は /ws/hunter の
    // プッシュ（init/roles/sounds）で反映。ポーリングは行わない
    // （Cloudflare無料枠のリクエスト数節約）。
    _connectCurseFeed();
  }

  /// /ws/hunter に乗り合いして、呪い発動・設定変更・音割当変更を
  /// すべてプッシュで受け取る（HTTPポーリング廃止）。
  /// init メッセージの recent_curses(過去履歴) では鳴らさず、
  /// 接続中に届いた 'curse' イベントだけで鳴らす。
  void _connectCurseFeed() {
    final s = SocketService('/ws/hunter', autoReconnect: true);
    _curseSocket = s;
    _curseSub = s.messages.listen((msg) {
      switch (msg['type']) {
        case 'curse':
          // ダッシュボードで割り当てたmp3があればそれを、
          // なければ内蔵の合成緊張音（3秒）を鳴らす。
          if (!SoundService.instance.playCurseCustom()) {
            AlarmService.instance.playCurseAlarm();
          }
          AlarmService.instance.vibrate();
          break;
        case 'init':
          // 接続/再接続のたびに最新設定・音マップが届く
          _applyRoles(msg['roles']);
          _applySoundMaps(msg['sounds'], msg['keys'], msg['fx']);
          break;
        case 'roles':
          _applyRoles(msg['roles']);
          break;
        case 'sounds':
          // sounds ブロードキャストは音URLマップを 'roles' キーで運ぶ
          _applySoundMaps(msg['roles'], msg['keys'], msg['fx']);
          break;
      }
    });
    s.connect();
  }

  /// WSで届いた RoleConfig を反映（_load と同じ規則）。
  void _applyRoles(dynamic raw) {
    if (raw is! Map<String, dynamic>) return;
    if (!mounted) return;
    final cfg = RoleConfig.fromJson(raw).timer;
    final prevResetAt = _cfg.resetAt;
    setState(() {
      _cfg = cfg;
      if (!_running && !_finished) _remaining = _cfg.durationSec;
    });
    // ダッシュボードの全体リセットを検知したらタイマーもリセット
    if (prevResetAt != 0 && _cfg.resetAt > prevResetAt) {
      _reset();
    }
  }

  /// WSで届いた音マップを反映（_loadSounds と同じ規則）。
  void _applySoundMaps(dynamic roleMap, dynamic keyMap, dynamic fxMap) {
    if (roleMap is! Map<String, dynamic>) return;
    SoundService.instance.updateSources({
      'timer_bgm':
          (roleMap['timer_bgm'] as String?) ?? '/audio/timer_bgm.mp3',
      'timer_key':
          (roleMap['timer_key'] as String?) ?? '/audio/timer_key.mp3',
      'curse': roleMap['curse'], // null=合成音フォールバック
    });
    if (keyMap is Map<String, dynamic>) {
      SoundService.instance.updateKeySounds(keyMap);
    }
    if (fxMap is Map<String, dynamic>) {
      SoundService.instance.updateFx(fxMap);
    }
  }

  Future<void> _load() async {
    try {
      final roles = await ApiService.instance.getRoles();
      if (!mounted) return;
      final prevResetAt = _cfg.resetAt;
      setState(() {
        _cfg = roles.timer;
        if (!_running && !_finished) _remaining = _cfg.durationSec;
      });
      // ダッシュボードの全体リセットを検知したらタイマーもリセット
      if (prevResetAt != 0 && _cfg.resetAt > prevResetAt) {
        _reset();
      }
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
        'curse': data.roleMap['curse'], // null=合成音フォールバック
      });
      SoundService.instance.updateKeySounds(data.keyMap);
      SoundService.instance.updateFx({
        for (final e in data.fxMap.entries)
          e.key: {
            'volume': e.value.volume,
            'distortion': e.value.distortion,
            'rate': e.value.rate,
          },
      });
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
    _curseSub?.cancel();
    _curseSocket?.dispose();
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
              // ---- 本体: 選択中のデザインだけのシンプル構成 ----
              SafeArea(
                child: Center(child: _face(danger)),
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

  /// 選択中のデザインで残り時間を描画する。
  /// ダッシュボードの「タイマーデザイン」設定 (_cfg.style) で切替。
  Widget _face(bool danger) {
    final progress =
        _cfg.durationSec <= 0 ? 0.0 : _remaining / _cfg.durationSec;
    return AnimatedBuilder(
      animation: _flame,
      builder: (context, _) {
        switch (_cfg.style) {
          case 'digits':
            return TimerDigits(
              remaining: _remaining,
              flicker: _flickerLevel,
              danger: danger,
              finished: _finished,
            );
          case 'bloodmoon':
            return TimerBloodMoon(
              progress: progress,
              flicker: _flickerLevel,
              flame: _flame.value,
              danger: danger,
              finished: _finished,
            );
          case 'hourglass':
            return TimerHourglass(
              progress: progress,
              flicker: _flickerLevel,
              flame: _flame.value,
              danger: danger,
              finished: _finished,
            );
          case 'heartbeat':
            return TimerHeartbeat(
              progress: progress,
              flicker: _flickerLevel,
              flame: _flame.value,
              danger: danger,
              finished: _finished,
            );
          case 'candles':
          default:
            return TimerCandles(
              progress: progress,
              flicker: _flickerLevel,
              flame: _flame.value,
              danger: danger,
              finished: _finished,
            );
        }
      },
    );
  }
}
