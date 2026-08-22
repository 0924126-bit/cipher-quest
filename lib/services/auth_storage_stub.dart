/// Non-web stub for token persistence (in-memory only).
String? _token;

String? loadStoredToken() => _token;

void storeToken(String? token) {
  _token = token;
}
