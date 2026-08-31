import 'ticket_storage_stub.dart'
    if (dart.library.js_interop) 'ticket_storage_web.dart' as impl;

/// 整理券のローカル保存＋通知のファサード（web/stub切替）。
class TicketStorage {
  TicketStorage._();

  static String? loadCode() => impl.loadTicketCode();
  static void storeCode(String? code) => impl.storeTicketCode(code);
  static String? loadCache() => impl.loadTicketCache();
  static void storeCache(String json) => impl.storeTicketCache(json);
  static void requestNotifyPermission() => impl.requestNotifyPermission();
  static void showNotification(String title, String body) =>
      impl.showNotification(title, body);
  static void vibrate() => impl.vibrate();

  // 予約用Googleログインのセッション（token + 表示用メール）。
  static String? loadReserveSession() => impl.loadReserveSession();
  static void storeReserveSession(String? s) => impl.storeReserveSession(s);
  static String? loadReserveEmail() => impl.loadReserveEmail();
  static void storeReserveEmail(String? e) => impl.storeReserveEmail(e);
}
