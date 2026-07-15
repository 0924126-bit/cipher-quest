import 'dart:math';

import 'package:flutter/material.dart';

import '../machine_designs.dart';

/// Base class for all cipher machine painters.
///
/// Holds the shared animation inputs and offers small drawing helpers so
/// that each machine painter stays focused on its own silhouette.
abstract class MachinePainter extends CustomPainter {
  /// Decode progress 0..100.
  final double progress;

  /// True while the player is holding (machine is running).
  final bool holding;

  /// True once decoding finished.
  final bool completed;

  /// Color palette.
  final MachineDesign design;

  /// Looping animation clock 0..1.
  final double t;

  MachinePainter({
    required this.progress,
    required this.holding,
    required this.completed,
    required this.design,
    required this.t,
  });

  /// Progress normalized to 0..1.
  double get p => (progress / 100).clamp(0.0, 1.0);

  // ------------------------------------------------------------ helpers

  /// Soft elliptical ground shadow under the machine.
  void paintGroundShadow(Canvas canvas, Size size,
      {double widthFactor = 0.74}) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.985),
        width: size.width * widthFactor,
        height: size.height * 0.05,
      ),
      paint,
    );
  }

  /// Indicator lamp with glow. Amber pulse while holding, green when done.
  void paintLamp(Canvas canvas, Offset c, double r) {
    Color color;
    double glow;
    if (completed) {
      color = design.lampDone;
      glow = 0.9;
    } else if (holding) {
      color = design.lampActive;
      glow = 0.55 + 0.35 * (0.5 + 0.5 * sin(t * 2 * pi * 2));
    } else {
      color = design.lampActive;
      glow = 0.12;
    }

    if (glow > 0.2) {
      canvas.drawCircle(
        c,
        r * 3.2,
        Paint()
          ..color = color.withValues(alpha: glow * 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    canvas.drawCircle(c, r * 1.25, Paint()..color = design.baseDark);
    canvas.drawCircle(
        c, r, Paint()..color = color.withValues(alpha: 0.25 + glow * 0.75));
  }

  /// Wooden crate / stand with plank seams, edge battens and an X brace.
  void paintCrate(Canvas canvas, Rect r) {
    final plank = Paint()..color = design.wood;
    final dark = Paint()..color = design.woodDark;

    canvas.drawRect(r, plank);

    final seam = Paint()
      ..color = design.woodDark.withValues(alpha: 0.55)
      ..strokeWidth = r.height * 0.012;
    const planks = 4;
    for (int i = 1; i < planks; i++) {
      final y = r.top + r.height * i / planks;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), seam);
    }

    final frameW = r.width * 0.055;
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, frameW, r.height), dark);
    canvas.drawRect(
        Rect.fromLTWH(r.right - frameW, r.top, frameW, r.height), dark);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, frameW * 0.75), dark);
    canvas.drawRect(
        Rect.fromLTWH(r.left, r.bottom - frameW * 0.75, r.width, frameW * 0.75),
        dark);

    final brace = Paint()
      ..color = design.woodDark
      ..strokeWidth = frameW * 0.8
      ..strokeCap = StrokeCap.round;
    final inset = frameW * 1.3;
    canvas.drawLine(Offset(r.left + inset, r.top + inset),
        Offset(r.right - inset, r.bottom - inset), brace);
    canvas.drawLine(Offset(r.right - inset, r.top + inset),
        Offset(r.left + inset, r.bottom - inset), brace);

    final nail = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final nailR = frameW * 0.16;
    for (final pos in [
      Offset(r.left + frameW / 2, r.top + frameW / 2),
      Offset(r.right - frameW / 2, r.top + frameW / 2),
      Offset(r.left + frameW / 2, r.bottom - frameW / 2),
      Offset(r.right - frameW / 2, r.bottom - frameW / 2),
    ]) {
      canvas.drawCircle(pos, nailR, nail);
    }

    final light = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.07), Colors.transparent],
      ).createShader(Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.4));
    canvas.drawRect(
        Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.4), light);
  }

  /// A cog wheel with [teeth] teeth, rotated by [angle] radians.
  void paintGear(
    Canvas canvas,
    Offset c,
    double radius, {
    required int teeth,
    required double angle,
    Color? color,
    Color? darkColor,
    double toothDepth = 0.18,
    double holeRatio = 0.22,
    int spokes = 4,
  }) {
    final body = color ?? design.accent;
    final dark = darkColor ?? design.accentDark;
    final rOuter = radius;
    final rInner = radius * (1 - toothDepth);

    final path = Path();
    final steps = teeth * 2;
    for (int i = 0; i <= steps; i++) {
      final a = angle + 2 * pi * i / steps;
      final r = i.isEven ? rOuter : rInner;
      final pt = Offset(c.dx + cos(a) * r, c.dy + sin(a) * r);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();

    canvas.drawPath(
      path.shift(const Offset(1.5, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(path, Paint()..color = body);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.05
        ..color = dark.withValues(alpha: 0.8),
    );

    // spokes
    final spoke = Paint()
      ..strokeWidth = radius * 0.13
      ..strokeCap = StrokeCap.round
      ..color = dark.withValues(alpha: 0.85);
    for (int i = 0; i < spokes; i++) {
      final a = angle + pi * 2 * i / spokes;
      canvas.drawLine(
        Offset(c.dx + cos(a) * radius * holeRatio,
            c.dy + sin(a) * radius * holeRatio),
        Offset(c.dx + cos(a) * rInner * 0.82, c.dy + sin(a) * rInner * 0.82),
        spoke,
      );
    }

    // hub
    canvas.drawCircle(c, radius * holeRatio, Paint()..color = dark);
    canvas.drawCircle(
      c,
      radius * holeRatio * 0.45,
      Paint()..color = body.withValues(alpha: 0.9),
    );
  }

  /// Typed cipher scribbles (dashes) filling [rect] line by line.
  /// [fillRatio] 0..1 controls how much of the sheet is written.
  void paintCipherText(
    Canvas canvas,
    Rect rect, {
    required double fillRatio,
    double? lineGap,
    int seed = 42,
  }) {
    final gap = lineGap ?? rect.height * 0.14;
    if (gap <= 0) return;
    final linePaint = Paint()
      ..color = design.ink.withValues(alpha: 0.75)
      ..strokeWidth = max(1.2, gap * 0.22)
      ..strokeCap = StrokeCap.round;
    final marginX = rect.width * 0.10;
    final maxLines = max(1, (rect.height / gap).floor());
    final visibleLines = (maxLines * fillRatio).ceil();
    final rnd = Random(seed);
    for (int i = 0; i < maxLines; i++) {
      final y = rect.top + gap * 0.6 + i * gap;
      if (i >= visibleLines) break;
      double x = rect.left + marginX;
      final lineEnd = rect.right - marginX;
      // the newest line may be partially written while running
      final isLast = i == visibleLines - 1;
      final partial = isLast && holding ? (t * 2) % 1.0 : 1.0;
      final limit = x + (lineEnd - x) * partial;
      while (x < limit) {
        final seg = rect.width * (0.06 + rnd.nextDouble() * 0.10);
        final end = min(x + seg, limit);
        canvas.drawLine(Offset(x, y), Offset(end, y), linePaint);
        x = end + rect.width * 0.04;
      }
    }
  }

  /// Vertical top-light gradient over [rect] to fake volume.
  void paintTopLight(Canvas canvas, Rect rect, {double alpha = 0.08}) {
    final light = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: alpha), Colors.transparent],
      ).createShader(rect);
    canvas.drawRect(rect, light);
  }

  /// Metal body gradient paint for [rect].
  Paint bodyGradient(Rect rect) {
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [design.baseLight, design.base, design.baseDark],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);
  }

  @override
  bool shouldRepaint(covariant MachinePainter old) =>
      old.progress != progress ||
      old.holding != holding ||
      old.completed != completed ||
      old.design != design ||
      old.t != t;
}
