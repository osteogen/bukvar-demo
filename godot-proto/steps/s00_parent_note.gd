## Сцена 0. Памятка взрослому и «Начнём!» (первое касание включает звук на iPad).
extends LessonStep

const SHORT := "Урок «А» — 5–8 минут.\n\n• Сядьте рядом и включите звук\n  (на iPad проверьте беззвучный режим).\n• Ребёнок играет сам; если ребёнок задумался — появится рука-подсказка.\n• В конце ребёнок говорит вслух, а слушаете ВЫ:\n  галочка ✓ — была попытка,\n  круговая стрелка «ещё раз» —\n  ответа не было или прозвучало другое слово."
const MORE := "\n\nНе подсказывайте сразу — дайте 3–5 секунд. Хвалите за попытку. Звезда — за любую попытку.\nПосле второго «ещё раз» урок всё равно пойдёт дальше.\nИгра без планшета после урока: «Кто дольше споёт [а]?»\nДля 4 лет — «младший режим» (обводка буквы с бо́льшим допуском)."

func run() -> void:
	var b := add_bg("bg_room_day")
	b.modulate = Color(0.55, 0.55, 0.55)
	var card := ColorRect.new()
	card.color = Color(1, 1, 1, 0.94)
	card.position = Vector2(132, 60)
	card.size = Vector2(760, 470)
	add_child(card)
	var txt := add_text(SHORT, Vector2(512, 270), 20, Color("#333"), Vector2(700, 400))
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var more := LinkButton.new()
	more.text = "Подробнее для взрослых"
	more.position = Vector2(170, 490)
	more.add_theme_font_size_override("font_size", 20)
	add_child(more)
	more.pressed.connect(func(): txt.text = SHORT + MORE; more.visible = false)
	# настройка для взрослого: младший режим (4 года) — допуск ±60 px в сцене 6
	var junior := CheckBox.new()
	junior.text = "Младший режим (4 года)"
	junior.button_pressed = bool(Assets.settings.get("junior", false))
	junior.position = Vector2(480, 482)
	junior.add_theme_font_size_override("font_size", 18)
	junior.add_theme_color_override("font_color", Color("#333"))
	junior.add_theme_color_override("font_pressed_color", Color("#333"))
	add_child(junior)
	junior.toggled.connect(func(on: bool): Assets.set_setting("junior", on))
	main.expose("junior", junior)
	var check := add_pic("ui_sound_check", Vector2(820, 470), Vector2(90, 90))
	check.pressed.connect(func(): Voice.sfx("sfx_ok"))
	main.expose("sound_check", check)
	var start := add_pic("ui_btn_start", Vector2(512, 640), Vector2(190, 190))
	main.expose("start", start)
	var tw := start.create_tween().set_loops()
	tw.tween_property(start, "scale", Vector2(1.06, 1.06), 0.5)
	tw.tween_property(start, "scale", Vector2.ONE, 0.5)
	main.hint_start(func(): return start, "")
	main.set_state("wait_start")
	if not await tapped(start):
		return
	main.hint_stop()
	Voice.sfx("sfx_start")
	main.log_event("start")
	var t2 := create_tween().set_parallel()
	t2.tween_property(card, "position:y", 900.0, 0.4)
	t2.tween_property(txt, "position:y", 900.0, 0.4)
	t2.tween_property(b, "modulate", Color.WHITE, 0.4)
	if not await wait(0.5):
		return
	main.next_step()
