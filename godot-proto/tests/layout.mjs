// Тест раскладки (DESIGN_RULES.md, §2): на всех экранах кнопки «назад», «Далее», крестик целиком на экране и
// не перекрывают карточки, картинки, буквы и другие интерактивные предметы — на каждом шаге s01…s11.
// Плюс: s04 «Слышу звук?» — каждая карточка по центру, ряды отвеченных карточек вверху, касание карточки в ряду
// говорит слово и ничего не подтверждает; s08 «Шарики» — летящие шарики (позиции в разные моменты) и итоговые А/а
// не заходят под кнопки; s05 «Паровозик» — рельсы от края до края экрана, поезд въезжает и уезжает из-за краёв,
// по пути не заходит под кнопки (снимки в пути — screenshots/layout/<экран>-s05-train-ride.png).
// Запуск: PORT=<свободный> node tests/layout.mjs   (VPS="390x844,1024x768" — свои экраны; SITE=папка сайта)
import { createRequire } from "module"; import { spawn } from "child_process"; import path from "path"; import fs from "fs"; import { fileURLToPath } from "url";
const require = createRequire(import.meta.url);
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const puppeteer = require(path.resolve(ROOT, "../.tools/node_modules/puppeteer-core"));
const PORT = +(process.env.PORT || 55784);
const SITE = path.resolve(process.env.SITE || path.join(ROOT, "../site"));
const SHOTS = path.join(ROOT, "screenshots", "layout"); fs.mkdirSync(SHOTS, { recursive: true });
const srv = spawn("node", [path.join(ROOT, "tests/serve.mjs"), SITE, String(PORT)], { stdio: "ignore", env: { ...process.env, NOCOI: "1" } });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
// телефон портрет/альбом, 4:3, 16:9, 16:10, iPhone 390×844 (там «назад» перекрывал карточку «мак»), планшет-портрет
const VPS = (process.env.VPS || "1024x768,1366x768,1280x800,844x390,390x844,360x640,768x1024").split(",");
const STEPS = ["s01_stork", "s02_intro", "s03_sing", "s04_hear", "s05_words", "s06_letter", "s07_write", "s08_find", "s09_sort", "s10_say", "s11_end"];
const errors = [], notes = []; let page;
const bk = () => page.evaluate(() => window.__bk || {}).catch(() => ({}));
async function waitFor(fn, desc, timeout = 40000) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeout) { const s = await bk(); if (fn(s)) return s; await sleep(120); }
  throw new Error("timeout: " + desc + " | last state=" + (await bk()).state);
}
let K = 1;   // CSS px на единицу холста
async function tapT(name) {
  const s = await waitFor((s) => s.targets && s.targets[name], "target " + name);
  const [x, y] = s.targets[name]; await page.touchscreen.tap(x * K, y * K); await sleep(150);
}
function checkButtonsOnScreen(s, where) {
  const [, , w, h] = s.visible_rect;
  for (const [k, [x, y, bw, bh]] of Object.entries(s.ui_rects || {}))
    if (x < -0.5 || y < -0.5 || x + bw > w + 0.5 || y + bh > h + 0.5)
      throw new Error(`${where}: кнопка ${k} не целиком на экране (${[x, y, bw, bh].map(Math.round)} в ${Math.round(w)}×${Math.round(h)})`);
}
async function sampleOverlaps(where, n, gap) {
  const all = new Set();
  for (let i = 0; i < n; i++) { const s = await bk(); (s.ui_overlaps || []).forEach((o) => all.add(o)); checkButtonsOnScreen(s, where); await sleep(gap); }
  if (all.size) throw new Error(`${where}: кнопки перекрывают ${[...all].join("; ")}`);
}
async function open(step, extra = "") {
  await page.goto(`http://127.0.0.1:${PORT}/lesson-a/index.html?test=1&fast=1&step=${step}${extra}`, { waitUntil: "load" });
  const s = await waitFor((s) => s.step === step && /^(wait|done|drive|fly_in)/.test(s.state || ""), "open " + step, 60000);
  K = (await page.evaluate(() => innerWidth)) / s.visible_rect[2];
  return s;
}
const near = (a, b, d) => Math.abs(a - b) <= d;
try {
  const browser = await puppeteer.launch({ executablePath: "/usr/bin/google-chrome", headless: "new",
    args: ["--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist", "--mute-audio"] });
  page = await browser.newPage();
  page.on("pageerror", (e) => errors.push("pageerror: " + e.message));
  page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
  for (const vp of VPS) {
    const [w, h] = vp.split("x").map(Number);
    await page.setViewport({ width: w, height: h, hasTouch: true, isMobile: w < 900 || h < 500 });
    try {
      // 1) все шаги: несколько замеров (анимации, въезд поезда, шарики)
      for (const st of STEPS) {
        await open(st);
        // s01: весь полёт аиста (влёт → круг → посадка, ≈ 5,5 с) и после посадки
        const [n, gap] = st === "s08_find" ? [12, 700] : st === "s01_stork" ? [70, 100] : [4, 500];
        await sampleOverlaps(`${vp} ${st}`, n, gap);
        if (st === "s01_stork") {   // аист сел, «Далее» на экране; касание аиста в гнезде и буквы «а» (зона у края) — работают
          const d = await waitFor((s) => s.state === "done" && s.targets.next && s.targets.stork_nest, vp + " s01 посадка");
          checkButtonsOnScreen(d, vp + " s01 посадка");
          await tapT("stork_nest"); await tapT("small");
          const q = await bk();
          if (q.info.s01_word_taps !== 1 || q.info.s01_letter_taps !== 1)
            throw new Error(`${vp} s01: касание аиста/«а» не сработало (${q.info.s01_word_taps}/${q.info.s01_letter_taps})`);
          await page.screenshot({ path: path.join(SHOTS, `${vp}-s01-landed.png`) });
          notes.push(`${vp} s01: полёт без перекрытий, «Далее» на экране, касания аиста и «а» работают`);
        }
      }
      // 2) s04 «на слух»: каждая карточка по центру; отвеченные — в два ряда вверху (со звуком слева, без — справа),
      //    на одной высоте; касание карточки в ряду говорит слово и ничего не подтверждает
      { const ans = ["yes", "no", "yes", "no", "yes"]; let y0 = null;
        await open("s04_hear");
        for (let i = 0; i < 5; i++) {
          await waitFor((s) => s.state === "wait_answer_" + i, "s04 answer " + i);
          await sleep(450);
          const s1 = await bk(); const [cx, cy] = s1.stage_center; const [x, y, cw, ch] = s1.info.s04_card;
          const mx = x + cw / 2, my = y + ch / 2;
          if (!near(mx, cx, 3)) throw new Error(`${vp} s04: карточка ${i + 1} не по центру (x ${Math.round(mx)} vs ${Math.round(cx)})`);
          if (y0 === null) y0 = my - cy; else if (!near(my - cy, y0, 3)) throw new Error(`${vp} s04: карточка ${i + 1} на другой высоте`);
          await sampleOverlaps(`${vp} s04 слово ${i + 1}`, 2, 300);
          await tapT(ans[i]);
        }
        const s = await waitFor((s) => s.state === "done" && s.info.s04_row, "s04 done", 40000);
        const row = s.info.s04_row; const [cx] = s.stage_center;
        for (const [x, , cw, , has] of row) if (has ? x + cw / 2 > cx : x + cw / 2 < cx) throw new Error(`${vp} s04: карточка не в своём ряду ${JSON.stringify(row.map((r) => r.map((v) => typeof v === "number" ? Math.round(v) : v)))}`);
        if (new Set(row.map(([, y, , ch]) => Math.round(y + ch / 2))).size !== 1) throw new Error(`${vp} s04: карточки рядов на разной высоте`);
        await sampleOverlaps(`${vp} s04 ряды`, 2, 300);
        const ok0 = (s.sfx_counts || {}).sfx_ok || 0;
        await tapT("row_card_0"); await sleep(700); await tapT("row_card_3"); await sleep(700);
        const s2 = await bk();
        if (s2.info.s04_word_taps !== 2) throw new Error(`${vp} s04: касание карточки в ряду не сработало (${s2.info.s04_word_taps})`);
        if (s2.info.s04_word_last !== "a_hear_05") throw new Error(`${vp} s04: карточка «дом» сказала ${s2.info.s04_word_last}`);
        if (s2.state !== "done" || ((s2.sfx_counts || {}).sfx_ok || 0) !== ok0) throw new Error(`${vp} s04: касание карточки в ряду что-то подтвердило`);
        await page.screenshot({ path: path.join(SHOTS, `${vp}-s04-rows.png`) });
        notes.push(`${vp} s04: 5 карточек по центру, ряды вверху, касания ряда — слово, без подтверждения`); }
      // 2б) s05 паровозик: рельсы от края до края экрана (плитка без растяжения); поезд въезжает целиком из-за края,
      //     уезжает целиком за другой край; во время езды кнопки ничего не перекрывают
      { let s = await open("s05_words");
        const r = s.info.s05_rails; const v = s.visible_rect; const kk = s.content_rect[2] / 1024;
        const vl = (v[0] - s.content_rect[0]) / kk, vr = (v[0] + v[2] - s.content_rect[0]) / kk;
        if (!r || r.x0 > vl + 0.5 || r.x1 < vr - 0.5) throw new Error(`${vp} s05: рельсы не на всю ширину (${r && [r.x0, r.x1].map(Math.round)} при экране ${[vl, vr].map(Math.round)})`);
        if (Math.abs(r.kx - r.ky) > 1e-6) throw new Error(`${vp} s05: рельсы растянуты (${r.kx}×${r.ky})`);
        const di = (await waitFor((s) => s.info && s.info.s05_drive_in, vp + " s05 drive_in")).info.s05_drive_in;
        const offIn = di.dir === "rtl" ? di.from >= di.vis_r : di.from + di.w <= di.vis_l;
        if (!offIn || di.vis_l > vl + 0.5 || di.vis_r < vr - 0.5) throw new Error(`${vp} s05: поезд въезжает не из-за края экрана ${JSON.stringify(di)}`);
        let shot = false;
        for (let n = 0; n < 200; n++) { s = await bk(); if (s.state !== "drive_in_0") break;
          checkButtonsOnScreen(s, vp + " s05 въезд"); if ((s.ui_overlaps || []).length) throw new Error(`${vp} s05 въезд: ${s.ui_overlaps.join("; ")}`);
          if (!shot && s.targets.train) { const tx = s.targets.train[0]; if (tx > v[2] * 0.55 && tx < v[2] * 0.8) { await page.screenshot({ path: path.join(SHOTS, `${vp}-s05-train-ride.png`) }); shot = true; } }
          await sleep(60); }
        await waitFor((s) => s.state === "wait_pic_0", vp + " s05 wait_pic_0");
        await tapT("pic");
        s = await waitFor((s) => s.state === "wait_slot_0" && s.info && s.info.s05_right !== undefined, vp + " s05 wait_slot_0");
        await tapT("slot" + s.info.s05_right);
        await waitFor((s) => /^(ok|drive_out)_0$/.test(s.state), vp + " s05 верный ответ");
        for (let n = 0; n < 300; n++) { s = await bk(); if (s.info && s.info.s05_left === 0) break;
          checkButtonsOnScreen(s, vp + " s05 выезд"); if ((s.ui_overlaps || []).length) throw new Error(`${vp} s05 выезд: ${s.ui_overlaps.join("; ")}`);
          await sleep(60); }
        const dout = (await waitFor((s) => s.info && s.info.s05_left === 0, vp + " s05 уехал", 20000)).info;
        const d = dout.s05_drive_out; const offOut = d.dir === "rtl" ? d.to + d.w <= d.vis_l : d.to >= d.vis_r;
        if (!offOut) throw new Error(`${vp} s05: поезд уехал не за край экрана ${JSON.stringify(d)}`);
        if (dout.s05_cards_visible !== 0) throw new Error(`${vp} s05: карточка осталась после отъезда`);
        notes.push(`${vp} s05: рельсы ${Math.round(r.x0)}…${Math.round(r.x1)} при экране ${Math.round(vl)}…${Math.round(vr)} (плитка ${Math.round(r.tile_w)}, ×${r.kx.toFixed(3)}); въезд ${Math.round(di.from)}→${Math.round(di.to)}, выезд ${Math.round(d.from)}→${Math.round(d.to)}, без перекрытий${shot ? ", снимок в пути" : ""}`); }
      // 3) s08: лопаем все шарики с А/а, затем А и а в центре; шарики летят дальше
      { await open("s08_find");
        for (let n = 0; n < 200; n++) { const s = await bk(); if (s.state === "done") break;
          checkButtonsOnScreen(s, vp + " s08"); if ((s.ui_overlaps || []).length) throw new Error(`${vp} s08: ${s.ui_overlaps.join("; ")}`);
          if (s.targets && s.targets.balloon) { const [x, y] = s.targets.balloon; await page.touchscreen.tap(x * K, y * K); }
          await sleep(350); }
        await waitFor((s) => s.targets && s.targets.end_big && s.targets.end_small, vp + " s08 А/а", 10000);
        await sampleOverlaps(`${vp} s08 итог А/а + шарики`, 8, 500);
        await page.screenshot({ path: path.join(SHOTS, `${vp}-s08-letters.png`) });
        notes.push(`${vp} s08: шарики и А/а без перекрытий`); }
      notes.push(`${vp}: шаги s01–s11 без перекрытий, кнопки на экране`);
    } catch (e) { errors.push(String(e.message || e)); try { await page.screenshot({ path: path.join(SHOTS, `FAIL-${vp}.png`) }); } catch {} }
  }
  await browser.close();
} catch (e) { errors.push("test: " + (e.stack || e)); }
finally { srv.kill(); }
console.log(notes.join("\n"));
console.log(errors.length ? "ERRORS:\n" + errors.join("\n") : "OK: layout");
process.exit(errors.length ? 1 : 0);
