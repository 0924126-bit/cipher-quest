import 'package:flutter/material.dart';

/// 紙整理券の発行ダイアログ（ダッシュボード / 受付デスク共用）。
///
/// デザイン: Google風ミニマリズム。白地・細枠・青1色。
/// 集合時刻は「先着順」と「日時を指定」の2択のみ。
/// 日時指定は独自の視覚的ピッカー（今日/明日 → 時 → 分チップ）で、
/// 大きな時刻プレビューを見ながらタップだけで選べる。
class PaperIssueResult {
  final String label;
  final String place;
  final DateTime? slotAt; // null = 先着順

  const PaperIssueResult({
    required this.label,
    required this.place,
    required this.slotAt,
  });
}

const _ink = Color(0xFF202124);
const _sub = Color(0xFF5F6368);
const _line = Color(0xFFDADCE0);
const _blue = Color(0xFF1A73E8);
const _blueBg = Color(0xFFE8F0FE);

Future<PaperIssueResult?> showPaperIssueDialog(BuildContext context) {
  return showDialog<PaperIssueResult>(
    context: context,
    builder: (context) => const _PaperIssueDialog(),
  );
}

class _PaperIssueDialog extends StatefulWidget {
  const _PaperIssueDialog();

  @override
  State<_PaperIssueDialog> createState() => _PaperIssueDialogState();
}

class _PaperIssueDialogState extends State<_PaperIssueDialog> {
  final _labelCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();

  /// false=先着順, true=日時指定
  bool _useSlot = false;

  // 視覚的ピッカーの選択値
  int _dayOffset = 0; // 0=今日, 1=明日
  late int _hour;
  late int _minute; // 5分刻み

  @override
  void initState() {
    super.initState();
    // 初期値: 今から30分後を5分単位に丸め
    final d = DateTime.now().add(const Duration(minutes: 30));
    _hour = d.hour;
    _minute = ((d.minute + 4) ~/ 5) * 5 % 60;
    if (((d.minute + 4) ~/ 5) * 5 >= 60) _hour = (_hour + 1) % 24;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _placeCtrl.dispose();
    super.dispose();
  }

  DateTime? get _slotAt {
    if (!_useSlot) return null;
    final now = DateTime.now();
    final base = now.add(Duration(days: _dayOffset));
    return DateTime(base.year, base.month, base.day, _hour, _minute);
  }

  String get _preview {
    final s = _slotAt;
    if (s == null) return '';
    final day = _dayOffset == 0 ? '今日' : '明日';
    return '$day ${s.hour}:${s.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('紙の整理券を発行',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, color: _ink)),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _labelCtrl,
                decoration: _dec('メモ（紙券の番号や名前など・任意）'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _placeCtrl,
                decoration: _dec('集合場所（任意・例: 3年2組前 受付）'),
              ),
              const SizedBox(height: 18),

              // ---- 2択: 先着順 / 日時指定 ----
              Row(
                children: [
                  Expanded(
                    child: _bigOption(
                      selected: !_useSlot,
                      icon: Icons.directions_walk,
                      title: '先着順',
                      sub: '今すぐ列の最後尾へ',
                      onTap: () => setState(() => _useSlot = false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _bigOption(
                      selected: _useSlot,
                      icon: Icons.schedule,
                      title: '日時を指定',
                      sub: '集合時刻を決める',
                      onTap: () => setState(() => _useSlot = true),
                    ),
                  ),
                ],
              ),

              // ---- 視覚的日時ピッカー ----
              if (_useSlot) ...[
                const SizedBox(height: 16),
                // 大きな時刻プレビュー
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _blueBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('集合時刻',
                          style: TextStyle(fontSize: 11.5, color: _sub)),
                      const SizedBox(height: 2),
                      Text(
                        _preview,
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: _blue,
                            letterSpacing: 1),
                      ),
                      const SizedBox(height: 2),
                      const Text('15分前・5分前に自動リマインド',
                          style: TextStyle(fontSize: 11, color: _sub)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _label('日にち'),
                Row(
                  children: [
                    _chip('今日', _dayOffset == 0,
                        () => setState(() => _dayOffset = 0)),
                    const SizedBox(width: 8),
                    _chip('明日', _dayOffset == 1,
                        () => setState(() => _dayOffset = 1)),
                  ],
                ),
                const SizedBox(height: 12),
                _label('時'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var h = 8; h <= 20; h++)
                      _chip('$h', _hour == h, () => setState(() => _hour = h),
                          dense: true),
                  ],
                ),
                const SizedBox(height: 12),
                _label('分'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var m = 0; m < 60; m += 5)
                      _chip(m.toString().padLeft(2, '0'), _minute == m,
                          () => setState(() => _minute = m),
                          dense: true),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '今の待ち行列の最後尾に入ります',
                    style: TextStyle(fontSize: 12.5, color: _sub),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル', style: TextStyle(color: _sub)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _blue),
          onPressed: () => Navigator.pop(
            context,
            PaperIssueResult(
              label: _labelCtrl.text.trim(),
              place: _placeCtrl.text.trim(),
              slotAt: _slotAt,
            ),
          ),
          child: Text(_useSlot ? '$_preview で発行' : '先着順で発行'),
        ),
      ],
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: _sub),
        isDense: true,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _blue),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, color: _sub, fontWeight: FontWeight.w600)),
      );

  Widget _bigOption({
    required bool selected,
    required IconData icon,
    required String title,
    required String sub,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _blueBg : Colors.white,
          border: Border.all(
              color: selected ? _blue : _line, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: selected ? _blue : _sub),
            const SizedBox(height: 6),
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? _blue : _ink)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 11, color: _sub)),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, bool selected, VoidCallback onTap,
      {bool dense = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: dense ? 13 : 18, vertical: dense ? 8 : 9),
        decoration: BoxDecoration(
          color: selected ? _blue : Colors.white,
          border: Border.all(color: selected ? _blue : _line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : _ink,
          ),
        ),
      ),
    );
  }
}
