extends Node2D
## A district and its rooms. Loads a map from data/maps, builds it from the
## tile and prop library, spawns the party and townspeople, runs the day and
## night cycle, the talk prompt, conversations, clues, the case file and saves.

const DEFAULT_MAP := "point_pleasant_main_street"
const CYCLE_SECONDS := 180.0   # one full day in real seconds, for now
const T := 32
const PROMPT_RANGE := 40.0

var map: Dictionary
var map_id := ""
var _world: Node2D                # everything built for the current district
var outside: Dictionary
var rooms: Dictionary = {}       # id -> built room
var party: Array[CharacterBody2D] = []
var camera: Camera2D
var time_of_day := 0.80          # 0..1, 0.25 = noon, 0.75 = midnight
var inside := ""                 # room id when indoors
var _modulate: CanvasModulate
var _torch: PointLight2D
var _snow: CPUParticles2D
var _prompt: Label
var _toast_label: Label
var _hud: Label
var _fade: ColorRect
var _box: DialogueBox
var _file: EvidencePanel
var _talk: RefCounted = null     # the running conversation or inspection
var _near: Node = null
var _near_door: Dictionary = {}
var _near_bed := false
var _toast_until := 0.0


func _ready() -> void:
	_modulate = CanvasModulate.new()
	add_child(_modulate)
	var start: String = GameState.flags.get("town_map", DEFAULT_MAP)
	if not GameData.maps.has(start):
		start = DEFAULT_MAP
	_build_map(start)
	_spawn_party()
	_build_snow()
	_build_ui()
	if GameState.flags.has("town_time"):
		time_of_day = GameState.flags.town_time
	if GameState.flags.get("town_inside", "") != "" and rooms.has(GameState.flags.town_inside):
		_enter(GameState.flags.town_inside, false)
	_apply_debug_query()
	_apply_time()
	_apply_phase()


## Builds a district and its rooms under a fresh World node.
func _build_map(id: String) -> void:
	map_id = id
	map = GameData.maps[id]
	rooms = {}
	inside = ""
	if _world:
		_world.queue_free()
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	move_child(_world, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	outside = MapBuilder.build_district(_world, map, Vector2i.ZERO, rng)
	var i := 0
	for rid in map.get("interiors", {}):
		rooms[rid] = MapBuilder.build_room(_world, rid, map.interiors[rid], Vector2i(i * 24, -28), rng)
		i += 1
	GameState.flags["town_map"] = id


## Web builds accept ?inside=diner or ?at=12,23 (tiles) so a scene can be reached directly for testing.
func _apply_debug_query() -> void:
	if not OS.has_feature("web"):
		return
	var query: String = str(JavaScriptBridge.eval("window.location.search", true))
	for part in query.trim_prefix("?").split("&"):
		var kv := part.split("=")
		if kv.size() != 2:
			continue
		if kv[0] == "map" and GameData.maps.has(kv[1]) and kv[1] != map_id:
			_travel({"to": kv[1], "at": GameData.maps[kv[1]].get("spawn", [2, 2])}, false)
		elif kv[0] == "inside" and rooms.has(kv[1]):
			_enter(kv[1], false)
		elif kv[0] == "at":
			var xy := kv[1].split(",")
			if xy.size() == 2:
				_move_party(Vector2(float(xy[0]), float(xy[1])) * T, outside.actors)
		elif kv[0] == "time":
			time_of_day = float(kv[1])


func _process(delta: float) -> void:
	if _talk == null:
		time_of_day = fmod(time_of_day + delta / CYCLE_SECONDS, 1.0)
	_apply_time()
	_toast_label.visible = Time.get_ticks_msec() / 1000.0 < _toast_until
	_snow.position = party[0].global_position + Vector2(0, -230)
	_snow.emitting = inside == ""
	if _talk != null:
		_handle_talk_input()
	elif _file.visible:
		if Input.is_action_just_pressed("evidence") or Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("interact"):
			_file.visible = false
	else:
		_update_prompt()
		if Input.is_action_just_pressed("interact"):
			_interact()
		if Input.is_action_just_pressed("evidence"):
			_file.refresh()
			_file.visible = true
		if Input.is_action_just_pressed("toggle_time"):
			time_of_day = 0.25 if time_of_day > 0.5 else 0.8
		if Input.is_action_just_pressed("save"):
			_save()
		if Input.is_action_just_pressed("load"):
			_load()
		if inside != "" and party[0].global_position.y > rooms[inside].exit_y:
			_leave()
		elif inside == "":
			for e in outside.exits:
				if e.rect.has_point(party[0].global_position):
					_use_exit(e)
					break


# ---------- party and camera ----------

func _spawn_party() -> void:
	var ids: Array = GameState.party
	if ids.is_empty():
		ids = ["player", "miriam", "teddy"]
		GameState.party = ids
	var spawn: Array = map.get("spawn", [2, 2])
	var at := Vector2(spawn[0], spawn[1]) * T
	if GameState.flags.has("town_pos") and GameState.flags.get("town_pos_map", "") == map_id:
		at = Vector2(GameState.flags.town_pos[0], GameState.flags.town_pos[1])
	var leader: CharacterBody2D = null
	for i in ids.size():
		var w := CharacterBody2D.new()
		w.set_script(load("res://scripts/town/walker.gd"))
		if i > 0:
			w.leader = leader
			w.trail_gap = 14 * i
		outside.actors.add_child(w)
		w.setup(ids[i])
		w.global_position = at + Vector2(-i * 18, 0)
		if i == 0:
			leader = w
		party.append(w)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	leader.add_child(camera)
	_set_camera_limits(outside.rect)
	_torch = PointLight2D.new()
	_torch.texture = MapBuilder.light_texture()
	_torch.color = Color("ffe2b0")
	_torch.energy = 0.9
	_torch.texture_scale = 1.1
	_torch.position = Vector2(0, -16)
	leader.add_child(_torch)


func _set_camera_limits(rect: Rect2) -> void:
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)


func _move_party(to: Vector2, actors: Node2D) -> void:
	for i in party.size():
		var w := party[i]
		w.get_parent().remove_child(w)
		actors.add_child(w)
		w.global_position = to + Vector2(0, i * 6)
		w.trail.clear()
	camera.reset_smoothing()


# ---------- day and night ----------

func _build_snow() -> void:
	_snow = CPUParticles2D.new()
	_snow.amount = 220
	_snow.lifetime = 7.0
	_snow.preprocess = 7.0
	_snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_snow.emission_rect_extents = Vector2(400, 20)
	_snow.direction = Vector2(0.15, 1)
	_snow.spread = 12
	_snow.gravity = Vector2(0, 14)
	_snow.initial_velocity_min = 24
	_snow.initial_velocity_max = 44
	_snow.scale_amount_min = 1.0
	_snow.scale_amount_max = 2.0
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.95, 0.97, 1.0, 0.9))
	_snow.texture = ImageTexture.create_from_image(img)
	_snow.z_index = 50
	add_child(_snow)


func _apply_time() -> void:
	# daylight peaks at 0.25, night is darkest at 0.75
	var daylight: float = clamp(cos((time_of_day - 0.25) * TAU) * 0.5 + 0.5, 0.0, 1.0)
	daylight = pow(daylight, 1.5)
	var night := Color("2c3454")
	var dusk := Color("8a6a78")
	var day := Color("ffffff")
	var tint: Color = night.lerp(dusk, clamp(daylight * 3.0, 0, 1)).lerp(day, daylight)
	if inside != "":
		tint = Color("8c8ca0").lerp(day, daylight)
	_modulate.color = tint
	var lamps_on := daylight < 0.45
	for l in outside.lamps:
		l.visible = lamps_on
	for r in rooms.values():
		for l in r.lamps:
			l.visible = true
	_torch.visible = lamps_on and inside == ""


## Who is about and which signs exist depend on the phase of the day and the night of the case.
func _apply_phase() -> void:
	var ph := Investigation.phase(time_of_day)
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.has_meta("when"):
			var when: Array = n.get_meta("when")
			var here: bool = when.is_empty() or ph in when
			n.visible = here
			n.monitoring = here
			n.set_meta("hidden", not here)
		elif n.has_meta("clue"):
			var here := Investigation.clue_visible(GameState, n.data, time_of_day)
			n.visible = here
			n.set_meta("hidden", not here)


# ---------- interaction ----------

func _update_prompt() -> void:
	_near = null
	_near_door = {}
	_near_bed = false
	var lp: Vector2 = party[0].global_position
	var best := PROMPT_RANGE
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.get_meta("hidden", false):
			continue
		var d: float = lp.distance_to(n.global_position)
		if n.has_method("set_near"):
			n.set_near(d < PROMPT_RANGE * 1.6)
		if d < best:
			best = d
			_near = n
	var doors: Array = outside.doors if inside == "" else []
	for door in doors:
		var d: float = lp.distance_to(door.pos + Vector2(0, 10))
		if d < best:
			best = d
			_near = null
			_near_door = door
	if inside != "" and rooms[inside].bed != Vector2.ZERO and lp.distance_to(rooms[inside].bed) < PROMPT_RANGE * 1.5 and _near == null:
		_near = null
		_near_door = {}
		_near_bed = true
	if _near:
		_prompt.text = str(_near.get_meta("prompt")) + "  [Space]"
	elif not _near_door.is_empty():
		_prompt.text = ("Enter " if _door_open(_near_door) else "Try ") + _near_door.name + "  [Space]"
	elif _near_bed:
		_prompt.text = "Sleep until morning  [Space]"
	_prompt.visible = _near != null or not _near_door.is_empty() or _near_bed


func _interact() -> void:
	if _near:
		if _near.has_meta("clue"):
			_talk = ClueInspect.new(_box, _near.data, _toast)
		elif _near.has_meta("hotspot"):
			_use_hotspot(_near)
			return
		else:
			_near.face_toward(party[0].global_position)
			party[0].face_toward(_near.global_position)
			if Investigation.script_for(GameData, GameState, _near.npc_id).is_empty():
				_talk = WitnessTalk.new(_box, _near.npc_id, _near.display_name, _toast)
			else:
				_talk = ScriptTalk.new(_box, _near.npc_id, _near.display_name, _toast)
		_talk.finished.connect(_end_talk)
		GameState.flags["_talking"] = true
		_prompt.visible = false
		_talk.start()
	elif not _near_door.is_empty():
		if _near_door.get("locked", "") != "":
			_toast(_near_door.locked)
		elif not _door_open(_near_door):
			_try_gate(_near_door.gate)
		elif rooms.has(_near_door.id):
			_enter(_near_door.id, true)
		else:
			_toast("Locked.")
	elif _near_bed:
		_prompt.visible = false
		_sleep()


func _door_open(door: Dictionary) -> bool:
	return door.get("gate", "") == "" or Investigation.gate_open(GameData, GameState, door.gate, time_of_day)


## A shut gate: roll its check if it offers one today, else say why it is shut.
func _try_gate(gate_id: String) -> bool:
	var g: Dictionary = Investigation.case_data(GameData, GameState).get("gates", {}).get(gate_id, {})
	var check := Investigation.gate_check(GameData, GameState, gate_id)
	if check.is_empty():
		_toast(g.get("locked", "It's shut."))
		return false
	var r: Dictionary = Investigation.try_gate(GameData, GameState, gate_id)
	var voice: String = Investigation.VOICE_NAMES.get(check.voice, check.voice).capitalize()
	_toast("[%s] %s: %d vs %d" % [voice, "passed" if r.ok else "failed", r.total, r.difficulty])
	return r.ok


## Look text, a pickup, or a barrier.
func _use_hotspot(spot: Node) -> void:
	var p: Dictionary = spot.data
	if p.has("gate"):
		if Investigation.gate_open(GameData, GameState, p.gate, time_of_day) or _try_gate(p.gate):
			GameState.picked.append(spot.key)
			spot.get_meta("node").queue_free()
			_near = null
		return
	if p.has("pickup"):
		GameState.add_item(p.pickup)
		GameState.picked.append(spot.key)
		_toast("Took " + str(GameData.items.get(p.pickup, {}).get("name", p.pickup)))
		spot.get_meta("node").queue_free()
		_near = null
		return
	var lines := []
	if p.look is String:
		lines.append(["narrator", p.look])
	else:
		for l in p.look:
			if GameData.roster.has(l[0]) and not l[0] in GameState.party:
				continue
			lines.append(l)
	if lines.is_empty():
		return
	_talk = NarrationTalk.new(_box, lines)
	_talk.finished.connect(_end_talk)
	GameState.flags["_talking"] = true
	_prompt.visible = false
	_talk.start()


func _use_exit(e: Dictionary) -> void:
	if e.get("gate", "") != "" and not Investigation.gate_open(GameData, GameState, e.gate, time_of_day):
		# step back off the exit and explain
		party[0].global_position += (party[0].global_position - e.rect.get_center()).normalized() * 12
		if not _try_gate(e.gate):
			return
	_travel(e, true)


## Moves the party to another district.
func _travel(e: Dictionary, with_fade: bool) -> void:
	if with_fade:
		await _fade_out()
	var keep := Node2D.new()
	add_child(keep)
	for w in party:
		w.get_parent().remove_child(w)
		keep.add_child(w)
	_build_map(e.to)
	keep.queue_free()
	var at: Array = e.get("at", map.get("spawn", [2, 2]))
	_move_party(Vector2(float(at[0]), float(at[1])) * T, outside.actors)
	_set_camera_limits(outside.rect)
	_apply_time()
	_apply_phase()
	if with_fade:
		await _fade_in()


func _handle_talk_input() -> void:
	if Input.is_action_just_pressed("interact"):
		_box.confirm()
	elif Input.is_action_just_pressed("cancel"):
		_box.cancel()
	elif Input.is_action_just_pressed("move_up"):
		_box.move(-1)
	elif Input.is_action_just_pressed("move_down"):
		_box.move(1)


func _end_talk() -> void:
	_talk = null
	GameState.flags["_talking"] = false


func _enter(id: String, with_fade: bool) -> void:
	var room: Dictionary = rooms[id]
	if with_fade:
		await _fade_out()
	inside = id
	_move_party(room.entry, room.actors)
	_set_camera_limits(room.rect)
	_apply_time()
	if with_fade:
		await _fade_in()


func _leave() -> void:
	var door: Dictionary = {}
	for d in outside.doors:
		if d.id == inside:
			door = d
			break
	await _fade_out()
	inside = ""
	var to: Vector2 = door.pos + Vector2(0, 20) if not door.is_empty() else Vector2(map.spawn[0], map.spawn[1]) * T
	_move_party(to, outside.actors)
	party[0].facing = "down"
	_set_camera_limits(outside.rect)
	_apply_time()
	await _fade_in()


func _sleep() -> void:
	await _fade_out()
	var results: Array = Investigation.sleep(GameData, GameState)
	time_of_day = 0.1
	_apply_time()
	await _fade_in()
	var lines := [["narrator", "Morning. Day %d. Dread %d." % [GameState.day, GameState.dread]]]
	var evidence: Dictionary = Investigation.case_data(GameData, GameState).get("evidence", {})
	for id in results:
		var e: Dictionary = evidence.get(id, {})
		lines.append(["narrator", "Lab results, %s: %s" % [e.get("title", id).replace("Lab: ", ""), e.get("text", "")]])
	if results.is_empty():
		lines.append(["narrator", "Nothing at the lab. Nothing was sent."])
	_talk = NarrationTalk.new(_box, lines)
	_talk.finished.connect(_end_talk)
	GameState.flags["_talking"] = true
	_talk.start()


func _fade_out() -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.25)
	await t.finished


func _fade_in() -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, 0.3)
	await t.finished


func _speaker_name(id: String) -> String:
	if id == "narrator":
		return ""
	if id == "player":
		return "You"
	if GameData.roster.has(id):
		return GameData.roster[id].name
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.has_method("face") and n.npc_id == id:
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
	_hud.position = Vector2(8, 6)
	_hud.add_theme_font_size_override("font_size", 11)
	_hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_hud.add_theme_constant_override("shadow_offset_x", 1)
	_hud.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(_hud)
	var help := Label.new()
	help.text = "WASD walk · Space talk/look · Tab case file · T day/night · F5 save · F9 load"
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	help.offset_left = -420
	help.offset_top = -16
	help.offset_right = -6
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.add_theme_font_size_override("font_size", 9)
	help.modulate.a = 0.75
	root.add_child(help)
	_prompt = Label.new()
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.offset_top = -70
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 12)
	_prompt.add_theme_color_override("font_color", Color("e8a64a"))
	_prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("shadow_offset_x", 1)
	_prompt.add_theme_constant_override("shadow_offset_y", 1)
	_prompt.visible = false
	root.add_child(_prompt)
	_box = DialogueBox.new(_speaker_name)
	root.add_child(_box)
	_file = EvidencePanel.new()
	root.add_child(_file)
	_toast_label = Label.new()
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_left = -300
	_toast_label.offset_right = 300
	_toast_label.offset_top = 22
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 12)
	_toast_label.add_theme_color_override("font_color", Color("e8a64a"))
	_toast_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_toast_label.add_theme_constant_override("shadow_offset_x", 1)
	_toast_label.add_theme_constant_override("shadow_offset_y", 1)
	_toast_label.visible = false
	root.add_child(_toast_label)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	_hud_tick()


func _hud_tick() -> void:
	var hour := int(fmod(time_of_day * 24.0 + 6.0, 24.0))
	var ampm := "AM" if hour < 12 else "PM"
	var h12 := hour % 12
	if h12 == 0:
		h12 = 12
	var where: String = map.get("name", "")
	if inside != "":
		for d in outside.doors:
			if d.id == inside:
				where = d.name
	_hud.text = "Point Pleasant · %s   Day %d   %d:00 %s (%s)   Dread %d   Evidence %d" % [where, GameState.day, h12, ampm, Investigation.phase(time_of_day), GameState.dread, GameState.evidence.size()]
	if _talk == null:
		_apply_phase()
	get_tree().create_timer(0.5).timeout.connect(_hud_tick)


func _toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.visible = true
	_toast_until = Time.get_ticks_msec() / 1000.0 + 2.5


# ---------- saves ----------

func _save() -> void:
	GameState.flags["town_time"] = time_of_day
	GameState.flags["town_pos"] = [party[0].global_position.x, party[0].global_position.y]
	GameState.flags["town_pos_map"] = map_id
	GameState.flags["town_inside"] = inside
	GameState.flags.erase("_talking")
	_toast("Saved" if GameState.save_game() else "Save failed")


func _load() -> void:
	if GameState.load_game():
		get_tree().reload_current_scene()
	else:
		_toast("No save yet")
