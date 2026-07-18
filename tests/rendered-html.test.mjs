import assert from "node:assert/strict";
import test from "node:test";

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
  assert.match(html, /Make your words worth keeping/);
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
  assert.match(html, /lexora-android-v1\.1\.3\.apk/);
  assert.match(html, /lexora-macos-v1\.1\.3\.dmg/);
  assert.match(html, /lexora-windows-v1\.1\.3-setup\.exe/);
  assert.match(html, /拖动手柄调整顺序/);
  assert.match(html, /href="\/favicon\.png\?v=5"/);
  assert.doesNotMatch(html, /\[object%20Object\]/);
  assert.doesNotMatch(html, /codex-preview|react-loading-skeleton|Starter Project/);
});

test("server-renders the bilingual donation page", async () => {
  const response = await render("/donate");
  assert.equal(response.status, 200);
  const html = await response.text();
  assert.match(html, /支持独立开发/);
  assert.match(html, /支持独立开发/);
  assert.match(html, /photo\.12323456\.xyz\/api\/rfile\/%E5%BE%AE%E4%BF%A1\.png/);
  assert.match(html, /photo\.12323456\.xyz\/api\/rfile\/%E6%94%AF%E4%BB%98%E5%AE%9D\.jpg/);
  assert.match(html, /捐款完全自愿/);
});
