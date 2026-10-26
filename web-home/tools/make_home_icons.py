#!/usr/bin/env python3
"""Значки ряда разделов главной (вариант B, без подложки) → web-home/assets/home_N_key.png.
Источник — сдаточные PNG художника (home_sections/: 360×420 со встроенной подписью; «Язык жестов» v4 — 720×840).
Берём верхний квадрат (картинка без подписи — подпись на странице рисуется текстом), 216×216 = 2× кнопки планшета 108,
палитра 256 цветов. Мои наклейки — вариант _v2, Язык жестов — _v4.
Запуск из корня репозитория: python3 web-home/tools/make_home_icons.py <папка home_sections>   (нужен Pillow)"""
import os, sys
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "art/sketches/v3/home_sections")
OUT = os.path.join(ROOT, "web-home/assets")
ICONS = [("1_alfavit", "home_B_icon_1_alfavit"), ("2_slogi", "home_B_icon_2_slogi"), ("3_slova", "home_B_icon_3_slova"),
         ("4_chitaem", "home_B_icon_4_chitaem"), ("5_nakleyki", "home_B_icon_5_nakleyki_v2"), ("6_zhesty", "home_B_icon_6_zhesty_v4")]
total = 0
for key, src in ICONS:
    im = Image.open(os.path.join(SRC, src + ".png")).convert("RGBA")
    w = im.size[0]; im = im.crop((0, 0, w, w)).resize((216, 216), Image.LANCZOS)
    q = im.quantize(colors=256, method=Image.FASTOCTREE, dither=Image.FLOYDSTEINBERG)
    p = os.path.join(OUT, f"home_{key}.png"); q.save(p, optimize=True); total += os.path.getsize(p)
    print(p, os.path.getsize(p))
print("всего", total, "Б")
# шрифт подписей: PT Sans Bold, только буквы подписей
# pyftsubset PTSans-Bold.ttf --text="АлфавитСлогиСловаЧитаемМоинаклейкиЯзыкжестов " --flavor=woff2 --output-file=web-home/assets/ptsans-bold-cap.woff2
