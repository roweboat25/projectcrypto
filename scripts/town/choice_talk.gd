class_name ChoiceTalk
extends PanelTalk
## One question in the dialogue box, answered with `chosen(index)`; -1 when backed out of.

signal chosen(index: int)

var title := ""
var options: Array = []
var can_cancel := true


func _init(p_box: DialogueBox, p_title: String, p_options: Array, p_toast: Callable, p_speaker := "") -> void:
	title = p_title
	options = p_options
	super(p_box, p_speaker, p_toast)


func _show() -> void:
	_menu(title, options)


func _on_option(i: int) -> void:
	_end()
	chosen.emit(i)


func _on_cancel() -> void:
	if not can_cancel:
		return
	_end()
	chosen.emit(-1)
