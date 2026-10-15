extends Node
## Loads the game's content from res://data. Everything a case needs (classes,
## foes, leads, evidence) lives in JSON so new cases are data, not code.

const DATA_DIR := "res://data"
const DAMAGE_TYPES := ["physical", "signal", "spirit", "reason", "arcane"]
const STATS := ["reason", "charm", "grit", "intuition"]
const SPEECH_TAGS := ["logic", "press", "tech", "lore", "empathy", "intimidate", "arcana"]
const ITEM_KINDS := ["kit", "consumable", "tool", "coat", "charm", "relic"]
const VOICES := ["logic", "tech", "recall", "press", "rapport", "bluff", "nerve", "intimidate", "fieldcraft", "empathy", "lore", "arcana"]
const PHASES := ["morning", "day", "dusk", "night"]
const TONES := ["kind", "hard", "wry", "silent"]
const LEANS := ["hoax", "natural", "unexplained"]
const TIDES := ["low", "rising", "high", "falling"]
const WEATHERS := ["snow", "clear", "mist", "rain", "gale"]
const USES := ["board", "ledger", "catalog", "radio_log", "shop", "dials", "siege"]
const MOVE_TYPES := ["attack", "horror", "status", "all"]
const STATUSES := ["unnerved", "blinded", "jammed", "cursed", "bound", "exposed", "marked", "counter", "ward", "charged", "haste"]
const SKILL_TYPES := ["damage", "status", "heal", "shield", "revive"]
const SKILL_TARGETS := ["foe", "ally", "self", "all_foes", "all_allies"]
const OBSERVE_METHODS := ["photograph", "record", "read"]

var classes: Dictionary = {}
var roster: Dictionary = {}
var foes: Dictionary = {}
var cases: Dictionary = {}
var maps: Dictionary = {}
var items: Dictionary = {}
var dialogue: Dictionary = {}   # case id -> witness id -> script
var office: Dictionary = {}     # data/office.json: rooms, upgrades, car, tiers, budget
var road: Dictionary = {}       # data/road.json: legs, events, stations


func _ready() -> void:
	load_all()


func load_all() -> void:
	classes = _strip(_read_json(DATA_DIR + "/classes.json"))
	roster = _strip(_read_json(DATA_DIR + "/roster.json"))
	foes = _strip(_read_json(DATA_DIR + "/foes.json"))
	items = _strip(_read_json(DATA_DIR + "/items.json"))
	office = _strip(_read_json(DATA_DIR + "/office.json")) if FileAccess.file_exists(DATA_DIR + "/office.json") else {}
	road = _strip(_read_json(DATA_DIR + "/road.json")) if FileAccess.file_exists(DATA_DIR + "/road.json") else {}
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


## An evidence card by id, from the case named first, then any case.
func evidence(case_id: String, id: String) -> Dictionary:
	if cases.get(case_id, {}).get("evidence", {}).has(id):
		return cases[case_id].evidence[id]
	for c in cases.values():
		if c.get("evidence", {}).has(id):
			return c.evidence[id]
	return {}


## A gate by id, from any case: gate ids are unique across the game.
func gate(gate_id: String) -> Dictionary:
	for c in cases.values():
		if c.get("gates", {}).has(gate_id):
			return c.gates[gate_id]
	return {}


## A witness's scripted conversation, from the case given first, then any case.
func script(case_id: String, witness_id: String) -> Dictionary:
	if dialogue.get(case_id, {}).has(witness_id):
		return dialogue[case_id][witness_id]
	for cid in dialogue:
		if dialogue[cid].has(witness_id):
			return dialogue[cid][witness_id]
	return {}


## The item ids a shop sells, cheapest first within each kind.
func shop_stock(shop_id: String) -> Array:
	var out: Array = []
	for id in items:
		if shop_id in items[id].get("shop", []):
			out.append(id)
	out.sort_custom(func(a, b):
		var ka: int = ITEM_KINDS.find(items[a].get("kind", "kit"))
		var kb: int = ITEM_KINDS.find(items[b].get("kind", "kit"))
		return ka < kb if ka != kb else int(items[a].get("price", 0)) < int(items[b].get("price", 0)))
	return out


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
			if not skill.get("type", "damage") in SKILL_TYPES:
				errors.append("class %s skill %s has unknown type %s" % [id, skill.id, skill.type])
			if not skill.get("target", "foe") in SKILL_TARGETS:
				errors.append("class %s skill %s has unknown target %s" % [id, skill.id, skill.target])
			for k in ["status", "apply"]:
				if skill.has(k) and not skill[k] in STATUSES:
					errors.append("class %s skill %s has unknown status %s" % [id, skill.id, skill[k]])
	for id in roster:
		if not classes.has(roster[id].get("class", "")):
			errors.append("roster %s has unknown class" % id)
	var all_evidence := {}
	for case_id in cases:
		all_evidence.merge(cases[case_id].get("evidence", {}))
	for id in foes:
		var f: Dictionary = foes[id]
		for t in f.get("weak", []) + f.get("resist", []):
			if not t in DAMAGE_TYPES:
				errors.append("foe %s has unknown damage type %s" % [id, t])
		for m in f.get("moves", []):
			if m is Dictionary:
				if not m.get("type", "attack") in MOVE_TYPES:
					errors.append("foe %s move %s has unknown type %s" % [id, m.get("name"), m.type])
				if m.has("damage") and not m.damage in DAMAGE_TYPES:
					errors.append("foe %s move %s has unknown damage type" % [id, m.get("name")])
				if m.has("status") and not m.status in STATUSES:
					errors.append("foe %s move %s has unknown status %s" % [id, m.get("name"), m.status])
		if f.get("kind", "") == "anomaly" and f.get("tells", []).is_empty():
			errors.append("anomaly %s has no tells to observe" % id)
		for t in f.get("tells", []):
			if not t.get("method", "") in OBSERVE_METHODS:
				errors.append("foe %s tell has unknown method %s" % [id, t.get("method")])
			if t.has("evidence") and not all_evidence.has(t.evidence):
				errors.append("foe %s tell gives unknown evidence %s" % [id, t.evidence])
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
				if cond.has("tide") and not cond.tide in TIDES:
					errors.append("case %s gate %s has an unknown tide" % [case_id, gid])
				if cond.has("tide") and not c.has("tide"):
					errors.append("case %s gate %s reads a tide the case does not have" % [case_id, gid])
				if cond.has("signs") and int(cond.signs) > c.get("trail", []).size():
					errors.append("case %s gate %s asks for more signs than the trail has" % [case_id, gid])
		for did in c.get("districts", {}):
			if not maps.has(c.districts[did].get("map", "")):
				errors.append("case %s district %s has an unknown map" % [case_id, did])
		if c.has("siege"):
			errors.append_array(_validate_siege(case_id, c.siege, evidence))
		for wid in dialogue.get(case_id, {}):
			errors.append_array(_validate_script(case_id, wid, dialogue[case_id][wid], evidence))
	for map_id in maps:
		var m: Dictionary = maps[map_id]
		var c: Dictionary = cases.get(m.get("case", ""), {})
		var evidence: Dictionary = c.get("evidence", {})
		var building_ids := []
		if m.has("weather") and not m.weather in WEATHERS:
			errors.append("map %s has unknown weather %s" % [map_id, m.weather])
		for b in m.get("facades", []) + m.get("houses", []):
			building_ids.append(b.id)
			if b.has("gate") and gate(b.gate).is_empty():
				errors.append("map %s building %s uses unknown gate %s" % [map_id, b.id, b.gate])
			if b.has("appears") and gate(b.appears).is_empty():
				errors.append("map %s building %s appears on unknown gate %s" % [map_id, b.id, b.appears])
		var entered := []
		for iid in m.get("interiors", {}):
			for p in m.interiors[iid].get("props", []):
				if p.has("enter"):
					entered.append(p.enter)
		for iid in m.get("interiors", {}):
			if not iid in building_ids and not iid in entered:
				errors.append("map %s interior %s has no facade, house or door into it" % [map_id, iid])
		for e in m.get("exits", []):
			if not maps.has(e.get("to", "")):
				errors.append("map %s has an exit to unknown map %s" % [map_id, e.get("to")])
			if e.has("gate") and gate(e.gate).is_empty():
				errors.append("map %s exit uses unknown gate %s" % [map_id, e.gate])
		var props: Array = m.get("props", []).duplicate()
		var npcs: Array = m.get("npcs", []).duplicate()
		for iid in m.get("interiors", {}):
			props += m.interiors[iid].get("props", [])
			npcs += m.interiors[iid].get("npcs", [])
		for e in m.get("encounters", []):
			errors.append_array(_validate_fight(map_id, "encounter", e))
			for ph in e.get("phase", []):
				if not ph in PHASES:
					errors.append("map %s encounter has unknown phase %s" % [map_id, ph])
		for p in props:
			if p.has("fight"):
				errors.append_array(_validate_fight(map_id, "prop " + str(p.get("kind")), p.fight))
			if p.has("pickup") and not items.has(p.pickup):
				errors.append("map %s prop %s picks up unknown item %s" % [map_id, p.kind, p.pickup])
			if p.has("gate") and gate(p.gate).is_empty():
				errors.append("map %s prop %s uses unknown gate %s" % [map_id, p.kind, p.gate])
			if p.has("appears") and gate(p.appears).is_empty():
				errors.append("map %s prop %s appears on unknown gate %s" % [map_id, p.kind, p.appears])
			if p.has("use") and not p.use in USES:
				errors.append("map %s prop %s has unknown use %s" % [map_id, p.kind, p.use])
			if p.has("enter") and not m.get("interiors", {}).has(p.enter):
				errors.append("map %s prop %s enters unknown room %s" % [map_id, p.kind, p.enter])
			if p.get("use", "") == "dials" and (not p.has("puzzle") or p.puzzle.get("order", []).is_empty()):
				errors.append("map %s dials prop has no puzzle order" % map_id)
			if p.has("travel"):
				for leg_id in (p.travel if p.travel is Array else [p.travel]):
					if not road.get("legs", {}).has(leg_id):
						errors.append("map %s prop %s drives unknown leg %s" % [map_id, p.kind, leg_id])
		for n in npcs:
			if n.has("fight"):
				errors.append_array(_validate_fight(map_id, "npc " + str(n.get("id")), n.fight))
			if n.has("appears") and gate(n.appears).is_empty():
				errors.append("map %s npc %s appears on unknown gate %s" % [map_id, n.id, n.appears])
			if n.has("shop") and shop_stock(n.shop).is_empty():
				errors.append("map %s npc %s runs shop %s with no stock" % [map_id, n.id, n.shop])
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
	for id in items:
		var it: Dictionary = items[id]
		if not it.get("kind", "") in ITEM_KINDS:
			errors.append("item %s has unknown kind %s" % [id, it.get("kind")])
		if it.get("kind") == "tool" and not classes.has(it.get("class", "")):
			errors.append("item %s is a tool with no class" % id)
		for st in it.get("stat", {}):
			if not st in STATS:
				errors.append("item %s boosts unknown stat %s" % [id, st])
		for v in it.get("voice", {}):
			if not v in VOICES:
				errors.append("item %s boosts unknown voice %s" % [id, v])
		if it.get("kind") == "relic" and (not cases.has(it.get("case", "")) or not it.get("verdict", "") in LEANS):
			errors.append("item %s relic needs a case and a verdict" % id)
	for uid in office.get("upgrades", {}).keys() + office.get("car", {}).keys():
		var u: Dictionary = office.get("upgrades", {}).get(uid, office.get("car", {}).get(uid, {}))
		if not u.has("cost") or not u.has("flag"):
			errors.append("office upgrade %s needs cost and flag" % uid)
	var events: Dictionary = road.get("events", {})
	var stations: Dictionary = road.get("stations", {})
	for lid in road.get("legs", {}):
		var leg: Dictionary = road.legs[lid]
		if not maps.has(leg.get("arrive_map", "")):
			errors.append("road leg %s arrives at unknown map" % lid)
		for st in leg.get("stops", []):
			for e in st.get("events", []):
				if not events.has(e):
					errors.append("road leg %s names unknown event %s" % [lid, e])
		for e in leg.get("deck", []):
			if not events.has(e):
				errors.append("road leg %s deck names unknown event %s" % [lid, e])
		for st in leg.get("stations", []):
			if not stations.has(st):
				errors.append("road leg %s names unknown station %s" % [lid, st])
	for eid in events:
		if events[eid].get("options", []).is_empty():
			errors.append("road event %s has no options" % eid)
		for o in events[eid].get("options", []):
			if o.has("check") and not o.check.get("voice", "") in VOICES:
				errors.append("road event %s check has unknown voice" % eid)
			for gv in [o.get("gives", {}), o.get("fail", {}).get("gives", {})]:
				if gv.has("item") and not items.has(gv.item):
					errors.append("road event %s gives unknown item %s" % [eid, gv.item])
	for sid in stations:
		if not stations[sid].get("kind", "") in ["local", "callin", "numbers", "tone"]:
			errors.append("road station %s has unknown kind" % sid)
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
## The siege table: approaches with carried items, waves with known foes, flashback answers in range.
func _validate_siege(case_id: String, s: Dictionary, evidence: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var w := "case %s siege" % case_id
	for ap in s.get("approaches", {}):
		var item: String = s.approaches[ap].get("prep", {}).get("item", "")
		if item != "" and not items.has(item):
			errors.append("%s approach %s needs unknown item %s" % [w, ap, item])
	if s.get("waves", []).is_empty():
		errors.append("%s has no waves" % w)
	for wave in s.get("waves", []):
		errors.append_array(_validate_fight(case_id, "siege wave", wave))
		if not s.get("approaches", {}).has(wave.get("from", "")):
			errors.append("%s wave comes from unknown approach %s" % [w, wave.get("from")])
		var fb: Dictionary = wave.get("flashback", {})
		if fb.has("question"):
			if int(fb.get("answer", -1)) < 0 or int(fb.get("answer", -1)) >= fb.get("options", []).size():
				errors.append("%s flashback answer is out of range" % w)
			if fb.has("evidence") and not evidence.has(fb.evidence):
				errors.append("%s flashback gives unknown evidence %s" % [w, fb.evidence])
	if s.has("lull"):
		errors.append_array(_validate_fight(case_id, "siege lull", s.lull.get("out", {})))
		if s.lull.get("out", {}).has("evidence") and not evidence.has(s.lull.out.evidence):
			errors.append("%s lull gives unknown evidence" % w)
	if s.has("final"):
		errors.append_array(_validate_fight(case_id, "siege final", s.final))
	if s.get("held", "") != "" and not evidence.has(s.held):
		errors.append("%s held evidence %s is unknown" % [w, s.held])
	return errors


## A fight spec on a prop, person or encounter: one to four known foes.
func _validate_fight(map_id: String, where: String, f: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not f is Dictionary:
		errors.append("map %s %s fight is not a table" % [map_id, where])
		return errors
	var list: Array = f.get("foes", [])
	if list.is_empty() or list.size() > 4:
		errors.append("map %s %s fight needs 1 to 4 foes" % [map_id, where])
	for id in list:
		if not foes.has(id):
			errors.append("map %s %s fights unknown foe %s" % [map_id, where, id])
	return errors


func _strip(d: Variant) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = d.duplicate()
	out.erase("_doc")
	return out
