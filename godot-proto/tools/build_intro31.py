#!/usr/bin/env python3
"""Собирает data/lesson_<id>/ для 31 короткого урока из docs/intro31-scripts.txt.

Тексты реплик берутся только из листа записи (раздел 5). Экраны — из разделов букв.
Свои формулировки не добавляются. Аудиофайлы не создаются.
"""
from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "docs" / "intro31-scripts.txt"
DATA = ROOT / "godot-proto" / "data"
MANIFEST = ROOT / "docs" / "intro31-recording-manifest.md"

# Прогрессия методиста, без А и У (они уже отдельные уроки).
ORDER = [
    ("М", "m"), ("Х", "h"), ("О", "o"), ("Ш", "sh"), ("Р", "r"), ("С", "s"), ("Ы", "y"),
    ("Л", "l"), ("Н", "n"), ("К", "k"), ("П", "p"), ("Т", "t"), ("В", "v"), ("З", "z"),
    ("Ж", "zh"), ("Ь", "soft"), ("И", "i"), ("Е", "e"), ("Д", "d"), ("Б", "b"), ("Г", "g"),
    ("Й", "j"), ("Ч", "ch"), ("Э", "eh"), ("Ё", "yo"), ("Я", "ya"), ("Ю", "yu"), ("Ц", "ts"),
    ("Щ", "sch"), ("Ф", "f"), ("Ъ", "hard"),
]
STUDIED_BEFORE = list("АУ")
VOWELS = set("АЕЁИОУЫЭЮЯаеёиоуыэюя")
SIGNS = set("ЬЪьъ")
ACUTE = "\u0301"


def norm(s: str) -> str:
    return s.replace(ACUTE, "").replace(".", "").replace("!", "").replace("?", "").strip().lower()


def quotes(s: str) -> list[str]:
    return re.findall(r"«([^»]+)»", s)


def letters_of(s: str) -> list[str]:
    out = []
    for ch in s.replace(ACUTE, ""):
        if ch.isalpha() or ch in "ёЁ":
            out.append(ch.upper())
    return out


def dur_of(text: str) -> float:
    return round(max(0.8, min(6.0, len(text) * 0.055)), 2)


def parse_lines(text: str) -> dict[str, dict]:
    lines = {}
    for raw in text.splitlines():
        m = re.match(r"^([a-z][a-z0-9_]*) — «(.*)»(?: — (.*))?$", raw)
        if not m:
            continue
        lines[m.group(1)] = {"text": m.group(2), "note": (m.group(3) or "").strip()}
    return lines


def parse_letters(text: str) -> dict[str, str]:
    body = text.split("4. Открытые решения")[0]
    parts = re.split(r"\n(?=\d+\. Буква )", body)
    found = {}
    for p in parts:
        m = re.match(r"\d+\. Буква (\S+)", p)
        if not m:
            continue
        found[m.group(1)] = p
    return found


def screen_of(scene_body: str) -> str:
    m = re.search(r"Экран: (.+)", scene_body)
    if not m:
        raise SystemExit("нет строки Экран")
    return m.group(1).strip()


def scenes_of(block: str) -> dict[str, str]:
    parts = re.split(r"\nСцена (\d)\n", block)
    out = {}
    i = 1
    while i + 1 < len(parts):
        out[parts[i]] = parts[i + 1]
        i += 2
    return out


def blend_map(lines: dict, lid: str) -> dict[str, str]:
    out = {}
    for key in (f"{lid}_analysis_model", f"{lid}_blend_01", f"{lid}_blend_02",
                f"{lid}_hard_model", f"{lid}_start_1", f"{lid}_start_2",
                f"{lid}_word_model", f"{lid}_answer"):
        if key in lines:
            out[norm(lines[key]["text"])] = key
    for key, row in lines.items():
        if key.startswith(f"{lid}_model_"):
            out[norm(row["text"])] = key
    return out


def card_audio(bmap: dict, text: str, lid: str) -> str:
    key = norm(text)
    if key not in bmap:
        raise SystemExit(f"{lid}: нет аудио для карточки «{text}» среди {sorted(bmap)}")
    return bmap[key]


def build_scene(lid: str, n: str, body: str, lines: dict, bmap: dict) -> dict:
    screen = screen_of(body)
    line = f"{lid}_s{n}"
    if line not in lines:
        raise SystemExit(f"нет реплики {line}")
    if n == "1":
        motif = re.search(r"Один носитель: ([^;]+);", screen)
        if not motif:
            raise SystemExit(f"{lid} s1: нет носителя")
        return {"kind": "meet", "line": line, "tap": f"{lid}_tap", "carrier": f"{lid}_carrier",
                "motif": motif.group(1).strip(), "screen": screen}
    if n == "2" and "нужная позиция" in screen:
        slots = int(re.search(r"(\d) одинаковые", screen).group(1))
        correct = int(re.search(r"нужная позиция — (\d)", screen).group(1))
        return {"kind": "locate", "line": line, "model": f"{lid}_analysis_model",
                "slots": slots, "correct": correct, "screen": screen}
    if n == "2" and "две однотонные кнопки" in screen:
        return {"kind": "two_dots", "line": line, "ears": [f"{lid}_start_1", f"{lid}_start_2"],
                "rest_after": True, "screen": screen}
    if n == "2" and lid == "soft":
        return {"kind": "soft_hear", "line": line, "model": "soft_analysis_model",
                "slots": 3, "correct": 3, "motif": "конь", "screen": screen}
    if n == "2" and lid == "hard":
        return {"kind": "hard_pair", "line": line, "screen": screen,
                "cards": [
                    {"text": "сел", "audio": "hard_model_sel", "motif": "кот сидит"},
                    {"text": "съел", "audio": "hard_model_syel", "motif": "кот ест"},
                ], "correct": "съел"}
    if n == "3" and screen.startswith("Крупно"):
        head = screen.split(";")[0]
        texts = quotes(head)
        if not texts:
            raise SystemExit(f"{lid} s3: нет слогов")
        cards = [{"text": t, "audio": card_audio(bmap, t, lid)} for t in texts]
        return {"kind": "trace", "line": line, "cards": cards, "screen": screen}
    if n == "3" and "дорожка только под" in screen:
        target = re.search(r"дорожка только под (\S+)", screen).group(1).strip(".,")
        texts = quotes(screen)
        # первые две кавычки — карточки
        pair = texts[:2]
        if len(pair) != 2:
            raise SystemExit(f"{lid} s3: карточки {texts}")
        cards = []
        for t in pair:
            cards.append({"text": t, "audio": card_audio(bmap, t, lid), "track": norm(t) == norm(target)})
        if sum(1 for c in cards if c["track"]) != 1:
            raise SystemExit(f"{lid} s3: цель «{target}» не на карточке")
        return {"kind": "choose_trace", "line": line, "cards": cards, "screen": screen}
    if n == "3" and lid == "soft":
        return {"kind": "soft_sign", "line": line, "word": "конь", "options": ["ь", "а"],
                "correct": "ь", "model": "soft_word_model", "screen": screen}
    if n == "3" and lid == "hard":
        return {"kind": "hard_compare", "line": line, "screen": screen,
                "cards": [
                    {"text": "лю", "audio": "hard_model_lyu", "motif": ""},
                    {"text": "лью", "audio": "hard_model_lyyu", "motif": "ребёнок с лейкой", "dots": 3},
                ], "correct": "лью"}
    if n == "4" and "неподписанные картинки" in screen:
        qs = quotes(screen)
        word = qs[0]
        tail = screen.split("картинки:", 1)[1]
        left, right = [x.strip() for x in tail.split("/", 1)]
        right = right.split(".")[0].strip()
        return {"kind": "picture", "line": line, "word": word, "answer": f"{lid}_answer",
                "choices": [{"seed": left}, {"seed": right}], "screen": screen}
    if n == "4" and "текстовые карточки" in screen:
        qs = quotes(screen)
        if len(qs) < 2:
            raise SystemExit(f"{lid} s4 text: {qs}")
        return {"kind": "text", "line": line, "answer": f"{lid}_answer",
                "choices": qs[:2], "screen": screen}
    if n == "4" and lid == "hard":
        return {"kind": "hard_sign", "line": line, "word": "съел", "model": "hard_model_syel",
                "choices": ["ъ", "е"], "correct": "ъ", "screen": screen}
    raise SystemExit(f"не разобран экран {lid} s{n}: {screen[:160]}")


def check_print(lid: str, ch: str, scene: dict, studied: set[str]) -> None:
    blobs = []
    kind = scene["kind"]
    if kind == "trace":
        blobs += [c["text"] for c in scene["cards"]]
    elif kind == "choose_trace":
        blobs += [c["text"] for c in scene["cards"]]
    elif kind == "picture":
        blobs.append(scene["word"])
    elif kind == "text":
        blobs += scene["choices"]
    elif kind == "soft_sign":
        blobs.append(scene["word"])
        blobs += scene["options"]
    elif kind in ("hard_pair", "hard_compare"):
        blobs += [c["text"] for c in scene["cards"]]
    elif kind == "hard_sign":
        blobs.append(scene["word"])
        blobs += scene["choices"]
    allowed = studied | {ch.upper()}
    for b in blobs:
        bad = [c for c in letters_of(b) if c not in allowed and c.upper() not in allowed]
        # letters_of already upper
        bad = [c for c in letters_of(b) if c not in allowed]
        if bad:
            raise SystemExit(f"{lid}: «{b}» содержит ещё не изученные {bad} при изученных {sorted(allowed)}")


def main() -> None:
    text = SRC.read_text(encoding="utf-8")
    lines = parse_lines(text)
    blocks = parse_letters(text)
    if len(lines) < 200:
        raise SystemExit(f"мало реплик: {len(lines)}")
    studied = set(STUDIED_BEFORE)
    used_ids: set[str] = set()
    for ch, lid in ORDER:
        if ch not in blocks:
            raise SystemExit(f"в источнике нет буквы {ch}")
        sc_bodies = scenes_of(blocks[ch])
        if list(sc_bodies) != ["1", "2", "3", "4"]:
            raise SystemExit(f"{ch}: сцены {list(sc_bodies)}")
        bmap = blend_map(lines, lid)
        scenes = [build_scene(lid, n, sc_bodies[n], lines, bmap) for n in "1234"]
        for sc in scenes:
            check_print(lid, ch, sc, studied)
            for key in ("line", "tap", "carrier", "model", "answer"):
                if key in sc:
                    used_ids.add(sc[key])
            for ear in sc.get("ears", []):
                used_ids.add(ear)
            for card in sc.get("cards", []):
                used_ids.add(card["audio"])
        for needle in (f"{lid}_s1", f"{lid}_s2", f"{lid}_s3", f"{lid}_s4", f"{lid}_tap", f"{lid}_carrier"):
            if needle not in lines:
                raise SystemExit(f"нет {needle}")
            used_ids.add(needle)
        big = ch
        small = ch.lower()
        lesson = {
            "id": lid,
            "title": f"Буква {ch}",
            "big": big,
            "small": small,
            "steps": ["intro_s1", "intro_s2", "intro_s3", "intro_s4"],
            "intro": {
                "letter": ch,
                "vowel": ch.upper() in VOWELS,
                "sign": ch in "ЬЪ",
                "art": "draft_placeholder",
                "scenes": scenes,
            },
        }
        folder = DATA / f"lesson_{lid}"
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "lesson.json").write_text(json.dumps(lesson, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        letter_lines = {}
        for iid, row in lines.items():
            if iid.startswith(lid + "_"):
                letter_lines[iid] = {"text": row["text"], "tone": row["note"], "dur": dur_of(row["text"])}
                used_ids.add(iid)
        (folder / "lines.json").write_text(json.dumps(letter_lines, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        studied.add(ch.upper())

    common = {}
    for iid, row in lines.items():
        if iid.startswith("c_"):
            common[iid] = {"text": row["text"], "tone": row["note"], "dur": dur_of(row["text"])}
            used_ids.add(iid)
    (DATA / "common" / "intro_lines.json").write_text(
        json.dumps(common, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    missing = sorted(set(lines) - used_ids)
    extra = sorted(used_ids - set(lines))
    if extra:
        raise SystemExit(f"использованы неизвестные id: {extra}")

    by_text: dict[str, list[str]] = defaultdict(list)
    for iid, row in lines.items():
        by_text[row["text"]].append(iid)
    unique = len(by_text)
    parts = [
        "# Лист записи коротких уроков",
        "",
        "Источник текстов — `docs/intro31-scripts.txt` (раздел 5), копия приложенного сценария.",
        "Файлы звука в репозиторий не кладутся и не синтезируются: каждую уникальную фразу записывает пользователь.",
        "Одинаковый текст пишется один раз; в таблице перечислены все id, которые на него ссылаются.",
        "Скобки `[ ]` в тексте — пометка диктору, вслух не читаются. Ударения оставлены как в сценарии.",
        "",
        f"Сценарных id: {len(lines)}. Уникальных текстов: {unique}.",
        f"Id без ссылки из сцен (всё равно в листе, их тоже записать, если текст ещё не покрыт): {len(missing)}.",
        "",
    ]
    if missing:
        parts.append("Не привязаны к полю сцены напрямую (остаются в lines.json буквы): " + ", ".join(missing) + ".")
        parts.append("")
    parts.append("| Текст | Id | Пометка диктору |")
    parts.append("| --- | --- | --- |")
    for text_key, ids in sorted(by_text.items(), key=lambda kv: kv[1][0]):
        notes = []
        for iid in ids:
            note = lines[iid]["note"]
            if note and note not in notes:
                notes.append(note)
        esc = text_key.replace("|", "\\|")
        parts.append(f"| {esc} | {', '.join(ids)} | {'; '.join(notes).replace('|', '\\|')} |")
    parts.append("")
    MANIFEST.write_text("\n".join(parts), encoding="utf-8")
    print(f"letters {len(ORDER)}  ids {len(lines)}  unique {unique}  unreferenced {len(missing)}")


if __name__ == "__main__":
    try:
        main()
    except SystemExit as e:
        print(e, file=sys.stderr)
        sys.exit(1)
