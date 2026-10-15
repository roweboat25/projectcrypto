class_name Siege
extends RefCounted
## A lair that is a night held in a house: the case's `siege` table, run from a prop
## with "use": "siege". Dusk is preparation (spend what you carried on the approaches
## the trail pinned), then the waves, each followed by a flashback whose change in the
## story is evidence if you catch it, a lull at two in the morning, and the thing on the
## roof at first light. The town lends it narration, menus and fights.

var spec: Dictionary
var prepared: Dictionary = {}
var pinned: Dictionary = {}


func _init(p_spec: Dictionary) -> void:
	spec = p_spec


## Which approaches the trail has pinned: the sign clue for each is logged.
static func pins(data: Node, state: Node, spec: Dictionary) -> Dictionary:
	var c := Investigation.case_data(data, state)
	var out := {}
	for ap in spec.get("approaches", {}):
		var sign: String = spec.approaches[ap].get("sign", "")
		out[ap] = sign == "" or Investigation.sign_logged(data, state, c, sign)
	return out


## The preparation menu: one line per approach, enabled when pinned and the item is carried.
static func prep_options(data: Node, state: Node, spec: Dictionary, pinned: Dictionary, prepared: Dictionary) -> Array:
	var opts := []
	for ap in spec.get("approaches", {}):
		var a: Dictionary = spec.approaches[ap]
		var prep: Dictionary = a.get("prep", {})
		var item: String = prep.get("item", "")
		var item_name: String = data.items.get(item, {}).get("name", item)
		var label: String = prep.get("text", "Prepare " + a.get("name", ap))
		var ok := true
		if prepared.get(ap, false):
			label += " (done)"
			ok = false
		elif not pinned.get(ap, false):
			label += " (no sign points here)"
			ok = false
		elif item != "" and not state.has_item(item):
			label += " (no %s)" % item_name.to_lower()
			ok = false
		opts.append({"label": label, "enabled": ok, "approach": ap})
	opts.append({"label": "Let the night come.", "enabled": true, "approach": ""})
	return opts


## Runs the whole night. `town` provides narrate(lines), ask(title, options) -> int and
## fight(spec) -> result, each awaitable.
func run(town, data: Node, state: Node) -> void:
	if state.flags.get(spec.get("flag", "siege_survived"), false) or state.flags.get(spec.get("lose_flag", "siege_broken"), false):
		await town.narrate([["narrator", "That night is over. Whatever it was, it is not coming back for a second look."]])
		return
	await town.narrate(spec.get("intro", [["narrator", "Dusk."]]))
	pinned = pins(data, state, spec)
	var names := []
	for ap in pinned:
		if pinned[ap]:
			names.append(spec.approaches[ap].get("name", ap).to_lower())
	if names.is_empty():
		await town.narrate([["narrator", "The trail pinned nothing. Every way in is open tonight."]])
	else:
		await town.narrate([["narrator", "The signs point at " + ", ".join(names) + ". Those can be shut."]])
	while true:
		var opts := prep_options(data, state, spec, pinned, prepared)
		var i: int = await town.ask("Dusk. Prepare the house.", opts)
		if i < 0 or opts[i].approach == "":
			break
		var ap: String = opts[i].approach
		var prep: Dictionary = spec.approaches[ap].get("prep", {})
		if prep.get("item", "") != "":
			state.take_item(prep.item)
		prepared[ap] = true
		await town.narrate([["narrator", prep.get("done", "Done.")]])
	var held := true
	var n := 0
	for wave in spec.get("waves", []):
		n += 1
		var from: String = wave.get("from", "")
		var ready: bool = prepared.get(from, false)
		var lines := [["narrator", wave.get("text", "They come.")]]
		if ready:
			lines.append(["narrator", "But %s is ready for them. They come in slow, and fewer." % spec.approaches.get(from, {}).get("name", from).to_lower()])
		await town.narrate(lines)
		var foes: Array = wave.get("foes", []).duplicate()
		if ready and foes.size() > 1:
			foes.pop_back()
		var r: Dictionary = await town.fight({"foes": foes, "no_flee": true, "handicap": 0.6 if ready else 1.0, "win": wave.get("win", "The yard is empty again. For now.")})
		if not r.outcome in ["won", "lasted"]:
			held = false
			break
		var fb: Dictionary = wave.get("flashback", {})
		if not fb.is_empty():
			await town.narrate(fb.get("lines", []))
			if fb.has("question"):
				var qopts := []
				for o in fb.get("options", []):
					qopts.append({"label": o, "enabled": true})
				var pick: int = await town.ask(fb.question, qopts)
				if pick == int(fb.get("answer", -1)):
					var ev: String = fb.get("evidence", "")
					if ev != "":
						Investigation.gain_evidence(data, state, ev)
						await town.narrate([["narrator", "Caught it. Logged: %s." % Investigation.case_data(data, state).get("evidence", {}).get(ev, {}).get("title", ev)]])
				else:
					await town.narrate([["narrator", "It slips past you. The telling goes on."]])
		if n == 2 and spec.has("lull"):
			await _lull(town, data, state)
	if held and spec.has("final"):
		var f: Dictionary = spec.final
		var r: Dictionary = await town.fight({"foes": f.get("foes", []), "no_flee": true, "intro": f.get("intro", ""), "win": f.get("win", ""), "lose": f.get("lose", "")})
		held = r.outcome in ["won", "lasted"]
	if held:
		state.flags[spec.get("flag", "siege_survived")] = true
		if spec.get("held", "") != "":
			Investigation.gain_evidence(data, state, spec.held)
		await town.narrate([["narrator", spec.get("outro", "Dawn. The house held.")]])
	else:
		state.flags[spec.get("lose_flag", "siege_broken")] = true
		await town.narrate([["narrator", spec.get("broken", "The house did not hold. You remember the road, and the sun coming up on it.")]])


func _lull(town, data: Node, state: Node) -> void:
	var lull: Dictionary = spec.lull
	await town.narrate([["narrator", lull.get("text", "Quiet.")]])
	var out: Dictionary = lull.get("out", {})
	var stay: Dictionary = lull.get("stay", {})
	var opts := [{"label": out.get("text", "Step outside"), "enabled": true}, {"label": stay.get("text", "Stay in"), "enabled": true}]
	var i: int = await town.ask("Two in the morning.", opts)
	if i == 0:
		var r: Dictionary = await town.fight({"foes": out.get("foes", []), "no_flee": true, "intro": out.get("intro", ""), "win": out.get("win", "You get back to the door.")})
		if r.outcome in ["won", "lasted"] and out.get("evidence", "") != "":
			Investigation.gain_evidence(data, state, out.evidence)
			await town.narrate([["narrator", "Logged: %s." % Investigation.case_data(data, state).get("evidence", {}).get(out.evidence, {}).get("title", out.evidence)]])
	else:
		await town.narrate([["narrator", stay.get("done", "You wait.")]])
