## Сцена 4. Слышу [а] или нет: Аля говорит «нажми на красный кружок… если не услышишь — на серый».
## Поэтому «да» — красный круг (#D93A2B) с большой чёрной «А», «нет» — серый круг с тёмно-серым крестиком (не красным).
## Отвеченные карточки встают в ряд по центру сверху; касание карточки в ряду — Аля говорит это слово (items[].word_audio).
extends LessonStep

func run() -> void:
	section("hear")
	add_bg(cfg.bg)
	var yes := add_pic(String(cfg.get("yes_pic", "ui_hear_yes")), Vector2(330, 620), Vector2(170, 170))
	var no := add_pic(String(cfg.get("no_pic", "ui_hear_no")), Vector2(694, 620), Vector2(170, 170))
	if cfg.get("yes_letter", "А") != "":
		# чёрная «А» на красной кнопке — шрифтом (как буквы урока), над кругом
		var la := add_text(String(cfg.get("yes_letter", "А")), Vector2(85, 82), 120, Color(String(cfg.get("yes_letter_color", "#1E1A16"))), Vector2(170, 170))
		la.reparent(yes, false)
		la.position = Vector2.ZERO
		la.name = "yes_letter"
	bind_pick(yes, true)
	bind_pick(no, false)
	main.expose("yes", yes)
	main.expose("no", no)
	yes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	no.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse(yes, 3)
	var tw := no.create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(func(): pulse(no, 3))
	if not await say(cfg.intro): return
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
				Voice.say(it.voice)
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
				# после 2-й ошибки — только подсказка: верная кнопка мерцает, рука показывает на неё.
				# Ответ не засчитывается сам: ждём, пока ребёнок нажмёт верную кнопку.
				var right: Control = yes if it.has else no
				pulse(right, 2)
				main.hint_start(func(): return right, it.voice)
				main.hint_now()
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
		var row := _row_center(i, items.size())
		var tm := pic.create_tween().set_parallel()
		_last_row_tw = tm
		tm.tween_property(pic, "position", row - pic.pivot_offset - (pic.size / 2 - pic.pivot_offset) * ROW_SCALE, 0.4)   # центр карточки после масштаба (вокруг pivot) точно в row
		tm.tween_property(pic, "scale", Vector2(ROW_SCALE, ROW_SCALE), 0.4)
		pic.set_meta("in_row", true)
		pic.set_meta("row_i", i)
		row_cards.append(pic)
		main.expose("row_card_%d" % i, pic)
	yes.visible = false
	no.visible = false
	await wait(0.45)
	if _last_row_tw and _last_row_tw.is_valid() and _last_row_tw.is_running():
		await _last_row_tw.finished   # в быстром режиме wait() короче анимации — ждём, пока последняя карточка встанет в ряд
	if dead: return
	main.set_info("s04_row", row_cards.map(func(c): return _rect_info(c)))
	if not await say(cfg.done): return
	finish()

var _last_row_tw: Tween
const ROW_SCALE := 0.45
const ROW_STEP := 165.0
var row_cards: Array = []
var word_taps := 0

func _row_center(i: int, n: int) -> Vector2:
	return Vector2(512.0 + (i - (n - 1) / 2.0) * ROW_STEP, 120.0)

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
	if not Voice.voice.playing:   # не перебиваем задание Али; нет файла — Voice.say молча пропускает
		Voice.say(String(pic.get_meta("word_audio")))

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
