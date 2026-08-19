import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/machine.dart';
import '../services/socket_service.dart';
import '../services/sound_service.dart';

/// Connection phase of the decoder page.
enum DecoderPhase { connecting, ready, locked, notFound, deleted }

/// Decoding logic, separated from UI.
///
/// Interaction:
/// - hold the machine => progress advances (speed set live by operators)
/// - optional rhythm mini-game => success/fail nudges progress
class DecoderController extends ChangeNotifier {
  final String machineId;

  Machine? machine;
  DecoderPhase phase = DecoderPhase.connecting;
  String? errorReason;

  // --- decode state ---
  double progress = 0; // 0..100
  bool holding = false;
  bool get completed => progress >= 100;

  // --- rhythm mini-game ---
  bool rhythmOpen = false;
  bool get rhythmAvailable =>
      (machine?.rhythmEnabled ?? false) && !completed && !rhythmOpen;

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
    if (phase != DecoderPhase.ready || completed || rhythmOpen) return;
    holding = true;
    _lastTick = DateTime.now();
    SoundService.instance.startDecodeLoop();
    notifyListeners();
  }

  void endHold() {
    if (!holding) return;
    holding = false;
    SoundService.instance.stopDecodeLoop();
    _sendProgress(completed ? 'completed' : 'paused');
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // rhythm mini-game
  // ------------------------------------------------------------------
  void openRhythm() {
    if (!rhythmAvailable || phase != DecoderPhase.ready) return;
    endHold();
    rhythmOpen = true;
    notifyListeners();
  }

  /// Apply the mini-game result: success => +bonus%, fail => -penalty%.
  void finishRhythm(bool success) {
    rhythmOpen = false;
    final m = machine;
    final bonus = m?.rhythmSuccessBonus ?? 5.0;
    final penalty = m?.rhythmFailPenalty ?? 2.0;
    if (success) {
      progress = (progress + bonus).clamp(0, 100);
    } else {
      progress = (progress - penalty).clamp(0, 100);
    }
    _socket?.send({'type': 'skill', 'success': success});
    if (completed) {
      progress = 100;
      SoundService.instance.playComplete();
      _sendProgress('completed');
    } else {
      _sendProgress('paused');
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
    holding = false;
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
