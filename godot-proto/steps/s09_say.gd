## Сцена 9. Скажи вслух — проверяет взрослый. Кнопка взрослого «✓ / ещё раз» есть ТОЛЬКО в этой сцене.
## Появляется через 2 с после реплики-задания; нажатия чаще 1 раза в секунду игнорируются;
## если взрослый молчит 8 с — кнопка пульсирует и звучит h_parent_01 (один раз за сцену).
extends LessonStep

var btn_ok: TextureButton
var btn_retry: TextureButton
var shown_at := 0
var last_press := 0
var parent_hinted := false
var idle_timer: Timer
var stars: Array = []

func run() -> void:
	section("say")
	add_bg(cfg.bg)
	var alya := add_character(cfg.host, Vector2(180, 440), Vector2(260, 350))
	alya.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop_in(alya)
	add_pic("reward_shelf", Vector2(512, 80), Vector2(420, 90), false)
	btn_ok = add_pic("ui_parent_ok", Vector2(880, 700), Vector2(64, 64))
	btn_retry = add_pic("ui_parent_retry", Vector2(960, 700), Vector2(64, 64))
	btn_ok.pressed.connect(_press.bind("ok"))
	btn_retry.pressed.connect(_press.bind("retry"))
	main.expose("parent_ok", btn_ok)
	main.expose("parent_retry", btn_retry)
	_show_parent(false)
	idle_timer = Timer.new()
	idle_timer.one_shot = true
	idle_timer.wait_time = float(cfg.parent_idle_sec)
	idle_timer.timeout.connect(_parent_idle)
	add_child(idle_timer)
	var tasks: Array = cfg.tasks
	if not await say(cfg.intro): return
	for i in tasks.size():
		var task: Dictionary = tasks[i]
		var card := _make_card(task)
		var sound_task := String(task.card) == "sound"
		main.expose("card", card)
		var cr := card.get_global_rect()
		main.set_info("s09_card", {"i": i, "id": String(task.card), "rect": [cr.position.x, cr.position.y, cr.size.x, cr.size.y]})
		pop_in(card)
		if sound_task:
			# задание «произнеси [а]»: Аля держит рот «а» (mouth_2), дуги пульсируют, пока звучит образец
			alya.singing = true
			_waves_pulse(card, true)
		else:
			alya.pose("point")             # «показывает» на карточку — статичная поза alya_pose_point
		if not await say(task.prompt): return
		_waves_pulse(card, false)
		alya.clear_pose()
		var tries := 0
		var second_try := false
		while true:
			if not await wait(float(cfg.button_delay_sec)): return
			_show_parent(true)
			main.set_state("wait_parent_%d" % i)
			var v = await picked
			if dead: return
			_show_parent(false)
			main.log_event("parent_button", {"task": i + 1, "answer": v, "try": tries + 1})
			if v == "ok":
				break
			tries += 1
			if not await say(cfg.retry_line): return
			_waves_pulse(card, sound_task)
			if not await say(task.model): return
			_waves_pulse(card, false)
			if tries >= 2:
				if not await say(cfg.giveup_line): return
				second_try = true
				break
		alya.singing = false
		await _fly_star(card, i, second_try)
		if dead: return
		if not second_try:
			if not await praise(): return
	main.set_meta("stars", stars)
	finish()

func _show_parent(on: bool) -> void:
	btn_ok.visible = on
	btn_retry.visible = on
	if on:
		shown_at = Time.get_ticks_msec()
		if not parent_hinted:
			idle_timer.start()
		# 20 с без касаний — рука показывает на ✓ (кнопку нажимает взрослый); без реплики и автопомощи
		main.hint_start(func(): return btn_ok, "")
	else:
		main.hint_stop()
		if idle_timer:
			idle_timer.stop()

func _press(v: String) -> void:
	var now := Time.get_ticks_msec()
	if now - last_press < 1000 or now - shown_at < 300:
		return               # защита от «детского» многократного нажатия
	last_press = now
	idle_timer.stop()
	picked.emit(v)

func _parent_idle() -> void:
	if parent_hinted or not btn_ok.visible:
		return
	parent_hinted = true
	pulse(btn_ok, 3)
	pulse(btn_retry, 3)
	Voice.say(cfg.parent_hint)

func _fly_star(card: Control, i: int, second_try: bool) -> void:
	# одна и та же звезда за любую попытку; «со второго раза» — только в журнал для взрослого
	var star := add_pic(cfg.star, card.position + card.size / 2, Vector2(110, 110), false)
	stars.append("second_try" if second_try else "first_try")
	var tc := card.create_tween()
	tc.tween_property(card, "scale", Vector2(0, 1), 0.2)
	tc.tween_callback(card.queue_free)
	var tw := star.create_tween().set_parallel()
	tw.tween_property(star, "position", Vector2(362 + i * 100 - 30, 71 - 30), 0.6).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(star, "size", Vector2(60, 60), 0.6)
	Voice.sfx("sfx_ok")
	await tw.finished

const CARD_C := Vector2(560, 360)
const CARD_S := Vector2(300, 300)
const CARD_BACKING := Color("#F7F0DE")

## Карточка задания: непрозрачная кремовая подложка + общая рамка ui_card_frame; внутри — содержимое.
##  • "sound" (9.1): плоский матовый кружок #D93A2B ≈ 42 % ширины по центру, справа 3 дуги-волны; больше ничего.
##  • "letter_big": буква А; • иначе — картинка pic_*.
func _make_card(task: Dictionary) -> Control:
	var card := Control.new()
	card.size = CARD_S
	card.position = CARD_C - CARD_S / 2
	card.pivot_offset = CARD_S / 2
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var id := String(task.card)
	if id == "sound":
		var d := CARD_S.x * float(cfg.get("sound_dot_frac", 0.42))
		var dot := _tex_rect(String(Assets.lesson.get("sound_dot", "ui_circle_flat")), Vector2(d, d))
		dot.position = (CARD_S - dot.size) / 2
		card.add_child(dot)
		# волны (160×280, центр дуг у левого края): крупнее прежних 0,5×0,875 — 0,6×1,05 диаметра кружка
		var wid := String(cfg.get("sound_waves", "ui_sound_waves"))
		var wsz := Vector2(d * 0.6, d * 1.05)
		var waves := Control.new()
		waves.name = "waves"
		waves.size = wsz
		waves.position = Vector2(dot.position.x + d + 2, (CARD_S.y - wsz.y) / 2)
		waves.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(waves)
		var rest := _tex_rect(wid, wsz)         # все три дуги — в покое
		rest.name = "all"
		waves.add_child(rest)
		for k in 3:                              # _1/_2/_3 — по одной дуге, тот же холст; загораются по очереди
			var arc := _tex_rect("%s_%d" % [wid, k + 1], wsz)
			arc.name = "arc_%d" % (k + 1)
			arc.visible = false
			waves.add_child(arc)
	elif id == "letter_big":
		var l := add_letter(Assets.lesson.big, CARD_C, 220)
		l.reparent(card)
	else:
		var pic := add_pic(id, CARD_C, CARD_S * 0.86, false)
		pic.reparent(card)
	if id.begins_with("pic_alya_card"):
		# у портрета Али рамка и кремовый фон нарисованы в файле — растягиваем картинку на всю карточку
		var p := card.get_child(0) as Control
		p.position = Vector2.ZERO
		p.size = CARD_S
	else:
		add_card_frame(card, 0.06, CARD_BACKING)
	main.set_info("s09_card_content", id)
	return card

func _tex_rect(id: String, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Assets.tex(id)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

var _wave_tw: Tween
## Пока звучит образец: дуги _1 → _2 → _3 загораются по очереди (≈0,25 с), затем пауза и снова; в покое видны все три.
func _waves_pulse(card: Control, on: bool) -> void:
	var w := card.get_node_or_null("waves") as Control
	if w == null:
		return
	if _wave_tw and _wave_tw.is_valid():
		_wave_tw.kill()
	var arcs: Array = []
	for k in 3:
		var a := w.get_node_or_null("arc_%d" % (k + 1)) as CanvasItem
		if a and a is TextureRect and (a as TextureRect).texture:
			arcs.append(a)
	var rest := w.get_node("all") as CanvasItem
	for a in arcs:
		a.visible = false
	rest.visible = true
	if not on or arcs.size() < 3:
		return
	rest.visible = false
	_wave_tw = w.create_tween().set_loops()
	for k in 3:
		_wave_tw.tween_callback(_light_arcs.bind(arcs, k + 1))
		_wave_tw.tween_interval(0.25)
	_wave_tw.tween_interval(0.2)
	_wave_tw.tween_callback(_light_arcs.bind(arcs, 0))
	_wave_tw.tween_interval(0.15)

func _light_arcs(arcs: Array, n: int) -> void:
	for k in arcs.size():
		(arcs[k] as CanvasItem).visible = k < n
	main.set_info("s09_arcs_lit", n)
