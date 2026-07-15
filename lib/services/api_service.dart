import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/machine.dart';

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
  }) async {
    final res = await http.patch(
      _u('/api/machines/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (name != null) 'name': name,
        if (durationSec != null) 'duration_sec': durationSec,
        if (design != null) 'design': design,
      }),
    );
    if (res.statusCode != 200) throw Exception('failed to update machine');
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
