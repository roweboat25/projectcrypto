extends CharacterBody2D
## A party member on the overworld. The leader reads input; followers walk a
## trail of the leader's past positions. Sheets are 9x4: idle, then 8 walk
## frames, rows down, left, right, up, 64px cells with the feet at the origin.

const SPEED := 96.0
const COLS := 9
const ROW := {"down": 0, "left": 1, "right": 2, "up": 3}

var leader: Node = null          # set on followers
var trail_gap := 14              # how many trail points behind the leader
var trail: Array[Vector2] = []
var facing := "down"
var sprite: Sprite2D
var _anim_t := 0.0
var _frame := 0
var _moving := false


func setup(sheet_id: String) -> void:
	var shadow := Sprite2D.new()
	shadow.texture = load("res://assets/sprites/shadow.png")
	shadow.position = Vector2(0, -2)
	shadow.z_index = -1
	add_child(shadow)
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/%s.png" % sheet_id)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.hframes = COLS
	sprite.vframes = 4
	sprite.position = Vector2(0, -29)
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 10)
	shape.shape = rect
	shape.position = Vector2(0, -5)
	add_child(shape)
	if leader != null:
		collision_layer = 0          # followers never block anyone
		collision_mask = 0
	_apply_frame()


func _physics_process(delta: float) -> void:
	var move := Vector2.ZERO
	if leader == null:
		if not GameState.flags.get("_talking", false):
			move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = move.normalized() * SPEED
		move_and_slide()
		if move.length() > 0.1:
			trail.push_front(global_position)
			if trail.size() > 240:
				trail.pop_back()
	else:
		var path: Array[Vector2] = leader.trail
		if path.size() > trail_gap:
			var goal: Vector2 = path[trail_gap]
			var to_goal := goal - global_position
			if to_goal.length() > 1.0:
				move = to_goal.normalized()
				global_position = global_position.move_toward(goal, SPEED * 1.1 * delta)
	_moving = move.length() > 0.1
	if _moving:
		_face(move)
	_animate(delta)


func face_toward(target: Vector2) -> void:
	_face(target - global_position)
	_apply_frame()


func _face(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		facing = "right" if dir.x > 0.0 else "left"
	else:
		facing = "down" if dir.y > 0.0 else "up"


func _animate(delta: float) -> void:
	if _moving:
		_anim_t += delta * 12.0
		_frame = 1 + int(_anim_t) % 8
	else:
		_anim_t = 0.0
		_frame = 0
	_apply_frame()


func _apply_frame() -> void:
	sprite.frame = ROW[facing] * COLS + _frame
