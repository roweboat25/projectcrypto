extends Control
## Character creation, between the title and the Office: your name, your field (one of the
## seven classes), and the two partners you take from the roster. Keyboard and mouse both
## work: W/S or the arrows move, Space picks, Escape steps back.

const PORTRAIT_DIR := "res://assets/portraits/"
const ROSTER_ORDER := ["miriam", "teddy", "june", "ruth", "elijah", "dale", "vera"]

var _step := 0
var _name_edit: LineEdit
var _left: VBoxContainer
var _right: VBoxContainer
var _title: Label
var _hint: Label
var _portrait: TextureRect
var _detail: RichTextLabel
var _picked_class := ""
var _picked_partners: Array = []
var _buttons: Array = []


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0a0d18")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_title = Label.new()
	_title.position = Vector2(24, 14)
	_title.add_theme_font_size_override("font_size", 16)
	_title.add_theme_color_override("font_color", Color("e0303c"))
	_shadow(_title)
	add_child(_title)
	_hint = Label.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.offset_left = 24
	_hint.offset_top = -22
	_hint.add_theme_font_size_override("font_size", 10)
	_hint.modulate.a = 0.75
	add_child(_hint)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 40)
	panel.size = Vector2(592, 290)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0e1424", 0.94)
	style.border_color = Color("e0303c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	_left = VBoxContainer.new()
	_left.custom_minimum_size = Vector2(220, 0)
	_left.add_theme_constant_override("separation", 2)
	row.add_child(_left)
	_right = VBoxContainer.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.add_theme_constant_override("separation", 6)
	row.add_child(_right)
	var frame := PanelContainer.new()
	var fstyle := StyleBoxFlat.new()
	fstyle.bg_color = Color("0e1424")
	fstyle.border_color = Color("e8a64a")
	fstyle.set_border_width_all(1)
	fstyle.set_content_margin_all(1)
	frame.add_theme_stylebox_override("panel", fstyle)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_right.add_child(frame)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(96, 96)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_portrait)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.scroll_active = false
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for f in ["normal_font_size", "italics_font_size", "bold_font_size", "bold_italics_font_size"]:
		_detail.add_theme_font_size_override(f, 11)
	_right.add_child(_detail)
	_show_step(0)


func _process(_delta: float) -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner is LineEdit:
		return
	if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("move_down"):
		var side := SIDE_TOP if Input.is_action_just_pressed("move_up") else SIDE_BOTTOM
		if owner != null:
			var next := owner.find_valid_focus_neighbor(side)
			if next != null:
				next.grab_focus()
		elif not _buttons.is_empty():
			_buttons[0].grab_focus()
	if Input.is_action_just_pressed("cancel") and _step > 0:
		_show_step(_step - 1)


func _show_step(step: int) -> void:
	_step = step
	for c in _left.get_children():
		c.queue_free()
	_buttons.clear()
	match step:
		0:
			_title.text = "THE SUTTON OFFICE · NEW HIRE"
			_hint.text = "Type a name, then Enter"
			var l := _label("Your name, for the case file.")
			_left.add_child(l)
			_name_edit = LineEdit.new()
			_name_edit.text = GameState.player_name if GameState.player_name != "" else ""
			_name_edit.placeholder_text = "Investigator"
			_name_edit.max_length = 18
			_name_edit.add_theme_font_size_override("font_size", 13)
			_name_edit.text_submitted.connect(func(_t: String) -> void: _show_step(1))
			_left.add_child(_name_edit)
			_name_edit.grab_focus.call_deferred()
			_set_portrait("player")
			_detail.text = "[b]1994.[/b] The Sutton Office hires one more investigator for the season. Three cases, three verdicts: Hoax, Natural or Unexplained.\n\nThe name goes on every report you file."
		1:
			if _name_edit != null and is_instance_valid(_name_edit):
				GameState.player_name = _name_edit.text.strip_edges()
			_title.text = "YOUR FIELD"
			_hint.text = "W/S choose · Space pick · Esc back"
			for cid in GameData.classes:
				if cid == "_doc":
					continue
				var c: Dictionary = GameData.classes[cid]
				var b := _button("%s  (%s)" % [c.name, c.get("role", "")])
				b.pressed.connect(func() -> void:
					_picked_class = cid
					_show_step(2))
				b.focus_entered.connect(func() -> void: _describe_class(cid, "player"))
				_left.add_child(b)
				_buttons.append(b)
			_focus_first()
		2:
			_title.text = "YOUR PARTNERS  (pick two)"
			_hint.text = "W/S choose · Space pick or unpick · Esc back"
			for pid in ROSTER_ORDER:
				if not GameData.roster.has(pid):
					continue
				var r: Dictionary = GameData.roster[pid]
				var b := _button(_partner_label(pid))
				b.pressed.connect(func() -> void: _toggle_partner(pid, b))
				b.focus_entered.connect(func() -> void: _describe_class(str(r.get("class", "")), pid))
				_left.add_child(b)
				_buttons.append(b)
			var go := _button("Drive to the Office")
			go.disabled = _picked_partners.size() != 2
			go.name = "Go"
			go.pressed.connect(_begin)
			go.focus_entered.connect(_describe_party)
			_left.add_child(go)
			_buttons.append(go)
			_focus_first()


func _partner_label(pid: String) -> String:
	var r: Dictionary = GameData.roster[pid]
	var cname: String = GameData.classes.get(str(r.get("class", "")), {}).get("name", "")
	return "%s%s  (%s)" % ["* " if pid in _picked_partners else "  ", r.name, cname]


func _toggle_partner(pid: String, b: Button) -> void:
	if pid in _picked_partners:
		_picked_partners.erase(pid)
	elif _picked_partners.size() < 2:
		_picked_partners.append(pid)
	b.text = _partner_label(pid)
	var go: Button = _left.get_node_or_null("Go")
	if go != null:
		go.disabled = _picked_partners.size() != 2
		if not go.disabled and _picked_partners.size() == 2:
			go.grab_focus()


func _describe_class(cid: String, who: String) -> void:
	_set_portrait(who)
	var c: Dictionary = GameData.classes.get(cid, {})
	var stats: Dictionary = c.get("stats", {})
	var skills := []
	for s in c.get("skills", []):
		skills.append("%s (L%d)" % [s.get("name", ""), int(s.get("level", 1))])
	var header := "[b]%s[/b]" % c.get("name", cid)
	if who != "player" and GameData.roster.has(who):
		header = "[b]%s[/b], %s" % [GameData.roster[who].name, c.get("name", cid)]
	_detail.text = "%s\n%s\n\nReason %d · Charm %d · Grit %d · Intuition %d\nComposure %d · Focus %d · Speech: %s\n\nSkills: %s" % [
		header, c.get("blurb", ""), int(stats.get("reason", 0)), int(stats.get("charm", 0)), int(stats.get("grit", 0)), int(stats.get("intuition", 0)),
		int(c.get("composure", 40)), int(c.get("focus", 20)), str(c.get("speech", "")).capitalize(), ", ".join(skills)]


func _describe_party() -> void:
	_set_portrait("player")
	var names := []
	for pid in _picked_partners:
		names.append(GameData.roster[pid].name)
	var who: String = GameState.player_name if GameState.player_name != "" else "You"
	_detail.text = "[b]%s[/b], %s\nwith %s\n\nThe station wagon is in the loading dock. First stop: Point Pleasant, West Virginia." % [
		who, GameData.classes.get(_picked_class, {}).get("name", _picked_class), " and ".join(names) if names.size() == 2 else "nobody yet"]


func _begin() -> void:
	if _picked_partners.size() != 2 or _picked_class == "":
		return
	GameState.player_class = _picked_class
	GameState.party = ["player"] + _picked_partners
	if GameData.maps.has("sutton_office"):
		GameState.flags["town_map"] = "sutton_office"
	get_tree().change_scene_to_file("res://scenes/town.tscn")


func _focus_first() -> void:
	if not _buttons.is_empty():
		_buttons[0].grab_focus.call_deferred()


func _set_portrait(id: String) -> void:
	var path := PORTRAIT_DIR + id + ".png"
	_portrait.texture = load(path) if ResourceLoader.exists(path) else null


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 12)
	b.focus_mode = Control.FOCUS_ALL
	return b


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color("e8a64a"))
	return l


static func _shadow(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
