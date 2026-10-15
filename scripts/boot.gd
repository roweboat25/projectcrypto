extends Node2D
## Title screen: Main Street at night in the snow, the party under a lamp,
## and the data check. Space starts the case.

var _status: Label


func _ready() -> void:
	MapBuilder.load_indexes()
	var modulate := CanvasModulate.new()
	modulate.color = Color("3a4260")
	add_child(modulate)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var scene := {"size": [20, 12], "ground": "snow", "fills": [{"rect": [0, 9, 20, 3], "tiles": ["asphalt", "asphalt2"]}, {"rect": [0, 8, 20, 1], "tiles": ["cement", "cement_b"]}],
		"facades": [{"id": "diner", "name": "Rosie's Diner", "pos": [1, 8]}, {"id": "sheriff", "name": "Sheriff's Office", "pos": [12, 8]}],
		"props": [{"kind": "lamp_post", "pos": [10.5, 8.6]}, {"kind": "pine_snow", "pos": [0.5, 7.8]}, {"kind": "wagon", "pos": [15, 11.4]}]}
	var built: Dictionary = MapBuilder.build_district(self, scene, Vector2i.ZERO, rng)
	for i in ["player", "miriam", "teddy"]:
		pass
	var ids := ["miriam", "player", "teddy"]
	for i in ids.size():
		var w := CharacterBody2D.new()
		w.set_script(load("res://scripts/town/walker.gd"))
		w.leader = w   # never reads input
		built.actors.add_child(w)
		w.setup(ids[i])
		w.global_position = Vector2(8.6 * 32 + i * 22, 9.6 * 32)
		w.set_physics_process(false)
	var cam := Camera2D.new()
	cam.position = Vector2(10 * 32, 6 * 32)
	add_child(cam)
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "THE CASEBOOK OF UNQUIET PLACES"
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 40
	title.offset_left = -300
	title.offset_right = 300
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("e0303c"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(title)
	var sub := Label.new()
	sub.text = "Season 1, 1994: the Sutton Office\n\nSpace to begin · F9 to load a saved game"
	sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	sub.offset_top = 70
	sub.offset_left = -300
	sub.offset_right = 300
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	sub.add_theme_constant_override("shadow_offset_x", 1)
	sub.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(sub)
	_status = Label.new()
	_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_status.offset_left = 8
	_status.offset_top = -20
	_status.add_theme_font_size_override("font_size", 9)
	_status.modulate.a = 0.7
	layer.add_child(_status)
	var errors: Array[String] = GameData.validate()
	_status.text = "%d classes · %d foes · %d cases · %s" % [GameData.classes.size(), GameData.foes.size(), GameData.cases.size(), "data OK" if errors.is_empty() else "DATA ERRORS: " + ", ".join(errors)]


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("load") and GameState.load_game():
		get_tree().change_scene_to_file("res://scenes/town.tscn")
	elif Input.is_action_just_pressed("interact"):
		# a new hire fills in the form first; debug query strings skip it and pick a map
		if GameState.party.is_empty() and not _has_debug_query():
			get_tree().change_scene_to_file("res://scenes/creation.tscn")
			return
		if GameData.maps.has("sutton_office") and not GameState.flags.has("town_map"):
			GameState.flags["town_map"] = "sutton_office"
		get_tree().change_scene_to_file("res://scenes/town.tscn")


func _has_debug_query() -> bool:
	if not OS.has_feature("web"):
		return false
	return str(JavaScriptBridge.eval("window.location.search", true)).length() > 1
