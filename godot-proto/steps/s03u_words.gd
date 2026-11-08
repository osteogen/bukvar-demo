## Сцена 3 «У»: звуковая полоска — перетащить красный кружок в ПЕРВУЮ клетку.
## После ошибки — wobble; рука только после 20 с бездействия (C1). Нет автоподтверждения.
extends LessonStep

var items: Array = []
var idx := 0
var circle: TextureButton
var cells: Array = []
var dragging := false
var drag_off := Vector2.ZERO
var home: Vector2
var fails := 0
var done_item := false

func run() -> void:
	section("words")
	items = cfg.get("items", [])
	add_bg(String(cfg.get("bg", "bg_meadow")))
	await _show_item()

func _show_item() -> void:
	if dead: return
	done_item = false
	fails = 0
	for c in get_children():
		if String(c.name).begins_with("dyn_"):
			c.queue_free()
	await get_tree().process_frame
	if idx >= items.size():
		if not await praise(): return
		finish()
		return
	var it: Dictionary = items[idx]
	main.set_state("words_%d" % idx)
	# карточка со сплошным кремовым фоном
	var frame := ColorRect.new()
	frame.name = "dyn_card"
	frame.color = Assets.CREAM
	var csz := Vector2(float(cfg.get("card_size", [280, 280])[0]), float(cfg.get("card_size", [280, 280])[1]))
	frame.size = csz + Vector2(24, 24)
	frame.position = Vector2(512, 220) - frame.size / 2
	add_child(frame)
	var pic := add_pic(String(it.pic), Vector2(512, 220), csz)
	pic.name = "dyn_pic"
	# полоска клеток
	cells.clear()
	var n := int(it.cells)
	var cell := float(cfg.get("cell_size", [70, 70])[0])
	var gap := 8.0
	var total := n * cell + (n - 1) * gap
	var y := float(cfg.get("strip_y", 520))
	var x0 := 512.0 - total / 2.0
	for i in n:
		var r := ColorRect.new()
		r.name = "dyn_cell_%d" % i
		r.color = Assets.CREAM
		r.size = Vector2(cell, cell)
		r.position = Vector2(x0 + i * (cell + gap), y)
		# outline
		var ol := ColorRect.new()
		ol.color = Assets.DARK
		ol.size = r.size + Vector2(4, 4)
		ol.position = r.position - Vector2(2, 2)
		ol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ol.z_index = -1
		ol.name = "dyn_ol_%d" % i
		add_child(ol)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		cells.append(r)
	# красный кружок слева
	circle = add_pic(String(cfg.get("circle", "ui_circle_flat")), Vector2(160, y + cell / 2), Vector2(cell + 20, cell + 20))
	circle.name = "dyn_circle"
	home = circle.position
	main.expose("circle", circle)
	main.expose("cell0", cells[0])
	circle.button_down.connect(_down)
	circle.button_up.connect(_up)
	circle.gui_input.connect(_on_gui)
	if not await say(String(it.audio)): return
	# подсказка только через 20 с (main.hint_start)
	main.hint_start(func(): return circle if not done_item else null, String(cfg.get("hint_drag", "h_drag_01")))
	main.set_state("wait_drag")

func _down() -> void:
	if done_item: return
	dragging = true
	drag_off = circle.get_local_mouse_position()
	main.hint_stop()
	Voice.stop_voice()

func _on_gui(e: InputEvent) -> void:
	if not dragging or done_item: return
	if e is InputEventMouseMotion:
		circle.position = circle.position + e.relative

func _up() -> void:
	if done_item or not dragging: return
	dragging = false
	var c0: ColorRect = cells[0]
	var hit := Rect2(c0.position - Vector2(10, 10), c0.size + Vector2(20, 20)).has_point(circle.position + circle.size / 2)
	if hit:
		circle.position = c0.position + (c0.size - circle.size) / 2
		c0.color = Assets.VOWEL_RED
		done_item = true
		main.hint_stop()
		Voice.sfx("sfx_ok")
		await say(String(items[idx].audio))
		if dead: return
		idx += 1
		await _show_item()
	else:
		fails += 1
		Voice.sfx("sfx_try")
		# мягкий возврат; мерцание 1-й клетки после 2-й ошибки, рука — только 20 с
		var tw := create_tween()
		tw.tween_property(circle, "position", home, 0.25)
		await tw.finished
		if fails >= 2:
			_shimmer(cells[0])
		if not dead:
			main.hint_start(func(): return circle if not done_item else null, String(cfg.get("hint_drag", "h_drag_01")))

func _shimmer(n: Control) -> void:
	var tw := create_tween()
	for i in 3:
		tw.tween_property(n, "modulate", Color(1.3, 1.2, 0.8), 0.15)
		tw.tween_property(n, "modulate", Color.WHITE, 0.15)

