## Сцена 5 «У»: буква У слева, картинка справа → слово внизу, У спускается в начало.
extends LessonStep

var items: Array = []
var idx := 0
var busy := false
var letter: Control
var slot: ColorRect

func run() -> void:
	section("letter_word")
	items = cfg.get("items", [])
	add_bg(String(cfg.get("bg", "bg_desk")))
	if cfg.get("intro", "") != "":
		if not await say(String(cfg.intro)): return
	await _item()

func _item() -> void:
	if dead: return
	busy = false
	for c in get_children():
		if String(c.name).begins_with("dyn_"):
			c.queue_free()
	await get_tree().process_frame
	if idx >= items.size():
		finish()
		return
	var it: Dictionary = items[idx]
	main.set_state("letter_word_%d" % idx)
	letter = add_letter("У", Vector2(280, 300), int(cfg.get("letter_h", 260)))
	letter.name = "dyn_letter"
	var cream := ColorRect.new()
	cream.name = "dyn_cream"
	cream.color = Assets.CREAM
	cream.size = letter.size + Vector2(40, 40)
	cream.position = letter.position - Vector2(20, 20)
	cream.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cream)
	move_child(cream, letter.get_index())
	var csz := Vector2(float(cfg.get("card_size", [240, 240])[0]), float(cfg.get("card_size", [240, 240])[1]))
	var card := ColorRect.new()
	card.name = "dyn_card"
	card.color = Assets.CREAM
	card.size = csz + Vector2(20, 20)
	card.position = Vector2(720, 280) - card.size / 2
	add_child(card)
	var pic := add_pic(String(it.pic), Vector2(720, 280), csz)
	pic.name = "dyn_pic"
	var plate := ColorRect.new()
	plate.name = "dyn_word"
	plate.color = Assets.CREAM
	plate.size = Vector2(520, 90)
	plate.position = Vector2(252, 560)
	add_child(plate)
	slot = ColorRect.new()
	slot.color = Color(Assets.MUSTARD.r, Assets.MUSTARD.g, Assets.MUSTARD.b, 0.35)
	slot.size = Vector2(70, 70)
	slot.position = plate.position + Vector2(16, 10)
	slot.name = "dyn_slot"
	add_child(slot)
	var rest := Label.new()
	rest.text = String(it.word).substr(1)
	rest.add_theme_font_size_override("font_size", 48)
	rest.add_theme_color_override("font_color", Color("#B49C82"))
	rest.position = slot.position + Vector2(80, 10)
	rest.size = Vector2(400, 70)
	rest.name = "dyn_rest"
	add_child(rest)
	main.expose("letter", letter)
	main.expose("pic", pic)
	tap_area(letter).pressed.connect(_on_go)
	pic.pressed.connect(_on_go)
	main.hint_start(func(): return letter if not busy else null, "h_tap_01")
	main.set_state("wait_tap")

func _on_go() -> void:
	if dead or busy:
		return
	busy = true
	main.hint_stop()
	var it: Dictionary = items[idx]
	var fly := add_letter("У", letter.position + letter.size / 2, 70)
	fly.name = "dyn_fly"
	var tw := create_tween()
	tw.tween_property(fly, "position", slot.position + Vector2(5, 5), 0.8).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(fly, "size", Vector2(60, 60), 0.8)
	await tw.finished
	if dead: return
	Voice.sfx("sfx_ok")
	if not await say(String(it.audio)): return
	idx += 1
	await _item()
