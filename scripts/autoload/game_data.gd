extends Node
## Loads the game's content from res://data. Everything a case needs (classes,
## foes, leads, evidence) lives in JSON so new cases are data, not code.

const DATA_DIR := "res://data"
const DAMAGE_TYPES := ["physical", "signal", "spirit", "reason", "arcane"]
const STATS := ["reason", "charm", "grit", "intuition"]
const SPEECH_TAGS := ["logic", "press", "tech", "lore", "empathy", "intimidate", "arcana"]

var classes: Dictionary = {}
var roster: Dictionary = {}
var foes: Dictionary = {}
var cases: Dictionary = {}
var maps: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	classes = _strip(_read_json(DATA_DIR + "/classes.json"))
	roster = _strip(_read_json(DATA_DIR + "/roster.json"))
	foes = _strip(_read_json(DATA_DIR + "/foes.json"))
	cases.clear()
	var dir := DirAccess.open(DATA_DIR + "/cases")
	if dir:
		for file in dir.get_files():
			if file.ends_with(".json"):
				var c: Dictionary = _read_json(DATA_DIR + "/cases/" + file)
				cases[c.get("id", file.get_basename())] = c
	maps.clear()
	var mdir := DirAccess.open(DATA_DIR + "/maps")
	if mdir:
		for file in mdir.get_files():
			if file.ends_with(".json"):
				var m: Dictionary = _strip(_read_json(DATA_DIR + "/maps/" + file))
				maps[m.get("id", file.get_basename())] = m


## Returns a list of human-readable problems with the data; empty means valid.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if classes.size() != 7:
		errors.append("expected 7 classes, found %d" % classes.size())
	for id in classes:
		var c: Dictionary = classes[id]
		for s in STATS:
			if not c.get("stats", {}).has(s):
				errors.append("class %s missing stat %s" % [id, s])
		for skill in c.get("skills", []):
			if skill.has("damage") and not skill.damage in DAMAGE_TYPES:
				errors.append("class %s skill %s has unknown damage type %s" % [id, skill.id, skill.damage])
	for id in roster:
		if not classes.has(roster[id].get("class", "")):
			errors.append("roster %s has unknown class" % id)
	for id in foes:
		for t in foes[id].get("weak", []) + foes[id].get("resist", []):
			if not t in DAMAGE_TYPES:
				errors.append("foe %s has unknown damage type %s" % [id, t])
	for case_id in cases:
		var c: Dictionary = cases[case_id]
		var evidence: Dictionary = c.get("evidence", {})
		for lead in c.get("leads", []):
			if not evidence.has(lead.get("evidence", "")):
				errors.append("case %s lead %s points at missing evidence" % [case_id, lead.get("id")])
			if not c.get("locations", {}).has(lead.get("location", "")):
				errors.append("case %s lead %s has unknown location" % [case_id, lead.get("id")])
			if lead.has("class_bonus") and not classes.has(lead.class_bonus):
				errors.append("case %s lead %s has unknown class bonus" % [case_id, lead.get("id")])
		for e in evidence:
			if not evidence[e].get("lean") in ["hoax", "natural", "unexplained"]:
				errors.append("case %s evidence %s has a bad lean" % [case_id, e])
			for x in evidence[e].get("exposes", []):
				if not evidence.has(x):
					errors.append("case %s evidence %s exposes missing evidence %s" % [case_id, e, x])
			if evidence[e].has("lab") and not evidence.has(evidence[e].lab):
				errors.append("case %s evidence %s has a missing lab result" % [case_id, e])
		var tags: Array = c.get("speech_tags", SPEECH_TAGS)
		var contradictions: Dictionary = c.get("contradictions", {})
		for cid in contradictions:
			for e in contradictions[cid].get("evidence", []):
				if not evidence.has(e):
					errors.append("case %s contradiction %s uses missing evidence %s" % [case_id, cid, e])
			if not c.get("witnesses", {}).has(contradictions[cid].get("witness", "")):
				errors.append("case %s contradiction %s has no witness" % [case_id, cid])
		for wid in c.get("witnesses", {}):
			for fact in c.witnesses[wid].get("facts", []):
				if fact.has("evidence") and not evidence.has(fact.evidence):
					errors.append("case %s witness %s fact %s gives missing evidence" % [case_id, wid, fact.get("id")])
				if fact.get("gates", []).is_empty():
					errors.append("case %s witness %s fact %s has no gate" % [case_id, wid, fact.get("id")])
				for gate in fact.get("gates", []):
					if gate.has("check") and not gate.check in tags:
						errors.append("case %s fact %s has unknown speech tag %s" % [case_id, fact.get("id"), gate.check])
					if gate.has("check") and not gate.has("prompt"):
						errors.append("case %s fact %s check has no prompt" % [case_id, fact.get("id")])
					if gate.has("show") and not evidence.has(gate.show):
						errors.append("case %s fact %s asks for missing evidence %s" % [case_id, fact.get("id"), gate.show])
					if gate.has("contradiction") and not contradictions.has(gate.contradiction):
						errors.append("case %s fact %s uses missing contradiction %s" % [case_id, fact.get("id"), gate.contradiction])
	for map_id in maps:
		var m: Dictionary = maps[map_id]
		var c: Dictionary = cases.get(m.get("case", ""), {})
		var evidence: Dictionary = c.get("evidence", {})
		var building_ids := []
		for b in m.get("facades", []) + m.get("houses", []):
			building_ids.append(b.id)
		for iid in m.get("interiors", {}):
			if not iid in building_ids:
				errors.append("map %s interior %s has no facade or house" % [map_id, iid])
		var clues: Array = m.get("clues", []).duplicate()
		for iid in m.get("interiors", {}):
			clues += m.interiors[iid].get("clues", [])
		for clue in clues:
			if clue.get("methods", {}).is_empty():
				errors.append("map %s clue %s has no methods" % [map_id, clue.get("id")])
			for method in clue.get("methods", {}):
				if not method in ["photograph", "bag", "cast", "measure"]:
					errors.append("map %s clue %s has unknown method %s" % [map_id, clue.get("id"), method])
				var e: String = clue.methods[method]
				if e != "spoil" and not evidence.has(e):
					errors.append("map %s clue %s yields missing evidence %s" % [map_id, clue.get("id"), e])
			if clue.has("requires") and not evidence.has(clue.requires):
				errors.append("map %s clue %s requires missing evidence" % [map_id, clue.get("id")])
	return errors


func _read_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("GameData: could not read " + path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("GameData: bad JSON in " + path)
		return {}
	return parsed


## Drops "_doc" notes so they never show up as content.
func _strip(d: Variant) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = d.duplicate()
	out.erase("_doc")
	return out
