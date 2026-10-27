#!/usr/bin/env python3
"""Заглушки ассетов урока «А» строго по соглашению с художником (см. ASSETS.md).
Вся графика — PNG в 2× (логический размер × 2). Звук — OGG 22,05 кГц моно.
Настоящий файл кладётся ПОВЕРХ заглушки с тем же путём и именем.
Запуск: python3 tools/make_placeholders.py [--force]  (без --force существующие файлы не трогаются)."""
import json, os, subprocess, sys, colorsys, hashlib
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FORCE = "--force" in sys.argv
FB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FR = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
RED, BLUE, GREY = (217, 58, 43), (31, 58, 138), (190, 190, 190)   # RED = #D93A2B — красный гласных (ровно)
WHITE = (255, 255, 255)
MUSTARD, CORAL = (226, 180, 46), (224, 122, 78)   # #E2B42E — «Начнём!», «Далее», галочка; #E07A4E — точка старта, клюв аиста

def font(sz, bold=True): return ImageFont.truetype(FB if bold else FR, sz)
def hue(id_):
    h = int(hashlib.md5(id_.encode()).hexdigest()[:4], 16) / 65535
    r, g, b = colorsys.hls_to_rgb(h, 0.80, 0.55); return (int(r*255), int(g*255), int(b*255))
def out(rel):
    p = os.path.join(ROOT, rel)
    if os.path.exists(p) and not FORCE: return None
    os.makedirs(os.path.dirname(p), exist_ok=True); return p
def ctext(d, box, text, f, fill, **kw):
    x0, y0, x1, y1 = box
    bb = d.multiline_textbbox((0, 0), text, font=f, align="center", **{k: v for k, v in kw.items() if k != "stroke_fill"})
    d.multiline_text(((x0+x1-(bb[2]-bb[0]))/2-bb[0], (y0+y1-(bb[3]-bb[1]))/2-bb[1]), text, font=f, fill=fill, align="center", **kw)
def blank(w, h): im = Image.new("RGBA", (w, h), (0, 0, 0, 0)); return im, ImageDraw.Draw(im)
def tag(d, w, h, rel):   # подпись «это заглушка» — имя файла внизу
    ctext(d, (0, h*0.86, w, h*0.98), os.path.basename(rel), font(max(12, int(min(w, h)*0.045)), False), (60, 60, 60, 255))

def card(rel, word, w, h, color=None, circle=False, alpha=255):
    p = out(rel)
    if not p: return
    im, d = blank(w, h); c = (color or hue(rel)) + (alpha,)
    (d.ellipse if circle else (lambda b, **k: d.rounded_rectangle(b, radius=min(w, h)//8, **k)))((6, 6, w-6, h-6), fill=c, outline=(60, 60, 60, alpha), width=max(4, w//80))
    if word: ctext(d, (0, 0, w, h*0.8), word, font(max(20, int(min(w, h)*0.15))), (40, 40, 40, 255))
    tag(d, w, h, rel); im.save(p, optimize=True)

def bg(rel, top, bottom, label):
    p = out(rel)
    if not p: return
    w, h = 2732, 1536; im = Image.new("RGB", (w, h)); d = ImageDraw.Draw(im)
    for y in range(h):
        t = y/(h-1); d.line([(0, y), (w, y)], fill=tuple(int(top[i]*(1-t)+bottom[i]*t) for i in range(3)))
    d.rectangle((342, 0, 2390, 1535), outline=(255, 255, 255), width=4)   # безопасная зона 4:3 (1024×768 лог.)
    ctext(d, (0, 0, w, 200), f"{os.path.basename(rel)} — {label} (заглушка 2×; рамка — зона 4:3)", font(44, False), (90, 90, 90))
    im.save(p, optimize=True)

def roundbtn(rel, sym, color, size, caption=None):
    p = out(rel)
    if not p: return
    im, d = blank(size, size)
    d.ellipse((6, 6, size-6, size-6), fill=color+(255,), outline=(255, 255, 255, 255), width=size//24)
    ctext(d, (0, 0, size, size*(0.8 if caption else 1)), sym, font(int(size*0.42)), (255, 255, 255, 255))
    if caption: ctext(d, (0, size*0.6, size, size*0.9), caption, font(int(size*0.11)), (255, 255, 255, 255))
    im.save(p, optimize=True)

def ear_btn(rel, color, size, crossed=False):
    """Кнопка-значок «ухо» (без слов); у «нет» ухо перечёркнуто серой (не красной) чертой."""
    p = out(rel)
    if not p: return
    im, d = blank(size, size)
    d.ellipse((6, 6, size-6, size-6), fill=color+(255,), outline=(255, 255, 255, 255), width=size//24)
    s = size / 340
    w = (255, 255, 255, 255)
    d.arc((110*s, 70*s, 240*s, 230*s), 180, 90, fill=w, width=int(22*s))                    # раковина уха
    d.line([(240*s, 150*s), (200*s, 270*s)], fill=w, width=int(22*s))
    d.arc((140*s, 110*s, 210*s, 180*s), 180, 30, fill=w, width=int(14*s))
    if crossed:
        d.line([(80*s, 80*s), (260*s, 260*s)], fill=(90, 90, 90, 255), width=int(20*s))
    im.save(p, optimize=True)

def glyph(rel, ch, w, h, color, outline=True, size=None):
    p = out(rel)
    if not p: return
    im, d = blank(w, h); f = font(size or int(h*0.85))
    ctext(d, (0, 0, w, h), ch, f, color+(255,), stroke_width=(max(6, h//40) if outline else 0), stroke_fill=(255, 255, 255, 255))
    im.save(p, optimize=True)

# ---------- фоны: res://art/common/bg/ (1366×768 лог. → 2732×1536) ----------
bg("art_placeholder/common/bg/bg_room_day.png", (255, 236, 205), (214, 170, 120), "детская, день")
bg("art_placeholder/common/bg/bg_room_evening.png", (120, 90, 140), (90, 60, 50), "детская, вечер")
bg("art_placeholder/common/bg/bg_meadow.png", (170, 220, 255), (120, 200, 110), "полянка у озера")
bg("art_placeholder/common/bg/bg_sky.png", (120, 180, 250), (220, 240, 255), "небо")
bg("art_placeholder/common/bg/bg_desk.png", (245, 245, 235), (225, 220, 200), "парта / лист в клетку")

# ---------- картинки урока: res://art/lesson_a/pic_<id>.png (+ кадры _f1/_f2) ----------
L = "art_placeholder/lesson_a/"
COLORS = {"mak": (255, 150, 120), "shar": (250, 210, 60)}   # мак — коралловый, шар — жёлтый (красный только для гласных)
for id_, word in [("aist", "аист"), ("alya_card", "Аля\nпортрет"), ("astra", "астра\n(на стебле)"), ("mak", "мак\n(коралловый)"), ("shar", "шар\n(жёлтый)"),
                  ("lampa", "лампа"), ("kot", "кот"), ("dom", "дом")]:
    card(f"{L}pic_{id_}.png", word, 800, 800, COLORS.get(id_))
for id_, word in [("aist", "аист"), ("alya_card", "Аля"), ("astra", "астра")]:   # 2 кадра «оживления»
    card(f"{L}pic_{id_}_f1.png", word + "\nкадр 1", 800, 800)
    card(f"{L}pic_{id_}_f2.png", word + "\nкадр 2", 800, 800, (255, 250, 200))
card(f"{L}pic_lesenka.png", "лесенка\n(форма А)", 760, 920, (200, 160, 110))
card(f"{L}pic_lesenka_ghost.png", "лесенка\nполупрозр.", 760, 920, (200, 160, 110), alpha=120)
# шарики сцены 7 — нейтральные цвета (не синие и не зелёные: зарезервированы для согласных; не красные — гласные)
for col, rgb in [("beige", (226, 206, 176)), ("grey", (196, 196, 200)), ("sand", (214, 186, 140)), ("cream", (240, 228, 200))]:
    p = out(f"{L}pic_balloons_{col}.png")
    if p:
        im, d = blank(320, 440)
        d.ellipse((20, 8, 300, 340), fill=rgb+(255,), outline=(90, 90, 90, 255), width=6)
        d.line([(160, 340), (160, 436)], fill=(90, 90, 90, 255), width=4); im.save(p)
for n in (1, 2, 3):
    p = out(f"{L}pic_balloon_pop_{n}.png")
    if p:
        im, d = blank(320, 440)
        for k in range(10 + n*6):
            import random; random.seed(n*100+k)
            x, y, r = random.randint(40, 280), random.randint(40, 340), 10 + n*2
            d.ellipse((x-r, y-r, x+r, y+r), fill=random.choice([(255, 210, 60), (255, 255, 255), (240, 228, 200)])+(255,))
        im.save(p)
card(f"{L}pic_basket_big.png", "корзинка\nбольшая", 600, 480, (205, 160, 100))
card(f"{L}pic_basket_small.png", "корзинка\nмаленькая", 480, 380, (215, 175, 120))
card(f"{L}pic_grib.png", "гриб", 128, 128, (150, 100, 60), circle=True)   # коричневая шляпка, без красного

# ---------- буквы: res://art/letters/ ----------
glyph("art_placeholder/letters/letter_a_upper.png", "А", 600, 760, RED)
glyph("art_placeholder/letters/letter_a_lower.png", "а", 440, 560, RED, size=520)
p = out("art_placeholder/letters/letter_a_trace.png")      # во весь логический экран 1024×768 (2×): совпадает с координатами штрихов в lesson.json
if p:
    lesson = json.load(open(os.path.join(ROOT, "data/lesson_a/lesson.json")))
    im, d = blank(2048, 1536)
    for (a, b) in lesson["write"]["strokes"]:
        A, B = (a[0]*2, a[1]*2), (b[0]*2, b[1]*2)
        d.line([A, B], fill=GREY+(255,), width=112)
        for P in (A, B): d.ellipse((P[0]-56, P[1]-56, P[0]+56, P[1]+56), fill=GREY+(255,))
    im.save(p, optimize=True)
for case, ch in [("upper", "А"), ("lower", "а")]:
    p = out(f"art_placeholder/letters/tile_a_{case}.png")
    if p:
        im, d = blank(240, 240)
        d.rounded_rectangle((6, 6, 234, 234), radius=30, fill=(255, 250, 235, 255), outline=(150, 120, 80, 255), width=6)
        ctext(d, (0, 0, 240, 240), ch, font(170 if case == "upper" else 140), RED+(255,)); im.save(p)
glyph("art_placeholder/letters/balloon_letter_a_upper.png", "А", 200, 220, RED, outline=False)
glyph("art_placeholder/letters/balloon_letter_a_lower.png", "а", 200, 220, RED, outline=False, size=170)
# фигуры-помехи для шариков (сцена 7) — белые, с тонким серым контуром (виден на светлом шарике)
def shape(name, draw):
    p = out(f"art_placeholder/letters/balloon_shape_{name}.png")
    if p:
        im, d = blank(200, 200); draw(d); im.save(p)
shape("triangle", lambda d: d.polygon([(100, 18), (186, 182), (14, 182)], fill=WHITE+(255,), outline=(120, 120, 120, 255), width=5))
shape("circle", lambda d: d.ellipse((22, 22, 178, 178), fill=WHITE+(255,), outline=(120, 120, 120, 255), width=5))
shape("square", lambda d: d.rectangle((30, 30, 170, 170), fill=WHITE+(255,), outline=(120, 120, 120, 255), width=5))
import math
shape("star", lambda d: d.polygon([(100 + (88 if k % 2 == 0 else 38) * math.sin(k * math.pi / 5), 108 - (88 if k % 2 == 0 else 38) * math.cos(k * math.pi / 5)) for k in range(10)], fill=WHITE+(255,), outline=(120, 120, 120, 255), width=5))

# ---------- интерфейс: res://art/common/ui/ ----------
U = "art_placeholder/common/ui/"
roundbtn(U+"ui_btn_start.png", "▶", MUSTARD, 384)   # кнопки — только значки, без слов
roundbtn(U+"ui_btn_next.png", "➜", MUSTARD, 200)
roundbtn(U+"ui_btn_back.png", "⬅", (240, 140, 40), 160)
for n, dy in [(1, 0), (2, 14)]:
    p = out(f"{U}ui_hand_f{n}.png")
    if p:
        im, d = blank(192, 192)
        sk, ol = (255, 214, 170, 255), (90, 60, 40, 255)
        d.rounded_rectangle((70, 10 + dy, 110, 120 + dy), radius=20, fill=sk, outline=ol, width=5)      # указательный палец
        d.rounded_rectangle((50, 90 + dy, 160, 185), radius=34, fill=sk, outline=ol, width=5)           # ладонь
        d.rounded_rectangle((70, 10 + dy, 110, 120 + dy), radius=20, fill=sk)
        im.save(p)
# дополнительные элементы ui_kit (имена предложены, согласовать с художником — см. ASSETS.md)
ear_btn(U+"ui_ear_yes.png", MUSTARD, 340)   # горчичная — так согласовано (финальная графика v3)
ear_btn(U+"ui_ear_no.png", (150, 150, 150), 340, crossed=True)
roundbtn(U+"ui_circle_red.png", "", RED, 384)
roundbtn(U+"ui_circle_empty.png", "", (235, 235, 235), 96)
roundbtn(U+"ui_sound_check.png", "♪", (150, 115, 80), 180)   # не синий (твёрдые согласные)
roundbtn(U+"ui_btn_again.png", "↺", (240, 140, 40), 260)   # не зелёный (мягкие согласные)
roundbtn(U+"ui_btn_home.png", "⌂", (150, 115, 80), 260)   # не синий
glyph(U+"ui_note.png", "♪", 88, 88, (120, 90, 60), outline=False)
# счётчик сцены 7: пустая звёздочка → золотая
glyph(U+"ui_counter_star_empty.png", "☆", 96, 96, (150, 140, 120), outline=False, size=96)
glyph(U+"ui_counter_star_gold.png", "★", 96, 96, (240, 190, 30), outline=False, size=96)
# заглушка «Домой» (сцена 10): закрытая дверца с замочком и звёздочками, без букв
p = out(U + "ui_door_locked.png")
if p:
    im, d = blank(600, 800)
    d.rounded_rectangle((90, 120, 510, 780), radius=40, fill=(170, 120, 75, 255), outline=(90, 60, 35, 255), width=12)
    d.pieslice((90, 40, 510, 300), 180, 360, fill=(170, 120, 75, 255), outline=(90, 60, 35, 255), width=12)
    for y in (240, 470):
        d.rounded_rectangle((140, y, 460, y + 190), radius=20, outline=(120, 80, 45, 255), width=8)
    d.arc((260, 400, 340, 480), 180, 360, fill=(120, 120, 120, 255), width=14)          # дужка замочка
    d.rounded_rectangle((245, 440, 355, 540), radius=14, fill=MUSTARD + (255,), outline=(120, 90, 20, 255), width=6)
    d.ellipse((290, 470, 310, 490), fill=(60, 40, 20, 255))
    for (x, y, r) in [(60, 90, 34), (545, 140, 28), (40, 520, 24), (560, 600, 34), (300, 20, 22)]:
        d.polygon([(x + (r if k % 2 == 0 else r * 0.42) * __import__("math").sin(k * 3.14159 / 5),
                    y - (r if k % 2 == 0 else r * 0.42) * __import__("math").cos(k * 3.14159 / 5)) for k in range(10)], fill=(240, 190, 30, 255))
    im.save(p, optimize=True)
# значок «для взрослого» (сцена 10, долгое нажатие ≈2 с): коричневый круг, кремовые силуэты взрослого и ребёнка; без текста, без синего/зелёного
p = out(U + "ui_parent_info.png")
if p:
    im, d = blank(160, 160)
    d.ellipse((4, 4, 156, 156), fill=(138, 106, 74, 255), outline=(90, 66, 44, 255), width=6)
    cr = (247, 240, 222, 255)
    d.ellipse((46, 30, 78, 62), fill=cr); d.rounded_rectangle((38, 66, 86, 128), radius=18, fill=cr)     # взрослый
    d.ellipse((92, 58, 116, 82), fill=cr); d.rounded_rectangle((86, 86, 122, 128), radius=14, fill=cr)   # ребёнок
    im.save(p, optimize=True)
# плоский матовый кружок-звук (ревью методиста, 21.10.2026): ровно #D93A2B, без блика, объёма, тени и тёмного контура;
# тонкая белая обводка. Сцена 3 (окошки паровозика) и карточка 9.1. Временный файл — финальный рисует иллюстратор.
p = out(U + "ui_circle_flat.png")
if p:
    im, d = blank(392, 392)
    d.ellipse((6, 6, 386, 386), fill=(255, 255, 255, 255))
    d.ellipse((16, 16, 376, 376), fill=RED + (255,))
    im.save(p, optimize=True)
# 3 дуги-волны справа от кружка (карточка 9.1), #BDB6A8, без кружка
p = out(U + "ui_sound_waves.png")
if p:
    im, d = blank(160, 280)
    for i, r in enumerate((50, 90, 130)):
        d.arc((-r + 10, 140 - r, r + 10, 140 + r), -48, 48, fill=(189, 182, 168, 255), width=16)
    im.save(p, optimize=True)
# дорожка-паровозик (сцена 3): паровоз = начало, средний вагон = середина, последний вагон = конец
def car(name, label, engine=False, last=False):
    p = out(U + name + ".png")
    if not p: return
    im, d = blank(168, 128)
    body = (150, 120, 90, 255) if engine else (240, 200, 90, 255)   # не синий/зелёный (согласные), не красный (гласные)
    d.rounded_rectangle((8, 24, 160, 100), radius=14, fill=body, outline=(60, 60, 60, 255), width=5)
    if engine:
        d.rectangle((28, 4, 58, 30), fill=(60, 60, 60, 255))          # труба спереди: паровоз смотрит носом ВЛЕВО
    for x in (40, 128):
        d.ellipse((x - 16, 88, x + 16, 120), fill=(60, 60, 60, 255))
    # подпись — только в заглушке (для художника); на финальной картинке слов нет
    ctext(d, (8, 24, 160, 100), label, font(22), (40, 40, 40, 255))
    im.save(p)
car("ui_train_engine", "начало", engine=True)
car("ui_train_mid", "середина")
car("ui_train_end", "конец", last=True)
p = out("core/boot_splash.png")
if p:
    im = Image.new("RGB", (1024, 768), (255, 236, 205)); d = ImageDraw.Draw(im)
    ctext(d, (0, 250, 1024, 420), "Урок «А»", font(80), RED)
    ctext(d, (0, 420, 1024, 520), "загружается… (первый раз ~10 МБ)", font(30, False), (90, 90, 90))
    im.save(p, optimize=True)

# ---------- награды: res://art/common/reward/ ----------
R = "art_placeholder/common/reward/"
card(R+"reward_sticker_aist.png", "наклейка\nаист", 520, 520, (255, 255, 255), circle=True)
roundbtn(R+"reward_album.png", "★", (120, 90, 200), 200, "альбом")

# ---------- персонажи: res://art/characters/<имя>/ — слои во весь кадр (одинаковый размер холста) ----------
def layer(rel, w, h, draw):
    p = out(rel)
    if p:
        im, d = blank(w, h); draw(d); im.save(p)
A = "art_placeholder/characters/alya/"; W, H = 720, 960     # кадр 360×480 лог.
skin, hair = (255, 214, 180, 255), (120, 70, 40, 255)
layer(A+"body.png", W, H, lambda d: (d.polygon([(250, 470), (470, 470), (560, 900), (160, 900)], fill=(150, 120, 90, 255)),
                                     d.rectangle((270, 440, 450, 600), fill=(222, 170, 40, 255))))
layer(A+"arm_l.png", W, H, lambda d: d.rounded_rectangle((180, 460, 250, 720), radius=30, fill=(222, 170, 40, 255)))
layer(A+"arm_r.png", W, H, lambda d: d.rounded_rectangle((470, 460, 540, 720), radius=30, fill=(222, 170, 40, 255)))
layer(A+"head.png", W, H, lambda d: (d.ellipse((220, 90, 500, 380), fill=hair), d.ellipse((240, 130, 480, 440), fill=skin),
                                     d.rectangle((230, 100, 490, 190), fill=hair)))
layer(A+"eyes_open.png", W, H, lambda d: [d.ellipse((x-18, 262, x+18, 298), fill=(40, 40, 40, 255)) for x in (310, 410)])
layer(A+"eyes_closed.png", W, H, lambda d: [d.line([(x-20, 282), (x+20, 282)], fill=(40, 40, 40, 255), width=6) for x in (310, 410)])
layer(A+"mouth_0.png", W, H, lambda d: d.line([(335, 370), (385, 370)], fill=(170, 50, 50, 255), width=8))
layer(A+"mouth_1.png", W, H, lambda d: d.ellipse((335, 352, 385, 388), fill=(170, 50, 50, 255)))
layer(A+"mouth_2.png", W, H, lambda d: d.ellipse((325, 338, 395, 410), fill=(150, 30, 40, 255)))
p = out(A+"alya_ref.png")
if p:
    im = Image.new("RGBA", (W, H), (255, 255, 255, 255))
    for n in ["body", "arm_l", "arm_r", "head", "eyes_open", "mouth_1"]:
        im.alpha_composite(Image.open(os.path.join(ROOT, A+n+".png")))
    d = ImageDraw.Draw(im); ctext(d, (0, 900, W, 950), "alya_ref.png — Аля (референс, заглушка)", font(26, False), (60, 60, 60, 255)); im.save(p)
B = "art_placeholder/characters/bunny/"; BW = BH = 400       # кадр 200×200 лог.
layer(B+"body.png", BW, BH, lambda d: (d.ellipse((90, 170, 310, 390), fill=(240, 228, 200, 255)),
                                       d.ellipse((120, 60, 280, 230), fill=(215, 215, 225, 255)),
                                       d.ellipse((130, 0, 175, 120), fill=(215, 215, 225, 255)), d.ellipse((225, 0, 270, 120), fill=(215, 215, 225, 255))))
layer(B+"eyes_open.png", BW, BH, lambda d: [d.ellipse((x-10, 130, x+10, 150), fill=(40, 40, 40, 255)) for x in (170, 230)])
layer(B+"eyes_closed.png", BW, BH, lambda d: [d.line([(x-12, 142), (x+12, 142)], fill=(40, 40, 40, 255), width=5) for x in (170, 230)])
p = out(B+"bunny_ref.png")
if p:
    im = Image.new("RGBA", (BW, BH), (255, 255, 255, 255))
    for n in ["body", "eyes_open"]: im.alpha_composite(Image.open(os.path.join(ROOT, B+n+".png")))
    im.save(p)

# ---------- звук: res://audio/lesson_a/<id>.ogg, res://audio/common/<id>.ogg ----------
def tone(rel, dur, freq, voice=True):
    p = out(rel)
    if not p: return
    af = (f"sine=f={freq}:d={dur}:r=22050,vibrato=f=5:d=0.4,volume=0.25,afade=t=in:d=0.05,afade=t=out:st={max(0, dur-0.15)}:d=0.15" if voice
          else f"sine=f={freq}:d={dur}:r=22050,volume=0.3,afade=t=out:st={max(0, dur-0.1)}:d=0.1")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "lavfi", "-i", af, "-ac", "1", "-ar", "22050", "-c:a", "libvorbis", "-q:a", "2", p], check=True)
for id_, v in json.load(open(os.path.join(ROOT, "data/lesson_a/lines.json"))).items():
    tone(f"audio_placeholder/lesson_a/{id_}.ogg", v["dur"], 520 if id_ == "a_sing_loop" else 330)
for id_, v in json.load(open(os.path.join(ROOT, "data/common/lines.json"))).items():
    tone(f"audio_placeholder/common/{id_}.ogg", v["dur"], 392 if id_.startswith("p_") else 262)
for id_, f, dur in [("sfx_start", 660, 0.4), ("sfx_ok", 880, 0.25), ("sfx_try", 200, 0.3), ("sfx_pop", 1200, 0.12),
                    ("sfx_cheer", 990, 0.8), ("sfx_whoosh", 500, 0.2), ("sfx_snore", 120, 1.0)]:
    tone(f"audio_placeholder/common/{id_}.ogg", dur, f, voice=False)
print("готово")
