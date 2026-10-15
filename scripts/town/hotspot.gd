extends Area2D
## An inspectable prop: Look text, something to pick up, or a gated barrier.

var data: Dictionary
var key := ""       # "map:index", remembered in GameState.picked once taken


func setup(p: Dictionary, p_key: String) -> void:
	data = p
	key = p_key
	add_to_group("interactable")
	set_meta("hotspot", true)
	if p.has("fight"):
		set_meta("prompt", str(p.get("name", "Something is there")))
	elif p.has("gate"):
		set_meta("prompt", str(p.get("name", "Gate")))
	elif p.has("use"):
		set_meta("prompt", {"board": "The case board", "ledger": "The Office ledger", "catalog": "The card catalog", "radio_log": "The station log", "shop": "Shop"}.get(p.use, "Use") if not p.has("name") else str(p.name))
	elif p.has("enter"):
		set_meta("prompt", str(p.get("name", "Through")))
	elif p.has("travel") and p.travel is Array:
		set_meta("prompt", str(p.get("name", "The station wagon")))
	elif p.has("travel"):
		set_meta("prompt", "Drive: " + str(GameData.road.get("legs", {}).get(p.travel, {}).get("name", p.travel)))
	elif p.has("pickup") and p.has("price"):
		set_meta("prompt", "Buy %s ($%d)" % [GameData.items.get(p.pickup, {}).get("name", p.pickup), int(p.price)])
	elif p.has("pickup"):
		set_meta("prompt", "Take " + str(GameData.items.get(p.pickup, {}).get("name", p.pickup)))
	else:
		set_meta("prompt", "Look" + (" at the " + str(p.name).to_lower().trim_prefix("the ") if p.has("name") else ""))
