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
	for e in errors:
		printerr("FAIL: " + e)
	print("Tests: %s (%d classes, %d foes, %d cases, %d maps)" % ["PASS" if errors.is_empty() else "FAIL", data.classes.size(), data.foes.size(), data.cases.size(), data.maps.size()])
	data.free()
	state.free()
	copy.free()
	quit(0 if errors.is_empty() else 1)


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
			if not facades.has(f.id):
				errors.append("map %s uses missing facade %s" % [map_id, f.id])
		for fill in m.get("fills", []) + m.get("scatter", []):
			var tiles: Variant = fill.tiles
			for t in (tiles if tiles is Array else [tiles]):
				if not atlas.has(t):
					errors.append("map %s fills with missing tile %s" % [map_id, t])
		for n in m.get("npcs", []):
			if not FileAccess.file_exists("res://assets/sprites/%s.png" % n.id):
				errors.append("map %s npc %s has no sprite" % [map_id, n.id])
	return errors
