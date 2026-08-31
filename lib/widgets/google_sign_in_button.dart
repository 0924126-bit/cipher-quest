import 'package:flutter/material.dart';

/// Google公式サインインボタン風の白いピルボタン（4色Gロゴ付き）。
/// /reserve と /ticket のログインで共用。
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.label = 'Google でログイン',
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFDADCE0)),
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CustomPaint(painter: GoogleGPainter()),
            ),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF202124),
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// Googleの「G」ロゴ（4色の円弧＋横バー）。ベクター描画・アセット不要。
class GoogleGPainter extends CustomPainter {
  const GoogleGPainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = size.width * 0.2;
    final r = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    double rad(double deg) => deg * 3.1415926535 / 180;
    // 赤: 左上 / 黄: 左下 / 緑: 右下 / 青: 右上→バーへ
    canvas.drawArc(rect, rad(-170), rad(80), false, p..color = _red);
    canvas.drawArc(rect, rad(100), rad(90), false, p..color = _yellow);
    canvas.drawArc(rect, rad(10), rad(90), false, p..color = _green);
    canvas.drawArc(rect, rad(-25), rad(35), false, p..color = _blue);
    // 青の横バー（中央→右端）
    final bar = Paint()..color = _blue;
    canvas.drawRect(
      Rect.fromLTWH(
          c.dx - stroke * 0.2, c.dy - stroke / 2, r + stroke * 0.7, stroke),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
