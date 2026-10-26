// Снимки сцен, изменённых правками урока «А» 27.10.2026 (rev1): 1024×768 и 844×390 → OUT (по умолчанию /workspace/publish/update-lesson-a-rev1-shots).
import { createRequire } from "module"; import { spawn } from "child_process"; import path from "path"; import fs from "fs"; import { fileURLToPath } from "url";
const require = createRequire(import.meta.url);
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const puppeteer = require(path.resolve(ROOT, "../.tools/node_modules/puppeteer-core"));
const PORT = +(process.env.PORT || 55851); const OUT = process.env.OUT || "/workspace/publish/update-lesson-a-rev1-shots";
fs.mkdirSync(OUT, { recursive: true });
const srv = spawn("node", [path.join(ROOT, "tests/serve.mjs"), path.join(ROOT, "build"), String(PORT)], { stdio: "ignore" });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const VPS = [[1024, 768], [844, 390]];
// [имя, шаг, действия]
const PLAN = [
  ["s01-stork", "s01_stork", [["state", "done"], ["wait", 500]]],
  ["s04-hear-alya-shows", "s04_hear", [["wait", 3000]], "slow"],
  ["s04-hear-card", "s04_hear", [["state", "wait_answer_0"], ["wait", 600]]],
  ["s05-train-ride-in", "s05_words", [["wait", 700]]],
  ["s05-train-cells", "s05_words", [["state", "wait_pic_0"], ["wait", 600]]],
  ["s06-letter-highlight", "s06_letter", [["wait", 4000]], "slow"],
  ["s07-write", "s07_write", [["wait", 1500]]],
  ["s08-find-stars-cloud", "s08_find", [["wait", 3500]]],
  ["s09-sort-sun", "s09_sort", [["wait", 2500]]],
  ["s10-say-sound-card", "s10_say", [["state", "wait_parent_0"], ["wait", 600]]],
  ["s10-say-parent-buttons", "s10_say", [["state", "wait_parent_0"], ["wait", 1800], ["tap", "parent_ok"], ["state", "wait_parent_1"], ["wait", 600]]],
  ["s11-end-sticker", "s11_end", [["state", "wait_sticker"], ["wait", 600]]],
  ["s11-end-album", "s11_end", [["state", "wait_sticker"], ["wait", 1500], ["tap", "sticker"], ["wait", 2200]]],
  ["exit-bye", "s05_words", [["wait", 1500], ["tap", "exit"], ["wait", 250]]],
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
          else if (k === "state") await page.waitForFunction((s) => window.__bk.state === s, { timeout: 60000 }, v);
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
