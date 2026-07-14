import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Full-screen gothic atmosphere: drifting fog blobs, floating dust
/// particles and a vignette. Painted with a single CustomPainter that
/// animates via [AnimationController] time value.
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
  final _rand = Random(7);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 60))
      ..repeat();
    for (int i = 0; i < 46; i++) {
      _dust.add(_Dust(
        x: _rand.nextDouble(),
        y: _rand.nextDouble(),
        size: 1.0 + _rand.nextDouble() * 2.4,
        speed: 0.15 + _rand.nextDouble() * 0.5,
        phase: _rand.nextDouble() * pi * 2,
      ));
    }
    for (int i = 0; i < 5; i++) {
      _fog.add(_Fog(
        x: _rand.nextDouble(),
        y: 0.3 + _rand.nextDouble() * 0.6,
        radius: 0.25 + _rand.nextDouble() * 0.35,
        speed: 0.008 + _rand.nextDouble() * 0.02,
        phase: _rand.nextDouble() * pi * 2,
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
  _Dust({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
  });
}

class _Fog {
  final double x, y, radius, speed, phase;
  _Fog({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.phase,
  });
}

class _AtmospherePainter extends CustomPainter {
  final double t;
  final List<_Dust> dust;
  final List<_Fog> fog;
  final bool intense;

  _AtmospherePainter({
    required this.t,
    required this.dust,
    required this.fog,
    required this.intense,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // base gradient
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.2),
        radius: 1.4,
        colors: [
          const Color(0xFF12121C),
          AppColors.bgDeep,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // fog blobs
    for (final f in fog) {
      final dx = (f.x + t * f.speed) % 1.4 - 0.2;
      final wobble = sin(t * 0.3 + f.phase) * 0.03;
      final center = Offset(dx * size.width, (f.y + wobble) * size.height);
      final r = f.radius * size.shortestSide;
      final paint = Paint()
        ..shader = RadialGradient(colors: [
          AppColors.violet.withValues(alpha: intense ? 0.05 : 0.03),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(center, r, paint);
    }

    // dust particles (drift up slowly)
    final speedMul = intense ? 2.0 : 1.0;
    for (final d in dust) {
      final yy = (d.y - t * 0.01 * d.speed * speedMul) % 1.0;
      final xx = d.x + sin(t * 0.4 * d.speed + d.phase) * 0.012;
      final alpha = 0.15 + 0.25 * (0.5 + 0.5 * sin(t * 0.9 + d.phase));
      final paint = Paint()
        ..color = (intense ? AppColors.cyan : AppColors.amber)
            .withValues(alpha: alpha * (intense ? 0.65 : 0.45));
      canvas.drawCircle(
          Offset(xx * size.width, yy * size.height), d.size, paint);
    }

    // vignette
    final vignette = Paint()
      ..shader = RadialGradient(
        radius: 1.15,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.55),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter old) => true;
}
