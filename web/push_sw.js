// Identity E — Web Push 専用 Service Worker。
//
// Flutter が生成する flutter_service_worker.js とは別 scope で登録し、
// push イベントの受信と通知表示だけを担当する。
// タブを閉じていても・iOSでタスクキルしていても、プッシュサービス
// (FCM / APNs) からこの SW が起こされて通知が表示される。

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {}
  const title = data.title || 'Identity E';
  const body = data.body || '';
  event.waitUntil(
    self.registration.showNotification(title, {
      body: body,
      tag: 'identity-e-push',
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      data: { url: data.url || '/#/ticket' },
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url =
    (event.notification.data && event.notification.data.url) || '/#/ticket';
  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((list) => {
        for (const c of list) {
          if ('focus' in c) return c.focus();
        }
        return self.clients.openWindow(url);
      }),
  );
});
