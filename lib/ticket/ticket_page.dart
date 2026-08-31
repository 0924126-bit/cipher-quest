import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../services/api_service.dart';
import '../services/ticket_storage.dart';

/// 来場者向けオンライン整理券ページ（/#/ticket）。
///
/// デザイン方針: Google的ミニマリズム。白背景・十分な余白・
/// 細いタイポグラフィ・アクセント1色（青）。装飾なし。
///
/// 負荷設計: コード・券面はlocalStorageに保存し、表示は即時
/// キャッシュから。サーバー同期は30秒ポーリング1リクエストのみ。
/// 通知（呼出/開始間近/チャット）はブラウザ通知＋バイブ。
class TicketPage extends StatefulWidget {
  const TicketPage({super.key});

  @override
  State<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends State<TicketPage> {
  static const _accent = Color(0xFF1A73E8); // Google blue
  static const _ink = Color(0xFF202124);
  static const _sub = Color(0xFF5F6368);
  static const _line = Color(0xFFDADCE0);

  String? _code;
  Ticket? _ticket;
  bool _loading = false;
  String? _error;
  Timer? _poll;

  // 通知の重複防止
  String _lastNotifiedStatus = '';
  bool _notifiedSoon = false;
  int _lastChatCount = -1;

  final _codeCtrl = TextEditingController();
  final _chatCtrl = TextEditingController();
  final _chatScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _code = TicketStorage.loadCode();
    final cached = TicketStorage.loadCache();
    if (cached != null) {
      try {
        _ticket = Ticket.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        _lastChatCount = _ticket!.chat.length;
        _lastNotifiedStatus = _ticket!.status;
      } catch (_) {}
    }
    if (_code != null) {
      _refresh();
      _startPoll();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _codeCtrl.dispose();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  void _startPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  Future<void> _login() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final t = await ApiService.instance.ticketLogin(code);
      if (!mounted) return;
      if (t == null) {
        setState(() {
          _loading = false;
          _error = '整理券コードが違います';
        });
        return;
      }
      TicketStorage.storeCode(code);
      TicketStorage.requestNotifyPermission();
      setState(() {
        _code = code;
        _ticket = t;
        _loading = false;
        _lastNotifiedStatus = t.status;
        _lastChatCount = t.chat.length;
      });
      _cache(t);
      _startPoll();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().contains('rate_limited')
            ? '試行回数が多すぎます。1分ほど待ってください'
            : '接続できませんでした';
      });
    }
  }

  void _cache(Ticket t) {
    TicketStorage.storeCache(jsonEncode({
      'id': t.id,
      'number': t.number,
      'kind': t.kind,
      'label': t.label,
      'status': t.status,
      'created_at': t.createdAt,
      'called_at': t.calledAt,
      'position': t.position,
      'eta_sec': t.etaSec,
      'game_sec': t.gameSec,
      'interval_sec': t.intervalSec,
      'late_cancel_sec': t.lateCancelSec,
      'reviews_enabled': t.reviewsEnabled,
      'review_posted': t.reviewPosted,
      'chat': [
        for (final m in t.chat)
          {
            'id': m.id,
            'from': m.from,
            'kind': m.kind,
            'text': m.text,
            'at': m.at
          }
      ],
    }));
  }

  Future<void> _refresh() async {
    final code = _code;
    if (code == null) return;
    try {
      final t = await ApiService.instance.ticketState(code);
      if (!mounted || t == null) return;
      _maybeNotify(t);
      setState(() => _ticket = t);
      _cache(t);
    } catch (_) {
      // オフライン時はキャッシュ表示を維持
    }
  }

  void _maybeNotify(Ticket t) {
    // 呼出通知
    if (t.status != _lastNotifiedStatus) {
      if (t.status == 'called') {
        TicketStorage.showNotification(
            '呼出中です', '整理券 ${t.number} の順番です。受付へお越しください');
        TicketStorage.vibrate();
      } else if (t.status == 'playing') {
        TicketStorage.showNotification('開始', 'ゲームを開始しました。楽しんで！');
      }
      _lastNotifiedStatus = t.status;
    }
    // 開始間近通知（5分以内、1回だけ）
    if (!_notifiedSoon && t.status == 'waiting' && t.etaSec > 0 && t.etaSec <= 300) {
      TicketStorage.showNotification(
          'まもなく順番です', '整理券 ${t.number}：あと約${(t.etaSec / 60).ceil()}分で開始予定');
      TicketStorage.vibrate();
      _notifiedSoon = true;
    }
    // 新着チャット通知
    if (_lastChatCount >= 0 && t.chat.length > _lastChatCount) {
      final last = t.chat.last;
      if (last.from == 'staff') {
        TicketStorage.showNotification(
            last.kind == 'notice' ? '運営からのお知らせ' : '運営からメッセージ', last.text);
        TicketStorage.vibrate();
      }
    }
    _lastChatCount = t.chat.length;
  }

  // ---- キャンセル（2段警告） ----
  Future<void> _cancelFlow() async {
    final t = _ticket;
    if (t == null) return;
    final first = await _confirm(
      title: 'キャンセルしますか？',
      body: 'キャンセルすると整理券 ${t.number} は無効になります。\n'
          '再度並ぶ場合は新しい整理券が必要です。',
      okLabel: 'キャンセルする',
    );
    if (first != true || !mounted) return;
    final second = await _confirm(
      title: '本当によろしいですか？',
      body: 'この操作は取り消せません。\n'
          '整理券 ${t.number} は完全に無効になります。',
      okLabel: '完全にキャンセル',
      danger: true,
    );
    if (second != true || !mounted) return;
    final code = _code;
    if (code == null) return;
    final r = await ApiService.instance.ticketCancel(code);
    if (!mounted) return;
    if (r != null) {
      setState(() => _ticket = r);
      _cache(r);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String okLabel,
    bool danger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(title,
            style: const TextStyle(
                fontSize: 17, color: _ink, fontWeight: FontWeight.w500)),
        content: Text(body,
            style: const TextStyle(fontSize: 14, color: _sub, height: 1.7)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('戻る', style: TextStyle(color: _accent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(okLabel,
                style: TextStyle(
                    color: danger ? const Color(0xFFD93025) : _accent,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendChat() async {
    final code = _code;
    final text = _chatCtrl.text.trim();
    if (code == null || text.isEmpty) return;
    _chatCtrl.clear();
    final t = await ApiService.instance.ticketChat(code, text);
    if (!mounted || t == null) return;
    _lastChatCount = t.chat.length;
    setState(() => _ticket = t);
    _cache(t);
  }

  void _logout() {
    TicketStorage.storeCode(null);
    _poll?.cancel();
    setState(() {
      _code = null;
      _ticket = null;
      _codeCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _code == null ? _loginView() : _ticketView(),
      ),
    );
  }

  // ================= ログイン画面（コード入力） =================
  Widget _loginView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Identity E',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w400,
                  color: _ink,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'オンライン整理券',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _sub),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _codeCtrl,
                autofocus: false,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20, letterSpacing: 4, color: _ink),
                decoration: InputDecoration(
                  hintText: '整理券コード',
                  hintStyle: const TextStyle(
                      fontSize: 15, letterSpacing: 0, color: _sub),
                  errorText: _error,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _accent, width: 2),
                  ),
                ),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: _loading ? null : _login,
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('表示する',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                '整理券コードは受付で発行しています',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _sub),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= 整理券表示 =================
  Widget _ticketView() {
    final t = _ticket;
    if (t == null) {
      return const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: _accent));
    }
    return DefaultTabController(
      length: t.reviewsEnabled ? 2 : 1,
      child: Column(
        children: [
          // ---- ヘッダー ----
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(
              children: [
                const Text('Identity E',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _ink)),
                const Spacer(),
                IconButton(
                  tooltip: '別のコードを入力',
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, size: 18, color: _sub),
                ),
              ],
            ),
          ),
          if (t.reviewsEnabled)
            const TabBar(
              labelColor: _accent,
              unselectedLabelColor: _sub,
              indicatorColor: _accent,
              dividerColor: _line,
              labelStyle:
                  TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: [Tab(text: '整理券'), Tab(text: '口コミ')],
            ),
          Expanded(
            child: TabBarView(
              physics: t.reviewsEnabled
                  ? null
                  : const NeverScrollableScrollPhysics(),
              children: [
                _ticketTab(t),
                if (t.reviewsEnabled) _ReviewsTab(code: _code, ticket: t),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ticketTab(Ticket t) {
    return RefreshIndicator(
      color: _accent,
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---- 券面 ----
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  decoration: BoxDecoration(
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('整理券番号',
                          style: TextStyle(fontSize: 12, color: _sub)),
                      const SizedBox(height: 10),
                      Text(
                        t.number,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 3,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _statusChip(t),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // ---- 状態詳細 ----
                ..._statusDetail(t),
                const SizedBox(height: 32),
                // ---- チャット ----
                if (t.isActive || t.chat.isNotEmpty) _chatSection(t),
                const SizedBox(height: 32),
                // ---- キャンセル ----
                if (t.isActive)
                  Center(
                    child: TextButton(
                      onPressed: _cancelFlow,
                      child: const Text(
                        'キャンセルする',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFFD93025)),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(Ticket t) {
    Color bg;
    Color fg;
    String label;
    switch (t.status) {
      case 'waiting':
        bg = const Color(0xFFE8F0FE);
        fg = _accent;
        label = '待機中';
        break;
      case 'called':
        bg = const Color(0xFFFEF7E0);
        fg = const Color(0xFFB05A00);
        label = '呼出中 — 受付へお越しください';
        break;
      case 'playing':
        bg = const Color(0xFFE6F4EA);
        fg = const Color(0xFF188038);
        label = 'プレイ中';
        break;
      case 'done':
        bg = const Color(0xFFF1F3F4);
        fg = _sub;
        label = '終了 — ありがとうございました';
        break;
      default:
        bg = const Color(0xFFFCE8E6);
        fg = const Color(0xFFD93025);
        label = t.cancelReason == 'late'
            ? 'キャンセル（15分以上の遅れ）'
            : 'キャンセル済み';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 13, color: fg, fontWeight: FontWeight.w500)),
    );
  }

  List<Widget> _statusDetail(Ticket t) {
    if (t.status == 'waiting') {
      final mins = (t.etaSec / 60).ceil();
      return [
        _kv('あなたの前', t.position <= 0 ? 'なし（次です）' : '${t.position} 組'),
        _kv('開始予想', mins <= 1 ? 'まもなく' : '約 $mins 分後'),
        const SizedBox(height: 8),
        const Text(
          '順番が近づくと通知でお知らせします。予想時間は進行状況で自動的に変わります。',
          style: TextStyle(fontSize: 12, color: _sub, height: 1.7),
        ),
      ];
    }
    if (t.status == 'called') {
      final waited = DateTime.now().millisecondsSinceEpoch ~/ 1000 - t.calledAt;
      final left = (t.lateCancelSec - waited).clamp(0, t.lateCancelSec);
      return [
        _kv('残り受付時間', '約 ${(left / 60).ceil()} 分'),
        const SizedBox(height: 8),
        const Text(
          '15分以上遅れると自動キャンセルになります。お早めに受付へお越しください。',
          style: TextStyle(fontSize: 12, color: Color(0xFFB05A00), height: 1.7),
        ),
      ];
    }
    return const [];
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 110,
              child:
                  Text(k, style: const TextStyle(fontSize: 13, color: _sub))),
          Text(v,
              style: const TextStyle(
                  fontSize: 15, color: _ink, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ---- 運営チャット ----
  Widget _chatSection(Ticket t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('運営とチャット',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: _ink)),
        const SizedBox(height: 12),
        if (t.chat.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              border: Border.all(color: _line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              controller: _chatScroll,
              shrinkWrap: true,
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: t.chat.length,
              itemBuilder: (context, i) {
                final m = t.chat[t.chat.length - 1 - i];
                final mine = m.from == 'user';
                return Align(
                  alignment:
                      mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: mine
                          ? const Color(0xFFE8F0FE)
                          : m.kind == 'notice'
                              ? const Color(0xFFFEF7E0)
                              : const Color(0xFFF1F3F4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(m.text,
                        style: const TextStyle(
                            fontSize: 13, color: _ink, height: 1.5)),
                  ),
                );
              },
            ),
          ),
        if (t.isActive) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatCtrl,
                  style: const TextStyle(fontSize: 13, color: _ink),
                  decoration: InputDecoration(
                    hintText: 'メッセージを入力',
                    hintStyle: const TextStyle(fontSize: 13, color: _sub),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: _line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: _accent),
                    ),
                  ),
                  onSubmitted: (_) => _sendChat(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sendChat,
                icon: const Icon(Icons.send, size: 20, color: _accent),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// =====================================================================
// 口コミタブ（閲覧 + 体験済みなら投稿）
// =====================================================================
class _ReviewsTab extends StatefulWidget {
  final String? code;
  final Ticket ticket;
  const _ReviewsTab({required this.code, required this.ticket});

  @override
  State<_ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<_ReviewsTab> {
  static const _accent = Color(0xFF1A73E8);
  static const _ink = Color(0xFF202124);
  static const _sub = Color(0xFF5F6368);
  static const _line = Color(0xFFDADCE0);
  static const _star = Color(0xFFFBBC04);

  List<Review> _reviews = const [];
  bool _loaded = false;
  int _stars = 5;
  final _textCtrl = TextEditingController();
  bool _posting = false;
  String? _postError;
  bool _posted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final (_, reviews) = await ApiService.instance.listReviews();
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _post() async {
    final code = widget.code;
    if (code == null) return;
    setState(() {
      _posting = true;
      _postError = null;
    });
    final err = await ApiService.instance
        .postReview(code, _stars, _textCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _posting = false;
      if (err == null) {
        _posted = true;
      } else {
        _postError = err;
      }
    });
    if (err == null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final canPost =
        widget.ticket.status == 'done' && !widget.ticket.reviewPosted && !_posted;
    final avg = _reviews.isEmpty
        ? 0.0
        : _reviews.map((r) => r.stars).reduce((a, b) => a + b) /
            _reviews.length;

    return RefreshIndicator(
      color: _accent,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---- 平均 ----
                  if (_reviews.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(avg.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w400,
                                color: _ink)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _starRow(avg.round(), size: 18),
                            const SizedBox(height: 2),
                            Text('${_reviews.length}件の口コミ',
                                style: const TextStyle(
                                    fontSize: 12, color: _sub)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: _line, height: 1),
                    const SizedBox(height: 12),
                  ],
                  // ---- 投稿フォーム（体験済みのみ） ----
                  if (canPost) ...[
                    const SizedBox(height: 8),
                    const Text('体験はいかがでしたか？',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _ink)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (var i = 1; i <= 5; i++)
                          IconButton(
                            onPressed: () => setState(() => _stars = i),
                            icon: Icon(
                              i <= _stars ? Icons.star : Icons.star_border,
                              color: _star,
                              size: 28,
                            ),
                          ),
                      ],
                    ),
                    TextField(
                      controller: _textCtrl,
                      maxLines: 3,
                      maxLength: 300,
                      style: const TextStyle(fontSize: 13, color: _ink),
                      decoration: InputDecoration(
                        hintText: '感想（任意）',
                        hintStyle:
                            const TextStyle(fontSize: 13, color: _sub),
                        errorText: _postError,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _accent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _posting ? null : _post,
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(_posting ? '送信中…' : '投稿する',
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: _line, height: 1),
                  ],
                  if (_posted)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('投稿ありがとうございました',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 13, color: Color(0xFF188038))),
                    ),
                  // ---- 一覧 ----
                  if (!_loaded)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _accent)),
                    )
                  else if (_reviews.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('まだ口コミはありません',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: _sub)),
                    )
                  else
                    for (final r in _reviews) _reviewTile(r),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _starRow(int n, {double size = 14}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(i <= n ? Icons.star : Icons.star_border,
              color: _star, size: size),
      ],
    );
  }

  Widget _reviewTile(Review r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _starRow(r.stars),
              const SizedBox(width: 8),
              Text(r.ticketNumber,
                  style: const TextStyle(fontSize: 11, color: _sub)),
            ],
          ),
          if (r.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(r.text,
                style:
                    const TextStyle(fontSize: 13, color: _ink, height: 1.6)),
          ],
          const SizedBox(height: 12),
          const Divider(color: _line, height: 1),
        ],
      ),
    );
  }
}
