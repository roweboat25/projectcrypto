class_name ShopTalk
extends PanelTalk
## A counter: everything the shop stocks, priced, paid from the party's cash.

var shop_id: String
var can_talk := false      # the shopkeeper is also a witness
var wants_talk := false    # set when the party picks "Ask about something else"
var _ids: Array = []


func _init(p_box: DialogueBox, p_shop: String, p_speaker: String, p_toast: Callable, p_portrait := "") -> void:
	super(p_box, p_speaker, p_toast, p_portrait)
	shop_id = p_shop


func _show() -> void:
	_ids = GameData.shop_stock(shop_id)
	var opts := []
	for id in _ids:
		var it: Dictionary = GameData.items[id]
		var have := int(GameState.items.get(id, 0))
		var label := "%s  $%d" % [it.get("name", id), int(it.get("price", 0))]
		if have > 0:
			label += "  (have %d)" % have
		var can: bool = GameState.cash >= int(it.get("price", 0)) and not (it.get("reusable", false) and have > 0)
		opts.append({"label": label, "enabled": can, "text": it.get("text", "")})
	if can_talk:
		opts.append({"label": "Ask about something else.", "enabled": true})
	opts.append({"label": "That's all.", "enabled": true})
	_menu("Cash $%d.  What'll it be?" % GameState.cash, opts)


func _on_option(i: int) -> void:
	if i >= _ids.size():
		wants_talk = can_talk and i == _ids.size()
		_end()
		return
	var id: String = _ids[i]
	var why := Investigation.buy(GameData, GameState, id)
	if why == "":
		toast.call("Bought %s. $%d left." % [GameData.items[id].get("name", id), GameState.cash])
	else:
		toast.call(why)
	_show()
