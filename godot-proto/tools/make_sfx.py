#!/usr/bin/env python3
"""Синтез коротких эффектов урока (свой синтез, без чужих сэмплов — CC0 / public domain, автор: команда «Букваря»).

  sfx_click        — щелчок механической клавиатуры (нажатие кнопок интерфейса), ~90 мс;
  sfx_train_clack  — перестук колёс «та-дам, та-дам» (паровозик въезжает / уезжает), ~2,2 с.

Запуск:  python3 tools/make_sfx.py   → audio/common/<id>.ogg (нужен ffmpeg).
Звукорежиссёр может заменить файлы своими с тем же именем (уровень res://audio/ важнее заглушек).
"""
import os, subprocess, tempfile, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "common")
rng = np.random.default_rng(7)


def env(n, tau):
    t = np.arange(n) / SR
    return np.exp(-t / tau)


def bandnoise(n, lo, hi):
    x = rng.standard_normal(n)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    X[(f < lo) | (f > hi)] = 0
    y = np.fft.irfft(X, n)
    return y / (np.abs(y).max() + 1e-9)


def place(buf, sig, at):
    i = int(at * SR)
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[: j - i]


def click():
    n = int(0.09 * SR)
    b = np.zeros(n)
    # верхний «клик» переключателя
    k = int(0.012 * SR)
    place(b, bandnoise(k, 2500, 7000) * env(k, 0.0018) * 0.9, 0.0)
    # «тук» колпачка о дно (низкий, глухой)
    k2 = int(0.05 * SR)
    t = np.arange(k2) / SR
    thock = np.sin(2 * np.pi * 210 * t) * env(k2, 0.010) * 0.55 + bandnoise(k2, 300, 1800) * env(k2, 0.004) * 0.35
    place(b, thock, 0.004)
    # лёгкий отскок
    k3 = int(0.01 * SR)
    place(b, bandnoise(k3, 3000, 8000) * env(k3, 0.0015) * 0.25, 0.032)
    return b * 0.8


def clack_hit(amp=1.0):
    k = int(0.12 * SR)
    t = np.arange(k) / SR
    metal = sum(np.sin(2 * np.pi * f * t + p) * a for f, a, p in ((870, .5, 0), (1390, .35, 1), (2270, .25, 2), (3110, .12, 3)))
    hit = metal * env(k, 0.028) + bandnoise(k, 800, 6000) * env(k, 0.006) * 0.8 + np.sin(2 * np.pi * 85 * t) * env(k, 0.03) * 0.6
    return hit * amp


def train_clack():
    dur = 2.2
    b = np.zeros(int(dur * SR))
    t0 = 0.05
    while t0 < dur - 0.2:
        place(b, clack_hit(0.9), t0)
        place(b, clack_hit(0.75), t0 + 0.13)
        t0 += 0.52
    # мягкий «шум хода» и плавные края
    b += bandnoise(len(b), 150, 1200) * 0.05
    n = len(b)
    fade = np.minimum(1, np.minimum(np.arange(n) / (0.25 * SR), (n - np.arange(n)) / (0.5 * SR)))
    return b * fade * 0.55


def write_ogg(name, x):
    x = x / max(1.0, np.abs(x).max() / 0.89)
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    os.makedirs(OUT, exist_ok=True)
    dst = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5", dst], check=True)
    os.unlink(tmp)
    print(dst, round(len(x) / SR, 2), "s")


if __name__ == "__main__":
    write_ogg("sfx_click", click())
    write_ogg("sfx_train_clack", train_clack())
