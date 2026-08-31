/// Web Push 購読（web実装）。
///
/// 専用SW（push_sw.js）を登録し、PushManager.subscribe で購読を作成する。
/// 購読情報はサーバー（/api/ticket/push/subscribe）に保存され、
/// タブを閉じていても・iOSのPWAをタスクキルしていても
/// プッシュサービス（FCM/APNs）経由で通知が届くようになる。
///
/// iOS Safari の制約: ホーム画面に追加したPWAでのみ Push が使える
/// （通常のSafariタブでは PushManager が存在しない → null を返す）。
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const _endpointKey = 'ie_push_endpoint';

/// この端末で保存済みの購読endpoint（未購読なら null）。
String? savedPushEndpoint() {
  try {
    final v = web.window.localStorage.getItem(_endpointKey);
    return (v == null || v.isEmpty) ? null : v;
  } catch (_) {
    return null;
  }
}

void storePushEndpoint(String? endpoint) {
  try {
    if (endpoint == null || endpoint.isEmpty) {
      web.window.localStorage.removeItem(_endpointKey);
    } else {
      web.window.localStorage.setItem(_endpointKey, endpoint);
    }
  } catch (_) {}
}

/// Push購読を作成して {endpoint, p256dh, auth} を返す。
/// 失敗・非対応（iOSの通常Safari等）なら null。
Future<Map<String, String>?> createPushSubscription(String vapidKey) async {
  try {
    if (vapidKey.isEmpty) return null;
    // 1) push専用SWを登録（Flutter標準SWと共存できる別scope）
    final reg = await web.window.navigator.serviceWorker
        .register(
          'push_sw.js'.toJS,
          web.RegistrationOptions(scope: './push/'),
        )
        .toDart;
    // 2) 既存購読があれば再利用、なければ subscribe
    var sub = await reg.pushManager.getSubscription().toDart;
    sub ??= await reg.pushManager
        .subscribe(web.PushSubscriptionOptionsInit(
          userVisibleOnly: true,
          applicationServerKey: _b64uToBytes(vapidKey).toJS,
        ))
        .toDart;
    final endpoint = sub.endpoint;
    final p256dh = _keyB64u(sub, 'p256dh');
    final auth = _keyB64u(sub, 'auth');
    if (endpoint.isEmpty || p256dh.isEmpty || auth.isEmpty) return null;
    return {'endpoint': endpoint, 'p256dh': p256dh, 'auth': auth};
  } catch (_) {
    return null;
  }
}

String _keyB64u(web.PushSubscription sub, String name) {
  try {
    final buf = sub.getKey(name);
    if (buf == null) return '';
    final bytes = buf.toDart.asUint8List();
    return base64UrlEncode(bytes).replaceAll('=', '');
  } catch (_) {
    return '';
  }
}

Uint8List _b64uToBytes(String s) {
  var t = s.replaceAll('-', '+').replaceAll('_', '/');
  while (t.length % 4 != 0) {
    t += '=';
  }
  return base64Decode(t);
}
