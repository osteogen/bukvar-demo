## Сцена 3. Звук [а] в словах: нажми картинку, затем посади кружок в паровоз (начало слова).
## Дорожка-паровозик: паровоз = начало, средний вагон = середина, последний вагон = конец (места, а не звуки).
## Для «Аля» кружок в последнем вагоне — не ошибка: звучит a_words_end_ok, и ребёнок ищет начало.
extends LessonStep

func run() -> void:
	section("words")
	add_bg(cfg.bg)
	if not await say(cfg.intro): return
	var items: Array = cfg.items
	for i in items.size():
		var it: Dictionary = items[i]
		var cx := 200.0 + i * 312.0
		var pic := add_pic(it.pic, Vector2(cx, 290), Vector2(250, 250))
		if not String(it.pic).begins_with("pic_alya_card"):   # у портрета Али своя рамка
			add_card_frame(pic)
		main.expose("pic", pic)
		pop_in(pic)
		burst(Vector2(cx, 290), Color("#fffbd0"))
		main.hint_start(func(): return pic, "h_tap_01", func(): pic.pressed.emit())
		main.set_state("wait_pic_%d" % i)
		if not await tapped(pic): return
		main.hint_stop()
		animate_frames(pic, it.pic)
		if not await say(it.voice): return
		pic.pressed.connect(func(): animate_frames(pic, it.pic); Voice.say(it.voice))
		# дорожка-паровозик: начало — середина — конец
		var slots: Array = []
		var track: Array = cfg.track
		# паровоз слева (смотрит носом влево), за ним средний и последний вагон; вагоны стоят вплотную
		var tsz := Vector2(cfg.track_size[0], cfg.track_size[1])
		for k in track.size():
			var s := add_pic(track[k], Vector2(cx + (k - 1) * tsz.x, 510), tsz)
			bind_pick(s, k)
			slots.append(s)
			main.expose("slot%d" % k, s)
		var circ := add_pic(String(Assets.lesson.get("sound_dot", "ui_circle_flat")), Vector2(cx, 610), Vector2(34, 34), false)   # плоский матовый кружок-звук
		pop_in(circ)
		if i == 0:
			if not await say(cfg.slot_hint): return
		else:
			burst(slots[0].position + slots[0].size / 2)
		var errors := 0
		main.hint_start(func(): return slots[0], "h_tap_01", func(): picked.emit(-1))
		main.set_state("wait_slot_%d" % i)
		while true:
			var k = await picked
			if dead: return
			if k == int(it.pos) or k == -1:
				break
			if k == slots.size() - 1 and bool(it.get("end_ok", false)):
				# «Аля»: в конце тоже слышится гласный — не ошибка, без sfx_try
				pulse(slots[k], 1)
				main.log_event("end_ok", {"word": it.word})
				if not await say(cfg.end_ok_line): return
				main.hint_start(func(): return slots[0], "h_tap_01", func(): picked.emit(-1))
				continue
			errors += 1
			shake(slots[k])
			Voice.sfx("sfx_try")
			if not await say(it.voice): return   # повтор слова с протяжкой
			if errors >= 2:
				break
		main.hint_stop()
		for s in slots:
			s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var target: Control = slots[int(it.pos)]
		var tw := circ.create_tween()
		# кружок садится в окошко вагона (доли ширины/высоты картинки — words.track_window)
		var win: Array = cfg.track_window[int(it.pos)]
		var spot := target.position + Vector2(target.size.x * float(win[0]), target.size.y * float(win[1]))
		tw.tween_property(circ, "position", spot - circ.size / 2, 0.35).set_trans(Tween.TRANS_BACK)
		Voice.sfx("sfx_ok")
		# после 2-й ошибки кружок садится сам, затем похвала; полная a_word_05 — только после третьей картинки
		if not await praise():
			return
	if not await say(cfg.summary): return
	finish()
