import 'alarm_service_stub.dart'
    if (dart.library.js_interop) 'alarm_service_web.dart';

/// Synthesized alarm & curse sounds (no audio files needed).
///
/// Used by:
/// - Chaser page  : security-buzzer siren for N seconds
/// - Cursed page  : deep rumble on press
/// - Hunter page  : curse notification sting + vibration
/// - Dashboard    : curse notification sting
class AlarmService {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  final AlarmBackend _backend = AlarmBackend();

  /// Force early construction so the mobile audio-unlock gesture
  /// listeners are installed from app startup (call from main()).
  void init() {}

  /// Start the two-tone siren (call [stopSiren] to end).
  void startSiren() => _backend.startSiren();

  void stopSiren() => _backend.stopSiren();

  /// Ominous notification sting for curse events.
  void playCurseSting() => _backend.playCurseSting();

  /// 3-second continuous tension alarm, auto-played on the timer screen
  /// when the cursed role fires a curse (rising pulses + drone + heartbeat).
  void playCurseAlarm() => _backend.playCurseAlarm();

  /// Sub-bass rumble feedback when the curse button is pressed.
  void playCursePress() => _backend.playCursePress();

  /// Vibrate the device if supported (mobile browsers).
  void vibrate() => _backend.vibrate();
}
