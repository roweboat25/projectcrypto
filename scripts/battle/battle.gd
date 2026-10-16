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
const TYPE_COLOURS := {"physical": "ffc08a", "signal": "5ad6ff", "spirit": "b48cff", "reason": "ffe24a", "arcane": "7cff8a"}
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
var _hud: BattleHud
var _field_label: Label
var _mark: Label                       # the timed-hit "!"
var _timing := false
var _timed_hit := false
var _foe_index: Dictionary = {}
var _running := false
var _fx: Node2D                        # effects drawn over the actors
var _banner: Label                     # the move's name, briefly
var _gone: Array = []                  # actor keys already faded out
var _players: Dictionary = {}          # sound name -> AudioStreamPlayer


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
	add_child(BattleBackdrop.new(field))
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
		i += 1
	_fx = Node2D.new()
	_stage.add_child(_fx)
	_hud = BattleHud.new()
	add_child(_hud)
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 34
	_banner.offset_left = -200
	_banner.offset_right = 200
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 16)
	_banner.add_theme_color_override("font_color", Color("f0e6d2"))
	_shadow(_banner)
	_banner.visible = false
	add_child(_banner)
	_field_label = Label.new()
	_field_label.position = Vector2(8, 20)
	_field_label.add_theme_font_size_override("font_size", 8)
	_field_label.modulate.a = 0.7
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
	await _reveal()
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
		_hud.current = a.key
		if a.side == "party":
			await _party_turn(a)
		else:
			await _foe_turn(a)
		_hud.current = ""
		_refresh()
		if BattleRules.outcome(b) != "":
			break
	await _outro()


# ---------- the entrance ----------

## The legendary entrance. An anomaly rises out of the dark in silhouette,
## the screen flashes, it stands revealed over its name card and calls; the
## uncanny get a burst of static and their name. Full length the first time
## a foe is met, shorter after.
func _reveal() -> void:
	for f in BattleRules.alive(b, "foe"):
		var kind: String = str(GameData.foes.get(f.id, {}).get("kind", ""))
		if kind == "anomaly":
			await _reveal_anomaly(f)
		elif kind == "uncanny":
			await _reveal_uncanny(f)


func _reveal_anomaly(f: Dictionary) -> void:
	var node: Node2D = _sprites.get(f.key)
	if node == null:
		return
	var first: bool = not GameState.flags.has("seen_" + str(f.id))
	GameState.flags["seen_" + str(f.id)] = true
	var k := 1.0 if first else 0.45
	_hud.visible = false
	var dark := ColorRect.new()
	dark.color = Color(0, 0, 0.02, 0)
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dark)
	move_child(dark, _stage.get_index() + 1)
	var front := Node2D.new()
	add_child(front)
	move_child(front, dark.get_index() + 1)
	var front_fx := Node2D.new()
	front.add_child(front_fx)
	var home := node.position
	node.reparent(front)
	node.modulate = Color(0, 0, 0, 1)
	node.position = home + Vector2(0, 80)
	node.scale = Vector2(1.1, 1.1)
	_play("reveal")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dark, "color:a", 0.88, 0.6 * k)
	tw.tween_property(node, "position", home + Vector2(0, 30), 1.5 * k).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var saved_fx := _fx
	_fx = front_fx
	for i in 3:
		await get_tree().create_timer(0.2 * k).timeout
		_shake(2 + i * 2)
		# awaited, so nothing is still drawing into the front layer when it goes
		await _fx_static(node.position + Vector2(0, -90), Color("d070ff"))
	await get_tree().create_timer(0.2 * k).timeout
	# the flash and the reveal
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 1)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	node.modulate = Color(1, 1, 1, 1)
	_shake(8)
	_play("cry_anomaly")
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(flash, "color:a", 0.0, 0.7)
	tw2.tween_property(node, "position", home, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fx_burst(node.position + Vector2(0, -90), Color("b48cff"), 40)
	# the name card
	var card := _name_card(f, "An anomaly" + (". " + str(GameData.cases.get(GameState.case_id, {}).get("place", "")) if GameData.cases.has(GameState.case_id) else ""))
	add_child(card)
	card.modulate.a = 0.0
	var tw3 := create_tween()
	tw3.tween_property(card, "modulate:a", 1.0, 0.3)
	await get_tree().create_timer((2.2 if first else 1.0)).timeout
	_fx = saved_fx
	var out := create_tween().set_parallel(true)
	out.tween_property(card, "modulate:a", 0.0, 0.4)
	out.tween_property(dark, "color:a", 0.0, 0.6)
	out.tween_property(node, "scale", Vector2(1, 1), 0.6)
	await out.finished
	node.reparent(_stage)
	node.position = home
	node.scale = Vector2(1, 1)
	_stage.move_child(node, 0)
	front.queue_free()
	dark.queue_free()
	flash.queue_free()
	card.queue_free()
	_hud.visible = true


func _reveal_uncanny(f: Dictionary) -> void:
	var node: Node2D = _sprites.get(f.key)
	if node == null:
		return
	_hud.visible = false
	_play("uncanny")
	_fx_dark(0.6)
	_shake(4)
	var card := _name_card(f, "Something wrong")
	add_child(card)
	await _fx_static(node.position + Vector2(0, -80), Color("d070ff"))
	await get_tree().create_timer(0.7).timeout
	var out := create_tween()
	out.tween_property(card, "modulate:a", 0.0, 0.3)
	await out.finished
	card.queue_free()
	_hud.visible = true


func _name_card(f: Dictionary, sub: String) -> Control:
	var card := Control.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := ColorRect.new()
	bar.color = Color(0.03, 0.02, 0.06, 0.8)
	bar.position = Vector2(0, 262)
	bar.size = Vector2(640, 60)
	card.add_child(bar)
	var rule := ColorRect.new()
	rule.color = Color("e0303c")
	rule.position = Vector2(220, 262)
	rule.size = Vector2(200, 1)
	card.add_child(rule)
	var name := Label.new()
	name.text = str(f.name).to_upper()
	name.position = Vector2(0, 268)
	name.size = Vector2(640, 30)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 22)
	name.add_theme_color_override("font_color", Color("f0e6d2"))
	name.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	name.add_theme_constant_override("shadow_offset_x", 2)
	name.add_theme_constant_override("shadow_offset_y", 2)
	card.add_child(name)
	var line := Label.new()
	line.text = sub
	line.position = Vector2(0, 298)
	line.size = Vector2(640, 16)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 10)
	line.add_theme_color_override("font_color", Color("b48cff"))
	card.add_child(line)
	return card


func _play(sound: String) -> void:
	# one player per sound, kept for the fight: freeing a player from its own
	# finished signal trips the web audio driver
	if not _players.has(sound):
		var path := "res://assets/audio/%s.wav" % sound
		if not ResourceLoader.exists(path):
			return
		var p := AudioStreamPlayer.new()
		p.stream = load(path)
		p.volume_db = -6.0
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		add_child(p)
		_players[sound] = p
	_players[sound].play()


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
				var before := _snapshot()
				var timed := await _swing(a, t)
				var lines := BattleRules.basic_attack(b, a, t, timed)
				_popups(before)
				await _say_lines(lines)
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
				var before := _snapshot()
				var timed := await _skill_fx(a, s, t)
				var lines := BattleRules.use_skill(GameData, GameState, b, a, s, t, timed)
				_popups(before)
				await _say_lines(lines)
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
				_show_banner(BattleRules.METHOD_NAMES[BattleRules.METHODS[mi]], Color("f0e6d2"))
				await _fx_flash(0.5)
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
				var before := _snapshot()
				_show_banner(items[ii].name, Color("e8a64a"))
				await _fx_glow(_sprites.get(t.key), Color("7fffb0"))
				var lines := BattleRules.use_item(GameData, GameState, b, a, items[ii].id, t)
				_popups(before)
				await _say_lines(lines)
			"guard":
				await _fx_glow(_sprites.get(a.key), Color("9ab0ff"))
				await _say_lines(BattleRules.guard(b, a))
				delay = 0.7
			"revelation":
				var before := _snapshot()
				_show_banner("Revelation!", Color("ffe24a"))
				await _fx_flash(0.9)
				await _shake(8)
				for f in BattleRules.alive(b, "foe"):
					_fx_burst(_sprites[f.key].position + Vector2(0, -60), Color("ffe24a"), 40)
					await _flash(f, Color("ffe24a"))
				var lines := BattleRules.revelation(GameData, b)
				_popups(before)
				await _say_lines(lines)
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
	var before := _snapshot()
	var r := BattleRules.foe_turn(b, f, blocked)
	var target: Node2D = _sprites.get(r.target)
	_show_banner(str(r.move.get("name", "")), Color("ff8a7a"))
	match r.move.get("type", "attack"):
		"horror":
			await _fx_dark(0.5)
			await _shake(6)
			if target:
				_fx_burst(target.position + Vector2(0, -40), Color("b48cff"), 24)
		"all":
			await _fx_sweep(Color("ff5a4a"), true)
			await _shake(4)
			for m in BattleRules.alive(b, "party"):
				_flash({"key": m.key}, Color("ff5a4a"))
		"status":
			if target:
				await _fx_static(target.position + Vector2(0, -40), Color("d070ff"))
		_:
			if target:
				_fx_burst(target.position + Vector2(0, -40), Color("ff5a4a"), 16)
				await _shake(3)
				await _flash({"key": r.target}, Color("ff5a4a"))
	_popups(before)
	await _say_lines(r.lines)
	BattleRules.spend_turn(b, f)


## The attacker steps up; a timed press on the "!" makes the hit land harder.
func _swing(a: Dictionary, t: Dictionary, step_time := 0.22) -> float:
	var node: Node2D = _sprites.get(a.key)
	var tnode: Node2D = _sprites.get(t.key)
	if node:
		var tw := create_tween()
		tw.tween_property(node, "position", node.position + Vector2(30, -20), step_time).set_trans(Tween.TRANS_BACK)
		await tw.finished
	var good := await _timed_moment((tnode.position + Vector2(0, -110)) if tnode else Vector2(470, 100))
	if tnode:
		_fx_burst(tnode.position + Vector2(0, -50), Color(TYPE_COLOURS.physical), 18 if good else 10)
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
		var node: Node2D = _sprites.get(a.key)
		if node:
			if a.broken and not a.key in _gone:
				_gone.append(a.key)
				var tw := create_tween()
				tw.tween_property(node, "modulate:a", 0.0, 0.5)
				if a.side == "foe":
					_fx_burst(node.position + Vector2(0, -50), Color("f0e6d2"), 30)
			elif not a.broken and a.key in _gone:
				_gone.erase(a.key)
				node.modulate.a = 1.0
			node.visible = not a.broken or a.key in _gone
	_hud.refresh(b, _sprites)


# ---------- effects ----------

## Plays the skill's `fx` and returns the timed-hit multiplier for the rules.
func _skill_fx(a: Dictionary, s: Dictionary, t: Dictionary) -> float:
	var colour := Color(TYPE_COLOURS.get(s.get("damage", "physical"), "f0e6d2"))
	var is_foe_target: bool = s.get("target", "foe") in ["foe", "all_foes"]
	var tnode: Node2D = _sprites.get(t.get("key", ""))
	var anode: Node2D = _sprites.get(a.key)
	var at: Vector2 = (tnode.position + Vector2(0, -60)) if tnode else Vector2(470, 140)
	if not is_foe_target and s.get("type", "") != "revive":
		at = (tnode.position + Vector2(0, -40)) if tnode else Vector2(150, 190)
	_show_banner(s.name, colour)
	match s.get("fx", "bolt"):
		"lunge":
			return await _swing(a, t if is_foe_target else BattleRules.alive(b, "foe")[0])
		"combo":
			var goods := 0
			var hits := int(s.get("hits", 3))
			for h in hits:
				if await _swing(a, t, 0.16) > 1.0:
					goods += 1
			return 1.0 + 0.25 * float(goods) / float(hits)
		"bolt":
			var from: Vector2 = (anode.position + Vector2(0, -50)) if anode else Vector2(150, 180)
			_step(anode, Vector2(10, -6))
			await _fx_bolt(from, at, colour)
			var good := await _timed_moment(at + Vector2(0, -50))
			_fx_burst(at, colour, 24 if good else 14)
			await _shake(4 if good else 2)
			return 1.25 if good else 1.0
		"slash":
			_step(anode, Vector2(24, -16))
			await _fx_slash(at, colour)
			var good := await _timed_moment(at + Vector2(0, -50))
			_fx_burst(at, colour, 30)
			await _shake(5)
			return 1.25 if good else 1.0
		"burst":
			_step(anode, Vector2(10, -6))
			await _fx_rune(at, colour)
			var good := await _timed_moment(at + Vector2(0, -50))
			_fx_burst(at, colour, 40)
			await _fx_flash(0.4)
			await _shake(6 if good else 3)
			return 1.25 if good else 1.0
		"sweep":
			_step(anode, Vector2(10, -6))
			await _fx_sweep(colour, false)
			var good := await _timed_moment(Vector2(470, 90))
			for f in BattleRules.alive(b, "foe"):
				_fx_burst(_sprites[f.key].position + Vector2(0, -60), colour, 16)
			await _shake(4 if good else 2)
			return 1.25 if good else 1.0
		"flash":
			await _fx_flash(0.8)
			if is_foe_target:
				for f in BattleRules.alive(b, "foe"):
					_flash(f, Color.WHITE)
			return 1.0
		"static":
			await _fx_static(at, colour)
			return 1.0
		"rune":
			await _fx_rune(at, colour)
			if not is_foe_target and tnode:
				await _fx_glow(tnode, colour)
			return 1.0
		"glow":
			if s.get("target", "") == "all_allies":
				for m in BattleRules.alive(b, "party"):
					_fx_glow(_sprites.get(m.key), colour)
				await get_tree().create_timer(0.45).timeout
			else:
				await _fx_glow(tnode if tnode else anode, colour)
			return 1.0
	return 1.0


func _step(node: Node2D, by: Vector2) -> void:
	if node == null:
		return
	var tw := create_tween()
	tw.tween_property(node, "position", node.position + by, 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(node, "position", node.position, 0.25).set_delay(0.3)


func _show_banner(text: String, colour: Color) -> void:
	if text == "":
		return
	_banner.text = text
	_banner.add_theme_color_override("font_color", colour)
	_banner.modulate.a = 0.0
	_banner.visible = true
	_banner.scale = Vector2(1.3, 1.3)
	_banner.pivot_offset = Vector2(200, 10)
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.3).set_delay(0.7)
	tw.tween_callback(func() -> void: _banner.visible = false)


## Composure of every actor, to find what a move changed.
func _snapshot() -> Dictionary:
	var out := {}
	for a in b.actors:
		out[a.key] = a.composure
	return out


## Floating numbers over whoever gained or lost composure since the snapshot.
func _popups(before: Dictionary) -> void:
	for a in b.actors:
		var diff: int = a.composure - int(before.get(a.key, a.composure))
		if diff == 0:
			continue
		var node: Node2D = _sprites.get(a.key)
		if node == null:
			continue
		var lbl := Label.new()
		lbl.text = ("+%d" if diff > 0 else "%d") % diff
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color("7fffb0") if diff > 0 else Color("ffffff"))
		_shadow(lbl)
		lbl.position = node.position + Vector2(-12 + (randi() % 16), -110 if a.side == "foe" else -80)
		_fx.add_child(lbl)
		var tw := create_tween()
		tw.tween_property(lbl, "position:y", lbl.position.y - 26, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7).set_delay(0.3)
		tw.tween_callback(lbl.queue_free)


func _fx_bolt(from: Vector2, to: Vector2, colour: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(-10, 0), Vector2(0, -4), Vector2(10, 0), Vector2(0, 4)])
	p.color = colour
	p.position = from
	p.rotation = (to - from).angle()
	_fx.add_child(p)
	var trail := CPUParticles2D.new()
	trail.amount = 20
	trail.lifetime = 0.3
	trail.color = Color(colour, 0.6)
	trail.scale_amount_min = 1.0
	trail.scale_amount_max = 2.0
	trail.initial_velocity_min = 5
	trail.initial_velocity_max = 20
	p.add_child(trail)
	var tw := create_tween()
	tw.tween_property(p, "position", to, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	p.queue_free()


func _fx_burst(at: Vector2, colour: Color, n: int) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.amount = n
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180
	p.direction = Vector2(0, -1)
	p.initial_velocity_min = 60
	p.initial_velocity_max = 170
	p.gravity = Vector2(0, 220)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = colour
	_fx.add_child(p)
	p.emitting = true
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)


func _fx_sweep(colour: Color, at_party: bool) -> void:
	var band := ColorRect.new()
	band.color = Color(colour, 0.55)
	band.size = Vector2(60, 150)
	band.position = Vector2(300 if not at_party else 300, 60)
	_fx.add_child(band)
	var tw := create_tween()
	var to_x := 640.0 if not at_party else -60.0
	tw.tween_property(band, "position:x", to_x, 0.3).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(band, "modulate:a", 0.0, 0.3)
	await tw.finished
	band.queue_free()


func _fx_glow(node: Node2D, colour: Color) -> void:
	if node == null:
		return
	var p := CPUParticles2D.new()
	p.position = Vector2(0, -20)
	p.amount = 18
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.6
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(14, 20)
	p.direction = Vector2(0, -1)
	p.spread = 20
	p.gravity = Vector2(0, -90)
	p.initial_velocity_min = 20
	p.initial_velocity_max = 50
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = colour
	node.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
	var tw := create_tween()
	tw.tween_property(node, "modulate", colour.lightened(0.3), 0.15)
	tw.tween_property(node, "modulate", Color.WHITE, 0.3)
	await tw.finished


func _fx_rune(at: Vector2, colour: Color) -> void:
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for i in 25:
		var ang := TAU * i / 24.0
		pts.append(Vector2(cos(ang), sin(ang)) * 30)
	ring.points = pts
	ring.width = 2
	ring.default_color = colour
	ring.position = at
	ring.scale = Vector2(0.2, 0.2)
	_fx.add_child(ring)
	var inner := Line2D.new()
	var tri := PackedVector2Array()
	for i in 4:
		var ang := TAU * i / 3.0 - PI / 2
		tri.append(Vector2(cos(ang), sin(ang)) * 22)
	inner.points = tri
	inner.width = 1.5
	inner.default_color = Color(colour, 0.8)
	ring.add_child(inner)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector2(1.4, 1.4), 0.45).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(ring, "rotation", PI, 0.45)
	tw.tween_property(ring, "modulate:a", 0.0, 0.2)
	await tw.finished
	ring.queue_free()


func _fx_slash(at: Vector2, colour: Color) -> void:
	for i in 2:
		var l := Line2D.new()
		var d := Vector2(1, 1) if i == 0 else Vector2(1, -1)
		l.points = PackedVector2Array([at - d * 30, at + d * 30])
		l.width = 4 - i
		l.default_color = colour if i == 0 else Color.WHITE
		_fx.add_child(l)
		var tw := create_tween()
		tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.08 * i)
		tw.tween_callback(l.queue_free)
		await get_tree().create_timer(0.1).timeout


func _fx_flash(strength: float) -> void:
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, strength)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.0, 0.35)
	await tw.finished
	r.queue_free()


func _fx_dark(strength: float) -> void:
	var r := ColorRect.new()
	r.color = Color(0.05, 0.0, 0.1, 0.0)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	move_child(r, _stage.get_index() + 1)
	var tw := create_tween()
	tw.tween_property(r, "color:a", strength, 0.15)
	tw.tween_property(r, "color:a", 0.0, 0.4)
	await tw.finished
	r.queue_free()


func _fx_static(at: Vector2, colour: Color) -> void:
	var rects := []
	for i in 10:
		var r := ColorRect.new()
		r.color = Color(colour, 0.8)
		r.size = Vector2(4 + randi() % 14, 2)
		_fx.add_child(r)
		rects.append(r)
	# wall-clock bound so a slow frame rate does not stretch it
	var until := Time.get_ticks_msec() + 450
	while Time.get_ticks_msec() < until:
		for r in rects:
			if is_instance_valid(r):
				r.position = at + Vector2(-30 + randi() % 60, -40 + randi() % 80)
				r.visible = randf() < 0.7
		await get_tree().create_timer(0.03).timeout
	for r in rects:
		if is_instance_valid(r):
			r.queue_free()
