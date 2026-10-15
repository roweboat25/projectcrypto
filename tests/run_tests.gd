extends SceneTree
## Headless checks run in CI: godot --headless -s res://tests/run_tests.gd
## Validates the content, the save round trip, and the investigation rules.

func _initialize() -> void:
	var data = load("res://scripts/autoload/game_data.gd").new()
	data.load_all()
	var errors: Array[String] = data.validate()
	var state = load("res://scripts/autoload/game_state.gd").new()
	state.party = ["player", "miriam", "teddy"]
	state.day = 2
	var copy = load("res://scripts/autoload/game_state.gd").new()
	copy.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	if copy.party != state.party or copy.day != 2:
		errors.append("save round-trip lost data")
	if data.cases.is_empty():
		errors.append("no cases loaded")
	if data.maps.is_empty():
		errors.append("no maps loaded")
	errors += _investigation_checks(data)
	errors += _voice_checks(data)
	errors += _art_checks(data)
	errors += _script_checks()
	errors += _office_checks(data)
	errors += _tide_checks(data)
	errors += _battle_checks(data)
	for e in errors:
		printerr("FAIL: " + e)
	print("Tests: %s (%d classes, %d foes, %d cases, %d maps)" % ["PASS" if errors.is_empty() else "FAIL", data.classes.size(), data.foes.size(), data.cases.size(), data.maps.size()])
	data.free()
	state.free()
	copy.free()
	quit(0 if errors.is_empty() else 1)


## Gear, shops, verdicts and the Office budget.
## The tide clock and the gate conditions Sandown adds: tide, signs and all.
func _tide_checks(data) -> Array[String]:
	var errors: Array[String] = []
	var state = load("res://scripts/autoload/game_state.gd").new()
	state.party = ["player", "miriam"]
	state.player_class = "skeptic"
	state.case_id = "tidetest"
	data.cases["tidetest"] = {"id": "tidetest", "name": "Tide test", "tide": {"low_at": 6.0, "period": 12.0},
		"trail": [{"night": 1, "clues": ["a"]}, {"night": 1, "clues": ["b"]}, {"night": 2, "clues": ["c"]}],
		"evidence": {"a": {"lean": "hoax"}, "b": {"lean": "hoax"}, "c": {"lean": "hoax"}},
		"gates": {"beach": {"opens": [{"tide": "low"}]}, "hut": {"opens": [{"all": [{"signs": 2}, {"phase": ["dusk", "night"]}]}]}}}
	# time_of_day 0 is 6 AM: low water on day 1
	if Investigation.tide_state(data, state, 0.0) != "low":
		errors.append("6 AM day 1 should be low water, got %s" % Investigation.tide_state(data, state, 0.0))
	if Investigation.tide_state(data, state, 0.25) != "high":
		errors.append("noon should be high water with a 12 hour period, got %s" % Investigation.tide_state(data, state, 0.25))
	if Investigation.tide_state(data, state, 0.125) != "rising":
		errors.append("9 AM should be rising, got %s" % Investigation.tide_state(data, state, 0.125))
	state.day = 2
	if Investigation.tide_state(data, state, 0.0) != "low":
		errors.append("the tide should keep its cycle across days")
	if not Investigation.gate_open(data, state, "beach", 0.0) or Investigation.gate_open(data, state, "beach", 0.25):
		errors.append("the tide gate should open at low water only")
	if Investigation.gate_open(data, state, "hut", 0.5):
		errors.append("the hut should stay hidden with no signs")
	state.evidence = ["a", "b"]
	if Investigation.signs_logged(data, state) != 2:
		errors.append("two signs should be logged, got %d" % Investigation.signs_logged(data, state))
	if Investigation.gate_open(data, state, "hut", 0.25):
		errors.append("the hut needs dusk as well as the signs")
	if not Investigation.gate_open(data, state, "hut", 0.5):
		errors.append("the hut should appear at dusk with two signs")
	data.cases.erase("tidetest")
	return errors


## A whole fight with no scene: turn order, a dog beaten by plain attacks, XP and levels,
## an observation battle captured tell by tell, statuses, the cure charm, and the new gate conditions.
func _battle_checks(data) -> Array[String]:
	var errors: Array[String] = []
	var state = load("res://scripts/autoload/game_state.gd").new()
	state.party = ["player", "miriam", "teddy"]
	state.player_class = "signals"
	state.case_id = "point_pleasant"
	state.composure = 100
	var b: Dictionary = BattleRules.setup(data, state, ["stray_dog"], {"phase": "night"})
	b["_rng"] = RandomNumberGenerator.new()
	b._rng.seed = 7
	if b.actors.size() != 4:
		errors.append("a fight of three against one should have four actors, got %d" % b.actors.size())
	if BattleRules.preview(b, 8).size() != 8:
		errors.append("the turn preview should show eight turns")
	var guard := 0
	while BattleRules.outcome(b) == "" and guard < 300:
		var a: Dictionary = BattleRules.next_actor(b)
		var st := BattleRules.start_turn(b, a)
		if not st.skip and not a.broken:
			if a.side == "party":
				BattleRules.basic_attack(b, a, BattleRules.alive(b, "foe")[0])
			else:
				BattleRules.foe_turn(b, a)
		BattleRules.spend_turn(b, a)
		guard += 1
	if BattleRules.outcome(b) != "won":
		errors.append("three agents should beat one stray dog, got %s after %d turns" % [BattleRules.outcome(b), guard])
	var r := BattleRules.settle(data, state, b)
	if r.xp != 8 or int(state.xp.get("player", 0)) != 8:
		errors.append("a stray dog pays 8 XP, got %d / %d" % [r.xp, int(state.xp.get("player", 0))])
	if BattleRules.gain_xp(state, "player", 40) != 2 or int(state.levels.get("player", 1)) != 2:
		errors.append("48 XP should reach level 2, got level %d" % int(state.levels.get("player", 1)))
	# an observation battle: the wrong method costs, the right ones capture the tells
	var b2: Dictionary = BattleRules.setup(data, state, ["mothman"], {"phase": "night", "inside": true})
	b2["_rng"] = RandomNumberGenerator.new()
	b2._rng.seed = 3
	var me: Dictionary = b2.actors[0]
	var moth: Dictionary = b2.actors[3]
	var ids := []
	for c in BattleRules.commands(data, b2, me, state):
		ids.append(c.id)
	if not "observe" in ids or "run" in ids:
		errors.append("an anomaly fight should offer Observe and no Run, got %s" % str(ids))
	var before: int = me.composure
	BattleRules.observe(data, state, b2, me, moth, "record")
	if moth.phase != 0 or me.composure != before - 4:
		errors.append("the wrong method should capture nothing and cost 4 composure")
	BattleRules.observe(data, state, b2, me, moth, "photograph")
	if moth.phase != 1 or not "plant_glare_photo" in b2.evidence or b2.meter < 2:
		errors.append("the photograph should capture the first tell")
	BattleRules.observe(data, state, b2, me, moth, "record")
	BattleRules.observe(data, state, b2, me, moth, "read")
	if not moth.broken or BattleRules.outcome(b2) != "won":
		errors.append("three tells should end the observation battle as a win, got %s" % BattleRules.outcome(b2))
	BattleRules.settle(data, state, b2)
	if not state.has_evidence("plant_glare_photo") or not state.has_evidence("plant_wall_mark"):
		errors.append("captured tells should land in the case file")
	if int(state.flags.get("banked_point_pleasant", 0)) <= 0:
		errors.append("the evidence meter should bank at the end of a won fight")
	# statuses and the cure charm
	me.statuses["jammed"] = 2
	for c in BattleRules.commands(data, b2, me, state):
		if c.kind == "skill" and c.enabled:
			errors.append("a jammed member should have no skills")
			break
	state.gear["player"] = {"charm1": "seaside_rock"}
	var m: Dictionary = BattleRules.member(data, state, "player")
	if not m.cure_charm:
		errors.append("the stick of rock should give the cure charm")
	var b3: Dictionary = BattleRules.setup(data, state, ["stray_dog"], {})
	var lines := []
	BattleRules.hurt(b3, b3.actors[0], 999, lines)
	if b3.actors[0].broken or b3.actors[0].composure <= 0:
		errors.append("the cure charm should catch the first break")
	BattleRules.hurt(b3, b3.actors[0], 999, lines)
	if not b3.actors[0].broken:
		errors.append("the cure charm works once a fight")
	# the gate conditions fights need: night, day, not_flag
	state.day = 5
	if not Investigation.cond_holds(data, state, {"night": 5}, 0.8) or Investigation.cond_holds(data, state, {"night": 5}, 0.3):
		errors.append("night 5 is the night of day 5")
	state.day = 4
	if Investigation.cond_holds(data, state, {"night": 5}, 0.8) or not Investigation.cond_holds(data, state, {"day": 4}, 0.3):
		errors.append("day and night conditions should read the case day")
	if not Investigation.cond_holds(data, state, {"not_flag": "nope"}, 0.3):
		errors.append("not_flag should hold while the flag is unset")
	# the siege: pins come from the trail, preparation needs the item
	if data.cases.has("kelly") and data.cases.kelly.has("siege"):
		state.case_id = "kelly"
		state.evidence = []
		state.items = {}
		var spec: Dictionary = data.cases.kelly.siege
		var pinned := Siege.pins(data, state, spec)
		for ap in pinned:
			if pinned[ap]:
				errors.append("no approach should be pinned with nothing logged, but %s is" % ap)
		state.evidence = ["fm_burned_circle"]
		pinned = Siege.pins(data, state, spec)
		if not pinned.get("gully", false):
			errors.append("logging the burned circle should pin the gully")
		var opts := Siege.prep_options(data, state, spec, pinned, {})
		var gully_opt := {}
		for o in opts:
			if o.approach == "gully":
				gully_opt = o
		if gully_opt.get("enabled", true):
			errors.append("the gully cannot be prepared without lamp oil")
		state.add_item("lamp_oil")
		for o in Siege.prep_options(data, state, spec, pinned, {}):
			if o.approach == "gully" and not o.enabled:
				errors.append("the gully should be preparable with lamp oil in the kit")
	state.free()
	return errors


func _office_checks(data) -> Array[String]:
	var errors: Array[String] = []
	var state = load("res://scripts/autoload/game_state.gd").new()
	state.party = ["player", "miriam", "teddy"]
	state.player_class = "skeptic"
	state.case_id = "point_pleasant"
	# the issue tool is equipped by default
	var g: Dictionary = Investigation.member_gear(data, state, "player")
	if data.items.get(g.tool, {}).get("class", "") != "skeptic":
		errors.append("the skeptic should start with a skeptic issue tool, got %s" % g.tool)
	# buying and equipping a slide rule raises reason and the logic voice
	var before := Investigation.voice_level(data, state, "logic")
	state.cash = 100
	if Investigation.buy(data, state, "slide_rule") != "" or not state.has_item("slide_rule"):
		errors.append("could not buy the slide rule")
	if state.cash != 100 - int(data.items.slide_rule.price):
		errors.append("the slide rule should cost its price")
	if not Investigation.equip(data, state, "player", "tool", "slide_rule"):
		errors.append("the skeptic should be able to equip the slide rule")
	if Investigation.voice_level(data, state, "logic") != before + 2:
		errors.append("slide rule should add +1 reason and +1 logic, got %d from %d" % [Investigation.voice_level(data, state, "logic"), before])
	if state.has_item("slide_rule") or not state.has_item(g.tool):
		errors.append("equipping should swap the slide rule for the issue tool in the kit")
	if Investigation.equip(data, state, "miriam", "tool", "slide_rule"):
		errors.append("a non-skeptic should not equip a skeptic tool")
	# shops only sell what they stock
	if "slide_rule" in data.shop_stock("variety") or not "film" in data.shop_stock("variety"):
		errors.append("shop stock is wrong")
	# a verdict pays budget and refreshes the Office
	Investigation.gain_evidence(data, state, "marlene_statement")
	var v: Dictionary = Investigation.file_verdict(data, state, "unexplained")
	if int(v.budget) < 1 or state.budget != int(v.budget) or not state.verdicts.has("point_pleasant"):
		errors.append("filing a verdict should pay budget")
	if data.cases.point_pleasant.get("truth", "") == "unexplained" and int(v.budget) < 3:
		errors.append("matching the hidden truth should pay extra")
	if not data.office.is_empty() and not state.flags.get("office_darkroom", false):
		errors.append("the darkroom should open after the first verdict")
	if not v.has("relic") or data.items.get(v.relic, {}).get("verdict", "") != "unexplained":
		errors.append("an unexplained verdict on Point Pleasant should drop its relic")
	if not data.office.is_empty():
		var any_id: String = data.office.car.keys()[0]
		state.budget = 99
		state.budget_earned = 99
		if Investigation.buy_upgrade(data, state, any_id) != "" or not state.flags.get(data.office.car[any_id].flag, false):
			errors.append("buying a car upgrade should set its flag")
		if Investigation.buy_upgrade(data, state, any_id) == "":
			errors.append("an upgrade should not sell twice")
	state.free()
	return errors


## Every script in scripts/ must at least parse, since most only run inside a scene.
func _script_checks() -> Array[String]:
	var errors: Array[String] = []
	for dir_path in ["res://scripts", "res://scripts/town", "res://scripts/autoload"]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for file in dir.get_files():
			if file.ends_with(".gd"):
				var scr = load(dir_path + "/" + file)
				if scr == null or not scr.can_instantiate():
					errors.append("script %s/%s does not compile" % [dir_path, file])
	return errors


## The inner voices, scripted checks, gates and phases.
func _voice_checks(data) -> Array[String]:
	var errors: Array[String] = []
	var state = load("res://scripts/autoload/game_state.gd").new()
	state.party = ["player", "miriam", "teddy"]
	state.player_class = "signals"
	# tech is the signals lead's own voice: reason 3 + 2
	if Investigation.voice_level(data, state, "tech") != 5:
		errors.append("tech voice level should be 5, got %d" % Investigation.voice_level(data, state, "tech"))
	# press: lead charm 1, teddy boosts it +1
	if Investigation.voice_level(data, state, "press") != 2:
		errors.append("press voice level should be 2, got %d" % Investigation.voice_level(data, state, "press"))
	state.dread = 3
	if Investigation.voice_level(data, state, "tech") != 4:
		errors.append("dread 3 should cost one voice level")
	state.dread = 1
	if Investigation.phase(0.0) != "morning" or Investigation.phase(0.3) != "day" or Investigation.phase(0.48) != "dusk" or Investigation.phase(0.8) != "night":
		errors.append("phases are off: %s %s %s %s" % [Investigation.phase(0.0), Investigation.phase(0.3), Investigation.phase(0.48), Investigation.phase(0.8)])
	if Investigation.night_number(state, 0.8) != 1 or Investigation.night_number(state, 0.3) != 0:
		errors.append("night numbering is off")
	if Investigation.clue_visible(state, {"id": "x", "night": 2}, 0.8):
		errors.append("a night-2 sign should not show on night 1")
	# a white check: forced 2d6 of 12 passes, a 2 fails and locks until tomorrow
	var check := {"voice": "tech", "kind": "white", "difficulty": 9}
	var key := Investigation.lock_key("w", "n", 0)
	if not Investigation.attempt_voice_check(data, state, "w", key, check, 12).ok:
		errors.append("a 12 should pass a difficulty 9 white check")
	if Investigation.attempt_voice_check(data, state, "w", key, check, 2).ok:
		errors.append("a 2 should fail")
	if not Investigation.check_locked(state, key):
		errors.append("a failed white check should lock for the day")
	Investigation.sleep(data, state)
	if Investigation.check_locked(state, key):
		errors.append("sleeping should reopen a white check")
	var red := {"voice": "tech", "kind": "red", "difficulty": 9}
	Investigation.attempt_voice_check(data, state, "w", key, red, 2)
	Investigation.sleep(data, state)
	if not Investigation.check_locked(state, key):
		errors.append("a failed red check should stay locked after sleeping")
	# gates: items, phases, trust and a check that opens it for good
	data.cases["_t"] = {"id": "_t", "gates": {"g": {"opens": [{"item": "waders"}, {"phase": ["day"]}, {"check": {"voice": "nerve", "difficulty": 7}}]}}, "witnesses": {}, "evidence": {}}
	state.case_id = "_t"
	if Investigation.gate_open(data, state, "g", 0.8):
		errors.append("gate should be shut at night with no item")
	if not Investigation.gate_open(data, state, "g", 0.3):
		errors.append("gate should be open by day")
	state.add_item("waders")
	if not Investigation.gate_open(data, state, "g", 0.8):
		errors.append("waders should open the gate")
	state.items = {}
	if Investigation.try_gate(data, state, "g", 1).ok:
		errors.append("a roll of 1 should not climb the gate")
	if not Investigation.gate_check(data, state, "g").is_empty():
		errors.append("a failed gate check should close for the day")
	Investigation.sleep(data, state)
	if not Investigation.try_gate(data, state, "g", 6).ok or not Investigation.gate_open(data, state, "g", 0.8):
		errors.append("a passed gate check should open the gate for good")
	data.cases.erase("_t")
	# gives
	state.case_id = "point_pleasant"
	Investigation.apply_gives(data, state, {"flag": "f", "trust": {"marlene": 2}, "dread": -1, "item": "film"})
	if not state.flags.get("f", false) or Investigation.trust_of(data, state, "marlene") != 3 or not state.has_item("film"):
		errors.append("apply_gives did not apply")
	state.free()
	return errors


func _investigation_checks(data) -> Array[String]:
	var errors: Array[String] = []
	var state = load("res://scripts/autoload/game_state.gd").new()
	state.party = ["player", "miriam", "teddy"]
	state.player_class = "signals"
	# the skeptic in the party makes [Logic] a specialist check
	if not Investigation.has_specialist(data, state, "logic"):
		errors.append("skeptic in party should give a logic specialist")
	if Investigation.has_specialist(data, state, "arcana"):
		errors.append("no occultist in party, arcana should not be specialist")
	# a forced roll of 6 passes an easy check, a roll of 1 fails and closes it for the day
	var fact: Dictionary = data.cases.point_pleasant.witnesses.editor.facts[0]
	var gate: Dictionary = fact.gates[0]
	if not Investigation.attempt_check(data, state, fact.id, gate, 6).ok:
		errors.append("logic check with a 6 should pass")
	if Investigation.attempt_check(data, state, fact.id, gate, 1).ok:
		errors.append("logic check with a 1 should fail")
	if not Investigation.check_closed(state, fact.id, gate.check):
		errors.append("failed check should be closed for the day")
	Investigation.sleep(data, state)
	if Investigation.check_closed(state, fact.id, gate.check):
		errors.append("sleeping should reopen failed checks")
	# a contradiction needs both pieces of evidence
	if Investigation.contradiction_ready(data, state, "marlene_time"):
		errors.append("contradiction should not be ready with no evidence")
	Investigation.gain_evidence(data, state, "marlene_statement")
	Investigation.gain_evidence(data, state, "call_log")
	if not Investigation.contradiction_ready(data, state, "marlene_time"):
		errors.append("contradiction should be ready with both statements")
	var found := false
	for o in Investigation.witness_options(data, state, "marlene"):
		if o.kind == "contradiction":
			found = true
	if not found:
		errors.append("marlene should offer the contradiction option")
	# showing the suits to marlene unlocks her fact and its evidence
	Investigation.gain_evidence(data, state, "the_suits")
	var f: Dictionary = Investigation.present(data, state, "marlene", "the_suits")
	if f.is_empty():
		errors.append("showing the suits to marlene should unlock a fact")
	else:
		Investigation.unlock_fact(data, state, f)
		if not state.has_evidence("suits_at_diner"):
			errors.append("unlocking marlene's fact should give evidence")
	# exposing: the editor's fact marks the crane letter false
	Investigation.gain_evidence(data, state, "biologist_letter")
	Investigation.gain_evidence(data, state, "no_such_biologist")
	if not "biologist_letter" in state.exposed:
		errors.append("no_such_biologist should expose the crane letter")
	if "biologist_letter" in Investigation.standing_evidence(state):
		errors.append("exposed evidence should not stand")
	# clues: the right method yields evidence, a bagged sample waits for the lab, the wrong method spoils
	var clues: Array = data.maps.point_pleasant_main_street.clues
	var fur: Dictionary = clues[0]
	var r: Dictionary = Investigation.process_clue(data, state, fur, "bag")
	if r.evidence != "fence_fur" or not "fence_fur_lab" in state.samples:
		errors.append("bagging the fence fur should queue a lab result")
	var day: int = state.day
	var results: Array = Investigation.sleep(data, state)
	if not "fence_fur_lab" in results or not state.has_evidence("fence_fur_lab") or state.day != day + 1:
		errors.append("sleeping should return the lab result and advance the day")
	var film: Dictionary = clues[3]
	r = Investigation.process_clue(data, state, film, "photograph")
	if not r.spoiled or not "dropped_film" in state.spoiled:
		errors.append("photographing the film should spoil it")
	state.free()
	return errors


func _art_checks(data) -> Array[String]:
	var errors: Array[String] = []
	var props: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/props/props.json"))
	var facades: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/facades/facades.json"))
	var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tiles/atlas.json"))
	for map_id in data.maps:
		var m: Dictionary = data.maps[map_id]
		var all_props: Array = m.get("props", []).duplicate()
		for id in m.get("interiors", {}):
			all_props += m.interiors[id].get("props", [])
		for p in all_props:
			if not props.has(p.kind):
				errors.append("map %s uses missing prop %s" % [map_id, p.kind])
		for h in m.get("houses", []):
			if not props.has(h.prop):
				errors.append("map %s house %s uses missing prop" % [map_id, h.id])
		for f in m.get("facades", []):
			if not facades.has(f.get("facade", f.id)):
				errors.append("map %s uses missing facade %s" % [map_id, f.get("facade", f.id)])
		for fill in m.get("fills", []) + m.get("scatter", []):
			var tiles: Variant = fill.tiles
			for t in (tiles if tiles is Array else [tiles]):
				if not atlas.has(t):
					errors.append("map %s fills with missing tile %s" % [map_id, t])
		var all_npcs: Array = m.get("npcs", []).duplicate()
		for id in m.get("interiors", {}):
			all_npcs += m.interiors[id].get("npcs", [])
		for n in all_npcs:
			if not FileAccess.file_exists("res://assets/sprites/%s.png" % n.get("sprite", n.id)):
				errors.append("map %s npc %s has no sprite" % [map_id, n.id])
		var all_clues: Array = m.get("clues", []).duplicate()
		for id in m.get("interiors", {}):
			all_clues += m.interiors[id].get("clues", [])
		for c in all_clues:
			if not props.has(c.get("prop", "clue_prints")):
				errors.append("map %s clue %s uses missing prop" % [map_id, c.id])
	return errors
