// Тест HTML-главной (web-home/ в корне сайта) + переход в урок lesson-a/ и обратно, в headless Chrome касаниями.
// Сайт собирается как в CI:  bash tests/assemble_site.sh   (корень = web-home/, lesson-a/ = build/)
// Проверяет: главная не тянет Godot (*.wasm/*.pck/index.js), её вес; раскладка (место под меню, кубики, черта, 6 пустых
// круглых кнопок) на 4:3, 16:10, 16:9 и телефонах без прокрутки и наложений; кнопки только «нажимаются»; закрытая буква качается и никуда не ведёт; рука-подсказка; тап «А» → мгновенный
// отклик → lesson-a/ с параметрами → s00 → s01; крестик и «?step=» → обратно на главную.
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
const tapAt = async ([x, y]) => { await page.touchscreen.tap(x, y); };
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
    const s = await home(); ok(s.hint_sec === 20, "подсказка по умолчанию не 20 с: " + s.hint_sec); }
  passed.push("home: без Godot");
  // 2) раскладка: верхняя полоса под меню, кубики, черта, 6 круглых кнопок — всё в окне, без прокрутки и наложений
  async function checkLayout(w, h) {
    await view(w, h); await noScroll(`${w}×${h}`);
    const L = await page.evaluate(() => {
      const R = (e) => { const r = e.getBoundingClientRect(); return { l: r.left, t: r.top, r: r.right, b: r.bottom, w: r.width, h: r.height }; };
      return { vw: innerWidth, vh: innerHeight, top: R(document.getElementById("topbar")),
        cubes: [...document.querySelectorAll(".cube")].map(R), div: document.getElementById("divider") && R(document.getElementById("divider")),
        divColor: getComputedStyle(document.getElementById("divider")).backgroundColor,
        btns: [...document.querySelectorAll("#bottombar .rb")].map((e) => ({ ...R(e), slot: e.dataset.slot, label: e.getAttribute("aria-label"), text: e.textContent, kids: e.children.length })),
        fs: parseFloat(getComputedStyle(document.querySelector(".cube span")).fontSize), home: window.__home };
    });
    const where = `${w}×${h}`, inside = (r) => r.l >= 0 && r.t >= 0 && r.r <= L.vw + 0.5 && r.b <= L.vh + 0.5;
    ok(L.cubes.length === 33 && L.cubes.every(inside), `${where}: кубики за краем окна`);
    const cubesTop = Math.min(...L.cubes.map((c) => c.t)), cubesBot = Math.max(...L.cubes.map((c) => c.b));
    ok(cubesTop >= L.top.h - 1 && L.top.h >= Math.min(72, 72 * L.home.scale) - 1, `${where}: нет места под верхнее меню (полоса ${L.top.h}, кубики с ${cubesTop})`);
    ok(L.div && inside(L.div) && L.div.h >= 3 && L.div.h <= Math.max(5, 4 * L.home.scale + 1) && L.div.t >= cubesBot, `${where}: черта не под кубиками ${JSON.stringify(L.div)}`);
    ok(!/rgb\((2[0-9]{2}), ([0-9]{1,2}), /.test(L.divColor), `${where}: черта красная? ${L.divColor}`);
    const gl = Math.min(...L.cubes.map((c) => c.l)), gr = Math.max(...L.cubes.map((c) => c.r));
    ok(L.div.w > (gr - gl) * 0.8 && L.div.w <= (gr - gl) + 1, `${where}: ширина черты ${L.div.w} не по сетке ${gr - gl}`);
    ok(L.btns.length === 6, `${where}: кнопок ${L.btns.length}, нужно 6`);
    L.btns.forEach((b, i) => {
      ok(b.slot === String(i + 1) && b.label && !b.text.trim() && !b.kids, `${where}: кнопка ${i + 1} не пустая / без data-slot`);
      ok(inside(b) && b.t > L.div.b, `${where}: кнопка ${i + 1} вне окна или над чертой ${JSON.stringify(b)}`);
      ok(Math.abs(b.w - b.h) < 1 && b.w >= 64, `${where}: кнопка ${i + 1} ${b.w}×${b.h} (меньше 64 или не круг)`);
      if (i) ok(b.l - L.btns[i - 1].r > 8 && Math.abs((b.l - L.btns[i - 1].r) - (L.btns[1].l - L.btns[0].r)) < 1.5 && Math.abs(b.t - L.btns[0].t) < 1, `${where}: кнопки неровно`);
    });
    const rowC = (L.btns[0].l + L.btns[5].r) / 2; ok(Math.abs(rowC - L.vw / 2) < 2, `${where}: ряд кнопок не по центру`);
    ok(L.fs / L.home.cube > 0.4, `${where}: буквы мелкие`);
    return L;
  }
  await sleep(1400);
  { const L = await checkLayout(1024, 768); ok(L.home.cols === 7 && L.btns[0].w === 88, `4:3: сетка ${L.home.cols} столбцов, кнопка ${L.btns[0].w} (нужно 7 и 88)`); }
  await sleep(600); await shot("home-4x3");
  { const L = await checkLayout(1366, 768); ok(L.home.cols >= 7, "16:9: сетка"); }
  await shot("home-16x9");
  { const L = await checkLayout(1280, 800); }
  await shot("home-16x10");
  const sizes = [];
  for (const [w, h] of [[1024, 768], [1180, 820], [2048, 1536], [1366, 768], [1280, 800], [1920, 1200], [1920, 1080], [820, 1180], [915, 412], [844, 390], [740, 360]]) {
    const L = await checkLayout(w, h);
    if (Math.abs(w / h - 4 / 3) < 0.12) ok(L.home.cols === 7, `${w}×${h}: на 4:3 должно быть 7×5, а ${L.home.cols}`);
    sizes.push(`${w}×${h}: ${L.home.cols} стлб, кубик ${L.home.cube}, кнопка ${L.btns[0].w}`);
  }
  console.log("раскладка (без прокрутки, черта и 6 кнопок в окне):\n    " + sizes.join("\n    "));
  passed.push("home: раскладка с чертой и кнопками");
  // 3) круглые кнопки: нажимаются (сжатие), но никуда не ведут
  await view(1024, 768);
  { const u0 = page.url(), s = await home(); const [x, y] = s.targets.buttons[2];
    await page.touchscreen.touchStart(x, y);
    await sleep(150);
    const pressed = await page.evaluate(() => { const b = document.querySelector('.rb[data-slot="3"]'); return b.classList.contains("press") && getComputedStyle(b).transform; });
    await page.touchscreen.touchEnd(); await sleep(500);
    const sc = pressed && /matrix\(([-\d.e]+)/.exec(pressed); ok(sc && +sc[1] < 0.95, "кнопка не сжалась при нажатии: " + pressed);
    ok(page.url() === u0 && (await home()).state === "wait_letter", "пустая кнопка что-то сделала");
    ok(!(await page.evaluate(() => document.querySelector(".rb.press"))), "кнопка осталась нажатой");
    console.log("кнопка 3: сжатие при касании (" + pressed + "), действий нет"); }
  passed.push("home: кнопки — только отклик");
  // 4) закрытая буква и рука-подсказка (укороченный таймер — только с test/debug)
  reqs.length = 0;
  await page.goto(`${BASE}/?hint_sec=2`, { waitUntil: "load" });
  ok((await home()).hint_sec === 20, "hint_sec без test/debug не должен действовать");
  await page.goto(`${BASE}/?test=1&hint_sec=2`, { waitUntil: "load" });
  await until(home, (s) => s.state === "wait_letter", "home ready (hint)");
  const tB = Date.now();
  { const s = await home(); await tapAt(s.targets.letter_locked); await sleep(120);
    ok(await page.evaluate(() => document.querySelector(".cube.locked.wobble") !== null), "закрытая «Б» не качнулась");
    await sleep(600); ok(page.url().startsWith(`${BASE}/?`), "закрытая «Б» куда-то увела"); }
  { const t0 = tB; const s = await until(home, (s) => s.targets.hint_hand, "рука через 2 с", 6000);
    const dt = (Date.now() - t0) / 1000, [hx, hy] = s.targets.hint_hand, [ax, ay] = s.targets.letter_a;
    ok(Math.hypot(hx - ax, hy - ay) < 10, "рука не над «А»"); ok(dt > 1.7, "рука раньше таймера");
    await sleep(500); await shot("home-hint");
    await until(home, (s) => !s.targets.hint_hand, "рука спряталась", 4000);
    await tapAt([1000, 740]); const t1 = Date.now(); await sleep(1200);
    ok(!(await home()).targets.hint_hand, "касание не сбросило таймер");
    await until(home, (s) => s.targets.hint_hand, "повторная рука", 5000);
    console.log(`рука над «А»: через ${dt.toFixed(1)} с бездействия (hint_sec=2), касание сбрасывает отсчёт (снова через ${((Date.now() - t1) / 1000).toFixed(1)} с)`); }
  passed.push("home: Б качается, рука");
  // 5) тап «А» → отклик → lesson-a/ (параметры переданы) → s00 → s01
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
  { const t0 = Date.now(); await until(bk, (s) => s.step === "s00_parent_note" && s.state === "wait_start", "lesson → s00", 120000);
    console.log(`lesson-a/: Godot загрузился и открыл s00 за ${((Date.now() - t0) / 1000).toFixed(1)} с (локально)`);
    const s = await bk(); ok(s.hint_sec === 30, "hint_sec не дошёл до урока: " + s.hint_sec); }
  await shot("lesson-s00");
  { const s = await bk(); await tapAt(s.targets.start); }
  await until(bk, (s) => s.step === "s01_intro", "s00 → s01", 20000);
  passed.push("А → lesson-a → s00 → s01");
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
