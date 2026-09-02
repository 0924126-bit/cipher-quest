import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../services/api_service.dart';
import '../services/push_service_stub.dart'
    if (dart.library.js_interop) '../services/push_service_web.dart'
    as push;
import '../services/socket_service.dart';
import '../services/ticket_storage.dart';
import '../services/url_open.dart'
    if (dart.library.js_interop) '../services/url_open_web.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/pwa_install_guide.dart';

/// 来場者向けオンライン整理券ページ（/#/ticket）。
///
/// デザイン方針: Google的ミニマリズム。白背景・十分な余白・
/// 細いタイポグラフィ・アクセント1色（青）。装飾なし。
///
/// リアルタイム: WebSocket（/ws/ticket?code=…）で即時pushを受信。
/// コード・券面はlocalStorageに保存し表示は即時キャッシュから。
/// WS切断中の保険として60秒ポーリングも維持する。
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
  String? _authNotice; // Googleログインのエラー表示
  bool _googleBusy = false;
  Timer? _poll;
  SocketService? _socket;
  StreamSubscription? _socketSub;
  StreamSubscription? _socketStatusSub;

  /// オフライン判定: WS切断中かつ 直近のAPI更新も失敗しているとき。
  /// キャッシュ済みの整理券を表示しつつ「オフラインモード」を明示する。
  bool _wsConnected = false;
  bool _lastFetchFailed = false;
  bool get _offline => !_wsConnected && _lastFetchFailed;

  // 通知の重複防止
  String _lastNotifiedStatus = '';
  bool _notifiedSoon = false;
  int _lastChatCount = -1;

  final _codeCtrl = TextEditingController();
  final _chatCtrl = TextEditingController();
  final _chatScroll = ScrollController();

  // 隠し導線: タイトル10連打（2秒以内間隔）→ スタッフパスワード画面。
  // PWAでは解除後にロール選択、ブラウザではダッシュボードへ。
  int _brandTaps = 0;
  Timer? _brandTapReset;

  void _brandTap() {
    _brandTapReset?.cancel();
    _brandTaps++;
    if (_brandTaps >= 10) {
      _brandTaps = 0;
      gotoHashRoute('/gate');
      return;
    }
    _brandTapReset = Timer(const Duration(seconds: 2), () => _brandTaps = 0);
  }

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
      _connectSocket();
      _startPoll();
      _ensurePushSubscription();
    } else {
      _handleOAuthReturn();
    }
  }

  /// Web Push 購読（許可済みならサイレントに作成・サーバーに保存）。
  /// これによりタブを閉じていても・iOSでタスクキルしていても
  /// 呼び出し・リマインダー・運営チャットの通知が届く。
  Future<void> _ensurePushSubscription() async {
    final code = _code;
    if (code == null) return;
    if (TicketStorage.notifyPermission() != 'granted') return;
    try {
      final key = await ApiService.instance.pushVapidKey();
      if (key.isEmpty) return;
      final sub = await push.createPushSubscription(key);
      if (sub == null) return;
      // 既に同じendpointを保存済みなら再送不要
      if (push.savedPushEndpoint() == sub['endpoint']) return;
      final ok = await ApiService.instance.pushSubscribe(code, sub);
      if (ok) push.storePushEndpoint(sub['endpoint']);
    } catch (_) {}
  }

  /// OAuth callback（/?rs=..&remail=..#/ticket または ?rerr=..）の処理。
  Future<void> _handleOAuthReturn() async {
    final qp = Uri.base.queryParameters;
    final rs = qp['rs'] ?? '';
    final rerr = qp['rerr'] ?? '';
    final remail = qp['remail'] ?? '';
    if (rs.isNotEmpty) {
      TicketStorage.storeReserveSession(rs);
      if (remail.isNotEmpty) TicketStorage.storeReserveEmail(remail);
      clearUrlQuery();
      setState(() => _googleBusy = true);
      await _loginWithSession(rs, redirectIfExpired: false);
      return;
    }
    if (rerr.isNotEmpty) {
      clearUrlQuery();
      if (!mounted) return;
      setState(() {
        _authNotice = switch (rerr) {
          'forbidden' => remail.isNotEmpty
              ? 'このアカウント（$remail）は使用できません。'
                  'gse.okayama-c.ed.jp のアカウントでログインしてください。'
              : 'gse.okayama-c.ed.jp のアカウントでログインしてください。',
          'denied' => 'ログインがキャンセルされました。',
          _ => 'ログインに失敗しました。もう一度お試しください。',
        };
      });
    }
  }

  /// Googleボタン: 保存済みセッションがあれば即座に、なければOAuthへ。
  Future<void> _googleLogin() async {
    if (_googleBusy) return;
    final stored = TicketStorage.loadReserveSession();
    if (stored != null && stored.isNotEmpty) {
      setState(() => _googleBusy = true);
      await _loginWithSession(stored, redirectIfExpired: true);
      return;
    }
    gotoUrl('${Uri.base.origin}/api/reserve/google/start?dest=ticket');
  }

  /// セッションで自分の整理券を取得して表示。
  Future<void> _loginWithSession(String session,
      {required bool redirectIfExpired}) async {
    try {
      final r = await ApiService.instance.ticketBySession(session);
      if (!mounted) return;
      if (r == null) {
        // セッション切れ
        TicketStorage.storeReserveSession(null);
        if (redirectIfExpired) {
          gotoUrl('${Uri.base.origin}/api/reserve/google/start?dest=ticket');
          return;
        }
        setState(() {
          _googleBusy = false;
          _authNotice = 'ログインの有効期限が切れました。もう一度ログインしてください。';
        });
        return;
      }
      final (code, t, _) = r;
      TicketStorage.storeCode(code);
      TicketStorage.requestNotifyPermission();
      setState(() {
        _googleBusy = false;
        _code = code;
        _ticket = t;
        _lastNotifiedStatus = t.status;
        _lastChatCount = t.chat.length;
        _authNotice = null;
      });
      _cache(t);
      _connectSocket();
      _startPoll();
      _ensurePushSubscription();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _googleBusy = false;
        _authNotice = e.toString().contains('NOTICKET')
            ? 'このアカウントの整理券はありません。先に予約するか、受付で発行されたコードを入力してください。'
            : '接続できませんでした。もう一度お試しください。';
      });
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _brandTapReset?.cancel();
    _disconnectSocket();
    _codeCtrl.dispose();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  /// WSが主役。ポーリングは切断時の保険（60秒）。
  void _startPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_socket?.isConnected != true) _refresh();
    });
  }

  /// 整理券コード認証の専用WebSocket。呼出・チャットが即時届く。
  void _connectSocket() {
    final code = _code;
    if (code == null) return;
    _disconnectSocket();
    final s = SocketService(
      '/ws/ticket',
      autoReconnect: true,
      queryOverride: 'code=${Uri.encodeComponent(code)}',
    );
    _socketSub = s.messages.listen((msg) {
      if (!mounted) return;
      if (msg['type'] == 'ticket' && msg['ticket'] is Map<String, dynamic>) {
        final t = Ticket.fromJson(msg['ticket'] as Map<String, dynamic>);
        _maybeNotify(t);
        setState(() {
          _ticket = t;
          _lastFetchFailed = false;
        });
        _cache(t);
      }
    });
    _socketStatusSub = s.connectionStatus.listen((ok) {
      if (!mounted) return;
      setState(() => _wsConnected = ok);
    });
    s.connect();
    _socket = s;
  }

  void _disconnectSocket() {
    _socketSub?.cancel();
    _socketSub = null;
    _socketStatusSub?.cancel();
    _socketStatusSub = null;
    _socket?.dispose();
    _socket = null;
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
      _connectSocket();
      _startPoll();
      _ensurePushSubscription();
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
      'reserved_slot': t.reservedSlot,
      'place': t.place,
      'party': t.party,
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
      setState(() {
        _ticket = t;
        _lastFetchFailed = false;
      });
      _cache(t);
    } catch (_) {
      // オフライン時はキャッシュ表示を維持し、オフラインモードを明示
      if (mounted) setState(() => _lastFetchFailed = true);
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
    _disconnectSocket();
    setState(() {
      _code = null;
      _ticket = null;
      _codeCtrl.clear();
    });
    // ログアウト後はトップページへ戻す
    gotoHashRoute('/');
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

  // ================= ログイン画面（Google主役・コードは補助） =================
  bool _showCodeEntry = false;

  Widget _loginView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _brandTap,
                behavior: HitTestBehavior.opaque,
                child: const Text(
                  'Identity E',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w400,
                    color: _ink,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'オンライン整理券',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _sub),
              ),
              const SizedBox(height: 36),
              const Text(
                '予約に使った Google アカウントで\n整理券を表示できます',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _sub, height: 1.8),
              ),
              if (_authNotice != null) ...[
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 18, color: Color(0xFFD93025)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _authNotice!,
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFD93025),
                            height: 1.6),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 28),
              if (_googleBusy)
                const SizedBox(
                  height: 44,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: _accent),
                    ),
                  ),
                )
              else
                GoogleSignInButton(onPressed: _googleLogin),
              const SizedBox(height: 36),
              // 受付発行のコード券用（控えめの補助リンク）
              if (!_showCodeEntry)
                TextButton(
                  onPressed: () => setState(() => _showCodeEntry = true),
                  child: const Text('整理券コードをお持ちの方はこちら',
                      style: TextStyle(fontSize: 13, color: _sub)),
                )
              else
                _codeEntry(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _codeEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(color: _line, height: 1),
        const SizedBox(height: 24),
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
        const SizedBox(height: 16),
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
      ],
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
                GestureDetector(
                  onTap: _brandTap,
                  behavior: HitTestBehavior.opaque,
                  child: const Text('Identity E',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _ink)),
                ),
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

  /// オフラインモードの明示バナー。通信断でも保存済みの券面は見られる。
  /// なめらかに出入りする（AnimatedSize + フェード）。
  Widget _offlineBanner() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !_offline
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF7E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.cloud_off, size: 18, color: Color(0xFFB05A00)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('オフラインモード',
                            style: TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFFB05A00),
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text(
                          '通信できないため、最後に取得した整理券情報を表示しています。'
                          '接続が戻ると自動的に最新の状態へ更新されます。',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB05A00),
                              height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// 通知未許可の案内カード。
  /// Google風: 白地 + 薄いグレー枠、小さなアイコン、控えめな本文、
  /// 右下に緑のテキストボタンだけを置くミニマルな構成。
  /// granted なら何も表示しない。denied（ブロック済み）は設定手順を案内。
  Widget _notifyBanner() {
    final perm = TicketStorage.notifyPermission();
    if (perm == 'granted' || perm == 'unsupported') {
      return const SizedBox.shrink();
    }
    const green = Color(0xFF188038);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.notifications_none, size: 20, color: _sub),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '通知がオフになっています',
                        style: TextStyle(
                            fontSize: 14,
                            color: _ink,
                            fontWeight: FontWeight.w500,
                            height: 1.4),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        perm == 'denied'
                            ? '通知がブロックされています。ブラウザの設定（サイトの設定 → 通知）から許可してください。'
                            : '順番が近づいてもお知らせが届きません。',
                        style: const TextStyle(
                            fontSize: 12.5, color: _sub, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (perm != 'denied')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: green,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
                onPressed: () {
                  TicketStorage.requestNotifyPermission();
                  // 許可ダイアログの結果を反映（少し待って再描画）。
                  // 許可されたらWeb Push購読も作成（タスキルでも届く）。
                  Future.delayed(const Duration(seconds: 2), () {
                    if (!mounted) return;
                    setState(() {});
                    _ensurePushSubscription();
                  });
                  Future.delayed(const Duration(seconds: 6), () {
                    if (!mounted) return;
                    setState(() {});
                    _ensurePushSubscription();
                  });
                },
                child: const Text('通知をオンにする',
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
            )
          else
            const SizedBox(height: 8),
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
                _offlineBanner(),
                _notifyBanner(),
                // PWA未導入の人向け: ホーム画面追加の案内（手順+動画）
                const PwaInstallGuideCard(),
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

  /// "14:05" 形式（今日以外は "9/1 14:05"）
  String _hm(DateTime d) {
    final now = DateTime.now();
    final sameDay =
        d.year == now.year && d.month == now.month && d.day == now.day;
    final hm = '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    return sameDay ? hm : '${d.month}/${d.day} $hm';
  }

  /// 「開始まで」の残り時間表記。予約が翌日などでも正しく出るよう
  /// 予想時刻（予定と行列予測の遅い方）を基準に計算する。
  String _untilLabel(DateTime predicted) {
    final diff = predicted.difference(DateTime.now());
    final mins = diff.inMinutes;
    if (mins < 1) return 'まもなく（1分以内）';
    if (mins < 60) return '約 $mins 分後';
    if (mins < 60 * 24) {
      final h = mins ~/ 60;
      final m = mins % 60;
      return m == 0 ? '約 $h 時間後' : '約 $h 時間 $m 分後';
    }
    final days = diff.inDays;
    final h = (mins - days * 60 * 24) ~/ 60;
    return h == 0 ? '約 $days 日後' : '約 $days 日と $h 時間後';
  }

  List<Widget> _statusDetail(Ticket t) {
    if (t.status == 'waiting') {
      final now = DateTime.now();
      // 予想開始時刻: 行列の進行状況からの推定（遅延も自動反映）。
      // 予約券で予定より早くは始まらないので、予定時刻との遅い方を採用。
      final queueEta = now.add(Duration(seconds: t.etaSec));
      final scheduled = t.reservedSlot > 0
          ? DateTime.fromMillisecondsSinceEpoch(t.reservedSlot * 1000)
          : null;
      final predicted = (scheduled != null && queueEta.isBefore(scheduled))
          ? scheduled
          : queueEta;
      final delayed = scheduled != null &&
          predicted.difference(scheduled).inMinutes >= 3;
      return [
        if (scheduled != null) _kv('当初の予定', _hm(scheduled)),
        _kvStyled(
          scheduled != null ? '予想時刻（現在）' : '開始予想時刻',
          '${_hm(predicted)} ごろ',
          color: delayed ? const Color(0xFFB05A00) : _ink,
        ),
        if (delayed)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              '進行が遅れているため、予定より遅くなっています。最新の予想時刻に合わせてお越しください。',
              style: TextStyle(
                  fontSize: 12, color: Color(0xFFB05A00), height: 1.6),
            ),
          ),
        if (t.place.isNotEmpty) _kv('集合場所', t.place),
        _kv('あなたの前', t.position <= 0 ? 'なし（次です）' : '${t.position} 組'),
        _kv('開始まで', _untilLabel(predicted)),
        const SizedBox(height: 8),
        const Text(
          '順番が近づくと通知でお知らせします。予想時刻は進行状況で自動的に更新されます。',
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

  Widget _kv(String k, String v) => _kvStyled(k, v, color: _ink);

  Widget _kvStyled(String k, String v, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 110,
              child:
                  Text(k, style: const TextStyle(fontSize: 13, color: _sub))),
          Text(v,
              style: TextStyle(
                  fontSize: 15, color: color, fontWeight: FontWeight.w500)),
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
