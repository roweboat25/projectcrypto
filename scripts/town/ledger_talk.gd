class_name LedgerTalk
extends PanelTalk
## The Office ledger: budget points become rooms, tools and car upgrades.

var _ids: Array = []


func _init(p_box: DialogueBox, p_toast: Callable) -> void:
	super(p_box, "The Office ledger", p_toast)


func _show() -> void:
	_ids = []
	var opts := []
	for table in ["upgrades", "car"]:
		for id in GameData.office.get(table, {}):
			var u: Dictionary = GameData.office[table][id]
			_ids.append(id)
			var done: bool = GameState.flags.get(u.get("flag", ""), false)
			var label := "%s%s  %d pt  (tier %d)" % ["[done] " if done else "", u.get("name", id), int(u.get("cost", 0)), int(u.get("tier", 1))]
			if table == "car":
				label = "Car: " + label
			opts.append({"label": label, "enabled": not done})
	opts.append({"label": "Close the ledger", "enabled": true})
	_menu("Budget: %d points to spend, tier %d (%d earned)." % [GameState.budget, Investigation.budget_tier(GameData, GameState), GameState.budget_earned], opts)


func _on_option(i: int) -> void:
	if i >= _ids.size():
		_end()
		return
	var why := Investigation.buy_upgrade(GameData, GameState, _ids[i])
	var u: Dictionary = GameData.office.get("upgrades", {}).get(_ids[i], GameData.office.get("car", {}).get(_ids[i], {}))
	if why == "":
		_say([["player", u.get("text", "Done.")]])
		toast.call("Bought: " + u.get("name", _ids[i]))
	else:
		toast.call(why)
		_show()
