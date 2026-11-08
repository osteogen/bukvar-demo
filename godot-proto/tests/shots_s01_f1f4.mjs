// F1–F4 equivalents from real s01_duck (letter=u). Phases via window.__bk.info.s01u_phase.
import { createRequire } from "module";
import { spawn } from "child_process";
import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";

const require = createRequire(import.meta.url);
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const puppeteer = require(path.resolve(ROOT, "../.tools/node_modules/puppeteer-core"));
const PORT = +(process.env.PORT || 56301);
const SITE = path.resolve(process.env.SITE || path.join(ROOT, "../site"));
const OUT = path.resolve(process.env.OUT || path.join(ROOT, "../publish/update-lesson-u-scaffold-shots"));
fs.mkdirSync(OUT, { recursive: true });
const srv = spawn("node", [path.join(ROOT, "tests/serve.mjs"), SITE, String(PORT)], {
  stdio: "ignore",
  env: { ...process.env, NOCOI: "1" },
});
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const bk = () => page.evaluate(() => window.__bk || {}).catch(() => ({}));

let browser, page;
try {
  await sleep(500);
  browser = await puppeteer.launch({
    executablePath: "/usr/bin/google-chrome",
    headless: "new",
    args: [
      "--no-sandbox",
      "--use-angle=swiftshader",
      "--enable-unsafe-swiftshader",
      "--ignore-gpu-blocklist",
      "--mute-audio",
      "--autoplay-policy=no-user-gesture-required",
    ],
  });
  page = await browser.newPage();
  await page.setViewport({ width: 1024, height: 768, hasTouch: true });
  // Real tempo so walk/cue/quack land; test=1 for __bk
  await page.goto(
    `http://127.0.0.1:${PORT}/lesson-u/index.html?test=1&letter=u&step=s01_duck`,
    { waitUntil: "load" }
  );
  const waitPhase = async (want, timeout = 20000) => {
    const t0 = Date.now();
    let last = "";
    while (Date.now() - t0 < timeout) {
      const s = await bk();
      const ph = (s.info && s.info.s01u_phase) || s.state || "";
      last = ph;
      if (want.includes(ph)) return s;
      await sleep(80);
    }
    throw new Error("timeout phase " + want.join("|") + " last=" + last);
  };
  await waitPhase(["enter", "alya_line"], 90000);
  // F1: walking + idle (alya_line)
  await waitPhase(["alya_line"], 15000);
  await sleep(400);
  let f = path.join(OUT, "f1-alya-line.png");
  await page.screenshot({ path: f });
  console.log("shot", path.basename(f));

  await waitPhase(["pull_sign"], 15000);
  await sleep(200);
  f = path.join(OUT, "f2-pull-sign.png");
  await page.screenshot({ path: f });
  console.log("shot", path.basename(f));

  await waitPhase(["quack"], 15000);
  await sleep(100);
  f = path.join(OUT, "f3-quack.png");
  await page.screenshot({ path: f });
  console.log("shot", path.basename(f));

  await waitPhase(["wait_tap", "enlarge"], 15000);
  await waitPhase(["wait_tap"], 10000);
  await sleep(200);
  f = path.join(OUT, "f4-sign-full.png");
  await page.screenshot({ path: f });
  console.log("shot", path.basename(f));

  // Also numbered suite shots 01–09 from lesson_u screenshots later
  console.log("OK F1–F4 →", OUT);
  process.exit(0);
} catch (e) {
  console.error("FAIL", e.stack || e);
  try {
    await page.screenshot({ path: path.join(OUT, "FAIL-s01.png") });
  } catch {}
  process.exit(1);
} finally {
  if (browser) await browser.close();
  srv.kill();
}
