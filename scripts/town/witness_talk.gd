class_name WitnessTalk
extends RefCounted
## One conversation with a townsperson: their open statement, then the menu of
## speech checks, contradictions and evidence to show, until the player leaves.

signal finished

var box: DialogueBox
var witness_id: String
var witness_name: String
var case: Dictionary
var toast: Callable
var _options: Array = []
var _picker: Array = []     # evidence ids in the show-evidence menu
var _mode := "open"         # open, menu, picker, fact, done
var _pending_fact: Dictionary = {}


func _init(p_box: DialogueBox, p_witness: String, p_name: String, p_toast: Callable) -> void:
	box = p_box
	witness_id = p_witness
	witness_name = p_name
	toast = p_toast
	case = Investigation.case_data(GameData, GameState)
	box.lines_finished.connect(_on_lines_finished)
	box.option_picked.connect(_on_option)
	box.cancelled.connect(_on_cancel)


func start() -> void:
	var lines: Array = []
	for lead in case.get("leads", []):
		if lead.get("speaker") == witness_id:
			lines = lead.lines.duplicate()
			if lead.has("evidence") and not GameState.has_evidence(lead.evidence):
				Investigation.gain_evidence(GameData, GameState, lead.evidence)
				_announce(lead.evidence)
			break
	if lines.is_empty():
		lines = [[witness_id, "Cold night. You're not from around here."]]
	_mode = "open"
	box.show_lines(lines)


func _on_lines_finished() -> void:
	match _mode:
		"open", "fact":
			if _pending_fact.is_empty() and not case.get("witnesses", {}).has(witness_id):
				_end()
			else:
				_pending_fact = {}
				_show_menu()
		"result":
			_show_menu()
		"done":
			_end()


func _show_menu() -> void:
	_mode = "menu"
	_options = Investigation.witness_options(GameData, GameState, witness_id)
	box.show_menu("What do you want to do?", witness_name, _options, witness_id)


func _on_option(i: int) -> void:
	if _mode == "picker":
		_present(_picker[i])
		return
	if _mode != "menu":
		return
	var o: Dictionary = _options[i]
	match o.kind:
		"leave":
			_mode = "done"
			box.show_lines([[witness_id, _goodbye()]])
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
		"show":
			_mode = "picker"
			_picker = GameState.evidence.duplicate()
			var opts := []
			for id in _picker:
				opts.append({"label": GameData.evidence(GameState.case_id, id).get("title", id), "enabled": true})
			box.show_menu("Show them what?", "Evidence", opts)


func _present(evidence_id: String) -> void:
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
	_pending_fact = fact
	box.show_lines(fact.lines)


func _announce(evidence_id: String) -> void:
	var e: Dictionary = GameData.evidence(GameState.case_id, evidence_id)
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
