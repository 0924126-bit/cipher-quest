/// Role page configuration (chaser / cursed / hunter).
///
/// Mirrors server/roles.py. Editable live from the operator dashboard.
class ChaserConfig {
  final String title;
  final String subtitle;
  final int alarmSec;

  const ChaserConfig({
    this.title = 'あなたはチェイサーです',
    this.subtitle = 'ボタンを押すと大音量の警報が鳴り響く',
    this.alarmSec = 30,
  });

  factory ChaserConfig.fromJson(Map<String, dynamic> json) => ChaserConfig(
        title: (json['title'] as String?) ?? 'あなたはチェイサーです',
        subtitle: (json['subtitle'] as String?) ?? '',
        alarmSec: (json['alarm_sec'] as num?)?.toInt() ?? 30,
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

class RoleConfig {
  final ChaserConfig chaser;
  final CursedConfig cursed;
  final HunterConfig hunter;

  const RoleConfig({
    this.chaser = const ChaserConfig(),
    this.cursed = const CursedConfig(),
    this.hunter = const HunterConfig(),
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
