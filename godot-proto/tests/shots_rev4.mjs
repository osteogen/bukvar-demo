// Снимки rev4 (27.10: «Скажи сам» убрана, финал s11_end → s10_end): конец s09, переход s09 → «Далее» → s10_end, шаг 1 финала;
// 1024×768 и 844×390 → OUT (по умолчанию /workspace/publish/update-lesson-a-rev4-shots).
import { createRequire } from "module"; import { spawn } from "child_process"; import path from "path"; import fs from "fs"; import { fileURLToPath } from "url";
const require = createRequire(import.meta.url);
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const puppeteer = require(path.resolve(ROOT, "../.tools/node_modules/puppeteer-core"));
const PORT = +(process.env.PORT || 55851); const OUT = process.env.OUT || "/workspace/publish/update-lesson-a-rev4-shots";
fs.mkdirSync(OUT, { recursive: true });
const srv = spawn("node", [path.join(ROOT, "tests/serve.mjs"), path.join(ROOT, "build"), String(PORT)], { stdio: "ignore" });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const VPS = [[1024, 768], [844, 390]];
// [имя, шаг, действия]
const SOLVE = [["state", "wait_drag"], ["wait", 800], ["solve_s09"], ["state", "done"]];
const PLAN = [
  ["s09-sort-done", "s09_sort", [...SOLVE, ["target", "next"], ["wait", 1200]]],
  ["s09-to-s10-transition", "s09_sort", [...SOLVE, ["wait", 1200], ["tap", "next"], ["step", "s10_end"], ["wait", 250]]],
  ["s09-to-s10-arrived", "s09_sort", [...SOLVE, ["wait", 1200], ["tap", "next"], ["step", "s10_end"], ["state", "wait_sticker"], ["wait", 600]]],
  ["s10-end-step1-sticker", "s10_end", [["state", "wait_sticker"], ["wait", 600]]],
];
let browser; const errs = [];
try {
  await sleep(800);
  browser = await puppeteer.launch({ executablePath: "/usr/bin/google-chrome", headless: "new",
    args: ["--no-sandbox", "--autoplay-policy=no-user-gesture-required", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist", "--mute-audio"] });
  const page = await browser.newPage();
  for (const [w, h] of VPS) {
    await page.setViewport({ width: w, height: h });
    for (const [name, step, acts, mode] of PLAN.filter((p) => !process.env.ONLY || process.env.ONLY.split(",").includes(p[0]))) {
      try {
        await page.goto(`http://127.0.0.1:${PORT}/index.html?test=1${mode === "slow" ? "" : "&fast=1"}&step=${step}`, { waitUntil: "load" });
        await page.waitForFunction((s) => window.__bk && window.__bk.step === s, { timeout: 120000 }, step);
        for (const [k, v] of acts) {
          if (k === "wait") await sleep(v);
          else if (k === "info") await page.waitForFunction((kv) => window.__bk.info && window.__bk.info[kv[0]] === kv[1], { timeout: 60000 }, v);
          else if (k === "state") await page.waitForFunction((s) => window.__bk.state === s, { timeout: 60000 }, v);
          else if (k === "step") await page.waitForFunction((s) => window.__bk.step === s || window.__bk.step === "s10_say" && (window.__bad = 1), { timeout: 60000 }, v).then(async () => { if ((await page.evaluate(() => window.__bk.step)) !== v) throw new Error("шаг " + (await page.evaluate(() => window.__bk.step)) + " вместо " + v); });
          else if (k === "target") await page.waitForFunction((t) => window.__bk.targets && window.__bk.targets[t], { timeout: 30000 }, v);
          else if (k === "solve_s09") {   // раскладываем все плитки по своим корзинкам (координаты холста → CSS px)
            for (let n = 0; n < 30; n++) {
              const s = await page.evaluate(() => ({ st: window.__bk.state, t: window.__bk.targets, K: innerWidth / window.__bk.visible_rect[2] }));
              if (s.st === "done") break;
              const t = s.t.tile, b = s.t.tile_basket; if (!t || !b) { await sleep(200); continue; }
              await page.mouse.move(t[0] * s.K, t[1] * s.K); await page.mouse.down(); await sleep(80);
              for (let i = 1; i <= 16; i++) { await page.mouse.move((t[0] + (b[0] - t[0]) * i / 16) * s.K, (t[1] + (b[1] - t[1]) * i / 16) * s.K); await sleep(25); }
              await page.mouse.up(); await sleep(900);
            } }
          else if (k === "tap") { await page.waitForFunction((t) => window.__bk.targets && window.__bk.targets[t], { timeout: 30000 }, v);
            const [p, K] = await page.evaluate((t) => [window.__bk.targets[t], innerWidth / window.__bk.visible_rect[2]], v); await page.mouse.click(p[0] * K, p[1] * K); }   // координаты холста → CSS px
        }
        const f = path.join(OUT, `${w}x${h}-${name}.png`); await page.screenshot({ path: f }); console.log("shot", path.basename(f));
      } catch (e) { errs.push(`${w}x${h} ${name}: ${e.message}`); }
    }
  }
} finally { if (browser) await browser.close(); srv.kill(); }
console.log(errs.length ? "ERRORS:\n" + errs.join("\n") : "OK: shots");
process.exit(errs.length ? 1 : 0);
