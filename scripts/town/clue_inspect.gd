class_name ClueInspect
extends RefCounted
## Looking closely at a physical clue, then choosing how to process it. The
## wrong method spoils the sample; a bagged sample goes to the lab overnight.

signal finished

var box: DialogueBox
var clue: Dictionary
var toast: Callable
var _mode := "look"


func _init(p_box: DialogueBox, p_clue: Dictionary, p_toast: Callable) -> void:
	box = p_box
	clue = p_clue
	toast = p_toast
	box.lines_finished.connect(_on_lines_finished)
	box.option_picked.connect(_on_option)
	box.cancelled.connect(_end)


func start() -> void:
	if clue.has("requires") and not GameState.has_evidence(clue.requires):
		_mode = "done"
		box.show_lines([["narrator", clue.get("locked_text", "You can't get at it.")]])
		return
	if clue.id in GameState.clues_done:
		_mode = "done"
		box.show_lines([["narrator", "You've already dealt with this."]])
		return
	_mode = "look"
	box.show_lines([["narrator", clue.text]])


func _on_lines_finished() -> void:
	if _mode == "look":
		_mode = "menu"
		var opts := []
		for m in Investigation.METHODS:
			opts.append({"label": Investigation.METHOD_VERBS[m], "enabled": true})
		opts.append({"label": "Leave it", "enabled": true})
		box.show_menu("How do you process it?", clue.name, opts)
	else:
		_end()


func _on_option(i: int) -> void:
	if _mode != "menu":
		return
	_mode = "done"
	if i >= Investigation.METHODS.size():
		_end()
		return
	var method: String = Investigation.METHODS[i]
	var r: Dictionary = Investigation.process_clue(GameData, GameState, clue, method)
	var case: Dictionary = Investigation.case_data(GameData, GameState)
	if r.spoiled:
		toast.call("Spoiled. Wrong method.")
		box.show_lines([["narrator", _spoil_text(method)]])
		return
	var e: Dictionary = case.get("evidence", {}).get(r.evidence, {})
	toast.call("Evidence: " + e.get("title", r.evidence))
	var line: String = e.get("text", "")
	if e.has("lab"):
		line += " Bagged and tagged. The lab will have it back by morning."
	box.show_lines([["narrator", line]])


func _spoil_text(method: String) -> String:
	match method:
		"photograph":
			return "The flash goes off. Whatever was there to keep is gone with it, and the sample's no good."
		"bag":
			return "You bag it and the sample crumbles. Should have left it where it lay."
		"cast":
			return "The plaster sets wrong and takes the whole thing with it when you lift it."
		_:
			return "The reading is nothing, and you've trampled it getting the meter in close."


func _end() -> void:
	box.close()
	box.lines_finished.disconnect(_on_lines_finished)
	box.option_picked.disconnect(_on_option)
	box.cancelled.disconnect(_end)
	finished.emit()
