// Тест HTML-главной (web-home/ в корне сайта) + переход в урок lesson-a/ и обратно, в headless Chrome касаниями.
// Сайт собирается как в CI:  bash tests/assemble_site.sh   (корень = web-home/, lesson-a/ = build/)
// Проверяет: главная не тянет Godot (*.wasm/*.pck/index.js), её вес; раскладка (сетка букв сверху — 7×5 на 4:3, 9×4/11×3 на широких,
// 5×7/4×9 на узких — самый крупный кубик с учётом ряда кнопок; под ней ряд из 6 значков-
// разделов с подписями, вариант B, без подложек) на 4:3, 16:10, 16:9 и телефонах без прокрутки и наложений: все 6 — в одну строку,
// не налезают друг на друга, на буквы и на «i»; значки загрузились; кнопки только «нажимаются»; закрытая буква качается и никуда не ведёт; руки-подсказки на главной НЕТ;
// кнопка «i» (левый нижний угол, не на кубиках/кнопках) → страница сведений (общая для всех уроков, текст web-home/info.html) → тёмно-серый крестик → буквы;
// тап «А» → мгновенный отклик → lesson-a/ с параметрами → сразу s01 (экрана s00 нет); крестик и «?step=» → обратно на главную.
// Запуск: PORT=<свободный> node tests/home.mjs [папка-сайта, по умолчанию ../site]
import { createRequire } from "module"; import { spawn } from "child_process"; import path from "path"; import fs from "fs"; import { fileURLToPath } from "url";
const require = createRequire(import.meta.url);
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const puppeteer = require(path.resolve(ROOT, "../.tools/node_modules/puppeteer-core"));
const PORT = +(process.env.PORT || 55783), BASE = `http://127.0.0.1:${PORT}`;
const SITE = path.resolve(process.argv[2] || path.join(ROOT, "../site"));
const SHOTS = path.join(ROOT, "screenshots"); fs.mkdirSync(SHOTS, { recursive: true });
const srv = spawn("node", [path.join(ROOT, "tests/serve.mjs"), SITE, String(PORT)], { stdio: "ignore", env: { ...process.env, NOCOI: "1" } });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const errors = [], passed = []; let browser, page;
const ok = (cond, msg) => { if (!cond) throw new Error(msg); };
const home = () => page.evaluate(() => window.__home || {}).catch(() => ({}));
const bk = () => page.evaluate(() => window.__bk || {}).catch(() => ({}));
async function until(get, fn, desc, timeout = 30000) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeout) { const s = await get(); if (fn(s)) return s; await sleep(80); }
  throw new Error("timeout: " + desc + " | last=" + JSON.stringify(await get()).slice(0, 400));
}
// Заставка загрузки Godot (#status) ещё гаснет поверх холста первые ≈0,5 с — касание по ней в игру не доходит.
// Короткие сцены (s05 в fast-режиме) успевают дойти до wait_* раньше, поэтому перед касанием ждём, пока она исчезнет.
const statusGone = () => page.waitForFunction(() => { const e = document.getElementById("status"); if (!e) return true; const cs = getComputedStyle(e); return cs.visibility === "hidden" || cs.display === "none" || +cs.opacity === 0; }, { timeout: 10000 }).catch(() => {});
const tapAt = async ([x, y]) => { await statusGone(); await page.touchscreen.tap(x, y); };
const tapNav = async (xy, what = "") => { const from = page.url(); try { await Promise.all([page.waitForNavigation({ waitUntil: "load", timeout: 10000 }), tapAt(xy)]); } catch (e) { throw new Error(`нет перехода после тапа ${what} (${from} → ${page.url()}): ${e.message}`); } };
const shot = (name) => page.screenshot({ path: path.join(SHOTS, name + ".png") });
async function view(w, h) { await page.setViewport({ width: w, height: h, hasTouch: true, isMobile: false }); await sleep(300); }
async function noScroll(where) {
  const r = await page.evaluate(() => ({ sw: document.documentElement.scrollWidth, sh: document.documentElement.scrollHeight, w: innerWidth, h: innerHeight }));
  ok(r.sw <= r.w && r.sh <= r.h, `${where}: есть прокрутка ${JSON.stringify(r)}`);
}
// средняя разница двух PNG (0…255) — считаем в странице через canvas
async function diffPng(a, b) {
  const [A, B] = [a, b].map((f) => "data:image/png;base64," + fs.readFileSync(f).toString("base64"));
  return page.evaluate(async (A, B) => {
    const load = async (s) => { const i = new Image(); i.src = s; await i.decode(); const c = document.createElement("canvas");
      c.width = i.width; c.height = i.height; const g = c.getContext("2d"); g.drawImage(i, 0, 0); return g.getImageData(0, 0, c.width, c.height).data; };
    const x = await load(A), y = await load(B); let s = 0, big = 0;
    for (let i = 0; i < x.length; i += 4) { const d = (Math.abs(x[i] - y[i]) + Math.abs(x[i + 1] - y[i + 1]) + Math.abs(x[i + 2] - y[i + 2])) / 3; s += d; if (d > 40) big++; }
    return { mean: s / (x.length / 4), bigShare: big / (x.length / 4) };
  }, A, B);
}
try {
  await sleep(700);
  browser = await puppeteer.launch({ executablePath: "/usr/bin/google-chrome", headless: "new",
    args: ["--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist", "--mute-audio"] });
  page = await browser.newPage();
  page.on("console", (m) => { if (m.type() === "error") errors.push("console: " + m.text()); });
  page.on("pageerror", (e) => errors.push("pageerror: " + e.message));
  const reqs = [];
  page.on("response", (r) => reqs.push({ url: r.url(), status: r.status(), len: +(r.headers()["content-length"] || 0) }));
  // 1) главная: без Godot, вес
  await view(1024, 768);
  await page.goto(`${BASE}/`, { waitUntil: "networkidle0" });
  await until(home, (s) => s.state === "wait_letter", "home ready", 10000);
  { const godot = reqs.filter((r) => /\.(wasm|pck)(\?|$)|lesson-a\//.test(r.url));
    ok(!godot.length, "главная грузит урок: " + godot.map((r) => r.url).join(", "));
    const bad = reqs.filter((r) => r.status >= 400); ok(!bad.length, "ошибки загрузки: " + bad.map((r) => r.status + " " + r.url).join(", "));
    const total = reqs.reduce((a, r) => a + r.len, 0);
    console.log(`главная: ${reqs.length} запросов, передано ${total} Б (${(total / 1024).toFixed(1)} КБ, html — gzip), без *.wasm/*.pck`);
    for (const r of reqs) console.log("   ", r.status, r.len, r.url.replace(BASE, ""));
    ok(total < 1.5e6, "главная тяжелее 1,5 МБ");
    ok(!(await page.evaluate(() => document.getElementById("hand"))), "на главной осталась рука-подсказка"); }
  passed.push("home: без Godot");
  // 2) раскладка: кубики 7×5, ряд из 6 разделов с подписями, «i» — всё в окне, без прокрутки и наложений
  async function checkLayout(w, h) {
    await view(w, h); await noScroll(`${w}×${h}`);
    const L = await page.evaluate(() => {
      const R = (e) => { const r = e.getBoundingClientRect(); return { l: r.left, t: r.top, r: r.right, b: r.bottom, w: r.width, h: r.height }; };
      return { vw: innerWidth, vh: innerHeight, top: R(document.getElementById("topbar")),
        cubes: [...document.querySelectorAll(".cube")].map(R),
        btns: [...document.querySelectorAll("#bottombar .rb")].map((e) => { const im = e.querySelector("img"), c = e.querySelector(".cap");
          return { ...R(e), slot: e.dataset.slot, section: e.dataset.section, label: e.getAttribute("aria-label"), img: im && im.getAttribute("src"),
            imgOk: !!(im && im.complete && im.naturalWidth >= 200), imgR: im && R(im), cap: c && c.textContent, capR: c && R(c),
            capFs: c && parseFloat(getComputedStyle(c).fontSize), capColor: c && getComputedStyle(c).color, capWeight: c && getComputedStyle(c).fontWeight,
            capOverflow: c ? c.scrollWidth - c.clientWidth : 0, bg: getComputedStyle(e).backgroundColor, border: getComputedStyle(e).borderTopWidth, shadow: getComputedStyle(e).boxShadow }; }),
        info: R(document.getElementById("info-btn")),
        fs: parseFloat(getComputedStyle(document.querySelector(".cube span")).fontSize), home: window.__home };
    });
    const where = `${w}×${h}`, inside = (r) => r.l >= 0 && r.t >= 0 && r.r <= L.vw + 0.5 && r.b <= L.vh + 0.5;
    ok(L.vw === w && L.vh === h, `${where}: окно ${L.vw}×${L.vh}`);
    const cubesSorted = L.cubes;   // кубики не налезают друг на друга
    for (let i = 0; i < cubesSorted.length; i++) for (let j = i + 1; j < cubesSorted.length; j++) {
      const a = cubesSorted[i], b = cubesSorted[j]; ok(a.r <= b.l + 0.5 || b.r <= a.l + 0.5 || a.b <= b.t + 0.5 || b.b <= a.t + 0.5, `${where}: кубики ${i} и ${j} налезают`); }
    ok(L.cubes.length === 33 && L.cubes.every(inside), `${where}: кубики за краем окна`);
    const cubesTop = Math.min(...L.cubes.map((c) => c.t)), cubesBot = Math.max(...L.cubes.map((c) => c.b));
    ok(cubesTop >= L.top.h - 1 && cubesTop >= 8 - 0.5, `${where}: кубики у самого верха (${cubesTop})`);
    ok([4, 5, 7, 9, 11].includes(L.home.cols) && L.home.cube >= L.home.cube7, `${where}: сетка ${L.home.cols} столбцов, кубик ${L.home.cube} мельче, чем при 7×5 (${L.home.cube7})`);
    if (Math.abs(w / h - 4 / 3) < 0.12) ok(L.home.cols === 7, `${where}: на 4:3 должно быть 7×5, а ${L.home.cols}`);
    if (L.home.cols !== 7) ok(L.home.cube >= L.home.cube7 * 1.12 - 1, `${where}: сетка ${L.home.cols} столбцов, хотя кубик крупнее 7×5 меньше чем на 12 %`);
    if (L.home.cols > 7) ok(w > h, `${where}: широкая сетка на вертикальном экране`);
    if (L.home.cols < 7) ok(h > w, `${where}: узкая сетка на горизонтальном экране`);
    const SEC = ["alfavit", "slogi", "slova", "chitaem", "nakleyki", "zhesty"], CAPS = ["Алфавит", "Слоги", "Слова", "Читаем", "Мои наклейки", "Язык жестов"];
    ok(L.btns.length === 6, `${where}: кнопок ${L.btns.length}, нужно 6`);
    L.btns.forEach((b, i) => {
      ok(b.slot === String(i + 1) && b.section === SEC[i] && b.label && b.label.startsWith(CAPS[i]), `${where}: кнопка ${i + 1} — не «${CAPS[i]}» (${b.section}, ${b.label})`);
      ok(b.img === `assets/home_${i + 1}_${SEC[i]}.png` && b.imgOk, `${where}: значок ${i + 1} не загрузился (${b.img})`);
      ok(b.cap === CAPS[i] && b.capR && b.capR.h > 0 && b.capOverflow <= 0, `${where}: подпись ${i + 1} «${b.cap}» не видна или не влезает`);
      ok(/rgba\(0, 0, 0, 0\)|transparent/.test(b.bg) && parseFloat(b.border) === 0 && b.shadow === "none", `${where}: у значка ${i + 1} есть подложка/рамка (${b.bg}, ${b.border}, ${b.shadow})`);
      ok(+b.capWeight >= 700 && /rgb\(60, 50, 40\)/.test(b.capColor), `${where}: подпись ${i + 1} не тёмная жирная (${b.capColor}, ${b.capWeight})`);
      ok(Math.abs((b.capR.l + b.capR.r) / 2 - (b.l + b.r) / 2) < 1 && b.capR.t >= b.b - 0.5, `${where}: подпись ${i + 1} не по центру под значком`);
      ok(inside(b) && inside(b.capR) && b.t > cubesBot, `${where}: кнопка ${i + 1} вне окна или не под буквами ${JSON.stringify(b.capR)}`);
      ok(Math.abs(b.w - b.h) < 1 && b.w >= 44, `${where}: кнопка ${i + 1} ${b.w}×${b.h} (меньше 44 или не квадрат)`);
      ok(b.l >= 12 - 0.5 && b.r <= L.vw - 12 + 0.5, `${where}: кнопка ${i + 1} ближе 12 px к боковому краю (${b.l.toFixed(1)}…${b.r.toFixed(1)} из ${L.vw})`);
      ok(b.capR.b <= L.vh - 8 + 0.5, `${where}: подпись ${i + 1} ближе 8 px к низу (${b.capR.b.toFixed(1)} из ${L.vh})`);
      ok(b.capFs >= 9 && (Math.min(w, h) < 600 || b.capFs >= 11), `${where}: подпись ${i + 1} мелкая (${b.capFs} px)`);
      // один ряд: одинаковый верх, равные промежутки ≥ 5 px; подписи соседей не налезают друг на друга
      if (i) { const p = L.btns[i - 1];
        ok(b.l - p.r >= 5 && Math.abs((b.l - p.r) - (L.btns[1].l - L.btns[0].r)) < 1.5 && Math.abs(b.t - L.btns[0].t) < 1, `${where}: кнопки не в один ряд / неровно`);
        ok(p.capR.r <= b.capR.l + 0.5, `${where}: подписи ${i} и ${i + 1} налезают`); }
    });
    ok(L.btns[0].w >= Math.min(108 * L.home.scale, 52) - 1 || L.vw < 380, `${where}: кнопки мельче макета (${L.btns[0].w})`);
    const rowC = (L.btns[0].l + L.btns[5].r) / 2; ok(Math.abs(rowC - L.vw / 2) < 2, `${where}: ряд кнопок не по центру`);
    ok(L.fs / L.home.cube > 0.4, `${where}: буквы мелкие`);
    // «i»: в окне, круг ≥ 32 px, в левой нижней части, ни на кубиках, ни на кнопках, ни на подписях
    const I = L.info, apart = (a, b, m = 2) => a.r + m <= b.l || b.r + m <= a.l || a.b + m <= b.t || b.b + m <= a.t;
    ok(inside(I) && I.w >= 32 && Math.abs(I.w - I.h) < 1, `${where}: «i» вне окна или мала ${JSON.stringify(I)}`);
    ok(I.l < L.vw / 3 && I.t > L.vh / 2, `${where}: «i» не в левом нижнем углу ${JSON.stringify(I)}`);
    L.cubes.forEach((c, i) => ok(apart(I, c), `${where}: «i» на кубике ${i}`));
    L.btns.forEach((b, i) => { ok(apart(I, b), `${where}: «i» на кнопке ${i + 1}`); ok(apart(I, b.capR), `${where}: «i» на подписи ${i + 1}`); });
    // кнопки/подписи не налезают на кубики
    L.btns.forEach((b, i) => L.cubes.forEach((c, k) => { ok(apart(b, c, 0) && apart(b.capR, c, 0), `${where}: кнопка ${i + 1} на кубике ${k}`); }));
    return L;
  }
  await sleep(1400);
  { const L = await checkLayout(1024, 768); ok(L.home.cols === 7 && L.btns[0].w === 108 && Math.round(L.btns[1].l - L.btns[0].l) === 122 && L.btns[0].capFs === 15,
      `4:3: сетка ${L.home.cols} столбцов, кнопка ${L.btns[0].w}, шаг ${L.btns[1].l - L.btns[0].l}, подпись ${L.btns[0].capFs} (по макету 7, 108, 122, 15)`);
    ok(L.btns.every((b) => b.capR.h < b.capFs * 1.5), "4:3: подписи должны быть в одну строку"); console.log(`1024×768: кубик ${L.home.cube}, ряд x=${L.btns[0].l}…${L.btns[5].r}, y=${L.btns[0].t}`); }
  await sleep(600); await shot("home-4x3");
  // поворот телефона: на 844×390 и 640×360 — широкая сетка (9×4 / 11×3), кубик крупнее, чем был бы при 7×5; вертикально — 5×7 / 4×9
  for (const [w, h, wide] of [[844, 390, 1], [640, 360, 1], [390, 844, 0], [360, 640, 0]]) {
    const L = await checkLayout(w, h);
    ok(wide ? L.home.cols >= 9 : L.home.cols <= 5, `${w}×${h}: сетка ${L.home.cols} столбцов, нужна ${wide ? "широкая (9/11)" : "узкая (5/4)"}`);
    ok(L.home.cube > L.home.cube7, `${w}×${h}: кубик ${L.home.cube} не крупнее, чем при 7×5 (${L.home.cube7})`);
    console.log(`поворот ${w}×${h}: ${L.home.cols}×${Math.ceil(33 / L.home.cols)}, кубик ${L.home.cube} (при 7×5 был бы ${L.home.cube7}), кнопка ${L.btns[0].w}`);
  }
  passed.push("home: поворот телефона — сетка по ориентации");
  // заданная проверка: 6 кнопок в один ряд без наложений (на кнопках, подписях, буквах и «i») — 1366×768, 1024×768, 768×1024, 390×844, 844×390, 360×640, 640×360, 320×560
  for (const [w, h] of [[1366, 768], [1024, 768], [768, 1024], [390, 844], [844, 390], [360, 640], [640, 360], [320, 560]]) {
    const L = await checkLayout(w, h), B = L.btns;
    const rows = new Set(B.map((b) => Math.round(b.t))).size, all = B.flatMap((b) => [b, b.capR]);
    for (let i = 0; i < B.length; i++) for (let j = i + 1; j < B.length; j++) {
      const A = B[i], C = B[j], sep = (a, b) => a.r <= b.l + 0.5 || b.r <= a.l + 0.5 || a.b <= b.t + 0.5 || b.b <= a.t + 0.5;
      ok(sep(A, C) && sep(A.capR, C.capR) && sep(A, C.capR) && sep(A.capR, C), `${w}×${h}: кнопки ${i + 1} и ${j + 1} налезают`); }
    ok(rows === 1 && B.every((b, i) => !i || b.l > B[i - 1].r), `${w}×${h}: кнопки не в один ряд`);
    const lines = B.map((b) => Math.round(b.capR.h / (b.capFs * 1.12)));
    console.log(`один ряд ${w}×${h}: сетка ${L.home.cols}, кнопка ${B[0].w}, шаг ${(B[1].l - B[0].l).toFixed(0)}, подпись ${B[0].capFs} px, строк ${lines.join("/")}; кубик ${L.home.cube}; «i» ${L.info.l},${L.info.t}`);
    if (w === 390 && h === 844) ok(B[0].w === 52 && B[0].capFs === 11 && lines[4] === 2 && lines[5] === 2 && lines[0] === 1, `390×844: по макету кнопка 52, подпись 11, «Мои / наклейки» и «Язык / жестов» в 2 строки (${B[0].w}, ${B[0].capFs}, ${lines})`);
  }
  passed.push("home: 6 кнопок в один ряд без наложений (8 размеров)");
  { const L = await checkLayout(1366, 768); ok(L.home.cols >= 7, "16:9: сетка"); }
  await shot("home-16x9");
  { const L = await checkLayout(1280, 800); }
  await shot("home-16x10");
  const sizes = [];
  const SIZES = [
    // прежние
    [1024, 768], [1180, 820], [2048, 1536], [1366, 768], [1280, 800], [1920, 1200], [1920, 1080], [820, 1180], [915, 412], [844, 390], [740, 360],
    // видимая область с панелями браузера: iPad Safari (альб./порт.)
    [1180, 740], [1024, 690], [1366, 950], [820, 1100], [768, 950],
    // Android-планшет Chrome
    [1280, 680], [1280, 720], [800, 1180], [960, 540], [1340, 750],
    // телефоны: альбомная / портретная
    [844, 340], [740, 300], [915, 370], [390, 660], [360, 620], [320, 560], [390, 844], [375, 667], [430, 932], [360, 640], [768, 1024], [640, 360], [844, 390]];
  for (const [w, h] of SIZES) {
    const L = await checkLayout(w, h);
    if (Math.min(w, h) >= 600) ok(L.btns[0].w >= 64, `${w}×${h}: на планшете кнопка ${L.btns[0].w} < 64`);
    sizes.push(`${w}×${h}: ${L.home.cols}×${Math.ceil(33 / L.home.cols)}, кубик ${L.home.cube} (7×5: ${L.home.cube7}), кнопка ${L.btns[0].w}`);
  }
  console.log("раскладка (без прокрутки, сетка по экрану, 6 разделов в один ряд и «i» в окне, без наложений):\n    " + sizes.join("\n    "));
  // скриншоты тесных случаев
  for (const [w, h, n] of [[1180, 740, "home-ipad-safari"], [1280, 680, "home-android-chrome"], [844, 340, "home-phone"], [360, 620, "home-portrait-phone"], [390, 844, "home-390x844"], [844, 390, "home-844x390"]]) {
    await checkLayout(w, h); await sleep(300); await shot(n); }
  // живой пересчёт: панели браузера показались (1180×820 → 1180×740) и поворот (→ 820×1180) без перезагрузки
  for (const [w, h] of [[1180, 820], [1180, 740], [820, 1180], [360, 620], [1024, 768]]) {
    await page.setViewport({ width: w, height: h, hasTouch: true, isMobile: false }); await sleep(250);
    const L = await checkLayout(w, h); }
  console.log("пересчёт при смене размера окна без перезагрузки: 1180×820 → 1180×740 → 820×1180 → 360×620 → 1024×768");
  passed.push("home: раскладка — буквы, ряд разделов, «i»");
  // 3) кнопки-разделы: нажимаются (сжатие), но никуда не ведут
  await view(1024, 768);
  { const u0 = page.url(), s = await home(); const [x, y] = s.targets.buttons[2];
    await page.touchscreen.touchStart(x, y);
    await sleep(150);
    const pressed = await page.evaluate(() => { const b = document.querySelector('.rb[data-slot="3"]'); return b.classList.contains("press") && getComputedStyle(b).transform; });
    await page.touchscreen.touchEnd(); await sleep(500);
    const sc = pressed && /matrix\(([-\d.e]+)/.exec(pressed); ok(sc && +sc[1] < 0.95, "кнопка не сжалась при нажатии: " + pressed);
    ok(page.url() === u0 && (await home()).state === "wait_letter", "кнопка раздела что-то сделала");
    ok(!(await page.evaluate(() => document.querySelector(".rb.press"))), "кнопка осталась нажатой");
    console.log("кнопка 3: сжатие при касании (" + pressed + "), действий нет"); }
  passed.push("home: кнопки — только отклик");
  // 4) закрытая буква; руки-подсказки на главной нет (ни по умолчанию, ни с ?hint_sec)
  reqs.length = 0;
  await page.goto(`${BASE}/?test=1&hint_sec=1`, { waitUntil: "load" });
  await until(home, (s) => s.state === "wait_letter", "home ready");
  { const s = await home(); await tapAt(s.targets.letter_locked); await sleep(120);
    ok(await page.evaluate(() => document.querySelector(".cube.locked.wobble") !== null), "закрытая «Б» не качнулась");
    await sleep(600); ok(page.url().startsWith(`${BASE}/?`), "закрытая «Б» куда-то увела"); }
  { const t0 = Date.now();
    while (Date.now() - t0 < 22000) {
      const s = await home(); ok(!s.targets.hint_hand, "на главной появилась рука-подсказка");
      ok(!(await page.evaluate(() => [...document.querySelectorAll("img")].some((i) => /hand/.test(i.src) && i.offsetWidth))), "на главной видна картинка руки");
      await sleep(500); }
    console.log("главная: 22 с без касаний — руки-подсказки нет"); }
  passed.push("home: Б качается, руки нет");
  // 4б) «i» → страница сведений (общая для всех уроков) → крестик / «назад» → буквы; на телефоне 390×844 и планшете
  for (const [w, h] of [[390, 844], [1024, 768], [820, 1180]]) {
    await page.setViewport({ width: w, height: h, hasTouch: true, isMobile: w < 600 });
    await page.goto(`${BASE}/?test=1`, { waitUntil: "load" });
    await until(home, (s) => s.state === "wait_letter", `home ${w}×${h}`); await sleep(900);
    const u0 = page.url();
    { const s = await home(); await tapAt(s.targets.info_btn); }
    const s = await until(home, (s) => s.state === "info" && s.info_text_len > 800, `«i» → сведения (${w}×${h})`, 5000);
    const txt = await page.evaluate(() => document.getElementById("info-text").innerText);
    for (const k of ["Как построен урок", "Подсказки и голос", "только когда ребёнок сам выберет правильный вариант", "Советы родителям"]) ok(txt.includes(k), `сведения: нет раздела «${k}»`);
    ok(!/Урок «А»|буква «А»/.test(txt), "сведения про один урок «А», а должны быть общими");
    const vis = await page.evaluate(() => { const r = document.getElementById("info").getBoundingClientRect(); const x = getComputedStyle(document.getElementById("info-close"), "::before");
      return { cover: r.width >= innerWidth - 1 && r.height >= innerHeight - 1, cross: x.backgroundColor }; });
    ok(vis.cover, "страница сведений не на весь экран");
    const [cr, cg, cb] = vis.cross.match(/\d+/g).map(Number); ok(Math.max(cr, cg, cb) - Math.min(cr, cg, cb) < 20 && cr < 120, "крестик не тёмно-серый: " + vis.cross);
    const [cx, cy] = s.targets.info_close; ok(cx > w * 0.8 && cy < 90, `крестик не в правом верхнем углу (${cx},${cy})`);
    ok(page.url() === u0 && !(await page.evaluate(() => /lesson-a/.test(performance.getEntriesByType("resource").map((e) => e.name).join(" ")))), "сведения грузят урок / Godot");
    if (w === 390) {   // длинный текст прокручивается пальцем (страница целиком — нет)
      ok(s.info_scroll[0] > s.info_scroll[1], "на телефоне текст сведений должен прокручиваться");
      await shot("home-info-390x844");
      await page.touchscreen.touchStart(200, 600); for (let k = 1; k <= 8; k++) await page.touchscreen.touchMove(200, 600 - k * 40); await page.touchscreen.touchEnd(); await sleep(500);
      const st = await page.evaluate(() => document.getElementById("info-scroll").scrollTop); ok(st > 50, "текст сведений не прокручивается пальцем: " + st);
      await noScroll("сведения 390×844");
      console.log(`сведения 390×844: текст ${s.info_text_len} симв., прокрутка пальцем ${st} px, крестик ${vis.cross}`);
      await page.goBack(); await until(home, (s) => s.state === "wait_letter", "«назад» закрывает сведения", 5000);
      ok(page.url() === u0, "«назад» ушёл со страницы букв");
    } else {
      if (w === 1024) await shot("home-info-1024");
      await tapAt(s.targets.info_close);
      await until(home, (s) => s.state === "wait_letter", `крестик → буквы (${w}×${h})`, 5000);
      ok(page.url() === u0 && !(await page.evaluate(() => document.getElementById("info").classList.contains("open"))), "крестик не вернул к буквам");
    }
    { const s2 = await home(); ok(s2.targets.letter_a, "после сведений нет «А»"); }
    console.log(`«i» ${w}×${h}: открылись сведения, ${w === 390 ? "«назад»" : "крестик"} → буквы`);
  }
  await view(1024, 768);
  passed.push("home: «i» → сведения → буквы");
  // 5) тап «А» → отклик → lesson-a/ (параметры переданы) → сразу s01 (экрана для взрослого s00 нет)
  await page.goto(`${BASE}/?test=1&fast=1&junior=1&debug=1&hint_sec=30&foo=bar`, { waitUntil: "load" });
  await until(home, (s) => s.state === "wait_letter", "home ready (А)");
  await sleep(1000);
  const nav = page.waitForNavigation({ waitUntil: "load", timeout: 10000 });
  { const s = await home(); const t0 = Date.now();
    await page.touchscreen.touchStart(...s.targets.letter_a);
    const pressed = await page.evaluate(() => document.getElementById("cube-a").classList.contains("press"));
    await page.touchscreen.touchEnd();
    const fb = await page.evaluate(() => document.getElementById("cube-a").className);
    console.log(`тап «А»: отклик сразу (press=${pressed}, затем «${fb}») за ${Date.now() - t0} мс`);
    ok(pressed || /go/.test(fb), "нет мгновенного отклика на «А»"); }
  await nav;
  { const u = new URL(page.url());
    console.log("урок открыт:", u.pathname + u.search);
    ok(u.pathname === "/lesson-a/", "не lesson-a/: " + u.pathname);
    for (const k of ["test", "fast", "junior", "debug", "hint_sec"]) ok(u.searchParams.has(k), "не передан параметр " + k);
    ok(!u.searchParams.has("foo"), "лишний параметр foo ушёл в урок"); }
  { const t0 = Date.now(); await until(bk, (s) => s.step === "s01_intro", "lesson → s01", 120000);
    console.log(`lesson-a/: Godot загрузился и сразу открыл s01 за ${((Date.now() - t0) / 1000).toFixed(1)} с (локально)`);
    const s = await bk(); ok(s.hint_sec === 30, "hint_sec не дошёл до урока: " + s.hint_sec);
    ok(!(s.targets || {}).start && !(s.targets || {}).junior, "в уроке остались «Начнём!» / младший режим"); }
  await shot("lesson-s01-start");
  passed.push("А → lesson-a → s01");
  // 6) крестик → главная (параметры, кроме step, сохранены)
  { const s = await until(bk, (s) => s.targets && s.targets.exit, "крестик на s01"); await tapNav(s.targets.exit, "крестик " + s.step); }
  { const u = new URL(page.url()); console.log("крестик →", u.pathname + u.search);
    ok(u.pathname === "/", "крестик не на главную: " + u.pathname);
    ok(u.searchParams.get("junior") === "1" && u.searchParams.get("debug") === "1", "параметры потерялись"); }
  await until(home, (s) => s.state === "wait_letter", "home after exit");
  passed.push("крестик → главная");
  // 7) прямая ссылка ?step= работает и крестик с неё ведёт домой без step
  await page.goto(`${BASE}/lesson-a/?test=1&fast=1&step=s05_letter`, { waitUntil: "load" });
  await until(bk, (s) => s.step === "s05_letter", "deep link s05", 120000);
  { const s = await until(bk, (s) => s.targets && s.targets.exit && /^wait/.test(s.state), "крестик на s05"); await tapNav(s.targets.exit, "крестик " + s.step); }
  { const u = new URL(page.url()); ok(u.pathname === "/" && !u.searchParams.has("step"), "из deep link не на главную: " + page.url()); }
  await until(home, (s) => s.state === "wait_letter", "home after deep link exit");
  console.log("?step=s05_letter → s05; крестик → /?" + new URL(page.url()).searchParams);
  passed.push("?step= → крестик → главная");
  // 8) «назад» в браузере после ухода в урок — главная снова живая (bfcache)
  { const s = await home(); await tapNav(s.targets.letter_a, "«А»"); }
  await page.goBack({ waitUntil: "load" });
  await until(home, (s) => s.state === "wait_letter", "home after back");
  passed.push("назад → главная");
} catch (e) { errors.push("test: " + (e.stack || e)); try { await shot("FAIL-home"); } catch {} }
finally { if (browser) await browser.close(); srv.kill(); }
console.log("passed:", passed.join(" → "));
console.log(errors.length ? "ERRORS:\n" + errors.join("\n") : "OK: no JS errors");
process.exit(errors.length ? 1 : 0);
