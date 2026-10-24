## Voice (autoload): голос ведущей, эффекты, петля.
## say(id) — корутина: ждёт конца реплики, но не дольше dur+1 с (если звук не сыграл, урок не зависает).
## ?audio=stream — режим Stream вместо Sample (обход падения iOS Safari #116750), для теста на планшетах.
extends Node

signal caption(text: String)

var voice: AudioStreamPlayer
var loop_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var _token := 0
var _speaking := 0          # токен реплики, которая звучит сейчас (0 — тишина)
var _cache: Dictionary = {}
var fast := false

func _ready() -> void:
	fast = Assets.flag("fast")
	voice = _mk()
	loop_player = _mk()
	for i in 3:
		sfx_pool.append(_mk())

func _mk() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	if String(Assets.params.get("audio", "")) == "stream":
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(p)
	return p

func _stream(id: String) -> AudioStream:
	if not _cache.has(id):
		_cache[id] = Assets.sound(id)
	return _cache[id]

## Освобождаем звуки прошлой сцены (память на iPad).
func clear_cache() -> void:
	_cache.clear()

func say(id: String) -> void:
	stop_voice()
	_token += 1
	var my := _token
	_speaking = my
	caption.emit(Assets.line_text(id))
	var s := _stream(id)
	var limit := Assets.line_dur(id) + 1.0
	if fast:
		limit = 0.25
	if s:
		voice.stream = s
		voice.play()
	else:
		limit = Assets.line_dur(id) if not fast else 0.25
	var t0 := Time.get_ticks_msec()
	await get_tree().process_frame
	while my == _token and (Time.get_ticks_msec() - t0) < limit * 1000.0:
		if s and not voice.playing and not fast:
			break
		await get_tree().process_frame
	if _speaking == my:
		_speaking = 0
	if my == _token:
		if fast:
			voice.stop()
		caption.emit("")

## Звучит ли реплика ведущей (для паузы отсчёта руки-подсказки).
func is_speaking() -> bool:
	return _speaking != 0 and _speaking == _token

func stop_voice() -> void:
	_token += 1
	voice.stop()

func sfx(id: String) -> void:
	var s := _stream(id)
	if s == null:
		return
	for p in sfx_pool:
		if not p.playing:
			p.stream = s
			p.play()
			return
	sfx_pool[0].stream = s
	sfx_pool[0].play()

func loop_start(id: String) -> void:
	var s := _stream(id)
	if s and not loop_player.playing:
		if s is AudioStreamOggVorbis:
			s.loop = true
		loop_player.stream = s
		loop_player.play()

func loop_stop() -> void:
	loop_player.stop()

func stop_all() -> void:
	stop_voice()
	loop_stop()
	for p in sfx_pool:
		p.stop()
	caption.emit("")
