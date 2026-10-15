class_name BattleRules
extends RefCounted
## The rules of a fight: who is in it, whose turn it is, what a move does.
## Pure logic over dictionaries and a RandomNumberGenerator, so the headless
## tests can run whole battles with no scene. The Battle scene only draws.
##
## A combatant is a Dictionary: {key, id, name, side ("party" | "foe"), level,
## composure, max_composure, focus, max_focus, stats, speed, statuses {name: turns},
## wait (turn order), broken, guarding, and for foes attack, weak, resist, moves,
## anomaly, tells, phase, turns, known}.

const STATUSES := ["unnerved", "blinded", "jammed", "cursed", "bound", "exposed", "marked", "counter", "ward", "charged", "haste"]
const METHODS := ["photograph", "record", "read"]
const METHOD_NAMES := {"photograph": "Photograph it", "record": "Record it", "read": "Read it"}
const STATUS_TURNS := {"unnerved": 3, "blinded": 2, "jammed": 2, "cursed": 3, "bound": 1, "exposed": 99, "marked": 3, "counter": 2, "ward": 3, "charged": 2, "haste": 3}
const METER_MAX := 10
const INSIGHT_MAX := 3
const BASIC_POWER := [5, 8]
const FOCUS_DEFAULT := 3
const STAT_FOR := {"physical": "grit", "signal": "reason", "spirit": "intuition", "reason": "reason", "arcane": "intuition"}


## A party member ready to fight. Nerve is the party's road composure, 0..100:
## at 50 everyone starts a fight half rattled.
static func member(data: Node, state: Node, id: String) -> Dictionary:
	var cls := Investigation.member_class(data, state, id)
	var c: Dictionary = data.classes.get(cls, {})
	var lvl := int(state.levels.get(id, 1))
	var stats := {}
	for s in data.STATS:
		stats[s] = Investigation.member_stat(data, state, id, s)
	var max_comp := int(c.get("composure", 40)) + 4 * (lvl - 1)
	var gear: Dictionary = Investigation.member_gear(data, state, id)
	var cure := false
	for slot in gear:
		var it: Dictionary = data.items.get(gear[slot], {})
		max_comp += int(it.get("composure", 0))
		if it.get("effect", "") == "cure_composure_once_per_fight":
			cure = true
	var nerve: float = 0.5 + 0.5 * clamp(float(state.composure) / 100.0, 0.0, 1.0)
	var name := "You"
	if id != "player":
		var full: String = str(data.roster.get(id, {}).get("name", id))
		var parts := full.split(" ")
		name = parts[1] if full.begins_with("Dr.") and parts.size() > 1 else parts[0]
	return {
		"cure_charm": cure,
		"key": id, "id": id, "name": name, "side": "party", "cls": cls, "level": lvl, "stats": stats,
		"composure": max(1, int(round(max_comp * nerve))), "max_composure": max_comp,
		"focus": int(c.get("focus", 20)) + 2 * (lvl - 1), "max_focus": int(c.get("focus", 20)) + 2 * (lvl - 1),
		"speed": 4 + int(stats.get("intuition", 1)) + lvl / 2, "statuses": {}, "wait": 0.0,
		"broken": false, "guarding": false, "cured": false,
	}


## One foe from data/foes.json; n tells two dogs apart.
static func foe(data: Node, state: Node, id: String, n: int) -> Dictionary:
	var f: Dictionary = data.foes.get(id, {})
	var moves := []
	for m in f.get("moves", ["Attacks"]):
		if m is String:
			moves.append({"name": m, "type": "attack", "damage": "physical"})
		else:
			var d: Dictionary = m.duplicate()
			if not d.has("type"):
				d["type"] = "attack"
			if d.type == "attack" and not d.has("damage"):
				d["damage"] = "physical"
			moves.append(d)
	var tells: Array = f.get("tells", [])
	var known: bool = f.get("known", false) or id in state.flags.get("foes_known", [])
	return {
		"key": "%s_%d" % [id, n], "id": id, "name": f.get("name", id), "side": "foe", "kind": f.get("kind", "animal"),
		"level": int(f.get("level", 1)), "composure": int(f.get("composure", 20)), "max_composure": int(f.get("composure", 20)),
		"attack": f.get("attack", [4, 7]), "xp": int(f.get("xp", 0)), "weak": f.get("weak", []), "resist": f.get("resist", []),
		"moves": moves, "speed": int(f.get("speed", 3 + int(f.get("level", 1)) / 2)), "statuses": {}, "wait": 0.0,
		"anomaly": f.get("kind", "") == "anomaly", "tells": tells, "phase": 0, "turns": int(f.get("turns", 8)),
		"known": known, "broken": false, "guarding": false, "focus": 0, "max_focus": 0, "stats": {},
	}


## The whole fight's state.
static func setup(data: Node, state: Node, foe_ids: Array, field: Dictionary) -> Dictionary:
	var actors := []
	for id in state.party:
		actors.append(member(data, state, id))
	var n := 0
	for id in foe_ids:
		n += 1
		actors.append(foe(data, state, id, n))
	for a in actors:
		a.wait = 100.0 / float(max(1, a.speed))
	var meter: int = min(3, Investigation.standing_evidence(state).size() / 4)
	return {
		"actors": actors, "field": field, "meter": meter, "insight": 0, "round": 0, "turn": 0, "acted": [],
		"captured": [], "evidence": [], "log": [], "over": "", "fled": false,
	}


static func alive(b: Dictionary, side: String) -> Array:
	var out := []
	for a in b.actors:
		if a.side == side and not a.broken:
			out.append(a)
	return out


static func has_anomaly(b: Dictionary) -> bool:
	for a in alive(b, "foe"):
		if a.anomaly:
			return true
	return false


## Whose turn it is next: the lowest wait, everyone's wait shrinking by that much.
static func next_actor(b: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	for a in b.actors:
		if a.broken:
			continue
		if best.is_empty() or a.wait < best.wait:
			best = a
	if best.is_empty():
		return {}
	var w: float = best.wait
	for a in b.actors:
		if not a.broken:
			a.wait -= w
	return best


## The next `n` turns, for the row across the top. Does not change anything.
static func preview(b: Dictionary, n: int) -> Array:
	var sim := []
	for a in b.actors:
		if not a.broken:
			sim.append({"key": a.key, "name": a.name, "side": a.side, "wait": a.wait, "speed": a.speed})
	var out := []
	for i in n:
		if sim.is_empty():
			break
		var best: Dictionary = sim[0]
		for s in sim:
			if s.wait < best.wait:
				best = s
		var w: float = best.wait
		for s in sim:
			s.wait -= w
		best.wait += 100.0 / float(max(1, best.speed))
		out.append({"key": best.key, "name": best.name, "side": best.side})
	return out


## Called after an actor acts: they go to the back of the line, a delay pushes them further.
static func spend_turn(b: Dictionary, a: Dictionary, delay := 1.0) -> void:
	if a.statuses.has("haste"):
		delay *= 0.6
	a.wait += 100.0 / float(max(1, a.speed)) * delay
	a.guarding = false
	b.turn += 1
	if a.side == "party":
		if not a.key in b.acted:
			b.acted.append(a.key)
		var all_acted := true
		for m in alive(b, "party"):
			if not m.key in b.acted:
				all_acted = false
		if all_acted:
			b.acted = []
			b.round += 1
			add_meter(b, 1)
	for s in a.statuses.keys():
		a.statuses[s] -= 1
		if a.statuses[s] <= 0:
			a.statuses.erase(s)


## Start of an actor's turn: curses bite, a bound actor loses the turn. Returns lines.
static func start_turn(b: Dictionary, a: Dictionary) -> Dictionary:
	var lines := []
	var skip := false
	if a.statuses.has("cursed"):
		var dmg := 4
		a.composure = max(0, a.composure - dmg)
		lines.append("%s takes %d from the curse." % [a.name, dmg])
		_check_broken(b, a, lines)
	if a.statuses.has("bound") and not a.broken:
		lines.append("%s is held and loses the turn." % a.name)
		skip = true
	elif a.statuses.has("unnerved") and not a.broken and a.side == "party" and _rng(b).randf() < 0.25:
		lines.append("%s freezes." % a.name)
		skip = true
	return {"lines": lines, "skip": skip}


static func add_meter(b: Dictionary, n: int) -> void:
	b.meter = clamp(b.meter + n, 0, METER_MAX)


static func add_insight(b: Dictionary, n: int) -> void:
	b.insight = clamp(b.insight + n, 0, INSIGHT_MAX)


## The commands a member can give. Each is {id, label, enabled, why, skill?, kind}.
static func commands(data: Node, b: Dictionary, a: Dictionary, state: Node) -> Array:
	var out := [{"id": "attack", "label": "Attack", "enabled": true, "kind": "attack"}]
	var c: Dictionary = data.classes.get(a.cls, {})
	for s in c.get("skills", []):
		if int(s.get("level", 1)) > a.level:
			continue
		var cost := skill_cost(s)
		var ok := true
		var why := ""
		if a.statuses.has("jammed"):
			ok = false
			why = "jammed"
		elif a.focus < cost.focus:
			ok = false
			why = "no focus"
		elif b.meter < cost.evidence:
			ok = false
			why = "no evidence to spend"
		var label: String = s.name
		if cost.evidence > 0:
			label += " (E%d)" % cost.evidence
		elif cost.focus > 0:
			label += " (F%d)" % cost.focus
		if cost.dread > 0:
			label += " +Dread"
		out.append({"id": "skill:" + s.id, "label": label, "enabled": ok, "why": why, "skill": s, "kind": "skill"})
	if has_anomaly(b):
		out.append({"id": "observe", "label": "Observe", "enabled": true, "kind": "observe"})
	var usable := battle_items(data, state)
	out.append({"id": "item", "label": "Item", "enabled": not usable.is_empty(), "why": "nothing in the kit", "kind": "item"})
	out.append({"id": "guard", "label": "Guard", "enabled": true, "kind": "guard"})
	if b.insight >= INSIGHT_MAX:
		out.append({"id": "revelation", "label": "Revelation!", "enabled": true, "kind": "revelation"})
	if not has_anomaly(b) and not b.field.get("no_flee", false):
		out.append({"id": "run", "label": "Run", "enabled": true, "kind": "run"})
	return out


static func skill_cost(s: Dictionary) -> Dictionary:
	var focus := int(s.get("focus_cost", FOCUS_DEFAULT if not s.has("evidence_cost") else 0))
	return {"focus": focus, "evidence": int(s.get("evidence_cost", 0)), "dread": int(s.get("dread_cost", 0))}


## Consumables that do something in a fight.
static func battle_items(data: Node, state: Node) -> Array:
	var out := []
	for id in state.items:
		var it: Dictionary = data.items.get(id, {})
		if it.get("kind", "") != "consumable":
			continue
		if it.get("restore", {}).has("composure") or it.get("effect", "") == "flare_blind_all":
			out.append({"id": id, "name": it.get("name", id), "count": int(state.items[id]), "item": it})
	return out


## Hit chance for an attacker with these statuses.
static func accuracy(a: Dictionary) -> float:
	var acc := 1.0
	if a.statuses.has("unnerved"):
		acc *= 0.7
	if a.statuses.has("blinded"):
		acc *= 0.5
	return acc


## Damage of one hit. `timed` is the timed-hit multiplier (1.25 good, 0.6 blocked, 1 otherwise).
## `opts` may carry `pierce` (ignores guard and resistance) and `execute` (x1.5 under 30%).
static func damage(b: Dictionary, power: Array, stat: int, dtype: String, target: Dictionary, timed := 1.0, opts := {}) -> Dictionary:
	var rng := _rng(b)
	var base := rng.randi_range(int(power[0]), int(power[1])) + stat
	var mult := 1.0
	var weak := false
	var resisted := false
	var pierce: bool = opts.get("pierce", false)
	if dtype in target.get("weak", []):
		mult *= 1.5
		weak = true
	if dtype in target.get("resist", []) and not pierce:
		mult *= 0.5
		resisted = true
	if dtype == "reason" and target.statuses.has("exposed"):
		mult *= 1.5
	if target.statuses.has("marked"):
		mult *= 1.5
	if target.statuses.has("ward") and dtype in ["spirit", "arcane"]:
		mult *= 0.5
	if opts.get("execute", false) and target.composure * 10 < target.max_composure * 3:
		mult *= 1.5
	if target.guarding and not pierce:
		mult *= 0.5
	if b.field.get("weather", "") == "rain" and dtype == "signal":
		mult *= 0.7
	if b.field.get("phase", "") == "night" and not b.field.get("inside", false) and target.side == "party":
		mult *= 1.1
	mult *= timed
	return {"amount": max(1, int(round(base * mult))), "weak": weak, "resisted": resisted}


static func hurt(b: Dictionary, target: Dictionary, amount: int, lines: Array) -> void:
	target.composure = max(0, target.composure - amount)
	_check_broken(b, target, lines)


static func _check_broken(b: Dictionary, a: Dictionary, lines: Array) -> void:
	if a.composure > 0 or a.broken:
		return
	if a.side == "party" and not a.get("cured", false) and a.get("cure_charm", false):
		a.cured = true
		a.composure = a.max_composure / 3
		lines.append("%s's charm holds: back on their feet." % a.name)
		return
	a.broken = true
	a.statuses = {}
	if a.side == "party":
		lines.append("%s breaks and backs into the dark." % a.name)
	elif a.anomaly:
		lines.append("%s is driven off." % a.name)
	else:
		lines.append("%s is down." % a.name)


## A member's basic attack on a foe.
static func basic_attack(b: Dictionary, a: Dictionary, target: Dictionary, timed := 1.0) -> Array:
	var lines := []
	a.focus = min(a.max_focus, a.focus + 3)
	if _rng(b).randf() > accuracy(a):
		lines.append("%s swing%s and miss%s." % [a.name, "" if a.name == "You" else "s", "" if a.name == "You" else "es"])
		return lines
	var d := damage(b, BASIC_POWER, int(a.stats.get("grit", 1)), "physical", target, timed)
	lines.append("%s hit%s %s for %d%s." % [a.name, "" if a.name == "You" else "s", target.name, d.amount, _tag(d, timed)])
	_landed(b, target, d)
	hurt(b, target, d.amount, lines)
	return lines


static func _tag(d: Dictionary, timed: float) -> String:
	var t := ""
	if d.weak:
		t += ", a weak point"
	if d.resisted:
		t += ", shrugged off"
	if timed > 1.0:
		t += ", timed"
	return t


static func _landed(b: Dictionary, target: Dictionary, d: Dictionary) -> void:
	if d.weak:
		target.known = true
		add_meter(b, 1)
		add_insight(b, 1)


## A class skill. Targets: the chosen foe or ally; "all_foes" and "all_allies" ignore the pick.
static func use_skill(data: Node, state: Node, b: Dictionary, a: Dictionary, s: Dictionary, target: Dictionary, timed := 1.0) -> Array:
	var lines := []
	var cost := skill_cost(s)
	a.focus -= cost.focus
	add_meter(b, -cost.evidence)
	if cost.dread > 0:
		state.dread += cost.dread
		lines.append("Dread rises.")
	if s.has("self_damage"):
		hurt(b, a, int(s.self_damage), lines)
		lines.append("%s pays %d composure for it." % [a.name, int(s.self_damage)])
	var targets := []
	match s.get("target", "foe"):
		"all_foes":
			targets = alive(b, "foe")
		"all_allies":
			targets = alive(b, "party")
		"self":
			targets = [a]
		_:
			targets = [target]
	match s.get("type", "damage"):
		"damage":
			if _rng(b).randf() > accuracy(a):
				lines.append("%s's %s goes wide." % [a.name, s.name])
				return lines
			var power: Array = s.get("power", [6, 9]).duplicate()
			if s.get("scale", "") == "dread":
				power[0] += 2 * state.dread
				power[1] += 2 * state.dread
			var charged: bool = a.statuses.has("charged")
			if charged:
				a.statuses.erase("charged")
			var opts := {"pierce": s.get("pierce", false), "execute": s.get("execute", false)}
			var dtype: String = s.get("damage", "physical")
			var stat := int(a.stats.get(STAT_FOR.get(dtype, "grit"), 1))
			var total := 0
			for t in targets:
				for h in int(s.get("hits", 1)):
					if t.broken:
						break
					var d := damage(b, power, stat, dtype, t, timed * (2.0 if charged else 1.0), opts)
					total += d.amount
					lines.append("%s: %s takes %d%s." % [s.name, t.name, d.amount, _tag(d, timed)])
					_landed(b, t, d)
					hurt(b, t, d.amount, lines)
				if s.has("apply") and not t.broken and _rng(b).randf() < float(s.get("apply_chance", 1.0)):
					var st: String = s.apply
					if not (t.anomaly and st == "bound"):
						t.statuses[st] = int(STATUS_TURNS.get(st, 2))
						lines.append("%s is %s." % [t.name, st])
			if s.has("drain") and total > 0:
				var back := int(round(total * float(s.drain)))
				a.composure = min(a.max_composure, a.composure + back)
				lines.append("%s draws %d of it back." % [a.name, back])
		"status":
			for t in targets:
				var st: String = s.get("status", "exposed")
				if t.anomaly and st == "bound":
					lines.append("%s: it will not be held." % s.name)
					continue
				t.statuses[st] = int(STATUS_TURNS.get(st, 2))
				if st == "exposed":
					t.known = true
				lines.append("%s: %s is %s." % [s.name, t.name, st])
				if s.has("push"):
					t.wait += float(s.push)
					lines.append("%s is slowed." % t.name)
		"heal":
			for t in targets:
				var amt := int(s.get("amount", 10))
				t.composure = min(t.max_composure, t.composure + amt)
				t.statuses.erase("unnerved")
				if s.get("cleanse", false):
					for st in ["unnerved", "blinded", "jammed", "cursed", "bound"]:
						t.statuses.erase(st)
				lines.append("%s: %s steadies by %d%s." % [s.name, t.name, amt, ", clear-headed" if s.get("cleanse", false) else ""])
		"revive":
			var any := false
			for m in b.actors:
				if m.side == "party" and m.broken and (target.is_empty() or m.key == target.key or s.get("target", "") == "all_allies"):
					m.broken = false
					m.composure = max(1, int(m.max_composure * float(s.get("fraction", 0.5))))
					lines.append("%s: %s comes back to the light." % [s.name, m.name])
					any = true
			if not any:
				lines.append("%s: nobody to call back." % s.name)
		"shield":
			for t in targets:
				t.guarding = true
				lines.append("%s: %s is covered." % [s.name, t.name])
	if s.has("focus_gain"):
		for m in alive(b, "party"):
			m.focus = min(m.max_focus, m.focus + int(s.focus_gain))
		lines.append("The party gains %d Focus." % int(s.focus_gain))
	if s.has("evidence_gain"):
		add_meter(b, int(s.evidence_gain))
		lines.append("Evidence +%d." % int(s.evidence_gain))
	return lines


## Observing an anomaly with a method. The right one captures the phase's tell.
static func observe(data: Node, state: Node, b: Dictionary, a: Dictionary, target: Dictionary, method: String) -> Array:
	var lines := []
	if not target.anomaly or target.phase >= target.tells.size():
		lines.append("There is nothing left to catch.")
		return lines
	var tell: Dictionary = target.tells[target.phase]
	if tell.get("method", "") != method:
		lines.append("%s tries to %s. Whatever it is, that was not the way." % [a.name, method])
		hurt(b, a, 4, lines)
		return lines
	if method == "photograph" and b.field.get("weather", "") == "mist" and _rng(b).randf() < 0.5:
		lines.append("The flash lights the fog and nothing else.")
		return lines
	target.phase += 1
	var ev: String = tell.get("evidence", "")
	b.captured.append(tell)
	if ev != "" and not ev in b.evidence:
		b.evidence.append(ev)
	add_meter(b, 2)
	add_insight(b, 1)
	target.known = true
	var weaken := int(target.max_composure * 0.2)
	if target.max_composure > 500:
		weaken = 0
	lines.append("%s %ss it. %s" % [a.name, method, tell.get("text", "")])
	if weaken > 0:
		hurt(b, target, weaken, lines)
	if target.phase >= target.tells.size() and not target.broken:
		lines.append("That is all of it. It knows you have it.")
		target.broken = true
	return lines


## Guard: half damage until the next turn, and a breath of focus.
static func guard(b: Dictionary, a: Dictionary) -> Array:
	a.guarding = true
	a.focus = min(a.max_focus, a.focus + 4)
	return ["%s brace%s." % [a.name, "" if a.name == "You" else "s"]]


## Using a consumable from the kit on a member.
static func use_item(data: Node, state: Node, b: Dictionary, a: Dictionary, item_id: String, target: Dictionary) -> Array:
	var lines := []
	var it: Dictionary = data.items.get(item_id, {})
	if not state.take_item(item_id):
		return ["There are none left."]
	if it.get("restore", {}).has("composure"):
		var amt := int(it.restore.composure)
		target.composure = min(target.max_composure, target.composure + amt)
		target.statuses.erase("unnerved")
		lines.append("%s: %s steadies by %d." % [it.get("name", item_id), target.name, amt])
	if it.get("effect", "") == "flare_blind_all":
		for f in alive(b, "foe"):
			f.statuses["blinded"] = 2
		lines.append("The flare goes up. Everything out there is blinded.")
	return lines


## The Revelation: the party's shared insight breaks on every foe at once.
static func revelation(data: Node, b: Dictionary) -> Array:
	var lines := ["Revelation! The pieces line up."]
	var power := 20
	for m in alive(b, "party"):
		power += m.level * 6
	for f in alive(b, "foe"):
		f.known = true
		var amt := power if not f.anomaly else int(f.max_composure * 0.15)
		if f.max_composure > 500:
			amt = power
		lines.append("%s takes %d." % [f.name, amt])
		hurt(b, f, amt, lines)
	b.insight = 0
	add_meter(b, 2)
	return lines


## Running away: a coin toss weighted by speed. Fails against an anomaly.
static func run(b: Dictionary, a: Dictionary) -> Array:
	if has_anomaly(b) or b.field.get("no_flee", false):
		return ["There is nowhere to run to."]
	var chance := 0.5 + 0.05 * float(a.speed - 6)
	if _rng(b).randf() < chance:
		b.fled = true
		b.over = "fled"
		return ["The party runs for it."]
	return ["%s turns to run and can't." % a.name]


## A foe's turn: pick a move and a target, apply it. `blocked` is the timed block multiplier.
static func foe_turn(b: Dictionary, f: Dictionary, blocked := 1.0) -> Dictionary:
	var lines := []
	var rng := _rng(b)
	var moves: Array = f.moves
	if f.anomaly and f.moves.size() >= f.tells.size() and f.tells.size() > 0:
		moves = [f.moves[min(f.phase, f.moves.size() - 1)]]
		if rng.randf() < 0.4:
			moves = f.moves
	var mv: Dictionary = moves[rng.randi_range(0, moves.size() - 1)]
	var party := alive(b, "party")
	if party.is_empty():
		return {"lines": lines, "move": mv, "target": ""}
	var target: Dictionary = party[rng.randi_range(0, party.size() - 1)]
	if rng.randf() < 0.3:
		for m in party:
			if m.composure < target.composure:
				target = m
	if mv.has("text"):
		lines.append(mv.text)
	if rng.randf() > accuracy(f):
		lines.append("%s: %s. It misses." % [f.name, mv.name])
		return {"lines": lines, "move": mv, "target": target.key}
	match mv.get("type", "attack"):
		"attack":
			var d := damage(b, mv.get("power", f.attack), f.level / 2, mv.get("damage", "physical"), target, blocked)
			lines.append("%s: %s. %s takes %d%s." % [f.name, mv.name, target.name, d.amount, ", blocked" if blocked < 1.0 else ""])
			hurt(b, target, d.amount, lines)
			if target.statuses.has("counter") and not target.broken:
				var c := damage(b, BASIC_POWER, int(target.stats.get("grit", 1)) + 2, "physical", f)
				lines.append("%s was waiting for that: %s takes %d." % [target.name, f.name, c.amount])
				_landed(b, f, c)
				hurt(b, f, c.amount, lines)
		"horror":
			var d := damage(b, mv.get("power", f.attack), f.level / 2, "spirit", target, blocked)
			lines.append("%s: %s. %s loses %d composure." % [f.name, mv.name, target.name, d.amount])
			hurt(b, target, d.amount, lines)
			if not target.broken and rng.randf() < 0.3:
				target.statuses["unnerved"] = STATUS_TURNS.unnerved
				lines.append("%s is unnerved." % target.name)
		"all":
			for m in party:
				var d := damage(b, mv.get("power", [3, 5]), f.level / 3, mv.get("damage", "physical"), m, blocked if m.key == target.key else 1.0)
				lines.append("%s: %s. %s takes %d." % [f.name, mv.name, m.name, d.amount])
				hurt(b, m, d.amount, lines)
				if mv.has("status") and not m.broken and rng.randf() < 0.5:
					m.statuses[mv.status] = int(STATUS_TURNS.get(mv.status, 2))
		"status":
			var st: String = mv.get("status", "unnerved")
			target.statuses[st] = int(STATUS_TURNS.get(st, 2))
			lines.append("%s: %s. %s is %s." % [f.name, mv.name, target.name, st])
	return {"lines": lines, "move": mv, "target": target.key}


## Checks whether the fight is over and says how: "won", "lost", "fled", "lasted" or "".
static func outcome(b: Dictionary) -> String:
	if b.over != "":
		return b.over
	if alive(b, "party").is_empty():
		b.over = "lost"
	elif alive(b, "foe").is_empty():
		b.over = "won"
	else:
		for f in alive(b, "foe"):
			if f.anomaly and b.round >= f.turns:
				b.over = "lasted"
	return b.over


## After the fight: XP, levels, the banked evidence, the party's nerve, who broke.
static func settle(data: Node, state: Node, b: Dictionary) -> Dictionary:
	var result := {"outcome": outcome(b), "levelups": [], "xp": 0, "evidence": b.evidence.duplicate(), "broken": [], "banked": 0}
	var won: bool = result.outcome in ["won", "lasted"]
	var xp := 0
	var pct := 0.0
	var members := 0
	for a in b.actors:
		if a.side == "foe":
			if won and (a.broken or a.anomaly):
				xp += a.xp
			if a.known and not a.id in state.flags.get("foes_known", []):
				var known: Array = state.flags.get("foes_known", [])
				known.append(a.id)
				state.flags["foes_known"] = known
		else:
			members += 1
			pct += float(a.composure) / float(max(1, a.max_composure))
			if a.broken:
				result.broken.append(a.id)
				var unreliable: Array = state.flags.get("unreliable", [])
				if not a.id in unreliable:
					unreliable.append(a.id)
				state.flags["unreliable"] = unreliable
	if won:
		result.xp = xp
		for a in b.actors:
			if a.side == "party" and not a.broken:
				var lv := gain_xp(state, a.id, xp)
				if lv > 0:
					result.levelups.append({"id": a.id, "name": a.name, "level": lv})
		for ev in b.evidence:
			if Investigation.case_data(data, state).get("evidence", {}).has(ev):
				Investigation.gain_evidence(data, state, ev)
		result.banked = b.meter
		var key: String = "banked_" + str(state.case_id)
		state.flags[key] = int(state.flags.get(key, 0)) + b.meter
	if members > 0:
		state.composure = clamp(int(round(100.0 * pct / float(members))), 5, Investigation.max_composure(data, state))
	if result.outcome == "lost":
		state.dread = min(10, state.dread + 1)
		state.composure = max(5, state.composure)
	return result


## XP toward the next level: level * 20. Returns the new level, or 0.
static func gain_xp(state: Node, id: String, amount: int) -> int:
	var lvl := int(state.levels.get(id, 1))
	var xp := int(state.xp.get(id, 0)) + amount
	var new_level := 0
	while xp >= lvl * 20 and lvl < 30:
		xp -= lvl * 20
		lvl += 1
		new_level = lvl
	state.levels[id] = lvl
	state.xp[id] = xp
	return new_level


static func _rng(b: Dictionary) -> RandomNumberGenerator:
	if not b.has("_rng"):
		b["_rng"] = RandomNumberGenerator.new()
	return b._rng
