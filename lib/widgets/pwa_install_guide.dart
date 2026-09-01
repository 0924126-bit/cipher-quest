import 'package:flutter/material.dart';

import '../services/pwa_service.dart';
import 'youtube_embed_stub.dart'
    if (dart.library.js_interop) 'youtube_embed_web.dart';

/// PWA（ホーム画面追加）未導入の人向け案内。
///
/// デザイン方針: Google風ミニマリズム。白地・細いグレー枠・青1色の
/// アクセント。目立たせつつ装飾はしない。
///
/// カードをタップするとシートが開き、上に簡単な文字の手順
/// （iPhone / Android）、その下にYouTube解説動画（Shorts埋め込み）を表示。
class PwaInstallGuideCard extends StatelessWidget {
  const PwaInstallGuideCard({super.key});

  static const _ink = Color(0xFF202124);
  static const _sub = Color(0xFF5F6368);
  static const _line = Color(0xFFDADCE0);
  static const _blue = Color(0xFF1A73E8);

  /// PWAとして起動していない場合だけ表示する。
  static bool get shouldShow => !PwaService.instance.isPwa;

  @override
  Widget build(BuildContext context) {
    if (!shouldShow) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openGuideSheet(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_outlined,
                      size: 19, color: _blue),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '通知を確実に受け取るには？',
                        style: TextStyle(
                            fontSize: 14,
                            color: _ink,
                            fontWeight: FontWeight.w600,
                            height: 1.4),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'ホーム画面に追加すると、アプリを閉じていても呼び出し通知が届きます',
                        style:
                            TextStyle(fontSize: 12.5, color: _sub, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 20, color: _sub),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openGuideSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _PwaGuideSheet(),
    );
  }
}

class _PwaGuideSheet extends StatelessWidget {
  const _PwaGuideSheet();

  static const _ink = Color(0xFF202124);
  static const _sub = Color(0xFF5F6368);
  static const _line = Color(0xFFDADCE0);
  static const _blue = Color(0xFF1A73E8);

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.9;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '通知を受け取るには',
                        style: TextStyle(
                            fontSize: 18,
                            color: _ink,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'ホーム画面に追加（アプリ化）して通知を許可すると、'
                        'アプリを閉じていても呼び出しやリマインダーが届きます。',
                        style:
                            TextStyle(fontSize: 13, color: _sub, height: 1.7),
                      ),
                      const SizedBox(height: 20),

                      // ---- 簡単な文字の説明（動画の上） ----
                      _steps(
                        icon: Icons.phone_iphone,
                        title: 'iPhoneなら　簡単に言うと↓',
                        steps: const [
                          'Safariでサイトを開く（他のもので開いてもできないことがあります）',
                          '「共有 ⬆︎」→「ホーム画面に追加」の順にタップ',
                          '追加されたIdentityEアプリを開き、通知を許可する',
                        ],
                      ),
                      const SizedBox(height: 14),
                      _steps(
                        icon: Icons.android,
                        title: 'Androidなら　簡単に言うと↓',
                        steps: const [
                          'Chromeでサイトを開く',
                          '右上の「⋮」→「ホーム画面に追加」（または「アプリをインストール」）をタップ',
                          '追加されたアプリを開き、通知を許可する',
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ---- 解説動画（YouTube Shorts 埋め込み） ----
                      const Text(
                        '動画で見る',
                        style: TextStyle(
                            fontSize: 13,
                            color: _ink,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 270,
                            height: 480, // Shorts(9:16)
                            child: buildYoutubeEmbedImpl('ymC6lPMrjH8'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          style:
                              TextButton.styleFrom(foregroundColor: _blue),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('閉じる',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _steps({
    required IconData icon,
    required String title,
    required List<String> steps,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _blue),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13.5,
                      color: _ink,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    child: Text('${i + 1}.',
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: _blue,
                            fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: Text(steps[i],
                        style: const TextStyle(
                            fontSize: 12.5, color: _ink, height: 1.6)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
