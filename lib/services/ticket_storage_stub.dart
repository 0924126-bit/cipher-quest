/// No-op ticket storage for non-web platforms.
library;

String? loadTicketCode() => null;
void storeTicketCode(String? code) {}
String? loadTicketCache() => null;
void storeTicketCache(String json) {}
void requestNotifyPermission() {}
void showNotification(String title, String body) {}
void vibrate() {}
