import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/sound_service.dart';
import '../theme/app_theme.dart';

/// Result returned when the rhythm mini-game closes.
class RhythmResult {
  final bool success;
  final int hits;
  final int total;
  const RhythmResult({
    required this.success,
    required this.hits,
    required this.total,
  });
}

/// Easy one-lane rhythm mini-game overlay.
///
/// Notes fall down a single lane; the player taps anywhere when a note
/// is inside the judgement ring. Hit 6 of 8 notes to succeed.
/// Tuned to be beginner friendly: slow fall, wide hit window.
class RhythmGameOverlay extends StatefulWidget {
  final double successBonus;
  final double failPenalty;
  final ValueChanged<RhythmResult> onFinished;

  const RhythmGameOverlay({
    super.key,
    required this.successBonus,
    required this.failPenalty,
    required this.onFinished,
  });

  @override
  State<RhythmGameOverlay> createState() => _RhythmGameOverlayState();
}

class _Note {
  /// Time (seconds since game start) the note should reach the ring.
  final double hitTime;
  bool judged = false;
  bool hit = false;
  _Note(this.hitTime);
}

enum _Phase { countdown, playing, result }

class _RhythmGameOverlayState extends State<RhythmGameOverlay>
    with SingleTickerProviderStateMixin {
  static const int noteCount = 8;
  static const int needHits = 6;

  /// Seconds a note takes to fall from top to the judgement ring.
  static const double fallTime = 2.2;

  /// +/- seconds around hitTime that counts as a hit (very forgiving).
  static const double hitWindow = 0.35;

  /// Seconds after hitTime where a tap is "late but judged" (miss).
  static const double missWindow = 0.55;

  late final Ticker _ticker;
  late final List<_Note> _notes;
  final math.Random _rng = math.Random();

  _Phase _phase = _Phase.countdown;
  double _t = 0; // seconds since game start (after countdown)
  int _countdown = 3;
  Timer? _countdownTimer;

  int _hits = 0;
  String _judgement = '';
  double _judgementAt = -10;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    // beat every 0.9s with tiny jitter => easy, readable pattern
    _notes = List.generate(noteCount, (i) {
      final jitter = (_rng.nextDouble() - 0.5) * 0.1;
      return _Note(1.5 + i * 0.9 + jitter);
    });
    _ticker = createTicker(_onTick);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          t.cancel();
          _phase = _Phase.playing;
          SoundService.instance.startRhythmBgm();
          _ticker.start();
        }
      });
    });
  }

  void _onTick(Duration elapsed) {
    _t = elapsed.inMicroseconds / 1e6;
    // auto-miss notes that scrolled past the window
    for (final n in _notes) {
      if (!n.judged && _t > n.hitTime + missWindow) {
        n.judged = true;
        _judgement = 'MISS';
        _judgementAt = _t;
      }
    }
    if (_notes.every((n) => n.judged)) {
      _finish();
      return;
    }
    if (mounted) setState(() {});
  }

  void _onTap() {
    if (_phase != _Phase.playing) return;
    // find nearest unjudged note within the miss window
    _Note? best;
    double bestDiff = double.infinity;
    for (final n in _notes) {
      if (n.judged) continue;
      final diff = (_t - n.hitTime).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = n;
      }
    }
    if (best == null || bestDiff > missWindow) return; // stray tap, ignore
    best.judged = true;
    if (bestDiff <= hitWindow) {
      best.hit = true;
      _hits++;
      _judgement = bestDiff <= hitWindow / 2 ? 'PERFECT' : 'GOOD';
    } else {
      _judgement = 'MISS';
    }
    _judgementAt = _t;
    if (_notes.every((n) => n.judged)) {
      _finish();
    } else {
      setState(() {});
    }
  }

  void _finish() {
    if (_phase == _Phase.result) return;
    _ticker.stop();
    _success = _hits >= needHits;
    SoundService.instance.playRhythmResult(_success);
    setState(() => _phase = _Phase.result);
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      widget.onFinished(
        RhythmResult(success: _success, hits: _hits, total: noteCount),
      );
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ticker.dispose();
    SoundService.instance.stopRhythmBgm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _onTap(),
        child: Container(
          color: AppColors.bgDeep.withValues(alpha: 0.92),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  '— リズム解読 —',
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 6,
                    color: AppColors.amber.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$needHits/$noteCount ヒットで成功　'
                  '成功 +${widget.successBonus.toStringAsFixed(1)}%　'
                  '失敗 -${widget.failPenalty.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    color: AppColors.boneDim,
                  ),
                ),
                const SizedBox(height: 8),
                _ScoreRow(hits: _hits, notes: _notes),
                Expanded(
                  child: switch (_phase) {
                    _Phase.countdown => Center(
                        child: Text(
                          '$_countdown',
                          style: const TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.w700,
                            color: AppColors.amber,
                          ),
                        ),
                      ),
                    _Phase.playing => CustomPaint(
                        painter: _LanePainter(
                          notes: _notes,
                          t: _t,
                          fallTime: fallTime,
                          judgement: _judgement,
                          judgementAge: _t - _judgementAt,
                        ),
                        size: Size.infinite,
                      ),
                    _Phase.result => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _success ? Icons.check_circle : Icons.cancel,
                              size: 64,
                              color:
                                  _success ? AppColors.lamp : AppColors.blood,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _success ? '解読成功！' : '解読失敗…',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 4,
                                color:
                                    _success ? AppColors.lamp : AppColors.blood,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$_hits / $noteCount ヒット　進捗 '
                              '${_success ? '+${widget.successBonus.toStringAsFixed(1)}' : '-${widget.failPenalty.toStringAsFixed(1)}'}%',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.bone,
                              ),
                            ),
                          ],
                        ),
                      ),
                  },
                ),
                if (_phase == _Phase.playing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(
                      'ノーツがリングに重なったら画面をタップ！',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 2,
                        color: AppColors.boneDim,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hit counter dots along the top.
class _ScoreRow extends StatelessWidget {
  final int hits;
  final List<_Note> notes;
  const _ScoreRow({required this.hits, required this.notes});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final n in notes)
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: !n.judged
                  ? AppColors.surface
                  : n.hit
                      ? AppColors.lamp
                      : AppColors.blood,
              border: Border.all(
                color: AppColors.amberDim,
                width: 1,
              ),
            ),
          ),
      ],
    );
  }
}

/// Paints the falling notes, judgement ring and judgement popup text.
class _LanePainter extends CustomPainter {
  final List<_Note> notes;
  final double t;
  final double fallTime;
  final String judgement;
  final double judgementAge;

  _LanePainter({
    required this.notes,
    required this.t,
    required this.fallTime,
    required this.judgement,
    required this.judgementAge,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final ringY = size.height * 0.82;
    final top = -30.0;

    // lane guide
    final lane = Paint()
      ..color = AppColors.amberDim.withValues(alpha: 0.25)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), lane);

    // judgement ring
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppColors.amber.withValues(alpha: 0.9);
    canvas.drawCircle(Offset(cx, ringY), 34, ring);
    final ringInner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.amber.withValues(alpha: 0.35);
    canvas.drawCircle(Offset(cx, ringY), 44, ringInner);

    // notes
    for (final n in notes) {
      if (n.judged && n.hit) continue; // consumed
      final progress = 1 - (n.hitTime - t) / fallTime; // 0 at top, 1 at ring
      if (progress < 0 || progress > 1.35) continue;
      final y = top + (ringY - top) * progress;
      final missed = n.judged && !n.hit;
      final glow = Paint()
        ..color = (missed ? AppColors.blood : AppColors.amber)
            .withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(Offset(cx, y), 26, glow);
      final body = Paint()
        ..color = missed
            ? AppColors.blood.withValues(alpha: 0.6)
            : AppColors.amber;
      canvas.drawCircle(Offset(cx, y), 20, body);
      final core = Paint()..color = AppColors.bgDeep;
      canvas.drawCircle(Offset(cx, y), 8, core);
    }

    // judgement popup (fades over 0.6s)
    if (judgement.isNotEmpty && judgementAge < 0.6) {
      final alpha = (1 - judgementAge / 0.6).clamp(0.0, 1.0);
      final color = judgement == 'MISS' ? AppColors.blood : AppColors.lamp;
      final tp = TextPainter(
        text: TextSpan(
          text: judgement,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
            color: color.withValues(alpha: alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(cx - tp.width / 2, ringY - 110 - judgementAge * 40),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LanePainter old) => true;
}
