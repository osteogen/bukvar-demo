## Сцена 7. Шарики: лопни все шарики с А и а (3 + 3); помехи — фигуры (треугольник, круг, квадрат, звёздочка),
## потому что других букв ребёнок на уроке «А» ещё не знает.
extends LessonStep

var balloons: Array = []
var popped := 0
var total := 0
var counter: Array = []
var l_warned := false
var finished := false
var wrong := 0
var field: Control   # слой шариков
## Полёт шариков: по x — только между угловыми зонами кнопок (ui_zones: «назад» слева, крестик и «Далее» справа),
## по y — через всю видимую высоту (на телефоне-портрете — от низа до верха экрана). Так шарик никогда не
## проходит под кнопкой ни на одном экране (DESIGN_RULES.md, §2). Скорость постоянная, без рывков и «перезапусков».
var _speed := 40.0
const BALLOON := Vector2(120, 165)

func run() -> void:
	section("find")
	add_bg(cfg.bg)
	var letters: Array = cfg.targets.duplicate()
	for sh in cfg.shapes:
		letters.append("shape:" + sh)
	letters.shuffle()
	total = cfg.targets.size()
	field = Control.new()
	field.name = "balloon_field"
	field.size = Vector2(1024, 768)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field)
	for i in total:
		var c := add_pic(cfg.counter_empty, Vector2(512 - (total - 1) * 30 + i * 60, 50), Vector2(48, 48), false)
		counter.append(c)
	_speed = 970.0 / float(cfg.rise_sec)
	for i in letters.size():
		_spawn(letters[i], i, letters.size())
	if not await say(cfg.intro): return
	# подсказка только показывает нужный шарик; лопает его лишь касание ребёнка
	main.hint_start(_nearest_target, "h_tap_01")
	main.set_state("wait_balloons")

func _spawn(ch: String, i: int, n: int) -> void:
	var colors: Array = cfg.balloon_colors
	var xr := _x_range()
	var b := add_pic("pic_balloons_%s" % colors[i % colors.size()], Vector2(xr.x + i * ((xr.y - xr.x) / (n - 1)), 900), BALLOON)
	var l: Control
	if ch.begins_with("shape:"):
		# фигура-помеха (белая): balloon_shape_<triangle|circle|square|star>.png
		var r := TextureRect.new()
		r.texture = Assets.tex("balloon_shape_" + ch.trim_prefix("shape:"))
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.size = Vector2(76, 76)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		l = r
	else:
		# буква на шарике: balloon_letter_a_<upper|lower>.png, если есть, иначе шрифтом (красный гласных #D93A2B)
		l = add_letter(ch, Vector2(60, 70), 80, Assets.VOWEL_RED, "balloon_letter")
	b.reparent(field, false)
	l.reparent(b, false)
	l.position = Vector2(60, 68) - l.size / 2
	b.set_meta("ch", ch)
	b.set_meta("target", ch in cfg.targets)
	b.pressed.connect(func(): _on_tap(b))
	balloons.append(b)
	b.position.y = 780.0 + (i % 3) * 120.0   # первый подъём — снизу сцены, как раньше; дальше — по кругу в _fly()
	var sw := b.create_tween().set_loops()
	sw.tween_property(b, "rotation", 0.08, 1.2 + (i % 3) * 0.3)
	sw.tween_property(b, "rotation", -0.08, 1.2 + (i % 3) * 0.3)

## Допустимые центры шариков по x (координаты сцены): правее зоны «назад», левее зон крестика и «Далее».
func _x_range() -> Vector2:
	var z: Dictionary = main.ui_zones()
	var lo: float = (z.back as Rect2).end.x + BALLOON.x / 2 + 6.0
	var hi: float = minf((z.exit as Rect2).position.x, (z.next as Rect2).position.x) - BALLOON.x / 2 - 6.0
	return Vector2(lo, hi)

## Плавный подъём; ушёл за верх видимой области — незаметно появляется снизу за её краем (не «прыгает» на виду).
func _fly(dt: float) -> void:
	var vis: Rect2 = main.visible_rect_local()
	var top := minf(vis.position.y, 0.0) - BALLOON.y - 40.0
	var bottom := maxf(vis.end.y, 768.0) + 20.0
	for b in balloons:
		if not is_instance_valid(b):
			continue
		b.position.y -= _speed * dt
		if b.position.y < top:
			b.position.y = bottom

func _nearest_target():
	var best = null
	for b in balloons:
		if is_instance_valid(b) and b.get_meta("target") and b.position.y > 40 and b.position.y < 600:
			if best == null or b.position.y < best.position.y:
				best = b
	return best

func _on_tap(b: TextureButton) -> void:
	if finished or not is_instance_valid(b):
		return
	if b.get_meta("target"):
		balloons.erase(b)
		Voice.sfx("sfx_pop")
		Voice.say(cfg.hit)
		burst(b.position + b.size / 2, Color("#ffd23c"))
		_pop_anim(b.position, b.size)
		counter[popped].texture_normal = Assets.tex(cfg.counter_full)   # пустая звёздочка → золотая
		popped += 1
		b.queue_free()
		main.expose("balloon", null)
		if popped >= total:
			finished = true
			main.hint_stop()
			# оставшиеся шарики летят дальше как летели (без сброса); в центре появляются большая А и маленькая а —
			# их можно нажать и услышать звук (find.letters_end в lesson.json)
			for x in balloons:
				if is_instance_valid(x):
					x.mouse_filter = Control.MOUSE_FILTER_IGNORE
			await wait(0.7)
			if dead: return
			_show_letters()
			if not await praise(): return
			finish()
	else:
		Voice.sfx("sfx_try")
		shake(b, null, false)   # шарик летит дальше — только покачивание
		wrong += 1
		if wrong % 2 == 0:
			main.hint_now()     # после ошибок рука показывает шарик с А/а — лопнуть его должен ребёнок
		if b.get_meta("ch") == "shape:" + String(cfg.near_miss_shape) and not l_warned:
			l_warned = true
			Voice.say(cfg.near_miss_line)
		else:
			Voice.say("r_try_01")

func _pop_anim(pos: Vector2, sz: Vector2) -> void:
	var frames := []
	for n in range(1, int(cfg.pop_frames) + 1):
		var t := Assets.tex("pic_balloon_pop_%d" % n, false)
		if t: frames.append(t)
	if frames.is_empty(): return
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.position = pos
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	var tw := r.create_tween()
	for t in frames:
		tw.tween_callback(func(): r.texture = t)
		tw.tween_interval(0.08)
	tw.tween_callback(r.queue_free)

func _show_letters() -> void:
	var le: Dictionary = cfg.get("letters_end", {})
	var pairs := [[Assets.lesson.big, le.get("big_center", [420, 400]), int(le.get("big_h", 260)), String(le.get("big_voice", "a_find_03")), "end_big"],
		[Assets.lesson.small, le.get("small_center", [640, 440]), int(le.get("small_h", 180)), String(le.get("small_voice", "a_find_03")), "end_small"]]
	var d := 0.0
	for p in pairs:
		var l := add_letter(p[0], Vector2(p[1][0], p[1][1]), p[2], Assets.VOWEL_RED)
		l.name = p[4]
		l.pivot_offset = l.size / 2
		l.scale = Vector2(0.2, 0.2)
		l.modulate.a = 0.0
		var tw := l.create_tween().set_parallel()
		tw.tween_property(l, "scale", Vector2.ONE, 0.6).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "modulate:a", 1.0, 0.4).set_delay(d)
		d += 0.35
		var hit := tap_area(l)
		hit.name = p[4] + "_tap"
		var voice: String = p[3]
		hit.pressed.connect(func():
			pulse(l, 1)
			Voice.say(voice))
		main.expose(p[4], hit)
	main.set_info("s08_letters", true)

func _process(_d: float) -> void:
	_fly(_d)
	if main and main.test_mode and not finished:
		var t = _nearest_target()
		main.expose("balloon", t)
		for b in balloons:
			if is_instance_valid(b) and not b.get_meta("target") and b.position.y > 60 and b.position.y < 600:
				main.expose("wrong_balloon", b)
				break
