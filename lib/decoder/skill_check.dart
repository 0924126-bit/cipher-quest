import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_theme.dart';

/// Identity V style skill check.
///
/// While the player is holding the machine, a circular QTE randomly pops
/// up: a needle sweeps around a circle once, and the player must tap while
/// the needle is inside the highlighted success zone. The whole thing lives
/// INSIDE the hold interaction - no separate button, no separate screen,
/// exactly like the original game.
///
/// Difficulty (set by operators, 1..5) controls needle speed and zone size.
class SkillCheckParams {
  final double sweepDurationMs; // time for one full needle revolution
  final double zoneSweepDeg; // success zone arc size in degrees
  final double perfectSweepDeg; // perfect sub-zone arc in degrees

  const SkillCheckParams({
    required this.sweepDurationMs,
    required this.zoneSweepDeg,
    required this.perfectSweepDeg,
  });

  /// Difficulty presets 1 (easy) .. 5 (hell).
  factory SkillCheckParams.forDifficulty(int difficulty) {
    switch (difficulty.clamp(1, 5)) {
      case 1:
        return const SkillCheckParams(
            sweepDurationMs: 2200, zoneSweepDeg: 75, perfectSweepDeg: 26);
      case 2:
        return const SkillCheckParams(
            sweepDurationMs: 1800, zoneSweepDeg: 60, perfectSweepDeg: 20);
      case 3:
        return const SkillCheckParams(
            sweepDurationMs: 1450, zoneSweepDeg: 48, perfectSweepDeg: 16);
      case 4:
        return const SkillCheckParams(
            sweepDurationMs: 1150, zoneSweepDeg: 38, perfectSweepDeg: 12);
      default: // 5
        return const SkillCheckParams(
            sweepDurationMs: 900, zoneSweepDeg: 30, perfectSweepDeg: 10);
    }
  }
}

/// Result of one skill check.
enum SkillCheckResult { perfect, good, miss }

/// State for a single active skill check (created per pop-up).
class SkillCheckState {
  final SkillCheckParams params;

  /// Success zone start angle in degrees (0 = top, clockwise).
  /// Placed in the later part of the sweep so players have reaction time.
  final double zoneStartDeg;

  SkillCheckState(this.params, math.Random rng)
      : zoneStartDeg =
            120 + rng.nextDouble() * (330 - params.zoneSweepDeg - 120);

  double get zoneEndDeg => zoneStartDeg + params.zoneSweepDeg;
  double get perfectStartDeg =>
      zoneStartDeg + (params.zoneSweepDeg - params.perfectSweepDeg) / 2;
  double get perfectEndDeg => perfectStartDeg + params.perfectSweepDeg;

  /// Judge a tap at sweep progress t (0..1 -> 0..360 deg).
  SkillCheckResult judge(double t) {
    final deg = t * 360.0;
    if (deg >= perfectStartDeg && deg <= perfectEndDeg) {
      return SkillCheckResult.perfect;
    }
    if (deg >= zoneStartDeg && deg <= zoneEndDeg) {
      return SkillCheckResult.good;
    }
    return SkillCheckResult.miss;
  }
}

/// The visual skill check widget: a circular gauge with a sweeping needle.
/// Reports completion via [onResult]. The tap itself is forwarded by the
/// parent (the machine hold gesture) through the [SkillCheckOverlayState.tap]
/// method, so the player never leaves the hold interaction.
class SkillCheckOverlay extends StatefulWidget {
  final SkillCheckState check;
  final ValueChanged<SkillCheckResult> onResult;

  const SkillCheckOverlay({
    super.key,
    required this.check,
    required this.onResult,
  });

  @override
  State<SkillCheckOverlay> createState() => SkillCheckOverlayState();
}

class SkillCheckOverlayState extends State<SkillCheckOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0; // sweep progress 0..1
  bool _done = false;
  SkillCheckResult? _flashResult;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_done) return;
    final t = elapsed.inMilliseconds / widget.check.params.sweepDurationMs;
    if (t >= 1.0) {
      // needle completed the sweep without a tap -> miss
      _finish(SkillCheckResult.miss);
      return;
    }
    setState(() => _t = t);
  }

  /// Called by the parent when the player taps during this skill check.
  void tap() {
    if (_done) return;
    _finish(widget.check.judge(_t));
  }

  void _finish(SkillCheckResult r) {
    if (_done) return;
    _done = true;
    _ticker.stop();
    setState(() => _flashResult = r);
    // brief result flash, then report
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) widget.onResult(r);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = (MediaQuery.of(context).size.shortestSide * 0.42)
        .clamp(150.0, 240.0);
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _SkillCheckPainter(
              check: widget.check,
              t: _t,
              flashResult: _flashResult,
            ),
          ),
        ),
      ),
    );
  }
}

class _SkillCheckPainter extends CustomPainter {
  final SkillCheckState check;
  final double t;
  final SkillCheckResult? flashResult;

  _SkillCheckPainter({
    required this.check,
    required this.t,
    required this.flashResult,
  });

  static const _topOffset = -math.pi / 2; // 0 deg = top of circle

  double _rad(double deg) => _topOffset + deg * math.pi / 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - 8;

    // dark backdrop disc so the QTE reads on any background
    canvas.drawCircle(
      c,
      r + 8,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    // base ring
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = Colors.white.withValues(alpha: 0.22);
    canvas.drawCircle(c, r, ring);

    // success zone arc (good = white, perfect = amber inside it)
    final zone = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      _rad(check.zoneStartDeg),
      check.params.zoneSweepDeg * math.pi / 180.0,
      false,
      zone,
    );
    final perfect = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = AppColors.amber;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      _rad(check.perfectStartDeg),
      check.params.perfectSweepDeg * math.pi / 180.0,
      false,
      perfect,
    );

    // sweeping needle
    final needleAngle = _rad(t * 360.0);
    final needleEnd = Offset(
      c.dx + (r + 4) * math.cos(needleAngle),
      c.dy + (r + 4) * math.sin(needleAngle),
    );
    final needleStart = Offset(
      c.dx + (r - 22) * math.cos(needleAngle),
      c.dy + (r - 22) * math.sin(needleAngle),
    );
    canvas.drawLine(
      needleStart,
      needleEnd,
      Paint()
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..color = AppColors.blood
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2),
    );

    // center dot
    canvas.drawCircle(
        c, 5, Paint()..color = Colors.white.withValues(alpha: 0.85));

    // result flash
    if (flashResult != null) {
      final (label, color) = switch (flashResult!) {
        SkillCheckResult.perfect => ('PERFECT', AppColors.amber),
        SkillCheckResult.good => ('GOOD', Colors.white),
        SkillCheckResult.miss => ('MISS', AppColors.blood),
      };
      canvas.drawCircle(
        c,
        r + 8,
        Paint()..color = color.withValues(alpha: 0.18),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: color,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
            shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _SkillCheckPainter old) =>
      old.t != t || old.flashResult != flashResult;
}
