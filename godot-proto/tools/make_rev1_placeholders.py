#!/usr/bin/env python3
"""Заглушки графики для правок урока А (27.10.2026). Все PNG — 2× логического размера.
Это временная графика до иллюстратора (спецификация — order/lesson-a-revisions-art-spec.md); финальный файл кладётся
в art/<тот же путь> и автоматически перекрывает заглушку (art/ → art_provisional/ → art_placeholder/).
Подписи-имени на этих заглушках нет: они видны на экране ребёнка и в демо, поэтому нарисованы «почти как надо».
Запуск: python3 tools/make_rev1_placeholders.py
"""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PH = os.path.join(ROOT, "art_placeholder")
FONT = os.path.join(ROOT, "fonts", "BukvarBellotaText-Bold.ttf")
ALPHABET = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"


def save(im, rel):
    p = os.path.join(PH, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im.save(p, optimize=True)
    print("ok", rel, im.size)


def cloud(w, h, seed):
    rnd = random.Random(seed)
    k = 3
    im = Image.new("RGBA", (w * k, h * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    blobs = [(0.22, 0.62, 0.20), (0.40, 0.45, 0.26), (0.62, 0.42, 0.24), (0.80, 0.60, 0.18), (0.50, 0.66, 0.22)]
    for shade, dy in (((214, 226, 236, 255), 0.05), ((255, 255, 255, 255), 0.0)):
        for cx, cy, r in blobs:
            cx += rnd.uniform(-0.01, 0.01)
            R = r * h * k * 1.25
            d.ellipse((cx * w * k - R, (cy + dy) * h * k - R * 0.82, cx * w * k + R, (cy + dy) * h * k + R * 0.82), fill=shade)
        d.rounded_rectangle((0.14 * w * k, (0.58 + dy) * h * k, 0.88 * w * k, (0.86 + dy) * h * k), radius=int(0.14 * h * k), fill=shade)
    im = im.resize((w, h), Image.LANCZOS)
    return im


def grass(w, h):
    k = 3
    im = Image.new("RGBA", (w * k, h * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rnd = random.Random(7)
    cols = [(108, 158, 72, 255), (126, 176, 84, 255), (92, 140, 62, 255)]
    base = h * k
    for i in range(9):
        x = w * k * (0.12 + 0.76 * i / 8) + rnd.uniform(-6, 6)
        top = base * rnd.uniform(0.05, 0.35)
        lean = rnd.uniform(-0.22, 0.22) * w * k
        bw = w * k * 0.07
        d.polygon([(x - bw, base), (x + lean, top), (x + bw, base)], fill=cols[i % 3])
    return im.resize((w, h), Image.LANCZOS)


def sun(sz):
    k = 3
    S = sz * k
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = S / 2
    for i in range(12):
        a = math.tau * i / 12
        r0, r1, bw = S * 0.34, S * 0.48, 0.13
        d.polygon([(c + r0 * math.cos(a - bw), c + r0 * math.sin(a - bw)), (c + r1 * math.cos(a), c + r1 * math.sin(a)),
                   (c + r0 * math.cos(a + bw), c + r0 * math.sin(a + bw))], fill=(255, 200, 60, 255))
    d.ellipse((c - S * 0.31, c - S * 0.31, c + S * 0.31, c + S * 0.31), fill=(255, 196, 46, 255), outline=(232, 160, 40, 255), width=int(S * 0.02))
    d.ellipse((c - S * 0.22, c - S * 0.24, c + S * 0.05, c - S * 0.02), fill=(255, 222, 120, 255))
    return im.resize((sz, sz), Image.LANCZOS)


def rays(w, h, apex_y):
    """Длинные полупрозрачные лучи веером вниз от солнца (точка apex по центру сверху)."""
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ax, ay = w / 2, apex_y
    n = 9
    for i in range(n):
        lay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(lay)
        a = math.radians(90 + (i - (n - 1) / 2) * 15.5)
        half = math.radians(3.6 if i % 2 else 5.2)
        L = h * 1.4
        d.polygon([(ax, ay), (ax + L * math.cos(a - half), ay + L * math.sin(a - half)),
                   (ax + L * math.cos(a + half), ay + L * math.sin(a + half))], fill=(255, 236, 150, 255))
        lay = lay.filter(ImageFilter.GaussianBlur(10))
        # затухание к низу
        grad = Image.linear_gradient("L").resize((w, h))
        fade = grad.point(lambda v: int(255 * (1 - v / 255) ** 1.2))
        al = Image.composite(lay.getchannel("A").point(lambda v: int(v * 0.42)), Image.new("L", (w, h), 0), fade)
        lay.putalpha(al)
        im.alpha_composite(lay)
    return im


def sticker():
    """Карточка-наклейка «А а» из настоящих букв (большая — рисунок иллюстратора, маленькая — по шрифту)."""
    W = H = 520
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((22, 30, W - 14, H - 6), radius=70, fill=(60, 40, 20, 90))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(8)))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((12, 12, W - 20, H - 24), radius=70, fill=(255, 255, 255, 255))             # белый край наклейки
    d.rounded_rectangle((30, 30, W - 38, H - 42), radius=56, fill=(247, 240, 222, 255), outline=(226, 180, 46, 255), width=10)
    up = Image.open(os.path.join(ROOT, "art", "letters", "letter_a_upper.png")).convert("RGBA")
    lo = Image.open(os.path.join(ROOT, "art", "letters", "letter_a_lower.png")).convert("RGBA")
    up = up.resize((int(up.width * 300 / up.height), 300), Image.LANCZOS)
    lo = lo.resize((int(lo.width * 205 / lo.height), 205), Image.LANCZOS)
    gap = 14
    x0 = (W - 8 - up.width - gap - lo.width) // 2
    im.alpha_composite(up, (x0, 92))
    im.alpha_composite(lo, (x0 + up.width + gap, 392 - 205))
    return im


GRID = {"pages": [[24, 24, 408, 576], [432, 24, 816, 576]], "cols": 3, "rows": 6}


def alphabet():
    """Бледный алфавит на развороте альбома (накладывается на reward_album_page 840×600); клетка А — пунктирное
    место под наклейку. Сетка — GRID (те же числа в lesson.json → end.album.grid)."""
    W, H = 840, 600
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((30, 30, 405, 570), fill=(247, 240, 222, 255))   # прячем пунктирное место из reward_album_page
    f = ImageFont.truetype(FONT, 50)
    cells = []
    for (x0, y0, x1, y1) in GRID["pages"]:
        cw, ch = (x1 - x0) / GRID["cols"], (y1 - y0) / GRID["rows"]
        for r in range(GRID["rows"]):
            for c in range(GRID["cols"]):
                cells.append((x0 + c * cw, y0 + r * ch, x0 + (c + 1) * cw, y0 + (r + 1) * ch))
    for i, ch in enumerate(ALPHABET):
        x0, y0, x1, y1 = cells[i]
        pad = 7
        box = (x0 + pad, y0 + pad, x1 - pad, y1 - pad)
        if i == 0:   # место под наклейку: пунктир
            _dashed_rect(d, box, (190, 180, 160, 255), 4, 12)
            txt, col = "А а", (214, 204, 186, 255)
        else:
            d.rounded_rectangle(box, radius=14, outline=(232, 224, 208, 255), width=3)
            txt, col = ch + " " + ch.lower(), (205, 195, 178, 255)
        bb = d.textbbox((0, 0), txt, font=f)
        d.text(((box[0] + box[2] - (bb[2] - bb[0])) / 2 - bb[0], (box[1] + box[3] - (bb[3] - bb[1])) / 2 - bb[1]), txt, font=f, fill=col)
    return im


def _dashed_rect(d, box, col, w, dash):
    x0, y0, x1, y1 = box
    for (ax, ay, bx, by) in ((x0, y0, x1, y0), (x1, y0, x1, y1), (x1, y1, x0, y1), (x0, y1, x0, y0)):
        L = math.hypot(bx - ax, by - ay)
        n = int(L / dash)
        for j in range(0, n, 2):
            t0, t1 = j / n, min(1.0, (j + 1) / n)
            d.line((ax + (bx - ax) * t0, ay + (by - ay) * t0, ax + (bx - ax) * t1, ay + (by - ay) * t1), fill=col, width=w)


def main():
    save(cloud(440, 220, 1), "lesson_a/pic_cloud_1.png")
    save(cloud(360, 180, 2), "lesson_a/pic_cloud_2.png")
    save(grass(112, 96), "lesson_a/pic_grass_tuft.png")
    save(sun(240), "lesson_a/pic_sun.png")
    save(rays(1400, 760, 40), "lesson_a/pic_sun_rays.png")
    save(sticker(), "common/reward/reward_sticker_a.png")
    save(alphabet(), "common/reward/reward_album_alphabet.png")


if __name__ == "__main__":
    main()
