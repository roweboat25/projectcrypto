extends SceneTree
## Headless checks run in CI: godot --headless -s res://tests/run_tests.gd

func _initialize() -> void:
	var data = load("res://scripts/autoload/game_data.gd").new()
	data.load_all()
	var errors: Array[String] = data.validate()
	var state = load("res://scripts/autoload/game_state.gd").new()
	state.party = ["player", "miriam"]
	state.day = 2
	var copy = load("res://scripts/autoload/game_state.gd").new()
	copy.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	if copy.party != state.party or copy.day != 2:
		errors.append("save round-trip lost data")
	if data.cases.is_empty():
		errors.append("no cases loaded")
	for e in errors:
		printerr("FAIL: " + e)
	print("Tests: %s (%d classes, %d foes, %d cases)" % ["PASS" if errors.is_empty() else "FAIL", data.classes.size(), data.foes.size(), data.cases.size()])
	data.free()
	state.free()
	copy.free()
	quit(0 if errors.is_empty() else 1)
