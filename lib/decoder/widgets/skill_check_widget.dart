import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../decoder_controller.dart';

/// Identity V style skill check: circular gauge with a sweeping needle
/// and a highlighted success zone. Pops in with a scale animation,
/// glows, and shows a bold "!" warning mark like the original game.
class SkillCheckWidget extends StatefulWidget {
  final SkillCheck skill;
  const SkillCheckWidget({super.key, required this.skill});

  @override
  State<SkillCheckWidget> createState() => _SkillCheckWidgetState();
}

class _SkillCheckWidgetState extends State<SkillCheckWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220))
      ..forward();
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _pop, curve: Curves.easeOutBack),
      child: SizedBox(
        width: 210,
        height: 210,
        child: CustomPaint(
          painter: _SkillPainter(widget.skill),
          child: Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.62),
                border: Border.all(
                  color: AppColors.bone.withValues(alpha: 0.55),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.blood.withValues(alpha: 0.35),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '!',
                    style: TextStyle(
                      color: AppColors.blood,
                      fontSize: 22,
                      height: 0.9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'SPACE',
                    style: TextStyle(
                      color: AppColors.bone.withValues(alpha: 0.9),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkillPainter extends CustomPainter {
  final SkillCheck skill;
  _SkillPainter(this.skill);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - 12;
    const startAngle = -pi / 2;

    // backdrop disc with soft red rim (danger)
    canvas.drawCircle(
      center,
      r + 9,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      center,
      r + 9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.blood.withValues(alpha: 0.35),
    );

    // track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      0,
      2 * pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color = Colors.white.withValues(alpha: 0.12),
    );

    // success zone (amber, glow underlay)
    final zoneStart = startAngle + skill.zoneStart * 2 * pi;
    final zoneSweep = skill.zoneWidth * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      zoneStart,
      zoneSweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..color = AppColors.amber.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      zoneStart,
      zoneSweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = AppColors.amber,
    );

    // perfect zone (bright white core)
    final perfectStart =
        skill.zoneStart + skill.zoneWidth / 2 - skill.zoneWidth * 0.18;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      startAngle + perfectStart * 2 * pi,
      skill.zoneWidth * 0.36 * 2 * pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );

    // needle with glowing trail
    final needleAngle = startAngle + skill.needle * 2 * pi;
    // trail (fading arc behind needle)
    const trail = 0.35;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      needleAngle - trail,
      trail,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..shader = ui.Gradient.sweep(
          center,
          [
            Colors.transparent,
            AppColors.blood.withValues(alpha: 0.45),
          ],
          [0.0, 1.0],
          TileMode.clamp,
          needleAngle - trail,
          needleAngle,
        ),
    );
    // needle line
    final tip = center + Offset(cos(needleAngle), sin(needleAngle)) * (r + 7);
    final base = center + Offset(cos(needleAngle), sin(needleAngle)) * (r - 18);
    canvas.drawLine(
      base,
      tip,
      Paint()
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = AppColors.blood.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawLine(
      base,
      tip,
      Paint()
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFF4A52),
    );
    canvas.drawCircle(
      tip,
      5,
      Paint()
        ..color = const Color(0xFFFF4A52)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(covariant _SkillPainter old) => true;
}
