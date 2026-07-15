import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Quiet workshop backdrop for the decoder page.
///
/// Deliberately simple: a dark vignette room, a few faint gear silhouettes
/// on the wall, and slow-drifting dust motes. No stars, no neon.
class WorkshopBackground extends StatefulWidget {
  /// Slightly warms the light while the player is decoding.
  final bool active;

  const WorkshopBackground({super.key, this.active = false});

  @override
  State<WorkshopBackground> createState() => _WorkshopBackgroundState();
}

class _WorkshopBackgroundState extends State<WorkshopBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
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
          painter: _WorkshopPainter(t: _anim.value, active: widget.active),
          size: Size.infinite,
        );
      },
    );
  }
}

class _WorkshopPainter extends CustomPainter {
  final double t;
  final bool active;

  _WorkshopPainter({required this.t, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _paintRoom(canvas, w, h);
    _paintGears(canvas, w, h);
    _paintFloor(canvas, w, h);
    _paintDust(canvas, w, h);
    _paintVignette(canvas, w, h);
  }

  /// Base room gradient with a soft warm pool of light in the center.
  void _paintRoom(Canvas canvas, double w, double h) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bg, AppColors.bgDeep],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // central lantern light, slightly stronger while decoding
    final strength = active ? 0.10 : 0.06;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.05),
          radius: 0.9,
          colors: [
            AppColors.amber.withValues(alpha: strength),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  /// Faint gear silhouettes on the back wall (static, very low contrast).
  void _paintGears(Canvas canvas, double w, double h) {
    final gearColor = Colors.white.withValues(alpha: 0.028);
    // gears: (cx, cy, radius, teeth) in fractions
    const gears = [
      (0.82, 0.24, 0.13, 10),
      (0.90, 0.44, 0.08, 8),
      (0.10, 0.62, 0.10, 9),
    ];
    // very slow rotation so the wall feels alive but not busy
    final spin = t * 2 * pi;
    for (final (cx, cy, rr, teeth) in gears) {
      _drawGear(
        canvas,
        Offset(w * cx, h * cy),
        w * rr,
        teeth,
        spin * 0.15,
        gearColor,
      );
    }
  }

  void _drawGear(
    Canvas canvas,
    Offset c,
    double r,
    int teeth,
    double angle,
    Color color,
  ) {
    final paint = Paint()..color = color;
    final path = Path();
    final inner = r * 0.82;
    for (int i = 0; i < teeth * 2; i++) {
      final a = angle + pi * i / teeth;
      final rad = i.isEven ? r : inner;
      final p = Offset(c.dx + cos(a) * rad, c.dy + sin(a) * rad);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
    // hollow center
    canvas.drawCircle(c, r * 0.30, Paint()..color = AppColors.bg);
    canvas.drawCircle(
      c,
      r * 0.30,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..color = color,
    );
  }

  /// Simple floor plane hint - a horizontal line with darker area below.
  void _paintFloor(Canvas canvas, double w, double h) {
    final floorY = h * 0.86;
    canvas.drawRect(
      Rect.fromLTWH(0, floorY, w, h - floorY),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );
    canvas.drawLine(
      Offset(0, floorY),
      Offset(w, floorY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.04)
        ..strokeWidth = 1,
    );
  }

  /// Slow drifting dust motes in the lantern light.
  void _paintDust(Canvas canvas, double w, double h) {
    final rnd = Random(11);
    const count = 26;
    for (int i = 0; i < count; i++) {
      final baseX = rnd.nextDouble();
      final baseY = rnd.nextDouble();
      final speed = 0.3 + rnd.nextDouble() * 0.7;
      final phase = rnd.nextDouble();

      final y = (baseY - t * speed * 0.15 + phase) % 1.0;
      final x = baseX + 0.015 * sin((t * 2 * pi + phase * 6) * speed);
      final alpha = 0.05 + 0.05 * sin((t + phase) * 2 * pi);

      canvas.drawCircle(
        Offset(x * w, y * h),
        0.8 + rnd.nextDouble() * 1.2,
        Paint()..color = AppColors.bone.withValues(alpha: alpha.clamp(0.0, 1.0)),
      );
    }
  }

  /// Dark edges to focus the eye on the machine.
  void _paintVignette(Canvas canvas, double w, double h) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = RadialGradient(
          radius: 1.1,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.55),
          ],
          stops: const [0.55, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  @override
  bool shouldRepaint(covariant _WorkshopPainter old) =>
      old.t != t || old.active != active;
}
