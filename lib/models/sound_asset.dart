/// Uploaded mp3 sound asset managed from the operator dashboard.
///
/// Every role has a built-in default sound; assigning an uploaded mp3
/// overrides it, and setting the upload back to "none" restores the
/// default automatically.
///
/// Roles (mirror of server/sounds.py):
///   none          - stored but unused (role falls back to built-in sound)
///   decode        - loop while a player is holding the machine
///   complete      - one-shot when a machine reaches 100%
///   skill_warn    - cue when a skill check pops up
///   skill_success - one-shot on skill check success
///   skill_fail    - one-shot on skill check miss
class SoundAsset {
  final String id;
  final String originalName;
  final String role;
  final String url;
  final int sizeBytes;
  final int createdAt;

  const SoundAsset({
    required this.id,
    required this.originalName,
    required this.role,
    required this.url,
    required this.sizeBytes,
    required this.createdAt,
  });

  factory SoundAsset.fromJson(Map<String, dynamic> json) {
    return SoundAsset(
      id: json['id'] as String,
      originalName: (json['original_name'] as String?) ?? 'sound.mp3',
      role: (json['role'] as String?) ?? 'none',
      url: (json['url'] as String?) ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
    );
  }

  static const roleLabels = <String, String>{
    'none': '未割当（初期音）',
    'decode': '解読中ループ',
    'complete': '解読完了',
    'skill_warn': 'スキルチェック出現',
    'skill_success': 'スキルチェック成功',
    'skill_fail': 'スキルチェック失敗',
    'timer_bgm': 'タイマーBGM（ループ）',
    'timer_key': 'タイマーキー音（既定）',
  };

  String get roleLabel => roleLabels[role] ?? role;
}

/// 音響エフェクト設定（ロールごと）。
/// volume: 0〜10000%（100=等倍、10000=100倍の爆音）
/// distortion: 0〜100（音割れの強さ、0=なし）
/// rate: 0.25〜4.0（再生速度、1=等倍。途中でもブースト反映）
class SoundFx {
  final int volume;
  final int distortion;
  final double rate;

  const SoundFx({this.volume = 100, this.distortion = 0, this.rate = 1.0});

  factory SoundFx.fromJson(Map<String, dynamic> json) => SoundFx(
        volume: (json['volume'] as num?)?.toInt() ?? 100,
        distortion: (json['distortion'] as num?)?.toInt() ?? 0,
        rate: (json['rate'] as num?)?.toDouble() ?? 1.0,
      );

  bool get isNeutral => volume == 100 && distortion == 0 && rate == 1.0;
}

/// Full payload of GET /api/sounds:
/// the uploaded assets plus the role->url map and the per-key bindings
/// used by the horror timer (key -> url for playback, key -> sound id
/// for the dashboard editor), plus live audio FX per role.
class SoundsData {
  final List<SoundAsset> sounds;
  final Map<String, String> roleMap;
  final Map<String, String> keyMap; // key -> url
  final Map<String, String> keyBindings; // key -> sound id
  final Map<String, SoundFx> fxMap; // role -> FX

  const SoundsData({
    required this.sounds,
    required this.roleMap,
    required this.keyMap,
    required this.keyBindings,
    required this.fxMap,
  });

  factory SoundsData.fromJson(Map<String, dynamic> json) {
    Map<String, String> strMap(dynamic v) => v is Map
        ? v.map((k, val) => MapEntry(k.toString(), val.toString()))
        : const {};
    Map<String, SoundFx> fxMap(dynamic v) => v is Map
        ? {
            for (final e in v.entries)
              if (e.value is Map<String, dynamic>)
                e.key.toString():
                    SoundFx.fromJson(e.value as Map<String, dynamic>),
          }
        : const {};
    return SoundsData(
      sounds: ((json['sounds'] as List?) ?? const [])
          .map((e) => SoundAsset.fromJson(e as Map<String, dynamic>))
          .toList(),
      roleMap: strMap(json['roles']),
      keyMap: strMap(json['keys']),
      keyBindings: strMap(json['key_bindings']),
      fxMap: fxMap(json['fx']),
    );
  }
}
