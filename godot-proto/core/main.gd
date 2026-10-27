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
const EXIT_MARGIN := 12.0
## Правило раскладки: кнопки интерфейса (назад, «Далее», крестик) стоят в углах видимой области (с учётом safe-area iPhone).
## Углы сцены 1024×768 под ними зарезервированы (ui_zones, туда не кладут предметы); на широких/высоких экранах кнопки уходят
## в поля вне сцены. Если safe-area вдавливает кнопку в сцену мимо её зоны — сцена (host) уменьшается в оставшееся место.
## Так кнопки никогда не перекрывают картинки, буквы и интерактивные предметы. См. DESIGN_RULES.md, §2.
const BACK_SIZE := 72.0
const NEXT_SIZE := 100.0
const BTN_GAP := 12.0               # зазор между кнопкой и содержимым (покрывает пульсацию «Далее» ×1.15)
var safe_inset := [0.0, 0.0, 0.0, 0.0]   # top, right, bottom, left — в единицах сцены
var content_rect := Rect2(0, 0, W, H)    # где лежит host (координаты сцены)
var caption_panel: ColorRect
var caption_label: Label
var caption_ever_visible := false
var info := {}
var hand: TextureRect
var unlock_layer: Control
var home_requested := false       # веб: ушли на HTML-главную (для автотеста)
var test_mode := false
var log_entries: Array = []
var _targets: Dictionary = {}       # имя -> Control (для автотеста)
var state := ""
var started_ms := 0
## Пройденные сцены (вызвали finish()): при возврате к такой сцене «Далее» видна сразу (DESIGN_RULES §2).
## Сбрасывается кнопкой «Ещё раз» в конце урока (restart()).
var completed: Dictionary = {}
var exiting := false               # крестик нажат: Аля прощается, потом уходим
## Шрифт урока (Bellota Text Bold, SIL OFL 1.1; в файле «а» заменена на однокруглую с хвостиком — fonts/README.md).
const FONT_PATH := "res://fonts/BukvarBellotaText-Bold.ttf"
## Щелчок механической клавиатуры на каждой кнопке интерфейса (свой синтез, CC0 — tools/make_sfx.py).
## Свой звук кнопки — meta "click_sfx" (пустая строка — без щелчка).
const CLICK_SFX := "sfx_click"

# подсказка-рука
var _hint_target: Callable
var _hint_drag_to: Callable
var _hint_voice := ""
var _hint_on_show: Callable         # доп. подсказка при показе руки (напр. искры у кружков паровозика) — тоже только через 20 с
var _hint_active := false
var _hint_force := false            # hint_now(): показать руку сразу (после реплики), не дожидаясь 20 с
var _hint_count := 0
var _hint_idle := 0.0
var _hint_showing := false
var _hint_tween: Tween
var _hand_frames: Array = []
## Бездействие ребёнка до руки-подсказки (и между повторами), с. Единственная настройка; в тесте — ?hint_sec=N.
## Настройки руки-подсказки — data/common/hint.json (задержка, картинка, размер, анимация, правила скрытия).
var hint_cfg: Dictionary = {}
var default_hint_sec := 20.0
var idle_hint_sec := default_hint_sec

func _ready() -> void:
	hint_cfg = Assets._load_json("res://data/common/hint.json")
	default_hint_sec = float(hint_cfg.get("delay_sec", 20.0))
	idle_hint_sec = default_hint_sec
	test_mode = Assets.flag("test")
	if (test_mode or Assets.flag("debug")) and String(Assets.params.get("hint_sec", "")).is_valid_float():
		idle_hint_sec = maxf(0.5, float(Assets.params.get("hint_sec")))
	started_ms = Time.get_ticks_msec()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font_size = 30
	var fnt = load(FONT_PATH)
	if fnt:
		th.default_font = fnt
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
	# без параметров урок сразу начинается со сцены 1 (памятки s00 и выбора «младшего режима» больше нет — текст памятки
	# теперь на главной, кнопка «i»; первый жест для звука на iOS — касание в сцене 1, см. s01_stork.gd и LessonStep.unlock_gate()).
	# ?step=... (s01…s10 или номер сцены 1…10; старое s11_end → s10_end) — сразу нужный шаг; ?step=letters_menu — экран букв внутри Godot (для отладки).
	# Не в вебе (редактор, десктоп) экран букв из Godot остаётся главным.
	var want := String(Assets.params.get("step", ""))
	if want == "s11_end" or want == "11":
		want = "s10_end"         # старые ссылки: финал был s11_end до удаления «Скажи сам» (27.10.2026)
	var i := steps.find(want)
	if i < 0 and want.is_valid_int():
		# номер сцены (1…11): ищем шаг с префиксом «sNN_», а не индекс в списке (s00 из списка убран)
		var pre := "s%02d_" % int(want)
		for k in steps.size():
			if String(steps[k]).begins_with(pre):
				i = k
		if i < 0:
			i = 0
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
	_read_safe_area()
	var vr := safe_rect()
	if exit_btn:
		# кнопки — в углах видимой области за вычетом safe-area (на 16:9 — в полях по бокам, на телефоне-портрете — сверху/снизу)
		back_btn.position = vr.position + Vector2(EXIT_MARGIN, EXIT_MARGIN)
		exit_btn.position = Vector2(vr.end.x - EXIT_MARGIN - EXIT_SIZE, vr.position.y + EXIT_MARGIN)
		next_btn.position = vr.end - Vector2(EXIT_MARGIN + NEXT_SIZE, EXIT_MARGIN + NEXT_SIZE)
	_layout_host(vr)
	if current and current.has_method("relayout"):
		current.relayout()

## Где разместить содержимое шага: видимая область минус поля под кнопки — либо слева/справа (планшет, 16:9,
## телефон-альбом), либо сверху/снизу (телефон-портрет); выбираем вариант, где host крупнее. Масштаб ≤ 1.
func _layout_host(vr: Rect2) -> void:
	if host == null:
		return
	if screen == "letters_menu" or _buttons_fit_zones(vr):
		# обычный случай (планшет 4:3, 16:9, 16:10, телефоны без выреза в зоне сцены): сцена 1:1, кнопки — либо в своих
		# угловых зонах сцены (их шаги держат пустыми), либо вообще вне сцены, в полях
		content_rect = Rect2(0, 0, W, H)
	else:
		var g_near := EXIT_MARGIN + BACK_SIZE + BTN_GAP                       # поле у «назад» (слева / сверху)
		var g_far := EXIT_MARGIN + maxf(NEXT_SIZE, EXIT_SIZE) + BTN_GAP       # поле у «Далее» и крестика (справа / снизу)
		var side := Rect2(vr.position.x + g_near, vr.position.y + BTN_GAP, vr.size.x - g_near - g_far, vr.size.y - 2.0 * BTN_GAP)
		var tb := Rect2(vr.position.x + BTN_GAP, vr.position.y + g_near, vr.size.x - 2.0 * BTN_GAP, vr.size.y - g_near - g_far)
		var ks := minf(1.0, minf(side.size.x / W, side.size.y / H))
		var kt := minf(1.0, minf(tb.size.x / W, tb.size.y / H))
		var area := side if ks >= kt else tb
		var k := maxf(0.3, maxf(ks, kt))
		var sz := Vector2(W, H) * k
		var pos := area.position + (area.size - sz) / 2
		# если места с запасом — держим содержимое по центру сцены, как раньше, но не заходя в поля
		var centered := (Vector2(W, H) - sz) / 2
		pos.x = clampf(centered.x, area.position.x, area.end.x - sz.x) if area.size.x >= sz.x else pos.x
		pos.y = clampf(centered.y, area.position.y, area.end.y - sz.y) if area.size.y >= sz.y else pos.y
		content_rect = Rect2(pos, sz)
	host.position = content_rect.position
	host.scale = Vector2.ONE * (content_rect.size.x / W)

## Угловые зоны сцены 1024×768, зарезервированные под кнопки (в них не кладут предметы — DESIGN_RULES.md, §2):
## «назад» — левый верхний, крестик — правый верхний, «Далее» — правый нижний угол.
func ui_zones() -> Dictionary:
	var zb := EXIT_MARGIN + BACK_SIZE + BTN_GAP
	var zn := EXIT_MARGIN + NEXT_SIZE + BTN_GAP
	return {"back": Rect2(0, 0, zb, zb), "exit": Rect2(W - zb, 0, zb, zb), "next": Rect2(W - zn, H - zn, zn, zn)}

## Кнопки при сцене 1:1 по центру: часть каждой кнопки, попавшая в сцену, лежит в её угловой зоне (или кнопка вне сцены).
## Иначе (вырез/safe-area вдавил кнопки внутрь сцены) — сцену уменьшаем в оставшееся место.
func _buttons_fit_zones(vr: Rect2) -> bool:
	var zones := ui_zones()
	var stage_r := Rect2(0, 0, W, H)
	var rects := {
		"back": Rect2(vr.position + Vector2(EXIT_MARGIN, EXIT_MARGIN), Vector2(BACK_SIZE, BACK_SIZE)),
		"exit": Rect2(Vector2(vr.end.x - EXIT_MARGIN - EXIT_SIZE, vr.position.y + EXIT_MARGIN), Vector2(EXIT_SIZE, EXIT_SIZE)),
		"next": Rect2(vr.end - Vector2(EXIT_MARGIN + NEXT_SIZE, EXIT_MARGIN + NEXT_SIZE), Vector2(NEXT_SIZE, NEXT_SIZE))}
	for k in rects:
		var r: Rect2 = rects[k]
		if r.intersects(stage_r) and not (zones[k] as Rect2).encloses(r.intersection(stage_r)):
			return false
	return true

## Safe-area iPhone (вырез, полоска «домой»): shell.html — viewport-fit=cover, поэтому читаем env(safe-area-inset-*).
func _read_safe_area() -> void:
	safe_inset = [0.0, 0.0, 0.0, 0.0]
	if not OS.has_feature("web"):
		return
	var r = JavaScriptBridge.eval("(function(){try{var d=document.getElementById('__bk_safe');if(!d){d=document.createElement('div');d.id='__bk_safe';" \
		+ "d.style.cssText='position:fixed;left:0;top:0;width:0;height:0;visibility:hidden;pointer-events:none;" \
		+ "padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)';" \
		+ "document.body.appendChild(d);}var c=getComputedStyle(d);return [c.paddingTop,c.paddingRight,c.paddingBottom,c.paddingLeft]" \
		+ ".map(function(x){return parseFloat(x)||0;}).join(',')+','+window.innerWidth;}catch(e){return '';}})()", true)
	var parts := String(r if r != null else "").split(",")
	if parts.size() < 5 or float(parts[4]) <= 0.0:
		return
	var css_to_canvas := get_viewport_rect().size.x / float(parts[4])
	for i in 4:
		safe_inset[i] = float(parts[i]) * css_to_canvas

## Видимая область окна в координатах сцены (для фонов «на вылет»).
func visible_rect() -> Rect2:
	return Rect2(-stage.position, get_viewport_rect().size)

## Видимая область минус safe-area — здесь могут лежать кнопки интерфейса.
func safe_rect() -> Rect2:
	var vr := visible_rect()
	return Rect2(vr.position + Vector2(safe_inset[3], safe_inset[0]),
		vr.size - Vector2(safe_inset[1] + safe_inset[3], safe_inset[0] + safe_inset[2]))

## Видимая область в координатах шага (host может быть сдвинут и уменьшен) — для фонов «на вылет».
func visible_rect_local() -> Rect2:
	var vr := visible_rect()
	var k := host.scale.x if host else 1.0
	var p := host.position if host else Vector2.ZERO
	return Rect2((vr.position - p) / k, vr.size / k)

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

	next_btn = _ui_button("ui_btn_next", Vector2(W - 120, H - 120), Vector2(NEXT_SIZE, NEXT_SIZE))
	next_btn.pressed.connect(next_step)
	next_btn.visible = false
	back_btn = _ui_button("ui_btn_back", Vector2(20, 20), Vector2(BACK_SIZE, BACK_SIZE))
	back_btn.pressed.connect(prev_step)
	back_btn.modulate.a = 0.75
	exit_btn = _ui_button("ui_exit", Vector2.ZERO, Vector2(EXIT_SIZE, EXIT_SIZE))
	exit_btn.name = "ui_exit"
	exit_btn.pressed.connect(exit_to_letters)
	exit_btn.visible = false
	_layout()

	hand = TextureRect.new()
	_hand_frames = hint_frames()
	hand.texture = _hand_frames[0]
	hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hand.size = hint_size()
	hand.pivot_offset = hint_tip()
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
	b.focus_mode = Control.FOCUS_NONE
	click_on(b)
	overlay.add_child(b)
	return b

## Щелчок клавиатуры на нажатие кнопки (общее правило урока: каждая кнопка навигации щёлкает, если у неё нет своего звука).
## Подключается первым, до обработчика кнопки, — щелчок звучит раньше перехода.
func click_on(b: BaseButton, sfx_id := CLICK_SFX) -> void:
	b.set_meta("click_sfx", sfx_id)
	b.pressed.connect(func():
		var id := String(b.get_meta("click_sfx", ""))
		if id != "":
			Voice.sfx(id))

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
	_enter("res://steps/%s.tscn" % screen)
	back_btn.visible = index > 0
	exit_btn.visible = true                  # s01–s10: везде в уроке — выход на главный экран букв
	exit_btn.disabled = false
	exiting = false
	expose("exit", exit_btn if exit_btn.visible else null)
	current.call_deferred("run")
	# вернулись к уже пройденной сцене — «Далее» сразу на месте (без пульсации и руки): можно идти дальше, не проходя заново
	if completed.has(screen) and index < steps.size() - 1:
		show_next(true, false)

## Шаг закончен (LessonStep.finish()): запоминаем, чтобы при возврате «Далее» была видна сразу.
func mark_done(step_name := "") -> void:
	completed[step_name if step_name != "" else screen] = true
	set_info("completed", completed.keys())

## «Ещё раз» в конце урока: урок с начала, как в первый раз.
func restart() -> void:
	log_event("restart", {})
	completed.clear()
	goto(0)

## Экран всех букв (пока активна только «А»). Сюда ведут крестик и «домой» в s10.
func show_letters() -> void:
	_leave_current()
	screen = "letters_menu"
	_enter(LETTERS_MENU)
	back_btn.visible = false
	exit_btn.visible = false
	current.call_deferred("run")

## Вход в урок «А» с экрана букв: сразу сцена 1 (памятки s00 больше нет).
func start_lesson() -> void:
	goto(0)

func exit_to_letters() -> void:
	if screen == "letters_menu":
		return
	if exiting:
		return
	exiting = true
	exit_btn.disabled = true
	log_event("exit", {})
	# Аля прощается («Пока! Увидимся!»), потом уходим. Нет файла — немая реплика dur с; ждём не дольше BYE_MAX_SEC.
	hint_stop()
	Voice.stop_all()
	if current:
		current.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_info("exit_bye", BYE_LINE)
	set_state("exit_bye")
	var t0 := Time.get_ticks_msec()
	var has_audio := Voice._stream(BYE_LINE) != null
	if has_audio or Assets.line_text(BYE_LINE) != "":
		await Voice.say(BYE_LINE, BYE_MAX_SEC)
	if not has_audio:
		await get_tree().create_timer(0.3).timeout
	set_info("exit_bye_ms", Time.get_ticks_msec() - t0)
	go_home()

const BYE_LINE := "c_bye_01"
const BYE_MAX_SEC := 2.5

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
	_layout_host(safe_rect())
	set_state("enter")

func next_step() -> void:
	if index >= steps.size() - 1:
		goto(0)
	else:
		goto(index + 1)

func prev_step() -> void:
	goto(maxi(0, index - 1))

## loud — пульсация ×3 и рука через 20 с (сцена только что пройдена); false — просто видна (возврат к пройденной сцене).
func show_next(on: bool, loud := true) -> void:
	next_btn.visible = on
	expose("next", next_btn if on else null)
	next_btn.scale = Vector2.ONE
	if on and loud:
		var tw := next_btn.create_tween().set_loops(3)
		tw.tween_property(next_btn, "scale", Vector2(1.15, 1.15), 0.3)
		tw.tween_property(next_btn, "scale", Vector2.ONE, 0.3)
		hint_start(func(): return next_btn, "")

# ---------- подсказка-рука ----------
## Все параметры — data/common/hint.json. Поведение (DESIGN_RULES.md §1, §6):
## • появляется через idle_hint_sec без касаний (пока звучит реплика, отсчёт не идёт) или сразу по hint_now();
## • остаётся на экране и повторяет мягкое движение (касание / «ведёт» к цели) — БЕЗ таймера скрытия;
## • прячется сразу, когда ребёнок начинает нужное действие: касание цели (или начало перетаскивания с неё),
##   либо шаг сам вызывает hint_stop()/hint_start() на верный ответ; неверное касание мимо цели её не прячет;
## • voice — реплика на каждом voice_every_shows-м показе подряд. Автопомощи НЕТ: засчитывает только ребёнок.
## Цель руки — Callable шага (target), для перетаскивания ещё drag_to.

## Кадры руки: sprite (новая рука иллюстратора), если файл есть; иначе frames. Тот же набор берёт демо-рука s07.
func hint_frames() -> Array:
	var sp := String(hint_cfg.get("sprite", ""))
	var t: Texture2D = Assets.tex(sp, false) if sp != "" else null
	if t:
		return [t]
	var out: Array = []
	for f in hint_cfg.get("frames", ["ui_hand_f1", "ui_hand_f2"]):
		var ft: Texture2D = Assets.tex(String(f), false)
		if ft:
			out.append(ft)
	if out.is_empty():
		out.append(Assets.tex("ui_hand_f1"))
	return out

func hint_size() -> Vector2:
	var a = hint_cfg.get("size", [96, 96])
	return Vector2(float(a[0]), float(a[1]))

## Кончик пальца в пикселях руки.
func hint_tip() -> Vector2:
	var a = hint_cfg.get("tip", [0.208, 0.042])
	return Vector2(float(a[0]), float(a[1])) * hint_size()

func hint_start(target: Callable, voice := "h_tap_01", drag_to := Callable(), on_show := Callable()) -> void:
	_hint_on_show = on_show
	_hint_target = target
	_hint_voice = voice
	_hint_drag_to = drag_to
	_hint_active = true
	_hint_force = false
	_hint_idle = 0.0
	if _hint_showing:
		# рука уже на экране (напр. шаг заново назначил подсказку после неверного ответа) — не прячем, а переводим
		# на новую цель и продолжаем движение
		_animate_hand()
	else:
		_hint_count = 0

## Показать руку как можно скорее (после ошибок): как только закончится текущая реплика. Ответ по-прежнему ждём от ребёнка.
## ОБЩЕЕ ПРАВИЛО (правки урока А, 27.10.2026; DESIGN_RULES §4): любые подсказки — рука, искры, мерцание — только после
## idle_hint_sec (20 с) бездействия, в том числе после ошибок. hint_now() поэтому лишь перезапускает отсчёт; старое
## поведение «рука сразу после 2-й ошибки» — только если урок явно включит lesson.json "hint_now_after_errors": true.
func hint_now() -> void:
	if not _hint_active:
		return
	if bool(Assets.lesson.get("hint_now_after_errors", false)):
		_hint_force = true
	else:
		_hint_idle = 0.0
		set_info("hint_now_deferred", int(info.get("hint_now_deferred", 0)) + 1)

func hint_stop() -> void:
	_hint_active = false
	_hint_force = false
	_hint_count = 0
	_hide_hand()

## Отсчёт бездействия заново (касание). Показанную руку не прячет — её прячет только нужное действие.
func hint_reset() -> void:
	_hint_idle = 0.0

func _hide_hand() -> void:
	_hint_showing = false
	if _hint_tween:
		_hint_tween.kill()
	hand.scale = Vector2.ONE
	hand.modulate.a = 1.0
	if hand.visible:
		hand.visible = false
		expose("hint_hand", null)
		set_info("hint_hidden", int(info.get("hint_hidden", 0)) + 1)

func _process(delta: float) -> void:
	if not _hint_active or _hint_showing:
		return
	# пока звучит реплика, ребёнок слушает — бездействие не считаем (отсчёт начинается после неё)
	if Voice.is_speaking():
		_hint_idle = 0.0
		return
	_hint_idle += delta
	if _hint_force or _hint_idle >= idle_hint_sec:
		_hint_force = false
		_show_hand()

func _hint_target_node():
	var c = _hint_target.call() if _hint_target.is_valid() else null
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return null
	return c

func _show_hand() -> void:
	var c = _hint_target_node()
	if c == null:
		_hint_idle = 0.0
		return
	_hint_count += 1
	_hint_showing = true
	_hint_idle = 0.0
	var every := int(hint_cfg.get("voice_every_shows", 2))
	if every > 0 and _hint_count % every == 0 and _hint_voice != "":
		Voice.tap_say(_hint_voice)
	if _hint_on_show.is_valid():
		_hint_on_show.call()
	hand.visible = true
	_animate_hand()   # сначала ставим руку к цели, потом публикуем её (иначе тест мог прочитать старое положение)
	expose("hint_hand", hand)
	set_info("hint_shown", int(info.get("hint_shown", 0)) + 1)

## Бесконечная мягкая анимация; каждый круг заново берёт положение цели (на случай поворота экрана / сдвига предмета).
func _animate_hand() -> void:
	if _hint_tween:
		_hint_tween.kill()
	var c = _hint_target_node()
	if c == null:
		_hide_hand()
		return
	hand.scale = Vector2.ONE
	hand.modulate.a = 1.0
	hand.texture = _hand_frames[0]
	hand.global_position = c.get_global_rect().get_center() - hint_tip()
	_hint_tween = hand.create_tween()
	var d = _hint_drag_to.call() if _hint_drag_to.is_valid() else null
	if d != null and is_instance_valid(d):
		var dc: Dictionary = hint_cfg.get("drag", {})
		var p1: Vector2 = d.get_global_rect().get_center() - hint_tip()
		_hint_tween.tween_property(hand, "global_position", p1, float(dc.get("move_sec", 1.2))).set_trans(Tween.TRANS_SINE)
		_hint_tween.tween_interval(float(dc.get("hold_sec", 0.3)))
		_hint_tween.tween_property(hand, "modulate:a", 0.0, float(dc.get("fade_sec", 0.25)))
		_hint_tween.tween_interval(float(dc.get("pause_sec", 0.4)))
	else:
		var tc: Dictionary = hint_cfg.get("tap", {})
		var sc := float(tc.get("scale", 0.85))
		if _hand_frames.size() > 1:
			_hint_tween.tween_callback(func(): hand.texture = _hand_frames[1])
		_hint_tween.tween_property(hand, "scale", Vector2(sc, sc), float(tc.get("down_sec", 0.25)))
		if _hand_frames.size() > 1:
			_hint_tween.tween_callback(func(): hand.texture = _hand_frames[0])
		_hint_tween.tween_property(hand, "scale", Vector2.ONE, float(tc.get("up_sec", 0.25)))
		_hint_tween.tween_interval(float(tc.get("pause_sec", 0.35)))
	_hint_tween.tween_callback(func(): if _hint_showing: _animate_hand())

func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed
	if not pressed:
		return
	hint_reset()
	if not _hint_showing:
		_hint_count = 0
		return
	# рука на экране: касание цели (= начало нужного действия) прячет её сразу; мимо цели — остаётся
	var c = _hint_target_node()
	var on_target: bool = c != null and c.get_global_rect().grow(12).has_point(_event_pos(event))
	if (on_target and bool(hint_cfg.get("hide_on_target_touch", true))) or (not on_target and bool(hint_cfg.get("hide_on_other_touch", false))):
		_hide_hand()
		_hint_count = 0

## Позиция касания в координатах канвы (как get_global_rect элементов).
func _event_pos(event: InputEvent) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * event.position

# ---------- iOS: звук ----------
## Godot сам возобновляет AudioContext по первому касанию/клику (слушает touchend/mousedown/keydown в самом движке).
## Урок — отдельная страница (lesson-a/), касание на главной до неё не «доезжает»: первый жест — в сцене 1 (s02_intro.gd,
## intro.unlock_tap): пока его не было, Аля ждёт касания и ничего не говорит.
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
		"exit_overlaps": _exit_overlaps(), "ui_overlaps": ui_overlaps() if test_mode else [], "sfx_counts": Voice.sfx_counts, "ui_rects": _ui_rects(),
		"content_rect": [content_rect.position.x, content_rect.position.y, content_rect.size.x, content_rect.size.y],
		"visible_rect": _r4(visible_rect()), "safe_rect": _r4(safe_rect()),
		"stage_center": _stage_center(),
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

## Для теста (правило раскладки): пересечения кнопок интерфейса — «назад», «Далее», крестик (их места в полях, даже
## если кнопка сейчас скрыта) — с видимыми предметами шага: картинками, буквами, кнопками, персонажами.
## Фон (meta "bg"), слои во весь экран (≥ сцены) и узлы с meta "no_overlap_check" не считаются; учитываются
## обрезки clip_contents; шаг может добавить свои области через content_rects() (напр. буква-дорожка в s07).
func ui_overlaps() -> Array:
	var out: Array = []
	if current == null or screen == "letters_menu" or exit_btn == null:
		return out
	var btns := {"back": back_btn, "next": next_btn, "exit": exit_btn}
	var items: Array = []   # [имя, Rect2]
	var stack: Array = [current]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CanvasItem and not (n as CanvasItem).visible:
			continue
		if n.has_meta("bg") or n.has_meta("no_overlap_check"):
			continue
		stack.append_array(n.get_children())
		if n == current or not (n is Control):
			continue
		var c := n as Control
		if c.modulate.a < 0.05 or c.self_modulate.a < 0.05:
			continue
		if not (c is TextureRect or c is BaseButton or c is Label or c is ColorRect or c is Panel or c is Cutout):
			continue
		if c is TextureRect and (c as TextureRect).texture == null:
			continue
		if c.size.x >= W - 1.0 and c.size.y >= H - 1.0:
			continue
		var r := _clipped_rect(c)
		if r.size.x > 1.0 and r.size.y > 1.0:
			items.append([String(c.name), r])
	if current.has_method("content_rects"):
		for r in current.content_rects():
			items.append(["content", r])
	for bn in btns:
		var br: Rect2 = (btns[bn] as Control).get_global_rect()
		for it in items:
			if br.intersects(it[1]):
				out.append("%s×%s" % [bn, it[0]])
	return out

func _clipped_rect(c: Control) -> Rect2:
	var r := c.get_global_rect()
	var p := c.get_parent()
	while p != null and p != self:
		if p is Control and (p as Control).clip_contents:
			r = r.intersection((p as Control).get_global_rect())
		p = p.get_parent()
	return r

## Центр сцены 1024×768 (точка 512,384 хоста) в координатах холста — как у get_global_transform_with_canvas() узлов.
func _stage_center() -> Array:
	var c: Vector2 = host.get_global_transform_with_canvas() * Vector2(512, 384)
	return [c.x, c.y]

func _r4(r: Rect2) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]

func _ui_rects() -> Dictionary:
	var d := {}
	if exit_btn == null:
		return d
	for pair in [["back", back_btn], ["next", next_btn], ["exit", exit_btn]]:
		var r: Rect2 = (pair[1] as Control).get_global_rect()
		d[pair[0]] = [r.position.x, r.position.y, r.size.x, r.size.y]
	return d
