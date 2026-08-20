import 'package:flutter/material.dart';

import '../../models/sound_asset.dart';
import '../../services/file_picker_stub.dart'
    if (dart.library.js_interop) '../../services/file_picker_web.dart';
import '../../theme/app_theme.dart';
import '../dashboard_controller.dart';

/// Dashboard panel for managing uploaded mp3 sounds.
///
/// Operators upload files and assign each a role; assignments are pushed
/// live to every open machine page via websocket.
class SoundPanel extends StatefulWidget {
  final DashboardController ctrl;
  const SoundPanel({super.key, required this.ctrl});

  @override
  State<SoundPanel> createState() => _SoundPanelState();
}

class _SoundPanelState extends State<SoundPanel> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final picked = await pickMp3File();
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await widget.ctrl.uploadSound(
        filename: picked.name,
        bytes: picked.bytes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${picked.name}」をアップロードしました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('アップロード失敗: $e'),
            backgroundColor: AppColors.dashRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sounds = widget.ctrl.sounds;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.library_music,
                    size: 20, color: AppColors.dashBlue),
                const SizedBox(width: 10),
                const Text(
                  'サウンド管理（mp3）',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _uploading ? null : _pickAndUpload,
                  icon: _uploading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file, size: 16),
                  label: Text(_uploading ? 'アップロード中...' : 'mp3を追加'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '用途を割り当てると全ての暗号機ページに即時反映されます（解読中ループ / 解読完了 / スキルチェック出現・成功・失敗）。「未割当（初期音）」に戻すと内蔵のデフォルト音が使われます。',
              style: TextStyle(fontSize: 12, color: AppColors.dashGrey),
            ),
            const SizedBox(height: 14),
            if (sounds.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 26),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.dashLine),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.music_off,
                        size: 30, color: AppColors.dashGrey),
                    SizedBox(height: 8),
                    Text(
                      'まだサウンドがありません。mp3を追加してください。',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.dashGrey),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (final s in sounds) ...[
                    _SoundRow(
                      sound: s,
                      onRoleChanged: (role) =>
                          widget.ctrl.setSoundRole(s.id, role),
                      onDelete: () => _confirmDelete(s),
                    ),
                    if (s != sounds.last)
                      const Divider(height: 1, color: AppColors.dashLine),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(SoundAsset s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('サウンドを削除'),
        content: Text('「${s.originalName}」を削除しますか？'),
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
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true) await widget.ctrl.deleteSound(s.id);
  }
}

/// One uploaded sound: name + size + role dropdown + delete.
class _SoundRow extends StatelessWidget {
  final SoundAsset sound;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onDelete;

  const _SoundRow({
    required this.sound,
    required this.onRoleChanged,
    required this.onDelete,
  });

  String get _sizeLabel {
    final kb = sound.sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final assigned = sound.role != 'none';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            assigned ? Icons.music_note : Icons.audio_file,
            size: 20,
            color: assigned ? AppColors.dashBlue : AppColors.dashGrey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sound.originalName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(
                  _sizeLabel,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.dashGrey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: sound.role,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(12),
            style: TextStyle(
              fontSize: 13,
              color: assigned ? AppColors.dashBlue : AppColors.dashGrey,
              fontWeight: assigned ? FontWeight.w600 : FontWeight.w400,
            ),
            items: [
              for (final e in SoundAsset.roleLabels.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) {
              if (v != null && v != sound.role) onRoleChanged(v);
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: '削除',
            icon: const Icon(Icons.delete_outline,
                size: 19, color: AppColors.dashGrey),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
