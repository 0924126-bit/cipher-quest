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

  Future<Machine> createMachine(
      {required String name, required int durationSec}) async {
    final res = await http.post(
      _u('/api/machines'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'duration_sec': durationSec}),
    );
    if (res.statusCode != 200) throw Exception('failed to create machine');
    return Machine.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<Machine> updateMachine(String id,
      {String? name, int? durationSec}) async {
    final res = await http.patch(
      _u('/api/machines/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (name != null) 'name': name,
        if (durationSec != null) 'duration_sec': durationSec,
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
}
