// Сквозной тест урока «А» в headless Chrome: проходит все шаги s01…s11 КАСАНИЯМИ (touch-события, как на планшете),
// делает ошибки там, где это нужно для проверки реакций, снимает скриншоты.
// Сайт как в CI: корень — HTML-главная (web-home/), урок — lesson-a/ (сборка: bash tests/assemble_site.sh).
// Вход: главная → «А» → lesson-a/ → сразу s01 «Аист приносит буквы» (экрана для взрослого s00 больше нет) → s01…s11.
// Звук на iOS: в вебе без жеста на странице s01 ждёт касания (пустое гнездо пульсирует, wait_unlock); s02 — так же, если урок
// открыт сразу с неё (?step=2); в тесте выключено, ?gate=1 — включить.
// Плюс: крестик выхода на s01–s11 (виден, ни с чем не пересекается) → «Пока! Увидимся!» → главная → «А» → s01; «Ещё раз» в s10 → s01;
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
// 
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
async function homeToLesson() {   // главная: тап «А» → lesson-a/ → сразу s01 (аист влетает)
  const h = await homeReady("перед «А»"); await sleep(400);
  await tapNav(h.targets.letter_a, "А на главной");
  if (!/\/lesson-a\/(index\.html)?\?/.test(page.url())) throw new Error("«А» открыла не lesson-a/: " + page.url());
  const s = await waitFor((s) => s.step === "s01_stork" && /^(fly_in|drop|rise|circle|approach|land|done)$/.test(s.state), "lesson-a → s01 (без экрана s00)", 120000);
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
// s01 «Аист приносит буквы»: полёт (без касаний, без «Далее», без перекрытий кнопок) → буквы на земле → посадка → «Далее».
// Касание аиста в гнезде: a_word_02 + взмах, повторное касание во время реплики не перезапускает; касание букв: a_aaa / a_find_03 + подскок.
async function stork() {
  const seen = new Set(), overl = new Set(); let nextEarly = null, shotDrop = false, shotCircle = false, tapFly = false;
  const t0 = Date.now();
  while (Date.now() - t0 < 30000) {
    const s = await bk();
    if (s.step !== "s01_stork") throw new Error("s01: ушли со сцены сами: " + s.step);
    seen.add(s.state);
    for (const o of s.ui_overlaps || []) overl.add(s.state + ":" + o);
    if (s.targets.next && s.state !== "done") nextEarly = s.state;
    if (s.state === "done") break;
    if (s.state === "rise" && !shotDrop) { shotDrop = true; await shot("s01-stork-drop"); }
    if (s.state === "circle" && !shotCircle && s.info.s01_fly_rect && s.info.s01_fly_rect[0] < 420) { shotCircle = true; await shot("s01-stork-circle"); }
    if (s.state === "circle" && !tapFly && s.targets.stork) {   // касание летящего аиста — ничего
      tapFly = true; await tapXY(s.targets.stork);
      const a = await bk(); if ((a.info.s01_word_taps || 0) || (a.info.s01_flaps || 0)) throw new Error("s01: летящий аист принял касание");
    }
    await sleep(60);
  }
  const s = await waitFor(state("done"), "s01 done (аист сел)", 5000);
  const i = s.info;
  for (const st of ["fly_in", "rise", "circle", "approach"]) if (!seen.has(st)) throw new Error("s01: не видели фазу " + st + " (" + [...seen] + ")");
  if (nextEarly) throw new Error("s01: «Далее» появилась до посадки (" + nextEarly + ")");
  if (overl.size) throw new Error("s01: кнопки перекрывают аиста/буквы: " + [...overl].join(", "));
  if (i.s01_appear_voice !== "a_word_02") throw new Error("s01: на появлении аиста не прозвучала a_word_02");
  if (!((s.sfx_counts || {}).sfx_whoosh >= 1)) throw new Error("s01: нет sfx_whoosh на влёте");
  const d = i.s01_drop_at || {};
  const near = (p, q, e = 3) => p && Math.hypot(p[0] - q[0], p[1] - q[1]) <= e;
  if (!near(d.big, [564.6, 336.6]) || !near(d.small, [577.8, 333])) throw new Error("s01: буквы отцепились не там: " + JSON.stringify(d));
  if (!near(i.s01_land_pos, [371, 156], 0.5)) throw new Error("s01: посадка не в LAND: " + JSON.stringify(i.s01_land_pos));
  if (Math.abs(i.s01_circle_sec - 2.0) > 0.35) throw new Error("s01: круг " + i.s01_circle_sec + " с вместо 2,0");
  const g = i.s01_ground;
  const kA = 280 / 765, ka = 196 / 563;   // спрайт буквы 693×812 / 520×610, глиф с обводкой от (20;20), 646×765 / 473×563
  if (!g || Math.abs(g.big[1] - (320 - 20 * kA)) > 0.2 || Math.abs(g.big[3] - (600 + 27 * kA)) > 0.2 || Math.abs(g.small[3] - (600 + 27 * ka)) > 0.2 || Math.abs(g.small[0] - (649.9 - 20 * ka)) > 0.2) throw new Error("s01: «А» на земле не на базовой линии: " + JSON.stringify(g));
  if (!i.s01_letters_down) throw new Error("s01: буквы не встали");
  await sleep(300); await shot("s01-stork-landed");
  // касание аиста: реплика + взмах; второе касание во время реплики — не перезапускает
  await tap("stork_nest"); await tap("stork_nest");
  let a = (await bk()).info;
  if (a.s01_word_taps !== 2 || a.s01_word_plays !== 1 || a.s01_flaps !== 1) throw new Error("s01: касание аиста: " + JSON.stringify([a.s01_word_taps, a.s01_word_plays, a.s01_flaps]));
  await shot("s01-stork-flap");
  if ((await bk()).state !== "done" || !(await bk()).targets.next) throw new Error("s01: касание аиста повлияло на «Далее»");
  await sleep(2300); await tap("stork_nest");
  a = (await bk()).info;
  if (a.s01_word_plays !== 2) throw new Error("s01: после конца реплики касание аиста не звучит");
  // буквы: подскок + a_aaa (пока нет записи — a_find_03)
  await tap("big"); await sleep(200); await tap("small"); await sleep(400);
  a = (await bk()).info;
  if (a.s01_letter_taps !== 2) throw new Error("s01: касания букв не засчитаны: " + a.s01_letter_taps);
  if (!["a_aaa", "a_find_03"].includes(a.s01_aaa_audio)) throw new Error("s01: буква — не a_aaa/a_find_03: " + a.s01_aaa_audio);
  if (!(a.s01_bounce_peak && a.s01_bounce_peak.px > 5)) throw new Error("s01: буква не подпрыгнула");
  console.log(`s01: фазы ${[...seen].join("→")}; круг ${i.s01_circle_sec} с; буквы отцепились ${JSON.stringify(d)}; посадка ${i.s01_land_pos}; ` +
    `«Далее» только после посадки; кнопки ни с чем не пересекаются; аист: касаний ${a.s01_word_taps}, реплик ${a.s01_word_plays}, взмахов ${a.s01_flaps}; ` +
    `буквы: ${a.s01_letter_taps} касания, звук ${a.s01_aaa_audio}`);
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
  // s01: аист приносит буквы
  await stork();
  await next("s01_stork");
  // s02
  await waitFor(state("wait_alya"), "s02 wait_alya (после s01 касание уже было — без ожидания)", 30000);
  await sleep(300);
  await shot("s02-intro"); await tap("alya");
  await sleep(900); await shot("s02-intro-sing");   // песенка у кроватки (поза alya_pose_sing_crib)
  await waitFor(state("done"), "s02 done"); await next("s02_intro");
  // s03: «нажми и держи»
  await waitFor(state("wait_hold"), "s03 wait_hold"); await shot("s03-sing");
  { // короткие нажатия (неудачные попытки) не засчитываются — шаг ждёт удержания
    const c = await target("circle"); const b0 = sfxSnap(await bk());
    for (let n = 0; n < 3; n++) { await drag(c, c, 1, 200); await sleep(900); }
    await assertNoConfirm("s03 (3 коротких нажатия)", "wait_hold", b0); noConfirmChecked.push("s03");
    await drag(c, c, 1, 2400); }
  await waitFor(state("done"), "s03 done"); await shot("s03-sing-done"); await next("s03_sing");
  { // правило 5: вернулись «назад» в пройденную сцену — «Далее» видна сразу; правило 1: щелчок на кнопках навигации
    const s0 = await waitFor((s) => s.step === "s04_hear" && s.ui_rects && s.ui_rects.back, "s04 открыта");
    const c0 = (s0.sfx_counts || {}).sfx_click || 0;
    if (!(c0 >= 2)) throw new Error("нет щелчка на «Далее»: sfx_click=" + c0);
    const [x, y, w, h] = s0.ui_rects.back; await tapXY([x + w / 2, y + h / 2]);
    const s1 = await waitFor((s) => s.step === "s03_sing" && s.targets.next, "«назад» → s03 с видимой «Далее»", 8000);
    if (s1.state === "done") console.log("s03 после «назад»: состояние done");
    if (!(((s1.sfx_counts || {}).sfx_click || 0) > c0)) throw new Error("нет щелчка на «назад»");
    await sleep(400); await tap("next");
    await waitFor((s) => s.step === "s04_hear", "s03 → s04 снова");
    console.log("«назад» в пройденную s03: «Далее» сразу видна; щелчки навигации: " + ((await bk()).sfx_counts.sfx_click)); passed.push("back-next-visible"); }
  // s04 «на слух» (с 27.10.2026 — до паровозика): Аля в центре показывает руками на кнопки, уходит; карточки по центру,
  // отвеченные — в ряды вверху (слева со звуком, справа без); в конце — «аплодисменты» (первая «а» красная)
  await waitFor(state("wait_answer_0"), "s04 answer 0", 40000);
  { const i = (await bk()).info;
    if (!i.s04_alya_point || !i.s04_alya_point_no) throw new Error("s04: Аля не показала на кнопки: " + JSON.stringify([i.s04_alya_point, i.s04_alya_point_no])); }
  const ans = ["yes", "no", "yes", "no", "yes"];
  for (let i = 0; i < 5; i++) {
    await waitFor(state("wait_answer_" + i), "s04 answer " + i);
    if (i === 0) await shot("s04-hear");
    if (i === 1) { // «кот»: две ошибки подряд — шаг ждёт; подсказки сразу нет (только после 20 с бездействия)
      const b0 = sfxSnap(await bk());
      for (let n = 0; n < 2; n++) { await tap("yes"); await sleep(1600); }
      const s = await assertNoConfirm("s04 «кот» (2 ошибки)", "wait_answer_1", b0);
      if (s.targets.hint_hand) throw new Error("s04: рука-подсказка сразу после ошибок (должна — через 20 с)");
      noConfirmChecked.push("s04"); }
    await tap(ans[i]);
  }
  { const s = await waitFor((s) => s.info.s04_applause && s.info.s04_row, "s04: аплодисменты", 30000);
    const ap = s.info.s04_applause;
    if (ap.word !== "аплодисменты" || JSON.stringify(ap.red) !== "[0]") throw new Error("s04: финал не «аплодисменты» с красной первой «а»: " + JSON.stringify(ap));
    for (const [x, y, w, h, has] of s.info.s04_row) {
      if (y + h / 2 > 250) throw new Error("s04: ряд карточек не вверху: " + y);
      if (has ? x + w / 2 > 512 : x + w / 2 < 512) throw new Error("s04: карточка не в своём ряду: " + JSON.stringify([x, w, has]));
    }
    await sleep(300); await shot("s04-hear-applause"); }
  await waitFor(state("done"), "s04 done"); await sleep(300); await shot("s04-hear-done");
  { const s = await bk(); const ok0 = s.sfx_counts.sfx_ok || 0; await tap("row_card_0"); await sleep(600);
    const s2 = await bk();
    if (s2.info.s04_word_last !== "a_hear_02" || s2.state !== "done" || (s2.sfx_counts.sfx_ok || 0) !== ok0) throw new Error("s04: касание карточки «мак» в ряду: " + JSON.stringify(s2.info));
    console.log("s04: Аля показала руками, ряды вверху (со звуком слева, без — справа), «аплодисменты», касание «мак» → a_hear_02"); }
  await next("s04_hear");
  // s05 паровозик: справа налево (зеркально), сразу; 5 слов вперемешку (первое — «аист»), ячейки внизу с начала;
  // на первом слове две ошибки (середина), подсказок сразу нет; «астра» — два кружка; в конце буквы въезжают по рельсам
  const LJ = JSON.parse(fs.readFileSync(path.join(ROOT, "data/lesson_a/lesson.json"), "utf8"));
  const WORDS = Object.fromEntries(LJ.words.items.map((it) => [it.word, it]));
  const order = [];
  for (let i = 0; i < 5; i++) {
    { // въезд: справа налево; стоп по центру; карточка вверху одна
      const s0 = await waitFor((s) => (s.state === "drive_in_" + i || s.state === "wait_pic_" + i) && s.targets && s.targets.train, "s05 train " + i, 40000);
      const x0 = s0.targets.train[0];
      if (i === 0 && s0.state === "drive_in_0" && s0.info.s05_cells !== 5) throw new Error("s05: пустых ячеек с начала " + s0.info.s05_cells + " вместо 5");
      const s1 = await waitFor(state("wait_pic_" + i), "s05 pic " + i);
      const x1 = s1.targets.train[0];
      if (s0.state === "drive_in_" + i && !(x1 < x0 - 20)) throw new Error(`s05: поезд ${i} не въехал справа налево (${x0} → ${x1})`);
      if (Math.abs(x1 - 512) > 40) throw new Error(`s05: поезд ${i} остановился не по центру (${x1})`);
      if (s1.info.s05_cards_visible !== 1) throw new Error(`s05: на сцене ${s1.info.s05_cards_visible} карточек вместо одной (слово ${i})`);
      order.push(s1.info.s05_word);
    }
    const it = WORDS[order[i]]; if (!it) throw new Error("s05: неизвестное слово " + order[i]);
    if (i === 0 && order[0] !== "аист") throw new Error("s05: первое слово не «аист»: " + order[0]);
    const pos = Array.isArray(it.pos) ? it.pos : [it.pos];
    await tap("pic");
    await waitFor(state("wait_slot_" + i), "s05 slot " + i);
    if (i === 0) { const t = (await bk()).targets; if (!(t.slot0[0] < t.slot2[0])) throw new Error("s05: начало слова не в левом окошке при RTL"); }
    if (i === 0) { const st = "wait_slot_0"; const b0 = sfxSnap(await bk()); const tx = (await bk()).targets.train[0];
      for (let n = 0; n < 2; n++) { await tap("slot1"); await sleep(1300); }
      const s = await assertNoConfirm("s05 слово 1 (2 ошибки)", st, b0);
      if (Math.abs(s.targets.train[0] - tx) > 8) throw new Error("s05: поезд поехал без верного ответа");
      if (s.targets.hint_hand || (s.info.s05_sparks || 0)) throw new Error("s05: подсказка/искры сразу после ошибок (должны — через 20 с)");
      noConfirmChecked.push("s05"); }
    await tap("slot" + pos[0]);
    if (pos.length > 1) { await waitFor(state("wait_slot2_" + i), "s05 второй кружок " + order[i], 20000); await tap("slot" + pos[1]); }
    { const s1 = await waitFor((s) => s.info && s.info.s05_left === i, "s05 left " + i, 20000);
      if (s1.info.s05_cards_visible !== 0) throw new Error(`s05: карточка слова ${i + 1} осталась вверху после отъезда`);
      const d = s1.info.s05_drive_out; console.log(`s05 слово ${i + 1} «${order[i]}» (окошки ${pos}): уехал ${JSON.stringify(d)}`); }
  }
  if (new Set(order).size !== 5) throw new Error("s05: слова повторились: " + order);
  { const s = await waitFor((s) => s.targets.ride_tap_big && s.targets.ride_tap_small && s.info.s05_letters_in, "s05: буквы въехали по рельсам", 20000);
    const [[bx, by], [sx, sy]] = s.info.s05_letters_in;
    if (!(bx < sx) || Math.abs((bx + sx) / 2 - 512) > 60) throw new Error("s05: буквы встали не по центру: " + JSON.stringify(s.info.s05_letters_in));
    if (!((s.sfx_counts || {}).sfx_train_clack >= 10)) throw new Error("s05: нет перестука колёс: " + (s.sfx_counts || {}).sfx_train_clack);
    if (!s.info.s05_clouds || !s.info.s05_grass) throw new Error("s05: нет облаков/травы");
    await sleep(300); await shot("s05-words-letters");
    await tap("ride_tap_big"); await sleep(400);
    if ((await bk()).info.s05_letter_tap !== "А") throw new Error("s05: касание буквы на рельсах не сработало");
    await waitFor(state("done"), "s05 done", 30000);
    await tap("cell_card2"); await sleep(400);
    if ((await bk()).info.s05_cell_tap !== order[2]) throw new Error("s05: касание карточки в ячейке не дало слово");
    if (!(await bk()).targets.next) throw new Error("s05: нет «Далее» в конце");
    console.log(`s05: порядок ${order.join(", ")}; перестук ${s.sfx_counts.sfx_train_clack}; буквы на рельсах ${JSON.stringify(s.info.s05_letters_in.map((p) => p.map(Math.round)))}; ячейки нажимаются`); }
  await shot("s05-words-done"); await next("s05_words");
  // s06
  await waitFor(state("wait_letters"), "s06 letters"); await shot("s06-letter");
  { // s06: Аля-персонаж; касание буквы — её реплика с подсветкой частей; большая А — левая рука, маленькая а — правая
    const s0 = await bk();
    if (!s0.targets.alya) throw new Error("s06: нет Али-персонажа");
    const b0 = sfxSnap(s0);
    await tap("big");
    await waitFor((s) => s.info.s06_seen && s.info.s06_seen.big, "s06: касание большой А");
    await sleep(1200);
    await assertNoConfirm("s06 (нажата только большая А)", "wait_letters", b0, 300); noConfirmChecked.push("s06");
    const hl = (await bk()).info.s06_hl_seen || [];
    for (const p of ["big:left", "big:right", "big:bar"]) if (!hl.includes(p)) throw new Error("s06: не подсветилась часть " + p + " " + JSON.stringify(hl));
    if ((await bk()).info.s06_arm !== "l") throw new Error("s06: на большую А не левая рука (arm l): " + (await bk()).info.s06_arm);
    await tap("big"); await sleep(400);
    if ((await bk()).state !== "wait_letters") throw new Error("s06: повторное касание А завершило сцену");
    await tap("small");
    await waitFor((s) => s.info.s06_arm === "r", "s06: на маленькую а — правая рука (arm r)", 10000);
    const s1 = await waitFor(state("done"), "s06 done");
    const hl1 = s1.info.s06_hl_seen || [];
    for (const p of ["small:round", "small:stick", "big", "small"]) if (!hl1.includes(p)) throw new Error("s06: не подсветилось " + p + " " + JSON.stringify(hl1));
    if (!s1.info.s06_outro) throw new Error("s06: не было итоговой реплики a_letter_04");
    console.log("s06: руки " + JSON.stringify(s1.info.s06_arms) + "; подсветка " + JSON.stringify(hl1) + "; итог → «Далее»");
  }
  await next("s06_letter");
  // s07: большая А (3 штриха; сначала 3 раза мимо), затем маленькая а (кружок + палочка с хвостиком) — по дорожке s07_path
  await waitFor(state("wait_stroke_0"), "s07 stroke 0"); await shot("s07-write");
  { const b0 = sfxSnap(await bk());
    for (let n = 0; n < 3; n++) { const a = await target("stroke_start"); await drag(a, [a[0] + 200, a[1] + 40]); await sleep(n === 1 ? 3200 : 1500); }
    await assertNoConfirm("s07 (3 штриха мимо)", "wait_stroke_0", b0, 500); noConfirmChecked.push("s07");
    await sleep(1500); }
  async function tracePath(pts) {
    const P = []; for (let j = 0; j < pts.length; j++) { if (j) { const [ax, ay] = pts[j - 1], [bx, by] = pts[j]; const n = Math.max(1, Math.ceil(Math.hypot(bx - ax, by - ay) / 12));
      for (let q = 1; q <= n; q++) P.push([ax + (bx - ax) * q / n, ay + (by - ay) * q / n]); } else P.push(pts[0]); }
    if (TOUCH) { await page.touchscreen.touchStart(P[0][0], P[0][1]); await sleep(60); for (const p of P.slice(1)) { await page.touchscreen.touchMove(p[0], p[1]); await sleep(16); } await page.touchscreen.touchEnd(); }
    else { await page.mouse.move(P[0][0], P[0][1]); await page.mouse.down(); for (const p of P.slice(1)) { await page.mouse.move(p[0], p[1]); await sleep(16); } await page.mouse.up(); }
    await sleep(200);
  }
  for (let k = 0; k < 3; k++) {
    const s = await waitFor((s) => s.state === "wait_stroke_" + k && s.info.s07_path, "s07 stroke " + k);
    await tracePath(s.info.s07_path);
    if (k === 0) { await sleep(200); await shot("s07-write-stroke1"); }
  }
  await waitFor((s) => s.info.s07_done_upper, "s07: большая А обведена", 20000);
  for (let k = 0; k < 2; k++) {
    const s = await waitFor((s) => s.state === "wait_lower_" + k && s.info.s07_path && s.info.s07_phase === "lower", "s07 маленькая а, штрих " + k, 30000);
    if (k === 0) { await sleep(300); await shot("s07-write-lower"); }
    await tracePath(s.info.s07_path);
  }
  await waitFor(state("done"), "s07 done"); await shot("s07-write-done");
  if (!(await bk()).info.s07_done_lower) throw new Error("s07: маленькая а не засчитана");
  console.log("s07: большая А (3 штриха) → маленькая а (2 штриха по дорожке)");
  await next("s07_write");
  // s08: шарики; по бокам — столбики звёзд под А и а; облако; в конце остальные шарики тихо лопаются, потом буквы
  await waitFor(state("wait_balloons"), "s08 balloons"); await sleep(3000); await shot("s08-find");
  { const st = (await bk()).info.s08_stars; if (!st) throw new Error("s08: нет столбиков звёзд"); }
  { const b0 = sfxSnap(await bk()); let nw = 0;
    for (let n = 0; n < 40 && nw < 2; n++) { const s = await bk();
      if (s.targets.wrong_balloon) { const w = s.targets.wrong_balloon; TOUCH ? await page.touchscreen.tap(w[0], w[1]) : await page.mouse.click(w[0], w[1]); nw++; await sleep(900); }
      else await sleep(300); }
    if (nw < 2) throw new Error("s08: не нашлось шариков-помех для проверки");
    await assertNoConfirm("s08 (2 ошибки)", "wait_balloons", b0, 1500); noConfirmChecked.push("s08"); }
  for (let n = 0; n < 120; n++) {
    const s = await bk(); if (s.state === "done") break;
    if (s.targets && s.targets.balloon) { const b = s.targets.balloon; TOUCH ? await page.touchscreen.tap(b[0], b[1]) : await page.mouse.click(b[0], b[1]); }
    await sleep(400);
  }
  await waitFor(state("done"), "s08 done");
  { await waitFor((s) => s.targets && s.targets.end_big && s.targets.end_small, "s08: А и а в центре", 8000);
    const s0 = await bk(); if (s0.info.s08_end_popped === undefined) throw new Error("s08: оставшиеся шарики не лопнули в конце");
    await sleep(800); await shot("s08-find-letters");
    await tap("end_big"); await sleep(500); await tap("end_small"); await sleep(500);
    const s1 = await bk();
    const [bx] = s1.targets.end_big, [sx] = s1.targets.end_small;
    if (!(bx < sx)) throw new Error("s08: большая А не слева от маленькой а");
    if (!s1.targets.next) throw new Error("s08: нет «Далее» после шариков");
    console.log(`s08: звёзды ${JSON.stringify(s1.info.s08_stars)}; в конце лопнуло ${s0.info.s08_end_popped}; А и а в центре`);
  }
  await next("s08_find");
  // s09: кактусы-корзинки; солнце с полупрозрачными лучами; верный бросок — звук буквы
  await waitFor(state("wait_drag"), "s09 drag"); await shot("s09-sort");
  if (!(await bk()).info.s09_sun) throw new Error("s09: нет солнца");
  { const b0 = sfxSnap(await bk()); await tap("basket_big"); await sleep(600);
    const s = await bk(); if (s.info && s.info.s09_done_taps !== undefined) throw new Error("s09: корзинка ответила на касание до конца сцены");
    await assertNoConfirm("s09 (касание корзинки до конца)", "wait_drag", b0); }
  let wrongDone = false;
  for (let n = 0; n < 20; n++) {
    const s = await bk(); if (s.state === "done") break;
    const t = s.targets.tile, b = s.targets.tile_basket;
    if (t && b) {
      if (!wrongDone) {
        const b0 = sfxSnap(await bk());
        for (let k = 0; k < 2; k++) { const s2 = await bk(); const t2 = s2.targets.tile, bb = s2.targets.tile_basket;
          const o2 = (bb[0] === s2.targets.basket_big[0]) ? s2.targets.basket_small : s2.targets.basket_big;
          await drag(t2, o2, 16); await sleep(1600); }
        await assertNoConfirm("s09 (2 ошибки)", "wait_drag", { ...b0, sfx_pop: (sfxSnap(await bk())).sfx_pop }); noConfirmChecked.push("s09");
        { const i8 = (await bk()).info || {}; if ((i8.s09_state_big || 0) !== 0 || (i8.s09_state_small || 0) !== 0) throw new Error(`s09: после ошибок корзинка наполнилась`);
          if (i8.s09_drop_says) throw new Error("s09: звук буквы на неверном броске"); }
        wrongDone = true; continue; }
      await drag(t, b, 16);
      if (n === 2) await shot("s09-sort-progress");
    }
    await sleep(700);
  }
  await waitFor(state("done"), "s09 done"); await shot("s09-sort-done");
  { const s = await waitFor((s) => s.info && s.info.s09_state_big === 4 && s.info.s09_state_small === 4, "s09: обе корзинки полные", 6000);
    if (!(s.info.s09_drop_says >= 6) || !["a_aaa", "a_find_03"].includes(s.info.s09_drop_audio)) throw new Error("s09: верный бросок без звука буквы: " + JSON.stringify([s.info.s09_drop_says, s.info.s09_drop_audio]));
    console.log(`s09: корзинки ${s.info.s09_state_big}/${s.info.s09_state_small}; звук буквы на верных бросках: ${s.info.s09_drop_says} (${s.info.s09_drop_audio})`); passed.push("s09-v3-states"); }
  { await waitFor((s) => s.info && s.info.s09_done_taps === 0, "s09: корзинки слушают касания");
    for (const [k, name] of [[1, "basket_big"], [2, "basket_small"]]) {
      await tap(name); await sleep(400);
      const s = await bk(); const pk = s.info.s09_bounce_peak || {}; const up = pk.n === k ? pk.px : 0; if (s.info.s09_done_taps !== k) throw new Error(`s09: касание ${name} после конца не сработало`);
      if (up < 3) throw new Error(`s09: ${name} не подпрыгнула (${up.toFixed(1)} px)`);
      await sleep(400); }
    passed.push("s09-done-basket-aaa"); }
  await next("s09_sort");
  // s10: кнопка взрослого (задание 2 — «ещё раз», затем «✓»; задание 4 — два раза «ещё раз» → серебряная звезда)
  for (let i = 0; i < 4; i++) {
    if (i === 0) { // пока звучит задание 9.1, дуги загораются по очереди
      const lit = new Set(); const t0 = Date.now();
      while (Date.now() - t0 < 30000) { const s = await bk(); if (s.info && s.info.s10_arcs_lit !== undefined) lit.add(s.info.s10_arcs_lit); if (s.state === "wait_parent_0") break; await sleep(40); }
      console.log("s10 9.1: замечено дуг горящими:", [...lit].sort().join(","));
      if (![1, 2, 3].some((n) => lit.has(n))) throw new Error("s10: дуги на карточке 9.1 не загорались");
    }
    await waitFor(state("wait_parent_" + i), "s10 parent " + i);
    await sleep(1100);   // кнопка игнорирует нажатия чаще 1 раза в секунду
    if (i === 0) { await checkExit("s10 (кнопка взрослого)"); await shot("s10-say-parent-button"); }
    { // карточки сцены 9 — без красных предметов (кроме самой буквы А в задании 4)
      const s = await bk(); const card = s.info && s.info.s10_card;
      if (!card || card.i !== i) throw new Error("s10: нет сведений о карточке " + i);
      const rf = await redFraction(card.rect);
      console.log(`s10 карточка ${i + 1}: ${card.id}, красных пикселей ${(rf * 100).toFixed(2)} %`);
      if (card.id === "sound") {
        // 9.1 «произнеси [а]»: только плоский кружок ≈42 % ширины (площадь ≈ 0,42²·π/4 ≈ 14 % карточки), без глянцевого шара
        if (s.info.s10_card_content !== "sound") throw new Error("s10: карточка 9.1 — не звуковое задание");
        if (rf < 0.08 || rf > 0.22) throw new Error(`s10: на карточке 9.1 кружок не того размера (${(rf * 100).toFixed(1)} %)`);
      } else if (card.id !== "letter_big" && rf > 0.005) throw new Error(`s10: красный предмет на карточке ${card.id} (${(rf * 100).toFixed(1)} %)`);
      // непрозрачная кремовая подложка: центр-верх карточки внутри рамки — кремовый
      if (!card.id.startsWith("pic_alya_card")) { const [x, y, w] = card.rect; const cf = await creamAt(x + w / 2, y + 14);
        if (!cf) throw new Error("s10: нет кремовой подложки у карточки " + card.id); }
    }
    if (i === 1 || i === 3) {
      await tap("parent_retry");
      await waitFor((s) => !s.targets.parent_ok, "s10 hide");
      if (i === 3) { await waitFor((s) => s.targets.parent_ok, "s10 reshow", 20000); await sleep(1100); await tap("parent_retry"); continue; }
      await waitFor((s) => s.targets.parent_ok, "s10 reshow", 20000); await sleep(1100);
    }
    { const c0 = ((await bk()).sfx_counts || {}).sfx_click || 0; await tap("parent_ok"); await sleep(150);
      const c1 = ((await bk()).sfx_counts || {}).sfx_click || 0; if (!(c1 > c0)) throw new Error("s10: нет щелчка на кнопке взрослого ✓"); }
  }
  await waitFor(state("done"), "s10 done"); await shot("s10-say-done"); await next("s10_say");
  // s11 финал: Аля слева, справа от центра — большая наклейка «А а»; касание → альбом, наклейка уменьшается в ячейку;
  // без кнопок взрослого и полки; «Ещё раз» (круглая) → урок сначала
  await waitFor((s) => s.step === "s11_end" && s.state === "wait_sticker" && s.targets.sticker, "s11 наклейка", 40000);
  await sleep(500); await shot("s11-end"); await checkExit("s11_end");
  { const s = await bk(); const t = s.targets;
    for (const k of ["parent_ok", "parent_retry", "parent_info", "home", "next", "again", "shelf"]) if (t[k]) throw new Error("s11: лишняя кнопка " + k);
    if (!(t.sticker[0] > 512)) throw new Error("s11: наклейка не правее центра: " + t.sticker);
    if (t.alya && !(t.alya[0] < 512)) throw new Error("s11: Аля не слева"); }
  await tap("sticker");
  { const s = await waitFor((s) => s.info.s11_placed && s.state === "done" && s.targets.again, "s11: наклейка в альбоме, «Ещё раз»", 20000);
    const [px, py, pw, ph] = s.info.s11_placed, [cx, cy, cw, ch] = s.info.s11_cell;
    if (Math.abs(px + pw / 2 - (cx + cw / 2)) > 4 || Math.abs(py + ph / 2 - (cy + ch / 2)) > 4 || pw > cw + 2) throw new Error("s11: наклейка не в ячейке: " + JSON.stringify([s.info.s11_placed, s.info.s11_cell]));
    await sleep(400); await shot("s11-end-album");
    const n0 = s.info.s11_taps || 0; await tap("sticker"); await sleep(400);
    const s2 = await bk(); if ((s2.info.s11_taps || 0) !== n0 + 1 || !["a_aaa", "a_find_03"].includes(s2.info.s11_tap_audio)) throw new Error("s11: касание наклейки в альбоме без звука: " + JSON.stringify([s2.info.s11_taps, s2.info.s11_tap_audio]));
    console.log(`s11: наклейка в ячейке ${JSON.stringify(s.info.s11_cell.map(Math.round))}; касание после — ${s2.info.s11_tap_audio}`); }
  await tap("again");
  await waitFor((s) => s.step === "s01_stork", "s11 «Ещё раз» → s01", 30000);
  console.log("s11: «Ещё раз» → урок сначала (s01)");
  passed.push("s11_end");
  // крестик: «Пока! Увидимся!» → главная
  await sleep(600);
  { const [x, y] = await target("exit"); let bye = false;
    const nav = page.waitForNavigation({ waitUntil: "load", timeout: 15000 });
    await tapXY([x, y]);
    for (let n = 0; n < 40 && !bye; n++) { const s = await page.evaluate(() => window.__bk || {}).catch(() => ({})); if (s.state === "exit_bye") bye = true; else await sleep(40); }
    await nav;
    if (!bye) throw new Error("крестик: не было прощания «Пока! Увидимся!» перед выходом");
    console.log("крестик: прощание exit_bye → главная"); }
  await homeReady("крестик → главная");
  if (new URL(page.url()).pathname !== "/") throw new Error("крестик привёл не на главную: " + page.url());
  await sleep(500); await shot("letters-menu");
  { const h = await home(); await tapXY(h.targets.letter_locked); await sleep(600);
    if (new URL(page.url()).pathname !== "/") throw new Error("закрытая буква «Б» открыла урок"); }
  await homeToLesson();
  console.log("повторный вход в «А»: сразу s01");
  // крестик посреди урока (аист ещё летит): s01 → главная → «А» → s01
  await checkExit("s01_stork"); await shot("s01-stork-exit");
  { const [x, y] = await target("exit"); await tapNav([x, y], "крестик s01"); }
  await homeReady("крестик → главная");
  await homeToLesson();
  { const miss = ["s01_stork","s02_intro","s03_sing","s04_hear","s05_words","s06_letter","s07_write","s08_find","s09_sort","s10_say","s11_end"].filter((n) => !exitSeen.has(n));
    if (miss.length) throw new Error("нет крестика на: " + miss.join(", ")); }
  console.log("крестик: виден на s01–s11 без перекрытий; выход → главная → «А» → s01 — ок");
  passed.push("exit→главная→А→s01");
  // звук на iOS: без жеста на странице s01 ждёт касания (пустое гнездо пульсирует, рука на нём); касание → аист влетает
  await page.goto(`http://127.0.0.1:${PORT}/lesson-a/index.html?test=1&fast=1&gate=1&hint_sec=1`, { waitUntil: "load" });
  { const s = await waitFor((s) => s.step === "s01_stork" && s.state === "wait_unlock" && s.targets.nest, "gate: s01 wait_unlock", 60000);
    if (s.targets.stork || s.targets.next) throw new Error("gate: аист/«Далее» до первого касания");
    const h = await waitFor((s) => s.targets.hint_hand, "gate s01: рука на гнезде", 6000);
    if (Math.hypot(h.targets.hint_hand[0] - h.targets.nest[0], h.targets.hint_hand[1] - h.targets.nest[1]) > 160) throw new Error("gate s01: рука не у гнезда");
    await sleep(2000);
    if ((await bk()).state !== "wait_unlock") throw new Error("gate: s01 пошла без касания");
    await shot("s01-stork-gate");
    await tap("nest");
    await waitFor((s) => s.state === "fly_in", "gate: касание → s01 fly_in", 15000);
    // дальше по «Далее» — s02 без второго ожидания (касание на странице уже было)
    await waitFor(state("done"), "gate: s01 done", 30000); await sleep(300); await tap("next");
    await waitFor((s) => s.step === "s02_intro" && s.state === "wait_alya", "gate: s01 → s02 без второго ожидания", 30000);
    console.log("gate=1: s01 ждёт касания (wait_unlock, гнездо пульсирует, рука на гнезде), касание → влёт; s02 после s01 — без ожидания"); }
  passed.push("s01-audio-gate");
  // подсказка s01: без касаний — рука на большой «А» (без голоса), после посадки — на «Далее»
  await page.goto(`http://127.0.0.1:${PORT}/lesson-a/index.html?test=1&fast=1&hint_sec=1&step=1`, { waitUntil: "load" });
  { await waitFor((s) => s.step === "s01_stork" && s.info.s01_letters_down, "s01 hint: буквы на земле", 30000);
    const s = await waitFor((s) => s.targets.hint_hand && s.targets.big, "s01 hint: рука", 6000);
    if (s.state === "done") throw new Error("s01 hint: рука появилась только после посадки");
    if (Math.hypot(s.targets.hint_hand[0] - s.targets.big[0], s.targets.hint_hand[1] - s.targets.big[1]) > 200) throw new Error("s01 hint: рука не на «А»");
    await shot("s01-stork-hint-big");
    const n = await waitFor((s) => s.state === "done" && s.targets.next && s.targets.hint_hand && Math.hypot(s.targets.hint_hand[0] - s.targets.next[0], s.targets.hint_hand[1] - s.targets.next[1]) < 160, "s01 hint: рука на «Далее»", 12000);
    if (n.caption) throw new Error("s01 hint: рука с голосом");
    console.log("s01 подсказка: рука на «А» во время полёта/после падения букв, после посадки — на «Далее»"); }
  passed.push("s01-hint");
  // урок открыт сразу со сцены 2 (?step=2): s02 ждёт касания (Аля пульсирует); касание → реплика → wait_alya
  await page.goto(`http://127.0.0.1:${PORT}/lesson-a/index.html?test=1&fast=1&gate=1&step=2`, { waitUntil: "load" });
  { const s = await waitFor((s) => s.step === "s02_intro" && s.state === "wait_unlock", "gate: s02 wait_unlock", 60000);
    await sleep(2500);
    if ((await bk()).state !== "wait_unlock") throw new Error("gate: s02 пошла без касания");
    await sleep(400); await tap("alya");
    await waitFor((s) => s.state === "wait_alya", "gate: касание → s02 wait_alya", 15000);
    console.log("gate=1: s02 ждёт касания (wait_unlock), после касания — реплика и wait_alya"); }
  passed.push("s02-audio-gate");
  console.log("без автоподтверждения после неверных попыток:", noConfirmChecked.join(", "));
  if (noConfirmChecked.length < 6) throw new Error("проверены не все игры на «без автоподтверждения»: " + noConfirmChecked.join(","));
  const log = await page.evaluate(() => (window.__bk || {}).log);
  console.log("журнал событий (записей):", log);
  if (textViolations.size) throw new Error("текст на экране ребёнка:\n" + [...textViolations].join("\n"));
  console.log("субтитры без debug: ни разу не показаны; текст на экране ребёнка — только А/а");
  // с ?debug=1 субтитры появляются
  await page.goto(`http://127.0.0.1:${PORT}/lesson-a/index.html?test=1&fast=1&debug=1&step=s02_intro`, { waitUntil: "load" });
  await waitFor((s) => s.step === "s02_intro", "deep link ?step=s02_intro → s02", 60000);
  console.log("deep link ?step=s02_intro: сразу s02");
  await waitFor((s) => s.caption_visible, "debug: субтитр виден", 60000);
  await shot("debug-subtitles-s02");
  console.log("debug=1: субтитры показаны");
  // рука-подсказка с укороченным таймером: s04, ждём картинку
  await page.goto(`http://127.0.0.1:${PORT}/lesson-a/index.html?test=1&fast=1&hint_sec=3&step=s05_words`, { waitUntil: "load" });
  await waitFor(state("wait_pic_0"), "idle: s04 wait_pic_0", 60000);
  { const t0 = Date.now(); await sleep(1500);
    if ((await bk()).targets.hint_hand) throw new Error("idle: рука появилась раньше таймера");
    const s = await waitFor((s) => s.targets.hint_hand, "idle: рука через 3 с", 6000);
    const dt = (Date.now() - t0) / 1000; const [hx, hy] = s.targets.hint_hand, [px, py] = s.targets.pic;
    console.log(`idle: рука появилась через ${dt.toFixed(1)} с (hint_sec=${s.hint_sec}), над картинкой: ${Math.hypot(hx - px, hy - py) < 120}`);
    if (Math.hypot(hx - px, hy - py) > 120) throw new Error("idle: рука не над картинкой");
    await sleep(300); await shot("s04-hint-hand");
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
  // s09 (перетаскивание): рука держится, касание корзинки (неверное действие) её не прячет, начало перетаскивания плитки — прячет
  await page.goto(`http://127.0.0.1:${PORT}/lesson-a/index.html?test=1&fast=1&hint_sec=2&step=s09_sort`, { waitUntil: "load" });
  await waitFor(state("wait_drag"), "idle: s09 wait_drag", 60000);
  { const s = await waitFor((s) => s.targets.hint_hand && s.targets.tile, "idle: s09 рука", 8000);
    await sleep(4500);
    if (!(await bk()).targets.hint_hand) throw new Error("idle s09: рука исчезла по таймеру");
    await tapXY(s.targets.basket_small); await sleep(600);
    if (!(await bk()).targets.hint_hand) throw new Error("idle s09: касание корзинки спрятало руку");
    const [x, y] = s.targets.tile;
    if (TOUCH) { await page.touchscreen.touchStart(x, y); } else { await page.mouse.move(x, y); await page.mouse.down(); }
    await waitFor((s) => !s.targets.hint_hand, "idle s09: начало перетаскивания прячет руку", 1500);
    if (TOUCH) await page.touchscreen.touchEnd(); else await page.mouse.up();
    console.log("idle s09: рука держится >6 с, касание корзинки не прячет, взяли плитку — рука спряталась"); }
  passed.push("idle-hint-drag");
  // бездействие с короткой подсказкой (hint_sec=1): рука показывается, но шаг сам не подтверждается
  for (const [step, st] of [["s03_sing", "wait_hold"], ["s04_hear", "wait_answer_0"], ["s05_words", "wait_pic_0"], ["s06_letter", "wait_letters"], ["s08_find", "wait_balloons"], ["s09_sort", "wait_drag"]]) {
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
