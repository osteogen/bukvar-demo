## Сцена 11 (последняя). Правки урока А 27.10.2026:
##  • слева от центра — Аля по пояс (крупный план alya_closeup: улыбается, моргает, говорит с губами);
##  • справа от центра — ОДНА большая карточка-наклейка «А а» (end.sticker); никаких полок с тарелками,
##    зайки, значков и кнопок для взрослого;
##  • касание наклейки — звук [а] и открывается большой альбом с бледным алфавитом (end.album: разворот +
##    накладка с алфавитом); наклейка плавно уменьшается и ложится в клетку «А а» (end.album.grid, клетка 0);
##  • касание наклейки и после этого — звук [а] (очередь голоса, без наложения);
##  • потом круглая кнопка «Ещё раз» (ui_btn_again, круговая стрелка) — урок с начала (main.restart()).
## Наклейка попадает в альбом ТОЛЬКО по касанию ребёнка; через 20 с бездействия рука показывает на наклейку.
extends LessonStep

var sticker: TextureButton
var album: Control
var placed := false
var cell_rect := Rect2()

func _v(a, def: Vector2) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a is Array and a.size() >= 2 else def

func run() -> void:
	section("end")
	add_bg(cfg.bg)
	var hc: Dictionary = cfg.get("host_at", {})
	var alya := add_character(String(cfg.get("host", "alya_closeup")), _v(hc.get("center"), Vector2(210, 440)), _v(hc.get("size"), Vector2(420, 420)))
	alya.name = "end_alya"
	alya.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.expose("alya", alya)
	pop_in(alya)
	for p in [Vector2(300, 200), Vector2(700, 180), Vector2(560, 300)]:
		burst(p, [Color("#ffd23c"), Color("#f6ecd6"), Assets.MUSTARD, Assets.CORAL][randi() % 4])   # палитра без синего и зелёного
	Voice.sfx("sfx_cheer")
	if not await say(String(cfg.lines[0])): return
	var sc: Dictionary = cfg.get("sticker_at", {})
	sticker = add_pic(String(cfg.sticker), _v(sc.get("center"), Vector2(650, 370)), _v(sc.get("size"), Vector2(340, 340)))
	sticker.name = "sticker"
	main.expose("sticker", sticker)
	pop_in(sticker)
	sticker.pressed.connect(_on_sticker)
	main.set_info("s11_sticker", _r(sticker.get_global_rect()))
	main.set_state("wait_sticker")
	main.hint_start(func(): return sticker if not placed else null, "")
	if cfg.lines.size() > 1:
		say(String(cfg.lines[1]))   # «Нажми на неё — и она попадёт в твой альбом!»; касание не ждёт конца фразы

func _r(r: Rect2) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]

func _tap_sound() -> void:
	var tp: Dictionary = cfg.get("tap", {})
	var id := String(tp.get("audio", "a_aaa"))
	if Voice._stream(id) == null and String(tp.get("fallback", "")) != "":
		id = String(tp.get("fallback"))
	main.set_info("s11_tap_audio", id)
	main.set_info("s11_taps", int(main.info.get("s11_taps", 0)) + 1)
	tap_say(id, float(tp.get("max_sec", 1.8)))

func _on_sticker() -> void:
	if dead:
		return
	if placed or album != null:
		pulse(sticker, 1)
		_tap_sound()
		return
	main.hint_stop()
	Voice.stop_voice()   # фраза-приглашение больше не нужна — сразу звук буквы
	_tap_sound()
	_open_album()

## Большой альбом: разворот (album.page) + накладка с бледным алфавитом (album.alphabet), обе 840×600 @2x.
func _open_album() -> void:
	var ac: Dictionary = cfg.get("album", {})
	var c := _v(ac.get("center"), Vector2(640, 390))
	var sz := _v(ac.get("size"), Vector2(620, 443))
	var src := _v(ac.get("src_size"), Vector2(840, 600))
	album = Control.new()
	album.name = "album"
	album.mouse_filter = Control.MOUSE_FILTER_IGNORE
	album.position = c - sz / 2
	album.size = sz
	album.pivot_offset = sz / 2
	add_child(album)
	for id in [String(ac.get("page", "reward_album_page")), String(ac.get("alphabet", "reward_album_alphabet"))]:
		var t := Assets.tex(id, false)
		if t == null:
			continue
		var r := TextureRect.new()
		r.name = id
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.size = sz
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		album.add_child(r)
	# клетка «А а» (клетка 0 сетки в px картинки) → координаты сцены
	var g: Dictionary = ac.get("grid", {})
	var pg: Array = g.get("pages", [[24, 24, 408, 576]])[0]
	var cw := (float(pg[2]) - float(pg[0])) / float(g.get("cols", 3))
	var ch := (float(pg[3]) - float(pg[1])) / float(g.get("rows", 6))
	var k := sz / src
	var pad := float(g.get("pad", 7))
	cell_rect = Rect2(album.position + Vector2(float(pg[0]) + pad, float(pg[1]) + pad) * k, Vector2(cw - 2 * pad, ch - 2 * pad) * k)
	main.set_info("s11_album", _r(Rect2(album.position, sz)))
	main.set_info("s11_cell", _r(cell_rect))
	album.scale = Vector2(0.6, 0.6)
	album.modulate.a = 0.0
	sticker.move_to_front()
	Voice.sfx("sfx_ok")
	var tw := album.create_tween().set_parallel()
	tw.tween_property(album, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(album, "modulate:a", 1.0, 0.3)
	await tw.finished
	if dead: return
	# наклейка плавно уменьшается и ложится в свою клетку (квадрат по высоте клетки, по центру)
	var side := minf(cell_rect.size.x, cell_rect.size.y)
	var dest := Rect2(cell_rect.get_center() - Vector2(side, side) / 2, Vector2(side, side))
	var t2 := sticker.create_tween().set_parallel()
	t2.tween_property(sticker, "position", dest.position, float(ac.get("fly_sec", 1.0))).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t2.tween_property(sticker, "size", dest.size, float(ac.get("fly_sec", 1.0))).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await t2.finished
	if dead: return
	sticker.pivot_offset = sticker.size / 2
	placed = true
	main.set_info("s11_placed", _r(sticker.get_global_rect()))
	burst(dest.get_center(), Assets.MUSTARD)
	Voice.sfx("sfx_cheer")
	if not await praise(): return
	_show_again()

func _show_again() -> void:
	var ag: Dictionary = cfg.get("again", {})
	var again := add_pic(String(ag.get("pic", "ui_btn_again")), _v(ag.get("center"), Vector2(640, 690)), _v(ag.get("size"), Vector2(120, 120)))
	again.name = "again"
	main.expose("again", again)
	pop_in(again)
	again.pressed.connect(func():
		Voice.stop_all()
		if main.has_method("restart"): main.restart()
		else: main.goto(0))
	var stars: Array = main.get_meta("stars", [])
	var mins := int((Time.get_ticks_msec() - main.started_ms) / 60000.0 + 0.5)
	main.log_event("lesson_end", {"stars": stars, "minutes": mins})   # итог — только в журнал (без экранов для взрослых)
	main.mark_done()
	main.set_state("done")
