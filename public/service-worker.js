const CACHE = 'ngu-v1';
const CORE = ['/', '/index.html', '/assets/css/styles.css'];
self.addEventListener('install', (e) => e.waitUntil(caches.open(CACHE).then((c) => c.addAll(CORE))));
self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  e.respondWith(caches.match(e.request).then((r) => r || fetch(e.request)));
});
