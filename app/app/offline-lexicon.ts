import { deleteOfflineLexicon, readOfflineLexicon, saveOfflineLexicon } from "./storage";
import type { DictionaryEntry } from "./types";

let activeEdition: string | null = null;
type SqlJsInitializer = (options: { locateFile(): string }) => Promise<{
  Database: new (data: Uint8Array) => NonNullable<typeof activeDatabase>;
}>;

let activeDatabase: {
  exec(
    sql: string,
    params?: unknown[],
  ): {
    columns: string[];
    values: unknown[][];
  }[];
} | null = null;

let sqlJsLoader: Promise<SqlJsInitializer> | null = null;

function loadSqlJs(): Promise<SqlJsInitializer> {
  const runtimeWindow = window as typeof window & {
    initSqlJs?: SqlJsInitializer;
  };
  if (runtimeWindow.initSqlJs) return Promise.resolve(runtimeWindow.initSqlJs);
  if (sqlJsLoader) return sqlJsLoader;
  sqlJsLoader = new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = "/sql-wasm.js";
    script.async = true;
    script.onload = () => {
      if (runtimeWindow.initSqlJs) resolve(runtimeWindow.initSqlJs);
      else reject(new Error("离线词库运行组件加载失败"));
    };
    script.onerror = () => reject(new Error("离线词库运行组件加载失败"));
    document.head.appendChild(script);
  });
  return sqlJsLoader;
}

export async function downloadOfflineLexicon(
  edition: "top20k" | "full",
  onProgress: (value: number) => void,
) {
  const filename =
    edition === "top20k"
      ? "lexora-open-oxford-frequency-20k.sqlite.gz"
      : "lexora-open-oxford-scope.sqlite.gz";
  const response = await fetch(
    `https://dict.12323456.xyz/v1/offline/download/${filename}`,
  );
  if (!response.ok || !response.body) throw new Error("离线词库下载失败");
  const total = Number(response.headers.get("content-length") || 0);
  let loaded = 0;
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    loaded += value.length;
    if (total) onProgress(Math.min(95, (loaded / total) * 95));
  }
  const compressed = new Blob(chunks as BlobPart[])
    .stream()
    .pipeThrough(new DecompressionStream("gzip"));
  const data = await new Response(compressed).arrayBuffer();
  await saveOfflineLexicon(edition, data);
  activeEdition = null;
  activeDatabase = null;
  onProgress(100);
}

export async function clearOfflineLexiconCache() {
  await Promise.all([
    deleteOfflineLexicon("top20k"),
    deleteOfflineLexicon("full"),
  ]);
  localStorage.removeItem("lexora-offline-edition");
  activeEdition = null;
  activeDatabase = null;
}

async function database(edition: string) {
  if (activeEdition === edition && activeDatabase) return activeDatabase;
  const data = await readOfflineLexicon(edition);
  if (!data) return null;
  const initSqlJs = await loadSqlJs();
  const SQL = await initSqlJs({ locateFile: () => "/sql-wasm.wasm" });
  activeDatabase = new SQL.Database(new Uint8Array(data));
  activeEdition = edition;
  return activeDatabase;
}

export async function offlineLookup(
  term: string,
): Promise<DictionaryEntry | null> {
  const edition = localStorage.getItem("lexora-offline-edition");
  if (!edition) return null;
  const db = await database(edition);
  if (!db) return null;
  const result = db.exec(
    "SELECT * FROM entries WHERE normalized_word = ? LIMIT 1",
    [term.trim().toLowerCase()],
  );
  if (!result.length || !result[0].values.length) return null;
  const row = Object.fromEntries(
    result[0].columns.map((column, index) => [
      column,
      result[0].values[0][index],
    ]),
  ) as Record<string, unknown>;
  for (const field of [
    "synonyms_json",
    "antonyms_json",
    "examples_json",
    "phrases_json",
    "phrase_entries_json",
    "related_words_json",
    "related_entries_json",
    "senses_json",
  ]) {
    if (typeof row[field] === "string") {
      try {
        row[field.replace(/_json$/, "")] = JSON.parse(row[field] as string);
      } catch {
        row[field.replace(/_json$/, "")] = [];
      }
    }
  }
  return row as DictionaryEntry;
}
