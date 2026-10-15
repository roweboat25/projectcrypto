class_name DialogueBox
extends PanelContainer
## The talk window at the bottom of the screen: a portrait, a speaker, a line,
## and when a choice is needed, a menu steered with up and down, picked with Space.

signal line_advanced
signal lines_finished
signal option_picked(index: int)
signal cancelled

const PORTRAIT_DIR := "res://assets/portraits/"

var _portrait: TextureRect
var _portrait_frame: PanelContainer
var _name: Label
var _text: RichTextLabel
var _menu: VBoxContainer
var _hint: Label
var _lines: Array = []
var _options: Array = []
var _cursor := 0
var _name_of: Callable


func _init(name_of: Callable) -> void:
	_name_of = name_of
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 8
	offset_right = -8
	offset_top = -124
	offset_bottom = -6
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0e1424", 0.94)
	style.border_color = Color("e0303c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_portrait_frame = PanelContainer.new()
	var fstyle := StyleBoxFlat.new()
	fstyle.bg_color = Color("0e1424")
	fstyle.border_color = Color("e8a64a")
	fstyle.set_border_width_all(1)
	fstyle.set_content_margin_all(1)
	_portrait_frame.add_theme_stylebox_override("panel", fstyle)
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(96, 96)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_frame.add_child(_portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 12)
	_name.add_theme_color_override("font_color", Color("e8a64a"))
	_shadow(_name)
	col.add_child(_name)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for f in ["normal_font_size", "italics_font_size", "bold_font_size", "bold_italics_font_size"]:
		_text.add_theme_font_size_override(f, 13)
	_text.add_theme_color_override("default_color", Color("f0e6d2"))
	_text.add_theme_color_override("font_shadow_color", Color("050608"))
	_text.add_theme_constant_override("shadow_offset_x", 1)
	_text.add_theme_constant_override("shadow_offset_y", 1)
	col.add_child(_text)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 0)
	col.add_child(_menu)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 9)
	_hint.modulate.a = 0.6
	col.add_child(_hint)


func _shadow(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color", Color("050608"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)


func is_in_menu() -> bool:
	return not _options.is_empty()


## Plays lines one Space at a time. Each line is [speaker_id, text].
func show_lines(lines: Array) -> void:
	_clear_menu()
	_lines = lines.duplicate()
	visible = true
	_hint.text = "Space"
	_next_line()


## Shows a question and a list of options ({label, enabled}) under the current speaker.
func show_menu(title: String, speaker: String, options: Array) -> void:
	_lines = []
	_options = options
	_cursor = 0
	visible = true
	_name.text = speaker
	_text.text = title
	_hint.text = "W/S choose · Space pick · X back"
	for child in _menu.get_children():
		child.queue_free()
	for o in options:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 12)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_shadow(l)
		_menu.add_child(l)
	_skip_disabled(1)
	_paint_menu()


func move(dir: int) -> void:
	if _options.is_empty():
		return
	_cursor = wrapi(_cursor + dir, 0, _options.size())
	_skip_disabled(dir)
	_paint_menu()


func confirm() -> void:
	if not _options.is_empty():
		if _options[_cursor].get("enabled", true):
			option_picked.emit(_cursor)
		return
	if _lines.is_empty():
		lines_finished.emit()
	else:
		_next_line()
		line_advanced.emit()


func cancel() -> void:
	if not _options.is_empty():
		cancelled.emit()


func close() -> void:
	_clear_menu()
	_lines = []
	visible = false


func _next_line() -> void:
	if _lines.is_empty():
		lines_finished.emit()
		return
	var line: Array = _lines.pop_front()
	_name.text = _name_of.call(line[0])
	_text.text = line[1]
	var path := PORTRAIT_DIR + str(line[0]) + ".png"
	_portrait.texture = load(path) if ResourceLoader.exists(path) else null
	_portrait_frame.visible = _portrait.texture != null


func _skip_disabled(dir: int) -> void:
	var tries := 0
	while tries < _options.size() and not _options[_cursor].get("enabled", true):
		_cursor = wrapi(_cursor + dir, 0, _options.size())
		tries += 1


func _paint_menu() -> void:
	var labels := _menu.get_children()
	for i in labels.size():
		var o: Dictionary = _options[i]
		var l: Label = labels[i]
		l.text = ("> " if i == _cursor else "   ") + o.label
		var color := Color("f0e6d2") if o.get("enabled", true) else Color("6a6f7a")
		if i == _cursor and o.get("enabled", true):
			color = Color("e8a64a")
		l.add_theme_color_override("font_color", color)


func _clear_menu() -> void:
	_options = []
	for child in _menu.get_children():
		child.queue_free()
