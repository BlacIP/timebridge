/* TimeBridge service worker — network-first with offline fallback.
 * Online: always serve the freshest files. Offline or slow: fall back
 * to the cached app shell so the app still opens instantly. */
const CACHE = 'timebridge-v8';
const NETWORK_TIMEOUT_MS = 3500;
const ASSETS = [
  './',
  './index.html',
  './styles.css',
  './tz.js',
  './zones.js',
  './app.js',
  './manifest.webmanifest',
  './icons/favicon.svg',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/maskable-512.png',
  './icons/apple-touch-icon.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE)
      // cache: 'reload' skips the browser's HTTP cache, so a new version
      // installs from fresh network copies (GitHub Pages caches for 10 min).
      .then((cache) => cache.addAll(ASSETS.map((u) => new Request(u, { cache: 'reload' }))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;
  // Leave cross-origin requests (e.g. analytics) to the browser.
  if (new URL(request.url).origin !== self.location.origin) return;
  event.respondWith(respond(event));
});

async function respond(event) {
  const { request } = event;
  const cache = await caches.open(CACHE);

  const network = fetch(request).then((res) => {
    if (res.ok) cache.put(request, res.clone()).catch(() => {});
    return res;
  });
  const guarded = network.catch(() => null);
  const timeout = new Promise((resolve) => setTimeout(resolve, NETWORK_TIMEOUT_MS));

  let res = await Promise.race([guarded, timeout]);
  if (res) return res;

  // Offline or slow: serve the cached copy now and let the network
  // request finish in the background so the cache stays fresh.
  event.waitUntil(guarded.then(() => undefined));
  const hit = await cache.match(request, { ignoreSearch: true });
  if (hit) return hit;

  // Nothing cached (first visit on a slow link): wait for the network after all.
  res = await guarded;
  if (res) return res;
  if (request.mode === 'navigate') {
    const shell = await cache.match('./index.html');
    if (shell) return shell;
  }
  return Response.error();
}
