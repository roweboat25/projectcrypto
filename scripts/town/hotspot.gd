extends Area2D
## An inspectable prop: Look text, something to pick up, or a gated barrier.

var data: Dictionary
var key := ""       # "map:index", remembered in GameState.picked once taken


func setup(p: Dictionary, p_key: String) -> void:
	data = p
	key = p_key
	add_to_group("interactable")
	set_meta("hotspot", true)
	if p.has("gate"):
		set_meta("prompt", str(p.get("name", "Gate")))
	elif p.has("pickup"):
		set_meta("prompt", "Take " + str(GameData.items.get(p.pickup, {}).get("name", p.pickup)))
	else:
		set_meta("prompt", "Look" + (" at the " + str(p.name).to_lower() if p.has("name") else ""))
