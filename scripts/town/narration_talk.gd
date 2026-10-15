class_name NarrationTalk
extends RefCounted
## A few lines with nobody to answer: the morning report, a locked door.

signal finished

var box: DialogueBox
var lines: Array


func _init(p_box: DialogueBox, p_lines: Array) -> void:
	box = p_box
	lines = p_lines
	box.lines_finished.connect(_end)


func start() -> void:
	box.show_lines(lines)


func _end() -> void:
	box.close()
	box.lines_finished.disconnect(_end)
	finished.emit()
