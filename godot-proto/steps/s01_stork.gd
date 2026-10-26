## Сцена 1. Аист приносит буквы (решение заказчика 26.10.2026; сценарий — ../lesson-a-demo-script.md, §2, сцена 1).
## Луг (bg_meadow), слева вверху дерево с гнездом; Али нет. Аист влетает справа с «А» и «а» в клюве (sfx_whoosh,
## на появлении — a_word_02 «А-а-а́ист»), роняет буквы — они падают и встают в центре (белая обводка, без подложки),
## делает 1,5 круга в верхней части экрана и садится в гнездо — и остаётся там. «Далее» — после посадки, автоперехода нет.
## Касания: буква → подскок + a_aaa (нет записи — a_find_03); аист в гнезде → a_word_02 и взмах крыльями (пока реплика
## звучит, повторное касание её не перезапускает; на «Далее» не влияет). В полёте аист касаний не принимает.
## Подсказка: 20 с без касаний → рука на большой «А» (без голоса); когда есть «Далее» — на «Далее».
## Все числа — lesson.json → "stork" (из art/lesson_a/s01_dlya_koda.txt, раунд 13). Точки пути — положение PIV летящего
## аиста (центр тела); кадры полёта смотрят ВЛЕВО, при движении вправо — зеркало (flip_h; PIV и крепления x' = 280 − x).
## Первый жест (iOS): пока касания не было — луг, дерево и пустое гнездо; гнездо мягко пульсирует, рука на нём
## (LessonStep.unlock_gate, stork.unlock_tap).
extends LessonStep

var tree_pic: TextureRect
var nest_sit: TextureRect
var nest_front: TextureRect
var bird: TextureRect                 # летящий аист (кадр 280×242, масштаб fly.scale)
var hang := {}                        # "big"/"small" -> TextureRect буквы (пока висит — ребёнок bird)
var ground := {}                      # "big"/"small" -> Rect2 буквы на земле (вся картинка, с обводкой)
var letter_btn := {}                  # "big"/"small" -> Button зоны касания
var touch_btn: Button                 # касание аиста в гнезде

var fly: Dictionary
var nest: Dictionary
var lt: Dictionary
var _frames: Array = []               # текущая пара кадров [up, down]
var _wing := 0
var _wing_t := 0.0
var _flying := false
var _mirror := false                  # кадр зеркальный (аист летит вправо)
var _sq := 1.0                        # сжатие по X при развороте (1 — нет)
var _flip_t := -1.0                   # время от начала разворота (−1 — не разворачивается)
var _flip_to := false
var _hang_kind := "carry"
var _piv := Vector2.ZERO
var _last_piv := Vector2.ZERO
var _letters_down := false
var _landed := false
var _word_until := 0                  # до какого момента (мс) звучит a_word_02 по касанию аиста
var _word_token := -1
var _flapping := false
var _n := {"word_taps": 0, "word_plays": 0, "flaps": 0, "letter_taps": 0}

const SPRITE := {"big": {"size": Vector2(693, 812), "glyph": Rect2(20, 20, 646, 765)},
	"small": {"size": Vector2(520, 610), "glyph": Rect2(20, 20, 473, 563)}}

func _v(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))

func _r(a) -> Rect2:
	return Rect2(float(a[0]), float(a[1]), float(a[2]) - float(a[0]), float(a[3]) - float(a[1]))

func _tex_rect(id: String, pos: Vector2, sz: Vector2, nm: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Assets.tex(id)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = pos
	r.size = sz
	r.name = nm
	return r

func run() -> void:
	section("stork")
	fly = cfg.fly
	nest = cfg.nest
	lt = cfg.letters
	add_bg(cfg.bg)
	tree_pic = _tex_rect(String(cfg.tree.id), _v(cfg.tree.pos), _v(cfg.tree.size), "pic_nest_tree")
	add_child(tree_pic)
	var no := _v(nest.origin)
	var ns := _v(nest.size)
	nest_sit = _tex_rect(String(nest.sit), no, ns, "stork_nest")
	nest_sit.pivot_offset = _v(nest.pivot)
	nest_sit.visible = false
	add_child(nest_sit)
	nest_front = _tex_rect(String(nest.front), no, ns, "pic_nest")
	nest_front.pivot_offset = Vector2(110, 180)       # центр чаши (x 360, y ≈ 204 на сцене) — для пульсации до первого касания
	add_child(nest_front)
	main.expose("nest", nest_front)
	# буквы на земле: рамки глифов из txt (по альфе спрайта) → прямоугольник всей картинки
	for k in ["big", "small"]:
		var g: Rect2 = _r(lt[k])
		var sp: Dictionary = SPRITE[k]
		var s: float = g.size.y / sp.glyph.size.y
		ground[k] = Rect2(g.position - sp.glyph.position * s, sp.size * s)
	main.set_info("s01_phase", "gate")
	main.set_info("s01_ground", {"big": _r4(ground.big), "small": _r4(ground.small)})
	if not await unlock_gate(nest_front, cfg.get("unlock_tap", {})): return
	main.hint_start(func(): return letter_btn.get(String(cfg.get("hint_target", "big"))) if _letters_down else null, "")
	await _fly_in()
	if dead: return
	if not await _rise_and_circle(): return
	if not await _approach_and_land(): return
	main.set_info("s01_phase", "landed")
	finish()

func _r4(r: Rect2) -> Array:
	return [snappedf(r.position.x, 0.1), snappedf(r.position.y, 0.1), snappedf(r.end.x, 0.1), snappedf(r.end.y, 0.1)]

# ---------- летящий аист ----------
func _make_bird() -> void:
	bird = _tex_rect(String(fly.carry[0]), Vector2.ZERO, _v(fly.size), "stork_fly")
	add_child(bird)
	for k in ["big", "small"]:
		var sp: Dictionary = SPRITE[k]
		var h: float = float(fly.hang_height[k])
		var r := _tex_rect(Assets.letter_name("letter", cfg_letter(k)), Vector2.ZERO, sp.size * (h / sp.glyph.size.y), "hang_" + k)
		r.show_behind_parent = true      # буквы под аистом
		bird.add_child(r)
		hang[k] = r
	_set_frames("carry")
	main.expose("stork", bird)

func cfg_letter(k: String) -> String:
	return String(Assets.lesson.get(k, "А" if k == "big" else "а"))

func _set_frames(kind: String) -> void:
	_frames = [Assets.tex(String(fly[kind][0])), Assets.tex(String(fly[kind][1]))]
	_hang_kind = kind
	bird.texture = _frames[_wing]

## Поставить аиста: PIV в точку p сцены. Зеркало — flip_h кадра, PIV и крепления x' = 280 − x; буквы не зеркалятся.
func _place(p: Vector2) -> void:
	_last_piv = _piv
	_piv = p
	var fs: Vector2 = _v(fly.size)
	var pv: Vector2 = _v(fly.pivot)
	if _mirror:
		pv.x = fs.x - pv.x
	bird.flip_h = _mirror
	bird.pivot_offset = pv
	bird.position = p - pv
	var sc := float(fly.scale)
	bird.scale = Vector2(sc * _sq, sc)
	for k in hang:
		var r: TextureRect = hang[k]
		if r.get_parent() != bird:
			continue
		var a: Vector2 = _v(fly["hang_" + _hang_kind][k])
		if _mirror:
			a.x = fs.x - a.x
		var sp: Dictionary = SPRITE[k]
		var s: float = r.size.y / sp.size.y
		var top_mid: Vector2 = (sp.glyph.position + Vector2(sp.glyph.size.x / 2, 0)) * s
		r.position = a - top_mid
	main.set_info("s01_fly_rect", _r4(bird.get_global_rect()))

## Разворот на месте (кадр сжимается по X до 0 и раскрывается зеркальным), неблокирующий.
func _flip(to_mirror: bool) -> void:
	if _flip_t >= 0.0:
		_flip_to = to_mirror
		return
	if to_mirror == _mirror:
		return
	_flip_to = to_mirror
	_flip_t = 0.0

func _process(delta: float) -> void:
	if not _flying or bird == null:
		return
	_wing_t += delta
	if _wing_t >= float(fly.wing_sec):
		_wing_t = 0.0
		_wing = 1 - _wing
		bird.texture = _frames[_wing]
	if _flip_t >= 0.0:
		var fsec := float(fly.flip_sec)
		_flip_t += delta
		var u := clampf(_flip_t / fsec, 0.0, 1.0)
		if u >= 0.5 and _mirror != _flip_to:
			_mirror = _flip_to
		_sq = maxf(0.04, absf(1.0 - 2.0 * u))
		if u >= 1.0:
			_flip_t = -1.0
			_sq = 1.0
		_place(_piv)

## Покадровая анимация: f(u), u 0→1 за sec (в реальном времени, и в тесте тоже).
func _anim(sec: float, f: Callable) -> bool:
	var t := 0.0
	while t < sec:
		if dead:
			return false
		f.call(t / sec)
		await get_tree().process_frame
		t += get_process_delta_time()
	if dead:
		return false
	f.call(1.0)
	return true

func _fly_in() -> void:
	main.set_state("fly_in")
	main.set_info("s01_phase", "fly_in")
	_make_bird()
	var pts: Array = []
	for a in fly.enter:
		pts.append(_v(a))
	var lens: Array = [0.0]
	for i in range(1, pts.size()):
		lens.append(float(lens[i - 1]) + (pts[i] - pts[i - 1]).length())
	var total: float = lens[-1]
	_mirror = false
	_flying = true
	_place(pts[0])
	Voice.sfx(String(fly.get("whoosh", "sfx_whoosh")))
	var said := [false]
	var at_x := float(cfg.get("voice_at_x", 1150))
	await _anim(total / float(fly.enter_speed), func(u):
		var d: float = u * total
		var i := 1
		while i < pts.size() - 1 and d > float(lens[i]):
			i += 1
		var seg: float = float(lens[i]) - float(lens[i - 1])
		var w: float = (d - float(lens[i - 1])) / seg if seg > 0 else 1.0
		_place((pts[i - 1] as Vector2).lerp(pts[i], clampf(w, 0, 1)))
		if not said[0] and _piv.x <= at_x:
			said[0] = true
			main.set_info("s01_appear_voice", String(cfg.voice_appear))
			Voice.say(String(cfg.voice_appear)))
	if dead: return
	_drop()

## DROP: буквы отцепляются в текущем месте и падают на землю, растут до размера на земле, мягко приседают.
func _drop() -> void:
	main.set_state("drop")
	main.set_info("s01_phase", "drop")
	var at := {}
	var inv := get_global_transform().affine_inverse()
	for k in hang:
		var r: TextureRect = hang[k]
		var g := r.get_global_rect()
		r.get_parent().remove_child(r)
		r.show_behind_parent = false
		add_child(r)
		move_child(r, nest_front.get_index() + 1)     # над гнездом, под летящим аистом
		# в координатах шага (шаг может быть сдвинут/уменьшен — берём локальные)
		var p0: Vector2 = inv * g.position
		var p1: Vector2 = inv * g.end
		r.position = p0
		r.size = p1 - p0
		var sp: Dictionary = SPRITE[k]
		var gs: float = r.size.y / sp.size.y
		at[k] = [snappedf(p0.x + (sp.glyph.position.x + sp.glyph.size.x / 2) * gs, 0.1), snappedf(p0.y + sp.glyph.position.y * gs, 0.1)]
		r.name = "letter_" + k
		r.pivot_offset = Vector2(r.size.x / 2, r.size.y)
		var dst: Rect2 = ground[k]
		var tw := r.create_tween().set_parallel()
		var ds := float(lt.drop_sec)
		tw.tween_property(r, "position", dst.position, ds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(r, "size", dst.size, ds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(r, "pivot_offset", Vector2(dst.size.x / 2, dst.size.y), ds)
		tw.chain().tween_property(r, "scale", Vector2(1.0 + float(lt.land_squash), 1.0 - float(lt.land_squash)), 0.08)
		tw.chain().tween_property(r, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if k == "small":
			tw.chain().tween_callback(_letters_landed)
	main.set_info("s01_drop_at", at)
	_set_frames("open")

func _letters_landed() -> void:
	if dead:
		return
	_letters_down = true
	var pad: Array = lt.get("tap_pad", [12, 12, 20, 20])
	for k in ["big", "small"]:
		var r: TextureRect = hang[k]
		var g: Rect2 = _r(lt[k])
		var b := tap_area(r)
		b.position = g.position - Vector2(float(pad[0]), float(pad[1]))
		b.size = g.size + Vector2(float(pad[0]) + float(pad[2]), float(pad[1]) + float(pad[3]))
		b.name = "tap_" + k
		b.set_meta("no_overlap_check", true)
		b.pressed.connect(_on_letter.bind(k))
		letter_btn[k] = b
		main.expose(k, b)
		main.set_info("s01_tap_" + k, _r4(b.get_rect()))
	move_child(bird, -1)
	main.set_info("s01_letters_down", true)

func _rise_and_circle() -> bool:
	main.set_state("rise")
	main.set_info("s01_phase", "rise")
	var a := _piv
	var b: Vector2 = _v(fly.rise_to)
	if not await _anim(float(fly.rise_sec), func(u): _place(a.lerp(b, u))): return false
	main.set_state("circle")
	main.set_info("s01_phase", "circle")
	var c: Dictionary = fly.circle
	var ctr: Vector2 = _v(c.center)
	var rx := float(c.rx)
	var ry := float(c.ry)
	var t0 := deg_to_rad(float(c.t0_deg))
	var t1 := deg_to_rad(float(c.t1_deg))
	var ms0 := Time.get_ticks_msec()
	var ok := await _anim(float(c.sec), func(u):
		var t: float = lerpf(t0, t1, u)
		# x = cx + rx·cos t: dx/dt = −rx·sin t > 0 (вправо) при sin t < 0
		var right := sin(t) < -0.0001
		if absf(sin(t)) > 0.0001 and right != (_flip_to if _flip_t >= 0.0 else _mirror):
			_flip(right)
		_place(ctr + Vector2(rx * cos(t), ry * sin(t))))
	main.set_info("s01_circle_sec", (Time.get_ticks_msec() - ms0) / 1000.0)
	return ok

func _approach_and_land() -> bool:
	# в верхней точке аист летит вправо (зеркало); подлёт — влево: разворот на месте
	main.set_state("approach")
	main.set_info("s01_phase", "flip")
	await _wait_flip()
	if dead: return false
	_flip(false)
	await _wait_flip()
	if dead: return false
	main.set_info("s01_phase", "approach")
	var a := _piv
	var b: Vector2 = _v(nest.land)
	var arc := float(fly.approach_arc)
	if not await _anim(float(fly.approach_sec), func(u):
		_place(a.lerp(b, u) - Vector2(0, arc * sin(PI * u)))): return false
	# посадка: летящий кадр → stork_nest_sit, масштаб 0,61 → 1,0 вокруг опоры (= LAND)
	main.set_state("land")
	main.set_info("s01_phase", "land")
	_flying = false
	main.expose("stork", null)
	bird.queue_free()
	bird = null
	nest_sit.visible = true
	var ls: Array = nest.land_scale
	nest_sit.scale = Vector2.ONE * float(ls[0])
	var tw := nest_sit.create_tween()
	tw.tween_property(nest_sit, "scale", Vector2.ONE * float(ls[1]), float(nest.land_sec))
	await tw.finished
	if dead: return false
	_landed = true
	main.set_info("s01_land_pos", [nest_sit.position.x + nest_sit.pivot_offset.x, nest_sit.position.y + nest_sit.pivot_offset.y])
	touch_btn = Button.new()
	touch_btn.flat = true
	touch_btn.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus"]:
		touch_btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var tr: Rect2 = _r(nest.touch)
	touch_btn.position = tr.position
	touch_btn.size = tr.size
	touch_btn.name = "tap_stork"
	touch_btn.set_meta("no_overlap_check", true)   # прозрачная зона касания; видимые слои — stork_nest / pic_nest
	touch_btn.pressed.connect(_on_stork)
	add_child(touch_btn)
	main.expose("stork_nest", touch_btn)
	return true

func _wait_flip() -> void:
	while _flip_t >= 0.0 and not dead:
		await get_tree().process_frame

# ---------- касания ----------
## Аист в гнезде: a_word_02 + взмах крыльями; пока реплика звучит — повторное касание ничего не перезапускает.
func _on_stork() -> void:
	if dead or not _landed:
		return
	_n.word_taps += 1
	main.set_info("s01_word_taps", _n.word_taps)
	if Time.get_ticks_msec() < _word_until and Voice._token == _word_token:
		return
	var st: Dictionary = cfg.get("stork_tap", {})
	var id := String(st.get("audio", cfg.voice_appear))
	var s := Voice._stream(id)
	_n.word_plays += 1
	main.set_info("s01_word_plays", _n.word_plays)
	var len_sec: float = s.get_length() if s and s.get_length() > 0.0 else Assets.line_dur(id)
	Voice.stop_voice()
	_word_token = Voice._token
	_word_until = Time.get_ticks_msec() + int(len_sec * 1000.0)
	if s:
		Voice.voice.stream = s
		Voice.voice.play()
	_flap(st)

func _flap(st: Dictionary) -> void:
	if _flapping:
		return
	_flapping = true
	_n.flaps += 1
	main.set_info("s01_flaps", _n.flaps)
	var fr: Array = nest.flap
	var sec := float(st.get("flap_frame_sec", 0.14))
	for i in int(st.get("flap_cycles", 3)) * 2:
		if dead:
			return
		nest_sit.texture = Assets.tex(String(fr[i % 2]))
		main.set_info("s01_nest_frame", String(fr[i % 2]))
		await get_tree().create_timer(sec).timeout
	if dead:
		return
	nest_sit.texture = Assets.tex(String(nest.sit))
	main.set_info("s01_nest_frame", String(nest.sit))
	_flapping = false

## Буква: подскок + a_aaa (нет записи — fallback, нет и его — только подскок). Можно сколько угодно.
func _on_letter(k: String) -> void:
	if dead:
		return
	var r: TextureRect = hang[k]
	_bounce(r, float(lt.get("bounce_px", 14)), float(lt.get("bounce_sec", 0.32)))
	_n.letter_taps += 1
	main.set_info("s01_letter_taps", _n.letter_taps)
	var dt: Dictionary = cfg.get("letter_tap", {})
	var id := String(dt.get("audio", "a_aaa"))
	if Voice._stream(id) == null:
		id = String(dt.get("fallback", ""))
	var ok := id != "" and Voice._stream(id) != null
	main.set_info("s01_aaa_audio", id if ok else "")
	if not ok:
		return
	Voice.stop_voice()
	var s := Voice._stream(id)
	Voice.voice.stream = s
	Voice.voice.play()
	var my := Voice._token
	await get_tree().create_timer(float(dt.get("max_sec", 1.8))).timeout
	if Voice._token == my and is_instance_valid(self) and Voice.voice.stream == s:
		Voice.voice.stop()

func _bounce(b: Control, px: float, sec: float) -> void:
	if b.has_meta("bounce_y"):
		b.position.y = b.get_meta("bounce_y")
	else:
		b.set_meta("bounce_y", b.position.y)
	var y0: float = b.get_meta("bounce_y")
	var tw := b.create_tween()
	tw.tween_property(b, "position:y", y0 - px, sec * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): main.set_info("s01_bounce_peak", {"n": _n.letter_taps, "px": y0 - b.position.y}))
	tw.tween_property(b, "position:y", y0, sec * 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
