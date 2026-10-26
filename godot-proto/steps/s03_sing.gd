## Сцена 3. Поющий звук: нажми и держи красный кружок 2 с.
## Звук «а-а-а» — a_aaa (решение методиста 26.10.2026, заменяет a_sing_loop): один раз образцом сразу после a_sing_01
## и по кругу, пока кружок нажат. Пока записи a_aaa нет — sing.loop_fallback / sample_fallback (a_find_03).
extends LessonStep

var circle: TextureButton
var face: Cutout
var bar_fill: ColorRect
var held := 0.0
var holding := false
var press_t := 0
var replayed := false
var done := false
var goal := 2.0

func run() -> void:
	section("sing")
	goal = float(cfg.hold_goal_sec)
	add_bg(cfg.bg)
	# крупный план: та же Аля из слоёв, увеличенная и сдвинутая так, что в кадре лицо
	face = add_character(cfg.face, Vector2(300, 430), Vector2(560, 560))   # крупный план лица (closeup v3)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop_in(face)
	# кружок-звук — тот же плоский матовый ui_circle_flat, что в сценах 3, 4, 5, 9; волны — отдельный ui_sound_waves справа
	circle = add_pic(String(cfg.get("circle", Assets.lesson.get("sound_dot", "ui_circle_flat"))), Vector2(760, 360), Vector2(240, 240))
	var waves := TextureRect.new()
	waves.texture = Assets.tex(String(cfg.get("waves", "ui_sound_waves")))
	waves.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	waves.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	waves.size = Vector2(120, 210)
	waves.position = Vector2(246, 15)
	waves.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.add_child(waves)
	circle.visible = false
	main.expose("circle", circle)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(1, 1, 1, 0.8)
	bar_bg.position = Vector2(212, 610)
	bar_bg.size = Vector2(600, 36)
	add_child(bar_bg)
	bar_fill = ColorRect.new()
	bar_fill.color = Assets.VOWEL_RED
	bar_fill.position = bar_bg.position
	bar_fill.size = Vector2(0, 36)
	add_child(bar_fill)
	if not await say(cfg.lines[0]): return
	if not await _sample(): return
	circle.visible = true
	pop_in(circle)
	if not await say(cfg.lines[1]): return
	if not await say(cfg.lines[2]): return
	circle.button_down.connect(_down)
	circle.button_up.connect(_up)
	# подсказка только показывает (рука + повтор реплики); засчитывает лишь удержание ребёнком 2 с
	main.hint_start(func(): return circle, cfg.lines[2])
	main.set_state("wait_hold")

func _down() -> void:
	if done: return
	holding = true
	press_t = Time.get_ticks_msec()
	Voice.stop_voice()
	Voice.loop_start(_audio(String(cfg.loop), String(cfg.get("loop_fallback", ""))))
	face.singing = true
	main.hint_stop()

## Запись или запасная (нет записи — пустая строка).
func _audio(id: String, fallback: String) -> String:
	if Assets.sound(id) != null:
		return id
	return fallback if fallback != "" and Assets.sound(fallback) != null else ""

## Образец протяжного «а-а-а» после a_sing_01: Аля поёт (рот открыт), один раз.
func _sample() -> bool:
	var id := _audio(String(cfg.get("sample", "")), String(cfg.get("sample_fallback", "")))
	main.set_info("s03_sample", id)
	if id == "":
		return not dead
	face.singing = true
	var t0 := Time.get_ticks_msec()
	var ok := await say(id)
	if not dead:
		face.singing = false
	main.set_info("s03_sample_ms", Time.get_ticks_msec() - t0)
	return ok

func _up() -> void:
	if done: return
	holding = false
	Voice.loop_stop()
	face.singing = false
	var dt := (Time.get_ticks_msec() - press_t) / 1000.0
	if dt < 0.5 and not replayed:
		replayed = true
		pulse(circle, 1)
		await say(cfg.lines[2])
	if not done and not dead:
		main.hint_start(func(): return circle, cfg.lines[2])

func _process(delta: float) -> void:
	if holding and not done:
		held += delta
		circle.scale = Vector2.ONE * (1.0 + 0.05 * sin(held * 20.0))
		_update()
		if held >= goal:
			_success()

func _update() -> void:
	bar_fill.size.x = 600.0 * clampf(held / goal, 0.0, 1.0)

func _success() -> void:
	if done: return
	done = true
	holding = false
	Voice.loop_stop()
	face.singing = false
	main.hint_stop()
	circle.scale = Vector2.ONE
	burst(circle.position + circle.size / 2, Color("#ffd23c"))
	pulse(circle, 2)
	if not await praise(): return
	if not await say(cfg.after_hold): return   # «Такие звуки называют гласными…» — после действия
	finish()
