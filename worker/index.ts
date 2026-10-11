/** Cloudflare Worker entry point for the vinext-starter template. */
import {
  handleImageOptimization,
  DEFAULT_DEVICE_SIZES,
  DEFAULT_IMAGE_SIZES,
} from "vinext/server/image-optimization";
import handler from "vinext/server/app-router-entry";

interface Env {
  ASSETS: Fetcher;
  DOWNLOADS?: R2Bucket;
  DOWNLOAD_UPLOAD_TOKEN?: string;
  DB: D1Database;
  WEB_ORIGIN?: string;
  WEB_ORIGIN_SECONDARY?: string;
  WEB_ORIGIN_TOKEN?: string;
  WEB_IDENTITY_SALT?: string;
  IMAGES: {
    input(stream: ReadableStream): {
      transform(options: Record<string, unknown>): {
        output(options: {
          format: string;
          quality: number;
        }): Promise<{ response(): Response }>;
      };
    };
  };
}

interface ExecutionContext {
  waitUntil(promise: Promise<unknown>): void;
  passThroughOnException(): void;
}

type EdgeDictionaryValue = [string, string, string, string, string, string];
type EdgeDictionaryManifest = {
  pack: string;
  shards: Record<string, { offset: number; length: number; rows: number }>;
};

let edgeDictionaryManifestPromise:
  | Promise<EdgeDictionaryManifest | null>
  | undefined;

const WEB_LOOKUP_DAILY_LIMIT = 10000;
const WEB_PDF_DAILY_LIMIT = 250;
const WEB_LOOKUP_MINUTE_LIMIT = 300;
const WEB_PDF_MINUTE_LIMIT = 8;
const WEB_MAX_BODY_BYTES = 2 * 1024 * 1024;

function defaultCache(): Cache {
  return (caches as CacheStorage & { readonly default: Cache }).default;
}

function edgeDictionaryPrefix(term: string): string {
  const second = /^[a-z]$/.test(term[1] ?? "") ? term[1] : "_";
  return `${term[0]}${second}`;
}

async function edgeDictionaryManifest(
  env: Env,
): Promise<EdgeDictionaryManifest | null> {
  if (!env.DOWNLOADS) return null;
  edgeDictionaryManifestPromise ??= (async () => {
    try {
      const object = await env.DOWNLOADS?.get(
        "dictionary-edge/v1/manifest.json",
      );
      if (!object) {
        console.error("edge dictionary manifest object is missing");
        return null;
      }
      const value = (await object.json()) as EdgeDictionaryManifest;
      if (!value?.pack || !value?.shards) {
        console.error("edge dictionary manifest is invalid");
        return null;
      }
      return value;
    } catch (error) {
      console.error("edge dictionary manifest failed", error);
      return null;
    }
  })();
  return edgeDictionaryManifestPromise;
}

async function lookupEdgeDictionary(
  env: Env,
  terms: string[],
): Promise<Map<string, EdgeDictionaryValue>> {
  const manifest = await edgeDictionaryManifest(env);
  if (!manifest || !env.DOWNLOADS) return new Map();
  const grouped = new Map<string, string[]>();
  for (const term of terms) {
    const prefix = edgeDictionaryPrefix(term);
    grouped.set(prefix, [...(grouped.get(prefix) ?? []), term]);
  }
  const found = new Map<string, EdgeDictionaryValue>();
  await Promise.all(
    [...grouped.entries()].map(async ([prefix, requested]) => {
      const shard = manifest.shards[prefix];
      if (!shard) {
        console.error("edge dictionary shard is absent", prefix);
        return;
      }
      try {
        const object = await env.DOWNLOADS?.get(
          `dictionary-edge/v1/${manifest.pack}`,
          { range: { offset: shard.offset, length: shard.length } },
        );
        if (!object?.body) return;
        const body = object.body.pipeThrough(new DecompressionStream("gzip"));
        const values = (await new Response(body).json()) as Record<
          string,
          EdgeDictionaryValue
        >;
        for (const term of requested) {
          if (Array.isArray(values[term])) found.set(term, values[term]);
        }
      } catch (error) {
        console.error("edge dictionary shard failed", prefix, error);
        // Public lookups remain available if an edge shard is unavailable.
      }
    }),
  );
  return found;
}

function localExactRow(term: string, value: EdgeDictionaryValue) {
  const [phonetic, definition, , position, , frequencyRank] = value;
  const definitionOverrides: Record<string, { part: string; text: string }> = {
    "people-to-people": {
      part: "adjective",
      text: "Involving direct contact and communication between ordinary people of different countries or cultures.",
    },
  };
  const override = definitionOverrides[term];
  const part =
    position.split(/[\s,;/]+/).find(Boolean) ?? override?.part ?? "";
  const definitions = (definition || override?.text || "")
    .split(/\n+/)
    .map((item) => item.trim())
    .filter(Boolean)
    .slice(0, 5)
    .map((item) => `${part || "definition"}\t${item}`);
  const tags = [
    part,
    phonetic ? `ipa_pron:${phonetic.replace(/^\/+|\/+$/g, "")}` : "",
    frequencyRank ? `lexora_rank:${frequencyRank}` : "",
  ].filter(Boolean);
  return { word: term, tags, defs: definitions };
}

function translatedTextFromGoogle(body: unknown): string {
  if (!Array.isArray(body) || !Array.isArray(body[0])) return "";
  return (body[0] as unknown[])
    .map((chunk) =>
      Array.isArray(chunk) ? String(chunk[0] ?? "") : "",
    )
    .join("")
    .trim();
}

async function translateEnglishToChinese(
  text: string,
  allowFallbackProvider = false,
): Promise<string> {
  if (!text.trim()) return "";
  const form = new URLSearchParams({
    client: "gtx",
    sl: "en",
    tl: "zh-CN",
    dt: "t",
    q: text.trim(),
  }).toString();
  try {
    const response = await fetch(
      "https://translate.google.com/translate_a/single",
      {
        method: "POST",
        headers: {
          accept: "application/json",
          "content-type": "application/x-www-form-urlencoded;charset=UTF-8",
          "user-agent": "Mozilla/5.0 Lexora/4",
        },
        body: form,
        signal: AbortSignal.timeout(4800),
      },
    );
    if (response.ok) {
      const translated = translatedTextFromGoogle(await response.json());
      if (translated) return translated;
    }
  } catch {
    // Fall through to the secondary provider when the subrequest budget
    // permits it. The client itself never contacts either public provider.
  }
  if (allowFallbackProvider) {
    try {
      const endpoint = new URL("https://api.mymemory.translated.net/get");
      endpoint.search = new URLSearchParams({
        q: text.trim(),
        langpair: "en|zh-CN",
      }).toString();
      const response = await fetch(endpoint, {
        headers: {
          accept: "application/json",
          "user-agent": "Mozilla/5.0 Lexora/4",
        },
        signal: AbortSignal.timeout(4800),
      });
      if (response.ok) {
        const body = (await response.json()) as {
          responseStatus?: number;
          responseData?: { translatedText?: string };
        };
        const translated = String(
          body.responseData?.translatedText ?? "",
        ).trim();
        if (
          Number(body.responseStatus ?? 200) === 200 &&
          translated &&
          !/MYMEMORY WARNING/i.test(translated)
        ) {
          return translated;
        }
      }
    } catch {
      // English results remain available even if translation is unavailable.
    }
  }
  return "";
}

async function sha256(value: string) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function webIdentity(request: Request, env: Env) {
  const device = request.headers.get("x-lexora-device") ?? "";
  if (!/^[a-f0-9-]{20,80}$/i.test(device))
    throw new Response("Invalid device identity", { status: 400 });
  const ip = request.headers.get("cf-connecting-ip") ?? "unknown";
  return sha256(`${env.WEB_IDENTITY_SALT ?? "lexora-web"}|${ip}|${device}`);
}

async function ensureWebUsageTable(env: Env) {
  await env.DB.prepare(
    "CREATE TABLE IF NOT EXISTS web_usage (bucket TEXT NOT NULL, client_hash TEXT NOT NULL, kind TEXT NOT NULL, count INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL, PRIMARY KEY(bucket,client_hash,kind))",
  ).run();
}

async function usageCount(
  env: Env,
  identity: string,
  kind: string,
  bucket: string,
) {
  const row = await env.DB.prepare(
    "SELECT count FROM web_usage WHERE bucket=? AND client_hash=? AND kind=?",
  )
    .bind(bucket, identity, kind)
    .first<{ count: number }>();
  return Number(row?.count ?? 0);
}

async function consumeUsage(
  env: Env,
  identity: string,
  kind: string,
  bucket: string,
  limit: number,
) {
  const timestamp = Math.floor(Date.now() / 1000);
  const row = await env.DB.prepare(
    "INSERT INTO web_usage(bucket,client_hash,kind,count,updated_at) VALUES(?,?,?,?,?) ON CONFLICT(bucket,client_hash,kind) DO UPDATE SET count=count+1,updated_at=excluded.updated_at WHERE count < ? RETURNING count",
  )
    .bind(bucket, identity, kind, 1, timestamp, limit)
    .first<{ count: number }>();
  if (!row) throw new Response("Quota exceeded", { status: 429 });
  return Number(row.count);
}

async function checkAndConsumeWebQuota(
  env: Env,
  identity: string,
  kind: "lookup" | "pdf",
  consume: boolean,
) {
  await ensureWebUsageTable(env);
  const now = new Date();
  const day = now.toISOString().slice(0, 10);
  const minute = now.toISOString().slice(0, 16);
  const dailyLimit =
    kind === "pdf" ? WEB_PDF_DAILY_LIMIT : WEB_LOOKUP_DAILY_LIMIT;
  const minuteLimit =
    kind === "pdf" ? WEB_PDF_MINUTE_LIMIT : WEB_LOOKUP_MINUTE_LIMIT;
  const [daily, burst] = await Promise.all([
    usageCount(env, identity, kind, `day:${day}`),
    usageCount(env, identity, kind, `minute:${minute}`),
  ]);
  if (!consume) return Math.max(0, dailyLimit - daily);
  if (burst >= minuteLimit)
    throw new Response("Too many requests; retry in a minute", {
      status: 429,
      headers: { "retry-after": "60" },
    });
  const nextDaily = await consumeUsage(
    env,
    identity,
    kind,
    `day:${day}`,
    dailyLimit,
  ).catch(() => {
    throw new Response("Daily quota exceeded", { status: 429 });
  });
  await consumeUsage(
    env,
    identity,
    kind,
    `minute:${minute}`,
    minuteLimit,
  ).catch(() => {
    throw new Response("Too many requests; retry in a minute", {
      status: 429,
      headers: { "retry-after": "60" },
    });
  });
  return Math.max(0, dailyLimit - nextDaily);
}

async function handleWebApi(request: Request, env: Env, url: URL) {
  if (!env?.WEB_ORIGIN || !env.DB)
    return Response.json(
      { detail: "Web service is not configured" },
      { status: 503 },
    );
  let identity: string;
  try {
    identity = await webIdentity(request, env);
  } catch (error) {
    return error instanceof Response
      ? error
      : new Response("Invalid request", { status: 400 });
  }
  if (url.pathname === "/api/web/quota" && request.method === "GET") {
    const [lookupsRemaining, pdfsRemaining] = await Promise.all([
      checkAndConsumeWebQuota(env, identity, "lookup", false),
      checkAndConsumeWebQuota(env, identity, "pdf", false),
    ]);
    return Response.json(
      { lookupsRemaining, pdfsRemaining },
      { headers: { "cache-control": "no-store" } },
    );
  }
  const isLookup =
    url.pathname === "/api/web/lookup" && request.method === "GET";
  const isSuggest =
    url.pathname === "/api/web/suggest" && request.method === "GET";
  const isImport =
    url.pathname === "/api/web/import" && request.method === "POST";
  const isGenerate =
    url.pathname === "/api/web/generate" && request.method === "POST";
  if (!isLookup && !isSuggest && !isImport && !isGenerate)
    return new Response("Not found", { status: 404 });
  if (isGenerate || isImport) {
    const length = Number(request.headers.get("content-length") ?? 0);
    const maximum = isImport ? 10 * 1024 * 1024 : WEB_MAX_BODY_BYTES;
    if (length > maximum)
      return Response.json(
        {
          detail: isImport
            ? "Import file is larger than 10 MB"
            : "Vocabulary book request is too large for one upload",
        },
        { status: 413 },
      );
  }
  let remaining: number;
  try {
    remaining = isImport
      ? await checkAndConsumeWebQuota(env, identity, "lookup", false)
      : await checkAndConsumeWebQuota(
          env,
          identity,
          isGenerate ? "pdf" : "lookup",
          true,
        );
  } catch (error) {
    return error instanceof Response
      ? error
      : Response.json({ detail: "Quota service unavailable" }, { status: 503 });
  }
  const headers = new Headers({
    accept: isGenerate
      ? "application/octet-stream, application/json"
      : "application/json",
    "x-lexora-client-hash": identity,
  });
  if (env.WEB_ORIGIN_TOKEN)
    headers.set("x-lexora-origin-token", env.WEB_ORIGIN_TOKEN);
  if (isGenerate) headers.set("content-type", "application/json");
  if (isImport)
    headers.set(
      "content-type",
      request.headers.get("content-type") ?? "application/octet-stream",
    );
  const body = isGenerate || isImport ? await request.arrayBuffer() : undefined;
  const origins = [env.WEB_ORIGIN, env.WEB_ORIGIN_SECONDARY].filter(
    Boolean,
  ) as string[];
  for (const origin of origins) {
    const upstreamPath = isGenerate
      ? "/v1/web/generate"
      : isImport
        ? "/v1/web/import"
        : isSuggest
          ? "/v1/suggest"
          : // The public lookup endpoint is already protected by the website's
            // D1 quota above. It can be cached and raced across both free OCI
            // origins, unlike the origin's per-client web endpoint.
            "/v1/lookup";
    const target = new URL(upstreamPath, origin);
    if (isLookup || isSuggest) target.search = url.search;
    try {
      const upstream = await fetch(target, {
        method: request.method,
        headers,
        body,
        signal: AbortSignal.timeout(
          isGenerate ? 120000 : isImport ? 30000 : 10000,
        ),
      });
      if (upstream.status >= 500 && origin !== origins.at(-1)) continue;
      const responseHeaders = new Headers(upstream.headers);
      responseHeaders.set("x-lexora-daily-remaining", String(remaining));
      responseHeaders.set("cache-control", "no-store");
      responseHeaders.set("x-content-type-options", "nosniff");
      responseHeaders.delete("server");
      return new Response(upstream.body, {
        status: upstream.status,
        headers: responseHeaders,
      });
    } catch {
      // Retry the second Always Free Oracle origin.
    }
  }
  return Response.json(
    { detail: "Lexora cloud service is temporarily unavailable" },
    { status: 503, headers: { "retry-after": "15" } },
  );
}

// Image security config. SVG sources with .svg extension auto-skip the
// optimization endpoint on the client side (served directly, no proxy).
// To route SVGs through the optimizer (with security headers), set
// dangerouslyAllowSVG: true in next.config.js and uncomment below:
// const imageConfig: ImageConfig = { dangerouslyAllowSVG: true };

const worker = {
  async fetch(
    request: Request,
    env: Env,
    ctx: ExecutionContext,
  ): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname.startsWith("/api/web/")) {
      return handleWebApi(request, env, url);
    }

    const r2Response = async (key: string, contentDisposition = true) => {
      const object = await env.DOWNLOADS?.get(key);
      if (!object) return null;
      const headers = new Headers();
      object.writeHttpMetadata(headers);
      headers.set("etag", object.httpEtag);
      if (contentDisposition) {
        headers.set("content-disposition", `attachment; filename="${key}"`);
      } else {
        headers.delete("content-disposition");
      }
      const isManifest =
        key === "version.json" ||
        key === "beta-version.json" ||
        key.endsWith("manifest.json");
      if (isManifest) {
        // Existing clients rely on the response charset when decoding Chinese
        // release notes. R2's default application/octet-stream would make the
        // Dart HTTP client decode them as Latin-1.
        headers.set("content-type", "application/json; charset=utf-8");
      }
      headers.set(
        "cache-control",
        isManifest
          ? "no-store, max-age=0"
          : /-v\d+\.\d+\.\d+(?:[-.])/.test(key)
            ? "public, max-age=31536000, immutable"
            : "no-cache",
      );
      return new Response(object.body, { headers });
    };

    if (
      url.pathname.startsWith("/api/admin/downloads-multipart/") &&
      (request.method === "POST" ||
        request.method === "PUT" ||
        request.method === "DELETE")
    ) {
      const token =
        request.headers.get("x-lexora-upload-token") ??
        request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
      if (!env.DOWNLOAD_UPLOAD_TOKEN || token !== env.DOWNLOAD_UPLOAD_TOKEN) {
        return new Response("Unauthorized", { status: 401 });
      }
      if (!env.DOWNLOADS) {
        return new Response("Download storage is unavailable", { status: 503 });
      }
      const key = decodeURIComponent(
        url.pathname.slice("/api/admin/downloads-multipart/".length),
      );
      if (!key || key.includes("/") || key.includes("..")) {
        return new Response("Invalid upload", { status: 400 });
      }

      const uploadId = url.searchParams.get("uploadId");
      if (!uploadId) {
        if (request.method !== "POST") {
          return new Response("Missing uploadId", { status: 400 });
        }
        const upload = await env.DOWNLOADS.createMultipartUpload(key, {
          httpMetadata: {
            contentType:
              request.headers.get("content-type") ?? "application/octet-stream",
            contentDisposition: `attachment; filename="${key}"`,
          },
        });
        return Response.json({ key: upload.key, uploadId: upload.uploadId });
      }

      const upload = env.DOWNLOADS.resumeMultipartUpload(key, uploadId);
      if (request.method === "DELETE") {
        await upload.abort();
        return Response.json({ ok: true, aborted: key });
      }
      if (request.method === "PUT") {
        const partNumber = Number(url.searchParams.get("partNumber"));
        if (
          !Number.isInteger(partNumber) ||
          partNumber < 1 ||
          partNumber > 10000 ||
          !request.body
        ) {
          return new Response("Invalid multipart part", { status: 400 });
        }
        const part = await upload.uploadPart(partNumber, request.body);
        return Response.json({ partNumber: part.partNumber, etag: part.etag });
      }

      const payload = await request.json<{ parts?: R2UploadedPart[] }>();
      if (!Array.isArray(payload.parts) || payload.parts.length === 0) {
        return new Response("Multipart parts are required", { status: 400 });
      }
      const completed = await upload.complete(payload.parts);
      return Response.json({ ok: true, key: completed.key });
    }

    if (
      url.pathname.startsWith("/api/admin/downloads/") &&
      (request.method === "PUT" || request.method === "DELETE")
    ) {
      // A dedicated header avoids Cloudflare Access interpreting a normal
      // Authorization bearer token before the request reaches this Worker.
      const token =
        request.headers.get("x-lexora-upload-token") ??
        request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
      if (!env.DOWNLOAD_UPLOAD_TOKEN || token !== env.DOWNLOAD_UPLOAD_TOKEN) {
        return new Response("Unauthorized", { status: 401 });
      }
      if (!env.DOWNLOADS)
        return new Response("Download storage is unavailable", { status: 503 });
      const key = decodeURIComponent(
        url.pathname.slice("/api/admin/downloads/".length),
      );
      if (!key || key.includes("/") || key.includes("..")) {
        return new Response("Invalid upload", { status: 400 });
      }
      if (request.method === "DELETE") {
        if (!key.startsWith("lexora-")) {
          return new Response("Only Lexora objects may be removed", {
            status: 400,
          });
        }
        await env.DOWNLOADS.delete(key);
        return Response.json({ ok: true, deleted: key });
      }
      if (!request.body) return new Response("Invalid upload", { status: 400 });
      await env.DOWNLOADS.put(key, request.body, {
        httpMetadata: {
          contentType:
            request.headers.get("content-type") ?? "application/octet-stream",
          contentDisposition: `attachment; filename="${key}"`,
        },
      });
      return Response.json({ ok: true, key });
    }

    if (url.pathname === "/api/admin/downloads" && request.method === "GET") {
      const token = request.headers.get("x-lexora-upload-token");
      if (!env.DOWNLOAD_UPLOAD_TOKEN || token !== env.DOWNLOAD_UPLOAD_TOKEN) {
        return new Response("Unauthorized", { status: 401 });
      }
      if (!env.DOWNLOADS) {
        return new Response("Download storage is unavailable", { status: 503 });
      }
      const listed = await env.DOWNLOADS.list({
        prefix: "lexora-",
        cursor: url.searchParams.get("cursor") ?? undefined,
        limit: 1000,
      });
      return Response.json({
        keys: listed.objects.map((object) => object.key),
        truncated: listed.truncated,
        cursor: listed.truncated ? listed.cursor : null,
      });
    }

    if (url.pathname === "/version.json") {
      const manifest = await r2Response("version.json", false);
      if (manifest) return manifest;
    }

    if (url.pathname === "/beta-version.json") {
      const manifest = await r2Response("beta-version.json", false);
      if (manifest) return manifest;
    }

    if (url.pathname.startsWith("/updates/")) {
      const key = decodeURIComponent(url.pathname.slice("/updates/".length));
      if (!key || key.includes("/") || key.includes("..")) {
        return new Response("Invalid update name", { status: 400 });
      }
      const object = await r2Response(key);
      return (
        object ?? new Response("Update mirror is not ready", { status: 503 })
      );
    }

    if (url.pathname.startsWith("/downloads/")) {
      const key = decodeURIComponent(url.pathname.slice("/downloads/".length));
      if (!key || key.includes("/") || key.includes("..")) {
        return new Response("Invalid download name", { status: 400 });
      }
      const object = await r2Response(key);
      if (object) return object;
      return Response.redirect(
        `https://github.com/xiaozhangwangxue/lexora/releases/latest/download/${encodeURIComponent(key)}`,
        302,
      );
    }

    if (url.pathname === "/api/dictionary/core" && request.method === "GET") {
      const term = (url.searchParams.get("term") ?? "")
        .trim()
        .toLowerCase()
        .replace(/\s+/g, " ");
      if (!/^[a-z][a-z' -]{0,79}$/.test(term)) {
        return Response.json({ error: "Invalid term" }, { status: 400 });
      }
      const cache = defaultCache();
      const cacheKey = new Request(
        `https://lexora-core-cache.invalid/v3/${encodeURIComponent(term)}`,
      );
      const cached = await cache.match(cacheKey);
      if (cached) return cached;

      const local = (await lookupEdgeDictionary(env, [term])).get(term);
      if (local && localExactRow(term, local).defs.length > 0) {
        const response = Response.json(
          {
            dictionary: null,
            exact: [localExactRow(term, local)],
            definition_zh: local[2],
          },
          {
            headers: {
              "access-control-allow-origin": "*",
              "cache-control": "public, max-age=2592000",
              "x-lexora-dictionary-source": "edge-ecdict",
            },
          },
        );
        ctx.waitUntil(cache.put(cacheKey, response.clone()));
        return response;
      }

      const dictionaryUrl = `https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(term)}`;
      const exactUrl = new URL("https://api.datamuse.com/words");
      exactUrl.search = new URLSearchParams({
        sp: term,
        md: "dfrp",
        ipa: "1",
        max: "8",
      }).toString();
      const json = async (input: string | URL) => {
        const response = await fetch(input, {
          headers: { accept: "application/json" },
          signal: AbortSignal.timeout(1400),
        });
        if (!response.ok) throw new Error(`Upstream ${response.status}`);
        return response.json();
      };
      const dictionary = json(dictionaryUrl).then((value) => {
        if (!Array.isArray(value) || !value[0]?.meanings?.length) {
          throw new Error("Dictionary result is empty");
        }
        return { dictionary: value, exact: null };
      });
      const exact = json(exactUrl).then((value) => {
        if (!Array.isArray(value)) throw new Error("Exact result is invalid");
        const match = value.find(
          (item) =>
            String(item?.word ?? "")
              .trim()
              .toLowerCase() === term &&
            Array.isArray(item?.defs) &&
            item.defs.length > 0,
        );
        if (!match) throw new Error("Exact result is empty");
        return { dictionary: null, exact: value };
      });
      try {
        const result = await Promise.any([exact, dictionary]);
        const response = Response.json(result, {
          headers: {
            "access-control-allow-origin": "*",
            "cache-control": "public, max-age=604800",
          },
        });
        ctx.waitUntil(cache.put(cacheKey, response.clone()));
        return response;
      } catch {
        return Response.json(
          { error: "Core dictionary providers are temporarily unavailable" },
          {
            status: 504,
            headers: {
              "access-control-allow-origin": "*",
              "cache-control": "no-store",
            },
          },
        );
      }
    }

    if (
      url.pathname === "/api/dictionary/suggest" &&
      request.method === "GET"
    ) {
      const term = (url.searchParams.get("term") ?? "")
        .trim()
        .toLowerCase()
        .replace(/\s+/g, " ");
      const limit = Math.max(
        1,
        Math.min(
          24,
          Number.parseInt(url.searchParams.get("limit") ?? "12", 10) || 12,
        ),
      );
      if (!/^[a-z][a-z' -]{0,79}$/.test(term)) {
        return Response.json({ error: "Invalid term" }, { status: 400 });
      }
      const cache = defaultCache();
      const cacheKey = new Request(
        `https://lexora-suggest-cache.invalid/v1/${encodeURIComponent(term)}?limit=${limit}`,
      );
      const cached = await cache.match(cacheKey);
      if (cached) return cached;
      try {
        const endpoint = new URL("https://api.datamuse.com/sug");
        endpoint.search = new URLSearchParams({
          s: term,
          max: String(limit),
        }).toString();
        const upstream = await fetch(endpoint, {
          headers: { accept: "application/json" },
          signal: AbortSignal.timeout(1600),
        });
        if (!upstream.ok) throw new Error(`Upstream ${upstream.status}`);
        const values = (await upstream.json()) as unknown[];
        const response = Response.json(Array.isArray(values) ? values : [], {
          headers: {
            "access-control-allow-origin": "*",
            "cache-control": "public, max-age=86400",
          },
        });
        ctx.waitUntil(cache.put(cacheKey, response.clone()));
        return response;
      } catch {
        return Response.json([], {
          headers: {
            "access-control-allow-origin": "*",
            "cache-control": "no-store",
          },
        });
      }
    }

    if (url.pathname === "/api/dictionary/full" && request.method === "GET") {
      const term = (url.searchParams.get("term") ?? "")
        .trim()
        .toLowerCase()
        .replace(/\s+/g, " ");
      if (!/^[a-z][a-z' -]{0,79}$/.test(term)) {
        return Response.json({ error: "Invalid term" }, { status: 400 });
      }
      const cache = defaultCache();
      const cacheKey = new Request(
        `https://lexora-full-cache.invalid/v3/${encodeURIComponent(term)}`,
      );
      const cached = await cache.match(cacheKey);
      if (cached) return cached;

      const localFuture = lookupEdgeDictionary(env, [term]);

      const requests = {
        dictionary: `https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(term)}`,
        related: `https://api.datamuse.com/words?${new URLSearchParams({
          ml: term,
          md: "dfr",
          ipa: "1",
          max: "30",
        })}`,
        exact: `https://api.datamuse.com/words?${new URLSearchParams({
          sp: term,
          md: "dfrp",
          ipa: "1",
          max: "8",
        })}`,
        synonyms: `https://api.datamuse.com/words?${new URLSearchParams({
          rel_syn: term,
          md: "f",
          max: "12",
        })}`,
        antonyms: `https://api.datamuse.com/words?${new URLSearchParams({
          rel_ant: term,
          max: "12",
        })}`,
      };
      const jsonOrNull = async (input: string) => {
        try {
          const response = await fetch(input, {
            headers: { accept: "application/json" },
            signal: AbortSignal.timeout(1550),
          });
          if (!response.ok) return null;
          return response.json();
        } catch {
          return null;
        }
      };
      const values = await Promise.all(Object.values(requests).map(jsonOrNull));
      const local = (await localFuture).get(term);
      if (
        values.every((value) => value === null) &&
        (!local || localExactRow(term, local).defs.length === 0)
      ) {
        return Response.json(
          { error: "Dictionary providers are temporarily unavailable" },
          {
            status: 504,
            headers: {
              "access-control-allow-origin": "*",
              "cache-control": "no-store",
            },
          },
        );
      }
      const result = Object.fromEntries(
        Object.keys(requests).map((key, index) => [key, values[index]]),
      );
      if (local) {
        result.definition_zh = local[2];
        if (!Array.isArray(result.exact) || result.exact.length === 0) {
          result.exact = [localExactRow(term, local)];
        }
      }
      const response = Response.json(result, {
        headers: {
          "access-control-allow-origin": "*",
          "cache-control": "public, max-age=604800",
        },
      });
      ctx.waitUntil(cache.put(cacheKey, response.clone()));
      return response;
    }

    if (url.pathname === "/api/dictionary/batch" && request.method === "POST") {
      let terms: string[] = [];
      try {
        const payload = (await request.json()) as { terms?: unknown };
        terms = Array.isArray(payload.terms)
          ? [
              ...new Set(
                payload.terms
                  .map((value) =>
                    String(value).trim().toLowerCase().replace(/\s+/g, " "),
                  )
                  .filter((term) => /^[a-z][a-z' -]{0,79}$/.test(term)),
              ),
            ].slice(0, 12)
          : [];
      } catch {
        return Response.json({ error: "Invalid JSON" }, { status: 400 });
      }
      if (terms.length === 0) {
        return Response.json(
          { results: [] },
          { headers: { "access-control-allow-origin": "*" } },
        );
      }

      const cache = defaultCache();
      const locals = await lookupEdgeDictionary(env, terms);
      const lookup = async (term: string) => {
        const cacheKey = new Request(
          `https://lexora-batch-cache.invalid/v5/${encodeURIComponent(term)}`,
        );
        const cached = await cache.match(cacheKey);
        if (cached) {
          return { term, result: await cached.json(), cached: true };
        }

        const datamuse = (parameters: Record<string, string>) => {
          const endpoint = new URL("https://api.datamuse.com/words");
          endpoint.search = new URLSearchParams(parameters).toString();
          return endpoint.toString();
        };
        const requests = {
          related: datamuse({
            ml: term,
            md: "dfr",
            ipa: "1",
            max: "8",
          }),
          exact: datamuse({
            sp: term,
            md: "dfrp",
            ipa: "1",
            max: "3",
          }),
        };
        const jsonOrNull = async (input: string) => {
          try {
            const response = await fetch(input, {
              headers: { accept: "application/json" },
              signal: AbortSignal.timeout(1450),
            });
            if (!response.ok) return null;
            return response.json();
          } catch {
            return null;
          }
        };
        const relatedFuture = jsonOrNull(requests.related);
        const exact = await jsonOrNull(requests.exact);
        const exactRows = Array.isArray(exact) ? exact : [];
        const exactRow = exactRows.find(
          (item) =>
            String(item?.word ?? "")
              .trim()
              .toLowerCase() === term &&
            Array.isArray(item?.defs) &&
            item.defs.length > 0,
        );
        const local = locals.get(term);
        const localRow = local ? localExactRow(term, local) : null;
        const definition = String(
          exactRow?.defs?.[0] ?? localRow?.defs?.[0] ?? "",
        )
          .replace(/^[a-z]+\s*[\t.]\s*/i, "")
          .trim();
        const [related, definitionZh] = await Promise.all([
          relatedFuture,
          local?.[2]
            ? Promise.resolve(local[2])
            : translateEnglishToChinese(definition, true),
        ]);
        const compactRows = (value: unknown, definitionLimit: number) =>
          Array.isArray(value)
            ? value.map((row) => ({
                word: row?.word,
                score: row?.score,
                tags: row?.tags,
                defs: Array.isArray(row?.defs)
                  ? row.defs.slice(0, definitionLimit)
                  : undefined,
              }))
            : value;
        const result = {
          dictionary: null,
          related: compactRows(related, 2),
          exact:
            exactRows.length > 0
              ? compactRows(exact, 5)
              : localRow
                ? [localRow]
                : compactRows(exact, 5),
          definition_zh: definitionZh,
          // DictionaryAPI already carries its own synonym/antonym lists.
          // Dedicated Datamuse relationship requests remain available on the
          // single-term endpoint, while the batch path stays below the free
          // Workers subrequest ceiling for twelve simultaneous terms.
          synonyms: null,
          antonyms: null,
        };
        if (exact !== null) {
          ctx.waitUntil(
            cache.put(
              cacheKey,
              Response.json(result, {
                headers: { "cache-control": "public, max-age=604800" },
              }),
            ),
          );
        }
        return {
          term,
          result: exact !== null ? result : null,
          cached: false,
        };
      };

      const results = await Promise.all(terms.map(lookup));
      return Response.json(
        { results },
        {
          headers: {
            "access-control-allow-origin": "*",
            "cache-control": "no-store",
            "server-timing": `lexora-batch;desc=\"${terms.length} terms\"`,
          },
        },
      );
    }

    if (url.pathname === "/api/translate/batch" && request.method === "POST") {
      let texts: string[] = [];
      try {
        const payload = (await request.json()) as { texts?: unknown };
        texts = Array.isArray(payload.texts)
          ? payload.texts
              .map((value) => String(value).trim())
              .filter((value) => value.length > 0 && value.length <= 480)
              .slice(0, 24)
          : [];
      } catch {
        return Response.json({ error: "Invalid JSON" }, { status: 400 });
      }
      if (texts.length === 0) {
        return Response.json(
          { translations: [] },
          {
            headers: { "access-control-allow-origin": "*" },
          },
        );
      }
      const cache = defaultCache();
      const cacheKeyFor = async (text: string) => {
        const encoded = new TextEncoder().encode(text);
        const digest = await crypto.subtle.digest("SHA-256", encoded);
        const key = Array.from(new Uint8Array(digest))
          .map((byte) => byte.toString(16).padStart(2, "0"))
          .join("");
        return new Request(
          `https://lexora-translation-cache.invalid/v2/${key}`,
        );
      };
      const keys = await Promise.all(texts.map(cacheKeyFor));
      const cached = await Promise.all(keys.map((key) => cache.match(key)));
      const translations = await Promise.all(
        cached.map((response) => response?.text() ?? ""),
      );
      const missingIndexes = translations
        .map((value, index) => (value ? -1 : index))
        .filter((index) => index >= 0);

      // One request per missing string is both faster and more reliable than
      // parsing translated separator markers. Calls run concurrently at the
      // edge, so mainland clients still make only one request to Lexora.
      await Promise.all(
        missingIndexes.map(async (index) => {
          const translated = await translateEnglishToChinese(
            texts[index],
            true,
          );
          if (translated) translations[index] = translated;
        }),
      );

      for (let index = 0; index < translations.length; index++) {
        const translated = translations[index];
        if (!translated) continue;
        ctx.waitUntil(
          cache.put(
            keys[index],
            new Response(translated, {
              headers: { "cache-control": "public, max-age=2592000" },
            }),
          ),
        );
      }
      return Response.json(
        { translations },
        {
          headers: {
            "access-control-allow-origin": "*",
            "cache-control": "no-store",
          },
        },
      );
    }

    if (url.pathname.startsWith("/api/") && request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "access-control-allow-origin": "*",
          "access-control-allow-methods": "GET, POST, OPTIONS",
          "access-control-allow-headers": "content-type",
          "access-control-max-age": "86400",
        },
      });
    }

    if (url.pathname === "/_vinext/image") {
      const allowedWidths = [...DEFAULT_DEVICE_SIZES, ...DEFAULT_IMAGE_SIZES];
      return handleImageOptimization(
        request,
        {
          fetchAsset: (path) =>
            env.ASSETS.fetch(new Request(new URL(path, request.url))),
          transformImage: async (body, { width, format, quality }) => {
            const result = await env.IMAGES.input(body)
              .transform(width > 0 ? { width } : {})
              .output({ format, quality });
            return result.response();
          },
        },
        allowedWidths,
      );
    }

    return handler.fetch(request, env, ctx);
  },
};

export default worker;
