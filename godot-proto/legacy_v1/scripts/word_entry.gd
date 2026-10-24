## Одно слово «на звук»: текст, картинка, звук.
class_name WordEntry
extends Resource

@export var text: String = ""
@export var picture: Texture2D
@export var voice: AudioStream
@export var voice_len: float = 1.3   ## запасная длительность, если звук не сыграл
