extends CharacterBody3D
## A party member on the overworld. The leader reads input; followers walk
## a trail of the leader's past positions. Animates a 4x3 placeholder sheet.

const SPEED := 5.0
const FRAME_TIME := 0.16

var leader: Node = null          # set on followers
var trail_gap := 12              # how many trail points behind the leader
var camera_rig: Node = null      # set on the leader
var trail: Array[Vector3] = []
var facing := 0                  # 0 down, 1 left, 2 right, 3 up (screen-relative)
var sprite: Sprite3D
var _anim_t := 0.0
var _moving := false


func setup(sheet: Texture2D) -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.4
	shape.shape = capsule
	shape.position.y = 0.7
	add_child(shape)
	sprite = Sprite3D.new()
	sprite.texture = sheet
	sprite.hframes = 4
	sprite.vframes = 3
	sprite.pixel_size = 0.036
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = true
	sprite.position.y = 0.86
	add_child(sprite)
	if leader != null:
		collision_layer = 0          # followers never block anyone
		collision_mask = 0


func _physics_process(delta: float) -> void:
	var move := Vector3.ZERO
	if leader == null:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if camera_rig and not get_tree().paused and not GameState.flags.get("_talking", false):
			move = camera_rig.world_direction(input)
		velocity = move * SPEED
		move_and_slide()
		if move.length() > 0.1:
			trail.push_front(global_position)
			if trail.size() > 200:
				trail.pop_back()
	else:
		var path: Array[Vector3] = leader.trail
		if path.size() > trail_gap:
			var goal: Vector3 = path[trail_gap]
			var to_goal := goal - global_position
			to_goal.y = 0
			if to_goal.length() > 0.05:
				move = to_goal.normalized()
				global_position = global_position.move_toward(Vector3(goal.x, global_position.y, goal.z), SPEED * 1.1 * delta)
	_moving = move.length() > 0.1
	if _moving:
		_face(move)
	_animate(delta)


func _face(world_move: Vector3) -> void:
	var yaw: float = 0.0
	var rig: Node = camera_rig if leader == null else leader.camera_rig
	if rig:
		yaw = rig.yaw
	var local := world_move.rotated(Vector3.UP, -yaw)
	if abs(local.x) > abs(local.z):
		facing = 2 if local.x > 0 else 1
	else:
		facing = 0 if local.z > 0 else 3


func _animate(delta: float) -> void:
	if _moving:
		_anim_t += delta
	else:
		_anim_t = 0.0
	var row := 0
	if _moving:
		row = 1 + int(_anim_t / FRAME_TIME) % 2
	sprite.frame = row * 4 + facing
