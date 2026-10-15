extends Node
## Loads the game's content from res://data. Everything a case needs (classes,
## foes, leads, evidence) lives in JSON so new cases are data, not code.

const DATA_DIR := "res://data"
const DAMAGE_TYPES := ["physical", "signal", "spirit", "reason", "arcane"]
const STATS := ["reason", "charm", "grit", "intuition"]

var classes: Dictionary = {}
var roster: Dictionary = {}
var foes: Dictionary = {}
var cases: Dictionary = {}


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
