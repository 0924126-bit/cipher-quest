import 'dart:math';

import 'package:flutter/material.dart';

import 'painter_common.dart';

/// Enigma-style rotor cipher machine in a wooden field case:
/// open lid at the back, 3 brass rotors on top, a lamp board that
/// flickers while decoding, and a plug board with patch cables.
///
/// - idle      : rotors still, lamps dark
/// - holding   : rotors step (right fastest), lamps flicker, plugs sway
/// - completed : all lamps calm green glow
class RotorPainter extends MachinePainter {
  RotorPainter({
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

    paintGroundShadow(canvas, size, widthFactor: 0.8);

    // wooden case body
    final caseRect = Rect.fromLTRB(w * 0.13, h * 0.40, w * 0.87, h * 0.96);
    _paintCase(canvas, caseRect, w, h);

    // open lid leaning back
    _paintLid(canvas, w, h);

    // rotor window strip
    _paintRotors(canvas, w, h);

    // lamp board (5x3 grid)
    _paintLampBoard(canvas, w, h);

    // plug board with cables
    _paintPlugBoard(canvas, w, h);

    // status lamp on the case's right edge
    paintLamp(canvas, Offset(w * 0.815, h * 0.455), w * 0.015);
  }

  // ---------------------------------------------------------------- case

  void _paintCase(Canvas canvas, Rect r, double w, double h) {
    // outer wooden box
    final box = RRect.fromRectAndRadius(r, Radius.circular(w * 0.015));
    canvas.drawRRect(
      box.shift(const Offset(2, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(
      box,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [design.wood, design.woodDark],
        ).createShader(r),
    );
    // wood edge trim
    canvas.drawRRect(
      box.deflate(w * 0.006),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, w * 0.004)
        ..color = design.woodDark,
    );

    // inner steel deck
    final deck = Rect.fromLTRB(
        r.left + w * 0.025, r.top + h * 0.025, r.right - w * 0.025,
        r.bottom - h * 0.03);
    canvas.drawRRect(
      RRect.fromRectAndRadius(deck, Radius.circular(w * 0.01)),
      bodyGradient(deck),
    );
    paintTopLight(canvas, deck, alpha: 0.06);

    // corner screws on the deck
    final screw = Paint()..color = design.accent.withValues(alpha: 0.6);
    final sr = w * 0.007;
    for (final pos in [
      Offset(deck.left + sr * 3, deck.top + sr * 3),
      Offset(deck.right - sr * 3, deck.top + sr * 3),
      Offset(deck.left + sr * 3, deck.bottom - sr * 3),
      Offset(deck.right - sr * 3, deck.bottom - sr * 3),
    ]) {
      canvas.drawCircle(pos, sr, screw);
    }

    // case handle on the front
    final handle = Rect.fromCenter(
      center: Offset(r.center.dx, r.bottom - h * 0.012),
      width: w * 0.16,
      height: h * 0.018,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(handle, Radius.circular(handle.height / 2)),
      Paint()..color = design.woodDark,
    );
  }

  // ---------------------------------------------------------------- lid

  void _paintLid(Canvas canvas, double w, double h) {
    // lid leaning back behind the case (perspective trapezoid)
    final path = Path()
      ..moveTo(w * 0.20, h * 0.405)
      ..lineTo(w * 0.80, h * 0.405)
      ..lineTo(w * 0.74, h * 0.13)
      ..lineTo(w * 0.26, h * 0.13)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [design.wood, design.woodDark],
        ).createShader(Rect.fromLTRB(w * 0.2, h * 0.13, w * 0.8, h * 0.405)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, w * 0.005)
        ..color = design.woodDark,
    );

    // inner lid panel with an operator card
    final card = Rect.fromLTRB(w * 0.33, h * 0.17, w * 0.67, h * 0.35);
    canvas.drawRRect(
      RRect.fromRectAndRadius(card, const Radius.circular(3)),
      Paint()..color = design.paper.withValues(alpha: 0.9),
    );
    // instruction sheet scribbles; fills up with progress
    paintCipherText(canvas, card.deflate(h * 0.012),
        fillRatio: 0.4 + 0.6 * p, seed: 11);

    // hinges
    final hinge = Paint()..color = design.accent.withValues(alpha: 0.8);
    for (final x in [w * 0.30, w * 0.70]) {
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset(x, h * 0.405), width: w * 0.035, height: h * 0.012),
        hinge,
      );
    }
  }

  // ---------------------------------------------------------------- rotors

  void _paintRotors(Canvas canvas, double w, double h) {
    // recessed rotor window strip
    final strip = Rect.fromLTRB(w * 0.24, h * 0.445, w * 0.76, h * 0.545);
    canvas.drawRRect(
      RRect.fromRectAndRadius(strip, Radius.circular(w * 0.008)),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    // 3 rotors; the right one steps fastest, like a real stepping motion
    final speeds = [0.25, 0.5, 2.0];
    for (int i = 0; i < 3; i++) {
      final cx = w * (0.325 + i * 0.175);
      final rotor = Rect.fromCenter(
        center: Offset(cx, strip.center.dy),
        width: w * 0.115,
        height: strip.height * 0.82,
      );

      // brass rotor wheel
      canvas.drawRRect(
        RRect.fromRectAndRadius(rotor, Radius.circular(w * 0.006)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [design.accent, design.accentDark, design.accent],
          ).createShader(rotor),
      );

      // rolling number band: ticks scroll vertically while holding
      final phase = holding ? (t * speeds[i]) % 1.0 : (p * (i + 1)) % 1.0;
      final tick = Paint()
        ..strokeWidth = max(1.0, h * 0.004)
        ..color = design.baseDark.withValues(alpha: 0.85);
      const tickCount = 4;
      for (int k = 0; k < tickCount; k++) {
        final ty = rotor.top +
            ((k / tickCount + phase) % 1.0) * rotor.height;
        canvas.drawLine(
          Offset(rotor.left + rotor.width * 0.22, ty),
          Offset(rotor.right - rotor.width * 0.22, ty),
          tick,
        );
      }

      // center index window
      final win = Rect.fromCenter(
        center: rotor.center,
        width: rotor.width * 0.52,
        height: rotor.height * 0.30,
      );
      canvas.drawRect(win, Paint()..color = design.paper);
      canvas.drawRect(
        win,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = design.accentDark,
      );
      // indicator dot inside the window (moves while stepping)
      canvas.drawCircle(
        Offset(win.left + win.width * ((phase * 3) % 1.0),
            win.center.dy),
        win.height * 0.16,
        Paint()..color = design.ink.withValues(alpha: 0.8),
      );

      // knurled edges
      final knurl = Paint()
        ..strokeWidth = 1.0
        ..color = design.accentDark.withValues(alpha: 0.7);
      for (int k = 0; k <= 6; k++) {
        final ty = rotor.top + rotor.height * k / 6;
        canvas.drawLine(Offset(rotor.left, ty),
            Offset(rotor.left + rotor.width * 0.12, ty), knurl);
        canvas.drawLine(Offset(rotor.right - rotor.width * 0.12, ty),
            Offset(rotor.right, ty), knurl);
      }
    }
  }

  // ------------------------------------------------------------ lamp board

  void _paintLampBoard(Canvas canvas, double w, double h) {
    const cols = 8;
    const rows = 2;
    final left = w * 0.26;
    final right = w * 0.74;
    final top = h * 0.60;
    final gapY = h * 0.055;

    final rnd = Random(3);
    final litIndex =
        holding ? (t * cols * rows * 2).floor() % (cols * rows) : -1;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final idx = r * cols + c;
        final cx = left + (right - left) * c / (cols - 1);
        final cy = top + r * gapY;
        final lampR = w * 0.014;

        // lamp is lit if: currently stepping onto it, or completed (all on)
        final flicker = rnd.nextDouble();
        final lit = completed ||
            idx == litIndex ||
            (holding && flicker > 0.93);

        final color = completed ? design.lampDone : design.lampActive;
        if (lit) {
          canvas.drawCircle(
            Offset(cx, cy),
            lampR * 2.2,
            Paint()
              ..color = color.withValues(alpha: 0.30)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          );
        }
        canvas.drawCircle(Offset(cx, cy), lampR * 1.25,
            Paint()..color = design.baseDark);
        canvas.drawCircle(
          Offset(cx, cy),
          lampR,
          Paint()
            ..color =
                lit ? color : design.accentDark.withValues(alpha: 0.55),
        );
      }
    }
  }

  // ------------------------------------------------------------ plug board

  void _paintPlugBoard(Canvas canvas, double w, double h) {
    const cols = 10;
    final left = w * 0.24;
    final right = w * 0.76;
    final y = h * 0.80;

    // socket row
    final socket = Paint()..color = design.baseDark;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = design.accent.withValues(alpha: 0.55);
    for (int c = 0; c < cols; c++) {
      final cx = left + (right - left) * c / (cols - 1);
      canvas.drawCircle(Offset(cx, y), w * 0.010, socket);
      canvas.drawCircle(Offset(cx, y), w * 0.010, ring);
    }

    // 3 patch cables drooping between socket pairs; sway while holding
    final sway = holding ? sin(t * 2 * pi) * h * 0.008 : 0.0;
    final cable = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = max(2.0, w * 0.007)
      ..color = design.accentDark;
    const pairs = [(0, 4), (2, 7), (5, 9)];
    for (final (a, b) in pairs) {
      final ax = left + (right - left) * a / (cols - 1);
      final bx = left + (right - left) * b / (cols - 1);
      final droop = h * 0.06 + (b - a) * h * 0.006;
      final path = Path()
        ..moveTo(ax, y)
        ..quadraticBezierTo(
            (ax + bx) / 2, y + droop + sway, bx, y);
      canvas.drawPath(path, cable);
      // plug tips
      final tip = Paint()..color = design.accent;
      canvas.drawCircle(Offset(ax, y), w * 0.006, tip);
      canvas.drawCircle(Offset(bx, y), w * 0.006, tip);
    }
  }
}
