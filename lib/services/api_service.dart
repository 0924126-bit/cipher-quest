import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/machine.dart';
import '../models/role_config.dart';
import '../models/sound_asset.dart';
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
}
