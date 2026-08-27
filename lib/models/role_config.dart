/// Role page configuration (chaser / cursed / hunter).
///
/// Mirrors server/roles.py. Editable live from the operator dashboard.
class ChaserConfig {
  final String title;
  final String subtitle;
  final int alarmSec;

  /// 警報は1回限り。発動すると false になり、
  /// ダッシュボードで再許可（または全体リセット）するまで使えない。
  final bool alarmArmed;

  const ChaserConfig({
    this.title = 'あなたはチェイサーです',
    this.subtitle = 'ボタンを押すと大音量の警報が鳴り響く',
    this.alarmSec = 30,
    this.alarmArmed = true,
  });

  factory ChaserConfig.fromJson(Map<String, dynamic> json) => ChaserConfig(
        title: (json['title'] as String?) ?? 'あなたはチェイサーです',
        subtitle: (json['subtitle'] as String?) ?? '',
        alarmSec: (json['alarm_sec'] as num?)?.toInt() ?? 30,
        alarmArmed: (json['alarm_armed'] as bool?) ?? true,
      );
}

class CursedConfig {
  final String title;
  final String subtitle;
  final int cooldownSec;

  /// Uploaded button-face image URL ('' = built-in scary button).
  final String buttonImage;
  final String notifyMessage;

  const CursedConfig({
    this.title = 'あなたは呪術師です',
    this.subtitle = '呪いの刻印に触れよ…',
    this.cooldownSec = 30,
    this.buttonImage = '',
    this.notifyMessage = '呪術師が呪いを発動した！',
  });

  factory CursedConfig.fromJson(Map<String, dynamic> json) => CursedConfig(
        title: (json['title'] as String?) ?? 'あなたは呪術師です',
        subtitle: (json['subtitle'] as String?) ?? '',
        cooldownSec: (json['cooldown_sec'] as num?)?.toInt() ?? 30,
        buttonImage: (json['button_image'] as String?) ?? '',
        notifyMessage: (json['notify_message'] as String?) ?? '呪術師が呪いを発動した！',
      );
}

class HunterConfig {
  final String title;

  const HunterConfig({this.title = 'ハンター通知端末'});

  factory HunterConfig.fromJson(Map<String, dynamic> json) => HunterConfig(
        title: (json['title'] as String?) ?? 'ハンター通知端末',
      );
}

/// 廃校ホラータイマーの設定。
class TimerConfig {
  final String title;
  final String subtitle;
  final int durationSec;

  /// 背景画像URL ('' = 内蔵の廃校背景 /images/timer_bg.jpg)。
  final String bgImage;

  const TimerConfig({
    this.title = '償いの刻限',
    this.subtitle = '時間が尽きる前に…逃げられると思うな',
    this.durationSec = 300,
    this.bgImage = '',
  });

  factory TimerConfig.fromJson(Map<String, dynamic> json) => TimerConfig(
        title: (json['title'] as String?) ?? '償いの刻限',
        subtitle: (json['subtitle'] as String?) ?? '',
        durationSec: (json['duration_sec'] as num?)?.toInt() ?? 300,
        bgImage: (json['bg_image'] as String?) ?? '',
      );
}

class RoleConfig {
  final ChaserConfig chaser;
  final CursedConfig cursed;
  final HunterConfig hunter;
  final TimerConfig timer;

  const RoleConfig({
    this.chaser = const ChaserConfig(),
    this.cursed = const CursedConfig(),
    this.hunter = const HunterConfig(),
    this.timer = const TimerConfig(),
  });

  factory RoleConfig.fromJson(Map<String, dynamic> json) => RoleConfig(
        chaser: json['chaser'] is Map<String, dynamic>
            ? ChaserConfig.fromJson(json['chaser'] as Map<String, dynamic>)
            : const ChaserConfig(),
        cursed: json['cursed'] is Map<String, dynamic>
            ? CursedConfig.fromJson(json['cursed'] as Map<String, dynamic>)
            : const CursedConfig(),
        hunter: json['hunter'] is Map<String, dynamic>
            ? HunterConfig.fromJson(json['hunter'] as Map<String, dynamic>)
            : const HunterConfig(),
        timer: json['timer'] is Map<String, dynamic>
            ? TimerConfig.fromJson(json['timer'] as Map<String, dynamic>)
            : const TimerConfig(),
      );
}

/// One curse-button press event pushed over WebSocket.
class CurseEvent {
  final String id;
  final int atMs;
  final String message;

  const CurseEvent({required this.id, required this.atMs, required this.message});

  factory CurseEvent.fromJson(Map<String, dynamic> json) => CurseEvent(
        id: (json['id'] as String?) ?? '',
        atMs: (json['at'] as num?)?.toInt() ?? 0,
        message: (json['message'] as String?) ?? '呪いが発動した！',
      );
}
