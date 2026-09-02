import 'package:flutter/material.dart';

import '../services/pwa_service.dart';
import 'youtube_embed_stub.dart'
    if (dart.library.js_interop) 'youtube_embed_web.dart';

/// PWA（ホーム画面追加）未導入の人向け案内。
///
/// デザイン: Googleのヘルプ画面とほぼ同じ、余計な装飾のない
/// ミニマリズム。白地・罫線1本・青1色・番号付きのプレーンな手順。
/// iPhone / Android はセグメントで切り替える。
///
/// PWA（ホーム画面から起動）で表示中は出さない。
class PwaInstallGuideCard extends StatelessWidget {
  const PwaInstallGuideCard({super.key});

  static const _ink = Color(0xFF202124);
  static const _sub = Color(0xFF5F6368);
  static const _line = Color(0xFFDADCE0);
  static const _blue = Color(0xFF1A73E8);

  /// ブラウザ表示のときだけ出す（アプリとして起動中は出さない）。
  static bool get shouldShow => !PwaService.instance.looksInstalled;

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
                const Icon(Icons.notifications_none, size: 20, color: _sub),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '通知を受け取る',
                        style: TextStyle(
                            fontSize: 14,
                            color: _ink,
                            fontWeight: FontWeight.w500,
                            height: 1.4),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'ホーム画面に追加すると呼び出し通知が届きます',
                        style:
                            TextStyle(fontSize: 12.5, color: _sub, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text('設定方法',
                    style: TextStyle(
                        fontSize: 13, color: _blue, fontWeight: FontWeight.w500)),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const _PwaGuideSheet(),
    );
  }
}

class _PwaGuideSheet extends StatefulWidget {
  const _PwaGuideSheet();

  @override
  State<_PwaGuideSheet> createState() => _PwaGuideSheetState();
}

class _PwaGuideSheetState extends State<_PwaGuideSheet> {
  static const _ink = Color(0xFF202124);
  static const _sub = Color(0xFF5F6368);
  static const _line = Color(0xFFDADCE0);
  static const _blue = Color(0xFF1A73E8);
  static const _blueBg = Color(0xFFE8F0FE);

  /// 0 = iPhone, 1 = Android
  int _os = 0;
  bool _showVideo = false;

  static const _iosSteps = [
    'Safari でこのサイトを開く',
    '共有ボタン（□に↑）をタップ',
    '「ホーム画面に追加」を選ぶ',
    '追加されたアプリを開き、通知を許可する',
  ];

  static const _androidSteps = [
    'Chrome でこのサイトを開く',
    '右上のメニュー（⋮）をタップ',
    '「ホーム画面に追加」または「アプリをインストール」を選ぶ',
    '追加されたアプリを開き、通知を許可する',
  ];

  @override
  Widget build(BuildContext context) {
    final steps = _os == 0 ? _iosSteps : _androidSteps;
    final maxH = MediaQuery.of(context).size.height * 0.9;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '通知を受け取る',
                  style: TextStyle(
                      fontSize: 20, color: _ink, fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ホーム画面に追加して通知を許可すると、アプリを閉じていても呼び出しが届きます。',
                  style: TextStyle(fontSize: 13.5, color: _sub, height: 1.7),
                ),
                const SizedBox(height: 20),

                // ---- OS切り替え（セグメント） ----
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      _seg('iPhone', 0),
                      Container(width: 1, color: _line),
                      _seg('Android', 1),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ---- 手順（プレーンな番号リスト） ----
                for (var i = 0; i < steps.length; i++) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text('${i + 1}.',
                            style: const TextStyle(
                                fontSize: 14, color: _sub, height: 1.6)),
                      ),
                      Expanded(
                        child: Text(steps[i],
                            style: const TextStyle(
                                fontSize: 14, color: _ink, height: 1.6)),
                      ),
                    ],
                  ),
                  if (i < steps.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: Color(0xFFF1F3F4)),
                    ),
                ],
                if (_os == 0) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Safari 以外のブラウザでは追加できないことがあります。',
                    style: TextStyle(fontSize: 12, color: _sub, height: 1.6),
                  ),
                ],
                const SizedBox(height: 20),
                const Divider(height: 1, color: _line),
                const SizedBox(height: 8),

                // ---- 動画（折りたたみ） ----
                InkWell(
                  onTap: () => setState(() => _showVideo = !_showVideo),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('動画で見る',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: _ink,
                                  fontWeight: FontWeight.w500)),
                        ),
                        Icon(
                          _showVideo
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 20,
                          color: _sub,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showVideo) ...[
                  const SizedBox(height: 8),
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
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(foregroundColor: _blue),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _seg(String text, int value) {
    final sel = _os == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _os = value),
        borderRadius: BorderRadius.horizontal(
          left: value == 0 ? const Radius.circular(20) : Radius.zero,
          right: value == 1 ? const Radius.circular(20) : Radius.zero,
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? _blueBg : Colors.transparent,
            borderRadius: BorderRadius.horizontal(
              left: value == 0 ? const Radius.circular(19) : Radius.zero,
              right: value == 1 ? const Radius.circular(19) : Radius.zero,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (sel) ...[
                const Icon(Icons.check, size: 16, color: _blue),
                const SizedBox(width: 6),
              ],
              Text(text,
                  style: TextStyle(
                      fontSize: 13.5,
                      color: sel ? _blue : _ink,
                      fontWeight: sel ? FontWeight.w500 : FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }
}
