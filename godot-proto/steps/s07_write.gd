## Сцена 7. Пишем пальчиком (правки 27.10.2026): сначала большая А (3 прямых штриха), затем маленькая а
## (2 штриха-кривых: кружок от точки и палочка с хвостиком). Штрих засчитан при ≥ 80 % длины и отклонении ≤ 40 px
## (младший режим — ≤ 60 px). Штрих — ломаная из любого числа точек (прямой штрих = 2 точки); прогресс считается по
## длине вдоль ломаной в «окне» [прогресс − 0,1; прогресс + 0,15] — замкнутый кружок нельзя «закрыть» одним касанием
## около старта. Точка старта — коралловая #E07A4E, пульсирует. Фазы: write (большая) → write.lower (маленькая;
## своя серая дорожка letter_<x>_lower_trace, реплики lines, финал done). Нет write.lower — как раньше, одна буква.
extends LessonStep

var phases: Array = []           # [{trace, strokes:[PackedVector2Array], intro, lines, done, width}]
var ph := 0                      # текущая фаза
var strokes: Array = []          # штрихи текущей фазы: [PackedVector2Array]
var lens: Array = []             # накопленные длины по точкам: [PackedFloat32Array]
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
var trace: TextureRect
var m_start: Control
var m_end: Control
var demo_hand: TextureRect
var has_trace := false
var width := 56.0

const WIN_BACK := 0.1
const WIN_FWD := 0.15

func _pl(s) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in s:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out

func run() -> void:
	section("write")
	tol = float(cfg.tolerance_junior if bool(Assets.settings.get("junior", false)) else cfg.tolerance)
	main.log_event("write_mode", {"junior": bool(Assets.settings.get("junior", false)), "tol": tol})
	min_prog = float(cfg.min_progress)
	var up_lines: Array = cfg.lines
	phases.append({"trace": "letter_%s_trace" % Assets.letter_id, "strokes": cfg.strokes.map(_pl), "intro": String(up_lines[0]),
		"lines": up_lines.slice(1), "done": String(cfg.done), "width": float(cfg.get("width", 56)), "name": "upper"})
	var lo: Dictionary = cfg.get("lower", {})
	if lo.has("strokes") and lo.has("lines"):
		phases.append({"trace": String(lo.get("trace", "letter_%s_lower_trace" % Assets.letter_id)), "strokes": lo.strokes.map(_pl),
			"intro": String(lo.get("intro", "")), "lines": lo.lines, "done": String(lo.get("done", "")), "width": float(lo.get("width", 50)), "name": "lower"})
	add_bg(cfg.bg)
	# серая буква с дорожкой — letter_<x>[_lower]_trace.png во весь экран 1024×768 (2×): совпадает с координатами штрихов
	trace = TextureRect.new()
	trace.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trace.size = Vector2(1024, 768)
	trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(trace)
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_draw_canvas)
	canvas.gui_input.connect(_on_input)
	add_child(canvas)
	m_start = _marker()
	m_end = _marker()
	demo_hand = TextureRect.new()
	demo_hand.texture = main.hint_frames()[0]   # та же картинка, что у руки-подсказки (data/common/hint.json)
	demo_hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	demo_hand.size = Vector2(90, 90)
	demo_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	demo_hand.visible = false
	add_child(demo_hand)
	_load_phase(0)
	await _run_phase()

func _load_phase(n: int) -> void:
	ph = n
	var p: Dictionary = phases[n]
	strokes = p.strokes
	width = float(p.width)
	lens = []
	for s in strokes:
		var acc := PackedFloat32Array([0.0])
		for i in range(1, s.size()):
			acc.append(acc[i - 1] + s[i - 1].distance_to(s[i]))
		lens.append(acc)
	k = 0
	done_all = false
	trail.clear()
	trace.texture = Assets.tex(String(p.trace), false)
	has_trace = trace.texture != null
	main.set_info("s07_phase", String(p.name))
	_set_markers()
	canvas.queue_redraw()

func _run_phase() -> void:
	var p: Dictionary = phases[ph]
	if String(p.intro) != "":
		if not await say(String(p.intro)): return
	await _begin_stroke()

func _marker() -> Control:
	var c := Control.new()
	c.size = Vector2(10, 10)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c

func _set_markers() -> void:
	if k < strokes.size():
		var s: PackedVector2Array = strokes[k]
		m_start.position = s[0] - Vector2(5, 5)
		m_end.position = s[s.size() - 1] - Vector2(5, 5)
		main.expose("stroke_start", m_start)
		main.expose("stroke_end", m_end)
		# для теста: весь путь текущего штриха (координаты сцены)
		var path := []
		for q in s:
			path.append([q.x, q.y])
		main.set_info("s07_path", path)
		main.set_info("s07_stroke", "%s_%d" % [String(phases[ph].name), k])

func _begin_stroke() -> void:
	busy = true
	fails = 0
	_set_markers()
	canvas.queue_redraw()
	var ln: Array = phases[ph].lines
	if k < ln.size():
		if not await say(String(ln[k])): return
	busy = false
	main.hint_start(func(): return m_start, "")
	main.set_state("wait_stroke_%d" % k if ph == 0 else "wait_lower_%d" % k)

## Точка на штрихе s на расстоянии d от начала (по длине ломаной) и направление в ней.
func _at(si: int, d: float) -> Array:
	var s: PackedVector2Array = strokes[si]
	var acc: PackedFloat32Array = lens[si]
	d = clampf(d, 0.0, acc[acc.size() - 1])
	for i in range(1, s.size()):
		if acc[i] >= d or i == s.size() - 1:
			var seg := acc[i] - acc[i - 1]
			var t := (d - acc[i - 1]) / seg if seg > 0.0 else 0.0
			return [s[i - 1].lerp(s[i], t), (s[i] - s[i - 1]).normalized()]
	return [s[0], Vector2.RIGHT]

func _total(si: int) -> float:
	var acc: PackedFloat32Array = lens[si]
	return acc[acc.size() - 1]

func _draw_canvas() -> void:
	var font := ThemeDB.fallback_font
	for i in strokes.size():
		var s: PackedVector2Array = strokes[i]
		var col := Assets.VOWEL_RED if (i < k or done_all) else Color(0.75, 0.75, 0.75)
		if has_trace and col != Assets.VOWEL_RED:
			continue
		canvas.draw_polyline(s, col, width, true)
		for q in s:
			canvas.draw_circle(q, width / 2, col)
	if not done_all and k < strokes.size():
		var a: Vector2 = strokes[k][0]
		# пунктир вдоль всей ломаной
		var L := _total(k)
		var d := 0.0
		while d < L:
			var p0: Vector2 = _at(k, d)[0]
			var p1: Vector2 = _at(k, minf(d + 18.0, L))[0]
			canvas.draw_line(p0, p1, Color.WHITE, 6.0)
			d += 36.0
		# стрелка вдоль начала штриха (по кривой); коричневая — синий/зелёный — цвета согласных
		var arrow := Color("#7a5a3a")
		var pts := PackedVector2Array()
		var e := minf(120.0, L * 0.6)
		var dd := 40.0
		while dd <= e:
			pts.append(_at(k, dd)[0])
			dd += 8.0
		if pts.size() > 1:
			canvas.draw_polyline(pts, arrow, 8.0, true)
			var tip: Vector2 = pts[pts.size() - 1]
			var dir: Vector2 = (tip - pts[pts.size() - 2]).normalized()
			canvas.draw_line(tip, tip - dir.rotated(0.5) * 24.0, arrow, 8.0)
			canvas.draw_line(tip, tip - dir.rotated(-0.5) * 24.0, arrow, 8.0)
		# коралловая точка старта с пульсацией
		var phs := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.2)
		var halo := Assets.CORAL
		halo.a = 0.35 * (1.0 - phs)
		canvas.draw_circle(a, 24.0 + 16.0 * phs, halo)
		canvas.draw_circle(a, 24, Assets.CORAL)
		canvas.draw_string(font, a + Vector2(-9, 11), str(k + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	if trail.size() > 1:
		canvas.draw_polyline(trail, Assets.VOWEL_RED, 14.0, true)

## Проекция точки на текущий штрих в окне вокруг достигнутого прогресса: [доля длины 0…1, расстояние].
func _project(p: Vector2) -> Array:
	var s: PackedVector2Array = strokes[k]
	var acc: PackedFloat32Array = lens[k]
	var L := _total(k)
	var lo := (progress - WIN_BACK) * L
	var hi := (progress + WIN_FWD) * L
	var best_d := INF
	var best_t := progress
	for i in range(1, s.size()):
		if acc[i] < lo or acc[i - 1] > hi:
			continue
		var a := s[i - 1]
		var ab := s[i] - a
		var seg := acc[i] - acc[i - 1]
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0) if seg > 0.0 else 0.0
		var al := clampf(acc[i - 1] + seg * t, maxf(lo, acc[i - 1]), minf(hi, acc[i]))
		var q: Vector2 = a + ab * ((al - acc[i - 1]) / seg if seg > 0.0 else 0.0)
		var dist := p.distance_to(q)
		if dist < best_d:
			best_d = dist
			best_t = al / L
	return [best_t, best_d]

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
	main.log_event("stroke_ok", {"phase": String(phases[ph].name), "stroke": k, "fails": fails})
	k += 1
	canvas.queue_redraw()
	if k >= strokes.size():
		done_all = true
		main.hint_stop()
		canvas.queue_redraw()
		burst(Vector2(512, 380), Color("#ffd23c"))
		burst(Vector2(400, 300), Color("#fff4a0"))
		main.set_info("s07_done_" + String(phases[ph].name), true)
		if not await praise(): return
		if String(phases[ph].done) != "":
			if not await say(String(phases[ph].done)): return
		if ph + 1 < phases.size():
			if not await wait(0.4): return
			_load_phase(ph + 1)
			await _run_phase()
			return
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
	# со 2-й неудачи рука показывает штрих (на каждой чётной), но штрих засчитывается только, когда ребёнок проведёт его сам
	if fails >= 2 and fails % 2 == 0:
		await _demo()
		if dead: return
	busy = false
	main.hint_start(func(): return m_start, "")   # рука-подсказка — только после 20 с бездействия (общее правило)

func _demo() -> void:
	var L := _total(k)
	demo_hand.position = strokes[k][0] - Vector2(20, 4)
	demo_hand.visible = true
	var si := k
	var tw := demo_hand.create_tween()
	tw.tween_method(func(d: float): demo_hand.position = _at(si, d)[0] - Vector2(20, 4), 0.0, L, clampf(L / 300.0, 1.5, 3.0))
	await tw.finished
	if not dead:
		demo_hand.visible = false

## Для проверки перекрытий кнопками: буква-дорожка нарисована на холсте во весь экран — её область = штрихи + толщина.
func content_rects() -> Array:
	var r := Rect2(strokes[0][0], Vector2.ZERO)
	for s in strokes:
		for q in s:
			r = r.expand(q)
	r = r.grow(40.0)
	var xf := get_global_transform()
	return [Rect2(xf * r.position, xf.get_scale() * r.size)]

func _process(_dt: float) -> void:
	# перерисовка ради пульсации точки старта
	if canvas and not done_all:
		canvas.queue_redraw()
