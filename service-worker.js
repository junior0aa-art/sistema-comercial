// ============================================================
// service-worker.js
// Cache de arquivos estáticos com atualização segura e fallback offline
// ============================================================

const CACHE_NAME = 'sistema-comercial-v2';
const CACHE_URLS = [
  './',
  './index.html',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2',
  'https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@latest/tabler-icons.min.css',
  'https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@latest/fonts/tabler-icons.woff2',
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache =>
      Promise.allSettled(CACHE_URLS.map(url => cache.add(url).catch(e => console.warn('[SW] Não cacheou:', url, e.message))))
    ).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys => Promise.all(
      keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))
    )).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);

  // Requisições ao Supabase: sempre tenta a rede, sem cache.
  if (url.hostname.includes('supabase.co')) {
    event.respondWith(fetch(event.request).catch(() => new Response(
      JSON.stringify({ error: { message: 'Failed to fetch — offline' }, data: null }),
      { status: 503, headers: { 'Content-Type': 'application/json' } }
    )));
    return;
  }

  // HTML/navegação: busca a versão mais nova primeiro e usa cache somente offline.
  if (event.request.mode === 'navigate' || url.pathname.endsWith('.html') || url.pathname === '/') {
    event.respondWith(
      fetch(event.request).then(response => {
        if (response.ok) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put('./index.html', clone));
        }
        return response;
      }).catch(() => caches.match('./index.html'))
    );
    return;
  }

  // Bibliotecas e fontes: cache first, pois mudam com menos frequência.
  event.respondWith(
    caches.match(event.request).then(cached => cached || fetch(event.request).then(response => {
      if (response.ok && url.hostname.includes('jsdelivr')) {
        const clone = response.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
      }
      return response;
    }))
  );
});

self.addEventListener('message', event => {
  if (event.data === 'skipWaiting') self.skipWaiting();
});
