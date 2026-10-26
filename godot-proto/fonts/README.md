# Шрифт урока: Bukvar Bellota Text

- **Файлы:** `BukvarBellotaText-Bold.ttf` (основной: подписи, кнопки) и `BukvarBellotaText-Regular.ttf`.
- **Основа:** Bellota Text Bold / Regular. Автор Kemie Guaida.
  Copyright 2019 The Bellota Project Authors (https://github.com/kemie/Bellota-Font).
- **Лицензия:** SIL Open Font License 1.1, полный текст в `OFL.txt`.
  Шрифт можно встраивать в приложение и распространять вместе с ним, в том числе в платном продукте.
  Отдельно сам шрифт продавать нельзя.
- **Что изменено** (правки урока А, 27.10.2026; скрипт `tools/make_font.py`):
  - Строчная «а» (U+0430) заменена на свой глиф `a.bukvar`: ровный кружок, вертикальная палочка справа и маленький хвостик вправо внизу. Это «школьная» форма, как в прописях.
  - Остальные буквы не тронуты.
  - По условию OFL изменённый шрифт не может называться «Bellota», поэтому семейство переименовано в **Bukvar Bellota Text** (name ID 1, 3, 4, 6, 16).
- **Пересобрать:** `python3 tools/make_font.py`. Нужен fontTools; исходники Bellota Text берутся из системных шрифтов, путь указан в скрипте.
