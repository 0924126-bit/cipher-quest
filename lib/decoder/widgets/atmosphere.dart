import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Full-screen gothic atmosphere, Identity V manor style:
///  - deep gradient night sky + blood moon with halo
///  - drifting violet fog banks
///  - diagonal rain streaks
///  - random distant lightning flashes
///  - dead tree / iron fence silhouettes
///  - floating embers / dust
///  - film grain + heavy vignette
class AtmosphereBackground extends StatefulWidget {
  final bool intense; // true while decoding (more particles, faster)
  const AtmosphereBackground({super.key, this.intense = false});

  @override
  State<AtmosphereBackground> createState() => _AtmosphereBackgroundState();
}

class _AtmosphereBackgroundState extends State<AtmosphereBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final List<_Dust> _dust = [];
  final List<_Fog> _fog = [];
  final List<_Rain> _rain = [];
  final _rand = Random(7);

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 60))
          ..repeat();
    for (int i = 0; i < 52; i++) {
      _dust.add(_Dust(
        x: _rand.nextDouble(),
        y: _rand.nextDouble(),
        size: 1.0 + _rand.nextDouble() * 2.6,
        speed: 0.15 + _rand.nextDouble() * 0.5,
        phase: _rand.nextDouble() * pi * 2,
      ));
    }
    for (int i = 0; i < 6; i++) {
      _fog.add(_Fog(
        x: _rand.nextDouble(),
        y: 0.3 + _rand.nextDouble() * 0.6,
        radius: 0.25 + _rand.nextDouble() * 0.35,
        speed: 0.008 + _rand.nextDouble() * 0.02,
        phase: _rand.nextDouble() * pi * 2,
      ));
    }
    for (int i = 0; i < 60; i++) {
      _rain.add(_Rain(
        x: _rand.nextDouble(),
        y: _rand.nextDouble(),
        len: 0.02 + _rand.nextDouble() * 0.035,
        speed: 0.6 + _rand.nextDouble() * 0.7,
        alpha: 0.04 + _rand.nextDouble() * 0.09,
      ));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          painter: _AtmospherePainter(
            t: _ctrl.value * 60, // seconds
            dust: _dust,
            fog: _fog,
            rain: _rain,
            intense: widget.intense,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Dust {
  final double x, y, size, speed, phase;
  _Dust(
      {required this.x,
      required this.y,
      required this.size,
      required this.speed,
      required this.phase});
}

class _Fog {
  final double x, y, radius, speed, phase;
  _Fog(
      {required this.x,
      required this.y,
      required this.radius,
      required this.speed,
      required this.phase});
}

class _Rain {
  final double x, y, len, speed, alpha;
  _Rain(
      {required this.x,
      required this.y,
      required this.len,
      required this.speed,
      required this.alpha});
}

class _AtmospherePainter extends CustomPainter {
  final double t;
  final List<_Dust> dust;
  final List<_Fog> fog;
  final List<_Rain> rain;
  final bool intense;

  // cached silhouette path (rebuilt when size changes)
  static Path? _silhouette;
  static Size? _silhouetteSize;

  _AtmospherePainter({
    required this.t,
    required this.dust,
    required this.fog,
    required this.rain,
    required this.intense,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ---------- night sky gradient ----------
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        [
          const Color(0xFF16121F),
          const Color(0xFF0D0C15),
          AppColors.bgDeep,
        ],
        [0.0, 0.55, 1.0],
      );
    canvas.drawRect(Offset.zero & size, bgPaint);

    // ---------- distant lightning flash ----------
    // pseudo-random flash: a few frames every ~9 seconds
    final flashCycle = t % 9.0;
    if (flashCycle < 0.35) {
      final k = (1 - flashCycle / 0.35);
      final flicker = 0.5 + 0.5 * sin(flashCycle * 80);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = const Color(0xFF9FB4D8)
              .withValues(alpha: 0.05 * k * flicker),
      );
    }

    // ---------- blood moon ----------
    final moonC = Offset(size.width * 0.82, size.height * 0.16);
    final moonR = size.shortestSide * 0.075;
    final breathe = 0.9 + 0.1 * sin(t * 0.6);
    // halo layers
    canvas.drawCircle(
      moonC,
      moonR * 3.2,
      Paint()
        ..shader = ui.Gradient.radial(moonC, moonR * 3.2, [
          const Color(0xFF8C1F26).withValues(alpha: 0.14 * breathe),
          Colors.transparent,
        ]),
    );
    canvas.drawCircle(
      moonC,
      moonR * 1.5,
      Paint()
        ..color = const Color(0xFFB3232A).withValues(alpha: 0.28 * breathe)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, moonR * 0.7),
    );
    // moon disc
    canvas.drawCircle(
      moonC,
      moonR,
      Paint()
        ..shader = ui.Gradient.radial(
          moonC.translate(-moonR * 0.25, -moonR * 0.25),
          moonR * 1.3,
          [const Color(0xFFE07A6A), const Color(0xFF7E1C22)],
        ),
    );
    // moon craters
    final craterPaint = Paint()
      ..color = const Color(0xFF641419).withValues(alpha: 0.5);
    canvas.drawCircle(moonC.translate(moonR * 0.3, moonR * 0.1),
        moonR * 0.18, craterPaint);
    canvas.drawCircle(moonC.translate(-moonR * 0.2, moonR * 0.4),
        moonR * 0.12, craterPaint);
    canvas.drawCircle(moonC.translate(-moonR * 0.35, -moonR * 0.3),
        moonR * 0.10, craterPaint);
    // thin cloud drifting across moon
    final cloudX = ((t * 0.012) % 1.6 - 0.3) * size.width;
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cloudX, moonC.dy + moonR * 0.2),
          width: size.width * 0.34,
          height: moonR * 1.1),
      Paint()
        ..color = const Color(0xFF0A0A12).withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, moonR * 0.5),
    );

    // ---------- fog banks ----------
    for (final f in fog) {
      final dx = (f.x + t * f.speed) % 1.4 - 0.2;
      final wobble = sin(t * 0.3 + f.phase) * 0.03;
      final center = Offset(dx * size.width, (f.y + wobble) * size.height);
      final r = f.radius * size.shortestSide;
      final paint = Paint()
        ..shader = ui.Gradient.radial(center, r, [
          AppColors.violet.withValues(alpha: intense ? 0.055 : 0.035),
          Colors.transparent,
        ]);
      canvas.drawCircle(center, r, paint);
    }

    // ---------- silhouettes: dead trees + iron fence ----------
    if (_silhouette == null || _silhouetteSize != size) {
      _silhouette = _buildSilhouette(size);
      _silhouetteSize = size;
    }
    canvas.drawPath(
      _silhouette!,
      Paint()..color = const Color(0xFF060609).withValues(alpha: 0.92),
    );

    // ---------- rain ----------
    final rainPaint = Paint()..strokeWidth = 1.1;
    for (final r0 in rain) {
      final yy = (r0.y + t * 0.22 * r0.speed) % 1.1;
      final xx = (r0.x - yy * 0.10) % 1.0;
      final p1 = Offset(xx * size.width, yy * size.height);
      final p2 = Offset(p1.dx - size.height * r0.len * 0.12,
          p1.dy + size.height * r0.len);
      rainPaint.color =
          const Color(0xFF9FB4D8).withValues(alpha: r0.alpha);
      canvas.drawLine(p1, p2, rainPaint);
    }

    // ---------- embers / dust ----------
    final speedMul = intense ? 2.0 : 1.0;
    for (final d in dust) {
      final yy = (d.y - t * 0.01 * d.speed * speedMul) % 1.0;
      final xx = d.x + sin(t * 0.4 * d.speed + d.phase) * 0.012;
      final alpha = 0.15 + 0.25 * (0.5 + 0.5 * sin(t * 0.9 + d.phase));
      final paint = Paint()
        ..color = (intense ? AppColors.cyan : AppColors.amber)
            .withValues(alpha: alpha * (intense ? 0.7 : 0.45));
      canvas.drawCircle(
          Offset(xx * size.width, yy * size.height), d.size, paint);
    }

    // ---------- film grain ----------
    final grainRand = Random((t * 24).floor());
    final grainPaint = Paint();
    for (int i = 0; i < 90; i++) {
      grainPaint.color = Colors.white
          .withValues(alpha: 0.015 + grainRand.nextDouble() * 0.03);
      canvas.drawCircle(
        Offset(grainRand.nextDouble() * size.width,
            grainRand.nextDouble() * size.height),
        grainRand.nextDouble() * 1.1,
        grainPaint,
      );
    }

    // ---------- vignette ----------
    final vignette = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height / 2),
        size.longestSide * 0.72,
        [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.62),
        ],
        [0.55, 1.0],
      );
    canvas.drawRect(Offset.zero & size, vignette);
  }

  /// Dead trees on both sides + spiked iron fence along the bottom.
  Path _buildSilhouette(Size size) {
    final path = Path();
    final rand = Random(11);

    // --- iron fence along bottom ---
    final fenceTop = size.height * 0.955;
    path.addRect(Rect.fromLTRB(
        0, size.height * 0.985, size.width, size.height));
    // horizontal rail
    path.addRect(Rect.fromLTRB(
        0, fenceTop + 8, size.width, fenceTop + 12));
    final spikes = (size.width / 46).ceil();
    for (int i = 0; i < spikes; i++) {
      final x = i * 46.0 + 10;
      // post
      path.addRect(Rect.fromLTRB(
          x - 2, fenceTop, x + 2, size.height));
      // spearhead
      path.moveTo(x - 5, fenceTop + 2);
      path.lineTo(x, fenceTop - 12);
      path.lineTo(x + 5, fenceTop + 2);
      path.close();
    }

    // --- dead trees (recursive branches) ---
    void branch(double x, double y, double angle, double len, double w,
        int depth) {
      if (depth <= 0 || len < 6) return;
      final ex = x + cos(angle) * len;
      final ey = y + sin(angle) * len;
      // draw branch as thin quad
      final nx = cos(angle + pi / 2);
      final ny = sin(angle + pi / 2);
      path.moveTo(x + nx * w, y + ny * w);
      path.lineTo(ex + nx * w * 0.6, ey + ny * w * 0.6);
      path.lineTo(ex - nx * w * 0.6, ey - ny * w * 0.6);
      path.lineTo(x - nx * w, y - ny * w);
      path.close();
      final n = 2 + rand.nextInt(2);
      for (int i = 0; i < n; i++) {
        branch(
          ex,
          ey,
          angle + (rand.nextDouble() - 0.5) * 1.3,
          len * (0.62 + rand.nextDouble() * 0.18),
          w * 0.65,
          depth - 1,
        );
      }
    }

    // left tree
    branch(size.width * 0.045, size.height * 1.0, -pi / 2 - 0.15,
        size.height * 0.16, 7, 6);
    // right tree
    branch(size.width * 0.965, size.height * 1.0, -pi / 2 + 0.2,
        size.height * 0.13, 6, 6);

    return path;
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter old) => true;
}
