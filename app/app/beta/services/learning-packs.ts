export type LearningPack = {
  id: string;
  titleZh: string;
  titleEn: string;
  descriptionZh: string;
  version: string;
  entryCount: number;
  bytes: number;
  sha256: string;
  urls: string[];
  license: string;
  attribution: string;
  filename: string;
};

type PackManifest = { schemaVersion: number; packs: LearningPack[] };
type PackPayload = { schemaVersion: number; id: string; version: string; entries: unknown[] };

const MANIFEST_URL = "/downloads/lexora-learning-packs-manifest.json";
const DB_NAME = "lexora-learning-packs";
const STORE = "packs";

function database() {
  return new Promise<IDBDatabase>((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, 1);
    request.onupgradeneeded = () => request.result.createObjectStore(STORE);
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error ?? new Error("无法打开本地词库"));
  });
}

async function withStore<T>(mode: IDBTransactionMode, run: (store: IDBObjectStore) => IDBRequest<T>) {
  const db = await database();
  try {
    return await new Promise<T>((resolve, reject) => {
      const transaction = db.transaction(STORE, mode);
      const request = run(transaction.objectStore(STORE));
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error ?? new Error("本地词库操作失败"));
    });
  } finally {
    db.close();
  }
}

export async function fetchLearningPackManifest(): Promise<LearningPack[]> {
  const response = await fetch(MANIFEST_URL, { cache: "no-store" });
  if (!response.ok) throw new Error("暂时无法读取预设词库列表");
  const manifest = await response.json() as PackManifest;
  if (manifest.schemaVersion !== 1 || !Array.isArray(manifest.packs)) throw new Error("预设词库清单格式无效");
  return manifest.packs;
}

async function digestHex(bytes: ArrayBuffer) {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function decodePack(bytes: ArrayBuffer): Promise<PackPayload> {
  const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream("gzip"));
  const json = await new Response(stream).json() as PackPayload;
  if (json.schemaVersion !== 1 || !Array.isArray(json.entries)) throw new Error("预设词库内容无效");
  return json;
}

export async function installLearningPack(pack: LearningPack, progress?: (value: number) => void) {
  const response = await fetch(pack.urls[0], { cache: "no-store" });
  if (!response.ok || !response.body) throw new Error("预设词库下载失败");
  const total = Number(response.headers.get("content-length")) || pack.bytes;
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let received = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    received += value.byteLength;
    progress?.(Math.min(1, received / Math.max(1, total)));
  }
  const bytes = new Uint8Array(received);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  if (received !== pack.bytes || await digestHex(bytes.buffer) !== pack.sha256) throw new Error("预设词库校验失败，请重试");
  const payload = await decodePack(bytes.buffer);
  if (payload.id !== pack.id || payload.entries.length !== pack.entryCount) throw new Error("预设词库与清单不一致");
  await withStore("readwrite", (store) => store.put(payload, pack.id));
  progress?.(1);
  return payload;
}

export async function loadLearningPack(id: string) {
  return await withStore<PackPayload | undefined>("readonly", (store) => store.get(id));
}

export async function removeLearningPack(id: string) {
  await withStore("readwrite", (store) => store.delete(id));
}

export async function clearLearningPacks() {
  await withStore("readwrite", (store) => store.clear());
}
