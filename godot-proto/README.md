# godot-proto — минимальная проверка web-экспорта Godot 4.7.2

Сцена «слово на звук»:

- картинка (SVG) появляется твином;
- через 5 с появляется «рука» (подсказка);
- тап по картинке → слово «аист» (первая буква красная) + звук;
- затем частицы-награда и покачивание картинки.

Данные буквы лежат в `letters/a.tres` (Resource `LetterConfig` + `WordEntry`).

Сборка (Linux, headless; шаблоны экспорта 4.7.2 должны лежать в `~/.local/share/godot/export_templates/4.7.2.stable/`):

```bash
G=.godot-bin/Godot_v4.7.2-stable_linux.x86_64
$G --headless --path . --import
$G --headless --path . --export-release "Web" build/index.html   # однопоточный (thread_support=false), PWA вкл.
```

Проверка в headless Chrome:

```bash
PORT=28790 node tests/smoke.mjs     # THROTTLE=1 — сеть ~10 Мбит/с, RTT 40 мс; NOCOI=1 — без заголовков COOP/COEP
```

Результаты — в `../godot-analysis.md`, §1.1.

## Урок «А»: навигация и подсказки (24.10.2026)

- Старт как раньше: памятка взрослому `s00` → «Начнём!» → `s01`.
- Крестик `ui_exit` справа вверху на `s01–s10` и «домой» в `s10` → экран букв `menu/letters_menu.tscn` (33 буквы, активна только «А» → `s01`). Прямо открыть экран букв: `?step=letters_menu`.
- Рука-подсказка: `IDLE_HINT_SEC = 20.0` в `core/main.gd` — 20 с без касаний в состоянии ожидания действия; любое касание сбрасывает отсчёт; пока звучит реплика, отсчёт стоит на нуле. В тесте/отладке: `?hint_sec=3`.
- Тест: `PORT=55791 node tests/lesson.mjs` (нужен `../.tools/node_modules/puppeteer-core`: `cd ../.tools && npm i puppeteer-core@23`).

`.godot-bin/` — бинарник редактора, ~146 МБ. В архивы не включать.
