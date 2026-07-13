import { createHash } from "node:crypto";
import { readFile, stat, writeFile } from "node:fs/promises";
import { basename } from "node:path";

const [inputPath, outputPath, ...artifactPaths] = process.argv.slice(2);
if (!inputPath || !outputPath || artifactPaths.length === 0) {
  throw new Error("Usage: node tool/finalize_update_manifest.mjs <input> <output> <artifacts...>");
}

const manifest = JSON.parse(await readFile(inputPath, "utf8"));
for (const [platform, download] of Object.entries(manifest.verifiedDownloads ?? {})) {
  if (!download || typeof download !== "object" || typeof download.filename !== "string") {
    throw new Error(`Invalid download metadata for ${platform}`);
  }
  const artifactPath = artifactPaths.find((path) => basename(path) === download.filename);
  if (!artifactPath) throw new Error(`Missing release artifact ${download.filename}`);
  const data = await readFile(artifactPath);
  const info = await stat(artifactPath);
  download.sha256 = createHash("sha256").update(data).digest("hex");
  download.size = info.size;
}

await writeFile(outputPath, `${JSON.stringify(manifest, null, 2)}\n`);
