## Сцена 7 «У»: Найди пару (memory). Карточки на кремовом фоне; озвучка при открытии.
## Конец раунда: пары улетают в клетки-итоги внизу (ui_pair_slot), подпись, тап → повтор звука.
## Рука-подсказка — только после 20 с. Нет автоподтверждения.
extends LessonStep

var rounds: Array = []
var r_i := 0
var cards: Array = []          # {btn, face_id, back, face_node, open, matched, pair, wrap}
var first = null
var busy := false
var matched_n := 0
var need := 0
var found_order: Array = []    # face_id of first card of each matched pair, in find order
var slots_host: Control = null
var round_done := false

const SLOT_LABELS := {
	"letter_U": "У", "letter_u": "у", "letter_A": "А", "letter_a": "а",
	"pic_utka": "Утка", "pic_ukho": "Ухо", "pic_udochka": "Удочка",
	"pic_ulei": "Улей", "pic_aist": "Аист", "pic_astra": "Астра",
}

func run() -> void:
	section("memory")
	rounds = cfg.get("rounds", [])
	add_bg(String(cfg.get("bg", "bg_meadow")))
	if cfg.get("intro", "") != "":
		if not await say(String(cfg.intro)): return
	await _round()

func _round() -> void:
	if dead: return
	for c in get_children():
		if String(c.name).begins_with("dyn_"):
			c.queue_free()
	await get_tree().process_frame
	if r_i >= rounds.size():
		if not await praise(): return
		finish()
		return
	var rd: Dictionary = rounds[r_i]
	cards.clear()
	first = null
	busy = false
	matched_n = 0
	found_order.clear()
	round_done = false
	slots_host = null
	var pairs: Array = rd.pairs
	need = pairs.size()
	var deck: Array = []
	for pi in pairs.size():
		var p: Array = pairs[pi]
		deck.append({"id": String(p[0]), "pair": pi})
		deck.append({"id": String(p[1]), "pair": pi})
	deck.shuffle()
	# avoid adjacent same-pair (best effort)
	for _attempt in 8:
		var bad := false
		var cols_try := int(rd.get("cols", 3))
		for i in deck.size():
			for j in deck.size():
				if i == j: continue
				if int(deck[i].pair) != int(deck[j].pair): continue
				var ci := i % cols_try
				var ri := i / cols_try
				var cj := j % cols_try
				var rj := j / cols_try
				if abs(ci - cj) + abs(ri - rj) == 1:
					bad = true
					break
			if bad: break
		if not bad: break
		deck.shuffle()
	var cols := int(rd.get("cols", 3))
	var csz := Vector2(float(cfg.get("card_size", [160, 160])[0]), float(cfg.get("card_size", [160, 160])[1]))
	var gap := 16.0
	var rows := int(ceil(float(deck.size()) / cols))
	var grid_w := cols * csz.x + (cols - 1) * gap
	var grid_h := rows * csz.y + (rows - 1) * gap
	var origin := Vector2(512 - grid_w / 2, 100)
	main.set_state("memory_r%d" % r_i)
	for i in deck.size():
		var col := i % cols
		var row := i / cols
		var pos := origin + Vector2(col * (csz.x + gap), row * (csz.y + gap))
		var wrap := Control.new()
		wrap.name = "dyn_card_%d" % i
		wrap.position = pos
		wrap.size = csz
		add_child(wrap)
		var back := ColorRect.new()
		back.color = Assets.CREAM
		back.size = csz
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(back)
		var star := Label.new()
		star.text = "★"
		star.add_theme_font_size_override("font_size", 48)
		star.add_theme_color_override("font_color", Assets.MUSTARD)
		star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		star.size = csz
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(star)
		var face_id := String(deck[i].id)
		var face: Control
		if face_id.begins_with("letter_"):
			var ch := _letter_ch(face_id)
			var lab := Label.new()
			lab.text = ch
			lab.add_theme_font_size_override("font_size", int(csz.y * 0.55))
			lab.add_theme_color_override("font_color", Assets.VOWEL_RED)
			lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lab.size = csz
			lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
			wrap.add_child(lab)
			face = lab
		else:
			var tr := TextureRect.new()
			tr.texture = Assets.tex(face_id)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.size = csz
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			wrap.add_child(tr)
			face = tr
		face.visible = false
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.size = csz
		btn.position = Vector2.ZERO
		for st in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		wrap.add_child(btn)
		var entry := {"btn": btn, "face_id": face_id, "face": face, "back": back, "star": star, "open": false, "matched": false, "pair": int(deck[i].pair), "wrap": wrap}
		btn.pressed.connect(_flip.bind(entry))
		cards.append(entry)
	main.expose("card0", cards[0].btn)
	main.hint_start(func(): return _hint_card(), "h_tap_01")
	main.set_state("wait_pair")

func _letter_ch(face_id: String) -> String:
	match face_id:
		"letter_U": return "У"
		"letter_u": return "у"
		"letter_A": return "А"
		"letter_a": return "а"
		_:
			return "У" if ("U" in face_id or "u" in face_id) else "А"

func _hint_card() -> Control:
	if round_done:
		if slots_host and slots_host.get_child_count() > 0:
			var first_slot = slots_host.get_child(0)
			if first_slot.has_meta("hit"):
				return first_slot.get_meta("hit")
		return null
	for c in cards:
		if not c.matched and not c.open:
			return c.btn
	return null

func _flip(entry: Dictionary) -> void:
	if busy or entry.matched or entry.open or dead or round_done:
		return
	main.hint_stop()
	entry.open = true
	entry.face.visible = true
	entry.star.visible = false
	_speak(String(entry.face_id))
	if first == null:
		first = entry
		main.hint_start(func(): return _hint_card(), "h_tap_01")
		return
	busy = true
	if int(first.pair) == int(entry.pair):
		first.matched = true
		entry.matched = true
		matched_n += 1
		found_order.append(String(first.face_id))
		Voice.sfx("sfx_ok")
		burst(entry.wrap.position + entry.wrap.size / 2, Assets.MUSTARD)
		# replay sound of the pair
		_speak(String(entry.face_id))
		first = null
		busy = false
		if matched_n >= need:
			await wait(0.4)
			await _fly_to_slots()
		else:
			main.hint_start(func(): return _hint_card(), "h_tap_01")
	else:
		# разведка — без sfx_try
		await wait(1.0)
		if dead: return
		for e in [first, entry]:
			e.open = false
			e.face.visible = false
			e.star.visible = true
		first = null
		busy = false
		main.hint_start(func(): return _hint_card(), "h_tap_01")

func _fly_to_slots() -> void:
	if dead: return
	round_done = true
	main.hint_stop()
	Voice.sfx("sfx_cheer")
	# wave bounce
	for c in cards:
		if not c.matched: continue
		var tw := create_tween()
		tw.tween_property(c.wrap, "position:y", c.wrap.position.y - 18, 0.12)
		tw.tween_property(c.wrap, "position:y", c.wrap.position.y, 0.12)
		await wait(0.04)
	await wait(0.25)
	# build slots host
	var n := found_order.size()
	var slot_sz := 160.0 if n > 3 else 180.0
	var gap := 16.0
	var cols := mini(n, 3) if n > 3 else n
	var rows := int(ceil(float(n) / cols))
	var grid_w := cols * slot_sz + (cols - 1) * gap
	var origin := Vector2(512 - grid_w / 2, 768 - 40 - rows * (slot_sz + 48) - (rows - 1) * gap)
	slots_host = Control.new()
	slots_host.name = "dyn_slots"
	add_child(slots_host)
	# hide unmatched backs already gone; fly matched cards one by one
	var slot_i := 0
	var seen_pairs: Dictionary = {}
	for c in cards:
		if not c.matched: continue
		var pid := int(c.pair)
		if seen_pairs.has(pid): continue
		seen_pairs[pid] = true
		var face_id := String(found_order[slot_i] if slot_i < found_order.size() else c.face_id)
		var col := slot_i % cols
		var row := slot_i / cols
		var target := origin + Vector2(col * (slot_sz + gap), row * (slot_sz + 48 + gap))
		var slot := _make_slot(face_id, slot_sz)
		slot.position = target
		slot.modulate.a = 0.0
		slots_host.add_child(slot)
		# fly both matched wraps toward slot
		for e in cards:
			if int(e.pair) != pid: continue
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(e.wrap, "position", target + Vector2(8, 8), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(e.wrap, "scale", Vector2(0.35, 0.35), 0.45)
			tw.tween_property(e.wrap, "modulate:a", 0.0, 0.45)
		Voice.sfx("sfx_ok")
		await wait(0.5)
		slot.modulate.a = 1.0
		slot_i += 1
	# hide old cards
	for c in cards:
		c.wrap.visible = false
	main.expose("slot0", slots_host.get_child(0).get_meta("hit") if slots_host.get_child_count() > 0 else null)
	# first round: hint tap on slot once
	if r_i == 0:
		main.hint_start(func(): return _hint_card(), "")
	await wait(1.5)
	if dead: return
	# Далее между раундами: временно отвязать next_step, иначе уйдём со сцены
	if main.next_btn.pressed.is_connected(main.next_step):
		main.next_btn.pressed.disconnect(main.next_step)
	main.show_next(true)
	main.set_state("round_slots")
	var advanced := false
	var on_next := func():
		advanced = true
	main.next_btn.pressed.connect(on_next, CONNECT_ONE_SHOT)
	while not dead and not advanced:
		await get_tree().process_frame
	if dead: return
	main.show_next(false)
	if not main.next_btn.pressed.is_connected(main.next_step):
		main.next_btn.pressed.connect(main.next_step)
	main.hint_stop()
	r_i += 1
	await _round()

func _make_slot(face_id: String, sz: float) -> Control:
	var wrap := Control.new()
	wrap.size = Vector2(sz, sz + 40)
	var plate := ColorRect.new()
	plate.color = Assets.CREAM
	plate.size = Vector2(sz, sz)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(plate)
	var face: Control
	if face_id.begins_with("letter_"):
		var lab := Label.new()
		lab.text = _letter_ch(face_id)
		lab.add_theme_font_size_override("font_size", int(sz * 0.55))
		lab.add_theme_color_override("font_color", Assets.VOWEL_RED)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.size = Vector2(sz, sz)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(lab)
		face = lab
	else:
		var tr := TextureRect.new()
		tr.texture = Assets.tex(face_id)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size = Vector2(sz, sz)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(tr)
		face = tr
	var word := String(SLOT_LABELS.get(face_id, ""))
	var caption := RichTextLabel.new()
	caption.bbcode_enabled = true
	caption.fit_content = true
	caption.scroll_active = false
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.size = Vector2(sz, 36)
	caption.position = Vector2(0, sz + 2)
	if word.length() <= 1:
		caption.text = "[center][color=#D93A2B]%s[/color][/center]" % word
	else:
		var first_ch := word.substr(0, 1)
		var rest := word.substr(1)
		caption.text = "[center][color=#D93A2B]%s[/color][color=#B49C82]%s[/color][/center]" % [first_ch, rest]
	wrap.add_child(caption)
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.size = Vector2(sz, sz + 40)
	for st in ["normal", "hover", "pressed", "focus"]:
		hit.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	wrap.add_child(hit)
	wrap.set_meta("hit", hit)
	wrap.set_meta("face_id", face_id)
	hit.pressed.connect(func():
		var tw := create_tween()
		tw.tween_property(wrap, "position:y", wrap.position.y - 10, 0.1)
		tw.tween_property(wrap, "position:y", wrap.position.y, 0.1)
		_speak(face_id)
	)
	return wrap

func _speak(face_id: String) -> void:
	var m: Dictionary = cfg.get("audio_map", {})
	var id := String(m.get(face_id, ""))
	if id == "a_aaa" and Assets.sound(id) == null:
		id = String(cfg.get("letter_A_fallback", "a_find_03"))
	if id == "a_word_04_short" and Assets.sound(id) == null:
		id = "a_word_04"
	if id != "":
		tap_say(id)
