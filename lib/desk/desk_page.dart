import 'dart:async';

import 'package:flutter/material.dart';

import '../dashboard/widgets/paper_issue_dialog.dart';
import '../models/ticket.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

/// スタッフ受付専用ページ（/#/desk）。サイトパスワード認証内。
///
/// 設計方針「神導線」:
/// - 上段: 今プレイ中の組（超特大表示）→「終了」ボタンだけ
/// - 中段: 呼出中の組 →「開始」「戻す」ボタン
/// - 下段: 待機列の先頭から順に →「呼出」ボタン
/// - 自動進行は一切なし。全てスタッフのボタン操作。
/// - WebSocket (/ws/dashboard) で他端末の操作も即時反映。
class DeskPage extends StatefulWidget {
  const DeskPage({super.key});

  @override
  State<DeskPage> createState() => _DeskPageState();
}

class _DeskPageState extends State<DeskPage> {
  static const _accent = Color(0xFF1A73E8);
  static const _ink = Color(0xFF202124);
  static const _sub = Color(0xFF5F6368);
  static const _line = Color(0xFFDADCE0);
  static const _green = Color(0xFF188038);
  static const _red = Color(0xFFD93025);
  static const _amber = Color(0xFFF9AB00);

  List<Ticket> _tickets = const [];
  bool _loaded = false;
  bool _busy = false;
  SocketService? _socket;
  StreamSubscription? _wsSub;
  Timer? _clock; // 経過時間の表示更新用（状態は一切進めない）

  @override
  void initState() {
    super.initState();
    _load();
    final s = SocketService('/ws/dashboard', autoReconnect: true);
    _wsSub = s.messages.listen((msg) {
      if (msg['type'] == 'tickets_changed') _load();
    });
    s.connect();
    _socket = s;
    _clock = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _wsSub?.cancel();
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final (tickets, _, _) = await ApiService.instance.listTickets();
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _action(Ticket t, String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await ApiService.instance.ticketAction(t.id, action);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('この状態からは実行できません（他の端末で操作済みの可能性）'),
        backgroundColor: _red,
      ));
    }
    _load();
  }

  Future<void> _issuePaper() async {
    final r = await showPaperIssueDialog(context);
    if (r == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ApiService.instance.issueTicket(
        kind: 'paper',
        label: r.label,
        reservedSlot:
            r.slotAt == null ? 0 : r.slotAt!.millisecondsSinceEpoch ~/ 1000,
        place: r.place,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('整理券を発行しました（${r.label}）'),
        backgroundColor: _green,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('発行に失敗しました: $e'),
        backgroundColor: _red,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _load();
  }

  // ---- helpers ----
  String _elapsed(int since) {
    if (since <= 0) return '';
    final sec = DateTime.now().millisecondsSinceEpoch ~/ 1000 - since;
    if (sec < 60) return '$sec秒';
    return '${sec ~/ 60}分${sec % 60}秒';
  }

  String _slotHm(int epochSec) {
    final d = DateTime.fromMillisecondsSinceEpoch(epochSec * 1000);
    return '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _title(Ticket t) {
    final label = t.label.isNotEmpty ? ' ${t.label}' : '';
    final kind = t.kind == 'paper' ? '紙' : '';
    return 'No.${t.number}$label $kind'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final playing = _tickets.where((t) => t.status == 'playing').toList();
    final called = _tickets.where((t) => t.status == 'called').toList()
      ..sort((a, b) => a.calledAt.compareTo(b.calledAt));
    final waiting = _tickets.where((t) => t.status == 'waiting').toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    // キャンセル（誤操作の取り消し用。新しい順）
    final cancelled = _tickets.where((t) => t.status == 'cancelled').toList()
      ..sort((a, b) => b.cancelledAt.compareTo(a.cancelledAt));
    // 終了（間違えて終了したときの取り消し用。新しい順）
    final done = _tickets.where((t) => t.status == 'done').toList()
      ..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: _line)),
        title: const Text('受付デスク',
            style: TextStyle(
                color: _ink, fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text('待機 ${waiting.length} ／ 呼出 ${called.length}',
                  style: const TextStyle(fontSize: 13, color: _sub)),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: FilledButton.icon(
                onPressed: _busy ? null : _issuePaper,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('発行',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          IconButton(
            tooltip: '再読み込み',
            icon: const Icon(Icons.refresh, color: _sub),
            onPressed: _load,
          ),
        ],
      ),
      body: !_loaded
          ? const Center(
              child: CircularProgressIndicator(color: _accent, strokeWidth: 2.5))
          : RefreshIndicator(
              color: _accent,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionLabel('プレイ中', _green),
                  if (playing.isEmpty)
                    _emptyCard('プレイ中の組はありません')
                  else
                    for (final t in playing) _playingCard(t),
                  const SizedBox(height: 20),
                  _sectionLabel('呼出中（受付へ来たら「開始」）', _amber),
                  if (called.isEmpty)
                    _emptyCard('呼出中の組はありません')
                  else
                    for (final t in called) _calledCard(t),
                  const SizedBox(height: 20),
                  _sectionLabel('待機列（上から順に「呼出」・${waiting.length}組）', _accent),
                  if (waiting.isEmpty)
                    _emptyCard('待機中の組はありません')
                  else if (waiting.length <= 8)
                    for (var i = 0; i < waiting.length; i++)
                      _waitingCard(waiting[i], i)
                  else
                    // 人数が多いときは専用スクロール枠（遅延生成で軽い）
                    Container(
                      height: 560,
                      decoration: BoxDecoration(
                        border: Border.all(color: _line),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: waiting.length,
                        itemBuilder: (context, i) =>
                            _waitingCard(waiting[i], i),
                      ),
                    ),
                  if (cancelled.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionLabel(
                        'キャンセル（間違えたら「列に戻す」・${cancelled.length}件）',
                        _red),
                    _scrollPane(cancelled, _cancelledCard, maxInline: 3),
                  ],
                  if (done.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionLabel(
                        '終了済み（間違えたら「列に戻す」・${done.length}件）',
                        _sub),
                    _scrollPane(done, _doneCard, maxInline: 3),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                  fontSize: 14, color: _sub, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(text, style: const TextStyle(fontSize: 13, color: _sub)),
      ),
    );
  }

  // ---- プレイ中: 超特大 + 終了ボタン ----
  Widget _playingCard(Ticket t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _green, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title(t),
                    style: const TextStyle(
                        fontSize: 30,
                        color: _ink,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('経過 ${_elapsed(t.startedAt)}',
                    style: const TextStyle(fontSize: 14, color: _sub)),
              ],
            ),
          ),
          SizedBox(
            width: 130,
            height: 64,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _busy ? null : () => _action(t, 'finish'),
              child: const Text('終了',
                  style:
                      TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 呼出中: 開始 / 待機に戻す ----
  Widget _calledCard(Ticket t) {
    final lateSec =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 - t.calledAt;
    final isLate = lateSec > 5 * 60;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _amber, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title(t),
                    style: const TextStyle(
                        fontSize: 24,
                        color: _ink,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('呼出から ${_elapsed(t.calledAt)}',
                    style: TextStyle(
                        fontSize: 13,
                        color: isLate ? _red : _sub,
                        fontWeight:
                            isLate ? FontWeight.w600 : FontWeight.w400)),
              ],
            ),
          ),
          SizedBox(
            width: 76,
            height: 56,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _line),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _busy ? null : () => _action(t, 'cancel'),
              child: const Text('取消',
                  style: TextStyle(fontSize: 14, color: _red)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            height: 56,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _busy ? null : () => _action(t, 'start'),
              child: const Text('開始',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 待機列: 呼出 ----
  Widget _waitingCard(Ticket t, int index) {
    final isNext = index == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
            color: isNext ? _accent : _line, width: isNext ? 1.5 : 1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isNext ? const Color(0xFFE8F0FE) : const Color(0xFFF1F3F4),
              shape: BoxShape.circle,
            ),
            child: Text('${index + 1}',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isNext ? _accent : _sub)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title(t),
                    style: TextStyle(
                        fontSize: 20,
                        color: _ink,
                        fontWeight:
                            isNext ? FontWeight.w700 : FontWeight.w500)),
                if (t.reservedSlot > 0)
                  Text('予約 ${_slotHm(t.reservedSlot)}〜',
                      style: const TextStyle(fontSize: 12, color: _accent)),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            height: 52,
            child: isNext
                ? FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _busy ? null : () => _action(t, 'call'),
                    child: const Text('呼出',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _line),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _busy ? null : () => _action(t, 'call'),
                    child: const Text('呼出',
                        style: TextStyle(fontSize: 16, color: _accent)),
                  ),
          ),
        ],
      ),
    );
  }

  // ---- キャンセル済み: 「列に戻す」で誤操作を取り消し ----
  Widget _cancelledCard(Ticket t) {
    final reason = switch (t.cancelReason) {
      'late' => '遅刻自動',
      'user' => '本人',
      _ => '運営',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF7F7),
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title(t),
                    style: const TextStyle(
                        fontSize: 18,
                        color: _ink,
                        fontWeight: FontWeight.w500)),
                Text('$reasonキャンセル・${_elapsed(t.cancelledAt)}前',
                    style: const TextStyle(fontSize: 12, color: _sub)),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _accent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _busy ? null : () => _action(t, 'requeue'),
              icon: const Icon(Icons.undo, size: 16, color: _accent),
              label: const Text('列に戻す',
                  style: TextStyle(fontSize: 14, color: _accent)),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 終了済み: 誤って終了したときの取り消し用 ----
  Widget _doneCard(Ticket t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F9F6),
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title(t),
                    style: const TextStyle(
                        fontSize: 18,
                        color: _ink,
                        fontWeight: FontWeight.w500)),
                Text('終了・${_elapsed(t.finishedAt)}前',
                    style: const TextStyle(fontSize: 12, color: _sub)),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _accent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _busy ? null : () => _action(t, 'requeue'),
              icon: const Icon(Icons.undo, size: 16, color: _accent),
              label: const Text('列に戻す',
                  style: TextStyle(fontSize: 14, color: _accent)),
            ),
          ),
        ],
      ),
    );
  }

  /// 件数が少なければそのまま並べ、多ければ固定高さのスクロール枠にする。
  /// （縦に無限に伸びるのを防ぐ。ListView.builderで遅延生成）
  Widget _scrollPane(List<Ticket> items, Widget Function(Ticket) card,
      {int maxInline = 3}) {
    if (items.length <= maxInline) {
      return Column(children: [for (final t in items) card(t)]);
    }
    return Container(
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: items.length,
        itemBuilder: (context, i) => card(items[i]),
      ),
    );
  }
}
