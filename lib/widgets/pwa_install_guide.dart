import 'package:flutter/material.dart';

import '../services/pwa_service.dart';
import 'youtube_embed_stub.dart'
    if (dart.library.js_interop) 'youtube_embed_web.dart';

/// ホーム画面追加（アプリ化）未導入の人向け案内。
///
/// デザイン: Googleのヘルプ画面とほぼ同じミニマリズム。
/// 白地・罫線1本・青1色・番号付きのプレーンな手順。
/// セグメント切替はピルがスライド、手順はフェード＋スライド、
/// 動画はスムーズに展開する（Material標準のイージング）。
///
/// アプリ（ホーム画面から起動）で表示中は出さない。
const _ink = Color(0xFF202124);
const _sub = Color(0xFF5F6368);
const _line = Color(0xFFDADCE0);
const _blue = Color(0xFF1A73E8);
const _blueBg = Color(0xFFE8F0FE);

/// どこからでも案内シートを開ける公開関数（トップページなどから使用）。
void showPwaGuideSheet(BuildContext context) {
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

class PwaInstallGuideCard extends StatelessWidget {
  const PwaInstallGuideCard({super.key});

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
          onTap: () => showPwaGuideSheet(context),
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
                        fontSize: 13,
                        color: _blue,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PwaGuideSheet extends StatefulWidget {
  const _PwaGuideSheet();

  @override
  State<_PwaGuideSheet> createState() => _PwaGuideSheetState();
}

class _PwaGuideSheetState extends State<_PwaGuideSheet> {
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
                  'ホーム画面に追加して通知を許可すると、アプリを閉じていても呼び出しが届きます。'
                  '通信できないときも、保存済みの整理券をオフラインで確認できます。',
                  style: TextStyle(fontSize: 13.5, color: _sub, height: 1.7),
                ),
                const SizedBox(height: 20),

                // ---- OS切り替え（ピルがスライドするセグメント） ----
                _SlidingSegment(
                  value: _os,
                  labels: const ['iPhone', 'Android'],
                  onChanged: (v) => setState(() => _os = v),
                ),
                const SizedBox(height: 20),

                // ---- 手順（切替時フェード＋スライド） ----
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    // Material の fade-through: 前の内容をスッと消してから
                    // 新しい内容をふわっと出す。横移動はしない（揺れ防止）。
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: const Interval(0.4, 1.0,
                        curve: Curves.easeOutCubic),
                    switchOutCurve: const Interval(0.6, 1.0,
                        curve: Curves.easeInCubic),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previous, if (current != null) current],
                    ),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: Column(
                      key: ValueKey(_os),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < steps.length; i++) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 28,
                                child: Text('${i + 1}.',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: _sub,
                                        height: 1.6)),
                              ),
                              Expanded(
                                child: Text(steps[i],
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: _ink,
                                        height: 1.6)),
                              ),
                            ],
                          ),
                          if (i < steps.length - 1)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(
                                  height: 1, color: Color(0xFFF1F3F4)),
                            ),
                        ],
                        if (_os == 0) ...[
                          const SizedBox(height: 14),
                          const Text(
                            'Safari 以外のブラウザでは追加できないことがあります。',
                            style: TextStyle(
                                fontSize: 12, color: _sub, height: 1.6),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: _line),
                const SizedBox(height: 8),

                // ---- 動画（なめらかに展開する折りたたみ） ----
                InkWell(
                  onTap: () => setState(() => _showVideo = !_showVideo),
                  borderRadius: BorderRadius.circular(8),
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
                        AnimatedRotation(
                          turns: _showVideo ? 0.5 : 0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          child: const Icon(Icons.keyboard_arrow_down,
                              size: 20, color: _sub),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _showVideo
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 270,
                                height: 480, // Shorts(9:16)
                                child: buildYoutubeEmbedImpl('ymC6lPMrjH8'),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
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
}

/// Google風のセグメント。選択ピル（青背景）が左右にスライドし、
/// 文字色・チェックマークもなめらかに切り替わる。
class _SlidingSegment extends StatelessWidget {
  final int value;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _SlidingSegment({
    required this.value,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / labels.length;
          return Stack(
            children: [
              // スライドするピル
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: value * w,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: _blueBg,
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: InkWell(
                        onTap: () => onChanged(i),
                        borderRadius: BorderRadius.circular(20),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSize(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                child: value == i
                                    ? const Padding(
                                        padding: EdgeInsets.only(right: 6),
                                        child: Icon(Icons.check,
                                            size: 16, color: _blue),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: value == i ? _blue : _ink,
                                  fontWeight: value == i
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                ),
                                child: Text(labels[i]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
