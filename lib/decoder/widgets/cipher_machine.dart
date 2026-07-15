import 'dart:math';

import 'package:flutter/material.dart';

import 'machine_designs.dart';

/// Identity V style cipher machine:
/// an antique typewriter sitting on a wooden crate.
///
/// Everything is drawn with a single CustomPainter so it scales cleanly.
/// The [design] preset only swaps colors - the silhouette stays the same.
///
/// Visual states:
///  - idle      : still machine, dim lamp
///  - holding   : keys jitter, type bars move, lamp glows, paper rises
///  - completed : paper fully typed, green lamp, machine at rest
class CipherMachine extends StatefulWidget {
  /// 0..100
  final double progress;
  final bool holding;
  final bool completed;
  final MachineDesign design;

  const CipherMachine({
    super.key,
    required this.progress,
    required this.holding,
    required this.completed,
    required this.design,
  });

  @override
  State<CipherMachine> createState() => _CipherMachineState();
}

class _CipherMachineState extends State<CipherMachine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    // continuous clock driving key jitter / lamp pulse
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return CustomPaint(
          painter: _MachinePainter(
            progress: widget.progress,
            holding: widget.holding,
            completed: widget.completed,
            design: widget.design,
            t: _anim.value,
          ),
        );
      },
    );
  }
}

class _MachinePainter extends CustomPainter {
  final double progress;
  final bool holding;
  final bool completed;
  final MachineDesign design;

  /// Animation clock 0..1 (looping).
  final double t;

  _MachinePainter({
    required this.progress,
    required this.holding,
    required this.completed,
    required this.design,
    required this.t,
  });

  // Deterministic random for stable per-key offsets.
  final Random _rand = Random(7);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Layout bands (fractions of height):
    //   paper     : 0.02 - 0.30 (rises out of the platen)
    //   typewriter: 0.22 - 0.58
    //   crate     : 0.58 - 0.98
    final crateRect = Rect.fromLTRB(w * 0.14, h * 0.575, w * 0.86, h * 0.98);
    final bodyRect = Rect.fromLTRB(w * 0.20, h * 0.335, w * 0.80, h * 0.585);

    _paintGroundShadow(canvas, w, h);
    _paintCrate(canvas, crateRect);
    _paintPaper(canvas, w, h);
    _paintPlaten(canvas, w, h);
    _paintBody(canvas, bodyRect, w, h);
    _paintCarriageLever(canvas, w, h);
    _paintDial(canvas, w, h);
    _paintKeyboard(canvas, w, h);
    _paintLamp(canvas, w, h);
  }

  // ---------------------------------------------------------------- ground

  void _paintGroundShadow(Canvas canvas, double w, double h) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.985),
        width: w * 0.74,
        height: h * 0.05,
      ),
      paint,
    );
  }

  // ---------------------------------------------------------------- crate

  void _paintCrate(Canvas canvas, Rect r) {
    final plank = Paint()..color = design.crate;
    final dark = Paint()..color = design.crateDark;

    // base box
    canvas.drawRect(r, plank);

    // horizontal plank seams
    final seam = Paint()
      ..color = design.crateDark.withValues(alpha: 0.55)
      ..strokeWidth = r.height * 0.012;
    const planks = 4;
    for (int i = 1; i < planks; i++) {
      final y = r.top + r.height * i / planks;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), seam);
    }

    // frame (edge battens)
    final frameW = r.width * 0.055;
    canvas.drawRect(
        Rect.fromLTWH(r.left, r.top, frameW, r.height), dark);
    canvas.drawRect(
        Rect.fromLTWH(r.right - frameW, r.top, frameW, r.height), dark);
    canvas.drawRect(
        Rect.fromLTWH(r.left, r.top, r.width, frameW * 0.75), dark);
    canvas.drawRect(
        Rect.fromLTWH(r.left, r.bottom - frameW * 0.75, r.width, frameW * 0.75),
        dark);

    // X cross brace
    final brace = Paint()
      ..color = design.crateDark
      ..strokeWidth = frameW * 0.8
      ..strokeCap = StrokeCap.round;
    final inset = frameW * 1.3;
    canvas.drawLine(
      Offset(r.left + inset, r.top + inset),
      Offset(r.right - inset, r.bottom - inset),
      brace,
    );
    canvas.drawLine(
      Offset(r.right - inset, r.top + inset),
      Offset(r.left + inset, r.bottom - inset),
      brace,
    );

    // corner nails
    final nail = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final nailR = frameW * 0.16;
    for (final p in [
      Offset(r.left + frameW / 2, r.top + frameW / 2),
      Offset(r.right - frameW / 2, r.top + frameW / 2),
      Offset(r.left + frameW / 2, r.bottom - frameW / 2),
      Offset(r.right - frameW / 2, r.bottom - frameW / 2),
    ]) {
      canvas.drawCircle(p, nailR, nail);
    }

    // subtle top light
    final light = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.07),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.4));
    canvas.drawRect(
        Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.4), light);
  }

  // ---------------------------------------------------------------- paper

  void _paintPaper(Canvas canvas, double w, double h) {
    // Paper rises out of the platen as progress goes up.
    final p = (progress / 100).clamp(0.0, 1.0);
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

    final paper = Paint()..color = design.paper;
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.circular(2),
      topRight: const Radius.circular(2),
    );
    // paper shadow
    canvas.drawRRect(
      rrect.shift(const Offset(2, 1)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(rrect, paper);

    // typed cipher lines: amount follows progress
    final linePaint = Paint()
      ..color = design.ink.withValues(alpha: 0.75)
      ..strokeWidth = max(1.2, h * 0.006)
      ..strokeCap = StrokeCap.round;
    final lineGap = h * 0.022;
    final marginX = paperW * 0.12;
    final usableTop = rect.top + h * 0.02;
    final usableBottom = rect.bottom - h * 0.028;
    final maxLines = ((usableBottom - usableTop) / lineGap).floor();
    final rnd = Random(42);
    for (int i = 0; i < maxLines; i++) {
      final y = usableTop + i * lineGap;
      // each line is a few dashes of varying width = typed cipher words
      double x = rect.left + marginX;
      final lineEnd = rect.right - marginX;
      // last visible line may be partially typed while decoding
      final isLast = i == maxLines - 1;
      final fill = isLast && holding ? (t * 2) % 1.0 : 1.0;
      final lineLimit = x + (lineEnd - x) * fill;
      while (x < lineLimit) {
        final seg = paperW * (0.06 + rnd.nextDouble() * 0.10);
        final end = min(x + seg, lineLimit);
        canvas.drawLine(Offset(x, y), Offset(end, y), linePaint);
        x = end + paperW * 0.04;
      }
    }
  }

  // ---------------------------------------------------------------- platen

  void _paintPlaten(Canvas canvas, double w, double h) {
    // roller cylinder across the top of the body
    final rect = Rect.fromLTWH(w * 0.245, h * 0.315, w * 0.51, h * 0.05);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2));

    final roller = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          design.platen.withValues(alpha: 0.85),
          design.platen,
          Colors.black.withValues(alpha: 0.9),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, roller);

    // platen knobs on both ends
    final knob = Paint()..color = design.bodyDark;
    final knobR = rect.height * 0.62;
    canvas.drawCircle(Offset(rect.left - knobR * 0.4, rect.center.dy), knobR, knob);
    canvas.drawCircle(Offset(rect.right + knobR * 0.4, rect.center.dy), knobR, knob);
    // knob highlight rings
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = design.bodyLight.withValues(alpha: 0.5);
    canvas.drawCircle(
        Offset(rect.left - knobR * 0.4, rect.center.dy), knobR * 0.55, ring);
    canvas.drawCircle(
        Offset(rect.right + knobR * 0.4, rect.center.dy), knobR * 0.55, ring);
  }

  // ---------------------------------------------------------------- body

  void _paintBody(Canvas canvas, Rect r, double w, double h) {
    // main shell with slightly rounded top corners
    final shell = RRect.fromRectAndCorners(
      r,
      topLeft: Radius.circular(r.width * 0.06),
      topRight: Radius.circular(r.width * 0.06),
    );
    final body = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [design.bodyLight, design.body, design.bodyDark],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(r);
    canvas.drawRRect(shell, body);

    // type bar basket: dark半円 behind the platen opening
    final basketCenter = Offset(r.center.dx, r.top + r.height * 0.10);
    final basketR = r.width * 0.17;
    canvas.drawArc(
      Rect.fromCircle(center: basketCenter, radius: basketR),
      pi,
      pi,
      true,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    // type bars (thin rods fanning into the basket); one bar strikes while holding
    final barPaint = Paint()
      ..strokeWidth = max(1.0, w * 0.004)
      ..color = design.dial.withValues(alpha: 0.7);
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
    final panel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.black.withValues(alpha: 0.3);
    canvas.drawLine(
      Offset(r.left + r.width * 0.06, r.top + r.height * 0.52),
      Offset(r.right - r.width * 0.06, r.top + r.height * 0.52),
      panel,
    );

    // maker's plate (small emblem)
    final plateRect = Rect.fromCenter(
      center: Offset(r.center.dx, r.top + r.height * 0.40),
      width: r.width * 0.20,
      height: r.height * 0.10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(plateRect, const Radius.circular(2)),
      Paint()..color = design.dial.withValues(alpha: 0.35),
    );
  }

  // -------------------------------------------------------- carriage lever

  void _paintCarriageLever(Canvas canvas, double w, double h) {
    // return lever sticking out on the left of the platen
    final base = Offset(w * 0.215, h * 0.34);
    final lever = Paint()
      ..strokeWidth = max(2.0, w * 0.008)
      ..strokeCap = StrokeCap.round
      ..color = design.bodyDark;
    canvas.drawLine(base, Offset(base.dx - w * 0.045, base.dy - h * 0.045), lever);
    canvas.drawCircle(
      Offset(base.dx - w * 0.045, base.dy - h * 0.045),
      w * 0.011,
      Paint()..color = design.dial,
    );
  }

  // ---------------------------------------------------------------- dial

  void _paintDial(Canvas canvas, double w, double h) {
    // side wheel like the reference image (left side of the body)
    final c = Offset(w * 0.175, h * 0.475);
    final rOuter = w * 0.052;

    canvas.drawCircle(
        c, rOuter, Paint()..color = design.bodyDark);
    canvas.drawCircle(
      c,
      rOuter,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, w * 0.006)
        ..color = design.dial,
    );
    // spokes - rotate slowly while decoding
    final spin = holding ? t * 2 * pi : 0.0;
    final spoke = Paint()
      ..strokeWidth = max(1.2, w * 0.005)
      ..color = design.dial.withValues(alpha: 0.85);
    for (int i = 0; i < 3; i++) {
      final a = spin + pi * i / 3;
      canvas.drawLine(
        Offset(c.dx + cos(a) * rOuter * 0.8, c.dy + sin(a) * rOuter * 0.8),
        Offset(c.dx - cos(a) * rOuter * 0.8, c.dy - sin(a) * rOuter * 0.8),
        spoke,
      );
    }
    canvas.drawCircle(c, rOuter * 0.18, Paint()..color = design.dial);
  }

  // -------------------------------------------------------------- keyboard

  void _paintKeyboard(Canvas canvas, double w, double h) {
    // 3 staggered rows of round keys on the sloped front
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

        // per-key press animation while holding (pseudo random pattern)
        double press = 0;
        if (holding) {
          final phase = (t * 3 + _rand.nextDouble()) % 1.0;
          if (phase < 0.12) press = 1 - phase / 0.12;
        }
        final dy = press * h * 0.006;

        final center = Offset(x, y + dy);
        // key stem
        canvas.drawLine(
          Offset(x, y + keyR * 0.4),
          Offset(x, y + keyR * 1.1),
          Paint()
            ..strokeWidth = max(1.0, w * 0.004)
            ..color = Colors.black.withValues(alpha: 0.5),
        );
        // cap shadow ring
        canvas.drawCircle(
          center,
          keyR,
          Paint()..color = Colors.black.withValues(alpha: 0.45),
        );
        // cap
        canvas.drawCircle(
          center.translate(0, -keyR * 0.12),
          keyR * 0.92,
          Paint()..color = design.keyCap,
        );
        // metal rim
        canvas.drawCircle(
          center.translate(0, -keyR * 0.12),
          keyR * 0.92,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = design.dial.withValues(alpha: 0.7),
        );
        // legend dot (too small for real letters at this scale)
        canvas.drawCircle(
          center.translate(0, -keyR * 0.12),
          keyR * 0.22,
          Paint()..color = design.keyLegend.withValues(alpha: 0.75),
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
      Paint()..color = design.keyCap,
    );
  }

  // ---------------------------------------------------------------- lamp

  void _paintLamp(Canvas canvas, double w, double h) {
    // indicator lamp on the body's top-right corner
    final c = Offset(w * 0.755, h * 0.365);
    final r = w * 0.016;

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
    canvas.drawCircle(c, r * 1.25, Paint()..color = design.bodyDark);
    canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: 0.25 + glow * 0.75));
  }

  @override
  bool shouldRepaint(covariant _MachinePainter old) =>
      old.progress != progress ||
      old.holding != holding ||
      old.completed != completed ||
      old.design != design ||
      old.t != t;
}
