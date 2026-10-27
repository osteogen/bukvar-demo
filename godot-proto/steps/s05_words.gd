## Сцена 5 (была 4; с 27.10.2026 идёт ПОСЛЕ «на слух»). Звук [а] в словах: на каждое слово приезжает паровозик, ребёнок
## нажимает картинку и сажает кружок в окошко (начало — середина — конец). Поезд уезжает ТОЛЬКО после верного ответа ребёнка.
## Правки урока А (27.10.2026):
##  • паровозик въезжает СРАЗУ (вступление звучит, пока он едет), зеркально — справа налево (words.train.direction "rtl");
##  • перестук колёс на въезде и выезде (sfx_train_clack);
##  • слова перемешаны (первым — простое слово со звуком в начале, для подсказки «в начало — в паровоз»), +2 слова со
##    звуком НЕ в начале (мак, шар — уже нарисованы); «астра» — второй красный кружок в конце слова;
##  • внизу с самого начала видны пустые ячейки по числу слов; отгаданная карточка улетает в следующую ячейку;
##    в конце нажатие на карточку в ячейке — слово голосом;
##  • подсказки (рука, искры у верного окошка) — только после 20 с бездействия (без мерцания/руки сразу после ошибок);
##  • после последнего слова поезд уезжает, и одновременно по рельсам въезжают буквы А и а и встают по центру
##    над рельсами; нажатие на букву — «А-а-а!» (a_aaa);
##  • медленные облака (трава убрана — правка Романа 27.10, rev2);
##  • вагоны — готовые файлы носом влево ui_train_*_right (words.train.pre_mirrored), код их не отражает.
## Рельсы — на всю ширину экрана (любое соотношение сторон, плитка ui_train_rails без растяжения).
## Раскладка и графика — из данных (words.train в lesson.json). Правило «без автоподтверждения» — DESIGN_RULES.md, §1.
extends LessonStep

var field: Control          # поезд и рельсы; без обрезки по сцене — едут по всей видимой ширине (кнопки — в углах, выше/ниже пути)
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
var _rtl := false           # words.train.direction == "rtl"
var rails: Control

func _process(dt: float) -> void:
	_wind(dt)
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
	_rtl = String(tc.get("direction", "ltr")) == "rtl"
	_add_clouds()
	field = Control.new()
	field.name = "train_field"
	field.size = Vector2(1024, 768)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field)
	_add_rails(tc)
	var items: Array = _ordered_items()
	main.set_info("s05_order", items.map(func(x): return x.word))
	_add_cells(items.size())
	var pc := Vector2(tc.pic_center[0], tc.pic_center[1])
	var psz := Vector2(tc.pic_size[0], tc.pic_size[1])
	var intro_pending := true
	for i in items.size():
		var it: Dictionary = items[i]
		# 1) приезжает поезд (справа, колёса подпрыгивают, стучат); окошки пока не нажимаются
		var slots := _make_train(tc)
		for s in slots:
			s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		main.set_state("drive_in_%d" % i)
		var vis := _vis_x()
		train.position.x = (vis.y + 8.0) if _rtl else (vis.x - train.size.x - 8.0)   # целиком за краем экрана
		_last_x = train.position.x
		main.set_info("s05_drive_in", _drive_info(train.position.x, _parked_x(tc), vis))
		Voice.sfx(String(tc.get("clack_sfx", "sfx_train_clack")))
		if intro_pending:
			# первый поезд въезжает сразу, вступление Али звучит в это время (очередь голоса не даст наложиться)
			intro_pending = false
			say(cfg.intro)
		if not await _drive(train, _parked_x(tc), _drive_sec(tc, "drive_in_sec", 1.8, absf(_parked_x(tc) - train.position.x)), Tween.EASE_OUT): return
		# 2) картинка слова
		var pic := add_pic(it.pic, pc, psz)
		if not String(it.pic).begins_with("pic_alya_card"):   # у портрета Али своя рамка
			add_card_frame(pic)
		pic.set_meta("word_card", it.word)
		main.expose("pic", pic)
		pop_in(pic)
		main.set_info("s05_cards_visible", _count_cards())   # тест: вверху ровно одна карточка — текущего слова
		main.set_info("s05_word", it.word)
		main.hint_start(func(): return pic, "h_tap_01")
		main.set_state("wait_pic_%d" % i)
		if not await tapped(pic): return
		main.hint_stop()
		animate_frames(pic, it.pic)
		if not await say(it.voice): return
		pic.pressed.connect(func(): animate_frames(pic, it.pic); tap_say(it.voice))
		# 3) кружок(и)-звук и окошки: у слова может быть несколько мест звука (words.items[].pos — число или список)
		for k in slots.size():
			slots[k].mouse_filter = Control.MOUSE_FILTER_STOP
			bind_pick(slots[k], k)
			main.expose("slot%d" % k, slots[k])
		var positions: Array = it.pos if it.pos is Array else [it.pos]
		var first := true
		for pos_v in positions:
			var pos := int(pos_v)
			var dc := Vector2(tc.dot_center[0], tc.dot_center[1])
			var dsz := Vector2(78, 78)
			if tc.has("dot_size"):
				dsz = Vector2(tc.dot_size[0], tc.dot_size[1])
			var circ := add_pic(String(Assets.lesson.get("sound_dot", "ui_circle_flat")), dc, dsz, false)   # плоский матовый кружок-звук с чёрной А
			circ.name = "sound_dot"
			pop_in(circ)
			var right: Control = slots[pos]
			main.set_info("s05_right", pos)   # тест раскладки: какое окошко верное
			if i == 0 and first:
				if not await say(cfg.slot_hint): return
			elif not first:
				if not await say(String(it.get("second_line", cfg.get("second_line", "")))): return
			first = false
			var errors := 0
			# рука и искры у верного окошка — только после 20 с бездействия
			main.hint_start(func(): return right, "h_tap_01", Callable(), func(): _sparks(right))
			main.set_state("wait_slot_%d" % i if positions.size() == 1 or pos == int(positions[0]) else "wait_slot2_%d" % i)
			while true:
				var k = await picked
				if dead: return
				if k == pos:
					break
				if bool(it.get("end_ok", false)) and k == slots.size() - 1:
					# «Аля»: в конце тоже слышится гласный — не ошибка, без sfx_try
					pulse(slots[k], 1)
					main.log_event("end_ok", {"word": it.word})
					if not await say(cfg.end_ok_line): return
					continue
				if k != pos and positions.has(k) and slots[k].has_node("sound_dot"):
					continue   # окошко уже с кружком (астра: первый кружок уже в начале)
				errors += 1
				main.set_info("s05_errors", errors)
				shake(slots[k], null, false)   # вагон покачивается, без крестиков
				Voice.sfx("sfx_try")
				if not await say(String(it.get("stretch", it.voice))): return   # повтор слова с протяжкой
				# после ошибок ничего не подсвечиваем сразу: рука и искры появятся сами через 20 с бездействия
			# верно: кружок садится в окошко
			main.hint_stop()
			var win: Array = right.get_meta("window")
			var spot := right.position + Vector2(right.size.x * float(win[0]), right.size.y * float(win[1]))
			circ.reparent(right)    # кружок едет вместе с вагоном
			var tw := circ.create_tween()
			tw.tween_property(circ, "position", spot - right.position - circ.size / 2, 0.35).set_trans(Tween.TRANS_BACK)
			Voice.sfx("sfx_ok")
		for s in slots:
			s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		main.set_state("ok_%d" % i)
		if not await praise(): return
		# 5) карточка отгаданного слова улетает в свою ячейку внизу; поезд уезжает
		main.set_state("drive_out_%d" % i)
		main.expose("pic", null)
		_card_to_cell(pic, i, it)
		var vo := _vis_x()
		var out_x := (vo.x - train.size.x - 8.0) if _rtl else (vo.y + 8.0)                 # целиком за другим краем
		main.set_info("s05_drive_out", _drive_info(train.position.x, out_x, vo))
		var last := i == items.size() - 1
		Voice.sfx(String(tc.get("clack_sfx", "sfx_train_clack")))
		if last:
			_letters_ride_in()      # буквы въезжают по рельсам одновременно с отъездом последнего поезда
		if not await _drive(train, out_x, _drive_sec(tc, "drive_out_sec", 1.6, absf(out_x - train.position.x)), Tween.EASE_IN): return
		train.queue_free()
		for k in slots.size():
			main.expose("slot%d" % k, null)
		await get_tree().process_frame
		if dead: return
		main.set_info("s05_cards_visible", _count_cards())   # тест: 0 — вверху карточки прошлого слова нет
		main.set_info("s05_left", i)
	# конец: карточки в ячейках и буквы на рельсах нажимаются
	for c in _cells:
		var card: Control = c.get_meta("card", null)
		if card:
			card.mouse_filter = Control.MOUSE_FILTER_STOP
	main.set_state("letters_in")
	await _letters_done()
	if dead: return
	if not await say(cfg.summary): return
	finish()

# ---------- перемешивание слов ----------
## Слова перемешиваются; первым ставим слово с меткой first_ok (простое, звук в начале) — к нему подсказка «в начало —
## в паровоз». ?words_order=аист,мак,… (тест) — точный порядок.
func _ordered_items() -> Array:
	var items: Array = (cfg.items as Array).duplicate()
	var forced := String(Assets.params.get("words_order", ""))
	if forced != "":
		var out: Array = []
		for w in forced.split(","):
			for it in items:
				if String(it.word) == w:
					out.append(it)
		if out.size() == items.size():
			return out
	items.shuffle()
	if bool(cfg.get("shuffle_first_simple", true)):
		for j in items.size():
			if bool(items[j].get("first_ok", false)):
				var f = items[j]
				items.remove_at(j)
				items.push_front(f)
				break
	return items

# ---------- ячейки внизу ----------
var _cells: Array = []

func _add_cells(n: int) -> void:
	var cc: Dictionary = cfg.get("cells", {})
	var csz := float(cc.get("size", 112))
	var step := float(cc.get("step", 132))
	var y := float(cc.get("y", 650))
	var x0 := 512.0 - step * (n - 1) / 2.0
	for i in n:
		var p := Panel.new()
		p.name = "cell_%d" % i
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(String(cc.get("color", "#F7F0DE")))
		sb.bg_color.a = float(cc.get("alpha", 0.55))
		sb.border_color = Color(String(cc.get("border", "#B9A27A")))
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(int(csz * 0.16))
		p.add_theme_stylebox_override("panel", sb)
		p.size = Vector2(csz, csz)
		p.position = Vector2(x0 + i * step - csz / 2, y - csz / 2)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(p)
		_cells.append(p)
		main.expose("cell%d" % i, p)
	main.set_info("s05_cells", n)

## Карточка улетает в ячейку i и уменьшается до её размера; потом (в конце сцены) нажатие — слово голосом.
func _card_to_cell(pic: TextureButton, i: int, it: Dictionary) -> void:
	if i >= _cells.size():
		pic.queue_free()
		return
	var cell: Control = _cells[i]
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in pic.pressed.get_connections():
		pic.pressed.disconnect(c.callable)
	pic.remove_meta("word_card")
	pic.set_meta("cell_card", it.word)
	var inner := cell.size.x * 0.86
	var k := inner / pic.size.x
	var to := cell.position + cell.size / 2 - pic.size / 2
	var tw := pic.create_tween().set_parallel()
	tw.tween_property(pic, "position", to, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(pic, "scale", Vector2(k, k), 0.6)
	cell.set_meta("card", pic)
	pic.name = "cell_card_%d" % i
	var voice := String(it.get("cell_voice", it.voice))
	pic.pressed.connect(func():
		animate_frames(pic, it.pic)
		tap_say(voice)
		main.set_info("s05_cell_tap", it.word))
	main.expose("cell_card%d" % i, pic)

# ---------- конец: буквы на рельсах ----------
var _end_letters: Array = []
var _letters_parked := 0

func _letters_ride_in() -> void:
	var ec: Dictionary = cfg.get("end_letters", {})
	var ry := float(_tc.rails_y)
	var vis := _vis_x()
	var spec := [[Assets.lesson.get("big", "А"), float(ec.get("big_h", 200)), float(ec.get("big_x", 430))],
		[Assets.lesson.get("small", "а"), float(ec.get("small_h", 140)), float(ec.get("small_x", 600))]]
	for j in spec.size():
		var ch := String(spec[j][0])
		var l := add_letter(ch, Vector2.ZERO, int(spec[j][1]))
		l.name = "ride_letter_%s" % ("big" if j == 0 else "small")
		var stop := Vector2(float(spec[j][2]) - l.size.x / 2, ry - l.size.y + float(ec.get("sink", 6)))
		var from_x := (vis.y + 20.0 + j * 140.0) if _rtl else (vis.x - l.size.x - 20.0 - (1 - j) * 140.0)
		l.position = Vector2(from_x, stop.y)
		var b := tap_area(l)
		b.name = "ride_tap_%s" % ("big" if j == 0 else "small")
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_end_letters.append([l, b])
		var sec := float(ec.get("ride_sec", 2.0)) + j * 0.35
		var tw := l.create_tween()
		tw.tween_property(l, "position:x", stop.x, sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(b, "position:x", stop.x, sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		# лёгкое покачивание «на ходу», как вагоны
		var bob := l.create_tween().set_loops(int(sec / 0.24))
		bob.tween_property(l, "rotation", 0.03, 0.12)
		bob.tween_property(l, "rotation", -0.03, 0.12)
		tw.tween_callback(func():
			l.rotation = 0.0
			b.mouse_filter = Control.MOUSE_FILTER_STOP
			_letters_parked += 1)
		b.pressed.connect(func():
			pulse(l, 1)
			tap_say(String(ec.get("tap_line", "a_aaa")), float(ec.get("tap_max_sec", 2.0)))
			main.set_info("s05_letter_tap", ch))

func _letters_done() -> void:
	while _letters_parked < _end_letters.size() and not dead:
		await get_tree().process_frame
	if dead: return
	for e in _end_letters:
		main.expose(String(e[1].name), e[1])
	main.set_info("s05_letters_in", _end_letters.map(func(e): return [e[0].get_global_rect().get_center().x, e[0].get_global_rect().get_center().y, e[0].get_global_rect().size.y]))

# ---------- подсказка-искры (только через 20 с бездействия, вместе с рукой) ----------
func _sparks(target: Control) -> void:
	if not is_instance_valid(target):
		return
	burst(get_global_transform().affine_inverse() * target.get_global_rect().get_center())
	main.set_info("s05_sparks", int(main.info.get("s05_sparks", 0)) + 1)

# ---------- облака ----------
var _clouds: Array = []
var _wind_t := 0.0

func _add_clouds() -> void:
	var cl: Array = cfg.get("clouds", [])
	for c in cl:
		var r := TextureRect.new()
		r.texture = Assets.tex(String(c.id), false)
		if r.texture == null:
			continue
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.size = Vector2(c.size[0], c.size[1])
		r.position = Vector2(float(c.x), float(c.y))
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_meta("no_overlap_check", true)
		r.set_meta("speed", float(c.get("speed", 6)))
		r.modulate.a = float(c.get("alpha", 1.0))
		r.name = "cloud_%d" % _clouds.size()
		add_child(r)
		_clouds.append(r)
	main.set_info("s05_clouds", _clouds.size())

## Ветер: облака плывут медленно (с переходом через край).
func _wind(dt: float) -> void:
	_wind_t += dt
	var vis := _vis_x()
	for c in _clouds:
		if not is_instance_valid(c):
			continue
		c.position.x -= float(c.get_meta("speed")) * dt
		if c.position.x + c.size.x < vis.x - 10.0:
			c.position.x = vis.y + 10.0

## Для теста: сколько карточек слов сейчас видно (после отъезда поезда — 0: карточка прошлого слова не остаётся).
func _count_cards() -> int:
	var n := 0
	for c in find_children("*", "TextureButton", true, false):
		if c.has_meta("word_card") and not c.is_queued_for_deletion() and c.is_visible_in_tree() and c.modulate.a > 0.05:
			n += 1
	return n

## Видимая ширина экрана в координатах шага: Vector2(левый край, правый край).
func _vis_x() -> Vector2:
	var v: Rect2 = main.visible_rect_local()
	return Vector2(minf(0.0, v.position.x), maxf(1024.0, v.end.x))

## Время проезда: drive_*_sec задано для пути по сцене 1024 (въезд от x = −ширина состава до stop_x, выезд от stop_x
## до 1024); на широком экране путь длиннее — время растёт так, чтобы скорость была та же.
func _drive_sec(tc: Dictionary, key: String, def: float, dist: float) -> float:
	var w := _train_width(tc)
	var px := _parked_x(tc)
	var ref := (px + w) if key == "drive_in_sec" else (1024.0 - px)
	if _rtl:
		ref = (1024.0 - px) if key == "drive_in_sec" else (px + w)
	return float(tc.get(key, def)) * maxf(1.0, dist / maxf(1.0, ref))

func _drive_info(from_x: float, to_x: float, vis: Vector2) -> Dictionary:
	return {"from": from_x, "to": to_x, "w": train.size.x, "vis_l": vis.x, "vis_r": vis.y, "dir": "rtl" if _rtl else "ltr"}

## Рельсы на всю видимую ширину экрана (ui_train_rails — плиткой, масштаб одинаковый по x и y, без растяжения);
## нет файла — простая заглушка: брусок и шпалы. При смене размера окна — relayout() растягивает путь заново.
func _add_rails(tc: Dictionary) -> void:
	var y := float(tc.rails_y)
	var h := float(tc.get("rails_h", 34))
	var t := Assets.tex(String(tc.get("rails", "ui_train_rails")), false)
	if rails and is_instance_valid(rails):
		rails.queue_free()
	var vis := _vis_x()
	if t:
		var k := h / float(t.get_height())
		var tw := float(t.get_width()) * k            # ширина одной плитки в координатах сцены
		var x0 := floorf(vis.x / tw) * tw              # шов плиток привязан к x = 0 сцены
		var r := TextureRect.new()
		r.name = "rails"
		r.texture = t
		r.stretch_mode = TextureRect.STRETCH_TILE
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.size = Vector2(ceilf((vis.y - x0) / tw) * float(t.get_width()), t.get_height())
		r.scale = Vector2(k, k)
		r.position = Vector2(x0, y)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		field.add_child(r)
		field.move_child(r, 0)
		rails = r
		main.set_info("s05_rails", {"x0": x0, "x1": x0 + r.size.x * k, "kx": k, "ky": k, "tile_w": tw})
		return
	var box := Control.new()
	box.name = "rails"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(box)
	field.move_child(box, 0)
	rails = box
	var bar := ColorRect.new()
	bar.color = Color("#8E6238")
	bar.position = Vector2(vis.x, y)
	bar.size = Vector2(vis.y - vis.x, h * 0.28)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	var x := floorf(vis.x / 64.0) * 64.0 + 8.0
	while x < vis.y:
		var sl := ColorRect.new()
		sl.color = Color("#B98650")
		sl.position = Vector2(x, y + h * 0.28)
		sl.size = Vector2(36, h * 0.6)
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(sl)
		x += 64.0
	main.set_info("s05_rails", {"x0": vis.x, "x1": vis.y, "kx": 1.0, "ky": 1.0, "tile_w": 64.0})

## Окно поменяло размер (поворот планшета, другое соотношение сторон) — путь снова от края до края.
func relayout() -> void:
	super.relayout()
	if field and is_instance_valid(field) and not _tc.is_empty():
		_add_rails(_tc)

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
	train.position = Vector2(-train.size.x - 40.0, float(tc.y))   # точный старт за краем экрана — в run()
	field.add_child(train)
	main.expose("train", train)   # тест: центр состава — откуда въезжает и куда уезжает поезд
	parts.clear()
	for j in tc.parts.size():
		var pd: Dictionary = tc.parts[j]
		var id := String(pd.id)
		var win: Array = pd.window.duplicate()
		var b := TextureButton.new()
		var t := Assets.tex(id)   # *_right — готовые файлы художника носом влево (раунд 14), без отражения
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
	if _rtl and not bool(tc.get("pre_mirrored", false)):
		_mirror_train()
		# зеркало: часть j теперь стоит на месте n−1−j; «начало» слова — по-прежнему левое окошко
		var n: int = parts.size()
		for s in tc.slots:
			out.append(parts[n - 1 - int(s)])
		return out
	for s in tc.slots:
		out.append(parts[int(s)])
	return out

## direction "rtl": состав зеркально (паровоз слева, носом влево) — части, окошки и колёса отражаются по ширине состава.
func _mirror_train() -> void:
	var w := train.size.x
	for c in train.get_children():
		var ctl := c as Control
		ctl.position.x = w - ctl.position.x - ctl.size.x
		if ctl is TextureButton:
			(ctl as TextureButton).flip_h = not (ctl as TextureButton).flip_h
			var win: Array = ctl.get_meta("window")
			win[0] = 1.0 - float(win[0])
			ctl.set_meta("window", win)
		elif ctl is TextureRect:
			(ctl as TextureRect).flip_h = not (ctl as TextureRect).flip_h

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
	var sx := float(sc.src[0])
	var dirx := 1.0
	if _rtl:   # паровоз носом влево: клубы уходят назад — вправо
		dirx = -1.0
		if not bool(_tc.get("pre_mirrored", false)):   # старые файлы отражены кодом — труба тоже
			sx = eng.size.x - sx
	var src: Vector2 = train.position + eng.position + Vector2(sx, sc.src[1])
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
	puff.position = src + Vector2(dirx * float(sc.offsets[0][0]), sc.offsets[0][1]) - sz0 / 2
	field.add_child(puff)
	var tw := puff.create_tween()
	var step := float(sc.get("step_sec", 0.45))
	for k in range(1, ids.size()):
		var szk := Vector2(sc.sizes[k][0], sc.sizes[k][1])
		var to := src + Vector2(dirx * float(sc.offsets[k][0]), sc.offsets[k][1]) - szk / 2
		tw.tween_callback(func(): puff.texture = Assets.tex(String(ids[k]), false))
		tw.parallel().tween_property(puff, "size", szk, step)
		tw.parallel().tween_property(puff, "position", to, step)
	tw.tween_property(puff, "modulate:a", 0.0, step)
	tw.tween_callback(puff.queue_free)
