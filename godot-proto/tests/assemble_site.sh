#!/usr/bin/env bash
# Собирает сайт так же, как .github/workflows/pages.yml: корень = web-home/ (без tools/), lesson-a/ = веб-экспорт Godot.
# Запуск из godot-proto/:  bash tests/assemble_site.sh [папка-сайта]   (по умолчанию ../site; build/ должен быть уже экспортирован)
set -euo pipefail
cd "$(dirname "$0")/.."
SITE="${1:-../site}"
test -s build/index.html && test -s build/index.wasm && test -s build/index.pck
rm -rf "$SITE" && mkdir -p "$SITE/lesson-a" "$SITE/lesson-u"
(cd ../web-home && tar --exclude=./tools -cf - .) | tar -C "$SITE" -xf -
cp -R build/. "$SITE/lesson-a/"
# Урок «У» — тот же web-export; буква выбирается ?letter=u / ?lesson=u
cp -R build/. "$SITE/lesson-u/"
touch "$SITE/.nojekyll"
echo "site: $(cd "$SITE" && pwd)"; (cd "$SITE" && find . -type f | sort)
