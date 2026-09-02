import 'sound_service_stub.dart'
    if (dart.library.js_interop) 'sound_service_web.dart';

/// App-wide sound player fed by the server's role->url map.
///
/// Every role has a built-in default (shipped at /audio/*.mp3); operators
/// can override each one with an uploaded mp3 and revert at any time.
/// Roles:
///   decode        - loop while holding the machine
///   complete      - one-shot on 100%
///   skill_warn    - short cue when a skill check appears
///   skill_success - one-shot on skill check success
///   skill_fail    - one-shot on skill check miss
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final SoundBackend _backend = SoundBackend();

  /// Per-key sound bindings for the horror timer (server keymap:
  /// normalized key name -> mp3 url). Empty when nothing is bound.
  Map<String, String> _keySounds = const {};

  /// Update role -> url assignments from a server payload.
  void updateSources(Map<String, dynamic>? roles) {
    if (roles == null) return;
    for (final role in const [
      'decode',
      'complete',
      'skill_warn',
      'skill_success',
      'skill_fail',
      'timer_bgm',
      'timer_key',
      'curse',
    ]) {
      final v = roles[role];
      if (!roles.containsKey(role)) continue; // 部分更新を許容
      _backend.setSource(role, v is String && v.isNotEmpty ? v : null);
    }
  }

  bool has(String role) => _backend.hasSource(role);

  /// Apply live audio FX from a server payload
  /// (role -> {volume, distortion, rate}); mid-playback boost included.
  void updateFx(Map<String, dynamic>? fx) {
    if (fx == null) return;
    for (final e in fx.entries) {
      final v = e.value;
      if (v is! Map) continue;
      _backend.setFx(
        e.key,
        volume: ((v['volume'] as num?)?.toDouble() ?? 100) / 100.0,
        distortion: ((v['distortion'] as num?)?.toDouble() ?? 0) / 100.0,
        rate: (v['rate'] as num?)?.toDouble() ?? 1.0,
      );
    }
  }

  void startDecodeLoop() => _backend.play('decode', loop: true);
  void stopDecodeLoop() => _backend.stop('decode');

  void playComplete() {
    _backend.stop('decode');
    _backend.play('complete');
  }

  void playSkillWarn() => _backend.play('skill_warn');

  void playSkillResult(bool success) =>
      _backend.play(success ? 'skill_success' : 'skill_fail');

  // ---- horror timer ----
  void startTimerBgm() => _backend.play('timer_bgm', loop: true);
  void stopTimerBgm() => _backend.stop('timer_bgm');

  /// Replace the per-key bindings (from /api/sounds `keys` or the
  /// websocket `sounds` push).
  void updateKeySounds(Map<String, dynamic>? keys) {
    if (keys == null) return;
    _keySounds = {
      for (final e in keys.entries)
        if (e.value is String && (e.value as String).isNotEmpty)
          e.key: e.value as String,
    };
  }

  /// タイマーのキー音。キー別の割当があればそれを、
  /// なければ既定の timer_key 音を連打対応で鳴らす。
  /// [key] は KeySoundMap.normalize 済みのキー名(null=タップなど)。
  void playTimerKey([String? key]) {
    final url = key == null ? null : _keySounds[key];
    if (url != null) {
      _backend.playOneShotUrl(url);
    } else {
      _backend.playOneShot('timer_key');
    }
  }

  void stopAll() => _backend.stopAll();
}
