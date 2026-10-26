## Voice (autoload): голос ведущей, эффекты, петля.
## ОЧЕРЕДЬ ГОЛОСА (правка урока А, 27.10.2026, общее правило DESIGN_RULES §«Звук»):
##  • реплики ведущей никогда не накладываются и не обрываются друг другом: say(id) ставит реплику в очередь (FIFO)
##    и ждёт, пока она прозвучит (await Voice.say(...)); следующая начинается только после конца предыдущей;
##  • реакции на нажатия ребёнка — tap_say(id): если ТА ЖЕ реплика уже звучит или ждёт — нажатие ничего не добавляет;
##    в очереди держится не больше ОДНОЙ ожидающей реакции (новое нажатие заменяет прежнее ожидающее), чтобы
##    частые нажатия не копили хвост из реплик;
##  • эффекты (sfx) и фоновая петля в очередь не встают — они короткие и звучат поверх;
##  • очередь сбрасывается только сменой сцены / выходом (stop_voice, stop_all).
## Каждая реплика ждёт свой файл не дольше dur+1 с (если звук не сыграл, урок не зависает); нет файла — молчим dur с
## и показываем субтитр (временный «немой» вариант до записи).
## ГУБЫ: mouth_level() — 0…1 по огибающей громкости текущей реплики (data/common/lipsync.json, tools/make_lipsync.py);
## нет огибающей — псевдослучайное «говорение», пока реплика звучит.
## ?audio=stream — режим Stream вместо Sample (обход падения iOS Safari #116750), для теста на планшетах.
extends Node

signal caption(text: String)
signal line_started(id: String)

var voice: AudioStreamPlayer
var loop_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var fast := false

var _queue: Array = []        # ожидающие реплики: {id, max, done, tap}
var _cur = null               # звучащая реплика (Dictionary) или null
var _gen := 0                 # поколение очереди: stop_voice() увеличивает — всё ожидающее снимается
var _running := false
var _cur_t0 := 0
var _lips: Dictionary = {}    # id → {fps, env:String}
var said_log: Array = []      # для теста: порядок прозвучавших реплик (id, начало мс, конец мс)

func _ready() -> void:
	fast = Assets.flag("fast")
	voice = _mk()
	loop_player = _mk()
	for i in 3:
		sfx_pool.append(_mk())
	var p := "res://data/common/lipsync.json"
	if FileAccess.file_exists(p):
		var d = JSON.parse_string(FileAccess.get_file_as_string(p))
		if d is Dictionary:
			_lips = d

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

## Реплика ведущей в очередь; корутина — ждёт, пока реплика прозвучит (или будет снята сменой сцены).
## max_sec > 0 — не дольше стольких секунд (короткий кусок длинного файла, напр. «а-а-а» из a_find_03).
## from_sec — начать с середины файла (кусок длинной реплики).
func say(id: String, max_sec := -1.0, from_sec := 0.0) -> void:
	var e := {"id": id, "max": max_sec, "done": false, "tap": false, "from": from_sec}
	_queue.append(e)
	_pump()
	while not e.done:
		await get_tree().process_frame

## Реакция на нажатие: не дублирует звучащую/ожидающую ту же реплику, держит не больше одной ожидающей реакции.
## Возвращает false, если нажатие ничего не добавило. Ждать (await) не обязательно.
func tap_say(id: String, max_sec := -1.0, from_sec := 0.0) -> bool:
	if _cur != null and String(_cur.id) == id:
		return false
	for q in _queue:
		if String(q.id) == id:
			return false
	for i in range(_queue.size() - 1, -1, -1):
		if _queue[i].tap:
			_queue[i].done = true
			_queue.remove_at(i)
	var e := {"id": id, "max": max_sec, "done": false, "tap": true, "from": from_sec}
	_queue.append(e)
	_pump()
	return true

func _pump() -> void:
	if not _running:
		_run()

func _run() -> void:
	_running = true
	while not _queue.is_empty():
		var e: Dictionary = _queue.pop_front()
		var g := _gen
		await _play(e, g)
		e.done = true
	_cur = null
	_running = false

func _play(e: Dictionary, g: int) -> void:
	var id := String(e.id)
	_cur = e
	caption.emit(Assets.line_text(id))
	line_started.emit(id)
	var s := _stream(id)
	var limit := Assets.line_dur(id) + 1.0
	if float(e.max) > 0.0:
		limit = minf(limit, float(e.max))
	if not s:
		limit = Assets.line_dur(id) if float(e.max) <= 0.0 else minf(Assets.line_dur(id), float(e.max))
	if fast:
		limit = 0.25
	if s:
		voice.stream = s
		voice.play(float(e.get("from", 0.0)))
	_cur_t0 = Time.get_ticks_msec() - int(float(e.get("from", 0.0)) * 1000.0)
	var t_start := Time.get_ticks_msec()
	var rec := [id, t_start, 0]
	said_log.append(rec)
	if said_log.size() > 200:
		said_log.pop_front()
	await get_tree().process_frame
	while g == _gen and (Time.get_ticks_msec() - t_start) < limit * 1000.0:
		if s and not voice.playing and not fast:
			break
		await get_tree().process_frame
	rec[2] = Time.get_ticks_msec()
	if g == _gen:
		if fast or float(e.max) > 0.0:
			voice.stop()
		caption.emit("")
	_cur = null

## Звучит ли реплика ведущей или ждёт в очереди (для паузы отсчёта руки-подсказки).
func is_speaking() -> bool:
	return _cur != null or not _queue.is_empty()

## id звучащей реплики ("" — тишина).
func current_id() -> String:
	return String(_cur.id) if _cur != null else ""

## Сброс очереди и тишина (смена сцены, выход).
func stop_voice() -> void:
	_gen += 1
	for q in _queue:
		q.done = true
	_queue.clear()
	voice.stop()
	caption.emit("")

## Уровень открытия рта 0…1 для губ персонажа.
func mouth_level() -> float:
	if _cur == null:
		return 0.0
	var id := String(_cur.id)
	var ms := Time.get_ticks_msec() - _cur_t0
	var key := id
	if _lips.has(key):
		var L: Dictionary = _lips[key]
		var env := String(L.get("env", ""))
		var i := int(ms / 1000.0 * float(L.get("fps", 30)))
		if i >= env.length():
			return 0.0
		return float(env.unicode_at(i) - 48) / 9.0
	if not voice.playing and _stream(id) != null:
		return 0.0
	# нет огибающей: «говорим» псевдослучайно, с паузами
	var k := int(ms / 110.0)
	var h := (k * 7919 + 13) % 11
	return 0.0 if h < 2 else float(h) / 10.0

var sfx_counts := {}   # для теста: сколько раз звучал каждый эффект (успех — sfx_ok/sfx_cheer; s08 — sfx_pop)

## Эффект поверх голоса; volume_db < 0 — тише (тихие хлопки шариков в конце сцены 8).
func sfx(id: String, volume_db := 0.0) -> void:
	sfx_counts[id] = int(sfx_counts.get(id, 0)) + 1
	var s := _stream(id)
	if s == null:
		return
	for p in sfx_pool:
		if not p.playing:
			p.stream = s
			p.volume_db = volume_db
			p.play()
			return
	sfx_pool[0].stream = s
	sfx_pool[0].volume_db = volume_db
	sfx_pool[0].play()

func loop_start(id: String) -> void:
	var s := _stream(id)
	if s and not loop_player.playing:
		if s is AudioStreamOggVorbis and not s.loop:
			# копия: тот же файл может звучать и как обычная реплика (a_find_03 — запасная петля сцены 3), её не зацикливаем
			s = s.duplicate()
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
