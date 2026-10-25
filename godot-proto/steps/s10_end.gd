## Сцена 10. Награда: наклейка-аист летит в альбом (обложка кремовая), зайка спит в кроватке; «Ещё раз» / «Домой» (→ экран букв).
## Итог для взрослого — за маленьким значком без текста (ui_parent_info), открывается долгим нажатием ≈2 с.
extends LessonStep

func run() -> void:
	section("end")
	add_bg(cfg.bg)
	var alya := add_character(cfg.host, Vector2(250, 440), Vector2(285, 380))
	alya.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# зайка — отдельный персонаж, спит в кроватке (≈240×176, зайка ≈160): поза bunny_sleep между слоями кроватки
	var bunny := add_bunny_crib(cfg.bunny, Vector2(770, 590))
	if not bunny.pose("sleep"):
		bunny.sleeping = true
	bunny.pressed.connect(func(): Voice.sfx("sfx_snore"))
	var album := add_pic(String(cfg.get("album", "reward_album")), Vector2(830, 70), Vector2(100, 100), false)   # левее угла: справа вверху крестик выхода; обложка кремовая #F7F0DE (финальный файл иллюстратора)
	pop_in(alya)
	alya.pose_for("joy", 1.6)              # радуется (статичная поза), потом машет
	get_tree().create_timer(1.7).timeout.connect(func(): if is_instance_valid(alya): alya.wave(2))
	for p in [Vector2(300, 200), Vector2(700, 180), Vector2(512, 300)]:
		burst(p, [Color("#ffd23c"), Color("#f6ecd6"), Assets.MUSTARD, Assets.CORAL][randi() % 4])   # палитра без синего и зелёного
	Voice.sfx("sfx_cheer")
	if not await say(cfg.lines[0]): return
	var sticker := add_pic(cfg.sticker, Vector2(540, 360), Vector2(260, 260))
	main.expose("sticker", sticker)
	pop_in(sticker)
	if not await say(cfg.lines[1]): return
	var tw := sticker.create_tween().set_parallel()
	tw.tween_property(sticker, "position", album.position, 0.8).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(sticker, "size", album.size, 0.8)
	await tw.finished
	if dead: return
	var ar := album.get_global_rect()
	main.set_info("s10_album", [ar.position.x, ar.position.y, ar.size.x, ar.size.y])
	pulse(album, 2)
	sticker.pressed.connect(func(): Voice.say(cfg.lines[1]))
	if not await say(cfg.lines[2]): return
	var again := add_pic("ui_btn_again", Vector2(420, 640), Vector2(130, 130))
	var home := add_pic("ui_btn_home", Vector2(604, 640), Vector2(130, 130))
	main.expose("again", again)
	main.expose("home", home)
	pop_in(again)
	pop_in(home, 0.15)
	var stars: Array = main.get_meta("stars", [])
	var second := stars.count("second_try")
	var mins := int((Time.get_ticks_msec() - main.started_ms) / 60000.0 + 0.5)
	_add_parent_icon("Звёзд: %d из %d (со второго раза: %d) · время: %d мин" % [stars.size(), 4, second, mins])
	main.log_event("lesson_end", {"stars": stars, "minutes": mins})
	again.pressed.connect(func(): main.goto(1))
	home.pressed.connect(main.go_home)
	# 20 с без касаний — рука показывает на «домой» (к экрану букв)
	main.hint_start(func(): return home, "")
	main.set_state("done")

## Значок для взрослого: коричневый кружок без текста; удерживать ≈2 с (end.parent_hold_sec) — откроется итог урока.
var _hold_t := -1.0
var _hold_icon: TextureButton
var _parent_text := ""
var _parent_panel: Control

func _add_parent_icon(text: String) -> void:
	_parent_text = text
	_hold_icon = add_pic(String(cfg.get("parent_icon", "ui_parent_info")), Vector2(60, 724), Vector2(56, 56))   # левый нижний угол: правый нижний — зона «Далее»
	_hold_icon.modulate.a = 0.75
	main.expose("parent_info", _hold_icon)
	_hold_icon.button_down.connect(func(): _hold_t = 0.0)
	_hold_icon.button_up.connect(func(): _hold_t = -1.0; _hold_icon.scale = Vector2.ONE)

func _process(delta: float) -> void:
	if _hold_t < 0.0 or _hold_icon == null:
		return
	_hold_t += delta
	var need := float(cfg.get("parent_hold_sec", 2.0))
	_hold_icon.scale = Vector2.ONE * (1.0 + 0.25 * minf(_hold_t / need, 1.0))
	if _hold_t >= need:
		_hold_t = -1.0
		_hold_icon.scale = Vector2.ONE
		_show_parent_panel()

func _show_parent_panel() -> void:
	if _parent_panel and is_instance_valid(_parent_panel):
		return
	var panel := Button.new()   # тап в любом месте — закрыть
	panel.flat = true
	panel.position = Vector2(232, 300)
	panel.size = Vector2(560, 150)
	var bgr := ColorRect.new()
	bgr.color = Color("#3c3228e6")
	bgr.set_anchors_preset(Control.PRESET_FULL_RECT)
	bgr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bgr)
	var l := add_text(_parent_text, Vector2(280, 75), 22, Color("#f7f0de"), Vector2(520, 120))
	l.reparent(panel, false)
	l.position = Vector2(20, 15)
	add_child(panel)
	panel.pressed.connect(func(): panel.visible = false; panel.queue_free(); main.set_info("parent_panel", false))
	_parent_panel = panel
	main.expose("parent_panel", panel)
	main.set_info("parent_panel", true)
	main.set_state(main.state)
