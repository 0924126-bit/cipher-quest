import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../dashboard_controller.dart';

/// よく使う操作をまとめたパネル（ダッシュボード最上部）。
///
/// - 全体リセット: 全暗号機の進捗/速度 + チェイサー警報を一括で初期化
/// - チェイサー警報の再許可: 1回限り警報の再チャージ
class QuickActionsPanel extends StatefulWidget {
  final DashboardController ctrl;
  const QuickActionsPanel({super.key, required this.ctrl});

  @override
  State<QuickActionsPanel> createState() => _QuickActionsPanelState();
}

class _QuickActionsPanelState extends State<QuickActionsPanel> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String doneMsg) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(doneMsg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('失敗しました: $e'),
          backgroundColor: AppColors.dashRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmGlobalReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('全体リセット'),
        content: const Text(
          '以下をまとめて初期状態に戻します。\n\n'
          '・全暗号機の解読進捗 → 0%\n'
          '・全暗号機の解読速度 → 100%\n'
          '・チェイサー警報 → 再び使用可能に\n\n'
          '実行しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル',
                style: TextStyle(color: AppColors.dashGrey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.dashRed,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('リセット実行'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => widget.ctrl.globalReset(), '全体リセットを実行しました');
    }
  }

  @override
  Widget build(BuildContext context) {
    final armed = widget.ctrl.roles.chaser.alarmArmed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bolt, size: 20, color: AppColors.dashAmber),
                SizedBox(width: 10),
                Text(
                  'クイック操作',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // ---- 全体リセット ----
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.dashRed,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                  onPressed: _busy ? null : _confirmGlobalReset,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('全体リセット'),
                ),
                // ---- チェイサー警報の再許可 ----
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        armed ? AppColors.dashSurfaceHi : AppColors.dashAmber,
                    foregroundColor:
                        armed ? AppColors.dashGrey : Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                  onPressed: _busy || armed
                      ? null
                      : () => _run(() => widget.ctrl.armChaserAlarm(),
                          'チェイサー警報を再許可しました'),
                  icon: Icon(
                    armed
                        ? Icons.notifications_active
                        : Icons.notification_add,
                    size: 18,
                  ),
                  label: Text(armed ? '警報: 使用可能' : '警報を再許可'),
                ),
                if (_busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
