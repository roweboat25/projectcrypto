extends Node
## Loads the game's content from res://data. Everything a case needs (classes,
## foes, leads, evidence) lives in JSON so new cases are data, not code.

const DATA_DIR := "res://data"
const DAMAGE_TYPES := ["physical", "signal", "spirit", "reason", "arcane"]
const STATS := ["reason", "charm", "grit", "intuition"]
const SPEECH_TAGS := ["logic", "press", "tech", "lore", "empathy", "intimidate", "arcana"]
const VOICES := ["logic", "tech", "recall", "press", "rapport", "bluff", "nerve", "intimidate", "fieldcraft", "empathy", "lore", "arcana"]
const PHASES := ["morning", "day", "dusk", "night"]
const TONES := ["kind", "hard", "wry", "silent"]

var classes: Dictionary = {}
var roster: Dictionary = {}
var foes: Dictionary = {}
var cases: Dictionary = {}
var maps: Dictionary = {}
var items: Dictionary = {}
var dialogue: Dictionary = {}   # case id -> witness id -> script


func _ready() -> void:
	load_all()


func load_all() -> void:
	classes = _strip(_read_json(DATA_DIR + "/classes.json"))
	roster = _strip(_read_json(DATA_DIR + "/roster.json"))
	foes = _strip(_read_json(DATA_DIR + "/foes.json"))
	items = _strip(_read_json(DATA_DIR + "/items.json"))
	cases.clear()
	var dir := DirAccess.open(DATA_DIR + "/cases")
	if dir:
		for file in dir.get_files():
			if file.ends_with(".json"):
				var c: Dictionary = _read_json(DATA_DIR + "/cases/" + file)
				var cid: String = c.get("id", file.get_basename())
				_merge_fragments(c, DATA_DIR + "/cases/" + cid)
				for item_id in c.get("items", {}):
					items[item_id] = c.items[item_id]
				cases[cid] = c
	dialogue.clear()
	var ddir := DirAccess.open(DATA_DIR + "/dialogue")
	if ddir:
		for cid in ddir.get_directories():
			dialogue[cid] = {}
			var cdir := DirAccess.open(DATA_DIR + "/dialogue/" + cid)
			for file in cdir.get_files():
				if file.ends_with(".json"):
					var d: Dictionary = _strip(_read_json(DATA_DIR + "/dialogue/%s/%s" % [cid, file]))
					dialogue[cid][d.get("id", file.get_basename())] = d
	maps.clear()
	var mdir := DirAccess.open(DATA_DIR + "/maps")
	if mdir:
		for file in mdir.get_files():
			if file.ends_with(".json"):
				var m: Dictionary = _strip(_read_json(DATA_DIR + "/maps/" + file))
				maps[m.get("id", file.get_basename())] = m


## A case can be split into data/cases/<id>/*.json fragments, one per district:
## dictionaries merge by key, lists append.
func _merge_fragments(c: Dictionary, dir_path: String) -> void:
	var fdir := DirAccess.open(dir_path)
	if fdir == null:
		return
	var files := fdir.get_files()
	files.sort()
	for file in files:
		if not file.ends_with(".json"):
			continue
		var f: Dictionary = _read_json(dir_path + "/" + file)
		for k in f:
			if k.begins_with("_"):
				continue
			if f[k] is Dictionary:
				if not c.has(k):
					c[k] = {}
				for kk in f[k]:
					c[k][kk] = f[k][kk]
			elif f[k] is Array:
				if not c.has(k):
					c[k] = []
				c[k].append_array(f[k])
			else:
				c[k] = f[k]


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
		var tags: Array = VOICES
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
		for gid in c.get("gates", {}):
			var g: Dictionary = c.gates[gid]
			if g.get("opens", []).is_empty():
				errors.append("case %s gate %s has no way through" % [case_id, gid])
			for cond in g.get("opens", []):
				if cond.has("item") and not items.has(cond.item):
					errors.append("case %s gate %s needs unknown item %s" % [case_id, gid, cond.item])
				if cond.has("trust") and not c.get("witnesses", {}).has(cond.trust.get("npc", "")):
					errors.append("case %s gate %s trusts an unknown witness" % [case_id, gid])
				if cond.has("check") and not cond.check.get("voice", "") in VOICES:
					errors.append("case %s gate %s has an unknown voice" % [case_id, gid])
				if cond.has("class") and not classes.has(cond.get("class")):
					errors.append("case %s gate %s has an unknown class" % [case_id, gid])
				if cond.has("evidence") and not evidence.has(cond.evidence):
					errors.append("case %s gate %s needs unknown evidence" % [case_id, gid])
		for did in c.get("districts", {}):
			if not maps.has(c.districts[did].get("map", "")):
				errors.append("case %s district %s has an unknown map" % [case_id, did])
		for wid in dialogue.get(case_id, {}):
			errors.append_array(_validate_script(case_id, wid, dialogue[case_id][wid], evidence))
	for map_id in maps:
		var m: Dictionary = maps[map_id]
		var c: Dictionary = cases.get(m.get("case", ""), {})
		var evidence: Dictionary = c.get("evidence", {})
		var building_ids := []
		for b in m.get("facades", []) + m.get("houses", []):
			building_ids.append(b.id)
			if b.has("gate") and not c.get("gates", {}).has(b.gate):
				errors.append("map %s building %s uses unknown gate %s" % [map_id, b.id, b.gate])
		for iid in m.get("interiors", {}):
			if not iid in building_ids:
				errors.append("map %s interior %s has no facade or house" % [map_id, iid])
		for e in m.get("exits", []):
			if not maps.has(e.get("to", "")):
				errors.append("map %s has an exit to unknown map %s" % [map_id, e.get("to")])
			if e.has("gate") and not c.get("gates", {}).has(e.gate):
				errors.append("map %s exit uses unknown gate %s" % [map_id, e.gate])
		var props: Array = m.get("props", []).duplicate()
		var npcs: Array = m.get("npcs", []).duplicate()
		for iid in m.get("interiors", {}):
			props += m.interiors[iid].get("props", [])
			npcs += m.interiors[iid].get("npcs", [])
		for p in props:
			if p.has("pickup") and not items.has(p.pickup):
				errors.append("map %s prop %s picks up unknown item %s" % [map_id, p.kind, p.pickup])
			if p.has("gate") and not c.get("gates", {}).has(p.gate):
				errors.append("map %s prop %s uses unknown gate %s" % [map_id, p.kind, p.gate])
		for n in npcs:
			for ph in n.get("when", []):
				if not ph in PHASES:
					errors.append("map %s npc %s has unknown phase %s" % [map_id, n.id, ph])
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


func _validate_script(case_id: String, wid: String, d: Dictionary, evidence: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var nodes: Dictionary = d.get("nodes", {})
	var where := "dialogue %s/%s" % [case_id, wid]
	if not nodes.has(d.get("start", "")):
		errors.append(where + " has no start node")
	for nid in nodes:
		var n: Dictionary = nodes[nid]
		var w := "%s node %s" % [where, nid]
		if n.get("lines", []).is_empty() and not n.has("line"):
			errors.append(w + " has no lines")
		for p in n.get("passives", []):
			if not p.get("voice", "") in VOICES:
				errors.append(w + " passive has an unknown voice")
		if n.has("next") and not nodes.has(n.next):
			errors.append(w + " next is missing")
		if n.get("gives", {}).has("evidence") and not evidence.has(n.gives.evidence):
			errors.append(w + " gives missing evidence")
		for o in n.get("options", []):
			if o.get("topics", false) or o.get("show", false) or o.get("leave", false):
				continue
			if o.has("tone") and not o.tone in TONES:
				errors.append(w + " option has an unknown tone")
			if o.has("next") and not nodes.has(o.next):
				errors.append(w + " option next is missing")
			if o.has("check"):
				if not o.check.get("voice", "") in VOICES:
					errors.append(w + " check has an unknown voice")
				if not nodes.has(o.get("pass", "")):
					errors.append(w + " check pass node is missing")
				if o.check.get("kind", "white") == "red" and not o.has("fail"):
					errors.append(w + " red check has no fail branch")
				if o.has("fail") and o.fail.has("next") and not nodes.has(o.fail.next):
					errors.append(w + " fail next is missing")
				for e in o.check.get("evidence_bonus", {}):
					if not evidence.has(e):
						errors.append(w + " evidence bonus names missing evidence")
			elif not o.has("next"):
				errors.append(w + " option goes nowhere")
			if o.get("gives", {}).has("evidence") and not evidence.has(o.gives.evidence):
				errors.append(w + " option gives missing evidence")
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
