class_name TravelTalk
extends PanelTalk
## The station wagon with more than one road out: pick the leg.

signal chosen(leg_id: String)

var legs: Array = []


func _init(p_box: DialogueBox, p_legs: Array, p_toast: Callable) -> void:
	legs = p_legs
	super(p_box, "The station wagon", p_toast)


func _show() -> void:
	var opts := []
	for id in legs:
		var leg: Dictionary = GameData.road.get("legs", {}).get(id, {})
		var to: String = GameData.cases.get(leg.get("to", ""), {}).get("place", leg.get("to", "").capitalize())
		opts.append({"label": "%s: %s, about %d hours" % [leg.get("name", id), to, int(leg.get("hours", 4))], "enabled": not leg.is_empty()})
	opts.append({"label": "Stay a while.", "enabled": true})
	_menu("Where to? The tank is %d of 6 and there is $%d in the glove box." % [GameState.gas, GameState.cash], opts)


func _on_option(i: int) -> void:
	if i >= legs.size():
		_end()
		return
	var id: String = legs[i]
	_end()
	chosen.emit(id)
