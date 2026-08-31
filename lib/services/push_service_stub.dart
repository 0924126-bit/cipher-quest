/// Web Push 購読（非webプラットフォーム用スタブ）。
library;

String? savedPushEndpoint() => null;

void storePushEndpoint(String? endpoint) {}

Future<Map<String, String>?> createPushSubscription(String vapidKey) async =>
    null;
