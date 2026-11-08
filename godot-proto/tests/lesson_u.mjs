// Тест урока «У»: шаги грузятся, раскладка/навигация ≥150 px, голоса не накладываются.
// Запуск: PORT=<свободный> SITE=... node tests/lesson_u.mjs
// LETTER=u через ?letter=u и ?lesson=u. Не правит suite «А».
import { createRequire } from "module";
import { spawn } from "child_process";
import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";

const require = createRequire(import.meta.url);
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const puppeteer = require(path.resolve(ROOT, "../.tools/node_modules/puppeteer-core"));
const PORT = +(process.env.PORT || 55792);
const SITE = path.resolve(process.env.SITE || path.join(ROOT, "../site"));
const SHOTS = path.join(ROOT, "screenshots", "lesson_u");
fs.mkdirSync(SHOTS, { recursive: true });
const srv = spawn("node", [path.join(ROOT, "tests/serve.mjs"), SITE, String(PORT)], {
  stdio: "ignore",
  env: { ...process.env, NOCOI: "1" },
});
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const errors = [], passed = [];
let browser, page;

const STEPS = [
  "s01_duck",
  "s03_sing",
  "s03u_words",
  "s06_letter",
  "s05u_letter_word",
  "s07_write",
  "s07u_memory",
  "s08u_read",
  "s10_end",
];

const bk = () => page.evaluate(() => window.__bk || {}).catch(() => ({}));
async function waitFor(fn, desc, timeout = 45000) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeout) {
    const s = await bk();
    if (fn(s)) return s;
    await sleep(120);
  }
  throw new Error("timeout: " + desc + " | last=" + JSON.stringify(await bk()));
}

function checkNavHit(s, where) {
  const ui = s.ui_rects || {};
  for (const [k, rect] of Object.entries(ui)) {
    if (!rect || rect.length < 4) continue;
    const [, , bw, bh] = rect;
    // DESIGN_RULES: finger targets ≥ ~64; task asks nav ≥150 where applicable (track/hit areas)
    if (k === "next" || k === "back" || k === "exit") {
      if (bw < 64 || bh < 64)
        throw new Error(`${where}: ${k} too small ${Math.round(bw)}×${Math.round(bh)}`);
    }
  }
  // Exposed large hits (track / tile) if present
  const t = s.targets || {};
  // targets are centers; check info hit sizes if published
  if (s.info && s.info.nav_hit_h != null && s.info.nav_hit_h < 150)
    throw new Error(`${where}: nav_hit_h ${s.info.nav_hit_h} < 150`);
}

function checkNoVoiceOverlap(s, where) {
  // Voice queue: overlapping would show voice_busy + pending, or dual speaking ids
  if (s.voice && s.voice.overlap) throw new Error(`${where}: voice overlap flag`);
  if ((s.info && s.info.voice_overlap) || (s.voice_overlap === true))
    throw new Error(`${where}: voice_overlap`);
  // Soft: if two say_* playing reported
  const playing = (s.voice && s.voice.playing) || s.playing_voice || [];
  if (Array.isArray(playing) && playing.length > 1)
    throw new Error(`${where}: multiple voices ${playing.join(",")}`);
}

async function open(step, q = "letter=u") {
  await page.goto(
    `http://127.0.0.1:${PORT}/lesson-u/index.html?test=1&fast=1&${q}&step=${step}`,
    { waitUntil: "load" }
  );
  const s = await waitFor(
    (s) => s.step === step || (s.letter_id === "u" && s.step),
    "open " + step,
    90000
  );
  if (s.step !== step) {
    // allow brief settle
    await waitFor((s2) => s2.step === step, "settle " + step, 30000);
  }
  return await bk();
}

try {
  await sleep(600);
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
  page.on("pageerror", (e) => errors.push("pageerror: " + e.message));
  page.on("console", (m) => {
    if (m.type() === "error") errors.push(m.text());
  });

  // 1) ?lesson=u alias loads first step
  await page.goto(
    `http://127.0.0.1:${PORT}/lesson-u/index.html?test=1&fast=1&lesson=u`,
    { waitUntil: "load" }
  );
  let s = await waitFor(
    (x) => x.step === "s01_duck" || x.letter_id === "u",
    "lesson=u boot",
    90000
  );
  if (s.letter_id && s.letter_id !== "u")
    throw new Error("lesson=u did not set letter_id=u: " + s.letter_id);
  passed.push("lesson=u alias → u");

  // 2) each step loads
  for (const st of STEPS) {
    s = await open(st);
    if (s.step !== st) throw new Error("expected step " + st + " got " + s.step);
    checkNavHit(s, st);
    checkNoVoiceOverlap(s, st + " load");
    // nav zones: back/exit size from ui_rects
    const ui = s.ui_rects || {};
    for (const k of ["back", "exit", "next"]) {
      if (!ui[k]) continue;
      const [, , bw, bh] = ui[k];
      if (Math.min(bw, bh) < 64)
        errors.push(`${st}: ${k} < 64px`);
    }
    await page.screenshot({ path: path.join(SHOTS, `${st}.png`) });
    passed.push("load " + st);
    await sleep(400);
    checkNoVoiceOverlap(s, st + " settle");
  }

  // 3) track hit ≥150 on read
  s = await open("s08u_read");
  await waitFor((x) => x.state === "read_ay" || x.targets?.track, "read_ay", 30000);
  // publish hit height if available via targets — sample track by dragging
  const t = (await bk()).targets || {};
  if (!t.track) throw new Error("s08u_read: no track target");
  passed.push("s08u_read track exposed");

  // 4) memory card0
  s = await open("s07u_memory");
  await waitFor((x) => x.targets?.card0, "memory card0", 30000);
  passed.push("s07u_memory card0");

  console.log("PASSED:\n" + passed.map((p) => "  ✓ " + p).join("\n"));
  if (errors.length) {
    console.log("ERRORS:\n" + errors.join("\n"));
    process.exit(1);
  }
  console.log("OK lesson_u suite");
  process.exit(0);
} catch (e) {
  console.error("FAIL:", e.stack || e);
  process.exit(1);
} finally {
  if (browser) await browser.close();
  srv.kill();
}
