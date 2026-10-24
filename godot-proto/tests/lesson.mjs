// Сквозной тест урока «А» в headless Chrome: проходит все шаги s00…s10 КАСАНИЯМИ (touch-события, как на планшете),
// делает ошибки там, где это нужно для проверки реакций, снимает скриншоты.
// Плюс: крестик выхода на s01–s10 (виден, ни с чем не пересекается) → экран букв → «А» → s01;
// рука-подсказка после бездействия (?hint_sec=3 — укороченный таймер; по умолчанию 20 с — проверяется на экране букв).
// Запуск: PORT=<свободный> node tests/lesson.mjs     (TOUCH=0 — мышью; URLQ="audio=stream" — доп. параметры)
import { createRequire } from "module"; import { spawn } from "child_process"; import path from "path"; import fs from "fs"; import { fileURLToPath } from "url";
const require = createRequire(import.meta.url);
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const puppeteer = require(path.resolve(ROOT, "../.tools/node_modules/puppeteer-core"));
const PORT = +(process.env.PORT || 55782);
const TOUCH = process.env.TOUCH !== "0";
const SHOTS = path.join(ROOT, "screenshots"); fs.mkdirSync(SHOTS, { recursive: true });
const srv = spawn("node", [path.join(ROOT, "tests/serve.mjs"), path.join(ROOT, "build"), String(PORT)], { stdio: "ignore", env: { ...process.env, NOCOI: "1" } });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const errors = [], logs = [], passed = []; let browser, page;
// Без ?debug=1 субтитров быть не должно, а из текста на экране ребёнка — только А/а
// (исключения: памятка для взрослого s00 и открытая взрослым панель итога в s10).
const textViolations = new Set();
const ALLOWED = new Set(["А", "а"]);
const bk = async () => {
  const s = await page.evaluate(() => window.__bk || {});
  if (s.caption_visible || s.caption_ever_visible) textViolations.add("субтитр виден: " + (s.step || "") + " «" + (s.caption || "") + "»");
  if (s.step && s.step !== "s00_parent_note" && s.step !== "letters_menu" && !(s.info && s.info.parent_panel))
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
  await page.goto(`http://127.0.0.1:${PORT}/index.html?${q}`, { waitUntil: "load" });
  // запуск без ?step → главный экран букв (без крестика)
  { const s = await waitFor((s) => s.step === "letters_menu" && s.state === "wait_letter", "boot → letters_menu", 120000);
    console.log("ready ms", Date.now() - t0);
    if (s.targets.exit) throw new Error("letters: на главном экране не должно быть крестика"); }
  await sleep(500); await shot("letters-home");
  passed.push("boot→letters_menu");
  // первый вход в «А» за сессию → памятка взрослому s00 (с крестиком)
  await tap("letter_a");
  await waitFor((s) => s.step === "s00_parent_note" && s.state === "wait_start", "«А» → s00 (первый раз)", 30000);
  await checkExit("s00_parent_note");
  await sleep(400); await shot("s00-parent-note");
  await tap("junior"); await sleep(300);   // младший режим (4 года): допуск ±60 px в сцене 6
  await tap("start");
  // s01
  await waitFor((s) => s.step === "s01_intro" && s.state === "wait_alya", "s01 wait_alya");
  await shot("s01-intro"); await tap("alya");
  await sleep(900); await shot("s01-intro-sing");   // песенка у кроватки (поза alya_pose_sing_crib)
  await waitFor(state("done"), "s01 done"); await next("s01_intro");
  // s02: «нажми и держи»
  await waitFor(state("wait_hold"), "s02 wait_hold"); await shot("s02-sing");
  { const c = await target("circle"); await drag(c, c, 1, 2400); }
  await waitFor(state("done"), "s02 done"); await shot("s02-sing-done"); await next("s02_sing");
  // s03: картинка → первое окошко (на 2-й картинке одна ошибка)
  for (let i = 0; i < 3; i++) {
    await waitFor(state("wait_pic_" + i), "s03 pic " + i);
    await tap("pic");
    await waitFor(state("wait_slot_" + i), "s03 slot " + i);
    // «Далее» не должна появляться, пока не посажен кружок у третьей картинки
    const nx = await page.evaluate(() => !!(window.__bk && window.__bk.targets && window.__bk.targets.next));
    if (nx) throw new Error("s03: кнопка «Далее» видна до третьей картинки (картинка " + (i + 1) + ")");
    if (i === 1) { await tap("slot2"); await sleep(1200); }
    await tap("slot0");
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
    if (i === 1) { await tap("yes"); await sleep(1500); }
    await tap(ans[i]);
  }
  await waitFor(state("done"), "s04 done"); await shot("s04-hear-done"); await next("s04_hear");
  // s05
  await waitFor(state("wait_letters"), "s05 letters"); await shot("s05-letter");
  await tap("big"); await tap("small");
  await waitFor(state("done"), "s05 done"); await next("s05_letter");
  // s06: обводка 3 штрихов (первый — сначала мимо дорожки)
  await waitFor(state("wait_stroke_0"), "s06 stroke 0"); await shot("s06-write");
  { const a = await target("stroke_start"); await drag(a, [a[0] + 200, a[1] + 40]); await sleep(1200); }
  for (let k = 0; k < 3; k++) {
    await waitFor(state("wait_stroke_" + k), "s06 stroke " + k);
    const a = await target("stroke_start"), b = await target("stroke_end");
    await drag(a, b, 24);
    if (k === 0) { await sleep(200); await shot("s06-write-stroke1"); }
  }
  await waitFor(state("done"), "s06 done"); await shot("s06-write-done"); await next("s06_write");
  // s07: шарики
  await waitFor(state("wait_balloons"), "s07 balloons"); await sleep(3000); await shot("s07-find");
  { const s = await bk(); if (s.targets.wrong_balloon) { const w = s.targets.wrong_balloon; TOUCH ? await page.touchscreen.tap(w[0], w[1]) : await page.mouse.click(w[0], w[1]); await sleep(800); } }
  for (let n = 0; n < 120; n++) {
    const s = await bk(); if (s.state === "done") break;
    if (s.targets && s.targets.balloon) { const b = s.targets.balloon; TOUCH ? await page.touchscreen.tap(b[0], b[1]) : await page.mouse.click(b[0], b[1]); }
    await sleep(400);
  }
  await waitFor(state("done"), "s07 done"); await next("s07_find");
  // s08: корзинки (первая плитка — сначала в чужую корзинку)
  await waitFor(state("wait_drag"), "s08 drag"); await shot("s08-sort");
  let wrongDone = false;
  for (let n = 0; n < 20; n++) {
    const s = await bk(); if (s.state === "done") break;
    const t = s.targets.tile, b = s.targets.tile_basket;
    if (t && b) {
      const other = (b[0] === s.targets.basket_big[0]) ? s.targets.basket_small : s.targets.basket_big;
      await drag(t, wrongDone ? b : other, 16); if (!wrongDone) { wrongDone = true; await sleep(800); continue; }
      if (n === 2) await shot("s08-sort-progress");
    }
    await sleep(700);
  }
  await waitFor(state("done"), "s08 done"); await shot("s08-sort-done"); await next("s08_sort");
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
  // «домой» → экран букв
  await tap("home"); await waitFor((s) => s.step === "letters_menu" && s.state === "wait_letter", "home → letters");
  { const s = await bk(); if (s.targets.exit) throw new Error("letters: на экране букв не должно быть крестика"); }
  await sleep(500); await shot("letters-menu");
  await tap("letter_locked"); await sleep(600);
  if ((await bk()).step !== "letters_menu") throw new Error("letters: закрытая буква «Б» открыла урок");
  await tap("letter_a");
  { const s = await waitFor((s) => s.step && s.step !== "letters_menu", "letters «А» → урок");
    if (s.step !== "s01_intro") throw new Error("второй вход в «А»: ожидался s01, а открылся " + s.step); }
  console.log("второй вход в «А» за сессию: сразу s01 (без памятки)");
  passed.push("s10_end");
  // крестик посреди урока: s01 → экран букв → «А» → снова s01
  await waitFor((s) => s.step === "s01_intro" && s.state === "wait_alya", "s01 again");
  await checkExit("s01_intro"); await shot("s01-intro-exit");
  await tap("exit"); await waitFor((s) => s.step === "letters_menu" && s.state === "wait_letter", "exit → letters");
  await tap("letter_a"); await waitFor((s) => s.step === "s01_intro" && s.state === "wait_alya", "letters → s01 (после крестика)");
  { const miss = ["s00_parent_note","s01_intro","s02_sing","s03_words","s04_hear","s05_letter","s06_write","s07_find","s08_sort","s09_say","s10_end"].filter((n) => !exitSeen.has(n));
    if (miss.length) throw new Error("нет крестика на: " + miss.join(", ")); }
  console.log("крестик: виден на s00–s10 без перекрытий; выход → экран букв → «А» → s01 — ок");
  passed.push("exit→letters→А→s01");
  const log = await page.evaluate(() => (window.__bk || {}).log);
  console.log("журнал событий (записей):", log);
  if (textViolations.size) throw new Error("текст на экране ребёнка:\n" + [...textViolations].join("\n"));
  console.log("субтитры без debug: ни разу не показаны; текст на экране ребёнка — только А/а");
  // с ?debug=1 субтитры появляются
  await page.goto(`http://127.0.0.1:${PORT}/index.html?test=1&fast=1&debug=1&step=s01_intro`, { waitUntil: "load" });
  await waitFor((s) => s.step === "s01_intro", "deep link ?step=s01_intro → s01", 60000);
  console.log("deep link ?step=s01_intro: сразу s01");
  await waitFor((s) => s.caption_visible, "debug: субтитр виден", 60000);
  await shot("debug-subtitles-s01");
  console.log("debug=1: субтитры показаны");
  // рука-подсказка с укороченным таймером: s03, ждём картинку
  await page.goto(`http://127.0.0.1:${PORT}/index.html?test=1&fast=1&hint_sec=3&step=s03_words`, { waitUntil: "load" });
  await waitFor(state("wait_pic_0"), "idle: s03 wait_pic_0", 60000);
  { const t0 = Date.now(); await sleep(1500);
    if ((await bk()).targets.hint_hand) throw new Error("idle: рука появилась раньше таймера");
    const s = await waitFor((s) => s.targets.hint_hand, "idle: рука через 3 с", 6000);
    const dt = (Date.now() - t0) / 1000; const [hx, hy] = s.targets.hint_hand, [px, py] = s.targets.pic;
    console.log(`idle: рука появилась через ${dt.toFixed(1)} с (hint_sec=${s.hint_sec}), над картинкой: ${Math.hypot(hx - px, hy - py) < 120}`);
    if (Math.hypot(hx - px, hy - py) > 120) throw new Error("idle: рука не над картинкой");
    await sleep(300); await shot("s03-hint-hand");
    // касание пустого места — рука прячется, отсчёт заново
    await waitFor((s) => !s.targets.hint_hand, "idle: рука спряталась после показа", 6000);
    TOUCH ? await page.touchscreen.tap(60, 400) : await page.mouse.click(60, 400);
    const t1 = Date.now(); await sleep(1500);
    if ((await bk()).targets.hint_hand) throw new Error("idle: касание не сбросило таймер");
    await waitFor((s) => s.targets.hint_hand, "idle: повторный показ", 6000);
    console.log(`idle: после касания рука снова через ${((Date.now() - t1) / 1000).toFixed(1)} с`); }
  passed.push("idle-hint(3s)");
  // по умолчанию — 20 с (экран букв: рука над «А»)
  await page.goto(`http://127.0.0.1:${PORT}/index.html?test=1&fast=1&step=letters_menu`, { waitUntil: "load" });
  { const s0 = await waitFor(state("wait_letter"), "letters ready", 60000);
    if (s0.hint_sec !== 20) throw new Error("idle: по умолчанию не 20 с: " + s0.hint_sec);
    const t0 = Date.now(); await sleep(18000);
    if ((await bk()).targets.hint_hand) throw new Error("idle: рука раньше 20 с");
    const s = await waitFor((s) => s.targets.hint_hand, "idle: рука через 20 с", 6000);
    const [hx, hy] = s.targets.hint_hand, [ax, ay] = s.targets.letter_a;
    console.log(`idle (20 с): рука через ${((Date.now() - t0) / 1000).toFixed(1)} с, над «А»: ${Math.hypot(hx - ax, hy - ay) < 80}`);
    if (Math.hypot(hx - ax, hy - ay) > 80) throw new Error("idle: рука не над «А»");
    await sleep(300); await shot("letters-menu-hint"); }
  passed.push("idle-hint(20s)");
} catch (e) { errors.push("test: " + (e.stack || e)); try { await shot("FAIL"); } catch {} }
finally { if (browser) await browser.close(); srv.kill(); }
console.log("passed:", passed.join(" → "));
console.log("LOG lines:\n" + logs.filter((l) => l.includes("LOG ")).join("\n"));
console.log(errors.length ? "ERRORS:\n" + errors.join("\n") : "OK: no JS errors");
process.exit(errors.length ? 1 : 0);
