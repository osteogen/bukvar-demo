#!/usr/bin/env python3
"""Временная (provisional) графика из утверждённых эскизов стиля ../art/sketches/ → res://art_provisional/.
Эскизы пока на кремовой подложке: подложку, связанную с краем кадра, делаем прозрачной (мягкий край).
Когда художник сдаст прозрачные PNG 2×, их кладут в res://art/<тот же путь> — они автоматически
важнее provisional (порядок поиска: art/ → art_provisional/ → art_placeholder/). Эту папку тогда можно удалить.
Эскизы сделаны ИИ-генератором: только для прототипа и демо (см. ../art/licensing-notes.md)."""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SK = os.path.join(ROOT, "..", "art", "sketches")
# эскиз → путь по соглашению (относительно res://art_provisional/), обрезать ли по содержимому
# пороги: расстояние до цвета подложки < t_in — прозрачно, > t_out — непрозрачно; белые объекты требуют малых порогов;
# all_bg=True — убирать подложку и внутри замкнутых контуров (просвет буквы А)
MAP = [
    ("sketch_pic_aist.png", "lesson_a/pic_aist.png", False, None, None, False),   # белый аист ≈ цвет подложки: не вырезаем, оставляем кремовую карточку со скруглёнными углами
    ("sketch_pic_aist.png", "common/reward/reward_sticker_aist.png", False, None, None, False),   # наклейка-аист в сцене 10 — тот же эскиз
    ("sketch_letter_a_upper_red.png", "letters/letter_a_upper.png", True, 10.0, 20.0, True),
    ("sketch_alya_fullbody.png", "characters/alya/alya_ref.png", False, 30.0, 56.0, False),
    ("sketch_alya_fullbody.png", "lesson_a/pic_alya_card.png", "card", None, None, False),   # портрет-карточка: верх эскиза в кремовой рамке
]

def key(im, T_IN, T_OUT, all_bg):
    rgb = np.asarray(im.convert("RGB")).astype(np.float32)
    h, w, _ = rgb.shape
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bgc = np.median(border, axis=0)
    dist = np.sqrt(((rgb - bgc) ** 2).sum(axis=2))
    near = Image.fromarray(((dist < T_OUT) * 255).astype(np.uint8)).copy()
    for x, y in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2)]:
        if near.getpixel((x, y)) == 255:
            ImageDraw.floodfill(near, (x, y), 128)
    region = np.asarray(near) == 128                      # подложка, связанная с краем
    if all_bg:
        region = dist < T_OUT
    alpha = np.ones((h, w), np.float32)
    soft = np.clip((dist - T_IN) / (T_OUT - T_IN), 0, 1)
    alpha[region] = soft[region]
    a = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
    out = im.convert("RGBA")
    out.putalpha(a)
    return out

def recolor_red_to_mustard(im):
    """Временная перекраска красной кофточки Али в горчичную (правило: красный — только гласные и звуковой маркер).
    Насыщенные красные пиксели → горчичный тон; щёки и губы (менее насыщенные) почти не задеваются."""
    a = np.asarray(im.convert("RGBA")).astype(np.float32) / 255.0
    rgb = a[..., :3]
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    red = (r == mx) & (sat > 0.5) & (mx > 0.3) & (g < r * 0.55) & (b < r * 0.55)
    lum = 0.6 * r + 0.3 * g + 0.1 * b
    mustard = np.stack([lum * 1.55, lum * 1.18, lum * 0.35], axis=-1)
    rgb2 = np.where(red[..., None], np.clip(mustard, 0, 1), rgb)
    out = np.concatenate([rgb2, a[..., 3:]], axis=2)
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")

def recolor_blue(im):
    """Синий — только твёрдые согласные: синий сарафан Али → тёмно-бежевый, голубое одеяльце зайки → кремовое, зелёные носочки → бежевые
    (временная перекраска эскиза до финальной графики)."""
    a = np.asarray(im.convert("RGBA")).astype(np.float32) / 255.0
    rgb = a[..., :3]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    blue = (b >= r + 0.01) & (sat > 0.04) & (b >= g - 0.02)                  # холодные/голубые тона
    green = (g > r + 0.05) & (sat > 0.1)                                     # зелёные носочки → бежевые
    blue = blue | green
    lum = 0.3 * r + 0.5 * g + 0.2 * b
    light = lum > 0.68
    beige = np.stack([lum * 1.25, lum * 1.0, lum * 0.72], axis=-1)        # тёмно-бежевый сарафан
    cream = np.stack([lum * 1.08, lum * 1.02, lum * 0.86], axis=-1)       # кремовое одеяльце
    new = np.where(light[..., None], cream, beige)
    rgb2 = np.where(blue[..., None], np.clip(new, 0, 1), rgb)
    return Image.fromarray((np.concatenate([rgb2, a[..., 3:]], axis=2) * 255).astype(np.uint8), "RGBA")

def to_vowel_red(im):
    """Красный гласных — ровно #D93A2B: насыщенные красные пиксели буквы приводятся к этому тону
    (сплошная заливка #D93A2B, тени/края — по яркости)."""
    a = np.asarray(im.convert("RGBA")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    red = (r > 120) & (g < r * 0.6) & (b < r * 0.6)
    target = np.array([217, 58, 43], np.float32)
    k = np.clip(r / 217.0, 0.0, 1.0)[..., None]
    k = np.where(k > 0.85, 1.0, k)
    a[..., :3] = np.where(red[..., None], target * k, a[..., :3])
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")

for src, dst, trim, t_in, t_out, all_bg in MAP:
    p = os.path.join(SK, src)
    if not os.path.exists(p):
        print("нет эскиза", src); continue
    if trim == "card":       # портрет по пояс: верхние ~55 % эскиза, квадрат
        src_im = Image.open(p).convert("RGBA")
        w0 = src_im.width
        top = int(src_im.height * 0.02)
        src_im = src_im.crop((0, top, w0, top + w0))
        im = src_im
        m = Image.new("L", im.size, 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, im.width - 1, im.height - 1), radius=im.width // 12, fill=255)
        im.putalpha(m)
        frame = ImageDraw.Draw(im)
        frame.rounded_rectangle((4, 4, im.width - 5, im.height - 5), radius=im.width // 12, outline=(150, 120, 80, 255), width=10)
        trim = False
    elif t_in is None:
        im = Image.open(p).convert("RGBA")
        m = Image.new("L", im.size, 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, im.width - 1, im.height - 1), radius=im.width // 12, fill=255)
        im.putalpha(m)
    else:
        im = key(Image.open(p), t_in, t_out, all_bg)
    if trim:
        bb = im.getchannel("A").filter(ImageFilter.MedianFilter(7)).point(lambda v: 255 if v > 160 else 0).getbbox()
        if bb:
            pad = int(max(im.size) * 0.03)
            im = im.crop((max(0, bb[0] - pad), max(0, bb[1] - pad), min(im.width, bb[2] + pad), min(im.height, bb[3] + pad)))
    if "letter_a" in src:
        im = to_vowel_red(im)
    if "alya" in src:
        im = recolor_red_to_mustard(im)
        im = recolor_blue(im)
    o = os.path.join(ROOT, "art_provisional", dst)
    os.makedirs(os.path.dirname(o), exist_ok=True)
    im.save(o, optimize=True)
    print(src, "→ art_provisional/" + dst, im.size)

# ---------- стиль v2 (утверждён пользователем 21.10.2026): ../art/sketches/v2/ ----------
# Прозрачные PNG 2×: кладём поверх v1 (тот же путь в art_provisional/). Паровоз смотрит НОСОМ ВЛЕВО
# (труба и фонарь слева): ui_train_engine.png v2 уже так нарисован — отражать не нужно.
V2 = os.path.join(SK, "v2")
V2_MAP = [
    ("pic_host_alya.png", "characters/alya/alya_ref.png", "copy"),
    ("pic_host_alya.png", "lesson_a/pic_alya_card.png", "card"),
    ("pic_aist.png", "lesson_a/pic_aist.png", "copy"),
    ("pic_aist.png", "common/reward/reward_sticker_aist.png", "copy"),
    ("bg_meadow_v2.png", "common/bg/bg_meadow.png", "copy"),
    ("ui_train_engine.png", "common/ui/ui_train_engine.png", "copy"),
    ("ui_train_mid.png", "common/ui/ui_train_mid.png", "copy"),
    ("ui_train_end.png", "common/ui/ui_train_end.png", "copy"),
    ("ui_btn_start.png", "common/ui/ui_btn_start.png", "copy"),
    ("ui_btn_next.png", "common/ui/ui_btn_next.png", "copy"),
    ("ui_btn_back.png", "common/ui/ui_btn_back.png", "copy"),
]
if os.path.isdir(V2):
    for src, dst, mode in V2_MAP:
        p = os.path.join(V2, src)
        if not os.path.exists(p):
            print("нет эскиза v2", src); continue
        im = Image.open(p).convert("RGBA")
        if mode == "flip":
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        elif mode == "card":   # портрет по грудь в кремовой карточке с коричневой рамкой, 800×800 (2×)
            w0 = im.width
            bust = im.crop((0, 0, w0, w0)).resize((680, 680), Image.LANCZOS)
            card = Image.new("RGBA", (800, 800), (0, 0, 0, 0))
            d = ImageDraw.Draw(card)
            d.rounded_rectangle((4, 4, 795, 795), radius=64, fill=(246, 236, 214, 255), outline=(135, 88, 51, 255), width=12)
            card.alpha_composite(bust, (60, 80))
            m = Image.new("L", card.size, 0)
            ImageDraw.Draw(m).rounded_rectangle((16, 16, 783, 783), radius=56, fill=255)
            inner = Image.composite(card, Image.new("RGBA", card.size, (0, 0, 0, 0)), m)
            d2 = ImageDraw.Draw(inner)
            d2.rounded_rectangle((4, 4, 795, 795), radius=64, outline=(135, 88, 51, 255), width=12)
            im = inner
        o = os.path.join(ROOT, "art_provisional", dst)
        os.makedirs(os.path.dirname(o), exist_ok=True)
        im.save(o, optimize=True)
        print("v2", src, "→ art_provisional/" + dst, im.size, mode)
