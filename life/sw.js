// Garde l'app en mémoire pour qu'elle s'ouvre même sans réseau,
// tout en allant chercher la dernière version dès qu'il y a du réseau.
const CACHE = "mon-quotidien-v41";
const SHELL = ["./", "index.html", "manifest.webmanifest", "icon-192.png", "icon-512.png", "apple-touch-icon.png"];
self.addEventListener("install", e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL.map(u => new Request(u, { cache: "reload" }))))); self.skipWaiting(); });
self.addEventListener("activate", e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k.startsWith("mon-quotidien") && k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener("fetch", e => {
  const u = new URL(e.request.url);
  if (e.request.method !== "GET" || u.hostname.endsWith("supabase.co")) return;
  const own = u.origin === location.origin;
  const req = own ? new Request(e.request, { cache: "no-store" }) : e.request;
  e.respondWith(fetch(req).then(r => { if (r.ok && (own || /jsdelivr|gstatic|googleapis/.test(u.hostname))) { const c = r.clone(); caches.open(CACHE).then(k => k.put(e.request, c)); } return r; })
    .catch(() => caches.match(e.request).then(r => r || caches.match("index.html"))));
});
