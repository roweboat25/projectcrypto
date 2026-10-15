extends Node2D
## The drive between the Office and a case: a node map of stops, each with a
## choice of road, an event card, a radio scan and the chance to spend.
## GameState.flags.road_leg names the leg, road_stop the stop we are at.

const T := 32
const DRIVE_SECONDS := 2.6
const HIGHWAY_HOURS := 1
const BACK_HOURS := 2
const TANK := 6
const GAS_PRICE := 3   # dollars a unit, 1994

var leg_id := ""
var leg: Dictionary = {}
var stop := 0
var time_of_day := 0.2
var _mode := "intro"      # intro, menu, event, event_menu, result, drive, radio, arrive
var _event: Dictionary = {}
var _options: Array = []
var _road_kind := "highway"
var _speed := 0.0
var _world: Node2D
var _strips: Array = []
var _wagon: Node2D
var _modulate: CanvasModulate
var _box: DialogueBox
var _hud: Label
var _map_label: Label
var _toast_label: Label
var _toast_until := 0.0
var _radio: RadioDial
var _fade: ColorRect
var _snow: CPUParticles2D
var _drive_left := 0.0


func _ready() -> void:
	MapBuilder.load_indexes()
	leg_id = GameState.flags.get("road_leg", "")
	leg = GameData.road.get("legs", {}).get(leg_id, {})
	stop = int(GameState.flags.get("road_stop", 0))
	time_of_day = float(GameState.flags.get("town_time", 0.2))
	_modulate = CanvasModulate.new()
	add_child(_modulate)
	_build_world()
	_build_ui()
	_apply_time()
	if leg.is_empty():
		_mode = "arrive"
		_arrive()
		return
	_intro()


# ---------- the strip of road ----------

func _build_world() -> void:
	_world = Node2D.new()
	add_child(_world)
	var pattern := {"size": [20, 12], "ground": "snow",
		"fills": [{"rect": [0, 5, 20, 4], "tiles": "asphalt"}, {"rect": [0, 7, 20, 1], "tiles": "asphalt_line", "every": 2},
			{"rect": [0, 4, 20, 1], "tiles": "gravel"}, {"rect": [0, 9, 20, 1], "tiles": "gravel"}],
		"props": [{"kind": "pine_snow", "pos": [2, 3.6]}, {"kind": "tree_bare", "pos": [9, 3.2]}, {"kind": "pine_snow2", "pos": [15, 3.9]},
			{"kind": "fence_h", "pos": [5, 11.5]}, {"kind": "pine_snow", "pos": [12, 11.8]}, {"kind": "rock_cliff", "pos": [18, 11.4]}, {"kind": "mailbox", "pos": [7, 10.3]}]}
	for i in 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var strip := Node2D.new()
		strip.position = Vector2(i * 20 * T, 0)
		_world.add_child(strip)
		MapBuilder.build_district(strip, pattern, Vector2i.ZERO, rng)
		_strips.append(strip)
	_wagon = MapBuilder.prop(_world, "wagon", Vector2(10 * T, 7.6 * T))
	_wagon.z_index = 10
	var cam := Camera2D.new()
	cam.position = Vector2(10 * T, 5.6 * T)
	add_child(cam)
	_snow = CPUParticles2D.new()
	_snow.amount = 160
	_snow.lifetime = 6.0
	_snow.preprocess = 6.0
	_snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_snow.emission_rect_extents = Vector2(400, 20)
	_snow.direction = Vector2(-0.6, 1)
	_snow.spread = 10
	_snow.gravity = Vector2(0, 14)
	_snow.initial_velocity_min = 30
	_snow.initial_velocity_max = 50
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.95, 0.97, 1.0, 0.9))
	_snow.texture = ImageTexture.create_from_image(img)
	_snow.position = Vector2(10 * T, -40)
	_snow.z_index = 50
	add_child(_snow)


func _process(delta: float) -> void:
	_toast_label.visible = Time.get_ticks_msec() / 1000.0 < _toast_until
	if _mode == "drive":
		_speed = min(_speed + delta * 240.0, 170.0)
		_drive_left -= delta
		if _drive_left <= 0.0:
			_speed = 0.0
			_next_stop()
	else:
		_speed = max(_speed - delta * 300.0, 0.0)
	if _speed > 0.0:
		for s in _strips:
			s.position.x -= _speed * delta
			if s.position.x <= -20 * T:
				s.position.x += 60 * T
		_wagon.position.y = 7.6 * T + sin(Time.get_ticks_msec() / 60.0) * 0.6
	_refresh_hud()
	if _mode == "radio":
		if Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("interact"):
			_close_radio()
		return
	if _box.visible:
		if Input.is_action_just_pressed("move_up"):
			_box.move(-1)
		elif Input.is_action_just_pressed("move_down"):
			_box.move(1)
		elif Input.is_action_just_pressed("interact"):
			_box.confirm()
		elif Input.is_action_just_pressed("cancel"):
			_box.cancel()


func _apply_time() -> void:
	var daylight: float = clamp(cos((time_of_day - 0.25) * TAU) * 0.5 + 0.5, 0.0, 1.0)
	daylight = pow(daylight, 1.5)
	var tint: Color = Color("2c3454").lerp(Color("8a6a78"), clamp(daylight * 3.0, 0, 1)).lerp(Color("ffffff"), daylight)
	_modulate.color = tint


# ---------- the stops ----------

func _stop_data() -> Dictionary:
	var stops: Array = leg.get("stops", [])
	return stops[min(stop, stops.size() - 1)] if not stops.is_empty() else {}


func _intro() -> void:
	_mode = "intro"
	var st := _stop_data()
	var lines := [["narrator", "%s. %s" % [st.get("name", ""), st.get("text", "")]]]
	if st.has("sights"):
		lines.append(["narrator", st.sights])
	_box.show_lines(lines)


func _menu() -> void:
	_mode = "menu"
	var st := _stop_data()
	var last: bool = stop >= leg.get("stops", []).size() - 1
	var opts := [
		{"label": "%s: %s (%d hour%s)" % ["Into town" if last else "Highway", st.get("highway", "the highway"), HIGHWAY_HOURS, ""], "enabled": true},
		{"label": "Back road: %s (%d hours, slower, more happens)" % [st.get("back", "the back way"), BACK_HOURS], "enabled": true},
		{"label": "Scan the radio", "enabled": true},
		{"label": "Fill the tank ($%d)" % ((TANK - GameState.gas) * GAS_PRICE), "enabled": GameState.gas < TANK and GameState.cash >= GAS_PRICE},
		{"label": "Stop for the night (motel $18, or the back seat)", "enabled": true},
	]
	_options = opts
	_box.show_menu("Stop %d of %d · %s · gas %d/%d · $%d" % [stop + 1, leg.get("stops", []).size(), _clock(), GameState.gas, TANK, GameState.cash], leg.get("name", "The road"), opts)


func _on_option(i: int) -> void:
	match _mode:
		"menu":
			match i:
				0:
					_road_kind = "highway"
					_set_off()
				1:
					_road_kind = "back"
					_set_off()
				2:
					_open_radio()
				3:
					var units: int = TANK - GameState.gas
					var cost: int = min(units * GAS_PRICE, GameState.cash)
					GameState.gas += int(cost / GAS_PRICE)
					GameState.cash -= cost
					_toast("Filled up. $%d left." % GameState.cash)
					_menu()
				4:
					_rest()
		"event_menu":
			_pick_event_option(i)
		"rest":
			_rest_pick(i)


func _on_cancel() -> void:
	if _mode in ["event_menu"]:
		return
	if _mode == "rest":
		_menu()


func _on_lines_finished() -> void:
	match _mode:
		"intro":
			_menu()
		"event":
			_event_menu()
		"result":
			_drive()
		"arrive":
			_go_to_town()
		"station":
			_open_radio()
		"dry":
			_drive()


func _clock() -> String:
	var hour := int(fmod(time_of_day * 24.0 + 6.0, 24.0))
	var h12 := hour % 12
	if h12 == 0:
		h12 = 12
	return "%d %s, day %d" % [h12, "AM" if hour < 12 else "PM", GameState.day]


func _advance(hours: float) -> void:
	var before := time_of_day
	time_of_day += hours / 24.0
	while time_of_day >= 1.0:
		time_of_day -= 1.0
		GameState.day += 1
	_apply_time()


## Picks the road, draws the card for it, or just drives when nothing happens.
func _set_off() -> void:
	if GameState.gas <= 0:
		_mode = "dry"
		GameState.gas = 2
		GameState.cash = max(0, GameState.cash - 15)
		_advance(4)
		_box.show_lines([["narrator", "The needle has been on E for a while and now the engine agrees. Four hours, a farmer with a gas can, and fifteen dollars later you are moving again."]])
		return
	var ev := _draw_event()
	if ev.is_empty():
		_drive()
		return
	_event = ev
	_mode = "event"
	_box.show_lines([["narrator", ev.get("title", "") + ". " + ev.get("text", "")]])


func _draw_event() -> Dictionary:
	var st := _stop_data()
	var seen: Array = GameState.flags.get("road_seen", [])
	var phase := Investigation.phase(time_of_day)
	var pools := [st.get("events", []), leg.get("deck", [])]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for pool in pools:
		var ok := []
		for id in pool:
			var ev: Dictionary = GameData.road.get("events", {}).get(id, {})
			if ev.is_empty() or id in seen:
				continue
			if ev.has("when") and not phase in ev.when:
				continue
			if ev.has("roads") and not _road_kind in ev.roads:
				continue
			if not _requires_ok(ev.get("requires", {})):
				continue
			ok.append(id)
		# the highway is quiet: a card only half the time
		if not ok.is_empty() and (_road_kind == "back" or rng.randf() < 0.5):
			var id: String = ok[rng.randi_range(0, ok.size() - 1)]
			seen.append(id)
			GameState.flags["road_seen"] = seen
			var ev: Dictionary = GameData.road.events[id].duplicate()
			ev["id"] = id
			return ev
	return {}


func _requires_ok(req: Dictionary) -> bool:
	for f in req.get("flag", []):
		if not GameState.flags.get(f, false):
			return false
	for f in req.get("not_flag", []):
		if GameState.flags.get(f, false):
			return false
	for it in req.get("item", []):
		if not GameState.has_item(it):
			return false
	return true


func _event_menu() -> void:
	_mode = "event_menu"
	_options = []
	var opts := []
	for o in _event.get("options", []):
		var label: String = o.get("text", "...")
		if o.has("check"):
			label = "[%s %d] %s" % [Investigation.VOICE_NAMES.get(o.check.voice, o.check.voice).capitalize(), Investigation.voice_level(GameData, GameState, o.check.voice), label]
		var req := _requires_ok(o.get("requires", {}))
		opts.append({"label": label + ("" if req else "  (needs %s)" % _requires_text(o.requires)), "enabled": req})
		_options.append(o)
	_box.show_menu(_event.get("title", ""), "The road", opts)


func _requires_text(req: Dictionary) -> String:
	var parts := []
	for f in req.get("flag", []):
		parts.append(_flag_name(f))
	for it in req.get("item", []):
		parts.append(GameData.items.get(it, {}).get("name", it).to_lower())
	return ", ".join(parts)


func _flag_name(flag: String) -> String:
	for table in ["car", "upgrades"]:
		for id in GameData.office.get(table, {}):
			if GameData.office[table][id].get("flag", "") == flag:
				return GameData.office[table][id].get("name", id).to_lower()
	return flag.replace("_", " ")


func _pick_event_option(i: int) -> void:
	var o: Dictionary = _options[i]
	var line: String = o.get("line", "")
	var gives: Dictionary = o.get("gives", {})
	if o.has("check"):
		var level := Investigation.voice_level(GameData, GameState, o.check.voice)
		var roll := randi_range(1, 6) + randi_range(1, 6)
		var total := roll + level
		var ok: bool = total >= int(o.check.get("difficulty", 8))
		_toast("[%s] %s: %d vs %d" % [Investigation.VOICE_NAMES.get(o.check.voice, o.check.voice).capitalize(), "passed" if ok else "failed", total, int(o.check.get("difficulty", 8))])
		if not ok:
			line = o.get("fail", {}).get("line", line)
			gives = o.get("fail", {}).get("gives", {})
	_apply(gives)
	_mode = "result"
	if line == "":
		_drive()
	else:
		_box.show_lines([["narrator", line]])


func _apply(gives: Dictionary) -> void:
	var got: Array = Investigation.apply_gives(GameData, GameState, gives)
	for e in got:
		_toast("New evidence: " + Investigation.case_data(GameData, GameState).get("evidence", {}).get(e, {}).get("title", e))
	if gives.has("hours"):
		_advance(float(gives.hours))
	if gives.has("item"):
		_toast("Got " + GameData.items.get(gives.item, {}).get("name", gives.item))


func _drive() -> void:
	_box.close()
	_mode = "drive"
	_drive_left = DRIVE_SECONDS
	GameState.gas = max(0, GameState.gas - 1)
	_advance(HIGHWAY_HOURS if _road_kind == "highway" else BACK_HOURS)


func _next_stop() -> void:
	stop += 1
	GameState.flags["road_stop"] = stop
	GameState.flags["town_time"] = time_of_day
	if stop >= leg.get("stops", []).size():
		_arrive()
	else:
		_intro()


# ---------- rest ----------

func _rest() -> void:
	_mode = "rest"
	var mattress: bool = GameState.flags.get("car_mattress", false)
	_options = []
	_box.show_menu("Where?", "The road", [
		{"label": "A motel ($18): sleep until morning, Composure back to full", "enabled": GameState.cash >= 18},
		{"label": "The back seat: free, cold, Composure %s" % ("back to full (the mattress)" if mattress else "+30 and a stiff neck"), "enabled": true},
		{"label": "Keep driving", "enabled": true},
	])


func _rest_pick(i: int) -> void:
	if i == 2:
		_menu()
		return
	var results: Array = Investigation.sleep(GameData, GameState)
	time_of_day = 0.05
	_apply_time()
	if i == 0:
		GameState.cash -= 18
		GameState.composure = Investigation.max_composure(GameData, GameState)
	elif GameState.flags.get("car_mattress", false):
		GameState.composure = Investigation.max_composure(GameData, GameState)
	else:
		GameState.composure = min(Investigation.max_composure(GameData, GameState), GameState.composure + 30)
	_toast("Morning. Day %d." % GameState.day)
	_menu()


# ---------- radio ----------

func _open_radio() -> void:
	_mode = "radio"
	_box.close()
	var phase := Investigation.phase(time_of_day)
	_radio.stations = []
	for sid in leg.get("stations", []):
		var st: Dictionary = GameData.road.get("stations", {}).get(sid, {})
		if st.has("when") and not phase in st.when:
			continue
		_radio.stations.append({"id": sid, "band": st.get("band", "fm"), "freq": float(st.get("freq", 100)), "name": st.get("name", sid)})
	_radio.heard = GameState.flags.get("road_heard", [])
	_radio.visible = true


func _close_radio() -> void:
	_radio.visible = false
	_menu()


func _on_station(sid: String) -> void:
	var st: Dictionary = GameData.road.get("stations", {}).get(sid, {})
	var heard: Array = GameState.flags.get("road_heard", [])
	if sid in heard:
		_toast("%s, again." % st.get("name", sid))
		return
	heard.append(sid)
	GameState.flags["road_heard"] = heard
	if not sid in GameState.radio_log:
		GameState.radio_log.append(sid)
	_radio.heard = heard
	_apply(st.get("gives", {}))
	_radio.visible = false
	_mode = "station"
	_box.show_lines([["narrator", "%s, %s %s. %s" % [st.get("name", sid), str(st.get("freq", "")), str(st.get("band", "")).to_upper(), st.get("text", "")]]])


# ---------- arrival ----------

func _arrive() -> void:
	_mode = "arrive"
	var to: String = leg.get("to", "sutton")
	var lines := []
	if to != "sutton" and GameData.cases.has(to):
		GameState.case_id = to
		var phase := Investigation.phase(time_of_day)
		if phase == "night":
			GameState.dread += 1
			lines.append(["narrator", "You come into %s after dark. The town is shut and the river is loud. Dread rises." % GameData.cases[to].get("name", to)])
		else:
			lines.append(["narrator", "You come into %s at %s." % [GameData.cases[to].get("name", to), _clock()]])
	else:
		lines.append(["narrator", "Sutton. The Office is dark but the porch light is on, which means Dot left it on for you."])
	_box.show_lines(lines)


func _go_to_town() -> void:
	var at: Array = leg.get("arrive_at", [2, 2])
	var map_id: String = leg.get("arrive_map", "sutton_office")
	GameState.flags["town_map"] = map_id
	GameState.flags["town_pos_map"] = map_id
	GameState.flags["town_pos"] = [float(at[0]) * T, float(at[1]) * T]
	GameState.flags["town_time"] = time_of_day
	GameState.flags.erase("road_leg")
	GameState.flags.erase("road_stop")
	GameState.flags.erase("road_seen")
	GameState.flags.erase("road_heard")
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.3)
	await t.finished
	get_tree().change_scene_to_file("res://scenes/town.tscn")


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
	_map_label = Label.new()
	_map_label.position = Vector2(8, 22)
	_map_label.add_theme_font_size_override("font_size", 10)
	_map_label.add_theme_color_override("font_color", Color("9ab0c8"))
	_map_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	root.add_child(_map_label)
	_box = DialogueBox.new(_speaker_name)
	root.add_child(_box)
	_box.option_picked.connect(_on_option)
	_box.cancelled.connect(_on_cancel)
	_box.lines_finished.connect(_on_lines_finished)
	_radio = RadioDial.new()
	_radio.visible = false
	_radio.locked.connect(_on_station)
	root.add_child(_radio)
	_toast_label = Label.new()
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_left = -300
	_toast_label.offset_right = 300
	_toast_label.offset_top = 38
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


func _refresh_hud() -> void:
	_hud.text = "%s   %s   Gas %d/%d   $%d   Composure %d   Dread %d" % [leg.get("name", "The road"), _clock(), GameState.gas, TANK, GameState.cash, GameState.composure, GameState.dread]
	var names := []
	var stops: Array = leg.get("stops", [])
	for i in stops.size():
		names.append(("[%s]" if i == stop else "%s") % stops[i].get("name", ""))
	_map_label.text = " · ".join(names)


func _toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.visible = true
	_toast_until = Time.get_ticks_msec() / 1000.0 + 3.0


func _speaker_name(id: String) -> String:
	if id == "narrator":
		return ""
	if id == "player":
		return "You"
	return GameData.roster.get(id, {}).get("name", id.capitalize())
