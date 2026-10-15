class_name Investigation
## The rules of the day: speech checks, gated witness facts, contradictions,
## physical clues, lab results and sleeping. Pure logic over GameData and
## GameState, so the headless tests can drive it with no scene.

const TAG_STAT := {
	"logic": "reason", "press": "charm", "tech": "reason", "lore": "intuition",
	"empathy": "intuition", "intimidate": "grit", "arcana": "intuition",
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


## Best value of an investigation stat across the party.
static func party_stat(data: Node, state: Node, stat: String) -> int:
	var best := 0
	for member in state.party:
		var c: Dictionary = data.classes.get(member_class(data, state, member), {})
		best = max(best, int(c.get("stats", {}).get(stat, 0)))
	return best


## True when someone in the party has this speech skill.
static func has_specialist(data: Node, state: Node, tag: String) -> bool:
	for member in state.party:
		if data.classes.get(member_class(data, state, member), {}).get("speech", "") == tag:
			return true
	return false


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
	state.day += 1
	state.dread += 1
	return results


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
