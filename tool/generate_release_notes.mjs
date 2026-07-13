import { readFile, writeFile } from "node:fs/promises";

const metadata = JSON.parse(await readFile("public/version.json", "utf8"));
const version = `v${metadata.version}`;
const bullets = (items) => items.map((item) => `- ${item}`).join("\n");
const body = `# Lexora ${version}

## 中文更新说明

${bullets(metadata.releaseNotes.zh)}

## What's new

${bullets(metadata.releaseNotes.en)}

## 下载与安装 / Download

推荐从 [Lexora 官网](https://lexora.12323456.xyz/#download) 下载。官网会在浏览器本地识别设备并推荐正确版本，同时保留全部平台安装包与安装说明。

Download from the [Lexora official website](https://lexora.12323456.xyz/#download). Device detection runs locally in the browser, recommends the matching build, and keeps every platform package available.
`;

await writeFile("release-notes.md", body);
