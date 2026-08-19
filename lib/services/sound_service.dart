import 'sound_service_stub.dart'
    if (dart.library.js_interop) 'sound_service_web.dart';

/// App-wide sound player fed by operator-uploaded mp3 files.
///
/// The server pushes a role->url map ("sounds" websocket message /
/// init payload); we mirror it here and play by role name:
///   decode   - loop while holding the machine
///   complete - one-shot on 100%
///   rhythm   - mini-game BGM (loop)
///   success  - one-shot on rhythm success
///   fail     - one-shot on rhythm fail
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
      'rhythm',
      'success',
      'fail',
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

  void startRhythmBgm() => _backend.play('rhythm', loop: true);
  void stopRhythmBgm() => _backend.stop('rhythm');

  void playRhythmResult(bool success) {
    _backend.stop('rhythm');
    _backend.play(success ? 'success' : 'fail');
  }

  void stopAll() => _backend.stopAll();
}
