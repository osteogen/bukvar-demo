// Снимок колыбельной (сцена 2, s02_intro; до 26.10.2026 была сценой 1 — отсюда имя файла) в реальном темпе (без fast): поза Али во время песенки.
import { createRequire } from "module"; import { spawn } from "child_process"; import path from "path"; import { fileURLToPath } from "url";
const require = createRequire(import.meta.url);
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const puppeteer = require(path.resolve(ROOT, "../.tools/node_modules/puppeteer-core"));
const PORT = +(process.env.PORT || 55783);
const srv = spawn("node", [path.join(ROOT, "tests/serve.mjs"), path.join(ROOT, "build"), String(PORT)], { stdio: "ignore", env: { ...process.env, NOCOI: "1" } });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
await sleep(600);
const browser = await puppeteer.launch({ executablePath: "/usr/bin/google-chrome", headless: "new", args: ["--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--autoplay-policy=no-user-gesture-required"] });
const page = await browser.newPage(); await page.setViewport({ width: 1024, height: 768, hasTouch: true });
await page.goto(`http://127.0.0.1:${PORT}/index.html?test=1&step=s02_intro`);
const t0 = Date.now(); let n = 0;
while (Date.now() - t0 < 26000) {
  const s = await page.evaluate(() => window.__bk || {});
  if (s.step === "s02_intro") { await page.screenshot({ path: path.join(ROOT, "screenshots", `s02-intro-t${String(n).padStart(2, "0")}.png`) }); n++; }
  await sleep(2000);
}
await browser.close(); srv.kill(); console.log("shots", n);
