/** Cloudflare Worker entry point for the vinext-starter template. */
import { handleImageOptimization, DEFAULT_DEVICE_SIZES, DEFAULT_IMAGE_SIZES } from "vinext/server/image-optimization";
import handler from "vinext/server/app-router-entry";

interface Env {
  ASSETS: Fetcher;
  DOWNLOADS?: R2Bucket;
  DOWNLOAD_UPLOAD_TOKEN?: string;
  DB: D1Database;
  IMAGES: {
    input(stream: ReadableStream): {
      transform(options: Record<string, unknown>): {
        output(options: { format: string; quality: number }): Promise<{ response(): Response }>;
      };
    };
  };
}

interface ExecutionContext {
  waitUntil(promise: Promise<unknown>): void;
  passThroughOnException(): void;
}

// Image security config. SVG sources with .svg extension auto-skip the
// optimization endpoint on the client side (served directly, no proxy).
// To route SVGs through the optimizer (with security headers), set
// dangerouslyAllowSVG: true in next.config.js and uncomment below:
// const imageConfig: ImageConfig = { dangerouslyAllowSVG: true };

const worker = {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    const authorizedUpload = () => {
      const token = request.headers.get("x-lexora-upload-token")
        ?? request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
      return Boolean(env.DOWNLOAD_UPLOAD_TOKEN && token === env.DOWNLOAD_UPLOAD_TOKEN);
    };

    const validDownloadKey = (key: string) =>
      Boolean(key && !key.includes("/") && !key.includes(".."));

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
      if (key === "version.json") {
        // Existing clients rely on the response charset when decoding Chinese
        // release notes. R2's default application/octet-stream would make the
        // Dart HTTP client decode them as Latin-1.
        headers.set("content-type", "application/json; charset=utf-8");
      }
      headers.set(
        "cache-control",
        /-v\d+\.\d+\.\d+\./.test(key)
          ? "public, max-age=31536000, immutable"
          : "no-cache",
      );
      return new Response(object.body, { headers });
    };

    if (url.pathname.startsWith("/api/admin/downloads-multipart/")) {
      if (!authorizedUpload()) return new Response("Unauthorized", { status: 401 });
      if (!env.DOWNLOADS) return new Response("Download storage is unavailable", { status: 503 });
      const key = decodeURIComponent(
        url.pathname.slice("/api/admin/downloads-multipart/".length),
      );
      if (!validDownloadKey(key)) return new Response("Invalid upload", { status: 400 });

      const uploadId = url.searchParams.get("uploadId");
      if (request.method === "POST" && !uploadId) {
        const upload = await env.DOWNLOADS.createMultipartUpload(key, {
          httpMetadata: {
            contentType: request.headers.get("content-type") ?? "application/octet-stream",
            contentDisposition: `attachment; filename="${key}"`,
            cacheControl: "public, max-age=31536000, immutable",
          },
        });
        return Response.json({ uploadId: upload.uploadId, key });
      }
      if (!uploadId) return new Response("Missing uploadId", { status: 400 });
      const upload = env.DOWNLOADS.resumeMultipartUpload(key, uploadId);

      if (request.method === "PUT" && request.body) {
        const partNumber = Number(url.searchParams.get("partNumber"));
        if (!Number.isInteger(partNumber) || partNumber < 1 || partNumber > 10000) {
          return new Response("Invalid part number", { status: 400 });
        }
        const part = await upload.uploadPart(partNumber, request.body);
        return Response.json(part);
      }
      if (request.method === "POST") {
        const payload = await request.json() as { parts?: R2UploadedPart[] };
        if (!Array.isArray(payload.parts) || payload.parts.length === 0) {
          return new Response("Missing uploaded parts", { status: 400 });
        }
        const object = await upload.complete(payload.parts);
        return Response.json({ ok: true, key, etag: object.httpEtag });
      }
      if (request.method === "DELETE") {
        await upload.abort();
        return Response.json({ ok: true, key, aborted: true });
      }
      return new Response("Unsupported multipart operation", { status: 405 });
    }

    if (url.pathname.startsWith("/api/admin/downloads/") && request.method === "PUT") {
      // A dedicated header avoids Cloudflare Access interpreting a normal
      // Authorization bearer token before the request reaches this Worker.
      if (!authorizedUpload()) return new Response("Unauthorized", { status: 401 });
      if (!env.DOWNLOADS) return new Response("Download storage is unavailable", { status: 503 });
      const key = decodeURIComponent(url.pathname.slice("/api/admin/downloads/".length));
      if (!validDownloadKey(key) || !request.body) {
        return new Response("Invalid upload", { status: 400 });
      }
      await env.DOWNLOADS.put(key, request.body, {
        httpMetadata: {
          contentType: request.headers.get("content-type") ?? "application/octet-stream",
          contentDisposition: `attachment; filename="${key}"`,
        },
      });
      return Response.json({ ok: true, key });
    }

    if (url.pathname === "/version.json") {
      const manifest = await r2Response("version.json", false);
      if (manifest) return manifest;
    }

    if (url.pathname.startsWith("/updates/")) {
      const key = decodeURIComponent(url.pathname.slice("/updates/".length));
      if (!key || key.includes("/") || key.includes("..")) {
        return new Response("Invalid update name", { status: 400 });
      }
      const object = await r2Response(key);
      return object ?? new Response("Update mirror is not ready", { status: 503 });
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
      const term = (url.searchParams.get("term") ?? "").trim().toLowerCase().replace(/\s+/g, " ");
      if (!/^[a-z][a-z' -]{0,79}$/.test(term)) {
        return Response.json({ error: "Invalid term" }, { status: 400 });
      }
      const cache = caches.default;
      const cacheKey = new Request(`https://lexora-core-cache.invalid/v1/${encodeURIComponent(term)}`);
      const cached = await cache.match(cacheKey);
      if (cached) return cached;

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
            String(item?.word ?? "").trim().toLowerCase() === term
            && Array.isArray(item?.defs)
            && item.defs.length > 0,
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

    if (url.pathname === "/api/dictionary/full" && request.method === "GET") {
      const term = (url.searchParams.get("term") ?? "").trim().toLowerCase().replace(/\s+/g, " ");
      if (!/^[a-z][a-z' -]{0,79}$/.test(term)) {
        return Response.json({ error: "Invalid term" }, { status: 400 });
      }
      const cache = caches.default;
      const cacheKey = new Request(`https://lexora-full-cache.invalid/v1/${encodeURIComponent(term)}`);
      const cached = await cache.match(cacheKey);
      if (cached) return cached;

      const requests = {
        dictionary: `https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(term)}`,
        related: `https://api.datamuse.com/words?${new URLSearchParams({
          ml: term, md: "dfr", ipa: "1", max: "30",
        })}`,
        exact: `https://api.datamuse.com/words?${new URLSearchParams({
          sp: term, md: "dfrp", ipa: "1", max: "8",
        })}`,
        synonyms: `https://api.datamuse.com/words?${new URLSearchParams({
          rel_syn: term, md: "f", max: "12",
        })}`,
        antonyms: `https://api.datamuse.com/words?${new URLSearchParams({
          rel_ant: term, max: "12",
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
      if (values.every((value) => value === null)) {
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
      const response = Response.json(result, {
        headers: {
          "access-control-allow-origin": "*",
          "cache-control": "public, max-age=604800",
        },
      });
      ctx.waitUntil(cache.put(cacheKey, response.clone()));
      return response;
    }

    if (url.pathname === "/api/translate/batch" && request.method === "POST") {
      let texts: string[] = [];
      try {
        const payload = await request.json() as { texts?: unknown };
        texts = Array.isArray(payload.texts)
          ? payload.texts
            .map((value) => String(value).trim())
            .filter((value) => value.length > 0 && value.length <= 480)
            .slice(0, 32)
          : [];
      } catch {
        return Response.json({ error: "Invalid JSON" }, { status: 400 });
      }
      if (texts.length === 0) {
        return Response.json({ translations: [] }, {
          headers: { "access-control-allow-origin": "*" },
        });
      }
      const cache = caches.default;
      const cacheKeyFor = async (text: string) => {
        const encoded = new TextEncoder().encode(text);
        const digest = await crypto.subtle.digest("SHA-256", encoded);
        const key = Array.from(new Uint8Array(digest))
          .map((byte) => byte.toString(16).padStart(2, "0"))
          .join("");
        return new Request(`https://lexora-translation-cache.invalid/v1/${key}`);
      };
      const keys = await Promise.all(texts.map(cacheKeyFor));
      const cached = await Promise.all(keys.map((key) => cache.match(key)));
      const translations = await Promise.all(cached.map((response) => response?.text() ?? ""));
      const missingIndexes = translations
        .map((value, index) => value ? -1 : index)
        .filter((index) => index >= 0);

      if (missingIndexes.length > 0) {
        // Digits and brackets survive translation more reliably than a
        // lettered sentinel (some engines translated "LEXORA" itself).
        const marker = (index: number) => `[[[${index}]]]`;
        const payload = missingIndexes
          .map((index) => `${marker(index)} ${texts[index]}`)
          .join("\n");
        try {
          const endpoint = new URL("https://translate.googleapis.com/translate_a/single");
          endpoint.search = new URLSearchParams({
            client: "gtx",
            sl: "en",
            tl: "zh-CN",
            dt: "t",
            q: payload,
          }).toString();
          const response = await fetch(endpoint, {
            headers: { accept: "application/json" },
            signal: AbortSignal.timeout(2300),
          });
          if (response.ok) {
            const body = await response.json() as unknown[];
            const chunks = Array.isArray(body[0]) ? body[0] as unknown[][] : [];
            const joined = chunks.map((chunk) => String(chunk[0] ?? "")).join("");
            for (let position = 0; position < missingIndexes.length; position++) {
              const index = missingIndexes[position];
              const startMarker = marker(index);
              const start = joined.indexOf(startMarker);
              if (start < 0) continue;
              const contentStart = start + startMarker.length;
              const nextIndex = missingIndexes[position + 1];
              const end = nextIndex === undefined
                ? joined.length
                : joined.indexOf(marker(nextIndex), contentStart);
              const translated = joined
                .slice(contentStart, end < 0 ? joined.length : end)
                .trim();
              if (translated) translations[index] = translated;
            }
          }
        } catch {
          // Individual fallback below handles providers that reject a batch.
        }
      }

      const stillMissing = translations
        .map((value, index) => value ? -1 : index)
        .filter((index) => index >= 0);
      await Promise.all(stillMissing.map(async (index) => {
        try {
          const endpoint = new URL("https://api.mymemory.translated.net/get");
          endpoint.search = new URLSearchParams({
            q: texts[index],
            langpair: "en|zh-CN",
          }).toString();
          const response = await fetch(endpoint, {
            headers: { accept: "application/json" },
            signal: AbortSignal.timeout(2300),
          });
          if (!response.ok) return;
          const body = await response.json() as {
            responseData?: { translatedText?: unknown };
          };
          translations[index] = String(body.responseData?.translatedText ?? "").trim();
        } catch {
          // A missing translation never blocks the English dictionary result.
        }
      }));

      for (let index = 0; index < translations.length; index++) {
        const translated = translations[index];
        if (!translated) continue;
        ctx.waitUntil(cache.put(
          keys[index],
          new Response(translated, {
            headers: { "cache-control": "public, max-age=2592000" },
          }),
        ));
      }
      return Response.json({ translations }, {
        headers: {
          "access-control-allow-origin": "*",
          "cache-control": "no-store",
        },
      });
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
      return handleImageOptimization(request, {
        fetchAsset: (path) => env.ASSETS.fetch(new Request(new URL(path, request.url))),
        transformImage: async (body, { width, format, quality }) => {
          const result = await env.IMAGES.input(body).transform(width > 0 ? { width } : {}).output({ format, quality });
          return result.response();
        },
      }, allowedWidths);
    }

    return handler.fetch(request, env, ctx);
  },
};

export default worker;
