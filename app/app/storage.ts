import type {
  AppSettings,
  GeneratedBook,
  GeneratedWordRecord,
  SearchRecord,
  WordItem,
} from "./types";

const DB_NAME = "lexora-web-files";
const STORE_NAME = "generated-files";
const LEXICON_STORE = "offline-lexicons";
export const STATE_KEY = "lexora-web-state-v2";

export type SavedState = {
  words: WordItem[];
  settings: AppSettings;
  records: GeneratedBook[];
  searches: SearchRecord[];
  generatedWords: GeneratedWordRecord[];
  onboardingDone: boolean;
};

export function saveState(value: SavedState) {
  localStorage.setItem(STATE_KEY, JSON.stringify(value));
}

export function loadState(): Partial<SavedState> | null {
  try {
    return JSON.parse(
      localStorage.getItem(STATE_KEY) || "null",
    ) as Partial<SavedState> | null;
  } catch {
    return null;
  }
}

function openDatabase(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, 2);
    request.onupgradeneeded = () => {
      if (!request.result.objectStoreNames.contains(STORE_NAME))
        request.result.createObjectStore(STORE_NAME);
      if (!request.result.objectStoreNames.contains(LEXICON_STORE))
        request.result.createObjectStore(LEXICON_STORE);
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

export async function saveGeneratedFile(id: string, blob: Blob) {
  const db = await openDatabase();
  await new Promise<void>((resolve, reject) => {
    const transaction = db.transaction(STORE_NAME, "readwrite");
    transaction.objectStore(STORE_NAME).put(blob, id);
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error);
  });
  db.close();
}

export async function readGeneratedFile(id: string): Promise<Blob | null> {
  const db = await openDatabase();
  const value = await new Promise<Blob | undefined>((resolve, reject) => {
    const request = db.transaction(STORE_NAME).objectStore(STORE_NAME).get(id);
    request.onsuccess = () => resolve(request.result as Blob | undefined);
    request.onerror = () => reject(request.error);
  });
  db.close();
  return value ?? null;
}

export async function deleteGeneratedFile(id: string) {
  const db = await openDatabase();
  await new Promise<void>((resolve, reject) => {
    const transaction = db.transaction(STORE_NAME, "readwrite");
    transaction.objectStore(STORE_NAME).delete(id);
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error);
  });
  db.close();
}

export async function saveOfflineLexicon(edition: string, data: ArrayBuffer) {
  const db = await openDatabase();
  await new Promise<void>((resolve, reject) => {
    const transaction = db.transaction(LEXICON_STORE, "readwrite");
    transaction.objectStore(LEXICON_STORE).put(data, edition);
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error);
  });
  db.close();
}

export async function readOfflineLexicon(edition: string) {
  const db = await openDatabase();
  const result = await new Promise<ArrayBuffer | undefined>(
    (resolve, reject) => {
      const request = db
        .transaction(LEXICON_STORE)
        .objectStore(LEXICON_STORE)
        .get(edition);
      request.onsuccess = () =>
        resolve(request.result as ArrayBuffer | undefined);
      request.onerror = () => reject(request.error);
    },
  );
  db.close();
  return result ?? null;
}

export async function deleteOfflineLexicon(edition: string) {
  const db = await openDatabase();
  await new Promise<void>((resolve, reject) => {
    const transaction = db.transaction(LEXICON_STORE, "readwrite");
    transaction.objectStore(LEXICON_STORE).delete(edition);
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error);
  });
  db.close();
}

