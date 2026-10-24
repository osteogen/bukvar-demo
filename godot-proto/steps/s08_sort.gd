## Сцена 8. Корзинки: перетащить 6 плиток (А — в большую, а — в маленькую).
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

func run() -> void:
	section("sort")
	add_bg(cfg.bg)
	basket_big = add_pic("pic_basket_big", Vector2(300, 600), Vector2(300, 240), false)
	basket_small = add_pic("pic_basket_small", Vector2(740, 620), Vector2(240, 190), false)
	var lb := add_letter(Assets.lesson.big, Vector2(150, 75), 90)
	lb.reparent(basket_big, false)
	lb.position = Vector2(150, 70) - lb.size / 2
	var ls := add_letter(Assets.lesson.small, Vector2(120, 60), 70)
	ls.reparent(basket_small, false)
	ls.position = Vector2(120, 55) - ls.size / 2
	main.expose("basket_big", basket_big)
	main.expose("basket_small", basket_small)
	var order: Array = cfg.tiles.duplicate()
	order.shuffle()
	for i in order.size():
		var t := _make_tile(order[i], Vector2(132 + i * 152, 200))
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

func _make_tile(ch: String, center: Vector2) -> Control:
	# плитка с буквой целиком — tile_<x>_<upper|lower>.png
	var t := TextureRect.new()
	t.texture = Assets.tex(Assets.letter_name("tile", ch))
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.size = Vector2(120, 120)
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
	var t = _first_tile()
	if t == null:
		return
	main.expose("tile", t)
	main.expose("tile_basket", _basket_for(t))
	main.hint_start(_first_tile, "h_drag_01", _auto_place, _auto_basket)

func _auto_place() -> void:
	var x = _first_tile()
	if x:
		_place(x)

func _auto_basket():
	var x = _first_tile()
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
	var c := t.get_global_rect().get_center()
	var right := _basket_for(t)
	var wrong := basket_small if right == basket_big else basket_big
	if right.get_global_rect().grow(20).has_point(c):
		_place(t)
	elif wrong.get_global_rect().grow(20).has_point(c):
		t.set_meta("errors", t.get_meta("errors") + 1)
		Voice.sfx("sfx_try")
		pulse(right, 1)
		if t.get_meta("errors") >= 2:
			_place(t)
		else:
			# плитка покачивается и плавно возвращается на своё место
			shake(t, t.get_meta("home"))
			get_tree().create_timer(0.7).timeout.connect(_hint)
	else:
		_go_home(t)

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
	var dest := b.position + Vector2(40 + n * 70, -40)
	var tw := t.create_tween().set_parallel()
	tw.tween_property(t, "position", dest, 0.35)
	tw.tween_property(t, "scale", Vector2(0.5, 0.5), 0.35)
	var fill := add_pic(cfg.fill_pic, b.position + Vector2(60 + n * 60, b.size.y - 60), Vector2(48, 48), false)   # гриб (без красного)
	pop_in(fill)
	Voice.sfx("sfx_ok")
	placed += 1
	main.log_event("tile", {"ch": t.get_meta("ch"), "errors": t.get_meta("errors")})
	if placed >= tiles.size():
		finished = true
		main.hint_stop()
		pulse(basket_big, 2)
		pulse(basket_small, 2)
		Voice.sfx("sfx_cheer")
		if not await praise(): return
		finish()
	else:
		if placed % 2 == 0:
			praise()
		_hint()
