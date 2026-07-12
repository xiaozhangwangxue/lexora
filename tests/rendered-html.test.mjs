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
  assert.match(html, /wechat\.png/);
  assert.match(html, /alipay\.jpg/);
  assert.match(html, /捐款完全自愿/);
});
