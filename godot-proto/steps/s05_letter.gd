## Сцена 5. Буква А: вырастает из кружка, лесенка, портрет Али (без надписи), маленькая а.
extends LessonStep

const LETTER_H := 300.0
const LADDER_OFFSET := Vector2(338 - 322, 755 - 750)   # px файла буквы: сдвиг кадра лесенки относительно кадра буквы

func run() -> void:
	section("letter")
	add_bg(cfg.bg)
	# лесенка в том же масштабе, что и буква (так её рисовал иллюстратор): k = высота буквы / 812
	var k := LETTER_H / 812.0
	var lsz := Vector2(644, 768) * k
	var ladder := add_pic(cfg.shape_pic, Vector2(220, 360), lsz)
	ladder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var circ := add_pic(String(Assets.lesson.get("sound_dot", "ui_circle_flat")), Vector2(600, 360), Vector2(80, 80), false)
	var big := add_letter(Assets.lesson.big, Vector2(600, 360), int(LETTER_H))
	big.visible = false
	var tg := create_tween()
	tg.tween_interval(1.5)
	tg.tween_callback(func(): circ.visible = false; big.visible = true; pop_in(big))
	if not await say(cfg.lines[0]): return
	big.visible = true
	circ.visible = false
	var home := ladder.position
	# полупрозрачная лесенка (pic_lesenka_ghost) накладывается на букву: низ ножек (y=750 в файле лесенки)
	# совпадает с нижней линией буквы (низ красного, y=755 в letter_a_upper), центры по x: 322 и 338
	var on_letter := big.position + LADDER_OFFSET * k
	var ghost := add_pic(cfg.shape_pic + "_ghost", on_letter + lsz / 2, lsz, false)
	ghost.visible = false
	main.expose("ladder_ghost", ghost)
	var tl := ladder.create_tween()
	tl.tween_property(ladder, "position", on_letter, 0.6)
	tl.tween_callback(func(): ghost.visible = true; ladder.modulate.a = 0.0)
	tl.tween_interval(1.5)
	tl.tween_callback(func(): ghost.visible = false; ladder.modulate.a = 1.0)
	tl.tween_property(ladder, "position", home, 0.6)
	if not await say(cfg.lines[1]): return
	# портрет Али рядом с буквой; имя звучит только голосом. Написанного слова «Аля» нет:
	# в нём буквы Л и Я, которых ребёнок ещё не знает. На экране только А и а.
	# портрет — сбоку, под лесенкой, целиком внутри листа (лист ≈ x 52…984, y 74…690)
	var portrait := add_pic(cfg.portrait, Vector2(220, 600), Vector2(140, 140), false)
	main.expose("portrait", portrait)
	pop_in(portrait)
	if not await say(cfg.lines[2]): return
	var small := add_letter(Assets.lesson.small, Vector2(870, 420), 170)
	pop_in(small)
	if not await say(cfg.lines[3]): return
	var big_btn := tap_area(big)
	var small_btn := tap_area(small)
	main.expose("big", big_btn)
	main.expose("small", small_btn)
	ladder.mouse_filter = Control.MOUSE_FILTER_STOP
	ladder.pressed.connect(func(): Voice.say(cfg.lines[1]))
	var seen := {"big": false, "small": false}
	big_btn.pressed.connect(func(): pulse(big); Voice.say(cfg.lines[2]); seen.big = true; _check(seen))
	small_btn.pressed.connect(func(): pulse(small); Voice.say(cfg.lines[3]); seen.small = true; _check(seen))
	main.hint_start(func(): return small_btn if seen.big else big_btn, "h_tap_01")
	main.set_state("wait_letters")

func _check(seen: Dictionary) -> void:
	if seen.big and seen.small and not main.next_btn.visible:
		main.hint_stop()
		finish()
