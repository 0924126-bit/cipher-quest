import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ticket.dart';
import '../../theme/app_theme.dart';
import '../dashboard_controller.dart';

/// Dashboard panel: online queue-ticket management.
///
/// - Issue online tickets (per-person code) or register paper tickets
/// - Call / start / finish / cancel / requeue / delete per ticket
/// - Per-ticket chat & arbitrary notifications (with unread badges)
/// - Queue settings (game length, changeover, capacity, late-cancel,
///   reviews on/off) — ETA recalculates automatically
class TicketPanel extends StatefulWidget {
  final DashboardController ctrl;
  const TicketPanel({super.key, required this.ctrl});

  @override
  State<TicketPanel> createState() => _TicketPanelState();
}

class _TicketPanelState extends State<TicketPanel> {
  bool _busy = false;
  bool _showFinished = false;

  DashboardController get ctrl => widget.ctrl;

  // ------------------------------------------------------------------
  // 発行
  // ------------------------------------------------------------------

  Future<void> _issueOnline() async {
    setState(() => _busy = true);
    try {
      final t = await ctrl.issueTicket(kind: 'online');
      if (!mounted) return;
      await _showCodeDialog(t);
    } catch (e) {
      _snackErr('発行に失敗: ${_msg(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _issuePaper() async {
    final labelCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('紙の整理券を登録'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '紙で配った整理券をこの待ち行列に組み込みます。オンライン券と同じ列で番号順に管理され、二重予約（オーバーブッキング）を防げます。',
              style: TextStyle(fontSize: 12.5, color: AppColors.dashGrey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'メモ（紙券の番号や名前など・任意）',
              ),
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
            child: const Text('登録'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ctrl.issueTicket(kind: 'paper', label: labelCtrl.text.trim());
    } catch (e) {
      _snackErr('登録に失敗: ${_msg(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showCodeDialog(Ticket t) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('整理券 ${t.number} を発行しました'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'このコードを来場者に渡してください。来場者は「/ticket」ページでコードを入力すると専用画面が開きます。',
              style: TextStyle(fontSize: 12.5, color: AppColors.dashGrey),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.dashBlue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                t.code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                  color: AppColors.dashBlue,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: t.code));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('コードをコピーしました')),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('コピー'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // helpers
  // ------------------------------------------------------------------

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _snackErr(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: AppColors.dashRed,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = ctrl.ticketSettings;
    final tickets = ctrl.tickets;
    final active = tickets.where((t) => t.isActive).toList();
    final finished = tickets.where((t) => !t.isActive).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- header ----
            Row(
              children: [
                const Icon(Icons.confirmation_number_outlined,
                    size: 20, color: AppColors.dashBlue),
                const SizedBox(width: 10),
                const Text(
                  'オンライン整理券',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.dashBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '受付中 ${ctrl.ticketActive} / ${s.capacity}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.dashBlue,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _issuePaper,
                  icon: const Icon(Icons.receipt_long, size: 16),
                  label: const Text('紙券を登録'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _busy ? null : _issueOnline,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('コードを発行'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '発行したコードを来場者に渡すと /ticket で専用画面が開きます。呼出→開始→終了はここから操作。'
              '予想開始時間は設定と行列から自動計算され、呼出後に来ない場合は自動キャンセルされます。',
              style: TextStyle(fontSize: 12, color: AppColors.dashGrey),
            ),
            const SizedBox(height: 14),

            // ---- settings ----
            _settingsBar(s),
            const SizedBox(height: 14),

            // ---- active list ----
            if (!ctrl.ticketsLoaded)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ))
            else if (active.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 26),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.dashLine),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.hourglass_empty,
                        size: 30, color: AppColors.dashGrey),
                    SizedBox(height: 8),
                    Text(
                      '現在待機中の整理券はありません',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.dashGrey),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (final t in active) ...[
                    _TicketRow(
                      ticket: t,
                      onAction: (a) => ctrl.ticketAction(t.id, a),
                      onChat: () => _openChat(t.id),
                      onNotify: () => _sendNotify(t),
                      onDelete: () => _confirmDelete(t),
                      onShowCode: t.kind == 'online' && t.code.isNotEmpty
                          ? () => _showCodeDialog(t)
                          : null,
                    ),
                    if (t != active.last)
                      const Divider(height: 1, color: AppColors.dashLine),
                  ],
                ],
              ),

            // ---- finished/cancelled (collapsed) ----
            if (finished.isNotEmpty) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => setState(() => _showFinished = !_showFinished),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        _showFinished ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: AppColors.dashGrey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '終了・キャンセル（${finished.length}）',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.dashGrey),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showFinished)
                Column(
                  children: [
                    for (final t in finished) ...[
                      _TicketRow(
                        ticket: t,
                        onAction: (a) => ctrl.ticketAction(t.id, a),
                        onChat: () => _openChat(t.id),
                        onNotify: () => _sendNotify(t),
                        onDelete: () => _confirmDelete(t),
                        onShowCode: null,
                      ),
                      if (t != finished.last)
                        const Divider(height: 1, color: AppColors.dashLine),
                    ],
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // 設定バー
  // ------------------------------------------------------------------

  Widget _settingsBar(TicketSettings s) {
    Widget chip(String label, String value, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.dashLine),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10.5, color: AppColors.dashGrey)),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 12, color: AppColors.dashGrey),
                ],
              ),
            ],
          ),
        ),
      );
    }

    String mmss(int sec) {
      final m = sec ~/ 60;
      final r = sec % 60;
      return r == 0 ? '$m分' : '$m分$r秒';
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        chip('1ゲームの時間', mmss(s.gameSec), () {
          _editNumber('1ゲームの時間（秒）', s.gameSec,
              (v) => ctrl.updateTicketSettings(gameSec: v));
        }),
        chip('入れ替え時間', mmss(s.intervalSec), () {
          _editNumber('入れ替え時間（秒）', s.intervalSec,
              (v) => ctrl.updateTicketSettings(intervalSec: v));
        }),
        chip('定員（同時受付上限）', '${s.capacity}組', () {
          _editNumber('定員（組）', s.capacity,
              (v) => ctrl.updateTicketSettings(capacity: v));
        }),
        chip('遅刻の自動キャンセル', mmss(s.lateCancelSec), () {
          _editNumber('呼出から自動キャンセルまで（秒）', s.lateCancelSec,
              (v) => ctrl.updateTicketSettings(lateCancelSec: v));
        }),
        FilterChip(
          selected: s.reviewsEnabled,
          onSelected: (v) => ctrl.updateTicketSettings(reviewsEnabled: v),
          label: Text(
            s.reviewsEnabled ? '口コミ 公開中' : '口コミ 非公開',
            style: const TextStyle(fontSize: 12.5),
          ),
          avatar: Icon(
            s.reviewsEnabled ? Icons.star : Icons.star_border,
            size: 16,
            color: s.reviewsEnabled ? AppColors.dashBlue : AppColors.dashGrey,
          ),
        ),
      ],
    );
  }

  Future<void> _editNumber(
      String title, int current, Future<void> Function(int) save) async {
    final ctrlText = TextEditingController(text: '$current');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: ctrlText,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル',
                style: TextStyle(color: AppColors.dashGrey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final v = int.tryParse(ctrlText.text);
    if (v == null) return;
    try {
      await save(v);
    } catch (e) {
      _snackErr('保存に失敗: ${_msg(e)}');
    }
  }

  // ------------------------------------------------------------------
  // チャット / 任意通知 / 削除
  // ------------------------------------------------------------------

  Future<void> _openChat(String id) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _TicketChatDialog(ctrl: ctrl, ticketId: id),
    );
  }

  Future<void> _sendNotify(Ticket t) async {
    final textCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${t.number} に通知を送る'),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '例: まもなくご案内できます。受付付近でお待ちください。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル',
                style: TextStyle(color: AppColors.dashGrey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('送信'),
          ),
        ],
      ),
    );
    if (ok != true || textCtrl.text.trim().isEmpty) return;
    try {
      await ctrl.ticketStaffMessage(t.id, 'notify', textCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('通知を送信しました')));
      }
    } catch (e) {
      _snackErr('送信に失敗: ${_msg(e)}');
    }
  }

  Future<void> _confirmDelete(Ticket t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('整理券を削除'),
        content: Text('${t.number} を完全に削除しますか？（来場者からも見えなくなります）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル',
                style: TextStyle(color: AppColors.dashGrey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dashRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ctrl.deleteTicket(t.id);
      } catch (e) {
        _snackErr('削除に失敗: ${_msg(e)}');
      }
    }
  }
}

// ====================================================================
// 1枚の整理券の行
// ====================================================================

class _TicketRow extends StatelessWidget {
  final Ticket ticket;
  final Future<bool> Function(String action) onAction;
  final VoidCallback onChat;
  final VoidCallback onNotify;
  final VoidCallback onDelete;
  final VoidCallback? onShowCode;

  const _TicketRow({
    required this.ticket,
    required this.onAction,
    required this.onChat,
    required this.onNotify,
    required this.onDelete,
    required this.onShowCode,
  });

  Color get _statusColor => switch (ticket.status) {
        'waiting' => AppColors.dashGrey,
        'called' => const Color(0xFFF29900),
        'playing' => const Color(0xFF188038),
        'done' => AppColors.dashBlue,
        _ => AppColors.dashRed,
      };

  String get _etaLabel {
    if (ticket.status != 'waiting') return '';
    final min = (ticket.etaSec / 60).ceil();
    return '約$min分後 / 前に${ticket.position}組';
  }

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // 番号
          SizedBox(
            width: 118,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.number,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  t.kind == 'paper'
                      ? '紙券${t.label.isNotEmpty ? ' · ${t.label}' : ''}'
                      : 'オンライン',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.dashGrey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 状態
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              t.statusLabel,
              style: TextStyle(
                  fontSize: 11.5,
                  color: _statusColor,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _etaLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 11.5, color: AppColors.dashGrey),
            ),
          ),
          // 操作ボタン群
          if (t.status == 'waiting')
            _actBtn('呼出', Icons.campaign_outlined, () => onAction('call')),
          if (t.status == 'called') ...[
            _actBtn('開始', Icons.play_arrow, () => onAction('start')),
            _actBtn('列に戻す', Icons.undo, () => onAction('requeue')),
          ],
          if (t.status == 'playing')
            _actBtn('終了', Icons.flag_outlined, () => onAction('finish')),
          if (t.isActive)
            _actBtn('取消', Icons.close, () => onAction('cancel'),
                color: AppColors.dashRed),
          // チャット（未読バッジ）
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'チャット',
                icon: const Icon(Icons.chat_bubble_outline,
                    size: 18, color: AppColors.dashGrey),
                onPressed: onChat,
              ),
              if (t.staffUnread > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.dashRed,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${t.staffUnread}',
                      style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: '通知を送る',
            icon: const Icon(Icons.notifications_none,
                size: 18, color: AppColors.dashGrey),
            onPressed: onNotify,
          ),
          if (onShowCode != null)
            IconButton(
              tooltip: 'コードを表示',
              icon: const Icon(Icons.qr_code_2,
                  size: 18, color: AppColors.dashGrey),
              onPressed: onShowCode,
            ),
          IconButton(
            tooltip: '削除',
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppColors.dashGrey),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _actBtn(String label, IconData icon, VoidCallback onTap,
      {Color color = AppColors.dashBlue}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14, color: color),
        label: Text(label, style: TextStyle(fontSize: 12, color: color)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size.zero,
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

// ====================================================================
// チャットダイアログ（スタッフ側）
// ====================================================================

class _TicketChatDialog extends StatefulWidget {
  final DashboardController ctrl;
  final String ticketId;
  const _TicketChatDialog({required this.ctrl, required this.ticketId});

  @override
  State<_TicketChatDialog> createState() => _TicketChatDialogState();
}

class _TicketChatDialogState extends State<_TicketChatDialog> {
  final _textCtrl = TextEditingController();
  bool _sending = false;

  Ticket? get _ticket {
    for (final t in widget.ctrl.tickets) {
      if (t.id == widget.ticketId) return t;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_onCtrl);
    // 開いたら既読化
    widget.ctrl.ticketAction(widget.ticketId, 'read');
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onCtrl);
    _textCtrl.dispose();
    super.dispose();
  }

  void _onCtrl() {
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.ctrl.ticketStaffMessage(widget.ticketId, 'chat', text);
      _textCtrl.clear();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _ticket;
    final chat = t?.chat ?? const <TicketChatMsg>[];
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('チャット — ${t?.number ?? ''}',
          style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 400,
        height: 380,
        child: Column(
          children: [
            Expanded(
              child: chat.isEmpty
                  ? const Center(
                      child: Text('まだメッセージはありません',
                          style: TextStyle(
                              fontSize: 12.5, color: AppColors.dashGrey)),
                    )
                  : ListView.builder(
                      reverse: true,
                      itemCount: chat.length,
                      itemBuilder: (context, i) {
                        final m = chat[chat.length - 1 - i];
                        final mine = m.from == 'staff';
                        final notice = m.kind == 'notice';
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            constraints: const BoxConstraints(maxWidth: 280),
                            decoration: BoxDecoration(
                              color: notice
                                  ? const Color(0xFFFFF3CD)
                                  : mine
                                      ? AppColors.dashBlue
                                          .withValues(alpha: 0.1)
                                      : const Color(0xFFF1F3F4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (notice)
                                  const Text('📢 通知',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF7A5C00),
                                          fontWeight: FontWeight.w700)),
                                Text(m.text,
                                    style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'メッセージ…',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send,
                      size: 20, color: AppColors.dashBlue),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('閉じる', style: TextStyle(color: AppColors.dashGrey)),
        ),
      ],
    );
  }
}
