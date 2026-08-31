import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ticket.dart';
import '../services/api_service.dart';
import '../services/ticket_storage.dart';
import '../services/url_open.dart'
    if (dart.library.js_interop) '../services/url_open_web.dart';
import '../widgets/google_sign_in_button.dart';

/// 来場者向け予約ページ（/#/reserve）。サイトパスワード不要・公開。
/// ただし予約確定には Google ログイン必須
/// （gse.okayama-c.ed.jp ドメイン or スタッフ指定メールのみ）。
///
/// OAuth フロー: [Googleでログイン] → /api/reserve/google/start → Google
/// → callback → `/?rs=SESSION&remail=EMAIL#/reserve`（失敗時 `?rerr=..`）。
/// クエリはハッシュより前なので Uri.base.queryParameters で読む。
///
/// デザイン方針: Google的ミニマリズム。白背景・十分な余白・
/// 細いタイポグラフィ・アクセント1色（青）。
///
/// フロー: Googleログイン → 日付を選ぶ → 30分毎の時間スロットを選ぶ
/// →（任意で名前）→ 予約確定 → 整理券コードを表示（そのまま /ticket へ）。
class ReservePage extends StatefulWidget {
  const ReservePage({super.key});

  @override
  State<ReservePage> createState() => _ReservePageState();
}

class _ReservePageState extends State<ReservePage> {
  static const _accent = Color(0xFF1A73E8);
  static const _ink = Color(0xFF202124);
  static const _sub = Color(0xFF5F6368);
  static const _line = Color(0xFFDADCE0);
  static const _green = Color(0xFF188038);
  static const _red = Color(0xFFD93025);

  bool _loading = true;
  bool _enabled = true;
  String? _error;

  // Googleログイン（予約に必須）
  String? _session; // Workers発行のセッションtoken（3時間）
  String? _email; // ログイン中のメール（表示用）
  String? _authNotice; // ログインエラーメッセージ
  bool _authChecking = true; // 保存セッションの検証中
  List<ReserveSlot> _slots = const [];
  String? _selectedDate; // "M月d日(曜)" key
  ReserveSlot? _selected;
  bool _submitting = false;

  // 完了画面
  String? _issuedCode;
  Ticket? _issuedTicket;

  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAuth();
    _load();
  }

  /// OAuth callback のクエリ（rs/remail/rerr）→ 保存セッションの順で復元。
  Future<void> _initAuth() async {
    final qp = Uri.base.queryParameters;
    final rs = qp['rs'] ?? '';
    final remail = qp['remail'] ?? '';
    final rerr = qp['rerr'] ?? '';
    if (rs.isNotEmpty) {
      // ログイン成功で戻ってきた。tokenはURLから即消す。
      TicketStorage.storeReserveSession(rs);
      TicketStorage.storeReserveEmail(remail.isEmpty ? null : remail);
      clearUrlQuery();
      if (!mounted) return;
      setState(() {
        _session = rs;
        _email = remail.isEmpty ? null : remail;
        _authChecking = false;
      });
      _redirectIfReserved(rs);
      return;
    }
    if (rerr.isNotEmpty) {
      clearUrlQuery();
      if (!mounted) return;
      setState(() {
        _authChecking = false;
        _authNotice = switch (rerr) {
          'forbidden' => remail.isNotEmpty
              ? 'このアカウント（$remail）では予約できません。\n'
                  'gse.okayama-c.ed.jp のGoogleアカウントでログインしてください。'
              : 'このアカウントでは予約できません。\n'
                  'gse.okayama-c.ed.jp のGoogleアカウントでログインしてください。',
          'denied' => 'ログインがキャンセルされました。',
          _ => 'ログインに失敗しました。もう一度お試しください。',
        };
      });
      return;
    }
    // 保存済みセッションがあればサーバーで検証（期限切れは破棄）。
    final stored = TicketStorage.loadReserveSession();
    if (stored == null || stored.isEmpty) {
      if (mounted) setState(() => _authChecking = false);
      return;
    }
    final email = await ApiService.instance.reserveMe(stored);
    if (!mounted) return;
    if (email == null) {
      TicketStorage.storeReserveSession(null);
      TicketStorage.storeReserveEmail(null);
      setState(() => _authChecking = false);
      return;
    }
    TicketStorage.storeReserveEmail(email);
    setState(() {
      _session = stored;
      _email = email;
      _authChecking = false;
    });
    _redirectIfReserved(stored);
  }

  /// すでに有効な予約（待機中・呼出中・体験中）があるアカウントなら
  /// 整理券ページへ飛ばす。終了・キャンセル済みはそのまま再予約可。
  Future<void> _redirectIfReserved(String session) async {
    try {
      final res = await ApiService.instance.ticketBySession(session);
      if (res == null || !mounted) return; // セッション切れ等は何もしない
      final (code, ticket, _) = res;
      const active = {'waiting', 'called', 'playing'};
      if (active.contains(ticket.status)) {
        TicketStorage.storeCode(code);
        gotoHashRoute('/ticket');
      }
    } catch (_) {
      // NOTICKET（整理券なし）など → 普通に予約フローへ
    }
  }

  void _startLogin() {
    gotoUrl('${Uri.base.origin}/api/reserve/google/start');
  }

  void _logout() {
    TicketStorage.storeReserveSession(null);
    TicketStorage.storeReserveEmail(null);
    setState(() {
      _session = null;
      _email = null;
      _authNotice = null;
    });
    // ログアウト後はトップページへ戻す
    gotoHashRoute('/');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (enabled, _, _, slots) = await ApiService.instance.reserveSlots();
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _slots = slots;
        _loading = false;
        // 選択中の日付が消えたらリセット
        if (_selectedDate != null &&
            !slots.any((s) => _dateKey(s) == _selectedDate)) {
          _selectedDate = null;
          _selected = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '読み込みに失敗しました。通信環境をご確認ください';
      });
    }
  }

  // ---- 日付・時刻フォーマット（JST表示。端末TZ前提で十分） ----
  static const _wd = ['月', '火', '水', '木', '金', '土', '日'];

  DateTime _dt(int epochSec) =>
      DateTime.fromMillisecondsSinceEpoch(epochSec * 1000);

  String _dateKey(ReserveSlot s) {
    final d = _dt(s.start);
    return '${d.month}月${d.day}日(${_wd[d.weekday - 1]})';
  }

  String _hm(int epochSec) {
    final d = _dt(epochSec);
    return '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    final slot = _selected;
    final session = _session;
    if (slot == null || _submitting) return;
    if (session == null || session.isEmpty) {
      // 保险（UI上はログイン済みでないとここに来ない）
      setState(() => _authNotice = '予約にはGoogleログインが必要です。');
      return;
    }
    setState(() => _submitting = true);
    try {
      final (code, ticket) = await ApiService.instance
          .reserveCreate(slot.start, _nameCtrl.text.trim(), session);
      if (!mounted) return;
      // そのまま /ticket で使えるようコードを保存しておく
      TicketStorage.storeCode(code);
      setState(() {
        _issuedCode = code;
        _issuedTicket = ticket;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      var msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.startsWith('AUTH:')) {
        // セッション切れ・許可外 → セッション破棄して再ログイン誘導
        msg = msg.substring(5);
        TicketStorage.storeReserveSession(null);
        setState(() {
          _submitting = false;
          _session = null;
          _authNotice = '$msg\nもう一度ログインしてください。';
        });
        return;
      }
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: _red),
      );
      _load(); // 満席になった等 → 最新の空き状況に更新
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _issuedCode != null ? _doneView() : _bookView(),
      ),
    );
  }

  // ================= 予約完了画面 =================
  Widget _doneView() {
    final code = _issuedCode!;
    final t = _issuedTicket!;
    final slotLabel = t.reservedSlot > 0
        ? '${_dateKey(ReserveSlot(start: t.reservedSlot, end: t.reservedSlot, capacity: 0, reserved: 0, available: 0))} ${_hm(t.reservedSlot)}〜'
        : '';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle_outline, color: _green, size: 56),
              const SizedBox(height: 20),
              const Text('予約が完了しました',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 22, color: _ink, fontWeight: FontWeight.w400)),
              const SizedBox(height: 8),
              Text(slotLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: _sub)),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: _line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text('整理券コード',
                        style: TextStyle(fontSize: 13, color: _sub)),
                    const SizedBox(height: 8),
                    SelectableText(code,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 32,
                            color: _ink,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 4)),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('コードをコピーしました')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16, color: _accent),
                      label: const Text('コピー',
                          style: TextStyle(color: _accent)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'このコードは再表示できません。\nスクリーンショット等で必ず保存してください。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _red, height: 1.7),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => gotoHashRoute('/ticket'),
                  child: const Text('整理券ページを開く',
                      style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= 予約画面 =================
  Widget _bookView() {
    return RefreshIndicator(
      color: _accent,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _content(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Identity E',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 26, color: _ink, fontWeight: FontWeight.w400)),
        const SizedBox(height: 6),
        const SizedBox(height: 32),
        if (_loading || _authChecking)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
                child: CircularProgressIndicator(
                    color: _accent, strokeWidth: 2.5)),
          )
        else if (_error != null)
          _message(Icons.wifi_off, _error!, retry: true)
        else if (!_enabled)
          _message(Icons.event_busy, '予約は現在受け付けていません')
        else if (_session == null)
          _loginCard()
        else if (_slots.isEmpty)
          _message(Icons.event_busy, '現在予約可能な日程はありません')
        else ...[
          _accountBar(),
          const SizedBox(height: 20),
          _dateSelector(),
          const SizedBox(height: 24),
          if (_selectedDate != null) _slotGrid(),
          if (_selected != null) ...[
            const SizedBox(height: 28),
            _confirmCard(),
          ],
          const SizedBox(height: 60),
        ],
      ],
    );
  }

  // ---- Googleログイン（未ログイン時）— Google風ミニマル ----
  Widget _loginCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Text('ログイン',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22, color: _ink, fontWeight: FontWeight.w400)),
          const SizedBox(height: 10),
          const Text(
            '予約には gse.okayama-c.ed.jp の\nGoogleアカウントを使用してください',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _sub, height: 1.8),
          ),
          if (_authNotice != null) ...[
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 18, color: _red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _authNotice!,
                      style: const TextStyle(
                          fontSize: 13, color: _red, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          // Google公式風の白ボタン（共通ウィジェット）
          GoogleSignInButton(onPressed: _startLogin),
        ],
      ),
    );
  }

  // ---- ログイン中アカウント表示 ----
  Widget _accountBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_circle, size: 18, color: _green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _email ?? 'ログイン済み',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: _ink),
            ),
          ),
          TextButton(
            onPressed: _logout,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('別のアカウント',
                style: TextStyle(fontSize: 12, color: _accent)),
          ),
        ],
      ),
    );
  }

  Widget _message(IconData icon, String text, {bool retry = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 44, color: _sub.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _sub, height: 1.7)),
          if (retry) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: _load,
              child: const Text('再読み込み', style: TextStyle(color: _accent)),
            ),
          ],
        ],
      ),
    );
  }

  // ---- 日付チップ ----
  Widget _dateSelector() {
    final dates = <String>[];
    for (final s in _slots) {
      final k = _dateKey(s);
      if (!dates.contains(k)) dates.add(k);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('1. 日付を選択',
            style: TextStyle(
                fontSize: 13, color: _sub, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in dates)
              ChoiceChip(
                label: Text(d),
                selected: _selectedDate == d,
                onSelected: (_) => setState(() {
                  _selectedDate = d;
                  _selected = null;
                }),
                labelStyle: TextStyle(
                    fontSize: 14,
                    color: _selectedDate == d ? _accent : _ink),
                selectedColor: const Color(0xFFE8F0FE),
                backgroundColor: Colors.white,
                side: BorderSide(
                    color: _selectedDate == d ? _accent : _line),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                showCheckmark: false,
              ),
          ],
        ),
      ],
    );
  }

  // ---- 時間スロット ----
  Widget _slotGrid() {
    final daySlots =
        _slots.where((s) => _dateKey(s) == _selectedDate).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('2. 時間を選択',
            style: TextStyle(
                fontSize: 13, color: _sub, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in daySlots) _slotChip(s),
          ],
        ),
      ],
    );
  }

  Widget _slotChip(ReserveSlot s) {
    final full = s.available <= 0;
    final sel = _selected?.start == s.start;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: full ? null : () => setState(() => _selected = s),
      child: Container(
        width: 104,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: full
              ? const Color(0xFFF1F3F4)
              : sel
                  ? const Color(0xFFE8F0FE)
                  : Colors.white,
          border: Border.all(color: sel ? _accent : _line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(_hm(s.start),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: full ? _sub.withValues(alpha: 0.5) : (sel ? _accent : _ink))),
            const SizedBox(height: 2),
            Text(
              full ? '満席' : '残り${s.available}組',
              style: TextStyle(
                  fontSize: 11,
                  color: full
                      ? _sub.withValues(alpha: 0.5)
                      : (s.available <= 1 ? _red : _green)),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 確認カード ----
  Widget _confirmCard() {
    final s = _selected!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('3. 予約内容の確認',
              style: TextStyle(
                  fontSize: 13, color: _sub, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.event, size: 18, color: _sub),
              const SizedBox(width: 10),
              Text('$_selectedDate ${_hm(s.start)}〜${_hm(s.end)}',
                  style: const TextStyle(fontSize: 15, color: _ink)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            maxLength: 20,
            decoration: InputDecoration(
              labelText: 'お名前・ニックネーム（任意）',
              labelStyle: const TextStyle(fontSize: 13, color: _sub),
              counterText: '',
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _accent),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            style: const TextStyle(fontSize: 14, color: _ink),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('予約を確定する', style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}


