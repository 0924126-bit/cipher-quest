import 'dart:math';

import 'package:flutter/material.dart';

import 'painter_common.dart';

/// Steampunk gear engine:
/// an iron frame full of meshing bronze gears, a pressure gauge on top,
/// a steam pipe with a relief valve, and a piston rod at the bottom.
///
/// - idle      : gears still, gauge at current progress
/// - holding   : gears mesh and spin, piston pumps, steam puffs out
/// - completed : gauge pinned at max, green lamp
class GearworkPainter extends MachinePainter {
  GearworkPainter({
    required super.progress,
    required super.holding,
    required super.completed,
    required super.design,
    required super.t,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    paintGroundShadow(canvas, size, widthFactor: 0.7);

    _paintFrame(canvas, w, h);
    _paintSteamPipe(canvas, w, h);
    _paintGears(canvas, w, h);
    _paintPiston(canvas, w, h);
    _paintGauge(canvas, w, h);
    paintLamp(canvas, Offset(w * 0.73, h * 0.235), w * 0.015);
  }

  // ---------------------------------------------------------------- frame

  void _paintFrame(Canvas canvas, double w, double h) {
    // heavy iron A-frame with feet
    final frame = Rect.fromLTRB(w * 0.18, h * 0.28, w * 0.82, h * 0.90);
    final rr = RRect.fromRectAndRadius(frame, Radius.circular(w * 0.025));

    canvas.drawRRect(
      rr.shift(const Offset(2, 4)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(rr, bodyGradient(frame));

    // inner recess where the gears live
    final recess = frame.deflate(w * 0.035);
    canvas.drawRRect(
      RRect.fromRectAndRadius(recess, Radius.circular(w * 0.018)),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    // rivets around the frame edge
    final rivet = Paint()..color = design.accent.withValues(alpha: 0.75);
    final rivetDark = Paint()..color = Colors.black.withValues(alpha: 0.4);
    final rPos = <Offset>[];
    const perSide = 5;
    for (int i = 0; i < perSide; i++) {
      final fx = frame.left + frame.width * (i + 0.5) / perSide;
      rPos.add(Offset(fx, frame.top + w * 0.018));
      rPos.add(Offset(fx, frame.bottom - w * 0.018));
      final fy = frame.top + frame.height * (i + 0.5) / perSide;
      rPos.add(Offset(frame.left + w * 0.018, fy));
      rPos.add(Offset(frame.right - w * 0.018, fy));
    }
    for (final pos in rPos) {
      canvas.drawCircle(pos.translate(0.8, 1.0), w * 0.006, rivetDark);
      canvas.drawCircle(pos, w * 0.006, rivet);
    }

    // feet
    final foot = Paint()..color = design.baseDark;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.13, h * 0.90, w * 0.16, h * 0.06),
          const Radius.circular(3)),
      foot,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.71, h * 0.90, w * 0.16, h * 0.06),
          const Radius.circular(3)),
      foot,
    );
  }

  // ------------------------------------------------------------ steam pipe

  void _paintSteamPipe(Canvas canvas, double w, double h) {
    // vertical pipe on the left rising above the frame
    final pipe = Paint()
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round
      ..color = design.baseDark;
    canvas.drawLine(
        Offset(w * 0.245, h * 0.30), Offset(w * 0.245, h * 0.135), pipe);
    // pipe highlight
    canvas.drawLine(
      Offset(w * 0.239, h * 0.30),
      Offset(w * 0.239, h * 0.14),
      Paint()
        ..strokeWidth = w * 0.008
        ..strokeCap = StrokeCap.round
        ..color = design.baseLight.withValues(alpha: 0.6),
    );
    // flange rings
    final flange = Paint()..color = design.accent;
    for (final y in [h * 0.155, h * 0.27]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(w * 0.245, y),
                width: w * 0.055,
                height: h * 0.014),
            const Radius.circular(2)),
        flange,
      );
    }

    // steam puffs while holding
    if (holding) {
      final rnd = Random(5);
      for (int i = 0; i < 3; i++) {
        final phase = (t + i / 3) % 1.0;
        final cy = h * 0.125 - phase * h * 0.09;
        final cx = w * 0.245 + (rnd.nextDouble() - 0.3) * w * 0.03 * phase;
        canvas.drawCircle(
          Offset(cx, cy),
          w * (0.012 + 0.020 * phase),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.22 * (1 - phase))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    }
  }

  // ---------------------------------------------------------------- gears

  void _paintGears(Canvas canvas, double w, double h) {
    // meshing gear train inside the recess.
    // base angle advances while holding; direction alternates so the
    // teeth appear to mesh.
    final a = holding ? t * 2 * pi : p * 2 * pi;

    // big central gear
    paintGear(
      canvas,
      Offset(w * 0.44, h * 0.55),
      w * 0.135,
      teeth: 12,
      angle: a,
      spokes: 5,
    );
    // top-right medium gear (counter-rotating)
    paintGear(
      canvas,
      Offset(w * 0.635, h * 0.435),
      w * 0.088,
      teeth: 9,
      angle: -a * 12 / 9 + 0.22,
      color: design.baseLight,
      darkColor: design.baseDark,
      spokes: 4,
    );
    // bottom-right small gear
    paintGear(
      canvas,
      Offset(w * 0.645, h * 0.68),
      w * 0.062,
      teeth: 7,
      angle: a * 12 / 7 + 0.5,
      spokes: 3,
    );
    // small idler top-left
    paintGear(
      canvas,
      Offset(w * 0.295, h * 0.415),
      w * 0.048,
      teeth: 6,
      angle: -a * 12 / 6 - 0.3,
      color: design.baseLight,
      darkColor: design.baseDark,
      spokes: 3,
    );
  }

  // ---------------------------------------------------------------- piston

  void _paintPiston(Canvas canvas, double w, double h) {
    // horizontal piston at the bottom of the recess, driven by the big gear
    final stroke = holding ? sin(t * 2 * pi) : sin(p * 2 * pi);
    final headX = w * (0.36 + 0.05 * stroke);

    // cylinder
    final cyl = Rect.fromLTWH(w * 0.25, h * 0.795, w * 0.13, h * 0.045);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cyl, Radius.circular(cyl.height / 2)),
      Paint()..color = design.baseDark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cyl, Radius.circular(cyl.height / 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = design.accent.withValues(alpha: 0.6),
    );
    // piston rod
    canvas.drawLine(
      Offset(headX, cyl.center.dy),
      Offset(w * 0.44, h * 0.55 + w * 0.135 * 0.6),
      Paint()
        ..strokeWidth = max(2.0, w * 0.008)
        ..strokeCap = StrokeCap.round
        ..color = design.accent,
    );
    // piston head
    canvas.drawCircle(
        Offset(headX, cyl.center.dy), w * 0.014, Paint()..color = design.accent);
    canvas.drawCircle(
        Offset(headX, cyl.center.dy), w * 0.006,
        Paint()..color = design.accentDark);
  }

  // ---------------------------------------------------------------- gauge

  void _paintGauge(Canvas canvas, double w, double h) {
    // big brass pressure gauge sitting on top of the frame
    final c = Offset(w * 0.5, h * 0.185);
    final r = w * 0.085;

    canvas.drawCircle(
      c.translate(1.5, 2.5),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(c, r, Paint()..color = design.accent);
    canvas.drawCircle(c, r * 0.86, Paint()..color = design.paper);

    // scale arc ticks
    final tick = Paint()
      ..strokeWidth = 1.4
      ..color = design.ink.withValues(alpha: 0.75);
    const tickCount = 8;
    for (int i = 0; i <= tickCount; i++) {
      final a = pi * 0.75 + pi * 1.5 * i / tickCount;
      canvas.drawLine(
        Offset(c.dx + cos(a) * r * 0.62, c.dy + sin(a) * r * 0.62),
        Offset(c.dx + cos(a) * r * 0.76, c.dy + sin(a) * r * 0.76),
        tick,
      );
    }
    // red zone near max
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.69),
      pi * 0.75 + pi * 1.5 * 0.85,
      pi * 1.5 * 0.15,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.10
        ..color = const Color(0xFFB03A2E).withValues(alpha: 0.8),
    );

    // needle follows progress; small tremble while holding
    final tremble = holding ? 0.02 * sin(t * 2 * pi * 8) : 0.0;
    final needleA = pi * 0.75 + pi * 1.5 * (p + tremble).clamp(0.0, 1.0);
    canvas.drawLine(
      c,
      Offset(c.dx + cos(needleA) * r * 0.60, c.dy + sin(needleA) * r * 0.60),
      Paint()
        ..strokeWidth = max(1.8, w * 0.006)
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFB03A2E),
    );
    canvas.drawCircle(c, r * 0.09, Paint()..color = design.accentDark);

    // gauge stem connecting to the frame
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(c.dx, h * 0.275), width: w * 0.028, height: h * 0.035),
      Paint()..color = design.accentDark,
    );
  }
}
