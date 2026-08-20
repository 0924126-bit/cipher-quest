import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/machine.dart';
import '../models/sound_asset.dart';

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

  Future<List<Machine>> listMachines() async {
    final res = await http.get(_u('/api/machines'));
    if (res.statusCode != 200) throw Exception('failed to list machines');
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (data['machines'] as List)
        .map((e) => Machine.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Machine> getMachine(String id) async {
    final res = await http.get(_u('/api/machines/$id'));
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
      headers: {'Content-Type': 'application/json'},
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
      headers: {'Content-Type': 'application/json'},
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
      headers: {'Content-Type': 'application/json'},
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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'speed_multiplier': multiplier}),
    );
    if (res.statusCode != 200) throw Exception('failed to change speed');
    return Machine.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<void> deleteMachine(String id) async {
    final res = await http.delete(_u('/api/machines/$id'));
    if (res.statusCode != 200) throw Exception('failed to delete machine');
  }

  Future<void> resetMachine(String id) async {
    final res = await http.post(_u('/api/machines/$id/reset'));
    if (res.statusCode != 200) throw Exception('failed to reset machine');
  }

  /// Public URL for a machine page (for QR / sharing).
  String machineUrl(String id) => '$baseUrl/#/machine/$id';

  // ---------------- sound assets (mp3) ----------------

  Future<List<SoundAsset>> listSounds() async {
    final res = await http.get(_u('/api/sounds'));
    if (res.statusCode != 200) throw Exception('failed to list sounds');
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (data['sounds'] as List)
        .map((e) => SoundAsset.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SoundAsset> uploadSound({
    required String filename,
    required List<int> bytes,
    String role = 'none',
  }) async {
    final req = http.MultipartRequest('POST', _u('/api/sounds'))
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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'role': role}),
    );
    if (res.statusCode != 200) throw Exception('failed to set sound role');
    return SoundAsset.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<void> deleteSound(String id) async {
    final res = await http.delete(_u('/api/sounds/$id'));
    if (res.statusCode != 200) throw Exception('failed to delete sound');
  }

  /// Public URL for the 3D game lobby.
  String gameUrl() => '$baseUrl/game/';

  // ---------------- 3D game admin ----------------

  Future<Map<String, dynamic>> gameStatus() async {
    final res = await http.get(_u('/api/game/status'));
    if (res.statusCode != 200) throw Exception('failed to get game status');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setGameConfig(
      {double? difficulty, bool? autoStart}) async {
    final res = await http.patch(
      _u('/api/game/config'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (difficulty != null) 'difficulty': difficulty,
        if (autoStart != null) 'auto_start': autoStart,
      }),
    );
    if (res.statusCode != 200) throw Exception('failed to set game config');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> gameForceStart() async {
    final res = await http.post(_u('/api/game/force_start'));
    if (res.statusCode != 200) throw Exception('failed to force start');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> gameForceEnd() async {
    final res = await http.post(_u('/api/game/force_end'));
    if (res.statusCode != 200) throw Exception('failed to force end');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }
}
