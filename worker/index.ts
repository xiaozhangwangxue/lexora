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
      headers.set(
        "cache-control",
        /-v\d+\.\d+\.\d+\./.test(key)
          ? "public, max-age=31536000, immutable"
          : "no-cache",
      );
      return new Response(object.body, { headers });
    };

    if (url.pathname.startsWith("/api/admin/downloads/") && request.method === "PUT") {
      const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
      if (!env.DOWNLOAD_UPLOAD_TOKEN || token !== env.DOWNLOAD_UPLOAD_TOKEN) {
        return new Response("Unauthorized", { status: 401 });
      }
      if (!env.DOWNLOADS) return new Response("Download storage is unavailable", { status: 503 });
      const key = decodeURIComponent(url.pathname.slice("/api/admin/downloads/".length));
      if (!key || key.includes("/") || key.includes("..") || !request.body) {
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
