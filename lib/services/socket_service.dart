import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'auth_service.dart';

/// Thin WebSocket wrapper with JSON messages, auto-reconnect (dashboard only),
/// and a broadcast stream of decoded messages.
class SocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _closed = false;

  /// Reconnect backoff (seconds). Doubles up to 60s to avoid hammering
  /// the server (each WS handshake counts against the free tier);
  /// resets to 2s once a connection delivers a message.
  int _backoffSec = 2;
  final bool autoReconnect;
  final String path; // e.g. /ws/dashboard or /ws/machine/xxx

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get messages => _controller.stream;
  Stream<bool> get connectionStatus => _statusController.stream;
  bool _connected = false;
  bool get isConnected => _connected;

  /// When set, used verbatim as the query string instead of `token=`
  /// (e.g. `code=ABCD1234` for the visitor ticket socket).
  final String? queryOverride;

  SocketService(this.path, {this.autoReconnect = false, this.queryOverride});

  String get _wsUrl {
    final base = Uri.base;
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    // site-wide auth: server verifies this token at handshake time
    final query = queryOverride ??
        'token=${Uri.encodeComponent(AuthService.instance.wsToken)}';
    return '$scheme://${base.host}${base.hasPort ? ':${base.port}' : ''}'
        '$path?$query';
  }

  void connect() {
    if (_closed) return;
    // clean up any previous attempt before reconnecting
    _sub?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _sub = _channel!.stream.listen(
        (raw) {
          if (!_connected) {
            _connected = true;
            _backoffSec = 2; // healthy again -> fast reconnects
            _statusController.add(true);
          }
          try {
            final msg = jsonDecode(raw as String) as Map<String, dynamic>;
            _controller.add(msg);
          } catch (_) {}
        },
        onDone: _onDisconnect,
        onError: (_) => _onDisconnect(),
      );
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        send({'type': 'ping'});
      });
    } catch (_) {
      _onDisconnect();
    }
  }

  void _onDisconnect() {
    _connected = false;
    // Always notify listeners, even when the very first attempt failed.
    // Without this the decoder page could hang on "connecting" forever.
    if (!_closed) {
      _statusController.add(false);
    }
    _pingTimer?.cancel();
    if (autoReconnect && !_closed) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(seconds: _backoffSec), connect);
      _backoffSec = (_backoffSec * 2).clamp(2, 60);
    }
  }

  void send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (_) {}
  }

  void dispose() {
    _closed = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _controller.close();
    _statusController.close();
  }
}
