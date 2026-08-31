import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ticket.dart';
import '../../services/api_service.dart';
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
    final codeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('オンライン整理券を発行'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'コードを自由に決められます（英数4〜12文字）。空欄のまま発行すると自動生成されます。',
              style: TextStyle(fontSize: 12.5, color: AppColors.dashGrey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              autofocus: true,
              maxLength: 12,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              ],
              decoration: const InputDecoration(
                labelText: 'コード（任意・未入力で自動生成）',
                counterText: '',
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
            child: const Text('発行'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final t = await ctrl.issueTicket(
          kind: 'online', code: codeCtrl.text.trim().toUpperCase());
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
    final placeCtrl = TextEditingController();
    DateTime? slotAt;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('紙の整理券を登録'),
          content: SizedBox(
            width: 400,
            child: Column(
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
                const SizedBox(height: 12),
                TextField(
                  controller: placeCtrl,
                  decoration: const InputDecoration(
                    labelText: '集合場所（任意・例: 3年2組前 受付）',
                  ),
                ),
                const SizedBox(height: 12),
                // 集合日時（任意）: 設定すると15分前/5分前の自動リマインダー対象
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        slotAt == null
                            ? '集合日時: 未設定（先着順）'
                            : '集合日時: ${slotAt!.month}/${slotAt!.day} '
                                '${slotAt!.hour}:${slotAt!.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: context,
                          initialDate: slotAt ?? now,
                          firstDate: now.subtract(const Duration(days: 1)),
                          lastDate: now.add(const Duration(days: 60)),
                        );
                        if (d == null || !context.mounted) return;
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(slotAt ?? now),
                        );
                        if (t == null) return;
                        setDlg(() => slotAt = DateTime(
                            d.year, d.month, d.day, t.hour, t.minute));
                      },
                      child: const Text('選択'),
                    ),
                    if (slotAt != null)
                      IconButton(
                        tooltip: 'クリア',
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setDlg(() => slotAt = null),
                      ),
                  ],
                ),
                if (slotAt != null)
                  const Text(
                    '設定した日時の15分前・5分前に自動通知されます（オンライン閲覧者のみ）',
                    style:
                        TextStyle(fontSize: 11.5, color: AppColors.dashGrey),
                  ),
              ],
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
              child: const Text('登録'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ctrl.issueTicket(
        kind: 'paper',
        label: labelCtrl.text.trim(),
        reservedSlot:
            slotAt == null ? 0 : slotAt!.millisecondsSinceEpoch ~/ 1000,
        place: placeCtrl.text.trim(),
      );
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

  /// 検索クエリ（番号・名前メモ・Googleアカウント・コードで絞り込み）
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  bool _matches(Ticket t) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return t.number.toLowerCase().contains(q) ||
        t.label.toLowerCase().contains(q) ||
        t.reservedEmail.toLowerCase().contains(q) ||
        t.code.toLowerCase().contains(q) ||
        t.place.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final s = ctrl.ticketSettings;
    final tickets = ctrl.tickets.where(_matches).toList();
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

            // ---- 検索 + タイムライン ----
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(fontSize: 13.5),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                        hintText: '検索：番号・名前・Googleアカウント・コード',
                        hintStyle: const TextStyle(
                            fontSize: 12.5, color: AppColors.dashGrey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.dashLine),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showTimeline(context),
                  icon: const Icon(Icons.schedule, size: 16),
                  label: const Text('タイムライン',
                      style: TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
            if (_searchQuery.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '検索結果: ${tickets.length}件',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.dashGrey),
              ),
            ],
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
        ActionChip(
          onPressed: _manageReviews,
          avatar: const Icon(Icons.rate_review_outlined,
              size: 16, color: AppColors.dashBlue),
          label: const Text('口コミ管理',
              style: TextStyle(fontSize: 12.5, color: AppColors.dashBlue)),
        ),
        // ---- 予約設定 ----
        FilterChip(
          selected: s.reserveEnabled,
          onSelected: (v) => ctrl.updateTicketSettings(reserveEnabled: v),
          label: Text(
            s.reserveEnabled ? '予約 受付中' : '予約 停止中',
            style: const TextStyle(fontSize: 12.5),
          ),
          avatar: Icon(
            s.reserveEnabled ? Icons.event_available : Icons.event_busy,
            size: 16,
            color: s.reserveEnabled ? AppColors.dashBlue : AppColors.dashGrey,
          ),
        ),
        chip('予約スロット長', mmss(s.reserveSlotSec), () {
          _editNumber('予約スロットの長さ（分）', s.reserveSlotSec ~/ 60,
              (v) => ctrl.updateTicketSettings(reserveSlotSec: v * 60));
        }),
        chip('スロットあたり組数', '${s.reserveSlotCapacity}組', () {
          _editNumber('1スロットあたりの組数', s.reserveSlotCapacity,
              (v) => ctrl.updateTicketSettings(reserveSlotCapacity: v));
        }),
        chip('予約可能日時', '${s.reserveWindows.length}件', _editWindows),
        chip('予約許可メール', '${s.reserveAllowedEmails.length}件',
            _editAllowedEmails),
        ActionChip(
          onPressed: () => Navigator.of(context).pushNamed('/desk'),
          avatar: const Icon(Icons.point_of_sale,
              size: 16, color: AppColors.dashBlue),
          label: const Text('受付デスクを開く',
              style: TextStyle(fontSize: 12.5, color: AppColors.dashBlue)),
        ),
      ],
    );
  }

  // ---- タイムライン: 日時ごとに誰がどの順番で来るかを一望 ----
  Future<void> _showTimeline(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _TimelineDialog(tickets: ctrl.tickets),
    );
  }

  // ---- 口コミ管理（一覧・削除） ----
  Future<void> _manageReviews() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => const _ReviewModerationDialog(),
    );
  }

  // ---- 予約可能日時ウィンドウの編集 ----
  Future<void> _editWindows() async {
    final windows = List<ReserveWindow>.from(ctrl.ticketSettings.reserveWindows);
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) {
          Future<void> addWindow() async {
            final now = DateTime.now();
            final date = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: now.subtract(const Duration(days: 1)),
              lastDate: now.add(const Duration(days: 365)),
            );
            if (date == null || !context.mounted) return;
            final start = await showTimePicker(
              context: context,
              initialTime: const TimeOfDay(hour: 10, minute: 0),
              helpText: '開始時刻',
            );
            if (start == null || !context.mounted) return;
            final end = await showTimePicker(
              context: context,
              initialTime: const TimeOfDay(hour: 15, minute: 0),
              helpText: '終了時刻',
            );
            if (end == null) return;
            if (end.hour * 60 + end.minute <= start.hour * 60 + start.minute) {
              return;
            }
            String two(int v) => v.toString().padLeft(2, '0');
            setD(() => windows.add(ReserveWindow(
                  date:
                      '${date.year}-${two(date.month)}-${two(date.day)}',
                  start: '${two(start.hour)}:${two(start.minute)}',
                  end: '${two(end.hour)}:${two(end.minute)}',
                )));
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('予約可能な日時'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ここで追加した日時の範囲内だけ、来場者が /reserve から予約できます。'
                    'スロットは設定の長さで自動分割されます。',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.dashGrey),
                  ),
                  const SizedBox(height: 12),
                  if (windows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('まだありません。「日時を追加」から登録してください。',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.dashGrey)),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (var i = 0; i < windows.length; i++)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.event,
                                  size: 18, color: AppColors.dashBlue),
                              title: Text(
                                  '${windows[i].date}  ${windows[i].start}〜${windows[i].end}',
                                  style: const TextStyle(fontSize: 13.5)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: AppColors.dashRed),
                                onPressed: () =>
                                    setD(() => windows.removeAt(i)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: addWindow,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('日時を追加'),
                  ),
                ],
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
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
    if (changed != true) return;
    try {
      await ctrl.updateTicketSettings(reserveWindows: windows);
    } catch (e) {
      _snackErr('保存に失敗: ${_msg(e)}');
    }
  }

  // ---- 予約許可メールの編集（gse.okayama-c.ed.jp ドメインは常時許可） ----
  Future<void> _editAllowedEmails() async {
    final emails =
        List<String>.from(ctrl.ticketSettings.reserveAllowedEmails);
    final inputCtrl = TextEditingController();
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) {
          void addEmail() {
            final v = inputCtrl.text.trim().toLowerCase();
            if (v.isEmpty || !v.contains('@') || emails.contains(v)) return;
            setD(() {
              emails.add(v);
              inputCtrl.clear();
            });
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('予約を許可するメールアドレス'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '@gse.okayama-c.ed.jp のGoogleアカウントは常に予約できます。'
                    'それ以外のアカウントを許可したい場合だけ、ここに追加してください。',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.dashGrey),
                  ),
                  const SizedBox(height: 12),
                  if (emails.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('追加の許可メールはありません（ドメインのみ）。',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.dashGrey)),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (var i = 0; i < emails.length; i++)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.mail_outline,
                                  size: 18, color: AppColors.dashBlue),
                              title: Text(emails[i],
                                  style: const TextStyle(fontSize: 13.5)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: AppColors.dashRed),
                                onPressed: () =>
                                    setD(() => emails.removeAt(i)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: inputCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'example@gmail.com',
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 13.5),
                          onSubmitted: (_) => addEmail(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: addEmail,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('追加'),
                      ),
                    ],
                  ),
                ],
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
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
    if (changed != true) return;
    try {
      await ctrl.updateTicketSettings(reserveAllowedEmails: emails);
    } catch (e) {
      _snackErr('保存に失敗: ${_msg(e)}');
    }
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
      builder: (context) => TicketChatDialog(ctrl: ctrl, ticketId: id),
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
            tooltip: '詳細を見る',
            icon: const Icon(Icons.more_horiz,
                size: 20, color: AppColors.dashGrey),
            onPressed: () => _showDetail(context),
          ),
        ],
      ),
    );
  }

  // ---- 詳細ダイアログ: Googleアカウント・各種時刻・補助操作を集約 ----
  void _showDetail(BuildContext context) {
    final t = ticket;
    String when(int sec) {
      if (sec <= 0) return '—';
      final d = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
      return '${d.month}/${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    }

    Widget row(String label, String value, {bool selectable = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.dashGrey)),
            ),
            Expanded(
              child: selectable
                  ? SelectableText(value,
                      style: const TextStyle(fontSize: 13.5))
                  : Text(value, style: const TextStyle(fontSize: 13.5)),
            ),
          ],
        ),
      );
    }

    final slotLabel = t.reservedSlot > 0
        ? () {
            final d =
                DateTime.fromMillisecondsSinceEpoch(t.reservedSlot * 1000);
            return '${d.month}/${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}〜';
          }()
        : '—（当日券）';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text('No.${t.number}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(t.statusLabel,
                  style: TextStyle(
                      fontSize: 12,
                      color: _statusColor,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                row('種別', t.kind == 'paper' ? '紙の整理券' : 'オンライン'),
                if (t.label.isNotEmpty) row('名前・メモ', t.label),
                row(
                  'Googleアカウント',
                  t.reservedEmail.isEmpty ? '—（未使用）' : t.reservedEmail,
                  selectable: t.reservedEmail.isNotEmpty,
                ),
                row('予約枠・集合日時', slotLabel),
                if (t.place.isNotEmpty) row('集合場所', t.place),
                const Divider(height: 20),
                row('発行', when(t.createdAt)),
                row('呼出', when(t.calledAt)),
                row('開始', when(t.startedAt)),
                row('終了', when(t.finishedAt)),
                if (t.cancelledAt > 0) ...[
                  row('キャンセル', when(t.cancelledAt)),
                  row(
                      'キャンセル理由',
                      switch (t.cancelReason) {
                        'late' => '遅刻による自動キャンセル',
                        'user' => '本人によるキャンセル',
                        _ => '運営によるキャンセル',
                      }),
                ],
                if (t.reviewPosted) row('口コミ', '投稿済み'),
                const Divider(height: 20),
                // 補助操作（使用頻度の低いものはここに集約）
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onNotify();
                      },
                      icon: const Icon(Icons.notifications_none, size: 16),
                      label: const Text('通知を送る',
                          style: TextStyle(fontSize: 12.5)),
                    ),
                    if (onShowCode != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onShowCode!();
                        },
                        icon: const Icon(Icons.qr_code_2, size: 16),
                        label: const Text('コードを表示',
                            style: TextStyle(fontSize: 12.5)),
                      ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.dashRed,
                        side: BorderSide(
                            color:
                                AppColors.dashRed.withValues(alpha: 0.4)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDelete();
                      },
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('削除',
                          style: TextStyle(fontSize: 12.5)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
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

class TicketChatDialog extends StatefulWidget {
  final DashboardController ctrl;
  final String ticketId;
  const TicketChatDialog(
      {super.key, required this.ctrl, required this.ticketId});

  @override
  State<TicketChatDialog> createState() => TicketChatDialogState();
}

class TicketChatDialogState extends State<TicketChatDialog> {
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

/// 口コミ管理ダイアログ: 一覧表示と削除（モデレーション）。
class _ReviewModerationDialog extends StatefulWidget {
  const _ReviewModerationDialog();

  @override
  State<_ReviewModerationDialog> createState() =>
      _ReviewModerationDialogState();
}

class _ReviewModerationDialogState extends State<_ReviewModerationDialog> {
  List<Review> _reviews = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (_, reviews) = await ApiService.instance.listReviews();
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '読み込みに失敗しました';
      });
    }
  }

  Future<void> _delete(Review r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('口コミを削除'),
        content: Text(
            '${r.name.isEmpty ? '' : '${r.name} '}No.${r.ticketNumber} ★${r.stars}\n「${r.text}」\n\nこの口コミを削除しますか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = await ApiService.instance.deleteReview(r.id);
    if (!mounted) return;
    if (done) {
      setState(() => _reviews = _reviews.where((x) => x.id != r.id).toList());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('削除に失敗しました')),
      );
    }
  }

  String _when(int at) {
    final d = DateTime.fromMillisecondsSinceEpoch(at * 1000);
    return '${d.month}/${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.rate_review_outlined,
              size: 20, color: AppColors.dashBlue),
          const SizedBox(width: 8),
          Text('口コミ管理（${_reviews.length}件）'),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 420,
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 8),
                        TextButton(
                            onPressed: _load, child: const Text('再読み込み')),
                      ],
                    ),
                  )
                : _reviews.isEmpty
                    ? const Center(
                        child: Text('口コミはまだありません',
                            style: TextStyle(color: AppColors.dashGrey)))
                    : ListView.separated(
                        itemCount: _reviews.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final r = _reviews[i];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            title: Row(
                              children: [
                                Text('★' * r.stars,
                                    style: const TextStyle(
                                        color: Color(0xFFF9AB00),
                                        fontSize: 13)),
                                const SizedBox(width: 8),
                                if (r.name.isNotEmpty) ...[
                                  Flexible(
                                    child: Text(r.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text('No.${r.ticketNumber}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.dashGrey)),
                                const SizedBox(width: 8),
                                Text(_when(r.at),
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.dashGrey)),
                              ],
                            ),
                            subtitle: Text(r.text,
                                style: const TextStyle(fontSize: 13.5)),
                            trailing: IconButton(
                              tooltip: '削除',
                              icon: const Icon(Icons.delete_outline,
                                  size: 20, color: Colors.red),
                              onPressed: () => _delete(r),
                            ),
                          );
                        },
                      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}

/// タイムラインダイアログ: 予約スロット（日時）ごとにグルーピングし、
/// 誰がどの順番で来るかを時系列で一望できる。当日券（先着順）は
/// 待機順のまま末尾セクションに表示。
class _TimelineDialog extends StatelessWidget {
  final List<Ticket> tickets;

  const _TimelineDialog({required this.tickets});

  static const _wd = ['月', '火', '水', '木', '金', '土', '日'];

  String _slotLabel(int epochSec) {
    final d = DateTime.fromMillisecondsSinceEpoch(epochSec * 1000);
    return '${d.month}月${d.day}日(${_wd[d.weekday - 1]}) '
        '${d.hour}:${d.minute.toString().padLeft(2, '0')}〜';
  }

  Color _statusColor(String status) => switch (status) {
        'waiting' => AppColors.dashGrey,
        'called' => const Color(0xFFF29900),
        'playing' => const Color(0xFF188038),
        'done' => AppColors.dashBlue,
        _ => AppColors.dashRed,
      };

  @override
  Widget build(BuildContext context) {
    // 予約券: スロット別にグルーピング（キャンセルは薄く表示）
    final reserved = tickets.where((t) => t.reservedSlot > 0).toList()
      ..sort((a, b) => a.reservedSlot.compareTo(b.reservedSlot));
    final slots = <int, List<Ticket>>{};
    for (final t in reserved) {
      slots.putIfAbsent(t.reservedSlot, () => []).add(t);
    }
    // 当日券（先着順）: 待機列の順番のまま
    final walkIn = tickets
        .where((t) => t.reservedSlot == 0 && t.isActive)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    Widget ticketLine(Ticket t, {int? order}) {
      final dim = !t.isActive;
      final c = _statusColor(t.status);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Opacity(
          opacity: dim ? 0.45 : 1,
          child: Row(
            children: [
              if (order != null)
                SizedBox(
                  width: 26,
                  child: Text('$order.',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.dashGrey)),
                ),
              SizedBox(
                width: 52,
                child: Text('No.${t.number}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(t.statusLabel,
                    style: TextStyle(
                        fontSize: 10.5,
                        color: c,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [
                    if (t.label.isNotEmpty) t.label,
                    if (t.reservedEmail.isNotEmpty) t.reservedEmail,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.dashGrey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget section(String title, Color color, List<Widget> children) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        fontSize: 13.5,
                        color: color,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 3),
            padding: const EdgeInsets.only(left: 16),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.dashLine, width: 2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.schedule, size: 20, color: AppColors.dashBlue),
          SizedBox(width: 8),
          Text('タイムライン'),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 480,
        child: (slots.isEmpty && walkIn.isEmpty)
            ? const Center(
                child: Text('表示する整理券がありません',
                    style: TextStyle(color: AppColors.dashGrey)))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in slots.entries)
                      section(
                        _slotLabel(e.key) +
                            (e.key < now ? '（過去）' : ''),
                        e.key < now
                            ? AppColors.dashGrey
                            : AppColors.dashBlue,
                        [
                          for (var i = 0; i < e.value.length; i++)
                            ticketLine(e.value[i], order: i + 1),
                        ],
                      ),
                    if (walkIn.isNotEmpty)
                      section(
                        '当日券（先着順・${walkIn.length}組）',
                        const Color(0xFF188038),
                        [
                          for (var i = 0; i < walkIn.length; i++)
                            ticketLine(walkIn[i], order: i + 1),
                        ],
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
