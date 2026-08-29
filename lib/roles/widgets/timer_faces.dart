import 'dart:math' as math;

import 'package:flutter/material.dart';

/// タイマーの追加デザイン集。
///
/// timer_candles.dart の「儀式の蝋燭」に加えて、ダッシュボードから
/// 選べる4つの表示デザインを提供する。全て同じインターフェース
/// (progress / flame / danger / finished) で timer_page から切替可能。
///
/// - TimerDigits    : シンプルな数字表示（ホラー書体風の明滅つき）
/// - TimerBloodMoon : 血月蝕 — 月が闇に食われていく
/// - TimerHourglass : 血の砂時計 — 血が下へ落ちきったら刻限
/// - TimerHeartbeat : 心電図 — 鼓動が弱まり、刻限で心停止

// ---------------------------------------------------------------------------
// 1) シンプルな数字表示
// ---------------------------------------------------------------------------

class TimerDigits extends StatelessWidget {
  final int remaining; // sec
  final double flicker;
  final bool danger;
  final bool finished;

  const TimerDigits({
    super.key,
    required this.remaining,
    required this.flicker,
    required this.danger,
    required this.finished,
  });

  String get _text {
    final m = (remaining ~/ 60).toString().padLeft(2, '0');
    final s = (remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final color = finished
        ? const Color(0xFF8A0F0F)
        : danger
            ? const Color(0xFFD8323C)
            : const Color(0xFFE8E2D0);
    return Opacity(
      opacity: (0.55 + 0.45 * flicker).clamp(0.0, 1.0),
      child: Text(
        finished ? '00:00' : _text,
        style: TextStyle(
          fontSize: 148,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
          letterSpacing: 6,
          color: color,
          shadows: [
            Shadow(
              color: (danger || finished
                      ? const Color(0xFFB3202A)
                      : const Color(0xFFB8A96A))
                  .withValues(alpha: 0.55),
              blurRadius: 34,
            ),
            const Shadow(color: Colors.black, blurRadius: 6),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2) 血月蝕 — 満月が闇に食われ、残り僅かで血の色に染まる
// ---------------------------------------------------------------------------

class TimerBloodMoon extends StatelessWidget {
  final double progress; // 1.0 = 満月, 0.0 = 完全に食われる
  final double flicker;
  final double flame; // 0..1 繰り返し（脈動に使用）
  final bool danger;
  final bool finished;

  const TimerBloodMoon({
    super.key,
    required this.progress,
    required this.flicker,
    required this.flame,
    required this.danger,
    required this.finished,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(360, 360),
      painter: _BloodMoonPainter(
        progress: progress.clamp(0.0, 1.0),
        flicker: flicker,
        flame: flame,
        danger: danger,
        finished: finished,
      ),
    );
  }
}

class _BloodMoonPainter extends CustomPainter {
  final double progress;
  final double flicker;
  final double flame;
  final bool danger;
  final bool finished;

  _BloodMoonPainter({
    required this.progress,
    required this.flicker,
    required this.flame,
    required this.danger,
    required this.finished,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * 0.38;
    final pulse = danger ? 1.0 + 0.02 * math.sin(flame * math.pi * 2) : 1.0;
    final radius = r * pulse;

    // 月の色: 通常は骨色 → danger/finished で血の色へ
    final moonColor = finished
        ? const Color(0xFF4A0A0A)
        : danger
            ? Color.lerp(const Color(0xFFB3202A), const Color(0xFF6E1016),
                0.5 + 0.5 * math.sin(flame * math.pi * 2))!
            : const Color(0xFFD9CFB4);

    // 外側グロー
    canvas.drawCircle(
      c,
      radius * 1.25,
      Paint()
        ..color = moonColor.withValues(alpha: 0.18 * flicker)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
    );

    // 月本体
    final moon = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: [
          moonColor,
          Color.lerp(moonColor, Colors.black, 0.35)!,
        ],
      ).createShader(Rect.fromCircle(center: c, radius: radius));
    canvas.drawCircle(c, radius, moon);

    // クレーター（固定シードでランダム配置）
    final rand = math.Random(20250924);
    final crater = Paint()..color = Colors.black.withValues(alpha: 0.14);
    for (var i = 0; i < 9; i++) {
      final a = rand.nextDouble() * math.pi * 2;
      final d = rand.nextDouble() * radius * 0.72;
      final cr = radius * (0.05 + rand.nextDouble() * 0.09);
      canvas.drawCircle(c + Offset(math.cos(a) * d, math.sin(a) * d), cr, crater);
    }

    // 蝕 — 影の円が右からせり出して月を食う。
    // progress=1 で影は月の外、progress=0 で完全に重なる。
    if (!finished) {
      final eaten = 1.0 - progress; // 0=無傷, 1=完食
      final shadowCenter = Offset(c.dx + radius * 2.15 * (1.0 - eaten), c.dy);
      final shadow = Paint()..color = const Color(0xFF060404);
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: radius)));
      canvas.drawCircle(shadowCenter, radius * 1.04, shadow);
      // 蝕の縁に血の光
      canvas.drawCircle(
        shadowCenter,
        radius * 1.04,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = const Color(0xFF8A0F0F).withValues(alpha: 0.65)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.restore();
    } else {
      // 刻限後: 血の輪だけが残る皆既蝕
      canvas.drawCircle(c, radius, Paint()..color = const Color(0xFF0A0505));
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFFB3202A)
              .withValues(alpha: 0.5 + 0.3 * math.sin(flame * math.pi * 2))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
  }

  @override
  bool shouldRepaint(_BloodMoonPainter old) =>
      old.progress != progress ||
      old.flicker != flicker ||
      old.flame != flame ||
      old.danger != danger ||
      old.finished != finished;
}

// ---------------------------------------------------------------------------
// 3) 血の砂時計 — 上の血が下へ落ちきったら刻限
// ---------------------------------------------------------------------------

class TimerHourglass extends StatelessWidget {
  final double progress; // 1.0 = 上が満タン, 0.0 = 落ちきり
  final double flicker;
  final double flame;
  final bool danger;
  final bool finished;

  const TimerHourglass({
    super.key,
    required this.progress,
    required this.flicker,
    required this.flame,
    required this.danger,
    required this.finished,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(280, 400),
      painter: _HourglassPainter(
        progress: progress.clamp(0.0, 1.0),
        flicker: flicker,
        flame: flame,
        danger: danger,
        finished: finished,
      ),
    );
  }
}

class _HourglassPainter extends CustomPainter {
  final double progress;
  final double flicker;
  final double flame;
  final bool danger;
  final bool finished;

  _HourglassPainter({
    required this.progress,
    required this.flicker,
    required this.flame,
    required this.danger,
    required this.finished,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final frameColor = const Color(0xFF2A241C);
    final blood = danger || finished
        ? Color.lerp(const Color(0xFFB3202A), const Color(0xFF7A1218),
            0.5 + 0.5 * math.sin(flame * math.pi * 2))!
        : const Color(0xFF8A1420);

    final topY = h * 0.08;
    final botY = h * 0.92;
    final midY = h * 0.5;
    final bulbW = w * 0.36; // 中心からの半幅
    final neckW = w * 0.035;

    // ---- ガラス輪郭 ----
    Path glass(double y0, double y1, bool top) {
      final p = Path();
      if (top) {
        p.moveTo(cx - bulbW, y0);
        p.lineTo(cx + bulbW, y0);
        p.quadraticBezierTo(cx + bulbW, (y0 + y1) / 2, cx + neckW, y1);
        p.lineTo(cx - neckW, y1);
        p.quadraticBezierTo(cx - bulbW, (y0 + y1) / 2, cx - bulbW, y0);
      } else {
        p.moveTo(cx - neckW, y0);
        p.lineTo(cx + neckW, y0);
        p.quadraticBezierTo(cx + bulbW, (y0 + y1) / 2, cx + bulbW, y1);
        p.lineTo(cx - bulbW, y1);
        p.quadraticBezierTo(cx - bulbW, (y0 + y1) / 2, cx - neckW, y0);
      }
      p.close();
      return p;
    }

    final topBulb = glass(topY + 8, midY - 3, true);
    final botBulb = glass(midY + 3, botY - 8, false);

    // ガラスの奥行き
    final glassFill = Paint()
      ..color = const Color(0xFF11150F).withValues(alpha: 0.75);
    canvas.drawPath(topBulb, glassFill);
    canvas.drawPath(botBulb, glassFill);

    // ---- 血（上の残量）----
    if (!finished && progress > 0.001) {
      canvas.save();
      canvas.clipPath(topBulb);
      final fillTop = midY - 3 - (midY - 3 - (topY + 8)) * progress;
      canvas.drawRect(
        Rect.fromLTRB(cx - bulbW, fillTop, cx + bulbW, midY - 3),
        Paint()..color = blood,
      );
      // 血面のゆらぎハイライト
      canvas.drawRect(
        Rect.fromLTRB(cx - bulbW, fillTop, cx + bulbW, fillTop + 3),
        Paint()
          ..color = const Color(0xFFD8626C)
              .withValues(alpha: 0.5 + 0.2 * math.sin(flame * math.pi * 2)),
      );
      canvas.restore();
    }

    // ---- 落ちる血の糸 ----
    if (!finished && progress > 0.001) {
      final drip = Paint()
        ..color = blood.withValues(alpha: 0.9)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      final sway = math.sin(flame * math.pi * 4) * 1.2;
      canvas.drawLine(
          Offset(cx + sway * 0.3, midY - 4), Offset(cx + sway, botY - 14), drip);
      // 滴
      final dropT = (flame * 2) % 1.0;
      final dropY = midY + (botY - 20 - midY) * dropT;
      canvas.drawCircle(Offset(cx + sway, dropY), 3, Paint()..color = blood);
    }

    // ---- 血（下の溜まり）----
    canvas.save();
    canvas.clipPath(botBulb);
    final filled = finished ? 1.0 : (1.0 - progress);
    final poolTop = botY - 8 - (botY - 8 - (midY + 3)) * filled;
    canvas.drawRect(
      Rect.fromLTRB(cx - bulbW, poolTop, cx + bulbW, botY - 8),
      Paint()..color = blood,
    );
    canvas.drawRect(
      Rect.fromLTRB(cx - bulbW, poolTop, cx + bulbW, poolTop + 3),
      Paint()
        ..color = const Color(0xFFD8626C)
            .withValues(alpha: 0.4 + 0.2 * math.sin(flame * math.pi * 2 + 1)),
    );
    canvas.restore();

    // ---- ガラスの反射 ----
    final gloss = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.10 * flicker);
    canvas.drawPath(topBulb, gloss);
    canvas.drawPath(botBulb, gloss);

    // ---- 木の枠 ----
    final frame = Paint()
      ..color = frameColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - bulbW - 18, topY - 10, (bulbW + 18) * 2, 18),
          const Radius.circular(5)),
      frame,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - bulbW - 18, botY - 8, (bulbW + 18) * 2, 18),
          const Radius.circular(5)),
      frame,
    );
    // 柱
    final pillar = Paint()..color = frameColor.withValues(alpha: 0.9);
    canvas.drawRect(
        Rect.fromLTWH(cx - bulbW - 14, topY + 6, 7, botY - topY - 12), pillar);
    canvas.drawRect(
        Rect.fromLTWH(cx + bulbW + 7, topY + 6, 7, botY - topY - 12), pillar);

    // ---- 刻限後: 底から血が滲み広がる ----
    if (finished) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, botY + 12),
            width: w * (0.8 + 0.05 * math.sin(flame * math.pi * 2)),
            height: 20),
        Paint()
          ..color = blood.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  @override
  bool shouldRepaint(_HourglassPainter old) =>
      old.progress != progress ||
      old.flicker != flicker ||
      old.flame != flame ||
      old.danger != danger ||
      old.finished != finished;
}

// ---------------------------------------------------------------------------
// 4) 心電図 — 鼓動が弱まり、刻限で心停止（フラットライン）
// ---------------------------------------------------------------------------

class TimerHeartbeat extends StatelessWidget {
  final double progress; // 1.0 = 元気な鼓動, 0.0 = 停止寸前
  final double flicker;
  final double flame; // スクロール/鼓動位相
  final bool danger;
  final bool finished;

  const TimerHeartbeat({
    super.key,
    required this.progress,
    required this.flicker,
    required this.flame,
    required this.danger,
    required this.finished,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 260),
      painter: _HeartbeatPainter(
        progress: progress.clamp(0.0, 1.0),
        flicker: flicker,
        flame: flame,
        danger: danger,
        finished: finished,
      ),
    );
  }
}

class _HeartbeatPainter extends CustomPainter {
  final double progress;
  final double flicker;
  final double flame;
  final bool danger;
  final bool finished;

  _HeartbeatPainter({
    required this.progress,
    required this.flicker,
    required this.flame,
    required this.danger,
    required this.finished,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final midY = h * 0.55;
    final lineColor = finished
        ? const Color(0xFFB3202A)
        : danger
            ? const Color(0xFFE0454F)
            : const Color(0xFF6FCF8E);

    // ---- モニタのグリッド ----
    final grid = Paint()
      ..color = lineColor.withValues(alpha: 0.07 * flicker)
      ..strokeWidth = 1;
    for (var x = 0.0; x < w; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
    }
    for (var y = 0.0; y < h; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    // ---- 波形 ----
    // progress が減ると鼓動間隔が伸び振幅が落ちる（弱っていく心臓）。
    // finished でフラットライン。
    final path = Path();
    final scroll = flame * w; // 左へ流れる
    final beatSpacing = 140.0 + (1.0 - progress) * 260.0; // 弱ると間隔が開く
    final amp = finished ? 0.0 : (h * 0.16) * (0.35 + 0.65 * progress);

    double waveY(double x) {
      if (finished) return midY;
      // ビート位置からの距離で QRS っぽい山を作る
      final phase = (x + scroll) % beatSpacing;
      double y = 0;
      // P波
      y += _bump(phase, beatSpacing * 0.30, 14, amp * 0.18);
      // QRS
      y -= _bump(phase, beatSpacing * 0.44, 5, amp * 0.30);
      y += _bump(phase, beatSpacing * 0.50, 7, amp * 1.55);
      y -= _bump(phase, beatSpacing * 0.56, 5, amp * 0.42);
      // T波
      y += _bump(phase, beatSpacing * 0.72, 18, amp * 0.30);
      return midY - y;
    }

    path.moveTo(0, waveY(0));
    for (var x = 2.0; x <= w; x += 2) {
      path.lineTo(x, waveY(x));
    }

    // グロー
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = lineColor.withValues(alpha: 0.22 * flicker)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // 本線
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round
        ..color = lineColor.withValues(alpha: (0.75 + 0.25 * flicker)),
    );

    // ---- 走査点（右端の輝点）----
    if (!finished) {
      final scanX = w * 0.86;
      canvas.drawCircle(
        Offset(scanX, waveY(scanX)),
        4,
        Paint()
          ..color = lineColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // ---- 刻限後: フラットラインが明滅 ----
    if (finished) {
      canvas.drawLine(
        Offset(0, midY),
        Offset(w, midY),
        Paint()
          ..strokeWidth = 3
          ..color = lineColor
              .withValues(alpha: 0.5 + 0.5 * math.sin(flame * math.pi * 6).abs()),
      );
    }
  }

  /// ガウス風の山。center を中心に幅 sigma、高さ height。
  double _bump(double x, double center, double sigma, double height) {
    final d = (x - center) / sigma;
    return height * math.exp(-d * d);
  }

  @override
  bool shouldRepaint(_HeartbeatPainter old) =>
      old.progress != progress ||
      old.flicker != flicker ||
      old.flame != flame ||
      old.danger != danger ||
      old.finished != finished;
}
