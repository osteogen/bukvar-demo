## Сцена 1. Колыбельная: Аля сидит у кроватки зайки и тихо поёт «а-а-а».
## Зайка — отдельный персонаж (bunny_ref / bunny_sleep) в кроватке bunny_crib_back/_front.
## Пение — поза alya_pose_sing_crib (кроватка справа от Али, зайки в позе нет; рот — слои _mouth_0/1/2).
## alya_pose_rock снята с использования.
## Урок начинается сразу с этой сцены (памятки s00 больше нет). intro.unlock_tap: если на странице урока ещё не было
## касания (iOS не даст звука), Аля и зайка уже на экране, Аля мягко пульсирует и ждёт любого касания — без текста.
extends LessonStep

var alya: Cutout
var bunny: Cutout

func run() -> void:
	section("intro")
	add_bg(cfg.bg)
	alya = add_character(cfg.host, Vector2(430, 420), Vector2(300, 400))
	alya.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# кроватка ≈240×176 справа от Али, низом на линии пола (ноги Али ≈ y 614)
	bunny = add_bunny_crib(cfg.bunny, Vector2(675, 530))
	bunny.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.expose("alya", alya)
	pop_in(alya)
	if bunny.visible:
		pop_in(bunny, 0.2)
	if not await _unlock_gate(): return
	if not await say("a_start_01"): return
	alya.wave(2)
	# «Тс-с…»: поза «палец к губам» alya_pose_shh
	alya.pose(String(cfg.get("shh_pose", "shh")))
	if not await say("a_intro_01"): return
	if alya.pose_name == String(cfg.get("shh_pose", "shh")):
		alya.clear_pose()
	if not await _sing(): return
	if not await say("a_intro_03"): return
	alya.mouse_filter = Control.MOUSE_FILTER_STOP
	pulse(alya, 3)
	main.hint_start(func(): return alya, "a_intro_03")
	main.set_state("wait_alya")
	var first := true
	while not dead:
		if not await tapped(alya): return
		main.hint_stop()
		alya.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not await _sing(): return
		# зайка уснул: поза bunny_sleep (если нет — закрытые глаза)
		if not bunny.pose("sleep"):
			bunny.sleeping = true
		if first:
			first = false
			burst(Vector2(560, 470), Color("#fff4a0"))
			if not await say(cfg.after_tap): return
			finish()
		alya.mouse_filter = Control.MOUSE_FILTER_STOP

func _sing() -> bool:
	# поза intro.sing_pose (= "sing_crib"): сидит у кроватки, поёт. Зайки в позе нет (rock_pose_has_bunny=false),
	# поэтому отдельный зайка остаётся в кроватке и покачивается.
	var rocking := alya.pose(String(cfg.get("sing_pose", "sing_crib")))
	if rocking:
		if bool(cfg.get("rock_pose_has_bunny", false)):
			bunny.visible = false
		alya.rock(2)                       # лёгкое покачивание Али в позе
	else:
		bunny.rock(2)
	alya.singing = true
	for i in 3:
		var n := add_pic("ui_note", Vector2(380 + i * 50, 220), Vector2(44, 44), false)
		var tn := n.create_tween().set_parallel()
		tn.tween_property(n, "position:y", 80.0, 2.0).set_delay(i * 0.3)
		tn.tween_property(n, "modulate:a", 0.0, 2.0).set_delay(i * 0.3)
		tn.chain().tween_callback(n.queue_free)
	var ok := await say(cfg.song)
	if ok:
		alya.singing = false
		if rocking:
			alya.clear_pose()
			bunny.visible = true
	return ok

## Первый жест на странице урока. В вебе: navigator.userActivation.hasBeenActive (касание уже было — сразу дальше).
## В тесте (?test=1) — только с ?gate=1, чтобы сквозные тесты не ждали лишнего касания.
signal _unlocked

func _needs_gate() -> bool:
	var u: Dictionary = cfg.get("unlock_tap", {})
	if not bool(u.get("enabled", true)) or not OS.has_feature("web"):
		return false
	if main.test_mode and not Assets.flag("gate"):
		return false
	var active = JavaScriptBridge.eval("(navigator.userActivation && navigator.userActivation.hasBeenActive) ? 1 : 0", true)
	return int(active) != 1 or Assets.flag("gate")

func _unlock_gate() -> bool:
	if not _needs_gate():
		return true
	var u: Dictionary = cfg.get("unlock_tap", {})
	var sc := float(u.get("pulse_scale", 1.05))
	var tw := alya.create_tween().set_loops()
	tw.tween_property(alya, "scale", Vector2(sc, sc), float(u.get("pulse_sec", 0.8)) / 2)
	tw.tween_property(alya, "scale", Vector2.ONE, float(u.get("pulse_sec", 0.8)) / 2)
	main.hint_start(func(): return alya, "")
	main.set_state("wait_unlock")
	await _unlocked
	tw.kill()
	alya.scale = Vector2.ONE
	main.hint_stop()
	return not dead

func _input(ev: InputEvent) -> void:
	if main and main.state == "wait_unlock" and (ev is InputEventScreenTouch or ev is InputEventMouseButton) and ev.pressed:
		_unlocked.emit()
