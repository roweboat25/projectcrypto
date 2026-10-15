class_name PartyStrip
extends Control
## The party's health at a glance, under the HUD line: one row per member with a small
## portrait, the name, a Composure bar and a Focus bar. Out of a fight every member's
## Composure follows the party's shared nerve (GameState.composure), so the bars read as
## "how much of each person is left" rather than three separate numbers.

const PORTRAIT_DIR := "res://assets/portraits/"
const ROW_H := 24

var _rows: Dictionary = {}   # member id -> {portrait, name, comp, comp_fill, comp_text, focus_fill}


func _init() -> void:
	position = Vector2(8, 22)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build(ids: Array) -> void:
	for c in get_children():
		c.queue_free()
	_rows.clear()
	for i in ids.size():
		var id: String = ids[i]
		var y := i * ROW_H
		var frame := PanelContainer.new()
		var fstyle := StyleBoxFlat.new()
		fstyle.bg_color = Color("0e1424", 0.9)
		fstyle.border_color = Color("e8a64a", 0.8)
		fstyle.set_border_width_all(1)
		fstyle.set_content_margin_all(1)
		frame.add_theme_stylebox_override("panel", fstyle)
		frame.position = Vector2(0, y)
		add_child(frame)
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(20, 20)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_SCALE
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var path := PORTRAIT_DIR + id + ".png"
		if ResourceLoader.exists(path):
			portrait.texture = load(path)
		frame.add_child(portrait)
		var name_label := Label.new()
		name_label.position = Vector2(25, y - 3)
		name_label.add_theme_font_size_override("font_size", 9)
		name_label.add_theme_color_override("font_color", Color("e8a64a"))
		_shadow(name_label)
		add_child(name_label)
		var comp_back := ColorRect.new()
		comp_back.color = Color("0e1424", 0.85)
		comp_back.position = Vector2(25, y + 12)
		comp_back.size = Vector2(62, 5)
		add_child(comp_back)
		var comp_fill := ColorRect.new()
		comp_fill.color = Color("5fc46a")
		comp_fill.position = Vector2(26, y + 13)
		comp_fill.size = Vector2(60, 3)
		add_child(comp_fill)
		var focus_back := ColorRect.new()
		focus_back.color = Color("0e1424", 0.85)
		focus_back.position = Vector2(25, y + 18)
		focus_back.size = Vector2(62, 3)
		add_child(focus_back)
		var focus_fill := ColorRect.new()
		focus_fill.color = Color("5aa0e0")
		focus_fill.position = Vector2(26, y + 19)
		focus_fill.size = Vector2(60, 1)
		add_child(focus_fill)
		var comp_text := Label.new()
		comp_text.position = Vector2(90, y + 10)
		comp_text.add_theme_font_size_override("font_size", 8)
		comp_text.modulate.a = 0.85
		_shadow(comp_text)
		add_child(comp_text)
		_rows[id] = {"name": name_label, "comp_fill": comp_fill, "comp_text": comp_text, "focus_fill": focus_fill}
	refresh()


## Reads each member's numbers from the battle rules so the strip and the fight agree.
func refresh() -> void:
	for id in _rows:
		var m: Dictionary = BattleRules.member(GameData, GameState, id)
		var r: Dictionary = _rows[id]
		var who: String = m.name
		if id == "player" and GameState.player_name != "":
			who = GameState.player_name
		r.name.text = "%s  L%d %s" % [who, m.level, GameData.classes.get(m.cls, {}).get("name", m.cls)]
		var frac: float = clamp(float(m.composure) / max(1.0, float(m.max_composure)), 0.0, 1.0)
		r.comp_fill.size.x = max(1.0, 60.0 * frac)
		r.comp_fill.color = Color("5fc46a") if frac > 0.5 else (Color("e8a64a") if frac > 0.25 else Color("e0303c"))
		r.comp_text.text = "%d/%d" % [m.composure, m.max_composure]
		r.focus_fill.size.x = max(1.0, 60.0 * clamp(float(m.focus) / max(1.0, float(m.max_focus)), 0.0, 1.0))


static func _shadow(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
