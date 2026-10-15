class_name PanelTalk
extends RefCounted
## Base for menus that run in the dialogue box with nobody to argue with:
## shops, the gear bag, the Office ledger and the case board. Subclasses fill
## `_show()` with options and answer `_on_option()`; `_say()` plays lines and
## comes back to the menu, or ends with then = "end".

signal finished

var box: DialogueBox
var toast: Callable
var speaker: String
var portrait: String
var _options: Array = []
var _after := "menu"


func _init(p_box: DialogueBox, p_speaker: String, p_toast: Callable, p_portrait := "") -> void:
	box = p_box
	speaker = p_speaker
	toast = p_toast
	portrait = p_portrait
	box.option_picked.connect(_on_option)
	box.cancelled.connect(_on_cancel)
	box.lines_finished.connect(_on_lines)


func start() -> void:
	_show()


func _show() -> void:
	pass


func _on_option(_i: int) -> void:
	pass


func _on_cancel() -> void:
	_end()


func _menu(title: String, options: Array) -> void:
	_options = options
	box.show_menu(title, speaker, options, portrait)


func _say(lines: Array, then := "menu") -> void:
	_after = then
	box.show_lines(lines)


func _on_lines() -> void:
	if _after == "end":
		_end()
	else:
		_show()


func _end() -> void:
	box.option_picked.disconnect(_on_option)
	box.cancelled.disconnect(_on_cancel)
	box.lines_finished.disconnect(_on_lines)
	box.close()
	finished.emit()
