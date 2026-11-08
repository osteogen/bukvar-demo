## Сцена 1 урока «У» (чистовик v6j): двор; Аля по пояс (idle↔sign crossfade 0.15, голова на месте);
## рот mouth_0/1/2 + mouth_u поверх позы, слой 1093² в place_2x (311, 443);
## табличка ui_sign_u_hold заканчивает жест в SIGN_HOLD, затем ui_sign_u_full;
## утка walk_a/b/c ~50 px/s NEAR↔FAR 0…3 с → STOP, кряк; тап → u_sound; «Далее» после первого тапа.
## Координаты — art/lesson_u/s01_geom.json (и lesson.json → duck).
extends LessonStep

const NAV_PAD := 150.0
const CROSSFADE := 0.15
const WALK_SEC := 3.0
const WALK_SPEED := 50.0
const FRAME_SEC := 0.14

var alya_root: Control
var pose_idle: TextureRect
var pose_sign: TextureRect
var mouth_rect: TextureRect
var mouth_tex: Array = []  # 0,1,2,u
var sign_hold: TextureRect
var sign_full: TextureButton
var duck: TextureRect
var duck_shadow: TextureRect
var duck_btn: Button

var _duck_tex := {}
var _duck_piv := {}  # id → Vector2 pivot 1× (ground)
var _duck_sz := {}   # id → Vector2 logical size

var enlarged := false
var tapped_big := false
var _intro_done := false
var _sign_pulled := false
var _intro_t0_ms := 0
var _duck_stopped := false
var _duck_cx := 0.0
var _duck_gy := 0.0
var _duck_face_left := true
var _duck_frame := "walk_a"
var _pose_sign_on := false
var _vowel_wins: Array = []  # [[start,end],…] для mouth_u
var _duck_mode := "off"  # off|walk|to_stop|done
var _duck_target := Vector2.ZERO
var _duck_near := Vector2.ZERO
var _duck_far := Vector2.ZERO
var _duck_stop := Vector2.ZERO
var _duck_speed := WALK_SPEED
var _duck_t_left := WALK_SEC
var _duck_frame_t := 0.0
var _duck_fi := 0
var _duck_stop_u := 0.0
var _duck_stop_t := 0.01
var _duck_c0 := Vector2.ZERO

func _v(a, def: Vector2 = Vector2.ZERO) -> Vector2:
	if a is Array and a.size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return def

func _r(a) -> Rect2:
	return Rect2(float(a[0]), float(a[1]), float(a[2]) - float(a[0]), float(a[3]) - float(a[1]))

func _tex(id: String, pos: Vector2, sz: Vector2, nm: String) -> TextureRect:
	return _rect_tex(Assets.tex(id), pos, sz, nm)

func _rect_tex(tex: Texture2D, pos: Vector2, sz: Vector2, nm: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = pos
	r.size = sz
	r.name = nm
	return r

## v6j alya_pose_sign.png — кадр 2048×1536 (Аля + утка). В сцену берём только Алю:
## утка остаётся живыми спрайтами duck_*, иначе на F2 стояла бы вторая, впечатанная.
func _sign_pose_texture() -> Texture2D:
	var src := Assets.tex(String(cfg.get("alya_sign", "alya_pose_sign")))
	var reg_a = cfg.get("alya_sign_region_2x", [548, 487, 650, 1049])
	if src == null or not (reg_a is Array) or reg_a.size() < 4:
		return src
	var reg := Rect2(float(reg_a[0]), float(reg_a[1]), float(reg_a[2]), float(reg_a[3]))
	var sz := src.get_size()
	if sz.x <= reg.size.x + 1.0 and sz.y <= reg.size.y + 1.0:
		return src
	var atlas := AtlasTexture.new()
	atlas.atlas = src
	atlas.region = reg
	return atlas

func _hold_bb() -> Rect2:
	return _r(cfg.get("sign_hold_bb", [315.5, 579.5, 553.5, 738.5]))

func run() -> void:
	section("duck")
	add_bg(String(cfg.get("bg", "bg_yard")))
	_load_duck_frames()
	_build_alya()
	_build_duck()
	_build_signs()
	for w in cfg.get("vowel_windows", [[0.36, 1.82], [2.40, 3.14]]):
		if w is Array and w.size() >= 2:
			_vowel_wins.append([float(w[0]), float(w[1])])
	main.set_state("intro")
	main.set_info("s01u_phase", "enter")
	main.set_info("nav_hit_h", NAV_PAD)
	main.expose("alya", alya_root)
	main.expose("duck", duck)
	main.expose("sign", sign_full)
	_start_duck_walk()
	main.set_info("s01u_phase", "alya_line")
	var intro_id := String(cfg.get("intro", "u_intro_01"))
	var cue := float(cfg.get("pull_cue_sec", 2.496))
	_intro_done = false
	_sign_pulled = false
	_intro_t0_ms = Time.get_ticks_msec()
	# Cue-таймер параллельно с репликой (без второй корутины — Godot 4 требует await)
	var cue_sec := 0.05 if Voice.fast else cue
	get_tree().create_timer(cue_sec).timeout.connect(_on_pull_cue)
	await say(intro_id)
	_intro_done = true
	if dead:
		return
	while not dead and not _sign_pulled:
		await get_tree().process_frame
	if dead:
		return
	# Дождаться STOP утки (или короткий запас)
	var t_wait := 0.0
	while not dead and not _duck_stopped and t_wait < 1.5:
		await get_tree().process_frame
		t_wait += get_process_delta_time()
	if dead:
		return
	main.set_info("s01u_phase", "quack")
	_set_duck_frame("quack")
	Voice.sfx(String(cfg.get("quack", "sfx_quack")))
	await get_tree().create_timer(0.45 if not Voice.fast else 0.05).timeout
	if dead:
		return
	main.set_info("s01u_phase", "enlarge")
	main.set_state("enlarge_sign")
	await _enlarge_full_sign()
	if dead:
		return
	enlarged = true
	main.set_info("s01u_phase", "wait_tap")
	main.set_state("wait_sign_tap")
	main.hint_start(func(): return sign_full if enlarged and not tapped_big else null, "")
	sign_full.pressed.connect(_on_sign_tap)
	while not dead and not tapped_big:
		await get_tree().process_frame
	if dead:
		return
	finish()

func _on_pull_cue() -> void:
	if dead or _sign_pulled:
		return
	main.set_info("s01u_phase", "pull_sign")
	_show_sign_hold()

func _on_sign_tap() -> void:
	if not enlarged:
		return
	tap_say(String(cfg.get("sound", "u_sound")))
	if not tapped_big:
		tapped_big = true
		main.set_info("s01u_phase", "tapped")
		main.hint_stop()

func _build_alya() -> void:
	# idle и рот делят place_2x (311, 443) → 1× (155.5, 221.5), холст 1093².
	var mouth_place_2x := _v(cfg.get("mouth_place_2x", [311, 443]))
	var idle_place := mouth_place_2x * 0.5
	var idle_sz := _v(cfg.get("alya_idle_size", [546.5, 546.5]))
	if cfg.has("alya_idle_place"):
		idle_place = _v(cfg.get("alya_idle_place"))
	# Поза с табличкой — вырез Али из кадра v6j, тот же якорь глаз, что у idle.
	var sign_place := _v(cfg.get("alya_sign_place", [274.0, 243.5]))
	var sign_sz := _v(cfg.get("alya_sign_size", [325.0, 524.5]))
	alya_root = Control.new()
	alya_root.name = "alya"
	alya_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alya_root.position = Vector2.ZERO
	alya_root.size = Vector2(1024, 768)
	add_child(alya_root)
	pose_idle = _tex(String(cfg.get("alya_idle", "alya_pose_idle")), idle_place, idle_sz, "alya_pose_idle")
	pose_sign = _rect_tex(_sign_pose_texture(), sign_place, sign_sz, "alya_pose_sign")
	pose_sign.modulate.a = 0.0
	var hold_bb := _hold_bb()
	sign_hold = _tex(String(cfg.get("sign_hold", "ui_sign_u_hold")), hold_bb.position, hold_bb.size, "ui_sign_u_hold")
	sign_hold.visible = false
	sign_hold.modulate.a = 0.0
	# Порядок: idle → табличка → поза (пальцы поверх таблички) → рот.
	alya_root.add_child(pose_idle)
	alya_root.add_child(sign_hold)
	alya_root.add_child(pose_sign)
	mouth_tex = [
		Assets.tex(String(cfg.get("mouth_0", "alya_mouth_0"))),
		Assets.tex(String(cfg.get("mouth_1", "alya_mouth_1"))),
		Assets.tex(String(cfg.get("mouth_2", "alya_mouth_2"))),
		Assets.tex(String(cfg.get("mouth_u", "alya_mouth_u"))),
	]
	var mouth_place := mouth_place_2x * 0.5
	var mouth_sz := idle_sz
	mouth_rect = _tex(String(cfg.get("mouth_0", "alya_mouth_0")), mouth_place, mouth_sz, "alya_mouth")
	alya_root.add_child(mouth_rect)

func _build_signs() -> void:
	var full_bb := _r(cfg.get("sign_full_bb", [262, 169, 734, 599]))
	sign_full = TextureButton.new()
	sign_full.texture_normal = Assets.tex(String(cfg.get("sign_full", "ui_sign_u_full")))
	sign_full.ignore_texture_size = true
	sign_full.stretch_mode = TextureButton.STRETCH_SCALE
	sign_full.position = full_bb.position
	sign_full.size = full_bb.size
	sign_full.visible = false
	sign_full.modulate.a = 0.0
	sign_full.z_index = 20
	sign_full.name = "ui_sign_u_full"
	add_child(sign_full)

func _load_duck_frames() -> void:
	for id in ["walk_a", "walk_b", "walk_c", "stand", "quack"]:
		var key: String = "duck_" + id
		var t: Texture2D = Assets.tex(key)
		_duck_tex[id] = t
		var nat := Assets.nat_size(t)
		_duck_sz[id] = nat
		var piv_cfg = cfg.get("duck_pivots", {}).get(id, null) if cfg.get("duck_pivots", {}) is Dictionary else null
		if piv_cfg is Array and piv_cfg.size() >= 2:
			_duck_piv[id] = Vector2(float(piv_cfg[0]), float(piv_cfg[1]))
		else:
			# дефолт из geom.json pivots.duck.*.pivot_1x
			var defaults := {
				"walk_a": Vector2(83.75, 174.0),
				"walk_b": Vector2(84.25, 174.0),
				"walk_c": Vector2(88.0, 167.0),
				"stand": Vector2(82.75, 174.0),
				"quack": Vector2(81.25, 174.0),
			}
			_duck_piv[id] = defaults[id]

func _build_duck() -> void:
	var near := _v(cfg.get("near", [715, 478]), Vector2(715, 478))
	_duck_cx = near.x
	_duck_gy = near.y
	_duck_face_left = true
	duck_shadow = _tex("duck_shadow", Vector2.ZERO, Assets.nat_size(Assets.tex("duck_shadow")), "duck_shadow")
	add_child(duck_shadow)
	duck = _tex("duck_walk_a", Vector2.ZERO, _duck_sz["walk_a"], "duck")
	add_child(duck)
	duck_btn = Button.new()
	duck_btn.flat = true
	duck_btn.focus_mode = Control.FOCUS_NONE
	duck_btn.modulate.a = 0.0
	duck_btn.name = "duck_hit"
	add_child(duck_btn)
	duck_btn.pressed.connect(func(): Voice.sfx(String(cfg.get("quack", "sfx_quack"))))
	_place_duck()

func _place_duck() -> void:
	var id := _duck_frame
	var sz: Vector2 = _duck_sz[id]
	var piv: Vector2 = _duck_piv[id]
	duck.texture = _duck_tex[id]
	duck.size = sz
	duck.flip_h = not _duck_face_left  # кадры смотрят влево; вправо — зеркало
	var pv := piv
	if duck.flip_h:
		pv.x = sz.x - piv.x
	duck.pivot_offset = pv
	duck.position = Vector2(_duck_cx, _duck_gy) - pv
	# тень
	var sh_sz := duck_shadow.size
	duck_shadow.position = Vector2(_duck_cx - sh_sz.x * 0.5, _duck_gy - sh_sz.y * 0.45)
	duck_btn.position = duck.position
	duck_btn.size = duck.size
	main.set_info("s01_duck_at", [_duck_cx, _duck_gy, id, _duck_face_left])

func _set_duck_frame(id: String) -> void:
	_duck_frame = id
	_place_duck()

func _start_duck_walk() -> void:
	_duck_near = _v(cfg.get("near", [715, 478]), Vector2(715, 478))
	_duck_far = _v(cfg.get("far", [865, 452]), Vector2(865, 452))
	_duck_stop = _v(cfg.get("stop", [790, 465]), Vector2(790, 465))
	_duck_speed = float(cfg.get("walk_speed", WALK_SPEED))
	_duck_t_left = float(cfg.get("walk_sec", WALK_SEC))
	_duck_target = _duck_far
	_duck_face_left = false
	_duck_fi = 0
	_duck_frame_t = 0.0
	_duck_frame = "walk_a"
	_duck_stopped = false
	_duck_mode = "walk"
	_place_duck()

func _tick_duck(delta: float) -> void:
	if _duck_mode == "off" or _duck_mode == "done":
		return
	var dt := delta
	if Voice.fast:
		dt *= 8.0
	var frames := ["walk_a", "walk_b", "walk_c"]
	if _duck_mode == "walk":
		_duck_t_left -= dt
		_duck_frame_t += dt
		if _duck_frame_t >= FRAME_SEC:
			_duck_frame_t = 0.0
			_duck_fi = (_duck_fi + 1) % frames.size()
			_duck_frame = frames[_duck_fi]
		var to := Vector2(_duck_target.x - _duck_cx, _duck_target.y - _duck_gy)
		var dist := to.length()
		var step := _duck_speed * dt
		if dist <= step or dist < 0.5:
			_duck_cx = _duck_target.x
			_duck_gy = _duck_target.y
			if _duck_target == _duck_far:
				_duck_target = _duck_near
				_duck_face_left = true
			else:
				_duck_target = _duck_far
				_duck_face_left = false
		else:
			var n := to / dist
			_duck_cx += n.x * step
			_duck_gy += n.y * step
			_duck_face_left = n.x < 0.0
		_place_duck()
		if _duck_t_left <= 0.0:
			_duck_face_left = true
			_duck_c0 = Vector2(_duck_cx, _duck_gy)
			var sd := _duck_c0.distance_to(_duck_stop)
			_duck_stop_t = maxf(sd / maxf(_duck_speed, 1.0), 0.01)
			_duck_stop_u = 0.0
			_duck_mode = "to_stop"
		return
	if _duck_mode == "to_stop":
		_duck_stop_u = minf(1.0, _duck_stop_u + dt / _duck_stop_t)
		_duck_cx = lerpf(_duck_c0.x, _duck_stop.x, _duck_stop_u)
		_duck_gy = lerpf(_duck_c0.y, _duck_stop.y, _duck_stop_u)
		_duck_face_left = true
		_duck_frame_t += dt
		if _duck_frame_t >= FRAME_SEC:
			_duck_frame_t = 0.0
			_duck_fi = (_duck_fi + 1) % frames.size()
			_duck_frame = frames[_duck_fi]
		_place_duck()
		if _duck_stop_u >= 1.0:
			_duck_cx = _duck_stop.x
			_duck_gy = _duck_stop.y
			_set_duck_frame("stand")
			_duck_stopped = true
			_duck_mode = "done"

func _show_sign_hold() -> void:
	# Жест заканчивается в SIGN_HOLD. Кроссфейд только по альфе: позиции поз не трогаем,
	# иначе голова прыгает (глаза idle и sign сведены к одному place_2x).
	var bb := _hold_bb()
	sign_hold.position = bb.position
	sign_hold.size = bb.size
	sign_hold.visible = true
	sign_hold.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(pose_sign, "modulate:a", 1.0, CROSSFADE)
	tw.parallel().tween_property(pose_idle, "modulate:a", 0.0, CROSSFADE)
	tw.parallel().tween_property(sign_hold, "modulate:a", 1.0, CROSSFADE)
	tw.finished.connect(func():
		sign_hold.position = bb.position
		sign_hold.size = bb.size
		_pose_sign_on = true
		_sign_pulled = true
		main.set_info("s01_sign_hold_bb", [bb.position.x, bb.position.y, bb.end.x, bb.end.y])
	)

func _enlarge_full_sign() -> void:
	# спрятать утку / Алю / hold; показать full
	duck.visible = false
	duck_shadow.visible = false
	duck_btn.visible = false
	alya_root.visible = false
	sign_hold.visible = false
	sign_full.visible = true
	sign_full.modulate.a = 0.0
	# старт из hold-позиции (масштаб)
	var hold_bb := _hold_bb()
	var full_bb := _r(cfg.get("sign_full_bb", [262, 169, 734, 599]))
	sign_full.position = hold_bb.position
	sign_full.size = hold_bb.size
	var sec := float(cfg.get("enlarge_sec", 0.7))
	if Voice.fast:
		sec = 0.05
	var tw := create_tween()
	tw.tween_property(sign_full, "position", full_bb.position, sec).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sign_full, "size", full_bb.size, sec).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sign_full, "modulate:a", 1.0, minf(0.25, sec))
	await tw.finished
	# зазор к «Далее» (euclid) — публикуем для теста
	main.set_info("s01_sign_full_bb", [full_bb.position.x, full_bb.position.y, full_bb.end.x, full_bb.end.y])
	main.set_info("nav_hit_h", NAV_PAD)

func _process(delta: float) -> void:
	_tick_duck(delta)
	if mouth_rect == null or not is_instance_valid(mouth_rect):
		return
	if not alya_root.visible:
		return
	var use_u := false
	var id := Voice.current_id()
	if id == String(cfg.get("intro", "u_intro_01")) or id == String(cfg.get("sound", "u_sound")):
		var t := (Time.get_ticks_msec() - _intro_t0_ms) / 1000.0
		if id == String(cfg.get("sound", "u_sound")):
			use_u = true
		else:
			for w in _vowel_wins:
				if t >= w[0] and t <= w[1]:
					use_u = true
					break
	var tex: Texture2D
	if use_u and mouth_tex.size() >= 4 and mouth_tex[3]:
		tex = mouth_tex[3]
	else:
		var lv := Voice.mouth_level()
		var mi := 0 if lv < 0.15 else (1 if lv < 0.5 else 2)
		tex = mouth_tex[mi] if mi < mouth_tex.size() else null
	if tex:
		mouth_rect.texture = tex
