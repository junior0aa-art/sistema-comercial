// ============================================================
// service-worker.js
// Cache de arquivos estáticos para funcionamento offline total
// ============================================================

const CACHE_NAME = 'sistema-comercial-v1';
const CACHE_URLS = [
  './',
  './index.html',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2',
  'https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@latest/tabler-icons.min.css',
  'https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@latest/fonts/tabler-icons.woff2',
];

// ── Instalação: pré-cacheia os recursos estáticos ─────────────
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => {
      console.log('[SW] Cacheando recursos estáticos...');
      return Promise.allSettled(
        CACHE_URLS.map(url =>
          cache.add(url).catch(e => console.warn('[SW] Não cacheou:', url, e.message))
        )
      );
    }).then(() => self.skipWaiting())
  );
});

// ── Ativação: remove caches antigos ──────────────────────────
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys
          .filter(k => k !== CACHE_NAME)
          .map(k => { console.log('[SW] Removendo cache antigo:', k); return caches.delete(k); })
      )
    ).then(() => self.clients.claim())
  );
});

// ── Fetch: estratégia Network First com fallback para cache ───
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);

  // Requisições ao Supabase: sempre tenta a rede, sem cache
  if (url.hostname.includes('supabase.co')) {
    event.respondWith(
      fetch(event.request).catch(() => {
        // Offline: retorna erro limpo para o app tratar
        return new Response(
          JSON.stringify({ error: { message: 'Failed to fetch — offline' }, data: null }),
          { status: 503, headers: { 'Content-Type': 'application/json' } }
        );
      })
    );
    return;
  }

  // Outros recursos (CDN, index.html): Cache First, depois rede
  event.respondWith(
    caches.match(event.request).then(cached => {
      if (cached) return cached;
      return fetch(event.request).then(response => {
        // Cacheia respostas bem-sucedidas de CDN
        if (response.ok && (url.hostname.includes('jsdelivr') || url.pathname.endsWith('.html'))) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
        }
        return response;
      }).catch(() => {
        // Fallback final: retorna index.html do cache para navegação
        if (event.request.mode === 'navigate') {
          return caches.match('./index.html');
        }
        return new Response('Offline', { status: 503 });
      });
    })
  );
});

// ── Mensagem para forçar atualização do cache ─────────────────
self.addEventListener('message', event => {
  if (event.data === 'skipWaiting') self.skipWaiting();
});
