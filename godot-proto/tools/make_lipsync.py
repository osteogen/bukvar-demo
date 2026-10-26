#!/usr/bin/env python3
"""Огибающие громкости реплик для губ персонажей → data/common/lipsync.json.

Для каждой реплики (ogg в audio/lesson_*/, audio/common/, затем audio_placeholder/… — тот же порядок, что Assets.sound)
считаем RMS кадрами по 1/30 с и кодируем строкой цифр 0…9 (0 — тишина, 9 — громко; нормировка по 95-му перцентилю файла).
Voice.mouth_level() читает цифру по времени от начала реплики, Cutout.mouth_frame() переводит в кадр рта 0/1/2.
Эффекты (sfx_*) пропускаем. Перезапускать после каждой новой записи голоса:  python3 tools/make_lipsync.py
Формат: {"<id>": {"fps": 30, "env": "0013578…"}}. Позже художник/звукорежиссёр может добавить ключ "visemes"
(строка фонемных кадров) — ядро пока использует только env.
"""
import glob, json, os, subprocess
import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FPS = 30
SR = 16000


def envelope(path):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "s16le", "-"],
                         capture_output=True, check=True).stdout
    x = np.frombuffer(raw, np.int16).astype(np.float32) / 32768
    hop = SR // FPS
    n = len(x) // hop
    if n == 0:
        return ""
    rms = np.sqrt((x[: n * hop].reshape(n, hop) ** 2).mean(1))
    ref = max(np.percentile(rms, 95), 1e-4)
    lv = np.clip(rms / ref, 0, 1)
    lv[rms < 0.008] = 0
    return "".join(str(int(round(v * 9))) for v in lv)


def main():
    out = {}
    order = sorted(glob.glob(ROOT + "/audio/lesson_*/*.ogg")) + sorted(glob.glob(ROOT + "/audio/common/*.ogg")) + \
        sorted(glob.glob(ROOT + "/audio_placeholder/lesson_*/*.ogg")) + sorted(glob.glob(ROOT + "/audio_placeholder/common/*.ogg"))
    for p in order:
        i = os.path.splitext(os.path.basename(p))[0]
        if i.startswith("sfx_") or i in out:
            continue
        out[i] = {"fps": FPS, "env": envelope(p)}
    dst = ROOT + "/data/common/lipsync.json"
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=0, sort_keys=True)
        f.write("\n")
    print(dst, len(out), "реплик")


if __name__ == "__main__":
    main()
