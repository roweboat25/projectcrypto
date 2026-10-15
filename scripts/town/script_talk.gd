class_name ScriptTalk
extends RefCounted
## A scripted conversation from data/dialogue: nodes of lines with inner-voice
## passives, tones, white and red checks that fail forward, and a hub that can
## fold in the witness's quick facts, the evidence picker and leaving.

signal finished

var box: DialogueBox
var witness_id: String
var witness_name: String
var case: Dictionary
var scr: Dictionary
var toast: Callable
var _node_id := ""
var _mode := "lines"        # lines, menu, picker, fact, result, done
var _options: Array = []    # menu entries: {label, enabled, kind, ...}
var _picker: Array = []
var _after_lines := ""      # node to go to when the current lines end


func _init(p_box: DialogueBox, p_witness: String, p_name: String, p_toast: Callable) -> void:
	box = p_box
	witness_id = p_witness
	witness_name = p_name
	toast = p_toast
	case = Investigation.case_data(GameData, GameState)
	scr = Investigation.script_for(GameData, GameState, witness_id)
	box.lines_finished.connect(_on_lines_finished)
	box.option_picked.connect(_on_option)
	box.cancelled.connect(_on_cancel)


func start() -> void:
	_go(scr.get("start", ""))


## Plays a node: its lines, the passives the lead's voices pass, the Static, then its gives.
func _go(node_id: String) -> void:
	var nodes: Dictionary = scr.get("nodes", {})
	if not nodes.has(node_id):
		_end()
		return
	_node_id = node_id
	var n: Dictionary = nodes[node_id]
	var key := "%s:%s" % [witness_id, node_id]
	var seen_today := int(GameState.visited.get(key, -1)) == GameState.day
	GameState.visited[key] = GameState.day
	var lines: Array = []
	if n.has("line"):
		lines.append([n.get("speaker", witness_id), n.line])
	for l in n.get("lines", []):
		if GameData.roster.has(l[0]) and not l[0] in GameState.party:
			continue
		lines.append(l)
	for p in n.get("passives", []):
		if Investigation.passive_passes(GameData, GameState, p.voice, int(p.get("threshold", 8))):
			lines.append(["voice:" + p.voice, p.line])
			if p.has("flag"):
				GameState.flags[p.flag] = true
	if n.has("static") and GameState.dread >= int(n.static.get("min_dread", 3)):
		lines.append(["voice:static", n.static.line])
	if not seen_today or n.get("repeat", false) or n.get("options", []).is_empty():
		for e in Investigation.apply_gives(GameData, GameState, n.get("gives", {})):
			_announce(e)
	_after_lines = ""
	if n.get("end", false):
		_mode = "done"
	elif not n.get("options", []).is_empty():
		_mode = "lines"
	elif n.has("next"):
		_mode = "lines"
		_after_lines = n.next
	else:
		_mode = "done"
	if seen_today and not n.get("options", []).is_empty() and not n.get("repeat", false):
		_show_menu()   # a hub already heard today goes straight to its choices
		return
	box.show_lines(lines)


func _on_lines_finished() -> void:
	match _mode:
		"lines":
			if _after_lines != "":
				_go(_after_lines)
			else:
				_show_menu()
		"fact", "result":
			_show_menu()
		"done":
			_end()


func _show_menu() -> void:
	_mode = "menu"
	_options = []
	var n: Dictionary = scr.nodes[_node_id]
	for i in n.get("options", []).size():
		var o: Dictionary = n.options[i]
		if o.get("topics", false):
			for w in Investigation.witness_options(GameData, GameState, witness_id):
				if w.kind in ["leave", "show"]:
					continue
				w["legacy"] = true
				_options.append(w)
		elif o.get("show", false):
			if not GameState.evidence.is_empty():
				_options.append({"kind": "show", "label": o.get("text", "Show evidence..."), "enabled": true})
		elif o.get("leave", false):
			_options.append({"kind": "leave", "label": o.get("text", "Leave"), "enabled": true})
		elif Investigation.option_available(GameData, GameState, o):
			var entry := {"kind": "option", "option": o, "index": i, "enabled": true, "label": ""}
			var label: String = o.get("text", "...")
			if o.has("tone"):
				label = "(%s) %s" % [o.tone, label]
			if o.has("check"):
				var key := Investigation.lock_key(witness_id, _node_id, i)
				var locked := Investigation.check_locked(GameState, key)
				entry.enabled = not locked
				label = "[%s %d] %s%s" % [Investigation.VOICE_NAMES[o.check.voice].capitalize(), int(o.check.get("difficulty", 8)), label,
					"  (locked)" if locked else ("  (one chance)" if o.check.get("kind", "white") == "red" else "")]
			entry.label = label
			_options.append(entry)
	if _options.is_empty():
		_options.append({"kind": "leave", "label": "Leave", "enabled": true})
	box.show_menu(n.get("prompt", ""), witness_name, _options, witness_id)


func _on_option(i: int) -> void:
	if _mode == "picker":
		_present(_picker[i])
		return
	if _mode != "menu":
		return
	var o: Dictionary = _options[i]
	if o.get("legacy", false):
		_legacy(o)
		return
	match o.kind:
		"leave":
			_mode = "done"
			box.show_lines([[witness_id, _goodbye()]])
		"show":
			_mode = "picker"
			_picker = GameState.evidence.duplicate()
			var opts := []
			for id in _picker:
				opts.append({"label": case.evidence.get(id, {}).get("title", id), "enabled": true})
			box.show_menu("Show them what?", "Evidence", opts)
		"option":
			_pick(o.option, o.index)


func _pick(o: Dictionary, index: int) -> void:
	for e in Investigation.apply_gives(GameData, GameState, o.get("gives", {})):
		_announce(e)
	if o.has("trust"):
		Investigation.apply_gives(GameData, GameState, {"trust": {witness_id: int(o.trust)}})
	if o.has("check"):
		var key := Investigation.lock_key(witness_id, _node_id, index)
		var r: Dictionary = Investigation.attempt_voice_check(GameData, GameState, witness_id, key, o.check)
		var voice: String = Investigation.VOICE_NAMES[o.check.voice].capitalize()
		if r.ok:
			toast.call("[%s] passed: %d vs %d" % [voice, r.total, r.difficulty])
			_go(o.pass)
		else:
			toast.call("[%s] failed: %d vs %d" % [voice, r.total, r.difficulty])
			var fail: Dictionary = o.get("fail", {})
			Investigation.apply_gives(GameData, GameState, {"trust": fail.get("trust", {}), "dread": fail.get("dread", 0)})
			if fail.has("next"):
				_go(fail.next)
			else:
				_mode = "result"
				box.show_lines([[witness_id, fail.get("line", _refusal())]])
		return
	if o.has("next"):
		_go(o.next)
	else:
		_show_menu()


## The quick-facts menu entries, handled as WitnessTalk does.
func _legacy(o: Dictionary) -> void:
	match o.kind:
		"replay":
			_mode = "fact"
			box.show_lines(o.fact.lines)
		"check":
			var r: Dictionary = Investigation.attempt_check(GameData, GameState, o.fact.id, o.gate)
			if r.ok:
				toast.call("[%s] passed: %d vs %d" % [o.gate.check.capitalize(), r.total, r.difficulty])
				_unlock(o.fact)
			else:
				toast.call("[%s] failed: %d vs %d" % [o.gate.check.capitalize(), r.total, r.difficulty])
				_mode = "result"
				box.show_lines([[witness_id, _refusal()]])
		"contradiction", "trust":
			_unlock(o.fact)


func _present(evidence_id: String) -> void:
	# a scripted "shows" table on the hub wins; otherwise the quick facts answer
	var n: Dictionary = scr.nodes[_node_id]
	if n.get("shows", {}).has(evidence_id):
		_go(n.shows[evidence_id])
		return
	var fact: Dictionary = Investigation.present(GameData, GameState, witness_id, evidence_id)
	if fact.is_empty():
		_mode = "result"
		box.show_lines([[witness_id, "They look at it, and look away. Nothing."]])
	else:
		_unlock(fact)


func _unlock(fact: Dictionary) -> void:
	Investigation.unlock_fact(GameData, GameState, fact)
	if fact.has("evidence"):
		_announce(fact.evidence)
	_mode = "fact"
	box.show_lines(fact.lines)


func _announce(evidence_id: String) -> void:
	var e: Dictionary = case.get("evidence", {}).get(evidence_id, {})
	toast.call("Evidence: " + e.get("title", evidence_id))


func _on_cancel() -> void:
	if _mode == "picker":
		_show_menu()
	elif _mode == "menu":
		_mode = "done"
		box.show_lines([[witness_id, _goodbye()]])


func _refusal() -> String:
	return ["That's all I've got to say about that.", "Ask me tomorrow. Maybe.", "No. And don't ask again today."][randi() % 3]


func _goodbye() -> String:
	return ["Mind the road out there.", "Lock your doors tonight.", "Good luck. You'll need it."][randi() % 3]


func _end() -> void:
	box.close()
	box.lines_finished.disconnect(_on_lines_finished)
	box.option_picked.disconnect(_on_option)
	box.cancelled.disconnect(_on_cancel)
	finished.emit()
