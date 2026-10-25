## Assets (autoload): данные урока и поиск ассетов ПО СОГЛАШЕНИЮ С ХУДОЖНИКОМ (ASSETS.md).
## Имя → путь:
##   pic_*            → res://art/lesson_<буква>/pic_*.png        (кадры: pic_<id>_f1/_f2)
##   s<N>_*           → res://art/lesson_<буква>/s<N>_*.png       (картинки одной сцены: s8_basket_big_A_0 …)
##   bg_*             → res://art/common/bg/bg_*.png
##   ui_*             → res://art/common/ui/ui_*.png
##   reward_*         → res://art/common/reward/reward_*.png
##   letter_*, tile_*, balloon_letter_*, balloon_shape_* → res://art/letters/*.png
##   "<персонаж>/<слой>" → res://art/characters/<персонаж>/<слой>.png   (alya/head, bunny/body …)
##   звук <id>        → res://audio/lesson_<буква>/<id>.ogg, затем res://audio/common/<id>.ogg
## Вся графика сдаётся в 2× — в коде размеры задаются в логических единицах (ART_SCALE = 0.5).
## Порядок поиска (уровни): res://art/… (настоящая графика художника) → res://art_provisional/… (утверждённые эскизы стиля,
## временно) → res://art_placeholder/… (заглушки). Путь внутри уровня одинаковый, поэтому файл художника просто кладётся в art/.
## Звук так же: res://audio/… → res://audio_placeholder/….
extends Node

## Красный гласных — ровно #D93A2B (единый для всех материалов).
const VOWEL_RED := Color("#D93A2B")
## Решения методиста 21.10.2026: кнопки «Начнём!», «Далее», галочка взрослого — горчичные; точка старта — коралловая.
## Зелёный — только мягкие согласные, синий — только твёрдые: в кнопках, одежде и крупных предметах не используются.
const MUSTARD := Color("#E2B42E")
const CORAL := Color("#E07A4E")
## Экран букв (menu/letters_menu): согласные — синие (только буквы, не кнопки), ь/ъ — тёмные, подложки — кремовые.
const CONSONANT_BLUE := Color("#2F6DB5")
const DARK := Color("#3C3228")
const CREAM := Color("#F7F0DE")
const VOWELS := "аеёиоуыэюя"
const SETTINGS_PATH := "user://settings.json"
## Настройки для взрослого (сохраняются на устройстве). junior — младший режим для 4 лет (допуск ±60 px в сцене 6).
## С 26.10.2026 выбора режима в уроке нет: junior всегда false (обычный допуск); сохранённое когда-то значение
## игнорируется, включить можно только параметром ?junior=1 (для отладки, путь в коде оставлен «спящим»).
var settings: Dictionary = {"junior": false}

const ART_SCALE := 0.5
var letter_id := "a"
var lesson: Dictionary = {}
var lines: Dictionary = {}
var params: Dictionary = {}

const TRANSLIT := {"а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "yo", "ж": "zh", "з": "z", "и": "i",
	"й": "y", "к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u",
	"ф": "f", "х": "h", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "sch", "ы": "y", "э": "e", "ю": "yu", "я": "ya"}

func _ready() -> void:
	_read_params()
	_load_settings()
	letter_id = String(params.get("letter", "a")).validate_filename()
	lesson = _load_json("res://data/lesson_%s/lesson.json" % letter_id)
	lines = _load_json("res://data/common/lines.json")
	lines.merge(_load_json("res://data/lesson_%s/lines.json" % letter_id), true)

func _read_params() -> void:
	if not OS.has_feature("web"):
		for a in OS.get_cmdline_user_args():
			var kv := a.split("=")
			params[kv[0]] = kv[1] if kv.size() > 1 else "1"
		return
	var q = JavaScriptBridge.eval("location.search", true)
	if typeof(q) != TYPE_STRING:
		return
	for part in String(q).trim_prefix("?").split("&", false):
		var kv := part.split("=")
		params[kv[0].uri_decode()] = kv[1].uri_decode() if kv.size() > 1 else "1"

func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if typeof(d) == TYPE_DICTIONARY:
			settings.merge(d, true)
	settings["junior"] = flag("junior") if params.has("junior") else false

func set_setting(key: String, value) -> void:
	settings[key] = value
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))

func flag(name: String) -> bool:
	return String(params.get(name, "0")) in ["1", "true", "yes"]

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("нет файла " + path)
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}

const ART_TIERS := ["res://art/", "res://art_provisional/", "res://art_placeholder/"]

## Путь внутри уровня по соглашению с художником.
func art_rel(name: String) -> String:
	if name.contains("/"):
		return "characters/" + name + ".png"
	if name.begins_with("pic_") or (name.length() > 2 and name[0] == "s" and name[1].is_valid_int()):
		# pic_* и картинки отдельных сцен урока s<N>_* (напр. s8_basket_big_A_0) — в папке урока
		return "lesson_%s/%s.png" % [letter_id, name]
	if name.begins_with("bg_"):
		return "common/bg/" + name + ".png"
	if name.begins_with("ui_"):
		return "common/ui/" + name + ".png"
	if name.begins_with("reward_"):
		return "common/reward/" + name + ".png"
	if name.begins_with("letter_") or name.begins_with("tile_") or name.begins_with("balloon_"):
		return "letters/" + name + ".png"
	return "common/" + name + ".png"

## Уровень, на котором нашёлся файл: 0 — настоящий, 1 — эскиз, 2 — заглушка, -1 — нет.
func art_tier(name: String) -> int:
	var rel := art_rel(name)
	for i in ART_TIERS.size():
		if ResourceLoader.exists(ART_TIERS[i] + rel):
			return i
	return -1

func art_path(name: String) -> String:
	var t := art_tier(name)
	return ART_TIERS[t] + art_rel(name) if t >= 0 else ART_TIERS[0] + art_rel(name)

func tex(name: String, warn := true) -> Texture2D:
	var t := art_tier(name)
	if t >= 0:
		return load(ART_TIERS[t] + art_rel(name))
	if warn:
		push_warning("нет картинки " + art_rel(name))
	return null

## Логический размер картинки (исходник 2× → × 0.5).
func nat_size(t: Texture2D) -> Vector2:
	return t.get_size() * ART_SCALE if t else Vector2(100, 100)

## Имя файла буквы: kind = "letter" | "tile" | "balloon_letter"; "А" → letter_a_upper, "а" → letter_a_lower.
func letter_name(kind: String, ch: String) -> String:
	var low := ch.to_lower()
	return "%s_%s_%s" % [kind, TRANSLIT.get(low, low), "lower" if ch == low else "upper"]

func sound(id: String) -> AudioStream:
	for p in ["res://audio/lesson_%s/%s.ogg" % [letter_id, id], "res://audio/common/%s.ogg" % id,
			"res://audio_placeholder/lesson_%s/%s.ogg" % [letter_id, id], "res://audio_placeholder/common/%s.ogg" % id]:
		if ResourceLoader.exists(p):
			return load(p)
	return null

func line_text(id: String) -> String:
	return String(lines.get(id, {}).get("text", ""))

func line_dur(id: String) -> float:
	return float(lines.get(id, {}).get("dur", 1.0))
