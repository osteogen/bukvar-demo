## Сцена 6. Пишем пальчиком: обвести А по 3 штрихам (≥ 80 % длины, отклонение ≤ 40 px; младший режим — ≤ 60 px).
## Точка старта — коралловая #E07A4E, пульсирует.
extends LessonStep

var strokes: Array = []          # [[Vector2, Vector2], …]
var k := 0                       # текущий штрих
var progress := 0.0
var tracing := false
var trail: PackedVector2Array = []
var fails := 0
var busy := true
var done_all := false
var tol := 40.0
var min_prog := 0.8
var canvas: Control
var m_start: Control
var m_end: Control
var demo_hand: TextureRect
var has_trace := false

func run() -> void:
	section("write")
	tol = float(cfg.tolerance_junior if bool(Assets.settings.get("junior", false)) else cfg.tolerance)
	main.log_event("write_mode", {"junior": bool(Assets.settings.get("junior", false)), "tol": tol})
	min_prog = float(cfg.min_progress)
	for s in cfg.strokes:
		strokes.append([Vector2(s[0][0], s[0][1]), Vector2(s[1][0], s[1][1])])
	add_bg(cfg.bg)
	# серая буква с дорожкой — letter_<x>_trace.png во весь экран 1024×768 (2×): совпадает с координатами штрихов
	var trace := TextureRect.new()
	trace.texture = Assets.tex("letter_%s_trace" % Assets.letter_id, false)
	trace.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trace.size = Vector2(1024, 768)
	trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(trace)
	has_trace = trace.texture != null
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_draw_canvas)
	canvas.gui_input.connect(_on_input)
	add_child(canvas)
	m_start = _marker()
	m_end = _marker()
	demo_hand = TextureRect.new()
	demo_hand.texture = Assets.tex("ui_hand_f1")
	demo_hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	demo_hand.size = Vector2(90, 90)
	demo_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	demo_hand.visible = false
	add_child(demo_hand)
	_set_markers()
	if not await say(cfg.lines[0]): return
	await _begin_stroke()

func _marker() -> Control:
	var c := Control.new()
	c.size = Vector2(10, 10)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c

func _set_markers() -> void:
	if k < strokes.size():
		m_start.position = strokes[k][0] - Vector2(5, 5)
		m_end.position = strokes[k][1] - Vector2(5, 5)
		main.expose("stroke_start", m_start)
		main.expose("stroke_end", m_end)

func _begin_stroke() -> void:
	busy = true
	fails = 0
	_set_markers()
	canvas.queue_redraw()
	if not await say(cfg.lines[k + 1]): return
	busy = false
	main.hint_start(func(): return m_start, "", Callable())
	main.set_state("wait_stroke_%d" % k)

func _draw_canvas() -> void:
	var font := ThemeDB.fallback_font
	for i in strokes.size():
		var a: Vector2 = strokes[i][0]
		var b: Vector2 = strokes[i][1]
		var col := Assets.VOWEL_RED if (i < k or done_all) else Color(0.75, 0.75, 0.75)
		if has_trace and col != Assets.VOWEL_RED:
			continue
		canvas.draw_line(a, b, col, 56.0, true)
		canvas.draw_circle(a, 28, col)
		canvas.draw_circle(b, 28, col)
	if not done_all and k < strokes.size():
		var a: Vector2 = strokes[k][0]
		var b: Vector2 = strokes[k][1]
		canvas.draw_dashed_line(a, b, Color.WHITE, 6.0, 18.0)
		var dir := (b - a).normalized()
		var tip := a + dir * 120.0
		var arrow := Color("#7a5a3a")   # стрелка — коричневая (синий/зелёный — цвета согласных)
		canvas.draw_line(a + dir * 40.0, tip, arrow, 8.0)
		canvas.draw_line(tip, tip - dir.rotated(0.5) * 24.0, arrow, 8.0)
		canvas.draw_line(tip, tip - dir.rotated(-0.5) * 24.0, arrow, 8.0)
		# коралловая точка старта с пульсацией
		var ph := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.2)
		var halo := Assets.CORAL
		halo.a = 0.35 * (1.0 - ph)
		canvas.draw_circle(a, 24.0 + 16.0 * ph, halo)
		canvas.draw_circle(a, 24, Assets.CORAL)
		canvas.draw_string(font, a + Vector2(-9, 11), str(k + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	if trail.size() > 1:
		canvas.draw_polyline(trail, Assets.VOWEL_RED, 14.0, true)

func _project(p: Vector2) -> Array:
	var a: Vector2 = strokes[k][0]
	var b: Vector2 = strokes[k][1]
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return [t, p.distance_to(a + ab * t)]

func _on_input(ev: InputEvent) -> void:
	if busy or done_all:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			if ev.position.distance_to(strokes[k][0]) <= tol * 1.6:
				tracing = true
				progress = 0.0
				trail = PackedVector2Array([ev.position])
				main.hint_stop()
		elif tracing:
			tracing = false
			if progress >= min_prog:
				_stroke_ok()
			else:
				_stroke_fail()
	elif ev is InputEventMouseMotion and tracing:
		var pr := _project(ev.position)
		if pr[1] > tol:
			tracing = false
			_stroke_fail()
			return
		progress = maxf(progress, pr[0])
		trail.append(ev.position)
		canvas.queue_redraw()
		if progress >= 0.98:
			tracing = false
			_stroke_ok()

func _stroke_ok() -> void:
	busy = true
	trail.clear()
	Voice.sfx("sfx_ok")
	main.log_event("stroke_ok", {"stroke": k, "fails": fails})
	k += 1
	canvas.queue_redraw()
	if k >= strokes.size():
		done_all = true
		main.hint_stop()
		canvas.queue_redraw()
		burst(Vector2(512, 380), Color("#ffd23c"))
		burst(Vector2(400, 300), Color("#fff4a0"))
		if not await praise(): return
		if not await say(cfg.done): return
		finish()
	else:
		await _begin_stroke()

func _stroke_fail() -> void:
	busy = true
	trail.clear()
	canvas.queue_redraw()
	fails += 1
	Voice.sfx("sfx_try")
	if not await say("r_try_04"): return
	if fails == 2:
		await _demo()
		if dead: return
	elif fails >= 3:
		_stroke_ok()
		return
	busy = false
	main.hint_start(func(): return m_start, "", Callable())

func _demo() -> void:
	demo_hand.position = strokes[k][0] - Vector2(20, 4)
	demo_hand.visible = true
	var tw := demo_hand.create_tween()
	tw.tween_property(demo_hand, "position", strokes[k][1] - Vector2(20, 4), 1.5)
	await tw.finished
	if not dead:
		demo_hand.visible = false


func _process(_dt: float) -> void:
	# перерисовка ради пульсации точки старта
	if canvas and not done_all:
		canvas.queue_redraw()
