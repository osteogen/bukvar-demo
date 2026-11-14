// Сверка 31 коротких уроков со сценарием docs/intro31-scripts.txt. Браузер не нужен.
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const REPO = path.resolve(ROOT, "..");
const src = fs.readFileSync(path.join(REPO, "docs/intro31-scripts.txt"), "utf8");
const ORDER = [["М","m"],["Х","h"],["О","o"],["Ш","sh"],["Р","r"],["С","s"],["Ы","y"],["Л","l"],["Н","n"],["К","k"],["П","p"],["Т","t"],["В","v"],["З","z"],["Ж","zh"],["Ь","soft"],["И","i"],["Е","e"],["Д","d"],["Б","b"],["Г","g"],["Й","j"],["Ч","ch"],["Э","eh"],["Ё","yo"],["Я","ya"],["Ю","yu"],["Ц","ts"],["Щ","sch"],["Ф","f"],["Ъ","hard"]];
const lines = {};
for (const raw of src.split(/\n/)) {
  const m = raw.match(/^([a-z][a-z0-9_]*) — «(.*)»(?: — (.*))?$/);
  if (m) lines[m[1]] = m[2];
}
const ids = Object.keys(lines);
const unique = new Set(Object.values(lines));
if (ids.length !== 298) throw new Error("в листе не 298 id: " + ids.length);
if (unique.size !== 234) throw new Error("уникальных текстов не 234: " + unique.size);
const studied = new Set(["А", "У"]);
const acute = /\u0301/g;
function lettersOf(s) {
  return [...s.replace(acute, "")].filter((ch) => /\p{L}/u.test(ch)).map((ch) => ch.toUpperCase());
}
let scenes = 0;
for (const [ch, id] of ORDER) {
  const lesson = JSON.parse(fs.readFileSync(path.join(ROOT, "data", `lesson_${id}`, "lesson.json"), "utf8"));
  const pack = JSON.parse(fs.readFileSync(path.join(ROOT, "data", `lesson_${id}`, "lines.json"), "utf8"));
  if (lesson.steps.length !== 4) throw new Error(id + ": не 4 сцены");
  if (lesson.intro.letter !== ch) throw new Error(id + ": буква " + lesson.intro.letter);
  const sc = lesson.intro.scenes;
  if (sc.length !== 4) throw new Error(id + ": scenes " + sc.length);
  for (const scene of sc) {
    scenes++;
    if (lines[scene.line] == null) throw new Error("нет реплики " + scene.line);
    if (pack[scene.line].text !== lines[scene.line]) throw new Error("текст " + scene.line + " разошёлся со сценарием");
    for (const key of ["tap", "carrier", "model", "answer"]) {
      if (scene[key] && lines[scene[key]] == null) throw new Error("нет " + scene[key]);
    }
    for (const ear of scene.ears || []) if (lines[ear] == null) throw new Error("нет " + ear);
    for (const card of scene.cards || []) if (lines[card.audio] == null) throw new Error("нет " + card.audio);
  }
  const blobs = [];
  for (const scene of sc) {
    if (scene.kind === "trace" || scene.kind === "choose_trace") blobs.push(...scene.cards.map((c) => c.text));
    if (scene.kind === "picture") blobs.push(scene.word);
    if (scene.kind === "text") blobs.push(...scene.choices);
    if (scene.kind === "soft_sign") blobs.push(scene.word, ...scene.options);
    if (scene.kind === "hard_pair" || scene.kind === "hard_compare") blobs.push(...scene.cards.map((c) => c.text));
    if (scene.kind === "hard_sign") blobs.push(scene.word, ...scene.choices);
  }
  const allowed = new Set([...studied, ch]);
  for (const b of blobs) {
    const bad = lettersOf(b).filter((c) => !allowed.has(c));
    if (bad.length) throw new Error(`${id}: «${b}» раньше прогрессии: ${bad.join(",")}`);
  }
  studied.add(ch);
  if (sc.some((s) => s.kind === "meet" && /звук/.test(s.screen) && id === "soft")) {
    /* знак не учим как звук: реплика это проверяет ниже */
  }
}
const soft = JSON.parse(fs.readFileSync(path.join(ROOT, "data/lesson_soft/lines.json"), "utf8"));
const hard = JSON.parse(fs.readFileSync(path.join(ROOT, "data/lesson_hard/lines.json"), "utf8"));
if (!soft.soft_s1.text.includes("нет зву́ка")) throw new Error("Ь учится как звук");
if (!hard.hard_tap.text.includes("нет зву́ка")) throw new Error("Ъ учится как звук");
const e = JSON.parse(fs.readFileSync(path.join(ROOT, "data/lesson_e/lesson.json"), "utf8"));
if (e.intro.scenes[1].kind !== "two_dots" || e.intro.scenes[2].kind !== "choose_trace") throw new Error("Е не двумя блоками");
if (fs.readdirSync(path.join(ROOT, "audio")).some((n) => n.startsWith("lesson_m"))) throw new Error("появилась синтезированная озвучка");
const d = JSON.parse(fs.readFileSync(path.join(ROOT, "data/lesson_d/lesson.json"), "utf8"));
const b = JSON.parse(fs.readFileSync(path.join(ROOT, "data/lesson_b/lesson.json"), "utf8"));
const g = JSON.parse(fs.readFileSync(path.join(ROOT, "data/lesson_g/lesson.json"), "utf8"));
if (d.intro.scenes[0].tex !== "pic_dom" || d.intro.scenes[0].from !== "e") throw new Error("Д: дом не из урока Е");
if (d.intro.scenes[1].kind !== "locate" || d.intro.scenes[2].cards.length !== 1 || d.intro.scenes[2].cards[0].text !== "да") throw new Error("Д: не «да»");
if (d.intro.scenes[3].word !== "дом" || d.intro.scenes[3].choices.map((c) => c.tex).join(",") !== "pic_dom,pic_zont") throw new Error("Д: картинки");
if (b.intro.scenes[0].tex !== "pic_busy" || b.intro.scenes[2].cards[0].text !== "ба" || b.intro.scenes[3].word !== "бык") throw new Error("Б: сценарий");
if (b.intro.scenes[3].choices.map((c) => c.tex).join(",") !== "pic_byk,pic_kot_sit") throw new Error("Б: картинки");
if (g.intro.scenes[0].tex !== "pic_gus" || g.intro.scenes[2].cards[0].text !== "гу" || g.intro.scenes[3].word !== "гу\u0301си") throw new Error("Г: сценарий");
if (g.intro.scenes[3].choices[0].tex !== "pic_gusi" || g.intro.scenes[3].choices[1].tex !== "pic_busy") throw new Error("Г4: нужен pic_gusi, не одиночный pic_gus");
for (const rel of ["art/lesson_b/pic_busy.png", "art/lesson_b/pic_byk.png", "art/lesson_g/pic_gus.png", "art/lesson_g/pic_gusi.png", "art/lesson_e/pic_dom.png"]) {
  if (!fs.existsSync(path.join(ROOT, rel))) throw new Error("нет " + rel);
}
for (const id of ["d", "b", "g"]) {
  if (fs.existsSync(path.join(ROOT, "audio", "lesson_" + id))) throw new Error("появилась озвучка " + id);
}
const j = JSON.parse(fs.readFileSync(path.join(ROOT, "data/lesson_j/lesson.json"), "utf8"));
const ch = JSON.parse(fs.readFileSync(path.join(ROOT, "data/lesson_ch/lesson.json"), "utf8"));
const eh = JSON.parse(fs.readFileSync(path.join(ROOT, "data/lesson_eh/lesson.json"), "utf8"));
if (j.intro.scenes[0].tex !== "pic_yogurt" || j.intro.scenes[1].slots !== 2 || j.intro.scenes[1].correct !== 2) throw new Error("Й: носитель или позиция 2");
if (j.intro.scenes[2].cards[0].text !== "ай" || j.intro.scenes[3].kind !== "text" || j.intro.scenes[3].choices.join(",") !== "май,мак") throw new Error("Й: не текст май/мак");
if (ch.intro.scenes[0].tex !== "pic_chai" || ch.intro.scenes[1].slots !== 3 || ch.intro.scenes[1].correct !== 1) throw new Error("Ч: носитель или 3 позиции");
if (ch.intro.scenes[2].cards[0].text !== "чу" || ch.intro.scenes[3].kind !== "picture" || ch.intro.scenes[3].word !== "чай") throw new Error("Ч: не чай");
if (ch.intro.scenes[3].choices.map((c) => c.tex).join(",") !== "pic_chai,pic_sup" || ch.intro.scenes[3].choices[1].from !== "p") throw new Error("Ч: картинки");
if (eh.intro.letter !== "Э" || eh.big !== "Э" || eh.intro.scenes[0].tex !== "pic_emu") throw new Error("Э: не буква Э или нет эму");
if (eh.intro.scenes[1].slots !== 2 || eh.intro.scenes[1].correct !== 1 || eh.intro.scenes[2].cards[0].text !== "эх") throw new Error("Э: не эх");
if (eh.intro.scenes[3].kind !== "text" || eh.intro.scenes[3].choices.join(",") !== "эх,ох") throw new Error("Э: не текст эх/ох");
for (const rel of ["art/lesson_j/pic_yogurt.png", "art/lesson_ch/pic_chai.png", "art/lesson_eh/pic_emu.png", "art/lesson_p/pic_sup.png"]) {
  if (!fs.existsSync(path.join(ROOT, rel))) throw new Error("нет " + rel);
}
for (const id of ["j", "ch", "eh"]) {
  if (fs.existsSync(path.join(ROOT, "audio", "lesson_" + id))) throw new Error("появилась озвучка " + id);
}
console.log(`OK intro31 content: ${ORDER.length} букв, ${scenes} сцен, ${ids.length} id, ${unique.size} уникальных текстов`);
