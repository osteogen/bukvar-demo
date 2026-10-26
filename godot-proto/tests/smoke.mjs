// Быстрая проверка web-сборки урока (build/) в headless Chrome: загрузка, COOP/COEP, WebGL2, ошибки JS, s01 → «Далее» → s02.
// THROTTLE=1 — эмуляция сети ~10 Мбит/с, RTT 40 мс (условный «хороший 4G»).
import { createRequire } from "module"; import { spawn } from "child_process"; import path from "path"; import { fileURLToPath } from "url";
const require = createRequire(import.meta.url);
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const puppeteer = require(path.resolve(ROOT, "../.tools/node_modules/puppeteer-core"));
const PORT = +(process.env.PORT || 55781); const srv = spawn("node", [path.join(ROOT, "tests/serve.mjs"), path.join(ROOT, "build"), String(PORT)], { stdio: "ignore", env: process.env });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const errors = [], logs = []; let browser; const t = {};
try {
  await sleep(800);
  browser = await puppeteer.launch({ executablePath: "/usr/bin/google-chrome", headless: "new",
    args: ["--no-sandbox", "--autoplay-policy=no-user-gesture-required", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist", "--mute-audio"] });
  const page = await browser.newPage(); await page.setViewport({ width: 1024, height: 768 });
  const cdp = await page.target().createCDPSession();
  await cdp.send("Network.enable"); await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  if (process.env.THROTTLE) await cdp.send("Network.emulateNetworkConditions", { offline: false, latency: 40, downloadThroughput: 10e6 / 8, uploadThroughput: 3e6 / 8 });
  let bytes = 0; cdp.on("Network.loadingFinished", (e) => { bytes += e.encodedDataLength; });
  page.on("console", (m) => { logs.push(m.type() + ": " + m.text()); if (m.type() === "error") errors.push(m.text()); });
  page.on("pageerror", (e) => errors.push("pageerror: " + e.message));
  const t0 = Date.now();
  await page.goto(`http://127.0.0.1:${PORT}/index.html?test=1&fast=1`, { waitUntil: "load" });
  // урок (сборка build/ без главной): загрузка → s01 «Аист приносит буквы» (было: старый прототип legacy_v1 с __godot_steps)
  await page.waitForFunction(() => window.__bk && window.__bk.step === "s01_stork", { timeout: 180000 });
  t.ready = Date.now() - t0; t.bytes = bytes;
  t.crossOriginIsolated = await page.evaluate(() => self.crossOriginIsolated);
  t.webgl2 = await page.evaluate(() => !!document.createElement("canvas").getContext("webgl2"));
  await page.screenshot({ path: path.join(ROOT, "screenshots/01-ready.png") });
  // аист садится, появляется «Далее» → касание → s02
  await page.waitForFunction(() => window.__bk.state === "done" && window.__bk.targets && window.__bk.targets.next, { timeout: 40000 });
  await sleep(600);
  const nx = await page.evaluate(() => window.__bk.targets.next); await page.mouse.click(nx[0], nx[1]);
  await page.waitForFunction(() => window.__bk.step === "s02_intro", { timeout: 15000 });
  await sleep(500); await page.screenshot({ path: path.join(ROOT, "screenshot.png") });
  t.steps = await page.evaluate(() => "s01_stork → " + window.__bk.step);
} catch (e) { errors.push("test: " + (e.stack || e)); }
finally { if (browser) await browser.close(); srv.kill(); }
console.log(JSON.stringify(t, null, 1));
console.log("console (first 15):\n" + logs.slice(0, 15).join("\n"));
console.log(errors.length ? "ERRORS:\n" + errors.join("\n") : "OK: no JS errors");
process.exit(errors.length ? 1 : 0);
