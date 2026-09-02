import 'package:flutter/material.dart';

import '../../models/role_config.dart';
import '../../services/file_picker_stub.dart'
    if (dart.library.js_interop) '../../services/file_picker_web.dart';
import '../../theme/app_theme.dart';
import '../dashboard_controller.dart';

/// ロールページ(チェイサー / 呪術師 / ハンター)の設定パネル。
///
/// - 各ページの表示文言の変更
/// - 警報の秒数、呪いのクールダウン秒数
/// - 呪いボタンの画像差し替え / 削除
/// - 各ページURLのコピー
/// - 呪い発動履歴の表示
class RolePanel extends StatefulWidget {
  final DashboardController ctrl;
  const RolePanel({super.key, required this.ctrl});

  @override
  State<RolePanel> createState() => _RolePanelState();
}

class _RolePanelState extends State<RolePanel> {
  bool _uploading = false;
  bool _uploadingTimer = false;

  DashboardController get ctrl => widget.ctrl;

  Future<void> _uploadImage() async {
    final picked = await pickImageFile();
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await ctrl.uploadCurseImage(
          filename: picked.name, bytes: picked.bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('呪いボタンの画像を差し替えました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _uploadTimerImage() async {
    final picked = await pickImageFile();
    if (picked == null || !mounted) return;
    setState(() => _uploadingTimer = true);
    try {
      await ctrl.uploadTimerImage(
          filename: picked.name, bytes: picked.bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('タイマーの背景画像を差し替えました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingTimer = false);
    }
  }

  Future<void> _editText({
    required String dialogTitle,
    required String initial,
    required Future<void> Function(String) onSave,
  }) async {
    final c = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(dialogTitle, style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 100,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await onSave(result);
    }
  }

  Future<void> _editSeconds({
    required String dialogTitle,
    required int initial,
    required Future<void> Function(int) onSave,
  }) async {
    var value = initial.toDouble();
    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: Text(dialogTitle, style: const TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${value.round()} 秒',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dashAmber,
                ),
              ),
              Slider(
                value: value.clamp(3, 180),
                min: 3,
                max: 180,
                divisions: 177,
                onChanged: (v) => setInner(() => value = v),
              ),
              const Text(
                '3秒〜180秒の範囲で設定できます',
                style:
                    TextStyle(fontSize: 12, color: AppColors.dashGrey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, value.round()),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (result != null) await onSave(result);
  }

  void _copyUrl(String url, String label) {
    // Clipboard API はダイアログ表示で代替(確実にコピーできる手段を提示)
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$label のURL', style: const TextStyle(fontSize: 16)),
        content: SelectableText(
          url,
          style: const TextStyle(fontSize: 14, color: AppColors.dashAmber),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roles = ctrl.roles;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.theater_comedy,
                    size: 20, color: AppColors.dashCurse),
                SizedBox(width: 10),
                Text(
                  'ロールページ',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                SizedBox(width: 10),
                Text(
                  'チェイサー・呪術師・ハンターの画面設定',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.dashGrey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 860;
                final cards = [
                  _chaserCard(roles.chaser),
                  _cursedCard(roles.cursed),
                  _hunterCard(roles.hunter),
                  _timerCard(roles.timer),
                ];
                if (narrow) {
                  return Column(
                    children: [
                      for (final c in cards) ...[
                        c,
                        const SizedBox(height: 12)
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      Expanded(child: cards[i]),
                      if (i != cards.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                );
              },
            ),
            if (ctrl.curseEvents.isNotEmpty) ...[
              const SizedBox(height: 16),
              _curseLog(),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- チェイサー ----------
  Widget _chaserCard(ChaserConfig c) {
    return _roleCard(
      icon: Icons.notifications_active,
      iconColor: AppColors.dashRed,
      roleName: 'チェイサー',
      url: ctrl.chaserUrl(),
      urlLabel: 'チェイサーページ',
      rows: [
        _settingRow(
          label: '表示タイトル',
          value: c.title,
          onTap: () => _editText(
            dialogTitle: 'チェイサーの表示タイトル',
            initial: c.title,
            onSave: (v) => ctrl.updateRole('chaser', title: v),
          ),
        ),
        _settingRow(
          label: 'サブタイトル',
          value: c.subtitle,
          onTap: () => _editText(
            dialogTitle: 'チェイサーのサブタイトル',
            initial: c.subtitle,
            onSave: (v) => ctrl.updateRole('chaser', subtitle: v),
          ),
        ),
        _settingRow(
          label: '警報の長さ',
          value: '${c.alarmSec} 秒',
          onTap: () => _editSeconds(
            dialogTitle: '警報が鳴り続ける秒数',
            initial: c.alarmSec,
            onSave: (v) => ctrl.updateRole('chaser', alarmSec: v),
          ),
        ),
      ],
    );
  }

  // ---------- 呪術師 ----------
  Widget _cursedCard(CursedConfig c) {
    return _roleCard(
      icon: Icons.auto_fix_high,
      iconColor: AppColors.dashCurse,
      roleName: '呪術師',
      url: ctrl.cursedUrl(),
      urlLabel: '呪術師ページ',
      rows: [
        _settingRow(
          label: '表示タイトル',
          value: c.title,
          onTap: () => _editText(
            dialogTitle: '呪術師の表示タイトル',
            initial: c.title,
            onSave: (v) => ctrl.updateRole('cursed', title: v),
          ),
        ),
        _settingRow(
          label: 'クールダウン',
          value: '${c.cooldownSec} 秒',
          onTap: () => _editSeconds(
            dialogTitle: '呪いボタンのクールダウン秒数',
            initial: c.cooldownSec,
            onSave: (v) => ctrl.updateRole('cursed', cooldownSec: v),
          ),
        ),
        _settingRow(
          label: '通知メッセージ',
          value: c.notifyMessage,
          onTap: () => _editText(
            dialogTitle: '呪い発動時の通知メッセージ',
            initial: c.notifyMessage,
            onSave: (v) =>
                ctrl.updateRole('cursed', notifyMessage: v),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (c.buttonImage.isNotEmpty)
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.dashLine),
                  image: DecorationImage(
                    image: NetworkImage(c.buttonImage),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _uploading ? null : _uploadImage,
                icon: _uploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.image, size: 16),
                label: Text(
                  c.buttonImage.isEmpty ? 'ボタン画像を設定' : '画像を変更',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            if (c.buttonImage.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: '画像を削除して既定の刻印に戻す',
                onPressed: () => ctrl.deleteCurseImage(),
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.dashRed),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ---------- ハンター ----------
  Widget _hunterCard(HunterConfig c) {
    return _roleCard(
      icon: Icons.phone_iphone,
      iconColor: AppColors.dashAmber,
      roleName: 'ハンター端末',
      url: ctrl.hunterUrl(),
      urlLabel: 'ハンター通知ページ',
      rows: [
        _settingRow(
          label: '表示タイトル',
          value: c.title,
          onTap: () => _editText(
            dialogTitle: 'ハンター端末の表示タイトル',
            initial: c.title,
            onSave: (v) => ctrl.updateRole('hunter', title: v),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '呪術師がボタンを押すと、この端末に音とバイブ付きで通知が届きます。',
          style: TextStyle(
              fontSize: 11.5, color: AppColors.dashGrey, height: 1.6),
        ),
      ],
    );
  }

  // ---------- 廃校タイマー ----------
  Widget _timerCard(TimerConfig c) {
    return _roleCard(
      icon: Icons.hourglass_bottom,
      iconColor: const Color(0xFF7A2430),
      roleName: '廃校タイマー',
      url: ctrl.timerUrl(),
      urlLabel: 'タイマーページ',
      rows: [
        _settingRow(
          label: '表示タイトル',
          value: c.title,
          onTap: () => _editText(
            dialogTitle: 'タイマーの表示タイトル',
            initial: c.title,
            onSave: (v) => ctrl.updateRole('timer', title: v),
          ),
        ),
        _settingRow(
          label: 'サブタイトル',
          value: c.subtitle,
          onTap: () => _editText(
            dialogTitle: 'タイマーのサブタイトル',
            initial: c.subtitle,
            onSave: (v) => ctrl.updateRole('timer', subtitle: v),
          ),
        ),
        _settingRow(
          label: '制限時間',
          value: '${c.durationSec ~/ 60}分 ${c.durationSec % 60}秒',
          onTap: () => _editTimerDuration(c.durationSec),
        ),
        _settingRow(
          label: 'デザイン',
          value: _timerStyleLabel(c.style),
          onTap: () => _pickTimerStyle(c.style),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.dashLine),
                image: DecorationImage(
                  image: NetworkImage(c.bgImage.isNotEmpty
                      ? c.bgImage
                      : '/images/timer_bg.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _uploadingTimer ? null : _uploadTimerImage,
                icon: _uploadingTimer
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.image, size: 16),
                label: Text(
                  c.bgImage.isEmpty ? '背景画像を変更' : '画像を変更',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            if (c.bgImage.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: '画像を削除して既定の廃校背景に戻す',
                onPressed: () => ctrl.deleteTimerImage(),
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.dashRed),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'BGM・キー音は下の「効果音」パネルでmp3をアップロードし、'
          '「タイマーBGM」「タイマーキー音」に割り当てると差し替わります。',
          style: TextStyle(
              fontSize: 11, color: AppColors.dashGrey, height: 1.6),
        ),
      ],
    );
  }

  // ---------- タイマーデザイン選択 ----------
  static const List<(String, String, String, IconData)> _timerStyles = [
    ('candles', '儀式の蝋燭', '13本の蝋燭が燃え尽きていく（数字なし・既定）',
        Icons.local_fire_department),
    ('digits', '数字表示', 'シンプルな残り秒数（MM:SS）。明滅つき', Icons.timer),
    ('bloodmoon', '血月蝕', '月が闇に食われていく。残り僅かで血の色に',
        Icons.dark_mode),
    ('hourglass', '血の砂時計', '血が落ちきったら刻限', Icons.hourglass_bottom),
    ('heartbeat', '心電図', '鼓動が弱まり、刻限で心停止', Icons.monitor_heart),
  ];

  String _timerStyleLabel(String style) {
    for (final s in _timerStyles) {
      if (s.$1 == style) return s.$2;
    }
    return '儀式の蝋燭';
  }

  Future<void> _pickTimerStyle(String current) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('タイマーのデザイン', style: TextStyle(fontSize: 16)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final s in _timerStyles)
                ListTile(
                  dense: true,
                  leading: Icon(s.$4,
                      size: 20,
                      color: s.$1 == current
                          ? AppColors.dashAmber
                          : AppColors.dashGrey),
                  title: Text(s.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: s.$1 == current
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: s.$1 == current
                            ? AppColors.dashAmber
                            : null,
                      )),
                  subtitle: Text(s.$3,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.dashGrey)),
                  trailing: s.$1 == current
                      ? const Icon(Icons.check,
                          size: 16, color: AppColors.dashAmber)
                      : null,
                  onTap: () => Navigator.pop(context, s.$1),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
    if (result != null && result != current) {
      await ctrl.updateRole('timer', style: result);
    }
  }

  Future<void> _editTimerDuration(int initial) async {
    const minSec = 30; // 下限30秒
    const maxSec = 7200; // 上限120分
    // 30秒刻みに丸めて範囲内へ
    var sec = ((initial / 30).round() * 30).clamp(minSec, maxSec);
    String fmt(int s) =>
        s % 60 == 0 ? '${s ~/ 60} 分' : '${s ~/ 60} 分 ${s % 60} 秒';
    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) {
          Widget stepBtn(String label, int delta) {
            final next = sec + delta;
            final enabled = next >= minSec && next <= maxSec;
            return OutlinedButton(
              onPressed: enabled
                  ? () => setInner(
                      () => sec = next.clamp(minSec, maxSec))
                  : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(88, 44),
                side: const BorderSide(color: AppColors.dashLine),
              ),
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            );
          }

          return AlertDialog(
            title: const Text('タイマーの制限時間',
                style: TextStyle(fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fmt(sec),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dashAmber,
                  ),
                ),
                const SizedBox(height: 12),
                // ±30秒ボタン
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    stepBtn('−30秒', -30),
                    const SizedBox(width: 12),
                    stepBtn('+30秒', 30),
                  ],
                ),
                const SizedBox(height: 4),
                // 大まかな調整用スライダー（30秒刻み）
                Slider(
                  value: sec.toDouble(),
                  min: minSec.toDouble(),
                  max: maxSec.toDouble(),
                  divisions: (maxSec - minSec) ~/ 30,
                  onChanged: (v) => setInner(
                      () => sec = ((v / 30).round() * 30)
                          .clamp(minSec, maxSec)),
                ),
                const Text(
                  '30秒〜120分の範囲で30秒刻みに設定できます',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.dashGrey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, sec),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
    if (result != null) {
      await ctrl.updateRole('timer', durationSec: result);
    }
  }

  // ---------- 共通部品 ----------
  Widget _roleCard({
    required IconData icon,
    required Color iconColor,
    required String roleName,
    required String url,
    required String urlLabel,
    required List<Widget> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dashSurfaceHi,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.dashLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                roleName,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _copyUrl(url, urlLabel),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Icon(Icons.link,
                          size: 15, color: AppColors.dashAmber),
                      SizedBox(width: 4),
                      Text('URL',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.dashAmber,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _settingRow({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.dashGrey),
              ),
            ),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
            const Icon(Icons.edit,
                size: 13, color: AppColors.dashGrey),
          ],
        ),
      ),
    );
  }

  Widget _curseLog() {
    two(int n) => n.toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dashCurse.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppColors.dashCurse.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_fix_high,
                  size: 15, color: AppColors.dashCurse),
              SizedBox(width: 8),
              Text(
                '呪い発動履歴',
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...ctrl.curseEvents.take(5).map((ev) {
            final dt =
                DateTime.fromMillisecondsSinceEpoch(ev.atMs);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Text(
                    '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.dashGrey),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(ev.message,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
