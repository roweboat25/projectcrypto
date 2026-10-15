extends Node
## Registers the game's input actions in code so they live in one readable place.

const ACTIONS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"rotate_left": [KEY_Q],
	"rotate_right": [KEY_E],
	"interact": [KEY_SPACE, KEY_ENTER, KEY_Z],
	"toggle_time": [KEY_T],
	"evidence": [KEY_TAB, KEY_I],
	"gear": [KEY_G],
	"cancel": [KEY_ESCAPE, KEY_X],
	"save": [KEY_F5],
	"load": [KEY_F9],
}


func _ready() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
