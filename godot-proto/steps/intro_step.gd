## Короткий ознакомительный урок одной буквы. Четыре сцены из lesson.json → intro.scenes.
## Тексты и id реплик — только из сценария. Нет файла звука: Voice.say всё равно завершается по dur, тупика нет.
## Рисунки предметов — спрайт из сцены (tex), иначе геометрический черновик в коде. Буквы и слова рисует шрифт урока.
extends LessonStep

@export var scene_no := 1

## Игровая зона 1024×768: не ближе 150 px к «назад» (84), крестику (940) и «Далее» (912,656).
const PLAY := Rect2(250, 248, 500, 248)
const INK := Color("#3C3228")

var _ill := false
var _hits: Array[String] = []
var _answered := false
var _traced := false
var _trace_open := false
var _drag := false
var _saw_left := false
var _task: Array[Node] = []
var _glyphs: Array[Label] = []

func run() -> void:
	var intro: Dictionary = Assets.lesson.get("intro", {})
	var scenes: Array = intro.get("scenes", [])
	if scene_no < 1 or scene_no > scenes.size():
		finish()
		return
	var sc: Dictionary = scenes[scene_no - 1]
	var carrier_tex := String(scenes[0].get("tex", ""))
	_ill = carrier_tex != "" and Assets.tex("ui_intro_ear", false) != null and Assets.tex(carrier_tex, false) != null
	main.set_info("illustrated", _ill)
	main.set_info("m_art", _ill and String(Assets.letter_id) == "m")
	main.set_info("intro_kind", String(sc.get("kind", "")))
	main.set_info("intro_letter", String(intro.get("letter", "")))
	main.set_info("art", String(intro.get("art", "")))
	main.set_info("scene_no", scene_no)
	main.set_info("audio_missing", Assets.sound(String(sc.get("line", ""))) == null)
	_cream()
	var kind := String(sc.get("kind", ""))
	match kind:
		"meet": await _meet(intro, sc)
		"locate", "soft_hear": await _locate(sc)
		"trace": await _trace(sc)
		"two_dots": await _two_dots(intro, sc)
		"choose_trace": await _choose_trace(sc)
		"picture", "text": await _pick(intro, sc)
		"soft_sign": await _soft_sign(sc)
		"hard_pair", "hard_compare": await _hard_cards(sc)
		"hard_sign": await _hard_sign(intro, sc)
		_:
			push_error("неизвестная сцена " + kind)
			finish()

func _cream() -> void:
	var c := ColorRect.new()
	c.color = Assets.CREAM
	c.position = Vector2.ZERO
	c.size = Vector2(1024, 768)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_meta("bg", true)
	add_child(c)

func _r(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(PLAY.position + Vector2(PLAY.size.x * x, PLAY.size.y * y), Vector2(PLAY.size.x * w, PLAY.size.y * h))

func _keep(n: Node) -> Node:
	_task.append(n)
	if n is Control:
		var r := (n as Control).get_global_rect()
		var items: Array = main.info.get("item_rects", [])
		items.append([r.position.x, r.position.y, r.size.x, r.size.y, String(n.name)])
		main.set_info("item_rects", items)
	return n

func _arm(b: BaseButton, id: String) -> void:
	b.pressed.connect(func() -> void:
		if _answered or dead:
			return
		_hits.append(id)
		main.hint_reset())

func _next_hit() -> String:
	while not dead and _hits.is_empty():
		await get_tree().process_frame
	if dead:
		return ""
	return String(_hits.pop_front())

func _ink(ch: String, nxt := "") -> Color:
	var base := ch.substr(0, 1).to_lower()
	if base in ["ь", "ъ"]:
		return Assets.DARK
	if Assets.VOWELS.contains(base):
		return Assets.VOWEL_RED
	# Ж/Ш не смягчаются, в том числе перед и. Остальные — только перед ь или смягчающей гласной этого слова.
	if base in ["ж", "ш"]:
		return Assets.CONSONANT_BLUE
	var n := nxt.substr(0, 1).to_lower()
	if n in ["ь", "и", "е", "ё", "ю", "я"]:
		return Assets.SOFT_GREEN
	return Assets.CONSONANT_BLUE

func _style(fill: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	return sb

func _button(rect: Rect2, id: String, fill: Color, radius: int) -> Button:
	var b := Button.new()
	b.name = id
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	var sb := _style(fill, radius)
	if fill.a > 0.5:
		sb.border_color = Color("#E4D5B8")
		sb.set_border_width_all(3)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(b)
	_arm(b, id)
	_keep(b)
	return b

func _round_btn(rect: Rect2, id: String) -> Button:
	var side := minf(rect.size.x, rect.size.y)
	var r := Rect2(rect.position + (rect.size - Vector2(side, side)) / 2.0, Vector2(side, side))
	return _button(r, id, Assets.MUSTARD, int(side / 2.0))

func _letter_btn(ch: String, px: int, rect: Rect2, id: String) -> Button:
	var b := _button(rect, id, Color("#FFF9EE"), 16)
	var lab := Label.new()
	lab.text = ch
	lab.set_anchors_preset(Control.PRESET_FULL_RECT)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lab.add_theme_font_size_override("font_size", px)
	lab.add_theme_color_override("font_color", _ink(ch))
	b.add_child(lab)
	return b

func _motif(seed: String, parent: Control) -> void:
	var m := DraftMotif.new()
	m.seed = seed
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.position = Vector2(12, 12)
	m.size = Vector2(maxf(8.0, parent.size.x - 24.0), maxf(8.0, parent.size.y - 24.0))
	parent.add_child(m)

func _ear(rect: Rect2, id: String) -> Button:
	var b := _round_btn(rect, id)
	if _ill:
		_paint(b, "ui_intro_ear", true)
	else:
		var mark := EarMark.new()
		mark.set_anchors_preset(Control.PRESET_FULL_RECT)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(mark)
	main.expose(id, b)
	return b

func _slot(rect: Rect2, id: String) -> Button:
	var b := _round_btn(rect, id)
	if _ill:
		_paint(b, "ui_intro_slot", true)
		return b
	var sb := _style(Color("#EFE4CC"), int(minf(rect.size.x, rect.size.y) / 2.0))
	sb.border_color = Color("#D9CDB4")
	sb.set_border_width_all(4)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	return b

func _quiet(b: Button) -> void:
	var sb := _style(Assets.CREAM, 8)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)

func _tex_of(tex_id: String, from_letter: String = "") -> Texture2D:
	if from_letter != "":
		for tier in ["res://art/", "res://art_provisional/", "res://art_placeholder/"]:
			var path := "%slesson_%s/%s.png" % [tier, from_letter, tex_id]
			if ResourceLoader.exists(path):
				return load(path)
		return null
	return Assets.tex(tex_id, false)

func _paint(host: Control, tex_id: String, cover := false, from_letter: String = "") -> void:
	var tex := _tex_of(tex_id, from_letter)
	if tex == null:
		return
	var r := TextureRect.new()
	r.texture = tex
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.offset_right = 0
	r.offset_bottom = 0
	r.grow_horizontal = Control.GROW_DIRECTION_BOTH
	r.grow_vertical = Control.GROW_DIRECTION_BOTH
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.add_child(r)

func _glyphs_of(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var i := 0
	while i < text.length():
		if i + 1 < text.length() and text.unicode_at(i + 1) == 0x0301:
			out.append(text.substr(i, 2))
			i += 2
		else:
			out.append(text.substr(i, 1))
			i += 1
	return out

func _word(text: String, px: int, rect: Rect2, hide_last := false) -> Control:
	var box := Control.new()
	box.name = "word"
	box.position = rect.position
	box.size = rect.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_keep(box)
	_glyphs.clear()
	var parts := _glyphs_of(text)
	var gap := 2.0
	var widths: Array[float] = []
	var total := 0.0
	for part in parts:
		var w := float(px) * (0.62 if part.length() > 0 else 0.3)
		widths.append(w)
		total += w
	total += gap * maxf(0, parts.size() - 1)
	var x := maxf(0.0, (rect.size.x - total) / 2.0)
	for i in parts.size():
		var nxt := parts[i + 1] if i + 1 < parts.size() else ""
		var slot := Rect2(Vector2(x, 0), Vector2(widths[i], rect.size.y))
		var hidden := hide_last and i == parts.size() - 1
		if hidden:
			box.set_meta("hidden_slot", slot)
			box.set_meta("hidden_text", parts[i])
			box.set_meta("hidden_px", px)
			box.set_meta("hidden_next", nxt)
		else:
			_glyphs.append(_glyph_label(box, parts[i], nxt, slot, px))
		x += widths[i] + gap
	return box

func _glyph_label(box: Control, text: String, nxt: String, slot: Rect2, px: int) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.position = slot.position
	lab.size = slot.size
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_font_size_override("font_size", px)
	lab.add_theme_color_override("font_color", _ink(text, nxt))
	box.add_child(lab)
	return lab

func _reveal_last(box: Control) -> void:
	if box == null or not box.has_meta("hidden_slot"):
		return
	var slot: Rect2 = box.get_meta("hidden_slot")
	_glyphs.append(_glyph_label(box, String(box.get_meta("hidden_text")), String(box.get_meta("hidden_next")), slot, int(box.get_meta("hidden_px"))))

func _track(rect: Rect2) -> Control:
	var t := Control.new()
	t.name = "track"
	t.position = rect.position
	t.size = rect.size
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(t)
	_keep(t)
	if _ill:
		_paint(t, "ui_intro_track", true)
	else:
		var road := ColorRect.new()
		road.color = Assets.MUSTARD
		road.position = Vector2(0, rect.size.y * 0.35)
		road.size = Vector2(rect.size.x, rect.size.y * 0.3)
		road.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.add_child(road)
	var left := ColorRect.new()
	left.name = "track_l"
	left.color = Color(0, 0, 0, 0) if _ill else Color("#C8962A")
	left.position = Vector2(0, rect.size.y * 0.2)
	left.size = Vector2(rect.size.y * 0.6, rect.size.y * 0.6)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(left)
	var right := ColorRect.new()
	right.name = "track_r"
	right.color = Color(0, 0, 0, 0) if _ill else Color("#C8962A")
	right.position = Vector2(rect.size.x - rect.size.y * 0.6, rect.size.y * 0.2)
	right.size = left.size
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(right)
	t.gui_input.connect(_on_track.bind(t))
	main.expose("track_l", left)
	main.expose("track_r", right)
	return t

func _on_track(ev: InputEvent, track: Control) -> void:
	if not _trace_open or _answered:
		return
	var local := Vector2.ZERO
	var edge := false
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		local = ev.position
		edge = true
		if ev.pressed:
			_drag = true
			_saw_left = local.x < track.size.x * 0.42
			main.hint_stop()
		else:
			_drag = false
	elif ev is InputEventMouseMotion and _drag:
		local = ev.position
	else:
		return
	if _drag and local.x < track.size.x * 0.42:
		_saw_left = true
	if _drag and _saw_left and local.x > track.size.x * 0.60:
		_traced = true
		_drag = false
	if edge:
		pass

func _await_trace() -> bool:
	_traced = false
	_trace_open = true
	_drag = false
	_saw_left = false
	main.set_state("wait_trace")
	while not dead and not _traced:
		await get_tree().process_frame
	_trace_open = false
	return not dead

func _hint_at(node: Control, line: String) -> void:
	main.hint_start(func() -> Control: return node, "c_hint", Callable(), func() -> void:
		if line != "":
			Voice.say(line))

func _flash_glyphs() -> void:
	for lab in _glyphs:
		if not is_instance_valid(lab):
			continue
		var tw := lab.create_tween()
		tw.tween_property(lab, "modulate", Color("#E2B42E"), 0.18)
		tw.tween_property(lab, "modulate", Color.WHITE, 0.18)
		await get_tree().create_timer(0.12).timeout
		if dead:
			return

func _meet(intro: Dictionary, sc: Dictionary) -> void:
	var carrier: Button
	var lb: Button
	var ls: Button
	var big := String(intro.get("letter", ""))
	var small := big.to_lower()
	if _ill:
		# Общая рамка М/Х/О/Ш. Если в сцене есть fit, рамка из layout_handoff этой буквы.
		var fit: Array = sc.get("fit", [])
		var box := Rect2(437, 152, 150, 100)
		var fill := Color("#FFF9EE")
		if fit.size() == 4:
			box = Rect2(float(fit[0]), float(fit[1]), float(fit[2]), float(fit[3]))
			fill = Color(0, 0, 0, 0)
		carrier = _button(box, "carrier", fill, 16)
		var carrier_id := String(sc.get("tex", ""))
		# Мышь и широкий сом заполняют рамку (обрезается только прозрачный край). Остальные предметы целиком.
		_paint(carrier, carrier_id, carrier_id == "pic_myshka" or bool(sc.get("cover", false)))
	else:
		carrier = _button(_r(0.18, 0.0, 0.64, 0.46), "carrier", Color("#FFF9EE"), 22)
		_motif(String(sc.get("motif", "")), carrier)
	main.expose("carrier", carrier)
	if not await say(String(sc.get("line", ""))):
		return
	if _ill:
		lb = _letter_btn(big, 100, Rect2(304, 335, 190, 177), "letter_big")
		ls = _letter_btn(small, 92, Rect2(530, 335, 190, 177), "letter_small")
		_quiet(lb)
		_quiet(ls)
	else:
		var px := 78
		lb = _letter_btn(big, px, _r(0.12, 0.52, 0.36, 0.46), "letter_big")
		ls = _letter_btn(small, int(px * 0.7), _r(0.52, 0.52, 0.34, 0.46), "letter_small")
	main.expose("letter_big", lb)
	main.expose("letter_small", ls)
	main.set_state("wait_letter")
	_hint_at(lb, String(sc.get("line", "")))
	while not dead:
		var h := await _next_hit()
		if h == "":
			return
		if h == "carrier":
			tap_say(String(sc.get("carrier", "")))
		elif h == "letter_big" or h == "letter_small":
			tap_say(String(sc.get("tap", "")))
			_answered = true
			main.hint_stop()
			finish()
			return

func _locate(sc: Dictionary) -> void:
	var n := int(sc.get("slots", 2))
	var correct := int(sc.get("correct", 1))
	main.set_info("correct", correct)
	var ear: Button
	var slots: Array[Button] = []
	if String(sc.get("kind", "")) == "soft_hear":
		if _ill:
			var fit: Array = sc.get("fit", [385, 145, 280, 178])
			var pic := _button(Rect2(float(fit[0]), float(fit[1]), float(fit[2]), float(fit[3])), "pic", Color(0, 0, 0, 0), 16)
			_paint(pic, String(sc.get("tex", "")), false)
			# Конь: три звука, отдельной позиции для ь нет. Рамка ниже картинки.
			ear = _ear(Rect2(278, 370, 80, 80), "ear")
			slots.append(_slot(Rect2(402, 369, 92, 92), "slot_1"))
			slots.append(_slot(Rect2(522, 369, 92, 92), "slot_2"))
			slots.append(_slot(Rect2(642, 369, 92, 92), "slot_3"))
		else:
			var plain := _button(_r(0.28, 0.0, 0.44, 0.42), "pic", Color("#FFF9EE"), 18)
			_motif(String(sc.get("motif", "конь")), plain)
			ear = _ear(_r(0.0, 0.34, 0.2, 0.4), "ear")
			var gap0 := 0.04
			var w0 := (0.74 - gap0 * (n - 1)) / n
			for i in n:
				var x0 := 0.24 + i * (w0 + gap0)
				slots.append(_slot(_r(x0, 0.28, w0, 0.5), "slot_%d" % (i + 1)))
	elif _ill and n == 2:
		ear = _ear(Rect2(270, 336, 80, 80), "ear")
		slots.append(_slot(Rect2(405, 325, 110, 110), "slot_1"))
		slots.append(_slot(Rect2(590, 325, 110, 110), "slot_2"))
	elif _ill and n == 3:
		# Три одинаковые позиции К/П/Т: нужная последняя. Рамка из layout_handoff.
		ear = _ear(Rect2(245, 336, 70, 70), "ear")
		slots.append(_slot(Rect2(350, 325, 105, 105), "slot_1"))
		slots.append(_slot(Rect2(490, 325, 105, 105), "slot_2"))
		slots.append(_slot(Rect2(630, 325, 105, 105), "slot_3"))
	else:
		ear = _ear(_r(0.0, 0.34, 0.2, 0.4), "ear")
		var gap := 0.04
		var w := (0.74 - gap * (n - 1)) / n
		for i in n:
			var x := 0.24 + i * (w + gap)
			slots.append(_slot(_r(x, 0.28, w, 0.5), "slot_%d" % (i + 1)))
	for i in slots.size():
		main.expose("slot_%d" % (i + 1), slots[i])
	if not await say(String(sc.get("line", ""))):
		return
	main.set_state("wait_slot")
	_hint_at(slots[correct - 1], String(sc.get("line", "")))
	var model := String(sc.get("model", ""))
	while not dead and not _answered:
		var h := await _next_hit()
		if h == "":
			return
		if h == "ear":
			await say(model)
		elif h.begins_with("slot_"):
			var k := int(h.trim_prefix("slot_"))
			if k == correct:
				_answered = true
				main.hint_stop()
				await say("c_success")
				finish()
				return
			shake(slots[k - 1])
			await say("c_retry")
		else:
			pass
	if ear:
		pass

func _drop(names: Array) -> void:
	var keep: Array[Node] = []
	for n in _task:
		if not is_instance_valid(n):
			continue
		if names.has(String(n.name)):
			n.queue_free()
		else:
			keep.append(n)
	_task = keep

func _show_card(text: String, audio: String) -> void:
	_drop(["syll", "track", "ear", "word"])
	var lab: Control
	if _ill:
		lab = _word(text, 72, Rect2(390, 320, 280, 100))
		_ear(Rect2(274, 285, 64, 64), "ear")
		_track(Rect2(310, 430, 420, 75))
	else:
		lab = _word(text, 72, _r(0.1, 0.08, 0.8, 0.42))
		_ear(_r(0.0, 0.08, 0.18, 0.32), "ear")
		_track(_r(0.08, 0.62, 0.84, 0.3))
	lab.name = "syll"
	main.set_info("card_text", text)
	if not await say(audio):
		return

func _trace(sc: Dictionary) -> void:
	var cards: Array = sc.get("cards", [])
	main.set_info("cards", cards.size())
	if not await say(String(sc.get("line", ""))):
		return
	for i in cards.size():
		var card: Dictionary = cards[i]
		await _show_card(String(card.get("text", "")), String(card.get("audio", "")))
		if dead:
			return
		main.set_info("card_i", i)
		_hint_at(get_node_or_null("track") as Control, "c_instruction_trace")
		if not await _await_trace():
			return
		main.hint_stop()
	_answered = true
	await say("c_success")
	finish()

func _two_dots(intro: Dictionary, sc: Dictionary) -> void:
	var big := String(intro.get("letter", ""))
	_letter_btn(big, 84, _r(0.3, 0.0, 0.4, 0.4), "letter_big")
	var ears: Array = sc.get("ears", [])
	_ear(_r(0.12, 0.46, 0.28, 0.42), "ear_1")
	_ear(_r(0.6, 0.46, 0.28, 0.42), "ear_2")
	if not await say(String(sc.get("line", ""))):
		return
	main.set_state("wait_ears")
	var heard := {}
	while not dead and heard.size() < 2:
		var h := await _next_hit()
		if h == "":
			return
		if h == "ear_1" and ears.size() > 0:
			await say(String(ears[0]))
			heard["1"] = true
		elif h == "ear_2" and ears.size() > 1:
			await say(String(ears[1]))
			heard["2"] = true
		main.set_info("heard", heard.size())
	if dead:
		return
	var e1 := get_node_or_null("ear_1") as CanvasItem
	var e2 := get_node_or_null("ear_2") as CanvasItem
	if e1:
		e1.visible = false
	if e2:
		e2.visible = false
	var one := _button(_r(0.08, 0.46, 0.38, 0.42), "dots_1", Color("#EFE4CC"), 16)
	var two := _button(_r(0.54, 0.46, 0.38, 0.42), "dots_2", Color("#EFE4CC"), 16)
	_dots(one, 1)
	_dots(two, 2)
	main.expose("dots_1", one)
	main.expose("dots_2", two)
	main.set_state("wait_dots")
	_hint_at(two, String(sc.get("line", "")))
	while not dead and not _answered:
		var h2 := await _next_hit()
		if h2 == "":
			return
		if h2 == "dots_2":
			_answered = true
			main.hint_stop()
			await say("c_success")
			if bool(sc.get("rest_after", false)):
				main.set_info("rest", true)
			finish()
			if bool(sc.get("rest_after", false)):
				await say("c_rest")
			return
		if h2 == "dots_1":
			shake(one)
			await say("c_retry")
		elif h2 == "ear_1" and ears.size() > 0:
			await say(String(ears[0]))
		elif h2 == "ear_2" and ears.size() > 1:
			await say(String(ears[1]))

func _dots(host: Control, n: int) -> void:
	for i in n:
		var d := ColorRect.new()
		d.color = INK
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var w := host.size.x
		var dot := 18.0
		var gap := 16.0
		var total := n * dot + (n - 1) * gap
		d.position = Vector2((w - total) / 2.0 + i * (dot + gap), (host.size.y - dot) / 2.0)
		d.size = Vector2(dot, dot)
		host.add_child(d)

func _choose_trace(sc: Dictionary) -> void:
	var cards: Array = sc.get("cards", [])
	if not await say(String(sc.get("line", ""))):
		return
	var heard := {}
	var target_i := -1
	for i in cards.size():
		var card: Dictionary = cards[i]
		var rect := Rect2(290 + i * 250, 250, 190, 150) if _ill else _r(0.04 + i * 0.5, 0.02, 0.44, 0.48)
		var b := _button(rect, "card_%d" % i, Color("#FFF9EE"), 16)
		if _ill:
			_paint(b, "ui_intro_card", true)
		_word_on(b, String(card.get("text", "")), 48)
		main.expose("card_%d" % i, b)
		if bool(card.get("track", false)):
			target_i = i
	main.set_state("wait_syll")
	var chosen := false
	while not dead and not chosen:
		var h := await _next_hit()
		if h == "":
			return
		if not h.begins_with("card_"):
			continue
		var i := int(h.trim_prefix("card_"))
		var ready := heard.size() >= cards.size()
		await say(String((cards[i] as Dictionary).get("audio", "")))
		heard[h] = true
		main.set_info("heard", heard.size())
		if not ready:
			if heard.size() >= cards.size():
				_hits.clear()
			continue
		if i == target_i:
			chosen = true
		else:
			var bad := get_node_or_null(h) as Control
			if bad:
				shake(bad)
			await say("c_retry")
	if dead or target_i < 0:
		return
	main.set_info("sounds", 2)
	if _ill:
		_sound_mark(Rect2(570, 405, 56, 56))
		_sound_mark(Rect2(650, 405, 56, 56))
		_track(Rect2(540, 477, 190, 55))
	else:
		var host := get_node_or_null("card_%d" % target_i) as Control
		if host:
			_sound_mark(Rect2(host.position.x + 24, host.position.y + host.size.y - 36, 28, 28))
			_sound_mark(Rect2(host.position.x + 64, host.position.y + host.size.y - 36, 28, 28))
		_track(_r(0.08 + target_i * 0.5, 0.62, 0.36, 0.3))
	main.set_state("wait_trace")
	if dead or not await _await_trace():
		return
	_answered = true
	main.hint_stop()
	await say("c_success")
	finish()

func _sound_mark(rect: Rect2) -> void:
	var c := Control.new()
	c.position = rect.position
	c.size = rect.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	_keep(c)
	if _ill:
		_paint(c, "ui_intro_slot", true)
		return
	var d := ColorRect.new()
	d.color = Color("#D9CDB4")
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(d)

func _word_on(host: Control, text: String, px: int) -> void:
	var lab := Label.new()
	lab.text = text
	lab.set_anchors_preset(Control.PRESET_FULL_RECT)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", px)
	# смешанная окраска: гласная красная, остальные не красные — через отдельные буквы, если строка короткая
	lab.add_theme_color_override("font_color", INK)
	host.add_child(lab)
	var row := Control.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(row)
	lab.visible = false
	var parts := _glyphs_of(text)
	var gap := 1.0
	var widths: Array[float] = []
	var total := 0.0
	for part in parts:
		var w := float(px) * 0.7
		widths.append(w)
		total += w
	total += gap * maxf(0, parts.size() - 1)
	var x := maxf(0.0, (host.size.x - total) / 2.0)
	for i in parts.size():
		var g := Label.new()
		g.text = parts[i]
		g.position = Vector2(x, 0)
		g.size = Vector2(widths[i], host.size.y)
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.add_theme_font_size_override("font_size", px)
		g.add_theme_color_override("font_color", _ink(parts[i], parts[i + 1] if i + 1 < parts.size() else ""))
		row.add_child(g)
		x += widths[i] + gap

func _pick(intro: Dictionary, sc: Dictionary) -> void:
	var kind := String(sc.get("kind", ""))
	var answer := String(sc.get("answer", ""))
	if not await say(String(sc.get("line", ""))):
		return
	if _ill and (kind == "picture" or kind == "text"):
		_ear(Rect2(270, 231, 70, 70), "ear")
	else:
		_ear(_r(0.0, 0.0, 0.18, 0.28), "ear")
	var choices: Array = sc.get("choices", [])
	var order := _order(choices.size(), String(intro.get("letter", "")) + str(scene_no))
	var correct_at := order.find(0)
	main.set_info("correct_at", correct_at)
	if kind == "picture":
		if _ill:
			_word(String(sc.get("word", "")), 64, Rect2(360, 230, 360, 90))
		else:
			_word(String(sc.get("word", "")), 54, _r(0.22, 0.0, 0.74, 0.3))
	for pos in order.size():
		var src: int = order[pos]
		var id := "pick_ok" if src == 0 else "pick_bad"
		var framed := _ill and (kind == "picture" or kind == "text")
		var rect := Rect2(280 + pos * 250, 340, 210, 210) if framed else (_r(0.04 + pos * 0.5, 0.38, 0.44, 0.58) if kind == "picture" else _r(0.04 + pos * 0.5, 0.4, 0.44, 0.52))
		var b := _button(rect, id, Color("#FFF9EE"), 18)
		if kind == "picture":
			var choice: Dictionary = choices[src]
			var tex_id := String(choice.get("tex", ""))
			if _ill and tex_id != "":
				_paint(b, "ui_intro_card", true)
				var inset := Control.new()
				inset.position = Vector2(16, 16)
				inset.size = b.size - Vector2(32, 32)
				inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.add_child(inset)
				_paint(inset, tex_id, false, String(choice.get("from", "")))
			else:
				_motif(String(choice.get("seed", "")), b)
		elif framed:
			_paint(b, "ui_intro_card", true)
			_word_on(b, String(choices[src]), 64)
		else:
			_word_on(b, String(choices[src]), 48)
		main.expose(id, b)
	main.set_state("wait_choice")
	var ok := get_node_or_null("pick_ok") as Control
	_hint_at(ok, answer)
	while not dead and not _answered:
		var h := await _next_hit()
		if h == "":
			return
		if h == "ear":
			await say(answer)
			await _flash_glyphs()
		elif h == "pick_ok":
			_answered = true
			main.hint_stop()
			await say(answer)
			await say("c_success")
			_clear_task()
			_sticker(intro)
			_again()
			finish()
			return
		elif h == "pick_bad":
			var bad := get_node_or_null("pick_bad") as Control
			if bad:
				shake(bad)
			await say("c_retry")

func _order(n: int, salt: String) -> Array:
	var arr: Array = []
	for i in n:
		arr.append(i)
	var state := absi(salt.hash()) % 2147483646
	if state == 0:
		state = 1
	for i in range(n - 1, 0, -1):
		state = int((int(state) * 1103515245 + 12345) % 2147483647)
		var j := state % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
	return arr

func _soft_sign(sc: Dictionary) -> void:
	if not await say(String(sc.get("line", ""))):
		return
	var word := String(sc.get("word", "конь"))
	var box := _word(word, 86, Rect2(250, 250, 400, 110), true)
	var curtain := ColorRect.new()
	curtain.name = "curtain"
	curtain.color = Color("#E4D3B0")
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot: Rect2 = box.get_meta("hidden_slot", Rect2(300, 0, 50, 110))
	# Шторка закрывает всю клетку последнего знака. Сам знак ещё не нарисован.
	curtain.position = box.position + slot.position - Vector2(6, 0)
	curtain.size = Vector2(slot.size.x + 12, box.size.y)
	curtain.z_index = 5
	add_child(curtain)
	_keep(curtain)
	for i in 3:
		if _ill:
			_sound_mark(Rect2(353 + i * 81, 370, 70, 70))
		else:
			var d := ColorRect.new()
			d.color = Color("#D9CDB4")
			d.position = _r(0.12 + i * 0.16, 0.4, 0.08, 0.1).position
			d.size = Vector2(16, 16)
			d.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(d)
	var opts: Array = sc.get("options", [])
	for i in opts.size():
		var ch := String(opts[i])
		var id := "pick_ok" if ch == String(sc.get("correct", "ь")) else "pick_bad"
		var opt := Rect2(680, 240 + i * 125, 90, 90) if _ill else _r(0.62, 0.02 + i * 0.22, 0.32, 0.2)
		_letter_btn(ch, 64, opt, id)
		main.expose(id, get_node_or_null(id) as Control)
	main.set_state("wait_sign")
	while not dead and not _answered:
		var h := await _next_hit()
		if h == "":
			return
		if h == "pick_bad":
			var bad := get_node_or_null("pick_bad") as Control
			if bad:
				shake(bad)
			await say("c_retry")
		elif h == "pick_ok":
			_reveal_last(box)
			curtain.visible = false
			_track(Rect2(310, 470, 420, 70) if _ill else _r(0.06, 0.62, 0.88, 0.3))
			main.hint_stop()
			if not await _await_trace():
				return
			_answered = true
			await say(String(sc.get("model", "")))
			await say("c_success")
			finish()
			return

func _hard_cards(sc: Dictionary) -> void:
	var cards: Array = sc.get("cards", [])
	var correct := String(sc.get("correct", ""))
	if not await say(String(sc.get("line", ""))):
		return
	var buttons: Array[Button] = []
	for i in cards.size():
		var card: Dictionary = cards[i]
		var b := _button(_r(0.04 + i * 0.5, 0.06, 0.44, 0.7), "card_%d" % i, Color("#FFF9EE"), 16)
		if String(sc.get("kind", "")) == "hard_pair" and i == 1:
			b.visible = false
		_word_on(b, String(card.get("text", "")), 40)
		if String(card.get("motif", "")) != "":
			var chip := Control.new()
			chip.position = Vector2(16, b.size.y * 0.55)
			chip.size = Vector2(b.size.x - 32, b.size.y * 0.36)
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(chip)
			var motif := DraftMotif.new()
			motif.seed = String(card.get("motif", ""))
			motif.set_anchors_preset(Control.PRESET_FULL_RECT)
			chip.add_child(motif)
		if int(card.get("dots", 0)) > 0:
			for k in int(card.get("dots", 0)):
				var d := ColorRect.new()
				d.color = Color("#D9CDB4")
				d.mouse_filter = Control.MOUSE_FILTER_IGNORE
				d.position = Vector2(24 + k * 28, b.size.y - 28)
				d.size = Vector2(14, 14)
				b.add_child(d)
		buttons.append(b)
		var hear_id := "hear_%d" % i
		main.expose(hear_id, b)
	main.set_state("wait_hear")
	var heard := {}
	while not dead and not _answered:
		var h := await _next_hit()
		if h == "":
			return
		if h.begins_with("card_"):
			var i := int(h.trim_prefix("card_"))
			var card: Dictionary = cards[i]
			if String(sc.get("kind", "")) == "hard_pair" and i == 0 and not heard.has(0):
				await say(String(card.get("audio", "")))
				heard[0] = true
				_hits.clear()
				buttons[1].visible = true
				main.expose("hear_1", buttons[1])
				main.set_info("heard", heard.size())
				continue
			if not heard.has(i):
				await say(String(card.get("audio", "")))
				heard[i] = true
				_hits.clear()
				main.set_info("heard", heard.size())
				if heard.size() >= cards.size():
					main.set_state("wait_pick")
					main.expose("pick_ok", buttons[0] if String(cards[0].get("text", "")) == correct else buttons[1])
					main.expose("pick_bad", buttons[1] if String(cards[0].get("text", "")) == correct else buttons[0])
				continue
			if heard.size() < cards.size():
				await say(String(card.get("audio", "")))
				continue
			if String(card.get("text", "")) == correct:
				_answered = true
				main.hint_stop()
				await say("c_success")
				finish()
				return
			shake(buttons[i])
			await say("c_retry")

func _hard_sign(intro: Dictionary, sc: Dictionary) -> void:
	if not await say(String(sc.get("line", ""))):
		return
	_word(String(sc.get("word", "")), 56, _r(0.22, 0.0, 0.7, 0.32))
	_ear(_r(0.0, 0.0, 0.2, 0.34), "ear")
	var choices: Array = sc.get("choices", [])
	var correct := String(sc.get("correct", "ъ"))
	var order := _order(choices.size(), "hard4")
	for pos in order.size():
		var src: int = order[pos]
		var ch := String(choices[src])
		var id := "pick_ok" if ch == correct else "pick_bad"
		_letter_btn(ch, 72, _r(0.08 + pos * 0.48, 0.42, 0.4, 0.5), id)
		main.expose(id, get_node_or_null(id) as Control)
	var heard := false
	main.set_state("wait_model")
	while not dead and not _answered:
		var h := await _next_hit()
		if h == "":
			return
		if h == "ear" or not heard:
			if h == "ear" or h.begins_with("pick_"):
				if not heard:
					await say(String(sc.get("model", "")))
					heard = true
					main.set_state("wait_choice")
					if h != "ear":
						continue
					continue
		if h == "pick_ok" and heard:
			_answered = true
			main.hint_stop()
			await say("c_success")
			_clear_task()
			_sticker(intro)
			_again()
			finish()
			return
		if h == "pick_bad" and heard:
			var bad := get_node_or_null("pick_bad") as Control
			if bad:
				shake(bad)
			await say("c_retry")

func _clear_task() -> void:
	for n in _task:
		if is_instance_valid(n):
			(n as CanvasItem).visible = false

func _sticker(intro: Dictionary) -> void:
	var host: Button
	var big := String(intro.get("letter", ""))
	if _ill:
		host = _button(Rect2(370, 270, 280, 154), "sticker", Color(0, 0, 0, 0), 18)
		_paint(host, "ui_intro_sticker", true)
		_word_on(host, big + " " + big.to_lower(), 64)
	else:
		host = _button(_r(0.22, 0.08, 0.56, 0.62), "sticker", Color("#FFF9EE"), 28)
		var sb := _style(Color("#FFF9EE"), 28)
		sb.border_color = Assets.MUSTARD
		sb.set_border_width_all(8)
		for st in ["normal", "hover", "pressed", "focus"]:
			host.add_theme_stylebox_override(st, sb)
		_word_on(host, big + " " + big.to_lower(), 64)
	main.expose("sticker", host)

func _again() -> void:
	var b: Button
	var lab := Label.new()
	lab.text = "Ещё раз"
	if _ill:
		b = _button(Rect2(650, 438, 80, 80), "again", Assets.MUSTARD, 40)
		_paint(b, "ui_intro_again", true)
		lab.position = Vector2(610, 522)
		lab.size = Vector2(160, 32)
	else:
		b = _round_btn(_r(0.78, 0.62, 0.2, 0.34), "again")
		var mark := ArrowMark.new()
		mark.set_anchors_preset(Control.PRESET_FULL_RECT)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(mark)
		lab.position = _r(0.62, 0.86, 0.36, 0.14).position
		lab.size = _r(0.62, 0.86, 0.36, 0.14).size
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_font_size_override("font_size", 22)
	lab.add_theme_color_override("font_color", INK)
	add_child(lab)
	main.expose("again", b)
	b.pressed.connect(func() -> void:
		main.completed.erase(main.screen)
		main.goto(main.index))

class DraftMotif extends Control:
	var seed := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_meta("placeholder", "draft")

	func _draw() -> void:
		var s := size
		if s.x < 8.0 or s.y < 8.0:
			return
		var h := absi(seed.hash())
		var pal := [Color("#F3C1B0"), Color("#F6E3A1"), Color("#C9DDB5"), Color("#F0C48A"), Color("#D7C4B0"), Color("#E7B8C8")]
		var c1: Color = pal[h % pal.size()]
		var c2: Color = pal[(h / 7) % pal.size()]
		var rad := minf(s.x * 0.28, s.y * 0.46)
		var mid := Vector2(s.x * 0.5, s.y * 0.56)
		var kind := h % 5
		if kind == 0:
			draw_circle(mid, rad, c1)
			draw_circle(mid + Vector2(-rad * 0.55, -rad * 0.85), rad * 0.42, c2)
			draw_circle(mid + Vector2(rad * 0.55, -rad * 0.85), rad * 0.42, c2)
		elif kind == 1:
			draw_rect(Rect2(s.x * 0.12, s.y * 0.42, s.x * 0.76, s.y * 0.46), c1, true)
			draw_colored_polygon(PackedVector2Array([
				Vector2(s.x * 0.06, s.y * 0.48), Vector2(s.x * 0.5, s.y * 0.06), Vector2(s.x * 0.94, s.y * 0.48)]), c2)
		elif kind == 2:
			draw_circle(mid, rad, c1)
			draw_rect(Rect2(s.x * 0.18, s.y * 0.62, s.x * 0.64, s.y * 0.22), c2, true)
		elif kind == 3:
			draw_colored_polygon(PackedVector2Array([
				Vector2(s.x * 0.5, s.y * 0.06), Vector2(s.x * 0.9, s.y * 0.88), Vector2(s.x * 0.1, s.y * 0.88)]), c1)
			draw_circle(Vector2(s.x * 0.5, s.y * 0.55), rad * 0.35, c2)
		else:
			draw_rect(Rect2(s.x * 0.28, s.y * 0.16, s.x * 0.44, s.y * 0.7), c1, true)
			draw_circle(Vector2(s.x * 0.5, s.y * 0.2), rad * 0.45, c2)

class EarMark extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var rad := minf(size.x, size.y) * 0.26
		draw_arc(c, rad, -0.9, 2.5, 20, Color("#3C3228"), 4.0, true)
		draw_arc(c + Vector2(3, 2), rad * 0.55, -0.5, 2.1, 14, Color("#3C3228"), 3.0, true)

class ArrowMark extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var rad := minf(size.x, size.y) * 0.28
		draw_arc(c, rad, 0.6, 5.3, 24, Color("#3C3228"), 4.0, true)
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(rad * 0.2, -rad * 0.95),
			c + Vector2(rad * 0.95, -rad * 0.15),
			c + Vector2(rad * 0.15, rad * 0.15)]), Color("#3C3228"))
