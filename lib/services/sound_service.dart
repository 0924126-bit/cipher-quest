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

  /// Update role -> url assignments from a server payload.
  void updateSources(Map<String, dynamic>? roles) {
    if (roles == null) return;
    for (final role in const [
      'decode',
      'complete',
      'skill_warn',
      'skill_success',
      'skill_fail',
    ]) {
      final v = roles[role];
      _backend.setSource(role, v is String && v.isNotEmpty ? v : null);
    }
  }

  bool has(String role) => _backend.hasSource(role);

  void startDecodeLoop() => _backend.play('decode', loop: true);
  void stopDecodeLoop() => _backend.stop('decode');

  void playComplete() {
    _backend.stop('decode');
    _backend.play('complete');
  }

  void playSkillWarn() => _backend.play('skill_warn');

  void playSkillResult(bool success) =>
      _backend.play(success ? 'skill_success' : 'skill_fail');

  void stopAll() => _backend.stopAll();
}
