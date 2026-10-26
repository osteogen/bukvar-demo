## Сцена 6. Буква А: большая А и маленькая а по центру парой; Аля (персонаж, ниже букв) говорит, губы — по огибающей
## голоса (Cutout.mouth_frame). Пока Аля описывает букву, называемые части подсвечиваются по таймлайну из данных
## (letter.lines.*.highlights, секунды от начала звука).
## Правки урока А (27.10.2026):
##  • в начале Аля по очереди показывает обе буквы: «Больша́я» — поднимает ЛЕВУЮ руку (к большой А слева),
##    «Ма́ленькая» — ПРАВУЮ (к маленькой а справа); слова «большая»/«маленькая» — отдельные файлы (w_bolshaya,
##    w_malenkaya), их можно склеивать с любой буквой;
##  • касание буквы — снова рука к ней, слово «большая»/«маленькая» и новый текст для 4–7 лет про эту букву
##    (a_letter_06 — большая, a_letter_07 — маленькая) с точной подсветкой частей;
##  • касание во время реплики — Аля сразу переключается на нажатую букву (реплики не накладываются: очередь
##    сбрасывается, затем звучит новая);
##  • подсказка — только через 20 с бездействия (рука на ещё не нажатую букву + «Нажми на любую букву!»).
## Когда нажаты обе — итоговая реплика, затем «Далее». Ответов здесь нет — ничего не подтверждается.
extends LessonStep

## Подсветка части буквы: полупрозрачная жёлтая полоса поверх штриха (чуть шире его — видно и ореол) по линии / овалу
## в долях кадра буквы. letter.hl.front = false — свечение только ЗА буквой.
class PartHL extends Control:
	var pts: PackedVector2Array
	var closed := false
	var w := 0.1
	var col := Color("#FFD23C")
	func _draw() -> void:
		var p := PackedVector2Array()
		for q in pts:
			p.append(Vector2(q.x * size.x, q.y * size.y))
		var lw := w * size.y
		if closed and p.size() > 2:
			p.append(p[0])
		draw_polyline(p, col, lw, true)
		for q in p:   # скруглённые концы и стыки
			draw_circle(q, lw / 2.0, col)

var big: Control
var small: Control
var alya: Cutout
var hls := {}               # "big:left" → PartHL
var _hl_tw: Array = []
var _line_token := 0
var _seen := {"big": false, "small": false}
var _outro_done := false
var _pulse_tw := {}
var _idle := 0.0
var _waiting := false
var _alya_y := 0.0
var _t := 0.0
var _big_btn: Button
var _small_btn: Button

func run() -> void:
	section("letter")
	add_bg(cfg.bg)
	# 1) буквы сразу, парой по центру (данные — letter.big / letter.small; угловые зоны кнопок не задеты)
	big = add_letter(Assets.lesson.big, _v(cfg.big.center), int(cfg.big.h))
	small = add_letter(Assets.lesson.small, _v(cfg.small.center), int(cfg.small.h))
	big.name = "letter_big"
	small.name = "letter_small"
	for l in [big, small]:
		l.pivot_offset = l.size / 2
	_build_parts("big", big)
	_build_parts("small", small)
	pop_in(big)
	pop_in(small, 0.15)
	# 2) Аля — персонаж ниже букв; рот двигается сам, пока звучит голос (Cutout.talk), плюс лёгкое покачивание
	var ad: Dictionary = cfg.alya
	alya = add_character(String(ad.get("who", "alya")), _v(ad.center), _v(ad.size))
	alya.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alya.name = "alya"
	_alya_y = alya.position.y
	main.expose("alya", alya)
	pop_in(alya, 0.25)
	_big_btn = tap_area(big)
	_small_btn = tap_area(small)
	_big_btn.name = "big_tap"
	_small_btn.name = "small_tap"
	main.expose("big", _big_btn)
	main.expose("small", _small_btn)
	_big_btn.pressed.connect(_on_letter.bind("big"))
	_small_btn.pressed.connect(_on_letter.bind("small"))
	# 3) вступление: последовательность реплик letter.lines.intro_seq (рука + подсветка у каждой)
	main.set_state("intro")
	_line_token += 1
	var my := _line_token
	for line in cfg.lines.intro_seq:
		if not await _play_line(line, my): return
	_waiting = true
	main.set_state("wait_letters")

func _v(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))

func _build_parts(letter: String, node: Control) -> void:
	var hc: Dictionary = cfg.get("hl", {})
	var col := Color(String(hc.get("color", "#FFD23C")))
	col.a = float(hc.get("alpha", 0.85))
	var glow := float(hc.get("glow", 1.7))
	var defs: Dictionary = cfg.parts.get(letter, {})
	for part in defs.keys():
		var d: Dictionary = defs[part]
		var h := PartHL.new()
		h.name = "hl_%s_%s" % [letter, part]
		h.size = node.size
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.show_behind_parent = not bool(hc.get("front", true))
		h.set_meta("no_overlap_check", true)
		h.col = col
		h.w = float(d.get("w", 0.1)) * glow
		if d.has("ellipse"):
			var e: Array = d.ellipse
			for k in 48:
				var a := TAU * k / 48.0
				h.pts.append(Vector2(float(e[0]) + cos(a) * float(e[2]), float(e[1]) + sin(a) * float(e[3])))
			h.closed = true
		else:
			for q in d.line:
				h.pts.append(Vector2(float(q[0]), float(q[1])))
		h.modulate.a = 0.0
		node.add_child(h)
		hls["%s:%s" % [letter, part]] = h

## part: "big" (вся буква) | "big:left" | …
func _hl_nodes(part: String) -> Array:
	if hls.has(part):
		return [hls[part]]
	var out: Array = []
	for k in hls.keys():
		if String(k).begins_with(part + ":"):
			out.append(hls[k])
	return out

func _hl_reset() -> void:
	for tw in _hl_tw:
		if tw and tw.is_valid():
			tw.kill()
	_hl_tw.clear()
	for h in hls.values():
		h.modulate.a = 0.0
	main.set_info("s06_hl", [])

## Реплика с таймлайном подсветки. Возвращает false, если сцена закрыта или реплику перебили другой.
func _play_line(line: Dictionary, my: int) -> bool:
	if my != _line_token: return false
	_hl_reset()
	var arm := String(line.get("arm", ""))
	if arm != "" and alya:
		alya.raise_arm(arm, maxf(0.6, Assets.line_dur(String(line.audio)) if not Voice.fast else 0.25) + float(line.get("arm_hold", 0.6)))
		main.set_info("s06_arm", arm)
		main.set_info("s06_arms", (main.info.get("s06_arms", []) as Array) + [arm])
	var fs := float(cfg.get("hl", {}).get("fade_sec", 0.15))
	var k := 1.0
	if Voice.fast:
		k = 0.25 / maxf(Assets.line_dur(String(line.audio)), 0.25)   # в тесте реплика ≈0,25 с — сжимаем таймлайн
	for hd in line.get("highlights", []):
		for h in _hl_nodes(String(hd.part)):
			var tw: Tween = h.create_tween()
			tw.tween_interval(float(hd.t_start) * k)
			tw.tween_callback(func(): _mark_hl(String(hd.part), true))
			tw.tween_property(h, "modulate:a", 1.0, fs)
			tw.tween_interval(maxf(0.0, (float(hd.t_end) - float(hd.t_start)) * k - fs))
			tw.tween_property(h, "modulate:a", 0.0, fs)
			_hl_tw.append(tw)
	var ok := await say(String(line.audio))   # нет файла — Voice.say молча ждёт длительность из lines.json
	if dead: return false
	if my != _line_token: return false
	return ok

var _hl_seen := {}
func _mark_hl(part: String, on: bool) -> void:
	_hl_seen[part] = true
	main.set_info("s06_hl_seen", _hl_seen.keys())

func _soft_pulse(letter: String) -> void:
	if _pulse_tw.has(letter) and _pulse_tw[letter].is_valid():
		return
	if _seen[letter]:
		return
	var n: Control = big if letter == "big" else small
	var pc: Dictionary = cfg.get("pulse", {})
	var sc := float(pc.get("scale", 1.06))
	var sec := float(pc.get("sec", 0.7))
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "scale", Vector2(sc, sc), sec).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "scale", Vector2.ONE, sec).set_trans(Tween.TRANS_SINE)
	_pulse_tw[letter] = tw

func _stop_pulse() -> void:
	for k in _pulse_tw.keys():
		if _pulse_tw[k].is_valid():
			_pulse_tw[k].kill()
	_pulse_tw.clear()
	big.scale = Vector2.ONE
	small.scale = Vector2.ONE

func _on_letter(letter: String) -> void:
	if not _waiting:
		return
	_idle = 0.0
	main.hint_stop()
	_stop_pulse()
	_seen[letter] = true
	main.set_info("s06_seen", _seen.duplicate())
	main.set_info("s06_last", letter)
	# касание прерывает текущее описание: очередь голоса сбрасывается, затем — реплики нажатой буквы
	Voice.stop_voice()
	_line_token += 1
	var my := _line_token
	var seq: Array = cfg.lines.tap_big if letter == "big" else cfg.lines.tap_small
	for line in seq:
		if not await _play_line(line, my): return
	if _seen.big and _seen.small and not _outro_done:
		_outro_done = true
		_waiting = false
		if not await _play_line(cfg.lines.outro, my):
			if dead: return
		_waiting = true
		main.set_info("s06_outro", true)
		finish()

## Подсказка — через 20 с без касаний (main.idle_hint_sec; letter.idle_hint.sec может только увеличить; в тесте —
## ?hint_sec): рука на ещё не нажатую букву и реплика letter.idle_hint.audio («Нажми на любую букву!»).
func _process(dt: float) -> void:
	_t += dt
	if alya and is_instance_valid(alya):
		var bob := float(cfg.alya.get("bob_px", 4))
		var target_y := _alya_y
		if Voice.is_speaking():
			target_y = _alya_y - absf(sin(_t * 6.0)) * bob
		alya.position.y = lerpf(alya.position.y, target_y, minf(1.0, dt * 12.0))
	if not _waiting or _outro_done:
		return
	if Voice.is_speaking():
		_idle = 0.0
		return
	_idle += dt
	var ih: Dictionary = cfg.get("idle_hint", {})
	var lim := float(main.idle_hint_sec)
	if not main.test_mode or not Assets.params.has("hint_sec"):
		lim = maxf(float(ih.get("sec", 20)), lim)
	if _idle < lim:
		return
	_idle = -2.0   # следующая подсказка — после паузы
	var tgt: Control = _small_btn if _seen.big else _big_btn
	main.hint_start(func(): return tgt, "")
	main.set_info("s06_idle_hints", int(main.info.get("s06_idle_hints", 0)) + 1)
	tap_say(String(ih.get("audio", "a_letter_08")))

func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton or ev is InputEventScreenTouch:
		_idle = 0.0
