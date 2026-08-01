import { open, readFile, stat } from "node:fs/promises";
import { basename } from "node:path";

const files = process.argv.slice(2);
const token = process.env.DOWNLOAD_UPLOAD_TOKEN;
const origin = process.env.DOWNLOAD_UPLOAD_ORIGIN
  ?? "https://lexora-official.xiaozhangwangxue.workers.dev";
const singleUploadLimit = 90 * 1024 * 1024;
const partSize = 48 * 1024 * 1024;

if (!token) throw new Error("DOWNLOAD_UPLOAD_TOKEN is not configured.");
if (files.length === 0) throw new Error("No release artifacts were supplied.");

const contentTypeFor = (name) => {
  if (name.endsWith(".apk")) return "application/vnd.android.package-archive";
  if (name.endsWith(".dmg")) return "application/x-apple-diskimage";
  if (name.endsWith(".exe")) return "application/vnd.microsoft.portable-executable";
  if (name.endsWith(".zip")) return "application/zip";
  if (name.endsWith(".tar.gz")) return "application/gzip";
  if (name.endsWith(".json")) return "application/json; charset=utf-8";
  return "application/octet-stream";
};

const request = async (url, options) => {
  let lastError;
  for (let attempt = 0; attempt < 5; attempt++) {
    try {
      const response = await fetch(url, options);
      if (response.ok) return response;
      const message = await response.text();
      if (response.status < 500 && response.status !== 429) {
        throw new Error(`${response.status} ${message}`);
      }
      lastError = new Error(`${response.status} ${message}`);
    } catch (error) {
      lastError = error;
    }
    await new Promise((resolve) => setTimeout(resolve, 500 * (2 ** attempt)));
  }
  throw lastError;
};

const headersFor = (name) => ({
  "x-lexora-upload-token": token,
  "content-type": contentTypeFor(name),
});

const uploadSingle = async (path, name) => {
  const body = await readFile(path);
  await request(`${origin}/api/admin/downloads/${encodeURIComponent(name)}`, {
    method: "PUT",
    headers: headersFor(name),
    body,
  });
};

const uploadMultipart = async (path, name, size) => {
  const endpoint = `${origin}/api/admin/downloads-multipart/${encodeURIComponent(name)}`;
  const started = await request(endpoint, {
    method: "POST",
    headers: headersFor(name),
  });
  const { uploadId } = await started.json();
  const parts = [];
  const handle = await open(path, "r");
  try {
    for (let offset = 0, partNumber = 1; offset < size; partNumber++) {
      const length = Math.min(partSize, size - offset);
      const buffer = Buffer.allocUnsafe(length);
      await handle.read(buffer, 0, length, offset);
      const uploaded = await request(
        `${endpoint}?uploadId=${encodeURIComponent(uploadId)}&partNumber=${partNumber}`,
        {
          method: "PUT",
          headers: headersFor(name),
          body: buffer,
        },
      );
      parts.push(await uploaded.json());
      offset += length;
    }
    await request(`${endpoint}?uploadId=${encodeURIComponent(uploadId)}`, {
      method: "POST",
      headers: { ...headersFor(name), "content-type": "application/json" },
      body: JSON.stringify({ parts }),
    });
  } catch (error) {
    await fetch(`${endpoint}?uploadId=${encodeURIComponent(uploadId)}`, {
      method: "DELETE",
      headers: headersFor(name),
    }).catch(() => {});
    throw error;
  } finally {
    await handle.close();
  }
};

for (const path of files) {
  const name = basename(path);
  const { size } = await stat(path);
  if (size > singleUploadLimit) {
    await uploadMultipart(path, name, size);
  } else {
    await uploadSingle(path, name);
  }
  console.log(`Uploaded ${name} (${size} bytes).`);
}
