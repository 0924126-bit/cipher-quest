import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/machine.dart';
import '../services/socket_service.dart';
import '../services/sound_service.dart';
import 'skill_check.dart';

/// Connection phase of the decoder page.
enum DecoderPhase { connecting, ready, locked, notFound, deleted }

/// Decoding logic, separated from UI.
///
/// Interaction (Identity V style):
/// - hold the machine => progress advances (speed set live by operators)
/// - while holding, skill checks randomly pop up; tap in the zone to
///   succeed (+bonus%), miss and progress is pushed back (-penalty%)
class DecoderController extends ChangeNotifier {
  final String machineId;

  Machine? machine;
  DecoderPhase phase = DecoderPhase.connecting;
  String? errorReason;

  // --- decode state ---
  double progress = 0; // 0..100
  bool holding = false;
  bool get completed => progress >= 100;

  // --- skill check (QTE while holding) ---
  SkillCheckState? skillCheck;
  int skillCheckNonce = 0; // forces a fresh overlay widget per check
  bool get skillCheckActive => skillCheck != null;
  final math.Random _rng = math.Random();
  Timer? _skillTimer;

  SocketService? _socket;
  StreamSubscription? _msgSub;
  Timer? _ticker;

  DateTime _lastTick = DateTime.now();
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  DecoderController(this.machineId);

  double get durationSec =>
      (machine?.durationSec ?? 60).clamp(5, 3600).toDouble();

  /// Operator-controlled decode speed multiplier (0.1 .. 3.0).
  double get speedMultiplier =>
      (machine?.speedMultiplier ?? 1.0).clamp(0.1, 3.0);

  /// Progress gained per second while holding.
  double get _ratePerSec => 100.0 / durationSec * speedMultiplier;

  // ------------------------------------------------------------------
  // lifecycle
  // ------------------------------------------------------------------
  void connect() {
    phase = DecoderPhase.connecting;
    notifyListeners();
    _socket = SocketService('/ws/machine/$machineId');
    _msgSub = _socket!.messages.listen(_onMessage);
    _socket!.connect();
  }

  void _onMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'init':
        machine = Machine.fromJson(msg['machine'] as Map<String, dynamic>);
        progress = machine!.progress;
        phase = DecoderPhase.ready;
        SoundService.instance
            .updateSources(msg['sounds'] as Map<String, dynamic>?);
        _startTicker();
        notifyListeners();
        break;
      case 'settings':
        // live settings update (name / duration / design / speed / rhythm)
        machine = Machine.fromJson(msg['machine'] as Map<String, dynamic>);
        notifyListeners();
        break;
      case 'sounds':
        // operator changed sound assignments
        SoundService.instance
            .updateSources(msg['roles'] as Map<String, dynamic>?);
        notifyListeners();
        break;
      case 'reset':
        progress = 0;
        holding = false;
        skillCheck = null;
        _skillTimer?.cancel();
        _sendProgress('idle');
        notifyListeners();
        break;
      case 'deleted':
        phase = DecoderPhase.deleted;
        _stopAll();
        notifyListeners();
        break;
      case 'error':
        final reason = msg['reason'] as String?;
        if (reason == 'locked') {
          phase = DecoderPhase.locked;
        } else if (reason == 'not_found') {
          phase = DecoderPhase.notFound;
        }
        errorReason = reason;
        _stopAll();
        notifyListeners();
        break;
    }
  }

  // ------------------------------------------------------------------
  // hold to decode
  // ------------------------------------------------------------------
  void startHold() {
    if (phase != DecoderPhase.ready || completed) return;
    holding = true;
    _lastTick = DateTime.now();
    SoundService.instance.startDecodeLoop();
    _scheduleSkillCheck();
    notifyListeners();
  }

  void endHold() {
    if (!holding) return;
    holding = false;
    _skillTimer?.cancel();
    SoundService.instance.stopDecodeLoop();
    _sendProgress(completed ? 'completed' : 'paused');
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // skill check (Identity V style QTE)
  // ------------------------------------------------------------------

  /// Schedule the next random skill check while holding.
  void _scheduleSkillCheck() {
    _skillTimer?.cancel();
    if (!(machine?.skillEnabled ?? false)) return;
    // random 3.5 - 8.5s until the next check pops up
    final delayMs = 3500 + _rng.nextInt(5000);
    _skillTimer = Timer(Duration(milliseconds: delayMs), _triggerSkillCheck);
  }

  void _triggerSkillCheck() {
    if (!holding || completed || skillCheckActive) {
      // not decoding right now -> try again later if still holding
      if (holding) _scheduleSkillCheck();
      return;
    }
    final difficulty = machine?.skillDifficulty ?? 2;
    skillCheck =
        SkillCheckState(SkillCheckParams.forDifficulty(difficulty), _rng);
    skillCheckNonce++;
    SoundService.instance.playSkillWarn();
    notifyListeners();
  }

  /// Apply the QTE result: success => +bonus%, miss => -penalty%.
  void onSkillCheckResult(SkillCheckResult result) {
    skillCheck = null;
    final m = machine;
    final success = result != SkillCheckResult.miss;
    // perfect gives the full bonus, good gives half
    final bonus = m?.skillSuccessBonus ?? 5.0;
    final penalty = m?.skillFailPenalty ?? 2.0;
    if (result == SkillCheckResult.perfect) {
      progress = (progress + bonus).clamp(0, 100);
    } else if (result == SkillCheckResult.good) {
      progress = (progress + bonus / 2).clamp(0, 100);
    } else {
      progress = (progress - penalty).clamp(0, 100);
    }
    SoundService.instance.playSkillResult(success);
    _socket?.send({'type': 'skill', 'success': success});
    if (completed) {
      progress = 100;
      holding = false;
      _skillTimer?.cancel();
      SoundService.instance.stopDecodeLoop();
      SoundService.instance.playComplete();
      _sendProgress('completed');
    } else {
      _throttledSend(force: true);
      if (holding) _scheduleSkillCheck();
    }
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _lastTick = DateTime.now();
    _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
  }

  void _tick() {
    if (!holding || completed) return;

    final now = DateTime.now();
    final dt = now.difference(_lastTick).inMilliseconds / 1000.0;
    _lastTick = now;

    progress = (progress + _ratePerSec * dt).clamp(0, 100);
    if (completed) {
      progress = 100;
      holding = false;
      SoundService.instance.stopDecodeLoop();
      SoundService.instance.playComplete();
      _sendProgress('completed');
    } else {
      _throttledSend();
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // networking
  // ------------------------------------------------------------------
  void _throttledSend({bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_lastSent).inMilliseconds < 200) return;
    _lastSent = now;
    _sendProgress(holding ? 'decoding' : 'paused');
  }

  void _sendProgress(String status) {
    _socket?.send({
      'type': 'progress',
      'progress': double.parse(progress.toStringAsFixed(2)),
      'status': status,
    });
  }

  void _stopAll() {
    _ticker?.cancel();
    _skillTimer?.cancel();
    holding = false;
    skillCheck = null;
    SoundService.instance.stopAll();
  }

  @override
  void dispose() {
    _stopAll();
    _msgSub?.cancel();
    _socket?.dispose();
    super.dispose();
  }
}
