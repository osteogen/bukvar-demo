## Сцена 4 (с 27.10.2026 идёт ДО паровозика). Слышу [а] или нет: Аля говорит «нажми на красный кружок… если не
## услышишь — на серый». «Да» — красный круг (#D93A2B) с чёрной «А» (общее правило: на каждом красном кружке — буква
## урока чёрным, LessonStep.dot_letter), «нет» — серый круг с тёмно-серым крестиком (не красным).
## Правки урока А (27.10.2026):
##  • во время задания Аля стоит в центре и показывает руками: на «красный кружок» — рукой к красному (слева),
##    на «серый» — к серому (справа); потом уходит, и в центр выходит первая карточка (hear.alya);
##  • отвеченные карточки уезжают наверх: слева — слова СО звуком [а], справа — БЕЗ звука; касание карточки — слово;
##  • в конце — слово «аплодисменты» (первая «а» красная) голосом Али, хлопушка и искры (hear.applause);
##  • подсказки (рука) — только через 20 с бездействия, и после ошибок тоже (main.hint_now только перезапускает отсчёт).
extends LessonStep

func run() -> void:
	section("hear")
	add_bg(cfg.bg)
	var yes := add_pic(String(cfg.get("yes_pic", "ui_hear_yes")), Vector2(330, 620), Vector2(170, 170))
	var no := add_pic(String(cfg.get("no_pic", "ui_hear_no")), Vector2(694, 620), Vector2(170, 170))
	bind_pick(yes, true)
	bind_pick(no, false)
	main.expose("yes", yes)
	main.expose("no", no)
	yes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	no.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Аля в центре показывает руками, какой кружок нажимать (тайминги — hear.alya.point_*, от начала реплики)
	var ac: Dictionary = cfg.get("alya", {})
	var alya: Cutout = add_character(String(ac.get("who", "alya")), Vector2(ac.center[0], ac.center[1]), Vector2(ac.size[0], ac.size[1]))
	alya.name = "hear_alya"
	main.expose("alya", alya)
	var gest := create_tween()
	gest.tween_interval(float(ac.get("point_yes_at", 2.6)) * (0.1 if Assets.flag("fast") else 1.0))
	gest.tween_callback(func():
		alya.raise_arm("l", float(ac.get("hold_sec", 1.8)), float(ac.get("point_angle", 1.25)), "point_red")
		pulse(yes, 2)
		main.set_info("s04_alya_point", "yes"))
	gest.tween_interval(float(ac.get("point_no_at", 5.0)) * (0.1 if Assets.flag("fast") else 1.0) - float(ac.get("point_yes_at", 2.6)) * (0.1 if Assets.flag("fast") else 1.0))
	gest.tween_callback(func():
		alya.raise_arm("r", float(ac.get("hold_sec", 1.8)), float(ac.get("point_angle", 1.25)), "point_grey")
		pulse(no, 2)
		main.set_info("s04_alya_point_no", "no"))
	if not await say(cfg.intro): return
	if gest.is_running():
		await gest.finished
	if dead: return
	# Аля уходит со сцены — центр свободен для карточек
	var ta := alya.create_tween().set_parallel()
	ta.tween_property(alya, "modulate:a", 0.0, 0.35)
	ta.tween_property(alya, "position:y", alya.position.y + 40.0, 0.35)
	await ta.finished
	if dead: return
	alya.queue_free()
	main.expose("alya", null)
	yes.mouse_filter = Control.MOUSE_FILTER_STOP
	no.mouse_filter = Control.MOUSE_FILTER_STOP
	var items: Array = cfg.items
	for i in items.size():
		var it: Dictionary = items[i]
		var pic := add_pic(it.pic, Vector2(512, 300), Vector2(300, 300))
		add_card_frame(pic)   # большая рамка сцены 4
		pic.pressed.connect(_on_card.bind(pic))
		pic.set_meta("word_audio", String(it.get("word_audio", it.voice)))
		pic.set_meta("word_card", true)
		pop_in(pic)
		if not await say(it.voice): return
		var errors := 0
		main.hint_start(func(): return _alt(yes, no), it.voice)
		main.expose("pic", pic)
		main.set_info("s04_card", _rect_info(pic))   # тест: текущая карточка по центру
		main.set_state("wait_answer_%d" % i)
		while true:
			var v = await picked
			if dead: return
			if typeof(v) == TYPE_STRING:
				tap_say(it.voice)
				continue
			if v == bool(it.has):
				break
			errors += 1
			Voice.sfx("sfx_try")
			shake(no if it.has else yes, null, false)   # нажатая кнопка мягко покачивается, без крестиков
			if it.has:
				if not await say(it.stretch): return
			else:
				if not await say(cfg.no_line): return
				if not await say(it.voice): return
			if errors >= 2:
				# после 2-й ошибки рука (через 20 с бездействия) показывает уже на верную кнопку — без мерцания сразу.
				# Ответ не засчитывается сам: ждём, пока ребёнок нажмёт верную кнопку.
				var right: Control = yes if it.has else no
				main.hint_start(func(): return right, it.voice)
		main.hint_stop()
		Voice.sfx("sfx_ok")
		if it.has:
			var dot := add_pic(String(Assets.lesson.get("sound_dot", "ui_circle_flat")), yes.position + yes.size / 2, Vector2(60, 60), false)
			var td := dot.create_tween()
			td.tween_property(dot, "position", pic.position + Vector2(230, 10), 0.4)
			td.tween_callback(func(): dot.reparent(pic))
		else:
			var tn := pic.create_tween()
			tn.tween_property(pic, "rotation", 0.12, 0.15)
			tn.tween_property(pic, "rotation", -0.12, 0.15)
			tn.tween_property(pic, "rotation", 0.0, 0.15)
		if not await praise(): return
		main.expose("pic", null)
		# ряд отвеченных карточек — по центру сцены (центр ряда = 512), правее зоны «назад» и левее зоны крестика
		# (DESIGN_RULES.md, §2); следующая карточка снова встаёт в центр (512, 300)
		var row := _row_center(bool(it.has), _side_count(bool(it.has)))
		var tm := pic.create_tween().set_parallel()
		_last_row_tw = tm
		tm.tween_property(pic, "position", row - pic.pivot_offset - (pic.size / 2 - pic.pivot_offset) * ROW_SCALE, 0.4)   # центр карточки после масштаба (вокруг pivot) точно в row
		tm.tween_property(pic, "scale", Vector2(ROW_SCALE, ROW_SCALE), 0.4)
		pic.set_meta("in_row", true)
		pic.set_meta("row_i", i)
		pic.set_meta("has", bool(it.has))
		row_cards.append(pic)
		main.expose("row_card_%d" % i, pic)
	yes.visible = false
	no.visible = false
	await wait(0.45)
	if _last_row_tw and _last_row_tw.is_valid() and _last_row_tw.is_running():
		await _last_row_tw.finished   # в быстром режиме wait() короче анимации — ждём, пока последняя карточка встанет в ряд
	if dead: return
	main.set_info("s04_row", row_cards.map(func(c): return _rect_info(c) + [bool(c.get_meta("has"))]))
	if not await say(cfg.done): return
	if not await _applause(): return
	finish()

## Финал сцены: слово «аплодисменты» (первая «а» — красная), голос Али, хлопушка и искры. Слово можно нажать — ещё раз.
func _applause() -> bool:
	var ap: Dictionary = cfg.get("applause", {})
	if ap.is_empty():
		return true
	var word := String(ap.get("word", "аплодисменты"))
	var red := Assets.VOWEL_RED.to_html(false)
	var bb := ""
	var mark: Array = ap.get("red", [0])
	for k in word.length():
		var ch := word.substr(k, 1)
		bb += ("[color=#%s]%s[/color]" % [red, ch]) if mark.has(k) else ch
	var box := Vector2(float(ap.get("w", 760)), float(ap.get("h", 150)))
	var c := Vector2(ap.center[0], ap.center[1])
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Assets.CREAM
	sb.set_corner_radius_all(36)
	panel.add_theme_stylebox_override("panel", sb)
	panel.size = box
	panel.position = c - box / 2
	panel.pivot_offset = box / 2
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.name = "applause"
	add_child(panel)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = false
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_OFF
	rt.add_theme_font_size_override("normal_font_size", int(ap.get("font_size", 96)))
	rt.add_theme_color_override("default_color", Color(String(ap.get("color", "#2B2420"))))
	rt.text = "[center]" + bb + "[/center]"
	rt.size = box
	rt.position = Vector2(0, (box.y - float(ap.get("font_size", 96)) * 1.25) / 2)
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(rt)
	var b := tap_area(panel)
	b.name = "applause_tap"
	b.pressed.connect(func(): pulse(panel, 1); tap_say(String(ap.voice)))
	main.expose("applause", b)
	pop_in(panel)
	Voice.sfx(String(ap.get("sfx", "sfx_cheer")))
	burst(c + Vector2(-box.x * 0.35, 0), Color("#FFD23C"))
	burst(c + Vector2(box.x * 0.35, 0), Color("#D93A2B"))
	main.set_info("s04_applause", {"word": word, "red": mark, "rect": _rect_info(panel)})
	main.set_state("applause")
	return await say(String(ap.voice))

var _last_row_tw: Tween
const ROW_SCALE := 0.45
const ROW_STEP := 165.0
var row_cards: Array = []
var word_taps := 0

## Ряды наверху (hear.rows): слева — слова СО звуком [а] (от левого края к центру), справа — БЕЗ звука.
## Между рядами — зазор по центру; ряды правее зоны «назад» и левее крестика (DESIGN_RULES.md, §2).
func _row_center(has: bool, k: int) -> Vector2:
	var r: Dictionary = cfg.get("rows", {})
	var step := float(r.get("step", 145))
	var y := float(r.get("y", 120))
	if has:
		return Vector2(float(r.get("yes_x0", 200)) + k * step, y)
	return Vector2(float(r.get("no_x0", 680)) + k * step, y)

func _side_count(has: bool) -> int:
	var n := 0
	for c in row_cards:
		if bool(c.get_meta("has")) == has:
			n += 1
	return n

## Касание карточки: текущая — повтор слова (как раньше, через picked); в ряду — Аля говорит слово карточки
## и карточка чуть подпрыгивает. На ответ это не влияет и ничего не подтверждает.
func _on_card(pic: TextureButton) -> void:
	if not pic.get_meta("in_row", false):
		picked.emit("pic")
		return
	word_taps += 1
	main.set_info("s04_word_taps", word_taps)
	main.set_info("s04_word_last", String(pic.get_meta("word_audio")))
	var tw := pic.create_tween()
	tw.tween_property(pic, "scale", Vector2(ROW_SCALE, ROW_SCALE) * 1.15, 0.12)
	tw.tween_property(pic, "scale", Vector2(ROW_SCALE, ROW_SCALE), 0.18)
	tap_say(String(pic.get_meta("word_audio")))   # очередь голоса: не перебивает Алю, повторные касания не копятся

func _rect_info(c: Control) -> Array:
	var r := c.get_global_rect()
	var xf := c.get_global_transform_with_canvas()
	var c0 := xf * (c.size / 2)
	var sz := c.size * xf.get_scale()
	return [c0.x - sz.x / 2, c0.y - sz.y / 2, sz.x, sz.y]

var _flip := false
func _alt(a: Control, b: Control) -> Control:
	_flip = not _flip
	return a if _flip else b
