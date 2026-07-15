import 'dart:math';

import 'package:flutter/material.dart';

import 'painter_common.dart';

/// Identity V reference machine:
/// an antique typewriter sitting on a wooden crate.
///
/// - idle      : still machine, dim lamp
/// - holding   : keys jitter, type bars strike, dial spins, paper rises
/// - completed : paper fully typed, green lamp, machine at rest
class TypewriterPainter extends MachinePainter {
  TypewriterPainter({
    required super.progress,
    required super.holding,
    required super.completed,
    required super.design,
    required super.t,
  });

  final Random _rand = Random(7);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final crateRect = Rect.fromLTRB(w * 0.14, h * 0.575, w * 0.86, h * 0.98);
    final bodyRect = Rect.fromLTRB(w * 0.20, h * 0.335, w * 0.80, h * 0.585);

    paintGroundShadow(canvas, size);
    paintCrate(canvas, crateRect);
    _paintPaper(canvas, w, h);
    _paintPlaten(canvas, w, h);
    _paintBody(canvas, bodyRect, w, h);
    _paintCarriageLever(canvas, w, h);
    _paintSideWheel(canvas, w, h);
    _paintKeyboard(canvas, w, h);
    paintLamp(canvas, Offset(w * 0.755, h * 0.365), w * 0.016);
  }

  // ---------------------------------------------------------------- paper

  void _paintPaper(Canvas canvas, double w, double h) {
    final paperW = w * 0.34;
    final maxRise = h * 0.24;
    final rise = h * 0.045 + maxRise * p;

    final platenY = h * 0.335;
    final rect = Rect.fromLTWH(
      w * 0.5 - paperW / 2,
      platenY - rise,
      paperW,
      rise + h * 0.02,
    );

    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.circular(2),
      topRight: const Radius.circular(2),
    );
    canvas.drawRRect(
      rrect.shift(const Offset(2, 1)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(rrect, Paint()..color = design.paper);

    paintCipherText(
      canvas,
      rect.deflate(h * 0.012),
      fillRatio: 1.0,
      lineGap: h * 0.022,
    );
  }

  // ---------------------------------------------------------------- platen

  void _paintPlaten(Canvas canvas, double w, double h) {
    final rect = Rect.fromLTWH(w * 0.245, h * 0.315, w * 0.51, h * 0.05);
    final rrect =
        RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2));

    final roller = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          design.baseDark.withValues(alpha: 0.85),
          design.accentDark,
          Colors.black.withValues(alpha: 0.9),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, roller);

    final knob = Paint()..color = design.baseDark;
    final knobR = rect.height * 0.62;
    canvas.drawCircle(
        Offset(rect.left - knobR * 0.4, rect.center.dy), knobR, knob);
    canvas.drawCircle(
        Offset(rect.right + knobR * 0.4, rect.center.dy), knobR, knob);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = design.baseLight.withValues(alpha: 0.5);
    canvas.drawCircle(
        Offset(rect.left - knobR * 0.4, rect.center.dy), knobR * 0.55, ring);
    canvas.drawCircle(
        Offset(rect.right + knobR * 0.4, rect.center.dy), knobR * 0.55, ring);
  }

  // ---------------------------------------------------------------- body

  void _paintBody(Canvas canvas, Rect r, double w, double h) {
    final shell = RRect.fromRectAndCorners(
      r,
      topLeft: Radius.circular(r.width * 0.06),
      topRight: Radius.circular(r.width * 0.06),
    );
    canvas.drawRRect(shell, bodyGradient(r));

    // type bar basket: dark half circle behind the platen opening
    final basketCenter = Offset(r.center.dx, r.top + r.height * 0.10);
    final basketR = r.width * 0.17;
    canvas.drawArc(
      Rect.fromCircle(center: basketCenter, radius: basketR),
      pi,
      pi,
      true,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    // type bars fanning into the basket; one strikes while holding
    final barPaint = Paint()
      ..strokeWidth = max(1.0, w * 0.004)
      ..color = design.accent.withValues(alpha: 0.7);
    const barCount = 9;
    final strikeIndex = (t * barCount * 2).floor() % barCount;
    for (int i = 0; i < barCount; i++) {
      final a = pi + pi * (i + 0.5) / barCount;
      final isStriking = holding && i == strikeIndex;
      final len = basketR * (isStriking ? 0.95 : 0.62);
      final from = Offset(
        basketCenter.dx + cos(a) * basketR * 0.25,
        basketCenter.dy + sin(a) * basketR * 0.25,
      );
      final to = Offset(
        basketCenter.dx + cos(a) * len,
        basketCenter.dy + sin(a) * len,
      );
      canvas.drawLine(from, to, barPaint);
    }

    // front face panel line
    canvas.drawLine(
      Offset(r.left + r.width * 0.06, r.top + r.height * 0.52),
      Offset(r.right - r.width * 0.06, r.top + r.height * 0.52),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.black.withValues(alpha: 0.3),
    );

    // maker's plate
    final plateRect = Rect.fromCenter(
      center: Offset(r.center.dx, r.top + r.height * 0.40),
      width: r.width * 0.20,
      height: r.height * 0.10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(plateRect, const Radius.circular(2)),
      Paint()..color = design.accent.withValues(alpha: 0.35),
    );
  }

  // -------------------------------------------------------- carriage lever

  void _paintCarriageLever(Canvas canvas, double w, double h) {
    final base = Offset(w * 0.215, h * 0.34);
    final lever = Paint()
      ..strokeWidth = max(2.0, w * 0.008)
      ..strokeCap = StrokeCap.round
      ..color = design.baseDark;
    canvas.drawLine(
        base, Offset(base.dx - w * 0.045, base.dy - h * 0.045), lever);
    canvas.drawCircle(
      Offset(base.dx - w * 0.045, base.dy - h * 0.045),
      w * 0.011,
      Paint()..color = design.accent,
    );
  }

  // ------------------------------------------------------------ side wheel

  void _paintSideWheel(Canvas canvas, double w, double h) {
    final c = Offset(w * 0.175, h * 0.475);
    final rOuter = w * 0.052;

    canvas.drawCircle(c, rOuter, Paint()..color = design.baseDark);
    canvas.drawCircle(
      c,
      rOuter,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, w * 0.006)
        ..color = design.accent,
    );
    final spin = holding ? t * 2 * pi : 0.0;
    final spoke = Paint()
      ..strokeWidth = max(1.2, w * 0.005)
      ..color = design.accent.withValues(alpha: 0.85);
    for (int i = 0; i < 3; i++) {
      final a = spin + pi * i / 3;
      canvas.drawLine(
        Offset(c.dx + cos(a) * rOuter * 0.8, c.dy + sin(a) * rOuter * 0.8),
        Offset(c.dx - cos(a) * rOuter * 0.8, c.dy - sin(a) * rOuter * 0.8),
        spoke,
      );
    }
    canvas.drawCircle(c, rOuter * 0.18, Paint()..color = design.accent);
  }

  // -------------------------------------------------------------- keyboard

  void _paintKeyboard(Canvas canvas, double w, double h) {
    const rows = 3;
    const keysPerRow = [10, 9, 8];
    final keyR = w * 0.021;

    for (int row = 0; row < rows; row++) {
      final count = keysPerRow[row];
      final y = h * (0.512 + row * 0.030);
      final rowWidth = w * (0.46 - row * 0.03);
      final startX = w * 0.5 - rowWidth / 2;
      for (int i = 0; i < count; i++) {
        final x = startX + rowWidth * i / (count - 1);

        double press = 0;
        if (holding) {
          final phase = (t * 3 + _rand.nextDouble()) % 1.0;
          if (phase < 0.12) press = 1 - phase / 0.12;
        }
        final dy = press * h * 0.006;

        final center = Offset(x, y + dy);
        canvas.drawLine(
          Offset(x, y + keyR * 0.4),
          Offset(x, y + keyR * 1.1),
          Paint()
            ..strokeWidth = max(1.0, w * 0.004)
            ..color = Colors.black.withValues(alpha: 0.5),
        );
        canvas.drawCircle(
          center,
          keyR,
          Paint()..color = Colors.black.withValues(alpha: 0.45),
        );
        canvas.drawCircle(
          center.translate(0, -keyR * 0.12),
          keyR * 0.92,
          Paint()..color = design.accentDark,
        );
        canvas.drawCircle(
          center.translate(0, -keyR * 0.12),
          keyR * 0.92,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = design.accent.withValues(alpha: 0.7),
        );
        canvas.drawCircle(
          center.translate(0, -keyR * 0.12),
          keyR * 0.22,
          Paint()..color = design.paper.withValues(alpha: 0.75),
        );
      }
    }

    // space bar
    final spaceRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.512 + 3 * h * 0.030),
      width: w * 0.22,
      height: h * 0.016,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(spaceRect, Radius.circular(spaceRect.height / 2)),
      Paint()..color = design.accentDark,
    );
  }
}
