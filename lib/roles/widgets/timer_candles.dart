import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 儀式の蝋燭列 — 数字を使わない残り時間表示。
///
/// 13本の蝋燭が時間経過とともに右から左へ消えていく。
/// 灯っている本数と、いま燃えている1本の蝋の残り高さで
/// 「残りがなんとなく」わかる。残り僅かで炎が血の色になる。
class TimerCandles extends StatelessWidget {
  /// 残り時間の割合 (1.0 = 満タン, 0.0 = 刻限)。
  final double progress;

  /// 蛍光灯の明滅レベル (timer_page と共有)。
  final double flicker;

  /// 炎の揺らぎ用アニメーション値 (0..1 を繰り返す)。
  final double flame;

  /// 残り僅か (血の色モード)。
  final bool danger;

  /// 刻限後 (全て消え、煙だけが立つ)。
  final bool finished;

  const TimerCandles({
    super.key,
    required this.progress,
    required this.flicker,
    required this.flame,
    required this.danger,
    required this.finished,
  });

  static const int candleCount = 13;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 190),
      painter: _CandlesPainter(
        progress: progress.clamp(0.0, 1.0),
        flicker: flicker,
        flame: flame,
        danger: danger,
        finished: finished,
      ),
    );
  }
}

class _CandlesPainter extends CustomPainter {
  final double progress;
  final double flicker;
  final double flame;
  final bool danger;
  final bool finished;

  _CandlesPainter({
    required this.progress,
    required this.flicker,
    required this.flame,
    required this.danger,
    required this.finished,
  });

  static const int n = TimerCandles.candleCount;

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = size.height - 18;
    final slot = size.width / (n + 1);

    // 各蝋燭の状態: remaining*n が「灯っている本数(小数)」
    final litExact = progress * n;

    for (var i = 0; i < n; i++) {
      // 左から i 番目。左側から消えていく方が「終わりへ向かう」感が強い。
      final x = slot * (i + 1);
      final rand = math.Random(i * 7919); // 蝋燭ごとの固定個体差
      // この蝋燭の「残り」: i 本目が完全に生きているのは litExact > i+1
      final local = (litExact - i).clamp(0.0, 1.0);
      final lit = !finished && local > 0.001;

      // 蝋燭の高さ: 溶けるほど短く (個体差 ±12px)
      final maxH = 58.0 + rand.nextDouble() * 24;
      final minH = 12.0;
      final h = minH + (maxH - minH) * local;

      _drawCandle(canvas, x, baseY, h, lit, local, rand, i);
    }

    // 台座の影 (床にぼんやり広がる灯り)
    if (!finished && litExact > 0) {
      final glow = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30)
        ..color = (danger ? const Color(0xFF5A0000) : const Color(0xFF3A2A08))
            .withValues(alpha: 0.20 * flicker);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width / 2, baseY + 8),
          width: size.width * (0.25 + 0.65 * progress),
          height: 26,
        ),
        glow,
      );
    }
  }

  void _drawCandle(Canvas canvas, double x, double baseY, double h, bool lit,
      double local, math.Random rand, int index) {
    final w = 9.0 + rand.nextDouble() * 3;
    final topY = baseY - h;

    // ---- 蝋 (wax) ----
    final waxRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x - w / 2, topY, w, h),
      const Radius.circular(2.5),
    );
    final wax = Paint()
      ..color = Color.lerp(
        const Color(0xFF3A3630),
        const Color(0xFF8F8574),
        lit ? 0.75 * flicker : 0.28,
      )!;
    canvas.drawRRect(waxRect, wax);

    // 垂れた蝋 (個体差)
    final drip = Paint()..color = wax.color.withValues(alpha: 0.8);
    final dripH = 4.0 + rand.nextDouble() * 7;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            x - w / 2 + rand.nextDouble() * (w - 2.5), topY, 2.5, dripH),
        const Radius.circular(1.2),
      ),
      drip,
    );

    // ---- 芯 ----
    final wick = Paint()
      ..color = const Color(0xFF141210)
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(x, topY), Offset(x, topY - 4), wick);

    if (lit) {
      // ---- 炎 ----
      // 揺らぎ: flame(0..1) と蝋燭indexで位相をずらす
      final t = flame * math.pi * 2 + index * 1.7;
      final sway = math.sin(t) * 1.8 + math.sin(t * 2.3) * 0.9;
      final flameH = 13.0 + math.sin(t * 1.4) * 2.5;
      final cx = x + sway;
      final cy = topY - 5 - flameH / 2;

      final outerColor = danger
          ? const Color(0xFFB3202A)
          : const Color(0xFFE8A33D);
      final coreColor = danger
          ? const Color(0xFFFF7A6B)
          : const Color(0xFFFFF0C8);

      // 外周グロー
      final glow = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
        ..color = outerColor.withValues(alpha: 0.5 * flicker);
      canvas.drawCircle(Offset(cx, cy), 12, glow);

      // 炎本体 (涙型)
      final path = Path()
        ..moveTo(cx, cy - flameH / 2)
        ..quadraticBezierTo(
            cx + 5, cy - flameH * 0.1, cx + 3.2, cy + flameH * 0.32)
        ..quadraticBezierTo(cx, cy + flameH / 2 + 1, cx - 3.2, cy + flameH * 0.32)
        ..quadraticBezierTo(cx - 5, cy - flameH * 0.1, cx, cy - flameH / 2);
      canvas.drawPath(
          path,
          Paint()
            ..color = outerColor.withValues(alpha: 0.92 * flicker)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4));

      // 芯側のコア
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, cy + flameH * 0.16),
            width: 4.4,
            height: flameH * 0.5),
        Paint()..color = coreColor.withValues(alpha: 0.9 * flicker),
      );

      // 消えかけ (local < 0.2) は炎を弱く
      if (local < 0.2) {
        canvas.drawRect(
          Rect.fromLTWH(cx - 8, cy - flameH, 16, flameH * 2),
          Paint()
            ..color = Colors.black
                .withValues(alpha: (1 - local / 0.2) * 0.55),
        );
      }
    } else {
      // ---- 消えた蝋燭: 立ちのぼる煙 ----
      final smoke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6)
        ..color = const Color(0xFF7B8078)
            .withValues(alpha: finished ? 0.30 : 0.22);
      final t = flame * math.pi * 2 + index * 2.9;
      final path = Path()..moveTo(x, topY - 5);
      for (var s = 1; s <= 4; s++) {
        final yy = topY - 5 - s * 9.0;
        final xx = x + math.sin(t + s * 1.3) * (2.0 + s * 1.6);
        path.quadraticBezierTo(
            x + math.sin(t + s) * 4, yy + 4.5, xx, yy);
      }
      canvas.drawPath(path, smoke);
    }
  }

  @override
  bool shouldRepaint(_CandlesPainter old) =>
      old.progress != progress ||
      old.flicker != flicker ||
      old.flame != flame ||
      old.danger != danger ||
      old.finished != finished;
}
