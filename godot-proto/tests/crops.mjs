// Увеличенные (×4) вырезки «i» и шестерёнки + замер смещения значка от центра (CSS px); шестерёнка — зеркально «i»
// (центр значка против зеркальной точки центра «i» относительно середины рабочей области). Запуск: PORT=… node tests/crops.mjs [сайт] [папка]
import { createRequire } from "module"; import { spawn } from "child_process"; import path from "path"; import { fileURLToPath } from "url";
const require = createRequire(import.meta.url);
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const puppeteer = require(path.resolve(ROOT, "../.tools/node_modules/puppeteer-core"));
const PORT = +(process.env.PORT || 55800), SITE = path.resolve(process.argv[2] || path.join(ROOT, "../site")), OUT = process.argv[3] || "/tmp";
const srv = spawn("node", [path.join(ROOT, "tests/serve.mjs"), SITE, String(PORT)], { stdio: "ignore", env: { ...process.env, NOCOI: "1" } });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms)); await sleep(700);
const b = await puppeteer.launch({ executablePath: "/usr/bin/google-chrome", headless: "new", args: ["--no-sandbox"] });
const pg = await b.newPage(); const res = [];
for (const [w, h] of [[844, 390], [844, 340], [740, 300], [915, 412], [1366, 768], [1024, 768], [390, 844], [640, 360]]) {
  await pg.setViewport({ width: w, height: h, deviceScaleFactor: 4 });
  await pg.goto(`http://127.0.0.1:${PORT}/?test=1`, { waitUntil: "networkidle0" }); await sleep(1500);
  const g = await pg.evaluate(() => { const R = (e) => { const r = e.getBoundingClientRect(); return { x: r.left, y: r.top, w: r.width, h: r.height }; };
    const c = [...document.querySelectorAll(".cube")], H = window.__home;
    return { i: R(document.getElementById("info-btn")), gear: R(document.getElementById("set-btn")), cols: H.cols, cube: H.cube, vw: innerWidth, work: H.work_x }; });
  const ic = [g.i.x + g.i.w / 2, g.i.y + g.i.h / 2], exp = [g.work[0] + g.work[1] - ic[0], ic[1]];   // зеркальная точка центра «i»
  for (const [n, r, cx] of [["i", g.i, ic], ["gear", g.gear, exp]]) {
    const pad = n === "i" ? 6 : 0, clip = { x: r.x - pad, y: r.y - pad, width: r.w + 2 * pad, height: r.h + 2 * pad };
    const file = path.join(OUT, `crop-${n}-${w}x${h}.png`);
    const buf = await pg.screenshot({ clip, path: file });
    // «чернила» значка: пиксели заметно темнее фона #ECE3D0 / круга (L < 205; бледная шестерёнка #B5AA97 ≈ 171) — для «i» только
    // внутри 0,72 радиуса, без рамки круга
    const ink = await pg.evaluate(async (src, rad) => { const im = new Image(); im.src = src; await im.decode();
      const cv = document.createElement("canvas"); cv.width = im.width; cv.height = im.height; const x = cv.getContext("2d"); x.drawImage(im, 0, 0);
      const d = x.getImageData(0, 0, cv.width, cv.height).data; let x0 = 1e9, y0 = 1e9, x1 = -1, y1 = -1; const C = [cv.width / 2, cv.height / 2];
      for (let yy = 0; yy < cv.height; yy++) for (let xx = 0; xx < cv.width; xx++) { const k = (yy * cv.width + xx) * 4, L = 0.3 * d[k] + 0.59 * d[k + 1] + 0.11 * d[k + 2];
        if (L > 205) continue; if (rad && Math.hypot(xx - C[0], yy - C[1]) > rad) continue;
        x0 = Math.min(x0, xx); x1 = Math.max(x1, xx); y0 = Math.min(y0, yy); y1 = Math.max(y1, yy); }
      return [x0, y0, x1 + 1, y1 + 1]; }, "data:image/png;base64," + Buffer.from(buf).toString("base64"), n === "i" ? r.w / 2 * 0.72 * 4 : 0);
    const c = [clip.x + (ink[0] + ink[2]) / 8, clip.y + (ink[1] + ink[3]) / 8];
    res.push({ view: `${w}×${h}`, el: n, cols: g.cols, cube: g.cube, place: n === "gear" ? "зеркально «i»" : "круг", box: n === "gear" ? [+(g.gear.x + g.gear.w / 2 - exp[0]).toFixed(2), +(g.gear.y + g.gear.h / 2 - exp[1]).toFixed(2)] : undefined,
      glyph: [((ink[2] - ink[0]) / 4).toFixed(1), ((ink[3] - ink[1]) / 4).toFixed(1)].join("×"), dx: +(c[0] - cx[0]).toFixed(2), dy: +(c[1] - cx[1]).toFixed(2), tap: `${r.w}×${r.h}` });
  }
}
await b.close(); srv.kill();
for (const r of res) console.log(JSON.stringify(r));
const bad = res.filter((r) => Math.abs(r.dx) > 1 || Math.abs(r.dy) > 1); console.log(bad.length ? "СМЕЩЕНИЕ > 1 px: " + bad.length : "OK: все значки по центру (≤ 1 px)");
process.exit(bad.length ? 1 : 0);
