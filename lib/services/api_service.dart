import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/machine.dart';
import '../models/role_config.dart';
import '../models/sound_asset.dart';
import '../models/ticket.dart';
import 'auth_service.dart';

/// REST API client. Base URL is same-origin (server hosts the Flutter build).
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  /// Same-origin base. Uri.base works on web.
  String get baseUrl {
    final origin = Uri.base.origin;
    return origin;
  }

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  /// Auth headers for every API call (site-wide password gate).
  Map<String, String> get _auth => AuthService.instance.authHeaders;

  Map<String, String> get _authJson =>
      {'Content-Type': 'application/json', ..._auth};

  Future<List<Machine>> listMachines() async {
    final res = await http.get(_u('/api/machines'), headers: _auth);
    if (res.statusCode != 200) throw Exception('failed to list machines');
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (data['machines'] as List)
        .map((e) => Machine.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Machine> getMachine(String id) async {
    final res = await http.get(_u('/api/machines/$id'), headers: _auth);
    if (res.statusCode != 200) throw Exception('machine not found');
    return Machine.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<Machine> createMachine({
    required String name,
    required int durationSec,
    String design = 'classic',
  }) async {
    final res = await http.post(
      _u('/api/machines'),
      headers: _authJson,
      body: jsonEncode({
        'name': name,
        'duration_sec': durationSec,
        'design': design,
      }),
    );
    if (res.statusCode != 200) throw Exception('failed to create machine');
    return Machine.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<Machine> updateMachine(
    String id, {
    String? name,
    int? durationSec,
    String? design,
    double? speedMultiplier,
    bool? skillEnabled,
    int? skillDifficulty,
    double? skillSuccessBonus,
    double? skillFailPenalty,
  }) async {
    final res = await http.patch(
      _u('/api/machines/$id'),
      headers: _authJson,
      body: jsonEncode({
        if (name != null) 'name': name,
        if (durationSec != null) 'duration_sec': durationSec,
        if (design != null) 'design': design,
        if (speedMultiplier != null) 'speed_multiplier': speedMultiplier,
        if (skillEnabled != null) 'skill_enabled': skillEnabled,
        if (skillDifficulty != null) 'skill_difficulty': skillDifficulty,
        if (skillSuccessBonus != null)
          'skill_success_bonus': skillSuccessBonus,
        if (skillFailPenalty != null)
          'skill_fail_penalty': skillFailPenalty,
      }),
    );
    if (res.statusCode != 200) throw Exception('failed to update machine');
    return Machine.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  /// Nudge decode speed live: deltaPercent=+10 => +10 percent points.
  Future<Machine> nudgeMachineSpeed(String id, double deltaPercent) async {
    final res = await http.post(
      _u('/api/machines/$id/speed'),
      headers: _authJson,
      body: jsonEncode({'delta_percent': deltaPercent}),
    );
    if (res.statusCode != 200) throw Exception('failed to change speed');
    return Machine.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  /// Set decode speed to an absolute multiplier (1.0 = 100%).
  Future<Machine> setMachineSpeed(String id, double multiplier) async {
    final res = await http.post(
      _u('/api/machines/$id/speed'),
      headers: _authJson,
      body: jsonEncode({'speed_multiplier': multiplier}),
    );
    if (res.statusCode != 200) throw Exception('failed to change speed');
    return Machine.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<void> deleteMachine(String id) async {
    final res = await http.delete(_u('/api/machines/$id'), headers: _auth);
    if (res.statusCode != 200) throw Exception('failed to delete machine');
  }

  Future<void> resetMachine(String id) async {
    final res = await http.post(_u('/api/machines/$id/reset'), headers: _auth);
    if (res.statusCode != 200) throw Exception('failed to reset machine');
  }

  /// Public URL for a machine page (for QR / sharing).
  String machineUrl(String id) => '$baseUrl/#/machine/$id';

  // ---------------- sound assets (mp3) ----------------

  Future<List<SoundAsset>> listSounds() async {
    final res = await http.get(_u('/api/sounds'), headers: _auth);
    if (res.statusCode != 200) throw Exception('failed to list sounds');
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (data['sounds'] as List)
        .map((e) => SoundAsset.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Full sounds payload: assets + role->url map + per-key bindings.
  Future<SoundsData> getSoundsData() async {
    final res = await http.get(_u('/api/sounds'), headers: _auth);
    if (res.statusCode != 200) throw Exception('failed to get sounds');
    return SoundsData.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  /// Bind a keyboard key ("a".."z", "digit1".., "space"...) to a sound.
  Future<void> setKeySound(String key, String soundId) async {
    final res = await http.post(
      _u('/api/sounds/keymap'),
      headers: _authJson,
      body: jsonEncode({'key': key, 'sound_id': soundId}),
    );
    if (res.statusCode != 200) {
      String detail = 'failed to bind key';
      try {
        final body =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        detail = (body['detail'] as String?) ?? detail;
      } catch (_) {}
      throw Exception(detail);
    }
  }

  Future<void> removeKeySound(String key) async {
    final res =
        await http.delete(_u('/api/sounds/keymap/$key'), headers: _auth);
    if (res.statusCode != 200) throw Exception('failed to unbind key');
  }

  Future<SoundAsset> uploadSound({
    required String filename,
    required List<int> bytes,
    String role = 'none',
  }) async {
    final req = http.MultipartRequest('POST', _u('/api/sounds'))
      ..headers.addAll(_auth)
      ..fields['role'] = role
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      String detail = 'failed to upload sound';
      try {
        final body =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        detail = (body['detail'] as String?) ?? detail;
      } catch (_) {}
      throw Exception(detail);
    }
    return SoundAsset.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<SoundAsset> setSoundRole(String id, String role) async {
    final res = await http.patch(
      _u('/api/sounds/$id'),
      headers: _authJson,
      body: jsonEncode({'role': role}),
    );
    if (res.statusCode != 200) throw Exception('failed to set sound role');
    return SoundAsset.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<void> deleteSound(String id) async {
    final res = await http.delete(_u('/api/sounds/$id'), headers: _auth);
    if (res.statusCode != 200) throw Exception('failed to delete sound');
  }

  /// Public URL for the 3D game lobby.
  String gameUrl() => '$baseUrl/game/';

  // ---------------- role pages (chaser / cursed / hunter) ----------------

  String chaserUrl() => '$baseUrl/#/chaser';
  String cursedUrl() => '$baseUrl/#/cursed';
  String hunterUrl() => '$baseUrl/#/hunter';
  String timerUrl() => '$baseUrl/#/timer';

  Future<RoleConfig> getRoles() async {
    final res = await http.get(_u('/api/roles'), headers: _auth);
    if (res.statusCode != 200) throw Exception('failed to get roles');
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return RoleConfig.fromJson(data['roles'] as Map<String, dynamic>);
  }

  Future<void> updateRole(
    String role, {
    String? title,
    String? subtitle,
    int? alarmSec,
    int? cooldownSec,
    String? notifyMessage,
    int? durationSec,
    String? style,
  }) async {
    final res = await http.patch(
      _u('/api/roles/$role'),
      headers: _authJson,
      body: jsonEncode({
        if (title != null) 'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (alarmSec != null) 'alarm_sec': alarmSec,
        if (cooldownSec != null) 'cooldown_sec': cooldownSec,
        if (notifyMessage != null) 'notify_message': notifyMessage,
        if (durationSec != null) 'duration_sec': durationSec,
        if (style != null) 'style': style,
      }),
    );
    if (res.statusCode != 200) throw Exception('failed to update role');
  }

  /// Fire the chaser's one-shot alarm.
  /// Returns alarm seconds, or null if it was already used (409).
  Future<int?> fireChaserAlarm() async {
    final res =
        await http.post(_u('/api/roles/chaser/fire'), headers: _auth);
    if (res.statusCode == 409) return null;
    if (res.statusCode != 200) throw Exception('failed to fire alarm');
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (data['alarm_sec'] as num?)?.toInt() ?? 30;
  }

  /// Re-arm the chaser alarm (dashboard).
  Future<void> armChaserAlarm() async {
    final res = await http.post(_u('/api/roles/chaser/arm'), headers: _auth);
    if (res.statusCode != 200) throw Exception('failed to arm alarm');
  }

  /// Global reset: all machine progress + speeds + chaser alarm.
  Future<void> globalReset() async {
    final res = await http.post(_u('/api/reset'), headers: _auth);
    if (res.statusCode != 200) throw Exception('failed to reset');
  }

  /// Fire the curse. Returns the server-confirmed cooldown seconds.
  Future<int> pressCurse() async {
    final res = await http.post(_u('/api/roles/cursed/press'), headers: _auth);
    if (res.statusCode != 200) throw Exception('failed to press curse');
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (data['cooldown_sec'] as num?)?.toInt() ?? 30;
  }

  Future<String> uploadCurseImage({
    required String filename,
    required List<int> bytes,
  }) async {
    final req = http.MultipartRequest('POST', _u('/api/roles/cursed/image'))
      ..headers.addAll(_auth)
      ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      String detail = '画像のアップロードに失敗しました';
      try {
        final body =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        detail = (body['detail'] as String?) ?? detail;
      } catch (_) {}
      throw Exception(detail);
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (data['button_image'] as String?) ?? '';
  }

  Future<void> deleteCurseImage() async {
    final res = await http.delete(_u('/api/roles/cursed/image'), headers: _auth);
    if (res.statusCode != 200) throw Exception('failed to delete image');
  }

  // ---------------- horror timer ----------------

  Future<String> uploadTimerImage({
    required String filename,
    required List<int> bytes,
  }) async {
    final req = http.MultipartRequest('POST', _u('/api/roles/timer/image'))
      ..headers.addAll(_auth)
      ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      String detail = '画像のアップロードに失敗しました';
      try {
        final body =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        detail = (body['detail'] as String?) ?? detail;
      } catch (_) {}
      throw Exception(detail);
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (data['bg_image'] as String?) ?? '';
  }

  Future<void> deleteTimerImage() async {
    final res = await http.delete(_u('/api/roles/timer/image'), headers: _auth);
    if (res.statusCode != 200) throw Exception('failed to delete image');
  }

  // ---------------- 3D game admin ----------------

  Future<Map<String, dynamic>> gameStatus() async {
    final res = await http.get(_u('/api/game/status'), headers: _auth);
    if (res.statusCode != 200) throw Exception('failed to get game status');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setGameConfig(
      {double? difficulty, bool? autoStart}) async {
    final res = await http.patch(
      _u('/api/game/config'),
      headers: _authJson,
      body: jsonEncode({
        if (difficulty != null) 'difficulty': difficulty,
        if (autoStart != null) 'auto_start': autoStart,
      }),
    );
    if (res.statusCode != 200) throw Exception('failed to set game config');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> gameForceStart() async {
    final res = await http.post(_u('/api/game/force_start'), headers: _auth);
    if (res.statusCode != 200) throw Exception('failed to force start');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> gameForceEnd() async {
    final res = await http.post(_u('/api/game/force_end'), headers: _auth);
    if (res.statusCode != 200) throw Exception('failed to force end');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  // ==================================================================
  // 音響エフェクト（音割れ / 爆音 / 再生速度）
  // ==================================================================

  Future<void> setSoundFx(
    String role, {
    int? volume,
    int? distortion,
    double? rate,
  }) async {
    final res = await http.patch(
      _u('/api/sounds/fx/$role'),
      headers: _authJson,
      body: jsonEncode({
        if (volume != null) 'volume': volume,
        if (distortion != null) 'distortion': distortion,
        if (rate != null) 'rate': rate,
      }),
    );
    if (res.statusCode != 200) throw Exception('failed to set sound fx');
  }

  // ==================================================================
  // 整理券 — スタッフ側（サイトパスワード認証）
  // ==================================================================

  Future<(List<Ticket>, TicketSettings, int)> listTickets() async {
    final res = await http.get(_u('/api/tickets'), headers: _auth);
    if (res.statusCode != 200) throw Exception('failed to list tickets');
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final tickets = ((data['tickets'] as List?) ?? const [])
        .map((e) => Ticket.fromJson(e as Map<String, dynamic>))
        .toList();
    final settings = TicketSettings.fromJson(
        (data['settings'] as Map<String, dynamic>?) ?? const {});
    return (tickets, settings, (data['active'] as num?)?.toInt() ?? 0);
  }

  Future<Ticket> issueTicket({
    required String kind,
    String label = '',
    String code = '',
    int reservedSlot = 0,
    String place = '',
    int party = 1,
  }) async {
    final res = await http.post(
      _u('/api/tickets'),
      headers: _authJson,
      body: jsonEncode({
        'kind': kind,
        'label': label,
        'code': code,
        if (reservedSlot > 0) 'reserved_slot': reservedSlot,
        if (place.isNotEmpty) 'place': place,
        if (party > 1) 'party': party,
      }),
    );
    if (res.statusCode != 200) {
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      throw Exception((data['detail'] as String?) ?? 'failed to issue');
    }
    return Ticket.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<void> updateTicketSettings({
    int? gameSec,
    int? intervalSec,
    int? capacity,
    int? lateCancelSec,
    bool? reviewsEnabled,
    bool? reserveEnabled,
    int? reserveSlotSec,
    int? reserveSlotCapacity,
    List<ReserveWindow>? reserveWindows,
    List<String>? reserveAllowedEmails,
  }) async {
    final res = await http.patch(
      _u('/api/tickets/settings'),
      headers: _authJson,
      body: jsonEncode({
        if (gameSec != null) 'game_sec': gameSec,
        if (intervalSec != null) 'interval_sec': intervalSec,
        if (capacity != null) 'capacity': capacity,
        if (lateCancelSec != null) 'late_cancel_sec': lateCancelSec,
        if (reviewsEnabled != null) 'reviews_enabled': reviewsEnabled,
        if (reserveEnabled != null) 'reserve_enabled': reserveEnabled,
        if (reserveSlotSec != null) 'reserve_slot_sec': reserveSlotSec,
        if (reserveSlotCapacity != null)
          'reserve_slot_capacity': reserveSlotCapacity,
        if (reserveWindows != null)
          'reserve_windows': reserveWindows.map((w) => w.toJson()).toList(),
        if (reserveAllowedEmails != null)
          'reserve_allowed_emails': reserveAllowedEmails,
      }),
    );
    if (res.statusCode != 200) throw Exception('failed to update settings');
  }

  // ==================================================================
  // 予約 — 公開（認証不要）
  // ==================================================================

  /// 空きスロット一覧。(enabled, slotSec, slotCapacity, slots)
  Future<(bool, int, int, List<ReserveSlot>)> reserveSlots() async {
    final res = await http.get(_u('/api/reserve/slots'));
    if (res.statusCode != 200) throw Exception('failed to load slots');
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final slots = ((data['slots'] as List?) ?? const [])
        .map((e) => ReserveSlot.fromJson(e as Map<String, dynamic>))
        .toList();
    return (
      (data['enabled'] as bool?) ?? false,
      (data['slot_sec'] as num?)?.toInt() ?? 1800,
      (data['slot_capacity'] as num?)?.toInt() ?? 5,
      slots,
    );
  }

  /// 予約ログインセッションの検証。有効ならメール、無効なら null。
  Future<String?> reserveMe(String session) async {
    try {
      final res = await http.post(
        _u('/api/reserve/me'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'session': session}),
      );
      if (res.statusCode != 200) return null;
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final email = data['email'] as String?;
      return (email == null || email.isEmpty) ? null : email;
    } catch (_) {
      return null;
    }
  }

  /// 予約作成（Googleログイン必須）。成功で (code, ticket)、
  /// 失敗で例外（401/403は 'AUTH:' プレフィックス付き→再ログイン誘導）。
  Future<(String, Ticket)> reserveCreate(
      int slotStart, String label, String session,
      {int party = 1}) async {
    final res = await http.post(
      _u('/api/reserve'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'slot_start': slotStart,
        'label': label,
        'session': session,
        if (party > 1) 'party': party,
      }),
    );
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception(
          'AUTH:${(data['detail'] as String?) ?? 'Googleログインが必要です'}');
    }
    if (res.statusCode != 200) {
      throw Exception((data['detail'] as String?) ?? '予約に失敗しました');
    }
    return (
      (data['code'] as String?) ?? '',
      Ticket.fromJson(data['ticket'] as Map<String, dynamic>),
    );
  }

  /// action: call / start / finish / cancel / requeue / read
  Future<bool> ticketAction(String id, String action) async {
    final res =
        await http.post(_u('/api/tickets/$id/$action'), headers: _auth);
    return res.statusCode == 200;
  }

  /// kind: 'chat'（会話） or 'notify'（任意の通知）
  Future<void> ticketStaffMessage(String id, String kind, String text) async {
    final res = await http.post(
      _u('/api/tickets/$id/$kind'),
      headers: _authJson,
      body: jsonEncode({'text': text}),
    );
    if (res.statusCode != 200) throw Exception('failed to send');
  }

  Future<void> deleteTicket(String id) async {
    final res = await http.delete(_u('/api/tickets/$id'), headers: _auth);
    if (res.statusCode != 200) throw Exception('failed to delete');
  }

  // ==================================================================
  // 整理券 — 来場者側（整理券コードが認証。サイトパスワード不要）
  // ==================================================================

  /// Googleセッションで自分の整理券を取得。(code, ticket, email)。
  /// セッション無効=null（再ログイン）、整理券なし=例外 'NOTICKET'。
  Future<(String, Ticket, String)?> ticketBySession(String session) async {
    final res = await http.post(
      _u('/api/ticket/bysession'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'session': session}),
    );
    if (res.statusCode == 401) return null;
    if (res.statusCode == 404) throw Exception('NOTICKET');
    if (res.statusCode != 200) throw Exception('failed to login');
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (
      (data['code'] as String?) ?? '',
      Ticket.fromJson(data['ticket'] as Map<String, dynamic>),
      (data['email'] as String?) ?? '',
    );
  }

  Future<Ticket?> ticketLogin(String code) async {
    final res = await http.post(
      _u('/api/ticket/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code}),
    );
    if (res.statusCode == 401) return null;
    if (res.statusCode == 429) throw Exception('rate_limited');
    if (res.statusCode != 200) throw Exception('failed to login');
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return Ticket.fromJson(data['ticket'] as Map<String, dynamic>);
  }

  Future<Ticket?> ticketState(String code) async {
    final res = await http.post(
      _u('/api/ticket/state'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code}),
    );
    if (res.statusCode != 200) return null;
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return Ticket.fromJson(data['ticket'] as Map<String, dynamic>);
  }

  Future<Ticket?> ticketCancel(String code) async {
    final res = await http.post(
      _u('/api/ticket/cancel'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code}),
    );
    if (res.statusCode != 200) return null;
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return Ticket.fromJson(data['ticket'] as Map<String, dynamic>);
  }

  Future<Ticket?> ticketChat(String code, String text) async {
    final res = await http.post(
      _u('/api/ticket/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code, 'text': text}),
    );
    if (res.statusCode != 200) return null;
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return Ticket.fromJson(data['ticket'] as Map<String, dynamic>);
  }

  Future<void> ticketMarkRead(String code) async {
    await http.post(
      _u('/api/ticket/read'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code}),
    );
  }

  /// 口コミ投稿（体験済みの整理券コードのみ・1回限り）。
  /// 成功で null、失敗でエラーメッセージを返す。
  Future<String?> postReview(String code, int stars, String text) async {
    final res = await http.post(
      _u('/api/ticket/review'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code, 'stars': stars, 'text': text}),
    );
    if (res.statusCode == 200) return null;
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (data['detail'] as String?) ?? '投稿に失敗しました';
  }

  /// 口コミ削除（運営・サイト認証必須）。
  Future<bool> deleteReview(String id) async {
    final res = await http.delete(_u('/api/reviews/$id'), headers: _auth);
    return res.statusCode == 200;
  }

  /// 全整理券・口コミ・連番・push購読の一括リセット（テスト後の初期化）。
  Future<bool> wipeTickets() async {
    final res = await http.post(_u('/api/tickets/wipe'), headers: _auth);
    return res.statusCode == 200;
  }

  // ==================================================================
  // Web Push（タブを閉じていても・iOSタスクキル中でも届く通知）
  // ==================================================================

  /// VAPID公開鍵（購読作成に必要。空なら未設定）。
  Future<String> pushVapidKey() async {
    final res = await http.get(_u('/api/push/vapid'));
    if (res.statusCode != 200) return '';
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (data['key'] as String?) ?? '';
  }

  /// Push購読をサーバーに保存（整理券コードに紐づく）。
  Future<bool> pushSubscribe(
      String code, Map<String, String> sub) async {
    final res = await http.post(
      _u('/api/ticket/push/subscribe'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code': code,
        'endpoint': sub['endpoint'],
        'p256dh': sub['p256dh'],
        'auth': sub['auth'],
      }),
    );
    return res.statusCode == 200;
  }

  /// 公開口コミ一覧（認証不要）。
  Future<(bool, List<Review>)> listReviews() async {
    final res = await http.get(_u('/api/reviews'));
    if (res.statusCode != 200) return (false, const <Review>[]);
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final reviews = ((data['reviews'] as List?) ?? const [])
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList();
    return ((data['enabled'] as bool?) ?? false, reviews);
  }

  // ==================================================================
  // YouTube -> mp4
  // ==================================================================

  Future<Map<String, dynamic>> resolveYoutube(String url) async {
    final res = await http.post(
      _u('/api/ytdl'),
      headers: _authJson,
      body: jsonEncode({'url': url}),
    );
    if (res.statusCode != 200) throw Exception('failed to resolve');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }
}
