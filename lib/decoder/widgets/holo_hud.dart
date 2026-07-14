import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Sci-fi holographic HUD frame: animated corner brackets, scanline sweep,
/// side telemetry panels and a bottom hex-grid floor. Pure decoration layer.
class HoloHud extends StatefulWidget {
  final double progress; // 0..100
  final bool holding;
  final bool completed;
  const HoloHud({
    super.key,
    required this.progress,
    required this.holding,
    required this.completed,
  });

  @override
  State<HoloHud> createState() => _HoloHudState();
}

class _HoloHudState extends State<HoloHud>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _HudPainter(
            t: _t.value,
            progress: widget.progress,
            holding: widget.holding,
            completed: widget.completed,
          ),
        ),
      ),
    );
  }
}

class _HudPainter extends CustomPainter {
  final double t;
  final double progress;
  final bool holding;
  final bool completed;
  _HudPainter({
    required this.t,
    required this.progress,
    required this.holding,
    required this.completed,
  });

  Color get accent => completed ? AppColors.amber : AppColors.cyan;

  @override
  void paint(Canvas canvas, Size size) {
    _hexFloor(canvas, size);
    _cornerBrackets(canvas, size);
    _scanSweep(canvas, size);
    _sidePanels(canvas, size);
  }

  // Perspective hex-grid "floor" at the bottom.
  void _hexFloor(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final baseY = size.height;
    final horizon = size.height * 0.72;
    for (var row = 0; row < 6; row++) {
      final f = row / 6.0;
      final y = baseY - (baseY - horizon) * (1 - pow(1 - f, 1.8) as double);
      final alpha = (0.14 * (1 - f)) * (holding ? 1.6 : 1.0);
      paint.color = accent.withValues(alpha: alpha.clamp(0, 0.3));
      final hexW = 60.0 * (1 - f * 0.55);
      final shift = (t * hexW * (holding ? 2 : 1)) % hexW;
      for (double x = -hexW + shift - hexW; x < size.width + hexW; x += hexW) {
        final path = Path()
          ..moveTo(x, y)
          ..lineTo(x + hexW * 0.25, y - hexW * 0.16)
          ..lineTo(x + hexW * 0.75, y - hexW * 0.16)
          ..lineTo(x + hexW, y);
        canvas.drawPath(path, paint);
      }
    }
  }

  void _cornerBrackets(Canvas canvas, Size size) {
    final pulse = 0.55 + 0.45 * sin(t * 2 * pi * 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = accent.withValues(alpha: 0.35 + 0.25 * pulse);
    const m = 26.0; // margin
    final len = 46.0 + 8 * pulse;
    void bracket(double x, double y, int sx, int sy) {
      canvas.drawLine(Offset(x, y), Offset(x + len * sx, y), p);
      canvas.drawLine(Offset(x, y), Offset(x, y + len * sy), p);
      // small inner tick
      canvas.drawLine(Offset(x + 10.0 * sx, y + 10.0 * sy),
          Offset(x + (10 + 14) * sx.toDouble(), y + 10.0 * sy), p);
    }

    bracket(m, m, 1, 1);
    bracket(size.width - m, m, -1, 1);
    bracket(m, size.height - m, 1, -1);
    bracket(size.width - m, size.height - m, -1, -1);
  }

  // Horizontal scanline sweeping down the screen.
  void _scanSweep(Canvas canvas, Size size) {
    final y = (t * 1.3 % 1.0) * size.height;
    final grad = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: 0),
          accent.withValues(alpha: holding ? 0.10 : 0.05),
          accent.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, y - 40, size.width, 80));
    canvas.drawRect(Rect.fromLTWH(0, y - 40, size.width, 80), grad);
    canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()..color = accent.withValues(alpha: holding ? 0.14 : 0.07));
  }

  // Fake telemetry bars on left / right edges.
  void _sidePanels(Canvas canvas, Size size) {
    if (size.width < 900) return; // only on wide (PC) screens
    final rand = Random(42);
    final p = Paint();
    for (var side = 0; side < 2; side++) {
      final x = side == 0 ? 40.0 : size.width - 40.0 - 90.0;
      final top = size.height * 0.30;
      for (var i = 0; i < 10; i++) {
        final seedV = rand.nextDouble();
        final v = 0.2 +
            0.8 *
                ((sin(t * 2 * pi * (0.5 + seedV) + i) + 1) / 2) *
                (holding ? 1.0 : 0.6);
        final y = top + i * 22.0;
        p.color = accent.withValues(alpha: 0.10);
        canvas.drawRect(Rect.fromLTWH(x, y, 90, 6), p);
        p.color = accent.withValues(alpha: 0.35);
        canvas.drawRect(Rect.fromLTWH(x, y, 90 * v, 6), p);
      }
      // progress readout tick column
      final ticks = (progress / 100 * 24).round();
      for (var i = 0; i < 24; i++) {
        final y = top + 230 + i * 5.0;
        p.color = i < ticks
            ? accent.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.06);
        canvas.drawRect(
            Rect.fromLTWH(side == 0 ? x : x + 70, y, 20, 3), p);
      }
    }
  }

  @override
  bool shouldRepaint(_HudPainter old) =>
      old.t != t || old.progress != progress || old.holding != holding;
}

/// Title text with occasional horizontal-slice glitch.
class GlitchText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const GlitchText({super.key, required this.text, required this.style});

  @override
  State<GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<GlitchText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t;
  final _rand = Random();
  bool _glitching = false;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..addListener(() {
        // random glitch bursts
        final g = _rand.nextDouble() < 0.03;
        if (g != _glitching && mounted) setState(() => _glitching = g);
      })
      ..repeat();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Text(widget.text, style: widget.style);
    if (!_glitching) return base;
    final dx = (_rand.nextDouble() - 0.5) * 6;
    return Stack(
      children: [
        Transform.translate(
          offset: Offset(dx, 0),
          child: Text(widget.text,
              style: widget.style.copyWith(
                  color: AppColors.cyan.withValues(alpha: 0.8))),
        ),
        Transform.translate(
          offset: Offset(-dx, 1),
          child: Text(widget.text,
              style: widget.style.copyWith(
                  color: AppColors.blood.withValues(alpha: 0.8))),
        ),
        base,
      ],
    );
  }
}
