import 'dart:math';

import 'package:flutter/material.dart';

import 'painter_common.dart';

/// Old telegraph station on a wooden desk:
/// a morse key on the left, two spark coils in the middle, and a
/// punched paper tape spooling out of a reader on the right.
///
/// - idle      : key up, tape still
/// - holding   : key taps, sparks jump between the coils, tape scrolls
/// - completed : tape fully punched, green lamp
class TelegraphPainter extends MachinePainter {
  TelegraphPainter({
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

    paintGroundShadow(canvas, size, widthFactor: 0.85);

    _paintDesk(canvas, w, h);
    _paintBackPanel(canvas, w, h);
    _paintCoils(canvas, w, h);
    _paintMorseKey(canvas, w, h);
    _paintTapeReader(canvas, w, h);
    _paintTape(canvas, w, h);
    paintLamp(canvas, Offset(w * 0.5, h * 0.315), w * 0.016);
  }

  // ---------------------------------------------------------------- desk

  void _paintDesk(Canvas canvas, double w, double h) {
    // desk top slab
    final top = Rect.fromLTRB(w * 0.08, h * 0.62, w * 0.92, h * 0.68);
    canvas.drawRRect(
      RRect.fromRectAndRadius(top, Radius.circular(w * 0.008)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [design.wood, design.woodDark],
        ).createShader(top),
    );
    // wood grain lines
    final grain = Paint()
      ..strokeWidth = 1.0
      ..color = design.woodDark.withValues(alpha: 0.45);
    for (int i = 0; i < 4; i++) {
      final y = top.top + top.height * (0.25 + i * 0.2);
      canvas.drawLine(
          Offset(top.left + w * 0.02, y), Offset(top.right - w * 0.02, y), grain);
    }

    // two sturdy legs with a cross beam
    final leg = Paint()..color = design.woodDark;
    canvas.drawRect(
        Rect.fromLTWH(w * 0.14, h * 0.68, w * 0.05, h * 0.29), leg);
    canvas.drawRect(
        Rect.fromLTWH(w * 0.81, h * 0.68, w * 0.05, h * 0.29), leg);
    canvas.drawRect(
        Rect.fromLTWH(w * 0.16, h * 0.80, w * 0.68, h * 0.035), leg);

    // drawer under the desk top
    final drawer = Rect.fromLTRB(w * 0.36, h * 0.685, w * 0.64, h * 0.76);
    canvas.drawRRect(
      RRect.fromRectAndRadius(drawer, const Radius.circular(3)),
      Paint()..color = design.wood,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(drawer, const Radius.circular(3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = design.woodDark,
    );
    // drawer knob
    canvas.drawCircle(
      drawer.center,
      w * 0.010,
      Paint()..color = design.accent,
    );
  }

  // ------------------------------------------------------------ back panel

  void _paintBackPanel(Canvas canvas, double w, double h) {
    // instrument board standing at the back of the desk
    final panel = Rect.fromLTRB(w * 0.22, h * 0.26, w * 0.78, h * 0.62);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        panel,
        topLeft: Radius.circular(w * 0.035),
        topRight: Radius.circular(w * 0.035),
      ),
      bodyGradient(panel),
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        panel,
        topLeft: Radius.circular(w * 0.035),
        topRight: Radius.circular(w * 0.035),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, w * 0.005)
        ..color = design.woodDark,
    );
    paintTopLight(canvas, panel);

    // voltmeter dial on the panel
    final gaugeC = Offset(w * 0.5, h * 0.40);
    final gaugeR = w * 0.055;
    canvas.drawCircle(gaugeC, gaugeR, Paint()..color = design.paper);
    canvas.drawCircle(
      gaugeC,
      gaugeR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, w * 0.005)
        ..color = design.accent,
    );
    // gauge ticks
    final tick = Paint()
      ..strokeWidth = 1.2
      ..color = design.ink.withValues(alpha: 0.7);
    for (int i = 0; i <= 6; i++) {
      final a = pi * 0.75 + pi * 1.5 * i / 6;
      canvas.drawLine(
        Offset(gaugeC.dx + cos(a) * gaugeR * 0.72,
            gaugeC.dy + sin(a) * gaugeR * 0.72),
        Offset(gaugeC.dx + cos(a) * gaugeR * 0.86,
            gaugeC.dy + sin(a) * gaugeR * 0.86),
        tick,
      );
    }
    // needle: kicks with each key tap, settles at progress when idle
    final kick = holding ? 0.12 * sin(t * 2 * pi * 6) : 0.0;
    final needleA = pi * 0.75 + pi * 1.5 * (p + kick).clamp(0.0, 1.0);
    canvas.drawLine(
      gaugeC,
      Offset(gaugeC.dx + cos(needleA) * gaugeR * 0.68,
          gaugeC.dy + sin(needleA) * gaugeR * 0.68),
      Paint()
        ..strokeWidth = max(1.5, w * 0.005)
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFB03A2E),
    );
    canvas.drawCircle(gaugeC, gaugeR * 0.10, Paint()..color = design.accentDark);
  }

  // ---------------------------------------------------------------- coils

  void _paintCoils(Canvas canvas, double w, double h) {
    // two copper spark coils on the desk, left and right of the panel base
    for (final cx in [w * 0.315, w * 0.685]) {
      final coil = Rect.fromCenter(
        center: Offset(cx, h * 0.545),
        width: w * 0.075,
        height: h * 0.115,
      );
      // coil body (copper windings)
      canvas.drawRRect(
        RRect.fromRectAndRadius(coil, Radius.circular(w * 0.010)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [design.accentDark, design.accent, design.accentDark],
          ).createShader(coil),
      );
      // winding lines
      final wind = Paint()
        ..strokeWidth = 1.0
        ..color = design.accentDark.withValues(alpha: 0.65);
      for (int i = 1; i < 7; i++) {
        final y = coil.top + coil.height * i / 7;
        canvas.drawLine(Offset(coil.left, y), Offset(coil.right, y), wind);
      }
      // brass caps
      final cap = Paint()..color = design.accent;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx, coil.top - h * 0.008),
              width: coil.width * 1.15,
              height: h * 0.018),
          const Radius.circular(2),
        ),
        cap,
      );
      // electrode rod pointing inwards
      canvas.drawCircle(
          Offset(cx, coil.top - h * 0.025), w * 0.007, cap);
    }

    // spark arc between the two electrodes while holding
    if (holding) {
      final y = h * 0.545 - h * 0.115 / 2 - h * 0.025;
      final from = Offset(w * 0.315, y);
      final to = Offset(w * 0.685, y);
      final rnd = Random((t * 60).floor());
      final spark = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, w * 0.004)
        ..color = const Color(0xFFBFE3FF)
            .withValues(alpha: 0.5 + 0.5 * rnd.nextDouble());
      final path = Path()..moveTo(from.dx, from.dy);
      const segs = 6;
      for (int i = 1; i <= segs; i++) {
        final x = from.dx + (to.dx - from.dx) * i / segs;
        final jitter = (rnd.nextDouble() - 0.5) * h * 0.03;
        path.lineTo(x, y + (i == segs ? 0 : jitter));
      }
      canvas.drawPath(path, spark);
      // glow
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.012
          ..color = const Color(0xFF7FB8E8).withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  // ------------------------------------------------------------- morse key

  void _paintMorseKey(Canvas canvas, double w, double h) {
    // brass morse key on the front-left of the desk
    final baseRect = Rect.fromLTWH(w * 0.13, h * 0.585, w * 0.17, h * 0.035);
    canvas.drawRRect(
      RRect.fromRectAndRadius(baseRect, const Radius.circular(3)),
      Paint()..color = design.woodDark,
    );

    // key arm: presses down rhythmically while holding
    final tap = holding ? (sin(t * 2 * pi * 5) > 0.2 ? 1.0 : 0.0) : 0.0;
    final pivot = Offset(w * 0.165, h * 0.575);
    final tipY = h * (0.548 + 0.012 * tap);
    final arm = Paint()
      ..strokeWidth = max(2.5, w * 0.009)
      ..strokeCap = StrokeCap.round
      ..color = design.accent;
    canvas.drawLine(pivot, Offset(w * 0.275, tipY), arm);
    // pivot post
    canvas.drawCircle(pivot, w * 0.011, Paint()..color = design.accentDark);
    // round knob at the tip
    canvas.drawCircle(
      Offset(w * 0.275, tipY),
      w * 0.016,
      Paint()..color = design.baseDark,
    );
    canvas.drawCircle(
      Offset(w * 0.275, tipY - w * 0.004),
      w * 0.010,
      Paint()..color = design.baseLight,
    );
    // contact spark under the knob at the moment of tap
    if (holding && tap > 0.5) {
      canvas.drawCircle(
        Offset(w * 0.275, h * 0.585),
        w * 0.008,
        Paint()
          ..color = const Color(0xFFBFE3FF).withValues(alpha: 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  // ------------------------------------------------------------ tape reader

  void _paintTapeReader(Canvas canvas, double w, double h) {
    // tape reader box on the front-right of the desk
    final box = Rect.fromLTWH(w * 0.68, h * 0.545, w * 0.16, h * 0.075);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(4)),
      bodyGradient(box),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(4)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = design.accentDark,
    );
    // tape reel on top of the box; rotates while holding
    final reelC = Offset(box.center.dx, box.top - h * 0.030);
    paintGear(
      canvas,
      reelC,
      w * 0.032,
      teeth: 10,
      angle: holding ? t * 2 * pi * 1.5 : p * 2 * pi,
      toothDepth: 0.10,
      holeRatio: 0.3,
      spokes: 3,
    );
  }

  // ---------------------------------------------------------------- tape

  void _paintTape(Canvas canvas, double w, double h) {
    // punched paper tape running from the reader across the desk front
    final tapeH = h * 0.030;
    final y = h * 0.635 - tapeH / 2;
    // tape length grows with progress
    final startX = w * 0.70;
    final endX = startX - (w * 0.52) * (0.15 + 0.85 * p);
    final rect = Rect.fromLTRB(endX, y, startX, y + tapeH);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(tapeH / 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(tapeH / 2)),
      Paint()..color = design.paper,
    );

    // punched holes: scroll to the left while holding
    final scroll = holding ? t * w * 0.10 : 0.0;
    final hole = Paint()..color = design.ink.withValues(alpha: 0.8);
    final rnd = Random(9);
    final holeGap = w * 0.020;
    for (double x = rect.left + holeGap; x < rect.right - holeGap; x += holeGap) {
      final shifted = rect.left +
          ((x - rect.left + scroll) % (rect.width - holeGap * 2)) +
          holeGap;
      // random 2-row morse-ish hole pattern
      if (rnd.nextDouble() > 0.35) {
        canvas.drawCircle(
            Offset(shifted, rect.top + tapeH * 0.32), tapeH * 0.13, hole);
      }
      if (rnd.nextDouble() > 0.55) {
        canvas.drawCircle(
            Offset(shifted, rect.top + tapeH * 0.68), tapeH * 0.13, hole);
      }
    }
    // sprocket line in the middle
    final sprocket = Paint()..color = design.ink.withValues(alpha: 0.35);
    for (double x = rect.left + holeGap; x < rect.right - holeGap;
        x += holeGap * 1.5) {
      canvas.drawCircle(
          Offset(x, rect.top + tapeH * 0.5), tapeH * 0.06, sprocket);
    }
  }
}
