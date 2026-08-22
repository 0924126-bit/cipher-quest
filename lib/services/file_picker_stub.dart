/// Picked file data returned by the platform file picker.
class PickedFile {
  final String name;
  final List<int> bytes;
  const PickedFile({required this.name, required this.bytes});
}

/// No-op picker for non-web platforms (dashboard is web-only in practice).
Future<PickedFile?> pickMp3File() async => null;

/// No-op image picker for non-web platforms.
Future<PickedFile?> pickImageFile() async => null;
