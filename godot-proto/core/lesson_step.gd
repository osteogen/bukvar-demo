## Базовый класс шага урока. Каждый шаг — своя сцена steps/sNN_*.tscn со скриптом extends LessonStep.
## Правило корутин: после каждого await проверяем, жив ли шаг:  if not await say("id"): return
class_name LessonStep
extends Control

var main                     # core/main.gd
var dead := false
var cfg: Dictionary = {}     # секция lesson.json для шага
var _last_praise := ""
const CFG_KEY := ""

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

func section(key: String) -> Dictionary:
	cfg = Assets.lesson.get(key, {})
	return cfg

func run() -> void:
	pass

# ---------- ожидание ----------
## Реплика ведущей через общую очередь (Voice): ждёт своей очереди и конца; реплики не накладываются.
func say(id: String, max_sec := -1.0, from_sec := 0.0) -> bool:
	if dead:
		return false
	await Voice.say(id, max_sec, from_sec)
	return not dead

## Реакция на нажатие ребёнка (не ждём): не дублирует звучащую ту же реплику и не копит очередь (Voice.tap_say).
func tap_say(id: String, max_sec := -1.0, from_sec := 0.0) -> bool:
	if dead:
		return false
	return Voice.tap_say(id, max_sec, from_sec)

func wait(sec: float) -> bool:
	if dead:
		return false
	if Voice.fast:
		sec = minf(sec, 0.2)
	await Engine.get_main_loop().create_timer(sec).timeout
	return not dead

func praise() -> bool:
	var ids := ["p_ok_01", "p_ok_02", "p_ok_03", "p_ok_04", "p_ok_05", "p_ok_06"]
	ids.erase(_last_praise)
	_last_praise = ids.pick_random()
	Voice.sfx("sfx_ok")
	return await say(_last_praise)

func retry(n: int = 1) -> bool:
	Voice.sfx("sfx_try")
	return await say(["r_try_01", "r_try_02", "r_try_03"][clampi(n - 1, 0, 2)])

func finish() -> void:
	if not dead:
		main.mark_done()
		main.show_next(true)
		main.set_state("done")

# ---------- построение сцены ----------
## Фон 1366×768 лог. (2732×1536 в файле), по центру сцены 1024×768; если окно ещё шире/выше — растягиваем «на вылет».
var _bg: TextureRect
var _bg_id := ""

func add_bg(id: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Assets.tex(id)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_meta("bg", true)          # фон не считается «предметом» в проверке перекрытий кнопками
	add_child(r)
	_bg = r
	_bg_id = id
	relayout()
	return r

func relayout() -> void:
	if _bg == null or main == null:
		return
	# видимая область в координатах шага: шаг может быть сдвинут/уменьшен, чтобы не попадать под кнопки (main._layout_host)
	var vis: Rect2 = main.visible_rect_local()
	var c := Vector2(512, 384)                       # центр фона = центр сцены (рисунок фона совпадает с раскладкой)
	var half := Vector2(maxf(c.x - vis.position.x, vis.end.x - c.x), maxf(c.y - vis.position.y, vis.end.y - c.y))
	var bsz := Vector2(1366, 768)
	var k := maxf(1.0, maxf(2.0 * half.x / bsz.x, 2.0 * half.y / bsz.y))
	bsz *= k
	_bg.size = bsz
	_bg.position = c - bsz / 2

## sz = Vector2.ZERO → натуральный логический размер (исходник 2× × 0.5).
func add_pic(id: String, center: Vector2, sz := Vector2.ZERO, clickable := true) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = Assets.tex(id)
	if sz == Vector2.ZERO:
		sz = Assets.nat_size(b.texture_normal)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.size = sz
	b.position = center - sz / 2
	b.pivot_offset = sz / 2
	b.name = id
	if not clickable:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(b)
	if id == String(Assets.lesson.get("sound_dot", "ui_circle_flat")) or id == "ui_circle_flat":
		cream_underlay(b)
	if is_red_circle(id):
		dot_letter(b)
	return b

## Красные кружки урока (кружок-звук, «да, есть звук» в сцене 4) — lesson.red_circles.
func is_red_circle(id: String) -> bool:
	var ids: Array = Assets.lesson.get("red_circles", [String(Assets.lesson.get("sound_dot", "ui_circle_flat")), "ui_circle_flat"])
	return ids.has(id)

## ОБЩЕЕ ПРАВИЛО (DESIGN_RULES §3): на каждом красном кружке — изучаемая буква ЧЁРНЫМ (lesson.dot_letter, по умолчанию
## заглавная буква урока). Буква — ребёнок кружка: двигается и масштабируется вместе с ним. Размер — dot_letter_frac диаметра.
func dot_letter(n: Control) -> Label:
	if n.has_node("dot_letter"):
		return n.get_node("dot_letter")
	var l := Label.new()
	l.name = "dot_letter"
	l.text = String(Assets.lesson.get("dot_letter", Assets.lesson.get("big", "А")))
	var d := minf(n.size.x, n.size.y)
	l.add_theme_font_size_override("font_size", int(d * float(Assets.lesson.get("dot_letter_frac", 0.62))))
	l.add_theme_color_override("font_color", Color(String(Assets.lesson.get("dot_letter_color", "#1E1A16"))))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = n.size
	l.position = Vector2(0, -d * 0.03)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_meta("no_overlap_check", true)
	n.add_child(l)
	return l

## DESIGN_RULES.md §3: красная буква / красный кружок на насыщенном тёплом фоне (bg_room_evening и др. из
## lesson.cream_underlay_bgs) — только на кремовой подложке #F7F0DE (как карточки s10). Подложка — ребёнок узла,
## рисуется за ним и двигается вместе с ним. На остальных фонах ничего не делаем.
func cream_underlay(n: Control, pad := 0.22) -> void:
	var bgs: Array = Assets.lesson.get("cream_underlay_bgs", ["bg_room_evening"])
	if not bgs.has(_bg_id) or n.has_node("cream_underlay"):
		return
	var p := Panel.new()
	p.name = "cream_underlay"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#F7F0DE")
	var r := int(minf(n.size.x, n.size.y) * (0.5 + pad))
	sb.set_corner_radius_all(r)
	p.add_theme_stylebox_override("panel", sb)
	var m := minf(n.size.x, n.size.y) * pad
	p.position = Vector2(-m, -m)
	p.size = n.size + Vector2(m, m) * 2
	p.show_behind_parent = true
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_meta("no_overlap_check", true)
	n.add_child(p)
	main.set_info("cream_underlays", int(main.info.get("cream_underlays", 0)) + 1)

## Общая рамка-карточка ui_card_frame (рисует иллюстратор) под картинкой: ребёнок узла, рисуется за ним
## (show_behind_parent), чуть больше картинки — двигается и масштабируется вместе с ней. Нет файла — ничего не делаем.
## ОБЩЕЕ ПРАВИЛО (DESIGN_RULES §3): у карточки с картинкой всегда сплошная кремовая подложка #F7F0DE (фон сцены сквозь
## картинку не просвечивает); прозрачная — только явно backing = Color(0,0,0,0).
func add_card_frame(pic: Control, pad := 0.06, backing := Assets.CREAM) -> void:
	# непрозрачная подложка внутри рамки
	if backing.a > 0.0:
		var bk := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = backing
		sb.set_corner_radius_all(int(pic.size.x * 0.06))
		bk.add_theme_stylebox_override("panel", sb)
		bk.size = pic.size
		bk.show_behind_parent = true
		bk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bk.name = "card_backing"
		pic.add_child(bk)
	var t := Assets.tex(String(Assets.lesson.get("card_frame", "ui_card_frame")), false)
	if t == null:
		return
	var f := TextureRect.new()
	f.texture = t
	f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f.stretch_mode = TextureRect.STRETCH_SCALE
	f.size = pic.size * (1.0 + 2.0 * pad)
	f.position = -pic.size * pad
	f.show_behind_parent = true
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.name = "card_frame"
	pic.add_child(f)

func add_text(text: String, center: Vector2, font_size: int, color := Color("#333333"), box := Vector2(400, 120)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size = box
	l.position = center - box / 2
	l.pivot_offset = box / 2
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

## Буква: картинка из res://art/letters/<kind>_<translit>_<upper|lower>.png, если есть, иначе шрифтом.
## height — логическая высота буквы.
func add_letter(ch: String, center: Vector2, height: int, color := Assets.VOWEL_RED, kind := "letter") -> Control:
	var t := Assets.tex(Assets.letter_name(kind, ch), false)
	if t:
		var r := TextureRect.new()
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var nat := Assets.nat_size(t)
		r.size = Vector2(nat.x * height / nat.y, height)
		r.position = center - r.size / 2
		r.pivot_offset = r.size / 2
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		if kind == "letter":
			cream_underlay(r, 0.12)
		return r
	var l := add_text(ch, center, int(height * 0.9), color, Vector2(height * 1.0, height * 1.15))
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 10 if kind == "letter" else 0)
	if kind == "letter" and color == Assets.VOWEL_RED:
		cream_underlay(l, 0.12)
	return l

## Персонаж из слоёв (Cutout): who = "alya" | "bunny"; sz — логический размер кадра.
## Кроватка зайки (bunny_crib_back/_front, 600×440 = 300×220 логич.) с зайкой между слоями.
## По манифесту: зайка (кадр 200 логич.) стоит низом на (150,146) в координатах кроватки.
## Здесь кроватка ≈240×176, значит зайка ≈160.
func add_bunny_crib(who: String, center: Vector2, crib_size := Vector2(240, 176)) -> Cutout:
	var k := crib_size.x / 300.0
	var top_left := center - crib_size / 2
	add_pic("%s/%s_crib_back" % [who, who], center, crib_size, false)
	var bsz := Vector2(200, 200) * k
	var bunny := add_character(who, top_left + Vector2(150, 146) * k - Vector2(0, bsz.y / 2), bsz)
	add_pic("%s/%s_crib_front" % [who, who], center, crib_size, false)
	return bunny

func add_character(who: String, center: Vector2, sz: Vector2) -> Cutout:
	var c := Cutout.new().setup(who, sz)
	c.position = center - sz / 2
	add_child(c)
	return c

## Кадры «оживления» pic_<id>_f1/_f2, если художник их сдал.
func animate_frames(b: TextureButton, id: String, cycles := 3) -> void:
	# кадры берём, только если они того же уровня, что и основная картинка (не смешиваем эскиз и заглушку)
	var tier := Assets.art_tier(id)
	var f1 := Assets.tex(id + "_f1", false) if Assets.art_tier(id + "_f1") == tier else null
	var f2 := Assets.tex(id + "_f2", false) if Assets.art_tier(id + "_f2") == tier else null
	if f1 == null or f2 == null:
		pulse(b, 2)
		return
	var base := b.texture_normal
	var tw := b.create_tween()
	for i in cycles:
		tw.tween_callback(func(): b.texture_normal = f1)
		tw.tween_interval(0.18)
		tw.tween_callback(func(): b.texture_normal = f2)
		tw.tween_interval(0.18)
	tw.tween_callback(func(): b.texture_normal = base)

# ---------- анимации ----------
func pop_in(n: CanvasItem, delay := 0.0) -> void:
	n.scale = Vector2.ZERO
	var tw := n.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(n, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func pulse(n: CanvasItem, times := 2) -> void:
	var tw := n.create_tween().set_loops(times)
	tw.tween_property(n, "scale", Vector2(1.12, 1.12), 0.2)
	tw.tween_property(n, "scale", Vector2.ONE, 0.2)

## Ошибка без наказания: предмет покачивается и плавно возвращается на своё место (без красных крестиков).
## home — исходная позиция; если не задана, берётся meta "home" или текущая.
func shake(n: Control, home = null, slide := true) -> void:
	var to: Vector2 = home if home != null else n.get_meta("home", n.position)
	n.pivot_offset = n.size / 2
	var tw := n.create_tween()
	for r in [-0.14, 0.14, -0.09, 0.09, 0.0]:
		tw.tween_property(n, "rotation", r, 0.07).set_trans(Tween.TRANS_SINE)
	if slide:
		tw.tween_property(n, "position", to, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func burst(at: Vector2, color := Color("#ffd23c")) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.emitting = false
	p.amount = 24
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 160.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, 400)
	p.scale_amount_min = 6.0
	p.scale_amount_max = 10.0
	p.color = color
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)

## Ждём нажатия кнопки; возвращает false, если шаг закрыли.
func tapped(b: BaseButton) -> bool:
	await b.pressed
	return not dead

# ---------- выбор из нескольких вариантов ----------
signal picked(value)

func bind_pick(b: BaseButton, value) -> void:
	b.pressed.connect(func(): picked.emit(value))

## Прозрачная кнопка поверх любого Control (например, над буквой-надписью).
func tap_area(over: Control) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = over.position
	b.size = over.size
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_child(b)
	return b

# ---------- первый жест на странице урока (звук на iOS) ----------
## Общий шаг для сцены 1 (s01_stork, lesson.stork.unlock_tap) и сцены 2 (s02_intro, intro.unlock_tap — если урок открыт
## сразу с неё). В вебе: navigator.userActivation.hasBeenActive (касание уже было — сразу дальше). В тесте (?test=1) —
## только с ?gate=1, чтобы сквозные тесты не ждали лишнего касания. Пока ждём: pulse_node мягко пульсирует, через hint_sec —
## рука на нём, состояние "wait_unlock"; любое касание (в любом месте экрана) — дальше.
## Шаг, у которого свой _input (s06_letter), этот шаг не использует (в Godot 4 _input наследника заменяет этот).
signal _unlocked

func needs_unlock(u: Dictionary) -> bool:
	if not bool(u.get("enabled", true)) or not OS.has_feature("web"):
		return false
	if main.has_meta("audio_unlocked"):
		return false      # на этой странице уже коснулись (сцена 1 → «Далее» → сцена 2): второй раз не ждём
	if main.test_mode and not Assets.flag("gate"):
		return false
	var active = JavaScriptBridge.eval("(navigator.userActivation && navigator.userActivation.hasBeenActive) ? 1 : 0", true)
	return int(active) != 1 or Assets.flag("gate")

func unlock_gate(pulse_node: Control, u: Dictionary) -> bool:
	if dead:
		return false
	if not needs_unlock(u):
		return true
	var sc := float(u.get("pulse_scale", 1.05))
	var half := float(u.get("pulse_sec", 0.8)) / 2
	var tw := pulse_node.create_tween().set_loops()
	tw.tween_property(pulse_node, "scale", Vector2(sc, sc), half)
	tw.tween_property(pulse_node, "scale", Vector2.ONE, half)
	main.hint_start(func(): return pulse_node, "")
	main.set_state("wait_unlock")
	await _unlocked
	main.set_meta("audio_unlocked", true)
	tw.kill()
	pulse_node.scale = Vector2.ONE
	main.hint_stop()
	return not dead

func _input(ev: InputEvent) -> void:
	if main and main.state == "wait_unlock" and (ev is InputEventScreenTouch or ev is InputEventMouseButton) and ev.pressed:
		_unlocked.emit()
