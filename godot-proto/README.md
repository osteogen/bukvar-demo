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

`.godot-bin/` — бинарник редактора, ~146 МБ. В архивы не включать.
