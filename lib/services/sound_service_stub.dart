/// No-op sound backend for platforms without an HTML audio element
/// (used via conditional import from sound_service.dart).
class SoundBackend {
  void setSource(String role, String? url) {}
  void play(String role, {bool loop = false}) {}
  void playOneShot(String role) {}
  void stop(String role) {}
  void stopAll() {}
  bool hasSource(String role) => false;
  void dispose() {}
}
