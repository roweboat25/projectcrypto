extends Node3D
## A walkable district. Loads a map from data/maps, spawns the party and NPCs,
## runs the day and night cycle, the talk prompt, dialogue and saves.

const MAP_PATH := "res://data/maps/point_pleasant_main_street.json"
const CYCLE_SECONDS := 150.0   # one full day in real seconds, for now

var map: Dictionary
var built: Dictionary
var party: Array[CharacterBody3D] = []
var rig: Node3D
var env: Environment
var sun: DirectionalLight3D
var time_of_day := 0.80        # 0..1, 0.25 = noon, 0.75 = midnight
var paused_time := false
var _prompt: Label
var _hud: Label
var _dialogue: PanelContainer
var _dialogue_text: RichTextLabel
var _dialogue_name: Label
var _lines: Array = []
var _talking := false
var _near: Node = null
var _snow: CPUParticles3D
var _torch: OmniLight3D


func _ready() -> void:
	map = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	_build_environment()
	built = TownBuilder.build(self, map)
	_spawn_npcs()
	_spawn_party()
	_build_ui()
	if GameState.flags.has("town_time"):
		time_of_day = GameState.flags.town_time
	_apply_time()


func _process(delta: float) -> void:
	if not paused_time and not _talking:
		time_of_day = fmod(time_of_day + delta / CYCLE_SECONDS, 1.0)
	if Input.is_action_just_pressed("toggle_time"):
		time_of_day = 0.25 if time_of_day > 0.5 else 0.8
	_apply_time()
	_update_prompt()
	if Input.is_action_just_pressed("interact"):
		if _talking:
			_advance_dialogue()
		elif _near:
			_start_dialogue(_near)
	if Input.is_action_just_pressed("save"):
		_save()
	if Input.is_action_just_pressed("load"):
		_load()


# ---------- world ----------

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)
	_snow = CPUParticles3D.new()
	_snow.amount = 500
	_snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_snow.lifetime = 8.0
	_snow.preprocess = 8.0
	_snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_snow.emission_box_extents = Vector3(14, 0.5, 14)
	_snow.direction = Vector3(0.2, -1, 0)
	_snow.spread = 10
	_snow.gravity = Vector3(0, -0.6, 0)
	_snow.initial_velocity_min = 0.6
	_snow.initial_velocity_max = 1.2
	var flake := QuadMesh.new()
	flake.size = Vector2(0.06, 0.06)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.albedo_color = Color(1, 1, 1, 0.85)
	flake.material = fm
	_snow.mesh = flake
	add_child(_snow)


func _apply_time() -> void:
	# daylight peaks at 0.25, night is darkest at 0.75
	var daylight: float = clamp(cos((time_of_day - 0.25) * TAU) * 0.5 + 0.5, 0.0, 1.0)
	daylight = pow(daylight, 1.6)
	var night_sky := Color("0e1424")
	var dusk_sky := Color("5a3a4a")
	var day_sky := Color("8fb0d0")
	var sky: Color = night_sky.lerp(dusk_sky, clamp(daylight * 3.0, 0, 1)).lerp(day_sky, daylight)
	env.background_color = sky
	env.ambient_light_color = Color("3d4a5c").lerp(Color("c8d4e0"), daylight)
	env.ambient_light_energy = lerp(0.3, 0.4, daylight)
	env.fog_light_color = Color("121a2c").lerp(Color("9fb4c8"), daylight)
	env.fog_density = lerp(0.03, 0.012, daylight)
	sun.light_color = Color("9ab0c8").lerp(Color("fff1dc"), daylight)
	sun.light_energy = lerp(0.25, 0.7, daylight)
	var angle: float = (time_of_day - 0.25) * TAU
	sun.rotation = Vector3(-PI / 2.0 + cos(angle) * 0.9, 0.5, 0)
	var lamps_on := daylight < 0.45
	for l in built.lamps:
		l.visible = lamps_on
		if l.has_meta("bulb"):
			l.get_meta("bulb").visible = lamps_on
	for n in built.neon:
		n.visible = lamps_on
	if _torch:
		_torch.visible = lamps_on
	if _snow:
		_snow.position = party[0].global_position + Vector3(0, 7, 0) if party.size() > 0 else Vector3(0, 7, 0)


func _spawn_npcs() -> void:
	for n in map.get("npcs", []):
		var npc := StaticBody3D.new()
		npc.set_script(load("res://scripts/town/npc.gd"))
		add_child(npc)
		npc.setup(n)
		npc.position = Vector3(n.pos[0], 0, n.pos[1])
		built.npcs.append(npc)


func _spawn_party() -> void:
	var ids: Array = GameState.party
	if ids.is_empty():
		ids = ["player", "miriam", "teddy"]
		GameState.party = ids
	var looks := {
		"player": [Color("2e3a52"), Color("1d1b1f"), Color("c99068"), false],
		"miriam": [Color("b8a27a"), Color("5a3a22"), Color("e0b48e"), false],
		"teddy": [Color("6b4a33"), Color("2a2420"), Color("c99068"), true],
		"june": [Color("3f6b4f"), Color("1d1b1f"), Color("b8805a"), false],
		"ruth": [Color("6a3a5a"), Color("9a968e"), Color("dcae8a"), false],
		"elijah": [Color("2e2e40"), Color("1a1410"), Color("8a5a3a"), false],
		"dale": [Color("5a6a3a"), Color("a0602a"), Color("e0b08a"), true],
		"vera": [Color("1a1a22"), Color("e8e2d0"), Color("efc6a0"), false],
	}
	var spawn: Array = map.get("spawn", [0, 0, 0])
	var leader: CharacterBody3D = null
	for i in ids.size():
		var w := CharacterBody3D.new()
		w.set_script(load("res://scripts/town/walker.gd"))
		var look: Array = looks.get(ids[i], looks.player)
		if i > 0:
			w.leader = leader
			w.trail_gap = 10 * i
		add_child(w)
		w.setup(PlaceholderArt.investigator_sheet(look[0], look[1], look[2], look[3]))
		w.position = Vector3(spawn[0] - i * 0.9, 0, spawn[2])
		if i == 0:
			leader = w
		party.append(w)
	rig = Node3D.new()
	rig.set_script(load("res://scripts/town/camera_rig.gd"))
	rig.target = leader
	add_child(rig)
	leader.camera_rig = rig
	_torch = OmniLight3D.new()
	_torch.light_color = Color("ffe2b0")
	_torch.light_energy = 1.4
	_torch.omni_range = 4.5
	_torch.position = Vector3(0, 1.3, 0)
	leader.add_child(_torch)
	if GameState.flags.has("town_pos"):
		var p: Array = GameState.flags.town_pos
		leader.position = Vector3(p[0], 0, p[1])
		for i in range(1, party.size()):
			party[i].position = leader.position + Vector3(-i * 0.9, 0, 0)
		rig.global_position = leader.position


# ---------- interaction ----------

func _update_prompt() -> void:
	_near = null
	if _talking or party.is_empty():
		_prompt.visible = false
		return
	var best := 2.6
	var lp: Vector3 = party[0].global_position
	for n in get_tree().get_nodes_in_group("interactable"):
		var d: float = lp.distance_to(n.global_position)
		if d < best:
			best = d
			_near = n
	for door in built.doors:
		var d: float = lp.distance_to(door.pos)
		if d < best:
			best = d
			_near = null
			_prompt.text = "Enter " + door.name + "  (interiors arrive in Milestone 2)"
			_prompt.visible = true
			return
	_prompt.visible = _near != null
	if _near:
		_prompt.text = str(_near.get_meta("prompt")) + "   [Space]"


func _start_dialogue(npc: Node) -> void:
	var case_data: Dictionary = GameData.cases.get("point_pleasant", {})
	_lines = []
	for lead in case_data.get("leads", []):
		if lead.get("speaker") == npc.npc_id:
			for l in lead.lines:
				_lines.append(l)
			break
	if _lines.is_empty():
		_lines = [[npc.npc_id, "Cold night. You're not from around here."]]
	_talking = true
	GameState.flags["_talking"] = true
	_dialogue.visible = true
	_advance_dialogue()


func _advance_dialogue() -> void:
	if _lines.is_empty():
		_talking = false
		GameState.flags["_talking"] = false
		_dialogue.visible = false
		return
	var line: Array = _lines.pop_front()
	_dialogue_name.text = _speaker_name(line[0])
	_dialogue_text.text = line[1]


func _speaker_name(id: String) -> String:
	if GameData.roster.has(id):
		return GameData.roster[id].name
	for n in built.npcs:
		if n.npc_id == id:
			return n.display_name
	return id.capitalize()


# ---------- ui ----------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_hud = Label.new()
	_hud.position = Vector2(16, 12)
	_hud.add_theme_font_size_override("font_size", 16)
	_hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	root.add_child(_hud)

	var help := Label.new()
	help.text = "WASD move · Q/E turn camera · Space talk · T skip to day/night · F5 save · F9 load"
	help.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	help.position = Vector2(-620, 12)
	help.size = Vector2(600, 24)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.add_theme_font_size_override("font_size", 13)
	help.modulate.a = 0.7
	root.add_child(help)

	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-400, -150)
	_prompt.size = Vector2(800, 30)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.add_theme_color_override("font_color", Color("e8a64a"))
	_prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_prompt.visible = false
	root.add_child(_prompt)

	_dialogue = PanelContainer.new()
	_dialogue.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialogue.position = Vector2(-440, -140)
	_dialogue.size = Vector2(880, 120)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0e1424", 0.92)
	style.border_color = Color("e0303c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14)
	_dialogue.add_theme_stylebox_override("panel", style)
	_dialogue.visible = false
	root.add_child(_dialogue)
	var vb := VBoxContainer.new()
	_dialogue.add_child(vb)
	_dialogue_name = Label.new()
	_dialogue_name.add_theme_font_size_override("font_size", 15)
	_dialogue_name.add_theme_color_override("font_color", Color("e8a64a"))
	vb.add_child(_dialogue_name)
	_dialogue_text = RichTextLabel.new()
	_dialogue_text.fit_content = true
	_dialogue_text.add_theme_font_size_override("normal_font_size", 19)
	_dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_dialogue_text)
	var cont := Label.new()
	cont.text = "Space ▸"
	cont.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cont.add_theme_font_size_override("font_size", 12)
	cont.modulate.a = 0.6
	vb.add_child(cont)
	_hud_tick()


func _hud_tick() -> void:
	var hour := int(fmod(time_of_day * 24.0 + 6.0, 24.0))
	var ampm := "AM" if hour < 12 else "PM"
	var h12 := hour % 12
	if h12 == 0:
		h12 = 12
	_hud.text = "Point Pleasant · Main Street   Day %d   %d:00 %s   Dread %d" % [GameState.day, h12, ampm, GameState.dread]
	get_tree().create_timer(0.5).timeout.connect(_hud_tick)


# ---------- saves ----------

func _save() -> void:
	GameState.flags["town_time"] = time_of_day
	GameState.flags["town_pos"] = [party[0].global_position.x, party[0].global_position.z]
	GameState.flags.erase("_talking")
	_toast("Saved" if GameState.save_game() else "Save failed")


func _load() -> void:
	if GameState.load_game():
		get_tree().reload_current_scene()
	else:
		_toast("No save yet")


func _toast(text: String) -> void:
	_prompt.text = text
	_prompt.visible = true
