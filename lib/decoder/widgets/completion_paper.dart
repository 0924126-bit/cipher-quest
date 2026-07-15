import 'dart:math';

import 'package:flutter/material.dart';

import 'machine_designs.dart';

/// "解読完了" paper fly-in effect.
///
/// When decoding completes, a cipher sheet shoots out of the machine,
/// flutters up toward the viewer while swaying like real paper, then
/// settles at screen center where a red "解読完了" stamp slams onto it.
///
/// Timeline (total ~2.6s):
///   0.00 - 0.35 : launch   - pops out of the machine, small and spinning
///   0.35 - 0.70 : flight   - sways left/right (decaying sine), scales up
///   0.70 - 0.85 : settle   - eases into its final tilt
///   0.78 - 1.00 : stamp    - red seal punches in with an impact ring
class CompletionPaper extends StatefulWidget {
  final MachineDesign design;

  const CompletionPaper({super.key, required this.design});

  @override
  State<CompletionPaper> createState() => _CompletionPaperState();
}

class _CompletionPaperState extends State<CompletionPaper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // paper size relative to the screen (portrait-ish sheet)
    final paperW = (size.shortestSide * 0.46).clamp(220.0, 360.0);
    final paperH = paperW * 1.30;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final v = _anim.value;

        // ---- flight path -------------------------------------------------
        // vertical: rises from the machine (below center) to center
        final rise = Curves.easeOutCubic
            .transform(((v) / 0.75).clamp(0.0, 1.0));
        final dy = size.height * 0.28 * (1 - rise);

        // horizontal sway: paper flutters side to side, decaying
        final sway = sin(v * pi * 3.2) * size.width * 0.045 * (1 - v);

        // scale: pops out small, grows as it approaches the viewer
        final scale = 0.18 +
            0.82 * Curves.easeOutBack
                .transform((v / 0.8).clamp(0.0, 1.0));

        // rotation: strong initial spin settling into a slight tilt
        final wobble = sin(v * pi * 4) * 0.25 * (1 - v);
        final tilt = -0.05; // final resting tilt (radians)
        final rot = wobble + tilt * Curves.easeOut.transform(v);

        // fade in quickly at launch
        final opacity = (v / 0.10).clamp(0.0, 1.0);

        // ---- stamp -------------------------------------------------------
        // red seal punches in at 78%
        final stampT =
            Curves.elasticOut.transform(((v - 0.78) / 0.22).clamp(0.0, 1.0));
        final stampVisible = v >= 0.78;
        // impact ring expands right after the stamp lands
        final ringT = ((v - 0.80) / 0.20).clamp(0.0, 1.0);

        return IgnorePointer(
          child: Center(
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(sway, dy),
                child: Transform.rotate(
                  angle: rot,
                  child: Transform.scale(
                    scale: scale,
                    child: SizedBox(
                      width: paperW,
                      height: paperH,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // paper sheet with scribbles
                          CustomPaint(
                            size: Size(paperW, paperH),
                            painter: _PaperSheetPainter(design: widget.design),
                          ),
                          // stamp impact ring
                          if (stampVisible && ringT < 1.0)
                            Center(
                              child: Container(
                                width: paperW * (0.5 + 0.9 * ringT),
                                height: paperW * (0.5 + 0.9 * ringT),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFB03A2E)
                                        .withValues(alpha: 0.5 * (1 - ringT)),
                                    width: 3 * (1 - ringT) + 0.5,
                                  ),
                                ),
                              ),
                            ),
                          // red "解読完了" seal
                          if (stampVisible)
                            Center(
                              child: Transform.rotate(
                                angle: -0.12,
                                child: Transform.scale(
                                  // slams from large to resting size
                                  scale: 2.2 - 1.2 * stampT,
                                  child: Opacity(
                                    opacity: stampT.clamp(0.0, 1.0),
                                    child: _StampSeal(size: paperW * 0.62),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The red rubber-stamp style "解読完了" seal.
class _StampSeal extends StatelessWidget {
  final double size;

  const _StampSeal({required this.size});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFB03A2E);
    return Container(
      width: size,
      padding: EdgeInsets.symmetric(vertical: size * 0.055),
      decoration: BoxDecoration(
        border: Border.all(color: red, width: size * 0.022),
        borderRadius: BorderRadius.circular(size * 0.05),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '解読完了',
            style: TextStyle(
              fontSize: size * 0.20,
              fontWeight: FontWeight.w800,
              letterSpacing: size * 0.020,
              color: red,
              height: 1.1,
            ),
          ),
          SizedBox(height: size * 0.02),
          Text(
            'DECODED',
            style: TextStyle(
              fontSize: size * 0.065,
              fontWeight: FontWeight.w600,
              letterSpacing: size * 0.030,
              color: red.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the aged cipher sheet: slightly torn edges, fold crease,
/// cipher scribble lines, and a small corner mark.
class _PaperSheetPainter extends CustomPainter {
  final MachineDesign design;

  _PaperSheetPainter({required this.design});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rnd = Random(17);

    // ---- sheet silhouette with subtly irregular (torn) edges ----
    final path = Path();
    const steps = 14;
    Offset jitter(double x, double y, double amp) =>
        Offset(x + (rnd.nextDouble() - 0.5) * amp,
            y + (rnd.nextDouble() - 0.5) * amp);
    path.moveTo(0, 0);
    for (int i = 1; i <= steps; i++) {
      final p = jitter(w * i / steps, 0, w * 0.008);
      path.lineTo(p.dx, p.dy);
    }
    for (int i = 1; i <= steps; i++) {
      final p = jitter(w, h * i / steps, w * 0.008);
      path.lineTo(p.dx, p.dy);
    }
    for (int i = steps - 1; i >= 0; i--) {
      final p = jitter(w * i / steps, h, w * 0.008);
      path.lineTo(p.dx, p.dy);
    }
    for (int i = steps - 1; i >= 1; i--) {
      final p = jitter(0, h * i / steps, w * 0.008);
      path.lineTo(p.dx, p.dy);
    }
    path.close();

    // drop shadow
    canvas.drawPath(
      path.shift(Offset(w * 0.015, w * 0.020)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // paper base with a soft vertical tone
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            design.paper,
            Color.lerp(design.paper, const Color(0xFFCBBF9E), 0.35)!,
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // fold crease across the middle
    canvas.drawLine(
      Offset(w * 0.03, h * 0.52),
      Offset(w * 0.97, h * 0.50),
      Paint()
        ..strokeWidth = 1.2
        ..color = Colors.black.withValues(alpha: 0.08),
    );

    // ---- cipher scribble lines ----
    final ink = Paint()
      ..color = design.ink.withValues(alpha: 0.72)
      ..strokeWidth = max(1.4, h * 0.008)
      ..strokeCap = StrokeCap.round;
    final marginX = w * 0.11;
    final gap = h * 0.052;
    final rnd2 = Random(29);
    for (int i = 0; i < 15; i++) {
      final y = h * 0.10 + i * gap;
      if (y > h * 0.90) break;
      // leave the center band empty for the stamp
      if (y > h * 0.36 && y < h * 0.62) continue;
      double x = marginX + (i.isEven ? 0 : w * 0.03);
      final lineEnd = w - marginX - rnd2.nextDouble() * w * 0.12;
      while (x < lineEnd) {
        final seg = w * (0.05 + rnd2.nextDouble() * 0.09);
        final end = min(x + seg, lineEnd);
        canvas.drawLine(Offset(x, y), Offset(end, y), ink);
        x = end + w * 0.035;
      }
    }

    // small corner reference mark (like a document number)
    final corner = Paint()
      ..color = design.ink.withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    canvas.drawLine(
        Offset(w * 0.78, h * 0.055), Offset(w * 0.92, h * 0.055), corner);
    canvas.drawLine(
        Offset(w * 0.82, h * 0.075), Offset(w * 0.92, h * 0.075), corner);

    // aged blotches
    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(rnd2.nextDouble() * w, rnd2.nextDouble() * h),
        w * (0.02 + rnd2.nextDouble() * 0.04),
        Paint()
          ..color = const Color(0xFF8A7B5A).withValues(alpha: 0.05)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PaperSheetPainter old) =>
      old.design != design;
}
