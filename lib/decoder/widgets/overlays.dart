import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Red flash + lightning bolts + chromatic edges when a skill check is missed.
class ShockOverlay extends StatefulWidget {
  const ShockOverlay({super.key});

  @override
  State<ShockOverlay> createState() => _ShockOverlayState();
}

class _ShockOverlayState extends State<ShockOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final v = _ctrl.value;
          final flash = (1 - v) * (0.5 + 0.5 * sin(v * 40));
          return Stack(
            fit: StackFit.expand,
            children: [
              // red flash
              Container(
                  color: AppColors.blood
                      .withValues(alpha: (flash * 0.35).clamp(0.0, 0.35))),
              // red edge vignette (danger pulse)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.1,
                    colors: [
                      Colors.transparent,
                      AppColors.blood
                          .withValues(alpha: (0.4 * (1 - v)).clamp(0, 0.4)),
                    ],
                    stops: const [0.6, 1.0],
                  ),
                ),
              ),
              CustomPaint(
                painter: _LightningPainter(progress: v),
              ),
              // "MISS" stamp
              if (v < 0.55)
                Align(
                  alignment: const Alignment(0, -0.15),
                  child: Transform.rotate(
                    angle: -0.12,
                    child: Opacity(
                      opacity: (1 - v / 0.55).clamp(0, 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AppColors.blood, width: 3),
                        ),
                        child: const Text(
                          'MISS',
                          style: TextStyle(
                            color: AppColors.blood,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LightningPainter extends CustomPainter {
  final double progress;
  _LightningPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress > 0.7) return;
    final rand = Random((progress * 12).floor());
    for (int i = 0; i < 4; i++) {
      final x0 = rand.nextDouble() * size.width;
      final path = Path()..moveTo(x0, 0);
      var x = x0;
      var y = 0.0;
      while (y < size.height) {
        y += 30 + rand.nextDouble() * 60;
        x += (rand.nextDouble() - 0.5) * 90;
        path.lineTo(x, y);
        // occasional fork
        if (rand.nextDouble() < 0.25) {
          final fx = x + (rand.nextDouble() - 0.5) * 120;
          final fy = y + 40 + rand.nextDouble() * 60;
          path.moveTo(x, y);
          path.lineTo(fx, fy);
          path.moveTo(x, y);
        }
      }
      // glow pass
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = AppColors.blood.withValues(alpha: 0.35 * (1 - progress))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = Colors.white.withValues(alpha: 0.85 * (1 - progress)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LightningPainter old) => true;
}

/// Golden particle burst + rotating rays + cinematic DECODED banner
/// shown when decoding reaches 100%.
class CompletedOverlay extends StatefulWidget {
  final String machineName;
  const CompletedOverlay({super.key, required this.machineName});

  @override
  State<CompletedOverlay> createState() => _CompletedOverlayState();
}

class _CompletedOverlayState extends State<CompletedOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _loop; // continuous rays / shimmer
  late final AnimationController _burst; // one-shot particle explosion
  final List<_Ray> _rays = [];
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _loop =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();
    _burst = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..forward();
    final rand = Random(3);
    for (int i = 0; i < 24; i++) {
      _rays.add(_Ray(
        angle: rand.nextDouble() * 2 * pi,
        length: 0.4 + rand.nextDouble() * 0.6,
        width: 1 + rand.nextDouble() * 3,
        speed: 0.5 + rand.nextDouble(),
      ));
    }
    for (int i = 0; i < 90; i++) {
      final a = rand.nextDouble() * 2 * pi;
      _particles.add(_Particle(
        angle: a,
        speed: 0.25 + rand.nextDouble() * 0.9,
        size: 1.5 + rand.nextDouble() * 3.5,
        drift: (rand.nextDouble() - 0.5) * 0.6,
        gold: rand.nextDouble() < 0.75,
        delay: rand.nextDouble() * 0.25,
      ));
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // white flash at the instant of completion
          AnimatedBuilder(
            animation: _burst,
            builder: (context, _) {
              final v = _burst.value;
              final flash = v < 0.12 ? (1 - v / 0.12) : 0.0;
              return Container(
                  color: Colors.white.withValues(alpha: flash * 0.35));
            },
          ),
          AnimatedBuilder(
            animation: Listenable.merge([_loop, _burst]),
            builder: (context, _) => CustomPaint(
              painter: _CelebrationPainter(
                t: _loop.value,
                burst: _burst.value,
                rays: _rays,
                particles: _particles,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 340),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutBack,
                  builder: (context, v, child) => Transform.scale(
                    scale: v,
                    child: Opacity(opacity: v.clamp(0, 1), child: child),
                  ),
                  child: Column(
                    children: [
                      // ornamental frame around DECODED
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 36, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                                color:
                                    AppColors.amber.withValues(alpha: 0.6),
                                width: 1),
                            bottom: BorderSide(
                                color:
                                    AppColors.amber.withValues(alpha: 0.6),
                                width: 1),
                          ),
                        ),
                        child: Text(
                          'DECODED',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 14,
                            color: AppColors.amber,
                            shadows: [
                              Shadow(
                                color:
                                    AppColors.amber.withValues(alpha: 0.8),
                                blurRadius: 26,
                              ),
                              const Shadow(
                                color: Colors.black,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${widget.machineName} の解読が完了しました',
                        style: const TextStyle(
                          color: AppColors.bone,
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Ray {
  final double angle, length, width, speed;
  _Ray(
      {required this.angle,
      required this.length,
      required this.width,
      required this.speed});
}

class _Particle {
  final double angle, speed, size, drift, delay;
  final bool gold;
  _Particle(
      {required this.angle,
      required this.speed,
      required this.size,
      required this.drift,
      required this.gold,
      required this.delay});
}

class _CelebrationPainter extends CustomPainter {
  final double t; // loop 0..1
  final double burst; // one-shot 0..1
  final List<_Ray> rays;
  final List<_Particle> particles;

  _CelebrationPainter({
    required this.t,
    required this.burst,
    required this.rays,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide * 0.5;

    // pulsing golden glow
    final pulse = 0.5 + 0.5 * sin(t * 2 * pi);
    canvas.drawCircle(
      center,
      maxR * 0.5,
      Paint()
        ..color = AppColors.amber.withValues(alpha: 0.10 + pulse * 0.08)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, maxR * 0.25),
    );

    // expanding shockwave ring (one-shot)
    if (burst < 0.6) {
      final wave = Curves.easeOut.transform(burst / 0.6);
      canvas.drawCircle(
        center,
        maxR * (0.3 + wave * 1.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - wave)
          ..color = AppColors.amber.withValues(alpha: 0.5 * (1 - wave)),
      );
    }

    // rotating light rays
    for (final ray in rays) {
      final a = ray.angle + t * 2 * pi * 0.08 * ray.speed;
      final start = center + Offset(cos(a), sin(a)) * maxR * 0.25;
      final end = center + Offset(cos(a), sin(a)) * maxR * (0.35 + ray.length);
      canvas.drawLine(
        start,
        end,
        Paint()
          ..strokeWidth = ray.width
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(start, end, [
            AppColors.amber.withValues(alpha: 0.5),
            Colors.transparent,
          ]),
      );
    }

    // golden particle explosion (one-shot, gravity + drift)
    for (final p in particles) {
      final local = ((burst - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final eased = Curves.easeOutCubic.transform(local);
      final dist = maxR * 0.15 + maxR * 1.1 * eased * p.speed;
      final gravity = maxR * 0.35 * local * local;
      final pos = center +
          Offset(cos(p.angle) + p.drift * local, sin(p.angle)) * dist +
          Offset(0, gravity);
      final alpha = (1 - local) * 0.9;
      final color = p.gold
          ? AppColors.amber
          : Colors.white;
      canvas.drawCircle(
        pos,
        p.size * (1 - local * 0.5),
        Paint()..color = color.withValues(alpha: alpha),
      );
      // tiny glint cross on larger particles
      if (p.size > 3.5 && local < 0.6) {
        final g = Paint()
          ..strokeWidth = 1
          ..color = color.withValues(alpha: alpha * 0.7);
        canvas.drawLine(pos.translate(-p.size * 2, 0),
            pos.translate(p.size * 2, 0), g);
        canvas.drawLine(pos.translate(0, -p.size * 2),
            pos.translate(0, p.size * 2), g);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter old) => true;
}
