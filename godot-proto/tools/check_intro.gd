extends SceneTree

func _initialize() -> void:
	var s = load("res://steps/intro_step.gd")
	print("SCRIPT ", s)
	for id in ["m", "e", "soft", "hard", "yo", "eh"]:
		var lesson = load("res://data/lesson_%s/lesson.json" % id)
		print("JSON ", id, " ", lesson)
	quit()
