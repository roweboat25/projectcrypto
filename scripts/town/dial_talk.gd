class_name DialTalk
extends PanelTalk
## A wall of dials: turn them in the right order and a door opens. The prop's
## `puzzle` gives the dial `names`, the `order` to turn them in, the `flag` set
## when it is right, and `text` / `done` / `wrong` lines.

var puzzle: Dictionary
var _turned: Array = []


func _init(p_box: DialogueBox, p_name: String, p_puzzle: Dictionary, p_toast: Callable) -> void:
	puzzle = p_puzzle
	super(p_box, p_name, p_toast)


func start() -> void:
	if GameState.flags.get(puzzle.get("flag", ""), false):
		_say([["narrator", puzzle.get("done", "The dials sit where you left them. The door is open.")]], "end")
		return
	_say([["narrator", puzzle.get("text", "A wall of dials. They turn.")]])


func _show() -> void:
	var opts := []
	for n in puzzle.get("names", []):
		opts.append({"label": "Turn the %s dial" % n, "enabled": not n in _turned})
	opts.append({"label": "Step back", "enabled": true})
	_menu("Turned so far: %s" % (", ".join(_turned) if not _turned.is_empty() else "none"), opts)


func _on_option(i: int) -> void:
	var names: Array = puzzle.get("names", [])
	if i >= names.size():
		_end()
		return
	_turned.append(names[i])
	var order: Array = puzzle.get("order", [])
	if _turned.size() < order.size():
		if _turned != order.slice(0, _turned.size()):
			_turned = []
			_say([["narrator", puzzle.get("wrong", "A click, then nothing. The dials spin back to where they were.")]])
			return
		_show()
		return
	if _turned == order:
		GameState.flags[puzzle.get("flag", "dials")] = true
		toast.call("Something unlatches.")
		_say([["narrator", puzzle.get("done", "The last dial stops with a clunk and a door you had not seen swings in.")]], "end")
	else:
		_turned = []
		_say([["narrator", puzzle.get("wrong", "A click, then nothing. The dials spin back to where they were.")]])
