## Сцена 4. Слышу [а] или нет: красная кнопка с ухом / серая.
extends LessonStep

func run() -> void:
	section("hear")
	add_bg(cfg.bg)
	var yes := add_pic("ui_ear_yes", Vector2(330, 620), Vector2(170, 170))
	var no := add_pic("ui_ear_no", Vector2(694, 620), Vector2(170, 170))
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
		bind_pick(pic, "pic")
		pop_in(pic)
		if not await say(it.voice): return
		var errors := 0
		main.hint_start(func(): return _alt(yes, no), it.voice)
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
			if errors >= 2:
				pulse(yes if it.has else no, 2)
				break
			if it.has:
				if not await say(it.stretch): return
			else:
				if not await say(cfg.no_line): return
				if not await say(it.voice): return
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
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tm := pic.create_tween().set_parallel()
		tm.tween_property(pic, "position", Vector2(112 + i * 170 - 150, 120 - 150), 0.4)
		tm.tween_property(pic, "scale", Vector2(0.45, 0.45), 0.4)
	yes.visible = false
	no.visible = false
	if not await say(cfg.done): return
	finish()

var _flip := false
func _alt(a: Control, b: Control) -> Control:
	_flip = not _flip
	return a if _flip else b
