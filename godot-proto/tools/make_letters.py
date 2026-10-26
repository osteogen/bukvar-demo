#!/usr/bin/env python3
"""Картинки строчной «а» по шрифту «Букваря» (fonts/BukvarBellotaText-Bold.ttf): кружок + палочка с хвостиком.

Правка урока А (27.10.2026): маленькая «а» во всех сценах должна быть одной формы. Большая «А» — рисунок
иллюстратора, её не трогаем. Скрипт перерисовывает (те же размеры холста и та же область буквы, что были):
  art/letters/letter_a_lower.png, balloon_letter_a_lower.png, tile_a_lower.png, tile_sort_a_lower.png,
  art/lesson_a/pic_basket_small_letter.png,
и рисует новую дорожку art/letters/letter_a_lower_trace.png (2048×1536 = сцена 1024×768 @2x) в стиле letter_a_trace,
а штрихи для обводки (ломаные в координатах сцены) записывает в data/lesson_a/lesson.json → write.lower.strokes.
Запуск: python3 tools/make_letters.py
"""
import json, math, os
from collections import OrderedDict
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FONT = os.path.join(ROOT, "fonts", "BukvarBellotaText-Bold.ttf")
RED = (217, 58, 43, 255)
WHITE = (255, 255, 255, 255)
SS = 4  # суперсэмплинг


def glyph(height, thick_frac, outline):
    """Красная «а» высотой height px (по красной части), утолщение thick_frac·height, белая обводка outline px."""
    size = int(height * SS / 0.527 * 1.0)
    f = ImageFont.truetype(FONT, size)
    th = int(round(thick_frac * height * SS))
    ol = int(round(outline * SS))
    pad = th + ol + 10
    l, t, r, b = f.getbbox("а")
    W, H = r - l + 2 * pad, b - t + 2 * pad
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    org = (pad - l, pad - t)
    if ol > 0:
        d.text(org, "а", font=f, fill=WHITE, stroke_width=th + ol, stroke_fill=WHITE)
    d.text(org, "а", font=f, fill=RED, stroke_width=th, stroke_fill=RED)
    im = im.crop(im.getbbox())
    return im, th + ol  # отступ обводки (в SS-пикселях) вокруг красной части


def place(path, red_box, outline, thick_frac=0.035, bg=None, erase_pad=6):
    """Ставит новую «а» в область red_box (x0,y0,x1,y1) старой красной буквы; bg — цвет фона, чтобы стереть старую."""
    src = os.path.join("/workspace/rev1_removed/letters_before_regen", os.path.basename(path))
    im = Image.open(src if os.path.exists(src) else path).convert("RGBA")
    x0, y0, x1, y1 = red_box
    if bg is not None:
        ImageDraw.Draw(im).rectangle((x0 - erase_pad - outline, y0 - erase_pad - outline,
                                      x1 + erase_pad + outline, y1 + erase_pad + outline), fill=bg)
    else:
        im = Image.new("RGBA", im.size, (0, 0, 0, 0))   # картинка — только буква: рисуем на чистом холсте
    h = (y1 - y0) * 0.92            # новая форма шире (хвостик) — чуть ниже, чтобы влезть в ту же область
    g, _ = glyph(h, thick_frac, outline)
    g = g.resize((max(1, round(g.width / SS)), max(1, round(g.height / SS))), Image.LANCZOS)
    maxw = (x1 - x0) + 2 * outline + 14
    if g.width > maxw:
        g = g.resize((maxw, round(g.height * maxw / g.width)), Image.LANCZOS)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    im.alpha_composite(g, (int(round(cx - g.width / 2)), int(round(cy - g.height / 2))))
    im.save(path)
    print("ok", os.path.relpath(path, ROOT), im.size)


# ---------- дорожка для обводки ----------
# Геометрия — как в tools/make_font.py (единицы шрифта, y вверх): кружок cx 264, cy 253.5, rx 226, ry 263.5, штрих 80;
# палочка x 410..490 от 517 до 108; хвостик — центр (528, 108), R 118.
S = 0.82                           # px сцены на единицу
OX = 512 - 317 * S
OY = 405 + 253.5 * S


def P(u, v):
    return (round(OX + u * S, 1), round(OY - v * S, 1))


def stroke_paths():
    circle = []
    # старт — справа вверху кружка (≈ на «2 часах»), ведём влево через верх, вниз, по низу и вверх справа
    a0, a1 = 50, 50 + 360 - 25
    for i in range(37):
        a = math.radians(a0 + (a1 - a0) * i / 36)
        circle.append(P(264 + 186 * math.cos(a), 253.5 + 223.5 * math.sin(a)))
    stick = [P(450, 500)]
    for i in range(1, 9):
        stick.append(P(450, 500 - (500 - 108) * i / 8))
    for i in range(1, 9):
        a = math.radians(180 + 90 * i / 8)
        stick.append(P(528 + 78 * math.cos(a), 108 + 78 * math.sin(a)))
    stick.append(P(560, 30))
    return [circle, stick]


def draw_trace(paths, dst):
    k = 2
    W, H = 1024 * k, 768 * k
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    def poly(pts, width, col):
        q = [(x * k, y * k) for x, y in pts]
        d.line(q, fill=col, width=width, joint="curve")
        for x, y in (q[0], q[-1]):
            d.ellipse((x - width / 2, y - width / 2, x + width / 2, y + width / 2), fill=col)
    for p in paths:
        poly(p, 120, (189, 182, 168, 255))
    for p in paths:
        poly(p, 108, (230, 223, 210, 255))
    # пунктир-направляющая со стрелкой на конце
    for p in paths:
        q = [(x * k, y * k) for x, y in p]
        acc = 0.0
        for (xa, ya), (xb, yb) in zip(q, q[1:]):
            seg = math.hypot(xb - xa, yb - ya)
            n = max(1, int(seg / 6))
            for j in range(n):
                s = acc + seg * j / n
                if (s // 22) % 2 == 0:
                    t0, t1 = j / n, (j + 1) / n
                    d.line((xa + (xb - xa) * t0, ya + (yb - ya) * t0, xa + (xb - xa) * t1, ya + (yb - ya) * t1),
                           fill=(163, 155, 140, 255), width=6)
            acc += seg
        (xa, ya), (xb, yb) = q[-2], q[-1]
        ang = math.atan2(yb - ya, xb - xa)
        for s in (2.6, -2.6):
            d.line((xb, yb, xb + 26 * math.cos(ang + s), yb + 26 * math.sin(ang + s)), fill=(163, 155, 140, 255), width=6)
    im.save(dst)
    print("ok", os.path.relpath(dst, ROOT), im.size)


def main():
    L = os.path.join(ROOT, "art", "letters")
    place(os.path.join(L, "letter_a_lower.png"), (36, 36, 467, 553), 16, 0.035)
    place(os.path.join(L, "balloon_letter_a_lower.png"), (50, 50, 149, 169), 10, 0.045)
    place(os.path.join(L, "tile_a_lower.png"), (70, 61, 164, 175), 0, 0.05, bg=(247, 240, 222, 255))
    place(os.path.join(L, "tile_sort_a_lower.png"), (67, 78, 132, 156), 4, 0.05, bg=(247, 240, 222, 255))
    place(os.path.join(ROOT, "art", "lesson_a", "pic_basket_small_letter.png"), (155, 296, 222, 377), 3, 0.05)
    paths = stroke_paths()
    draw_trace(paths, os.path.join(L, "letter_a_lower_trace.png"))
    lj = os.path.join(ROOT, "data", "lesson_a", "lesson.json")
    with open(lj, encoding="utf-8") as fh:
        data = json.load(fh, object_pairs_hook=OrderedDict)
    low = data["write"].setdefault("lower", OrderedDict())
    low["strokes"] = [[[x, y] for x, y in p] for p in paths]
    with open(lj, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("strokes ->", lj)


if __name__ == "__main__":
    main()
