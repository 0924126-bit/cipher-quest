import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/machine.dart';
import '../models/role_config.dart';
import '../models/sound_asset.dart';
import '../services/alarm_service.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

/// Dashboard state: live machine list + event feed via WebSocket,
/// CRUD via REST. Auto-reconnects.
class DashboardController extends ChangeNotifier {
  List<Machine> machines = [];
  List<MachineEvent> events = [];
  List<SoundAsset> sounds = [];
  RoleConfig roles = const RoleConfig();
  List<CurseEvent> curseEvents = [];
  bool allCompleted = false;
  bool connected = false;
  bool loading = true;
  String? error;

  /// 呪い通知音はブラウザの自動再生制限のため、操作後に有効化される。
  bool curseSoundArmed = false;

  SocketService? _socket;
  StreamSubscription? _msgSub;
  StreamSubscription? _statusSub;

  void init() {
    _socket = SocketService('/ws/dashboard', autoReconnect: true);
    _msgSub = _socket!.messages.listen(_onMessage);
    _statusSub = _socket!.connectionStatus.listen((ok) {
      connected = ok;
      notifyListeners();
    });
    _socket!.connect();
    // REST fallback for the initial paint
    _loadOnce();
  }

  Future<void> _loadOnce() async {
    try {
      machines = await ApiService.instance.listMachines();
      loading = false;
      notifyListeners();
    } catch (e) {
      loading = false;
      error = '$e';
      notifyListeners();
    }
    // sounds / roles are non-critical; load separately
    refreshSounds();
    refreshRoles();
  }

  Future<void> refreshSounds() async {
    try {
      sounds = await ApiService.instance.listSounds();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshRoles() async {
    try {
      roles = await ApiService.instance.getRoles();
      notifyListeners();
    } catch (_) {}
  }

  void _onMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'state':
        machines = (msg['machines'] as List)
            .map((e) => Machine.fromJson(e as Map<String, dynamic>))
            .toList();
        allCompleted = (msg['all_completed'] as bool?) ?? false;
        if (msg['events'] != null) {
          events = (msg['events'] as List)
              .map((e) => MachineEvent.fromJson(e as Map<String, dynamic>))
              .toList()
              .reversed
              .toList();
        }
        loading = false;
        notifyListeners();
        break;
      case 'event':
        final ev =
            MachineEvent.fromJson(msg['event'] as Map<String, dynamic>);
        events.insert(0, ev);
        if (events.length > 60) events = events.sublist(0, 60);
        notifyListeners();
        break;
      case 'sounds':
        // sound roles changed somewhere -> refresh the list
        refreshSounds();
        break;
      case 'roles':
        final r = msg['roles'];
        if (r is Map<String, dynamic>) {
          roles = RoleConfig.fromJson(r);
          notifyListeners();
        }
        break;
      case 'curse':
        final ev = msg['event'];
        if (ev is Map<String, dynamic>) {
          final curse = CurseEvent.fromJson(ev);
          curseEvents.insert(0, curse);
          if (curseEvents.length > 30) {
            curseEvents = curseEvents.sublist(0, 30);
          }
          if (curseSoundArmed) {
            AlarmService.instance.playCurseSting();
          }
          notifyListeners();
        }
        break;
    }
  }

  /// ユーザー操作のタイミングで呼ぶと以降の呪い通知に音が鳴る。
  void armCurseSound() {
    if (curseSoundArmed) return;
    curseSoundArmed = true;
    notifyListeners();
  }

  // ---------- aggregates ----------
  double get overallProgress {
    if (machines.isEmpty) return 0;
    final total = machines.fold<double>(0, (s, m) => s + m.progress);
    return total / machines.length;
  }

  int get completedCount => machines.where((m) => m.isCompleted).length;
  int get onlineCount => machines.where((m) => m.connected).length;

  // ---------- CRUD ----------
  Future<void> createMachine(
    String name,
    int durationSec, {
    String design = 'classic',
  }) async {
    await ApiService.instance.createMachine(
      name: name,
      durationSec: durationSec,
      design: design,
    );
  }

  Future<void> updateMachine(
    String id, {
    String? name,
    int? durationSec,
    String? design,
    bool? skillEnabled,
    int? skillDifficulty,
    double? skillSuccessBonus,
    double? skillFailPenalty,
  }) async {
    await ApiService.instance.updateMachine(
      id,
      name: name,
      durationSec: durationSec,
      design: design,
      skillEnabled: skillEnabled,
      skillDifficulty: skillDifficulty,
      skillSuccessBonus: skillSuccessBonus,
      skillFailPenalty: skillFailPenalty,
    );
  }

  /// Live decode-speed nudge from the machine card (+/-10% etc).
  Future<void> nudgeSpeed(String id, double deltaPercent) async {
    await ApiService.instance.nudgeMachineSpeed(id, deltaPercent);
  }

  /// Reset decode speed to 100%.
  Future<void> resetSpeed(String id) async {
    await ApiService.instance.setMachineSpeed(id, 1.0);
  }

  // ---------- sound assets ----------
  Future<void> uploadSound({
    required String filename,
    required List<int> bytes,
    String role = 'none',
  }) async {
    await ApiService.instance
        .uploadSound(filename: filename, bytes: bytes, role: role);
    await refreshSounds();
  }

  Future<void> setSoundRole(String id, String role) async {
    await ApiService.instance.setSoundRole(id, role);
    await refreshSounds();
  }

  Future<void> deleteSound(String id) async {
    await ApiService.instance.deleteSound(id);
    await refreshSounds();
  }

  Future<void> deleteMachine(String id) async {
    await ApiService.instance.deleteMachine(id);
  }

  Future<void> resetMachine(String id) async {
    await ApiService.instance.resetMachine(id);
  }

  String machineUrl(String id) => ApiService.instance.machineUrl(id);
  String chaserUrl() => ApiService.instance.chaserUrl();
  String cursedUrl() => ApiService.instance.cursedUrl();
  String hunterUrl() => ApiService.instance.hunterUrl();

  // ---------- role config ----------
  Future<void> updateRole(
    String role, {
    String? title,
    String? subtitle,
    int? alarmSec,
    int? cooldownSec,
    String? notifyMessage,
  }) async {
    await ApiService.instance.updateRole(
      role,
      title: title,
      subtitle: subtitle,
      alarmSec: alarmSec,
      cooldownSec: cooldownSec,
      notifyMessage: notifyMessage,
    );
    await refreshRoles();
  }

  Future<void> uploadCurseImage({
    required String filename,
    required List<int> bytes,
  }) async {
    await ApiService.instance
        .uploadCurseImage(filename: filename, bytes: bytes);
    await refreshRoles();
  }

  Future<void> deleteCurseImage() async {
    await ApiService.instance.deleteCurseImage();
    await refreshRoles();
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _statusSub?.cancel();
    _socket?.dispose();
    super.dispose();
  }
}
