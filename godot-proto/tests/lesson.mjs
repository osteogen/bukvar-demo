// Сквозной тест урока «А» в headless Chrome: проходит все шаги s01…s10 КАСАНИЯМИ (touch-события, как на планшете),
// делает ошибки там, где это нужно для проверки реакций, снимает скриншоты.
// Сайт как в CI: корень — HTML-главная (web-home/), урок — lesson-a/ (сборка: bash tests/assemble_site.sh).
// Вход: главная → «А» → lesson-a/ → сразу s01 (экрана для взрослого s00 больше нет) → s01…s10.
// Звук на iOS: в вебе без жеста на странице s01 ждёт касания (Аля пульсирует, wait_unlock); в тесте выключено, ?gate=1 — включить.
// Плюс: крестик выхода на s01–s10 (виден, ни с чем не пересекается) → главная → «А» → s01; «домой» в s10 → главная;
// рука-подсказка после бездействия (?hint_sec=3 — укороченный таймер; по умолчанию 20 с из data/common/hint.json): держится до нужного действия,
// касание цели / начало перетаскивания прячет её, касание мимо — нет. На главной руки нет (tests/home.mjs).
// Запуск: PORT=<свободный> node tests/lesson.mjs     (TOUCH=0 — мышью; URLQ="audio=stream" — доп. параметры; SITE=папка сайта)
import { createRequire } from "module"; import { spawn } from "child_process"; import path from "path"; import fs from "fs"; import { fileURLToPath } from "url";
const require = createRequire(import.meta.url);
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const puppeteer = require(path.resolve(ROOT, "../.tools/node_modules/puppeteer-core"));
const PORT = +(process.env.PORT || 55782);
const TOUCH = process.env.TOUCH !== "0";
const SHOTS = path.join(ROOT, "screenshots"); fs.mkdirSync(SHOTS, { recursive: true });
const SITE = path.resolve(process.env.SITE || path.join(ROOT, "../site"));
const srv = spawn("node", [path.join(ROOT, "tests/serve.mjs"), SITE, String(PORT)], { stdio: "ignore", env: { ...process.env, NOCOI: "1" } });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const errors = [], logs = [], passed = []; let browser, page;
// Без ?debug=1 субтитров быть не должно, а из текста на экране ребёнка — только А/а
// (исключение: открытая взрослым панель итога в s10).
const textViolations = new Set();
const ALLOWED = new Set(["А", "а"]);
const bk = async () => {
  const s = await page.evaluate(() => window.__bk || {}).catch(() => ({}));
  if (s.caption_visible || s.caption_ever_visible) textViolations.add("субтитр виден: " + (s.step || "") + " «" + (s.caption || "") + "»");
  if (s.step && s.step !== "letters_menu" && !(s.info && s.info.parent_panel))
    for (const t of s.labels_visible || []) if (!ALLOWED.has(t.trim())) textViolations.add("текст на экране " + s.step + ": «" + t + "»");
  return s;
};
async function creamAt(x, y) {   // пиксель ≈ #F7F0DE
  const b64 = await page.screenshot({ clip: { x: Math.round(x) - 2, y: Math.round(y) - 2, width: 4, height: 4 }, encoding: "base64" });
  return page.evaluate(async (b) => { const img = new Image(); img.src = "data:image/png;base64," + b; await img.decode();
    const c = document.createElement("canvas"); c.width = 4; c.height = 4; const g = c.getContext("2d"); g.drawImage(img, 0, 0);
    const d = g.getImageData(1, 1, 1, 1).data; return Math.abs(d[0] - 247) < 10 && Math.abs(d[1] - 240) < 10 && Math.abs(d[2] - 222) < 12; }, b64);
}
// доля «красных» пикселей (оттенок гласных #D93A2B и глянцевый красный; коралл #E07A4E — не красный) в прямоугольнике экрана
async function redFraction(rect, lo = 12, hi = 345) {
  const [x, y, w, h] = rect.map(Math.round);
  const b64 = await page.screenshot({ clip: { x, y, width: w, height: h }, encoding: "base64" });
  return page.evaluate(async (b, lo, hi) => {
    const img = new Image(); img.src = "data:image/png;base64," + b; await img.decode();
    const c = document.createElement("canvas"); c.width = img.width; c.height = img.height;
    const g = c.getContext("2d"); g.drawImage(img, 0, 0); const d = g.getImageData(0, 0, c.width, c.height).data;
    let red = 0;
    for (let i = 0; i < d.length; i += 4) {
      const r = d[i] / 255, gg = d[i + 1] / 255, bb = d[i + 2] / 255, mx = Math.max(r, gg, bb), mn = Math.min(r, gg, bb);
      if (mx < 0.45 || mx - mn < 0.45 * mx) continue;
      let hue = mx === r ? ((gg - bb) / (mx - mn)) * 60 : mx === gg ? (2 + (bb - r) / (mx - mn)) * 60 : (4 + (r - gg) / (mx - mn)) * 60;
      if (hue < 0) hue += 360;
      if (lo < hi ? (hue < lo || hue > hi) : (hue >= hi && hue <= lo)) red++;
    }
    return red / (d.length / 4);
  }, b64, lo, hi);
}
async function waitFor(fn, desc, timeout = 30000) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeout) { const s = await bk(); if (fn(s)) return s; await sleep(100); }
  throw new Error("timeout: " + desc + " | last=" + JSON.stringify(await bk()));
}
const target = async (name, timeout) => (await waitFor((s) => s.targets && s.targets[name], "target " + name, timeout)).targets[name];
async function tap(name, timeout) {
  const [x, y] = await target(name, timeout);
  if (TOUCH) await page.touchscreen.tap(x, y); else await page.mouse.click(x, y);
  await sleep(150);
}
async function drag(from, to, steps = 18, holdMs = 0) {
  if (TOUCH) {
    await page.touchscreen.touchStart(from[0], from[1]); await sleep(60 + holdMs);
    for (let i = 1; i <= steps; i++) { await page.touchscreen.touchMove(from[0] + (to[0] - from[0]) * i / steps, from[1] + (to[1] - from[1]) * i / steps); await sleep(25); }
    await page.touchscreen.touchEnd();
  } else {
    await page.mouse.move(from[0], from[1]); await page.mouse.down(); await sleep(60 + holdMs);
    await page.mouse.move(to[0], to[1], { steps }); await page.mouse.up();
  }
  await sleep(150);
}
// HTML-главная (window.__home) и переходы между страницами
const home = () => page.evaluate(() => window.__home || {}).catch(() => ({}));
async function homeReady(desc) {
  const t0 = Date.now();
  while (Date.now() - t0 < 15000) { const h = await home(); if (h.state === "wait_letter") return h; await sleep(100); }
  throw new Error("timeout: " + desc + " (главная) | url=" + page.url());
}
async function tapXY([x, y]) { if (TOUCH) await page.touchscreen.tap(x, y); else await page.mouse.click(x, y); }
async function tapNav(xy, what) {
  try { await Promise.all([page.waitForNavigation({ waitUntil: "load", timeout: 15000 }), tapXY(xy)]); }
  catch (e) { throw new Error(`нет перехода после «${what}» (${page.url()}): ${e.message}`); }
}
async function homeToLesson() {   // главная: тап «А» → lesson-a/ → сразу s01
  const h = await homeReady("перед «А»"); await sleep(400);
  await tapNav(h.targets.letter_a, "А на главной");
  if (!/\/lesson-a\/(index\.html)?\?/.test(page.url())) throw new Error("«А» открыла не lesson-a/: " + page.url());
  const s = await waitFor((s) => s.step === "s01_intro" && s.state === "wait_alya", "lesson-a → s01 (без экрана s00)", 120000);
  await sleep(600);   // свежая загрузка Godot: первые ~300 мс касания не доходят
  return s;
}
const shot = async (name) => { await page.screenshot({ path: path.join(SHOTS, name + ".png") }); };
const state = (st) => (s) => s.state === st;
// крестик выхода: виден в правом верхнем углу и не пересекается с кнопками/альбомом экрана
const exitSeen = new Set();
async function checkExit(where) {
  const s = await waitFor((s) => s.targets && s.targets.exit, "exit button on " + where, 10000);
  const [x, y] = s.targets.exit;
  if (x < 900 || y > 100) throw new Error(`${where}: крестик не в правом верхнем углу (${x}, ${y})`);
  if ((s.exit_overlaps || []).length) throw new Error(`${where}: крестик перекрывает ${s.exit_overlaps.join(", ")}`);
  exitSeen.add(s.step);
}
// Правило «без автоподтверждения» (DESIGN_RULES.md, §1): после неверных попыток шаг ждёт верного ответа —
// состояние не меняется, нет звука успеха (sfx_ok/sfx_cheer), шарик не лопается, «Далее» не появляется.
const SUCCESS_SFX = ["sfx_ok", "sfx_cheer", "sfx_pop"];
const sfxSnap = (s) => Object.fromEntries(SUCCESS_SFX.map((k) => [k, (s.sfx_counts || {})[k] || 0]));
async function assertNoConfirm(where, st, before, ms = 0) {
  if (ms) await sleep(ms);
  const s = await bk();
  if (s.state !== st) throw new Error(`${where}: после неверных попыток шаг подтвердился сам (состояние ${st} → ${s.state})`);
  const now = sfxSnap(s);
  for (const k of SUCCESS_SFX) if (now[k] !== before[k]) throw new Error(`${where}: после неверной попытки прозвучал ${k} (${before[k]} → ${now[k]})`);
  if (s.targets && s.targets.next) throw new Error(`${where}: «Далее» появилась без верного ответа`);
  return s;
}
const noConfirmChecked = [];
async function hintNear(where, name, maxD = 160, timeout = 8000) {
  const s = await waitFor((s) => s.targets && s.targets.hint_hand && s.targets[name], `${where}: рука-подсказка после ошибок`, timeout);
  const [hx, hy] = s.targets.hint_hand, [tx, ty] = s.targets[name];
  if (Math.hypot(hx - tx, hy - ty) > maxD) throw new Error(`${where}: рука-подсказка не у верного ответа «${name}» (${hx},${hy} vs ${tx},${ty})`);
}
async function next(fromStep) {
  await checkExit(fromStep);
  await tap("next", 40000);
  await waitFor((s) => s.step && s.step !== fromStep, "leave " + fromStep);
  passed.push(fromStep);
}
try {
  await sleep(800);
  browser = await puppeteer.launch({ executablePath: "/usr/bin/google-chrome", headless: "new",
    args: ["--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist", "--mute-audio"] });
  page = await browser.newPage();
  await page.setViewport({ width: 1024, height: 768, hasTouch: TOUCH, isMobile: false });
  page.on("console", (m) => { logs.push(m.type() + ": " + m.text()); if (m.type() === "error") errors.push(m.text()); });
  page.on("pageerror", (e) => errors.push("pageerror: " + e.message));
  const t0 = Date.now();
  const q = "test=1&fast=1" + (process.env.URLQ ? "&" + process.env.URLQ : "");
  await page.goto(`http://127.0.0.1:${PORT}/?${q}`, { waitUntil: "load" });
  // сайт открывается HTML-главной (Godot не грузится), «А» → урок → сразу сцена 1 (экрана для взрослого нет)
  await homeReady("старт");
  await homeToLesson();
  console.log("ready ms (главная → урок → s01)", Date.now() - t0);
  passed.push("главная→«А»→s01");
  { const s = await bk(); if (s.targets.start || s.targets.junior) throw new Error("на старте урока остались «Начнём!»/младший режим"); }
  // s01
  await shot("s01-intro"); await tap("alya");
  await sleep(900); await shot("s01-intro-sing");   // песенка у кроватки (поза alya_pose_sing_crib)
  await waitFor(state("done"), "s01 done"); await next("s01_intro");
  // s02: «нажми и держи»
  await waitFor(state("wait_hold"), "s02 wait_hold"); await shot("s02-sing");
  { // короткие нажатия (неудачные попытки) не засчитываются — шаг ждёт удержания
    const c = await target("circle"); const b0 = sfxSnap(await bk());
    for (let n = 0; n < 3; n++) { await drag(c, c, 1, 200); await sleep(900); }
    await assertNoConfirm("s02 (3 коротких нажатия)", "wait_hold", b0); noConfirmChecked.push("s02");
    await drag(c, c, 1, 2400); }
  await waitFor(state("done"), "s02 done"); await shot("s02-sing-done"); await next("s02_sing");
  // s03: поезд въезжает слева → картинка → окошко; на каждом слове две ошибки (середина), потом верно (начало)
  for (let i = 0; i < 3; i++) {
    { // въезд: центр состава движется слева направо; паровоз справа
      const s0 = await waitFor((s) => (s.state === "drive_in_" + i || s.state === "wait_pic_" + i) && s.targets && s.targets.train, "s03 train " + i);
      const x0 = s0.targets.train[0];
      const s1 = await waitFor(state("wait_pic_" + i), "s03 pic " + i);
      const x1 = s1.targets.train[0];
      if (s0.state === "drive_in_" + i && !(x1 > x0 + 20)) throw new Error(`s03: поезд ${i} не въехал слева направо (${x0} → ${x1})`);
      if (Math.abs(x1 - 512) > 40) throw new Error(`s03: поезд ${i} остановился не по центру (${x1})`);
      if (s1.info.s03_cards_visible !== 1) throw new Error(`s03: на сцене ${s1.info.s03_cards_visible} карточек вместо одной (слово ${i})`);
      console.log(`s03 слово ${i + 1}: поезд въехал ${s0.state === "drive_in_" + i ? Math.round(x0) + "→" : ""}${Math.round(x1)}, карточек на сцене: 1`);
    }
    await tap("pic");
    await waitFor(state("wait_slot_" + i), "s03 slot " + i);
    { const st = "wait_slot_" + i; const b0 = sfxSnap(await bk()); const tx = (await bk()).targets.train[0];
      for (let n = 0; n < 2; n++) { await tap("slot1"); await sleep(1300); }
      const s = await assertNoConfirm(`s03 слово ${i + 1} (2 ошибки)`, st, b0);
      if (Math.abs(s.targets.train[0] - tx) > 8) throw new Error(`s03: поезд поехал без верного ответа (слово ${i + 1})`);
      await hintNear(`s03 слово ${i + 1}`, "slot0");
      if (i === 0) noConfirmChecked.push("s03"); }
    // «Далее» не должна появляться, пока не посажен кружок у третьей картинки
    const nx = await page.evaluate(() => !!(window.__bk && window.__bk.targets && window.__bk.targets.next));
    if (nx) throw new Error("s03: кнопка «Далее» видна до третьей картинки (картинка " + (i + 1) + ")");
    if (i === 1) { await tap("slot2"); await sleep(1200); }
    await tap("slot0");
    { // после верного ответа поезд уезжает вправо, карточка отгаданного слова исчезает
      const s0 = await waitFor((s) => s.state === "drive_out_" + i || (s.info && s.info.s03_left === i), "s03 drive_out " + i, 20000);
      const x0 = s0.targets.train ? s0.targets.train[0] : 0;
      const s1 = await waitFor((s) => s.info && s.info.s03_left === i, "s03 left " + i, 20000);
      if (s1.info.s03_cards_visible !== 0) throw new Error(`s03: карточка слова ${i + 1} осталась после отъезда поезда`);
      console.log(`s03 слово ${i + 1}: поезд уехал вправо (от x=${Math.round(x0)}), карточек осталось: ${s1.info.s03_cards_visible}`);
    }
  }
  await waitFor(state("done"), "s03 done");
  if (!(await page.evaluate(() => !!(window.__bk.targets && window.__bk.targets.next)))) throw new Error("s03: нет «Далее» после третьей картинки");
  console.log("s03: «Далее» появилась только после третьей картинки");
  await shot("s03-words-done"); await next("s03_words");
  // s04: есть/нет (на «кот» — одна ошибка)
  const ans = ["yes", "no", "yes", "no", "yes"];
  for (let i = 0; i < 5; i++) {
    await waitFor(state("wait_answer_" + i), "s04 answer " + i);
    if (i === 0) await shot("s04-hear");
    if (i === 1) { // «кот»: две ошибки подряд — шаг ждёт, рука показывает «нет»
      const b0 = sfxSnap(await bk());
      for (let n = 0; n < 2; n++) { await tap("yes"); await sleep(1600); }
      await assertNoConfirm("s04 «кот» (2 ошибки)", "wait_answer_1", b0);
      await hintNear("s04 «кот»", "no"); noConfirmChecked.push("s04"); }
    await tap(ans[i]);
  }
  await waitFor((s) => s.state === "done" && s.info.s04_row, "s04 done"); await sleep(300); await shot("s04-hear-done");
  { // ряд отвеченных карточек по центру; касание карточки в ряду — слово голосом Али, без подтверждения
    const s = await bk(); const mid = s.info.s04_row.reduce((a, [x, , w]) => a + x + w / 2, 0) / s.info.s04_row.length;
    if (Math.abs(mid - s.stage_center[0]) > 3) throw new Error(`s04: ряд карточек не по центру (${mid})`);
    const ok0 = s.sfx_counts.sfx_ok || 0; await tap("row_card_0"); await sleep(600);
    const s2 = await bk();
    if (s2.info.s04_word_last !== "a_hear_02" || s2.state !== "done" || (s2.sfx_counts.sfx_ok || 0) !== ok0) throw new Error("s04: касание карточки «мак» в ряду: " + JSON.stringify(s2.info));
    console.log("s04: ряд по центру, касание «мак» в ряду → a_hear_02, без подтверждения"); }
  await next("s04_hear");
  // s05
  await waitFor(state("wait_letters"), "s05 letters"); await shot("s05-letter");
  { // s05 (ред. 25.10.2026): Аля-персонаж, без «лесенки»; касание одной буквы — только её реплика с подсветкой частей
    const s0 = await bk();
    if (!s0.targets.alya) throw new Error("s05: нет Али-персонажа");
    const b0 = sfxSnap(s0);
    await tap("big");
    await waitFor((s) => s.info.s05_seen && s.info.s05_seen.big, "s05: касание большой А");
    await sleep(1200);
    await assertNoConfirm("s05 (нажата только большая А)", "wait_letters", b0, 300); noConfirmChecked.push("s05");
    const hl = (await bk()).info.s05_hl_seen || [];
    for (const p of ["big:left", "big:right", "big:bar"]) if (!hl.includes(p)) throw new Error("s05: не подсветилась часть " + p + " " + JSON.stringify(hl));
    await tap("big"); await sleep(400);   // повтор реплики — по-прежнему без подтверждения
    if ((await bk()).state !== "wait_letters") throw new Error("s05: повторное касание А завершило сцену");
    await tap("small");
    const s1 = await waitFor(state("done"), "s05 done");
    const hl1 = s1.info.s05_hl_seen || [];
    for (const p of ["small:round", "small:stick", "big", "small"]) if (!hl1.includes(p)) throw new Error("s05: не подсветилось " + p + " " + JSON.stringify(hl1));
    if (!s1.info.s05_outro) throw new Error("s05: не было итоговой реплики a_letter_04");
    console.log("s05: подсветка частей по таймлайну " + JSON.stringify(hl1) + "; итог a_letter_04 → «Далее»");
  }
  await next("s05_letter");
  // s06: обводка 3 штрихов (первый — сначала мимо дорожки)
  await waitFor(state("wait_stroke_0"), "s06 stroke 0"); await shot("s06-write");
  { // три штриха мимо дорожки: штрих не засчитывается сам (была автоприёмка после 3-й неудачи)
    const b0 = sfxSnap(await bk());
    for (let n = 0; n < 3; n++) { const a = await target("stroke_start"); await drag(a, [a[0] + 200, a[1] + 40]); await sleep(n === 1 ? 3200 : 1500); }
    await assertNoConfirm("s06 (3 штриха мимо)", "wait_stroke_0", b0, 500); noConfirmChecked.push("s06");
    await sleep(1500); }
  for (let k = 0; k < 3; k++) {
    await waitFor(state("wait_stroke_" + k), "s06 stroke " + k);
    const a = await target("stroke_start"), b = await target("stroke_end");
    await drag(a, b, 24);
    if (k === 0) { await sleep(200); await shot("s06-write-stroke1"); }
  }
  await waitFor(state("done"), "s06 done"); await shot("s06-write-done"); await next("s06_write");
  // s07: шарики
  await waitFor(state("wait_balloons"), "s07 balloons"); await sleep(3000); await shot("s07-find");
  { // два касания шариков-помех: ни один шарик с А/а не лопается сам
    const b0 = sfxSnap(await bk()); let nw = 0;
    for (let n = 0; n < 40 && nw < 2; n++) { const s = await bk();
      if (s.targets.wrong_balloon) { const w = s.targets.wrong_balloon; TOUCH ? await page.touchscreen.tap(w[0], w[1]) : await page.mouse.click(w[0], w[1]); nw++; await sleep(900); }
      else await sleep(300); }
    if (nw < 2) throw new Error("s07: не нашлось шариков-помех для проверки");
    await assertNoConfirm("s07 (2 ошибки)", "wait_balloons", b0, 1500); noConfirmChecked.push("s07"); }
  for (let n = 0; n < 120; n++) {
    const s = await bk(); if (s.state === "done") break;
    if (s.targets && s.targets.balloon) { const b = s.targets.balloon; TOUCH ? await page.touchscreen.tap(b[0], b[1]) : await page.mouse.click(b[0], b[1]); }
    await sleep(400);
  }
  await waitFor(state("done"), "s07 done");
  { // после последнего шарика: оставшиеся летят дальше плавно (без сброса), в центре — большая А и маленькая а со звуком
    await waitFor((s) => s.targets && s.targets.end_big && s.targets.end_small, "s07: А и а в центре", 8000);
    await sleep(800); await shot("s07-find-letters");
    await tap("end_big"); await sleep(500); await tap("end_small"); await sleep(500);
    const s1 = await bk();
    const [bx] = s1.targets.end_big, [sx] = s1.targets.end_small;
    if (!(bx < sx)) throw new Error("s07: большая А не слева от маленькой а");
    if (!s1.targets.next) throw new Error("s07: нет «Далее» после шариков");
    console.log(`s07: после шариков — А (${s1.targets.end_big.map(Math.round)}) и а (${s1.targets.end_small.map(Math.round)}) в центре, нажимаются`);
  }
  await next("s07_find");
  // s08: корзинки (первая плитка — сначала в чужую корзинку)
  await waitFor(state("wait_drag"), "s08 drag"); await shot("s08-sort");
  { // до конца сцены корзинки на касание не отвечают
    const b0 = sfxSnap(await bk()); await tap("basket_big"); await sleep(600);
    const s = await bk(); if (s.info && s.info.s08_done_taps !== undefined) throw new Error("s08: корзинка ответила на касание до конца сцены");
    await assertNoConfirm("s08 (касание корзинки до конца)", "wait_drag", b0); }
  let wrongDone = false;
  for (let n = 0; n < 20; n++) {
    const s = await bk(); if (s.state === "done") break;
    const t = s.targets.tile, b = s.targets.tile_basket;
    if (t && b) {
      const other = (b[0] === s.targets.basket_big[0]) ? s.targets.basket_small : s.targets.basket_big;
      if (!wrongDone) { // две ошибки подряд: плитка возвращается, сама в корзинку не ложится
        const b0 = sfxSnap(await bk());
        for (let k = 0; k < 2; k++) { const s2 = await bk(); const t2 = s2.targets.tile, bb = s2.targets.tile_basket;
          const o2 = (bb[0] === s2.targets.basket_big[0]) ? s2.targets.basket_small : s2.targets.basket_big;
          await drag(t2, o2, 16); await sleep(1600); }
        await assertNoConfirm("s08 (2 ошибки)", "wait_drag", { ...b0, sfx_pop: (sfxSnap(await bk())).sfx_pop }); noConfirmChecked.push("s08");
        { const i8 = (await bk()).info || {}; if ((i8.s08_state_big || 0) !== 0 || (i8.s08_state_small || 0) !== 0) throw new Error(`s08: после ошибок корзинка наполнилась (${i8.s08_state_big}/${i8.s08_state_small})`); }
        wrongDone = true; continue; }
      await drag(t, b, 16);
      if (n === 2) await shot("s08-sort-progress");
    }
    await sleep(700);
  }
  await waitFor(state("done"), "s08 done"); await shot("s08-sort-done");
  { const s = await waitFor((s) => s.info && s.info.s08_state_big === 4 && s.info.s08_state_small === 4, "s08 v3: обе корзинки полные (состояние 4)", 6000);
    console.log(`s08 v3: корзинки в состоянии ${s.info.s08_state_big}/${s.info.s08_state_small}`); passed.push("s08-v3-states"); }
  { // после конца: касание корзинки — «А-а-а» + подскок
    await waitFor((s) => s.info && s.info.s08_done_taps === 0, "s08: корзинки слушают касания");
    for (const [k, name] of [[1, "basket_big"], [2, "basket_small"]]) {
      await tap(name); await sleep(400);
      const s = await bk(); const pk = s.info.s08_bounce_peak || {}; const up = pk.n === k ? pk.px : 0; if (s.info.s08_done_taps !== k) throw new Error(`s08: касание ${name} после конца не сработало`);
      if (up < 3) throw new Error(`s08: ${name} не подпрыгнула (${up.toFixed(1)} px)`);
      console.log(`s08: после конца касание ${name} — подскок ${up.toFixed(0)} px, звук: ${s.info.s08_done_audio || "(нет файла — тихо)"}`);
      await sleep(400); }
    passed.push("s08-done-basket-aaa"); }
  await next("s08_sort");
  // s09: кнопка взрослого (задание 2 — «ещё раз», затем «✓»; задание 4 — два раза «ещё раз» → серебряная звезда)
  for (let i = 0; i < 4; i++) {
    if (i === 0) { // пока звучит задание 9.1, дуги загораются по очереди
      const lit = new Set(); const t0 = Date.now();
      while (Date.now() - t0 < 30000) { const s = await bk(); if (s.info && s.info.s09_arcs_lit !== undefined) lit.add(s.info.s09_arcs_lit); if (s.state === "wait_parent_0") break; await sleep(40); }
      console.log("s09 9.1: замечено дуг горящими:", [...lit].sort().join(","));
      if (![1, 2, 3].some((n) => lit.has(n))) throw new Error("s09: дуги на карточке 9.1 не загорались");
    }
    await waitFor(state("wait_parent_" + i), "s09 parent " + i);
    await sleep(1100);   // кнопка игнорирует нажатия чаще 1 раза в секунду
    if (i === 0) { await checkExit("s09 (кнопка взрослого)"); await shot("s09-say-parent-button"); }
    { // карточки сцены 9 — без красных предметов (кроме самой буквы А в задании 4)
      const s = await bk(); const card = s.info && s.info.s09_card;
      if (!card || card.i !== i) throw new Error("s09: нет сведений о карточке " + i);
      const rf = await redFraction(card.rect);
      console.log(`s09 карточка ${i + 1}: ${card.id}, красных пикселей ${(rf * 100).toFixed(2)} %`);
      if (card.id === "sound") {
        // 9.1 «произнеси [а]»: только плоский кружок ≈42 % ширины (площадь ≈ 0,42²·π/4 ≈ 14 % карточки), без глянцевого шара
        if (s.info.s09_card_content !== "sound") throw new Error("s09: карточка 9.1 — не звуковое задание");
        if (rf < 0.08 || rf > 0.22) throw new Error(`s09: на карточке 9.1 кружок не того размера (${(rf * 100).toFixed(1)} %)`);
      } else if (card.id !== "letter_big" && rf > 0.005) throw new Error(`s09: красный предмет на карточке ${card.id} (${(rf * 100).toFixed(1)} %)`);
      // непрозрачная кремовая подложка: центр-верх карточки внутри рамки — кремовый
      if (!card.id.startsWith("pic_alya_card")) { const [x, y, w] = card.rect; const cf = await creamAt(x + w / 2, y + 14);
        if (!cf) throw new Error("s09: нет кремовой подложки у карточки " + card.id); }
    }
    if (i === 1 || i === 3) {
      await tap("parent_retry");
      await waitFor((s) => !s.targets.parent_ok, "s09 hide");
      if (i === 3) { await waitFor((s) => s.targets.parent_ok, "s09 reshow", 20000); await sleep(1100); await tap("parent_retry"); continue; }
      await waitFor((s) => s.targets.parent_ok, "s09 reshow", 20000); await sleep(1100);
    }
    await tap("parent_ok");
  }
  await waitFor(state("done"), "s09 done"); await shot("s09-say-done"); await next("s09_say");
  // s10
  await waitFor((s) => s.step === "s10_end" && s.state === "done", "s10 done", 40000);
  await sleep(500); await shot("s10-end"); await checkExit("s10_end");
  { const s = await bk(); const [ax, ay, aw, ah] = s.info.s10_album; const [ex, ey] = s.targets.exit;
    if (ex + 36 > ax && ex - 36 < ax + aw && ey + 36 > ay && ey - 36 < ay + ah) throw new Error("s10: крестик перекрывает альбом"); }
  { const s = await bk(); if (!s.targets.sticker) throw new Error("s10: нет наклейки-аиста (она в утверждённом сценарии)"); }
  { // обложка альбома — без красного и оранжевого (оттенок 0…35° и 345…360°)
    const s = await bk(); const r = s.info && s.info.s10_album; if (!r) throw new Error("s10: нет сведений об альбоме");
    // точки на обложке (корешок и низ обложки, мимо наклейки и прозрачных полей; фон за альбомом — вечерняя стена, она оранжевая)
    const [x, y, w, h] = r; let of = 0;
    for (const [fx, fy] of [[0.12, 0.5], [0.12, 0.8], [0.86, 0.88], [0.86, 0.2]]) of += await redFraction([x + fx * w - 2, y + fy * h - 2, 4, 4], 35, 345);
    console.log(`s10 альбом: красно-оранжевых точек обложки ${of.toFixed(2)} из 4`);
    if (of > 0) throw new Error(`s10: красный/оранжевый фон альбома`); }
  // итог для взрослого: короткий тап не открывает, удержание ≈2 с — открывает
  await tap("parent_info"); await sleep(400);
  if ((await bk()).info.parent_panel) throw new Error("s10: панель взрослого открылась от короткого тапа");
  { const [x, y] = await target("parent_info");
    if (TOUCH) { await page.touchscreen.touchStart(x, y); await sleep(2300); await page.touchscreen.touchEnd(); }
    else { await page.mouse.move(x, y); await page.mouse.down(); await sleep(2300); await page.mouse.up(); } }
  await waitFor((s) => s.info && s.info.parent_panel, "s10 parent panel", 5000);
  await sleep(300); await shot("s10-parent-panel");
  await tap("parent_panel"); await waitFor((s) => !s.info.parent_panel, "s10 parent panel closed", 5000);
  // «домой» → HTML-главная
  { const [x, y] = await target("home"); await tapNav([x, y], "домой (s10)"); }
  await homeReady("s10 домой → главная");
  if (new URL(page.url()).pathname !== "/") throw new Error("«домой» привела не на главную: " + page.url());
  console.log("s10 «домой» → главная:", page.url().replace(/^http:\/\/[^/]+/, ""));
  await sleep(500); await shot("letters-menu");
  { const h = await home(); await tapXY(h.targets.letter_locked); await sleep(600);
    if (new URL(page.url()).pathname !== "/") throw new Error("закрытая буква «Б» открыла урок"); }
  // повторный вход: урок загружается заново → сразу s01
  await homeToLesson();
  console.log("повторный вход в «А»: сразу s01");
  passed.push("s10_end");
  // крестик посреди урока: s01 → главная → «А» → s01
  await checkExit("s01_intro"); await shot("s01-intro-exit");
  { const [x, y] = await target("exit"); await tapNav([x, y], "крестик s01"); }
  await homeReady("крестик → главная");
  await homeToLesson();
  { const miss = ["s01_intro","s02_sing","s03_words","s04_hear","s05_letter","s06_write","s07_find","s08_sort","s09_say","s10_end"].filter((n) => !exitSeen.has(n));
    if (miss.length) throw new Error("нет крестика на: " + miss.join(", ")); }
  console.log("крестик: виден на s01–s10 без перекрытий; выход → главная → «А» → s01 — ок");
  passed.push("exit→главная→А→s01");
  // звук на iOS: без жеста на странице s01 ждёт касания (Аля пульсирует, рука сразу над ней); касание → реплика → wait_alya
  await page.goto(`http://127.0.0.1:${PORT}/lesson-a/index.html?test=1&fast=1&gate=1`, { waitUntil: "load" });
  { const s = await waitFor((s) => s.step === "s01_intro" && s.state === "wait_unlock", "gate: s01 wait_unlock", 60000);
    await sleep(2500);
    if ((await bk()).state !== "wait_unlock") throw new Error("gate: s01 пошла без касания");
    await sleep(400); await tap("alya");
    await waitFor((s) => s.state === "wait_alya", "gate: касание → s01 wait_alya", 15000);
    console.log("gate=1: s01 ждёт касания (wait_unlock), после касания — реплика и wait_alya"); }
  passed.push("s01-audio-gate");
  console.log("без автоподтверждения после неверных попыток:", noConfirmChecked.join(", "));
  if (noConfirmChecked.length < 6) throw new Error("проверены не все игры на «без автоподтверждения»: " + noConfirmChecked.join(","));
  const log = await page.evaluate(() => (window.__bk || {}).log);
  console.log("журнал событий (записей):", log);
  if (textViolations.size) throw new Error("текст на экране ребёнка:\n" + [...textViolations].join("\n"));
  console.log("субтитры без debug: ни разу не показаны; текст на экране ребёнка — только А/а");
  // с ?debug=1 субтитры появляются
  await page.goto(`http://127.0.0.1:${PORT}/lesson-a/index.html?test=1&fast=1&debug=1&step=s01_intro`, { waitUntil: "load" });
  await waitFor((s) => s.step === "s01_intro", "deep link ?step=s01_intro → s01", 60000);
  console.log("deep link ?step=s01_intro: сразу s01");
  await waitFor((s) => s.caption_visible, "debug: субтитр виден", 60000);
  await shot("debug-subtitles-s01");
  console.log("debug=1: субтитры показаны");
  // рука-подсказка с укороченным таймером: s03, ждём картинку
  await page.goto(`http://127.0.0.1:${PORT}/lesson-a/index.html?test=1&fast=1&hint_sec=3&step=s03_words`, { waitUntil: "load" });
  await waitFor(state("wait_pic_0"), "idle: s03 wait_pic_0", 60000);
  { const t0 = Date.now(); await sleep(1500);
    if ((await bk()).targets.hint_hand) throw new Error("idle: рука появилась раньше таймера");
    const s = await waitFor((s) => s.targets.hint_hand, "idle: рука через 3 с", 6000);
    const dt = (Date.now() - t0) / 1000; const [hx, hy] = s.targets.hint_hand, [px, py] = s.targets.pic;
    console.log(`idle: рука появилась через ${dt.toFixed(1)} с (hint_sec=${s.hint_sec}), над картинкой: ${Math.hypot(hx - px, hy - py) < 120}`);
    if (Math.hypot(hx - px, hy - py) > 120) throw new Error("idle: рука не над картинкой");
    await sleep(300); await shot("s03-hint-hand");
    // рука НЕ исчезает по таймеру (раньше пряталась через 2 с): ждём 3+2+3 с — всё ещё на экране
    await sleep(5000);
    if (!(await bk()).targets.hint_hand) throw new Error("idle: рука исчезла по таймеру, а ребёнок ничего не сделал");
    // неверное действие (касание мимо цели) руку не прячет
    TOUCH ? await page.touchscreen.tap(60, 400) : await page.mouse.click(60, 400);
    await sleep(800);
    if (!(await bk()).targets.hint_hand) throw new Error("idle: касание мимо цели спрятало руку");
    console.log(`idle: рука держится ${((Date.now() - t0) / 1000).toFixed(1)} с (дольше старого таймера), касание мимо — не прячет`);
    // нужное действие (касание картинки) — рука прячется сразу
    const hid0 = ((await bk()).info || {}).hint_hidden || 0;
    await tapXY(s.targets.pic); const t1 = Date.now();
    await waitFor((s) => !s.targets.hint_hand, "idle: касание цели прячет руку", 1500);
    console.log(`idle: касание картинки — рука спрятана через ${Date.now() - t1} мс (hint_hidden ${hid0} → ${((await bk()).info || {}).hint_hidden})`); }
  passed.push("idle-hint-persists");
  // s08 (перетаскивание): рука держится, касание корзинки (неверное действие) её не прячет, начало перетаскивания плитки — прячет
  await page.goto(`http://127.0.0.1:${PORT}/lesson-a/index.html?test=1&fast=1&hint_sec=2&step=s08_sort`, { waitUntil: "load" });
  await waitFor(state("wait_drag"), "idle: s08 wait_drag", 60000);
  { const s = await waitFor((s) => s.targets.hint_hand && s.targets.tile, "idle: s08 рука", 8000);
    await sleep(4500);
    if (!(await bk()).targets.hint_hand) throw new Error("idle s08: рука исчезла по таймеру");
    await tapXY(s.targets.basket_small); await sleep(600);
    if (!(await bk()).targets.hint_hand) throw new Error("idle s08: касание корзинки спрятало руку");
    const [x, y] = s.targets.tile;
    if (TOUCH) { await page.touchscreen.touchStart(x, y); } else { await page.mouse.move(x, y); await page.mouse.down(); }
    await waitFor((s) => !s.targets.hint_hand, "idle s08: начало перетаскивания прячет руку", 1500);
    if (TOUCH) await page.touchscreen.touchEnd(); else await page.mouse.up();
    console.log("idle s08: рука держится >6 с, касание корзинки не прячет, взяли плитку — рука спряталась"); }
  passed.push("idle-hint-drag");
  // бездействие с короткой подсказкой (hint_sec=1): рука показывается, но шаг сам не подтверждается
  for (const [step, st] of [["s02_sing", "wait_hold"], ["s03_words", "wait_pic_0"], ["s04_hear", "wait_answer_0"], ["s05_letter", "wait_letters"], ["s07_find", "wait_balloons"], ["s08_sort", "wait_drag"]]) {
    await page.goto(`http://127.0.0.1:${PORT}/lesson-a/index.html?test=1&fast=1&hint_sec=1&step=${step}`, { waitUntil: "load" });
    await waitFor(state(st), `idle-noauto: ${step} ${st}`, 60000);
    const b0 = sfxSnap(await bk()); let hand = false; const t0 = Date.now();
    while (Date.now() - t0 < 10000) { const s = await bk(); if (s.targets && s.targets.hint_hand) hand = true; await sleep(200); }
    await assertNoConfirm(`бездействие ${step} 10 с`, st, b0);
    if (!hand) throw new Error(`бездействие ${step}: рука-подсказка не появилась`);
    console.log(`бездействие 10 с на ${step}: рука показана, шаг ждёт (${st})`);
  }
  passed.push("idle-no-autoconfirm");
} catch (e) { errors.push("test: " + (e.stack || e)); try { await shot("FAIL"); } catch {} }
finally { if (browser) await browser.close(); srv.kill(); }
console.log("passed:", passed.join(" → "));
console.log("LOG lines:\n" + logs.filter((l) => l.includes("LOG ")).join("\n"));
console.log(errors.length ? "ERRORS:\n" + errors.join("\n") : "OK: no JS errors");
process.exit(errors.length ? 1 : 0);
