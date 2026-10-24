// Проверка web-сборки Godot в headless Chrome: загрузка, ошибки, тап, твин, награда.
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
  await page.goto(`http://127.0.0.1:${PORT}/index.html`, { waitUntil: "load" });
  await page.waitForFunction(() => (window.__godot_steps || []).includes("ready"), { timeout: 180000 });
  t.ready = Date.now() - t0; t.bytes = bytes;
  t.crossOriginIsolated = await page.evaluate(() => self.crossOriginIsolated);
  t.webgl2 = await page.evaluate(() => !!document.createElement("canvas").getContext("webgl2"));
  await page.screenshot({ path: path.join(ROOT, "screenshots/01-ready.png") });
  await page.waitForFunction(() => window.__godot_steps.includes("hint"), { timeout: 10000 });
  await sleep(300); await page.screenshot({ path: path.join(ROOT, "screenshots/02-hint.png") });
  await page.mouse.click(320, 380);
  await page.waitForFunction(() => window.__godot_steps.includes("tapped"), { timeout: 5000 });
  await sleep(700); await page.screenshot({ path: path.join(ROOT, "screenshots/03-word.png") });
  await page.waitForFunction(() => window.__godot_steps.includes("end"), { timeout: 8000 });
  await page.screenshot({ path: path.join(ROOT, "screenshot.png") });
  t.steps = await page.evaluate(() => window.__godot_steps.join(" → "));
} catch (e) { errors.push("test: " + (e.stack || e)); }
finally { if (browser) await browser.close(); srv.kill(); }
console.log(JSON.stringify(t, null, 1));
console.log("console (first 15):\n" + logs.slice(0, 15).join("\n"));
console.log(errors.length ? "ERRORS:\n" + errors.join("\n") : "OK: no JS errors");
process.exit(errors.length ? 1 : 0);
