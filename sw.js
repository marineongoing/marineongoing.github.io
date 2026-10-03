// Ancienne version : se désinstalle toute seule pour laisser la place à la nouvelle
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", e => e.waitUntil((async () => {
  const ks = await caches.keys(); await Promise.all(ks.filter(k => k.startsWith("bts-ndrc")).map(k => caches.delete(k)));
  await self.registration.unregister();
  (await self.clients.matchAll({ type: "window" })).forEach(c => c.navigate(c.url));
})()));
