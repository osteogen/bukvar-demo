## Перекладной персонаж из слоёв res://art/characters/<who>/ (все слои — во весь кадр, одного размера, 2×).
## Аля: body, arm_l, arm_r, head, eyes_open/eyes_closed, mouth_0..2 (+ alya_ref.png — цельная картинка).
## Зайка: body, eyes_open/eyes_closed (+ bunny_ref.png) — отдельный персонаж, Аля его не держит.
## Статичные позы (финальная графика v3): characters/alya/poses/alya_pose_<wave|point|joy|sing_crib|shh>.png,
## characters/bunny/poses/bunny_sleep.png. Отдельных слоёв рук для жестов «машет / показывает» нет —
## жест = переключение на статичную позу (pose()), возврат — clear_pose().
## Крупный план (сцена 2): who = "alya_closeup" → characters/alya/closeup/alya_face_base + alya_face_mouth_0..2.
## Наследуется от BaseButton: есть сигнал pressed, можно «нажимать» на персонажа.
class_name Cutout
extends BaseButton

## Точки вращения рук в долях кадра 720×960 (плечи новой Али v3: pivot 284,286 и 440,286 из manifest).
const SHOULDER_L := Vector2(0.394, 0.298)
const SHOULDER_R := Vector2(0.611, 0.298)

var who := ""
var layers: Dictionary = {}
var talk := true            # двигать рот, пока звучит голос
var singing := false        # рот широко «а»
var sleeping := false       # глаза закрыты
var _t := 0.0
var _blink_at := 3.0
var _mouth_tex: Array = []

var ref_mode := false       # показываем цельную картинку <who>_ref (эскиз), а не слои
var pose_name := ""         # текущая статичная поза ("" — слои)
var _pose_rect: TextureRect
var _frame := Vector2.ZERO

func setup(character: String, frame_size: Vector2) -> Cutout:
	who = character
	_frame = frame_size
	size = frame_size
	pivot_offset = frame_size / 2
	focus_mode = Control.FOCUS_NONE
	# если цельная картинка «выше уровнем», чем слои (например, утверждённый эскиз против заглушек слоёв) — берём её
	if who.ends_with("_closeup"):
		return _setup_closeup(frame_size)
	if who.ends_with("_half"):
		# Аля по пояс (s10_end): characters/alya/half/alya_half_base + _mouth_0..2 + _eyes_closed; пока художник не нарисовал — крупный план
		var hb := who.trim_suffix("_half")
		if Assets.tex("%s/half/%s_half_base" % [hb, hb], false) != null:
			return _setup_closeup(frame_size, "half", "half_")
		who = hb + "_closeup"
		return _setup_closeup(frame_size)
	var ref_tier := Assets.art_tier("%s/%s_ref" % [who, who])
	var body_tier := Assets.art_tier("%s/body" % who)
	ref_mode = ref_tier >= 0 and (body_tier < 0 or ref_tier < body_tier)
	if ref_mode:
		var r := TextureRect.new()
		r.texture = Assets.tex("%s/%s_ref" % [who, who])
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.size = frame_size
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		return self
	for part in ["body", "arm_l", "arm_r", "head", "eyes_open", "eyes_closed", "mouth_0"]:
		var t := Assets.tex("%s/%s" % [who, part], false)
		if t:
			var r := TextureRect.new()
			r.texture = t
			r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.stretch_mode = TextureRect.STRETCH_SCALE
			r.size = frame_size
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(r)
			layers[part] = r
	for part in ["arm_l", "arm_r"]:
		if layers.has(part):
			layers[part].pivot_offset = frame_size * (SHOULDER_L if part == "arm_l" else SHOULDER_R)
	for i in 3:
		_mouth_tex.append(Assets.tex("%s/mouth_%d" % [who, i], false))
	if layers.is_empty():          # нет слоёв — показываем референс
		var ref := Assets.tex("%s/%s_ref" % [who, who])
		var r := TextureRect.new()
		r.texture = ref
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.size = frame_size
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
	if layers.has("eyes_closed"):
		layers.eyes_closed.visible = false
	return self

func _setup_closeup(frame_size: Vector2, dir := "closeup", pre := "face_") -> Cutout:
	var base := who.trim_suffix("_closeup").trim_suffix("_half")
	for part in [pre + "base", pre + "mouth_0"]:
		var t := Assets.tex("%s/%s/%s_%s" % [base, dir, base, part], false)
		if t == null:
			continue
		var r := TextureRect.new()
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.size = frame_size
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		layers["mouth_0" if part == pre + "mouth_0" else "body"] = r
	for i in 3:
		_mouth_tex.append(Assets.tex("%s/%s/%s_%smouth_%d" % [base, dir, base, pre, i], false))
	# моргание крупного плана: слой глаз закрыты (заглушка art_placeholder/…/alya_face_eyes_closed, ждёт художника)
	var ec := Assets.tex("%s/%s/%s_%seyes_closed" % [base, dir, base, pre], false)
	if ec and not layers.is_empty():
		var r2 := TextureRect.new()
		r2.texture = ec
		r2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r2.size = frame_size
		r2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r2.visible = false
		add_child(r2)
		layers["eyes_closed"] = r2
		layers["eyes_open"] = layers["body"]   # глаза открыты нарисованы в основе: «открыть» = спрятать слой закрытых
		_closeup_blink = true
	if layers.is_empty():   # нет крупного плана — обычные слои персонажа
		who = base
		return setup(base, frame_size)
	return self

## Статичная поза: alya → characters/alya/poses/alya_pose_<name>; для зайки «sleep» → bunny/poses/bunny_sleep.
## Возвращает false, если позы нет (тогда остаются слои).
## Позы бывают двух видов (финальная графика v4):
##  • кадр слоёв 720×960 (sing_crib, shh) — растягиваем на весь кадр персонажа, как слои;
##  • обрезанные по высоте 1040 (wave/point/joy) — без нормировки «прыгали» бы по росту.
##    Масштаб: стоящая Аля в них 1028 px (поля 6), в кадре слоёв — 930 px (16…946),
##    поэтому 1 px позы = POSE_CROP_K px кадра слоёв; ноги ставим на ту же линию y=946.
## Если у позы есть <id>_base + _mouth_0/1/2 — собираем позу из основы и рта (рот поёт/говорит).
const BASE_FRAME := {"alya": Vector2(720, 960), "bunny": Vector2(400, 400)}
const ALYA_FIG_BOTTOM := 946.0
const POSE_CROP_K := 930.0 / 1028.0
const POSE_CROP_PAD := 6.0
var _pose_mouth: TextureRect
var _pose_mouth_tex: Array = []
var _closeup_blink := false
var _arm_pose_t := 0.0
var blinks := 0                 # для теста: сколько раз моргнула
var last_mouth := 0

## ГУБЫ (общее ядро): кадр рта 0/1/2 по уровню громкости текущей реплики (Voice.mouth_level — огибающая из
## data/common/lipsync.json; нет огибающей — псевдослучайно). Пороги — lesson.json "lipsync" {open1, open2}.
## Нет звука — рот закрыт (0). Художник может сдать позже фонемные рты: тот же интерфейс mouth_frame() → номер кадра.
const LIP_T1 := 0.15
const LIP_T2 := 0.5
func mouth_frame() -> int:
	var lv: float = Voice.mouth_level()
	last_mouth = 0 if lv < LIP_T1 else (1 if lv < LIP_T2 else 2)
	return last_mouth

## Поднять руку (сцена 6: левая — к большой А, правая — к маленькой а). side = "l" | "r" — сторона КАДРА
## (рука, что ближе к левому / правому краю экрана; у Али, стоящей лицом к нам, это её правая / левая рука —
## в задании «левая рука» = рука со стороны левой буквы). Есть поза художника alya_pose_arm_left_up / _right_up —
## берём её; нет — поворачиваем слой руки (временно, ждёт художника). sec — сколько держать (0 — до lower_arms()).
func raise_arm(side: String, sec := 1.6, ang_rad := 2.3, pose_id := "") -> void:
	var pname := pose_id if pose_id != "" else ("arm_left_up" if side == "l" else "arm_right_up")
	_lower_arms()
	if pose(pname):
		_arm_pose_t = sec
		raised = side
		return
	clear_pose()
	var part := "arm_l" if side == "l" else "arm_r"
	if not layers.has(part):
		return
	var a: Control = layers[part]
	# поворот вокруг плеча: левая (в кадре) рука вверх-влево — против часовой (отрицательный угол)
	var ang := ang_rad if side == "l" else -ang_rad
	var tw := a.create_tween()
	tw.tween_property(a, "rotation", ang, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_arm_pose_t = sec
	raised = side

var raised := ""                # для теста: какая рука поднята сейчас ("l" / "r" / "")

func lower_arms() -> void:
	_lower_arms()

func _lower_arms() -> void:
	_arm_pose_t = 0.0
	if pose_name.begins_with("arm_") or pose_name.begins_with("point_"):
		clear_pose()
	for part in ["arm_l", "arm_r"]:
		if layers.has(part) and absf(layers[part].rotation) > 0.01:
			var a: Control = layers[part]
			a.create_tween().tween_property(a, "rotation", 0.0, 0.25)
	raised = ""

func pose(name: String) -> bool:
	var id := "%s/poses/%s_pose_%s" % [who, who, name]
	if who == "bunny":
		id = "bunny/poses/bunny_%s" % name
	var base := Assets.tex(id + "_base", false)
	var t := base if base != null else Assets.tex(id, false)
	if t == null:
		return false
	if _pose_rect == null:
		_pose_rect = TextureRect.new()
		_pose_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_pose_rect.stretch_mode = TextureRect.STRETCH_SCALE
		_pose_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_pose_rect)
		_pose_mouth = TextureRect.new()
		_pose_mouth.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_pose_mouth.stretch_mode = TextureRect.STRETCH_SCALE
		_pose_mouth.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pose_rect.add_child(_pose_mouth)
	_pose_rect.texture = t
	var ts := t.get_size()
	var bf: Vector2 = BASE_FRAME.get(who, ts)
	var fx := _frame.x / bf.x
	var fy := _frame.y / bf.y
	if ts.is_equal_approx(bf):
		_pose_rect.position = Vector2.ZERO
		_pose_rect.size = _frame
	elif who == "alya":
		var sz := Vector2(ts.x * fx, ts.y * fy) * POSE_CROP_K
		_pose_rect.size = sz
		_pose_rect.position = Vector2((_frame.x - sz.x) * 0.5,
			ALYA_FIG_BOTTOM * fy - (ts.y - POSE_CROP_PAD) * fy * POSE_CROP_K)
	else:
		# прочие (bunny_sleep 760×402): вписать с сохранением пропорций, низом к низу кадра
		var k := minf(_frame.x / ts.x, _frame.y / ts.y)
		_pose_rect.size = ts * k
		_pose_rect.position = Vector2((_frame.x - ts.x * k) * 0.5, _frame.y - ts.y * k)
	_pose_mouth_tex = []
	if base != null:
		for i in 3:
			_pose_mouth_tex.append(Assets.tex("%s_mouth_%d" % [id, i], false))
		# слои рта — во весь кадр позы (точка крепления (338,477) уже учтена в файлах)
		_pose_mouth.position = Vector2.ZERO
		_pose_mouth.size = _pose_rect.size
		_pose_mouth.texture = _pose_mouth_tex[0]
	_pose_mouth.visible = base != null
	_pose_rect.visible = true
	for k2 in layers:
		layers[k2].visible = false
	pose_name = name
	return true

func clear_pose() -> void:
	if _pose_rect:
		_pose_rect.visible = false
	for k in layers:
		layers[k].visible = k != "eyes_closed"
	pose_name = ""

## Показать позу на время, потом вернуться к слоям.
func pose_for(name: String, sec: float) -> void:
	if not pose(name):
		return
	var tw := create_tween()
	tw.tween_interval(sec)
	tw.tween_callback(func(): if pose_name == name: clear_pose())

func _process(delta: float) -> void:
	_t += delta
	if _arm_pose_t > 0.0:
		_arm_pose_t -= delta
		if _arm_pose_t <= 0.0:
			_lower_arms()
	if pose_name != "":
		if _pose_mouth and _pose_mouth.visible and _pose_mouth_tex.size() == 3:
			var pm := 0
			if singing:
				pm = 2 if int(_t * 2.0) % 2 == 0 else 1
			elif talk:
				pm = mouth_frame()
			if _pose_mouth_tex[pm]:
				_pose_mouth.texture = _pose_mouth_tex[pm]
		return
	if layers.has("eyes_open") and layers.has("eyes_closed"):
		var closed := sleeping or (_t > _blink_at and _t < _blink_at + 0.15)
		if _t > _blink_at + 0.15:
			_blink_at = _t + randf_range(2.5, 4.5)
			blinks += 1
		if not _closeup_blink:
			layers.eyes_open.visible = not closed
		layers.eyes_closed.visible = closed
	if layers.has("mouth_0") and _mouth_tex.size() == 3:
		var m := 0
		if singing:
			m = 2
		elif talk:
			m = mouth_frame()
		if _mouth_tex[m]:
			layers.mouth_0.texture = _mouth_tex[m]

## «Машет»: статичная поза alya_pose_wave (слоёв рук для жеста нет); если позы нет — качаем слой руки.
func wave(times := 2) -> void:
	if pose("wave"):
		var tw0 := create_tween()
		tw0.tween_interval(0.6 * times + 0.6)
		tw0.tween_callback(func(): if pose_name == "wave": clear_pose())
		return
	if not layers.has("arm_r"):
		return
	var a: Control = layers.arm_r
	var tw := a.create_tween().set_loops(times)
	tw.tween_property(a, "rotation", -0.9, 0.25)
	tw.tween_property(a, "rotation", -0.4, 0.25)
	tw.chain().tween_property(a, "rotation", 0.0, 0.2)

func rock(times := 2) -> void:
	var tw := create_tween().set_loops(times)
	tw.tween_property(self, "rotation", 0.06, 0.5)
	tw.tween_property(self, "rotation", -0.06, 0.5)
	tw.chain().tween_property(self, "rotation", 0.0, 0.3)
