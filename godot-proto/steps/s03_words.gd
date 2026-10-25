## Сцена 3. Звук [а] в словах: на каждое слово приезжает паровозик, ребёнок нажимает картинку и сажает кружок в окошко
## (начало — середина — конец, слева направо по вагонам). Поезд уезжает вправо ТОЛЬКО после верного ответа ребёнка,
## затем приезжает поезд со следующим словом. Для «Аля» кружок в конце — не ошибка: звучит a_words_end_ok.
## Раскладка и графика — из данных (words.train в lesson.json): финальные картинки, размеры и окошки художника
## подставляются без правки кода. Правило «без автоподтверждения» — DESIGN_RULES.md, §1.
extends LessonStep

var field: Control          # поезд и рельсы — внутри сцены 1024×768 (clip): при въезде/выезде не заходят под кнопки
var train: Control          # весь состав; ездит по x
var parts: Array = []       # части слева направо (TextureButton)
var _bob_t := 0.0
var _driving := false
var _bob_px := 3.0
var wheels: Array = []      # колёса — на узле поезда (не на качающихся телах), крутятся от пройденного пути
var _wheel_r := 24.0
var _last_x := 0.0
var _steam_t := 0.0
var _tc: Dictionary

func _process(dt: float) -> void:
	if train == null or not is_instance_valid(train):
		return
	# колёса: угол (рад) = путь / радиус качения (words.train.wheels.r)
	var dx := train.position.x - _last_x
	_last_x = train.position.x
	for w in wheels:
		if is_instance_valid(w):
			w.rotation += dx / _wheel_r
	_steam(dt)
	if not _driving:
		return
	_bob_t += dt
	for i in parts.size():   # колёса «подпрыгивают» — части чуть качаются вверх-вниз, вразнобой
		var p: Control = parts[i]
		p.position.y = p.get_meta("y0", 0.0) - absf(sin(_bob_t * 14.0 + i * 1.3)) * _bob_px

func run() -> void:
	section("words")
	add_bg(cfg.bg)
	var tc: Dictionary = cfg.train
	_tc = tc
	_bob_px = float(tc.get("bob_px", 3))
	field = Control.new()
	field.name = "train_field"
	field.size = Vector2(1024, 768)
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field)
	_add_rails(tc)
	if not await say(cfg.intro): return
	var items: Array = cfg.items
	var pc := Vector2(tc.pic_center[0], tc.pic_center[1])
	var psz := Vector2(tc.pic_size[0], tc.pic_size[1])
	for i in items.size():
		var it: Dictionary = items[i]
		# 1) приезжает поезд (слева, колёса подпрыгивают); окошки пока не нажимаются
		var slots := _make_train(tc)
		for s in slots:
			s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		main.set_state("drive_in_%d" % i)
		if not await _drive(train, _parked_x(tc), float(tc.get("drive_in_sec", 1.8)), Tween.EASE_OUT): return
		# 2) картинка слова
		var pic := add_pic(it.pic, pc, psz)
		if not String(it.pic).begins_with("pic_alya_card"):   # у портрета Али своя рамка
			add_card_frame(pic)
		pic.set_meta("word_card", it.word)
		main.expose("pic", pic)
		pop_in(pic)
		main.set_info("s03_cards_visible", _count_cards())   # тест: на сцене ровно одна карточка — текущего слова
		burst(pc, Color("#fffbd0"))
		main.hint_start(func(): return pic, "h_tap_01")
		main.set_state("wait_pic_%d" % i)
		if not await tapped(pic): return
		main.hint_stop()
		animate_frames(pic, it.pic)
		if not await say(it.voice): return
		pic.pressed.connect(func(): animate_frames(pic, it.pic); Voice.say(it.voice))
		# 3) кружок-звук и окошки
		for k in slots.size():
			slots[k].mouse_filter = Control.MOUSE_FILTER_STOP
			bind_pick(slots[k], k)
			main.expose("slot%d" % k, slots[k])
		var dc := Vector2(tc.dot_center[0], tc.dot_center[1])
		var dsz := Vector2(78, 78)
		if tc.has("dot_size"):
			dsz = Vector2(tc.dot_size[0], tc.dot_size[1])
		var circ := add_pic(String(Assets.lesson.get("sound_dot", "ui_circle_flat")), dc, dsz, false)   # плоский матовый кружок-звук (78 — под окошко r 44)
		pop_in(circ)
		var right: Control = slots[int(it.pos)]
		if i == 0:
			if not await say(cfg.slot_hint): return
		else:
			burst(get_global_transform().affine_inverse() * right.get_global_rect().get_center())
		var errors := 0
		main.hint_start(func(): return right, "h_tap_01")
		main.set_state("wait_slot_%d" % i)
		while true:
			var k = await picked
			if dead: return
			if k == int(it.pos):
				break
			if k == slots.size() - 1 and bool(it.get("end_ok", false)):
				# «Аля»: в конце тоже слышится гласный — не ошибка, без sfx_try
				pulse(slots[k], 1)
				main.log_event("end_ok", {"word": it.word})
				if not await say(cfg.end_ok_line): return
				main.hint_start(func(): return right, "h_tap_01")
				continue
			errors += 1
			shake(slots[k], null, false)   # вагон покачивается, без крестиков
			Voice.sfx("sfx_try")
			if not await say(it.voice): return   # повтор слова с протяжкой
			if errors >= 2:
				# после 2-й ошибки — только подсказка: нужный вагон мерцает, рука показывает на него.
				# Кружок не садится сам и поезд не уезжает: ждём верного нажатия ребёнка.
				pulse(right, 2)
				main.hint_now()
		# 4) верно: кружок садится в окошко, похвала, поезд уезжает вправо вместе с кружком
		main.hint_stop()
		for s in slots:
			s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var win: Array = right.get_meta("window")
		var spot := right.position + Vector2(right.size.x * float(win[0]), right.size.y * float(win[1]))
		circ.reparent(right)    # кружок едет вместе с вагоном
		var tw := circ.create_tween()
		tw.tween_property(circ, "position", spot - right.position - circ.size / 2, 0.35).set_trans(Tween.TRANS_BACK)
		Voice.sfx("sfx_ok")
		main.set_state("ok_%d" % i)
		if not await praise(): return
		# 5) карточка отгаданного слова уходит со сцены вместе с поездом: words.train.pic_leave —
		#    "fade" (тает, по умолчанию) или "ride" (уезжает вместе с поездом); к приезду следующего поезда её нет
		main.set_state("drive_out_%d" % i)
		main.expose("pic", null)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if String(tc.get("pic_leave", "fade")) == "ride":
			pic.reparent(train)
		else:
			var pt := pic.create_tween()
			pt.tween_property(pic, "modulate:a", 0.0, float(tc.get("pic_fade_sec", 0.5)))
		if not await _drive(train, 1024.0 + 40.0, float(tc.get("drive_out_sec", 1.6)), Tween.EASE_IN): return
		pic.hide()
		pic.queue_free()
		train.queue_free()
		for k in slots.size():
			main.expose("slot%d" % k, null)
		await get_tree().process_frame
		if dead: return
		main.set_info("s03_cards_visible", _count_cards())   # тест: 0 — карточка отгаданного слова ушла
		main.set_info("s03_left", i)
	if not await say(cfg.summary): return
	finish()

## Для теста: сколько карточек слов сейчас видно (после отъезда поезда — 0: карточка прошлого слова не остаётся).
func _count_cards() -> int:
	var n := 0
	for c in find_children("*", "TextureButton", true, false):
		if c.has_meta("word_card") and not c.is_queued_for_deletion() and c.is_visible_in_tree() and c.modulate.a > 0.05:
			n += 1
	return n

## Рельсы на всю ширину сцены (ui_train_rails, плитка); нет файла — простая заглушка: брусок и шпалы.
func _add_rails(tc: Dictionary) -> void:
	var y := float(tc.rails_y)
	var h := float(tc.get("rails_h", 34))
	var t := Assets.tex(String(tc.get("rails", "ui_train_rails")), false)
	if t:
		var k := h / float(t.get_height())
		var r := TextureRect.new()
		r.name = "rails"
		r.texture = t
		r.stretch_mode = TextureRect.STRETCH_TILE
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.size = Vector2(1024.0 / k, t.get_height())
		r.scale = Vector2(k, k)
		r.position = Vector2(0, y)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		field.add_child(r)
		return
	var bar := ColorRect.new()
	bar.name = "rails"
	bar.color = Color("#8E6238")
	bar.position = Vector2(0, y)
	bar.size = Vector2(1024, h * 0.28)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(bar)
	for x in range(8, 1024, 64):
		var s := ColorRect.new()
		s.color = Color("#B98650")
		s.position = Vector2(x, y + h * 0.28)
		s.size = Vector2(36, h * 0.6)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		field.add_child(s)

func _train_width(tc: Dictionary) -> float:
	var n: int = tc.parts.size()
	return n * float(tc.size[0]) + (n - 1) * float(tc.get("gap", 0))

func _parked_x(tc: Dictionary) -> float:
	if tc.has("stop_x"):
		return float(tc.stop_x)
	return round((1024.0 - _train_width(tc)) / 2.0)

## Состав из частей words.train.parts (слева направо); возвращает окошки в порядке [начало, середина, конец] (words.train.slots).
func _make_train(tc: Dictionary) -> Array:
	train = Control.new()
	train.name = "train"
	train.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sz := Vector2(tc.size[0], tc.size[1])
	train.size = Vector2(_train_width(tc), sz.y)
	train.position = Vector2(-train.size.x - 40.0, float(tc.y))
	field.add_child(train)
	main.expose("train", train)   # тест: центр состава — видно, что поезд въезжает слева и уезжает вправо
	parts.clear()
	for j in tc.parts.size():
		var pd: Dictionary = tc.parts[j]
		var id := String(pd.id)
		var win: Array = pd.window.duplicate()
		var b := TextureButton.new()
		var t := Assets.tex(id, false)
		if t == null and bool(tc.get("mirror_fallback", true)) and id.ends_with("_right"):
			# художник ещё не сдал вариант носом вправо — отражаем старую картинку (и окошко)
			t = Assets.tex(id.trim_suffix("_right"))
			b.flip_h = true
			win[0] = 1.0 - float(win[0])
		b.texture_normal = t
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.size = sz
		b.pivot_offset = sz / 2
		b.position = Vector2(j * (sz.x + float(tc.get("gap", 0))), 0)
		b.set_meta("y0", 0.0)
		b.set_meta("window", win)
		b.name = id
		train.add_child(b)
		parts.append(b)
	# колёса (words.train.wheels): поверх тел, на узле поезда — тела качаются (bob_px), колёса остаются на рельсах
	wheels.clear()
	var wc: Dictionary = tc.get("wheels", {})
	var wt := Assets.tex(String(wc.get("id", "ui_train_wheel")), false) if not wc.is_empty() else null
	if wt:
		_wheel_r = float(wc.get("r", 24))
		var wsz := Vector2(wc.size[0], wc.size[1])
		for j in parts.size():
			var xs: Array = wc.x[j] if j < wc.x.size() else []
			for wx in xs:
				var w := TextureRect.new()
				w.texture = wt
				w.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				w.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				w.size = wsz
				w.pivot_offset = wsz / 2
				w.position = Vector2((parts[j] as Control).position.x + float(wx), float(wc.y)) - wsz / 2
				w.mouse_filter = Control.MOUSE_FILTER_IGNORE
				w.name = "wheel_%d_%d" % [j, wheels.size()]
				train.add_child(w)
				wheels.append(w)
	_last_x = train.position.x
	var out: Array = []
	for s in tc.slots:
		out.append(parts[int(s)])
	return out

func _drive(n: Control, to_x: float, sec: float, ease: int) -> bool:
	_driving = true
	var tw := n.create_tween()
	tw.tween_property(n, "position:x", to_x, sec).set_trans(Tween.TRANS_SINE).set_ease(ease)
	await tw.finished
	_driving = false
	for p in parts:
		if is_instance_valid(p):
			p.position.y = p.get_meta("y0", 0.0)
	return not dead

## Пар из трубы паровоза (words.train.steam): клубы S → M → L поднимаются и уходят назад (влево); чаще, пока поезд едет.
func _steam(dt: float) -> void:
	var sc: Dictionary = _tc.get("steam", {})
	if sc.is_empty() or parts.is_empty():
		return
	_steam_t -= dt
	if _steam_t > 0.0:
		return
	_steam_t = float(sc.get("every_drive", 0.45)) if _driving else float(sc.get("every_idle", 1.6))
	var eng: Control = parts[int(sc.get("part", parts.size() - 1))]
	if not is_instance_valid(eng):
		return
	var src: Vector2 = train.position + eng.position + Vector2(sc.src[0], sc.src[1])
	var ids: Array = sc.ids
	var puff := TextureRect.new()
	puff.texture = Assets.tex(String(ids[0]), false)
	if puff.texture == null:
		return
	puff.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	puff.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	puff.mouse_filter = Control.MOUSE_FILTER_IGNORE
	puff.set_meta("no_overlap_check", true)   # декор: не предмет игры
	var sz0 := Vector2(sc.sizes[0][0], sc.sizes[0][1])
	puff.size = sz0
	puff.position = src + Vector2(sc.offsets[0][0], sc.offsets[0][1]) - sz0 / 2
	field.add_child(puff)
	var tw := puff.create_tween()
	var step := float(sc.get("step_sec", 0.45))
	for k in range(1, ids.size()):
		var szk := Vector2(sc.sizes[k][0], sc.sizes[k][1])
		var to := src + Vector2(sc.offsets[k][0], sc.offsets[k][1]) - szk / 2
		tw.tween_callback(func(): puff.texture = Assets.tex(String(ids[k]), false))
		tw.parallel().tween_property(puff, "size", szk, step)
		tw.parallel().tween_property(puff, "position", to, step)
	tw.tween_property(puff, "modulate:a", 0.0, step)
	tw.tween_callback(puff.queue_free)
