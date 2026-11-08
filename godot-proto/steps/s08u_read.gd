## Сцена 8 «У»: чтение «ау» / «уа». Без «Скажи сам» (решение пользователя).
## 8.1 лес: палец по дорожке А→У; 8.2 дома: перетащить У влево (АУ→УА), потом вести.
## Подсказка руки — после 20 с.
extends LessonStep

var phase := 0                 # 1=ay swipe, 2=ua swap, 3=ua swipe
var track: Control
var dragging := false
var progress := 0.0
var fails := 0
var phase_done := false
var tile_a: Control
var tile_u: Control
var tile_u_hit: Control = null
var nest_left: Vector2
var nest_right: Vector2
var swap_done := false
var drag_tile: Control = null
var drag_origin := Vector2.ZERO

func run() -> void:
	section("read")
	await _phase_ay()
	if dead: return
	await _phase_ua()
	if dead: return
	if not await praise(): return
	finish()

func _clear_dyn() -> void:
	for c in get_children():
		if String(c.name).begins_with("dyn_"):
			c.queue_free()
	await get_tree().process_frame
	track = null
	tile_a = null
	tile_u = null
	tile_u_hit = null

func _phase_ay() -> void:
	phase = 1
	phase_done = false
	progress = 0.0
	fails = 0
	swap_done = true  # no swap needed
	add_bg(String(cfg.get("bg", "bg_forest_small")))
	var bunny := add_pic(String(cfg.get("bunny", "pic_bunny_forest")), Vector2(700, 280), Vector2(160, 180))
	bunny.name = "dyn_bunny"
	bunny.modulate.a = 0.0
	_build_board(["А", "У"], false)
	main.set_state("read_ay")
	main.hint_start(func(): return track if not phase_done else null, "r_try_04")
	while not dead and not phase_done:
		await get_tree().process_frame
	if dead: return
	var tw := create_tween()
	tw.tween_property(bunny, "modulate:a", 1.0, 0.35)
	await tw.finished
	await wait(0.35)

func _phase_ua() -> void:
	phase = 2
	phase_done = false
	progress = 0.0
	fails = 0
	swap_done = false
	await _clear_dyn()
	add_bg(String(cfg.get("bg_home", "bg_room_evening")))
	var baby := add_pic(String(cfg.get("baby", "pic_baby_crib")), Vector2(700, 300), Vector2(220, 180))
	baby.name = "dyn_baby"
	baby.modulate.a = 0.35  # clouded until read
	# Start as А У — child must drag У to left nest
	_build_board(["А", "У"], true)
	main.set_state("read_ua_swap")
	_shimmer(tile_u)
	main.hint_start(func(): return (tile_u_hit if tile_u_hit else tile_u) if not swap_done else null, "h_drag_01")
	while not dead and not swap_done:
		await get_tree().process_frame
	if dead: return
	main.hint_stop()
	# After swap: shimmer track, swipe У→А
	phase = 3
	phase_done = false
	progress = 0.0
	fails = 0
	_pulse_track()
	main.set_state("read_ua")
	main.hint_start(func(): return track if not phase_done else null, "r_try_04")
	while not dead and not phase_done:
		await get_tree().process_frame
	if dead: return
	var tw := create_tween()
	tw.tween_property(baby, "modulate:a", 1.0, 0.35)
	await tw.finished
	await wait(0.3)

func _build_board(order: Array, enable_drag: bool) -> void:
	var y := float(cfg.get("board_y", 620))
	var board := ColorRect.new()
	board.name = "dyn_board"
	board.color = Assets.CREAM
	board.size = Vector2(420, 110)
	board.position = Vector2(512 - 210, y - 55)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	nest_left = Vector2(512 - 90, y)
	nest_right = Vector2(512 + 90, y)
	for i in order.size():
		var ch := String(order[i])
		var pos := nest_left if i == 0 else nest_right
		var L := add_letter(ch, pos, 90)
		L.name = "dyn_tile_%s" % ch
		if ch == "А":
			tile_a = L
		elif ch == "У":
			tile_u = L
		if enable_drag and ch == "У":
			L.mouse_filter = Control.MOUSE_FILTER_STOP
			L.gui_input.connect(_on_tile_drag.bind(L))
			# big hit for finger
			var hit := Button.new()
			hit.name = "dyn_tile_hit_U"
			hit.flat = true
			hit.focus_mode = Control.FOCUS_NONE
			hit.position = pos - Vector2(45, 45)
			hit.size = Vector2(150, 150)
			for st in ["normal", "hover", "pressed", "focus"]:
				hit.add_theme_stylebox_override(st, StyleBoxEmpty.new())
			add_child(hit)
			hit.gui_input.connect(_on_tile_drag.bind(L))
			tile_u_hit = hit
			main.expose("tile_u", hit)
	track = ColorRect.new()
	track.name = "dyn_track"
	track.color = Assets.MUSTARD
	track.size = Vector2(360, 28)
	track.position = Vector2(512 - 180, float(cfg.get("track_y", 700)))
	track.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(track)
	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_font_size_override("font_size", 28)
	arrow.add_theme_color_override("font_color", Assets.DARK)
	arrow.position = track.position + Vector2(330, -4)
	arrow.name = "dyn_arrow"
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(arrow)
	var hit := Button.new()
	hit.name = "dyn_track_hit"
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.position = track.position - Vector2(0, 60)
	hit.size = Vector2(track.size.x, 150)
	for st in ["normal", "hover", "pressed", "focus"]:
		hit.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	add_child(hit)
	main.expose("track", hit)
	hit.gui_input.connect(_on_track)
	track.gui_input.connect(_on_track)
	# During swap phase, track not yet the goal — still expose for tests after swap

func _on_tile_drag(e: InputEvent, tile: Control) -> void:
	if swap_done or dead or phase != 2:
		return
	if e is InputEventMouseButton:
		if e.pressed:
			drag_tile = tile
			drag_origin = tile.position
			main.hint_stop()
			tile.z_index = 20
		else:
			if drag_tile == tile:
				_drop_tile(tile)
	elif e is InputEventMouseMotion and drag_tile == tile:
		tile.position += e.relative

func _drop_tile(tile: Control) -> void:
	drag_tile = null
	tile.z_index = 0
	# Accept if near left nest
	if tile.position.distance_to(nest_left) < 100.0:
		# Snap У left, А slides right
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(tile, "position", nest_left, 0.25)
		if tile_a:
			tw.tween_property(tile_a, "position", nest_right, 0.25)
		tw.chain().tween_callback(func():
			swap_done = true
			Voice.sfx("sfx_ok")
			burst(nest_left, Assets.MUSTARD)
		)
	else:
		# soft return
		var tw := create_tween()
		tw.tween_property(tile, "position", drag_origin, 0.2)
		main.hint_start(func(): return (tile_u_hit if tile_u_hit else tile_u) if not swap_done else null, "h_drag_01")

func _on_track(e: InputEvent) -> void:
	if phase_done or dead:
		return
	# During swap phase ignore track
	if phase == 2 and not swap_done:
		return
	if e is InputEventMouseButton:
		if e.pressed:
			dragging = true
			progress = 0.0
			main.hint_stop()
		else:
			_end_swipe()
	elif e is InputEventMouseMotion and dragging:
		if e.relative.x > 0:
			progress += e.relative.x / 360.0
		elif e.relative.x < -4:
			progress = maxf(0.0, progress + e.relative.x / 360.0)

func _end_swipe() -> void:
	if not dragging or phase_done:
		return
	dragging = false
	if progress >= 0.8:
		phase_done = true
		main.hint_stop()
		Voice.sfx("sfx_ok")
		var audio := "u_read_ay"
		if phase == 1:
			var ay: Dictionary = cfg.get("ay", {})
			audio = String(ay.get("audio", "u_read_ay"))
		else:
			var ua: Dictionary = cfg.get("ua", {})
			audio = String(ua.get("audio", "u_read_ua"))
		tap_say(audio)
	else:
		fails += 1
		progress = 0.0
		# soft fail — no error sfx per script
		if fails >= 2:
			_pulse_track()
		main.hint_start(func(): return track if not phase_done else null, "r_try_04")

func _shimmer(node: Control) -> void:
	if node == null: return
	var tw := create_tween()
	tw.set_loops(4)
	tw.tween_property(node, "modulate", Color(1.5, 1.2, 0.8), 0.18)
	tw.tween_property(node, "modulate", Color.WHITE, 0.18)

func _pulse_track() -> void:
	if track == null: return
	var tw := create_tween()
	for i in 3:
		tw.tween_property(track, "modulate", Color(1.4, 1.2, 0.7), 0.12)
		tw.tween_property(track, "modulate", Color.WHITE, 0.12)
