class_name Battle
extends Control
## A fight, drawn over the town: the party seen from behind, the foes facing
## them, the turn order across the top, the shared Evidence meter, and the
## dialogue box for commands and what happened. The rules live in BattleRules;
## this scene only asks, draws, and waits for Space at the timed moments.
##
## spec: {foes: [ids], intro: "..." | [[speaker, text]], win: "...", lose: "...",
##        no_flee: bool, field: {phase, weather, inside}}

signal finished(result: Dictionary)
signal _choice(index: int)

const FOE_DIR := "res://assets/foes/"
const TIMED_WINDOW := 0.22
const BACKDROPS := {
	"night": ["0a0e1c", "141a2e"], "dusk": ["2a1a30", "4a2a3a"], "morning": ["3a4a5a", "6a7a8a"],
	"day": ["4a5a4a", "7a8a6a"], "inside": ["1a1410", "2e2418"],
}

var spec: Dictionary
var b: Dictionary                      # the BattleRules state
var _box: DialogueBox
var _root: Control
var _stage: Node2D
var _sprites: Dictionary = {}          # actor key -> Node2D
var _bars: Dictionary = {}             # actor key -> {name, comp, focus}
var _turn_row: Label
var _meter: Label
var _field_label: Label
var _mark: Label                       # the timed-hit "!"
var _timing := false
var _timed_hit := false
var _foe_index: Dictionary = {}
var _running := false


func _init(p_spec: Dictionary) -> void:
	spec = p_spec
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var field: Dictionary = spec.get("field", {})
	field["no_flee"] = spec.get("no_flee", false)
	b = BattleRules.setup(GameData, GameState, spec.get("foes", []), field)
	var handicap := float(spec.get("handicap", 1.0))
	if handicap < 1.0:
		for a in b.actors:
			if a.side == "foe":
				a.composure = max(1, int(a.composure * handicap))
	_foe_index = {}
	if FileAccess.file_exists(FOE_DIR + "foes.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FOE_DIR + "foes.json"))
		if typeof(parsed) == TYPE_DICTIONARY:
			_foe_index = parsed
	_build()
	_running = true
	_run.call_deferred()


func _build() -> void:
	var field: Dictionary = b.field
	var key: String = "inside" if field.get("inside", false) else field.get("phase", "night")
	var cols: Array = BACKDROPS.get(key, BACKDROPS.night)
	var back := ColorRect.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.color = Color(cols[0])
	add_child(back)
	var ground := ColorRect.new()
	ground.color = Color(cols[1])
	ground.position = Vector2(0, 200)
	ground.size = Vector2(640, 60)
	add_child(ground)
	var horizon := ColorRect.new()
	horizon.color = Color(cols[1]).lightened(0.15)
	horizon.position = Vector2(0, 198)
	horizon.size = Vector2(640, 2)
	add_child(horizon)
	_stage = Node2D.new()
	add_child(_stage)
	if field.get("weather", "") in ["rain", "gale", "snow", "mist"] and not field.get("inside", false):
		var p := CPUParticles2D.new()
		p.amount = 160 if field.weather != "mist" else 40
		p.lifetime = 2.0
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(340, 10)
		p.position = Vector2(320, -10)
		p.direction = Vector2(0.2 if field.weather != "gale" else 0.8, 1)
		p.gravity = Vector2(0, 220 if field.weather == "rain" else 40)
		p.initial_velocity_min = 40
		p.initial_velocity_max = 120
		p.scale_amount_min = 1.0
		p.scale_amount_max = 1.5 if field.weather != "mist" else 6.0
		p.color = Color(0.7, 0.8, 1.0, 0.5) if field.weather != "mist" else Color(0.8, 0.8, 0.85, 0.12)
		_stage.add_child(p)
	# foes, right half
	var foes := BattleRules.alive(b, "foe")
	var spread: float = min(110.0, 280.0 / float(max(1, foes.size())))
	var x0: float = 470.0 - spread * float(foes.size() - 1) / 2.0
	var i := 0
	for f in foes:
		var node := _foe_node(f)
		node.position = Vector2(x0 + spread * i, 210)
		_stage.add_child(node)
		_sprites[f.key] = node
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", Color("f0e6d2"))
		_shadow(lbl)
		lbl.position = Vector2(node.position.x - 50, 52)
		lbl.size = Vector2(100, 20)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(lbl)
		_bars[f.key] = {"name": lbl}
		i += 1
	# party, left half, seen from behind
	var party := BattleRules.alive(b, "party")
	i = 0
	for m in party:
		var node := Node2D.new()
		var sh := Sprite2D.new()
		sh.texture = load("res://assets/sprites/shadow.png")
		sh.scale = Vector2(2, 2)
		sh.position = Vector2(0, -4)
		node.add_child(sh)
		var sp := Sprite2D.new()
		var path := "res://assets/sprites/%s.png" % m.id
		sp.texture = load(path if ResourceLoader.exists(path) else "res://assets/sprites/player.png")
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.hframes = 9
		sp.vframes = 4
		sp.frame = 3 * 9
		sp.scale = Vector2(2, 2)
		sp.position = Vector2(0, -58)
		node.add_child(sp)
		node.position = Vector2(90 + 70 * i, 236)
		_stage.add_child(node)
		_sprites[m.key] = node
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", Color("e8a64a"))
		_shadow(lbl)
		lbl.position = Vector2(node.position.x - 40, 72)
		lbl.size = Vector2(80, 36)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(lbl)
		_bars[m.key] = {"name": lbl}
		i += 1
	_turn_row = Label.new()
	_turn_row.position = Vector2(8, 6)
	_turn_row.size = Vector2(420, 14)
	_turn_row.add_theme_font_size_override("font_size", 10)
	_turn_row.add_theme_color_override("font_color", Color("f0e6d2"))
	_shadow(_turn_row)
	add_child(_turn_row)
	_meter = Label.new()
	_meter.position = Vector2(400, 6)
	_meter.size = Vector2(232, 14)
	_meter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_meter.add_theme_font_size_override("font_size", 10)
	_meter.add_theme_color_override("font_color", Color("e8a64a"))
	_shadow(_meter)
	add_child(_meter)
	_field_label = Label.new()
	_field_label.position = Vector2(8, 20)
	_field_label.add_theme_font_size_override("font_size", 9)
	_field_label.modulate.a = 0.8
	_shadow(_field_label)
	var parts := [str(field.get("phase", "night")).capitalize()]
	if field.get("weather", "") not in ["", "clear"] and not field.get("inside", false):
		parts.append(str(field.weather).capitalize())
	if field.get("inside", false):
		parts.append("Indoors")
	if GameState.flags.get("timed_hits", true):
		parts.append("timed hits on (H)")
	else:
		parts.append("timed hits off (H)")
	_field_label.text = " · ".join(parts)
	add_child(_field_label)
	_mark = Label.new()
	_mark.text = "!"
	_mark.add_theme_font_size_override("font_size", 22)
	_mark.add_theme_color_override("font_color", Color("ffe24a"))
	_shadow(_mark)
	_mark.visible = false
	add_child(_mark)
	_box = DialogueBox.new(_name_of)
	add_child(_box)
	_box.option_picked.connect(func(i: int) -> void: _choice.emit(i))
	_box.cancelled.connect(func() -> void: _choice.emit(-1))
	_refresh()


func _foe_node(f: Dictionary) -> Node2D:
	var node := Node2D.new()
	var path: String = FOE_DIR + str(f.id) + ".png"
	if ResourceLoader.exists(path):
		var sp := Sprite2D.new()
		sp.texture = load(path)
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.hframes = int(_foe_index.get(f.id, {}).get("frames", 2))
		sp.vframes = 1
		sp.scale = Vector2(2, 2)
		sp.position = Vector2(0, -96)
		node.add_child(sp)
		sp.set_meta("idle", true)
	else:
		var body := Polygon2D.new()
		var h := 60.0 if f.kind != "animal" else 36.0
		var w := 36.0 if f.kind != "animal" else 50.0
		if f.anomaly:
			h = 110.0
			w = 70.0
		body.polygon = PackedVector2Array([Vector2(-w / 2, 0), Vector2(-w / 2 + 6, -h), Vector2(w / 2 - 6, -h), Vector2(w / 2, 0)])
		body.color = Color("05070c")
		node.add_child(body)
		for dx in [-8, 8]:
			var eye := ColorRect.new()
			eye.size = Vector2(5, 4)
			eye.position = Vector2(dx - 2, -h + 18)
			eye.color = Color("ff3a2a") if f.anomaly else Color("ffe24a")
			node.add_child(eye)
	return node


func _name_of(id: String) -> String:
	if id == "narrator":
		return ""
	return id


func _shadow(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color", Color("050608"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)


func _process(delta: float) -> void:
	if not _running:
		return
	if Input.is_action_just_pressed("timed"):
		GameState.flags["timed_hits"] = not GameState.flags.get("timed_hits", true)
		_field_label.text = _field_label.text.replace("timed hits on", "timed hits X").replace("timed hits off", "timed hits on").replace("timed hits X", "timed hits off")
	if _timing:
		if Input.is_action_just_pressed("interact"):
			_timed_hit = true
			_timing = false
			_mark.visible = false
		return
	if Input.is_action_just_pressed("interact"):
		_box.confirm()
	elif Input.is_action_just_pressed("cancel"):
		_box.cancel()
	elif Input.is_action_just_pressed("move_up"):
		_box.move(-1)
	elif Input.is_action_just_pressed("move_down"):
		_box.move(1)
	for key in _sprites:
		var node: Node2D = _sprites[key]
		for c in node.get_children():
			if c is Sprite2D and c.has_meta("idle") and c.hframes > 1:
				c.frame = int(Time.get_ticks_msec() / 700) % c.hframes


# ---------- the loop ----------

func _run() -> void:
	var intro = spec.get("intro", "")
	if intro is String and intro != "":
		await _say([["narrator", intro]])
	elif intro is Array and not intro.is_empty():
		await _say(intro)
	while BattleRules.outcome(b) == "":
		var a: Dictionary = BattleRules.next_actor(b)
		if a.is_empty():
			break
		var st := BattleRules.start_turn(b, a)
		if not st.lines.is_empty():
			await _say_lines(st.lines)
		if st.skip or a.broken:
			BattleRules.spend_turn(b, a)
			_refresh()
			continue
		if a.side == "party":
			await _party_turn(a)
		else:
			await _foe_turn(a)
		_refresh()
		if BattleRules.outcome(b) != "":
			break
	await _outro()


func _party_turn(a: Dictionary) -> void:
	while true:
		_refresh()
		var cmds := BattleRules.commands(GameData, b, a, GameState)
		var opts := []
		for c in cmds:
			opts.append({"label": c.label + ("" if c.enabled else " (%s)" % c.get("why", "")), "enabled": c.enabled})
		var i: int = await _menu("%s. What do you do?" % a.name, opts, a.id)
		if i < 0:
			continue
		var cmd: Dictionary = cmds[i]
		var delay := 1.0
		match cmd.kind:
			"attack":
				var t := await _pick_foe()
				if t.is_empty():
					continue
				var timed := await _swing(a, t)
				await _say_lines(BattleRules.basic_attack(b, a, t, timed))
			"skill":
				var s: Dictionary = cmd.skill
				var t := {}
				if s.get("target", "foe") == "foe":
					t = await _pick_foe()
				elif s.get("target", "foe") == "ally":
					t = await _pick_ally(a)
				else:
					t = a
				if t.is_empty():
					continue
				var timed := 1.0
				if s.get("type", "") == "damage":
					timed = await _swing(a, t if s.get("target", "foe") == "foe" else BattleRules.alive(b, "foe")[0])
				else:
					await _flash(a, Color("7fb2ff"))
				await _say_lines(BattleRules.use_skill(GameData, GameState, b, a, s, t, timed))
			"observe":
				var t := await _pick_foe(true)
				if t.is_empty():
					continue
				var mopts := []
				for m in BattleRules.METHODS:
					mopts.append({"label": BattleRules.METHOD_NAMES[m], "enabled": true})
				var mi: int = await _menu("Catch what it does. How?", mopts, a.id)
				if mi < 0:
					continue
				await _flash(t, Color.WHITE)
				await _say_lines(BattleRules.observe(GameData, GameState, b, a, t, BattleRules.METHODS[mi]))
				delay = 0.8
			"item":
				var items := BattleRules.battle_items(GameData, GameState)
				var iopts := []
				for it in items:
					iopts.append({"label": "%s x%d" % [it.name, it.count], "enabled": true})
				var ii: int = await _menu("From the kit:", iopts, a.id)
				if ii < 0:
					continue
				var t := a
				if items[ii].item.get("restore", {}).has("composure"):
					t = await _pick_ally(a)
					if t.is_empty():
						continue
				await _say_lines(BattleRules.use_item(GameData, GameState, b, a, items[ii].id, t))
			"guard":
				await _say_lines(BattleRules.guard(b, a))
				delay = 0.7
			"revelation":
				await _shake(8)
				for f in BattleRules.alive(b, "foe"):
					await _flash(f, Color("ffe24a"))
				await _say_lines(BattleRules.revelation(GameData, b))
			"run":
				await _say_lines(BattleRules.run(b, a))
		BattleRules.spend_turn(b, a, delay)
		return


func _foe_turn(f: Dictionary) -> void:
	var node: Node2D = _sprites.get(f.key)
	var blocked := 1.0
	if node:
		var t := create_tween()
		t.tween_property(node, "position:x", node.position.x - 40, 0.25).set_trans(Tween.TRANS_BACK)
		await t.finished
		blocked = 0.6 if await _timed_moment(Vector2(node.position.x - 60, 120)) else 1.0
		var back := create_tween()
		back.tween_property(node, "position:x", node.position.x + 40, 0.2)
	var r := BattleRules.foe_turn(b, f, blocked)
	var target: Node2D = _sprites.get(r.target)
	if target and r.move.get("type", "attack") != "status":
		await _shake(3)
		await _flash({"key": r.target}, Color("ff5a4a"))
	await _say_lines(r.lines)
	BattleRules.spend_turn(b, f)


## The attacker steps up; a timed press on the "!" makes the hit land harder.
func _swing(a: Dictionary, t: Dictionary) -> float:
	var node: Node2D = _sprites.get(a.key)
	var tnode: Node2D = _sprites.get(t.key)
	if node:
		var tw := create_tween()
		tw.tween_property(node, "position", node.position + Vector2(30, -20), 0.22).set_trans(Tween.TRANS_BACK)
		await tw.finished
	var good := await _timed_moment((tnode.position + Vector2(0, -110)) if tnode else Vector2(470, 100))
	if tnode:
		await _flash(t, Color.WHITE)
		await _shake(4 if good else 2)
	if node:
		var back := create_tween()
		back.tween_property(node, "position", node.position - Vector2(30, -20), 0.2)
	return 1.25 if good else 1.0


## Shows the "!" and waits a short window for Space. False when timed hits are off.
func _timed_moment(at: Vector2) -> bool:
	if not GameState.flags.get("timed_hits", true):
		await get_tree().create_timer(0.15).timeout
		return false
	_mark.position = at
	_mark.visible = true
	_timing = true
	_timed_hit = false
	var t0 := Time.get_ticks_msec()
	while _timing and Time.get_ticks_msec() - t0 < TIMED_WINDOW * 1000.0:
		await get_tree().process_frame
	_timing = false
	_mark.visible = false
	if _timed_hit:
		_mark.text = "Good!"
		_mark.visible = true
		await get_tree().create_timer(0.3).timeout
		_mark.visible = false
		_mark.text = "!"
	return _timed_hit


func _flash(actor: Dictionary, colour: Color) -> void:
	var node: Node2D = _sprites.get(actor.get("key", ""))
	if node == null:
		return
	node.modulate = colour
	await get_tree().create_timer(0.08).timeout
	node.modulate = Color.WHITE


func _shake(px: int) -> void:
	var orig := _stage.position
	for i in 4:
		_stage.position = orig + Vector2((px if i % 2 == 0 else -px), 0)
		await get_tree().process_frame
		await get_tree().process_frame
	_stage.position = orig


func _pick_foe(anomaly_only := false) -> Dictionary:
	var foes := BattleRules.alive(b, "foe")
	if anomaly_only:
		var only := []
		for f in foes:
			if f.anomaly:
				only.append(f)
		foes = only
	if foes.size() == 1:
		return foes[0]
	var opts := []
	for f in foes:
		opts.append({"label": f.name + (" (%s)" % ", ".join(f.weak) if f.known and not f.weak.is_empty() else ""), "enabled": true})
	var i: int = await _menu("At whom?", opts)
	return foes[i] if i >= 0 else {}


func _pick_ally(a: Dictionary) -> Dictionary:
	var party := BattleRules.alive(b, "party")
	var opts := []
	for m in party:
		opts.append({"label": "%s (%d/%d)" % [m.name, m.composure, m.max_composure], "enabled": true})
	var i: int = await _menu("For whom?", opts, a.id)
	return party[i] if i >= 0 else {}


func _menu(title: String, options: Array, portrait := "") -> int:
	_box.show_menu(title, "", options, portrait)
	var i: int = await _choice
	return i


func _say(lines: Array) -> void:
	_box.show_lines(lines)
	await _box.lines_finished


func _say_lines(lines: Array) -> void:
	if lines.is_empty():
		return
	_refresh()
	await _say([["narrator", " ".join(lines)]])


func _outro() -> void:
	_running = false
	var result := BattleRules.settle(GameData, GameState, b)
	var lines := []
	match result.outcome:
		"won":
			lines.append(spec.get("win", "It is over."))
			lines.append("%d XP." % result.xp)
		"lasted":
			lines.append(spec.get("win", "First light. It is gone, and you are still here."))
			lines.append("%d XP." % result.xp)
		"lost":
			lines.append(spec.get("lose", "The party breaks and runs. Dread rises."))
		"fled":
			lines.append("You got away. Nobody is proud of it.")
	for lv in result.levelups:
		lines.append("%s reaches level %d." % [lv.name, lv.level])
	for ev in result.evidence:
		var e: Dictionary = Investigation.case_data(GameData, GameState).get("evidence", {}).get(ev, {})
		if not e.is_empty():
			lines.append("Logged: %s." % e.get("title", ev))
	if result.banked > 0:
		lines.append("Evidence banked: %d." % result.banked)
	if not result.broken.is_empty():
		lines.append("Unreliable witness for the rest of the case: %s." % ", ".join(result.broken))
	_running = true
	await _say([["narrator", " ".join(lines)]])
	_running = false
	_box.close()
	finished.emit(result)


func _refresh() -> void:
	for a in b.actors:
		var bars: Dictionary = _bars.get(a.key, {})
		if bars.is_empty():
			continue
		var st := ""
		for s in a.statuses:
			st += " " + str(s)
		if a.side == "party":
			bars.name.text = "%s\n%s %d\n%s %d%s" % [a.name, _bar(a.composure, a.max_composure, 8), a.composure, _bar(a.focus, a.max_focus, 5, "+"), a.focus, st]
			if a.broken:
				bars.name.text = a.name + "\nbroken"
		else:
			var weak := ""
			if a.known and not a.weak.is_empty():
				weak = "\nweak: " + ", ".join(a.weak)
			elif not a.weak.is_empty():
				weak = "\nweak: ?"
			if a.anomaly:
				bars.name.text = "%s\n%s%s%s" % [a.name, _bar(a.phase, max(1, a.tells.size()), a.tells.size(), "*"), weak, st]
			else:
				bars.name.text = "%s\n%s%s%s" % [a.name, _bar(a.composure, a.max_composure, 8), weak, st]
			if a.broken:
				bars.name.text = ""
		var node: Node2D = _sprites.get(a.key)
		if node:
			node.visible = not a.broken
	var row := []
	for p in BattleRules.preview(b, 7):
		row.append(p.name if p.side == "party" else "[%s]" % p.name)
	_turn_row.text = "Next: " + " › ".join(row)
	var anomaly := BattleRules.has_anomaly(b)
	var turns := ""
	if anomaly:
		for f in BattleRules.alive(b, "foe"):
			if f.anomaly:
				turns = "   Hold %d more" % max(0, f.turns - b.round)
	_meter.text = "Evidence %s %d   Insight %s%s" % [_bar(b.meter, BattleRules.METER_MAX, 10, "o"), b.meter, _bar(b.insight, BattleRules.INSIGHT_MAX, 3, "^"), turns]


func _bar(v: int, maxv: int, cells: int, mark := "#") -> String:
	var filled := int(round(float(cells) * float(v) / float(max(1, maxv))))
	var s := ""
	for i in cells:
		s += mark if i < filled else "-"
	return s
