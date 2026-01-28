/**
 * Service Worker for Web Push Notifications
 * This file must be in the public directory to be accessible
 */

self.addEventListener('push', function(event) {
  console.log('[Service Worker] Push received');

  let notificationData = {
    title: 'New Notification',
    body: 'You have a new notification',
    icon: '/icon-192x192.png', // Update with your icon path
    badge: '/badge-72x72.png', // Update with your badge path
    data: {},
  };

  if (event.data) {
    try {
      const data = event.data.json();
      notificationData = {
        title: data.notification?.title || data.title || notificationData.title,
        body: data.notification?.body || data.body || notificationData.body,
        icon: data.notification?.icon || notificationData.icon,
        badge: data.notification?.badge || notificationData.badge,
        image: data.notification?.image,
        data: data.data || {},
      };
    } catch (e) {
      console.error('[Service Worker] Error parsing push data:', e);
    }
  }

  const promiseChain = self.registration.showNotification(notificationData.title, {
    body: notificationData.body,
    icon: notificationData.icon,
    badge: notificationData.badge,
    image: notificationData.image,
    data: notificationData.data,
    tag: notificationData.data.type || 'default',
    requireInteraction: false,
    vibrate: [200, 100, 200],
  });

  event.waitUntil(promiseChain);
});

self.addEventListener('notificationclick', function(event) {
  console.log('[Service Worker] Notification clicked');

  event.notification.close();

  // Handle notification click based on data
  const data = event.notification.data;
  const type = data?.type;

  let url = '/admin/dashboard';

  switch (type) {
    case 'order_update':
      url = `/admin/dashboard/orders${data.order_id ? `?id=${data.order_id}` : ''}`;
      break;
    case 'payment':
      url = `/admin/dashboard/orders${data.order_id ? `?id=${data.order_id}` : ''}`;
      break;
    case 'booking_request':
      url = `/admin/dashboard/orders${data.booking_id ? `?id=${data.booking_id}` : ''}`;
      break;
    case 'support':
      url = '/admin/dashboard/support';
      break;
    default:
      url = '/admin/dashboard';
  }

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      // If a window is already open, focus it
      for (let i = 0; i < clientList.length; i++) {
        const client = clientList[i];
        if (client.url === url && 'focus' in client) {
          return client.focus();
        }
      }
      // Otherwise, open a new window
      if (clients.openWindow) {
        return clients.openWindow(url);
      }
    })
  );
});

self.addEventListener('notificationclose', function(event) {
  console.log('[Service Worker] Notification closed');
  // You can track notification dismissals here if needed
});
