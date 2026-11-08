#!/usr/bin/env bash
# Общий веб-экспорт показывает кубик и заголовок урока «А».
# После копирования сборки в lesson-u/ подменяет заставку на «У у» и заголовок.
# Движковая boot_splash в project.godot — только кремовый фон (show_image=false), буквы «А» там нет.
set -euo pipefail
DEST="${1:?path to lesson-u directory}"
SRC="$(cd "$(dirname "$0")/lesson_u_splash" && pwd)"
for f in index.icon.png index.apple-touch-icon.png index.144x144.png index.180x180.png index.512x512.png; do
  test -s "$SRC/$f"
  cp "$SRC/$f" "$DEST/$f"
done
python3 - "$DEST" << 'PY'
import pathlib, sys
dest = pathlib.Path(sys.argv[1])
old, new = "Урок А — демо", "Урок У — демо"
for name in ("index.html", "index.manifest.json"):
    p = dest / name
    text = p.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"{old!r} not found in {p}")
    p.write_text(text.replace(old, new), encoding="utf-8")
html = (dest / "index.html").read_text(encoding="utf-8")
if "<title>Урок У — демо</title>" not in html:
    raise SystemExit("title was not updated")
if 'src="index.apple-touch-icon.png"' not in html:
    raise SystemExit("loading image tag missing")
PY
