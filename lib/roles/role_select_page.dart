import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/fullscreen_service.dart';

/// ロール選択ページ(PWAアプリのホーム画面)。
///
/// Identity E ロゴと3つのロール(チェイサー/呪術師/ハンター)への
/// 導線だけを表示する。インストールされたPWAではこのページが
/// スタート地点になり、ロール以外のページへは遷移できない。
class RoleSelectPage extends StatelessWidget {
  const RoleSelectPage({super.key});

  static const _bgTop = Color(0xFF2B3844);
  static const _bgBottom = Color(0xFF141B21);
  static const _ink = Color(0xFFCFD8E0);
  static const _inkDim = Color(0xFF7A8794);

  void _go(BuildContext context, String route) {
    // ユーザージェスチャのタイミングで全画面化
    FullscreenService.instance.enter();
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.4,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Image.asset(
                        'assets/images/identity_e_logo.png',
                        width: 118,
                        height: 118,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'IDENTITY E',
                      style: GoogleFonts.shipporiMincho(
                        color: _ink,
                        fontSize: 26,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'あなたのロールを選択',
                      style: GoogleFonts.shipporiMincho(
                        color: _inkDim,
                        fontSize: 12.5,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 34),
                    _roleButton(
                      context,
                      route: '/chaser',
                      icon: Icons.campaign_rounded,
                      color: const Color(0xFFC5392C),
                      title: 'チェイサー',
                      sub: '警報ブザーで追跡を知らせる',
                    ),
                    const SizedBox(height: 14),
                    _roleButton(
                      context,
                      route: '/cursed',
                      icon: Icons.auto_fix_high_rounded,
                      color: const Color(0xFF9B59D0),
                      title: '呪術師',
                      sub: '一度きりの呪いを放つ',
                    ),
                    const SizedBox(height: 14),
                    _roleButton(
                      context,
                      route: '/hunter',
                      icon: Icons.visibility_rounded,
                      color: const Color(0xFFB7791F),
                      title: 'ハンター',
                      sub: '呪いの通知を受け取る',
                    ),
                    const SizedBox(height: 30),
                    Text(
                      '案内された自分のロールを選んでください',
                      style: GoogleFonts.shipporiMincho(
                        color: _inkDim.withValues(alpha: 0.7),
                        fontSize: 11,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleButton(
    BuildContext context, {
    required String route,
    required IconData icon,
    required Color color,
    required String title,
    required String sub,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _go(context, route),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.16),
                  border: Border.all(color: color.withValues(alpha: 0.6)),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.shipporiMincho(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: GoogleFonts.shipporiMincho(
                        color: _inkDim,
                        fontSize: 11.5,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: _inkDim.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}
