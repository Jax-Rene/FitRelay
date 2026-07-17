import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);
  return worker.fetch(new Request("http://localhost/", { headers: { accept: "text/html" } }), {
    ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) },
  }, { waitUntil() {}, passThroughOnException() {} });
}

test("server-renders the Suilian AI onboarding entry", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);
  const html = await response.text();
  assert.match(html, /<title>随练 AI · 静态产品 Demo<\/title>/i);
  assert.match(html, /欢迎来到随练 AI/);
  assert.match(html, /开始设置/);
  assert.match(html, /不用坚持打卡/);
});

test("keeps the MVP core states and interactions in the product surface", async () => {
  const page = await readFile(new URL("../app/page.tsx", import.meta.url), "utf8");
  const css = await readFile(new URL("../app/globals.css", import.meta.url), "utf8");
  assert.match(page, /type Screen = "onboarding" \| "home" \| "plan" \| "workout" \| "summary"/);
  assert.match(page, /function applyPlanAdjustment/);
  assert.match(page, /function switchExercise/);
  assert.match(page, /function endCurrentExercise/);
  assert.match(page, /总结只统计本次实际完成的动作与组数/);
  assert.match(css, /\.onboarding-screen/);
  assert.match(css, /\.end-workout-button/);
});
