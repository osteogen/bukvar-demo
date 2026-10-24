#!/usr/bin/env python3
"""Готовит лёгкие ассеты домашней страницы (web-home/assets) из финальных файлов проекта godot-proto.
Кубик = ui_cube_tint × цвет клетки (как modulate в Godot) + поверх ui_cube_face (закрытый: × 0.94).
Запуск из корня репозитория: python3 web-home/tools/make_assets.py   (нужны Pillow, fonttools, brotli)"""
import os
from PIL import Image, ImageChops
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UI = os.path.join(ROOT, "godot-proto/art/common/ui")
OUT = os.path.join(ROOT, "web-home/assets")
os.makedirs(OUT, exist_ok=True)
COLORS = ["#F6B9C0", "#F9CB9C", "#F6E08E", "#CDE9DC", "#BEDCEE", "#C9CAF0", "#DCC2EC"]
LOCK_GREY, LOCK_MIX, FACE_LOCK = (0xD8, 0xD2, 0xC7), 0.5, 0.94

def hexrgb(h): return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
def lerp(a, b, t): return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))

tint = Image.open(os.path.join(UI, "ui_cube_tint.png")).convert("RGBA")
face = Image.open(os.path.join(UI, "ui_cube_face.png")).convert("RGBA")
def mul(im, rgb):
    m = ImageChops.multiply(im, Image.new("RGBA", im.size, rgb + (255,)))
    m.putalpha(im.getchannel("A"))
    return m
for k, h in enumerate(COLORS):
    for locked in (False, True):
        c = hexrgb(h)
        if locked:
            c = lerp(c, LOCK_GREY, LOCK_MIX)
        im = Image.new("RGBA", tint.size, (0, 0, 0, 0))
        im.alpha_composite(mul(tint, c))
        im.alpha_composite(mul(face, tuple(round(255 * FACE_LOCK) for _ in range(3))) if locked else face)
        im.save(os.path.join(OUT, "cube_%d%s.webp" % (k, "_lock" if locked else "")), quality=88, method=6)
for f in ("ui_hand_f1", "ui_hand_f2"):
    Image.open(os.path.join(UI, f + ".png")).convert("RGBA").save(os.path.join(OUT, f.replace("ui_", "") + ".webp"), quality=90, method=6)
# иконка — кубик «А» (персик, красная А): favicon главной (64×64) и иконка проекта Godot (core/app_icon.png, 256×256;
# из неё экспорт делает index.icon.png / apple-touch-icon урока — вместо логотипа Godot)
from PIL import ImageDraw, ImageFont
ic = Image.new("RGBA", tint.size, (0, 0, 0, 0)); ic.alpha_composite(mul(tint, hexrgb(COLORS[1]))); ic.alpha_composite(face)
k = tint.size[0] / 124.0
fnt = ImageFont.truetype(os.path.join(ROOT, "godot-proto/core/fonts/DejaVuSans-Bold.ttf"), round(52 * k))
d = ImageDraw.Draw(ic); cx, cy = (9.7 + 93 / 2) * k, (19.4 + 93 / 2) * k
d.text((cx, cy), "А", font=fnt, fill="#D93A2B", anchor="mm")
ic.resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, "favicon.png"), optimize=True)
big = Image.new("RGBA", (256, 256), (0, 0, 0, 0)); big.alpha_composite(ic.resize((240, 240), Image.LANCZOS), (8, 8))
big.save(os.path.join(ROOT, "godot-proto/core/app_icon.png"), optimize=True)
# шрифт: DejaVu Sans Bold, только прописные А–Я, Ё
from fontTools import subset
opts = subset.Options(); opts.flavor = "woff2"; opts.layout_features = ["*"]; opts.name_IDs = ["*"]
font = subset.load_font(os.path.join(ROOT, "godot-proto/core/fonts/DejaVuSans-Bold.ttf"), opts)
s = subset.Subsetter(opts); s.populate(text="АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"); s.subset(font)
subset.save_font(font, os.path.join(OUT, "dejavu-sans-bold-cyr.woff2"), opts)
print("ok")
