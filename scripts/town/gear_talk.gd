class_name GearTalk
extends PanelTalk
## The gear bag: who wears what, and what is in the field kit to swap in.

var _level := "members"
var _member := ""
var _slot := ""
var _ids: Array = []
var _members: Array = []


func _init(p_box: DialogueBox, p_toast: Callable) -> void:
	super(p_box, "Gear", p_toast)


func _name_of(member: String) -> String:
	if member == "player":
		return "You"
	return GameData.roster.get(member, {}).get("name", member.capitalize())


func _item_name(id: String) -> String:
	return GameData.items.get(id, {}).get("name", "(nothing)") if id != "" else "(nothing)"


func _show() -> void:
	match _level:
		"members":
			_members = GameState.party.duplicate()
			var opts := []
			for m in _members:
				var g := Investigation.member_gear(GameData, GameState, m)
				opts.append({"label": "%s: %s, %s" % [_name_of(m), _item_name(g.tool), _item_name(g.coat)], "enabled": true})
			opts.append({"label": "Use something from the kit", "enabled": true})
			opts.append({"label": "Close", "enabled": true})
			_menu("Cash $%d, Composure %d of %d. Who?" % [GameState.cash, GameState.composure, Investigation.max_composure(GameData, GameState)], opts)
		"slots":
			var g := Investigation.member_gear(GameData, GameState, _member)
			var opts := []
			for slot in Investigation.SLOTS:
				opts.append({"label": "%s: %s" % [slot.capitalize().trim_suffix("1").trim_suffix("2"), _item_name(g[slot])], "enabled": true})
			opts.append({"label": "Back", "enabled": true})
			var stats := []
			for st in GameData.STATS:
				stats.append("%s %d" % [st.capitalize().left(3), Investigation.member_stat(GameData, GameState, _member, st)])
			_menu("%s: %s" % [_name_of(_member), ", ".join(stats)], opts)
		"items":
			_ids = []
			var opts := []
			for id in GameState.items:
				if Investigation.fits(GameData, GameState, _member, _slot, id):
					_ids.append(id)
					var it: Dictionary = GameData.items[id]
					opts.append({"label": "%s  %s" % [it.get("name", id), it.get("text", "")], "enabled": true})
			opts.append({"label": "Back", "enabled": true})
			_menu("Put what in the %s slot?" % _slot.trim_suffix("1").trim_suffix("2"), opts)
		"use":
			_ids = []
			var opts := []
			for id in GameState.items:
				if GameData.items.get(id, {}).get("kind") == "consumable":
					_ids.append(id)
					opts.append({"label": "%s x%d  %s" % [GameData.items[id].get("name", id), int(GameState.items[id]), GameData.items[id].get("text", "")], "enabled": true})
			opts.append({"label": "Back", "enabled": true})
			_menu("Use what?", opts)


func _on_option(i: int) -> void:
	match _level:
		"members":
			if i < _members.size():
				_member = _members[i]
				_level = "slots"
			elif i == _members.size():
				_level = "use"
			else:
				_end()
				return
		"slots":
			if i < Investigation.SLOTS.size():
				_slot = Investigation.SLOTS[i]
				_level = "items"
			else:
				_level = "members"
		"items":
			if i < _ids.size():
				if Investigation.equip(GameData, GameState, _member, _slot, _ids[i]):
					toast.call("%s takes the %s." % [_name_of(_member), GameData.items[_ids[i]].get("name", "")])
			_level = "slots"
		"use":
			if i < _ids.size():
				toast.call(Investigation.use_consumable(GameData, GameState, _ids[i]))
			else:
				_level = "members"
	_show()


func _on_cancel() -> void:
	match _level:
		"members":
			_end()
		"slots", "use":
			_level = "members"
			_show()
		"items":
			_level = "slots"
			_show()
