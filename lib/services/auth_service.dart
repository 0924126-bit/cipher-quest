import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_storage_stub.dart'
    if (dart.library.js_interop) 'auth_storage_web.dart';

/// Site-wide password authentication client.
///
/// Flow:
///  1. App boots -> [restore] loads a stored token and validates it
///     against the server.
///  2. No/invalid token -> the app shows the lock screen; [login]
///     exchanges the password for a bearer token.
///  3. All API calls and WebSockets attach the token via
///     [authHeaders] / [wsToken].
///  4. Password change (secret /#/passkey page) revokes all sessions.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  String? _token;

  String get baseUrl => Uri.base.origin;

  bool get hasToken => _token != null && _token!.isNotEmpty;

  String get wsToken => _token ?? '';

  Map<String, String> get authHeaders =>
      {if (hasToken) 'Authorization': 'Bearer $_token'};

  /// Load the stored token and check it server-side.
  /// Returns true when a valid session exists.
  Future<bool> restore() async {
    final stored = loadStoredToken();
    if (stored == null) return false;
    _token = stored;
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/auth/check'),
        headers: authHeaders,
      );
      if (res.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        if (data['ok'] == true) return true;
      }
    } catch (_) {
      // network trouble: keep token, allow retry later
      return false;
    }
    logout();
    return false;
  }

  /// Exchange password for a session token. Throws with a message on
  /// wrong password.
  Future<void> login(String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'password': password}),
    );
    if (res.statusCode != 200) {
      String detail = 'パスワードが違います';
      try {
        final body =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        detail = (body['detail'] as String?) ?? detail;
      } catch (_) {}
      throw Exception(detail);
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    _token = data['token'] as String?;
    storeToken(_token);
  }

  /// Change the site password (requires a valid session + old password).
  /// All sessions are revoked server-side; caller must re-login.
  Future<void> changePassword(String oldPassword, String newPassword) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/change'),
      headers: {'Content-Type': 'application/json', ...authHeaders},
      body: jsonEncode({
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    );
    if (res.statusCode != 200) {
      String detail = 'パスワードの変更に失敗しました';
      try {
        final body =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        detail = (body['detail'] as String?) ?? detail;
      } catch (_) {}
      throw Exception(detail);
    }
    // server revoked every session including ours
    logout();
  }

  void logout() {
    _token = null;
    storeToken(null);
  }
}
