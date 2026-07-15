import 'dart:math';

import 'package:flutter/material.dart';

import 'painter_common.dart';

/// Astronomical clock cabinet:
/// a tall ebony grandfather-clock case with a star-chart dial on top,
/// a swinging pendulum behind a glass door, and moon-phase disc.
///
/// - idle      : pendulum hangs still, dial frozen
/// - holding   : pendulum swings, star dial rotates, constellations glow
/// - completed : dial fully lit, green lamp
class HorologePainter extends MachinePainter {
  HorologePainter({
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

    paintGroundShadow(canvas, size, widthFactor: 0.55);

    _paintCabinet(canvas, w, h);
    _paintPendulumWindow(canvas, w, h);
    _paintStarDial(canvas, w, h);
    _paintMoonPhase(canvas, w, h);
    paintLamp(canvas, Offset(w * 0.5, h * 0.505), w * 0.014);
  }

  // ---------------------------------------------------------------- cabinet

  void _paintCabinet(Canvas canvas, double w, double h) {
    // tall case silhouette: crown - hood - waist - base
    final body = Rect.fromLTRB(w * 0.30, h * 0.10, w * 0.70, h * 0.955);
    final rr = RRect.fromRectAndCorners(
      body,
      topLeft: Radius.circular(w * 0.05),
      topRight: Radius.circular(w * 0.05),
    );
    canvas.drawRRect(
      rr.shift(const Offset(2, 4)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [design.baseDark, design.base, design.baseDark],
        ).createShader(body),
    );

    // crown ornament
    final crown = Path()
      ..moveTo(w * 0.34, h * 0.105)
      ..quadraticBezierTo(w * 0.5, h * 0.035, w * 0.66, h * 0.105)
      ..close();
    canvas.drawPath(crown, Paint()..color = design.baseDark);
    canvas.drawCircle(
        Offset(w * 0.5, h * 0.055), w * 0.012, Paint()..color = design.accent);

    // gold trim lines separating hood / waist / base
    final trim = Paint()
      ..strokeWidth = max(1.5, w * 0.005)
      ..color = design.accent.withValues(alpha: 0.85);
    for (final y in [h * 0.475, h * 0.535, h * 0.875]) {
      canvas.drawLine(Offset(w * 0.30, y), Offset(w * 0.70, y), trim);
    }

    // base plinth
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.27, h * 0.875, w * 0.73, h * 0.955),
          Radius.circular(w * 0.012)),
      Paint()..color = design.baseDark,
    );
    // clawed feet
    final foot = Paint()..color = design.accentDark;
    canvas.drawCircle(Offset(w * 0.315, h * 0.955), w * 0.016, foot);
    canvas.drawCircle(Offset(w * 0.685, h * 0.955), w * 0.016, foot);

    // side columns with gold capitals
    final col = Paint()..color = design.baseLight.withValues(alpha: 0.35);
    for (final x in [w * 0.325, w * 0.675]) {
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(x, h * 0.70),
              width: w * 0.018,
              height: h * 0.32),
          col);
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(x, h * 0.545), width: w * 0.030, height: h * 0.014),
          Paint()..color = design.accent.withValues(alpha: 0.8));
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(x, h * 0.862), width: w * 0.030, height: h * 0.014),
          Paint()..color = design.accent.withValues(alpha: 0.8));
    }
  }

  // ------------------------------------------------------- pendulum window

  void _paintPendulumWindow(Canvas canvas, double w, double h) {
    // arched glass door in the waist showing the pendulum
    final win = Rect.fromLTRB(w * 0.375, h * 0.555, w * 0.625, h * 0.855);
    final arched = RRect.fromRectAndCorners(
      win,
      topLeft: Radius.circular(w * 0.12),
      topRight: Radius.circular(w * 0.12),
    );
    canvas.drawRRect(arched, Paint()..color = const Color(0xFF12101A));
    canvas.drawRRect(
      arched,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, w * 0.005)
        ..color = design.accent.withValues(alpha: 0.8),
    );

    // pendulum: swings while holding, hangs straight when idle
    final swing = holding ? sin(t * 2 * pi * 1.2) * 0.30 : 0.0;
    final pivot = Offset(w * 0.5, h * 0.565);
    final rodLen = h * 0.235;
    final bob = Offset(
      pivot.dx + sin(swing) * rodLen,
      pivot.dy + cos(swing) * rodLen,
    );

    canvas.save();
    canvas.clipRRect(arched);
    // rod
    canvas.drawLine(
      pivot,
      bob,
      Paint()
        ..strokeWidth = max(1.5, w * 0.005)
        ..color = design.accent,
    );
    // bob with glow while swinging
    if (holding || completed) {
      canvas.drawCircle(
        bob,
        w * 0.045,
        Paint()
          ..color = (completed ? design.lampDone : design.lampActive)
              .withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    canvas.drawCircle(bob, w * 0.028, Paint()..color = design.accent);
    canvas.drawCircle(
        bob, w * 0.028,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = design.accentDark);
    canvas.drawCircle(bob, w * 0.010, Paint()..color = design.accentDark);
    // glass reflection streak
    canvas.drawLine(
      Offset(win.left + win.width * 0.25, win.top + win.height * 0.1),
      Offset(win.left + win.width * 0.05, win.top + win.height * 0.55),
      Paint()
        ..strokeWidth = w * 0.014
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.05),
    );
    canvas.restore();
  }

  // --------------------------------------------------------------- star dial

  void _paintStarDial(Canvas canvas, double w, double h) {
    final c = Offset(w * 0.5, h * 0.295);
    final r = w * 0.155;

    // dial face: deep night blue
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF141227));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(2.0, w * 0.008)
        ..color = design.accent,
    );
    // inner ring
    canvas.drawCircle(
      c,
      r * 0.78,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = design.accent.withValues(alpha: 0.5),
    );

    // rotating star field; brightness follows progress
    final rot = holding ? t * 2 * pi * 0.4 : p * 2 * pi * 0.5;
    final rnd = Random(21);
    final starCount = 26;
    for (int i = 0; i < starCount; i++) {
      final ra = rnd.nextDouble() * 2 * pi + rot;
      final rr = rnd.nextDouble() * r * 0.70;
      // stars light up progressively: first N stars visible
      final visible = i < (starCount * (0.25 + 0.75 * p)).round();
      if (!visible) continue;
      final sparkle =
          holding ? 0.5 + 0.5 * sin(t * 2 * pi * 3 + i) : 0.8;
      final sr = w * (0.0035 + rnd.nextDouble() * 0.004);
      canvas.drawCircle(
        Offset(c.dx + cos(ra) * rr, c.dy + sin(ra) * rr),
        sr,
        Paint()
          ..color = design.lampActive.withValues(alpha: 0.35 + 0.6 * sparkle),
      );
    }

    // constellation lines connecting a few stars (fixed pattern, rotates)
    final constel = Paint()
      ..strokeWidth = 1.0
      ..color = design.accent.withValues(alpha: 0.45);
    final pts = <Offset>[];
    final rnd2 = Random(33);
    for (int i = 0; i < 5; i++) {
      final ra = rnd2.nextDouble() * 2 * pi + rot;
      final rr = (0.25 + rnd2.nextDouble() * 0.45) * r;
      pts.add(Offset(c.dx + cos(ra) * rr, c.dy + sin(ra) * rr));
    }
    for (int i = 0; i < pts.length - 1; i++) {
      canvas.drawLine(pts[i], pts[i + 1], constel);
    }

    // two ornate hands
    final hourA = -pi / 2 + p * 2 * pi;
    final minA = -pi / 2 + (holding ? t * 2 * pi : p * 2 * pi * 4);
    canvas.drawLine(
      c,
      Offset(c.dx + cos(hourA) * r * 0.42, c.dy + sin(hourA) * r * 0.42),
      Paint()
        ..strokeWidth = max(2.0, w * 0.008)
        ..strokeCap = StrokeCap.round
        ..color = design.accent,
    );
    canvas.drawLine(
      c,
      Offset(c.dx + cos(minA) * r * 0.62, c.dy + sin(minA) * r * 0.62),
      Paint()
        ..strokeWidth = max(1.2, w * 0.004)
        ..strokeCap = StrokeCap.round
        ..color = design.accent.withValues(alpha: 0.85),
    );
    canvas.drawCircle(c, r * 0.06, Paint()..color = design.accent);

    // roman numeral tick marks
    final tick = Paint()
      ..strokeWidth = 1.4
      ..color = design.accent.withValues(alpha: 0.7);
    for (int i = 0; i < 12; i++) {
      final a = 2 * pi * i / 12;
      canvas.drawLine(
        Offset(c.dx + cos(a) * r * 0.86, c.dy + sin(a) * r * 0.86),
        Offset(c.dx + cos(a) * r * 0.94, c.dy + sin(a) * r * 0.94),
        tick,
      );
    }
  }

  // -------------------------------------------------------------- moon phase

  void _paintMoonPhase(Canvas canvas, double w, double h) {
    // small moon-phase window between dial and pendulum
    final c = Offset(w * 0.5, h * 0.44);
    final r = w * 0.030;

    canvas.drawCircle(c, r * 1.35, Paint()..color = design.baseDark);
    canvas.drawCircle(
      c,
      r * 1.35,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = design.accent.withValues(alpha: 0.7),
    );
    // moon disc: phase follows progress (new moon -> full moon)
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF181528));
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    final phaseShift = (1 - p) * r * 2;
    canvas.drawCircle(
      Offset(c.dx + phaseShift, c.dy),
      r,
      Paint()..color = const Color(0xFFE8E4D0).withValues(alpha: 0.9),
    );
    canvas.restore();
  }
}
