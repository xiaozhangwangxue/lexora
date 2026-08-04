const token = process.env.DOWNLOAD_UPLOAD_TOKEN;
const origin = process.env.DOWNLOAD_UPLOAD_ORIGIN
  ?? "https://lexora-official.xiaozhangwangxue.workers.dev";
const marker = process.argv.indexOf("--keep");
const keep = new Set(
  marker < 0
    ? []
    : process.argv.slice(marker + 1).map((version) => version.replace(/^v/, "")),
);
if (!token || keep.size === 0) {
  throw new Error("DOWNLOAD_UPLOAD_TOKEN and --keep versions are required.");
}

const headers = { "x-lexora-upload-token": token };
const keys = [];
let cursor;
do {
  const url = new URL("/api/admin/downloads", origin);
  if (cursor) url.searchParams.set("cursor", cursor);
  const response = await fetch(url, { headers });
  if (!response.ok) throw new Error(`R2 list failed: ${response.status}`);
  const page = await response.json();
  keys.push(...page.keys);
  cursor = page.cursor ?? undefined;
} while (cursor);

const releasePattern = /^lexora-(?:android|linux|macos|windows)-v(.+?)(?:-setup)?\.(?:apk|dmg|zip|exe|tar\.gz)$/;
const semanticVersion = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/;
for (const key of keys) {
  const match = key.match(releasePattern);
  if (!match || !semanticVersion.test(match[1]) || keep.has(match[1])) continue;
  const response = await fetch(
    new URL(`/api/admin/downloads/${encodeURIComponent(key)}`, origin),
    { method: "DELETE", headers },
  );
  if (!response.ok) throw new Error(`R2 delete failed for ${key}: ${response.status}`);
  console.log(`Removed old R2 release object ${key}`);
}
