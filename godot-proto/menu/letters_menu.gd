## ГЛАВНЫЙ экран (открывается при запуске): 33 кубика-буквы по алфавиту. Активна только «А» (тап — урок «А»:
## сразу s02; экрана-памятки s00 больше нет), остальные «закрыты» (приглушённые, без прозрачности), на тап покачиваются.
## Сюда ведут крестик (s01–s11) и «домой» в s11. Крестика здесь нет — это дом. Первое касание здесь включает звук (iOS Safari).
## Кубики — финальные файлы иллюстратора (палитра 2 «мягкая радуга», art/common/ui/ui_cube_dlya_koda.txt):
## слой ui_cube_tint (красится modulate цветом клетки) + поверх ui_cube_face (не красится) + буква на лицевой грани.
extends LessonStep

const ALPHABET := "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
const ACTIVE := "А"
const CUBE_COLORS := [
	Color("#F6B9C0"),  # 0 розовый
	Color("#F9CB9C"),  # 1 персик
	Color("#F6E08E"),  # 2 жёлтый
	Color("#CDE9DC"),  # 3 мятный
	Color("#BEDCEE"),  # 4 голубой
	Color("#C9CAF0"),  # 5 барвинок
	Color("#DCC2EC"),  # 6 сиреневый
]
## индекс цвета для клеток А..Я (соседи, включая диагональ, всегда разного цвета)
const CUBE_ORDER := [1, 0, 5, 6, 3, 0, 4, 6, 2, 4, 1, 2, 5, 1, 5, 3, 6, 5, 0, 6, 2, 0, 4, 1, 3, 4, 1, 3, 6, 2, 0, 5, 2]
const CUBE_LOCK_GREY := Color("#D8D2C7")
const CUBE_LOCK_MIX := 0.5
const CUBE_FACE_LOCK := Color(0.94, 0.94, 0.94)
const CUBE_LETTER_LOCK_TO := Color("#ECE7DC")
const CUBE_LETTER_LOCK_MIX := 0.55
const COLS := 7
const CUBE_SIZE := 124.0
const CUBE_STEP := Vector2(138, 136)
const CUBE_GRID_SIZE := Vector2(952, 668)
## Буква на лицевой грани (светлая зона ≈ 74×74 при 1×). Спека: 46; выбрано 52 — крупнее, но самые широкие Ж Ш Щ Ю
## (≈69 px) и точки Ё / кратка Й ещё не касаются рамки грани (при 56 Ж уже заходит на рамку).
const CUBE_FONT_SIZE := 52
## лицевая грань в кубике 124×124: x 9.7..102.7, y 19.4..112.4 (центр смещён от центра PNG на (−5.8; +3.9))
const FACE_POS := Vector2(9.7, 19.4)
const FACE_SIZE := Vector2(93, 93)

func run() -> void:
	add_bg("bg_letters_menu")
	# сетка 952×668 по центру сцены 1024×768 (сцена сама центрируется в видимой области, на 16:9 — тоже по центру)
	var origin := (Vector2(1024, 768) - CUBE_GRID_SIZE) / 2      # = (36, 50)
	var active: Control = null
	for i in ALPHABET.length():
		var ch := ALPHABET[i]
		var col := i % COLS + (1 if i >= 28 else 0)           # последний ряд из 5 — по центру
		var pos := origin + Vector2(col * CUBE_STEP.x, (i / COLS) * CUBE_STEP.y)
		var t := _cube(ch, pos, CUBE_COLORS[CUBE_ORDER[i]])
		if ch == ACTIVE:
			active = t
	main.expose("letter_a", active)
	pop_in(active)
	pulse(active, 2)
	# Руки-подсказки на экране букв нет (правило: на главной — без подсказки).
	main.set_state("wait_letter")

func _layer(btn: Control, id: String, mod: Color) -> void:
	var r := TextureRect.new()
	r.texture = Assets.tex(id)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = btn.size
	r.modulate = mod
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(r)

func _cube(ch: String, pos: Vector2, color: Color) -> Control:
	var locked := ch != ACTIVE
	var btn := Button.new()
	btn.name = "tile_" + Assets.TRANSLIT.get(ch.to_lower(), ch)
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = true
	btn.position = pos
	btn.size = Vector2(CUBE_SIZE, CUBE_SIZE)
	btn.pivot_offset = btn.size / 2
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		btn.add_theme_stylebox_override(st, empty)
	add_child(btn)
	_layer(btn, "ui_cube_tint", color.lerp(CUBE_LOCK_GREY, CUBE_LOCK_MIX) if locked else color)
	_layer(btn, "ui_cube_face", CUBE_FACE_LOCK if locked else Color.WHITE)
	var low := ch.to_lower()
	var lc := Assets.CONSONANT_BLUE
	if Assets.VOWELS.contains(low):
		lc = Assets.VOWEL_RED
	elif low in ["ь", "ъ"]:
		lc = Assets.DARK
	if locked:
		lc = lc.lerp(CUBE_LETTER_LOCK_TO, CUBE_LETTER_LOCK_MIX)   # гласные #E3998C, согласные #97B0CA, ь/ъ #9D968B
	var l := Label.new()
	l.text = ch
	l.add_theme_font_size_override("font_size", CUBE_FONT_SIZE)
	l.add_theme_color_override("font_color", lc)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = FACE_POS
	l.size = FACE_SIZE
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(l)
	if locked:
		btn.pressed.connect(func(): shake(btn, pos, false); Voice.sfx("sfx_try"))
		if ch == "Б":
			main.expose("letter_locked", btn)
	else:
		btn.pressed.connect(_start_lesson)
	return btn

func _start_lesson() -> void:
	main.hint_stop()
	main.log_event("letter", {"ch": ACTIVE})
	Voice.sfx("sfx_start")
	main.start_lesson()
