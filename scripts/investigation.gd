class_name Investigation
## The rules of the day: speech checks, gated witness facts, contradictions,
## physical clues, lab results and sleeping. Pure logic over GameData and
## GameState, so the headless tests can drive it with no scene.

const TAG_STAT := {
	"logic": "reason", "tech": "reason", "recall": "reason",
	"press": "charm", "rapport": "charm", "bluff": "charm",
	"nerve": "grit", "intimidate": "grit", "fieldcraft": "grit",
	"empathy": "intuition", "lore": "intuition", "arcana": "intuition",
}
## The inner voices each class is strong in (the bible's "class that boosts it").
const CLASS_VOICES := {
	"skeptic": ["logic", "bluff"], "journalist": ["press", "rapport", "bluff"], "signals": ["tech"],
	"folklorist": ["recall", "lore"], "crypto": ["nerve", "intimidate", "fieldcraft"],
	"medium": ["empathy"], "occultist": ["arcana"],
}
const VOICE_NAMES := {
	"logic": "LOGIC", "tech": "TECH", "recall": "RECALL", "press": "PRESS", "rapport": "RAPPORT", "bluff": "BLUFF",
	"nerve": "NERVE", "intimidate": "INTIMIDATE", "fieldcraft": "FIELDCRAFT", "empathy": "EMPATHY", "lore": "LORE",
	"arcana": "ARCANA", "static": "THE STATIC",
}
const SPECIALIST_BONUS := 2
const METHODS := ["photograph", "bag", "cast", "measure"]
const METHOD_VERBS := {"photograph": "Photograph it", "bag": "Bag a sample", "cast": "Take a plaster cast", "measure": "Take a reading"}


static func case_data(data: Node, state: Node) -> Dictionary:
	return data.cases.get(state.case_id, {})


## The class id of a party member: the player's own, or the partner's roster class.
static func member_class(data: Node, state: Node, member: String) -> String:
	if member == "player":
		return state.player_class
	return data.roster.get(member, {}).get("class", "")


## Best value of an investigation stat across the party, gear included.
static func party_stat(data: Node, state: Node, stat: String) -> int:
	var best := 0
	for member in state.party:
		best = max(best, member_stat(data, state, member, stat))
	return best


## One member's stat: the class value plus what they wear.
static func member_stat(data: Node, state: Node, member: String, stat: String) -> int:
	var c: Dictionary = data.classes.get(member_class(data, state, member), {})
	var v := int(c.get("stats", {}).get(stat, 0))
	for id in member_gear(data, state, member).values():
		v += int(data.items.get(id, {}).get("stat", {}).get(stat, 0))
	return v


const SLOTS := ["tool", "coat", "charm1", "charm2"]


## What a member has equipped: the class's issue tool and the Office trench by default.
static func member_gear(data: Node, state: Node, member: String) -> Dictionary:
	var g: Dictionary = state.gear.get(member, {})
	var out := {}
	for slot in SLOTS:
		out[slot] = g.get(slot, "")
	if out.tool == "":
		var cls := member_class(data, state, member)
		for id in data.items:
			if data.items[id].get("kind") == "tool" and data.items[id].get("tier") == "issue" and data.items[id].get("class") == cls:
				out.tool = id
	if out.coat == "" and data.items.has("office_trench"):
		out.coat = "office_trench"
	return out


## True when the item can go in the slot for this member.
static func fits(data: Node, state: Node, member: String, slot: String, item_id: String) -> bool:
	var it: Dictionary = data.items.get(item_id, {})
	match slot:
		"tool":
			return it.get("kind") == "tool" and it.get("class") == member_class(data, state, member)
		"coat":
			return it.get("kind") == "coat"
		_:
			return it.get("kind") in ["charm", "relic"]


## Moves an item from the field kit into a slot; what was there goes back to the kit.
static func equip(data: Node, state: Node, member: String, slot: String, item_id: String) -> bool:
	if not fits(data, state, member, slot, item_id) or not state.take_item(item_id):
		return false
	var g: Dictionary = state.gear.get(member, {})
	var old: String = member_gear(data, state, member).get(slot, "")
	if old != "":
		state.add_item(old)
	g[slot] = item_id
	state.gear[member] = g
	return true


## Max composure: 100 plus the coat and charms of everyone in the party.
static func max_composure(data: Node, state: Node) -> int:
	var v := 100
	for member in state.party:
		for id in member_gear(data, state, member).values():
			v += int(data.items.get(id, {}).get("composure", 0))
	return v


## Buys one of an item for cash. Returns "" or the reason it failed.
static func buy(data: Node, state: Node, item_id: String) -> String:
	var it: Dictionary = data.items.get(item_id, {})
	var price := int(it.get("price", 0))
	if state.cash < price:
		return "Not enough cash."
	if it.get("reusable", false) and state.has_item(item_id):
		return "You already have one."
	state.cash -= price
	state.add_item(item_id)
	return ""


## Drinks the coffee: consumables restore composure or settle dread.
static func use_consumable(data: Node, state: Node, item_id: String) -> String:
	var it: Dictionary = data.items.get(item_id, {})
	if it.get("kind") != "consumable" or not state.take_item(item_id):
		return "Nothing to use."
	var r: Dictionary = it.get("restore", {})
	state.composure = clamp(state.composure + int(r.get("composure", 0)), 0, max_composure(data, state))
	state.dread = max(0, state.dread + int(r.get("dread", 0)))
	return "Used " + it.get("name", item_id)


## True when someone in the party has this speech skill.
static func has_specialist(data: Node, state: Node, tag: String) -> bool:
	for member in state.party:
		var cls := member_class(data, state, member)
		if data.classes.get(cls, {}).get("speech", "") == tag or tag in CLASS_VOICES.get(cls, []):
			return true
	return false


## The lead's own level in a voice: their stat, +2 when their class boosts it,
## +1 for each partner in the room whose class boosts it, less Dread.
static func voice_level(data: Node, state: Node, voice: String) -> int:
	var stat: String = TAG_STAT.get(voice, "reason")
	var lead_class := member_class(data, state, state.party[0] if not state.party.is_empty() else "player")
	var lead: String = state.party[0] if not state.party.is_empty() else "player"
	var level := member_stat(data, state, lead, stat)
	for id in member_gear(data, state, lead).values():
		level += int(data.items.get(id, {}).get("voice", {}).get(voice, 0))
	if voice in CLASS_VOICES.get(lead_class, []):
		level += SPECIALIST_BONUS
	for i in range(1, state.party.size()):
		if voice in CLASS_VOICES.get(member_class(data, state, state.party[i]), []):
			level += 1
	if state.dread >= 5:
		level -= 2
	elif state.dread >= 3:
		level -= 1
	return level


## A passive is a quiet check with no dice: the voice level plus 3 (a cautious
## roll) against the threshold, so thresholds of 7 to 10 suit levels of 4 to 7.
const PASSIVE_BONUS := 3


static func passive_passes(data: Node, state: Node, voice: String, threshold: int) -> bool:
	return voice_level(data, state, voice) + PASSIVE_BONUS >= threshold


## The day phase for a time of day (0 = 6 AM, 0.25 = noon, 0.75 = midnight).
static func phase(time_of_day: float) -> String:
	var hour := fmod(time_of_day * 24.0 + 6.0, 24.0)
	if hour >= 19.0 or hour < 6.0:
		return "night"
	if hour >= 17.0:
		return "dusk"
	if hour >= 10.0:
		return "day"
	return "morning"


## Case night number: the first night is night 1 of day 1.
static func night_number(state: Node, time_of_day: float) -> int:
	return state.day if phase(time_of_day) == "night" else state.day - 1


static func clue_visible(state: Node, clue: Dictionary, time_of_day: float) -> bool:
	if clue.has("requires") and not state.has_evidence(clue.requires):
		return false
	if int(clue.get("night", 0)) > night_number(state, time_of_day):
		return false
	return true


# ---------- scripted dialogue ----------

static func script_for(data: Node, state: Node, witness_id: String) -> Dictionary:
	return data.script(state.case_id, witness_id)


static func trust_of(data: Node, state: Node, witness_id: String) -> int:
	var w: Dictionary = case_data(data, state).get("witnesses", {}).get(witness_id, {})
	return int(state.trust.get(witness_id, w.get("trust", 0)))


static func option_available(data: Node, state: Node, o: Dictionary) -> bool:
	var req: Dictionary = o.get("requires", {})
	for e in req.get("evidence", []):
		if not state.has_evidence(e):
			return false
	for f in req.get("flag", []):
		if not state.flags.get(f, false):
			return false
	for f in req.get("not_flag", []):
		if state.flags.get(f, false):
			return false
	return true


static func lock_key(witness_id: String, node_id: String, index: int) -> String:
	return "%s:%s:%d" % [witness_id, node_id, index]


static func check_locked(state: Node, key: String) -> bool:
	var when := int(state.locked_checks.get(key, -99))
	return when == -1 or when == state.day


## A scripted check: 2d6 + voice level + evidence bonus + trust modifier against the difficulty.
## White checks lock until tomorrow on a failure; red checks lock for the case.
static func attempt_voice_check(data: Node, state: Node, witness_id: String, key: String, check: Dictionary, roll := -1) -> Dictionary:
	if roll < 0:
		roll = randi_range(1, 6) + randi_range(1, 6)
	var bonus := 0
	for e in check.get("evidence_bonus", {}):
		if state.has_evidence(e):
			bonus += int(check.evidence_bonus[e])
	var trust := clampi(trust_of(data, state, witness_id) - 1, -2, 2)
	var total: int = roll + voice_level(data, state, check.voice) + bonus + trust
	var difficulty := int(check.get("difficulty", 8))
	var ok := total >= difficulty
	if not ok:
		state.locked_checks[key] = -1 if check.get("kind", "white") == "red" else state.day
	return {"ok": ok, "roll": roll, "total": total, "difficulty": difficulty}


## Applies a node's or option's "gives": evidence, facts, flags, trust, dread, items.
static func apply_gives(data: Node, state: Node, gives: Dictionary) -> Array:
	var announced := []
	if gives.has("evidence") and not state.has_evidence(gives.evidence):
		gain_evidence(data, state, gives.evidence)
		announced.append(gives.evidence)
	if gives.has("fact") and not gives.fact in state.facts:
		state.facts.append(gives.fact)
	if gives.has("flag"):
		state.flags[gives.flag] = true
	for npc in gives.get("trust", {}):
		var w: Dictionary = case_data(data, state).get("witnesses", {}).get(npc, {})
		state.trust[npc] = int(state.trust.get(npc, w.get("trust", 0))) + int(gives.trust[npc])
	if gives.has("dread"):
		state.dread = max(0, state.dread + int(gives.dread))
	if gives.has("item"):
		state.add_item(gives.item)
	if gives.has("cash"):
		state.cash = max(0, state.cash + int(gives.cash))
	if gives.has("gas"):
		state.gas = clamp(state.gas + int(gives.gas), 0, 6)
	if gives.has("composure"):
		state.composure = clamp(state.composure + int(gives.composure), 0, max_composure(data, state))
	return announced


# ---------- gates ----------

## Why a gate is shut, or "" when any of its conditions holds. Check conditions roll once a day.
static func gate_open(data: Node, state: Node, gate_id: String, time_of_day: float) -> bool:
	if gate_id in state.gates_open:
		return true
	var g: Dictionary = data.gate(gate_id)
	for cond in g.get("opens", []):
		if cond.has("item") and state.has_item(cond.item):
			return true
		if cond.has("trust") and trust_of(data, state, cond.trust.get("npc", "")) >= int(cond.trust.get("level", 0)):
			return true
		if cond.has("class") and has_class(data, state, cond.get("class")):
			return true
		if cond.has("flag") and state.flags.get(cond.flag, false):
			return true
		if cond.has("evidence") and state.has_evidence(cond.evidence):
			return true
		if cond.has("phase") and phase(time_of_day) in cond.phase:
			return true
	return false


static func has_class(data: Node, state: Node, cls: String) -> bool:
	for member in state.party:
		if member_class(data, state, member) == cls:
			return true
	return false


## The check a gate offers when it is shut, if any and not already failed today.
static func gate_check(data: Node, state: Node, gate_id: String) -> Dictionary:
	var g: Dictionary = data.gate(gate_id)
	for cond in g.get("opens", []):
		if cond.has("check") and not check_closed(state, "gate:" + gate_id, cond.check.voice):
			return cond.check
	return {}


## Rolls the gate's check; success opens the gate for good.
static func try_gate(data: Node, state: Node, gate_id: String, roll := -1) -> Dictionary:
	var check := gate_check(data, state, gate_id)
	if check.is_empty():
		return {}
	var r := attempt_check(data, state, "gate:" + gate_id, {"check": check.voice, "difficulty": check.difficulty}, roll)
	if r.ok and not gate_id in state.gates_open:
		state.gates_open.append(gate_id)
	return r


static func check_modifier(data: Node, state: Node, tag: String) -> int:
	var total := party_stat(data, state, TAG_STAT.get(tag, "reason"))
	if has_specialist(data, state, tag):
		total += SPECIALIST_BONUS
	return total


static func check_key(fact_id: String, tag: String) -> String:
	return fact_id + ":" + tag


static func check_closed(state: Node, fact_id: String, tag: String) -> bool:
	return int(state.failed_checks.get(check_key(fact_id, tag), -1)) == state.day


## Rolls a speech check: d6 + stat + specialist bonus against the gate's difficulty.
## A fixed roll is used by tests. A failure closes the option until tomorrow.
static func attempt_check(data: Node, state: Node, fact_id: String, gate: Dictionary, roll := -1) -> Dictionary:
	var tag: String = gate.check
	if roll < 0:
		roll = randi_range(1, 6)
	var total := roll + check_modifier(data, state, tag)
	var ok := total >= int(gate.difficulty)
	if not ok:
		state.failed_checks[check_key(fact_id, tag)] = state.day
	return {"ok": ok, "roll": roll, "total": total, "difficulty": int(gate.difficulty)}


static func contradiction_ready(data: Node, state: Node, id: String) -> bool:
	var c: Dictionary = case_data(data, state).get("contradictions", {}).get(id, {})
	for e in c.get("evidence", []):
		if not state.has_evidence(e):
			return false
	return true


## The things the player can do with a witness right now.
static func witness_options(data: Node, state: Node, witness_id: String) -> Array:
	var options := []
	var w: Dictionary = case_data(data, state).get("witnesses", {}).get(witness_id, {})
	var contradictions: Dictionary = case_data(data, state).get("contradictions", {})
	for fact in w.get("facts", []):
		if fact.id in state.facts:
			options.append({"kind": "replay", "fact": fact, "label": "Ask again about " + fact.title, "enabled": true})
			continue
		for gate in fact.gates:
			if gate.has("check"):
				var closed := check_closed(state, fact.id, gate.check)
				options.append({"kind": "check", "fact": fact, "gate": gate, "enabled": not closed,
					"label": "[%s] %s%s" % [gate.check.capitalize(), gate.prompt, "  (closed until tomorrow)" if closed else ""]})
			elif gate.has("contradiction") and contradiction_ready(data, state, gate.contradiction):
				var c: Dictionary = contradictions[gate.contradiction]
				options.append({"kind": "contradiction", "fact": fact, "gate": gate, "enabled": true, "label": "[Contradiction] " + c.prompt})
			elif gate.has("trust") and int(state.trust.get(witness_id, w.get("trust", 0))) >= int(gate.trust):
				options.append({"kind": "trust", "fact": fact, "gate": gate, "enabled": true, "label": "They trust you. Ask about " + fact.title.to_lower()})
	if not state.evidence.is_empty():
		options.append({"kind": "show", "label": "Show evidence...", "enabled": true})
	options.append({"kind": "leave", "label": "Leave", "enabled": true})
	return options


## Showing a piece of evidence to a witness: returns the fact it unlocks, or {}.
static func present(data: Node, state: Node, witness_id: String, evidence_id: String) -> Dictionary:
	var w: Dictionary = case_data(data, state).get("witnesses", {}).get(witness_id, {})
	for fact in w.get("facts", []):
		if fact.id in state.facts:
			continue
		for gate in fact.gates:
			if gate.get("show", "") == evidence_id:
				return fact
	return {}


static func unlock_fact(data: Node, state: Node, fact: Dictionary) -> void:
	if not fact.id in state.facts:
		state.facts.append(fact.id)
	if fact.has("evidence"):
		gain_evidence(data, state, fact.evidence)


## Adds evidence, marks anything it exposes as false, and queues samples for the lab.
static func gain_evidence(data: Node, state: Node, id: String) -> void:
	if state.has_evidence(id):
		return
	state.evidence.append(id)
	var e: Dictionary = case_data(data, state).get("evidence", {}).get(id, {})
	for x in e.get("exposes", []):
		if not x in state.exposed:
			state.exposed.append(x)
	if e.has("lab") and not e.lab in state.samples:
		state.samples.append(e.lab)


## Processing a physical clue with a method. Returns {evidence, spoiled}.
static func process_clue(data: Node, state: Node, clue: Dictionary, method: String) -> Dictionary:
	if clue.id in state.clues_done:
		return {"evidence": "", "spoiled": false}
	state.clues_done.append(clue.id)
	var result: String = clue.methods.get(method, "spoil")
	if result == "spoil":
		for m in clue.methods:
			var e: String = clue.methods[m]
			if e != "spoil" and not e in state.spoiled:
				state.spoiled.append(e)
		return {"evidence": "", "spoiled": true}
	gain_evidence(data, state, result)
	return {"evidence": result, "spoiled": false}


## A night's sleep: the lab returns, Dread rises, failed checks reopen.
static func sleep(data: Node, state: Node) -> Array:
	var results := []
	for id in state.samples:
		gain_evidence(data, state, id)
		results.append(id)
	state.samples = []
	state.failed_checks = {}
	for key in state.locked_checks.keys():
		if int(state.locked_checks[key]) != -1:
			state.locked_checks.erase(key)
	state.day += 1
	state.dread += 1
	return results


## The case rating from what stands: the share of the case's real evidence found,
## less a step for every red herring still believed.
static func case_rating(data: Node, state: Node) -> String:
	var evidence: Dictionary = case_data(data, state).get("evidence", {})
	var real := 0
	var found := 0
	var fooled := 0
	for id in evidence:
		var e: Dictionary = evidence[id]
		if e.get("key", false) or int(e.get("weight", 0)) == 0:
			continue
		if e.get("red_herring", false):
			if id in standing_evidence(state):
				fooled += 1
			continue
		real += 1
		if id in standing_evidence(state):
			found += 1
	var share := (float(found) / float(real) if real > 0 else 0.0) - 0.1 * fooled
	if share >= 0.6:
		return "A"
	if share >= 0.4:
		return "B"
	if share >= 0.2:
		return "C"
	return "D"


## Files the verdict on the current case and pays the budget for it.
static func file_verdict(data: Node, state: Node, lean: String) -> Dictionary:
	var c: Dictionary = case_data(data, state)
	var pay: Dictionary = data.office.get("budget", {"verdict": 1, "truth": 2, "rating_a": 1})
	var rating := case_rating(data, state)
	var points := int(pay.get("verdict", 1))
	var truth: String = c.get("truth", "")
	if truth != "" and lean == truth:
		points += int(pay.get("truth", 2))
	if rating == "A":
		points += int(pay.get("rating_a", 1))
	var v := {"lean": lean, "rating": rating, "budget": points, "day": state.day, "leans": lean_totals(data, state)}
	state.verdicts[state.case_id] = v
	state.budget += points
	state.budget_earned += points
	for id in data.items:
		var it: Dictionary = data.items[id]
		if it.get("kind") == "relic" and it.get("case") == state.case_id and it.get("verdict") == lean:
			state.add_item(id)
			v["relic"] = id
	refresh_office(data, state)
	return v


## The budget tier the Office has reached: 1, 2 or 3.
static func budget_tier(data: Node, state: Node) -> int:
	var tiers: Array = data.office.get("tiers", [0, 4, 8])
	var tier := 1
	for i in tiers.size():
		if state.budget_earned >= int(tiers[i]):
			tier = i + 1
	return tier


## Rooms open by verdicts or tier set their flags here.
static func refresh_office(data: Node, state: Node) -> void:
	for rid in data.office.get("rooms", {}):
		var opens: Dictionary = data.office.rooms[rid].get("opens", {})
		if opens.is_empty():
			continue
		var ok := true
		if opens.has("verdicts") and state.verdicts.size() < int(opens.verdicts):
			ok = false
		if opens.has("tier") and budget_tier(data, state) < int(opens.tier):
			ok = false
		if opens.has("flag") and not state.flags.get(opens.flag, false):
			ok = false
		if ok:
			state.flags["office_" + rid] = true


## An Office or car upgrade: "" when bought, else why not.
static func buy_upgrade(data: Node, state: Node, upgrade_id: String) -> String:
	var u: Dictionary = data.office.get("upgrades", {}).get(upgrade_id, data.office.get("car", {}).get(upgrade_id, {}))
	if u.is_empty():
		return "No such upgrade."
	if state.flags.get(u.get("flag", ""), false):
		return "Already done."
	if budget_tier(data, state) < int(u.get("tier", 1)):
		return "Needs budget tier %d." % int(u.get("tier", 1))
	if state.budget < int(u.get("cost", 0)):
		return "Not enough budget."
	state.budget -= int(u.get("cost", 0))
	state.flags[u.flag] = true
	return ""


## Evidence that still counts: found, not exposed, not spoiled.
static func standing_evidence(state: Node) -> Array:
	var out := []
	for id in state.evidence:
		if not id in state.exposed and not id in state.spoiled:
			out.append(id)
	return out


static func lean_totals(data: Node, state: Node) -> Dictionary:
	var totals := {"hoax": 0, "natural": 0, "unexplained": 0}
	var evidence: Dictionary = case_data(data, state).get("evidence", {})
	for id in standing_evidence(state):
		var e: Dictionary = evidence.get(id, {})
		totals[e.get("lean", "unexplained")] += int(e.get("weight", 0))
	return totals
