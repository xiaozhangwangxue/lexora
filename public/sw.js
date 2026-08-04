const CACHE = "lexora-web-v5-beta";
const SHELL = ["/app", "/app/beta", "/manifest.webmanifest", "/beta-manifest.webmanifest", "/favicon.png", "/lexora-icon-192.png", "/lexora-icon-512.png", "/lexora-apple-touch-icon-180.png"];
self.addEventListener("install", (event) => event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(SHELL)).then(() => self.skipWaiting())));
self.addEventListener("activate", (event) => event.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key)))).then(() => self.clients.claim())));
self.addEventListener("fetch", (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (
    request.method !== "GET" ||
    url.origin !== self.location.origin ||
    url.pathname.startsWith("/api/") ||
    url.pathname === "/.rsc"
  ) return;
  event.respondWith(fetch(request).then((response) => {
    if (response.ok) caches.open(CACHE).then((cache) => cache.put(request, response.clone()));
    return response;
  }).catch(() => caches.match(request).then((cached) => {
    if (cached) return cached;
    if (request.mode === "navigate") return caches.match("/app");
    return Response.error();
  })));
});
