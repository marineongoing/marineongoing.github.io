// Garde l'app en mémoire pour qu'elle s'ouvre même sans réseau.
const CACHE = "bts-ndrc-v1";
const SHELL = ["./", "index.html", "manifest.webmanifest", "icon-192.png", "icon-512.png", "apple-touch-icon.png"];
self.addEventListener("install", e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL))); self.skipWaiting(); });
self.addEventListener("activate", e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))); self.clients.claim(); });
self.addEventListener("fetch", e => {
  const u = new URL(e.request.url);
  if (e.request.method !== "GET" || u.hostname.endsWith("supabase.co")) return; // données et Claude : toujours en ligne
  e.respondWith(fetch(e.request).then(r => { if (r.ok && (u.origin === location.origin || /jsdelivr|gstatic|googleapis/.test(u.hostname))) { const c = r.clone(); caches.open(CACHE).then(k => k.put(e.request, c)); } return r; })
    .catch(() => caches.match(e.request).then(r => r || caches.match("index.html"))));
});
