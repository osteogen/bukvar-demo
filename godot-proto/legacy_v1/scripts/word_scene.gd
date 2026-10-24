## WordScene — сцена «слово на звук» (аналог WordScene из шаблона Animate):
## intro → ready (искры + рука после бездействия) → tap → слово + голос → награда → end.
extends Control

@export var letter: LetterConfig = preload("res://letters/a.tres")
@export var word_index: int = 0
@export var idle_hint_sec: float = 5.0

enum Step { INTRO, READY, WORD, REWARD, END }
var step: Step = Step.INTRO

@onready var picture: TextureButton = %Picture
@onready var first_lbl: Label = %First
@onready var rest_lbl: Label = %Rest
@onready var word_box: Control = %Word
@onready var hand: Control = %Hand
@onready var burst: CPUParticles2D = %Burst
@onready var voice: AudioStreamPlayer = %Voice
@onready var sfx: AudioStreamPlayer = %Sfx
@onready var hint_timer: Timer = %HintTimer
@onready var status_lbl: Label = %Status

func _ready() -> void:
	var w: WordEntry = letter.words[word_index]
	picture.texture_normal = w.picture
	first_lbl.text = w.text.substr(0, 1)
	rest_lbl.text = w.text.substr(1)
	word_box.modulate.a = 0.0
	hand.visible = false
	picture.pressed.connect(_on_picture_pressed)
	hint_timer.timeout.connect(_show_hint)
	_report("intro")
	# intro: картинка «выпрыгивает»
	picture.pivot_offset = picture.size / 2
	picture.scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(picture, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_enter_ready)

func _enter_ready() -> void:
	step = Step.READY
	hint_timer.start(idle_hint_sec)
	_report("ready")

func _show_hint() -> void:
	if step != Step.READY:
		return
	hand.visible = true
	hand.position = picture.position + picture.size * 0.6
	var tw := create_tween().set_loops(3)
	tw.tween_property(hand, "position:y", hand.position.y + 18, 0.25)
	tw.tween_property(hand, "position:y", hand.position.y, 0.35)
	_report("hint")

func _on_picture_pressed() -> void:
	if step != Step.READY:
		voice.play()          # повтор после конца сцены
		return
	step = Step.WORD
	hint_timer.stop()
	hand.visible = false
	_report("tapped")
	var tw := create_tween()
	tw.tween_property(word_box, "modulate:a", 1.0, 0.3)
	tw.tween_callback(_say_word)

func _say_word() -> void:
	var w: WordEntry = letter.words[word_index]
	voice.stream = w.voice
	voice.play()
	first_lbl.pivot_offset = first_lbl.size / 2
	var tw := create_tween().set_loops(3)
	tw.tween_property(first_lbl, "scale", Vector2(1.2, 1.2), 0.18)
	tw.tween_property(first_lbl, "scale", Vector2.ONE, 0.18)
	# аудио-гейтинг: ждём конца реплики, но не дольше запасной длительности
	await _wait_voice(w.voice_len)
	_reward()

func _wait_voice(fallback: float) -> void:
	var t := get_tree().create_timer(fallback + 1.0)
	while voice.playing and t.time_left > 0.0:
		await get_tree().process_frame
	if not voice.playing:
		return

func _reward() -> void:
	step = Step.REWARD
	sfx.play()
	burst.restart()
	burst.emitting = true
	var tw := create_tween()
	tw.tween_property(picture, "rotation", deg_to_rad(-8), 0.12)
	tw.tween_property(picture, "rotation", deg_to_rad(8), 0.16)
	tw.tween_property(picture, "rotation", 0.0, 0.12)
	tw.tween_interval(0.4)
	tw.tween_callback(func(): step = Step.END; _report("end"))

func _input(event: InputEvent) -> void:
	# любое касание сбрасывает таймер подсказки
	if step == Step.READY and (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
		hand.visible = false
		hint_timer.start(idle_hint_sec)

func _report(s: String) -> void:
	status_lbl.text = "шаг: " + s
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__godot_steps=(window.__godot_steps||[]);window.__godot_steps.push('%s')" % s)
