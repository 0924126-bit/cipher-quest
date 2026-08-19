/// Uploaded mp3 sound asset managed from the operator dashboard.
///
/// Roles (mirror of server/sounds.py):
///   none     - stored but not used anywhere
///   decode   - loop while a player is holding the machine
///   complete - one-shot when a machine reaches 100%
///   rhythm   - BGM for the rhythm mini-game
///   success  - one-shot on rhythm success
///   fail     - one-shot on rhythm fail
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
    'none': '未割当',
    'decode': '解読中ループ',
    'complete': '解読完了',
    'rhythm': 'リズムBGM',
    'success': 'リズム成功',
    'fail': 'リズム失敗',
  };

  String get roleLabel => roleLabels[role] ?? role;
}
