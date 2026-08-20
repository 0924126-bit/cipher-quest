/// Cipher machine data model shared by decoder page and dashboard.
class Machine {
  final String id;
  final String name;
  final int durationSec;

  /// Visual design key: classic / mahogany / military / brass / noir.
  /// See lib/decoder/widgets/machine_designs.dart for definitions.
  final String design;

  /// Live decode speed multiplier set by operators (1.0 = 100%).
  final double speedMultiplier;

  /// Skill check (Identity V style QTE while decoding) settings.
  final bool skillEnabled;
  final int skillDifficulty; // 1 (easy) .. 5 (hell)
  final double skillSuccessBonus;
  final double skillFailPenalty;

  final double progress; // 0-100
  final String status; // idle / decoding / paused / completed
  final bool connected;
  final bool locked;
  final int skillSuccess;
  final int skillMiss;
  final int? completedAt;
  final int createdAt;
  final int updatedAt;

  const Machine({
    required this.id,
    required this.name,
    required this.durationSec,
    required this.design,
    this.speedMultiplier = 1.0,
    this.skillEnabled = true,
    this.skillDifficulty = 2,
    this.skillSuccessBonus = 5.0,
    this.skillFailPenalty = 2.0,
    required this.progress,
    required this.status,
    required this.connected,
    required this.locked,
    required this.skillSuccess,
    required this.skillMiss,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Machine.fromJson(Map<String, dynamic> json) {
    return Machine(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '暗号機',
      durationSec: (json['duration_sec'] as num?)?.toInt() ?? 60,
      design: (json['design'] as String?) ?? 'classic',
      speedMultiplier:
          (json['speed_multiplier'] as num?)?.toDouble() ?? 1.0,
      skillEnabled: (json['skill_enabled'] as bool?) ?? true,
      skillDifficulty: (json['skill_difficulty'] as num?)?.toInt() ?? 2,
      skillSuccessBonus:
          (json['skill_success_bonus'] as num?)?.toDouble() ?? 5.0,
      skillFailPenalty:
          (json['skill_fail_penalty'] as num?)?.toDouble() ?? 2.0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      status: (json['status'] as String?) ?? 'idle',
      connected: (json['connected'] as bool?) ?? false,
      locked: (json['locked'] as bool?) ?? false,
      skillSuccess: (json['skill_success'] as num?)?.toInt() ?? 0,
      skillMiss: (json['skill_miss'] as num?)?.toInt() ?? 0,
      completedAt: (json['completed_at'] as num?)?.toInt(),
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isDecoding => status == 'decoding';

  /// Speed as an operator-friendly percentage (100 = normal).
  int get speedPercent => (speedMultiplier * 100).round();

  Machine copyWith({
    String? name,
    int? durationSec,
    String? design,
    double? speedMultiplier,
    bool? skillEnabled,
    int? skillDifficulty,
    double? skillSuccessBonus,
    double? skillFailPenalty,
    double? progress,
    String? status,
  }) {
    return Machine(
      id: id,
      name: name ?? this.name,
      durationSec: durationSec ?? this.durationSec,
      design: design ?? this.design,
      speedMultiplier: speedMultiplier ?? this.speedMultiplier,
      skillEnabled: skillEnabled ?? this.skillEnabled,
      skillDifficulty: skillDifficulty ?? this.skillDifficulty,
      skillSuccessBonus: skillSuccessBonus ?? this.skillSuccessBonus,
      skillFailPenalty: skillFailPenalty ?? this.skillFailPenalty,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      connected: connected,
      locked: locked,
      skillSuccess: skillSuccess,
      skillMiss: skillMiss,
      completedAt: completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Dashboard event log entry.
class MachineEvent {
  final String machineId;
  final String type;
  final String message;
  final int at;

  const MachineEvent({
    required this.machineId,
    required this.type,
    required this.message,
    required this.at,
  });

  factory MachineEvent.fromJson(Map<String, dynamic> json) {
    return MachineEvent(
      machineId: (json['machine_id'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      at: (json['at'] as num?)?.toInt() ?? 0,
    );
  }
}
