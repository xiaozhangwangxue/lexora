import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const manifest = JSON.parse(
  await readFile(new URL("../public/version.json", import.meta.url), "utf8"),
);

async function render(path = "/") {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);
  return worker.fetch(
    new Request(`http://localhost${path}`, { headers: { accept: "text/html" } }),
    { ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) } },
    { waitUntil() {}, passThroughOnException() {} },
  );
}

test("server-renders the finished Lexora landing page", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);
  const html = await response.text();
  assert.match(html, /<title>Lexora/);
  assert.match(html, /免费个人英语词汇书生成器与英汉词典/);
  assert.match(html, /SoftwareApplication/);
  assert.match(html, /每一次查词，都在写/);
  assert.match(html, /开始生成/);
  assert.match(html, /macOS/);
  assert.match(html, /捐款渠道/);
  assert.match(html, /WeChat Pay/);
  assert.match(html, /Alipay/);
  assert.match(html, /github\.com\/xiaozhangwangxue\/lexora/);
  assert.match(html, /lexoraWordmarkHero/);
  assert.match(html, /\/lɛkˈsɔːrə\//);
  assert.match(html, /正在识别设备/);
  assert.match(html, /id="all-downloads"/);
  assert.match(html, new RegExp(manifest.verifiedDownloads.android.filename));
  assert.match(html, new RegExp(manifest.verifiedDownloads.macos.filename));
  assert.match(html, new RegExp(manifest.verifiedDownloads.windows.filename));
  assert.match(html, /历史版本/);
  assert.match(html, /lexora-android-v3\.2\.5\.apk/);
  assert.match(html, /lexora-android-v3\.1\.0\.apk/);
  assert.match(html, /4\.0\.0 性能、安全与动画/);
  assert.match(html, /4\.0\.2 搜索与服务器稳定性/);
  assert.match(html, /id="release-notes"/);
  assert.doesNotMatch(html, /id="release-notes"[^>]*data-reveal/);
  assert.match(html, /每一次查词/);
  assert.match(html, /分页图片或长图/);
  assert.doesNotMatch(html, /supportInner/);
  assert.match(html, /拖动手柄调整顺序/);
  assert.match(html, /href="\/favicon\.png\?v=5"/);
  assert.match(html, /href="\/guides"/);
  assert.match(html, /href="\/web"/);
  assert.match(html, /在线使用/);
  assert.doesNotMatch(html, /\[object%20Object\]/);
  assert.doesNotMatch(html, /codex-preview|react-loading-skeleton|Starter Project/);
});

test("server-renders searchable Chinese guide pages", async () => {
  for (const [path, expected] of [
    ["/guides", "英语单词整理与个人词汇书制作指南"],
    ["/guides/personal-vocabulary-book", "如何制作真正适合自己的英语词汇书"],
    ["/guides/import-word-list", "如何批量导入英语单词和短语"],
    ["/guides/word-to-pdf", "如何把英语单词表制作成 PDF 词汇书"],
  ]) {
    const response = await render(path);
    assert.equal(response.status, 200);
    const html = await response.text();
    assert.match(html, new RegExp(expected));
    assert.match(html, /免费下载/);
  }
});

test("server-renders bilingual vocabulary generator landing pages", async () => {
  const chinese = await render("/vocabulary-book-generator");
  assert.equal(chinese.status, 200);
  const chineseHtml = await chinese.text();
  assert.match(chineseHtml, /免费的个人英语词汇书生成器/);
  assert.match(chineseHtml, /FAQPage/);
  assert.match(chineseHtml, /单词表转换成 PDF/);

  const english = await render("/en/vocabulary-book-generator");
  assert.equal(english.status, 200);
  const englishHtml = await english.text();
  assert.match(englishHtml, /free personal vocabulary book generator/i);
  assert.match(englishHtml, /FAQPage/);
  assert.match(englishHtml, /Which formats are supported/);
});

test("server-renders the open-source browser app", async () => {
  const response = await render("/web");
  assert.equal(response.status, 200);
  const html = await response.text();
  assert.match(html, /在线查词，生成你的词汇书/);
  assert.match(html, /输入单词或短语/);
  assert.match(html, /导入文件/);
  assert.match(html, /生成并下载/);
  assert.match(html, /github\.com\/xiaozhangwangxue\/lexora/);
});

test("publishes robots, sitemap, and web app manifest", async () => {
  const robots = await render("/robots.txt");
  assert.equal(robots.status, 200);
  assert.match(await robots.text(), /sitemap\.xml/);

  const sitemap = await render("/sitemap.xml");
  assert.equal(sitemap.status, 200);
  const sitemapText = await sitemap.text();
  assert.match(sitemapText, /guides\/word-to-pdf/);
  assert.match(sitemapText, /vocabulary-book-generator/);
  assert.match(sitemapText, /\/web/);

  const manifest = await render("/manifest.webmanifest");
  assert.equal(manifest.status, 200);
  assert.match(await manifest.text(), /个人英语词汇书/);
});

test("server-renders the bilingual donation page", async () => {
  const response = await render("/donate");
  assert.equal(response.status, 200);
  const html = await response.text();
  assert.match(html, /支持独立开发/);
  assert.match(html, /photo\.12323456\.xyz\/api\/rfile\/%E5%BE%AE%E4%BF%A1\.png/);
  assert.match(html, /photo\.12323456\.xyz\/api\/rfile\/%E6%94%AF%E4%BB%98%E5%AE%9D\.jpg/);
  assert.match(html, /捐款完全自愿/);
});
