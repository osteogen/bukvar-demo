// Проходит все 31 коротких урока мышью/касанием без файлов озвучки.
// PORT=<свободный> SITE=<сайт> node tests/intro31.mjs
import { createRequire } from "module";
import { spawn } from "child_process";
import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";

const require = createRequire(import.meta.url);
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const puppeteer = require(path.resolve(ROOT, "../.tools/node_modules/puppeteer-core"));
const PORT = +(process.env.PORT || 55931);
const TOUCH = process.env.TOUCH !== "0";
const SITE = path.resolve(process.env.SITE || path.join(ROOT, "../site"));
const SHOTS = path.resolve(process.env.SHOTS || path.join(ROOT, "../docs/intro31-screenshots"));
fs.mkdirSync(SHOTS, { recursive: true });
const ONLY = (process.env.ONLY || "").split(",").filter(Boolean);
const srv = spawn("node", [path.join(ROOT, "tests/serve.mjs"), SITE, String(PORT)], { stdio: "ignore", env: { ...process.env, NOCOI: "1" } });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const errors = [];
let browser, page;

const LETTERS = ["m","h","o","sh","r","s","y","l","n","k","p","t","v","z","zh","soft","i","e","d","b","g","j","ch","eh","yo","ya","yu","ts","sch","f","hard"];
const ILL = ["m", "h", "o", "sh", "r", "s", "y", "l", "n", "k", "p", "t", "v", "z", "zh", "soft", "i", "e", "d", "b", "g", "j", "ch", "eh", "yo", "ya", "yu", "ts", "sch", "f", "hard"];
const SHOT = { m: "consonant-m", e: "iotated-e", soft: "sign-soft" };

const bk = async () => page.evaluate(() => window.__bk || {}).catch(() => ({}));
async function waitFor(fn, desc, timeout = 25000) {
  const t0 = Date.now();
  let last = {};
  while (Date.now() - t0 < timeout) {
    last = await bk();
    if (fn(last)) return last;
    await sleep(80);
  }
  throw new Error("timeout: " + desc + " | " + JSON.stringify({ step: last.step, state: last.state, kind: last.info && last.info.intro_kind, heard: last.info && last.info.heard, targets: last.targets && Object.keys(last.targets) }));
}
async function press(x, y) {
  if (TOUCH) {
    await page.touchscreen.touchStart(x, y);
    await sleep(80);
    await page.touchscreen.touchEnd();
  } else {
    await page.mouse.move(x, y);
    await page.mouse.down();
    await sleep(80);
    await page.mouse.up();
  }
}
async function tap(name) {
  const s = await waitFor((s) => s.targets && s.targets[name], "target " + name);
  const [x, y] = s.targets[name];
  let after = s;
  for (let i = 0; i < 3; i++) {
    const before = await bk();
    await press(x, y);
    await sleep(450);
    after = await bk();
    const moved = after.state !== before.state || JSON.stringify(after.info && after.info.heard) !== JSON.stringify(before.info && before.info.heard) || (after.targets && before.targets && !!after.targets.dots_2 !== !!before.targets.dots_2);
    if (moved || after.state === "done") break;
  }
  if (process.env.DEBUG) console.log("tap", name, x, y, "->", after.state);
  return after;
}
async function drag(from, to) {
  const steps = 14;
  if (TOUCH) {
    await page.touchscreen.touchStart(from[0], from[1]);
    await sleep(40);
    for (let i = 1; i <= steps; i++) {
      await page.touchscreen.touchMove(from[0] + (to[0] - from[0]) * i / steps, from[1] + (to[1] - from[1]) * i / steps);
      await sleep(20);
    }
    await page.touchscreen.touchEnd();
  } else {
    await page.mouse.move(from[0], from[1]);
    await page.mouse.down();
    await page.mouse.move(to[0], to[1], { steps });
    await page.mouse.up();
  }
  await sleep(150);
}
function gap(a, b) {
  const dx = Math.max(b[0] - (a[0] + a[2]), a[0] - (b[0] + b[2]), 0);
  const dy = Math.max(b[1] - (a[1] + a[3]), a[1] - (b[1] + b[3]), 0);
  return Math.hypot(dx, dy);
}

async function playScene(id) {
  const s0 = await waitFor((s) => s.state && s.state.startsWith("wait"), "wait " + id, 90000);
  const kind = s0.info.intro_kind;
  if (kind === "meet") {
    await tap("letter_big");
  } else if (kind === "locate" || kind === "soft_hear") {
    if (id === "m" && kind === "locate") {
      const wrong = s0.info.correct === 1 ? "slot_2" : "slot_1";
      await tap(wrong);
      await waitFor((s) => s.state === "wait_slot", "ошибка не сбросила сцену");
    }
    await tap("slot_" + s0.info.correct);
  } else if (kind === "trace") {
    const n = s0.info.cards || 1;
    for (let i = 0; i < n; i++) {
      for (let attempt = 0; attempt < 3; attempt++) {
        const s = await waitFor((s) => s.state === "wait_trace" && s.info.card_i === i && s.targets.track_l, "дорожка " + i);
        await drag(s.targets.track_l, s.targets.track_r);
        await sleep(200);
        const now = await bk();
        if (now.info.card_i !== i || now.state !== "wait_trace") break;
      }
    }
  } else if (kind === "two_dots") {
    await tap("ear_1");
    await waitFor((s) => (s.info.heard || 0) >= 1, "первое ухо");
    await tap("ear_2");
    await waitFor((s) => s.state === "wait_dots" && s.targets.dots_2, "две точки");
    await tap("dots_1");
    await waitFor((s) => s.state === "wait_dots", "одна точка прошла как верная");
    if (id === "e") await page.screenshot({ path: path.join(SHOTS, "e-play-s2-dots.png") });
    await tap("dots_2");
  } else if (kind === "choose_trace") {
    await tap("card_0");
    await waitFor((s) => (s.info.heard || 0) >= 1, "слог 1");
    await tap("card_1");
    await waitFor((s) => (s.info.heard || 0) >= 2 && s.state === "wait_syll", "оба слога, выбор ещё впереди");
    await tap("card_0");
    await waitFor((s) => s.state === "wait_syll", "ла не открыла дорожку");
    await tap("card_1");
    await waitFor((s) => s.state === "wait_trace" && s.info.sounds === 2, "выбрано ле, два звука");
    if (id === "e") await page.screenshot({ path: path.join(SHOTS, "e-play-s3-trace.png") });
    for (let attempt = 0; attempt < 3; attempt++) {
      const s = await waitFor((s) => s.state === "wait_trace" && s.targets.track_l, "дорожка слога");
      await drag(s.targets.track_l, s.targets.track_r);
      await sleep(200);
      if ((await bk()).state !== "wait_trace") break;
    }
  } else if (kind === "soft_sign") {
    await tap("pick_bad");
    await waitFor((s) => s.state === "wait_sign", "чужой знак прошёл");
    await tap("pick_ok");
    for (let attempt = 0; attempt < 3; attempt++) {
      const s = await waitFor((s) => s.state === "wait_trace" && s.targets.track_l, "дорожка конь");
      await drag(s.targets.track_l, s.targets.track_r);
      await sleep(200);
      if ((await bk()).state !== "wait_trace") break;
    }
  } else if (kind === "hard_pair" || kind === "hard_compare") {
    if (kind === "hard_compare") {
      const earlyTarget = await waitFor((s) => s.targets && s.targets.hear_1, "лью");
      await press(earlyTarget.targets.hear_1[0], earlyTarget.targets.hear_1[1]);
      await sleep(500);
      const early = await bk();
      if ((early.info.heard || 0) !== 0 || early.state !== "wait_hear") throw new Error("лью раньше лю засчиталось");
    }
    await tap("hear_0");
    await waitFor((s) => (s.info.heard || 0) >= 1 && s.targets.hear_1, "второй образец");
    await tap("hear_1");
    await waitFor((s) => s.state === "wait_pick" && s.targets.pick_ok, "выбор");
    await tap("pick_bad");
    await waitFor((s) => s.state === "wait_pick", "неверный выбор прошёл");
    await tap("pick_ok");
  } else if (kind === "picture" || kind === "text" || kind === "hard_sign") {
    if (kind === "hard_sign") {
      await tap("ear");
      await waitFor((s) => s.state === "wait_choice", "модель съел");
    }
    if ((kind === "picture" || kind === "text") && ILL.includes(id)) {
      await tap("pick_bad");
      await waitFor((s) => s.state === "wait_choice", "неверный выбор прошёл");
    }
    await tap("pick_ok");
  } else throw new Error("неизвестный вид " + kind);
  return waitFor((s) => s.state === "done" && s.targets.next, "готово " + kind + " " + id, 20000);
}

async function lesson(id) {
  const url = `http://127.0.0.1:${PORT}/lesson-a/index.html?test=1&fast=1&letter=${id}&step=intro_s1`;
  await page.goto(url, { waitUntil: "load", timeout: 120000 });
  for (let n = 1; n <= 4; n++) {
    await waitFor((s) => s.step === "intro_s" + n && s.letter_id === id, "сцена " + n + " " + id, 90000);
    if (ILL.includes(id)) {
      const ready = n === 1 ? (s) => s.state === "wait_letter" && s.targets.letter_big : (s) => s.state && s.state.startsWith("wait");
      await waitFor(ready, "кадр " + id + " " + n);
      await page.waitForFunction(() => !document.getElementById("status"), { timeout: 5000 }).catch(() => {});
      await page.screenshot({ path: path.join(SHOTS, id + "-play-s" + n + ".png") });
    } else if (SHOT[id] && n === 1) {
      await waitFor((s) => s.state === "wait_letter" && s.targets.letter_big, "кадр знакомства");
      await page.waitForFunction(() => !document.getElementById("status"), { timeout: 5000 }).catch(() => {});
      await page.screenshot({ path: path.join(SHOTS, SHOT[id] + "-s1.png") });
    }
    const done = await playScene(id);
    if ((done.ui_overlaps || []).length) throw new Error(id + " s" + n + " перекрытия: " + done.ui_overlaps.join(", "));
    if (["e", "yo", "ya", "yu"].includes(id) && n === 2 && !done.info.rest) throw new Error(id + ": после двух звуков нет перерыва");
    if (id === "hard" && n === 4 && !done.info.rest) throw new Error("ъ: после выбора нет отдыха");
    if (id === "hard" && n === 4 && !done.targets.next) throw new Error("ъ: после отдыха нет «Далее»");
    if (n < 4) await tap("next");
    if (["e", "yo", "ya", "yu"].includes(id) && n === 2) {
      await waitFor((s) => s.step === "intro_s3" && s.letter_id === id, id + "3 после перерыва");
      const back = (await bk()).ui_rects.back;
      await press(back[0] + back[2] / 2, back[1] + back[3] / 2);
      await waitFor((s) => s.step === "intro_s2" && s.targets && s.targets.next, "возврат к пройденной " + id + "2");
      await tap("next");
      await waitFor((s) => s.step === "intro_s3" && s.letter_id === id, "снова " + id + "3");
    }
    if (id === "hard" && n === 2) {
      await waitFor((s) => s.step === "intro_s3" && s.letter_id === "hard", "ъ3 после сел/съел");
      const back = (await bk()).ui_rects.back;
      await press(back[0] + back[2] / 2, back[1] + back[3] / 2);
      await waitFor((s) => s.step === "intro_s2" && s.targets && s.targets.next, "возврат к пройденной ъ2");
      await tap("next");
      await waitFor((s) => s.step === "intro_s3" && s.letter_id === "hard", "снова ъ3");
    }
  }
  const end = await bk();
  if (!end.targets.again || !end.targets.sticker) throw new Error(id + ": нет наклейки или «Ещё раз»");
  if (ILL.includes(id)) await page.screenshot({ path: path.join(SHOTS, id + "-play-s4-done.png") });
  else if (SHOT[id]) await page.screenshot({ path: path.join(SHOTS, SHOT[id] + "-s4.png") });
  if (id === "m") {
    await tap("again");
    await waitFor((s) => s.step === "intro_s4" && s.state && s.state.startsWith("wait"), "Ещё раз");
    await playScene("m");
  }
  console.log("OK", id, end.info.intro_kind);
}

async function spacing() {
  await page.setViewport({ width: 1024, height: 768, deviceScaleFactor: 1 });
  for (const id of ["m", "r", "s", "y", "l", "n", "k", "p", "t", "v", "z", "zh", "soft", "i", "e", "d", "b", "g", "j", "ch", "eh", "yo", "ya", "yu", "ts", "sch", "f", "hard"]) {
    await page.goto(`http://127.0.0.1:${PORT}/lesson-a/index.html?test=1&fast=1&letter=${id}&step=intro_s1`, { waitUntil: "load" });
    const s = await waitFor((s) => s.state === "wait_letter" && s.info.item_rects && s.letter_id === id, "раскладка " + id, 90000);
    const btns = s.ui_rects || {};
    for (const it of s.info.item_rects) {
      if (it[2] < 2 || it[3] < 2) continue;
      for (const name of ["back", "exit", "next"]) {
        const g = gap(it, btns[name]);
        if (g < 150) throw new Error(`${id}: «${it[4]}» ближе 150 px к ${name}: ${g.toFixed(0)}`);
      }
    }
    console.log("OK spacing", id, "1024×768, предметов", s.info.item_rects.length);
  }
}

async function responsive(size) {
  await page.setViewport({ width: size[0], height: size[1], deviceScaleFactor: 1 });
  await page.goto(`http://127.0.0.1:${PORT}/lesson-a/index.html?test=1&fast=1&letter=o&step=intro_s4`, { waitUntil: "load" });
  const s = await waitFor((s) => s.state === "wait_choice" && s.targets.pick_ok && s.targets.exit, size.join("x"), 90000);
  if ((s.ui_overlaps || []).length) throw new Error(size.join("x") + " перекрытия: " + s.ui_overlaps.join(", "));
  const canvas = await page.evaluate(() => { const r = document.querySelector("canvas").getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width, h: r.height }; });
  const [vx, vy, vw, vh] = s.visible_rect;
  const [gx, gy] = s.targets.pick_ok;
  const x = canvas.x + (gx - vx) / vw * canvas.w;
  const y = canvas.y + (gy - vy) / vh * canvas.h;
  if (x < 8 || y < 8 || x > canvas.w - 8 || y > canvas.h - 8) throw new Error(size.join("x") + " цель вне холста " + Math.round(x) + "," + Math.round(y));
  await page.screenshot({ path: path.join(SHOTS, `vowel-o-s4-${size[0]}x${size[1]}.png`) });
  console.log("OK layout", size.join("×"));
}

try {
  browser = await puppeteer.launch({ executablePath: "/usr/bin/google-chrome", headless: "new", args: ["--no-sandbox", "--disable-dev-shm-usage"] });
  page = await browser.newPage();
  page.on("pageerror", (e) => errors.push(String(e)));
  page.on("console", (msg) => { if (msg.type() === "error") errors.push(msg.text()); });
  await page.setViewport({ width: 1024, height: 768, deviceScaleFactor: 1 });
  const list = ONLY.length ? ONLY : LETTERS;
  for (const id of list) await lesson(id);
  if (!ONLY.length) {
    await spacing();
    await responsive([844, 390]);
    await responsive([390, 844]);
    for (const id of ["h", "sh", "d", "b", "g", "j", "ch", "eh", "yo", "ya", "yu", "ts", "sch", "f"]) {

      for (const size of [[844, 390], [390, 844]]) {
        await page.setViewport({ width: size[0], height: size[1], deviceScaleFactor: 1 });
        await page.goto(`http://127.0.0.1:${PORT}/lesson-a/index.html?test=1&fast=1&letter=${id}&step=intro_s4`, { waitUntil: "load" });
        const s = await waitFor((s) => s.state === "wait_choice" && s.targets.pick_ok && s.letter_id === id, id + " " + size.join("x"), 90000);
        if ((s.ui_overlaps || []).length) throw new Error(id + " " + size.join("x") + " перекрытия: " + s.ui_overlaps.join(", "));
        console.log("OK layout", id, size.join("×"));
      }
    }
    for (const size of [[844, 390], [390, 844]]) {
      await page.setViewport({ width: size[0], height: size[1], deviceScaleFactor: 1 });
      for (const step of ["intro_s2", "intro_s4"]) {
        await page.goto(`http://127.0.0.1:${PORT}/lesson-a/index.html?test=1&fast=1&letter=hard&step=${step}`, { waitUntil: "load" });
        const s = await waitFor((s) => s.letter_id === "hard" && s.step === step && s.state && s.state.startsWith("wait") && s.targets.exit, "ъ " + step + " " + size.join("x"), 90000);
        if ((s.ui_overlaps || []).length) throw new Error("ъ " + step + " " + size.join("x") + " перекрытия: " + s.ui_overlaps.join(", "));
        console.log("OK layout hard", step, size.join("×"));
      }
    }
  }
  const bad = errors.filter((e) => !/favicon|Download the React DevTools|wasm streaming/i.test(e));
  if (bad.length) throw new Error("ошибки страницы:\n" + bad.slice(0, 8).join("\n"));
  console.log("OK intro31 flow", list.length, "letters");
} catch (e) {
  console.error("FAIL", e && e.stack || e);
  process.exitCode = 1;
} finally {
  if (browser) await browser.close();
  srv.kill();
}
