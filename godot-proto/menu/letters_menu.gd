## Экран всех букв: 33 плитки по алфавиту. Активна только «А» (тап — урок «А» с s01), остальные приглушены (замок).
## Сюда ведут крестик выхода (s01–s10) и «домой» в s10. Цвета: гласные — красные #D93A2B,
## согласные — синие, ь/ъ — тёмные #3C3228; подложки плиток — кремовые #F7F0DE.
extends LessonStep

const ALPHABET := "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
const ACTIVE := "А"
const COLS := 8
const TILE := 96.0
const GAP := 16.0
const TOP := 150.0
const LOCKED_ALPHA := 0.35

func run() -> void:
	var b := add_bg("bg_room_day")
	b.modulate = Color(0.85, 0.85, 0.85)
	var grid_w := COLS * TILE + (COLS - 1) * GAP
	var x0 := (1024.0 - grid_w) / 2
	var active: Control = null
	for i in ALPHABET.length():
		var ch := ALPHABET[i]
		var pos := Vector2(x0 + (i % COLS) * (TILE + GAP), TOP + (i / COLS) * (TILE + GAP))
		var t := _tile(ch, pos)
		if ch == ACTIVE:
			active = t
	main.expose("letter_a", active)
	pop_in(active)
	pulse(active, 2)
	main.hint_start(func(): return active, "")
	main.set_state("wait_letter")

func _tile(ch: String, pos: Vector2) -> Control:
	var btn := Button.new()
	btn.name = "tile_" + Assets.TRANSLIT.get(ch.to_lower(), ch)
	btn.focus_mode = Control.FOCUS_NONE
	btn.position = pos
	btn.size = Vector2(TILE, TILE)
	btn.pivot_offset = btn.size / 2
	var sb := StyleBoxFlat.new()
	sb.bg_color = Assets.CREAM
	sb.set_corner_radius_all(18)
	sb.border_color = Color(Assets.DARK, 0.25)
	sb.set_border_width_all(2)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st, sb)
	add_child(btn)
	var low := ch.to_lower()
	var col := Assets.CONSONANT_BLUE
	if Assets.VOWELS.contains(low):
		col = Assets.VOWEL_RED
	elif low in ["ь", "ъ"]:
		col = Assets.DARK
	var l := Label.new()
	l.text = ch
	l.add_theme_font_size_override("font_size", 60)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(l)
	if ch == ACTIVE:
		btn.pressed.connect(_start_lesson)
	else:
		btn.modulate.a = LOCKED_ALPHA
		btn.pressed.connect(func(): shake(btn, pos, false); Voice.sfx("sfx_try"))
		if ch == "Б":
			main.expose("letter_locked", btn)
	return btn

func _start_lesson() -> void:
	main.hint_stop()
	main.log_event("letter", {"ch": ACTIVE})
	Voice.sfx("sfx_start")
	main.goto(1)
