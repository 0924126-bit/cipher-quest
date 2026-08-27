import 'package:flutter/material.dart';

import '../../models/sound_asset.dart';
import '../../services/file_picker_stub.dart'
    if (dart.library.js_interop) '../../services/file_picker_web.dart';
import '../../services/key_sound_map.dart';
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
            // ---- タイマー: キー別効果音 ----
            const SizedBox(height: 22),
            _keyBindingSection(sounds),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // タイマーのキー別効果音（例: 「e」→ きゅいん）。何個でも設定可。
  // ------------------------------------------------------------------

  Widget _keyBindingSection(List<SoundAsset> sounds) {
    final bindings = widget.ctrl.keyBindings;
    final soundById = {for (final s in sounds) s.id: s};
    final entries = bindings.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.keyboard, size: 18, color: AppColors.dashBlue),
            SizedBox(width: 8),
            Text(
              'タイマーのキー別効果音',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'タイマー画面で指定のキーを押したときに鳴る音を1対1で割り当てます（何個でも追加可）。未割当のキーは「タイマーキー音（既定）」が鳴ります。',
          style: TextStyle(fontSize: 12, color: AppColors.dashGrey),
        ),
        const SizedBox(height: 12),
        if (sounds.isEmpty)
          const Text(
            '先にmp3をアップロードするとキーに割り当てられます。',
            style: TextStyle(fontSize: 12.5, color: AppColors.dashGrey),
          )
        else ...[
          if (entries.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in entries)
                  InputChip(
                    avatar: const Icon(Icons.keyboard_alt_outlined,
                        size: 16, color: AppColors.dashBlue),
                    label: Text(
                      '${KeySoundMap.label(e.key)} → '
                      '${soundById[e.value]?.originalName ?? '(削除済みの音)'}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    onDeleted: () => widget.ctrl.removeKeySound(e.key),
                    deleteIconColor: AppColors.dashGrey,
                  ),
              ],
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _addKeyBinding(sounds),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('キー割当を追加'),
          ),
        ],
      ],
    );
  }

  Future<void> _addKeyBinding(List<SoundAsset> sounds) async {
    String selKey = 'e';
    String selSound = sounds.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('キー割当を追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('キー', style: TextStyle(fontSize: 12.5)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selKey,
                isExpanded: true,
                items: [
                  for (final k in KeySoundMap.allKeys)
                    DropdownMenuItem(
                        value: k, child: Text(KeySoundMap.label(k))),
                ],
                onChanged: (v) => setDlg(() => selKey = v ?? selKey),
              ),
              const SizedBox(height: 16),
              const Text('鳴らす音', style: TextStyle(fontSize: 12.5)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selSound,
                isExpanded: true,
                items: [
                  for (final s in sounds)
                    DropdownMenuItem(
                      value: s.id,
                      child: Text(s.originalName,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setDlg(() => selSound = v ?? selSound),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル',
                  style: TextStyle(color: AppColors.dashGrey)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('割り当てる'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      try {
        await widget.ctrl.setKeySound(selKey, selSound);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('割当に失敗: $e'),
            backgroundColor: AppColors.dashRed,
          ));
        }
      }
    }
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
