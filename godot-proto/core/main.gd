## Менеджер сцен урока: загружает шаги из lesson.json, держит общий интерфейс
## (кнопки «дальше»/«назад», крестик выхода к экрану букв, субтитры, рука-подсказка, разблокировка звука на iOS).
extends Control

const W := 1024.0
const H := 768.0

var steps: Array = []
var stage: Control          # логическая сцена 1024×768 (зона 4:3), по центру окна; aspect=expand даёт поля по краям
var index := -1
var current: Node = null
var host: Control
var overlay: Control
var next_btn: TextureButton
var back_btn: TextureButton
var exit_btn: TextureButton        # крестик справа вверху на s01–s10 → экран букв (menu/letters_menu)
var screen := ""                   # имя текущего экрана: шаг из lesson.json или "letters_menu"
const LETTERS_MENU := "res://menu/letters_menu.tscn"
const EXIT_SIZE := 72.0            # кнопка 72×72 (≥ 64 px для пальца), как «назад»
const EXIT_MARGIN := 14.0
var caption_panel: ColorRect
var caption_label: Label
var caption_ever_visible := false
var info := {}
var hand: TextureRect
var unlock_layer: Control
var parent_note_seen := false     # памятка s00 уже была в этой сессии
var home_requested := false       # веб: ушли на HTML-главную (для автотеста)
var test_mode := false
var log_entries: Array = []
var _targets: Dictionary = {}       # имя -> Control (для автотеста)
var state := ""
var started_ms := 0

# подсказка-рука
var _hint_target: Callable
var _hint_drag_to: Callable
var _hint_voice := ""
var _hint_auto: Callable
var _hint_active := false
var _hint_count := 0
var _hint_idle := 0.0
var _hint_showing := false
var _hint_tween: Tween
var _hand_frames: Array = []
## Бездействие ребёнка до руки-подсказки (и между повторами), с. Единственная настройка; в тесте — ?hint_sec=N.
const IDLE_HINT_SEC := 20.0
var idle_hint_sec := IDLE_HINT_SEC
const HINT_SHOW := 2.0

func _ready() -> void:
	test_mode = Assets.flag("test")
	if (test_mode or Assets.flag("debug")) and String(Assets.params.get("hint_sec", "")).is_valid_float():
		idle_hint_sec = maxf(0.5, float(Assets.params.get("hint_sec")))
	started_ms = Time.get_ticks_msec()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font_size = 30
	theme = th
	steps = Assets.lesson.get("steps", [])
	stage = Control.new()
	stage.size = Vector2(W, H)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	host = Control.new()
	host.size = Vector2(W, H)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(host)
	overlay = Control.new()
	overlay.size = Vector2(W, H)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(overlay)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_build_overlay()
	Voice.caption.connect(_on_caption)
	_ios_audio_session()
	# В вебе главный экран букв — отдельная лёгкая HTML-страница в корне сайта (web-home/), а Godot живёт в lesson-a/:
	# без параметров урок всегда начинается с памятки s00 (её кнопка — первый жест, разблокирует звук на iOS).
	# ?step=... (s00…s10 или номер) — сразу нужный шаг; ?step=letters_menu — экран букв внутри Godot (для отладки).
	# Не в вебе (редактор, десктоп) экран букв из Godot остаётся главным.
	var want := String(Assets.params.get("step", ""))
	var i := steps.find(want)
	if i < 0 and want.is_valid_int():
		i = int(want)
	if want == "letters_menu" or (want == "" and not OS.has_feature("web")):
		show_letters()
	elif i < 0:
		goto(0)
	else:
		goto(clampi(i, 0, steps.size() - 1))
	if test_mode:
		var t := Timer.new()
		t.wait_time = 0.25
		t.autostart = true
		t.timeout.connect(publish)
		add_child(t)

## Центрируем сцену 1024×768 в видимой области (stretch canvas_items + aspect expand).
func _layout() -> void:
	var vs := get_viewport_rect().size
	stage.position = ((vs - Vector2(W, H)) / 2).floor()
	if exit_btn:
		# правый верхний угол ВИДИМОЙ области (на 4:3 — угол сцены, на 16:9 — уходит в поле справа)
		var vr := visible_rect()
		exit_btn.position = Vector2(vr.end.x - EXIT_MARGIN - EXIT_SIZE, vr.position.y + EXIT_MARGIN)
	if current and current.has_method("relayout"):
		current.relayout()

## Видимая область окна в координатах сцены (для фонов «на вылет»).
func visible_rect() -> Rect2:
	return Rect2(-stage.position, get_viewport_rect().size)

func _build_overlay() -> void:
	caption_panel = ColorRect.new()
	caption_panel.color = Color(0, 0, 0, 0.55)
	caption_panel.position = Vector2(112, 690)
	caption_panel.size = Vector2(800, 64)
	caption_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_label = Label.new()
	caption_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_label.add_theme_font_size_override("font_size", 24)
	caption_label.add_theme_color_override("font_color", Color.WHITE)
	caption_panel.add_child(caption_label)
	caption_panel.visible = false
	overlay.add_child(caption_panel)

	next_btn = _ui_button("ui_btn_next", Vector2(W - 120, H - 120), Vector2(100, 100))
	next_btn.pressed.connect(next_step)
	next_btn.visible = false
	back_btn = _ui_button("ui_btn_back", Vector2(20, 20), Vector2(72, 72))
	back_btn.pressed.connect(prev_step)
	back_btn.modulate.a = 0.75
	exit_btn = _ui_button("ui_exit", Vector2.ZERO, Vector2(EXIT_SIZE, EXIT_SIZE))
	exit_btn.name = "ui_exit"
	exit_btn.pressed.connect(exit_to_letters)
	exit_btn.visible = false
	_layout()

	hand = TextureRect.new()
	hand.texture = Assets.tex("ui_hand_f1")
	_hand_frames = [Assets.tex("ui_hand_f1"), Assets.tex("ui_hand_f2")]
	hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand.size = Vector2(96, 96)
	hand.pivot_offset = Vector2(20, 4)
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand.visible = false
	overlay.add_child(hand)

func _ui_button(pic: String, pos: Vector2, sz: Vector2) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = Assets.tex(pic)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.position = pos
	b.size = sz
	b.pivot_offset = sz / 2
	overlay.add_child(b)
	return b

## Субтитры реплик — только для отладки (?debug=1). В демо и пилоте на экране ребёнка из текста — только А/а.
func _on_caption(text: String) -> void:
	caption_label.text = text
	caption_panel.visible = Assets.flag("debug") and text != ""
	if caption_panel.visible:
		caption_ever_visible = true
	if test_mode:
		publish()

## Доп. сведения для теста (window.__bk.info), напр. id карточки сцены 9 и её прямоугольник.
func set_info(k: String, v) -> void:
	info[k] = v
	if test_mode:
		publish()

# ---------- навигация ----------
func goto(i: int) -> void:
	_leave_current()
	index = clampi(i, 0, steps.size() - 1)
	screen = String(steps[index])
	if index == 0:
		parent_note_seen = true
	_enter("res://steps/%s.tscn" % screen)
	back_btn.visible = index > 1
	exit_btn.visible = true                  # s00–s10: везде в уроке — выход на главный экран букв
	expose("exit", exit_btn if exit_btn.visible else null)
	current.call_deferred("run")

## Экран всех букв (пока активна только «А»). Сюда ведут крестик и «домой» в s10.
func show_letters() -> void:
	_leave_current()
	screen = "letters_menu"
	_enter(LETTERS_MENU)
	back_btn.visible = false
	exit_btn.visible = false
	current.call_deferred("run")

## Вход в урок «А» с экрана букв: памятка взрослому s00 — только в первый раз за сессию (загрузку страницы), потом сразу s01.
func start_lesson() -> void:
	goto(1 if parent_note_seen else 0)

func exit_to_letters() -> void:
	if screen == "letters_menu":
		return
	log_event("exit", {})
	Voice.sfx("sfx_whoosh")
	go_home()

## Домой, к экрану букв. В вебе — на HTML-главную (../), с теми же параметрами адреса, кроме step;
## не в вебе — экран букв внутри Godot. Сюда ведут крестик и «домой» в s10.
func go_home() -> void:
	if OS.has_feature("web") and String(Assets.params.get("step", "")) != "letters_menu":
		if home_requested:
			return
		hint_stop()
		home_requested = true
		publish()
		JavaScriptBridge.eval("setTimeout(function(){try{var p=new URLSearchParams(location.search);p.delete('step');" \
			+ "var q=p.toString();location.href='../'+(q?'?'+q:'');}catch(e){location.href='../';}},150);", true)
		return
	show_letters()

func _leave_current() -> void:
	hint_stop()
	Voice.stop_all()
	show_next(false)
	_targets.clear()
	info.erase("parent_panel")
	if current:
		current.dead = true
		host.remove_child(current)
		var old := current
		get_tree().create_timer(3.0).timeout.connect(func(): old.free())
		current = null
	Voice.clear_cache()

func _enter(path: String) -> void:
	var sc: PackedScene = load(path)
	current = sc.instantiate()
	current.main = self
	host.add_child(current)
	set_state("enter")

func next_step() -> void:
	Voice.sfx("sfx_whoosh")
	if index >= steps.size() - 1:
		goto(1)
	else:
		goto(index + 1)

func prev_step() -> void:
	goto(maxi(1, index - 1))

func show_next(on: bool) -> void:
	next_btn.visible = on
	expose("next", next_btn if on else null)
	if on:
		var tw := next_btn.create_tween().set_loops(3)
		tw.tween_property(next_btn, "scale", Vector2(1.15, 1.15), 0.3)
		tw.tween_property(next_btn, "scale", Vector2.ONE, 0.3)
		hint_start(func(): return next_btn, "")

# ---------- подсказка-рука ----------
## target — Callable, возвращающий Control (куда показать); drag_to — для перетаскивания;
## voice — реплика на 2-м показе; auto — что сделать на 3-м показе (автопомощь).
func hint_start(target: Callable, voice := "h_tap_01", auto := Callable(), drag_to := Callable()) -> void:
	_hint_target = target
	_hint_voice = voice
	_hint_auto = auto
	_hint_drag_to = drag_to
	_hint_active = true
	_hint_count = 0
	_hint_idle = 0.0
	_hide_hand()

func hint_stop() -> void:
	_hint_active = false
	_hide_hand()

func hint_reset() -> void:
	_hint_idle = 0.0
	_hide_hand()

func _hide_hand() -> void:
	_hint_showing = false
	if _hint_tween:
		_hint_tween.kill()
	if hand.visible:
		hand.visible = false
		expose("hint_hand", null)
		if test_mode:
			publish()

func _process(delta: float) -> void:
	if not _hint_active:
		return
	# пока звучит реплика, ребёнок слушает — бездействие не считаем (отсчёт 20 с начинается после неё)
	if not _hint_showing and Voice.is_speaking():
		_hint_idle = 0.0
		return
	_hint_idle += delta
	if not _hint_showing and _hint_idle >= idle_hint_sec:
		_show_hand()
	elif _hint_showing and _hint_idle >= HINT_SHOW:
		_hide_hand()
		_hint_idle = 0.0

func _show_hand() -> void:
	var c = _hint_target.call() if _hint_target.is_valid() else null
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		_hint_idle = 0.0
		return
	_hint_count += 1
	if _hint_count >= 3 and _hint_auto.is_valid():
		var a := _hint_auto
		hint_stop()
		a.call()
		return
	_hint_showing = true
	_hint_idle = 0.0
	if _hint_count == 2 and _hint_voice != "":
		Voice.say(_hint_voice)
	var p0: Vector2 = c.get_global_rect().get_center()
	hand.global_position = p0 - Vector2(20, 4)
	hand.texture = _hand_frames[0]
	hand.visible = true
	expose("hint_hand", hand)
	set_info("hint_shown", int(info.get("hint_shown", 0)) + 1)
	_hint_tween = hand.create_tween()
	var d = _hint_drag_to.call() if _hint_drag_to.is_valid() else null
	if d != null and is_instance_valid(d):
		var p1: Vector2 = d.get_global_rect().get_center()
		_hint_tween.tween_property(hand, "global_position", p1 - Vector2(20, 4), 1.2)
	else:
		_hint_tween.set_loops(3)
		_hint_tween.tween_callback(func(): hand.texture = _hand_frames[1])
		_hint_tween.tween_property(hand, "scale", Vector2(0.85, 0.85), 0.25)
		_hint_tween.tween_callback(func(): hand.texture = _hand_frames[0])
		_hint_tween.tween_property(hand, "scale", Vector2.ONE, 0.25)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed:
		hint_reset()
		_hint_count = 0

# ---------- iOS: звук ----------
## Godot сам возобновляет AudioContext по первому касанию/клику (слушает touchend/mousedown/keydown в самом движке).
## Первое касание теперь — на экране букв (тап по «А» или по любой плитке): оно и включает звук, дальше s00/s01 уже со звуком.
## Дополнительно: на iOS 17+ просим Safari играть звук даже при беззвучном режиме.
func _ios_audio_session() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try{ if(navigator.audioSession){navigator.audioSession.type='playback';} }catch(e){}", true)

# ---------- журнал и автотест ----------
func log_event(kind: String, data: Dictionary = {}) -> void:
	var e := {"t": Time.get_unix_time_from_system(), "step": screen, "kind": kind}
	e.merge(data)
	log_entries.append(e)
	print("LOG ", JSON.stringify(e))
	var f := FileAccess.open("user://pilot_log.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(log_entries))

func set_state(s: String) -> void:
	state = s
	if test_mode:
		publish()

func expose(name: String, c: Control) -> void:
	if c == null:
		_targets.erase(name)
	else:
		_targets[name] = c

func publish() -> void:
	if not OS.has_feature("web"):
		return
	var t := {}
	for k in _targets.keys():
		var c = _targets[k]
		if is_instance_valid(c) and c.is_visible_in_tree():
			var r: Rect2 = c.get_global_rect()
			t[k] = [r.get_center().x, r.get_center().y]
	var d := {"step": screen, "state": state, "targets": t, "hint_sec": idle_hint_sec,
		"exit_overlaps": _exit_overlaps(),
		"log": log_entries.size(), "caption": caption_label.text,
		"caption_visible": caption_panel.visible, "caption_ever_visible": caption_ever_visible,
		"labels_visible": _visible_labels(), "info": info, "home_requested": home_requested}
	JavaScriptBridge.eval("window.__bk=" + JSON.stringify(d) + ";", true)

## Все видимые надписи (Label) на экране — тест проверяет, что у ребёнка нет текста, кроме А/а.
func _visible_labels() -> Array:
	var out: Array = []
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and (n as Label).is_visible_in_tree() and (n as Label).text.strip_edges() != "":
			out.append((n as Label).text.substr(0, 40))
		stack.append_array(n.get_children())
	return out

## Для теста: видимые кнопки текущего экрана, которые пересекаются с крестиком (должно быть пусто).
func _exit_overlaps() -> Array:
	var out: Array = []
	if exit_btn == null or not exit_btn.visible or current == null:
		return out
	var er := exit_btn.get_global_rect()
	var stack: Array = [current, next_btn, back_btn]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control and n != exit_btn and (n as Control).is_visible_in_tree() \
				and (n is BaseButton or n.name == "reward_album") and (n as Control).get_global_rect().intersects(er):
			out.append(String(n.name))
		stack.append_array(n.get_children())
	return out
