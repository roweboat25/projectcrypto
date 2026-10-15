extends Node3D
## HD-2D style camera: looks down at the party from a fixed tilt and distance,
## follows smoothly, and rotates in 45 degree steps with Q and E.

@export var target: Node3D
@export var distance := 15.0
@export var pitch_degrees := -38.0
@export var follow_speed := 6.0

var yaw := 0.0
var _yaw_goal := 0.0
var camera: Camera3D


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 30
	camera.current = true
	add_child(camera)
	if target:
		global_position = target.global_position


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("rotate_left"):
		_yaw_goal += PI / 4
	if Input.is_action_just_pressed("rotate_right"):
		_yaw_goal -= PI / 4
	yaw = lerp_angle(yaw, _yaw_goal, 1.0 - exp(-8.0 * delta))
	if target:
		global_position = global_position.lerp(target.global_position, 1.0 - exp(-follow_speed * delta))
	var pitch := deg_to_rad(pitch_degrees)
	var offset := Vector3(0, -sin(pitch), cos(pitch)) * distance
	camera.position = offset.rotated(Vector3.UP, yaw) + Vector3(0, 1.0, 0)
	camera.look_at(global_position + Vector3(0, 1.0, 0))


## Converts a 2D input vector into a world direction relative to the camera.
func world_direction(input: Vector2) -> Vector3:
	return Vector3(input.x, 0, input.y).rotated(Vector3.UP, yaw)
