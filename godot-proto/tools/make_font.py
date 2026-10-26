#!/usr/bin/env python3
"""Шрифт «Букваря»: Bellota Text (SIL OFL 1.1, © 2019 The Bellota Project Authors) с изменённой строчной «а».

Правка урока А (27.10.2026): маленькая «а» везде — «кружок + палочка с хвостиком» (как в прописях для 4–7 лет).
Скрипт берёт оригинальные Bellota Text Bold/Regular, рисует новую глиф-форму U+0430 (кружок; справа палочка от верха
кружка до строки, внизу хвостик вправо), ставит её в cmap U+0430 и переименовывает семейство в «Bukvar Bellota Text»
(по OFL изменённую версию нельзя называть исходным зарезервированным именем — у Bellota RFN нет, но переименуем для ясности).
Результат: fonts/BukvarBellotaText-Bold.ttf, fonts/BukvarBellotaText-Regular.ttf.
Запуск: python3 tools/make_font.py [папка_с_оригиналами]
"""
import math, os, sys
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.cu2quPen import Cu2QuPen

SRC = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/fonts/truetype/sand-box/google/Bellota Text"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "fonts")
GLYPH = "a.bukvar"


def arc(pen, cx, cy, rx, ry, a0, a1, steps):
    """Дуга эллипса кубическими кривыми от a0 до a1 (градусы), steps кусков."""
    for i in range(steps):
        t0 = math.radians(a0 + (a1 - a0) * i / steps)
        t1 = math.radians(a0 + (a1 - a0) * (i + 1) / steps)
        k = 4 / 3 * math.tan((t1 - t0) / 4)
        p0 = (cx + rx * math.cos(t0), cy + ry * math.sin(t0))
        p3 = (cx + rx * math.cos(t1), cy + ry * math.sin(t1))
        p1 = (p0[0] - k * rx * math.sin(t0), p0[1] + k * ry * math.cos(t0))
        p2 = (p3[0] + k * rx * math.sin(t1), p3[1] - k * ry * math.cos(t1))
        pen.curveTo(p1, p2, p3)


def build(font, t):
    """t — толщина штриха (Bold 80, Regular 60, как у «l»). Высота x = 500, выносной овершут 17/-10."""
    top, bot = 517, -10
    ry = (top - bot) / 2
    cy = bot + ry
    rx = 226
    lsb = 38
    cx = lsb + rx
    a = cx + rx - t                 # левый край палочки: правый край кружка = правый край палочки
    R = 118                         # радиус хвостика (внешний)
    cyt = bot + R
    gs = font.getGlyphSet()
    tt = TTGlyphPen(gs)
    pen = Cu2QuPen(tt, max_err=0.5, reverse_direction=False)
    # кружок: внешний контур по часовой (y вверх), внутренний — против
    pen.moveTo((cx, top)); arc(pen, cx, cy, rx, ry, 90, -270, 4); pen.closePath()
    irx, iry = rx - t * 1.02, ry - t * 0.92
    pen.moveTo((cx, cy + iry)); arc(pen, cx, cy, irx, iry, 90, 450, 4); pen.closePath()
    # палочка с хвостиком
    pen.moveTo((a, top))
    pen.lineTo((a + t, top))
    pen.lineTo((a + t, cyt))
    arc(pen, a + R, cyt, R - t, R - t, 180, 270, 1)          # внутренняя дуга хвостика
    arc(pen, a + R, bot + t / 2, t / 2, t / 2, 90, -90, 2)   # круглый кончик
    arc(pen, a + R, cyt, R, R, 270, 180, 1)                  # внешняя дуга обратно к палочке
    pen.closePath()
    g = tt.glyph()
    adv = int(round(a + R + t / 2 + 34))
    return g, adv


def main():
    for style, t in (("Bold", 80), ("Regular", 60)):
        f = TTFont(os.path.join(SRC, "BellotaText-%s.ttf" % style))
        g, adv = build(f, t)
        order = f.getGlyphOrder()
        if GLYPH not in order:
            f.setGlyphOrder(order + [GLYPH])
        f["glyf"][GLYPH] = g
        g.recalcBounds(f["glyf"])
        f["hmtx"][GLYPH] = (adv, g.xMin)
        if "post" in f and hasattr(f["post"], "extraNames"):
            pass
        for tb in f["cmap"].tables:
            if tb.isUnicode() and 0x430 in tb.cmap:
                tb.cmap[0x430] = GLYPH
        f["maxp"].numGlyphs = len(f.getGlyphOrder())
        for rec in f["name"].names:
            s = rec.toUnicode()
            s2 = s.replace("Bellota Text", "Bukvar Bellota Text").replace("BellotaText", "BukvarBellotaText")
            if rec.nameID in (1, 3, 4, 6, 16) and s2 != s:
                rec.string = s2
        os.makedirs(OUT, exist_ok=True)
        dst = os.path.join(OUT, "BukvarBellotaText-%s.ttf" % style)
        f.save(dst)
        print(dst, "adv", adv)


if __name__ == "__main__":
    main()
