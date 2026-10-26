## Сцена 8. Корзинки: перетащить 6 плиток (А — в большую, а — в маленькую).
## Раскладка — из данных (sort.layout в lesson.json, всё необязательно; по умолчанию — как раньше): корзинки
## (картинка/центр/размер), места плиток (tiles_at — список центров, напр. «на кустах» сверху, или ряд), размер плитки.
## sort.success_pic (напр. "pic_ananas"): плитка, верно положенная в корзинку, превращается в эту картинку внутри корзинки;
## пусто — как раньше: плитка уменьшается над корзинкой, а в корзинке появляется fill_pic.
## sort.done_tap: ПОСЛЕ того как разложены все плитки (сцена пройдена), касание любой корзинки — «А-а-а» голосом Али
## (audio, при отсутствии файла — fallback, нет и его — тишина) и лёгкий подскок корзинки. До конца сцены корзинки
## на касание не отвечают (ничего не подтверждают). Картинки/центры/размеры корзинок — только в sort.layout.
## Плитка попадает в корзинку ТОЛЬКО когда её туда перетащит ребёнок (DESIGN_RULES.md, §1).
## Раскладка v3 (утверждена 26.10.2026; признак — у корзинки есть states): грядка + 6 кустов-ананасов сверху,
## на каждом висит плитка; внизу корзинки без ручек с состояниями 0–4 (число ананасов), зона сброса — drop;
## верно положенная плитка превращается в ананас (morph.frames + вспышка morph.flash), корзинка → следующее состояние;
## после последней плитки обе корзинки — в состоянии 4. Все числа — в sort.layout (lesson.json).
extends LessonStep

var tiles: Array = []
var basket_big: TextureButton
var basket_small: TextureButton
var drag_tile: Control = null
var drag_off := Vector2.ZERO
var placed := 0
var count_big := 0
var count_small := 0
var finished := false
var tile_size := Vector2(120, 120)

func _v(a, def: Vector2) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a is Array and a.size() >= 2 else def

func run() -> void:
	section("sort")
	add_bg(cfg.bg)
	lay = cfg.get("layout", {})
	_add_sun(cfg.get("sun", {}))
	var bb: Dictionary = lay.get("basket_big", {})
	var bs: Dictionary = lay.get("basket_small", {})
	v3 = bb.has("states") and bs.has("states")
	tile_size = _v(lay.get("tile_size"), Vector2(120, 120))
	var at: Array = lay.get("tiles_at", [])
	if v3:
		_add_bed(lay.get("bed", {}))
		var bu: Dictionary = lay.get("bushes", {})
		var off := _v(lay.get("tile_offset"), Vector2(0, -120))
		var by := float(bu.get("base_y", 346))
		at = []
		for x in bu.get("x_list", []):
			_add_bush(String(bu.get("pic", "s8_bush_empty")), float(x), by, float(bu.get("width", 170)))
			# tile_y — центр плиток одним рядом (финал иллюстратора: y 220); нет ключа — от низа куста + tile_offset
			at.append([float(x) + off.x, float(lay.get("tile_y", by + off.y))])
		basket_big = _add_basket(bb)
		basket_small = _add_basket(bs)
	else:
		basket_big = add_pic(String(bb.get("pic", "pic_basket_big")), _v(bb.get("center"), Vector2(300, 600)), _v(bb.get("size"), Vector2(300, 240)), false)
		basket_small = add_pic(String(bs.get("pic", "pic_basket_small")), _v(bs.get("center"), Vector2(740, 620)), _v(bs.get("size"), Vector2(240, 190)), false)
		var lb := add_letter(Assets.lesson.big, Vector2(150, 75), 90)
		lb.reparent(basket_big, false)
		lb.position = Vector2(150, 70) - lb.size / 2
		var ls := add_letter(Assets.lesson.small, Vector2(120, 60), 70)
		ls.reparent(basket_small, false)
		ls.position = Vector2(120, 55) - ls.size / 2
	main.expose("basket_big", basket_big)
	main.expose("basket_small", basket_small)
	var order: Array = cfg.tiles.duplicate()
	if bool(cfg.get("shuffle", true)):
		order.shuffle()
	for i in order.size():
		var t := _make_tile(order[i], _v(at[i], Vector2.ZERO) if i < at.size() else Vector2(132 + i * 152, 200))
		tiles.append(t)
		Voice.sfx("sfx_pop")
		if not await wait(0.3): return
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(func(): pulse(basket_big, 2))
	tw.tween_interval(1.6)
	tw.tween_callback(func(): pulse(basket_small, 2))
	if not await say(cfg.intro): return
	_hint()
	main.set_state("wait_drag")

var lay: Dictionary = {}
var v3 := false

func _rect(a, def := Rect2()) -> Rect2:
	return Rect2(float(a[0]), float(a[1]), float(a[2]) - float(a[0]), float(a[3]) - float(a[1])) if a is Array and a.size() >= 4 else def

## Грядка под кустами: верх и передняя стенка (плоские цвета из sort.layout.bed).
func _add_bed(bd: Dictionary) -> void:
	if bd.is_empty():
		return
	var r := _rect(bd.get("rect"), Rect2(92, 312, 840, 72))
	var fy := float(bd.get("front_y", r.position.y + r.size.y * 0.55))
	var rad := int(bd.get("radius", 18))
	for part in [[Rect2(r.position, Vector2(r.size.x, r.end.y - r.position.y)), String(bd.get("top", "#B48A5C"))],
			[Rect2(r.position.x, fy, r.size.x, r.end.y - fy), String(bd.get("front", "#9A7249"))]]:
		var p := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(part[1])
		sb.set_corner_radius_all(rad)
		p.add_theme_stylebox_override("panel", sb)
		p.position = part[0].position
		p.size = part[0].size
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.name = "bed"
		add_child(p)

func _add_bush(id: String, x: float, base_y: float, w: float) -> void:
	var t := TextureRect.new()
	t.texture = Assets.tex(id)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var h := w * (t.texture.get_height() / float(t.texture.get_width()) if t.texture else 0.8)
	t.size = Vector2(w, h)
	t.position = Vector2(x - w / 2, base_y - h)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.name = "bush"
	add_child(t)

## Корзинка v3: картинка состояния 0 в своей рамке (frame); зона сброса drop хранится в meta.
func _add_basket(d: Dictionary) -> TextureButton:
	var fr := _rect(d.get("frame"), Rect2(200, 430, 240, 316))
	var b := TextureButton.new()
	b.texture_normal = Assets.tex(String(d.states[0]))
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.position = fr.position
	b.size = fr.size
	b.pivot_offset = Vector2(fr.size.x / 2, fr.size.y)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.name = String(d.states[0])
	b.set_meta("states", d.states)
	b.set_meta("drop", _rect(d.get("drop"), fr.grow(12)))
	b.set_meta("silhouette", _rect(d.get("silhouette"), fr))
	add_child(b)
	# финал: табличка в картинке корзинки пустая, буква — отдельный слой на том же холсте (letter), поверх любого состояния
	var lt := Assets.tex(String(d.get("letter", "")), false) if d.has("letter") else null
	if lt:
		var l := TextureRect.new()
		l.name = "letter"
		l.texture = lt
		l.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		l.stretch_mode = TextureRect.STRETCH_SCALE
		l.size = fr.size
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
	if d.has("label"):   # тест: табличка (координаты сцены)
		var lr := _rect(d.get("label"), fr)
		main.set_info("s09_label_" + ("big" if String(d.states[0]).contains("big") else "small"), [lr.position.x, lr.position.y, lr.end.x, lr.end.y])
	return b

func _set_state(b: TextureButton, n: int) -> void:
	if not b.has_meta("states"):
		return
	var st: Array = b.get_meta("states")
	n = clampi(n, 0, st.size() - 1)
	var tx := Assets.tex(String(st[n]))
	if tx:
		b.texture_normal = tx
	main.set_info("s09_state_" + ("big" if b == basket_big else "small"), n)

## Зона сброса (в координатах сцены): v3 — sort.layout.*.drop, иначе — корзинка + 20.
func _drop_rect(b: Control) -> Rect2:
	return b.get_meta("drop") if b.has_meta("drop") else Rect2(b.position, b.size).grow(20)

func _make_tile(ch: String, center: Vector2) -> Control:
	# плитка с буквой целиком — tile_<x>_<upper|lower>.png (v3 — sort.layout.tile_pics)
	var t := TextureRect.new()
	var tp: Dictionary = lay.get("tile_pics", {})
	t.texture = Assets.tex(String(tp[ch])) if tp.has(ch) else null
	if t.texture == null:
		t.texture = Assets.tex(Assets.letter_name("tile", ch))
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.size = tile_size
	t.position = center - t.size / 2
	t.pivot_offset = t.size / 2
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.set_meta("ch", ch)
	t.set_meta("home", t.position)
	t.set_meta("errors", 0)
	add_child(t)
	t.gui_input.connect(func(ev): _tile_input(t, ev))
	pop_in(t)
	return t

func _first_tile():
	for t in tiles:
		if is_instance_valid(t) and not t.get_meta("placed", false):
			return t
	return null

func _hint() -> void:
	var t = _hint_tile()
	if t == null:
		return
	main.expose("tile", t)
	main.expose("tile_basket", _basket_for(t))
	# рука «ведёт» плитку к её корзинке; положить плитку может только ребёнок
	main.hint_start(_hint_tile, "h_drag_01", _hint_basket)

## После ошибок подсказка — про ту плитку, с которой ошиблись (пока она не положена).
var hint_tile: Control = null

func _hint_tile():
	if hint_tile and is_instance_valid(hint_tile) and not hint_tile.get_meta("placed", false):
		return hint_tile
	return _first_tile()

func _hint_basket():
	var x = _hint_tile()
	return _basket_for(x) if x else null

func _basket_for(t: Control) -> Control:
	return basket_big if t.get_meta("ch") == Assets.lesson.big else basket_small

func _tile_input(t: Control, ev: InputEvent) -> void:
	if finished or t.get_meta("placed", false):
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed and drag_tile == null:
			drag_tile = t
			drag_off = ev.position
			t.move_to_front()
			t.scale = Vector2(1.15, 1.15)
			main.hint_stop()
		elif not ev.pressed and drag_tile == t:
			drag_tile = null
			t.scale = Vector2.ONE
			_drop(t)
	elif ev is InputEventMouseMotion and drag_tile == t:
		# абсолютная позиция под пальцем (относительные сдвиги на быстрых жестах теряются)
		t.position = get_local_mouse_position() - drag_off * t.scale

func _drop(t: Control) -> void:
	var c := t.position + t.size / 2   # центр плитки в координатах сцены
	var right := _basket_for(t)
	var wrong := basket_small if right == basket_big else basket_big
	if _drop_rect(right).has_point(c):
		_place(t)
	elif _drop_rect(wrong).has_point(c):
		t.set_meta("errors", t.get_meta("errors") + 1)
		Voice.sfx("sfx_try")   # без подсветки верной корзинки: любые подсказки — только после 20 с бездействия
		# плитка всегда покачивается и плавно возвращается на своё место — сама в корзинку она не попадает
		shake(t, t.get_meta("home"))
		hint_tile = t
		get_tree().create_timer(0.7).timeout.connect(_after_error.bind(right, t.get_meta("errors") >= 2))
	else:
		_go_home(t)

func _after_error(right: Control, again: bool) -> void:
	if dead or finished:
		return
	_hint()
	if again:
		main.hint_now()   # после 2-й ошибки рука сразу ведёт эту плитку к верной корзинке

func _go_home(t: Control) -> void:
	var tw := t.create_tween()
	tw.tween_property(t, "position", t.get_meta("home"), 0.3).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_hint)

func _place(t: Control) -> void:
	if t.get_meta("placed", false):
		return
	t.set_meta("placed", true)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b := _basket_for(t)
	var is_big := b == basket_big
	var n := count_big if is_big else count_small
	if is_big: count_big += 1
	else: count_small += 1
	var swap := String(cfg.get("success_pic", ""))
	var swap_tex: Texture2D = Assets.tex(swap, false) if swap != "" else null
	if v3:
		_morph(t, b, n + 1)
	elif swap_tex:
		# плитка «превращается» в картинку (напр. ананас) внутри корзинки
		var dest2 := b.position + Vector2(b.size.x * (0.25 + 0.25 * (n % 3)), b.size.y * 0.55) - t.size / 2
		var tw2 := t.create_tween()
		tw2.tween_property(t, "position", dest2, 0.3)
		tw2.tween_property(t, "scale", Vector2(0.1, 0.1), 0.12)
		tw2.tween_callback(func(): t.texture = swap_tex)
		tw2.tween_property(t, "scale", Vector2(0.55, 0.55), 0.2).set_trans(Tween.TRANS_BACK)
	else:
		var dest := b.position + Vector2(40 + n * 70, -40)
		var tw := t.create_tween().set_parallel()
		tw.tween_property(t, "position", dest, 0.35)
		tw.tween_property(t, "scale", Vector2(0.5, 0.5), 0.35)
		var fill := add_pic(cfg.fill_pic, b.position + Vector2(60 + n * 60, b.size.y - 60), Vector2(48, 48), false)   # гриб (без красного)
		pop_in(fill)
	Voice.sfx("sfx_ok")
	_drop_say()   # верно положенная плитка звучит: [а] (очередь голоса — без наложения)
	placed += 1
	main.log_event("tile", {"ch": t.get_meta("ch"), "errors": t.get_meta("errors")})
	if placed >= tiles.size():
		finished = true
		main.hint_stop()
		if v3:
			get_tree().create_timer(_morph_total()).timeout.connect(func():
				if dead: return
				for bk in [basket_big, basket_small]:
					_set_state(bk, 4)
					pop_in(bk))
		pulse(basket_big, 2)
		pulse(basket_small, 2)
		Voice.sfx("sfx_cheer")
		if not await praise(): return
		finish()
		_enable_done_taps()
	else:
		if placed % 2 == 0:
			praise()
		_hint()

## Звук буквы при верном сбросе: sort.drop_say {audio, fallback, max_sec}; нет файла — тишина (субтитр в ?debug=1).
func _drop_say() -> void:
	var ds: Dictionary = cfg.get("drop_say", {})
	if ds.is_empty():
		return
	var id := String(ds.get("audio", "a_aaa"))
	if Voice._stream(id) == null and String(ds.get("fallback", "")) != "":
		id = String(ds.get("fallback"))
	main.set_info("s09_drop_audio", id)
	main.set_info("s09_drop_says", int(main.info.get("s09_drop_says", 0)) + 1)
	Voice.tap_say(id, float(ds.get("max_sec", 1.8)))

## Солнце по центру сверху (над ананасами) с длинными полупрозрачными лучами; статичное, касания не ловит.
## sort.sun {pic, rays, center, size, rays_size, rays_apex (точка схода лучей внутри картинки лучей, доли), rays_alpha}.
func _add_sun(sd: Dictionary) -> void:
	if sd.is_empty():
		return
	var c := _v(sd.get("center"), Vector2(512, 62))
	var rs := _v(sd.get("rays_size"), Vector2(700, 380))
	var apex := _v(sd.get("rays_apex"), Vector2(0.5, 0.053))
	var rt := Assets.tex(String(sd.get("rays", "pic_sun_rays")), false)
	if rt:
		var r := TextureRect.new()
		r.name = "sun_rays"
		r.texture = rt
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.size = rs
		r.position = c - rs * apex
		r.modulate.a = float(sd.get("rays_alpha", 1.0))
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
	var s := add_pic(String(sd.get("pic", "pic_sun")), c, _v(sd.get("size"), Vector2(104, 104)), false)
	s.name = "sun"
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.set_info("s09_sun", [c.x, c.y])

# ---------- v3: плитка → ананас ----------
func _morph_total() -> float:
	var m: Dictionary = lay.get("morph", {})
	return float(m.get("fly_sec", 0.3)) + float(m.get("frame_sec", 0.14)) * (m.get("frames", []).size() + 1) + 0.05

## Плитка летит к корзинке, сжимается; на её месте кадры превращения (f1 → f2 → f3) со вспышкой, затем
## корзинка переходит в состояние n (столько ананасов внутри, максимум 3 во время игры).
func _morph(t: Control, b: TextureButton, n: int) -> void:
	var m: Dictionary = lay.get("morph", {})
	var sil: Rect2 = b.get_meta("silhouette")
	var at := Vector2(sil.get_center().x, sil.position.y - 10)
	var fly := float(m.get("fly_sec", 0.3))
	var fs := float(m.get("frame_sec", 0.14))
	var msz := _v(m.get("size"), Vector2(130, 130))
	var tw := t.create_tween()
	tw.tween_property(t, "position", at - t.size / 2, fly).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	if dead:
		return
	t.visible = false
	var fl := TextureRect.new()
	fl.texture = Assets.tex(String(m.get("flash", "s8_flash_2")), false)
	var mo := TextureRect.new()
	for r in [fl, mo]:
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.size = msz
		r.position = at - msz / 2
		r.pivot_offset = msz / 2
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
	fl.name = "s8_flash"
	mo.name = "s8_morph"
	if fl.texture:
		fl.scale = Vector2(0.6, 0.6)
		var tf := fl.create_tween().set_parallel()
		tf.tween_property(fl, "scale", Vector2(1.35, 1.35), fs * 3)
		tf.tween_property(fl, "modulate:a", 0.0, fs * 3).set_delay(fs)
	for f in m.get("frames", []):
		var tx := Assets.tex(String(f), false)
		if tx:
			mo.texture = tx
		if not await wait(fs): return
	_set_state(b, mini(n, 3))
	var to := mo.create_tween()
	to.tween_property(mo, "modulate:a", 0.0, fs)
	to.tween_callback(mo.queue_free)
	to.tween_callback(fl.queue_free)

# ---------- после конца сцены: корзинки «поют» А-а-а ----------
var _taps := 0

func _enable_done_taps() -> void:
	if dead:
		return
	for b in [basket_big, basket_small]:
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.pressed.connect(_on_basket_done_tap.bind(b))
	main.set_info("s09_done_taps", 0)

func _on_basket_done_tap(b: TextureButton) -> void:
	if dead or not finished:
		return
	var dt: Dictionary = cfg.get("done_tap", {})
	_bounce(b, float(dt.get("bounce_px", 14)), float(dt.get("bounce_sec", 0.32)))
	var id := String(dt.get("audio", "a_sort_aaa"))
	if Voice._stream(id) == null:
		id = String(dt.get("fallback", ""))
	_taps += 1
	main.set_info("s09_done_taps", _taps)
	main.set_info("s09_done_audio", id if id != "" and Voice._stream(id) != null else "")
	if id == "" or Voice._stream(id) == null:
		return   # записи ещё нет — молча, только подскок
	Voice.tap_say(id, float(dt.get("max_sec", 1.8)))   # очередь голоса: без наложения, без дублей

func _bounce(b: Control, px: float, sec: float) -> void:
	if b.has_meta("bounce_y"):
		b.position.y = b.get_meta("bounce_y")
	else:
		b.set_meta("bounce_y", b.position.y)
	var y0: float = b.get_meta("bounce_y")
	var tw := b.create_tween()
	tw.tween_property(b, "position:y", y0 - px, sec * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): main.set_info("s09_bounce_peak", {"n": _taps, "px": y0 - b.position.y}))
	tw.tween_property(b, "position:y", y0, sec * 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
