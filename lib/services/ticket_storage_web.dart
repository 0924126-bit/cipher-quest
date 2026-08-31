/// 整理券のローカル保存（web: localStorage）＋ブラウザ通知。
///
/// PWA/再訪問時にサーバーへ負担をかけないよう、コードと直近の券面
/// 情報を端末に保存する。表示はキャッシュから即時、状態はポーリングで
/// 軽く同期（サーバー側が正・不正はコード再検証で防止）。
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

const _codeKey = 'ie_ticket_code';
const _cacheKey = 'ie_ticket_cache';
const _rsSessKey = 'ie_reserve_session';
const _rsEmailKey = 'ie_reserve_email';

String? loadTicketCode() {
  try {
    final v = web.window.localStorage.getItem(_codeKey);
    return (v == null || v.isEmpty) ? null : v;
  } catch (_) {
    return null;
  }
}

void storeTicketCode(String? code) {
  try {
    if (code == null || code.isEmpty) {
      web.window.localStorage.removeItem(_codeKey);
      web.window.localStorage.removeItem(_cacheKey);
    } else {
      web.window.localStorage.setItem(_codeKey, code);
    }
  } catch (_) {}
}

String? loadTicketCache() {
  try {
    return web.window.localStorage.getItem(_cacheKey);
  } catch (_) {
    return null;
  }
}

void storeTicketCache(String json) {
  try {
    web.window.localStorage.setItem(_cacheKey, json);
  } catch (_) {}
}

/// 予約用Googleログインのセッション（Workersが発行、3時間有効）。
String? loadReserveSession() {
  try {
    final v = web.window.localStorage.getItem(_rsSessKey);
    return (v == null || v.isEmpty) ? null : v;
  } catch (_) {
    return null;
  }
}

void storeReserveSession(String? session) {
  try {
    if (session == null || session.isEmpty) {
      web.window.localStorage.removeItem(_rsSessKey);
    } else {
      web.window.localStorage.setItem(_rsSessKey, session);
    }
  } catch (_) {}
}

/// ログイン中のメールアドレス（表示用。サーバー側が正）。
String? loadReserveEmail() {
  try {
    final v = web.window.localStorage.getItem(_rsEmailKey);
    return (v == null || v.isEmpty) ? null : v;
  } catch (_) {
    return null;
  }
}

void storeReserveEmail(String? email) {
  try {
    if (email == null || email.isEmpty) {
      web.window.localStorage.removeItem(_rsEmailKey);
    } else {
      web.window.localStorage.setItem(_rsEmailKey, email);
    }
  } catch (_) {}
}

/// ブラウザ通知の許可を要求（ユーザー操作の中で呼ぶ）。
void requestNotifyPermission() {
  try {
    web.Notification.requestPermission();
  } catch (_) {}
}

/// 通知を表示（許可済みのときだけ）。タブが背面でも届く。
void showNotification(String title, String body) {
  try {
    if (web.Notification.permission == 'granted') {
      web.Notification(
        title,
        web.NotificationOptions(body: body, tag: 'identity-e-ticket'),
      );
    }
  } catch (_) {}
}

/// ページタイトル点滅などの代替不要：バイブがあれば揺らす（スマホ）。
void vibrate() {
  try {
    web.window.navigator.vibrate([200, 100, 200].jsify() as JSAny);
  } catch (_) {}
}
