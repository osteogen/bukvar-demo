## Сцена 7. Шарики: лопни все шарики с А и а (3 + 3); помехи — фигуры (треугольник, круг, квадрат, звёздочка),
## потому что других букв ребёнок на уроке «А» ещё не знает.
extends LessonStep

var balloons: Array = []
var popped := 0
var total := 0
var counter: Array = []
var l_warned := false
var finished := false

func run() -> void:
	section("find")
	add_bg(cfg.bg)
	var letters: Array = cfg.targets.duplicate()
	for sh in cfg.shapes:
		letters.append("shape:" + sh)
	letters.shuffle()
	total = cfg.targets.size()
	for i in total:
		var c := add_pic(cfg.counter_empty, Vector2(512 - (total - 1) * 30 + i * 60, 50), Vector2(48, 48), false)
		counter.append(c)
	for i in letters.size():
		_spawn(letters[i], i, letters.size())
	if not await say(cfg.intro): return
	main.hint_start(_nearest_target, "h_tap_01", _auto_pop)
	main.set_state("wait_balloons")

func _spawn(ch: String, i: int, n: int) -> void:
	var colors: Array = cfg.balloon_colors
	var b := add_pic("pic_balloons_%s" % colors[i % colors.size()], Vector2(90 + i * (844.0 / (n - 1)), 900), Vector2(120, 165))
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
	l.reparent(b, false)
	l.position = Vector2(60, 68) - l.size / 2
	b.set_meta("ch", ch)
	b.set_meta("target", ch in cfg.targets)
	b.pressed.connect(func(): _on_tap(b))
	balloons.append(b)
	var rise := float(cfg.rise_sec)
	var start_y := 780.0 + (i % 3) * 120.0
	b.position.y = start_y
	var tw := b.create_tween().set_loops()
	tw.tween_property(b, "position:y", -200.0, rise * (start_y + 200.0) / 970.0)
	tw.tween_callback(func(): b.position.y = 780.0)
	var sw := b.create_tween().set_loops()
	sw.tween_property(b, "rotation", 0.08, 1.2 + (i % 3) * 0.3)
	sw.tween_property(b, "rotation", -0.08, 1.2 + (i % 3) * 0.3)

func _auto_pop() -> void:
	var b = _nearest_target()
	if b:
		_on_tap(b)
	if not finished:
		main.hint_start(_nearest_target, "h_tap_01", _auto_pop)

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
			for x in balloons:
				var tw: Tween = x.create_tween()
				tw.tween_property(x, "position:y", -300.0, 1.0)
			await wait(0.7)
			if not await praise(): return
			finish()
	else:
		Voice.sfx("sfx_try")
		shake(b, null, false)   # шарик летит дальше — только покачивание
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

func _process(_d: float) -> void:
	if main and main.test_mode and not finished:
		var t = _nearest_target()
		main.expose("balloon", t)
		for b in balloons:
			if is_instance_valid(b) and not b.get_meta("target") and b.position.y > 60 and b.position.y < 600:
				main.expose("wrong_balloon", b)
				break
