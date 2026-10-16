class_name MapTalk
extends PanelTalk
## The case map: every story, its areas and rooms, and the roads between
## them, for jumping straight to any part of the game. Opened with M.

signal travel(map_id: String, room_id: String)
signal drive(leg_id: String)

const ORDER := ["sutton", "point_pleasant", "sandown", "kelly"]

var _case := ""
var _map := ""
var _items: Array = []


func _init(p_box: DialogueBox, p_toast: Callable) -> void:
	super(p_box, "The case map", p_toast)


func _show() -> void:
	_items = []
	var opts := []
	if _case == "":
		for cid in _cases():
			var c: Dictionary = GameData.cases[cid]
			var n := _maps_of(cid).size()
			_items.append({"kind": "case", "id": cid})
			opts.append({"label": "%s: %s (%d areas)" % [c.get("name", cid.capitalize()), c.get("place", ""), n], "enabled": true})
		_menu("Every story in the casebook. Where to?", opts)
	elif _map == "":
		var c: Dictionary = GameData.cases[_case]
		var lead: Dictionary = {}
		if _case == GameState.case_id:
			lead = Investigation.current_lead(GameData, GameState, 0.3)
		for mid in _maps_of(_case):
			var m: Dictionary = GameData.maps[mid]
			_items.append({"kind": "map", "id": mid})
			var tag := ""
			if not lead.is_empty() and str(c.get("districts", {}).get(lead.get("district", ""), {}).get("map", "")) == mid:
				tag = "  ▸ next: " + str(lead.get("title", ""))
			elif _case == GameState.case_id and not Investigation.map_open(GameData, GameState, mid, 0.3):
				tag = "  (not yet)"
			opts.append({"label": "%s (%d rooms)%s" % [m.get("name", mid), m.get("interiors", {}).size(), tag], "enabled": true})
		for lid in GameData.road.get("legs", {}):
			var leg: Dictionary = GameData.road.legs[lid]
			if leg.get("from", "") == _case:
				_items.append({"kind": "leg", "id": lid})
				opts.append({"label": "Drive: " + str(leg.get("name", lid)), "enabled": true})
		_items.append({"kind": "back"})
		opts.append({"label": "Back to the stories.", "enabled": true})
		_menu("%s, %s. Which area?" % [c.get("name", _case.capitalize()), c.get("place", "")], opts)
	else:
		var m: Dictionary = GameData.maps[_map]
		_items.append({"kind": "go", "map": _map, "room": ""})
		opts.append({"label": "Outside, at the start of " + str(m.get("name", _map)), "enabled": true})
		for rid in m.get("interiors", {}):
			var room: Dictionary = m.interiors[rid]
			_items.append({"kind": "go", "map": _map, "room": rid})
			opts.append({"label": str(room.get("name", rid.capitalize().replace("_", " "))), "enabled": true})
		_items.append({"kind": "back"})
		opts.append({"label": "Back to the areas.", "enabled": true})
		_menu("%s. Which room?" % m.get("name", _map), opts)


func _on_option(i: int) -> void:
	if i < 0 or i >= _items.size():
		return
	var it: Dictionary = _items[i]
	match it.kind:
		"case":
			_case = it.id
			_show()
		"map":
			_map = it.id
			_show()
		"leg":
			var lid: String = it.id
			_end()
			drive.emit(lid)
		"go":
			var mid: String = it.map
			var rid: String = it.room
			_end()
			travel.emit(mid, rid)
		"back":
			if _map != "":
				_map = ""
			else:
				_case = ""
			_show()


func _on_cancel() -> void:
	if _map != "":
		_map = ""
		_show()
	elif _case != "":
		_case = ""
		_show()
	else:
		_end()


func _cases() -> Array:
	var out := []
	for cid in ORDER:
		if GameData.cases.has(cid):
			out.append(cid)
	for cid in GameData.cases:
		if not out.has(cid):
			out.append(cid)
	return out


func _maps_of(cid: String) -> Array:
	var out := []
	var c: Dictionary = GameData.cases[cid]
	for did in c.get("districts", {}):
		var mid: String = str(c.districts[did].get("map", ""))
		if GameData.maps.has(mid) and not out.has(mid):
			out.append(mid)
	for mid in GameData.maps:
		if str(GameData.maps[mid].get("case", "")) == cid and not out.has(mid):
			out.append(mid)
	return out
