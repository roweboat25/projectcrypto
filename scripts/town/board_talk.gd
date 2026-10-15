class_name BoardTalk
extends PanelTalk
## The case board in the sorting room: what stands, and filing the verdict.

var _confirm := ""


func _init(p_box: DialogueBox, p_toast: Callable) -> void:
	super(p_box, "The case board", p_toast)


func _show() -> void:
	var c: Dictionary = Investigation.case_data(GameData, GameState)
	var totals: Dictionary = Investigation.lean_totals(GameData, GameState)
	var rating := Investigation.case_rating(GameData, GameState)
	var filed: Dictionary = GameState.verdicts.get(GameState.case_id, {})
	if not filed.is_empty():
		_say([["player", "%s is filed: %s, rated %s. It paid %d budget." % [c.get("name", ""), str(filed.lean).capitalize(), filed.rating, int(filed.budget)]]], "end")
		return
	if GameState.evidence.is_empty():
		_say([["player", "The board is bare. %s has nothing pinned to it yet." % c.get("name", "The case")]], "end")
		return
	if _confirm != "":
		_menu("File %s as %s? That closes the case." % [c.get("name", ""), _confirm.capitalize()],
			[{"label": "File it.", "enabled": true}, {"label": "Not yet.", "enabled": true}])
		return
	var opts := []
	for lean in GameData.LEANS:
		opts.append({"label": "File as %s (%d)" % [lean.capitalize(), int(totals[lean])], "enabled": true})
	opts.append({"label": "Leave it pinned.", "enabled": true})
	_menu("%s: %d cards stand, rating %s. Hoax %d · Natural %d · Unexplained %d." % [c.get("name", ""), Investigation.standing_evidence(GameState).size(), rating, totals.hoax, totals.natural, totals.unexplained], opts)


func _on_option(i: int) -> void:
	if _confirm != "":
		if i == 0:
			var v := Investigation.file_verdict(GameData, GameState, _confirm)
			var lines := [["player", "Filed. %s: %s. Rating %s." % [Investigation.case_data(GameData, GameState).get("name", ""), _confirm.capitalize(), v.rating]],
				["player", "The Office pays %d budget point%s for it." % [int(v.budget), "" if int(v.budget) == 1 else "s"]]]
			if v.has("relic"):
				lines.append(["player", "Something came back with the file: %s." % GameData.items[v.relic].get("name", v.relic)])
			toast.call("Verdict filed: +%d budget" % int(v.budget))
			_say(lines, "end")
		else:
			_confirm = ""
			_show()
		return
	if i < GameData.LEANS.size():
		_confirm = GameData.LEANS[i]
		_show()
	else:
		_end()
