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
var time_of_day := 0.10          # 0..1, 0.25 = noon, 0.75 = midnight; a new hire arrives in the morning
var inside := ""                 # room id when indoors
var _modulate: CanvasModulate
var _torch: PointLight2D
var _snow: CPUParticles2D
var _weather := "snow"
var _entered_via := ""           # the room whose door the party came in by, for rooms reached from other rooms
var _prompt: Label
var _toast_label: Label
var _hud: Label
var _strip: PartyStrip = null
var _minimap: Minimap = null
var _fade: ColorRect
var _box: DialogueBox
var _file: EvidencePanel
var _talk: RefCounted = null     # the running conversation or inspection
var _battle: Battle = null       # the fight drawn over the town, if one is on
var _ui_root: Control
var _walk_t := 0.0               # seconds walked outdoors since the last encounter roll
var _grace := 0.0                # seconds of peace after a fight
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
	_apply_weather()
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
			var case_of: String = str(GameData.maps[kv[1]].get("case", ""))
			if GameData.cases.has(case_of) and case_of != "sutton":
				GameState.case_id = case_of
			_travel({"to": kv[1], "at": GameData.maps[kv[1]].get("spawn", [2, 2])}, false)
		elif kv[0] == "inside" and rooms.has(kv[1]):
			_enter(kv[1], false)
		elif kv[0] == "at":
			var xy := kv[1].split(",")
			if xy.size() == 2:
				var at := Vector2(float(xy[0]), float(xy[1])) * T
				if inside != "":
					_move_party(rooms[inside].rect.position + Vector2(T, T) + at, rooms[inside].actors)
				else:
					_move_party(at, outside.actors)
		elif kv[0] == "time":
			time_of_day = float(kv[1])
		elif kv[0] == "day":
			GameState.day = int(kv[1])
		elif kv[0] == "flag":
			for f in kv[1].split(","):
				GameState.flags[f] = true
		elif kv[0] == "road" and GameData.road.get("legs", {}).has(kv[1]):
			_drive.call_deferred(kv[1])
		elif kv[0] == "fight":
			_start_fight.call_deferred({"foes": Array(kv[1].split(",")), "intro": "A test of nerve."}, "", null)


func _process(delta: float) -> void:
	if _talk == null and _battle == null:
		time_of_day = fmod(time_of_day + delta / CYCLE_SECONDS, 1.0)
	_apply_time()
	_toast_label.visible = Time.get_ticks_msec() / 1000.0 < _toast_until
	_snow.position = party[0].global_position + (Vector2(0, -30) if _weather == "mist" else Vector2(0, -230))
	_snow.emitting = inside == "" and _weather != "clear"
	if _battle != null:
		return
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
		if Input.is_action_just_pressed("gear"):
			_start_talk(GearTalk.new(_box, _toast))
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
			_roll_encounter(delta)


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
	_refresh_minimap()
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
	_snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_snow.z_index = 50
	add_child(_snow)


## The map's `weather`: snow (Point Pleasant), clear, mist, rain or a gale.
func _apply_weather() -> void:
	_weather = map.get("weather", "snow")
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0.9))
	_snow.amount = 220
	_snow.lifetime = 7.0
	_snow.emission_rect_extents = Vector2(400, 20)
	_snow.direction = Vector2(0.15, 1)
	_snow.spread = 12
	_snow.gravity = Vector2(0, 14)
	_snow.initial_velocity_min = 24
	_snow.initial_velocity_max = 44
	_snow.scale_amount_min = 1.0
	_snow.scale_amount_max = 2.0
	_snow.color = Color.WHITE
	match _weather:
		"rain", "gale":
			img = Image.create(1, 4, false, Image.FORMAT_RGBA8)
			img.fill(Color(0.75, 0.85, 1.0, 0.7))
			_snow.amount = 320 if _weather == "rain" else 520
			_snow.lifetime = 2.5
			_snow.direction = Vector2(0.3, 1) if _weather == "rain" else Vector2(0.9, 1)
			_snow.spread = 4
			_snow.gravity = Vector2(0, 60)
			_snow.initial_velocity_min = 160
			_snow.initial_velocity_max = 220
			_snow.scale_amount_max = 1.0
		"mist":
			img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
			img.fill(Color(0.9, 0.93, 0.96, 0.10))
			_snow.amount = 60
			_snow.lifetime = 14.0
			_snow.emission_rect_extents = Vector2(420, 220)
			_snow.direction = Vector2(1, 0)
			_snow.spread = 20
			_snow.gravity = Vector2.ZERO
			_snow.initial_velocity_min = 4
			_snow.initial_velocity_max = 10
			_snow.scale_amount_min = 6.0
			_snow.scale_amount_max = 14.0
	_snow.preprocess = _snow.lifetime
	_snow.texture = ImageTexture.create_from_image(img)
	_snow.restart()


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
	for a in outside.appears:
		var open: bool = Investigation.gate_open(GameData, GameState, a.gate, time_of_day)
		a.node.visible = open
		a.node.process_mode = Node.PROCESS_MODE_INHERIT if open else Node.PROCESS_MODE_DISABLED
		for child in a.node.get_children():
			if child.has_meta("hotspot"):
				child.set_meta("hidden", not open)
	for d in outside.doors:
		if d.get("appears", "") != "":
			d["hidden"] = not Investigation.gate_open(GameData, GameState, d.appears, time_of_day)
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.has_meta("when"):
			var when: Array = n.get_meta("when")
			var here: bool = when.is_empty() or ph in when
			if here and n.has_meta("appears"):
				here = Investigation.gate_open(GameData, GameState, n.get_meta("appears"), time_of_day)
			n.set_present(here)
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
		if door.get("hidden", false):
			continue
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
			if _near.data.has("fight"):
				_start_fight(_near.data.fight, "", _near)
				return
			if _near.data.has("shop"):
				_talk = ShopTalk.new(_box, _near.data.shop, _near.display_name, _toast, _near.npc_id)
				_talk.can_talk = Investigation.case_data(GameData, GameState).get("witnesses", {}).has(_near.npc_id) or not Investigation.script_for(GameData, GameState, _near.npc_id).is_empty()
			elif Investigation.script_for(GameData, GameState, _near.npc_id).is_empty():
				_talk = WitnessTalk.new(_box, _near.npc_id, _near.display_name, _toast)
			else:
				_talk = ScriptTalk.new(_box, _near.npc_id, _near.display_name, _toast)
		_start_talk(_talk)
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


func _start_talk(talk) -> void:
	_talk = talk
	_talk.finished.connect(_end_talk)
	GameState.flags["_talking"] = true
	_prompt.visible = false
	_talk.start()


## The card catalog: verdict history and the evidence archive.
func _catalog_lines() -> Array:
	var lines := [["narrator", "Oak drawers, index cards in Gus Weller's hand and everyone's since. Drawer S has a lock on it."]]
	if GameState.verdicts.is_empty():
		lines.append(["narrator", "Nothing has been filed since you took the job."])
	for cid in GameState.verdicts:
		var v: Dictionary = GameState.verdicts[cid]
		lines.append(["narrator", "%s: filed %s, rated %s, day %d." % [GameData.cases.get(cid, {}).get("name", cid), str(v.lean).capitalize(), v.rating, int(v.day)]])
	lines.append(["narrator", "%d cards in the %s file. Budget tier %d." % [GameState.evidence.size(), Investigation.case_data(GameData, GameState).get("name", "open"), Investigation.budget_tier(GameData, GameState)]])
	return lines


## The radio shack's station log.
func _radio_log_lines() -> Array:
	if GameState.radio_log.is_empty():
		return [["narrator", "A ledger of frequencies, the last entry in 1967. Nothing logged on this trip yet."]]
	var lines := []
	for sid in GameState.radio_log:
		var st: Dictionary = GameData.road.get("stations", {}).get(sid, {})
		lines.append(["narrator", "%s %s: %s" % [str(st.get("freq", "")), st.get("name", sid), st.get("text", "")]])
	return lines


## Gets in the station wagon: saves where we are and hands over to the road.
func _drive(leg_id: String) -> void:
	var leg: Dictionary = GameData.road.get("legs", {}).get(leg_id, {})
	if leg.is_empty():
		return
	GameState.flags["road_leg"] = leg_id
	GameState.flags["road_stop"] = 0
	GameState.flags["town_time"] = time_of_day
	GameState.flags.erase("town_pos")
	GameState.flags.erase("town_inside")
	_prompt.visible = false
	await _fade_out()
	get_tree().change_scene_to_file("res://scenes/road.tscn")


func _door_open(door: Dictionary) -> bool:
	return door.get("gate", "") == "" or Investigation.gate_open(GameData, GameState, door.gate, time_of_day)


## A shut gate: roll its check if it offers one today, else say why it is shut.
func _try_gate(gate_id: String) -> bool:
	var g: Dictionary = GameData.gate(gate_id)
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
	if p.has("fight"):
		_start_fight(p.fight, spot.key, spot.get_meta("node"))
		return
	if p.has("gate"):
		if Investigation.gate_open(GameData, GameState, p.gate, time_of_day) or _try_gate(p.gate):
			GameState.picked.append(spot.key)
			spot.get_meta("node").queue_free()
			_near = null
		return
	if p.has("use"):
		match p.use:
			"board":
				_start_talk(BoardTalk.new(_box, _toast))
			"ledger":
				_start_talk(LedgerTalk.new(_box, _toast))
			"shop":
				_start_talk(ShopTalk.new(_box, p.get("shop", ""), p.get("name", "Counter"), _toast))
			"catalog":
				_start_talk(NarrationTalk.new(_box, _catalog_lines()))
			"radio_log":
				_start_talk(NarrationTalk.new(_box, _radio_log_lines()))
			"dials":
				_start_talk(DialTalk.new(_box, p.get("name", "The dials"), p.get("puzzle", {}), _toast))
			"siege":
				_run_siege()
		return
	if p.has("enter"):
		if rooms.has(p.enter):
			_prompt.visible = false
			_enter(p.enter, true)
		return
	if p.has("travel"):
		if p.travel is Array:
			var t := TravelTalk.new(_box, p.travel, _toast)
			t.chosen.connect(_drive)
			_start_talk(t)
		else:
			_drive(p.travel)
		return
	if p.has("pickup"):
		var name: String = GameData.items.get(p.pickup, {}).get("name", p.pickup)
		if p.has("price"):
			if GameState.cash < int(p.price):
				_toast("Not enough cash for the %s." % name.to_lower())
				return
			GameState.cash -= int(p.price)
			_toast("Bought %s. $%d left." % [name, GameState.cash])
		else:
			_toast("Took " + name)
		GameState.add_item(p.pickup)
		GameState.picked.append(spot.key + (":%d" % GameState.day if p.get("restock", false) else ""))
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


# ---------- fights ----------

## Starts a fight over the town. `key` is the prop's picked key (gone for good once won),
## `node` the prop or person to remove on a win.
func _start_fight(fight: Dictionary, key: String, node: Node) -> void:
	if _battle != null:
		return
	var spec: Dictionary = fight.duplicate(true)
	spec["field"] = {"phase": Investigation.phase(time_of_day), "weather": _weather, "inside": inside != ""}
	_prompt.visible = false
	GameState.flags["_talking"] = true
	_battle = Battle.new(spec)
	_ui_root.add_child(_battle)
	_battle.finished.connect(func(r: Dictionary) -> void: _end_fight(r, fight, key, node))


func _end_fight(r: Dictionary, fight: Dictionary, key: String, node: Node) -> void:
	_battle.queue_free()
	_battle = null
	GameState.flags["_talking"] = false
	_grace = 20.0
	_walk_t = 0.0
	if r.outcome in ["won", "lasted"]:
		if fight.has("flag"):
			GameState.flags[fight.flag] = true
		if key != "":
			GameState.picked.append(key)
		if node != null and not fight.get("stays", false):
			node.queue_free()
			_near = null
		_apply_phase()
	elif r.outcome == "lost" and fight.has("lose_flag"):
		GameState.flags[fight.lose_flag] = true


## The case's siege, from dusk to dawn, then the morning after.
func _run_siege() -> void:
	var spec: Dictionary = Investigation.case_data(GameData, GameState).get("siege", {})
	if spec.is_empty() or _battle != null or _talk != null:
		return
	_prompt.visible = false
	GameState.flags["_talking"] = true
	var siege := Siege.new(spec)
	await siege.run(self, GameData, GameState)
	GameState.flags["_talking"] = false
	if GameState.flags.get(spec.get("flag", "siege_survived"), false) or GameState.flags.get(spec.get("lose_flag", "siege_broken"), false):
		await _fade_out()
		Investigation.sleep(GameData, GameState)
		time_of_day = 0.03
		_apply_time()
		_apply_phase()
		await _fade_in()


## Lines in the dialogue box, awaited. For the siege and anything else scripted.
func narrate(lines: Array) -> void:
	if lines.is_empty():
		return
	var talk := NarrationTalk.new(_box, lines)
	_talk = talk
	talk.start()
	await talk.finished
	_talk = null


## A question in the dialogue box, awaited: the option index, or -1.
func ask(title: String, options: Array) -> int:
	var talk := ChoiceTalk.new(_box, title, options, _toast)
	talk.can_cancel = false
	_talk = talk
	talk.start()
	var i: int = await talk.chosen
	_talk = null
	return i


## A fight, awaited: the BattleRules result.
func fight(spec: Dictionary) -> Dictionary:
	var full: Dictionary = spec.duplicate(true)
	full["field"] = {"phase": Investigation.phase(time_of_day), "weather": _weather, "inside": inside != ""}
	_battle = Battle.new(full)
	_ui_root.add_child(_battle)
	var r: Dictionary = await _battle.finished
	_battle.queue_free()
	_battle = null
	_grace = 20.0
	return r


## Walking outdoors at the wrong hour: the map's `encounters` list, rolled once a second.
func _roll_encounter(delta: float) -> void:
	if _grace > 0.0:
		_grace -= delta
		return
	var list: Array = map.get("encounters", [])
	if list.is_empty() or party[0].velocity.length() < 1.0:
		return
	_walk_t += delta
	if _walk_t < 1.0:
		return
	_walk_t = 0.0
	var ph := Investigation.phase(time_of_day)
	var pool := []
	var total := 0.0
	for e in list:
		if e.get("phase", []).is_empty() or ph in e.phase:
			pool.append(e)
			total += float(e.get("weight", 1))
	if pool.is_empty() or randf() > float(map.get("encounter_rate", 0.04)):
		return
	var pick := randf() * total
	for e in pool:
		pick -= float(e.get("weight", 1))
		if pick <= 0.0:
			_start_fight({"foes": e.foes, "intro": e.get("intro", "Something comes out of the dark."), "win": e.get("win", "It is over. The night goes on.")}, "", null)
			return


func _use_exit(e: Dictionary) -> void:
	if e.get("gate", "") != "" and not Investigation.gate_open(GameData, GameState, e.gate, time_of_day):
		# step back off the exit, toward the middle of the map, and explain
		var back: Vector2 = (outside.rect.get_center() - e.rect.get_center()).normalized()
		if e.rect.size.x <= e.rect.size.y:
			back = Vector2(sign(back.x), 0)
		else:
			back = Vector2(0, sign(back.y))
		party[0].global_position += back * 12
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
	_apply_weather()
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
	var again: bool = _talk is ShopTalk and _talk.wants_talk and _near != null and not _near.has_meta("hotspot")
	_talk = null
	GameState.flags["_talking"] = false
	if again:
		if Investigation.script_for(GameData, GameState, _near.npc_id).is_empty():
			_start_talk(WitnessTalk.new(_box, _near.npc_id, _near.display_name, _toast))
		else:
			_start_talk(ScriptTalk.new(_box, _near.npc_id, _near.display_name, _toast))


func _enter(id: String, with_fade: bool) -> void:
	var room: Dictionary = rooms[id]
	if with_fade:
		await _fade_out()
	if inside == "":
		_entered_via = id
	inside = id
	_move_party(room.entry, room.actors)
	_set_camera_limits(room.rect)
	_apply_time()
	if with_fade:
		await _fade_in()


func _leave() -> void:
	var door: Dictionary = {}
	for d in outside.doors:
		if d.id == inside or (door.is_empty() and d.id == _entered_via):
			door = d
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
	_ui_root = root
	_hud = Label.new()
	_hud.position = Vector2(8, 6)
	_hud.add_theme_font_size_override("font_size", 11)
	_hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_hud.add_theme_constant_override("shadow_offset_x", 1)
	_hud.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(_hud)
	_strip = PartyStrip.new()
	root.add_child(_strip)
	_strip.build(GameState.party)
	_minimap = Minimap.new()
	root.add_child(_minimap)
	_refresh_minimap()
	var help := Label.new()
	help.text = "WASD walk · Space talk/look · Tab case file · G gear · T day/night · H timed hits · F5 save · F9 load"
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
	var tide := Investigation.tide_state(GameData, GameState, time_of_day)
	var tide_text := ""
	if tide != "":
		tide_text = "   Tide %s%s" % [tide, "" if tide == "low" else " (low in %dh)" % ceil(Investigation.hours_to_low(GameData, GameState, time_of_day))]
	_hud.text = "%s · %s   Day %d   %d:00 %s (%s)%s   Dread %d   Evidence %d" % [GameData.cases.get(map.get("case", ""), {}).get("name", "The Casebook"), where, GameState.day, h12, ampm, Investigation.phase(time_of_day), tide_text, GameState.dread, GameState.evidence.size()]
	if _talk == null:
		_apply_phase()
	if _strip != null:
		_strip.refresh()
	get_tree().create_timer(0.5).timeout.connect(_hud_tick)


## Redraws the corner map for wherever the party is now: the district, or the room.
func _refresh_minimap() -> void:
	if _minimap == null or party.is_empty():
		return
	if inside != "":
		var room: Dictionary = rooms[inside]
		_minimap.build(_world.get_node_or_null("Ground_" + inside), _world.get_node_or_null("Walls_" + inside), room.rect, room.actors, [], [], room.npcs, party[0])
	else:
		_minimap.build(_world.get_node_or_null("Ground"), _world.get_node_or_null("Walls"), outside.rect, outside.actors, outside.exits, outside.doors, outside.npcs, party[0])


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
