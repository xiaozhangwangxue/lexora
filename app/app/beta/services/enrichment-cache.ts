const DB_NAME = "lexora-beta-enrichment";
const STORE = "entries";

type CachedEntry = {
  term: string;
  entry: unknown;
  cachedAt: string;
};

function openCache() {
  return new Promise<IDBDatabase>((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, 1);
    request.onupgradeneeded = () => request.result.createObjectStore(STORE, { keyPath: "term" });
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error ?? new Error("无法打开补全缓存"));
  });
}

async function transaction<T>(mode: IDBTransactionMode, run: (store: IDBObjectStore) => IDBRequest<T>) {
  const db = await openCache();
  try {
    return await new Promise<T>((resolve, reject) => {
      const request = run(db.transaction(STORE, mode).objectStore(STORE));
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error ?? new Error("补全缓存操作失败"));
    });
  } finally {
    db.close();
  }
}

export async function readEnrichmentCache(term: string) {
  const normalized = term.trim().toLowerCase().replace(/\s+/g, " ");
  const cached = await transaction<CachedEntry | undefined>("readonly", (store) => store.get(normalized));
  return cached?.entry ?? null;
}

export async function writeEnrichmentCache(term: string, entry: unknown) {
  const normalized = term.trim().toLowerCase().replace(/\s+/g, " ");
  await transaction("readwrite", (store) => store.put({ term: normalized, entry, cachedAt: new Date().toISOString() } satisfies CachedEntry));
}

export async function enrichmentCacheCount() {
  return await transaction<number>("readonly", (store) => store.count());
}

export async function enrichmentCacheUsage() {
  const entries = await transaction<CachedEntry[]>("readonly", (store) => store.getAll());
  const encoder = new TextEncoder();
  return {
    entries: entries.length,
    bytes: entries.reduce((total, entry) => total + encoder.encode(JSON.stringify(entry)).byteLength, 0),
  };
}

export async function clearEnrichmentCache() {
  await transaction("readwrite", (store) => store.clear());
}
